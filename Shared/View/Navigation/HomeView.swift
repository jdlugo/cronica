import SwiftUI
import StoreKit
import UserNotifications
import ConfettiSwiftUI
#if os(iOS)
import AdmobSwiftUI
#endif

struct HomeView: View {
    static let tag: Screens? = .home
#if os(tvOS)
    @AppStorage("showOnboarding") private var displayOnboard = false
#else
    @AppStorage("showOnboarding") private var displayOnboard = true
#endif
    @State private var viewModel = HomeViewModel()
    @State private var showNotifications = false
    @State private var showDailyReel = false
    @State private var showDailyPuzzle = false
    @State private var showMovieArcade = false
    @State private var openArchiveAfterPuzzle = false
    @State private var showPuzzleArchive = false
    @State private var dailyPuzzleSessionPuzzleCount = 0
    @State private var quizSessionPuzzleIDs = Set<String>()
    @State private var quizSessionMovieIDs = Set<Int>()
    @State private var showPopup = false
    @State private var reloadHome = false
    @State private var showWhatsNew = false
    @State private var hasNotifications = false
    @State private var popupType: ActionPopupItems?
    #if os(iOS)
    @Environment(\.requestReview) private var requestReview
    @State private var showSettings = false
    @State private var dailyReelFeature: DailyReelFeature?
    @State private var dailyReelRollout = DailyReelRolloutController()
    @State private var dailyPuzzleViewModel: DailyPuzzleViewModel?
    private let dailyPuzzleService = DailyPuzzleService(preferFirestorePrimary: true)
    private let reviewPromptCoordinator = ReviewPromptCoordinator.shared
    @StateObject private var homeNativeViewModel = NativeAdViewModel(
        adUnitID: AdConfiguration.AdUnitID.native,
        requestInterval: AdConfiguration.nativeRefreshInterval
    )
    #endif
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
#if os(iOS)
                if let rolloutVariant = dailyReelRolloutVariant {
                    DailyReelHomeCard {
                        openDailyReel(rolloutVariant: rolloutVariant)
                    }
                    .padding(.horizontal)
                }

                if let dailyPuzzleViewModel {
                    DailyPuzzleHomeCard(viewModel: dailyPuzzleViewModel) {
                        Task {
                            await openDailyPuzzleFromHomeCard()
                        }
                    }
                    .padding(.horizontal)
                }
#endif
                #if os(iOS)
                MovieArcadeHomeCard { showMovieArcade = true }.padding(.horizontal)
                #endif
                HorizontalUpNextListView(shouldReload: $reloadHome)
                UpcomingWatchlist(shouldReload: $reloadHome)
                PinItemsList(showPopup: $showPopup, popupType: $popupType, shouldReload: $reloadHome)
                HorizontalPinnedList(showPopup: $showPopup, popupType: $popupType, shouldReload: $reloadHome)
                HorizontalItemContentListView(items: viewModel.trending,
                                              title: "Trending",
                                              subtitle: "Today",
                                              showPopup: $showPopup,
                                              popupType: $popupType)
#if os(iOS)
                if shouldShowHomeNativeAd {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Advertisement")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        CronicaNativeAdCardView(nativeViewModel: homeNativeViewModel)
                            .frame(height: 320)
                            .background(Color(uiColor: .secondarySystemBackground))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 24)
                }
#endif
                ForEach(viewModel.sections) { section in
                    HorizontalItemContentListView(items: section.results,
                                                  title: section.title,
                                                  subtitle: section.subtitle,
                                                  showPopup: $showPopup,
                                                  popupType: $popupType,
                                                  endpoint: section.endpoint)
                }
                HorizontalItemContentListView(items: viewModel.recommendations,
                                              title: "recommendationsTitle",
                                              subtitle: "recommendationsSubtitle",
                                              showPopup: $showPopup,
                                              popupType: $popupType)
                .redacted(reason: viewModel.isLoadingRecommendations ? .placeholder : [] )
                AttributionView()
            }
#if os(iOS)
            .refreshable {
                reloadHome = true
                viewModel.reload()
            }
#endif
        }
        .overlay { if !viewModel.isLoaded { ProgressView("Loading").unredacted() } }
        .actionPopup(isShowing: $showPopup, for: popupType)
#if os(tvOS)
        .ignoresSafeArea(.all, edges: .horizontal)
#endif
        .onAppear {
            checkVersion()
#if os(iOS)
            reviewPromptCoordinator.prepareDebugEligibilityIfRequested()
            reviewPromptCoordinator.recordActiveDay()
            scheduleReviewPromptEvaluation()
#endif
#if os(iOS) || os(macOS)
            Task {
                let notifications = await NotificationManager.shared.hasDeliveredItems()
                hasNotifications = notifications
            }
#endif
        }
        .sheet(isPresented: $showWhatsNew) {
#if os(iOS)
            ChangelogView(showChangelog: $showWhatsNew)
                .onDisappear {
                    showWhatsNew = false
                }
#if os(macOS)
                .frame(minWidth: 400, idealWidth: 600, maxWidth: nil, minHeight: 500, idealHeight: 500, maxHeight: nil, alignment: .center)
#elseif os(iOS)
                .appTheme()
#endif
#endif
        }
        .navigationDestination(for: ItemContent.self) { item in
            ItemContentDetails(title: item.itemTitle,
                               id: item.id,
                               type: item.itemContentMedia)
#if os(tvOS)
            .ignoresSafeArea(.all, edges: .horizontal)
#endif
        }
        .navigationDestination(for: Person.self) { person in
            PersonDetailsView(name: person.name, id: person.id)
#if os(tvOS)
                .ignoresSafeArea(.all, edges: .horizontal)
#endif
        }
        .navigationDestination(for: WatchlistItem.self) { item in
            ItemContentDetails(title: item.itemTitle,
                               id: item.itemId,
                               type: item.itemMedia)
#if os(tvOS)
            .ignoresSafeArea(.all, edges: .horizontal)
#endif
        }
        .navigationDestination(for: Endpoints.self) { endpoint in
            EndpointDetails(title: endpoint.title,
                            endpoint: endpoint)
        }
#if os(iOS) || os(macOS)
        .navigationDestination(for: [WatchlistItem].self) { item in
            WatchlistSectionDetails(items: item)
        }
        .navigationDestination(for: [String:[WatchlistItem]].self) { item in
            let title = item.map { (key, _) in key }.first
            let items = item.map { (_, value) in value }.first
            if let title, let items {
                WatchlistSectionDetails(title: title, items: items)
            }
        }
#endif
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
        .redacted(reason: !viewModel.isLoaded ? .placeholder : [] )
#if os(iOS) || os(macOS)
        .navigationTitle("Home")
