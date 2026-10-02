import SwiftUI
import UserNotifications

struct NotificationsSettingsView: View {
    var navigationTitle = "settingsNotificationTitle"
    @StateObject private var settings = SettingsStore.shared
    @AppStorage("selectedView") private var selectedView: Screens?
    private let dailyPuzzleAnalytics = DailyPuzzleLiveAnalyticsTracker()
    var body: some View {
        Form {
            Section {
                Toggle("allowNotification", isOn: $settings.allowNotifications)
                Toggle(isOn: $settings.notifyMovieRelease) {
                    Text("movieNotificationTitle")
                    Text("movieNotificationSubtitle")
                }
                .disabled(!settings.allowNotifications)
                Toggle(isOn: $settings.notifyNewEpisodes) {
                    Text("episodeNotificationTitle")
                    Text("episodeNotificationSubtitle")
                }
                .disabled(!settings.allowNotifications)
                DailyPuzzleReminderOptInView(
                    allowDisable: true,
                    onShown: { trackReminderEvent("daily_puzzle_prompt_shown") },
                    onChoice: { trackReminderEvent("daily_puzzle_notification_choice", metadata: ["action": $0]) },
                    onOutcome: { trackReminderEvent("daily_puzzle_notification_outcome", metadata: ["outcome": $0]) }
                )
                Button(NSLocalizedString("dailyPuzzleRemindersSettingsPlay", value: "Play Daily Puzzle", comment: "Open today's puzzle from notification settings")) {
                    dailyPuzzleAnalytics.track(event: .openRequested(source: "notification_settings"))
                    DailyPuzzleLaunchIntentStore.requestOpen(source: "notification_settings")
                    selectedView = .home
                    NotificationCenter.default.post(name: .dailyPuzzleOpenRequested, object: nil)
                }
                
            }
            .onChange(of: settings.allowNotifications) {
                if !settings.allowNotifications {
                    settings.notifyMovieRelease = false
                    settings.notifyNewEpisodes = false
                    settings.dailyPuzzleRemindersEnabled = false
                }
                DailyPuzzlePushTopicManager.syncSubscription()
                NotificationManager.shared.refreshDailyPuzzleReminders()
            }
            .onChange(of: settings.dailyPuzzleRemindersEnabled) {
                dailyPuzzleAnalytics.track(
                    event: .remindersToggleChanged(
                        enabled: settings.dailyPuzzleRemindersEnabled,
                        source: "notification_settings"
                    )
                )
                DailyPuzzlePushTopicManager.syncSubscription()
                NotificationManager.shared.refreshDailyPuzzleReminders()
            }
#if os(iOS)
            Button("openNotificationInSettings") {
                Task {
                    // Create the URL that deep links to your app's notification settings.
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        // Ask the system to open that URL.
                        await UIApplication.shared.open(url)
                    }
                }
            }
#endif
        }
        .navigationTitle(NSLocalizedString(navigationTitle, comment: ""))
#if os(macOS)
        .formStyle(.grouped)
#endif
    }

    private func trackReminderEvent(_ name: String, metadata: [String: String] = [:]) {
        var properties = metadata
        properties["source"] = "notification_settings"
        dailyPuzzleAnalytics.track(event: .init(name: name, metadata: properties))
    }
}

#Preview {
    NotificationsSettingsView()
}


/// Shared by the post-solve card and notification settings; OS permission is
/// rechecked on every explicit enable action and on return from Settings.
struct DailyPuzzleReminderOptInView: View {
    var allowDisable = false
    var onShown: () -> Void = {}
    var onChoice: (String) -> Void = { _ in }
    var onOutcome: (String) -> Void = { _ in }
    @ObservedObject private var preferences = SettingsStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var status: UNAuthorizationStatus?
    @State private var busy = false
    @State private var failed = false
    @State private var returnedFromSettings = false
    @State private var didTrackOffer = false

    private var enabled: Bool {
        status == .authorized && preferences.allowNotifications && preferences.dailyPuzzleRemindersEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if enabled {
                Text(NSLocalizedString("puzzleReminderEnabled", value: "Reminders enabled for 6 p.m.", comment: "Reminder confirmation"))
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("dailyPuzzle.reminderEnabled")
                if allowDisable {
                    Button(NSLocalizedString("puzzleReminderDisable", value: "Turn off puzzle reminders", comment: "Disable puzzle reminders")) {
                        preferences.dailyPuzzleRemindersEnabled = false
                        NotificationManager.shared.refreshDailyPuzzleReminders()
                    }
                }
            } else if status != nil {
                Button {
                    Task { await enable() }
                } label: {
                    Text(status == .denied
                        ? NSLocalizedString("puzzleReminderSettings", value: "Open Notification Settings", comment: "Denied notification permission action")
                        : NSLocalizedString("puzzleReminderTomorrow", value: "Remind me tomorrow", comment: "Puzzle reminder opt in"))
                }
                .buttonStyle(.bordered)
                .disabled(busy)
                .accessibilityIdentifier("dailyPuzzle.reminderOptIn")
                .onAppear {
                    if !didTrackOffer { didTrackOffer = true; onShown() }
                }
            }
            Text(NSLocalizedString("puzzleReminderSchedule", value: "A reminder at 6 p.m. your time. Skipped when you’ve already finished.", comment: "Reminder promise"))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if status == .denied {
                Text(NSLocalizedString("puzzleReminderDenied", value: "Notifications are off in Settings. Allow them there to receive puzzle reminders.", comment: "Permission denied explanation"))
                    .font(.footnote)
            }
            if failed {
                Text(NSLocalizedString("puzzleReminderError", value: "Couldn’t enable reminders. Please try again.", comment: "Authorization failure"))
                    .foregroundStyle(.secondary)
            }
        }
        .task { status = await NotificationManager.shared.authorizationStatus() }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task {
                    status = await NotificationManager.shared.authorizationStatus()
                    if returnedFromSettings {
                        returnedFromSettings = false
                        if status == .authorized { await enable() }
                        else { onOutcome("denied") }
                    }
                }
            }
        }
    }

    @MainActor
    private func enable() async {
        guard !busy else { return }
        busy = true
        failed = false
        defer { busy = false }
        status = await NotificationManager.shared.authorizationStatus()
        if status == .denied {
            onChoice("open_settings")
#if os(iOS)
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                returnedFromSettings = await UIApplication.shared.open(url)
                if !returnedFromSettings { failed = true; onOutcome("settings_unavailable") }
            }
#endif
            return
        }
        onChoice("enable")
        do {
            status = try await NotificationManager.shared.enableDailyPuzzleReminders()
            onOutcome(status == .authorized ? "enabled" : "denied")
        } catch {
            failed = true
            onOutcome("error")
        }
    }
}
