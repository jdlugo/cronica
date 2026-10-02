import SwiftUI
import UserNotifications

func localizedDailyPuzzleString(
    _ key: String,
    defaultValue: String,
    comment: String
) -> String {
    NSLocalizedString(
        key,
        tableName: nil,
        bundle: .main,
        value: defaultValue,
        comment: comment
    )
}

@MainActor
@Observable
final class DailyPuzzleViewModel {
    static let maxAttempts = 6

    let puzzle: DailyPuzzle
    let puzzleIndex: Int
    private let streakStore: DailyPuzzleStreakStore
    private let promptStore: DailyPuzzlePromptStore
    private let progressStore: DailyPuzzleProgressStore
    private let activationStore: DailyPuzzleActivationStore
    private let analyticsTracker: DailyPuzzleAnalyticsTracking
    private let reminderScheduler: DailyPuzzleReminderScheduling
    private let recordsDailyStreak: Bool
    private let puzzleLocaleIdentifier: String
    private let puzzleLocalizationSource: DailyPuzzleLocalizationSource
    private var sessionStartedAt: Date?
    private var didTrackStarterClueShown = false
    private var presentationID = UUID().uuidString
    private var presentationVisible = false
    private var presentationEnded = false
    private var didTrackFirstInput = false
    private var presentationSource = "unknown"
    private var visibleAt: Date?

    func trackScreenVisible(now: Date = Date()) {
        guard !presentationVisible else { return }
        if presentationEnded {
            presentationID = UUID().uuidString
            didTrackFirstInput = false
        }
        presentationEnded = false
        presentationVisible = true
        visibleAt = now
        track(event: .init(name: "daily_puzzle_screen_visible", metadata: ["puzzle_id": puzzle.puzzleID, "source": presentationSource]))
    }

    func trackFirstInput() {
        guard !didTrackFirstInput, !isSolved, !didFail else { return }
        didTrackFirstInput = true
        track(event: .init(name: "daily_puzzle_first_input", metadata: ["puzzle_id": puzzle.puzzleID, "source": presentationSource]))
    }

    func trackDismissed(now: Date = Date()) {
        guard presentationVisible, !presentationEnded else { return }
        presentationVisible = false
        presentationEnded = true
        guard !isSolved, !didFail else { return }
        track(event: .init(name: "daily_puzzle_abandoned", metadata: [
            "puzzle_id": puzzle.puzzleID,
            "source": presentationSource,
            "had_input": String(didTrackFirstInput),
            "visible_seconds": String(max(0, Int(now.timeIntervalSince(visibleAt ?? now))))
        ]))
    }


    var quizState: MovieQuizState?
    var quizLoading = false
    var quizLoadFailed = false
    private var trackedQuizImageOutcomes = Set<String>()

    var attempts = 0
    var unlockedHintCount = 0
    var isSolved = false
    var didFail = false
    var solveCelebrationCount = 0
    var shouldShowNotificationPrompt = false
    var isTitlePatternRevealed = false
    var hasSubmittedDifficultyFeedback = false

    var isFailed: Bool { attempts >= Self.maxAttempts && !isSolved }

    var currentStreak: Int { recordsDailyStreak ? streakStore.currentStreak : 0 }

    var starterClueText: String {
        if titleWordCount == 1 {
            return localizedDailyPuzzleString(
                "dailyPuzzleStarterClueOneWord",
                defaultValue: "Starter clue: 1-word title",
                comment: "Starter clue for a one-word puzzle title"
            )
        }
        return String(
            format: localizedDailyPuzzleString(
                "dailyPuzzleStarterClueManyWordsFormat",
                defaultValue: "Starter clue: %d-word title",
                comment: "Starter clue showing the number of words in a puzzle title"
            ),
            titleWordCount
        )
    }

    var canOfferTitlePattern: Bool {
        attempts >= 2 && !isSolved && !didFail && !isTitlePatternRevealed && !puzzleTitle.isEmpty
    }

    var titlePatternText: String {
        String(
            format: localizedDailyPuzzleString(
                "dailyPuzzleTitlePatternFormat",
                defaultValue: "Title pattern: %@",
                comment: "Masked puzzle title pattern"
            ),
            maskedPuzzleTitle
        )
    }

    var shouldRequestDifficultyFeedback: Bool {
        (isSolved || didFail) && !hasSubmittedDifficultyFeedback
    }

