import XCTest
import UserNotifications
#if os(iOS)
import SwiftUI
import UIKit
#endif
@testable import StreamingNow

/// Tests for SettingsStore default values and persistence behavior.
/// Critical for ensuring ad gating works correctly across app launches.
final class SettingsStoreTests: XCTestCase {

    private let tipJarKey = "userHasPurchasedTipJar"

    override func tearDown() {
        // Clean up any test state
        UserDefaults.standard.removeObject(forKey: tipJarKey)
        super.tearDown()
    }

    // MARK: - Tip Jar Defaults

    func testTipJarDefaultIsFalse() {
        UserDefaults.standard.removeObject(forKey: tipJarKey)
        XCTAssertFalse(SettingsStore.shared.hasPurchasedTipJar,
                        "Tip jar should default to false for new users")
    }

    func testTipJarPersistsTrue() {
        UserDefaults.standard.set(true, forKey: tipJarKey)
        XCTAssertTrue(SettingsStore.shared.hasPurchasedTipJar)
    }

    func testTipJarPersistsFalse() {
        UserDefaults.standard.set(false, forKey: tipJarKey)
        XCTAssertFalse(SettingsStore.shared.hasPurchasedTipJar)
    }

    // MARK: - Other Defaults

    func testDefaultWatchProviderEnabled() {
        XCTAssertTrue(SettingsStore.shared.isWatchProviderEnabled,
                       "Watch providers should be enabled by default")
    }

    func testDefaultNotificationSettings() {
        #if os(iOS)
        XCTAssertTrue(SettingsStore.shared.allowNotifications,
                       "Notifications should be enabled by default on iOS")
        XCTAssertTrue(SettingsStore.shared.notifyMovieRelease)
        XCTAssertTrue(SettingsStore.shared.notifyNewEpisodes)
        #endif
    }

    // MARK: - Singleton

    func testSharedInstanceIsConsistent() {
        let a = SettingsStore.shared
        let b = SettingsStore.shared
        XCTAssertTrue(a === b, "SettingsStore.shared should always return the same instance")
    }
}

final class TelemetryLocalePropertiesTests: XCTestCase {
    func testLocalePropertiesNormalizeTerritoryJoinDimensions() {
        let properties = CronicaTelemetry.localeProperties(
            appLocale: "pt_BR",
            deviceRegion: "br",
            contentRegion: .br
        )

        XCTAssertEqual(properties["app_locale"] as? String, "pt-BR")
        XCTAssertEqual(properties["device_region"] as? String, "BR")
        XCTAssertEqual(properties["content_region"] as? String, "BR")
    }

    func testLocalePropertiesDoNotInventMissingLocaleOrRegion() {
        let properties = CronicaTelemetry.localeProperties(
            appLocale: "  ",
            deviceRegion: nil,
            contentRegion: .mx
        )

        XCTAssertEqual(properties["app_locale"] as? String, "unknown")
        XCTAssertEqual(properties["device_region"] as? String, "unknown")
        XCTAssertEqual(properties["content_region"] as? String, "MX")
    }
}

final class DailyPuzzleStreakStoreTests: XCTestCase {

    private let currentStreakKey = "dailyPuzzleCurrentStreak"
    private let bestStreakKey = "dailyPuzzleBestStreak"
    private let lastSolvedDateKey = "dailyPuzzleLastSolvedDate"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: currentStreakKey)
        UserDefaults.standard.removeObject(forKey: bestStreakKey)
        UserDefaults.standard.removeObject(forKey: lastSolvedDateKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: currentStreakKey)
        UserDefaults.standard.removeObject(forKey: bestStreakKey)
        UserDefaults.standard.removeObject(forKey: lastSolvedDateKey)
        super.tearDown()
    }

    func testSolveOnConsecutiveDayIncrementsStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let store = DailyPuzzleStreakStore(userDefaults: .standard, calendar: calendar)
        let formatter = ISO8601DateFormatter()

        store.recordSolved(on: formatter.date(from: "2026-02-15T12:00:00Z")!)
        store.recordSolved(on: formatter.date(from: "2026-02-16T12:00:00Z")!)

        XCTAssertEqual(store.currentStreak, 2)
    }

    func testMissingDayResetsStreakToOne() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let store = DailyPuzzleStreakStore(userDefaults: .standard, calendar: calendar)
        let formatter = ISO8601DateFormatter()

        store.recordSolved(on: formatter.date(from: "2026-02-15T12:00:00Z")!)
        store.recordSolved(on: formatter.date(from: "2026-02-18T12:00:00Z")!)

        XCTAssertEqual(store.currentStreak, 1)
    }
}

@MainActor
final class DailyPuzzleViewModelTests: XCTestCase {

