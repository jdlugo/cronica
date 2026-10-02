import SwiftUI
#if os(iOS) && DEBUG
import SDWebImageSwiftUI
#endif

struct ContentView: View {
    var body: some View {
#if os(iOS)
#if DEBUG
        if let previewConfiguration = PreviewVideoLaunchConfiguration.fromProcessInfo() {
            PreviewVideoRootView(configuration: previewConfiguration)
        } else {
            TabBarView()
        }
#else
        TabBarView()
#endif
#elseif os(tvOS)
        TabBarView()
#elseif os(macOS)
        SideBarView()
#endif
    }
}

#Preview {
    ContentView()
}

#if os(iOS) && DEBUG
struct PreviewVideoLaunchConfiguration: Equatable {
    static let scenarioArgument = PreviewVideoRuntime.scenarioArgument
    static let sceneDurationArgument = PreviewVideoRuntime.sceneDurationArgument
    static let defaultSceneDurationSeconds = 2.3

    let scenarioID: String
    let sceneDurationSeconds: Double

    static func fromProcessInfo(_ processInfo: ProcessInfo = .processInfo) -> Self? {
        parse(arguments: processInfo.arguments)
    }

    static func parse(arguments: [String]) -> Self? {
        guard let rawScenarioID = PreviewVideoRuntime.scenarioID(arguments: arguments) else {
            return nil
        }

        let rawDuration = value(for: sceneDurationArgument, arguments: arguments)
        let parsedDuration = rawDuration.flatMap(Double.init)
        let sceneDuration = (parsedDuration ?? defaultSceneDurationSeconds) > 0
            ? (parsedDuration ?? defaultSceneDurationSeconds)
            : defaultSceneDurationSeconds

        return Self(
            scenarioID: rawScenarioID,
            sceneDurationSeconds: sceneDuration
        )
    }

    private static func value(for flag: String, arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let nextIndex = arguments.index(after: index)
        guard nextIndex < arguments.endIndex else { return nil }
        return arguments[nextIndex]
    }
}

private struct PreviewVideoRootView: View {
    let configuration: PreviewVideoLaunchConfiguration