    private var puzzleTitle: String {
        if let title = puzzle.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return puzzle.acceptedAnswers.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var titleWordCount: Int {
        max(1, puzzleTitle.split(whereSeparator: { $0.isWhitespace }).count)
    }

    private var maskedPuzzleTitle: String {
        var revealNextAlphanumeric = true
        return String(puzzleTitle.map { character in
            if character.isLetter || character.isNumber {
                if revealNextAlphanumeric {
                    revealNextAlphanumeric = false
                    return character
                }
                return "•"
            }
            if character.isWhitespace || character == "-" {
                revealNextAlphanumeric = true
            }
            return character
        })
    }

    init(
        puzzle: DailyPuzzle,
        streakStore: DailyPuzzleStreakStore = DailyPuzzleStreakStore(),
        promptStore: DailyPuzzlePromptStore = DailyPuzzlePromptStore(),
        progressStore: DailyPuzzleProgressStore = DailyPuzzleProgressStore(),
        activationStore: DailyPuzzleActivationStore = DailyPuzzleActivationStore(),
        analyticsTracker: DailyPuzzleAnalyticsTracking = DailyPuzzleLiveAnalyticsTracker(),
        reminderScheduler: DailyPuzzleReminderScheduling? = nil,
        recordsDailyStreak: Bool = true,
        restoresProgress: Bool = true,
        puzzleIndex: Int = 1,
        locale: Locale = .autoupdatingCurrent
    ) {
        let localization = puzzle.localized(for: locale)
        self.puzzle = localization.puzzle
        self.puzzleIndex = max(1, puzzleIndex)
        self.streakStore = streakStore
        self.promptStore = promptStore
        self.progressStore = progressStore
        self.activationStore = activationStore
        self.analyticsTracker = analyticsTracker
        self.reminderScheduler = reminderScheduler ?? NotificationManager.shared
        self.recordsDailyStreak = recordsDailyStreak
        self.puzzleLocaleIdentifier = localization.localeIdentifier
        self.puzzleLocalizationSource = localization.source
        self.sessionStartedAt = nil
        self.isTitlePatternRevealed = activationStore.isTitlePatternRevealed(
            for: self.puzzle.puzzleID
        )
        self.hasSubmittedDifficultyFeedback = activationStore.difficultyRating(
            for: self.puzzle.puzzleID
        ) != nil

        if restoresProgress, let progress = progressStore.load(puzzleID: self.puzzle.puzzleID) {
            quizState = progress.quizState
            attempts = progress.attempts
            unlockedHintCount = progress.unlockedHintCount
            isSolved = progress.solved
            if progress.quizState?.skipped == true || (!isSolved && attempts >= Self.maxAttempts) {
                didFail = true
            }
        }
    }

    var quizPoints: Int { quizState?.points ?? 0 }

    func loadMovieQuiz() async {
        guard quizState == nil, !quizLoading else { return }
        quizLoading = true
        quizLoadFailed = false
        defer { quizLoading = false }
        do {
            let round = try await MovieQuizRoundLoader.load(puzzle: puzzle, roundIndex: puzzleIndex)
            guard !Task.isCancelled else { return }
            prepareMovieQuiz(round)
        } catch {
            guard !Task.isCancelled else { return }
            quizLoadFailed = true
            track(event: .init(name: "movie_quiz_load_failed", metadata: ["reason": "unavailable"]))
        }
    }

    func prepareMovieQuiz(_ round: MovieQuizRound) {
        guard quizState == nil, round.answerID == puzzle.tmdbID, round.choices.count == 4 else { return }
        var state = MovieQuizState(round: round)
        // Completed legacy puzzles remain completed; their old attempt score is not converted.
        if isSolved || didFail { state.restoreLegacyCompletion(solved: isSolved) }
        else {
            attempts = 0
            unlockedHintCount = 0
            if puzzleIndex % 2 == 0 { state.enableZoomReveal() }
            else { state.enableTileReveal() }
        }
        quizState = state
        saveQuizProgress()
    }

    func chooseMovie(_ id: Int, notificationStatus: UNAuthorizationStatus, now: Date = Date()) {
        guard !isSolved, !didFail, var state = quizState, state.choose(id) else { return }
        quizState = state
        if state.hintRevealed { unlockedHintCount = max(1, unlockedHintCount) }
        let answer = id == puzzle.tmdbID ? puzzleTitle : state.round.choices.first(where: { $0.id == id })!.title
        submitGuess(answer, notificationStatus: notificationStatus, now: now)
        track(event: .init(name: "movie_quiz_answer_selected", metadata: [
            "correct": String(state.isSolved), "assisted": String(state.hintRevealed),
            "revealed_tile_count": String(state.visibleTileIndices.count),
            "tile_reveal_enabled": String(state.revealedTiles != nil),
            "zoom_step": state.zoomStep.map(String.init) ?? "none",
            "image_fallback": String(state.imageUnavailable == true)
        ]))
    }

    func trackQuizImage(_ outcome: String) {
        guard trackedQuizImageOutcomes.insert(outcome).inserted else { return }
        track(event: .init(name: "movie_quiz_image", metadata: ["outcome": outcome]))
    }

    func revealMovieQuizTile(_ index: Int) {
        guard !isSolved, !didFail, var state = quizState, state.revealTile(index) else { return }
        quizState = state
        saveQuizProgress()
        track(event: .init(name: "movie_quiz_tile_revealed", metadata: [
            "tile_index": String(index), "revealed_tile_count": String(state.visibleTileIndices.count),
            "available_points": String(state.availablePoints)
        ]))
    }

    func handleMovieQuizImageUnavailable() {
        trackQuizImage("unavailable")
        guard !isSolved, !didFail, var state = quizState, state.imageUnavailable != true else { return }
        state.disableTileRevealForUnavailableImage()
        quizState = state
        unlockedHintCount = max(1, unlockedHintCount)
        saveQuizProgress()
        track(event: .init(name: "movie_quiz_hint_revealed", metadata: ["reason": "image_unavailable"]))
    }

    func zoomOutMovieQuiz() {
        guard !isSolved, !didFail, var state = quizState, state.zoomOut() else { return }
        quizState = state
        saveQuizProgress()
        track(event: .init(name: "movie_quiz_zoomed_out", metadata: [
            "zoom_step": String(state.zoomStep ?? 0),
            "available_points": String(state.availablePoints)
        ]))
    }

    func revealMovieQuizHint(reason: String = "requested") {
        guard !isSolved, !didFail, var state = quizState, !state.hintRevealed else { return }
        state.revealHint()
        quizState = state
        unlockedHintCount = max(1, unlockedHintCount)
        saveQuizProgress()
        track(event: .init(name: "movie_quiz_hint_revealed", metadata: ["reason": reason]))
    }

    func skipMovieQuiz(now: Date = Date()) {
        guard !isSolved, !didFail, var state = quizState else { return }
        state.skip()
        quizState = state
        didFail = true
        reminderScheduler.cancelDailyPuzzleFallbackReminder(for: puzzle.puzzleID)
        if recordsDailyStreak { reminderScheduler.completeDailyPuzzle(at: now) }
        saveQuizProgress()
        track(event: .failed(puzzleID: puzzle.puzzleID, attempts: attempts))
        track(event: .init(name: "movie_quiz_skipped", metadata: [:]))
        trackSessionEnded(status: "failed", attempts: attempts, at: now)
    }

    private func saveQuizProgress() {
        progressStore.save(.init(puzzleID: puzzle.puzzleID, solved: isSolved, attempts: attempts,
                                unlockedHintCount: unlockedHintCount, solvedAt: isSolved ? Date() : nil,
                                quizState: quizState))
    }

    var cardStatusText: String {
        if isSolved {
            let streak = max(streakStore.currentStreak, 1)
            return String(
                format: NSLocalizedString("dailyPuzzleCardStreakFormat", comment: "Daily puzzle card streak"),
                streak
            )
        }
        return NSLocalizedString("dailyPuzzleNewToday", comment: "New daily puzzle badge")
    }

    var shareResultText: String? {
        guard isSolved else { return nil }
        let streak = recordsDailyStreak ? max(streakStore.currentStreak, 1) : 0
        var lines = [
            String(
                format: NSLocalizedString("dailyPuzzleShareSolvedFormat", comment: "Solved puzzle share summary"),
                attempts,
                Self.maxAttempts
            )
        ]
        if streak > 0 {
            lines.append(
                String(
                    format: NSLocalizedString("dailyPuzzleShareStreakFormat", comment: "Puzzle share streak"),
                    streak
                )
            )
        }
        lines.append(NSLocalizedString("dailyPuzzleSharePlayCTA", comment: "Puzzle share App Store CTA"))
        return lines.joined(separator: "\n")
    }

    func submitGuess(_ guess: String, notificationStatus: UNAuthorizationStatus, now: Date = Date()) {
        guard !isSolved, !didFail else { return }
        guard !guess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        trackFirstInput()
        let previousHintCount = unlockedHintCount
        attempts += 1
        if attempts >= 2 {
            unlockedHintCount = max(unlockedHintCount, 1)
        }
        if attempts >= 4 {
            unlockedHintCount = max(unlockedHintCount, 2)
        }
        track(event: .guessSubmitted(puzzleID: puzzle.puzzleID, attempts: attempts))

        if unlockedHintCount > previousHintCount {
            for level in (previousHintCount + 1)...unlockedHintCount {
                track(event: .hintUnlocked(puzzleID: puzzle.puzzleID, level: level))
            }
        }

        if puzzle.matches(guess: guess) {
            isSolved = true
            solveCelebrationCount += 1
            if recordsDailyStreak {
                streakStore.recordSolved(on: now)
            }
            track(event: .solved(puzzleID: puzzle.puzzleID, attempts: attempts))
            trackSessionEnded(status: "solved", attempts: attempts, at: now)
        }

        if !isSolved && attempts == 2 && !isTitlePatternRevealed {
            track(event: .answerRescueOffered(puzzleID: puzzle.puzzleID, attempts: attempts))
        }

        // Check for failure (max attempts reached without solving)
        if !isSolved && attempts >= Self.maxAttempts {
            didFail = true
            track(event: .failed(puzzleID: puzzle.puzzleID, attempts: attempts))
            trackSessionEnded(status: "failed", attempts: attempts, at: now)
        }

        if isSolved || didFail {
            reminderScheduler.cancelDailyPuzzleFallbackReminder(for: puzzle.puzzleID)
            if recordsDailyStreak { reminderScheduler.completeDailyPuzzle(at: now) }
        }

        if isSolved {
            // Show notification prompt at peak joy (post-solve) instead of first wrong guess
            if recordsDailyStreak && !promptStore.hasSeenPrompt && notificationStatus == .notDetermined {
                shouldShowNotificationPrompt = true
            }
        }

        let progress = DailyPuzzleProgress(
            puzzleID: puzzle.puzzleID,
            solved: isSolved,
            attempts: attempts,
            unlockedHintCount: unlockedHintCount,
            solvedAt: isSolved ? now : nil,
            quizState: quizState
        )
        progressStore.save(progress)
    }

    @discardableResult
    func unlockNextHint(expectedLevel: Int? = nil) -> Bool {
        guard !isSolved, !didFail, unlockedHintCount < 2,
              expectedLevel == nil || expectedLevel == unlockedHintCount + 1 else { return false }
        unlockedHintCount += 1
        let progress = DailyPuzzleProgress(
            puzzleID: puzzle.puzzleID,
            solved: isSolved,
            attempts: attempts,
            unlockedHintCount: unlockedHintCount,
            solvedAt: nil,
            quizState: quizState
        )
        progressStore.save(progress)
        track(event: .hintUnlocked(puzzleID: puzzle.puzzleID, level: unlockedHintCount))
        return true
    }

    var offersDailyReminder: Bool { recordsDailyStreak && isSolved }
    private var didTrackReminderOffer = false

    func trackReminderOfferVisible() {
        guard offersDailyReminder, !didTrackReminderOffer else { return }
        didTrackReminderOffer = true
        track(event: .promptShown(puzzleID: puzzle.puzzleID))
    }

    func trackReminderChoice(_ action: String) {
        track(event: .init(name: "daily_puzzle_notification_choice", metadata: ["puzzle_id": puzzle.puzzleID, "action": action]))
    }

    func trackReminderOutcome(_ outcome: String) {
        track(event: .init(name: "daily_puzzle_notification_outcome", metadata: ["puzzle_id": puzzle.puzzleID, "outcome": outcome]))
    }

    func markNotificationPromptHandled(granted: Bool) {
        promptStore.markSeen(granted: granted)
        shouldShowNotificationPrompt = false
        track(event: .promptResponse(puzzleID: puzzle.puzzleID, granted: granted))
    }

    func trackOpened(source: String) {
        presentationSource = source
        if sessionStartedAt == nil {
            sessionStartedAt = Date()
            track(
                event: .sessionStarted(
                    puzzleID: puzzle.puzzleID,
                    source: source,
                    puzzleMediaType: puzzle.mediaType.rawValue,
                    puzzleSource: puzzle.source
                )
            )
        }
        track(event: .opened(puzzleID: puzzle.puzzleID, source: source))
        if !didTrackStarterClueShown {
            didTrackStarterClueShown = true
            track(
                event: .starterClueShown(
                    puzzleID: puzzle.puzzleID,
                    titleWordCount: titleWordCount
                )
            )
        }
    }

    func revealTitlePattern() {
        guard canOfferTitlePattern else { return }
        isTitlePatternRevealed = true
        activationStore.markTitlePatternRevealed(for: puzzle.puzzleID)
        track(event: .answerRescueRevealed(puzzleID: puzzle.puzzleID, attempts: attempts))
    }

    func submitDifficultyFeedback(_ rating: DailyPuzzleDifficultyRating) {
        guard shouldRequestDifficultyFeedback else { return }
        activationStore.saveDifficultyRating(rating, for: puzzle.puzzleID)
        hasSubmittedDifficultyFeedback = true
        track(
            event: .difficultyRated(
                puzzleID: puzzle.puzzleID,
                rating: rating,
                attempts: attempts
            )
        )
    }

    func trackShareTapped() {
        track(event: .shareTapped(puzzleID: puzzle.puzzleID, attempts: attempts))
    }

    func trackNextPuzzleTapped(source: String) {
        track(event: .nextPuzzleTapped(puzzleID: puzzle.puzzleID, source: source))
    }

    func trackNextPuzzleLoaded(previousPuzzleID: String, puzzleIndex: Int) {
        track(
            event: .nextPuzzleLoaded(
                puzzleID: puzzle.puzzleID,
                previousPuzzleID: previousPuzzleID,
                puzzleIndex: puzzleIndex
            )
        )
    }

    func trackNextPuzzleLoadFailed(reason: String) {
        track(event: .nextPuzzleLoadFailed(puzzleID: puzzle.puzzleID, reason: reason))
    }

    func trackAdOpportunity(placement: String) {
        track(event: .adOpportunity(puzzleID: puzzle.puzzleID, placement: placement))
    }

    func trackRunStarted(runSequence: Int) {
        track(
            event: .runStarted(
                puzzleID: puzzle.puzzleID,
                runSequence: runSequence,
                targetRounds: DailyPuzzleRunState.targetRounds
            )
        )
    }

    func trackRunCompleted(runSequence: Int, state: DailyPuzzleRunState) {
        track(event: .init(name: "movie_quiz_run_scored", metadata: ["points": String(state.quizPoints), "first_try_rounds": String(state.firstTryRounds), "participation_streak": String(state.currentStreak)]))
        track(
            event: .runCompleted(
                puzzleID: puzzle.puzzleID,
                runSequence: runSequence,
                targetRounds: DailyPuzzleRunState.targetRounds,
                completedRounds: state.completedRounds,
                solvedRounds: state.solvedRounds,
                totalAttempts: state.totalAttempts,
                totalHints: state.totalHints,
                currentStreak: state.currentStreak
            )
        )
    }

    func trackRunShared(runSequence: Int, state: DailyPuzzleRunState) {
        track(
            event: .runShared(
                puzzleID: puzzle.puzzleID,
                runSequence: runSequence,
                targetRounds: DailyPuzzleRunState.targetRounds,
                completedRounds: state.completedRounds,
                solvedRounds: state.solvedRounds,
                totalAttempts: state.totalAttempts,
                totalHints: state.totalHints,
                currentStreak: state.currentStreak
            )
        )
    }

    func trackRunContinueTapped(runSequence: Int, state: DailyPuzzleRunState) {
        track(
            event: .runContinueTapped(
                puzzleID: puzzle.puzzleID,
                runSequence: runSequence,
                targetRounds: DailyPuzzleRunState.targetRounds,
                completedRounds: state.completedRounds,
                solvedRounds: state.solvedRounds,
                totalAttempts: state.totalAttempts,
                totalHints: state.totalHints,
                currentStreak: state.currentStreak
            )
        )
    }

    func trackWeeklyGoalUpdated(_ update: DailyPuzzleWeeklyGoalUpdate) {
        track(
            event: .weeklyGoalUpdated(
                puzzleID: puzzle.puzzleID,
                update: update
            )
        )
    }

    func trackHintOfferShown(hintLevel: Int) {
        track(
            event: .hintOfferShown(
                puzzleID: puzzle.puzzleID,
                hintLevel: hintLevel,
                attempts: attempts
            )
        )
    }

    func trackHintOfferTapped(hintLevel: Int) {
        track(
            event: .hintOfferTapped(
                puzzleID: puzzle.puzzleID,
                hintLevel: hintLevel,
                attempts: attempts
            )
        )
    }

    func trackHintRewardGranted(hintLevel: Int) {
        track(
            event: .hintRewardGranted(
                puzzleID: puzzle.puzzleID,
                hintLevel: hintLevel,
                attempts: attempts
            )
        )
    }

    private func track(event: DailyPuzzleAnalyticsEvent) {
        analyticsTracker.track(event: event.withMetadata(buildPuzzleContextMetadata()))
    }

    private func buildPuzzleContextMetadata() -> [String:String] {
        [
            "presentation_id": presentationID,
            "answer_mode": quizState == nil ? "typed" : "image_choice",
            "quiz_points": String(quizPoints),
            "attempts": "\(attempts)",
            "hint_unlocked_count": "\(unlockedHintCount)",
            "puzzle_media_type": puzzle.mediaType.rawValue,
            "puzzle_source": puzzle.source,
            "puzzle_date": puzzle.date,
            "puzzle_index": "\(puzzleIndex)",
            "puzzle_locale": puzzleLocaleIdentifier,
            "puzzle_localization_source": puzzleLocalizationSource.rawValue,
            "solved": "\(isSolved)",
            "terminal_result": isSolved ? "solved" : (didFail ? "failed" : "in_progress"),
            "is_archive": "\(isArchivePuzzle)"
        ]
    }

    private var isArchivePuzzle: Bool {
        !recordsDailyStreak || puzzle.source == "archive" || puzzle.puzzleID.hasPrefix("archive-")
    }

    private func trackSessionEnded(status: String, attempts: Int, at timestamp: Date) {
        let durationSeconds = sessionStartedAt.map { Int(timestamp.timeIntervalSince($0).rounded()) } ?? 0
        track(
            event: .sessionEnded(
                puzzleID: puzzle.puzzleID,
                status: status,
                attempts: attempts,
                unlockedHints: unlockedHintCount,
                durationSeconds: "\(durationSeconds)"
            )
        )
    }


}

struct DailyPuzzleRunState: Equatable {
    static let targetRounds = 4
    static let maxPoints = targetRounds * 3