    private let currentStreakKey = "dailyPuzzleCurrentStreak"
    private let bestStreakKey = "dailyPuzzleBestStreak"
    private let lastSolvedDateKey = "dailyPuzzleLastSolvedDate"
    private let promptSeenKey = "dailyPuzzlePromptSeen"
    private let progressKey = "dailyPuzzleProgress-2026-02-15"
    private let archiveXPKey = "dailyPuzzleArchiveXP"
    private let archiveSolvedPuzzleIDsKey = "dailyPuzzleArchiveSolvedPuzzleIDs"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: currentStreakKey)
        UserDefaults.standard.removeObject(forKey: bestStreakKey)
        UserDefaults.standard.removeObject(forKey: lastSolvedDateKey)
        UserDefaults.standard.removeObject(forKey: promptSeenKey)
        UserDefaults.standard.removeObject(forKey: progressKey)
        UserDefaults.standard.removeObject(forKey: "dailyPuzzleReminderCompletedAt")
        UserDefaults.standard.removeObject(forKey: archiveXPKey)
        UserDefaults.standard.removeObject(forKey: archiveSolvedPuzzleIDsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: currentStreakKey)
        UserDefaults.standard.removeObject(forKey: bestStreakKey)
        UserDefaults.standard.removeObject(forKey: lastSolvedDateKey)
        UserDefaults.standard.removeObject(forKey: promptSeenKey)
        UserDefaults.standard.removeObject(forKey: progressKey)
        UserDefaults.standard.removeObject(forKey: "dailyPuzzleReminderCompletedAt")
        UserDefaults.standard.removeObject(forKey: archiveXPKey)
        UserDefaults.standard.removeObject(forKey: archiveSolvedPuzzleIDsKey)
        super.tearDown()
    }

    func testFirstAnswerPromptsForNotificationWhenStatusIsNotDetermined() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore
        )

        // Prompt now fires post-solve, not on first wrong guess
        viewModel.submitGuess("Avatar", notificationStatus: .notDetermined, now: Date())
        XCTAssertFalse(viewModel.shouldShowNotificationPrompt)

        viewModel.submitGuess("Titanic", notificationStatus: .notDetermined, now: Date())
        XCTAssertTrue(viewModel.isSolved)
        XCTAssertTrue(viewModel.shouldShowNotificationPrompt)
        XCTAssertFalse(promptStore.hasSeenPrompt)
    }

    func testPromptIsMarkedSeenWhenDismissedAndIsNotShownAgain() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore
        )

        viewModel.submitGuess("Avatar", notificationStatus: .notDetermined, now: Date())
        viewModel.markNotificationPromptHandled(granted: false)
        viewModel.submitGuess("Interstellar", notificationStatus: .notDetermined, now: Date())

        XCTAssertTrue(promptStore.hasSeenPrompt)
        XCTAssertEqual(viewModel.attempts, 2)
        XCTAssertFalse(viewModel.shouldShowNotificationPrompt)
    }

    func testCorrectGuessMarksSolvedAndUpdatesStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard, calendar: calendar)
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore
        )

        let solvedAt = ISO8601DateFormatter().date(from: "2026-02-15T08:00:00Z")!
        viewModel.submitGuess("Titanic", notificationStatus: .authorized, now: solvedAt)

        XCTAssertTrue(viewModel.isSolved)
        XCTAssertEqual(streakStore.currentStreak, 1)
        XCTAssertEqual(streakStore.bestStreak, 1)
        XCTAssertEqual(viewModel.cardStatusText, "1-day Streak! 🔥")
    }

    func testArchivePuzzleSolveDoesNotUpdateDailyStreak() {
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let progressStore = DailyPuzzleProgressStore(userDefaults: .standard)
        let puzzle = makeHistoricalPuzzle()
        let viewModel = ArchivePuzzleViewModel(
            puzzle: puzzle,
            progressStore: progressStore
        )

        viewModel.submitGuess("Titanic", notificationStatus: .authorized, now: Date())

        XCTAssertTrue(viewModel.isSolved)
        XCTAssertEqual(streakStore.currentStreak, 0)
        XCTAssertEqual(streakStore.bestStreak, 0)
    }

    func testArchivePuzzleProgressPersistedAndStarRatingComputed() {
        let progressStore = DailyPuzzleProgressStore(userDefaults: .standard)
        let puzzle = makeHistoricalPuzzle()

        let first = ArchivePuzzleViewModel(
            puzzle: puzzle,
            progressStore: progressStore
        )
        first.submitGuess("Titanic", notificationStatus: .authorized, now: Date())

        XCTAssertTrue(first.isSolved)
        XCTAssertEqual(first.starRating, 3) // 1 attempt = 3 stars

        // Re-creating the VM should restore progress
        let second = ArchivePuzzleViewModel(
            puzzle: puzzle,
            progressStore: progressStore
        )
        XCTAssertTrue(second.isSolved)
        XCTAssertEqual(second.attempts, 1)
        XCTAssertEqual(second.starRating, 3)
    }

    func testCorrectGuessIncrementsSolveCelebrationCountOnce() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore
        )

        XCTAssertEqual(viewModel.solveCelebrationCount, 0)

        viewModel.submitGuess("Avatar", notificationStatus: .authorized, now: Date())
        XCTAssertEqual(viewModel.solveCelebrationCount, 0)

        viewModel.submitGuess("Titanic", notificationStatus: .authorized, now: Date())
        XCTAssertEqual(viewModel.solveCelebrationCount, 1)

        viewModel.submitGuess("Titanic", notificationStatus: .authorized, now: Date())
        XCTAssertEqual(viewModel.solveCelebrationCount, 1)
    }

    func testPracticePuzzleDoesNotIncrementDailyStreak() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore,
            recordsDailyStreak: false
        )

        viewModel.submitGuess("Titanic", notificationStatus: .authorized, now: Date())

        XCTAssertTrue(viewModel.isSolved)
        XCTAssertEqual(viewModel.currentStreak, 0)
    }

    func testBlankGuessDoesNotIncrementAttemptsOrPrompt() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore
        )

        viewModel.submitGuess("   ", notificationStatus: .notDetermined, now: Date())

        XCTAssertEqual(viewModel.attempts, 0)
        XCTAssertFalse(viewModel.shouldShowNotificationPrompt)
        XCTAssertFalse(viewModel.isSolved)
    }

    func testDuplicateOrStaleRewardCannotUnlockADifferentHint() {
        let model = DailyPuzzleViewModel(puzzle: makePuzzle())
        XCTAssertFalse(model.unlockNextHint(expectedLevel: 2))
        XCTAssertTrue(model.unlockNextHint(expectedLevel: 1))
        XCTAssertFalse(model.unlockNextHint(expectedLevel: 1))
        XCTAssertEqual(model.unlockedHintCount, 1)
        XCTAssertTrue(model.unlockNextHint(expectedLevel: 2))
        XCTAssertFalse(model.unlockNextHint(expectedLevel: 2))
        XCTAssertEqual(model.unlockedHintCount, 2)
    }

    func testLateRewardDoesNotUnlockHintsAfterPuzzleIsFinished() {
        let model = DailyPuzzleViewModel(puzzle: makePuzzle())
        model.submitGuess("Titanic", notificationStatus: .authorized)
        let hints = model.unlockedHintCount
        model.unlockNextHint()
        XCTAssertEqual(model.unlockedHintCount, hints)
    }

    func testFirstUnsolvedGuessDoesNotCreateAnExtraReminder() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let reminderScheduler = MockDailyPuzzleReminderScheduler()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore,
            reminderScheduler: reminderScheduler
        )

        viewModel.submitGuess("Avatar", notificationStatus: .authorized, now: Date())
        viewModel.submitGuess("Interstellar", notificationStatus: .authorized, now: Date())

        XCTAssertTrue(reminderScheduler.completedDates.isEmpty)
        XCTAssertTrue(reminderScheduler.cancelledPuzzleIDs.isEmpty)
    }

    func testSolvingPuzzleCancelsFallbackReminder() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let reminderScheduler = MockDailyPuzzleReminderScheduler()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore,
            reminderScheduler: reminderScheduler
        )

        viewModel.submitGuess("Avatar", notificationStatus: .authorized, now: Date())
        viewModel.submitGuess("Titanic", notificationStatus: .authorized, now: Date())

        XCTAssertEqual(reminderScheduler.completedDates.count, 1)
        XCTAssertEqual(reminderScheduler.cancelledPuzzleIDs, ["2026-02-15"])
    }

    func testFinishingDailyPuzzleCancelsTodayEvenWhenAllGuessesFail() {
        let scheduler = MockDailyPuzzleReminderScheduler()
        let model = DailyPuzzleViewModel(puzzle: makePuzzle(), reminderScheduler: scheduler)
        let now = Date()
        for index in 0..<DailyPuzzleViewModel.maxAttempts {
            model.submitGuess("Wrong title \(index)", notificationStatus: .authorized, now: now)
        }
        XCTAssertTrue(model.didFail)
        XCTAssertEqual(scheduler.completedDates, [now])
        XCTAssertEqual(scheduler.cancelledPuzzleIDs, ["2026-02-15"])
    }

    func testPracticeCompletionDoesNotSuppressTheDailyReminder() {
        let scheduler = MockDailyPuzzleReminderScheduler()
        let model = DailyPuzzleViewModel(puzzle: makePuzzle(), reminderScheduler: scheduler, recordsDailyStreak: false)
        model.submitGuess("Titanic", notificationStatus: .authorized)
        XCTAssertTrue(model.isSolved)
        XCTAssertTrue(scheduler.completedDates.isEmpty)
    }

    func testFirstUnsolvedGuessDoesNotScheduleFallbackReminderWhenDenied() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let reminderScheduler = MockDailyPuzzleReminderScheduler()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore,
            reminderScheduler: reminderScheduler
        )

        viewModel.submitGuess("Avatar", notificationStatus: .denied, now: Date())

        XCTAssertTrue(reminderScheduler.completedDates.isEmpty)
        XCTAssertTrue(reminderScheduler.cancelledPuzzleIDs.isEmpty)
    }

    func testCardStatusTextUsesDayBasedStreakFormat() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore
        )
        viewModel.isSolved = true

        let streakCases = [
            (2, "2-day Streak! 🔥"),
            (7, "7-day Streak! 🔥"),
            (30, "30-day Streak! 🔥")
        ]

        for (streak, expected) in streakCases {
            UserDefaults.standard.set(streak, forKey: currentStreakKey)
            XCTAssertEqual(viewModel.cardStatusText, expected)
        }
    }

    func testShareResultTextContainsPuzzleAndAttemptsWithoutTitleLeak() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore
        )

        XCTAssertNil(viewModel.shareResultText)
        viewModel.submitGuess("Titanic", notificationStatus: .authorized, now: Date())

        guard let shareResultText = viewModel.shareResultText else {
            XCTFail("Expected share text when puzzle is solved")
            return
        }
        XCTAssertTrue(shareResultText.contains("Daily Movie Puzzle"))
        XCTAssertTrue(shareResultText.contains("1/6"))
        XCTAssertTrue(shareResultText.contains("apps.apple.com"))
        // Emoji clue should NOT be in share text (spoiler-free)
        XCTAssertFalse(shareResultText.contains("🚢"))
        XCTAssertFalse(shareResultText.localizedCaseInsensitiveContains("Titanic"))
    }

    func testVisibilityAndAbandonmentAreOncePerPresentation() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker)
        vm.trackOpened(source: "push_notification")
        vm.trackDismissed()
        XCTAssertFalse(tracker.events.contains { $0.name == "daily_puzzle_abandoned" })
        XCTAssertFalse(tracker.events.contains { $0.name == "daily_puzzle_screen_visible" })
        vm.trackScreenVisible()
        vm.trackScreenVisible()
        vm.trackFirstInput()
        vm.trackFirstInput()
        vm.trackDismissed()
        vm.trackDismissed()
        let visible = tracker.events.filter { $0.name == "daily_puzzle_screen_visible" }
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.metadata["source"], "push_notification")
        XCTAssertEqual(tracker.events.filter { $0.name == "daily_puzzle_first_input" }.count, 1)
        let abandoned = tracker.events.filter { $0.name == "daily_puzzle_abandoned" }
        XCTAssertEqual(abandoned.count, 1)
        XCTAssertEqual(abandoned.first?.metadata["had_input"], "true")
        XCTAssertEqual(abandoned.first?.metadata["presentation_id"], visible.first?.metadata["presentation_id"])
        vm.trackScreenVisible()
        vm.trackDismissed()
        let presentations = tracker.events.filter { $0.name == "daily_puzzle_screen_visible" }
        XCTAssertNotEqual(presentations.first?.metadata["presentation_id"], presentations.last?.metadata["presentation_id"])
    }

    func testSolvedPuzzleDismissalIsNotAbandonment() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker)
        vm.trackScreenVisible()
        vm.submitGuess("Titanic", notificationStatus: .authorized)
        vm.trackDismissed()
        XCTAssertFalse(tracker.events.contains { $0.name == "daily_puzzle_abandoned" })
    }

    func testFirstGuessRecordsInputWithoutItsContents() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker)
        vm.submitGuess("private guess", notificationStatus: .authorized)
        vm.submitGuess("another guess", notificationStatus: .authorized)
        let events = tracker.events.filter { $0.name == "daily_puzzle_first_input" }
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(events.description.contains("private guess"))
    }

    func testSubmitGuessTracksGuessAndSolvedEvents() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore,
            analyticsTracker: tracker
        )

        viewModel.submitGuess("Titanic", notificationStatus: .authorized, now: Date())

        XCTAssertTrue(
            tracker.events.contains(where: { $0.name == "daily_puzzle_guess_submitted" })
        )
        XCTAssertTrue(
            tracker.events.contains(where: { $0.name == "daily_puzzle_solved" })
        )
    }

    func testFailedPuzzleTracksTerminalEventOnce() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            analyticsTracker: tracker,
            puzzleIndex: 3
        )

        for _ in 0..<DailyPuzzleViewModel.maxAttempts {
            viewModel.submitGuess("Avatar", notificationStatus: .authorized, now: Date())
        }
        viewModel.submitGuess("Avatar", notificationStatus: .authorized, now: Date())

        let failures = tracker.events.filter { $0.name == "daily_puzzle_failed" }
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(failures.first?.metadata["puzzle_index"], "3")
        XCTAssertEqual(failures.first?.metadata["terminal_result"], "failed")
    }

    func testPuzzleAdOpportunityIncludesSessionDepth() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            analyticsTracker: tracker,
            recordsDailyStreak: false,
            puzzleIndex: 4
        )

        viewModel.trackAdOpportunity(placement: "native_puzzle")

        let opportunity = tracker.events.first { $0.name == "daily_puzzle_ad_opportunity" }
        XCTAssertEqual(opportunity?.metadata["placement"], "native_puzzle")
        XCTAssertEqual(opportunity?.metadata["puzzle_index"], "4")
        XCTAssertEqual(opportunity?.metadata["terminal_result"], "in_progress")
    }

    func testSecondWrongGuessTracksHintUnlockedEvent() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore,
            analyticsTracker: tracker
        )

        viewModel.submitGuess("Avatar", notificationStatus: .authorized, now: Date())
        viewModel.submitGuess("Interstellar", notificationStatus: .authorized, now: Date())

        XCTAssertEqual(viewModel.unlockedHintCount, 1)
        XCTAssertTrue(
            tracker.events.contains(where: {
                $0.name == "daily_puzzle_hint_unlocked" && $0.metadata["hint_level"] == "1"
            })
        )
    }

    func testContinuationCanStartFreshWithoutReopeningAnOldSolvedResult() {
        let original = DailyPuzzleViewModel(puzzle: makePuzzle())
        original.submitGuess("Titanic", notificationStatus: .authorized)
        XCTAssertTrue(DailyPuzzleViewModel(puzzle: makePuzzle()).isSolved)
        let next = DailyPuzzleViewModel(puzzle: makePuzzle(), recordsDailyStreak: false, restoresProgress: false)
        XCTAssertFalse(next.isSolved)
        XCTAssertEqual(next.attempts, 0)
    }

    func testMovieQuizEliminatesOnceAndRestoresProgress() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker)
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        let round = MovieQuizRound(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil)
        vm.prepareMovieQuiz(round)
        vm.chooseMovie(603, notificationStatus: .authorized)
        vm.chooseMovie(603, notificationStatus: .authorized)
        vm.chooseMovie(9999, notificationStatus: .authorized)
        XCTAssertEqual(vm.attempts, 1)
        XCTAssertTrue(vm.quizState?.hintRevealed == true)
        let restored = DailyPuzzleViewModel(puzzle: makePuzzle())
        XCTAssertEqual(restored.quizState?.eliminatedIDs, [603])
        restored.chooseMovie(answer.id, notificationStatus: .authorized)
        XCTAssertTrue(restored.isSolved)
        XCTAssertEqual(restored.quizPoints, 2)
        restored.chooseMovie(answer.id, notificationStatus: .authorized)
        XCTAssertEqual(restored.attempts, 2)
    }

    func testMovieQuizTilesPersistAndOnlyTrackValidReveals() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker)
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        vm.prepareMovieQuiz(.init(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil))
        XCTAssertEqual(vm.quizState?.visibleTileIndices, [4])
        for index in [0, 1, 2, 2, -1, 9] { vm.revealMovieQuizTile(index) }
        XCTAssertEqual(vm.quizState?.availablePoints, 2)
        let events = tracker.events.filter { $0.name == "movie_quiz_tile_revealed" }
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.last?.metadata["revealed_tile_count"], "4")
        let restored = DailyPuzzleViewModel(puzzle: makePuzzle())
        XCTAssertEqual(restored.quizState?.visibleTileIndices, [0, 1, 2, 4])
        restored.chooseMovie(answer.id, notificationStatus: .authorized)
        XCTAssertEqual(restored.quizPoints, 2)
        restored.revealMovieQuizTile(3)
        restored.handleMovieQuizImageUnavailable()
        XCTAssertEqual(restored.quizPoints, 2)
        XCTAssertEqual(restored.quizState?.visibleTileIndices, [0, 1, 2, 4])
    }

    func testSecondMovieQuizRoundZoomPersistsAndOnlyTracksValidReveals() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker, puzzleIndex: 2)
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        let round = MovieQuizRound(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil)
        vm.prepareMovieQuiz(round)
        XCTAssertEqual(vm.quizState?.zoomStep, 0)
        XCTAssertNil(vm.quizState?.revealedTiles)
        vm.zoomOutMovieQuiz()
        XCTAssertEqual(vm.quizState?.availablePoints, 2)
        let restored = DailyPuzzleViewModel(puzzle: makePuzzle(), puzzleIndex: 1)
        restored.prepareMovieQuiz(round)
        XCTAssertEqual(restored.quizState?.zoomStep, 1, "Restored mode and reveal progress survive a different entry point")
        vm.zoomOutMovieQuiz()
        vm.zoomOutMovieQuiz()
        XCTAssertEqual(vm.quizState?.zoomStep, 2)
        let events = tracker.events.filter { $0.name == "movie_quiz_zoomed_out" }
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.last?.metadata["zoom_step"], "2")
        XCTAssertEqual(events.last?.metadata["available_points"], "1")
        vm.chooseMovie(answer.id, notificationStatus: .authorized)
        vm.zoomOutMovieQuiz()
        vm.handleMovieQuizImageUnavailable()
        XCTAssertEqual(vm.quizPoints, 1)
        XCTAssertEqual(vm.quizState?.zoomStep, 2)
        XCTAssertEqual(tracker.events.filter { $0.name == "movie_quiz_zoomed_out" }.count, 2)
    }

    func testFourthMovieQuizRoundUsesZoomReveal() {
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), restoresProgress: false, puzzleIndex: 4)
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        vm.prepareMovieQuiz(.init(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil))
        XCTAssertEqual(vm.quizState?.zoomStep, 0)
        XCTAssertNil(vm.quizState?.revealedTiles)
        vm.zoomOutMovieQuiz()
        XCTAssertEqual(vm.quizState?.zoomStep, 1)
        XCTAssertEqual(vm.quizState?.availablePoints, 2)
    }

    func testNextRunOpeningMovieQuizReturnsToTiles() {
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), restoresProgress: false, puzzleIndex: 5)
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        vm.prepareMovieQuiz(.init(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil))
        XCTAssertNil(vm.quizState?.zoomStep)
        XCTAssertEqual(vm.quizState?.visibleTileIndices, [4])
    }

    func testSecondRoundPreservesExistingTileGame() {
        let first = DailyPuzzleViewModel(puzzle: makePuzzle())
        let answer = MovieQuizChoice(id: first.puzzle.tmdbID, title: "Titanic")
        let round = MovieQuizRound(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil)
        first.prepareMovieQuiz(round)
        first.revealMovieQuizTile(0)
        let restored = DailyPuzzleViewModel(puzzle: makePuzzle(), puzzleIndex: 2)
        restored.prepareMovieQuiz(round)
        restored.zoomOutMovieQuiz()
        XCTAssertNil(restored.quizState?.zoomStep)
        XCTAssertEqual(restored.quizState?.revealedTiles, [0, 4])
    }

    func testUnavailableZoomImageRemovesZoomAndRestoresFreeClue() {
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), puzzleIndex: 2)
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        vm.prepareMovieQuiz(.init(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil))
        vm.zoomOutMovieQuiz()
        vm.handleMovieQuizImageUnavailable()
        vm.zoomOutMovieQuiz()
        XCTAssertNil(vm.quizState?.zoomStep)
        XCTAssertEqual(vm.quizState?.availablePoints, 3)
        XCTAssertTrue(vm.quizState?.hintRevealed == true)
        let restored = DailyPuzzleViewModel(puzzle: makePuzzle(), puzzleIndex: 2)
        XCTAssertNil(restored.quizState?.zoomStep)
        XCTAssertTrue(restored.quizState?.imageUnavailable == true)
    }

    func testUnavailableQuizImageRevealsFreeClueAndPersistsFallback() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker)
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        vm.prepareMovieQuiz(.init(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil))
        vm.handleMovieQuizImageUnavailable()
        vm.handleMovieQuizImageUnavailable()
        XCTAssertEqual(vm.quizState?.visibleTileIndices.count, 9)
        XCTAssertTrue(vm.quizState?.hintRevealed == true)
        XCTAssertFalse(vm.quizState?.requestedHint == true)
        XCTAssertEqual(vm.unlockedHintCount, 1)
        XCTAssertEqual(tracker.events.filter { $0.name == "movie_quiz_hint_revealed" }.count, 1)
        let restored = DailyPuzzleViewModel(puzzle: makePuzzle())
        XCTAssertTrue(restored.quizState?.imageUnavailable == true)
        restored.chooseMovie(answer.id, notificationStatus: .authorized)
        XCTAssertEqual(restored.quizPoints, 3)
    }

    func testUnavailableQuizImageStillAwardsOnePointAfterThreeWrongChoices() {
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle())
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        let wrongChoices = [MovieQuizChoice(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")]
        vm.prepareMovieQuiz(.init(answerID: answer.id, choices: [answer] + wrongChoices, backdropPath: nil, posterPath: nil))
        vm.handleMovieQuizImageUnavailable()
        for choice in wrongChoices { vm.chooseMovie(choice.id, notificationStatus: .authorized) }
        vm.chooseMovie(answer.id, notificationStatus: .authorized)
        XCTAssertTrue(vm.isSolved)
        XCTAssertEqual(vm.quizPoints, 1)
        let restored = DailyPuzzleViewModel(puzzle: makePuzzle())
        XCTAssertTrue(restored.isSolved)
        XCTAssertEqual(restored.quizPoints, 1)
        XCTAssertTrue(restored.quizState?.imageUnavailable == true)
    }

    func testArchiveStarsRespectRevealPenaltyAndPreserveLegacyScores() {
        let puzzle = makePuzzle()
        let store = DailyPuzzleProgressStore()
        let answer = MovieQuizChoice(id: puzzle.tmdbID, title: "Titanic")
        let round = MovieQuizRound(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil)
        var quiz = MovieQuizState(round: round)
        quiz.enableTileReveal()
        for index in 0..<9 { quiz.revealTile(index) }
        quiz.choose(answer.id)
        let archive = PuzzleArchiveViewModel(puzzles: [puzzle], progressStore: store)
        store.save(.init(puzzleID: puzzle.puzzleID, solved: true, attempts: 1, unlockedHintCount: 0, solvedAt: Date(), quizState: quiz))
        XCTAssertEqual(archive.totalStars, 1, "A full reveal must not earn three archive stars")
        store.save(.init(puzzleID: puzzle.puzzleID, solved: true, attempts: 1, unlockedHintCount: 0, solvedAt: Date()))
        XCTAssertEqual(archive.totalStars, 3, "Pre-quiz completion scores stay intact")
        var imported = MovieQuizState(round: round)
        imported.restoreLegacyCompletion(solved: true)
        store.save(.init(puzzleID: puzzle.puzzleID, solved: true, attempts: 1, unlockedHintCount: 0, solvedAt: Date(), quizState: imported))
        XCTAssertEqual(archive.totalStars, 3, "Opening a legacy completion must not erase archive stars")
    }

    func testMovieQuizSkipPersistsTerminalStateWithoutSolveCredit() {
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle())
        let answer = MovieQuizChoice(id: vm.puzzle.tmdbID, title: "Titanic")
        vm.prepareMovieQuiz(.init(answerID: answer.id, choices: [answer, .init(id: 603, title: "The Matrix"), .init(id: 329, title: "Jurassic Park"), .init(id: 27205, title: "Inception")], backdropPath: nil, posterPath: nil))
        vm.skipMovieQuiz()
        XCTAssertTrue(vm.didFail)
        XCTAssertFalse(vm.isSolved)
        XCTAssertEqual(vm.quizPoints, 0)
        let restored = DailyPuzzleViewModel(puzzle: makePuzzle())
        XCTAssertTrue(restored.didFail)
        restored.chooseMovie(answer.id, notificationStatus: .authorized)
        XCTAssertFalse(restored.isSolved)
    }

    func testSolvingDoesNotClaimReminderOfferWasVisible() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker)
        vm.submitGuess("Titanic", notificationStatus: .notDetermined)
        XCTAssertFalse(tracker.events.contains { $0.name == "daily_puzzle_prompt_shown" })
    }

    func testReminderOfferSurvivesEarlierDeclineButExcludesPractice() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        promptStore.markSeen(granted: false)
        let daily = DailyPuzzleViewModel(puzzle: makePuzzle(), promptStore: promptStore)
        XCTAssertFalse(daily.offersDailyReminder)
        daily.submitGuess("Titanic", notificationStatus: .denied)
        XCTAssertTrue(daily.offersDailyReminder)

        let tracker = MockDailyPuzzleAnalyticsTracker()
        let practice = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker, recordsDailyStreak: false)
        practice.submitGuess("Titanic", notificationStatus: .notDetermined)
        XCTAssertFalse(practice.offersDailyReminder)
        practice.trackReminderOfferVisible()
        XCTAssertFalse(tracker.events.contains { $0.name == "daily_puzzle_prompt_shown" })
    }

    func testReminderChoiceIsSeparateFromConfirmedOutcome() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let vm = DailyPuzzleViewModel(puzzle: makePuzzle(), analyticsTracker: tracker)
        vm.trackReminderChoice("open_settings")
        XCTAssertFalse(tracker.events.contains { $0.name == "daily_puzzle_notification_outcome" })
        vm.trackReminderOutcome("denied")
        XCTAssertEqual(tracker.events.last?.metadata["outcome"], "denied")
    }

    func testPromptShownAndHandledTracksEvents() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore,
            analyticsTracker: tracker
        )

        // Prompt now fires post-solve, so solve the puzzle first
        viewModel.submitGuess("Titanic", notificationStatus: .notDetermined, now: Date())
        viewModel.trackReminderOfferVisible()
        viewModel.trackReminderOfferVisible()
        viewModel.markNotificationPromptHandled(granted: true)

        XCTAssertEqual(tracker.events.filter { $0.name == "daily_puzzle_prompt_shown" }.count, 1)
        XCTAssertTrue(
            tracker.events.contains(where: { $0.name == "daily_puzzle_prompt_shown" })
        )
        XCTAssertTrue(
            tracker.events.contains(where: {
                $0.name == "daily_puzzle_prompt_response" && $0.metadata["granted"] == "true"
            })
        )
    }

    func testNextPuzzleLoadOutcomeEventsIncludeSessionContext() {
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            analyticsTracker: tracker,
            recordsDailyStreak: false
        )

        viewModel.trackNextPuzzleLoaded(previousPuzzleID: "previous", puzzleIndex: 3)
        viewModel.trackNextPuzzleLoadFailed(reason: "network")

        let loaded = tracker.events.first(where: { $0.name == "daily_puzzle_next_loaded" })
        XCTAssertEqual(loaded?.metadata["previous_puzzle_id"], "previous")
        XCTAssertEqual(loaded?.metadata["puzzle_index"], "3")
        let failed = tracker.events.first(where: { $0.name == "daily_puzzle_next_load_failed" })
        XCTAssertEqual(failed?.metadata["reason"], "network")
    }

    func testTrackOpenedAndShareTappedEvents() {
        let promptStore = DailyPuzzlePromptStore(userDefaults: .standard)
        let streakStore = DailyPuzzleStreakStore(userDefaults: .standard)
        let tracker = MockDailyPuzzleAnalyticsTracker()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            streakStore: streakStore,
            promptStore: promptStore,
            analyticsTracker: tracker
        )

        viewModel.trackOpened(source: "home_card")
        viewModel.trackShareTapped()
        viewModel.trackNextPuzzleTapped(source: "modal")

        XCTAssertTrue(
            tracker.events.contains(where: {
                $0.name == "daily_puzzle_opened" && $0.metadata["source"] == "home_card"
            })
        )
        XCTAssertTrue(
            tracker.events.contains(where: { $0.name == "daily_puzzle_share_tapped" })
        )
        XCTAssertTrue(
            tracker.events.contains(where: {
                $0.name == "daily_puzzle_next_tapped" && $0.metadata["source"] == "modal"
            })
        )
    }

    private func makePuzzle() -> DailyPuzzle {
        DailyPuzzle(
            date: "2026-02-15",
            puzzleID: "2026-02-15",
            mediaType: .movie,
            tmdbID: 597,
            title: "Titanic",
            emojiClue: "🚢🧊❤️",
            hint1: "Released in 1997",
            hint2: "Directed by James Cameron",
            acceptedAnswers: ["titanic"],
            source: "ai+tmdb",
            generatedAt: "2026-02-15T05:00:00.000Z"
        )
    }

    private func makeHistoricalPuzzle() -> DailyPuzzle {
        DailyPuzzle(
            date: "2026-01-20",
            puzzleID: "2026-01-20",
            mediaType: .movie,
            tmdbID: 597,
            title: "Titanic",
            emojiClue: "🚢🧊❤️",
            hint1: "Released in 1997",
            hint2: "Directed by James Cameron",
            acceptedAnswers: ["titanic"],
            source: "archive",
            generatedAt: "2026-01-20T05:00:00.000Z"
        )
    }

    private final class MockDailyPuzzleAnalyticsTracker: DailyPuzzleAnalyticsTracking {
        var events = [DailyPuzzleAnalyticsEvent]()

        func track(event: DailyPuzzleAnalyticsEvent) {
            events.append(event)
        }
    }

    private final class MockDailyPuzzleReminderScheduler: DailyPuzzleReminderScheduling {
        var cancelledPuzzleIDs = [String]()
        var completedDates = [Date]()
        func completeDailyPuzzle(at date: Date) { completedDates.append(date) }
        func cancelDailyPuzzleFallbackReminder(for puzzleID: String) {
            cancelledPuzzleIDs.append(puzzleID)
        }
    }

    private func waitForCondition(
        timeout: TimeInterval,
        pollIntervalNanoseconds: UInt64 = 10_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        XCTFail("Timed out waiting for condition")
    }
}

