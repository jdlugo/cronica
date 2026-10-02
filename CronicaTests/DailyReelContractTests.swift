import Foundation
import XCTest

#if canImport(Story)
@testable import Story
#elseif canImport(Cronica)
@testable import Cronica
#endif

final class DailyReelContractTests: XCTestCase {
    private struct ScoringFixture: Decodable {
        struct TestCase: Decodable {
            let name: String
            let input: DailyReelActScoreInput
            let expectedScore: Int
        }

        let cases: [TestCase]
    }

    private struct TransitionFixture: Decodable {
        struct Scenario: Decodable {
            let name: String
            let initial: DailyReelActProgress
            let events: [Event]
            let expected: DailyReelActProgress
        }

        struct Event: Decodable {
            let type: String
            let clueId: String?
            let affectsScore: Bool?

            var domainEvent: DailyReelActEvent {
                switch type {
                case "incorrect": .incorrect
                case "correct": .correct
                case "requestClue": .requestClue(
                    id: clueId ?? "",
                    affectsScore: affectsScore ?? false
                )
                case "reveal": .reveal
                default: .reveal
                }
            }
        }

        let maxIncorrectAttemptsPerAct: Int
        let scenarios: [Scenario]
    }

    func testPublishedFixtureDecodesEverySupportedLocaleAndActRole() throws {
        let reel = try decode(DailyReel.self, fixture: "published-reel.json")

        XCTAssertEqual(reel.contractVersion, DailyReelContract.version)
        XCTAssertEqual(reel.scoringVersion, DailyReelContract.scoringVersion)
        XCTAssertEqual(reel.supportedLocales, DailyReelContract.locales)
        XCTAssertEqual(Set(reel.localized.keys), Set(DailyReelContract.locales))

        for locale in DailyReelContract.locales {
            let content = try XCTUnwrap(reel.localized[locale])
            XCTAssertEqual(content.acts.map(\.role), [.decode, .connect, .arrange])
        }
    }

    func testScoringMatchesSharedFixtures() throws {
        let fixture = try decode(ScoringFixture.self, fixture: "scoring-cases.json")

        for testCase in fixture.cases {
            XCTAssertEqual(
                DailyReelScoring.scoreAct(testCase.input),
                testCase.expectedScore,
                testCase.name
            )
        }
    }

    func testStateTransitionsMatchSharedFixtures() throws {
        let fixture = try decode(TransitionFixture.self, fixture: "session-transitions.json")

        for scenario in fixture.scenarios {
            let result = scenario.events.reduce(scenario.initial) { state, event in
                state.applying(
                    event.domainEvent,
                    maxIncorrectAttempts: fixture.maxIncorrectAttemptsPerAct
                )
            }
            XCTAssertEqual(result, scenario.expected, scenario.name)
        }
    }

    func testTotalScoreCapsAtThreeHundred() {
        XCTAssertEqual(DailyReelScoring.totalScore([100, 75, 50]), 225)
        XCTAssertEqual(DailyReelScoring.totalScore([200, 200, 200]), 300)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, fixture: String) throws -> Value {
        let data = try Data(contentsOf: fixtureURL(fixture))
        return try JSONDecoder().decode(type, from: data)
    }

    private func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("contracts/daily-reel/v1/fixtures")
            .appendingPathComponent(name)
    }
}
