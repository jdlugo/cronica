import Foundation
import GoogleMobileAds
#if os(iOS)
import UIKit
#endif

// MARK: - Protocols for Dependency Injection

/// Abstracts access to the tip jar purchase state for testability.
protocol AdSettingsProviding {
    var hasPurchasedTipJar: Bool { get }
}

extension SettingsStore: AdSettingsProviding {}

struct AdLifecycleEvent: Equatable {
    let placement: String
    let action: String
    let outcome: String
    let metadata: [String: String]

    init(
        placement: String,
        action: String,
        outcome: String,
        metadata: [String: String] = [:]
    ) {
        self.placement = placement
        self.action = action
        self.outcome = outcome
        self.metadata = metadata
    }
}

protocol AdLifecycleTracking {
    func track(_ event: AdLifecycleEvent)
}

struct AdLifecycleTelemetryTracker: AdLifecycleTracking {
    func track(_ event: AdLifecycleEvent) {
        var metadata = event.metadata
        metadata["placement"] = event.placement
        metadata["action"] = event.action
        metadata["outcome"] = event.outcome
        CronicaTelemetry.shared.capture(
            "ad_\(event.placement)_\(event.action)",
            properties: metadata.reduce(into: [String: Any]()) { payload, item in
                payload[item.key] = item.value
            }
        )
    }
}

#if os(iOS)

/// A type that can be presented as a full-screen interstitial ad.
protocol PresentableAd: AnyObject {
    nonisolated func present(from viewController: UIViewController?)
}

extension InterstitialAd: PresentableAd {}

/// Loads interstitial ads and returns them via completion handler.
protocol InterstitialAdLoading {
    func load(delegate: AdCoordinator, completion: @escaping (PresentableAd?) -> Void)
}

/// Loads rewarded ads and returns them via completion handler.
protocol RewardedAdLoading {
    func load(completion: @escaping (RewardedAd?) -> Void)
}

/// A type that can be presented as an app open ad.
protocol AppOpenPresentableAd: AnyObject {
    var fullScreenContentDelegate: FullScreenContentDelegate? { get set }
    nonisolated func present(from viewController: UIViewController?)
}

extension AppOpenAd: AppOpenPresentableAd {}

/// Loads app open ads and returns them via completion handler.
protocol AppOpenAdLoading {
    func load(completion: @escaping (AppOpenPresentableAd?) -> Void)
}

/// Provides the root view controller for ad presentation.
protocol RootViewControllerProviding {
    func rootViewController() -> UIViewController?
}

// MARK: - Production Implementations

final class GoogleInterstitialAdLoader: InterstitialAdLoading {
    func load(delegate: AdCoordinator, completion: @escaping (PresentableAd?) -> Void) {
        let request = Request()
        InterstitialAd.load(
            with: AdConfiguration.AdUnitID.interstitial,
            request: request
        ) { ad, error in
            if let error {
                print("[AdCoordinator] Failed to load interstitial: \(error.localizedDescription)")
                completion(nil)
                return
            }
            ad?.fullScreenContentDelegate = delegate
            completion(ad)
        }
    }
}