final class DailyPuzzleLaunchIntentStoreTests: XCTestCase {
    private let launchIntentKey = "dailyPuzzleShouldOpenFromPush"
    private let launchIntentSourceKey = "dailyPuzzleOpenSource"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: launchIntentKey)
        UserDefaults.standard.removeObject(forKey: launchIntentSourceKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: launchIntentKey)
        UserDefaults.standard.removeObject(forKey: launchIntentSourceKey)
        super.tearDown()
    }

    func testDailyPuzzleTypeIsRecognizedFromPushPayload() {
        XCTAssertTrue(
            DailyPuzzleLaunchIntentStore.shouldOpenFromNotification(
                userInfo: ["type": "daily_puzzle"]
            )
        )
        XCTAssertFalse(
            DailyPuzzleLaunchIntentStore.shouldOpenFromNotification(
                userInfo: ["type": "content_release"]
            )
        )
    }

    func testRequestOpenPersistsAndConsumeClearsFlag() {
        DailyPuzzleLaunchIntentStore.requestOpen(userDefaults: .standard)
        XCTAssertTrue(DailyPuzzleLaunchIntentStore.consumeOpenRequest(userDefaults: .standard))
        XCTAssertFalse(DailyPuzzleLaunchIntentStore.consumeOpenRequest(userDefaults: .standard))
    }

    func testRequestOpenSourceIsPersistedAndConsumed() {
        DailyPuzzleLaunchIntentStore.requestOpen(source: "notification_settings", userDefaults: .standard)
        XCTAssertEqual(
            DailyPuzzleLaunchIntentStore.consumeOpenRequestSource(userDefaults: .standard),
            "notification_settings"
        )
        XCTAssertNil(DailyPuzzleLaunchIntentStore.consumeOpenRequestSource(userDefaults: .standard))
    }
}

