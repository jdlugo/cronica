#if os(iOS)
import FirebaseAppCheck

struct FirebaseDailyReelAppCheckTokenProvider: DailyReelAppCheckTokenProviding {
    func token() async throws -> String {
        try await AppCheck.appCheck().token(forcingRefresh: false).token
    }
}
#endif
