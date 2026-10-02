import SwiftUI
import BackgroundTasks
import FirebaseCore
import UserNotifications
import OSLog

#if os(iOS)
import UIKit
import NotificationCenter
import FirebaseMessaging
import FirebaseAppCheck
import GoogleMobileAds

enum PreviewVideoRuntime {
    static let scenarioArgument = "--preview-video-scenario"
    static let sceneDurationArgument = "--preview-video-scene-duration"
    static let disableMonetizationArgument = "--preview-video-disable-monetization"

    static func scenarioID(arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: scenarioArgument) else { return nil }
        let nextIndex = arguments.index(after: index)
        guard nextIndex < arguments.endIndex else { return nil }
        let scenarioID = arguments[nextIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return scenarioID.isEmpty ? nil : scenarioID
    }

    static func isPreviewVideoMode(arguments: [String]) -> Bool {
        scenarioID(arguments: arguments) != nil
    }

    static func isPreviewVideoMode(processInfo: ProcessInfo = .processInfo) -> Bool {
        isPreviewVideoMode(arguments: processInfo.arguments)
    }

    static func shouldDisableMonetization(arguments: [String]) -> Bool {
        if arguments.contains(disableMonetizationArgument) {
            return true
        }
        return isPreviewVideoMode(arguments: arguments)
    }

    static func shouldDisableMonetization(processInfo: ProcessInfo = .processInfo) -> Bool {
        shouldDisableMonetization(arguments: processInfo.arguments)
    }
}

protocol MobileAdsStarting {
    func start() async
}

protocol AdConsentGathering {
    @MainActor
    func gatherConsentIfPossible(from viewController: UIViewController?) async
}

protocol AdRequestEligibilityProviding: Sendable {
    @MainActor
    var canRequestAds: Bool { get }
}

protocol AdPreloading {
    func preloadAds() async
}

protocol AdPreloadCoordinating {
    func loadAd()
    func loadRewardedAd()
    func loadAppOpenAd()
}

extension AdCoordinator: AdPreloadCoordinating {}

protocol AdForegroundPresenting {
    func ensureInterstitialLoaded()
    func presentAppOpenAd()
}

extension AdCoordinator: AdForegroundPresenting {}

struct MobileAdsStarter: MobileAdsStarting {
    @MainActor
    func start() async {
        await MobileAds.shared.start()
    }
}

struct AdConsentGatherer: AdConsentGathering {
    @MainActor
    func gatherConsentIfPossible(from viewController: UIViewController?) async {
        guard let viewController else { return }
        await AdConsentManager.gatherConsent(from: viewController)
    }
}

struct AdRequestEligibilityProvider: AdRequestEligibilityProviding {
    @MainActor
    var canRequestAds: Bool {
        AdConsentManager.canRequestAds
    }
}

struct SharedAdPreloader: AdPreloading {
    let adCoordinator: AdPreloadCoordinating

    init(adCoordinator: AdPreloadCoordinating = AdCoordinator.shared) {
        self.adCoordinator = adCoordinator
    }

    @MainActor
    func preloadAds() async {
        adCoordinator.loadAppOpenAd()
    }
}

struct AdStartupCoordinator {
    let mobileAdsStarter: MobileAdsStarting
    let consentGatherer: AdConsentGathering
    let adRequestEligibilityProvider: AdRequestEligibilityProviding
    let adPreloader: AdPreloading

    init(
        mobileAdsStarter: MobileAdsStarting = MobileAdsStarter(),
        consentGatherer: AdConsentGathering = AdConsentGatherer(),
        adRequestEligibilityProvider: AdRequestEligibilityProviding = AdRequestEligibilityProvider(),
        adPreloader: AdPreloading = SharedAdPreloader()
    ) {
        self.mobileAdsStarter = mobileAdsStarter
        self.consentGatherer = consentGatherer
        self.adRequestEligibilityProvider = adRequestEligibilityProvider
        self.adPreloader = adPreloader
    }

