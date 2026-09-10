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
    private var closedMatchIDs: Set<UUID> = []
    private var processedCommandIDs: Set<UUID> = []
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
        closedMatchIDs = Set(matches.map(\.id))
        if let activeMatch { closedMatchIDs.remove(activeMatch.id) }
        sync.onMatchReceived = { [weak self] match in
            Task { @MainActor in self?.acceptWatchRemote(match) }
        }
        sync.onCommandReceived = { [weak self] command in
            Task { @MainActor in self?.executeWatchCommand(command) }
        }
        sync.onMatchCleared = { [weak self] match in
            Task { @MainActor in self?.handleRemoteClear(match) }
        }
        sync.onWorkoutMetricsReceived = { [weak self] matchID, metrics in
            Task { @MainActor in self?.acceptWorkoutMetrics(metrics, for: matchID) }
        }
        sync.onActiveMatchRequested = { [weak self] in
            Task { @MainActor in self?.broadcast() }
        }
        configureNearbySession()
    }

    func start(home: TeamPlayers, away: TeamPlayers, rule: ScoringRule, format: MatchFormat, firstServerIndex: Int) {
        let match = PadelMatch(syncRevision: 1, home: home, away: away, rule: rule, format: format, serverIndex: firstServerIndex)
        activeMatch = match
        closedMatchIDs.remove(match.id)
        processedCommandIDs.removeAll()
        saveActive()
        broadcast()
    }

    func awardPoint(to team: Team) {
        #if os(watchOS)
        guard let match = activeMatch else { return }
        sendWatchCommand(.awardPoint(team, matchID: match.id))
        #else
        guard nearbyRole != .participant else {
            guard let matchID = activeMatch?.id else { return }
            sendNearbyCommand(.awardPoint(team, matchID: matchID))
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
        guard let match = activeMatch else { return }
        sendWatchCommand(.undo(matchID: match.id))
        #else
        guard nearbyRole != .participant else {
            guard let matchID = activeMatch?.id else { return }
            sendNearbyCommand(.undo(matchID: matchID))
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
        activeMatch = match
        saveActive()
        #if os(watchOS)
        sync.sendWorkoutMetrics(metrics, for: match.id)
        #endif
    }

    func finishEarly() {
        #if os(watchOS)
        guard let match = activeMatch else { return }
        sendWatchCommand(.finishEarly(matchID: match.id))
        #else
        guard nearbyRole != .participant else {
            guard let matchID = activeMatch?.id else { return }
            sendNearbyCommand(.finishEarly(matchID: matchID))
            return
        }
        guard var match = activeMatch else { return }
        match.endedAt = Date()
        bumpRevision(&match)
        archive(match)
        closedMatchIDs.insert(match.id)
        activeMatch = nil
        clearActive()
        sync.clearMatch(match)
        clearNearbySession(match)
        #endif
    }

    func closeCompletedMatch() {
        guard let match = activeMatch, match.isFinished else { return }
        archive(match)
        closedMatchIDs.insert(match.id)
        activeMatch = nil
        clearActive()
        sync.clearMatch(match)
        clearNearbySession(match)
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
        guard activeMatch == nil else { return }
        #endif
        acceptRemoteState(match)
    }

    @discardableResult
    private func acceptRemoteState(_ match: PadelMatch) -> Bool {
        guard MatchSyncPolicy.shouldAccept(
            remote: match,
            current: activeMatch,
            closedMatchIDs: closedMatchIDs
        ) else { return false }

        var accepted = match
        #if os(watchOS)
        if let localMetrics = activeMatch?.workoutMetrics {
            accepted.workoutMetrics = localMetrics
        }
        #else
        if nearbyRole == .participant, let localMetrics = activeMatch?.workoutMetrics {
            accepted.workoutMetrics = localMetrics
        }
        #endif
        activeMatch = accepted
        persistActiveIfNeeded()
        return true
    }

    private func broadcast() {
        guard let activeMatch else { return }
        sync.send(activeMatch)
    }

    private func bumpRevision(_ match: inout PadelMatch) {
        match.syncRevision += 1
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
        guard activeMatch?.id == command.matchID else { return }
        guard processedCommandIDs.insert(command.id).inserted else { return }

        switch command.action {
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

    private func clearNearbySession(_ match: PadelMatch) {
        guard nearbyRole == .host else { return }
        #if os(iOS)
        nearby.clear(match)
        #endif
    }

    private func configureNearbySession() {
        #if os(iOS)
        nearby.onMatchReceived = { [weak self] match in
            Task { @MainActor in
                guard let self, self.nearbyRole == .participant else { return }
                if self.acceptRemoteState(match) { self.broadcast() }
            }
        }
        nearby.onCommandReceived = { [weak self] command in
            Task { @MainActor in self?.executeNearbyCommand(command) }
        }
        nearby.onPeerConnected = { [weak self] in
            Task { @MainActor in self?.broadcastNearbyState() }
        }
        nearby.onCleared = { [weak self] match in
            Task { @MainActor in
                guard let self else { return }
                let finalizedMatch = self.handleRemoteClear(match)
                if let finalizedMatch { self.sync.clearMatch(finalizedMatch) }
                self.nearby.stop()
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

    private func acceptWorkoutMetrics(_ metrics: WorkoutMetrics, for matchID: UUID) {
        guard var match = activeMatch, match.id == matchID else { return }
        guard match.workoutMetrics != metrics else { return }
        match.workoutMetrics = metrics
        activeMatch = match
        saveActive()
    }

    @discardableResult
    private func handleRemoteClear(_ finalizedMatch: PadelMatch?) -> PadelMatch? {
        var matchToClose = finalizedMatch
        if var finalizedMatch,
           finalizedMatch.id == activeMatch?.id,
           let localMetrics = activeMatch?.workoutMetrics {
            finalizedMatch.workoutMetrics = localMetrics
            matchToClose = finalizedMatch
        }
        if matchToClose == nil, var current = activeMatch {
            current.endedAt = current.endedAt ?? Date()
            matchToClose = current
        }
        guard let matchToClose else { return nil }

        archive(matchToClose)
        closedMatchIDs.insert(matchToClose.id)
        if activeMatch?.id == matchToClose.id {
            activeMatch = nil
            clearActive()
        }
        return matchToClose
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