    private(set) var completedRounds = 0
    private(set) var solvedRounds = 0
    private(set) var quizPoints = 0
    private(set) var firstTryRounds = 0
    private(set) var totalAttempts = 0
    private(set) var totalHints = 0
    private(set) var currentStreak = 0
    private var recordedPuzzleIDs: Set<String> = []

    var failedRounds: Int {
        max(0, completedRounds - solvedRounds)
    }

    var isComplete: Bool {
        completedRounds >= Self.targetRounds
    }

    func displayedRound(for puzzleID: String) -> Int {
        if recordedPuzzleIDs.contains(puzzleID) {
            return max(1, min(completedRounds, Self.targetRounds))
        }

        return min(completedRounds + 1, Self.targetRounds)
    }

    @discardableResult
    mutating func record(
        puzzleID: String,
        solved: Bool,
        attempts: Int,
        hints: Int,
        currentStreak: Int = 0,
        points: Int = 0
    ) -> Bool {
        guard !isComplete, recordedPuzzleIDs.insert(puzzleID).inserted else {
            return false
        }

        quizPoints += max(0, min(3, points))
        firstTryRounds += solved && attempts == 1 ? 1 : 0
        completedRounds += 1
        solvedRounds += solved ? 1 : 0
        totalAttempts += max(0, attempts)
        totalHints += max(0, hints)
        self.currentStreak = max(self.currentStreak, currentStreak)
        return true
    }

    mutating func setParticipationStreak(_ streak: Int) { currentStreak = streak }

    mutating func startNextRun() {
        self = DailyPuzzleRunState()
    }