final class AppDeepLinkRouterTests: XCTestCase {
    func testDailyPuzzleRouteIsRecognized() throws {
        let url = try XCTUnwrap(URL(string: "qscanlite://daily-puzzle"))

        XCTAssertEqual(AppDeepLinkRouter.destination(for: url), .dailyPuzzle)
    }

    func testDailyPuzzleRouteAllowsTrackingQuery() throws {
        let url = try XCTUnwrap(URL(string: "qscanlite://daily-puzzle?source=app-store"))

        XCTAssertEqual(AppDeepLinkRouter.destination(for: url), .dailyPuzzle)
    }

    func testLegacyContentRouteIsPreserved() throws {
        let url = try XCTUnwrap(URL(string: "qscanlite://12345"))

        XCTAssertEqual(AppDeepLinkRouter.destination(for: url), .content("12345"))
    }

    func testExternalURLFallsBackToExistingContentLookup() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/content/12345"))

        XCTAssertEqual(
            AppDeepLinkRouter.destination(for: url),
            .content("https://example.com/content/12345")
        )
    }
}

#if os(iOS)
@MainActor
final class NotificationDelegateTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "NotificationDelegateTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testHandleNotificationTapRequestsDailyPuzzleOpenAndPostsNotification() {
        let delegate = NotificationDelegate()
        let openRequested = expectation(forNotification: .dailyPuzzleOpenRequested, object: nil)

        delegate.handleNotificationTap(userInfo: ["type": "daily_puzzle"], userDefaults: testDefaults)

        wait(for: [openRequested], timeout: 0.2)
        XCTAssertEqual(
            DailyPuzzleLaunchIntentStore.consumeOpenRequestSource(userDefaults: testDefaults),
            "push_notification"
        )
    }

    func testLocalReminderTapKeepsItsSourceAndOpensTheCurrentPuzzle() {
        let delegate = NotificationDelegate()
        delegate.handleNotificationTap(
            userInfo: ["type": "daily_puzzle", "source": "local_reminder"],
            userDefaults: testDefaults
        )
        XCTAssertEqual(DailyPuzzleLaunchIntentStore.consumeOpenRequestSource(userDefaults: testDefaults), "local_reminder")
    }

    func testHandleNotificationTapIgnoresNonDailyPuzzleNotifications() {
        let delegate = NotificationDelegate()

        delegate.handleNotificationTap(userInfo: ["type": "content_release"], userDefaults: testDefaults)

        XCTAssertNil(DailyPuzzleLaunchIntentStore.consumeOpenRequestSource(userDefaults: testDefaults))
    }

    func testHandleNotificationTapStoresContentIDForContentNotifications() {
        let delegate = NotificationDelegate()

        delegate.handleNotificationTap(
            userInfo: [
                "type": "content_release",
                "contentID": "123@0",
            ],
            userDefaults: testDefaults
        )

        XCTAssertEqual(delegate.notificationID, "123@0")
        XCTAssertNil(DailyPuzzleLaunchIntentStore.consumeOpenRequestSource(userDefaults: testDefaults))
    }
}
#endif

final class DailyPuzzleServiceTests: XCTestCase {
    private let developerModeKey = "displayDeveloperSettings"

    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

#if os(iOS)
    @MainActor
    func testHorizontalUpNextListViewRendersWithInMemoryContext() {
        let persistence = PersistenceController(inMemory: true, useCloudKit: false)
        let view = HorizontalUpNextListView(shouldReload: .constant(false))
            .environment(\.managedObjectContext, persistence.container.viewContext)
        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        let expectation = expectation(description: "SwiftUI view rendered")
        DispatchQueue.main.async {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(hostingController.view)
    }
#endif

    func testFetchLatestPuzzleReturnsSampleWhenURLIsNil() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(false, forKey: developerModeKey)
        let service = DailyPuzzleService(
            session: .shared,
            latestPuzzleURL: nil,
            userDefaults: defaults,
            isDebugBuild: true
        )
        let puzzle = try await service.fetchLatestPuzzle()
        XCTAssertEqual(puzzle, .sample)
    }

    func testFetchLatestPuzzleUsesRemoteRandomInDeveloperMode() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(true, forKey: developerModeKey)
        let randomURL = URL(string: "https://example.com/getRandomDailyPuzzle")!