    func startAdsIfNeeded(
        monetizationDisabled: Bool,
        rootViewController: UIViewController?
    ) async {
        guard !monetizationDisabled else { return }

        await consentGatherer.gatherConsentIfPossible(from: rootViewController)
        let canRequestAds = await adRequestEligibilityProvider.canRequestAds
        CronicaTelemetry.shared.capture(
            "ad_startup_eligibility_evaluated",
            properties: [
                "can_request_ads": canRequestAds ? "true" : "false",
                "outcome": canRequestAds ? "allowed" : "denied"
            ]
        )
        guard canRequestAds else { return }
        await mobileAdsStarter.start()
        await adPreloader.preloadAds()
    }
}

struct AdForegroundPresentationCoordinator {
    let adPresenter: AdForegroundPresenting

    init(adPresenter: AdForegroundPresenting = AdCoordinator.shared) {
        self.adPresenter = adPresenter
    }

    func presentForegroundAdsIfNeeded(monetizationDisabled: Bool) {
        guard !monetizationDisabled else { return }
        adPresenter.presentAppOpenAd()
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
    private let adStartupCoordinator = AdStartupCoordinator()
    private let adForegroundCoordinator = AdForegroundPresentationCoordinator()
    
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
#if DEBUG
    AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#else
    AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
#endif
    FirebaseApp.configure()

    Messaging.messaging().delegate = self

    application.registerForRemoteNotifications()
    NotificationManager.shared.fetchNotificationSettings()

    if let window { window.tintColor = UIColor.red }

    Task { @MainActor in
        await LegacyAdFreeEntitlements.restorePreviousBenefit()
        await adStartupCoordinator.startAdsIfNeeded(
            monetizationDisabled: PreviewVideoRuntime.shouldDisableMonetization(),
            rootViewController: launchRootViewController()
        )
    }

    return true
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    adForegroundCoordinator.presentForegroundAdsIfNeeded(
        monetizationDisabled: PreviewVideoRuntime.shouldDisableMonetization()
    )
  }

  private func launchRootViewController() -> UIViewController? {
    if let window {
        return window.rootViewController
    }

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
        return nil
    }

    return windowScene.windows.first?.rootViewController
  }

      // [START receive_message]
      func application(_ application: UIApplication,
                       didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                       fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let gcmMessageIDKey = "gcm.message_id"
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification

        // With swizzling disabled you must let Messaging know about the message, for Analytics
        // Messaging.messaging().appDidReceiveMessage(userInfo)

        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
          print("Message ID: \(messageID)")
        }

        // Print full message.
        print(userInfo)

        completionHandler(.newData)
      }

      // [END receive_message]

      func application(_ application: UIApplication,
                       didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
      }

      // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
      // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
      // the FCM registration token.
      func application(_ application: UIApplication,
                       didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let apnsTokenHex = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs token retrieved (hex): \(apnsTokenHex)")
        Messaging.messaging().apnsToken = deviceToken
        DailyPuzzlePushTopicManager.syncSubscription()

        // With swizzling disabled you must set the APNs token here.
        // Messaging.messaging().apnsToken = deviceToken
      }
    
}
#endif


@main
struct StreamingNowApp: App {
#if os(iOS)
    private let notificationDelegate = NotificationDelegate()
    @State private var lastNotificationID = String()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
#endif

    var persistence = PersistenceController.shared
    private let backgroundIdentifier = "com.dlugokecki.qscanlite.refreshContent"
    @Environment(\.scenePhase) private var scene
    @State private var widgetItem: ItemContent?
    @State private var notificationItem: ItemContent?
    @State private var selectedItem: ItemContent?
    @State private var showFeedbackForm = false
    @State private var showAbout = false
    @State private var showNewListView = false
    @ObservedObject private var settings = SettingsStore.shared
    @AppStorage("showMenuBarApp") var showMenuBar = true
#if os(iOS)
    private let adForegroundCoordinator = AdForegroundPresentationCoordinator()
#endif