#endif
        #if os(iOS)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        #endif
        .toolbar {
#if os(macOS)
            ToolbarItem(placement: .navigation) {
                Button {
                    reloadHome = true
                    viewModel.reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            ToolbarItem {
                Button {
                    showNotifications.toggle()
                } label: {
                    Label("Notifications", systemImage: hasNotifications ? "bell.badge.fill" : "bell")
                        .labelStyle(.iconOnly)
                }
            }
#elseif os(iOS)
            if UIDevice.isIPad {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                            .fontDesign(.default)
                            .fontWeight(.semibold)
                            .imageScale(.medium)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.borderedProminent)
                    .contentShape(Circle())
                    .clipShape(Circle())
                    .tint(SettingsStore.shared.appTheme.color.opacity(0.7))
                    .shadow(radius: 2.5)
                    .accessibilityLabel("Settings")
                    .applyHoverEffect()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNotifications.toggle()
                } label: {
                    Image(systemName: hasNotifications ? "bell.badge.fill" : "bell")
                        .fontDesign(.default)
                        .fontWeight(.semibold)
                        .imageScale(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.borderedProminent)
                .contentShape(Circle())
                .clipShape(Circle())
                .tint(SettingsStore.shared.appTheme.color.opacity(0.7))
                .shadow(radius: 2.5)
                .accessibilityLabel("Notifications")
                .applyHoverEffect()
            }
#endif
        }
        .sheet(isPresented: $displayOnboard) {
            WelcomeView()
#if os(macOS)
                .frame(width: 500, height: 700, alignment: .center)
#endif
        }
        .sheet(isPresented: $showNotifications) {
#if os(iOS) || os(macOS)
            NotificationListView(showNotification: $showNotifications)
                .appTheme()
                .onDisappear {
                    Task {
                        let notifications = await NotificationManager.shared.hasDeliveredItems()
                        hasNotifications = notifications
                    }
                }
#if os(macOS)
                .frame(width: 800, height: 500)
#endif
#endif
        }
#if os(iOS)
        .fullScreenCover(isPresented: $showDailyReel) {
            if let dailyReelFeature {
                DailyReelView(
                    feature: dailyReelFeature,
                    onChallenge: { session in
                        try await createDailyReelChallenge(for: session)
                    },
                    onClose: { showDailyReel = false }
                )
                .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $showMovieArcade) { MovieArcadeView() }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--arcade-test"),
               ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--arcade-game=") }) { showMovieArcade = true }
#endif
        }
        .sheet(isPresented: $showDailyPuzzle, onDismiss: handleDailyPuzzleDismissed) {
            if let dailyPuzzleViewModel {
                NavigationStack {
                    DailyPuzzleGameView(
                        viewModel: dailyPuzzleViewModel,
                        showsNextPuzzleControl: true,
                        onRequestNextPuzzle: {
                            try await loadNextDailyPuzzleFromModal()
                        },
                        onOpenArchive: {
                            openArchiveAfterPuzzle = true
                            showDailyPuzzle = false
                        }
                    )
                }
                .appTheme()
            }
        }
#endif
        .sheet(isPresented: $showPuzzleArchive) {
            NavigationStack {
                PuzzleArchiveView()
            }
            .appTheme()
        }
        .task {
            await viewModel.load()
#if os(iOS)
            if !shouldPreviewDailyReel {
                await dailyReelRollout.refresh()
            }
            await loadDailyPuzzle()
            await loadHomeNativeAdIfNeeded()
            await openDailyPuzzleFromPushIfNeeded()
#endif
        }
#if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: .dailyPuzzleOpenRequested)) { _ in
            Task {
                await openDailyPuzzleFromPushIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reviewPromptMilestoneEarned)) { _ in
            scheduleReviewPromptEvaluation()
        }
#endif
    }
    
    private func checkVersion() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let lastSeenVersion = UserDefaults.standard.string(forKey: UserDefaults.lastSeenAppVersionKey)
        if SettingsStore.shared.displayOnboard {
            return
        } else {
            if currentVersion != lastSeenVersion {
                // showWhatsNew.toggle()
                UserDefaults.standard.set(currentVersion, forKey: UserDefaults.lastSeenAppVersionKey)
            }
        }
    }
    
#if os(iOS)
    private var dailyReelRolloutVariant: String? {
        if shouldPreviewDailyReel {
            return "debug-preview"
        }
        guard case .enabled(let variant) = dailyReelRollout.state else {
            return nil
        }
        return variant
    }

    private var shouldPreviewDailyReel: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("--daily-reel-preview")
#else
        false
