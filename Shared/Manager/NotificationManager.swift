import Foundation
import UserNotifications
#if os(iOS)
import UIKit
import FirebaseMessaging
#endif

@MainActor
enum DailyPuzzleNotificationAuthorization {
    static let options: UNAuthorizationOptions = [.alert, .sound, .badge]

    static func enable(
        status: () async -> UNAuthorizationStatus,
        request: (UNAuthorizationOptions) async throws -> Bool,
        enablePreferences: () -> Void
    ) async throws -> UNAuthorizationStatus {
        let current = await status()
        guard current != .denied else { return current }
        if current != .authorized {
            _ = try await request(options)
        }
        let resolved = await status()
        if resolved == .authorized { enablePreferences() }
        return resolved
    }
}

@MainActor
protocol DailyPuzzleReminderScheduling {
    func completeDailyPuzzle(at date: Date)
    func cancelDailyPuzzleFallbackReminder(for puzzleID: String)
}

@MainActor
@Observable
class NotificationManager: DailyPuzzleReminderScheduling {
    static let shared = NotificationManager()
    var settings: UNNotificationSettings?
    private var reminderRefreshTask: Task<Void, Never>?
    private static let completionKey = "dailyPuzzleReminderCompletedAt"
    private let reminderCoordinator = DailyPuzzleReminderCoordinator(
        center: SystemDailyPuzzleReminderCenter(),
        reportError: { error in
            CronicaTelemetry.shared.handleMessage(error.localizedDescription, for: "DailyPuzzleReminders")
        }
    )
    private init() { }
    
    func requestAuthorization(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .provisional, .badge]) { granted, _ in
            Task { @MainActor in
                self.fetchNotificationSettings()
                completion(granted)
            }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func enableDailyPuzzleReminders() async throws -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let result = try await DailyPuzzleNotificationAuthorization.enable(
            status: { await center.notificationSettings().authorizationStatus },
            request: { try await center.requestAuthorization(options: $0) },
            enablePreferences: {
                SettingsStore.shared.allowNotifications = true
                SettingsStore.shared.dailyPuzzleRemindersEnabled = true
            }
        )
        fetchNotificationSettings()
        DailyPuzzlePushTopicManager.syncSubscription()
        refreshDailyPuzzleReminders()
        return result
    }

    @MainActor
    func fetchNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor [weak self] in
                self?.settings = settings
            }
        }
    }
    
    func isNotificationAllowed() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    func schedule(_ content: ItemContent) {
        let settings = SettingsStore.shared
        let type = content.itemContentMedia
        if !settings.allowNotifications { return }
        if type == .movie {
            if !settings.notifyMovieRelease { return }
        } else {
            if !settings.notifyNewEpisodes { return }
        }
        self.requestAuthorization { granted in
            if !granted {
                return
            } 
        }
        let identifier = content.itemContentID
        let title = content.itemTitle
        var body: String
		body = content.itemContentMedia == .movie ? NSLocalizedString("The movie will be released today.", comment: "") : NSLocalizedString("Next episode arrives today.", comment: "")
        var date: Date?
        if content.itemContentMedia == .movie {
            date = content.itemTheatricalDate
        } else if content.itemContentMedia == .tvShow {
            date = content.nextEpisodeDate
        } else {
            date = content.itemFallbackDate
        }
		guard let date else { return }
		if date.isLessThanTwoWeeksAway() {
			removeNotification(identifier: content.itemContentID)
			self.scheduleNotification(identifier: identifier,
									  title: title,
									  message: body,
									  date: date)
		}
    }
    
    private func scheduleNotification(identifier: String, title: String, message: String, date: Date) {
#if os(tvOS)
#else
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = title
        notificationContent.body = message
        notificationContent.userInfo = ["contentID":"\(identifier)"]
        notificationContent.sound = UNNotificationSound.default
        var dateComponent: DateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                                            from: date)
        dateComponent.hour = 7
        dateComponent.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponent, repeats: false)
        let request = UNNotificationRequest(identifier: identifier,
                                            content: notificationContent,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request)
