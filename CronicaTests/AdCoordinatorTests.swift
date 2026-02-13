import XCTest
import UIKit
@testable import StreamingNow

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

private final class MockRootVCProvider: RootViewControllerProviding {
    var vc: UIViewController?

    func rootViewController() -> UIViewController? {
        return vc
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
    private var mockRootVC: MockRootVCProvider!
    private var mockAd: MockPresentableAd!
    private var coordinator: AdCoordinator!

    override func setUp() {
        super.setUp()
        AdCoordinator.lastPresentationDate = nil

        mockSettings = MockAdSettings(hasPurchasedTipJar: false)
        mockAd = MockPresentableAd()
        mockLoader = MockAdLoader()
        mockLoader.adToReturn = mockAd
        mockRootVC = MockRootVCProvider()
        mockRootVC.vc = UIViewController()

        coordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: mockLoader,
            rootVCProvider: mockRootVC
        )
    }

    override func tearDown() {
        AdCoordinator.lastPresentationDate = nil
        coordinator = nil
        mockSettings = nil
        mockLoader = nil
        mockRootVC = nil
        mockAd = nil
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
            rootVCProvider: mockRootVC
        )

        var dismissed = false
        paidCoordinator.presentAd {
            dismissed = true
        }
        XCTAssertTrue(dismissed)
    }

    // MARK: - Frequency Capping

    func testPresentSkipsAdDuringCooldown() {
        AdCoordinator.lastPresentationDate = Date()

        var dismissed = false
        coordinator.presentAd {
            dismissed = true
        }

        XCTAssertFalse(mockAd.presentCalled,
                       "Ad should NOT present during cooldown period")
        XCTAssertTrue(dismissed,
                      "onDismiss should fire immediately when cooldown is active")
    }

    func testPresentAllowsAdAfterCooldownExpires() {
        AdCoordinator.lastPresentationDate = Date().addingTimeInterval(
            -(AdConfiguration.interstitialCooldown + 1)
        )

        coordinator.presentAd()
        XCTAssertTrue(mockAd.presentCalled,
                      "Ad should present after cooldown has expired")
    }

    func testMultipleRapidPresentCallsRespectCooldown() {
        // First call presents the ad
        coordinator.presentAd()
        XCTAssertTrue(mockAd.presentCalled)

        // lastPresentationDate is now set by the first call
        let secondAd = MockPresentableAd()
        mockLoader.adToReturn = secondAd

        // Simulate a reload (as would happen after dismiss)
        coordinator.loadAd()

        // Second call should be blocked by cooldown
        coordinator.presentAd()
        XCTAssertFalse(secondAd.presentCalled,
                       "Second ad should NOT present — cooldown is active")
    }

    // MARK: - No Ad / No Root VC

    func testPresentCallsOnDismissWhenNoAdLoaded() {
        mockLoader.adToReturn = nil
        // Create a new coordinator with nil ad
        let noAdCoordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: mockLoader,
            rootVCProvider: mockRootVC
        )

        var dismissed = false
        noAdCoordinator.presentAd {
            dismissed = true
        }
        XCTAssertTrue(dismissed,
                      "onDismiss should fire when no ad is loaded")
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
        let pastDate = Date().addingTimeInterval(-cooldown - 1)
        let recentDate = Date().addingTimeInterval(-cooldown + 10)

        XCTAssertGreaterThan(Date().timeIntervalSince(pastDate), cooldown,
                             "Past date should be beyond cooldown")
        XCTAssertLessThan(Date().timeIntervalSince(recentDate), cooldown,
                          "Recent date should be within cooldown")
    }

    // MARK: - onDismiss Cleanup

    func testOnDismissIsNilledAfterPresentWithNoAd() {
        mockLoader.adToReturn = nil
        let noAdCoordinator = AdCoordinator(
            settings: mockSettings,
            adLoader: mockLoader,
            rootVCProvider: mockRootVC
        )

        noAdCoordinator.presentAd { }
        XCTAssertNil(noAdCoordinator.onDismiss,
                     "onDismiss should be nil after the no-ad fallback path")
    }
}
