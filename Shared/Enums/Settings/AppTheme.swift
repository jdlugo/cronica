import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case system, light, dark
    var overrideTheme: ColorScheme? {
        switch self {
        case .system:
            return .dark
            //return nil
        case .light:
            return .dark
            //return .light
        case .dark:
            return .dark
        }
    }
    var localizableName: String {
        switch self {
        case .system:
            return NSLocalizedString("appThemeDark", comment: "")
        case .light:
            return NSLocalizedString("appThemeDark", comment: "")
        case .dark:
            return NSLocalizedString("appThemeDark", comment: "")
        }
    }
}
