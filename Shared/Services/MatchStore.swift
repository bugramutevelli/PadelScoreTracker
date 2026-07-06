import Foundation
import Combine

@MainActor
final class MatchStore: ObservableObject {
    @Published private(set) var matches: [PadelMatch] = []
    @Published var activeMatch: PadelMatch?

    private let fileURL: URL
    private let activeFileURL: URL
    private let sync = WatchSessionCoordinator.shared

    init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("RalliPadel", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? directory.appendingPathComponent("matches.json")
        self.activeFileURL = directory.appendingPathComponent("active-match.json")
        load()
        sync.onMatchReceived = { [weak self] match in
            Task { @MainActor in self?.acceptRemote(match) }
        }
    }

    func start(home: TeamPlayers, away: TeamPlayers, rule: ScoringRule, format: MatchFormat, firstServerIndex: Int) {
        activeMatch = PadelMatch(home: home, away: away, rule: rule, format: format, serverIndex: firstServerIndex)
        saveActive()
        broadcast()
    }

    func awardPoint(to team: Team) {
        guard var match = activeMatch else { return }
        PadelScoringEngine.awardPoint(to: team, in: &match)
        activeMatch = match
        persistActiveIfNeeded()
        broadcast()
    }

    func undo() {
        guard var match = activeMatch else { return }
        PadelScoringEngine.undo(in: &match)
        activeMatch = match
        saveActive()
        broadcast()
    }

    func finishEarly() {
        guard var match = activeMatch else { return }
        match.endedAt = Date()
        archive(match)
        activeMatch = nil
        clearActive()
        sync.clearMatch()
    }

    func closeCompletedMatch() {
        guard let match = activeMatch, match.isFinished else { return }
        archive(match)
        activeMatch = nil
        clearActive()
        sync.clearMatch()
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

    private func acceptRemote(_ match: PadelMatch) {
        activeMatch = match
        persistActiveIfNeeded()
        broadcast()
    }

    private func broadcast() {
        guard let activeMatch else { return }
        sync.send(activeMatch)
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
