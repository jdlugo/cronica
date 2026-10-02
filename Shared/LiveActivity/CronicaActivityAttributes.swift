#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct CronicaActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var releaseDate: Date
        var hasReleased: Bool
    }

    var title: String
    var posterPath: String?
    var mediaType: String // "movie" or "tv"
    var tmdbID: Int
}
#endif