    init() {
#if DEBUG && os(iOS)
        if ProcessInfo.processInfo.arguments.contains("--movie-quiz-fixture") {
            // Mutable launch intent, unlike a UserDefaults command-line override:
            // deep links must be able to update this flag after launch.
            UserDefaults.standard.set(false, forKey: "dailyPuzzleShouldOpenFromPush")
            if let source = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--quiz-launch-source=") }) {
                DailyPuzzleLaunchIntentStore.requestOpen(source: String(source.dropFirst("--quiz-launch-source=".count)))
            }
        }
#endif
#if DEBUG && os(iOS) && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--arcade-discovery-test") {
            var failedOnce = false
            NetworkService.shared.fixtureItemLoader = { id, type in
                guard type == .movie, let film = ArcadeCatalog.films.first(where: { $0.id == id }) else { return nil }
                if ProcessInfo.processInfo.arguments.contains("--arcade-detail-fail-once"), !failedOnce {
                    failedOnce = true
                    throw URLError(.notConnectedToInternet)
                }
                // Test metadata drives the real details view and persistent save.
                // No providers, reviews or recommendations are fabricated.
                let data = try JSONSerialization.data(withJSONObject: [
                    "id": film.id, "title": film.title, "overview": film.localizedPlot,
                    "releaseDate": "\(film.year)-01-01", "status": "Released", "mediaType": "movie"
                ])
                return try JSONDecoder().decode(ItemContent.self, from: data)
            }
        }
#endif
        let watchRegionResolution = SettingsStore.shared.initializeWatchRegionIfNeeded()
        CronicaTelemetry.shared.setup()
        CronicaTelemetry.shared.capture(
            "watch_region_resolved",
            properties: [
                "watch_region": watchRegionResolution.region.rawValue,
                "watch_region_source": watchRegionResolution.source.rawValue,
                "device_region": Locale.detectedRegionCode ?? "unknown",
                "preference_persisted": watchRegionResolution.shouldPersist ? "true" : "false"
            ]
        )
        CronicaTelemetry.shared.capture(
            "app_launched",
            properties: [
                "launch_state": "initialized",
                "watch_region_source": watchRegionResolution.source.rawValue
            ]
        )
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.unknown.app", category: "Startup")
        if !CronicaTelemetry.shared.isPostHogInitializedForRuntime {
#if targetEnvironment(simulator)
            logger.info("PostHog is intentionally disabled on the simulator")
#else
            logger.fault("PostHog failed to initialize during app startup")
#if DEBUG && os(iOS)
            assertionFailure("PostHog should initialize in debug builds.")
#endif
#endif
        } else {
            logger.info("PostHog initialized during app startup")
        }
        registerRefreshBGTask()
#if os(iOS)
        UNUserNotificationCenter.current().delegate = notificationDelegate
#endif
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { NotificationManager.shared.refreshDailyPuzzleReminders() }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                    NotificationManager.shared.refreshDailyPuzzleReminders()
                }
#if os(macOS)
                .frame(minWidth: 1000, minHeight: 600)
#endif
                .environment(\.managedObjectContext, persistence.container.viewContext)
#if os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        guard let id = notificationDelegate.notificationID else { return }
                        if lastNotificationID != id {
                            await fetchContent(for: id)
                        }
                        lastNotificationID = id
                    }
                }