#endif
    }
    
    nonisolated func removeNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func removeDeliveredNotification(identifier: String) {
#if os(tvOS)
#else
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
#endif
    }
    
    func removeAllDeliveredNotifications() {
#if os(tvOS)
#else
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
#endif
    }
    
    private func getUpcomingNotificationsId() async -> [String] {
        var identifiers = [String]()
        let notifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
        for item in notifications {
            identifiers.append(item.identifier)
        }
        return identifiers
    }
    
    private func getDeliveredNotificationsId() async -> [String] {
#if os(tvOS)
        return []
#else
        var identifiers = [String]()
        let notifications = await UNUserNotificationCenter.current().deliveredNotifications()
        if notifications.isEmpty {
            return identifiers
        } else {
            for item in notifications {
                if item.request.identifier.contains("@") {
                    identifiers.append(item.request.identifier)
                }
            }
        }
        return identifiers
#endif
    }
    
    func fetchDeliveredNotifications() async -> [ItemContent] {
        var items = [ItemContent]()
        let notifications = await getDeliveredNotificationsId()
        if notifications.isEmpty { return items }
        for notification in notifications {
            let type = notification.last ?? "0"
            var media: MediaType = .movie
            if type == "1" {
                media = .tvShow
            }
            let id = notification.dropLast(2)
            guard let contentID = Int(id) else { return [] }
            let item = try? await NetworkService.shared.fetchItem(id: contentID, type: media)
            if let item {
                items.append(item)
            }
        }
        return items
    }
    
    func hasDeliveredItems() async -> Bool {
        let notifications = await getDeliveredNotificationsId()
        if notifications.isEmpty { return false }
        return true
    }
    
    func fetchUpcomingNotifications() async throws -> [WatchlistItem] {
        var items = [WatchlistItem]()
        let notifications = await getUpcomingNotificationsId()
        for notification in notifications {
            let item = PersistenceController.shared.fetch(for: notification)
            if let item {
                items.append(item)
            }
        }
        return items
    }
    
    func fetchUpcomingNotifications() async -> [ItemContent]? {
        var identifiers = [String]()
        let notifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
        for item in notifications {
            if item.identifier.contains("@") {
                identifiers.append(item.identifier)
            }
        }
        var items = [ItemContent]()
        if identifiers.isEmpty {
            return items
        }
        let service = NetworkService.shared
        for identifier in identifiers {
            let type = identifier.last ?? "0"
            var media: MediaType = .movie
            if type == "1" {
                media = .tvShow
            }
            let id = identifier.dropLast(2)
            do {
                let item = try await service.fetchItem(id: Int(id)!, type: media)
                items.append(item)
            } catch {
                return nil
            }
        }
        return items
    }
	
	func hasPendingNotification(for id: String) async -> Bool {
		let notifications = await UNUserNotificationCenter.current().pendingNotificationRequests()
		if notifications.contains(where: { $0.identifier == id }) { return true }
		return false
	}

    func refreshDailyPuzzleReminders(now: Date = Date()) {
#if !os(tvOS)
        reminderRefreshTask?.cancel()
        // Invalidate pending additions immediately, before querying OS authorization.
        reminderCoordinator.refresh(enabled: false, now: now, calendar: .autoupdatingCurrent, completedAt: nil)
        reminderRefreshTask = Task { @MainActor in
            let status = await authorizationStatus()
            guard !Task.isCancelled else { return }
            let preferences = SettingsStore.shared
            let enabled = preferences.allowNotifications && preferences.dailyPuzzleRemindersEnabled
                && isEligibleForFallbackReminder(status: status)
            await reminderCoordinator.refresh(
                enabled: enabled,
                now: now,
                calendar: .autoupdatingCurrent,
                completedAt: lastDailyPuzzleCompletion
            ).value
        }
#endif
    }

    private var lastDailyPuzzleCompletion: Date? {
        let completion = UserDefaults.standard.object(forKey: Self.completionKey) as? Date
        let solved = DailyPuzzleStreakStore().lastSolvedDate
        return [completion, solved].compactMap { $0 }.max()
    }

    func completeDailyPuzzle(at date: Date) {
        UserDefaults.standard.set(date, forKey: Self.completionKey)
        refreshDailyPuzzleReminders(now: date)
    }

    func cancelDailyPuzzleFallbackReminder(for puzzleID: String) {
        removeNotification(identifier: "daily-puzzle-fallback-\(puzzleID)")
    }

    func shouldPresentDailyPuzzleReminder(now: Date = Date()) -> Bool {
        let preferences = SettingsStore.shared
        guard preferences.allowNotifications && preferences.dailyPuzzleRemindersEnabled else { return false }
        if let completedAt = lastDailyPuzzleCompletion,
           Calendar.autoupdatingCurrent.isDate(completedAt, inSameDayAs: now) { return false }
        return Calendar.autoupdatingCurrent.component(.hour, from: now) == 18
    }

    private func isEligibleForFallbackReminder(status: UNAuthorizationStatus) -> Bool {
#if os(watchOS)
        return status == .authorized || status == .provisional
#else
        return status == .authorized || status == .provisional || status == .ephemeral
#endif
    }

}

