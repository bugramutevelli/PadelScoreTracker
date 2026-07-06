import Foundation

enum PadelScoringEngine {
    static func awardPoint(to team: Team, in match: inout PadelMatch) {
        guard !match.isFinished else { return }
        match.history.append(snapshot(of: match))

        if match.isTieBreak {
            awardTieBreakPoint(to: team, in: &match)
            return
        }

        if team == .home { match.homePoints += 1 } else { match.awayPoints += 1 }
        let ours = team == .home ? match.homePoints : match.awayPoints
        let theirs = team == .home ? match.awayPoints : match.homePoints
        let gameWon: Bool
        switch match.rule {
        case .advantage:
            gameWon = ours >= 4 && ours - theirs >= 2
        case .goldenPoint:
            gameWon = ours >= 4
        }
        if gameWon { completeGame(for: team, in: &match) }
    }

    static func undo(in match: inout PadelMatch) {
        guard let previous = match.history.popLast() else { return }
        match.completedSets = previous.sets
        match.currentSet = previous.currentSet
        match.homePoints = previous.homePoints
        match.awayPoints = previous.awayPoints
        match.isTieBreak = previous.isTieBreak
        match.serverIndex = previous.serverIndex
        match.tieBreakPointsPlayed = previous.tieBreakPointsPlayed
        match.winner = previous.winner
        if match.winner == nil { match.endedAt = nil }
    }

    private static func completeGame(for team: Team, in match: inout PadelMatch) {
        if team == .home { match.currentSet.homeGames += 1 } else { match.currentSet.awayGames += 1 }
        match.homePoints = 0
        match.awayPoints = 0
        match.serverIndex = (match.serverIndex + 1) % 4

        let ours = team == .home ? match.currentSet.homeGames : match.currentSet.awayGames
        let theirs = team == .home ? match.currentSet.awayGames : match.currentSet.homeGames
        if ours >= 6 && ours - theirs >= 2 {
            completeSet(for: team, in: &match)
        } else if match.currentSet.homeGames == 6 && match.currentSet.awayGames == 6 {
            match.isTieBreak = true
            match.tieBreakPointsPlayed = 0
        }
    }

    private static func awardTieBreakPoint(to team: Team, in match: inout PadelMatch) {
        if team == .home { match.homePoints += 1 } else { match.awayPoints += 1 }
        match.tieBreakPointsPlayed += 1
        if match.tieBreakPointsPlayed == 1 || match.tieBreakPointsPlayed % 2 == 1 {
            match.serverIndex = (match.serverIndex + 1) % 4
        }

        let ours = team == .home ? match.homePoints : match.awayPoints
        let theirs = team == .home ? match.awayPoints : match.homePoints
        if ours >= 7 && ours - theirs >= 2 {
            match.currentSet.homeTieBreak = match.homePoints
            match.currentSet.awayTieBreak = match.awayPoints
            if team == .home { match.currentSet.homeGames = 7 } else { match.currentSet.awayGames = 7 }
            completeSet(for: team, in: &match)
        }
    }

    private static func completeSet(for team: Team, in match: inout PadelMatch) {
        match.completedSets.append(match.currentSet)
        match.currentSet = SetScore()
        match.homePoints = 0
        match.awayPoints = 0
        match.isTieBreak = false
        match.tieBreakPointsPlayed = 0

        let wonSets = team == .home ? match.homeSets : match.awaySets
        if wonSets >= match.format.setsToWin {
            match.winner = team
            match.endedAt = Date()
        }
    }

    private static func snapshot(of match: PadelMatch) -> ScoreSnapshot {
        ScoreSnapshot(
            sets: match.completedSets,
            currentSet: match.currentSet,
            homePoints: match.homePoints,
            awayPoints: match.awayPoints,
            isTieBreak: match.isTieBreak,
            serverIndex: match.serverIndex,
            tieBreakPointsPlayed: match.tieBreakPointsPlayed,
            winner: match.winner
        )
    }
}
