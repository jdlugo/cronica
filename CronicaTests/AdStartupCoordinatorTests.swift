import XCTest
import UIKit
@testable import StreamingNow

final class AdStartupCoordinatorTests: XCTestCase {
    func testStartAdsGathersConsentBeforeStartingOrPreloading() async {
        let recorder = StartupCallOrderRecorder()
        let coordinator = AdStartupCoordinator(
            mobileAdsStarter: OrderedMobileAdsStarter(recorder: recorder),
            consentGatherer: OrderedConsentGatherer(recorder: recorder),
            adRequestEligibilityProvider: AllowedAdRequestEligibilityProvider(),
            adPreloader: OrderedAdPreloader(recorder: recorder)
        )

        await coordinator.startAdsIfNeeded(
            monetizationDisabled: false,
            rootViewController: nil as UIViewController?
        )

        XCTAssertEqual(recorder.calls, ["consent", "mobile_ads", "preload"])
    }

    func testStartAdsSkipsSDKAndPreloadWhenConsentDeniesAdRequests() async {
        let recorder = StartupCallOrderRecorder()
        let coordinator = AdStartupCoordinator(
            mobileAdsStarter: OrderedMobileAdsStarter(recorder: recorder),
            consentGatherer: DeniedConsentGatherer(recorder: recorder),
            adRequestEligibilityProvider: DeniedAdRequestEligibilityProvider(),
            adPreloader: OrderedAdPreloader(recorder: recorder)
        )

        await coordinator.startAdsIfNeeded(
            monetizationDisabled: false,
            rootViewController: nil as UIViewController?
        )

        XCTAssertEqual(recorder.calls, ["consent_denied"])
    }

    func testStartAdsGathersConsentOnMainThreadWhenCalledOffMainActor() async {
        let consentGatherer = ConsentThreadRecorder()
        let coordinator = AdStartupCoordinator(
            mobileAdsStarter: MobileAdsStarterSpy(),
            consentGatherer: consentGatherer,
            adPreloader: AdPreloaderSpy()
        )

        await Task.detached {
            await coordinator.startAdsIfNeeded(
                monetizationDisabled: false,
                rootViewController: nil as UIViewController?
            )
        }.value

        XCTAssertTrue(consentGatherer.wasCalledOnMainThread)
    }


    func testStartAdsWaitsForConsentBeforeStartingOrPreloading() async {
        let mobileAds = MobileAdsStarterSpy()
        let consent = ConsentGathererSpy()
        consent.shouldSuspend = true
        let preloader = AdPreloaderSpy()

        let coordinator = AdStartupCoordinator(
            mobileAdsStarter: mobileAds,
            consentGatherer: consent,
            adPreloader: preloader
        )

        let task = Task {
            await coordinator.startAdsIfNeeded(
                monetizationDisabled: false,
                rootViewController: UIViewController()
            )
        }

        for _ in 0..<20 where consent.gatherCallCount == 0 {
            try? await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(consent.gatherCallCount, 1, "Consent should be gathered first")
        XCTAssertEqual(mobileAds.startCallCount, 0, "Mobile Ads must wait for consent")
        XCTAssertEqual(preloader.preloadCallCount, 0, "Ad preloading must wait for consent")

        task.cancel()
    }

    func testStartAdsSkipsAllWorkWhenMonetizationDisabled() async {
        let mobileAds = MobileAdsStarterSpy()
        let consent = ConsentGathererSpy()
        let preloader = AdPreloaderSpy()

        let coordinator = AdStartupCoordinator(
            mobileAdsStarter: mobileAds,
            consentGatherer: consent,
            adPreloader: preloader
        )

        await coordinator.startAdsIfNeeded(
            monetizationDisabled: true,
            rootViewController: nil
        )

        XCTAssertEqual(mobileAds.startCallCount, 0)
        XCTAssertEqual(preloader.preloadCallCount, 0)
        XCTAssertEqual(consent.gatherCallCount, 0)
    }

    func testSharedPreloaderRequestsOnlyLaunchVisibleInventory() async {
        let adCoordinator = AdPreloadCoordinatorSpy()
        let preloader = SharedAdPreloader(adCoordinator: adCoordinator)

        await preloader.preloadAds()

        XCTAssertEqual(
            adCoordinator.loadInterstitialCallCount,
            0,
            "Policy-review builds must not preload regular interstitial inventory."
        )
        XCTAssertEqual(adCoordinator.loadAppOpenCallCount, 1)
        XCTAssertEqual(
            adCoordinator.loadRewardedCallCount,
            0,
            "Rewarded ads should be requested when the hint surface is visible, not on every app launch."
        )
    }

    func testForegroundCoordinatorPresentsLaunchVisibleAdsWhenMonetizationEnabled() {
        let presenter = AdForegroundPresenterSpy()
        let coordinator = AdForegroundPresentationCoordinator(adPresenter: presenter)

        coordinator.presentForegroundAdsIfNeeded(monetizationDisabled: false)

        XCTAssertEqual(presenter.ensureInterstitialLoadedCallCount, 0)
        XCTAssertEqual(presenter.presentAppOpenAdCallCount, 1)
    }

    func testForegroundCoordinatorSkipsWorkWhenMonetizationDisabled() {
        let presenter = AdForegroundPresenterSpy()
        let coordinator = AdForegroundPresentationCoordinator(adPresenter: presenter)

        coordinator.presentForegroundAdsIfNeeded(monetizationDisabled: true)

        XCTAssertEqual(presenter.ensureInterstitialLoadedCallCount, 0)
        XCTAssertEqual(presenter.presentAppOpenAdCallCount, 0)
    }
}

private final class StartupCallOrderRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedCalls: [String] = []