    var shareText: String {
        var lines = [
            NSLocalizedString("dailyPuzzleRunShareTitle", comment: "Daily Run share title"),
            String(
                format: NSLocalizedString("dailyPuzzleRunSolvedFormat", comment: "Daily Run solved summary"),
                solvedRounds,
                Self.targetRounds
            ),
            String(
                format: NSLocalizedString("dailyPuzzleRunAttemptsHintsFormat", comment: "Daily Run attempts and hints"),
                totalAttempts,
                totalHints
            )
        ]
        lines.append(String(format: NSLocalizedString("movieQuizRunScore", value: "%ld / %ld points · %ld first-try answers", comment: "Movie quiz score"), quizPoints, Self.maxPoints, firstTryRounds))
        if currentStreak > 0 {
            lines.append(
                String(
                    format: NSLocalizedString("dailyPuzzleRunShareStreakFormat", comment: "Daily Run streak"),
                    currentStreak
                )
            )
        }
        lines.append(NSLocalizedString("dailyPuzzleRunShareChallenge", comment: "Daily Run share challenge"))
        return lines.joined(separator: "\n")
    }
}

struct DailyPuzzleWeeklyGoalProgress: Equatable {
    static let targetDays = 5

    let weekID: String
    let completedDays: Int
    let completedToday: Bool

    var targetDays: Int { Self.targetDays }
    var remainingDays: Int { max(0, Self.targetDays - completedDays) }
    var isComplete: Bool { completedDays >= Self.targetDays }
}

enum DailyPuzzleWeeklyGoalOutcome: String, Equatable {
    case progressed
    case completed
    case alreadyCompletedToday = "already_completed_today"
    case alreadyComplete = "already_complete"
}

struct DailyPuzzleWeeklyGoalUpdate: Equatable {
    let progress: DailyPuzzleWeeklyGoalProgress
    let outcome: DailyPuzzleWeeklyGoalOutcome
}

struct DailyPuzzleWeeklyGoalStore {
    private static let storedWeekIDKey = "dailyPuzzleWeeklyGoal.weekID"
    private static let completedDayIDsKey = "dailyPuzzleWeeklyGoal.completedDayIDs"

    private let userDefaults: UserDefaults
    private var calendar: Calendar

    init(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    func progress(on date: Date = Date()) -> DailyPuzzleWeeklyGoalProgress {
        let weekID = weekIdentifier(for: date)
        guard userDefaults.string(forKey: Self.storedWeekIDKey) == weekID else {
            return DailyPuzzleWeeklyGoalProgress(
                weekID: weekID,
                completedDays: 0,
                completedToday: false
            )
        }

        return makeProgress(
            weekID: weekID,
            completedDayIDs: Set(
                userDefaults.stringArray(forKey: Self.completedDayIDsKey) ?? []
            ),
            date: date
        )
    }

    @discardableResult
    func recordCompletedRun(on date: Date = Date()) -> DailyPuzzleWeeklyGoalUpdate {
        let weekID = weekIdentifier(for: date)
        let isCurrentStoredWeek = userDefaults.string(forKey: Self.storedWeekIDKey) == weekID
        var completedDayIDs = isCurrentStoredWeek
            ? Set(userDefaults.stringArray(forKey: Self.completedDayIDsKey) ?? [])
            : []
        let dayID = dayIdentifier(for: date)

        if completedDayIDs.contains(dayID) {
            return DailyPuzzleWeeklyGoalUpdate(
                progress: makeProgress(
                    weekID: weekID,
                    completedDayIDs: completedDayIDs,
                    date: date
                ),
                outcome: .alreadyCompletedToday
            )
        }

        if completedDayIDs.count >= DailyPuzzleWeeklyGoalProgress.targetDays {
            return DailyPuzzleWeeklyGoalUpdate(
                progress: makeProgress(
                    weekID: weekID,
                    completedDayIDs: completedDayIDs,
                    date: date
                ),
                outcome: .alreadyComplete
            )
        }

        completedDayIDs.insert(dayID)
        userDefaults.set(weekID, forKey: Self.storedWeekIDKey)
        userDefaults.set(completedDayIDs.sorted(), forKey: Self.completedDayIDsKey)

        let progress = makeProgress(
            weekID: weekID,
            completedDayIDs: completedDayIDs,
            date: date
        )
        return DailyPuzzleWeeklyGoalUpdate(
            progress: progress,
            outcome: progress.isComplete ? .completed : .progressed
        )
    }

    private func makeProgress(
        weekID: String,
        completedDayIDs: Set<String>,
        date: Date
    ) -> DailyPuzzleWeeklyGoalProgress {
        DailyPuzzleWeeklyGoalProgress(
            weekID: weekID,
            completedDays: min(
                completedDayIDs.count,
                DailyPuzzleWeeklyGoalProgress.targetDays
            ),
            completedToday: completedDayIDs.contains(dayIdentifier(for: date))
        )
    }

    private func weekIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date
        )
        return String(
            format: "%04d-W%02d",
            components.yearForWeekOfYear ?? 0,
            components.weekOfYear ?? 0
        )
    }

    private func dayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

enum DailyPuzzleDifficultyRating: String, CaseIterable, Hashable {
    case tooEasy = "too_easy"
    case justRight = "just_right"
    case tooHard = "too_hard"

    var localizedTitle: String {
        switch self {
        case .tooEasy:
            localizedDailyPuzzleString(
                "dailyPuzzleDifficultyTooEasy",
                defaultValue: "Too easy",
                comment: "Puzzle difficulty feedback: too easy"
            )
        case .justRight:
            localizedDailyPuzzleString(
                "dailyPuzzleDifficultyJustRight",
                defaultValue: "Just right",
                comment: "Puzzle difficulty feedback: just right"
            )
        case .tooHard:
            localizedDailyPuzzleString(
                "dailyPuzzleDifficultyTooHard",
                defaultValue: "Too hard",
                comment: "Puzzle difficulty feedback: too hard"
            )
        }
    }
}

struct DailyPuzzleActivationStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isTitlePatternRevealed(for puzzleID: String) -> Bool {
        defaults.bool(forKey: key("title-pattern-revealed", puzzleID: puzzleID))
    }

    func markTitlePatternRevealed(for puzzleID: String) {
        defaults.set(true, forKey: key("title-pattern-revealed", puzzleID: puzzleID))
    }

    func difficultyRating(for puzzleID: String) -> DailyPuzzleDifficultyRating? {
        guard let rawValue = defaults.string(forKey: key("difficulty-rating", puzzleID: puzzleID)) else {
            return nil
        }
        return DailyPuzzleDifficultyRating(rawValue: rawValue)
    }

    func saveDifficultyRating(_ rating: DailyPuzzleDifficultyRating, for puzzleID: String) {
        defaults.set(rating.rawValue, forKey: key("difficulty-rating", puzzleID: puzzleID))
    }

    private func key(_ suffix: String, puzzleID: String) -> String {
        "daily-puzzle.activation.\(puzzleID).\(suffix)"
    }
}

enum DailyPuzzleHintOfferPolicy {
    static func shouldShow(
        attempts: Int,
        unlockedHintCount: Int,
        puzzleFinished: Bool,
        hasPurchasedTipJar: Bool
    ) -> Bool {
        attempts > 0
            && unlockedHintCount < 2
            && !puzzleFinished
            && !hasPurchasedTipJar
    }
}

struct DailyPuzzleAnalyticsEvent: Equatable {
    let name: String
    let metadata: [String:String]

