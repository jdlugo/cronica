import SnapshotTesting
import SwiftUI
import UIKit

/// Device configurations matching App Store required screenshot sizes.
enum ScreenshotDevice: String, CaseIterable {
    /// 6.9" — iPhone 16 Pro Max / 15 Pro Max (required by App Store)
    case iPhone6_9 = "iPhone_6.9"
    /// 6.5" — iPhone 14 Pro Max / 13 Pro Max (required by App Store)
    case iPhone6_5 = "iPhone_6.5"

    var config: ViewImageConfig {
        switch self {
        case .iPhone6_9:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                size: CGSize(width: 440, height: 956),
                traits: UITraitCollection(traitsFrom: [
                    .init(displayScale: 3),
                    .init(userInterfaceStyle: .dark)
                ])
            )
        case .iPhone6_5:
            return ViewImageConfig(
                safeArea: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                size: CGSize(width: 430, height: 932),
                traits: UITraitCollection(traitsFrom: [
                    .init(displayScale: 3),
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
    }

    static func tearDown() {
        UserDefaults.standard.removeObject(forKey: "userHasPurchasedTipJar")
        UserDefaults.standard.removeObject(forKey: "showOnboarding")
    }
}
