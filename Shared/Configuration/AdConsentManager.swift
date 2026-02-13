import Foundation
import GoogleMobileAds
#if os(iOS)
import AppTrackingTransparency
import UserMessagingPlatform
#endif

/// Manages UMP consent and ATT authorization before ads are loaded.
enum AdConsentManager {
#if os(iOS)
    /// Request UMP consent info update, present the consent form if needed, then request ATT.
    /// Call this once at app launch before loading ads.
    static func gatherConsent(from viewController: UIViewController) async {
        // 1. Update UMP consent information
        let parameters = UMPRequestParameters()
        parameters.tagForUnderAgeOfConsent = false

        do {
            try await UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters)
        } catch {
            print("[AdConsentManager] UMP info update failed: \(error.localizedDescription)")
        }

        // 2. Load and present consent form if required
        do {
            try await UMPConsentForm.loadAndPresentIfRequired(from: viewController)
        } catch {
            print("[AdConsentManager] UMP form error: \(error.localizedDescription)")
        }

        // 3. Request ATT authorization (has no effect if user already responded)
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
    }

    /// Whether we can serve personalized ads based on current consent status.
    static var canRequestAds: Bool {
        UMPConsentInformation.sharedInstance.canRequestAds
    }
#endif
}
