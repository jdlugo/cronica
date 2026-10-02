import Foundation

enum ReviewPromptMilestone: String, CaseIterable, Equatable {
    case canonicalDailyPuzzleSolved = "canonical_daily_puzzle_solved"
    case dailyRunCompleted = "daily_run_completed"
    case fifthWatchlistItem = "fifth_watchlist_item"
}

enum ReviewPromptSuppressionReason: String, Equatable {
    case onboardingActive = "onboarding_active"
    case blockingPresentationActive = "blocking_presentation_active"
    case fullScreenAdActive = "full_screen_ad_active"
    case insufficientActiveDays = "insufficient_active_days"
    case noQualifyingMilestone = "no_qualifying_milestone"
    case sameAppVersion = "same_app_version"
    case cooldownActive = "cooldown_active"
}

enum ReviewPromptDecision: Equatable {
    case eligible(ReviewPromptMilestone)
    case suppressed(ReviewPromptSuppressionReason)
}

struct ReviewPromptContext: Equatable {
    let onboardingActive: Bool
    let blockingPresentationActive: Bool
    let fullScreenAdActive: Bool

    static let clear = ReviewPromptContext(
        onboardingActive: false,
        blockingPresentationActive: false,
        fullScreenAdActive: false
    )
}

final class ReviewPromptCoordinator {
    static let shared = ReviewPromptCoordinator()
    static let minimumActiveDays = 3
    static let cooldownDays = 180
    static let debugEligibilityArgument = "--review-prompt-eligible-preview"

    private enum Keys {
        static let activeDayIDs = "reviewPrompt.activeDayIDs"
        static let milestones = "reviewPrompt.milestones"
        static let lastRequestVersion = "reviewPrompt.lastRequestVersion"
        static let lastRequestDate = "reviewPrompt.lastRequestDate"
    }

    private let userDefaults: UserDefaults
    private var calendar: Calendar

    init(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    var activeDayCount: Int {
        Set(userDefaults.stringArray(forKey: Keys.activeDayIDs) ?? []).count
    }

    var earnedMilestones: [ReviewPromptMilestone] {
        let stored = Set(userDefaults.stringArray(forKey: Keys.milestones) ?? [])
        return ReviewPromptMilestone.allCases.filter { stored.contains($0.rawValue) }
    }

    var lastRequestVersion: String? {
        userDefaults.string(forKey: Keys.lastRequestVersion)
    }

    func recordActiveDay(on date: Date = Date()) {
        var dayIDs = Set(userDefaults.stringArray(forKey: Keys.activeDayIDs) ?? [])
        dayIDs.insert(dayIdentifier(for: date))
        userDefaults.set(Array(dayIDs.sorted().suffix(370)), forKey: Keys.activeDayIDs)
    }

    func recordMilestone(_ milestone: ReviewPromptMilestone) {
        var milestones = Set(userDefaults.stringArray(forKey: Keys.milestones) ?? [])
        guard milestones.insert(milestone.rawValue).inserted else { return }
        userDefaults.set(milestones.sorted(), forKey: Keys.milestones)
        CronicaTelemetry.shared.capture(
            "review_prompt_milestone_earned",
            properties: ["milestone": milestone.rawValue]
        )
    }

    func decision(
        now: Date = Date(),
        appVersion: String,
        context: ReviewPromptContext
    ) -> ReviewPromptDecision {
        if context.onboardingActive {
            return .suppressed(.onboardingActive)
        }
        if context.blockingPresentationActive {
            return .suppressed(.blockingPresentationActive)
        }
        if context.fullScreenAdActive {
            return .suppressed(.fullScreenAdActive)
        }
        if activeDayCount < Self.minimumActiveDays {
            return .suppressed(.insufficientActiveDays)
        }
        guard let milestone = earnedMilestones.first else {
            return .suppressed(.noQualifyingMilestone)
        }
        if lastRequestVersion == appVersion {
            return .suppressed(.sameAppVersion)
        }
        if let lastRequestDate = userDefaults.object(forKey: Keys.lastRequestDate) as? Date,
           let nextEligibleDate = calendar.date(
               byAdding: .day,
               value: Self.cooldownDays,
               to: lastRequestDate
           ),
           now < nextEligibleDate {
            return .suppressed(.cooldownActive)
        }
        return .eligible(milestone)
    }

    func trackEvaluation(_ decision: ReviewPromptDecision, appVersion: String) {
        var properties = [
            "app_version": appVersion,
            "active_day_count": "\(activeDayCount)",
            "milestone": earnedMilestones.first?.rawValue ?? "none"
        ]
        switch decision {
        case .eligible(let milestone):
            properties["outcome"] = "eligible"
            properties["milestone"] = milestone.rawValue
            properties["suppression_reason"] = "none"
        case .suppressed(let reason):
            properties["outcome"] = "suppressed"
            properties["suppression_reason"] = reason.rawValue
        }
        CronicaTelemetry.shared.capture(
            "review_prompt_eligibility_evaluated",
            properties: properties
        )
    }

    func recordRequestAttempt(
        now: Date = Date(),
        appVersion: String,
        milestone: ReviewPromptMilestone
    ) {
        userDefaults.set(now, forKey: Keys.lastRequestDate)
        userDefaults.set(appVersion, forKey: Keys.lastRequestVersion)
        CronicaTelemetry.shared.capture(
            "review_prompt_request_attempted",
            properties: [
                "app_version": appVersion,
                "milestone": milestone.rawValue,
                "request_api": "swiftui_environment",
                "outcome": "attempted"
            ]
        )
    }

    func resetRequestHistory() {
        userDefaults.removeObject(forKey: Keys.lastRequestVersion)
        userDefaults.removeObject(forKey: Keys.lastRequestDate)
    }

    func prepareDebugEligibilityIfRequested(now: Date = Date()) {
#if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(Self.debugEligibilityArgument) else { return }
        resetRequestHistory()
        for offset in 0..<Self.minimumActiveDays {
            if let date = calendar.date(byAdding: .day, value: -offset, to: now) {
                recordActiveDay(on: date)
            }
        }
        recordMilestone(.canonicalDailyPuzzleSolved)
#endif
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

extension Notification.Name {
    static let reviewPromptMilestoneEarned = Notification.Name("reviewPromptMilestoneEarned")
}