#endif
                .onOpenURL { url in
                    switch AppDeepLinkRouter.destination(for: url) {
                    case .dailyPuzzle:
#if os(iOS)
                        DailyPuzzleLaunchIntentStore.requestOpen(source: "app_deep_link")
                        DailyPuzzleLiveAnalyticsTracker().track(
                            event: .openRequested(source: "app_deep_link")
                        )
                        UserDefaults.standard.set(Screens.home.rawValue, forKey: "selectedView")
                        NotificationCenter.default.post(name: .dailyPuzzleOpenRequested, object: nil)
#else
                        Task {
                            await fetchContent(for: url.absoluteString)
                        }
#endif
                    case .content(let identifier):
                        Task {
                            await fetchContent(for: identifier)
                        }
                    }
                }
                .sheet(item: $selectedItem) { item in
                    NavigationStack {
                        ItemContentDetails(title: item.itemTitle,
                                           id: item.id,
                                           type: item.itemContentMedia, handleToolbar: true)
                        .toolbar {
#if os(iOS)
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") { selectedItem = nil }
                            }
#else
                            Button("Done") { selectedItem = nil }
#endif
                        }
                        .navigationDestination(for: ItemContent.self) { item in
                            ItemContentDetails(title: item.itemTitle,
                                               id: item.id,
                                               type: item.itemContentMedia)
                        }
                        .navigationDestination(for: Person.self) { person in
                            PersonDetailsView(name: person.name, id: person.id)
                        }
                        .navigationDestination(for: [String:[ItemContent]].self) { item in
                            let keys = item.map { (key, _) in key }
                            let value = item.map { (_, value) in value }
                            ItemContentSectionDetails(title: keys[0], items: value[0])
                        }
                        .navigationDestination(for: [Person].self) { items in
                            DetailedPeopleList(items: items)
                        }
                        .navigationDestination(for: ProductionCompany.self) { item in
                            CompanyDetails(company: item)
                        }
                        .navigationDestination(for: [ProductionCompany].self) { item in
                            CompaniesListView(companies: item)
                        }
                    }
                    .onDisappear { selectedItem = nil }
#if os(macOS)
                    .presentationDetents([.large])
                    .frame(minWidth: 800, idealWidth: 800, minHeight: 600, idealHeight: 600, alignment: .center)
#elseif os(iOS)
                    .appTheme()
                    .appTint()
#endif
                }
#if os(macOS)
                .sheet(isPresented: $showFeedbackForm) {
                    FeedbackComposerView(showFeedbackForm: $showFeedbackForm)
                        .frame(width: 400, height: 400, alignment: .center)
                }
                .sheet(isPresented: $showAbout) {
                    NavigationStack {
                        AboutSettings()
                            .navigationDestination(for: SettingsScreens.self) { _ in
                                DeveloperView()
                            }
                    }
                    .frame(width: 400, height: 400, alignment: .center)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showAbout = false
                            }
                        }
                    }
                }
#endif
        }
        .onChange(of: scene) {
            if scene == .active {
                NotificationManager.shared.refreshDailyPuzzleReminders()
            }
            if scene == .background {
                scheduleAppRefresh()
            }
#if os(iOS)
            if scene == .active {
                adForegroundCoordinator.presentForegroundAdsIfNeeded(
                    monetizationDisabled: PreviewVideoRuntime.shouldDisableMonetization()
                )
            }
#endif
        }
