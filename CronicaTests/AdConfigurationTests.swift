import XCTest
@testable import StreamingNow

#if os(iOS)
import UIKit
#endif

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

    func testRewardedAdUnitIDHasCorrectPrefix() {
        XCTAssertTrue(
            AdConfiguration.AdUnitID.rewarded.hasPrefix("ca-app-pub-"),
            "Rewarded ad unit ID must start with 'ca-app-pub-'"
        )
    }

    func testAppOpenAdUnitIDHasCorrectPrefix() {
        XCTAssertTrue(
            AdConfiguration.AdUnitID.appOpen.hasPrefix("ca-app-pub-"),
            "App open ad unit ID must start with 'ca-app-pub-'"
        )
    }

    func testAdUnitIDsAreNotEmpty() {
        XCTAssertFalse(AdConfiguration.AdUnitID.native.isEmpty)
        XCTAssertFalse(AdConfiguration.AdUnitID.interstitial.isEmpty)
        XCTAssertFalse(AdConfiguration.AdUnitID.rewarded.isEmpty)
        XCTAssertFalse(AdConfiguration.AdUnitID.appOpen.isEmpty)
    }

    func testAdUnitIDsAreDifferent() {
        let ids = [
            AdConfiguration.AdUnitID.native,
            AdConfiguration.AdUnitID.interstitial,
            AdConfiguration.AdUnitID.rewarded,
            AdConfiguration.AdUnitID.appOpen,
        ]

        XCTAssertEqual(
            Set(ids).count,
            ids.count,
            "All ad placements must use distinct ad unit IDs"
        )
    }

    func testAdUnitIDsAreNotGoogleTestIDs() {
        // Google's well-known test ad unit IDs
        let testIDs = [
            "ca-app-pub-3940256099942544/2934735716", // test banner
            "ca-app-pub-3940256099942544/4411468910", // test interstitial
            "ca-app-pub-3940256099942544/1712485313", // test rewarded
            "ca-app-pub-3940256099942544/3986624511", // test native
            "ca-app-pub-3940256099942544/6300978111", // test app open
        ]
        XCTAssertFalse(testIDs.contains(AdConfiguration.AdUnitID.native),
                        "Production build must not use Google test ad unit IDs")
        XCTAssertFalse(testIDs.contains(AdConfiguration.AdUnitID.interstitial),
                        "Production build must not use Google test ad unit IDs")
        XCTAssertFalse(testIDs.contains(AdConfiguration.AdUnitID.rewarded),
                        "Production build must not use Google test ad unit IDs")
        XCTAssertFalse(testIDs.contains(AdConfiguration.AdUnitID.appOpen),
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

    func testInterstitialCooldownPreventsRapidRepeatPresentation() {
        XCTAssertGreaterThan(
            AdConfiguration.interstitialCooldown, 0,
            "Interstitial cooldown should be a positive value to prevent rapid-repeat ads"
        )
    }

    func testInterstitialSessionCapsAreConfigured() {
        XCTAssertGreaterThan(
            AdConfiguration.interstitialSessionWindow, 0,
            "Interstitial session window should be configured with a positive duration"
        )
        XCTAssertGreaterThan(
            AdConfiguration.maxInterstitialPresentsPerSession, 0,
            "Interstitial session cap must allow at least one impression"
        )
        XCTAssertEqual(
            AdConfiguration.interstitialSessionWindow,
            1_200,
            "Interstitial session window should remain 20 minutes unless policy is intentionally changed"
        )
        XCTAssertEqual(
            AdConfiguration.maxInterstitialPresentsPerSession,
            1,
            "Interstitial sessions should allow at most one presentation"
        )
    }

    func testAppOpenFrequencyCapsAreConfigured() {
        XCTAssertEqual(
            AdConfiguration.appOpenCooldown,
            180,
            "App open ads should require three minutes between presentations"
        )
        XCTAssertEqual(
            AdConfiguration.appOpenSessionWindow,
            900,
            "App open sessions should use a 15-minute window"
        )
        XCTAssertEqual(
            AdConfiguration.maxAppOpenPresentsPerSession,
            1,
            "App open sessions should allow at most one presentation"
        )
    }

    func testEngagementInterstitialRequiresFourQualifiedActions() {
        XCTAssertEqual(
            AdConfiguration.engagementInterstitialInterval,
            4,
            "Engagement interstitials should require four qualified actions"
        )
    }

    func testNativeInitialRequestDelayDoesNotThrottleStartupRequests() {
        XCTAssertEqual(
            AdConfiguration.nativeInitialRequestDelay, 0,
            "Native request startup delay should be disabled so monetized screens request immediately"
        )
    }

#if os(iOS)
    @MainActor
    func testNativeAdCardKeepsRegisteredAssetsInsideNativeAdViewBounds() {
        let nativeAdView = CronicaNativeAdCardContainer(
            frame: CGRect(x: 0, y: 0, width: 390, height: 320)
        )
        nativeAdView.layoutIfNeeded()

        let registeredAssets = [
            nativeAdView.headlineView,
            nativeAdView.advertiserView,
            nativeAdView.bodyView,
            nativeAdView.iconView,
            nativeAdView.callToActionView,
            nativeAdView.mediaView,
        ]

        for asset in registeredAssets {
            guard let asset else {
                XCTFail("Every displayed native ad asset must be registered")
                continue
            }

            XCTAssertTrue(asset.isDescendant(of: nativeAdView))
            let assetFrame = asset.convert(asset.bounds, to: nativeAdView)
            XCTAssertGreaterThanOrEqual(assetFrame.minX, nativeAdView.bounds.minX - 0.5)
            XCTAssertGreaterThanOrEqual(assetFrame.minY, nativeAdView.bounds.minY - 0.5)
            XCTAssertLessThanOrEqual(assetFrame.maxX, nativeAdView.bounds.maxX + 0.5)
            XCTAssertLessThanOrEqual(assetFrame.maxY, nativeAdView.bounds.maxY + 0.5)
        }
    }
#endif
}