    static func guessSubmitted(puzzleID: String, attempts: Int) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_guess_submitted",
            metadata: [
                "puzzle_id": puzzleID,
                "attempts": "\(attempts)"
            ]
        )
    }

    static func starterClueShown(
        puzzleID: String,
        titleWordCount: Int
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_starter_clue_shown",
            metadata: [
                "puzzle_id": puzzleID,
                "title_word_count": "\(titleWordCount)"
            ]
        )
    }

    static func answerRescueOffered(
        puzzleID: String,
        attempts: Int
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_answer_rescue_offered",
            metadata: [
                "puzzle_id": puzzleID,
                "attempts": "\(attempts)"
            ]
        )
    }

    static func answerRescueRevealed(
        puzzleID: String,
        attempts: Int
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_answer_rescue_revealed",
            metadata: [
                "puzzle_id": puzzleID,
                "attempts": "\(attempts)"
            ]
        )
    }

    static func difficultyRated(
        puzzleID: String,
        rating: DailyPuzzleDifficultyRating,
        attempts: Int
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_difficulty_rated",
            metadata: [
                "puzzle_id": puzzleID,
                "rating": rating.rawValue,
                "attempts": "\(attempts)"
            ]
        )
    }

    static func hintUnlocked(puzzleID: String, level: Int) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_hint_unlocked",
            metadata: [
                "puzzle_id": puzzleID,
                "hint_level": "\(level)"
            ]
        )
    }

    static func solved(puzzleID: String, attempts: Int) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_solved",
            metadata: [
                "puzzle_id": puzzleID,
                "attempts": "\(attempts)"
            ]
        )
    }

    static func failed(puzzleID: String, attempts: Int) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_failed",
            metadata: [
                "puzzle_id": puzzleID,
                "attempts": "\(attempts)"
            ]
        )
    }

    static func adOpportunity(puzzleID: String, placement: String) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_ad_opportunity",
            metadata: [
                "puzzle_id": puzzleID,
                "placement": placement
            ]
        )
    }

    static func promptShown(puzzleID: String) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_prompt_shown",
            metadata: ["puzzle_id": puzzleID]
        )
    }

    static func promptResponse(puzzleID: String, granted: Bool) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_prompt_response",
            metadata: [
                "puzzle_id": puzzleID,
                "granted": granted.description
            ]
        )
    }

    static func opened(puzzleID: String, source: String) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_opened",
            metadata: [
                "puzzle_id": puzzleID,
                "source": source
            ]
        )
    }

    static func shareTapped(puzzleID: String, attempts: Int) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_share_tapped",
            metadata: [
                "puzzle_id": puzzleID,
                "attempts": "\(attempts)"
            ]
        )
    }

    static func nextPuzzleTapped(puzzleID: String, source: String) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_next_tapped",
            metadata: [
                "puzzle_id": puzzleID,
                "source": source
            ]
        )
    }

    static func nextPuzzleLoaded(
        puzzleID: String,
        previousPuzzleID: String,
        puzzleIndex: Int
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_next_loaded",
            metadata: [
                "puzzle_id": puzzleID,
                "previous_puzzle_id": previousPuzzleID,
                "puzzle_index": "\(puzzleIndex)"
            ]
        )
    }

    static func nextPuzzleLoadFailed(puzzleID: String, reason: String) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_next_load_failed",
            metadata: [
                "puzzle_id": puzzleID,
                "reason": reason
            ]
        )
    }

    static func remindersToggleChanged(enabled: Bool, source: String) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_reminders_toggle_changed",
            metadata: [
                "enabled": enabled.description,
                "source": source
            ]
        )
    }

    static func openRequested(source: String) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_open_requested",
            metadata: ["source": source]
        )
    }

    static func sessionStarted(
        puzzleID: String,
        source: String,
        puzzleMediaType: String,
        puzzleSource: String
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_session_started",
            metadata: [
                "puzzle_id": puzzleID,
                "source": source,
                "puzzle_media_type": puzzleMediaType,
                "puzzle_source": puzzleSource
            ]
        )
    }

    static func sessionEnded(
        puzzleID: String,
        status: String,
        attempts: Int,
        unlockedHints: Int,
        durationSeconds: String
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_session_ended",
            metadata: [
                "puzzle_id": puzzleID,
                "status": status,
                "attempts": "\(attempts)",
                "unlocked_hints": "\(unlockedHints)",
                "duration_seconds": durationSeconds
            ]
        )
    }

    static func runStarted(
        puzzleID: String,
        runSequence: Int,
        targetRounds: Int
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_run_started",
            metadata: [
                "puzzle_id": puzzleID,
                "run_sequence": "\(runSequence)",
                "target_rounds": "\(targetRounds)"
            ]
        )
    }

    static func runCompleted(
        puzzleID: String,
        runSequence: Int,
        targetRounds: Int,
        completedRounds: Int,
        solvedRounds: Int,
        totalAttempts: Int,
        totalHints: Int,
        currentStreak: Int = 0
    ) -> DailyPuzzleAnalyticsEvent {
        runEvent(
            name: "daily_puzzle_run_completed",
            puzzleID: puzzleID,
            runSequence: runSequence,
            targetRounds: targetRounds,
            completedRounds: completedRounds,
            solvedRounds: solvedRounds,
            totalAttempts: totalAttempts,
            totalHints: totalHints,
            currentStreak: currentStreak
        )
    }

    static func runShared(
        puzzleID: String,
        runSequence: Int,
        targetRounds: Int,
        completedRounds: Int,
        solvedRounds: Int,
        totalAttempts: Int,
        totalHints: Int,
        currentStreak: Int = 0
    ) -> DailyPuzzleAnalyticsEvent {
        runEvent(
            name: "daily_puzzle_run_shared",
            puzzleID: puzzleID,
            runSequence: runSequence,
            targetRounds: targetRounds,
            completedRounds: completedRounds,
            solvedRounds: solvedRounds,
            totalAttempts: totalAttempts,
            totalHints: totalHints,
            currentStreak: currentStreak
        )
    }

    static func runContinueTapped(
        puzzleID: String,
        runSequence: Int,
        targetRounds: Int,
        completedRounds: Int,
        solvedRounds: Int,
        totalAttempts: Int,
        totalHints: Int,
        currentStreak: Int = 0
    ) -> DailyPuzzleAnalyticsEvent {
        runEvent(
            name: "daily_puzzle_run_continue_tapped",
            puzzleID: puzzleID,
            runSequence: runSequence,
            targetRounds: targetRounds,
            completedRounds: completedRounds,
            solvedRounds: solvedRounds,
            totalAttempts: totalAttempts,
            totalHints: totalHints,
            currentStreak: currentStreak
        )
    }

    private static func runEvent(
        name: String,
        puzzleID: String,
        runSequence: Int,
        targetRounds: Int,
        completedRounds: Int,
        solvedRounds: Int,
        totalAttempts: Int,
        totalHints: Int,
        currentStreak: Int
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: name,
            metadata: [
                "puzzle_id": puzzleID,
                "run_sequence": "\(runSequence)",
                "target_rounds": "\(targetRounds)",
                "completed_rounds": "\(completedRounds)",
                "solved_rounds": "\(solvedRounds)",
                "failed_rounds": "\(max(0, completedRounds - solvedRounds))",
                "total_attempts": "\(max(0, totalAttempts))",
                "total_hints": "\(max(0, totalHints))",
                "current_streak": "\(max(0, currentStreak))"
            ]
        )
    }

    static func weeklyGoalUpdated(
        puzzleID: String,
        update: DailyPuzzleWeeklyGoalUpdate
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: "daily_puzzle_weekly_goal_updated",
            metadata: [
                "puzzle_id": puzzleID,
                "week_id": update.progress.weekID,
                "outcome": update.outcome.rawValue,
                "completed_days": "\(update.progress.completedDays)",
                "target_days": "\(update.progress.targetDays)",
                "remaining_days": "\(update.progress.remainingDays)",
                "completed_today": "\(update.progress.completedToday)",
                "goal_complete": "\(update.progress.isComplete)"
            ]
        )
    }

    static func hintOfferShown(
        puzzleID: String,
        hintLevel: Int,
        attempts: Int
    ) -> DailyPuzzleAnalyticsEvent {
        hintOfferEvent(
            name: "daily_puzzle_hint_offer_shown",
            puzzleID: puzzleID,
            hintLevel: hintLevel,
            attempts: attempts
        )
    }

    static func hintOfferTapped(
        puzzleID: String,
        hintLevel: Int,
        attempts: Int
    ) -> DailyPuzzleAnalyticsEvent {
        hintOfferEvent(
            name: "daily_puzzle_hint_offer_tapped",
            puzzleID: puzzleID,
            hintLevel: hintLevel,
            attempts: attempts
        )
    }

    static func hintRewardGranted(
        puzzleID: String,
        hintLevel: Int,
        attempts: Int
    ) -> DailyPuzzleAnalyticsEvent {
        hintOfferEvent(
            name: "daily_puzzle_hint_reward_granted",
            puzzleID: puzzleID,
            hintLevel: hintLevel,
            attempts: attempts
        )
    }

    private static func hintOfferEvent(
        name: String,
        puzzleID: String,
        hintLevel: Int,
        attempts: Int
    ) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: name,
            metadata: [
                "puzzle_id": puzzleID,
                "hint_level": "\(hintLevel)",
                "attempts": "\(attempts)"
            ]
        )
    }

    func withMetadata(_ additionalMetadata: [String:String]) -> DailyPuzzleAnalyticsEvent {
        .init(
            name: name,
            metadata: additionalMetadata.merging(metadata) { _, eventValue in eventValue }
        )
    }
}

protocol DailyPuzzleAnalyticsTracking {
    func track(event: DailyPuzzleAnalyticsEvent)
}

struct DailyPuzzleLiveAnalyticsTracker: DailyPuzzleAnalyticsTracking {
    func track(event: DailyPuzzleAnalyticsEvent) {
        CronicaTelemetry.shared.capture(
            event.name,
            properties: event.metadata.reduce(into: [String: Any]()) { payload, item in
                payload[item.key] = item.value
            }
        )
    }
}

struct DailyPuzzleService {
    enum ServiceError: LocalizedError {
        case invalidResponse
        case badStatusCode(Int)
    }

