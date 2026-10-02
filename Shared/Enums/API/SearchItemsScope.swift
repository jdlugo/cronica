import SwiftUI

enum SearchItemsScope: String, Identifiable, Hashable, CaseIterable {
    var id: String { rawValue }
    case noScope, movies, shows, people
    var localizableTitle: LocalizedStringKey {
        switch self {
        case .noScope: return "All"
        case .movies: return "Movies"
        case .shows: return "Shows"
        case .people: return "People"
        }
    }
}