#endif
    }

    @MainActor
    private func openDailyReel(rolloutVariant: String) {
        let publicationID = dailyReelPublicationID
        let locale = Locale.current.identifier
#if DEBUG
        if shouldPreviewDailyReel {
            dailyReelFeature = DailyReelPreviewAssembly.makeFeature(
                publicationID: publicationID,
                locale: locale
            )
        } else {
            dailyReelFeature = DailyReelAssembly.makeFeature(
                publicationID: publicationID,
                locale: locale,
                rolloutVariant: rolloutVariant
            )
        }
#else
        dailyReelFeature = DailyReelAssembly.makeFeature(
            publicationID: publicationID,
            locale: locale,
            rolloutVariant: rolloutVariant
        )
#endif
        showDailyReel = dailyReelFeature != nil
    }

    @MainActor
    private func createDailyReelChallenge(
        for session: DailyReelSessionProjection
    ) async throws -> URL {
        guard session.isComplete, let feature = dailyReelFeature, let capability = feature.capability else {
            throw DailyReelClientError.invalidResponse
        }
#if DEBUG
        if shouldPreviewDailyReel {
            await feature.recordChallengeCreated()
            return URL(string: "https://example.invalid/c#capability=debug-preview")!
        }
#endif
        guard let client = DailyReelAssembly.makeChallengeClient() else {
            throw DailyReelClientError.invalidEndpoint
        }
        do {
            let response = try await client.create(
                sourceSessionCapability: capability,
                requestID: UUID().uuidString.lowercased(),
                nickname: nil
            )
            await feature.recordChallengeCreated()
            return response.shareURL
        } catch {
            let code: String
            if let error = error as? DailyReelClientError,
               case .server(let serverCode, _, _) = error {
                code = serverCode
            } else {
                code = "network_or_decode"
            }
            await feature.recordChallengeCreationFailed(code: code)
            throw error
        }
    }

    private var dailyReelPublicationID: String {
        DailyReelPublicationCalendar.publicationID()
    }

    @MainActor
    private func openDailyPuzzleFromHomeCard() async {
        if shouldUseFallbackDailyPuzzle {
            dailyPuzzleViewModel = makeFallbackDailyPuzzleViewModel()
        } else {
            let currentPuzzleID = dailyPuzzleViewModel?.puzzle.puzzleID
            dailyPuzzleViewModel = await DailyPuzzleModalOpenLoader.refreshViewModelForOpen(
                currentPuzzleID: currentPuzzleID,
                service: dailyPuzzleService
            )
        }
        dailyPuzzleViewModel?.trackOpened(source: "home_card")
        dailyPuzzleSessionPuzzleCount = 1
        quizSessionPuzzleIDs = Set([dailyPuzzleViewModel?.puzzle.puzzleID].compactMap { $0 })
        quizSessionMovieIDs = Set([dailyPuzzleViewModel?.puzzle.tmdbID].compactMap { $0 })
        showDailyPuzzle = true
    }

    private func loadDailyPuzzle() async {
        if shouldUseFallbackDailyPuzzle {
            dailyPuzzleViewModel = makeFallbackDailyPuzzleViewModel()
            return
        }

        do {
            let puzzle = try await dailyPuzzleService.fetchLatestPuzzle()
            dailyPuzzleViewModel = DailyPuzzleViewModel(puzzle: puzzle)
        } catch {
            dailyPuzzleViewModel = DailyPuzzleViewModel(puzzle: dailyPuzzleService.fallbackPuzzle())
        }
    }

    private var shouldUseFallbackDailyPuzzle: Bool {
        ProcessInfo.processInfo.arguments.contains("--daily-puzzle-use-fallback")
    }

    private func makeFallbackDailyPuzzleViewModel() -> DailyPuzzleViewModel {
        let processID = ProcessInfo.processInfo.processIdentifier
        let suiteName = "CronicaUITests.DailyPuzzle.\(processID)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        var puzzle = dailyPuzzleService.fallbackPuzzle()
        puzzle.puzzleID = "\(puzzle.puzzleID)-ui-\(processID)"

        return DailyPuzzleViewModel(
            puzzle: puzzle,
            streakStore: DailyPuzzleStreakStore(userDefaults: userDefaults),
            promptStore: DailyPuzzlePromptStore(userDefaults: userDefaults),
            progressStore: DailyPuzzleProgressStore(userDefaults: userDefaults)
        )
    }

    private var shouldShowHomeNativeAd: Bool {
        HomeAdPolicy.shouldShowNativeAd(
            hasPurchasedTipJar: SettingsStore.shared.hasPurchasedTipJar,
            monetizationDisabled: PreviewVideoRuntime.shouldDisableMonetization(),
            isOverlayPresented: isHomeOverlayPresented
        )
    }

    private var isHomeOverlayPresented: Bool {
        displayOnboard
            || showSettings
            || showNotifications
            || showDailyReel
            || showDailyPuzzle
            || showPuzzleArchive
            || showWhatsNew
            || showPopup
    }

    private func loadHomeNativeAdIfNeeded() async {
        guard shouldShowHomeNativeAd else { return }
        let delay = AdConfiguration.nativeInitialRequestDelay
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
        }
        await MainActor.run {
            homeNativeViewModel.refreshAd()
        }
    }

    private func openDailyPuzzleFromPushIfNeeded() async {
        guard let openSource = DailyPuzzleLaunchIntentStore.consumeOpenRequestSource() else { return }
        let currentPuzzleID = dailyPuzzleViewModel?.puzzle.puzzleID
        dailyPuzzleViewModel = shouldUseFallbackDailyPuzzle ? makeFallbackDailyPuzzleViewModel() : await DailyPuzzleModalOpenLoader.refreshViewModelForOpen(
            currentPuzzleID: currentPuzzleID,
            service: dailyPuzzleService
        )
        dailyPuzzleViewModel?.trackOpened(source: openSource)
        dailyPuzzleSessionPuzzleCount = 1
        quizSessionPuzzleIDs = Set([dailyPuzzleViewModel?.puzzle.puzzleID].compactMap { $0 })
        quizSessionMovieIDs = Set([dailyPuzzleViewModel?.puzzle.tmdbID].compactMap { $0 })
        showDailyPuzzle = true
    }

    @MainActor
    private func loadNextDailyPuzzleFromModal() async throws {
        guard let previousViewModel = dailyPuzzleViewModel else { return }
        let currentPuzzleID = previousViewModel.puzzle.puzzleID
        let completedPuzzleIndex = max(1, dailyPuzzleSessionPuzzleCount)
        previousViewModel.trackNextPuzzleTapped(source: "modal")

        do {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--daily-puzzle-next-offline") {
                throw URLError(.notConnectedToInternet)
            }
#endif
            let refreshedPuzzle: DailyPuzzle
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--movie-quiz-fixture") {
                refreshedPuzzle = DailyPuzzle.developerSamples[completedPuzzleIndex % DailyPuzzle.developerSamples.count]
            } else {
                refreshedPuzzle = try await dailyPuzzleService.fetchNextPuzzle(excluding: currentPuzzleID, excludingIDs: quizSessionPuzzleIDs, excludingMovieIDs: quizSessionMovieIDs)
            }
#else
            refreshedPuzzle = try await dailyPuzzleService.fetchNextPuzzle(excluding: currentPuzzleID, excludingIDs: quizSessionPuzzleIDs, excludingMovieIDs: quizSessionMovieIDs)
#endif
            quizSessionPuzzleIDs.insert(refreshedPuzzle.puzzleID)
            quizSessionMovieIDs.insert(refreshedPuzzle.tmdbID)
            let nextPuzzleIndex = completedPuzzleIndex + 1
            dailyPuzzleViewModel = DailyPuzzleViewModel(
                puzzle: refreshedPuzzle,
                recordsDailyStreak: false,
                restoresProgress: false,
                puzzleIndex: nextPuzzleIndex
            )
            dailyPuzzleSessionPuzzleCount = nextPuzzleIndex
            dailyPuzzleViewModel?.trackOpened(source: "modal_next")
            dailyPuzzleViewModel?.trackNextPuzzleLoaded(
                previousPuzzleID: currentPuzzleID,
                puzzleIndex: dailyPuzzleSessionPuzzleCount
            )
        } catch {
            previousViewModel.trackNextPuzzleLoadFailed(
                reason: (error as? URLError).map { "url_error_\($0.code.rawValue)" } ?? "loading_failed"
            )
            // Preserve progress and let the game present recovery actions.
            throw error
        }
    }

    @MainActor
    private func handleDailyPuzzleDismissed() {
        dailyPuzzleViewModel?.trackDismissed()
        if openArchiveAfterPuzzle {
            openArchiveAfterPuzzle = false
            showPuzzleArchive = true
            return
        }
        scheduleReviewPromptEvaluation()
    }

    private var hasBlockingReviewPresentation: Bool {
        showSettings
            || showNotifications
            || showWhatsNew
            || showDailyPuzzle
            || showPuzzleArchive
            || showPopup
    }

    @MainActor
    private func scheduleReviewPromptEvaluation() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(750))
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            let decision = reviewPromptCoordinator.decision(
                appVersion: appVersion,
                context: ReviewPromptContext(
                    onboardingActive: displayOnboard,
                    blockingPresentationActive: hasBlockingReviewPresentation,
                    fullScreenAdActive: AdCoordinator.shared.isPresentingFullScreenAd
                )
            )
            reviewPromptCoordinator.trackEvaluation(decision, appVersion: appVersion)
            guard case .eligible(let milestone) = decision else { return }
            reviewPromptCoordinator.recordRequestAttempt(
                appVersion: appVersion,
                milestone: milestone
            )
            requestReview()
        }
    }
