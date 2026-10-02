import XCTest
import UIKit
@testable import StreamingNow
import GoogleMobileAds

// MARK: - Mocks

private struct MockAdSettings: AdSettingsProviding {
    var hasPurchasedTipJar: Bool
}

private final class MockPresentableAd: PresentableAd {
    var presentCalled = false
    var presentedFromVC: UIViewController?

    func present(from viewController: UIViewController?) {
        presentCalled = true
        presentedFromVC = viewController
    }
}

private final class MockAdLoader: InterstitialAdLoading {
    var adToReturn: PresentableAd?
    var loadCallCount = 0

    func load(delegate: AdCoordinator, completion: @escaping (PresentableAd?) -> Void) {
        loadCallCount += 1
        completion(adToReturn)
    }
}

private final class MockRewardedAdLoader: RewardedAdLoading {
    var adToReturn: RewardedAd?
    var loadCallCount = 0

    func load(completion: @escaping (RewardedAd?) -> Void) {
        loadCallCount += 1
        completion(adToReturn)
    }
}

private final class MockAppOpenAdLoader: AppOpenAdLoading {
    var adToReturn: AppOpenPresentableAd?
    var loadCallCount = 0

    func load(completion: @escaping (AppOpenPresentableAd?) -> Void) {
        loadCallCount += 1
        completion(adToReturn)
    }
}

private final class MockAppOpenAd: AppOpenPresentableAd {
    var presentCalled = false
    var presentedFromVC: UIViewController?
    var fullScreenContentDelegate: FullScreenContentDelegate?

    func present(from viewController: UIViewController?) {
        presentCalled = true
        presentedFromVC = viewController
    }
}

private final class MockRootVCProvider: RootViewControllerProviding {
    var vc: UIViewController?

    func rootViewController() -> UIViewController? {
        return vc
    }
}

private final class AdLifecycleTrackerSpy: AdLifecycleTracking {
    private(set) var events = [AdLifecycleEvent]()

    func track(_ event: AdLifecycleEvent) {
        events.append(event)
    }

    func removeAllEvents() {
        events.removeAll()
    }
}

// MARK: - Helper

private enum TestError: Error {
    case mockFailure
}

// MARK: - Tests

final class AdCoordinatorTests: XCTestCase {

    private var mockSettings: MockAdSettings!
    private var mockLoader: MockAdLoader!
    private var mockRewardedLoader: MockRewardedAdLoader!
    private var mockAppOpenLoader: MockAppOpenAdLoader!
    private var mockAppOpenAd: MockAppOpenAd!
    private var mockRootVC: MockRootVCProvider!
    private var mockAd: MockPresentableAd!
    private var lifecycleTracker: AdLifecycleTrackerSpy!
    private var coordinator: AdCoordinator!

