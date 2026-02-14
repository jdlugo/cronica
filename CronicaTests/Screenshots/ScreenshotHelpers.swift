import SnapshotTesting
import SwiftUI
import UIKit

/// Device configurations matching App Store required screenshot sizes.
///
/// Screenshot filenames include locale, device, and pixel dimensions for easy
/// App Store Connect identification: `en-US_iPhone_6.9in_1320x2868`.
enum ScreenshotDevice: String, CaseIterable {
    /// 6.9" — iPhone 16 Pro Max / 15 Pro Max (required by App Store)
    case iPhone6_9 = "iPhone_6.9"
    /// 6.5" — iPhone 14 Pro Max / 13 Pro Max (required by App Store)
    case iPhone6_5 = "iPhone_6.5"
    /// 13" — iPad Pro 13" M5 (required by App Store)
    case iPad13 = "iPad_13"
    /// 11" — iPad Pro 11" M5 (optional, good coverage)
    case iPad11 = "iPad_11"

    /// Descriptive filename for App Store screenshots.
    /// Format: `{locale}_{device}_{pixelW}x{pixelH}`
    func screenshotName(locale: String = "en-US") -> String {
        switch self {
        case .iPhone6_9: return "\(locale)_iPhone_6.9in_1320x2868"
        case .iPhone6_5: return "\(locale)_iPhone_6.5in_1290x2796"
        case .iPad13:    return "\(locale)_iPad_13in_2064x2752"
        case .iPad11:    return "\(locale)_iPad_11in_1668x2420"
        }
    }

    var config: ViewImageConfig {
        switch self {
        case .iPhone6_9:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
                size: CGSize(width: 440, height: 956),
                traits: UITraitCollection(traitsFrom: [
                    .init(displayScale: 3),
                    .init(userInterfaceStyle: .dark)
                ])
            )
        case .iPhone6_5:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
                size: CGSize(width: 430, height: 932),
                traits: UITraitCollection(traitsFrom: [
                    .init(displayScale: 3),
                    .init(userInterfaceStyle: .dark)
                ])
            )
        case .iPad13:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
                size: CGSize(width: 1032, height: 1376),
                traits: UITraitCollection(traitsFrom: [
                    .init(displayScale: 2),
                    .init(userInterfaceStyle: .dark),
                    .init(horizontalSizeClass: .regular),
                    .init(verticalSizeClass: .regular)
                ])
            )
        case .iPad11:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
                size: CGSize(width: 834, height: 1210),
                traits: UITraitCollection(traitsFrom: [
                    .init(displayScale: 2),
                    .init(userInterfaceStyle: .dark),
                    .init(horizontalSizeClass: .regular),
                    .init(verticalSizeClass: .regular)
                ])
            )
        }
    }
}

/// Watch device configurations for App Store screenshots.
///
/// Separate enum to avoid polluting `ScreenshotDevice.allCases` used by iOS tests.
/// Renders watch-sized SwiftUI views through the iOS test target at watch point dimensions.
enum WatchScreenshotDevice: String, CaseIterable {
    /// Series 9/8/7 (45mm) — 396×484 pixels @2x
    case watch45mm = "Watch_45mm"
    /// Ultra 2 (49mm) — 410×502 pixels @2x
    case watchUltra = "Watch_Ultra"

    func screenshotName(locale: String = "en-US") -> String {
        switch self {
        case .watch45mm:  return "\(locale)_Watch_45mm_396x484"
        case .watchUltra: return "\(locale)_Watch_Ultra_410x502"
        }
    }

    var config: ViewImageConfig {
        switch self {
        case .watch45mm:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
                size: CGSize(width: 198, height: 242),
                traits: UITraitCollection(traitsFrom: [
                    .init(displayScale: 2),
                    .init(userInterfaceStyle: .dark)
                ])
            )
        case .watchUltra:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
                size: CGSize(width: 205, height: 251),
                traits: UITraitCollection(traitsFrom: [
                    .init(displayScale: 2),
                    .init(userInterfaceStyle: .dark)
                ])
            )
        }
    }
}

/// Common setup for screenshot tests — hides ads and disables onboarding.
enum ScreenshotSetup {
    static func configure() {
        UserDefaults.standard.set(true, forKey: "userHasPurchasedTipJar")
        UserDefaults.standard.set(false, forKey: "showOnboarding")
        // Disable the app's translucent background — Material effects don't render
        // in snapshot tests. DetailScreenshotView uses its own explicit overlay instead.
        UserDefaults.standard.set(true, forKey: "disableTranslucentBackground")
    }

    static func tearDown() {
        UserDefaults.standard.removeObject(forKey: "userHasPurchasedTipJar")
        UserDefaults.standard.removeObject(forKey: "showOnboarding")
        UserDefaults.standard.removeObject(forKey: "disableTranslucentBackground")
    }
}
