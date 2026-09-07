import Foundation
import Combine

@MainActor
final class MatchStore: ObservableObject {
    @Published private(set) var matches: [PadelMatch] = []
    @Published var activeMatch: PadelMatch?
    @Published private(set) var nearbyRole: MatchSessionRole = .solo
    @Published private(set) var nearbyMatchCode: String?
    @Published private(set) var nearbyStatusText = "Tek cihaz"
    @Published private(set) var nearbyPeerNames: [String] = []
    @Published private(set) var nearbyErrorMessage: String?

    private let fileURL: URL
    private let activeFileURL: URL
    private let sync = WatchSessionCoordinator.shared
    private var cancellables: Set<AnyCancellable> = []
    #if os(iOS)
    private let nearby = NearbyMatchSessionCoordinator.shared
    #endif

    init(fileURL: URL? = nil, activeFileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("RalliPadel", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? directory.appendingPathComponent("matches.json")
        self.activeFileURL = activeFileURL ?? directory.appendingPathComponent("active-match.json")
        load()
        sync.onMatchReceived = { [weak self] match in
            Task { @MainActor in self?.acceptWatchRemote(match) }
        }
        sync.onCommandReceived = { [weak self] command in
            Task { @MainActor in self?.executeWatchCommand(command) }
        }
        sync.onMatchCleared = { [weak self] in
            Task { @MainActor in
                self?.activeMatch = nil
                self?.clearActive()
            }
        }
        sync.onActiveMatchRequested = { [weak self] in
            Task { @MainActor in self?.broadcast() }
        }
        configureNearbySession()
    }

    func start(home: TeamPlayers, away: TeamPlayers, rule: ScoringRule, format: MatchFormat, firstServerIndex: Int) {
        activeMatch = PadelMatch(syncRevision: 1, home: home, away: away, rule: rule, format: format, serverIndex: firstServerIndex)
        saveActive()
        broadcast()
    }

    func awardPoint(to team: Team) {
        #if os(watchOS)
        sendWatchCommand(.awardPoint(team))
        guard var match = activeMatch else { return }
        PadelScoringEngine.awardPoint(to: team, in: &match)
        bumpRevision(&match)
        activeMatch = match
        persistActiveIfNeeded()
        #else
        guard nearbyRole != .participant else {
            sendNearbyCommand(.awardPoint(team))
            return
        }
        guard var match = activeMatch else { return }
        PadelScoringEngine.awardPoint(to: team, in: &match)
        bumpRevision(&match)
        activeMatch = match
        persistActiveIfNeeded()
        broadcast()
        broadcastNearbyState()
        #endif
    }

    func undo() {
        #if os(watchOS)
        sendWatchCommand(.undo)
        guard var match = activeMatch else { return }
        PadelScoringEngine.undo(in: &match)
        bumpRevision(&match)
        activeMatch = match
        saveActive()
        #else
        guard nearbyRole != .participant else {
            sendNearbyCommand(.undo)
            return
        }
        guard var match = activeMatch else { return }
        PadelScoringEngine.undo(in: &match)
        bumpRevision(&match)
        activeMatch = match
        saveActive()
        broadcast()
        broadcastNearbyState()
        #endif
    }

    func updateWorkoutMetrics(_ metrics: WorkoutMetrics) {
        guard var match = activeMatch, match.workoutMetrics != metrics else { return }
        match.workoutMetrics = metrics
        #if os(iOS)
        guard nearbyRole != .participant else {
            activeMatch = match
            saveActive()
            broadcast()
            return
        }
        #endif
        if nearbyRole != .participant {
            bumpRevision(&match)
        }
        activeMatch = match
        persistActiveIfNeeded()
        broadcast()
        broadcastNearbyState()
    }

    func finishEarly() {
        #if os(watchOS)
        sendWatchCommand(.finishEarly)
        guard var match = activeMatch else { return }
        match.endedAt = Date()
        bumpRevision(&match)
        archive(match)
        activeMatch = nil
        clearActive()
        #else
        guard nearbyRole != .participant else {
            sendNearbyCommand(.finishEarly)
            return
        }
        guard var match = activeMatch else { return }
        match.endedAt = Date()
        bumpRevision(&match)
        archive(match)
        activeMatch = nil
        clearActive()
        sync.clearMatch()
        clearNearbySession()
        #endif
    }

    func closeCompletedMatch() {
        guard let match = activeMatch, match.isFinished else { return }
        archive(match)
        activeMatch = nil
        clearActive()
        sync.clearMatch()
        clearNearbySession()
    }

    func requestActiveMatch() {
        sync.requestActiveMatch()
    }

    func publishActiveMatch() {
        broadcast()
        broadcastNearbyState()
    }

    func hostNearbyMatch() {
        guard let activeMatch else { return }
        #if os(iOS)
        let code = NearbyMatchSessionCoordinator.makeMatchCode()
        nearby.startHosting(matchCode: code, match: activeMatch)
        #endif
    }

    func joinNearbyMatch(code: String) {
        #if os(iOS)
        nearby.join(matchCode: code)
        #endif
    }

    func leaveNearbyMatch() {
        #if os(iOS)
        nearby.stop()
        #endif
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) { matches.remove(at: index) }
        save()
    }