    private enum FirestoreFallbackMode {
        case latest
        case random
    }

    private struct FirestoreDocumentResponse: Decodable {
        let name: String
        let fields: [String: FirestoreValue]
    }

    private struct FirestoreCollectionResponse: Decodable {
        let documents: [FirestoreDocumentResponse]?
    }

    private struct FirestoreArrayValue: Decodable {
        let values: [FirestoreValue]?
    }

    private struct FirestoreMapValue: Decodable {
        let fields: [String: FirestoreValue]?
    }

    private enum FirestoreValue: Decodable {
        case string(String)
        case integer(Int)
        case array([FirestoreValue])
        case map([String: FirestoreValue])
        case unknown

        private enum CodingKeys: String, CodingKey {
            case stringValue
            case integerValue
            case arrayValue
            case mapValue
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let value = try container.decodeIfPresent(String.self, forKey: .stringValue) {
                self = .string(value)
                return
            }
            if let value = try container.decodeIfPresent(String.self, forKey: .integerValue),
               let integer = Int(value) {
                self = .integer(integer)
                return
            }
            if let arrayValue = try container.decodeIfPresent(FirestoreArrayValue.self, forKey: .arrayValue) {
                self = .array(arrayValue.values ?? [])
                return
            }
            if let mapValue = try container.decodeIfPresent(FirestoreMapValue.self, forKey: .mapValue) {
                self = .map(mapValue.fields ?? [:])
                return
            }
            self = .unknown
        }

        var stringValue: String? {
            if case .string(let value) = self {
                return value
            }
            return nil
        }

        var integerValue: Int? {
            if case .integer(let value) = self {
                return value
            }
            return nil
        }

        var arrayValues: [FirestoreValue]? {
            if case .array(let values) = self {
                return values
            }
            return nil
        }

        var mapValues: [String: FirestoreValue]? {
            if case .map(let values) = self {
                return values
            }
            return nil
        }
    }

    private static let developerModeKey = "displayDeveloperSettings"
    private static let developerModalRetryCount = 4

    let session: URLSession
    let latestPuzzleURL: URL?
    let randomPuzzleURL: URL?
    let firestoreLatestDocumentURL: URL?
    let firestoreCollectionURL: URL?
    let userDefaults: UserDefaults
    let isDebugBuild: Bool
    let randomUnitValue: () -> Double
    let preferFirestorePrimary: Bool

    init(
        session: URLSession = .shared,
        latestPuzzleURL: URL? = Key.dailyPuzzleLatestURL,
        randomPuzzleURL: URL? = Key.dailyPuzzleRandomURL,
        firestoreLatestDocumentURL: URL? = Key.dailyPuzzleFirestoreLatestURL,
        firestoreCollectionURL: URL? = Key.dailyPuzzleFirestoreCollectionURL,
        userDefaults: UserDefaults = .standard,
        isDebugBuild: Bool = _isDebugAssertConfiguration(),
        randomUnitValue: @escaping () -> Double = { Double.random(in: 0 ..< 1) },
        preferFirestorePrimary: Bool = false
    ) {
        self.session = session
        self.latestPuzzleURL = latestPuzzleURL
        self.randomPuzzleURL = randomPuzzleURL
        self.firestoreLatestDocumentURL = firestoreLatestDocumentURL
        self.firestoreCollectionURL = firestoreCollectionURL
        self.userDefaults = userDefaults
        self.isDebugBuild = isDebugBuild
        self.randomUnitValue = randomUnitValue
        self.preferFirestorePrimary = preferFirestorePrimary
    }

    func fetchLatestPuzzle() async throws -> DailyPuzzle {
        if preferFirestorePrimary {
            if shouldUseDeveloperRandomMode {
                do {
                    if let firestoreRandom = try await fetchFirestorePuzzle(mode: .random) {
                        logTelemetry("Loaded puzzle from Firestore random collection (primary).")
                        return firestoreRandom
                    }
                } catch {
                    logTelemetry("Firestore random collection fetch failed.", error: error)
                }

                do {
                    if let firestoreLatest = try await fetchFirestorePuzzle(mode: .latest) {
                        logTelemetry("Loaded puzzle from Firestore latest document (random fallback).")
                        return firestoreLatest
                    }
                } catch {
                    logTelemetry("Firestore latest fetch failed after random collection failure.", error: error)
                }
                logTelemetry("Firestore primary sources unavailable, falling back to Cloud Functions endpoints.")
            } else {
                do {
                    if let firestoreLatest = try await fetchFirestorePuzzle(mode: .latest) {
                        logTelemetry("Loaded puzzle from Firestore latest document (primary).")
                        return firestoreLatest
                    }
                    logTelemetry("Firestore latest document returned no puzzle; falling back to Cloud Functions endpoint.")
                } catch {
                    logTelemetry("Firestore latest fetch failed in primary mode.", error: error)
                }
            }
        }

        if shouldUseDeveloperRandomMode {
            do {
                let puzzle = try await fetchPuzzle(from: randomPuzzleURL ?? latestPuzzleURL)
                logTelemetry("Loaded puzzle from Cloud Functions random/latest endpoint.")
                return puzzle
            } catch {
                logTelemetry("Cloud Functions random/latest endpoint failed in developer mode.", error: error)
                // If random fetch fails in developer mode, fall back to latest puzzle endpoint.
                if randomPuzzleURL != nil, latestPuzzleURL != nil {
                    if let latestPuzzle = try? await fetchPuzzle(from: latestPuzzleURL) {
                        logTelemetry("Loaded puzzle from Cloud Functions latest endpoint after random failure.")
                        return latestPuzzle
                    }
                    logTelemetry("Cloud Functions latest endpoint fallback failed in developer mode.")
                }

                do {
                    if let firestoreRandom = try await fetchFirestorePuzzle(mode: .random) {
                        logTelemetry("Loaded puzzle from Firestore random collection after Cloud Functions failure.")
                        return firestoreRandom
                    }
                } catch {
                    logTelemetry("Firestore random collection fallback failed in developer mode.", error: error)
                }

                do {
                    if let firestoreLatest = try await fetchFirestorePuzzle(mode: .latest) {
                        logTelemetry("Loaded puzzle from Firestore latest document after random fallback failure.")
                        return firestoreLatest
                    }
                } catch {
                    logTelemetry("Firestore latest fallback failed in developer mode.", error: error)
                }
                logTelemetry("All remote puzzle sources failed in developer mode; propagating original error.")
                throw error
            }
        }

        do {
            let puzzle = try await fetchPuzzle(from: latestPuzzleURL)
            logTelemetry("Loaded puzzle from Cloud Functions latest endpoint.")
            return puzzle
        } catch {
            logTelemetry("Cloud Functions latest endpoint failed; trying Firestore latest fallback.", error: error)
            do {
                if let firestoreLatest = try await fetchFirestorePuzzle(mode: .latest) {
                    logTelemetry("Loaded puzzle from Firestore latest document after Cloud Functions failure.")
                    return firestoreLatest
                }
            } catch {
                logTelemetry("Firestore latest fallback failed after Cloud Functions latest failure.", error: error)
            }
            logTelemetry("All remote puzzle sources failed; propagating original error.")
            throw error
        }
    }

    func fallbackPuzzle() -> DailyPuzzle {
        if shouldUseDeveloperRandomMode {
            let samples = DailyPuzzle.developerSamples
            guard !samples.isEmpty else {
                return .sample
            }
            let boundedRandom = max(0, min(0.999999, randomUnitValue()))
            let index = Int(Double(samples.count) * boundedRandom)
            return samples[index]
        }
        return .sample
    }

    var isDeveloperSampleModeEnabled: Bool {
        shouldUseDeveloperRandomMode
    }

    func puzzleForModalOpen(currentPuzzleID: String?) async throws -> DailyPuzzle {
        guard shouldUseDeveloperRandomMode else {
            return try await fetchLatestPuzzle()
        }

        var latestCandidate: DailyPuzzle?
        for _ in 0 ..< Self.developerModalRetryCount {
            let candidate = try await fetchLatestPuzzle()
            latestCandidate = candidate
            guard let currentPuzzleID else { return candidate }
            if candidate.puzzleID != currentPuzzleID {
                return candidate
            }
        }
        if let latestCandidate {
            return latestCandidate
        }
        return try await fetchLatestPuzzle()
    }

