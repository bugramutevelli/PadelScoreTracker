import XCTest
@testable import PadelScoreTracker

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

    func testStarPointEndsGameAfterTwoUnresolvedAdvantages() {
        var match = PadelMatch(rule: .starPoint)
        repeatPoint(.home, 3, in: &match)
        repeatPoint(.away, 3, in: &match)
        PadelScoringEngine.awardPoint(to: .home, in: &match)
        PadelScoringEngine.awardPoint(to: .away, in: &match)
        PadelScoringEngine.awardPoint(to: .away, in: &match)
        PadelScoringEngine.awardPoint(to: .home, in: &match)

        XCTAssertTrue(match.isDecidingPoint)
        XCTAssertEqual(match.decidingPointLabel, "STAR POINT")

        PadelScoringEngine.awardPoint(to: .away, in: &match)
        XCTAssertEqual(match.currentSet.awayGames, 1)
        XCTAssertEqual(match.homePoints, 0)
        XCTAssertEqual(match.awayPoints, 0)
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

    func testMiniSetStartsTieBreakAtFourAll() {
        var match = PadelMatch(format: .miniSets)
        for game in 0..<8 { winGame(game.isMultiple(of: 2) ? .home : .away, in: &match) }
        XCTAssertTrue(match.isTieBreak)
        XCTAssertEqual(match.currentSet.homeGames, 4)
        XCTAssertEqual(match.currentSet.awayGames, 4)
    }

    func testSuperTieBreakReplacesThirdSet() {
        var match = PadelMatch(format: .superTieBreak)
        for _ in 0..<6 { winGame(.home, in: &match) }
        for _ in 0..<6 { winGame(.away, in: &match) }

        XCTAssertTrue(match.isMatchTieBreak)
        repeatPoint(.home, 10, in: &match)
        XCTAssertEqual(match.winner, .home)
        XCTAssertEqual(match.completedSets.last?.homeTieBreak, 10)
    }

    func testAdvantageFinalSetContinuesPastSixAll() {
        var match = PadelMatch(format: .advantageFinalSet)
        for _ in 0..<6 { winGame(.home, in: &match) }
        for _ in 0..<6 { winGame(.away, in: &match) }
        for game in 0..<12 { winGame(game.isMultiple(of: 2) ? .home : .away, in: &match) }

        XCTAssertFalse(match.isTieBreak)
        XCTAssertEqual(match.currentSet.homeGames, 6)
        XCTAssertEqual(match.currentSet.awayGames, 6)

        winGame(.home, in: &match)
        winGame(.home, in: &match)
        XCTAssertEqual(match.winner, .home)
    }

    func testMatchDecodesLegacyJSONWithoutSyncRevision() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "startedAt": 0,
          "home": { "first": "A", "second": "B" },
          "away": { "first": "C", "second": "D" },
          "rule": "advantage",
          "format": "bestOfThree",
          "completedSets": [],
          "currentSet": {
            "homeGames": 0,
            "awayGames": 0
          },
          "homePoints": 0,
          "awayPoints": 0,
          "isTieBreak": false,
          "serverIndex": 0,
          "tieBreakPointsPlayed": 0,
          "history": []
        }
        """.data(using: .utf8)!

        let match = try JSONDecoder().decode(PadelMatch.self, from: json)
        XCTAssertEqual(match.syncRevision, 0)
        XCTAssertEqual(match.home.displayName, "A & B")
    }

    private func repeatPoint(_ team: Team, _ count: Int, in match: inout PadelMatch) {
        for _ in 0..<count { PadelScoringEngine.awardPoint(to: team, in: &match) }
    }

    private func winGame(_ team: Team, in match: inout PadelMatch) {
        repeatPoint(team, 4, in: &match)
    }
}