    var calls: [String] {
        lock.withLock { recordedCalls }
    }

    func append(_ call: String) {
        lock.withLock {
            recordedCalls.append(call)
        }
    }
}

private struct OrderedMobileAdsStarter: MobileAdsStarting {
    let recorder: StartupCallOrderRecorder

    func start() async {
        recorder.append("mobile_ads")
    }
}

private struct OrderedConsentGatherer: AdConsentGathering {
    let recorder: StartupCallOrderRecorder

    @MainActor
    func gatherConsentIfPossible(from viewController: UIViewController?) async {
        recorder.append("consent")
    }
}

private struct OrderedAdPreloader: AdPreloading {
    let recorder: StartupCallOrderRecorder

    func preloadAds() async {
        recorder.append("preload")
    }
}

private struct DeniedConsentGatherer: AdConsentGathering {
    let recorder: StartupCallOrderRecorder

    @MainActor
    func gatherConsentIfPossible(from viewController: UIViewController?) async {
        recorder.append("consent_denied")
    }
}

private struct DeniedAdRequestEligibilityProvider: AdRequestEligibilityProviding {
    @MainActor
    var canRequestAds: Bool { false }
}

private struct AllowedAdRequestEligibilityProvider: AdRequestEligibilityProviding {
    @MainActor
    var canRequestAds: Bool { true }
}

private final class ConsentThreadRecorder: AdConsentGathering, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedMainThread = false

    var wasCalledOnMainThread: Bool {
        lock.withLock { recordedMainThread }
    }

    func gatherConsentIfPossible(from viewController: UIViewController?) async {
        lock.withLock {
            recordedMainThread = Thread.isMainThread
        }
    }
}

private final class MobileAdsStarterSpy: MobileAdsStarting {
    private(set) var startCallCount = 0

    func start() async {
        startCallCount += 1
    }
}

private final class ConsentGathererSpy: AdConsentGathering {
    private(set) var gatherCallCount = 0
    var shouldSuspend = false

    func gatherConsentIfPossible(from viewController: UIViewController?) async {
        gatherCallCount += 1
        if shouldSuspend {
            try? await Task.sleep(for: .seconds(5))
        }
    }
}

private final class AdPreloaderSpy: AdPreloading {
    private(set) var preloadCallCount = 0

    func preloadAds() async {
        preloadCallCount += 1
    }
}

private final class AdPreloadCoordinatorSpy: AdPreloadCoordinating {
    private(set) var loadInterstitialCallCount = 0
    private(set) var loadRewardedCallCount = 0
    private(set) var loadAppOpenCallCount = 0

    func loadAd() {
        loadInterstitialCallCount += 1
    }

    func loadRewardedAd() {
        loadRewardedCallCount += 1
    }

    func loadAppOpenAd() {
        loadAppOpenCallCount += 1
    }
}

private final class AdForegroundPresenterSpy: AdForegroundPresenting {
    private(set) var ensureInterstitialLoadedCallCount = 0
    private(set) var presentAppOpenAdCallCount = 0

    func ensureInterstitialLoaded() {
        ensureInterstitialLoadedCallCount += 1
    }

    func presentAppOpenAd() {
        presentAppOpenAdCallCount += 1
    }
}
