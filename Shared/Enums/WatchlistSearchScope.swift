import SwiftUI

enum WatchlistSearchScope: String, Identifiable, CaseIterable {
    var id: String { rawValue }
    case noScope, movies, shows
    var localizableTitle: LocalizedStringKey {
        switch self {
        case .noScope: return "All"
        case .movies: return "Movies"
        case .shows: return "Shows"
        }
    }
}