    var body: some View {
        let scenes = PreviewVideoScenarioFactory.scenes(for: configuration.scenarioID)

        Group {
            if scenes.isEmpty {
                Color.black
                    .overlay {
                        Text("Unknown preview scenario")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
            } else {
                PreviewVideoScenarioPlayerView(
                    scenes: scenes,
                    dwellSeconds: configuration.sceneDurationSeconds
                )
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}

private enum PreviewVideoScenarioFactory {
    private static let allItems = ItemContent.examples
    private static let exploreItems = Array(allItems.dropFirst(10).prefix(15))
    private static let searchItems = Array(allItems.dropFirst(5).prefix(5)) + Array(allItems.dropFirst(18).prefix(7))
    private static let watchlistFavorites = Array(allItems.dropFirst(5).prefix(4))
    private static let watchlistGrid = Array(allItems.dropFirst(15).prefix(10))
    private static var detailItem: ItemContent { allItems[6] }
    private static var detailCastItem: ItemContent { allItems[8] }
    private static var detailTrailersItem: ItemContent { allItems[1] }

    static func scenes(for scenarioID: String) -> [AnyView] {
        switch scenarioID {
        case "home-discovery":
            return [
                AnyView(PreviewHomeSceneView()),
                AnyView(PreviewExploreSceneView(items: exploreItems)),
                AnyView(PreviewDetailSceneView(item: detailItem))
            ]
        case "watchlist-search":
            return [
                AnyView(
                    PreviewWatchlistSceneView(
                        favorites: watchlistFavorites,
                        items: watchlistGrid
                    )
                ),
                AnyView(PreviewSearchSceneView(items: searchItems)),
                AnyView(PreviewDetailRecommendationsSceneView(item: detailTrailersItem))
            ]
        case "detail-deep-dive":
            return [
                AnyView(
                    PreviewDetailCastSceneView(
                        item: detailCastItem,
                        recommendations: Array(allItems.dropFirst(20).prefix(8)),
                        similar: Array(allItems.dropFirst(12).prefix(8))
                    )
                ),
                AnyView(PreviewDetailRecommendationsSceneView(item: detailTrailersItem)),
                AnyView(PreviewDetailSceneView(item: detailItem))
            ]
        default:
            return []
        }
    }
}

private struct PreviewVideoScenarioPlayerView: View {
    let scenes: [AnyView]
    let dwellSeconds: Double
    @State private var currentIndex = 0
    @State private var tapCue = PreviewTapCue(normalizedPoint: CGPoint(x: 0.82, y: 0.24))
    @State private var tapPulseToken = 0

    var body: some View {
        ZStack {
            ForEach(Array(scenes.enumerated()), id: \.offset) { index, scene in
                scene
                    .opacity(currentIndex == index ? 1 : 0)
                    .scaleEffect(currentIndex == index ? 1 : 1.015)
                    .animation(.easeInOut(duration: 0.65), value: currentIndex)
                    .ignoresSafeArea()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .overlay {
            GeometryReader { proxy in
                PreviewTapIndicator(pulseToken: tapPulseToken)
                    .position(
                        x: proxy.size.width * tapCue.normalizedPoint.x,
                        y: proxy.size.height * tapCue.normalizedPoint.y
                    )
                    .zIndex(10)
            }
            .allowsHitTesting(false)
        }
        .task {
            guard scenes.count > 1 else { return }
            tapCue = previewTapCue(for: currentIndex, sceneCount: scenes.count)
            tapPulseToken += 1

            while !Task.isCancelled {
                let safeDwellSeconds = max(1.2, dwellSeconds)
                let preTapLeadSeconds = min(0.85, safeDwellSeconds * 0.36)
                try? await Task.sleep(
                    nanoseconds: UInt64((safeDwellSeconds - preTapLeadSeconds) * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }

                withAnimation(.easeOut(duration: 0.2)) {
                    tapPulseToken += 1
                }

                try? await Task.sleep(nanoseconds: UInt64(preTapLeadSeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }

                let nextIndex = (currentIndex + 1) % scenes.count
                withAnimation(.easeInOut(duration: 0.65)) {
                    currentIndex = nextIndex
                }
                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                    tapCue = previewTapCue(for: nextIndex, sceneCount: scenes.count)
                    tapPulseToken += 1
                }
            }
        }
    }

    private func previewTapCue(for index: Int, sceneCount: Int) -> PreviewTapCue {
        let cues = [
            PreviewTapCue(normalizedPoint: CGPoint(x: 0.82, y: 0.24)),
            PreviewTapCue(normalizedPoint: CGPoint(x: 0.78, y: 0.74)),
            PreviewTapCue(normalizedPoint: CGPoint(x: 0.52, y: 0.38)),
            PreviewTapCue(normalizedPoint: CGPoint(x: 0.24, y: 0.48))
        ]
        let normalizedIndex = index % max(1, min(cues.count, sceneCount))
        return cues[normalizedIndex]
    }
}

private struct PreviewTapCue {
    let normalizedPoint: CGPoint
}

private struct PreviewTapIndicator: View {
    let pulseToken: Int
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.36))
                .frame(width: 86, height: 86)
                .overlay {
                    Circle()
                        .stroke(Color.yellow.opacity(0.92), lineWidth: 3)
                        .padding(4)
                }
                .scaleEffect(animate ? 1.06 : 0.9)

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(Color.yellow)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 3)
                .scaleEffect(animate ? 1.08 : 0.9)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .onChange(of: pulseToken) {
            animate = false
            withAnimation(.easeOut(duration: 0.35)) {
                animate = true
            }
        }
    }
}

private struct PreviewHomeSceneView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?

    private let trending = Array(ItemContent.examples.prefix(10))
    private let nowPlaying = Array(ItemContent.examples.dropFirst(7).prefix(8))
    private let upcoming = Array(ItemContent.examples.dropFirst(15).prefix(8))
    private let topRated = Array(ItemContent.examples.dropFirst(22).prefix(8))
    private let popularTV = Array(ItemContent.examples.dropFirst(4).prefix(8))
    private let recommendations = Array(ItemContent.examples.dropFirst(10).prefix(5))

    var body: some View {
        NavigationStack {
            ScrollView {
                HorizontalItemContentListView(
                    items: trending,
                    title: NSLocalizedString("Trending", comment: ""),
                    subtitle: NSLocalizedString("Today", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )

                HorizontalItemContentListView(
                    items: nowPlaying,
                    title: NSLocalizedString("Now Playing", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType,
                    endpoint: .nowPlaying
                )

                HorizontalItemContentListView(
                    items: upcoming,
                    title: NSLocalizedString("Upcoming", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType,
                    endpoint: .upcoming
                )

                HorizontalItemContentListView(
                    items: topRated,
                    title: NSLocalizedString("Top Rated", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )

                HorizontalItemContentListView(
                    items: popularTV,
                    title: NSLocalizedString("Popular", comment: ""),
                    subtitle: NSLocalizedString("TV Shows", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )

                HorizontalItemContentListView(
                    items: recommendations,
                    title: NSLocalizedString("recommendationsTitle", comment: ""),
                    subtitle: NSLocalizedString("recommendationsSubtitle", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )
            }
            .navigationTitle("Home")
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PreviewExploreSceneView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?
    private let items: [ItemContent]

    init(items: [ItemContent] = ItemContent.examples) {
        self.items = items
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 160))]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        ItemContentPosterView(
                            item: item,
                            showPopup: $showPopup,
                            popupType: $popupType
                        )
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("Explore", comment: ""))
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PreviewWatchlistSceneView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?
    private let favorites: [ItemContent]
    private let items: [ItemContent]

    init(
        favorites: [ItemContent] = Array(ItemContent.examples.prefix(6)),
        items: [ItemContent] = Array(ItemContent.examples.dropFirst(6))
    ) {
        self.favorites = favorites
        self.items = items
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 160))]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    HorizontalItemContentListView(
                        items: favorites,
                        title: NSLocalizedString("Favorites", comment: ""),
                        subtitle: "",
                        showPopup: $showPopup,
                        popupType: $popupType
                    )

                    Section {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                                ItemContentPosterView(
                                    item: item,
                                    showPopup: $showPopup,
                                    popupType: $popupType
                                )
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    } header: {
                        HStack {
                            Text("To Watch")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(items.count, format: .number)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PreviewSearchSceneView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?
    private let items: [ItemContent]

    init(items: [ItemContent] = ItemContent.examples) {
        self.items = items
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 160))]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text("Action")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal)

                    Picker("Scope", selection: .constant(0)) {
                        Text("Movies").tag(0)
                        Text("TV Shows").tag(1)
                        Text("People").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        ItemContentPosterView(
                            item: item,
                            showPopup: $showPopup,
                            popupType: $popupType
                        )
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PreviewDetailSceneView: View {
    private let item: ItemContent
    private let recommendations = Array(ItemContent.examples.dropFirst(14).prefix(8))

    init(item: ItemContent = .example) {
        self.item = item
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WebImage(url: item.posterImageMedium) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle().fill(.gray.gradient)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 210, height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.38), radius: 16, y: 12)
                    .padding(.top, 8)

                    Text(item.itemTitle)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(item.itemQuickInfo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        PreviewActionPill(label: "Watched", icon: "rectangle.badge.checkmark")
                        PreviewActionPill(label: "Add", icon: "plus.circle.fill", isAccent: true)
                        PreviewActionPill(label: "Lists", icon: "rectangle.on.rectangle.angled")
                    }

                    PreviewOverviewCardView(
                        overview: item.itemOverview,
                        title: item.itemTitle
                    )
                    .padding(.horizontal)

                    PreviewCastStrip(people: Array((item.credits?.cast ?? []).prefix(8)))
                    PreviewPosterStrip(
                        title: NSLocalizedString("Recommendations", comment: ""),
                        items: recommendations
                    )
                }
                .padding(.bottom, 20)
            }
            .background {
                ZStack {
                    WebImage(url: item.cardImageLarge) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle().fill(.background)
                    }
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                    Color.black.opacity(0.6).ignoresSafeArea()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct PreviewDetailRecommendationsSceneView: View {
    @State private var viewModel: ItemContentViewModel
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?
    private let item: ItemContent
    private let recommendations = Array(ItemContent.examples.dropFirst(10).prefix(8))

    init(item: ItemContent = .example) {
        self.item = item
        _viewModel = State(wrappedValue: ItemContentViewModel.preview(with: item, includeMockTrailers: true))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                TrailerListView(trailers: viewModel.trailers)
                CastListView(credits: item.credits?.cast ?? [])
                PreviewOverviewCardView(
                    overview: item.itemOverview,
                    title: item.itemTitle
                )
                .padding(.horizontal)

                HorizontalItemContentListView(
                    items: recommendations,
                    title: NSLocalizedString("Recommendations", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )
            }
            .navigationTitle(item.itemTitle)
            .toolbar(.hidden, for: .navigationBar)
            .background {
                ZStack {
                    WebImage(url: item.cardImageLarge) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle().fill(.background)
                    }
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                    Color.black.opacity(0.6).ignoresSafeArea()
                }
            }
        }
    }
}

private struct PreviewDetailCastSceneView: View {
    @State private var showPopup = false
    @State private var popupType: ActionPopupItems?
    private let item: ItemContent
    private let recommendations: [ItemContent]
    private let similar: [ItemContent]

    init(
        item: ItemContent = .example,
        recommendations: [ItemContent] = Array(ItemContent.examples.dropFirst(10).prefix(8)),
        similar: [ItemContent] = Array(ItemContent.examples.dropFirst(18).prefix(8))
    ) {
        self.item = item
        self.recommendations = recommendations
        self.similar = similar
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                PreviewOverviewCardView(
                    overview: item.itemOverview,
                    title: item.itemTitle
                )
                .padding(.horizontal)

                CastListView(credits: item.credits?.cast ?? [])

                HorizontalItemContentListView(
                    items: recommendations,
                    title: NSLocalizedString("Recommendations", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )

                HorizontalItemContentListView(
                    items: similar,
                    title: NSLocalizedString("Similar", comment: ""),
                    subtitle: NSLocalizedString("Movies", comment: ""),
                    showPopup: $showPopup,
                    popupType: $popupType
                )
            }
            .navigationTitle(item.itemTitle)
            .toolbar(.hidden, for: .navigationBar)
            .background {
                ZStack {
                    WebImage(url: item.cardImageLarge) { image in
                        image.resizable()
                    } placeholder: {
                        Rectangle().fill(.background)
                    }
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()

                    Color.black.opacity(0.6).ignoresSafeArea()
                }
            }
        }
    }
}

private struct PreviewOverviewCardView: View {
    let overview: String?
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.headline)

            Text(overview ?? "")
                .font(.callout)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("Show more")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct PreviewCastStrip: View {
    let people: [Person]

    var body: some View {
        if !people.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cast & Crew")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(people, id: \.personListID) { person in
                            VStack(alignment: .leading, spacing: 6) {
                                WebImage(url: person.personImage) { image in
                                    image.resizable()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.1))
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 92, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text(person.name)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .frame(width: 92)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct PreviewPosterStrip: View {
    let title: String
    let items: [ItemContent]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items.prefix(8)) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                WebImage(url: item.posterImageMedium) { image in
                                    image.resizable()
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white.opacity(0.1))
                                }
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 108, height: 152)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text(item.itemTitle)
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .frame(width: 108)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct PreviewActionPill: View {
    let label: String
    let icon: String
    var isAccent = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
                .font(.caption)
        }
        .padding(.vertical, 6)
        .frame(width: 78)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isAccent ? Color.red : Color.white.opacity(0.15))
        )
        .foregroundStyle(.white)
    }
}
#endif
