import Foundation

enum Team: Int, Codable, CaseIterable, Identifiable, Sendable {
    case home = 0
    case away = 1

    var id: Int { rawValue }
    var opponent: Team { self == .home ? .away : .home }
}

enum ScoringRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case advantage
    case goldenPoint

    var id: String { rawValue }
    var title: String { self == .advantage ? "Avantaj" : "Altın puan" }
}

enum MatchFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case bestOfThree
    case singleSet

    var id: String { rawValue }
    var title: String { self == .bestOfThree ? "3 set üzerinden" : "Tek set" }
    var setsToWin: Int { self == .bestOfThree ? 2 : 1 }
}

struct TeamPlayers: Codable, Equatable, Sendable {
    var first: String
    var second: String

    var displayName: String { "\(first) & \(second)" }
    static let homeDefault = TeamPlayers(first: "Oyuncu 1", second: "Oyuncu 2")
    static let awayDefault = TeamPlayers(first: "Oyuncu 3", second: "Oyuncu 4")
}

struct SetScore: Codable, Equatable, Sendable {
    var homeGames: Int = 0
    var awayGames: Int = 0
    var homeTieBreak: Int? = nil
    var awayTieBreak: Int? = nil
}

struct ScoreSnapshot: Codable, Equatable, Sendable {
    var sets: [SetScore]
    var currentSet: SetScore
    var homePoints: Int
    var awayPoints: Int
    var isTieBreak: Bool
    var serverIndex: Int
    var tieBreakPointsPlayed: Int
    var winner: Team?
}

struct PadelMatch: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date? = nil
    var home: TeamPlayers = .homeDefault
    var away: TeamPlayers = .awayDefault
    var rule: ScoringRule = .advantage
    var format: MatchFormat = .bestOfThree
    var completedSets: [SetScore] = []
    var currentSet: SetScore = SetScore()
    var homePoints: Int = 0
    var awayPoints: Int = 0
    var isTieBreak: Bool = false
    var serverIndex: Int = 0
    var tieBreakPointsPlayed: Int = 0
    var winner: Team? = nil
    var history: [ScoreSnapshot] = []

    var duration: TimeInterval { (endedAt ?? Date()).timeIntervalSince(startedAt) }
    var isFinished: Bool { winner != nil }
    var homeSets: Int { completedSets.filter { $0.homeGames > $0.awayGames }.count }
    var awaySets: Int { completedSets.filter { $0.awayGames > $0.homeGames }.count }

    func teamName(_ team: Team) -> String {
        team == .home ? home.displayName : away.displayName
    }

    func pointLabel(for team: Team) -> String {
        let value = team == .home ? homePoints : awayPoints
        if isTieBreak { return String(value) }
        let other = team == .home ? awayPoints : homePoints
        if rule == .advantage, value >= 3, other >= 3 {
            if value == other { return "40" }
            return value > other ? "AV" : "40"
        }
        return ["0", "15", "30", "40"][min(value, 3)]
    }

    var currentServerName: String {
        let players = [home.first, away.first, home.second, away.second]
        return players[serverIndex % players.count]
    }

    var currentServerTeam: Team { serverIndex.isMultiple(of: 2) ? .home : .away }

    var receivingSide: String {
        (homePoints + awayPoints).isMultiple(of: 2) ? "Sağ taraf" : "Sol taraf"
    }
}

