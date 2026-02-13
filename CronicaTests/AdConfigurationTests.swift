import XCTest
@testable import StreamingNow

final class AdConfigurationTests: XCTestCase {

    // MARK: - Ad Unit ID Format

    func testNativeAdUnitIDHasCorrectPrefix() {
        XCTAssertTrue(
            AdConfiguration.AdUnitID.native.hasPrefix("ca-app-pub-"),
            "Native ad unit ID must start with 'ca-app-pub-'"
        )
    }

    func testInterstitialAdUnitIDHasCorrectPrefix() {
        XCTAssertTrue(
            AdConfiguration.AdUnitID.interstitial.hasPrefix("ca-app-pub-"),
            "Interstitial ad unit ID must start with 'ca-app-pub-'"
        )
    }

    func testAdUnitIDsAreNotEmpty() {
        XCTAssertFalse(AdConfiguration.AdUnitID.native.isEmpty)
        XCTAssertFalse(AdConfiguration.AdUnitID.interstitial.isEmpty)
    }

    func testAdUnitIDsAreDifferent() {
        XCTAssertNotEqual(
            AdConfiguration.AdUnitID.native,
            AdConfiguration.AdUnitID.interstitial,
            "Native and interstitial should use different ad units"
        )
    }

    func testAdUnitIDsAreNotGoogleTestIDs() {
        // Google's well-known test ad unit IDs
        let testIDs = [
            "ca-app-pub-3940256099942544/2934735716", // test banner
            "ca-app-pub-3940256099942544/4411468910", // test interstitial
            "ca-app-pub-3940256099942544/1712485313", // test rewarded
            "ca-app-pub-3940256099942544/3986624511", // test native
        ]
        XCTAssertFalse(testIDs.contains(AdConfiguration.AdUnitID.native),
                        "Production build must not use Google test ad unit IDs")
        XCTAssertFalse(testIDs.contains(AdConfiguration.AdUnitID.interstitial),
                        "Production build must not use Google test ad unit IDs")
    }

    // MARK: - Policy Compliance

    func testNativeRefreshIntervalMeetsGoogleMinimum() {
        // Google AdMob policy: minimum 30 seconds between native ad refreshes
        XCTAssertGreaterThanOrEqual(
            AdConfiguration.nativeRefreshInterval, 30,
            "Native ad refresh interval must be >= 30s per Google policy"
        )
    }

    func testInterstitialCooldownIsPositive() {
        XCTAssertGreaterThan(
            AdConfiguration.interstitialCooldown, 0,
            "Interstitial cooldown must be > 0 to prevent ad spam"
        )
    }

    func testInterstitialCooldownIsReasonable() {
        // At least 30 seconds to avoid annoying users
        XCTAssertGreaterThanOrEqual(
            AdConfiguration.interstitialCooldown, 30,
            "Interstitial cooldown should be at least 30s for good UX"
        )
    }
}