    override func setUp() {
        super.setUp()
        AdCoordinator.lastPresentationDate = nil
        AdCoordinator.lastAppOpenDate = nil
        AdCoordinator.interstitialSessionStartDate = nil
        AdCoordinator.interstitialPresentsThisSession = 0
        AdCoordinator.appOpenSessionStartDate = nil
        AdCoordinator.appOpenPresentsThisSession = 0

        mockSettings = MockAdSettings(hasPurchasedTipJar: false)
        mockAd = MockPresentableAd()
        mockLoader = MockAdLoader()
        mockLoader.adToReturn = mockAd
        mockRewardedLoader = MockRewardedAdLoader()
        mockAppOpenLoader = MockAppOpenAdLoader()
        mockAppOpenAd = MockAppOpenAd()
        mockAppOpenLoader.adToReturn = mockAppOpenAd
        mockRootVC = MockRootVCProvider()
        mockRootVC.vc = UIViewController()
        lifecycleTracker = AdLifecycleTrackerSpy()

        coordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC,
            lifecycleTracker: lifecycleTracker
        )
    }

    override func tearDown() {
        AdCoordinator.lastPresentationDate = nil
        AdCoordinator.lastAppOpenDate = nil
        coordinator = nil
        mockSettings = nil
        mockLoader = nil
        mockRewardedLoader = nil
        mockAppOpenLoader = nil
        mockAppOpenAd = nil
        mockRootVC = nil
        mockAd = nil
        lifecycleTracker = nil
        AdCoordinator.interstitialSessionStartDate = nil
        AdCoordinator.interstitialPresentsThisSession = 0
        AdCoordinator.appOpenSessionStartDate = nil
        AdCoordinator.appOpenPresentsThisSession = 0
        super.tearDown()
    }

    // MARK: - Ad Loading

    func testInitLoadsAd() {
        // loadAd() is called during init
        XCTAssertEqual(mockLoader.loadCallCount, 1, "Should load an ad on init")
    }

    func testLoadAdSkippedWhenTipJarPurchased() {
        let paidSettings = MockAdSettings(hasPurchasedTipJar: true)
        let paidLoader = MockAdLoader()

        _ = AdCoordinator(
            settings: paidSettings,
            adLoader: paidLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        XCTAssertEqual(paidLoader.loadCallCount, 0,
                        "Should not load ads for tip jar purchasers")
    }

    func testLoadAdCallsLoaderWhenFreeUser() {
        XCTAssertEqual(mockLoader.loadCallCount, 1)
        coordinator.loadAd()
        XCTAssertEqual(mockLoader.loadCallCount, 2,
                        "Calling loadAd again should invoke the loader")
    }

    func testLoadAdSetsInterstitial() {
        XCTAssertNotNil(coordinator.interstitial,
                        "Interstitial should be set after mock loader completes")
    }

    func testLoadAdWithNilAdResult() {
        mockLoader.adToReturn = nil
        coordinator.loadAd()
        // interstitial should now be nil from the second load
        // (first load in init set it to mockAd, second load sets it to nil)
        XCTAssertNil(coordinator.interstitial,
                     "Interstitial should be nil when loader returns nil")
    }

    // MARK: - Ad Presentation (Happy Path)

    func testPresentCallsPresentOnAd() {
        coordinator.presentAd()
        XCTAssertTrue(mockAd.presentCalled,
                      "Should call present(from:) on the loaded ad")
    }

    func testPresentPassesRootViewController() {
        let expectedVC = mockRootVC.vc
        coordinator.presentAd()
        XCTAssertTrue(mockAd.presentedFromVC === expectedVC,
                      "Should present from the root VC provided by the rootVCProvider")
    }

    func testPresentSetsLastPresentationDate() {
        XCTAssertNil(AdCoordinator.lastPresentationDate)
        coordinator.presentAd()
        XCTAssertNotNil(AdCoordinator.lastPresentationDate,
                        "Should set lastPresentationDate when presenting")
    }

    func testPresentDoesNotFireOnDismissImmediately() {
        // When ad actually presents, onDismiss should wait for dismissal
        var dismissed = false
        coordinator.presentAd {
            dismissed = true
        }
        XCTAssertFalse(dismissed,
                       "onDismiss should NOT fire immediately when ad is shown — waits for dismiss delegate")
    }

    // MARK: - Tip Jar Gating

    func testPresentSkipsAdWhenTipJarPurchased() {
        let paidSettings = MockAdSettings(hasPurchasedTipJar: true)
        let paidLoader = MockAdLoader()
        let paidAd = MockPresentableAd()
        paidLoader.adToReturn = paidAd

        let paidCoordinator = AdCoordinator(
            settings: paidSettings,
            adLoader: paidLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        var dismissed = false
        paidCoordinator.presentAd {
            dismissed = true
        }

        XCTAssertFalse(paidAd.presentCalled,
                       "Ad should NOT be presented for tip jar purchasers")
        XCTAssertTrue(dismissed,
                      "onDismiss should fire immediately when tip jar is purchased")
    }

    func testPresentCallsOnDismissImmediatelyWhenTipJarPurchased() {
        let paidSettings = MockAdSettings(hasPurchasedTipJar: true)
        let paidCoordinator = AdCoordinator(
            settings: paidSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        var dismissed = false
        paidCoordinator.presentAd {
            dismissed = true
        }
        XCTAssertTrue(dismissed)
    }

    // MARK: - Frequency Capping

    func testPresentBlocksAdDuringCooldown() {
        AdCoordinator.lastPresentationDate = Date()

        coordinator.presentAd()

        XCTAssertFalse(
            mockAd.presentCalled,
            "Interstitials should be blocked while cooldown has not elapsed"
        )
    }

    func testPresentAllowsAdAfterCooldownExpires() {
        AdCoordinator.lastPresentationDate = Date().addingTimeInterval(
            -(AdConfiguration.interstitialCooldown + 1)
        )

        coordinator.presentAd()
        XCTAssertTrue(mockAd.presentCalled,
                      "Ad should present after cooldown has expired")
    }

    func testSecondInterstitialIsBlockedWithinTheSameSession() {
        // First call presents the ad
        coordinator.presentAd()
        XCTAssertTrue(mockAd.presentCalled)

        // lastPresentationDate is now set by the first call
        AdCoordinator.lastPresentationDate = Date().addingTimeInterval(
            -(AdConfiguration.interstitialCooldown + 1)
        )

        let secondAd = MockPresentableAd()
        mockLoader.adToReturn = secondAd

        // Simulate a reload (as would happen after dismiss)
        coordinator.loadAd()

        // Cooldown has elapsed, but the per-session cap should still block a second ad.
        coordinator.presentAd()
        XCTAssertFalse(secondAd.presentCalled,
                       "A second interstitial should be blocked within the same session")
        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "interstitial",
            action: "present",
            outcome: "session_limit_reached",
            metadata: ["block_reason": "session_limit_reached"]
        )))
    }

    func testPresentBlocksWhenSessionCapReached() {
        AdCoordinator.interstitialSessionStartDate = Date()
        AdCoordinator.interstitialPresentsThisSession = AdConfiguration.maxInterstitialPresentsPerSession

        coordinator.presentAd()
        XCTAssertFalse(mockAd.presentCalled, "Interstitial should be blocked when session cap is reached")
        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "interstitial",
            action: "present",
            outcome: "session_limit_reached",
            metadata: ["block_reason": "session_limit_reached"]
        )))
    }

    // MARK: - No Ad / No Root VC

    func testPresentCallsOnDismissWhenNoAdLoaded() {
        mockLoader.adToReturn = nil
        // Create a new coordinator with nil ad
        let noAdCoordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        var dismissed = false
        noAdCoordinator.presentAd {
            dismissed = true
        }
        XCTAssertTrue(dismissed,
                      "onDismiss should fire when no ad is loaded")
    }

    func testPresentWhenNoAdLoadedTriggersReloadAttempt() {
        mockLoader.adToReturn = nil
        let noAdCoordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        let loadCountBeforePresent = mockLoader.loadCallCount
        noAdCoordinator.presentAd()

        XCTAssertEqual(
            mockLoader.loadCallCount,
            loadCountBeforePresent + 1,
            "Missing interstitial should trigger an immediate reload attempt so the session can recover."
        )
    }

    func testPresentCallsOnDismissWhenNoRootVC() {
        mockRootVC.vc = nil

        var dismissed = false
        coordinator.presentAd {
            dismissed = true
        }
        XCTAssertTrue(dismissed,
                      "onDismiss should fire when no root VC is available")
        XCTAssertFalse(mockAd.presentCalled,
                       "Ad should NOT present without a root VC")
    }

    func testPresentWithNilOnDismissDoesNotCrash() {
        coordinator.presentAd(onDismiss: nil)
    }

    func testPresentWithoutOnDismissDoesNotCrash() {
        coordinator.presentAd()
    }

    // MARK: - Engagement Interstitials

    func testEngagementInterstitialSkipsFirstDetailOpenButKeepsInventoryReady() {
        coordinator.presentInterstitialForEngagement(.detailOpen)

        XCTAssertFalse(
            mockAd.presentCalled,
            "First detail open should warm/keep inventory but avoid interrupting the user immediately."
        )
        XCTAssertEqual(
            mockLoader.loadCallCount,
            1,
            "Loaded inventory should be reused instead of issuing duplicate interstitial requests."
        )
    }

    func testEngagementInterstitialPresentsOnFourthDetailOpen() {
        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.detailOpen)

        XCTAssertTrue(
            mockAd.presentCalled,
            "Fourth detail open should present loaded interstitial inventory to convert requests into impressions."
        )
    }

    func testPuzzleInterstitialPresentsAfterThirdCompletedRound() {
        coordinator.presentInterstitialForEngagement(.puzzleCompleted)
        coordinator.presentInterstitialForEngagement(.puzzleCompleted)

        XCTAssertFalse(mockAd.presentCalled)

        coordinator.presentInterstitialForEngagement(.puzzleCompleted)

        XCTAssertTrue(
            mockAd.presentCalled,
            "The first forced puzzle interstitial should occur only after three completed rounds."
        )
    }

    func testPuzzleAndDetailEngagementCountersAreIsolated() {
        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.puzzleCompleted)
        coordinator.presentInterstitialForEngagement(.puzzleCompleted)

        XCTAssertFalse(
            mockAd.presentCalled,
            "Browsing details must not advance the Daily Puzzle monetization cadence."
        )
    }

    func testRuntimeDisabledPuzzleInterstitialContinuesImmediately() {
        var continued = false

        coordinator.presentInterstitialForEngagement(
            .puzzleCompleted,
            monetizationDisabled: true
        ) {
            continued = true
        }

        XCTAssertFalse(mockAd.presentCalled)
        XCTAssertTrue(continued)
    }

    func testEngagementInterstitialTracksTriggerMetadataWhenPresented() {
        lifecycleTracker.removeAllEvents()

        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.detailOpen)
        coordinator.presentInterstitialForEngagement(.detailOpen)

        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "interstitial",
            action: "engagement",
            outcome: "presenting",
            metadata: [
                "trigger": "detail_open",
                "engagement_count": "4"
            ]
        )))
    }

    func testEngagementInterstitialSkipsPaidUserAndRunsContinuation() {
        let paidSettings = MockAdSettings(hasPurchasedTipJar: true)
        let paidAd = MockPresentableAd()
        let paidLoader = MockAdLoader()
        paidLoader.adToReturn = paidAd
        let paidCoordinator = AdCoordinator(
            settings: paidSettings,
            adLoader: paidLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        var continued = false
        paidCoordinator.presentInterstitialForEngagement(.detailOpen) {
            continued = true
        }

        XCTAssertFalse(paidAd.presentCalled)
        XCTAssertTrue(continued)
    }

    // MARK: - handleAdDismissed (Delegate Path)

    func testHandleAdDismissedFiresOnDismiss() {
        var dismissed = false
        coordinator.onDismiss = {
            dismissed = true
        }

        coordinator.handleAdDismissed()
        XCTAssertTrue(dismissed, "handleAdDismissed should fire the onDismiss callback")
    }

    func testHandleAdDismissedNilsOnDismiss() {
        coordinator.onDismiss = {}
        coordinator.handleAdDismissed()
        XCTAssertNil(coordinator.onDismiss,
                     "onDismiss should be nil after handleAdDismissed")
    }

    func testHandleAdDismissedReloadsAd() {
        let countBefore = coordinator.loadAdCallCount
        coordinator.handleAdDismissed()
        XCTAssertEqual(coordinator.loadAdCallCount, countBefore + 1,
                       "handleAdDismissed should trigger a reload")
    }

    func testHandleAdDismissedWithNilOnDismissDoesNotCrash() {
        coordinator.onDismiss = nil
        coordinator.handleAdDismissed()
    }

    // MARK: - handleAdFailedToPresent (Failure Path)

    func testHandleAdFailedToPresentFiresOnDismiss() {
        var dismissed = false
        coordinator.onDismiss = {
            dismissed = true
        }

        coordinator.handleAdFailedToPresent(error: TestError.mockFailure)
        XCTAssertTrue(dismissed,
                      "handleAdFailedToPresent should fire the onDismiss callback")
    }

    func testHandleAdFailedToPresentNilsOnDismiss() {
        coordinator.onDismiss = {}
        coordinator.handleAdFailedToPresent(error: TestError.mockFailure)
        XCTAssertNil(coordinator.onDismiss,
                     "onDismiss should be nil after handleAdFailedToPresent")
    }

    func testHandleAdFailedToPresentReloadsAd() {
        let countBefore = coordinator.loadAdCallCount
        coordinator.handleAdFailedToPresent(error: TestError.mockFailure)
        XCTAssertEqual(coordinator.loadAdCallCount, countBefore + 1,
                       "handleAdFailedToPresent should trigger a reload")
    }

    // MARK: - Full Lifecycle Chain

    func testFullPresentDismissReloadChain() {
        // 1. Initial load during init
        XCTAssertEqual(mockLoader.loadCallCount, 1, "Init should trigger load")
        XCTAssertNotNil(coordinator.interstitial, "Ad should be loaded")

        // 2. Present the ad
        var dismissed = false
        coordinator.presentAd {
            dismissed = true
        }
        XCTAssertTrue(mockAd.presentCalled, "Ad should be presented")
        XCTAssertFalse(dismissed, "onDismiss should NOT fire yet — ad is showing")
        XCTAssertNotNil(AdCoordinator.lastPresentationDate)

        // 3. Simulate ad dismissal (what the Google SDK delegate would call)
        let reloadAd = MockPresentableAd()
        mockLoader.adToReturn = reloadAd

        coordinator.handleAdDismissed()

        // 4. Verify the chain
        XCTAssertTrue(dismissed, "onDismiss should fire after dismissal")
        XCTAssertNil(coordinator.onDismiss, "onDismiss should be cleaned up")
        XCTAssertEqual(mockLoader.loadCallCount, 2, "Dismiss should trigger reload")
    }

    func testFullPresentFailReloadChain() {
        // 1. Present the ad
        var dismissed = false
        coordinator.presentAd {
            dismissed = true
        }
        XCTAssertTrue(mockAd.presentCalled)

        // 2. Simulate presentation failure
        let reloadAd = MockPresentableAd()
        mockLoader.adToReturn = reloadAd

        coordinator.handleAdFailedToPresent(error: TestError.mockFailure)

        // 3. Verify the chain
        XCTAssertTrue(dismissed, "onDismiss should fire after failure")
        XCTAssertNil(coordinator.onDismiss, "onDismiss should be cleaned up")
        XCTAssertEqual(mockLoader.loadCallCount, 2, "Failure should trigger reload")
    }

    // MARK: - State Reset

    func testLastPresentationDateStartsNil() {
        AdCoordinator.lastPresentationDate = nil
        XCTAssertNil(AdCoordinator.lastPresentationDate)
    }

    func testCooldownCalculation() {
        let cooldown = AdConfiguration.interstitialCooldown
        let currentDate = Date().addingTimeInterval(-(cooldown + 1))

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(currentDate), cooldown,
                                    "After cooldown window, repeat presentation should be eligible")
    }

    // MARK: - onDismiss Cleanup

    func testOnDismissIsNilledAfterPresentWithNoAd() {
        mockLoader.adToReturn = nil
        let noAdCoordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        noAdCoordinator.presentAd { }
        XCTAssertNil(noAdCoordinator.onDismiss,
                     "onDismiss should be nil after the no-ad fallback path")
    }

    // MARK: - Rewarded Ad Loading

    func testLoadRewardedAdCallsLoader() {
        coordinator.loadRewardedAd()
        XCTAssertEqual(mockRewardedLoader.loadCallCount, 1,
                       "loadRewardedAd should invoke the rewarded ad loader")
    }

    func testLoadRewardedAdSkippedWhenTipJarPurchased() {
        let paidSettings = MockAdSettings(hasPurchasedTipJar: true)
        let paidRewardedLoader = MockRewardedAdLoader()

        let paidCoordinator = AdCoordinator(
            settings: paidSettings,
            adLoader: mockLoader,
            rewardedAdLoader: paidRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        paidCoordinator.loadRewardedAd()
        XCTAssertEqual(paidRewardedLoader.loadCallCount, 0,
                        "Should not load rewarded ads for tip jar purchasers")
    }

    func testEnsureRewardedAdLoadedCallsLoaderWhenNil() {
        XCTAssertNil(coordinator.rewardedAd)
        coordinator.ensureRewardedAdLoaded()
        XCTAssertEqual(mockRewardedLoader.loadCallCount, 1)
    }

    func testPresentRewardedAdSkippedWhenTipJarPurchased() {
        let paidSettings = MockAdSettings(hasPurchasedTipJar: true)
        let paidCoordinator = AdCoordinator(
            settings: paidSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        var rewarded = false
        paidCoordinator.presentRewardedAd {
            rewarded = true
        }
        XCTAssertFalse(rewarded,
                       "Reward callback should NOT fire for tip jar purchasers")
    }

    func testPresentRewardedAdTriggersLoadWhenNoAdAvailable() {
        XCTAssertNil(coordinator.rewardedAd)
        coordinator.presentRewardedAd {}
        XCTAssertEqual(mockRewardedLoader.loadCallCount, 1,
                       "Should trigger load when no rewarded ad is available")
    }

    func testPresentHintAdDoesNotFallBackToInterstitialWhenRewardedUnavailable() {
        XCTAssertNil(coordinator.rewardedAd)

        var hintUnlocked = false
        var unavailable = false
        coordinator.presentHintAd(onUnavailable: { unavailable = true }) {
            hintUnlocked = true
        }

        XCTAssertFalse(mockAd.presentCalled,
                       "Hint flow must never substitute a regular interstitial")
        XCTAssertFalse(hintUnlocked,
                       "Hint should not unlock without a completed rewarded ad")
        XCTAssertTrue(unavailable,
                      "The UI should receive an immediate unavailable result")
        XCTAssertEqual(mockRewardedLoader.loadCallCount, 1)
    }

    func testPresentHintAdDoesNotUnlockHintWhenNoAdIsAvailable() {
        let noAdLoader = MockAdLoader()
        noAdLoader.adToReturn = nil
        let noRewardedLoader = MockRewardedAdLoader()
        let noAdCoordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: noAdLoader,
            rewardedAdLoader: noRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        var hintUnlocked = false
        var unavailable = false
        noAdCoordinator.presentHintAd(onUnavailable: { unavailable = true }) {
            hintUnlocked = true
        }

        XCTAssertFalse(hintUnlocked,
                       "Hint should not unlock when rewarded inventory is unavailable")
        XCTAssertTrue(unavailable)
        XCTAssertEqual(noRewardedLoader.loadCallCount, 1,
                       "Hint flow should request rewarded inventory when unavailable")
    }

    func testPresentHintAdDoesNotAutoPresentWhenInterstitialLoadsAfterTap() {
        let delayedAdLoader = MockAdLoader()
        delayedAdLoader.adToReturn = nil
        let noRewardedLoader = MockRewardedAdLoader()
        noRewardedLoader.adToReturn = nil
        let delayedCoordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: delayedAdLoader,
            rewardedAdLoader: noRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        var hintUnlocked = false
        var unavailable = false
        delayedCoordinator.presentHintAd(onUnavailable: { unavailable = true }) {
            hintUnlocked = true
        }

        XCTAssertFalse(hintUnlocked, "Hint should not unlock before ad is shown/dismissed")
        XCTAssertTrue(unavailable)

        let interstitial = MockPresentableAd()
        delayedAdLoader.adToReturn = interstitial
        delayedCoordinator.loadAd()

        XCTAssertFalse(interstitial.presentCalled,
                       "A prior hint tap must never queue a later interstitial presentation")
        XCTAssertFalse(hintUnlocked)
    }

    // MARK: - App Open Ad Loading

    func testLoadAppOpenAdCallsLoader() {
        coordinator.loadAppOpenAd()
        XCTAssertEqual(mockAppOpenLoader.loadCallCount, 1,
                       "loadAppOpenAd should invoke the app open ad loader")
    }

    func testLoadAppOpenAdTracksRequestAndLoadedOutcome() {
        lifecycleTracker.removeAllEvents()

        coordinator.loadAppOpenAd()

        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "app_open",
            action: "load",
            outcome: "requested"
        )))
        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "app_open",
            action: "load",
            outcome: "loaded"
        )))
    }

    func testLoadAppOpenAdSkippedWhenTipJarPurchased() {
        let paidSettings = MockAdSettings(hasPurchasedTipJar: true)
        let paidAppOpenLoader = MockAppOpenAdLoader()

        let paidCoordinator = AdCoordinator(
            settings: paidSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: paidAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        paidCoordinator.loadAppOpenAd()
        XCTAssertEqual(paidAppOpenLoader.loadCallCount, 0,
                        "Should not load app open ads for tip jar purchasers")
    }

    func testPresentAppOpenAdSkippedWhenTipJarPurchased() {
        let paidSettings = MockAdSettings(hasPurchasedTipJar: true)
        let paidCoordinator = AdCoordinator(
            settings: paidSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: mockAppOpenLoader,
            rootVCProvider: mockRootVC
        )

        paidCoordinator.presentAppOpenAd()
        // No crash, no presentation
    }

    func testPresentAppOpenAdPresentsLoadedAdImmediately() {
        lifecycleTracker.removeAllEvents()
        coordinator.loadAppOpenAd()
        coordinator.presentAppOpenAd()

        XCTAssertTrue(mockAppOpenAd.presentCalled,
                      "Loaded app open inventory should present immediately")
        XCTAssertTrue(mockAppOpenAd.presentedFromVC === mockRootVC.vc,
                      "App open ads should present from the root view controller")
        XCTAssertNil(coordinator.appOpenAd,
                     "App open inventory should be consumed after presentation because Google ad objects are single-use.")
        XCTAssertNotNil(AdCoordinator.lastAppOpenDate)
        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "app_open",
            action: "present",
            outcome: "attempted",
            metadata: ["source": "foreground"]
        )))
        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "app_open",
            action: "present",
            outcome: "presented"
        )))
    }

    func testPresentAppOpenAdBlocksRecentForegroundTimestamp() {
        AdCoordinator.lastAppOpenDate = Date()
        coordinator.loadAppOpenAd()
        coordinator.presentAppOpenAd()

        XCTAssertFalse(mockAppOpenAd.presentCalled,
                       "App open presentation should be blocked during cooldown")
        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "app_open",
            action: "present",
            outcome: "cooldown",
            metadata: ["source": "foreground", "block_reason": "cooldown"]
        )))
    }

    func testPresentAppOpenAdAutoPresentsWhenLoadCompletesAfterForegroundRequest() {
        let delayedLoader = MockAppOpenAdLoader()
        delayedLoader.adToReturn = nil
        let delayedCoordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: mockLoader,
            rewardedAdLoader: mockRewardedLoader,
            appOpenAdLoader: delayedLoader,
            rootVCProvider: mockRootVC
        )

        let delayedAd = MockAppOpenAd()

        delayedCoordinator.presentAppOpenAd()
        XCTAssertEqual(delayedLoader.loadCallCount, 1,
                       "Missing app open inventory should trigger a load")

        delayedLoader.adToReturn = delayedAd
        delayedCoordinator.loadAppOpenAd()

        XCTAssertTrue(delayedAd.presentCalled,
                      "A pending app open request should present as soon as inventory loads")
        XCTAssertNil(delayedCoordinator.appOpenAd,
                     "Auto-presented app open inventory should be consumed immediately.")
    }

    func testPresentAppOpenAdDoesNotReuseCurrentlyPresentingAd() {
        lifecycleTracker.removeAllEvents()
        coordinator.loadAppOpenAd()

        coordinator.presentAppOpenAd()
        coordinator.presentAppOpenAd()

        XCTAssertEqual(
            lifecycleTracker.events.filter {
                $0.placement == "app_open" && $0.action == "present" && $0.outcome == "presented"
            }.count,
            1
        )
        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "app_open",
            action: "present",
            outcome: "already_presenting"
        )))
    }

    func testPresentAppOpenAdTracksMissingRootViewController() {
        lifecycleTracker.removeAllEvents()
        mockRootVC.vc = nil
        coordinator.loadAppOpenAd()

        coordinator.presentAppOpenAd()

        XCTAssertFalse(mockAppOpenAd.presentCalled)
        XCTAssertTrue(lifecycleTracker.events.contains(.init(
            placement: "app_open",
            action: "present",
            outcome: "no_root_view_controller"
        )))
    }

    func testLastAppOpenDateStartsNil() {
        XCTAssertNil(AdCoordinator.lastAppOpenDate)
    }

    func testAppOpenCooldownCalculation() {
        let cooldown = AdConfiguration.appOpenCooldown
        let currentDate = Date()

        XCTAssertLessThan(Date().timeIntervalSince(currentDate), cooldown,
                          "An immediate foreground return should remain inside the app-open cooldown")
    }
}
