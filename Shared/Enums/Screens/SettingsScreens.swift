import Foundation

enum SettingsScreens: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case about, appearance, behavior, developer, roadmap, notifications, sync, tipJar, settings
}
