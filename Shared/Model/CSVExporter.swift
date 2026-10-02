import Foundation
import CoreData

struct CSVExporter {
    static func exportWatchlist(from context: NSManagedObjectContext) throws -> String {
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WatchlistItem.title, ascending: true)]
        let items = try context.fetch(request)

        var csv = "Title,Year,Type,Status,Rating,Notes\n"
        for item in items {
            let title = escapeCSV(item.title ?? "")
            let year = yearString(from: item)
            let type = item.contentType == 0 ? "Movie" : "TV Show"
            let status = item.watched ? "Watched" : "Watchlist"
            let rating = item.userRating > 0 ? "\(item.userRating)" : ""
            let notes = escapeCSV(item.userNotes ?? "")
            csv += "\(title),\(year),\(type),\(status),\(rating),\(notes)\n"
        }
        return csv
    }

    private static func yearString(from item: WatchlistItem) -> String {
        let date = item.movieReleaseDate ?? item.firstAirDate ?? item.date
        guard let date else { return "" }
        let calendar = Calendar.current
        return "\(calendar.component(.year, from: date))"
    }

    private static func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }
}