    private func persistActiveIfNeeded() {
        saveActive()
        guard let match = activeMatch, match.isFinished else { return }
        archive(match)
    }

    private func archive(_ match: PadelMatch) {
        matches.removeAll { $0.id == match.id }
        matches.insert(match, at: 0)
        save()
    }

    private func acceptWatchRemote(_ match: PadelMatch) {
        #if os(iOS)
        guard nearbyRole != .participant else { return }
        #endif
        acceptRemote(match)
    }

    private func acceptRemote(_ match: PadelMatch) {
        activeMatch = mergedRemoteMatch(match)
        persistActiveIfNeeded()
        broadcast()
    }

    private func broadcast() {
        guard let activeMatch else { return }
        sync.send(activeMatch)
    }

    private func bumpRevision(_ match: inout PadelMatch) {
        match.syncRevision += 1
    }

    private func mergedRemoteMatch(_ remote: PadelMatch) -> PadelMatch {
        guard var current = activeMatch, current.id == remote.id else { return remote }
        guard remote.syncRevision >= current.syncRevision else { return current }
        let localMetrics = current.workoutMetrics
        current = remote
        if nearbyRole == .participant, localMetrics != nil {
            current.workoutMetrics = localMetrics
        }
        return current
    }

    private func executeNearbyCommand(_ command: MatchSessionCommand) {
        guard nearbyRole == .host else { return }
        executeLocalCommand(command)
    }

    private func executeWatchCommand(_ command: MatchSessionCommand) {
        #if os(iOS)
        if nearbyRole == .participant {
            sendNearbyCommand(command)
            return
        }
        #endif
        executeLocalCommand(command)
    }

    private func executeLocalCommand(_ command: MatchSessionCommand) {
        switch command {
        case .awardPoint(let team):
            guard var match = activeMatch else { return }
            PadelScoringEngine.awardPoint(to: team, in: &match)
            bumpRevision(&match)
            activeMatch = match
            persistActiveIfNeeded()
            broadcast()
            broadcastNearbyState()
        case .undo:
            guard var match = activeMatch else { return }
            PadelScoringEngine.undo(in: &match)
            bumpRevision(&match)
            activeMatch = match
            saveActive()
            broadcast()
            broadcastNearbyState()
        case .finishEarly:
            finishEarly()
        }
    }

    private func sendNearbyCommand(_ command: MatchSessionCommand) {
        #if os(iOS)
        nearby.sendCommand(command)
        #endif
    }

    private func sendWatchCommand(_ command: MatchSessionCommand) {
        sync.sendCommand(command)
    }

    private func broadcastNearbyState() {
        guard nearbyRole == .host, let activeMatch else { return }
        #if os(iOS)
        nearby.broadcast(activeMatch)
        #endif
    }

    private func clearNearbySession() {
        guard nearbyRole == .host else { return }
        #if os(iOS)
        nearby.clear()
        #endif
    }

    private func configureNearbySession() {
        #if os(iOS)
        nearby.onMatchReceived = { [weak self] match in
            Task { @MainActor in self?.acceptRemote(match) }
        }
        nearby.onCommandReceived = { [weak self] command in
            Task { @MainActor in self?.executeNearbyCommand(command) }
        }
        nearby.onPeerConnected = { [weak self] in
            Task { @MainActor in self?.broadcastNearbyState() }
        }
        nearby.onCleared = { [weak self] in
            Task { @MainActor in
                self?.activeMatch = nil
                self?.clearActive()
                self?.sync.clearMatch()
            }
        }

        nearby.$role.assign(to: &$nearbyRole)
        nearby.$matchCode.assign(to: &$nearbyMatchCode)
        nearby.$statusText.assign(to: &$nearbyStatusText)
        nearby.$connectedPeerNames.assign(to: &$nearbyPeerNames)
        nearby.$errorMessage.assign(to: &$nearbyErrorMessage)
        #endif
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PadelMatch].self, from: data) {
            matches = decoded
        }
        if let data = try? Data(contentsOf: activeFileURL),
           let decoded = try? JSONDecoder().decode(PadelMatch.self, from: data) {
            activeMatch = decoded
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(matches) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func saveActive() {
        guard let activeMatch, let data = try? JSONEncoder().encode(activeMatch) else { return }
        try? data.write(to: activeFileURL, options: .atomic)
    }

    private func clearActive() {
        try? FileManager.default.removeItem(at: activeFileURL)
    }
}

#if DEBUG
extension MatchStore {
    static func preview(active: Bool = false, scored: Bool = false) -> MatchStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RalliPadelPreviews", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let id = UUID().uuidString
        let store = MatchStore(
            fileURL: directory.appendingPathComponent("matches-\(id).json"),
            activeFileURL: directory.appendingPathComponent("active-match-\(id).json")
        )

        guard active else { return store }

        store.start(
            home: TeamPlayers(first: "Buğra", second: "Deniz"),
            away: TeamPlayers(first: "Ece", second: "Mert"),
            rule: .starPoint,
            format: .bestOfThree,
            firstServerIndex: 0
        )

        guard scored else { return store }

        [.home, .away, .home, .home, .away, .home, .away, .away, .home].forEach {
            store.awardPoint(to: $0)
        }

        return store
    }
}
#endif