final class GoogleRewardedAdLoader: RewardedAdLoading {
    func load(completion: @escaping (RewardedAd?) -> Void) {
        let request = Request()
        RewardedAd.load(
            with: AdConfiguration.AdUnitID.rewarded,
            request: request
        ) { ad, error in
            if let error {
                print("[AdCoordinator] Failed to load rewarded ad: \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(ad)
        }
    }
}

final class GoogleAppOpenAdLoader: AppOpenAdLoading {
    func load(completion: @escaping (AppOpenPresentableAd?) -> Void) {
        let request = Request()
        AppOpenAd.load(
            with: AdConfiguration.AdUnitID.appOpen,
            request: request
        ) { ad, error in
            if let error {
                print("[AdCoordinator] Failed to load app open ad: \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(ad)
        }
    }
}

struct AppRootViewControllerProvider: RootViewControllerProviding {
    func rootViewController() -> UIViewController? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = windowScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? windowScenes.first?.windows.first
        guard let root = keyWindow?.rootViewController else { return nil }

        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        if let navigationController = current as? UINavigationController {
            return navigationController.visibleViewController ?? navigationController
        }
        if let tabBarController = current as? UITabBarController {
            return tabBarController.selectedViewController ?? tabBarController
        }
        return current
    }
}

#endif

// MARK: - AdCoordinator

class AdCoordinator: NSObject, FullScreenContentDelegate {
    var onDismiss: (() -> Void)?
    static var lastPresentationDate: Date?
    static var interstitialSessionStartDate: Date?
    static var interstitialPresentsThisSession: Int = 0
    static var appOpenSessionStartDate: Date?
    static var appOpenPresentsThisSession: Int = 0

    /// Shared singleton — does NOT auto-load; call `loadAd()` after SDK is ready.
    static let shared = AdCoordinator(autoLoad: false)

    let settings: AdSettingsProviding
    private let lifecycleTracker: AdLifecycleTracking
#if os(iOS)
    private(set) var interstitial: (any PresentableAd)?
    let adLoader: InterstitialAdLoading
    let rootVCProvider: RootViewControllerProviding
    private(set) var loadAdCallCount = 0
    private var engagementInterstitialCounts: [InterstitialEngagementTrigger: Int] = [:]
    private var activeInterstitialMetadata: [String: String] = [:]
    private var activeRewardedMetadata: [String: String] = [:]
    fileprivate(set) var isPresentingFullScreenAd = false

    // Rewarded ad support
    private(set) var rewardedAd: RewardedAd?
    let rewardedAdLoader: RewardedAdLoading
    var onRewardEarned: (() -> Void)?
    private var isPresentingHintAdFlow = false
    private(set) var loadRewardedAdCallCount = 0

    // App open ad support
    fileprivate(set) var appOpenAd: (any AppOpenPresentableAd)?
    let appOpenAdLoader: AppOpenAdLoading
    static var lastAppOpenDate: Date?
    private(set) var loadAppOpenAdCallCount = 0
    private lazy var appOpenAdDelegate = AppOpenAdDelegate(coordinator: self)
    fileprivate var pendingAppOpenPresentation = false
    private var isLoadingAppOpenAd = false
    fileprivate var isPresentingAppOpenAd = false

    init(settings: AdSettingsProviding = SettingsStore.shared,
         adLoader: InterstitialAdLoading = GoogleInterstitialAdLoader(),
         rewardedAdLoader: RewardedAdLoading = GoogleRewardedAdLoader(),
         appOpenAdLoader: AppOpenAdLoading = GoogleAppOpenAdLoader(),
         rootVCProvider: RootViewControllerProviding = AppRootViewControllerProvider(),
         lifecycleTracker: AdLifecycleTracking = AdLifecycleTelemetryTracker(),
         autoLoad: Bool = true) {
        self.settings = settings
        self.adLoader = adLoader
        self.rewardedAdLoader = rewardedAdLoader
        self.appOpenAdLoader = appOpenAdLoader
        self.rootVCProvider = rootVCProvider
        self.lifecycleTracker = lifecycleTracker
        super.init()
        if autoLoad { loadAd() }
    }
#else
    init(settings: AdSettingsProviding = SettingsStore.shared,
         lifecycleTracker: AdLifecycleTracking = AdLifecycleTelemetryTracker(),
         autoLoad: Bool = true) {
        self.settings = settings
        self.lifecycleTracker = lifecycleTracker
        super.init()
    }
#endif

    fileprivate func trackAdLifecycle(
        placement: String,
        action: String,
        outcome: String,
        metadata: [String: String] = [:]
    ) {
        lifecycleTracker.track(.init(
            placement: placement,
            action: action,
            outcome: outcome,
            metadata: metadata
        ))
    }

    private func interstitialPresentationBlockReason(now: Date = Date()) -> String? {
        if let last = Self.lastPresentationDate,
           now.timeIntervalSince(last) < AdConfiguration.interstitialCooldown {
            return "cooldown"
        }

        if let sessionStart = Self.interstitialSessionStartDate,
           now.timeIntervalSince(sessionStart) >= AdConfiguration.interstitialSessionWindow {
            Self.interstitialSessionStartDate = nil
            Self.interstitialPresentsThisSession = 0
        }

        if Self.interstitialSessionStartDate == nil {
            Self.interstitialSessionStartDate = now
            Self.interstitialPresentsThisSession = 0
        }

        if Self.interstitialPresentsThisSession >= AdConfiguration.maxInterstitialPresentsPerSession {
            return "session_limit_reached"
        }

        return nil
    }

    private func appOpenPresentationBlockReason(now: Date = Date()) -> String? {
        if let last = Self.lastAppOpenDate,
           now.timeIntervalSince(last) < AdConfiguration.appOpenCooldown {
            return "cooldown"
        }

        if let sessionStart = Self.appOpenSessionStartDate,
           now.timeIntervalSince(sessionStart) >= AdConfiguration.appOpenSessionWindow {
            Self.appOpenSessionStartDate = nil
            Self.appOpenPresentsThisSession = 0
        }

        if Self.appOpenSessionStartDate == nil {
            Self.appOpenSessionStartDate = now
            Self.appOpenPresentsThisSession = 0
        }

        if Self.appOpenPresentsThisSession >= AdConfiguration.maxAppOpenPresentsPerSession {
            return "session_limit_reached"
        }

        return nil
    }

    private func noteInterstitialPresented(at now: Date = Date()) {
        if let sessionStart = Self.interstitialSessionStartDate,
           now.timeIntervalSince(sessionStart) >= AdConfiguration.interstitialSessionWindow {
            Self.interstitialSessionStartDate = now
            Self.interstitialPresentsThisSession = 0
        } else if Self.interstitialSessionStartDate == nil {
            Self.interstitialSessionStartDate = now
            Self.interstitialPresentsThisSession = 0
        }

        Self.lastPresentationDate = now
        Self.interstitialPresentsThisSession += 1
    }

    private func noteAppOpenPresented(at now: Date = Date()) {
        if let sessionStart = Self.appOpenSessionStartDate,
           now.timeIntervalSince(sessionStart) >= AdConfiguration.appOpenSessionWindow {
            Self.appOpenSessionStartDate = now
            Self.appOpenPresentsThisSession = 0
        } else if Self.appOpenSessionStartDate == nil {
            Self.appOpenSessionStartDate = now
            Self.appOpenPresentsThisSession = 0
        }

        Self.lastAppOpenDate = now
        Self.appOpenPresentsThisSession += 1
    }

    func loadAd() {
        // Don't waste network requests if user purchased ad-free
        if settings.hasPurchasedTipJar {
            trackAdLifecycle(placement: "interstitial", action: "load", outcome: "skipped_paid")
            return
        }

#if os(iOS)
        loadAdCallCount += 1
        trackAdLifecycle(placement: "interstitial", action: "load", outcome: "requested")
        adLoader.load(delegate: self) { [weak self] ad in
            guard let self else { return }
            self.interstitial = ad
            self.trackAdLifecycle(
                placement: "interstitial",
                action: "load",
                outcome: ad == nil ? "no_fill_or_error" : "loaded"
            )
        }
#endif
    }

    /// Ensures we have an interstitial ready without issuing duplicate loads.
    func ensureInterstitialLoaded() {
#if os(iOS)
        guard interstitial == nil else { return }
        loadAd()
#endif
    }

    func presentInterstitialForEngagement(
        _ trigger: InterstitialEngagementTrigger,
        metadata: [String: String] = [:],
        monetizationDisabled: Bool = false,
        onDismiss: (() -> Void)? = nil
    ) {
        if monetizationDisabled {
            trackAdLifecycle(
                placement: "interstitial",
                action: "engagement",
                outcome: "skipped_runtime",
                metadata: metadata.merging(["trigger": trigger.rawValue]) { _, new in new }
            )
            onDismiss?()
            return
        }

        if settings.hasPurchasedTipJar {
            trackAdLifecycle(
                placement: "interstitial",
                action: "engagement",
                outcome: "skipped_paid",
                metadata: metadata.merging(["trigger": trigger.rawValue]) { _, new in new }
            )
            onDismiss?()
            return
        }

#if os(iOS)
        let engagementInterstitialCount = (engagementInterstitialCounts[trigger] ?? 0) + 1
        engagementInterstitialCounts[trigger] = engagementInterstitialCount
        let metadata = metadata.merging([
            "trigger": trigger.rawValue,
            "engagement_count": "\(engagementInterstitialCount)"
        ]) { _, new in new }

        guard engagementInterstitialCount % trigger.presentationInterval == 0 else {
            trackAdLifecycle(
                placement: "interstitial",
                action: "engagement",
                outcome: "deferred",
                metadata: metadata
            )
            ensureInterstitialLoaded()
            onDismiss?()
            return
        }

        trackAdLifecycle(
            placement: "interstitial",
            action: "engagement",
            outcome: "presenting",
            metadata: metadata
        )
        presentAd(metadata: metadata, onDismiss: onDismiss)
#else
        onDismiss?()
#endif
    }

    /// Present an interstitial ad. Calls `onDismiss` after the ad is dismissed
    /// (or immediately if no ad is available / cooldown active / user is ad-free).
    func presentAd(
        metadata: [String: String] = [:],
        onDismiss: (() -> Void)? = nil
    ) {
        self.onDismiss = onDismiss

#if os(iOS)
        // Skip ads for tip jar purchasers
        if settings.hasPurchasedTipJar {
            trackAdLifecycle(
                placement: "interstitial",
                action: "present",
                outcome: "skipped_paid",
                metadata: metadata
            )
            self.onDismiss?()
            self.onDismiss = nil
            return
        }

        trackAdLifecycle(
            placement: "interstitial",
            action: "present",
            outcome: "attempted",
            metadata: metadata
        )

        let now = Date()
        if let blockReason = interstitialPresentationBlockReason(now: now) {
            trackAdLifecycle(
                placement: "interstitial",
                action: "present",
                outcome: blockReason,
                metadata: metadata.merging(["block_reason": blockReason]) { _, new in new }
            )
            ensureInterstitialLoaded()
            self.onDismiss?()
            self.onDismiss = nil
            return
        }

        guard let interstitial else {
            // Recover quickly when launch-time preload misses.
            trackAdLifecycle(
                placement: "interstitial",
                action: "present",
                outcome: "no_inventory",
                metadata: metadata
            )
            ensureInterstitialLoaded()
            self.onDismiss?()
            self.onDismiss = nil
            return
        }

        guard let root = rootVCProvider.rootViewController() else {
            trackAdLifecycle(
                placement: "interstitial",
                action: "present",
                outcome: "no_root_view_controller",
                metadata: metadata
            )
            ensureInterstitialLoaded()
            self.onDismiss?()
            self.onDismiss = nil
            return
        }

        noteInterstitialPresented(at: now)
        trackAdLifecycle(
            placement: "interstitial",
            action: "present",
            outcome: "presented",
            metadata: metadata
        )
        activeInterstitialMetadata = metadata
        interstitial.present(from: root)
#else
        self.onDismiss?()
        self.onDismiss = nil
#endif
    }

    // MARK: - Rewarded Ad

    func loadRewardedAd() {
        if settings.hasPurchasedTipJar {
            trackAdLifecycle(placement: "rewarded", action: "load", outcome: "skipped_paid")
            return
        }

#if os(iOS)
        loadRewardedAdCallCount += 1
        trackAdLifecycle(placement: "rewarded", action: "load", outcome: "requested")
        rewardedAdLoader.load { [weak self] ad in
            guard let self else { return }
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.trackAdLifecycle(
                placement: "rewarded",
                action: "load",
                outcome: ad == nil ? "no_fill_or_error" : "loaded"
            )
        }
#endif
    }

    func ensureRewardedAdLoaded() {
#if os(iOS)
        guard rewardedAd == nil else { return }
        loadRewardedAd()
#endif
    }

    /// Present a rewarded ad. No cooldown — user-initiated.
    func presentRewardedAd(onRewardEarned: @escaping () -> Void) {
#if os(iOS)
        if settings.hasPurchasedTipJar {
            trackAdLifecycle(placement: "rewarded", action: "present", outcome: "skipped_paid")
            return
        }

        trackAdLifecycle(placement: "rewarded", action: "present", outcome: "attempted")

        guard let rewardedAd else {
            trackAdLifecycle(placement: "rewarded", action: "present", outcome: "no_inventory")
            ensureRewardedAdLoaded()
            return
        }

        guard let root = rootVCProvider.rootViewController() else {
            trackAdLifecycle(placement: "rewarded", action: "present", outcome: "no_root_view_controller")
            ensureRewardedAdLoaded()
            return
        }

        self.onRewardEarned = onRewardEarned
        trackAdLifecycle(placement: "rewarded", action: "present", outcome: "presented")
        activeRewardedMetadata = ["flow": "rewarded"]
        rewardedAd.present(from: root) { [weak self] in
            self?.onRewardEarned?()
            self?.onRewardEarned = nil
        }
#endif
    }

    /// Presents a loaded rewarded ad from an explicit hint request.
    /// Never queues a later presentation or substitutes a regular interstitial.
    func presentHintAd(
        metadata: [String: String] = [:],
        onUnavailable: (() -> Void)? = nil,
        onHintUnlocked: @escaping () -> Void
    ) {
#if os(iOS)
        if settings.hasPurchasedTipJar {
            trackAdLifecycle(
                placement: "hint",
                action: "present",
                outcome: "skipped_paid",
                metadata: metadata
            )
            onHintUnlocked()
            return
        }

        trackAdLifecycle(
            placement: "hint",
            action: "present",
            outcome: "attempted",
            metadata: metadata
        )

        guard !isPresentingHintAdFlow else {
            trackAdLifecycle(
                placement: "hint",
                action: "present",
                outcome: "already_presenting",
                metadata: metadata
            )
            onUnavailable?()
            return
        }

        guard let rewardedAd else {
            trackAdLifecycle(
                placement: "hint",
                action: "present",
                outcome: "rewarded_unavailable",
                metadata: metadata
            )
            ensureRewardedAdLoaded()
            onUnavailable?()
            return
        }

        guard let root = rootVCProvider.rootViewController() else {
            trackAdLifecycle(
                placement: "hint",
                action: "present",
                outcome: "no_root_view_controller",
                metadata: metadata
            )
            onUnavailable?()
            return
        }

        isPresentingHintAdFlow = true
        trackAdLifecycle(
            placement: "hint",
            action: "present",
            outcome: "rewarded_presented",
            metadata: metadata
        )
        trackAdLifecycle(
            placement: "rewarded",
            action: "present",
            outcome: "attempted",
            metadata: metadata.merging(["flow": "hint"]) { _, new in new }
        )
        onRewardEarned = { [weak self] in
            onHintUnlocked()
            self?.isPresentingHintAdFlow = false
        }
        activeRewardedMetadata = metadata.merging(["flow": "hint"]) { _, new in new }
        rewardedAd.present(from: root) { [weak self] in
            self?.onRewardEarned?()
            self?.onRewardEarned = nil
        }
        trackAdLifecycle(
            placement: "rewarded",
            action: "present",
            outcome: "presented",
            metadata: metadata.merging(["flow": "hint"]) { _, new in new }
        )
#endif
    }

    // MARK: - App Open Ad

    func loadAppOpenAd() {
        if settings.hasPurchasedTipJar {
            trackAdLifecycle(placement: "app_open", action: "load", outcome: "skipped_paid")
            return
        }

#if os(iOS)
        guard !isLoadingAppOpenAd else {
            trackAdLifecycle(placement: "app_open", action: "load", outcome: "already_loading")
            return
        }
        isLoadingAppOpenAd = true
        loadAppOpenAdCallCount += 1
        trackAdLifecycle(placement: "app_open", action: "load", outcome: "requested")
        appOpenAdLoader.load { [weak self] ad in
            guard let self else { return }
            self.isLoadingAppOpenAd = false
            self.appOpenAd = ad
            self.appOpenAd?.fullScreenContentDelegate = self.appOpenAdDelegate
            self.trackAdLifecycle(
                placement: "app_open",
                action: "load",
                outcome: ad == nil ? "no_fill_or_error" : "loaded"
            )
            self.presentPendingAppOpenAdIfPossible()
        }
#endif
    }

    func presentAppOpenAd() {
#if os(iOS)
        if settings.hasPurchasedTipJar {
            trackAdLifecycle(placement: "app_open", action: "present", outcome: "skipped_paid")
            return
        }

        guard !isPresentingAppOpenAd else {
            trackAdLifecycle(placement: "app_open", action: "present", outcome: "already_presenting")
            return
        }

        let attemptMetadata = ["source": "foreground"]
        trackAdLifecycle(
            placement: "app_open",
            action: "present",
            outcome: "attempted",
            metadata: attemptMetadata
        )

        let now = Date()
        if let blockReason = appOpenPresentationBlockReason(now: now) {
            trackAdLifecycle(
                placement: "app_open",
                action: "present",
                outcome: blockReason,
                metadata: attemptMetadata.merging(["block_reason": blockReason]) { _, new in new }
            )
            return
        }

        pendingAppOpenPresentation = true

        guard let appOpenAd else {
            trackAdLifecycle(placement: "app_open", action: "present", outcome: "no_inventory")
            loadAppOpenAd()
            return
        }

        self.appOpenAd = appOpenAd
        presentPendingAppOpenAdIfPossible()
#endif
    }

    private func presentPendingAppOpenAdIfPossible() {
#if os(iOS)
        guard pendingAppOpenPresentation,
              !isPresentingAppOpenAd,
              let appOpenAd else {
            return
        }

        let now = Date()
        if let blockReason = appOpenPresentationBlockReason(now: now) {
            trackAdLifecycle(
                placement: "app_open",
                action: "present",
                outcome: blockReason,
                metadata: ["source": "foreground", "block_reason": blockReason]
            )
            pendingAppOpenPresentation = false
            return
        }

        guard let root = rootVCProvider.rootViewController() else {
            trackAdLifecycle(placement: "app_open", action: "present", outcome: "no_root_view_controller")
            return
        }

        pendingAppOpenPresentation = false
        isPresentingAppOpenAd = true
        self.appOpenAd = nil
        noteAppOpenPresented(at: now)
        trackAdLifecycle(placement: "app_open", action: "present", outcome: "presented")
        appOpenAd.present(from: root)
#endif
    }

    // MARK: - Extracted for Testability

    /// Called when an ad is dismissed. Fires the onDismiss callback and reloads.
    func handleAdDismissed() {
        let metadata = activeInterstitialMetadata
        activeInterstitialMetadata = [:]
        trackAdLifecycle(
            placement: "interstitial",
            action: "dismiss",
            outcome: "dismissed",
            metadata: metadata
        )
        onDismiss?()
        onDismiss = nil
        loadAd()
    }

    /// Called when an ad fails to present. Fires the onDismiss callback and reloads.
    func handleAdFailedToPresent(error: Error) {
        print("[AdCoordinator] Failed to present: \(error.localizedDescription)")
        let metadata = activeInterstitialMetadata.merging(
            ["error": error.localizedDescription]
        ) { _, new in new }
        activeInterstitialMetadata = [:]
        trackAdLifecycle(
            placement: "interstitial",
            action: "present",
            outcome: "failed",
            metadata: metadata
        )
        onDismiss?()
        onDismiss = nil
        loadAd()
    }

    // MARK: - FullScreenContentDelegate (interstitial + rewarded)

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isPresentingFullScreenAd = false
        if ad is RewardedAd {
            let metadata = activeRewardedMetadata
            activeRewardedMetadata = [:]
            trackAdLifecycle(
                placement: "rewarded",
                action: "dismiss",
                outcome: "dismissed",
                metadata: metadata
            )
            onRewardEarned = nil
            isPresentingHintAdFlow = false
            loadRewardedAd()
        } else {
            handleAdDismissed()
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        isPresentingFullScreenAd = false
        if ad is RewardedAd {
            print("[AdCoordinator] Failed to present rewarded ad: \(error.localizedDescription)")
            let metadata = activeRewardedMetadata.merging(
                ["error": error.localizedDescription]
            ) { _, new in new }
            activeRewardedMetadata = [:]
            trackAdLifecycle(
                placement: "rewarded",
                action: "present",
                outcome: "failed",
                metadata: metadata
            )
            onRewardEarned = nil
            isPresentingHintAdFlow = false
            loadRewardedAd()
        } else {
            handleAdFailedToPresent(error: error)
        }
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        let metadata = ad is RewardedAd ? activeRewardedMetadata : activeInterstitialMetadata
        trackAdLifecycle(
            placement: ad is RewardedAd ? "rewarded" : "interstitial",
            action: "impression",
            outcome: "recorded",
            metadata: metadata
        )
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        let metadata = ad is RewardedAd ? activeRewardedMetadata : activeInterstitialMetadata
        trackAdLifecycle(
            placement: ad is RewardedAd ? "rewarded" : "interstitial",
            action: "click",
            outcome: "recorded",
            metadata: metadata
        )
    }
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        isPresentingFullScreenAd = true
    }
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {}
}

// MARK: - App Open Ad Delegate

#if os(iOS)
private class AppOpenAdDelegate: NSObject, FullScreenContentDelegate {
    weak var coordinator: AdCoordinator?

    init(coordinator: AdCoordinator) {
        self.coordinator = coordinator
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        coordinator?.isPresentingFullScreenAd = false
        coordinator?.trackAdLifecycle(placement: "app_open", action: "dismiss", outcome: "dismissed")
        coordinator?.pendingAppOpenPresentation = false
        coordinator?.isPresentingAppOpenAd = false
        coordinator?.appOpenAd = nil
        coordinator?.loadAppOpenAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        coordinator?.isPresentingFullScreenAd = false
        print("[AdCoordinator] App open ad failed to present: \(error.localizedDescription)")
        coordinator?.trackAdLifecycle(
            placement: "app_open",
            action: "present",
            outcome: "failed",
            metadata: ["error": error.localizedDescription]
        )
        coordinator?.pendingAppOpenPresentation = false
        coordinator?.isPresentingAppOpenAd = false
        coordinator?.appOpenAd = nil
        coordinator?.loadAppOpenAd()
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        coordinator?.trackAdLifecycle(placement: "app_open", action: "impression", outcome: "recorded")
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        coordinator?.trackAdLifecycle(placement: "app_open", action: "click", outcome: "recorded")
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        coordinator?.isPresentingFullScreenAd = true
    }
}
#endif