        var capturedURLs = [URL]()
        let session = makeStubbedSession(statusCode: 200, data: makePuzzleJSON(puzzleID: "remote-random-1")) { request in
            if let url = request.url {
                capturedURLs.append(url)
            }
        }
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: URL(string: "https://example.com/getLatestDailyPuzzle")!,
            randomPuzzleURL: randomURL,
            userDefaults: defaults,
            isDebugBuild: true
        )

        let puzzle = try await service.fetchLatestPuzzle()

        XCTAssertEqual(puzzle.puzzleID, "remote-random-1")
        XCTAssertEqual(capturedURLs, [randomURL])
    }

    func testPuzzleForModalOpenRetriesRemoteRandomUntilPuzzleChangesInDeveloperMode() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(true, forKey: developerModeKey)
        let randomURL = URL(string: "https://example.com/getRandomDailyPuzzle")!

        let firstResponse = makePuzzleJSON(puzzleID: "same-puzzle")
        let secondResponse = makePuzzleJSON(puzzleID: "different-puzzle")
        var responses = [firstResponse, secondResponse, secondResponse]
        var requestCount = 0
        let session = makeStubbedSession { _ in
            requestCount += 1
            let nextData = responses.isEmpty ? secondResponse : responses.removeFirst()
            return (200, nextData)
        }
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: URL(string: "https://example.com/getLatestDailyPuzzle")!,
            randomPuzzleURL: randomURL,
            userDefaults: defaults,
            isDebugBuild: true
        )

        let puzzle = try await service.puzzleForModalOpen(currentPuzzleID: "same-puzzle")

        XCTAssertEqual(puzzle.puzzleID, "different-puzzle")
        XCTAssertGreaterThanOrEqual(requestCount, 2)
    }

    func testNextQuizExcludesBothEarlierPuzzleIDsAndRepeatedMovies() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        let randomURL = URL(string: "https://example.com/random")!
        var responses = [
            makePuzzleJSON(puzzleID: "seen"),
            Data(String(decoding: makePuzzleJSON(puzzleID: "different-date"), as: UTF8.self).replacingOccurrences(of: "\"tmdb_id\":1", with: "\"tmdb_id\":2").utf8),
            Data(String(decoding: makePuzzleJSON(puzzleID: "fresh"), as: UTF8.self).replacingOccurrences(of: "\"tmdb_id\":1", with: "\"tmdb_id\":3").utf8)
        ]
        let session = makeStubbedSession { _ in (200, responses.removeFirst()) }
        let service = DailyPuzzleService(session: session, latestPuzzleURL: randomURL, randomPuzzleURL: randomURL, userDefaults: defaults, isDebugBuild: false)
        let result = try await service.fetchNextPuzzle(excluding: "current", excludingIDs: ["seen"], excludingMovieIDs: [2])
        XCTAssertEqual(result.puzzleID, "fresh")
        XCTAssertEqual(result.tmdbID, 3)
        XCTAssertTrue(responses.isEmpty)
    }

    func testFetchNextPuzzleUsesRandomEndpointOutsideDeveloperModeAndSkipsCurrent() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(false, forKey: developerModeKey)
        let randomURL = URL(string: "https://example.com/getRandomDailyPuzzle")!
        let firstResponse = makePuzzleJSON(puzzleID: "current-puzzle")
        let secondResponse = makePuzzleJSON(puzzleID: "next-puzzle")
        var responses = [firstResponse, secondResponse]
        var requestedURLs = [URL]()
        let session = makeStubbedSession { request in
            if let url = request.url {
                requestedURLs.append(url)
            }
            return (200, responses.removeFirst())
        }
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: URL(string: "https://example.com/getLatestDailyPuzzle")!,
            randomPuzzleURL: randomURL,
            userDefaults: defaults,
            isDebugBuild: false
        )

        let puzzle = try await service.fetchNextPuzzle(excluding: "current-puzzle")

        XCTAssertEqual(puzzle.puzzleID, "next-puzzle")
        XCTAssertEqual(requestedURLs, [randomURL, randomURL])
    }

    @MainActor
    func testModalOpenLoaderRefreshesPuzzleEvenWhenCurrentPuzzleExists() async {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(false, forKey: developerModeKey)
        let latestURL = URL(string: "https://example.com/getLatestDailyPuzzle")!

        let session = makeStubbedSession(
            statusCode: 200,
            data: makePuzzleJSON(puzzleID: "fresh-from-server")
        )
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: latestURL,
            randomPuzzleURL: nil,
            userDefaults: defaults,
            isDebugBuild: true
        )

        let viewModel = await DailyPuzzleModalOpenLoader.refreshViewModelForOpen(
            currentPuzzleID: "stale-local",
            service: service
        )

        XCTAssertEqual(viewModel.puzzle.puzzleID, "fresh-from-server")
    }

    func testFetchLatestPuzzleFallsBackToLatestWhenRandomEndpointFailsInDeveloperMode() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(true, forKey: developerModeKey)
        let randomURL = URL(string: "https://example.com/getRandomDailyPuzzle")!
        let latestURL = URL(string: "https://example.com/getLatestDailyPuzzle")!

        let session = makeStubbedSession { request in
            guard let url = request.url else {
                return (statusCode: 500, data: Data())
            }
            if url == randomURL {
                return (statusCode: 503, data: Data())
            }
            if url == latestURL {
                return (statusCode: 200, data: self.makePuzzleJSON(puzzleID: "latest-fallback"))
            }
            return (statusCode: 404, data: Data())
        }
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: latestURL,
            randomPuzzleURL: randomURL,
            userDefaults: defaults,
            isDebugBuild: true
        )

        let puzzle = try await service.fetchLatestPuzzle()
        XCTAssertEqual(puzzle.puzzleID, "latest-fallback")
    }

    func testFetchLatestPuzzleUsesLatestEndpointWhenDeveloperModeDisabled() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(false, forKey: developerModeKey)
        let randomURL = URL(string: "https://example.com/getRandomDailyPuzzle")!
        let latestURL = URL(string: "https://example.com/getLatestDailyPuzzle")!
        var requestedURLs = [URL]()
        let session = makeStubbedSession { request in
            if let url = request.url {
                requestedURLs.append(url)
            }
            return (statusCode: 200, data: self.makePuzzleJSON(puzzleID: "latest-only"))
        }

        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: latestURL,
            randomPuzzleURL: randomURL,
            userDefaults: defaults,
            isDebugBuild: true
        )

        let puzzle = try await service.fetchLatestPuzzle()
        XCTAssertEqual(puzzle.puzzleID, "latest-only")
        XCTAssertEqual(requestedURLs, [latestURL])
    }

    func testFetchLatestPuzzleFallsBackToFirestoreLatestWhenFunctionEndpointFails() async throws {
        let latestURL = URL(string: "https://example.com/getLatestDailyPuzzle")!
        let firestoreLatestURL = URL(string: "https://firestore.googleapis.com/v1/projects/demo/databases/(default)/documents/dailyPuzzles/latest?key=test")!

        let session = makeStubbedSession { request in
            guard let url = request.url else {
                return (statusCode: 500, data: Data())
            }
            if url == latestURL {
                return (statusCode: 404, data: "<html>not found</html>".data(using: .utf8) ?? Data())
            }
            if url == firestoreLatestURL {
                return (statusCode: 200, data: self.makeFirestoreDocumentJSON(puzzleID: "firestore-latest"))
            }
            return (statusCode: 404, data: Data())
        }

        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: latestURL,
            randomPuzzleURL: nil,
            firestoreLatestDocumentURL: firestoreLatestURL,
            firestoreCollectionURL: nil
        )

        let puzzle = try await service.fetchLatestPuzzle()
        XCTAssertEqual(puzzle.puzzleID, "firestore-latest")
        XCTAssertEqual(puzzle.emojiClue, "🛸🌌🔍")
    }

    func testFetchLatestPuzzlePrefersFirestoreWhenEnabled() async throws {
        let latestURL = URL(string: "https://example.com/getLatestDailyPuzzle")!
        let firestoreLatestURL = URL(string: "https://firestore.googleapis.com/v1/projects/demo/databases/(default)/documents/dailyPuzzles/latest?key=test")!
        var requestedURLs = [URL]()

        let session = makeStubbedSession { request in
            if let url = request.url {
                requestedURLs.append(url)
            }
            guard let url = request.url else {
                return (statusCode: 500, data: Data())
            }
            if url == firestoreLatestURL {
                return (statusCode: 200, data: self.makeFirestoreDocumentJSON(puzzleID: "firestore-primary"))
            }
            if url == latestURL {
                return (statusCode: 200, data: self.makePuzzleJSON(puzzleID: "function-primary"))
            }
            return (statusCode: 404, data: Data())
        }

        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: latestURL,
            randomPuzzleURL: nil,
            firestoreLatestDocumentURL: firestoreLatestURL,
            firestoreCollectionURL: nil,
            preferFirestorePrimary: true
        )

        let puzzle = try await service.fetchLatestPuzzle()

        XCTAssertEqual(puzzle.puzzleID, "firestore-primary")
        XCTAssertEqual(requestedURLs, [firestoreLatestURL])
    }

    func testFetchLatestPuzzleFallsBackToFirestoreRandomInDeveloperMode() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(true, forKey: developerModeKey)
        let randomURL = URL(string: "https://example.com/getRandomDailyPuzzle")!
        let latestURL = URL(string: "https://example.com/getLatestDailyPuzzle")!
        let firestoreCollectionURL = URL(string: "https://firestore.googleapis.com/v1/projects/demo/databases/(default)/documents/dailyPuzzles?key=test")!

        let session = makeStubbedSession { request in
            guard let url = request.url else {
                return (statusCode: 500, data: Data())
            }
            if url == randomURL || url == latestURL {
                return (statusCode: 503, data: Data())
            }
            if url == firestoreCollectionURL {
                return (statusCode: 200, data: self.makeFirestoreCollectionJSON(puzzleID: "firestore-random"))
            }
            return (statusCode: 404, data: Data())
        }

        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: latestURL,
            randomPuzzleURL: randomURL,
            firestoreLatestDocumentURL: nil,
            firestoreCollectionURL: firestoreCollectionURL,
            userDefaults: defaults,
            isDebugBuild: true,
            randomUnitValue: { 0.0 }
        )

        let puzzle = try await service.fetchLatestPuzzle()
        XCTAssertEqual(puzzle.puzzleID, "firestore-random")
    }

    func testFetchLatestPuzzleDecodesResponsePayload() async throws {
        let session = makeStubbedSession(
            statusCode: 200,
            data: """
            {
              "date":"2026-02-15",
              "puzzle_id":"2026-02-15",
              "media_type":"movie",
              "tmdb_id":597,
              "title":"Titanic",
              "emoji_clue":"🚢🧊❤️",
              "hint_1":"Released in 1997",
              "hint_2":"Directed by James Cameron",
              "accepted_answers":["titanic"],
              "source":"ai+tmdb",
              "generated_at":"2026-02-15T05:00:00.000Z"
            }
            """.data(using: .utf8)!
        )
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: URL(string: "https://example.com/daily-puzzle")!
        )

        let puzzle = try await service.fetchLatestPuzzle()

        XCTAssertEqual(puzzle.puzzleID, "2026-02-15")
        XCTAssertEqual(puzzle.emojiClue, "🚢🧊❤️")
        XCTAssertEqual(puzzle.hint1, "Released in 1997")
    }

    func testFetchLatestPuzzleBypassesURLCache() async throws {
        var capturedCachePolicy: URLRequest.CachePolicy?
        let session = makeStubbedSession(
            statusCode: 200,
            data: makePuzzleJSON(puzzleID: "cache-policy-test")
        ) { request in
            capturedCachePolicy = request.cachePolicy
        }
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: URL(string: "https://example.com/daily-puzzle")!
        )

        _ = try await service.fetchLatestPuzzle()

        XCTAssertEqual(capturedCachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testFetchLatestPuzzleThrowsForNonSuccessStatus() async throws {
        let session = makeStubbedSession(statusCode: 500, data: Data())
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: URL(string: "https://example.com/daily-puzzle")!
        )

        do {
            _ = try await service.fetchLatestPuzzle()
            XCTFail("Expected bad status code error")
        } catch let error as DailyPuzzleService.ServiceError {
            switch error {
            case .badStatusCode(let code):
                XCTAssertEqual(code, 500)
            default:
                XCTFail("Expected .badStatusCode")
            }
        }
    }

    func testFetchLatestPuzzleThrowsWhenRandomAndLatestFailInDeveloperMode() async throws {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(true, forKey: developerModeKey)
        let randomURL = URL(string: "https://example.com/getRandomDailyPuzzle")!
        let latestURL = URL(string: "https://example.com/getLatestDailyPuzzle")!

        let session = makeStubbedSession { request in
            guard let url = request.url else {
                return (statusCode: 500, data: Data())
            }
            if url == randomURL || url == latestURL {
                return (statusCode: 503, data: Data())
            }
            return (statusCode: 404, data: Data())
        }
        let service = DailyPuzzleService(
            session: session,
            latestPuzzleURL: latestURL,
            randomPuzzleURL: randomURL,
            userDefaults: defaults,
            isDebugBuild: true
        )

        do {
            _ = try await service.fetchLatestPuzzle()
            XCTFail("Expected bad status code error")
        } catch let error as DailyPuzzleService.ServiceError {
            switch error {
            case .badStatusCode(let code):
                XCTAssertEqual(code, 503)
            default:
                XCTFail("Expected .badStatusCode")
            }
        }
    }

    func testArchivePuzzlesContainsFiftyEntries() {
        let puzzles = DailyPuzzle.archivePuzzles
        XCTAssertEqual(puzzles.count, 50)
        // Verify all puzzle IDs are unique
        let ids = Set(puzzles.map(\.puzzleID))
        XCTAssertEqual(ids.count, 50)
        // Verify all have archive- prefix
        XCTAssertTrue(puzzles.allSatisfy { $0.puzzleID.hasPrefix("archive-") })
    }

    func testArchivePuzzlesFavorAccessibleRecognizableTitles() {
        let titles = Set(DailyPuzzle.archivePuzzles.compactMap(\.title))
        let removedHardTitles: Set<String> = [
            "Pulp Fiction",
            "Fight Club",
            "The Shawshank Redemption",
            "Schindler's List",
            "Die Hard",
            "Alien",
            "Avengers: Endgame"
        ]
        let accessibleReplacements: Set<String> = [
            "Despicable Me",
            "Cars",
            "Monsters, Inc.",
            "The Incredibles",
            "Kung Fu Panda",
            "Inside Out",
            "Zootopia"
        ]

        XCTAssertTrue(titles.isDisjoint(with: removedHardTitles))
        XCTAssertTrue(accessibleReplacements.isSubset(of: titles))
    }

    func testEquationPiecesUsesFirstThreeGraphemeClusters() {
        let puzzle = DailyPuzzle(
            date: "2026-03-01",
            puzzleID: "equation-test",
            mediaType: .movie,
            tmdbID: 1,
            title: "Test Title",
            emojiClue: "🦸‍♂️🫰⌛🔥",
            hint1: "",
            hint2: "",
            acceptedAnswers: ["test"],
            source: "test",
            generatedAt: ""
        )

        XCTAssertEqual(puzzle.equationPieces, ["🦸‍♂️", "🫰", "⌛"])
    }

    func testHomeCardClueTextPreservesEmojiGraphemeClusters() {
        let puzzle = DailyPuzzle(
            date: "2026-08-27",
            puzzleID: "home-card-clue-test",
            mediaType: .movie,
            tmdbID: 1,
            title: "The Odyssey",
            emojiClue: "🛶🌊👑🧙‍♂️🐉",
            hint1: "",
            hint2: "",
            acceptedAnswers: ["the odyssey"],
            source: "test",
            generatedAt: ""
        )

        XCTAssertEqual(puzzle.homeCardClueText, "🛶 + 🌊 + 👑")
    }

    func testEquationResultTextReturnsQuestionMarkWhenUnsolved() {
        let puzzle = DailyPuzzle(
            date: "2026-03-01",
            puzzleID: "equation-result-test",
            mediaType: .movie,
            tmdbID: 1,
            title: "Inception",
            emojiClue: "😴🌀🏙️",
            hint1: "",
            hint2: "",
            acceptedAnswers: ["inception"],
            source: "test",
            generatedAt: ""
        )

        XCTAssertEqual(puzzle.equationResultText(isSolved: false), "?")
        XCTAssertEqual(puzzle.equationResultText(isSolved: true), "Inception")
    }

    func testFallbackPuzzleUsesDeveloperSamplesInDeveloperMode() {
        let defaults = makeIsolatedDefaults(for: #function)
        defaults.set(true, forKey: developerModeKey)
        let service = DailyPuzzleService(
            session: .shared,
            latestPuzzleURL: nil,
            randomPuzzleURL: nil,
            firestoreLatestDocumentURL: nil,
            firestoreCollectionURL: nil,
            userDefaults: defaults,
            isDebugBuild: true,
            randomUnitValue: { 0.99 }
        )

        let puzzle = service.fallbackPuzzle()
        XCTAssertEqual(puzzle, DailyPuzzle.developerSamples.last)
    }

    private func makeStubbedSession(statusCode: Int, data: Data) -> URLSession {
        URLProtocolStub.handler = { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    private func makeStubbedSession(
        statusCode: Int,
        data: Data,
        onRequest: @escaping (URLRequest) -> Void
    ) -> URLSession {
        URLProtocolStub.handler = { request in
            onRequest(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    private func makeStubbedSession(
        responseProvider: @escaping (URLRequest) -> (statusCode: Int, data: Data)
    ) -> URLSession {
        URLProtocolStub.handler = { request in
            let result = responseProvider(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: result.statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, result.data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    private func makePuzzleJSON(puzzleID: String) -> Data {
        """
        {
          "date":"2026-03-01",
          "puzzle_id":"\(puzzleID)",
          "media_type":"movie",
          "tmdb_id":1,
          "title":"Remote Puzzle",
          "emoji_clue":"🛰️🌍🎬",
          "hint_1":"Remote hint one",
          "hint_2":"Remote hint two",
          "accepted_answers":["remote puzzle"],
          "source":"remote",
          "generated_at":"2026-03-01T05:00:00.000Z"
        }
        """.data(using: .utf8)!
    }

    private func makeFirestoreDocumentJSON(puzzleID: String) -> Data {
        """
        {
          "name":"projects/admob-app-id-9658087638/databases/(default)/documents/dailyPuzzles/\(puzzleID)",
          "fields":{
            "date":{"stringValue":"2026-03-02"},
            "puzzle_id":{"stringValue":"\(puzzleID)"},
            "media_type":{"stringValue":"movie"},
            "tmdb_id":{"integerValue":"98"},
            "title":{"stringValue":"Firestore Puzzle"},
            "emoji_clue":{"stringValue":"🛸🌌🔍"},
            "hint_1":{"stringValue":"Firestore hint one"},
            "hint_2":{"stringValue":"Firestore hint two"},
            "accepted_answers":{"arrayValue":{"values":[{"stringValue":"firestore puzzle"}]}},
            "source":{"stringValue":"firestore-seed"},
            "generated_at":{"stringValue":"2026-03-02T05:00:00.000Z"}
          }
        }
        """.data(using: .utf8)!
    }

    private func makeFirestoreCollectionJSON(puzzleID: String) -> Data {
        """
        {
          "documents":[
            {
              "name":"projects/admob-app-id-9658087638/databases/(default)/documents/dailyPuzzles/latest",
              "fields":{
                "date":{"stringValue":"2026-03-01"},
                "puzzle_id":{"stringValue":"latest"},
                "media_type":{"stringValue":"movie"},
                "tmdb_id":{"integerValue":"1"},
                "title":{"stringValue":"Latest Alias"},
                "emoji_clue":{"stringValue":"🎬📅⭐"},
                "hint_1":{"stringValue":"Latest hint one"},
                "hint_2":{"stringValue":"Latest hint two"},
                "accepted_answers":{"arrayValue":{"values":[{"stringValue":"latest alias"}]}},
                "source":{"stringValue":"firestore-seed"},
                "generated_at":{"stringValue":"2026-03-01T05:00:00.000Z"}
              }
            },
            {
              "name":"projects/admob-app-id-9658087638/databases/(default)/documents/dailyPuzzles/\(puzzleID)",
              "fields":{
                "date":{"stringValue":"2026-03-02"},
                "puzzle_id":{"stringValue":"\(puzzleID)"},
                "media_type":{"stringValue":"movie"},
                "tmdb_id":{"integerValue":"2"},
                "title":{"stringValue":"Random Puzzle"},
                "emoji_clue":{"stringValue":"🧩🎥🔥"},
                "hint_1":{"stringValue":"Random hint one"},
                "hint_2":{"stringValue":"Random hint two"},
                "accepted_answers":{"arrayValue":{"values":[{"stringValue":"random puzzle"}]}},
                "source":{"stringValue":"firestore-seed"},
                "generated_at":{"stringValue":"2026-03-02T05:00:00.000Z"}
              }
            }
          ]
        }
        """.data(using: .utf8)!
    }

    private func makeIsolatedDefaults(for testName: String) -> UserDefaults {
        let suiteName = "DailyPuzzleServiceTests.\(testName)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create isolated UserDefaults suite")
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

final class DailyPuzzleAdminConfigServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testUpdateConfigThrowsWhenAdminKeyIsMissing() async throws {
        let service = DailyPuzzleAdminConfigService(
            session: .shared,
            endpointURL: URL(string: "https://example.com/admin")!
        )

        do {
            try await service.updateConfig(
                request: DailyPuzzleAdminConfigUpdateRequest(enabled: true, pushEnabled: true),
                apiKey: "   "
            )
            XCTFail("Expected missingAdminKey error")
        } catch let error as DailyPuzzleAdminConfigService.ServiceError {
            XCTAssertEqual(error, .missingAdminKey)
        }
    }

    func testUpdateConfigSendsExpectedHeaderAndJSONBody() async throws {
        var capturedRequest: URLRequest?
        let session = makeStubbedSession(statusCode: 200, data: Data()) { request in
            capturedRequest = request
        }
        let service = DailyPuzzleAdminConfigService(
            session: session,
            endpointURL: URL(string: "https://example.com/admin")!
        )

        try await service.updateConfig(
            request: DailyPuzzleAdminConfigUpdateRequest(enabled: false, pushEnabled: true),
            apiKey: "test-key"
        )

        guard let capturedRequest else {
            return XCTFail("Expected request to be captured")
        }
        XCTAssertEqual(capturedRequest.httpMethod, "POST")
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "x-admin-key"), "test-key")
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        guard
            let data = requestBodyData(from: capturedRequest),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return XCTFail("Expected JSON body with enabled and pushEnabled")
        }
        XCTAssertEqual(object["enabled"] as? Bool, false)
        XCTAssertEqual(object["pushEnabled"] as? Bool, true)
    }

    func testUpdateConfigThrowsForNonSuccessStatusCode() async throws {
        let session = makeStubbedSession(statusCode: 401, data: Data())
        let service = DailyPuzzleAdminConfigService(
            session: session,
            endpointURL: URL(string: "https://example.com/admin")!
        )

        do {
            try await service.updateConfig(
                request: DailyPuzzleAdminConfigUpdateRequest(enabled: true, pushEnabled: false),
                apiKey: "bad-key"
            )
            XCTFail("Expected badStatusCode error")
        } catch let error as DailyPuzzleAdminConfigService.ServiceError {
            XCTAssertEqual(error, .badStatusCode(401))
        }
    }

    func testSendTestPushSendsExpectedHeaderAndMethod() async throws {
        var capturedRequest: URLRequest?
        let session = makeStubbedSession(statusCode: 200, data: Data()) { request in
            capturedRequest = request
        }
        let service = DailyPuzzleAdminConfigService(
            session: session,
            endpointURL: URL(string: "https://example.com/admin")!,
            testPushEndpointURL: URL(string: "https://example.com/admin/test-push")!
        )

        try await service.sendTestPush(apiKey: "test-key")

        guard let capturedRequest else {
            return XCTFail("Expected request to be captured")
        }
        XCTAssertEqual(capturedRequest.httpMethod, "POST")
        XCTAssertEqual(capturedRequest.url?.absoluteString, "https://example.com/admin/test-push")
        XCTAssertEqual(capturedRequest.value(forHTTPHeaderField: "x-admin-key"), "test-key")
    }

    func testSendTestPushThrowsWhenEndpointIsMissing() async throws {
        let service = DailyPuzzleAdminConfigService(
            session: .shared,
            endpointURL: URL(string: "https://example.com/admin")!,
            testPushEndpointURL: nil
        )

        do {
            try await service.sendTestPush(apiKey: "test-key")
            XCTFail("Expected missing endpoint error")
        } catch let error as DailyPuzzleAdminConfigService.ServiceError {
            XCTAssertEqual(error, .missingEndpointURL)
        }
    }

    func testSendTestPushThrowsForNonSuccessStatusCode() async throws {
        let session = makeStubbedSession(statusCode: 403, data: Data())
        let service = DailyPuzzleAdminConfigService(
            session: session,
            endpointURL: URL(string: "https://example.com/admin")!,
            testPushEndpointURL: URL(string: "https://example.com/admin/test-push")!
        )

        do {
            try await service.sendTestPush(apiKey: "bad-key")
            XCTFail("Expected badStatusCode error")
        } catch let error as DailyPuzzleAdminConfigService.ServiceError {
            XCTAssertEqual(error, .badStatusCode(403))
        }
    }

    private func makeStubbedSession(
        statusCode: Int,
        data: Data,
        onRequest: ((URLRequest) -> Void)? = nil
    ) -> URLSession {
        URLProtocolStub.handler = { request in
            onRequest?(request)
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    private func requestBodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: buffer.count)
            if readCount < 0 {
                return nil
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }
        return data
    }
}

#if os(iOS)
@MainActor
final class DailyPuzzlePushTopicManagerTests: XCTestCase {
    private final class MockMessagingClient: DailyPuzzleTopicMessagingClient {
        var subscribedTopics = [String]()
        var unsubscribedTopics = [String]()

        func subscribe(topic: String) {
            subscribedTopics.append(topic)
        }

        func unsubscribe(topic: String) {
            unsubscribedTopics.append(topic)
        }
    }

    private var originalAllowNotifications = true
    private var originalDailyPuzzleRemindersEnabled = true

    override func setUp() {
        super.setUp()
        originalAllowNotifications = SettingsStore.shared.allowNotifications
        originalDailyPuzzleRemindersEnabled = SettingsStore.shared.dailyPuzzleRemindersEnabled
    }

    override func tearDown() {
        SettingsStore.shared.allowNotifications = originalAllowNotifications
        SettingsStore.shared.dailyPuzzleRemindersEnabled = originalDailyPuzzleRemindersEnabled
        DailyPuzzlePushTopicManager.messagingClient = FirebaseDailyPuzzleTopicMessagingClient()
        super.tearDown()
    }

    func testSyncSubscriptionRemovesLegacyBroadcastWhenNotificationsAndRemindersAreEnabled() {
        let mockClient = MockMessagingClient()
        DailyPuzzlePushTopicManager.messagingClient = mockClient
        SettingsStore.shared.allowNotifications = true
        SettingsStore.shared.dailyPuzzleRemindersEnabled = true

        DailyPuzzlePushTopicManager.syncSubscription()

        XCTAssertTrue(mockClient.subscribedTopics.isEmpty)
        XCTAssertEqual(mockClient.unsubscribedTopics, ["daily-puzzle"])
    }

    func testSyncSubscriptionRemovesLegacyBroadcastWhenNotificationsAreDisabled() {
        let mockClient = MockMessagingClient()
        DailyPuzzlePushTopicManager.messagingClient = mockClient
        SettingsStore.shared.allowNotifications = false
        SettingsStore.shared.dailyPuzzleRemindersEnabled = true

        DailyPuzzlePushTopicManager.syncSubscription()

        XCTAssertTrue(mockClient.subscribedTopics.isEmpty)
        XCTAssertEqual(mockClient.unsubscribedTopics, ["daily-puzzle"])
    }

    func testSyncSubscriptionRemovesLegacyBroadcastWhenRemindersAreDisabled() {
        let mockClient = MockMessagingClient()
        DailyPuzzlePushTopicManager.messagingClient = mockClient
        SettingsStore.shared.allowNotifications = true
        SettingsStore.shared.dailyPuzzleRemindersEnabled = false

        DailyPuzzlePushTopicManager.syncSubscription()

        XCTAssertTrue(mockClient.subscribedTopics.isEmpty)
        XCTAssertEqual(mockClient.unsubscribedTopics, ["daily-puzzle"])
    }
}
#endif

final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}

final class DailyPuzzleLocalizationTests: XCTestCase {
    func testDailyPuzzleLocalizationKeysExistInEnglishTable() throws {
        let contents = try String(contentsOf: englishLocalizationFileURL(), encoding: .utf8)

        let requiredKeys = [
            "dailyPuzzleTitle",
            "dailyPuzzleSubtitle",
            "dailyPuzzlePlayPuzzle",
            "dailyPuzzleViewPuzzle",
            "dailyPuzzleGuessFromEmojis",
            "dailyPuzzleGuessTitlePlaceholder",
            "dailyPuzzleSubmitGuess",
            "dailyPuzzleHint1Format",
            "dailyPuzzleHint2Format",
            "dailyPuzzleSolvedMessage",
            "dailyPuzzleShareResult",
            "dailyPuzzleAttemptsFormat",
            "dailyPuzzleEnableRemindersTitle",
            "dailyPuzzleEnableRemindersMessage",
            "dailyPuzzleEnableAction",
            "dailyPuzzleNotNowAction",
            "dailyPuzzleReminderNotificationTitle",
            "dailyPuzzleReminderNotificationBody"
        ]

        for key in requiredKeys {
            XCTAssertTrue(
                contents.contains("\"\(key)\" = "),
                "Missing localization key '\(key)' in Shared/Localization/en.lproj/Localizable.strings"
            )
        }
    }

    func testDailyPuzzleSubtitleUsesShortSingleLineCopy() throws {
        let contents = try String(contentsOf: englishLocalizationFileURL(), encoding: .utf8)
        XCTAssertTrue(
            contents.contains("\"dailyPuzzleSubtitle\" = \"Solve today's emoji movie clue.\";"),
            "dailyPuzzleSubtitle should use the shorter one-line copy."
        )
    }

    private func englishLocalizationFileURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Shared/Localization/en.lproj/Localizable.strings")
    }
}

final class DailyPuzzleRunStateTests: XCTestCase {
    func testFourDistinctTerminalPuzzlesProduceAccurateRunSummary() {
        var state = DailyPuzzleRunState()

        XCTAssertEqual(state.displayedRound(for: "puzzle-1"), 1)
        XCTAssertTrue(state.record(puzzleID: "puzzle-1", solved: true, attempts: 2, hints: 1))
        XCTAssertEqual(state.displayedRound(for: "puzzle-1"), 1)
        XCTAssertEqual(state.displayedRound(for: "puzzle-2"), 2)

        XCTAssertTrue(state.record(puzzleID: "puzzle-2", solved: false, attempts: 6, hints: 2))
        XCTAssertEqual(state.displayedRound(for: "puzzle-3"), 3)
        XCTAssertTrue(state.record(puzzleID: "puzzle-3", solved: true, attempts: 1, hints: 0))

        XCTAssertFalse(state.isComplete, "The third puzzle must leave a fourth round to play")
        XCTAssertEqual(state.displayedRound(for: "puzzle-4"), 4)
        XCTAssertTrue(state.record(puzzleID: "puzzle-4", solved: true, attempts: 1, hints: 0))
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(state.completedRounds, 4)
        XCTAssertEqual(state.solvedRounds, 3)
        XCTAssertEqual(state.failedRounds, 1)
        XCTAssertEqual(state.totalAttempts, 10)
        XCTAssertEqual(state.totalHints, 3)
        XCTAssertTrue(state.shareText.contains("3/4 solved"))
        XCTAssertFalse(state.shareText.contains("Titanic"))
        XCTAssertFalse(state.shareText.contains("The Matrix"))
    }

    func testDuplicatePuzzleDoesNotChangeRunTotals() {
        var state = DailyPuzzleRunState()

        XCTAssertTrue(state.record(puzzleID: "same", solved: true, attempts: 1, hints: 0, points: 3))
        XCTAssertFalse(state.record(puzzleID: "same", solved: true, attempts: 1, hints: 0, points: 3))

        XCTAssertEqual(state.completedRounds, 1)
        XCTAssertEqual(state.solvedRounds, 1)
        XCTAssertEqual(state.totalAttempts, 1)
        XCTAssertEqual(state.totalHints, 0)
        XCTAssertEqual(state.quizPoints, 3)
        XCTAssertEqual(state.firstTryRounds, 1)
    }

    func testPerfectRunScoresTwelvePointsAndIgnoresAnExtraPuzzle() {
        var state = DailyPuzzleRunState()
        for index in 1...4 {
            XCTAssertTrue(state.record(puzzleID: "puzzle-\(index)", solved: true, attempts: 1, hints: 0, points: 3))
        }
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(DailyPuzzleRunState.maxPoints, 12)
        XCTAssertEqual(state.quizPoints, 12)
        XCTAssertEqual(state.firstTryRounds, 4)
        XCTAssertTrue(state.shareText.contains("12 / 12 points"))
        XCTAssertTrue(state.shareText.contains("4 first-try answers"))
        XCTAssertFalse(state.record(puzzleID: "extra", solved: true, attempts: 1, hints: 0, points: 3))
        XCTAssertEqual(state.completedRounds, 4)
        XCTAssertEqual(state.quizPoints, 12)
    }

    func testStartingNextRunClearsCumulativeState() {
        var state = DailyPuzzleRunState()
        _ = state.record(puzzleID: "one", solved: true, attempts: 1, hints: 0)
        _ = state.record(puzzleID: "two", solved: true, attempts: 2, hints: 1)
        _ = state.record(puzzleID: "three", solved: false, attempts: 6, hints: 2)
        _ = state.record(puzzleID: "four", solved: true, attempts: 1, hints: 0, currentStreak: 5, points: 3)
        XCTAssertTrue(state.isComplete)

        state.startNextRun()

        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.completedRounds, 0)
        XCTAssertEqual(state.solvedRounds, 0)
        XCTAssertEqual(state.totalAttempts, 0)
        XCTAssertEqual(state.totalHints, 0)
        XCTAssertEqual(state.quizPoints, 0)
        XCTAssertEqual(state.firstTryRounds, 0)
        XCTAssertEqual(state.currentStreak, 0)
        XCTAssertEqual(state.displayedRound(for: "four"), 1)
        XCTAssertTrue(state.record(puzzleID: "one", solved: true, attempts: 1, hints: 0, points: 3), "Reset clears previously recorded IDs")
    }

    func testRunCompletedEventIncludesDecisionContext() {
        let event = DailyPuzzleAnalyticsEvent.runCompleted(
            puzzleID: "puzzle-3",
            runSequence: 2,
            targetRounds: 3,
            completedRounds: 3,
            solvedRounds: 2,
            totalAttempts: 9,
            totalHints: 3
        )

        XCTAssertEqual(event.name, "daily_puzzle_run_completed")
        XCTAssertEqual(event.metadata["run_sequence"], "2")
        XCTAssertEqual(event.metadata["target_rounds"], "3")
        XCTAssertEqual(event.metadata["completed_rounds"], "3")
        XCTAssertEqual(event.metadata["solved_rounds"], "2")
        XCTAssertEqual(event.metadata["failed_rounds"], "1")
        XCTAssertEqual(event.metadata["total_attempts"], "9")
        XCTAssertEqual(event.metadata["total_hints"], "3")
    }

    func testRunStartedEventIncludesSequenceAndTarget() {
        let event = DailyPuzzleAnalyticsEvent.runStarted(
            puzzleID: "puzzle-1",
            runSequence: 1,
            targetRounds: 3
        )

        XCTAssertEqual(event.name, "daily_puzzle_run_started")
        XCTAssertEqual(event.metadata["puzzle_id"], "puzzle-1")
        XCTAssertEqual(event.metadata["run_sequence"], "1")
        XCTAssertEqual(event.metadata["target_rounds"], "3")
    }
}

final class DailyPuzzleWeeklyGoalTests: XCTestCase {
    func testSameDayRunsCountOnceAndPersist() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let store = DailyPuzzleWeeklyGoalStore(
            userDefaults: context.defaults,
            calendar: context.calendar
        )
        let day = makeDate(year: 2026, month: 8, day: 24, calendar: context.calendar)

        let first = store.recordCompletedRun(on: day)
        let duplicate = store.recordCompletedRun(on: day)
        let reloaded = DailyPuzzleWeeklyGoalStore(
            userDefaults: context.defaults,
            calendar: context.calendar
        ).progress(on: day)

        XCTAssertEqual(first.outcome, .progressed)
        XCTAssertEqual(duplicate.outcome, .alreadyCompletedToday)
        XCTAssertEqual(reloaded.completedDays, 1)
        XCTAssertTrue(reloaded.completedToday)
        XCTAssertFalse(reloaded.isComplete)
    }

    func testFifthUniqueDayCompletesWeeklyGoal() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let store = DailyPuzzleWeeklyGoalStore(
            userDefaults: context.defaults,
            calendar: context.calendar
        )
        var update: DailyPuzzleWeeklyGoalUpdate?

        for day in 24 ... 28 {
            update = store.recordCompletedRun(
                on: makeDate(year: 2026, month: 8, day: day, calendar: context.calendar)
            )
        }

        XCTAssertEqual(update?.outcome, .completed)
        XCTAssertEqual(update?.progress.completedDays, 5)
        XCTAssertEqual(update?.progress.remainingDays, 0)
        XCTAssertEqual(update?.progress.isComplete, true)
    }

    func testNewWeekStartsFreshGoal() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let store = DailyPuzzleWeeklyGoalStore(
            userDefaults: context.defaults,
            calendar: context.calendar
        )
        let sunday = makeDate(year: 2026, month: 1, day: 4, calendar: context.calendar)
        let monday = makeDate(year: 2026, month: 1, day: 5, calendar: context.calendar)

        _ = store.recordCompletedRun(on: sunday)
        let nextWeek = store.recordCompletedRun(on: monday)

        XCTAssertEqual(nextWeek.outcome, .progressed)
        XCTAssertEqual(nextWeek.progress.completedDays, 1)
        XCTAssertNotEqual(
            store.progress(on: sunday).weekID,
            nextWeek.progress.weekID
        )
    }

    func testWeeklyGoalEventIncludesDecisionContext() {
        let progress = DailyPuzzleWeeklyGoalProgress(
            weekID: "2026-W35",
            completedDays: 3,
            completedToday: true
        )
        let update = DailyPuzzleWeeklyGoalUpdate(
            progress: progress,
            outcome: .progressed
        )

        let event = DailyPuzzleAnalyticsEvent.weeklyGoalUpdated(
            puzzleID: "puzzle-3",
            update: update
        )

        XCTAssertEqual(event.name, "daily_puzzle_weekly_goal_updated")
        XCTAssertEqual(event.metadata["week_id"], "2026-W35")
        XCTAssertEqual(event.metadata["outcome"], "progressed")
        XCTAssertEqual(event.metadata["completed_days"], "3")
        XCTAssertEqual(event.metadata["target_days"], "5")
        XCTAssertEqual(event.metadata["remaining_days"], "2")
        XCTAssertEqual(event.metadata["goal_complete"], "false")
    }

    private func makeContext() -> (suiteName: String, defaults: UserDefaults, calendar: Calendar) {
        let suiteName = "DailyPuzzleWeeklyGoalTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return (suiteName, defaults, calendar)
    }

    private func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return components.date!
    }
}