enum DailyPuzzlePushTopicManager {
#if os(iOS)
    static var messagingClient: DailyPuzzleTopicMessagingClient = FirebaseDailyPuzzleTopicMessagingClient()
#endif

    static func syncSubscription() {
#if os(iOS)
        // Local reminders own delivery from 4.25.42 onward. The legacy console
        // campaign must also exclude these versions (it does not target this topic).
        messagingClient.unsubscribe(topic: "daily-puzzle")
#endif
    }
}

#if os(iOS)
protocol DailyPuzzleTopicMessagingClient {
    func subscribe(topic: String)
    func unsubscribe(topic: String)
}

struct FirebaseDailyPuzzleTopicMessagingClient: DailyPuzzleTopicMessagingClient {
    func subscribe(topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error {
                CronicaTelemetry.shared.handleMessage(
                    "subscribe failed topic=\(topic) error=\(error.localizedDescription)",
                    for: "DailyPuzzlePushTopicManager"
                )
            } else {
                CronicaTelemetry.shared.handleMessage(
                    "subscribe succeeded topic=\(topic)",
                    for: "DailyPuzzlePushTopicManager"
                )
            }
        }
    }

    func unsubscribe(topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error {
                CronicaTelemetry.shared.handleMessage(
                    "unsubscribe failed topic=\(topic) error=\(error.localizedDescription)",
                    for: "DailyPuzzlePushTopicManager"
                )
            } else {
                CronicaTelemetry.shared.handleMessage(
                    "unsubscribe succeeded topic=\(topic)",
                    for: "DailyPuzzlePushTopicManager"
                )
            }
        }
    }
}
#endif

enum DailyPuzzleLaunchIntentStore {
    private static let dailyPuzzleType = "daily_puzzle"
    private static let openFromPushKey = "dailyPuzzleShouldOpenFromPush"
    private static let openSourceKey = "dailyPuzzleOpenSource"

    static func shouldOpenFromNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = userInfo["type"] as? String else { return false }
        return type == dailyPuzzleType
    }

    static func requestOpen(source: String = "unknown", userDefaults: UserDefaults = .standard) {
        userDefaults.set(true, forKey: openFromPushKey)
        userDefaults.set(source, forKey: openSourceKey)
    }

    @discardableResult
    static func consumeOpenRequestSource(userDefaults: UserDefaults = .standard) -> String? {
        let shouldOpen = userDefaults.bool(forKey: openFromPushKey)
        guard shouldOpen else { return nil }
        let source = userDefaults.string(forKey: openSourceKey) ?? "unknown"
        userDefaults.removeObject(forKey: openFromPushKey)
        userDefaults.removeObject(forKey: openSourceKey)
        return source
    }

    @discardableResult
    static func consumeOpenRequest(userDefaults: UserDefaults = .standard) -> Bool {
        consumeOpenRequestSource(userDefaults: userDefaults) != nil
    }
}

enum AppDeepLinkDestination: Equatable {
    case dailyPuzzle
    case content(String)
}

enum AppDeepLinkRouter {
    private static let appSchemePrefix = "qscanlite://"

    static func destination(for url: URL) -> AppDeepLinkDestination {
        let absoluteURL = url.absoluteString
        guard absoluteURL.lowercased().hasPrefix(appSchemePrefix) else {
            return .content(absoluteURL)
        }

        let route = String(absoluteURL.dropFirst(appSchemePrefix.count))
        let routeName = route
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        if routeName == "daily-puzzle" {
            return .dailyPuzzle
        }
        return .content(route)
    }
}

extension Notification.Name {
    static let dailyPuzzleOpenRequested = Notification.Name("dailyPuzzleOpenRequested")
}

@MainActor
private struct SystemDailyPuzzleReminderCenter: DailyPuzzleReminderCenter {
    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func remove(identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(identifier: String, date: Date, calendar: Calendar) async throws {
#if !os(tvOS)
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("dailyPuzzleReminderNotificationTitle", value: "Daily Puzzle", comment: "Daily puzzle reminder")
        content.body = NSLocalizedString("dailyPuzzleDailyReminderBody", value: "Today's movie quiz is ready. Recognize the image and tap your answer!", comment: "Daily reminder")
        content.sound = .default
        content.userInfo = ["type": "daily_puzzle", "source": "local_reminder"]
        // Leave timezone unset: use the device's local wall clock, including travel.
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        )
#endif
    }
}
