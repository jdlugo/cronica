#if os(iOS)
import Foundation

enum DailyReelPublicationCalendar {
    static func publicationID(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date.addingTimeInterval(-5 * 60 * 60))
    }
}

enum DailyReelAssembly {
    @MainActor
    static func makeFeature(
        publicationID: String,
        locale: String,
        rolloutVariant: String
    ) -> DailyReelFeature? {
        guard let baseURL = Key.dailyReelAPIBaseURL else { return nil }
        let client = LiveDailyReelClient(
            baseURL: baseURL,
            appCheck: FirebaseDailyReelAppCheckTokenProvider(),
            identity: UserDefaultsDailyReelInstallationIdentity()
        )
        return DailyReelFeature(
            client: client,
            capabilities: KeychainDailyReelCapabilityStore(),
            telemetry: PostHogDailyReelTelemetryTracker(
                publicationID: publicationID,
                locale: locale,
                rolloutVariant: rolloutVariant
            ),
            publicationID: publicationID,
            locale: locale
        )
    }

    @MainActor
    static func makeChallengeClient() -> (any DailyReelChallengeClientProtocol)? {
        guard let baseURL = Key.dailyReelAPIBaseURL else { return nil }
        return LiveDailyReelChallengeClient(
            baseURL: baseURL,
            appCheck: FirebaseDailyReelAppCheckTokenProvider(),
            identity: UserDefaultsDailyReelInstallationIdentity()
        )
    }
}
#endif