final class DailyPuzzleHintOfferTests: XCTestCase {
    func testHintOfferAppearsOnlyAfterDemonstratedDifficulty() {
        XCTAssertFalse(
            DailyPuzzleHintOfferPolicy.shouldShow(
                attempts: 0,
                unlockedHintCount: 0,
                puzzleFinished: false,
                hasPurchasedTipJar: false
            )
        )
        XCTAssertTrue(
            DailyPuzzleHintOfferPolicy.shouldShow(
                attempts: 1,
                unlockedHintCount: 0,
                puzzleFinished: false,
                hasPurchasedTipJar: false
            )
        )
        XCTAssertFalse(
            DailyPuzzleHintOfferPolicy.shouldShow(
                attempts: 1,
                unlockedHintCount: 2,
                puzzleFinished: false,
                hasPurchasedTipJar: false
            )
        )
        XCTAssertFalse(
            DailyPuzzleHintOfferPolicy.shouldShow(
                attempts: 1,
                unlockedHintCount: 0,
                puzzleFinished: true,
                hasPurchasedTipJar: false
            )
        )
        XCTAssertFalse(
            DailyPuzzleHintOfferPolicy.shouldShow(
                attempts: 1,
                unlockedHintCount: 0,
                puzzleFinished: false,
                hasPurchasedTipJar: true
            )
        )
    }