    func fetchNextPuzzle(excluding currentPuzzleID: String?, excludingIDs: Set<String> = [], excludingMovieIDs: Set<Int> = []) async throws -> DailyPuzzle {
        var fetchError: Error?

        if randomPuzzleURL != nil {
            for _ in 0 ..< Self.developerModalRetryCount {
                do {
                    let candidate = try await fetchPuzzle(from: randomPuzzleURL)
                    if candidate.puzzleID != currentPuzzleID && !excludingIDs.contains(candidate.puzzleID) && !excludingMovieIDs.contains(candidate.tmdbID) {
                        return candidate
                    }
                } catch {
                    fetchError = error
                    break
                }
            }
        }

        if firestoreCollectionURL != nil {
            for _ in 0 ..< Self.developerModalRetryCount {
                do {
                    guard let candidate = try await fetchFirestorePuzzle(mode: .random) else { break }
                    if candidate.puzzleID != currentPuzzleID && !excludingIDs.contains(candidate.puzzleID) && !excludingMovieIDs.contains(candidate.tmdbID) {
                        return candidate
                    }
                } catch {
                    fetchError = fetchError ?? error
                    break
                }
            }
        }

        if let fetchError {
            throw fetchError
        }
        throw ServiceError.invalidResponse
    }

    private var shouldUseDeveloperRandomMode: Bool {
        isDebugBuild && userDefaults.bool(forKey: Self.developerModeKey)
    }

    private func fetchPuzzle(from url: URL?) async throws -> DailyPuzzle {
        guard let url else { return fallbackPuzzle() }
        let data = try await fetchData(from: url)
        return try JSONDecoder().decode(DailyPuzzle.self, from: data)
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ServiceError.badStatusCode(httpResponse.statusCode)
        }
        return data
    }

    private func fetchFirestorePuzzle(mode: FirestoreFallbackMode) async throws -> DailyPuzzle? {
        switch mode {
        case .latest:
            guard let url = firestoreLatestDocumentURL else { return nil }
            let data = try await fetchData(from: url)
            let document = try JSONDecoder().decode(FirestoreDocumentResponse.self, from: data)
            return mapFirestoreDocumentToPuzzle(document)
        case .random:
            guard let url = firestoreCollectionURL else { return nil }
            let data = try await fetchData(from: url)
            let collection = try JSONDecoder().decode(FirestoreCollectionResponse.self, from: data)
            let candidates = (collection.documents ?? [])
                .filter { !$0.name.hasSuffix("/latest") }
                .compactMap(mapFirestoreDocumentToPuzzle)
            guard !candidates.isEmpty else { return nil }
            let boundedRandom = max(0, min(0.999999, randomUnitValue()))
            let index = Int(Double(candidates.count) * boundedRandom)
            return candidates[index]
        }
    }

    private func mapFirestoreDocumentToPuzzle(_ document: FirestoreDocumentResponse) -> DailyPuzzle? {
        let fields = document.fields
        guard
            let date = fields["date"]?.stringValue,
            let puzzleID = fields["puzzle_id"]?.stringValue,
            let tmdbID = fields["tmdb_id"]?.integerValue,
            let emojiClue = fields["emoji_clue"]?.stringValue,
            let hint1 = fields["hint_1"]?.stringValue,
            let hint2 = fields["hint_2"]?.stringValue
        else {
            return nil
        }

        let mediaTypeRaw = fields["media_type"]?.stringValue ?? DailyPuzzleMediaType.movie.rawValue
        let mediaType = DailyPuzzleMediaType(rawValue: mediaTypeRaw) ?? .movie
        let title = fields["title"]?.stringValue
        let acceptedAnswers = fields["accepted_answers"]?.arrayValues?
            .compactMap { $0.stringValue }
            .filter { !$0.isEmpty } ?? []
        let source = fields["source"]?.stringValue ?? "firestore"
        let generatedAt = fields["generated_at"]?.stringValue ?? ""
        let localizations = fields["localizations"]?.mapValues?.reduce(
            into: [String: DailyPuzzleLocalizedContent]()
        ) { result, entry in
            guard let localizedFields = entry.value.mapValues,
                  let localizedTitle = localizedFields["title"]?.stringValue,
                  let localizedEmojiClue = localizedFields["emoji_clue"]?.stringValue,
                  let localizedHint1 = localizedFields["hint_1"]?.stringValue,
                  let localizedHint2 = localizedFields["hint_2"]?.stringValue
            else {
                return
            }
            let localizedAnswers = localizedFields["accepted_answers"]?.arrayValues?
                .compactMap { $0.stringValue }
                .filter { !$0.isEmpty } ?? []
            guard !localizedAnswers.isEmpty else { return }
            result[entry.key] = DailyPuzzleLocalizedContent(
                title: localizedTitle,
                emojiClue: localizedEmojiClue,
                hint1: localizedHint1,
                hint2: localizedHint2,
                acceptedAnswers: localizedAnswers
            )
        }

        return DailyPuzzle(
            date: date,
            puzzleID: puzzleID,
            mediaType: mediaType,
            tmdbID: tmdbID,
            title: title,
            emojiClue: emojiClue,
            hint1: hint1,
            hint2: hint2,
            acceptedAnswers: acceptedAnswers,
            localizations: localizations,
            source: source,
            generatedAt: generatedAt
        )
    }

    private func logTelemetry(_ message: String, error: Error? = nil) {
        let payload: String
        if let error {
            payload = "\(message) error=\(String(describing: error))"
        } else {
            payload = message
        }
        CronicaTelemetry.shared.handleMessage(payload, for: "DailyPuzzleService")
    }
}

@MainActor
enum DailyPuzzleModalOpenLoader {
    static func refreshViewModelForOpen(
        currentPuzzleID: String?,
        service: DailyPuzzleService
    ) async -> DailyPuzzleViewModel {
        do {
            let refreshedPuzzle = try await service.puzzleForModalOpen(currentPuzzleID: currentPuzzleID)
            return DailyPuzzleViewModel(puzzle: refreshedPuzzle)
        } catch {
            return DailyPuzzleViewModel(puzzle: service.fallbackPuzzle())
        }
    }
}

// MARK: - Puzzle Archive

@MainActor
@Observable
final class ArchivePuzzleViewModel {
    static let maxAttempts = 6

    let puzzle: DailyPuzzle
    private let progressStore: DailyPuzzleProgressStore
    private let analyticsTracker: DailyPuzzleAnalyticsTracking
    private var sessionStartedAt: Date?

    var attempts = 0
    var unlockedHintCount = 0
    var isSolved = false
    var didFail = false
    var solveCelebrationCount = 0

    // Unused but required by DailyPuzzleGameView interface compatibility
    var shouldShowNotificationPrompt = false

    var isFailed: Bool { attempts >= Self.maxAttempts && !isSolved }

    init(
        puzzle: DailyPuzzle,
        progressStore: DailyPuzzleProgressStore = DailyPuzzleProgressStore(),
        analyticsTracker: DailyPuzzleAnalyticsTracking = DailyPuzzleLiveAnalyticsTracker()
    ) {
        self.puzzle = puzzle
        self.progressStore = progressStore
        self.analyticsTracker = analyticsTracker
        self.sessionStartedAt = nil

        if let progress = progressStore.load(puzzleID: puzzle.puzzleID) {
            attempts = progress.attempts
            unlockedHintCount = progress.unlockedHintCount
            isSolved = progress.solved
            if !isSolved && attempts >= Self.maxAttempts {
                didFail = true
            }
        }
    }

    var starRating: Int {
        guard isSolved else { return 0 }
        return DailyPuzzle.starRating(for: attempts)
    }

    var cardStatusText: String {
        if isSolved {
            return "\(starRating) Star\(starRating == 1 ? "" : "s") ⭐"
        }
        return NSLocalizedString("puzzleArchiveUnsolved", comment: "Unsolved puzzle badge")
    }

    var shareResultText: String? {
        guard isSolved else { return nil }
        let stars = String(repeating: "\u{2B50}", count: starRating)
        let puzzleNumber = puzzle.puzzleID.replacingOccurrences(of: "archive-", with: "")
        return [
            "\u{1F3AC} Puzzle Archive #\(puzzleNumber) \u{2014} \(stars) (\(attempts)/\(Self.maxAttempts))",
            "Play at https://apps.apple.com/app/id455556959"
        ].joined(separator: "\n")
    }

