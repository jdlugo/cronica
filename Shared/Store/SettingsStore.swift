import SwiftUI

enum WatchRegionResolutionSource: String, Equatable {
    case existingPreference = "existing_preference"
    case localeDefault = "locale_default"
    case unsupportedLocaleFallback = "unsupported_locale_fallback"
}

struct WatchRegionResolution: Equatable {
    let region: AppContentRegion
    let source: WatchRegionResolutionSource
    let shouldPersist: Bool
}

enum WatchRegionPreferenceResolver {
    static let preferenceKey = "selectedWatchProviderRegion"
    static let fallbackRegion = AppContentRegion.us

    static func resolve(
        storedPreference: String?,
        deviceRegionCode: String?
    ) -> WatchRegionResolution {
        if let storedPreference,
           let storedRegion = AppContentRegion(rawValue: storedPreference.lowercased()) {
            return WatchRegionResolution(
                region: storedRegion,
                source: .existingPreference,
                shouldPersist: false
            )
        }

        if let deviceRegion = supportedRegion(for: deviceRegionCode) {
            return WatchRegionResolution(
                region: deviceRegion,
                source: .localeDefault,
                shouldPersist: true
            )
        }

        return WatchRegionResolution(
            region: fallbackRegion,
            source: .unsupportedLocaleFallback,
            shouldPersist: false
        )
    }

    private static func supportedRegion(for regionCode: String?) -> AppContentRegion? {
        guard let normalizedCode = regionCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
              !normalizedCode.isEmpty else {
            return nil
        }

        if normalizedCode == "IN" {
            return .india
        }

        return AppContentRegion(rawValue: normalizedCode.lowercased())
    }
}

extension Locale {
    static var detectedRegionCode: String? {
        Locale.autoupdatingCurrent.region?.identifier.uppercased()
    }
}

class SettingsStore: ObservableObject {
    private init() { }
    static var shared = SettingsStore()
    @AppStorage("showOnboarding") var displayOnboard = true
    @AppStorage("displayDeveloperSettings") var displayDeveloperSettings = false
    @AppStorage("gesture") var gesture: UpdateItemProperties = .favorite
    @AppStorage("appThemeColor") var appTheme: AppThemeColors = .red
#if os(iOS)
    @AppStorage("watchlistStyle") var watchlistStyle: SectionDetailsPreferredStyle = UIDevice.isIPhone ? .list : .poster
#else
    @AppStorage("watchlistStyle") var watchlistStyle: SectionDetailsPreferredStyle = .card
#endif
    @AppStorage("disableTranslucentBackground") var disableTranslucent = false
    @AppStorage("user_theme") var currentTheme: AppTheme = .dark
    @AppStorage("openInYouTube") var openInYouTube = false
    @AppStorage("markEpisodeWatchedTap") var markEpisodeWatchedOnTap = false
    @AppStorage("enableHapticFeedback") var hapticFeedback = true
    @AppStorage("enableWatchProviders") var isWatchProviderEnabled = true
    @AppStorage(WatchRegionPreferenceResolver.preferenceKey) var watchRegion: AppContentRegion = .us
    @AppStorage("primaryLeftSwipe") var primaryLeftSwipe: SwipeGestureOptions = .markWatch
    @AppStorage("secondaryLeftSwipe") var secondaryLeftSwipe: SwipeGestureOptions = .markFavorite
    @AppStorage("primaryRightSwipe") var primaryRightSwipe: SwipeGestureOptions = .delete
    @AppStorage("secondaryRightSwipe") var secondaryRightSwipe: SwipeGestureOptions = .markArchive
    @AppStorage("allowFullSwipe") var allowFullSwipe = false
#if os(macOS)
    @AppStorage("allowNotifications") var allowNotifications = false
    @AppStorage("notifyMovies") var notifyMovieRelease = false
    @AppStorage("notifyTVShows") var notifyNewEpisodes = false
#else
    @AppStorage("allowNotifications") var allowNotifications = true
    @AppStorage("notifyMovies") var notifyMovieRelease = true
    @AppStorage("notifyTVShows") var notifyNewEpisodes = true
#endif
    @AppStorage("userHasPurchasedTipJar") var hasPurchasedTipJar = false
#if os(tvOS)
    @AppStorage("itemContentListDisplayType") var listsDisplayType: ItemContentListPreferredDisplayType = .card
#else
    @AppStorage("itemContentListDisplayType") var listsDisplayType: ItemContentListPreferredDisplayType = .standard
#endif
#if os(iOS)
    @AppStorage("exploreDisplayType") var sectionStyleType: SectionDetailsPreferredStyle = UIDevice.isIPhone ? .card : .poster
#else
    @AppStorage("exploreDisplayType") var sectionStyleType: SectionDetailsPreferredStyle = .card
#endif
    @AppStorage("preferCompactUI") var isCompactUI = false
    @AppStorage("selectedWatchProviderEnabled") var isSelectedWatchProviderEnabled = false
    @AppStorage("selectedWatchProviders") var selectedWatchProviders = ""
    @AppStorage("userHasImportedFromTMDB") var userImportedTMDB = false
    @AppStorage("isUserConnectedWithTMDB") var isUserConnectedWithTMDb = false
#if os(tvOS) || os(watchOS)
    @AppStorage("showRemoveConfirmation") var showRemoveConfirmation = true
#else
    @AppStorage("showRemoveConfirmation") var showRemoveConfirmation = false
#endif
    @AppStorage("choosePreferredLaunchScreen") var isPreferredLaunchScreenEnabled = false
#if !os(watchOS)
    @AppStorage("preferredLaunchScreen") var preferredLaunchScreen: Screens = .home
#else
    @AppStorage("preferredLaunchScreen") var preferredLaunchScreen: Screens = .watchlist
#endif
    @AppStorage("removeFromPinOnWatched") var removeFromPinOnWatched = false
    @AppStorage("autoOpenCustomListSelector") var openListSelectorOnAdding = false
#if os(iOS)
    @AppStorage("alwaysUsePosterAsCover") var usePostersAsCover = true
#endif
    @AppStorage("shareLinkPreference") var shareLinkPreference: ShareLinkPreference = .tmdb
    @AppStorage("upNextStyle") var upNextStyle: UpNextDetailsPreferredStyle = .card
    @AppStorage("showDateOnWatchlistRow") var showDateOnWatchlist = true
    @AppStorage("disableSearchFilter") var disableSearchFilter = false
    @AppStorage("removeFromWatchingOnRenew") var removeFromWatchOnRenew = false
    @AppStorage("hideEpisodeTitles") var hideEpisodesTitles = false
    @AppStorage("hideEpisodeThumbnails") var hideEpisodesThumbnails = false
    @AppStorage("preferCoverOnUpNext") var preferCoverOnUpNext = false
    @AppStorage("markUpNextWatchedOnTap") var markWatchedOnTapUpNext = false
    @AppStorage("confirmationForMarkOnTapUpNext") var askForConfirmationUpNext = true
    @AppStorage("dailyPuzzleRemindersEnabled") var dailyPuzzleRemindersEnabled = true
#if os(macOS)
    @AppStorage("showMenuBarApp") var showMenuBarApp = true
#endif
}