    func testHintOfferEventsDescribeTheConversionFunnel() {
        let shown = DailyPuzzleAnalyticsEvent.hintOfferShown(
            puzzleID: "puzzle-1",
            hintLevel: 1,
            attempts: 1
        )
        let tapped = DailyPuzzleAnalyticsEvent.hintOfferTapped(
            puzzleID: "puzzle-1",
            hintLevel: 1,
            attempts: 1
        )
        let rewarded = DailyPuzzleAnalyticsEvent.hintRewardGranted(
            puzzleID: "puzzle-1",
            hintLevel: 1,
            attempts: 1
        )

        XCTAssertEqual(shown.name, "daily_puzzle_hint_offer_shown")
        XCTAssertEqual(tapped.name, "daily_puzzle_hint_offer_tapped")
        XCTAssertEqual(rewarded.name, "daily_puzzle_hint_reward_granted")
        XCTAssertEqual(shown.metadata["hint_level"], "1")
        XCTAssertEqual(shown.metadata["attempts"], "1")
        XCTAssertEqual(tapped.metadata["puzzle_id"], "puzzle-1")
        XCTAssertEqual(rewarded.metadata["hint_level"], "1")
    }
}

@MainActor
final class DailyPuzzleReminderPresentationTests: XCTestCase {
    func testPreferenceCompletionAndQuietHoursGateForegroundPresentation() {
        let settings = SettingsStore.shared
        let defaults = UserDefaults.standard
        let allow = settings.allowNotifications
        let reminders = settings.dailyPuzzleRemindersEnabled
        let completion = defaults.object(forKey: "dailyPuzzleReminderCompletedAt")
        let solved = defaults.object(forKey: "dailyPuzzleLastSolvedDate")
        defer {
            settings.allowNotifications = allow
            settings.dailyPuzzleRemindersEnabled = reminders
            defaults.set(completion, forKey: "dailyPuzzleReminderCompletedAt")
            defaults.set(solved, forKey: "dailyPuzzleLastSolvedDate")
        }
        defaults.removeObject(forKey: "dailyPuzzleReminderCompletedAt")
        defaults.removeObject(forKey: "dailyPuzzleLastSolvedDate")
        let calendar = Calendar.autoupdatingCurrent
        let evening = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        let overnight = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: Date())!
        settings.allowNotifications = true
        settings.dailyPuzzleRemindersEnabled = true
        XCTAssertTrue(NotificationManager.shared.shouldPresentDailyPuzzleReminder(now: evening))
        XCTAssertFalse(NotificationManager.shared.shouldPresentDailyPuzzleReminder(now: overnight))
        settings.allowNotifications = false
        XCTAssertFalse(NotificationManager.shared.shouldPresentDailyPuzzleReminder(now: evening))
        settings.allowNotifications = true
        settings.dailyPuzzleRemindersEnabled = false
        XCTAssertFalse(NotificationManager.shared.shouldPresentDailyPuzzleReminder(now: evening))
        settings.dailyPuzzleRemindersEnabled = true
        defaults.set(evening, forKey: "dailyPuzzleReminderCompletedAt")
        XCTAssertFalse(NotificationManager.shared.shouldPresentDailyPuzzleReminder(now: evening))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: evening)!
        XCTAssertTrue(NotificationManager.shared.shouldPresentDailyPuzzleReminder(now: tomorrow))
    }
}