    func submitGuess(_ guess: String, notificationStatus: UNAuthorizationStatus, now: Date = Date()) {
        guard !isSolved, !didFail else { return }
        guard !guess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let previousHintCount = unlockedHintCount
        attempts += 1
        if attempts >= 2 { unlockedHintCount = max(unlockedHintCount, 1) }
        if attempts >= 4 { unlockedHintCount = max(unlockedHintCount, 2) }

        track(event: .guessSubmitted(puzzleID: puzzle.puzzleID, attempts: attempts))

        if unlockedHintCount > previousHintCount {
            for level in (previousHintCount + 1)...unlockedHintCount {
                track(event: .hintUnlocked(puzzleID: puzzle.puzzleID, level: level))
            }
        }

        if puzzle.matches(guess: guess) {
            isSolved = true
            solveCelebrationCount += 1
            // NOTE: No streak update for archive puzzles
            track(event: .solved(puzzleID: puzzle.puzzleID, attempts: attempts))
            trackSessionEnded(status: "solved", attempts: attempts, at: now)
        }

        if !isSolved && attempts >= Self.maxAttempts {
            didFail = true
            trackSessionEnded(status: "failed", attempts: attempts, at: now)
        }

        let progress = DailyPuzzleProgress(
            puzzleID: puzzle.puzzleID,
            solved: isSolved,
            attempts: attempts,
            unlockedHintCount: unlockedHintCount,
            solvedAt: isSolved ? now : nil
        )
        progressStore.save(progress)
    }

    @discardableResult
    func unlockNextHint(expectedLevel: Int? = nil) -> Bool {
        guard !isSolved, !didFail, unlockedHintCount < 2,
              expectedLevel == nil || expectedLevel == unlockedHintCount + 1 else { return false }
        unlockedHintCount += 1
        let progress = DailyPuzzleProgress(
            puzzleID: puzzle.puzzleID,
            solved: isSolved,
            attempts: attempts,
            unlockedHintCount: unlockedHintCount,
            solvedAt: nil
        )
        progressStore.save(progress)
        track(event: .hintUnlocked(puzzleID: puzzle.puzzleID, level: unlockedHintCount))
        return true
    }

    func markNotificationPromptHandled(granted: Bool) {}
    func trackOpened(source: String) {
        if sessionStartedAt == nil {
            sessionStartedAt = Date()
            track(event: .sessionStarted(
                puzzleID: puzzle.puzzleID,
                source: source,
                puzzleMediaType: puzzle.mediaType.rawValue,
                puzzleSource: puzzle.source
            ))
        }
        track(event: .opened(puzzleID: puzzle.puzzleID, source: source))
    }
    func trackShareTapped() {
        track(event: .shareTapped(puzzleID: puzzle.puzzleID, attempts: attempts))
    }
    func trackNextPuzzleTapped(source: String) {}

    private func track(event: DailyPuzzleAnalyticsEvent) {
        analyticsTracker.track(event: event.withMetadata(buildPuzzleContextMetadata()))
    }

    private func buildPuzzleContextMetadata() -> [String:String] {
        [
            "attempts": "\(attempts)",
            "hint_unlocked_count": "\(unlockedHintCount)",
            "puzzle_media_type": puzzle.mediaType.rawValue,
            "puzzle_source": puzzle.source,
            "puzzle_date": puzzle.date,
            "solved": "\(isSolved)",
            "is_archive": "\(isArchivePuzzle)"
        ]
    }

    private var isArchivePuzzle: Bool {
        puzzle.source == "archive" || puzzle.puzzleID.hasPrefix("archive-")
    }

    private func trackSessionEnded(status: String, attempts: Int, at timestamp: Date) {
        let durationSeconds = sessionStartedAt.map { Int(timestamp.timeIntervalSince($0).rounded()) } ?? 0
        track(
            event: .sessionEnded(
                puzzleID: puzzle.puzzleID,
                status: status,
                attempts: attempts,
                unlockedHints: unlockedHintCount,
                durationSeconds: "\(durationSeconds)"
            )
        )
    }
}

@MainActor
@Observable
final class PuzzleArchiveViewModel {
    let puzzles: [DailyPuzzle]
    private let progressStore: DailyPuzzleProgressStore

    init(
        puzzles: [DailyPuzzle] = DailyPuzzle.archivePuzzles,
        progressStore: DailyPuzzleProgressStore = DailyPuzzleProgressStore()
    ) {
        self.puzzles = puzzles
        self.progressStore = progressStore
    }

    var solvedCount: Int {
        puzzles.filter { progressStore.load(puzzleID: $0.puzzleID)?.solved == true }.count
    }

    var totalStars: Int {
        puzzles.compactMap { puzzle -> Int? in
            guard let progress = progressStore.load(puzzleID: puzzle.puzzleID),
                  progress.solved else { return nil }
            if let quiz = progress.quizState, quiz.importedLegacyResult != true {
                return quiz.points
            }
            return DailyPuzzle.starRating(for: progress.attempts)
        }.reduce(0, +)
    }

    var maxStars: Int { puzzles.count * 3 }

    func progress(for puzzleID: String) -> DailyPuzzleProgress? {
        progressStore.load(puzzleID: puzzleID)
    }

    func refresh() {
        // Trigger observation update by reading stores
        _ = solvedCount
    }
}

/// Enrich existing daily records without requiring a server migration. Legacy clients
/// keep their original puzzle format; title choices use the app's TMDb locale.
@MainActor
enum MovieQuizRoundLoader {
    private static func fetchMedia(id: Int, type: MediaType) async throws -> MovieQuizMedia {
        try await fetch(path: "\(type.rawValue)/\(id)", append: "recommendations,images")
    }

    private static func fetchCatalog(type: MediaType) async throws -> [ItemContent] {
        let result: ItemContentResponse = try await fetch(path: "\(type.rawValue)/popular")
        return result.results
    }

    private static func fetch<T: Decodable>(path: String, append: String? = nil) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = "/3/" + path
        components.queryItems = [
            .init(name: "api_key", value: Key.tmdbApi),
            .init(name: "language", value: Locale.userLang),
            .init(name: "include_image_language", value: "null")
        ]
        if let append { components.queryItems?.append(.init(name: "append_to_response", value: append)) }
        guard let url = components.url else { throw DailyPuzzleService.ServiceError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            throw DailyPuzzleService.ServiceError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    static func load(puzzle: DailyPuzzle, roundIndex: Int) async throws -> MovieQuizRound {
        let fallback = DailyPuzzle.developerSamples.filter { $0.tmdbID != puzzle.tmdbID && !puzzle.matches(guess: $0.title ?? "") }
        let type: MediaType = puzzle.mediaType == .movie ? .movie : .tvShow
        var item: MovieQuizMedia?
        var popular: [ItemContent] = []
#if DEBUG
        let fixture = ProcessInfo.processInfo.arguments.contains("--movie-quiz-fixture")
#else
        let fixture = false
#endif
        if !fixture {
            async let details = try? fetchMedia(id: puzzle.tmdbID, type: type)
            async let catalog = try? fetchCatalog(type: type)
            (item, popular) = await (details, catalog ?? [])
        }
        try Task.checkCancellation()
        let answer = MovieQuizChoice(id: puzzle.tmdbID, title: item?.title ?? item?.name ?? puzzle.title ?? puzzle.acceptedAnswers.first ?? "")
        guard !answer.title.isEmpty else { throw DailyPuzzleService.ServiceError.invalidResponse }
        let familiar = fallback.map { MovieQuizChoice(id: $0.tmdbID, title: NSLocalizedString("movieQuizTitle\($0.tmdbID)", value: $0.title ?? "", comment: "Familiar film title")) }
        let related = (item?.recommendations?.results ?? []).filter {
            $0.adult != true && $0.id != puzzle.tmdbID && !puzzle.matches(guess: $0.title ?? $0.name ?? "")
        }.map { MovieQuizChoice(id: $0.id, title: $0.title ?? $0.name ?? "") }
        let broad = popular.filter {
            $0.adult != true && $0.id != puzzle.tmdbID && !puzzle.matches(guess: $0.title ?? $0.name ?? "")
        }.map { MovieQuizChoice(id: $0.id, title: $0.title ?? $0.name ?? "") }
        // Rotate alternatives daily; do not make the correct film the lone new title
        // among the same three distractors on every visit.
        let pool = broad.isEmpty ? familiar : broad
        let offset = fixture ? 0 : puzzle.puzzleID.utf8.reduce(0) { ($0 + Int($1)) % max(1, pool.count) }
        let varied = Array(pool.dropFirst(offset)) + Array(pool.prefix(offset))
        let index = (max(1, roundIndex) - 1) % DailyPuzzleRunState.targetRounds
        let candidates: [MovieQuizChoice]
        switch index {
        case 0: candidates = varied + familiar + related
        case 1: candidates = Array(related.prefix(1)) + varied + familiar + related
        default: candidates = related + varied + familiar
        }
        let choices = MovieQuizRound.choices(answer: answer, candidates: candidates, seed: puzzle.puzzleID)
        guard choices.count == 4 else { throw DailyPuzzleService.ServiceError.invalidResponse }
        return .init(answerID: puzzle.tmdbID, choices: choices, backdropPath: item?.textlessBackdropPath, posterPath: item?.posterPath)
    }
}
