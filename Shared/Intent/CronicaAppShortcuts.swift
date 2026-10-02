import AppIntents

struct CronicaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddToWatchlistIntent(),
            phrases: [
                "Add to my watchlist in \(.applicationName)",
                "Add a movie to \(.applicationName)"
            ],
            shortTitle: "Add to Watchlist",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: MarkAsWatchedIntent(),
            phrases: [
                "Mark as watched in \(.applicationName)",
                "I just watched something in \(.applicationName)"
            ],
            shortTitle: "Mark as Watched",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: GetUpNextIntent(),
            phrases: [
                "What's next on my watchlist in \(.applicationName)",
                "What should I watch next in \(.applicationName)"
            ],
            shortTitle: "What's Up Next",
            systemImageName: "list.bullet"
        )
    }
}
