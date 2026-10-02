import AppIntents
import CoreData

// MARK: - Add to Watchlist Intent

struct AddToWatchlistIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Watchlist"
    static var description = IntentDescription("Search for a movie or TV show and add it to your watchlist.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let searchResults = try await NetworkService.shared.search(query: query, page: "1")
        let matched: SearchItemContent? = searchResults.first { item in
            item.mediaType == "movie" || item.mediaType == "tv"
        }
        guard let matched else {
            return .result(value: "", dialog: "No results found for \"\(query)\".")
        }

        let contentType: MediaType = matched.mediaType == "tv" ? .tvShow : .movie
        let item = try await NetworkService.shared.fetchItem(id: matched.id, type: contentType)

        let persistence = PersistenceController.shared
        if persistence.isItemSaved(id: item.itemContentID) {
            return .result(value: item.itemTitle, dialog: "\"\(item.itemTitle)\" is already on your watchlist.")
        }

        persistence.save(item)
        return .result(value: item.itemTitle, dialog: "Added \"\(item.itemTitle)\" to your watchlist.")
    }
}

// MARK: - Mark as Watched Intent

struct MarkAsWatchedIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark as Watched"
    static var description = IntentDescription("Mark a movie or TV show on your watchlist as watched.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var query: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let persistence = PersistenceController.shared
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", query)
        request.fetchLimit = 1

        guard let item = try? persistence.container.viewContext.fetch(request).first else {
            return .result(value: "", dialog: "Couldn't find \"\(query)\" on your watchlist.")
        }

        if item.watched {
            return .result(value: item.title ?? query, dialog: "\"\(item.title ?? query)\" is already marked as watched.")
        }

        persistence.updateWatched(for: item)
        return .result(value: item.title ?? query, dialog: "Marked \"\(item.title ?? query)\" as watched.")
    }
}

// MARK: - Get Up Next Intent

struct GetUpNextIntent: AppIntent {
    static var title: LocalizedStringResource = "What's Up Next"
    static var description = IntentDescription("See what's next on your watchlist.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let persistence = PersistenceController.shared
        let request: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        request.predicate = NSPredicate(format: "watched == NO AND isArchive == NO")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        request.fetchLimit = 5

        let items = (try? persistence.container.viewContext.fetch(request)) ?? []

        if items.isEmpty {
            return .result(value: "Nothing up next", dialog: "Your watchlist is empty. Add some movies or shows!")
        }

        let titles = items.compactMap(\.title).joined(separator: ", ")
        let count = items.count
        return .result(value: titles, dialog: "You have \(count) items up next: \(titles).")
    }
}
