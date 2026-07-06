import XCTest
@testable import RalliPadel

final class PadelScoringEngineTests: XCTestCase {
    func testAdvantageGameRequiresTwoPointLead() {
        var match = PadelMatch()
        repeatPoint(.home, 3, in: &match)
        repeatPoint(.away, 3, in: &match)

        PadelScoringEngine.awardPoint(to: .home, in: &match)
        XCTAssertEqual(match.pointLabel(for: .home), "AV")
        XCTAssertEqual(match.currentSet.homeGames, 0)

        PadelScoringEngine.awardPoint(to: .home, in: &match)
        XCTAssertEqual(match.currentSet.homeGames, 1)
        XCTAssertEqual(match.homePoints, 0)
    }

    func testGoldenPointEndsGameAtDeuce() {
        var match = PadelMatch(rule: .goldenPoint)
        repeatPoint(.home, 3, in: &match)
        repeatPoint(.away, 3, in: &match)
        PadelScoringEngine.awardPoint(to: .away, in: &match)
        XCTAssertEqual(match.currentSet.awayGames, 1)
    }

    func testTieBreakStartsAtSixAllAndEndsSevenFive() {
        var match = PadelMatch(format: .singleSet)
        for game in 0..<12 { winGame(game.isMultiple(of: 2) ? .home : .away, in: &match) }
        XCTAssertTrue(match.isTieBreak)

        repeatPoint(.home, 6, in: &match)
        repeatPoint(.away, 5, in: &match)
        PadelScoringEngine.awardPoint(to: .home, in: &match)

        XCTAssertEqual(match.winner, .home)
        XCTAssertEqual(match.completedSets.first?.homeGames, 7)
        XCTAssertEqual(match.completedSets.first?.awayGames, 6)
    }

    func testUndoRestoresPreviousScoreAndServer() {
        var match = PadelMatch()
        winGame(.home, in: &match)
        XCTAssertEqual(match.currentSet.homeGames, 1)
        XCTAssertEqual(match.serverIndex, 1)

        PadelScoringEngine.undo(in: &match)
        XCTAssertEqual(match.currentSet.homeGames, 0)
        XCTAssertEqual(match.homePoints, 3)
        XCTAssertEqual(match.serverIndex, 0)
    }

    private func repeatPoint(_ team: Team, _ count: Int, in match: inout PadelMatch) {
        for _ in 0..<count { PadelScoringEngine.awardPoint(to: team, in: &match) }
    }

    private func winGame(_ team: Team, in match: inout PadelMatch) {
        repeatPoint(team, 4, in: &match)
    }
}

