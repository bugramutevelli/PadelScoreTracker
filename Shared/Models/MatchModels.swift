import Foundation

enum Team: Int, Codable, CaseIterable, Identifiable, Sendable {
    case home = 0
    case away = 1

    var id: Int { rawValue }
    var opponent: Team { self == .home ? .away : .home }
}

enum ScoringRule: String, Codable, CaseIterable, Identifiable, Sendable {
    case advantage
    case starPoint
    case goldenPoint

    var id: String { rawValue }
    var title: String {
        switch self {
        case .advantage: "Klasik avantaj"
        case .starPoint: "Star Point"
        case .goldenPoint: "Golden Point"
        }
    }

    var explanation: String {
        switch self {
        case .advantage: "Deuce sonrası iki puan fark oluşana kadar devam eder."
        case .starPoint: "İki avantaj döngüsü sonuçlanmazsa üçüncü deuce’de tek karar puanı oynanır."
        case .goldenPoint: "İlk deuce’de oynanan tek karar puanı oyunu kazandırır."
        }
    }
}

enum MatchFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case bestOfThree
    case singleSet
    case miniSets
    case advantageFinalSet
    case matchTieBreak
    case superTieBreak

    var id: String { rawValue }
    var title: String {
        switch self {
        case .bestOfThree: "3 set üzerinden"
        case .singleSet: "Tek set"
        case .miniSets: "Mini setler"
        case .advantageFinalSet: "3. set: Avantaj seti"
        case .matchTieBreak: "3. set: Match tie-break"
        case .superTieBreak: "3. set: Super tie-break"
        }
    }
    var setsToWin: Int { self == .singleSet ? 1 : 2 }
    var gamesToWinSet: Int { self == .miniSets ? 4 : 6 }
    var decidingTieBreakTarget: Int? {
        switch self {
        case .matchTieBreak: 7
        case .superTieBreak: 10
        default: nil
        }
    }
    var explanation: String {
        switch self {
        case .bestOfThree: "İki set kazanan maçı alır; 6-6'da tie-break oynanır."
        case .singleSet: "Tek standart set oynanır."
        case .miniSets: "Setler 4 oyuna oynanır; 4-4'te tie-break yapılır."
        case .advantageFinalSet: "Üçüncü sette 6-6'dan sonra tie-break yoktur; iki oyun fark gerekir."
        case .matchTieBreak: "Setler 1-1 olursa üçüncü set yerine 7 puanlık tie-break oynanır."
        case .superTieBreak: "Setler 1-1 olursa üçüncü set yerine 10 puanlık super tie-break oynanır."
        }
    }
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

struct WorkoutMetrics: Codable, Equatable, Sendable {
    var duration: TimeInterval = 0
    var activeCalories: Double = 0
    var steps: Int = 0
    var distanceMeters: Double = 0
    var heartRate: Double = 0
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
    var workoutMetrics: WorkoutMetrics? = nil

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
        if rule == .starPoint, isDecidingPoint { return "★" }
        let other = team == .home ? awayPoints : homePoints
        if rule != .goldenPoint, value >= 3, other >= 3 {
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

    var isDecidingPoint: Bool {
        guard !isTieBreak, homePoints == awayPoints else { return false }
        switch rule {
        case .advantage: false
        case .goldenPoint: homePoints == 3
        case .starPoint: homePoints >= 5
        }
    }

    var isMatchTieBreak: Bool {
        isTieBreak && currentSet.homeGames == 0 && currentSet.awayGames == 0 &&
        completedSets.count == 2 && homeSets == 1 && awaySets == 1 &&
        format.decidingTieBreakTarget != nil
    }

    var decidingPointLabel: String? {
        guard isDecidingPoint else { return nil }
        return rule == .starPoint ? "STAR POINT" : "GOLDEN POINT"
    }
}
