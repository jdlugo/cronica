import XCTest
@testable import StreamingNow

final class ReviewPromptCoordinatorTests: XCTestCase {
    private var suiteName: String!
    private var userDefaults: UserDefaults!
    private var calendar: Calendar!
    private var coordinator: ReviewPromptCoordinator!

    override func setUp() {
        super.setUp()
        suiteName = "ReviewPromptCoordinatorTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        coordinator = ReviewPromptCoordinator(userDefaults: userDefaults, calendar: calendar)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        coordinator = nil
        calendar = nil
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstDaySolveIsNotEligible() {
        coordinator.recordActiveDay(on: date(day: 1))
        coordinator.recordMilestone(.canonicalDailyPuzzleSolved)

        XCTAssertEqual(
            coordinator.decision(
                now: date(day: 1),
                appVersion: "1.0",
                context: .clear
            ),
            .suppressed(.insufficientActiveDays)
        )
    }

    func testMilestoneAfterThreeDistinctActiveDaysIsEligible() {
        recordThreeActiveDays()
        coordinator.recordMilestone(.dailyRunCompleted)

        XCTAssertEqual(
            coordinator.decision(
                now: date(day: 3),
                appVersion: "1.0",
                context: .clear
            ),
            .eligible(.dailyRunCompleted)
        )
    }

    func testSameAppVersionCannotRequestTwice() {
        makeEligible()
        coordinator.recordRequestAttempt(
            now: date(day: 3),
            appVersion: "1.0",
            milestone: .canonicalDailyPuzzleSolved
        )

        XCTAssertEqual(
            coordinator.decision(
                now: date(day: 400),
                appVersion: "1.0",
                context: .clear
            ),
            .suppressed(.sameAppVersion)
        )
    }

    func testNewVersionWithinCooldownIsSuppressed() {
        makeEligible()
        coordinator.recordRequestAttempt(
            now: date(day: 3),
            appVersion: "1.0",
            milestone: .canonicalDailyPuzzleSolved
        )

        XCTAssertEqual(
            coordinator.decision(
                now: date(day: 100),
                appVersion: "1.1",
                context: .clear
            ),
            .suppressed(.cooldownActive)
        )
    }

    func testBlockingPresentationStatesSuppressEligibility() {
        makeEligible()

        XCTAssertEqual(
            decision(context: ReviewPromptContext(
                onboardingActive: true,
                blockingPresentationActive: false,
                fullScreenAdActive: false
            )),
            .suppressed(.onboardingActive)
        )
        XCTAssertEqual(
            decision(context: ReviewPromptContext(
                onboardingActive: false,
                blockingPresentationActive: true,
                fullScreenAdActive: false
            )),
            .suppressed(.blockingPresentationActive)
        )
        XCTAssertEqual(
            decision(context: ReviewPromptContext(
                onboardingActive: false,
                blockingPresentationActive: false,
                fullScreenAdActive: true
            )),
            .suppressed(.fullScreenAdActive)
        )
    }

    func testNewVersionIsEligibleAtExactCooldownBoundary() throws {
        makeEligible()
        let requestDate = date(day: 3)
        coordinator.recordRequestAttempt(
            now: requestDate,
            appVersion: "1.0",
            milestone: .canonicalDailyPuzzleSolved
        )
        let boundary = try XCTUnwrap(
            calendar.date(
                byAdding: .day,
                value: ReviewPromptCoordinator.cooldownDays,
                to: requestDate
            )
        )

        XCTAssertEqual(
            coordinator.decision(
                now: boundary,
                appVersion: "1.1",
                context: .clear
            ),
            .eligible(.canonicalDailyPuzzleSolved)
        )
    }

    private func makeEligible() {
        recordThreeActiveDays()
        coordinator.recordMilestone(.canonicalDailyPuzzleSolved)
    }

    private func recordThreeActiveDays() {
        coordinator.recordActiveDay(on: date(day: 1))
        coordinator.recordActiveDay(on: date(day: 2))
        coordinator.recordActiveDay(on: date(day: 3))
    }

    private func decision(context: ReviewPromptContext) -> ReviewPromptDecision {
        coordinator.decision(
            now: date(day: 3),
            appVersion: "1.0",
            context: context
        )
    }

    private func date(day: Int) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: day
        ))!
    }
}