#endif
}

#Preview {
    HomeView()
}

#if os(iOS)
private struct DailyPuzzleHomeCard: View {
    @AppStorage("dailyPuzzleLastSeenHomeCardPuzzleID") private var lastSeenPuzzleID = ""
    @State private var attentionScale: CGFloat = 1
    @State private var attentionRotation: Double = 0
    @State private var attentionGlow = false
    @State private var isVisible = false
    @State private var shimmerPhase: CGFloat = 0

    let viewModel: DailyPuzzleViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(NSLocalizedString("dailyPuzzleTitle", comment: "Daily puzzle card title"))
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    Text(viewModel.cardStatusText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(SettingsStore.shared.appTheme.color.opacity(0.22))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(SettingsStore.shared.appTheme.color.opacity(0.45), lineWidth: 1)
                        )
                }
                Text(
                    NSLocalizedString(
                        "movieQuizCardSubtitle",
                        value: "Recognize the movie from the image.",
                        comment: "Daily puzzle card subtitle"
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Label(quizText("movieQuizCard", "4 movies. Four choices. Just tap."), systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 8)
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                        Text(
                            viewModel.isSolved
                                ? NSLocalizedString("dailyPuzzleViewPuzzle", comment: "View puzzle CTA")
                                : NSLocalizedString("dailyPuzzlePlayPuzzle", comment: "Play puzzle CTA")
                        )
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SettingsStore.shared.appTheme.color.opacity(0.2))
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(uiColor: .secondarySystemBackground),
                                SettingsStore.shared.appTheme.color.opacity(0.18),
                                Color(uiColor: .secondarySystemBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Subtle shimmer overlay
                        GeometryReader { geometry in
                            let shimmerWidth = geometry.size.width * 0.5
                            let totalTravel = geometry.size.width + shimmerWidth
                            LinearGradient(
                                colors: [
                                    .clear,
                                    SettingsStore.shared.appTheme.color.opacity(0.15),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: shimmerWidth)
                            .offset(x: -shimmerWidth + (shimmerPhase * totalTravel))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(SettingsStore.shared.appTheme.color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(attentionScale)
            .rotationEffect(.degrees(attentionRotation))
            .shadow(
                color: SettingsStore.shared.appTheme.color.opacity(attentionGlow ? 0.45 : 0),
                radius: attentionGlow ? 22 : 0,
                x: 0,
                y: attentionGlow ? 10 : 0
            )
            // Entrance animation
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .onAppear {
                // Entrance animation
                withAnimation(.easeOut(duration: 0.4)) {
                    isVisible = true
                }
                // Start shimmer loop after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startShimmerLoop()
                }
                animateCardAttentionIfFirstSeen()
            }
            .onChange(of: viewModel.puzzle.puzzleID) {
                animateCardAttentionIfFirstSeen()
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dailyPuzzle.homeCard")
    }

    private func startShimmerLoop() {
        // First shimmer
        withAnimation(.easeInOut(duration: 1.8)) {
            shimmerPhase = 1
        }
        // Second shimmer after a pause
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            shimmerPhase = 0
            withAnimation(.easeInOut(duration: 1.8)) {
                shimmerPhase = 1
            }
        }
    }

    private func animateCardAttentionIfFirstSeen() {
        guard lastSeenPuzzleID != viewModel.puzzle.puzzleID else { return }
        lastSeenPuzzleID = viewModel.puzzle.puzzleID

        withAnimation(.spring(response: 0.35, dampingFraction: 0.62).repeatCount(3, autoreverses: true)) {
            attentionScale = 1.03
            attentionGlow = true
        }
        withAnimation(.easeInOut(duration: 0.14).repeatCount(6, autoreverses: true)) {
            attentionRotation = 1.4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                attentionScale = 1
                attentionRotation = 0
                attentionGlow = false
            }
        }
    }
}

private struct DailyPuzzleDifficultyFeedbackView: View {
    @Bindable var viewModel: DailyPuzzleViewModel

    var body: some View {
        if viewModel.shouldRequestDifficultyFeedback {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    localizedDailyPuzzleString(
                        "dailyPuzzleDifficultyQuestion",
                        defaultValue: "How did this puzzle feel?",
                        comment: "Prompt for puzzle difficulty feedback"
                    )
                )
                .font(.headline)

                ForEach(DailyPuzzleDifficultyRating.allCases, id: \.self) { rating in
                    Button {
                        viewModel.submitDifficultyFeedback(rating)
                    } label: {
                        Text(rating.localizedTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("dailyPuzzle.difficulty.\(rating.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier("dailyPuzzle.difficultyFeedback")
        } else if viewModel.hasSubmittedDifficultyFeedback {
            Label(
                localizedDailyPuzzleString(
                    "dailyPuzzleDifficultyThanks",
                    defaultValue: "Thanks. We'll tune future puzzles.",
                    comment: "Confirmation after puzzle difficulty feedback"
                ),
                systemImage: "checkmark.circle.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("dailyPuzzle.difficultyFeedback")
        }
    }
}

private func quizText(_ key: String, _ fallback: String) -> String {
    NSLocalizedString(key, value: fallback, comment: "Movie image quiz")
}

private struct MovieQuizRoundView: View {
    @Bindable var viewModel: DailyPuzzleViewModel
    let notificationStatus: UNAuthorizationStatus
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var finished: Bool { viewModel.isSolved || viewModel.didFail }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let state = viewModel.quizState {
                Text(state.zoomStep != nil && !finished ? quizText("movieQuizZoomPrompt", "Look closer. Which movie is this?") : quizText("movieQuizQuestion", "Which movie is this?"))
                    .font(.title3.bold())
                imageClue(state.round)
                if finished {
                    HStack(alignment: .top, spacing: 16) {
                        if viewModel.puzzle.mediaType == .movie, UIImage(named: "MovieQuizPoster\(state.round.answerID)") != nil {
                            Image("MovieQuizPoster\(state.round.answerID)").resizable().scaledToFit()
                                .frame(width: 85, height: 126)
                                .clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
                        } else if let path = state.round.posterPath,
                           let url = NetworkService.urlBuilder(size: .medium, path: path) {
                            AsyncImage(url: url) { image in image.resizable().scaledToFit() }
                                placeholder: { Color.secondary.opacity(0.1) }
                                .frame(width: 85, height: 126)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(viewModel.isSolved ? quizText("movieQuizCorrect", "You got it!") : quizText("movieQuizReveal", "The answer is…"))
                                .font(.headline).foregroundStyle(viewModel.isSolved ? .green : .primary)
                            Text(state.round.choices.first(where: { $0.id == state.round.answerID })?.title ?? "")
                                .font(.title2.bold())
                            Text(state.importedLegacyResult == true ? quizText("movieQuizLegacy", "Completed before the quiz update") : String(format: quizText("movieQuizPoints", "%ld / 3 points"), state.points))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    .accessibilityIdentifier("movieQuiz.result")
                    Text(viewModel.puzzle.hint1 + " • " + viewModel.puzzle.hint2)
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    if state.hintRevealed && state.imageUnavailable != true {
                        Label(viewModel.puzzle.hint1 + " • " + viewModel.puzzle.hint2, systemImage: "lightbulb.fill")
                            .font(.callout)
                            .accessibilityIdentifier("movieQuiz.hint")
                    }
                    if !state.eliminatedIDs.isEmpty {
                        Text(quizText("movieQuizTryAgain", "Not that one. Here’s a clue—try another title."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(state.round.choices) { choice in
                        Button {
                            viewModel.chooseMovie(choice.id, notificationStatus: notificationStatus)
                        } label: {
                            HStack {
                                Text(choice.title).multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                if state.eliminatedIDs.contains(choice.id) {
                                    Image(systemName: "xmark.circle").accessibilityLabel(quizText("movieQuizEliminated", "Eliminated"))
                                }
                            }
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .disabled(state.eliminatedIDs.contains(choice.id))
                        .accessibilityIdentifier("movieQuiz.choice.\(choice.id)")
                    }
                    HStack {
                        if !state.hintRevealed {
                            Button(hintTitle(state)) { viewModel.revealMovieQuizHint() }
                                .accessibilityIdentifier("movieQuiz.showHint")
                        }
                        Spacer()
                        Button(quizText("movieQuizSkip", "Reveal answer")) { viewModel.skipMovieQuiz() }
                            .accessibilityIdentifier("movieQuiz.skip")
                    }
                    .font(.footnote)
                }
            } else if viewModel.quizLoadFailed {
                Text(quizText("movieQuizUnavailable", "Couldn’t load this round."))
                Button(quizText("movieQuizRetry", "Try again")) { Task { await viewModel.loadMovieQuiz() } }
            } else {
                ProgressView(quizText("movieQuizLoading", "Loading movie quiz…"))
                    .frame(maxWidth: .infinity, minHeight: 180)
            }
        }
        .sensoryFeedback(.success, trigger: viewModel.isSolved)
        .sensoryFeedback(.warning, trigger: viewModel.quizState?.eliminatedIDs.count ?? 0)
        .task(id: viewModel.puzzle.puzzleID) { await viewModel.loadMovieQuiz() }
    }

    private func hintTitle(_ state: MovieQuizState) -> String {
        var assisted = state
        assisted.revealHint()
        return assisted.availablePoints < state.availablePoints
            ? quizText("movieQuizHint", "Show clue · −1 point")
            : quizText("movieQuizHintFree", "Show clue")
    }

    private func tileScoreHint(_ state: MovieQuizState, index: Int) -> String {
        var revealed = state
        revealed.revealTile(index)
        return String(format: quizText("movieQuizTileScoreHint", "Score after this reveal: up to %ld"), revealed.availablePoints)
    }

    private func fullImageTitle(_ state: MovieQuizState) -> String {
        var revealed = state
        for index in 0..<9 { revealed.revealTile(index) }
        return String(format: quizText("movieQuizRevealAllScore", "Uncover image · score %ld"), revealed.availablePoints)
    }

    @ViewBuilder
    private func imageClue(_ round: MovieQuizRound) -> some View {
        if viewModel.puzzle.mediaType == .movie, UIImage(named: "MovieQuiz\(round.answerID)") != nil {
            revealImage(Image("MovieQuiz\(round.answerID)"))
        } else if let path = round.backdropPath, let url = NetworkService.urlBuilder(size: .medium, path: path) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): revealImage(image)
                case .failure: unavailableImage
                default: ProgressView().frame(maxWidth: .infinity, minHeight: 190)
                }
            }
        } else {
            unavailableImage
        }
    }

    private func revealImage(_ image: Image) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack {
                    image.resizable().scaledToFit()
                        .scaleEffect(finished ? 1 : (viewModel.quizState?.zoomScale ?? 1))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: finished ? 1 : (viewModel.quizState?.zoomScale ?? 1))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped().accessibilityHidden(true)
                    if let state = viewModel.quizState, state.revealedTiles != nil {
                        ForEach(0..<9) { index in
                            let covered = !finished && !state.visibleTileIndices.contains(index)
                            Button {
                                viewModel.revealMovieQuizTile(index)
                            } label: {
                                ZStack {
                                    LinearGradient(colors: [Color(white: 0.23), Color(white: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.16), lineWidth: 1)
                                    Image(systemName: "sparkle")
                                        .font(.title3).foregroundStyle(.white.opacity(0.75))
                                }
                                .frame(width: geometry.size.width / 3, height: geometry.size.height / 3)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(format: quizText("movieQuizTileLabel", "Reveal tile %ld"), index + 1))
                            .accessibilityHint(tileScoreHint(state, index: index))
                            .accessibilityIdentifier("movieQuiz.tile.\(index)")
                            .accessibilityHidden(!covered)
                            .allowsHitTesting(covered)
                            .opacity(covered ? 1 : 0)
                            .scaleEffect(covered || reduceMotion ? 1 : 0.82)
                            .rotation3DEffect(.degrees(covered || reduceMotion ? 0 : 65), axis: (x: 0, y: 1, z: 0))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.32).delay(finished ? Double(index) * 0.035 : 0), value: covered)
                            .position(x: (CGFloat(index % 3) + 0.5) * geometry.size.width / 3,
                                      y: (CGFloat(index / 3) + 0.5) * geometry.size.height / 3)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .frame(height: 190)
            .onAppear { viewModel.trackQuizImage("shown") }
            .sensoryFeedback(.selection, trigger: viewModel.quizState?.visibleTileIndices.count ?? 9)
            .sensoryFeedback(.selection, trigger: viewModel.quizState?.zoomStep ?? 0)
            if let state = viewModel.quizState, let step = state.zoomStep, !finished {
                ViewThatFits(in: .horizontal) {
                    revealControls(state, zoomStep: step, vertical: false)
                    revealControls(state, zoomStep: step, vertical: true)
                }
            }
            if let state = viewModel.quizState, state.revealedTiles != nil, !finished {
                ViewThatFits(in: .horizontal) {
                    revealControls(state, zoomStep: nil, vertical: false)
                    revealControls(state, zoomStep: nil, vertical: true)
                }
            }
        }
    }

    private func revealControls(_ state: MovieQuizState, zoomStep: Int?, vertical: Bool) -> some View {
        let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return layout {
            if let step = zoomStep {
                    Text(String(format: step == 0
                                ? quizText("movieQuizZoomClose", "Close-up · Score up to %ld")
                                : step == 1 ? quizText("movieQuizZoomWider", "Wider view · Score up to %ld")
                                : quizText("movieQuizZoomFull", "Full image · Score up to %ld"), state.availablePoints))
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("movieQuiz.zoomStatus")
                    if step < 2 {
                        Button(state.availablePoints > 1
                               ? quizText("movieQuizZoomOut", "Zoom out · −1 point")
                               : quizText("movieQuizZoomOutFree", "Zoom out")) { viewModel.zoomOutMovieQuiz() }
                            .font(.caption)
                            .accessibilityIdentifier("movieQuiz.zoomOut")
                    }
            } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.visibleTileIndices.count == 9
                             ? quizText("movieQuizFullImage", "Full image revealed")
                             : quizText("movieQuizTilePrompt", "Tap tiles to uncover the movie"))
                            .font(.caption.weight(.semibold))
                        Text(String(format: quizText("movieQuizRevealStatus", "%ld of 9 tiles · Score up to %ld"), state.visibleTileIndices.count, state.availablePoints))
                            .font(.caption2).foregroundStyle(.secondary)
                            .accessibilityIdentifier("movieQuiz.revealStatus")
                    }
                    if state.visibleTileIndices.count < 9 {
                        Button(fullImageTitle(state)) {
                            for index in 0..<9 { viewModel.revealMovieQuizTile(index) }
                        }
                        .font(.caption)
                        .accessibilityIdentifier("movieQuiz.revealAll")
                    }
            }
        }
        .fixedSize(horizontal: !vertical, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var unavailableImage: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(quizText("movieQuizImageUnavailable", "Image unavailable. Play with a clue instead."), systemImage: "photo")
                .font(.caption).foregroundStyle(.secondary)
            if !finished {
                Text(viewModel.puzzle.hint1 + " • " + viewModel.puzzle.hint2).font(.callout)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            viewModel.trackQuizImage("unavailable")
            viewModel.handleMovieQuizImageUnavailable()
        }
    }
}

private struct DailyPuzzleGameView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: DailyPuzzleViewModel
    let showsNextPuzzleControl: Bool
    let onRequestNextPuzzle: (() async throws -> Void)?
    var onOpenArchive: (() -> Void)?
    @State private var currentStatus: UNAuthorizationStatus = .notDetermined
    @State private var isLoadingNextPuzzle = false
    @State private var showNextPuzzleError = false
    @State private var dailyRunState = DailyPuzzleRunState()
    @State private var trackedDailyRunSequence: Int?
    @State private var weeklyGoalProgress: DailyPuzzleWeeklyGoalProgress?
    private let weeklyGoalStore = DailyPuzzleWeeklyGoalStore()
    private var puzzleFinished: Bool { viewModel.isSolved || viewModel.didFail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
            if showsNextPuzzleControl { dailyRunProgress }
            MovieQuizRoundView(viewModel: viewModel, notificationStatus: currentStatus)

            if viewModel.offersDailyReminder,
               !showsNextPuzzleControl || onRequestNextPuzzle == nil || dailyRunState.isComplete {
                reminderOptIn
            }

            if puzzleFinished, showsNextPuzzleControl, onRequestNextPuzzle != nil, dailyRunState.isComplete {
                dailyRunSummary
            }

            if puzzleFinished {
                DisclosureGroup(quizText("movieQuizFeedback", "Rate this round")) {
                    DailyPuzzleDifficultyFeedbackView(viewModel: viewModel)
                }
                .font(.subheadline)
            }

                if let onOpenArchive {
                    Button {
                        onOpenArchive()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "archivebox.fill")
                            Text(NSLocalizedString("puzzleArchiveViewArchive", comment: "View archive CTA"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .confettiCannon(
            trigger: Binding(get: { reduceMotion ? 0 : viewModel.solveCelebrationCount }, set: { viewModel.solveCelebrationCount = $0 }),
            num: 45,
            radius: 320,
            repetitions: 2,
            repetitionInterval: 0.14
        )
        // A new round must not inherit particles still falling from the previous solve.
        .id(viewModel.puzzle.puzzleID)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if puzzleFinished,
               showsNextPuzzleControl,
               onRequestNextPuzzle != nil,
               !dailyRunState.isComplete {
                dailyRunContinueBar
            }
        }
        .navigationTitle(NSLocalizedString("dailyPuzzleTitle", comment: "Daily puzzle title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(Text(verbatim: "Dismiss"))
                .accessibilityIdentifier("dailyPuzzle.dismiss")
            }
        }
        .accessibilityIdentifier("dailyPuzzle.modal")
        .alert(NSLocalizedString("puzzleNextLoadError", value: "Couldn’t load the next puzzle", comment: "Puzzle loading error"), isPresented: $showNextPuzzleError) {
            Button(NSLocalizedString("puzzleRetry", value: "Retry", comment: "Retry puzzle loading")) {
                Task { await handleNextPuzzleTapped() }
            }
            if let onOpenArchive {
                Button(NSLocalizedString("puzzleOffline", value: "Offline Puzzles", comment: "Open bundled puzzles")) { onOpenArchive() }
            }
            Button(NSLocalizedString("puzzleStay", value: "Stay Here", comment: "Keep current puzzle"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("puzzleNextLoadMessage", value: "Your progress is saved. Try again, or play the included puzzles without an internet connection.", comment: "Puzzle recovery message"))
        }
        .onAppear {
            viewModel.trackScreenVisible()
            recordTerminalPuzzleIfNeeded()
        }
        .onChange(of: puzzleFinished) {
            recordTerminalPuzzleIfNeeded()
        }
        .onChange(of: viewModel.puzzle.puzzleID) {
            viewModel.trackScreenVisible()
            if dailyRunState.isComplete {
                dailyRunState.startNextRun()
            }
            recordTerminalPuzzleIfNeeded()
        }
        .onDisappear { isLoadingNextPuzzle = false }
        .task {
            currentStatus = await NotificationManager.shared.authorizationStatus()
        }
    }

    private var dailyRunSequence: Int {
        max(1, ((viewModel.puzzleIndex - 1) / DailyPuzzleRunState.targetRounds) + 1)
    }

    private var displayedDailyRunRound: Int {
        dailyRunState.displayedRound(for: viewModel.puzzle.puzzleID)
    }

    private var dailyRunProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(NSLocalizedString("dailyPuzzleRunTitle", comment: "Daily Run progress title"))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(
                    String(
                        format: NSLocalizedString("dailyPuzzleRunRoundFormat", comment: "Daily Run round progress"),
                        displayedDailyRunRound,
                        DailyPuzzleRunState.targetRounds
                    )
                )
                    .font(.caption.monospacedDigit().weight(.semibold))
            }

            ProgressView(
                value: Double(displayedDailyRunRound),
                total: Double(DailyPuzzleRunState.targetRounds)
            )
            .tint(.accentColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            NSLocalizedString("dailyPuzzleRunProgressAccessibilityLabel", comment: "Daily Run progress accessibility label")
        )
        .accessibilityValue(
            String(
                format: NSLocalizedString("dailyPuzzleRunRoundFormat", comment: "Daily Run round progress"),
                displayedDailyRunRound,
                DailyPuzzleRunState.targetRounds
            )
        )
        .accessibilityIdentifier("dailyPuzzle.runProgress")
    }

    private var dailyRunSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(
                NSLocalizedString("dailyPuzzleRunComplete", comment: "Daily Run completion title"),
                systemImage: "flag.checkered"
            )
                .font(.title3.weight(.bold))

            Text(
                String(
                    format: NSLocalizedString("dailyPuzzleRunSolvedFormat", comment: "Daily Run solved summary"),
                    dailyRunState.solvedRounds,
                    DailyPuzzleRunState.targetRounds
                )
            )
                .font(.title2.monospacedDigit().weight(.heavy))

            Text(String(format: quizText("movieQuizRunScore", "%ld / %ld points · %ld first-try answers"), dailyRunState.quizPoints, DailyPuzzleRunState.maxPoints, dailyRunState.firstTryRounds))
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("movieQuiz.runPoints")

            HStack(spacing: 18) {
                Label(
                    String(
                        format: NSLocalizedString("dailyPuzzleRunAttemptsFormat", comment: "Daily Run attempts"),
                        dailyRunState.totalAttempts
                    ),
                    systemImage: "hand.tap"
                )
                Label(
                    String(
                        format: NSLocalizedString("dailyPuzzleRunHintsFormat", comment: "Daily Run hints"),
                        dailyRunState.totalHints
                    ),
                    systemImage: "lightbulb"
                )
            }
            .font(.subheadline.weight(.semibold))

            Label(
                String(
                    format: quizText("movieQuizParticipationStreak", "%ld-day playing streak"),
                    dailyRunState.currentStreak
                ),
                systemImage: "flame.fill"
            )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            if let weeklyGoalProgress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(
                            NSLocalizedString("dailyPuzzleWeeklyGoalTitle", comment: "Weekly puzzle goal title"),
                            systemImage: weeklyGoalProgress.isComplete
                                ? "trophy.fill"
                                : "calendar.badge.checkmark"
                        )
                        .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(
                            String(
                                format: NSLocalizedString("dailyPuzzleWeeklyGoalDaysFormat", comment: "Weekly goal day progress"),
                                weeklyGoalProgress.completedDays,
                                weeklyGoalProgress.targetDays
                            )
                        )
                        .font(.subheadline.monospacedDigit().weight(.bold))
                    }

                    ProgressView(
                        value: Double(weeklyGoalProgress.completedDays),
                        total: Double(weeklyGoalProgress.targetDays)
                    )
                    .tint(weeklyGoalProgress.isComplete ? .green : .accentColor)

                    Text(
                        weeklyGoalProgress.isComplete
                            ? NSLocalizedString("dailyPuzzleWeeklyGoalCompleteMessage", comment: "Weekly goal completed message")
                            : NSLocalizedString("dailyPuzzleWeeklyGoalProgressMessage", comment: "Weekly goal progress message")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(
                    Color.accentColor.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    NSLocalizedString("dailyPuzzleWeeklyGoalTitle", comment: "Weekly puzzle goal title")
                )
                .accessibilityValue(
                    String(
                        format: NSLocalizedString("dailyPuzzleWeeklyGoalAccessibilityValueFormat", comment: "Weekly goal accessibility progress"),
                        weeklyGoalProgress.completedDays,
                        weeklyGoalProgress.targetDays
                    )
                )
                .accessibilityIdentifier("dailyPuzzle.weeklyGoal")
            }

            ShareLink(item: dailyRunState.shareText) {
                Label(
                    NSLocalizedString("dailyPuzzleShareRun", comment: "Share Daily Run button"),
                    systemImage: "square.and.arrow.up"
                )
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .simultaneousGesture(
                TapGesture().onEnded {
                    viewModel.trackRunShared(
                        runSequence: dailyRunSequence,
                        state: dailyRunState
                    )
                }
            )
            .accessibilityIdentifier("dailyPuzzle.shareRunCTA")

            Button {
                viewModel.trackRunContinueTapped(
                    runSequence: dailyRunSequence,
                    state: dailyRunState
                )
                Task {
                    await handleNextPuzzleTapped()
                }
            } label: {
                Label(
                    NSLocalizedString("dailyPuzzleKeepPlaying", comment: "Continue Daily Run button"),
                    systemImage: "arrow.right.circle.fill"
                )
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoadingNextPuzzle)
            .accessibilityIdentifier("dailyPuzzle.nextPuzzleCTA")
        }
        .padding(18)
        .background(
            Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyPuzzle.runSummary")
    }

    private var reminderOptIn: some View {
        DailyPuzzleReminderOptInView(
            onShown: { viewModel.trackReminderOfferVisible() },
            onChoice: { viewModel.trackReminderChoice($0) },
            onOutcome: { viewModel.trackReminderOutcome($0) }
        )
    }

    private var dailyRunContinueBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isSolved ? "checkmark.seal.fill" : "flag.checkered")
                    .font(.title3)
                    .foregroundStyle(viewModel.isSolved ? .green : .orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        String(
                            format: NSLocalizedString("dailyPuzzleRunRoundFormat", comment: "Daily Run round progress"),
                            displayedDailyRunRound,
                            DailyPuzzleRunState.targetRounds
                        )
                    )
                        .font(.subheadline.weight(.bold))
                    Text(NSLocalizedString("dailyPuzzleRunContinuePrompt", comment: "Daily Run continue prompt"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            Button {
                Task {
                    await handleNextPuzzleTapped()
                }
            } label: {
                Label(
                    NSLocalizedString("dailyPuzzleKeepPlaying", comment: "Continue Daily Run button"),
                    systemImage: "arrow.right.circle.fill"
                )
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isLoadingNextPuzzle)
            .accessibilityIdentifier("dailyPuzzle.nextPuzzleCTA")

            if viewModel.offersDailyReminder {
                reminderOptIn
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dailyPuzzle.continueRunBar")
    }

    private func trackDailyRunStartedIfNeeded() {
        guard trackedDailyRunSequence != dailyRunSequence else { return }
        trackedDailyRunSequence = dailyRunSequence
        viewModel.trackRunStarted(runSequence: dailyRunSequence)
    }

    private func recordTerminalPuzzleIfNeeded() {
        guard puzzleFinished else { return }

        let didRecord = dailyRunState.record(
            puzzleID: viewModel.puzzle.puzzleID,
            solved: viewModel.isSolved,
            attempts: viewModel.attempts,
            hints: viewModel.unlockedHintCount,
            currentStreak: viewModel.currentStreak,
            points: viewModel.quizPoints
        )

        guard didRecord else { return }

        trackDailyRunStartedIfNeeded()

        if showsNextPuzzleControl,
           viewModel.puzzleIndex == 1,
           viewModel.isSolved {
            ReviewPromptCoordinator.shared.recordMilestone(.canonicalDailyPuzzleSolved)
        }

        guard dailyRunState.isComplete else { return }
        dailyRunState.setParticipationStreak(MovieQuizParticipationStore().recordCompletedRun())
        ReviewPromptCoordinator.shared.recordMilestone(.dailyRunCompleted)
        let weeklyGoalUpdate = weeklyGoalStore.recordCompletedRun()
        weeklyGoalProgress = weeklyGoalUpdate.progress
        viewModel.trackWeeklyGoalUpdated(weeklyGoalUpdate)
        viewModel.trackRunCompleted(
            runSequence: dailyRunSequence,
            state: dailyRunState
        )
    }

    @MainActor
    private func handleNextPuzzleTapped() async {
        guard !isLoadingNextPuzzle, let onRequestNextPuzzle else { return }
        isLoadingNextPuzzle = true
        do {
            try await onRequestNextPuzzle()
        } catch {
            if !Task.isCancelled { showNextPuzzleError = true }
        }
        isLoadingNextPuzzle = false
    }
}

private struct PuzzleArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var archiveVM = PuzzleArchiveViewModel()
    @State private var selectedPuzzle: DailyPuzzle?
    @State private var activeGameVM: DailyPuzzleViewModel?

    var body: some View {
        ScrollView {
            // Header stats
            VStack(spacing: 16) {
                HStack(spacing: 32) {
                    // Progress ring
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                                .frame(width: 64, height: 64)
                            Circle()
                                .trim(from: 0, to: archiveVM.puzzles.isEmpty ? 0 : CGFloat(archiveVM.solvedCount) / CGFloat(archiveVM.puzzles.count))
                                .stroke(SettingsStore.shared.appTheme.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(-90))
                            Text("\(archiveVM.solvedCount)/\(archiveVM.puzzles.count)")
                                .font(.caption.weight(.bold).monospacedDigit())
                        }
                        Text(NSLocalizedString("puzzleArchiveSolvedLabel", comment: "Solved label"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Star count
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                                .frame(width: 64, height: 64)
                            Circle()
                                .trim(from: 0, to: archiveVM.maxStars == 0 ? 0 : CGFloat(archiveVM.totalStars) / CGFloat(archiveVM.maxStars))
                                .stroke(.yellow, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(-90))
                            Text("\(archiveVM.totalStars)/\(archiveVM.maxStars)")
                                .font(.caption.weight(.bold).monospacedDigit())
                        }
                        Text(NSLocalizedString("puzzleArchiveStarsLabel", comment: "Stars label"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                Text(NSLocalizedString("puzzleArchiveSubtitle", comment: "Archive subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Puzzle list
            LazyVStack(spacing: 0) {
                ForEach(Array(archiveVM.puzzles.enumerated()), id: \.element.puzzleID) { index, puzzle in
                    let progress = archiveVM.progress(for: puzzle.puzzleID)
                    let isSolved = progress?.solved == true
                    let quizPoints = progress?.quizState.flatMap { $0.importedLegacyResult == true ? nil : $0.points }
                    let stars = isSolved ? (quizPoints ?? DailyPuzzle.starRating(for: progress?.attempts ?? 0)) : 0

                    Button {
                        selectedPuzzle = puzzle
                        activeGameVM = DailyPuzzleViewModel(puzzle: puzzle, recordsDailyStreak: false)
                        activeGameVM?.trackOpened(source: "archive_list")
                    } label: {
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .leading)

                            PuzzleArchiveEquationRowView(
                                puzzle: puzzle,
                                isSolved: isSolved
                            )

                            Spacer()

                            if isSolved {
                                HStack(spacing: 2) {
                                    ForEach(1...3, id: \.self) { star in
                                        Image(systemName: star <= stars ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundStyle(star <= stars ? .yellow : .secondary.opacity(0.3))
                                    }
                                }

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.body)
                            } else {
                                Image(systemName: "play.circle")
                                    .foregroundStyle(SettingsStore.shared.appTheme.color)
                                    .font(.body)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            index.isMultiple(of: 2)
                                ? Color(uiColor: .secondarySystemBackground).opacity(0.5)
                                : Color.clear
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle(NSLocalizedString("puzzleArchiveTitle", comment: "Archive title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(Text(verbatim: "Dismiss"))
                .accessibilityIdentifier("dailyPuzzle.archiveDismiss")
            }
        }
        .sheet(item: $selectedPuzzle, onDismiss: { archiveVM.refresh() }) { puzzle in
            if let activeGameVM {
                NavigationStack {
                    DailyPuzzleGameView(viewModel: activeGameVM, showsNextPuzzleControl: false, onRequestNextPuzzle: nil)
                }
                .appTheme()
            }
        }
    }
}

private struct PuzzleArchiveEquationRowView: View {
    let puzzle: DailyPuzzle
    let isSolved: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isSolved, UIImage(named: "MovieQuiz\(puzzle.tmdbID)") != nil {
                Image("MovieQuiz\(puzzle.tmdbID)").resizable().scaledToFill()
                    .frame(width: 72, height: 44).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: isSolved ? "film" : "square.grid.3x3.fill")
                    .frame(width: 72, height: 44).accessibilityHidden(true)
            }
            Text(isSolved ? (puzzle.title ?? "") : quizText("movieQuizArchiveRound", "Movie quiz") + " #" + puzzle.puzzleID.replacingOccurrences(of: "archive-", with: ""))
                .font(.subheadline.weight(.semibold))
        }
    }
}

#endif