final class DailyPuzzleAnswerAcceptanceTests: XCTestCase {
    private var puzzle: DailyPuzzle {
        var puzzle = DailyPuzzle.sample
        puzzle.title = "Spirited Away"
        puzzle.acceptedAnswers = ["spirited away"]
        puzzle.localizations = [
            "fr-FR": .init(title: "Le Voyage de Chihiro", emojiClue: "", hint1: "", hint2: "", acceptedAnswers: ["Voyage de Chihiro"]),
            "es-MX": .init(title: "El viaje de Chihiro", emojiClue: "", hint1: "", hint2: "", acceptedAnswers: ["El viaje de Chihiro"]),
            "pt-BR": .init(title: "A Viagem de Chihiro", emojiClue: "", hint1: "", hint2: "", acceptedAnswers: ["A viagem de Chihiro"])
        ]
        return puzzle
    }

    func testAcceptsKnownRegionalTitlesRegardlessOfDisplayLanguage() {
        for locale in ["en", "de-DE", "fr-FR", "es-MX", "pt-BR"] {
            let localized = puzzle.localized(forLocaleIdentifier: locale).puzzle
            for answer in ["Spirited Away", "Le Voyage de Chihiro", "Voyage de Chihiro", "El viaje de Chihiro", "A Viagem de Chihiro"] {
                XCTAssertTrue(localized.matches(guess: answer), "\(locale) rejected \(answer)")
            }
        }
    }

    func testCanonicalTitleIsAcceptedEvenWhenMissingFromAliases() {
        var titleOnly = puzzle
        titleOnly.acceptedAnswers = []
        XCTAssertTrue(titleOnly.matches(guess: "Spirited Away"))
    }

    func testNormalizationKeepsAccentsAndPunctuationForgivingWithoutAcceptingOtherFilms() {
        var accented = DailyPuzzle.sample
        accented.title = "Amélie"
        accented.acceptedAnswers = ["Amélie", "Spider-Man 2"]
        XCTAssertTrue(accented.matches(guess: "  AMELIE!  "))
        XCTAssertTrue(accented.matches(guess: "Spider Man 2"))
        for wrong in ["", "!!!", "Spider Man", "Spider Man 3", "Spirited", "Titanic 2"] {
            XCTAssertFalse(accented.matches(guess: wrong))
        }
    }
}


@MainActor
final class DailyPuzzleNotificationAuthorizationTests: XCTestCase {
    func testRemainingProvisionalDoesNotClaimFullPermission() async throws {
        let result = try await DailyPuzzleNotificationAuthorization.enable(status: { .provisional }, request: { _ in
            true
        }, enablePreferences: { XCTFail("Provisional is not full authorization") })
        XCTAssertEqual(result, .provisional)
    }

    func testUndeterminedAndProvisionalRequestFullPermissionThenEnablePreferences() async throws {
        for initial in [UNAuthorizationStatus.notDetermined, .provisional] {
            var status = initial
            var enabled = false
            let result = try await DailyPuzzleNotificationAuthorization.enable(status: { status }, request: { options in
                XCTAssertTrue(options.contains(.alert))
                XCTAssertFalse(options.contains(.provisional))
                status = .authorized
                return true
            }, enablePreferences: { enabled = true })
            XCTAssertEqual(result, .authorized)
            XCTAssertTrue(enabled)
        }
    }

    func testAuthorizedRestoresPreferencesWithoutPermissionRequest() async throws {
        var enabled = false
        _ = try await DailyPuzzleNotificationAuthorization.enable(status: { .authorized }, request: { _ in
            XCTFail("Do not request already granted permission")
            return false
        }, enablePreferences: { enabled = true })
        XCTAssertTrue(enabled)
    }

    func testDeniedDoesNotRequestOrEnable() async throws {
        let result = try await DailyPuzzleNotificationAuthorization.enable(status: { .denied }, request: { _ in
            XCTFail("Denied permission requires Settings")
            return false
        }, enablePreferences: { XCTFail("Must not claim enabled") })
        XCTAssertEqual(result, .denied)
    }

    func testDecliningSystemPermissionDoesNotEnable() async throws {
        var status = UNAuthorizationStatus.notDetermined
        let result = try await DailyPuzzleNotificationAuthorization.enable(status: { status }, request: { _ in
            status = .denied
            return false
        }, enablePreferences: { XCTFail("Must not enable after denial") })
        XCTAssertEqual(result, .denied)
    }

    func testPermissionErrorDoesNotEnablePreferences() async {
        do {
            _ = try await DailyPuzzleNotificationAuthorization.enable(status: { .notDetermined }, request: { _ in
                throw URLError(.unknown)
            }, enablePreferences: { XCTFail("Must not enable after error") })
            XCTFail("Expected error")
        } catch { XCTAssertTrue(error is URLError) }
    }
}