#if os(macOS)
        .commands {
            CommandGroup(after: .sidebar) {
                Picker("appearanceRowStyleTitle", selection: $settings.watchlistStyle) {
                    ForEach(SectionDetailsPreferredStyle.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Picker("appearanceSectionDetailsTitle", selection: $settings.sectionStyleType) {
                    ForEach(SectionDetailsPreferredStyle.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Picker("appearanceHorizontalListsTitle", selection: $settings.listsDisplayType) {
                    ForEach(ItemContentListPreferredDisplayType.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
            }
            
            CommandGroup(replacing: .help) {
                Button("Send Feedback") {
                    showFeedbackForm = true
                }
            }
            
            CommandGroup(replacing: .appInfo) {
                Button("aboutTitle") {
                    showAbout.toggle()
                }
            }
        }
#endif
        
#if os(macOS)
        Settings {
            SettingsView()
        }
        
        MenuBarExtra("Up Next (Streaming Now)", systemImage: "popcorn", isInserted: $showMenuBar) {
            VStack {
                UpNextMenuBar()
                    .environment(\.managedObjectContext, persistence.container.viewContext)
            }
            .frame(minWidth: 360, minHeight: 300, maxHeight: 600)
        }
        .menuBarExtraStyle(.window)
#endif
    }
    
    private func fetchContent(for id: String) async {
        if selectedItem != nil { selectedItem = nil }
        let type = id.last ?? "0"
        var media: MediaType = .movie
        if type == "1" {
            media = .tvShow
        }
        let contentID = id.dropLast(2)
        guard let contentIDNumber = Int(contentID) else { return }
        let item = try? await NetworkService.shared.fetchItem(id: contentIDNumber, type: media)
        guard let item else { return }
        self.selectedItem = item
    }
    
    private func registerRefreshBGTask() {
#if os(iOS)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as? BGAppRefreshTask ?? nil)
        }
#elseif os(macOS)
        _ = Timer.scheduledTimer(withTimeInterval: 10 * 3600, repeats: true) { _ in
            self.handleAppRefresh()
        }
#endif
    }
    
    private func scheduleAppRefresh() {
#if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: backgroundIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 180 * 60) // Fetch no earlier than 3 hours from now
        try? BGTaskScheduler.shared.submit(request)
#endif
    }
    
#if os(iOS)
    // Fetch the latest updates from api.
    private func handleAppRefresh(task: BGAppRefreshTask?) {
        if let task {
            scheduleAppRefresh()
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            
            // Track completion properly
            let operation = BlockOperation {
                Task {
                    await BackgroundManager.shared.handleWatchingContentRefresh()
                    BackgroundManager.shared.lastWatchingRefresh = Date()
                    await BackgroundManager.shared.handleUpcomingContentRefresh()
                    BackgroundManager.shared.lastUpcomingRefresh = Date()
                    await BackgroundManager.shared.handleAppRefreshMaintenance()
                    BackgroundManager.shared.lastMaintenance = Date()
                    
                    // Complete task after operations finish
                    task.setTaskCompleted(success: true)
                }
            }
            
            task.expirationHandler = {
                // After all operations are cancelled, the completion block below is called to set the task to complete.
                queue.cancelAllOperations()
                task.setTaskCompleted(success: false)
            }
            
            queue.addOperation(operation)
        }
    }
#elseif os(macOS)
    private func handleAppRefresh() {
        Task {
            await BackgroundManager.shared.handleWatchingContentRefresh()
            BackgroundManager.shared.lastWatchingRefresh = Date()
            await BackgroundManager.shared.handleUpcomingContentRefresh()
            BackgroundManager.shared.lastUpcomingRefresh = Date()
            await BackgroundManager.shared.handleAppRefreshMaintenance()
            BackgroundManager.shared.lastMaintenance = Date()
        }
    }
#endif
}

#if os(iOS)
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var notificationID: String?

    func handleNotificationTap(
        userInfo: [AnyHashable: Any],
        userDefaults: UserDefaults = .standard
    ) {
        notificationID = userInfo["contentID"] as? String
        guard DailyPuzzleLaunchIntentStore.shouldOpenFromNotification(userInfo: userInfo) else { return }

        let source = userInfo["source"] as? String == "local_reminder" ? "local_reminder" : "push_notification"
        DailyPuzzleLaunchIntentStore.requestOpen(source: source, userDefaults: userDefaults)
        DailyPuzzleLiveAnalyticsTracker().track(event: .openRequested(source: source))
        userDefaults.set(Screens.home.rawValue, forKey: "selectedView")
        NotificationCenter.default.post(name: .dailyPuzzleOpenRequested, object: nil)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        let gcmMessageIDKey = "gcm.message_id"

        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }

        if DailyPuzzleLaunchIntentStore.shouldOpenFromNotification(userInfo: userInfo) {
            // Background remote alerts cannot be vetoed here; the console version
            // cutoff is required as well. Local reminders are the sole owner now.
            if notification.request.trigger is UNPushNotificationTrigger { return [] }
            let allowed = await NotificationManager.shared.shouldPresentDailyPuzzleReminder()
            if !allowed { return [] }
        }
        return [[.banner, .list, .sound]]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        handleNotificationTap(userInfo: userInfo)

        completionHandler()
    }
}

extension AppDelegate: MessagingDelegate {
  // [START refresh_token]
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
    if let fcmToken, !fcmToken.isEmpty {
      UserDefaults.standard.set(fcmToken, forKey: "dailyPuzzleLastFCMToken")
    }

    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
    DailyPuzzlePushTopicManager.syncSubscription()
    // TODO: If necessary send token to application server.
    // Note: This callback is fired at each app startup and whenever a new token is generated.
  }

  // [END refresh_token]
}
#endif