extension SettingsStore {
    @discardableResult
    func initializeWatchRegionIfNeeded(
        deviceRegionCode: String? = Locale.detectedRegionCode
    ) -> WatchRegionResolution {
        let resolution = WatchRegionPreferenceResolver.resolve(
            storedPreference: UserDefaults.standard.string(
                forKey: WatchRegionPreferenceResolver.preferenceKey
            ),
            deviceRegionCode: deviceRegionCode
        )

        if resolution.shouldPersist {
            watchRegion = resolution.region
        }

        return resolution
    }

    var effectiveWatchRegion: AppContentRegion {
        WatchRegionPreferenceResolver.resolve(
            storedPreference: UserDefaults.standard.string(
                forKey: WatchRegionPreferenceResolver.preferenceKey
            ),
            deviceRegionCode: Locale.detectedRegionCode
        ).region
    }
}

final class DailyPuzzleStreakStore {
    private enum Keys {
        static let currentStreak = "dailyPuzzleCurrentStreak"
        static let bestStreak = "dailyPuzzleBestStreak"
        static let lastSolvedDate = "dailyPuzzleLastSolvedDate"
    }

    private let userDefaults: UserDefaults
    private var calendar: Calendar

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    var currentStreak: Int {
        userDefaults.integer(forKey: Keys.currentStreak)
    }

    var bestStreak: Int {
        userDefaults.integer(forKey: Keys.bestStreak)
    }

    var lastSolvedDate: Date? {
        userDefaults.object(forKey: Keys.lastSolvedDate) as? Date
    }

    func recordSolved(on date: Date = Date()) {
        let normalizedDate = calendar.startOfDay(for: date)

        guard let lastDate = lastSolvedDate else {
            updateStreak(newValue: 1, solvedDate: normalizedDate)
            return
        }

        let normalizedLastDate = calendar.startOfDay(for: lastDate)
        if calendar.isDate(normalizedLastDate, inSameDayAs: normalizedDate) {
            return
        }

        let nextExpectedDate = calendar.date(byAdding: .day, value: 1, to: normalizedLastDate)
        let newStreak: Int
        if let nextExpectedDate, calendar.isDate(nextExpectedDate, inSameDayAs: normalizedDate) {
            newStreak = max(1, currentStreak) + 1
        } else {
            newStreak = 1
        }

        updateStreak(newValue: newStreak, solvedDate: normalizedDate)
    }

    private func updateStreak(newValue: Int, solvedDate: Date) {
        userDefaults.set(newValue, forKey: Keys.currentStreak)
        if newValue > bestStreak {
            userDefaults.set(newValue, forKey: Keys.bestStreak)
        }
        userDefaults.set(solvedDate, forKey: Keys.lastSolvedDate)
    }
}

final class DailyPuzzlePromptStore {
    private enum Keys {
        static let promptSeen = "dailyPuzzlePromptSeen"
        static let promptGranted = "dailyPuzzlePromptGranted"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var hasSeenPrompt: Bool {
        userDefaults.bool(forKey: Keys.promptSeen)
    }

    var lastPromptGranted: Bool? {
        guard userDefaults.object(forKey: Keys.promptGranted) != nil else { return nil }
        return userDefaults.bool(forKey: Keys.promptGranted)
    }

    func markSeen(granted: Bool) {
        userDefaults.set(true, forKey: Keys.promptSeen)
        userDefaults.set(granted, forKey: Keys.promptGranted)
    }
}

final class DailyPuzzleProgressStore {
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(userDefaults: UserDefaults = .standard, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func load(puzzleID: String) -> DailyPuzzleProgress? {
        let key = storageKey(for: puzzleID)
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? decoder.decode(DailyPuzzleProgress.self, from: data)
    }

    func save(_ progress: DailyPuzzleProgress) {
        let key = storageKey(for: progress.puzzleID)
        guard let data = try? encoder.encode(progress) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func storageKey(for puzzleID: String) -> String {
        "dailyPuzzleProgress-\(puzzleID)"
    }
}
