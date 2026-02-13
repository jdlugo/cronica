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

struct AppRootViewControllerProvider: RootViewControllerProviding {
    func rootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }
        return window.rootViewController
    }
}

#endif

// MARK: - AdCoordinator

class AdCoordinator: NSObject, FullScreenContentDelegate {
    var onDismiss: (() -> Void)?
    static var lastPresentationDate: Date?

    let settings: AdSettingsProviding
#if os(iOS)
    private(set) var interstitial: (any PresentableAd)?
    let adLoader: InterstitialAdLoading
    let rootVCProvider: RootViewControllerProviding
    private(set) var loadAdCallCount = 0

    init(settings: AdSettingsProviding = SettingsStore.shared,
         adLoader: InterstitialAdLoading = GoogleInterstitialAdLoader(),
         rootVCProvider: RootViewControllerProviding = AppRootViewControllerProvider()) {
        self.settings = settings
        self.adLoader = adLoader
        self.rootVCProvider = rootVCProvider
        super.init()
        loadAd()
    }
#else
    init(settings: AdSettingsProviding = SettingsStore.shared) {
        self.settings = settings
        super.init()
    }
#endif

    func loadAd() {
        // Don't waste network requests if user purchased ad-free
        if settings.hasPurchasedTipJar { return }

#if os(iOS)
        loadAdCallCount += 1
        adLoader.load(delegate: self) { [weak self] ad in
            self?.interstitial = ad
        }
#endif
    }

    /// Present an interstitial ad. Calls `onDismiss` after the ad is dismissed
    /// (or immediately if no ad is available / cooldown active / user is ad-free).
    func presentAd(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss

#if os(iOS)
        // Skip ads for tip jar purchasers
        if settings.hasPurchasedTipJar {
            self.onDismiss?()
            self.onDismiss = nil
            return
        }

        // Frequency cap: skip if shown too recently
        if let last = Self.lastPresentationDate,
           Date().timeIntervalSince(last) < AdConfiguration.interstitialCooldown {
            self.onDismiss?()
            self.onDismiss = nil
            return
        }

        guard let interstitial,
              let root = rootVCProvider.rootViewController() else {
            self.onDismiss?()
            self.onDismiss = nil
            return
        }

        Self.lastPresentationDate = Date()
        interstitial.present(from: root)
#else
        self.onDismiss?()
        self.onDismiss = nil
#endif
    }

    // MARK: - Extracted for Testability

    /// Called when an ad is dismissed. Fires the onDismiss callback and reloads.
    func handleAdDismissed() {
        onDismiss?()
        onDismiss = nil
        loadAd()
    }

    /// Called when an ad fails to present. Fires the onDismiss callback and reloads.
    func handleAdFailedToPresent(error: Error) {
        print("[AdCoordinator] Failed to present: \(error.localizedDescription)")
        onDismiss?()
        onDismiss = nil
        loadAd()
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        handleAdDismissed()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        handleAdFailedToPresent(error: error)
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {}
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {}
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {}
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {}
}
