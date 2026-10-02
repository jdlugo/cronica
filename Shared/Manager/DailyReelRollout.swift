import Foundation
import Observation
import PostHog

struct DailyReelRolloutAssignment: Equatable, Sendable {
    let isEnabled: Bool
    let variant: String

    static let disabled = DailyReelRolloutAssignment(isEnabled: false, variant: "disabled")

    static func resolve(rawValue: Any?) -> DailyReelRolloutAssignment {
        if let enabled = rawValue as? Bool {
            return DailyReelRolloutAssignment(
                isEnabled: enabled,
                variant: enabled ? "enabled" : "disabled"
            )
        }
        if let variant = rawValue as? String {
            let normalized = variant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let disabledValues = ["", "false", "disabled", "off", "none"]
            guard !disabledValues.contains(normalized) else {
                return .disabled
            }
            return DailyReelRolloutAssignment(
                isEnabled: true,
                variant: normalized
            )
        }
        return .disabled
    }
}

protocol DailyReelRolloutProviding: Sendable {
    func assignment() async -> DailyReelRolloutAssignment
}

struct PostHogDailyReelRolloutProvider: DailyReelRolloutProviding {
    static let flagKey = "daily-reel-rollout"

    func assignment() async -> DailyReelRolloutAssignment {
        await withCheckedContinuation { continuation in
            PostHogSDK.shared.reloadFeatureFlags {
                let rawValue = PostHogSDK.shared.getFeatureFlag(Self.flagKey)
                continuation.resume(returning: .resolve(rawValue: rawValue))
            }
        }
    }
}

@MainActor
@Observable
final class DailyReelRolloutController {
    enum State: Equatable {
        case idle
        case loading
        case enabled(variant: String)
        case disabled
    }

    private let provider: any DailyReelRolloutProviding
    private(set) var state: State = .idle

    init(provider: any DailyReelRolloutProviding = PostHogDailyReelRolloutProvider()) {
        self.provider = provider
    }

    func refresh() async {
        guard state == .idle else { return }
        state = .loading
        let assignment = await provider.assignment()
        state = assignment.isEnabled ? .enabled(variant: assignment.variant) : .disabled
    }
}

struct PostHogDailyReelTelemetryTracker: DailyReelTelemetryTracking {
    let publicationID: String
    let locale: String
    let rolloutVariant: String

    func track(_ event: DailyReelTelemetryEvent) async {
        var properties: [String: Any] = [
            "publication_id": publicationID,
            "content_locale": locale,
            "rollout_variant": rolloutVariant,
            "surface": "ios",
        ]
        let eventName: String
        switch event {
        case .sessionStarted(let mode, let configHash):
            eventName = "daily_reel_session_started"
            properties["mode"] = mode.rawValue
            properties["config_hash"] = configHash
        case .sessionResumed(let mode, let configHash):
            eventName = "daily_reel_session_resumed"
            properties["mode"] = mode.rawValue
            properties["config_hash"] = configHash
        case .actViewed(let index, let role):
            eventName = "daily_reel_act_viewed"
            properties["act_index"] = index
            properties["act_role"] = role.rawValue
        case .attemptSubmitted(let index, let role):
            eventName = "daily_reel_attempt_submitted"
            properties["act_index"] = index
            properties["act_role"] = role.rawValue
        case .assistRequested(let index, let kind):
            eventName = "daily_reel_assist_requested"
            properties["act_index"] = index
            properties["assist_kind"] = kind.rawValue
        case .actRevealed(let index):
            eventName = "daily_reel_act_revealed"
            properties["act_index"] = index
        case .completed(let score):
            eventName = "daily_reel_completed"
            properties["score"] = score
        case .challengeCreated:
            eventName = "daily_reel_challenge_created"
        case .challengeCreationFailed(let code):
            eventName = "daily_reel_challenge_creation_failed"
            properties["error_code"] = code
        case .failed(let code):
            eventName = "daily_reel_failed"
            properties["error_code"] = code
        }
        PostHogSDK.shared.capture(eventName, properties: properties)
    }
}
