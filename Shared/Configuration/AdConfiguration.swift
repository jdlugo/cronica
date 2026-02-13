import Foundation

/// Centralized configuration for all AdMob ad units and settings.
enum AdConfiguration {
    /// AdMob ad unit IDs
    enum AdUnitID {
        static let native = "ca-app-pub-7891478850122465/8171033829"
        static let interstitial = "ca-app-pub-7891478850122465/6565020438"
    }

    /// Native ad refresh interval in seconds (Google policy minimum: 30s)
    static let nativeRefreshInterval: Int = 30

    /// Minimum seconds between interstitial presentations
    static let interstitialCooldown: TimeInterval = 60
}
