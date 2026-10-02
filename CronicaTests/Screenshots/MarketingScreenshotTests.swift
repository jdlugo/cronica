import XCTest
import SnapshotTesting
import SwiftUI
@testable import StreamingNow

/// Marketing App Store screenshot generation — wraps existing screenshot views in a
/// gradient background with localized headline text.
///
/// Generates 420 PNGs: 7 iOS screens × 4 devices × 15 locales (en-US + 14 localized).
/// Watch screenshots are excluded — marketing text would be illegible at watch sizes.
///
/// Each screen uses a distinct content slice from ItemContent.examples to ensure
/// no poster repetition across screenshots.
///
/// Set `RECORD_MARKETING_SCREENSHOTS=1` in the local run configuration to update references.
/// Screenshots are saved to `__Snapshots__/MarketingScreenshotTests/{locale}/`.
final class MarketingScreenshotTests: XCTestCase {

    // MARK: - Content Slices
    // 30 items total (0-29). Items 0-9 have full credits/cast data.
    // Each screen gets a distinct slice so hero posters never repeat across screenshots.

    /// Items 0-9: Zootopia 2, Badlands, Crime 101, Housemaid, Wuthering Heights,
    /// Fallout, House of Dragon, The Pitt, Bridgerton, Spartacus
    private static let allItems = ItemContent.examples

    // Home: uses items 0-9 internally (trending/now-playing sections) — default behavior
    // Explore: items 10-24 (GoT, Shōgun, Baby Reindeer, X-Men, 3 Body Problem, RoP, Andor, ...)
    private static let exploreItems = Array(allItems.dropFirst(10).prefix(15))
    // Search: items 5-9 + 18-24 (Fallout, HotD, The Pitt, Bridgerton, Spartacus, Queen Charlotte, ...)
    private static let searchItems = Array(allItems.dropFirst(5).prefix(5)) + Array(allItems.dropFirst(18).prefix(7))
    // Watchlist favorites: items 5-8 (Fallout, House of Dragon, The Pitt, Bridgerton)
    private static let watchlistFavorites = Array(allItems.dropFirst(5).prefix(4))
    // Watchlist grid: items 15-24 (RoP, Andor, Sandman, Queen Charlotte, Emily in Paris, ...)
    private static let watchlistGrid = Array(allItems.dropFirst(15).prefix(10))
    // Detail: item 6 (House of the Dragon) — dramatic, prestige content
    private static var detailItem: ItemContent { allItems[6] }
    // DetailCast: item 8 (Bridgerton) — popular, recognizable cast
    private static var detailCastItem: ItemContent { allItems[8] }
    // DetailTrailers: item 1 (Predator: Badlands) — dark, cinematic
    private static var detailTrailersItem: ItemContent { allItems[1] }

    override func setUp() {
        super.setUp()
        ScreenshotSetup.configure()
    }

    override func tearDown() {
        ScreenshotLocaleHelper.resetLanguage()
        ScreenshotSetup.tearDown()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Snapshot a view wrapped in a marketing shell for en-US + all localized locales.
    private func marketingSnapshot<V: View>(
        _ viewBuilder: @autoclosure @escaping () -> V,
        screen: String,
        devices: [ScreenshotDevice] = ScreenshotDevice.allCases
    ) {
        // All locales: en-US first, then all ScreenshotLocale cases
        var allLocales: [(code: String, lprojName: String?, isRTL: Bool)] =
            [("en-US", nil, false)]
            + ScreenshotLocale.allCases.map { ($0.code, $0.lprojName, $0.isRTL) }
        if let requestedLocales = environmentValue("MARKETING_SCREENSHOT_LOCALES") {
            let requested = Set(requestedLocales.split(separator: ",").map(String.init))
            allLocales = allLocales.filter { requested.contains($0.code) }
            XCTAssertEqual(
                Set(allLocales.map(\.code)),
                requested,
                "MARKETING_SCREENSHOT_LOCALES contains unknown locale codes"
            )
        }

        var selectedDevices = devices
        if let requestedDevices = environmentValue("MARKETING_SCREENSHOT_DEVICES") {
            let requested = Set(requestedDevices.split(separator: ",").map(String.init))
            selectedDevices = devices.filter { requested.contains($0.rawValue) }
            XCTAssertEqual(
                Set(selectedDevices.map(\.rawValue)),
                requested,
                "MARKETING_SCREENSHOT_DEVICES contains unknown device values"
            )
        }

        guard !allLocales.isEmpty, !selectedDevices.isEmpty else { return }

        for locale in allLocales {
            // Set bundle swizzle for non-English locales
            if let lproj = locale.lprojName {
                ScreenshotLocaleHelper.setLanguage(lproj)
            } else {
                ScreenshotLocaleHelper.resetLanguage()
            }

            // Build the view AFTER setting the locale so ItemContent.examples picks up localized content
            let headline = MarketingHeadlines.headline(for: screen, locale: locale.code)
            let wrappedView = MarketingScreenshotView(headline: headline) {
                viewBuilder()
            }

            for device in selectedDevices {
                let localizedView: AnyView
                if locale.isRTL {
                    localizedView = AnyView(
                        wrappedView
                            .environment(\.locale, Locale(identifier: locale.code))
                            .environment(\.layoutDirection, .rightToLeft)
                    )
                } else {
                    localizedView = AnyView(
                        wrappedView
                            .environment(\.locale, Locale(identifier: locale.code))
                    )
                }

                snapshotView(
                    localizedView,
                    config: device.config,
                    named: device.screenshotName(locale: locale.code),
                    testName: screen,
                    snapshotDirectory: snapshotDir(for: locale.code)
                )
            }
        }
    }

    private func snapshotDir(for locale: String) -> String {
        URL(fileURLWithPath: "\(#filePath)", isDirectory: false)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent("MarketingScreenshotTests")
            .appendingPathComponent(locale)
            .path
    }

    /// Core snapshot helper — hosts a SwiftUI view in a UIWindow, waits for async image
    /// loading, then asserts the snapshot.
    private func snapshotView<V: View>(
        _ view: V,
        config: ViewImageConfig,
        named name: String,
        precision: Float = 0.85,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        snapshotDirectory: String? = nil
    ) {
        let hostingController = UIHostingController(rootView: view)
        let size = config.size ?? CGSize(width: 440, height: 956)
        hostingController.view.frame = CGRect(origin: .zero, size: size)

        let window = UIWindow(frame: hostingController.view.frame)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let renderExpectation = expectation(description: "Render \(name)")
        let renderDelay = TimeInterval(environmentValue("MARKETING_SCREENSHOT_RENDER_DELAY") ?? "") ?? 5
        DispatchQueue.main.asyncAfter(deadline: .now() + renderDelay) {
            renderExpectation.fulfill()
        }
        waitForExpectations(timeout: 8)

        let failure = verifySnapshot(
            of: hostingController,
            as: .image(on: config, precision: precision, perceptualPrecision: 0.90),
            named: name,
            record: environmentValue("RECORD_MARKETING_SCREENSHOTS") == "1" ? .all : .never,
            snapshotDirectory: snapshotDirectory,
            file: file,
            testName: testName,
            line: line
        )
        if let message = failure {
            XCTFail(message, file: file, line: line)
        }
    }

    private func environmentValue(_ key: String) -> String? {
        let sourceFile = URL(fileURLWithPath: "\(#filePath)")
        let configurationURL = sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(".build/marketing-screenshot-run.json")
        if let data = try? Data(contentsOf: configurationURL),
           let values = try? JSONDecoder().decode([String: String].self, from: data),
           let value = values[key] {
            return value
        }

        let environment = ProcessInfo.processInfo.environment
        return environment[key] ?? environment["TEST_RUNNER_\(key)"]
    }

    // MARK: - iOS Marketing Screenshots
    // Ordered by conversion funnel: Hook → Value → Collect → Search → Learn → Connect → Decide

    func testAcquisitionScreensLeadWithPuzzleProvidersAndWatchlist() {
        XCTAssertEqual(
            MarketingHeadlines.acquisitionScreenOrder,
            ["HomeScreen", "DetailScreen", "WatchlistScreen"]
        )
    }

    func testTargetMarketHeadlinesTellPlayFindSaveStory() {
        let expected = [
            "en-US": [
                "**A New Movie** to Guess Every Day",
                "**Solved It?** See Where to Stream",
                "**Save It Now.** Watch It Later."
            ],
            "fr": [
                "**Un nouveau film** à deviner chaque jour",
                "**Trouvé ?** Voyez où le regarder",
                "**Gardez-le.** Regardez-le plus tard."
            ],
            "es": [
                "**Una peli nueva** para adivinar cada día",
                "**¿La adivinaste?** Mira dónde verla",
                "**Guárdala hoy.** Mírala después."
            ],
            "es-MX": [
                "**Una peli nueva** para adivinar cada día",
                "**¿La adivinaste?** Mira dónde verla",
                "**Guárdala hoy.** Vela después."
            ],
            "pt-BR": [
                "**Um filme novo** para adivinhar todo dia",
                "**Acertou?** Veja onde assistir",
                "**Salve agora.** Assista depois."
            ]
        ]

        for (locale, headlines) in expected {
            let actual = MarketingHeadlines.acquisitionScreenOrder.map {
                MarketingHeadlines.headline(for: $0, locale: locale)
            }
            XCTAssertEqual(actual, headlines, "Unexpected acquisition story for \(locale)")
        }
    }

    func testHomeScreen() {
        marketingSnapshot(HomeScreenshotView(), screen: "HomeScreen")
    }

    func testDetailScreen() {
        marketingSnapshot(DetailScreenshotView(item: Self.detailItem), screen: "DetailScreen")
    }

    func testWatchlistScreen() {
        marketingSnapshot(
            WatchlistScreenshotView(
                favorites: Self.watchlistFavorites,
                items: Self.watchlistGrid
            ),
            screen: "WatchlistScreen"
        )
    }

    func testExploreScreen() {
        marketingSnapshot(ExploreScreenshotView(items: Self.exploreItems), screen: "ExploreScreen")
    }

    func testSearchScreen() {
        marketingSnapshot(SearchScreenshotView(items: Self.searchItems), screen: "SearchScreen")
    }

    func testDetailTrailersScreen() {
        marketingSnapshot(
            DetailRecommendationsScreenshotView(item: Self.detailTrailersItem),
            screen: "DetailTrailersScreen"
        )
    }

    func testDetailCastScreen() {
        marketingSnapshot(
            DetailCastScreenshotView(
                item: Self.detailCastItem,
                recommendations: Array(Self.allItems.dropFirst(20).prefix(8)),
                similar: Array(Self.allItems.dropFirst(12).prefix(8))
            ),
            screen: "DetailCastScreen"
        )
    }
}

final class PreviewVideoManifestTests: XCTestCase {
    func testPreviewVideoManifestExistsAndHasScenarios() throws {
        let manifest = try PreviewVideoManifestLoader.load()
        XCTAssertFalse(manifest.isEmpty)
    }

    func testPreviewVideoManifestHasUniqueIDsAndValidFields() throws {
        let manifest = try PreviewVideoManifestLoader.load()

        let ids = manifest.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Scenario ids must be unique")

        for scenario in manifest {
            XCTAssertFalse(scenario.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(scenario.xcodeTest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(scenario.outputFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertGreaterThan(scenario.durationSeconds, 1)
        }
    }
}

final class PreviewVideoLaunchConfigurationTests: XCTestCase {
    func testParseReturnsNilWhenScenarioFlagMissing() {
        let configuration = PreviewVideoLaunchConfiguration.parse(arguments: ["StreamingNow"])
        XCTAssertNil(configuration)
    }

    func testParseReadsScenarioAndDefaultSceneDuration() {
        let configuration = PreviewVideoLaunchConfiguration.parse(arguments: [
            "StreamingNow",
            PreviewVideoLaunchConfiguration.scenarioArgument,
            "home-discovery"
        ])

        XCTAssertEqual(configuration?.scenarioID, "home-discovery")
        XCTAssertEqual(configuration?.sceneDurationSeconds, PreviewVideoLaunchConfiguration.defaultSceneDurationSeconds)
    }

    func testParseReadsCustomSceneDuration() {
        let configuration = PreviewVideoLaunchConfiguration.parse(arguments: [
            "StreamingNow",
            PreviewVideoLaunchConfiguration.scenarioArgument,
            "watchlist-search",
            PreviewVideoLaunchConfiguration.sceneDurationArgument,
            "3.1"
        ])

        XCTAssertEqual(configuration?.scenarioID, "watchlist-search")
        XCTAssertEqual(configuration?.sceneDurationSeconds, 3.1)
    }

    func testParseFallsBackForInvalidSceneDuration() {
        let configuration = PreviewVideoLaunchConfiguration.parse(arguments: [
            "StreamingNow",
            PreviewVideoLaunchConfiguration.scenarioArgument,
            "detail-deep-dive",
            PreviewVideoLaunchConfiguration.sceneDurationArgument,
            "invalid"
        ])

        XCTAssertEqual(configuration?.sceneDurationSeconds, PreviewVideoLaunchConfiguration.defaultSceneDurationSeconds)
    }
}

final class PreviewVideoRuntimeTests: XCTestCase {
    func testIsPreviewVideoModeTrueWhenScenarioFlagPresent() {
        let enabled = PreviewVideoRuntime.isPreviewVideoMode(arguments: [
            "StreamingNow",
            PreviewVideoRuntime.scenarioArgument,
            "home-discovery"
        ])

        XCTAssertTrue(enabled)
    }

    func testIsPreviewVideoModeFalseWhenScenarioFlagMissing() {
        let enabled = PreviewVideoRuntime.isPreviewVideoMode(arguments: [
            "StreamingNow",
            "--some-other-flag",
            "value"
        ])

        XCTAssertFalse(enabled)
    }

    func testShouldDisableMonetizationWhenScenarioFlagPresent() {
        let shouldDisable = PreviewVideoRuntime.shouldDisableMonetization(arguments: [
            "StreamingNow",
            PreviewVideoRuntime.scenarioArgument,
            "home-discovery"
        ])

        XCTAssertTrue(shouldDisable)
    }

    func testShouldDisableMonetizationWhenDisableFlagPresent() {
        let shouldDisable = PreviewVideoRuntime.shouldDisableMonetization(arguments: [
            "StreamingNow",
            PreviewVideoRuntime.disableMonetizationArgument
        ])

        XCTAssertTrue(shouldDisable)
    }

    func testShouldDisableMonetizationFalseWithoutRelevantFlags() {
        let shouldDisable = PreviewVideoRuntime.shouldDisableMonetization(arguments: [
            "StreamingNow",
            "--another-flag",
            "value"
        ])

        XCTAssertFalse(shouldDisable)
    }
}

final class PreviewVideoTests: XCTestCase {

    private static let allItems = ItemContent.examples
    private static let exploreItems = Array(allItems.dropFirst(10).prefix(15))
    private static let searchItems = Array(allItems.dropFirst(5).prefix(5)) + Array(allItems.dropFirst(18).prefix(7))
    private static let watchlistFavorites = Array(allItems.dropFirst(5).prefix(4))
    private static let watchlistGrid = Array(allItems.dropFirst(15).prefix(10))
    private static var detailItem: ItemContent { allItems[6] }
    private static var detailCastItem: ItemContent { allItems[8] }
    private static var detailTrailersItem: ItemContent { allItems[1] }

    override func setUp() {
        super.setUp()
        ScreenshotSetup.configure()
        ScreenshotLocaleHelper.resetLanguage()
    }

    override func tearDown() {
        ScreenshotLocaleHelper.resetLanguage()
        ScreenshotSetup.tearDown()
        super.tearDown()
    }

    func testHomeDiscoveryPreviewVideo() throws {
        try runScenario(withID: "home-discovery")
    }

    func testWatchlistSearchPreviewVideo() throws {
        try runScenario(withID: "watchlist-search")
    }

    func testDetailDeepDivePreviewVideo() throws {
        try runScenario(withID: "detail-deep-dive")
    }

    func testScenarioWindowUsesActiveWindowSceneWhenAvailable() throws {
        guard !UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).isEmpty else {
            throw XCTSkip("No UIWindowScene available in this test environment.")
        }

        let window = makeScenarioWindow(frame: CGRect(origin: .zero, size: CGSize(width: 440, height: 956)))
        XCTAssertNotNil(window.windowScene, "Preview scenario window must attach to a UIWindowScene to be visible.")
    }

    private func runScenario(withID id: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let scenario = try PreviewVideoManifestLoader.scenario(withID: id)
        let scenes = Self.scenes(for: id)
        XCTAssertFalse(scenes.isEmpty, "No scenes configured for scenario '\(id)'", file: file, line: line)

        let scenarioView = PreviewVideoScenarioPlayerView(
            scenes: scenes,
            dwellSeconds: scenario.sceneDurationSeconds ?? 2.3
        )
        let hostingController = UIHostingController(rootView: scenarioView)
        let frame = CGRect(origin: .zero, size: CGSize(width: 440, height: 956))
        hostingController.view.frame = frame

        let window = makeScenarioWindow(frame: frame)
        window.rootViewController = hostingController
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let expectation = expectation(description: "Play scenario \(id)")
        DispatchQueue.main.asyncAfter(deadline: .now() + scenario.durationSeconds) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: scenario.durationSeconds + 5)
    }

    private func makeScenarioWindow(frame: CGRect) -> UIWindow {
        if let activeScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            return UIWindow(windowScene: activeScene)
        }

        if let anyScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            return UIWindow(windowScene: anyScene)
        }

        return UIWindow(frame: frame)
    }

    private static func scenes(for scenarioID: String) -> [AnyView] {
        switch scenarioID {
        case "home-discovery":
            return [
                AnyView(HomeScreenshotView()),
                AnyView(ExploreScreenshotView(items: exploreItems)),
                AnyView(DetailScreenshotView(item: detailItem))
            ]
        case "watchlist-search":
            return [
                AnyView(
                    WatchlistScreenshotView(
                        favorites: watchlistFavorites,
                        items: watchlistGrid
                    )
                ),
                AnyView(SearchScreenshotView(items: searchItems)),
                AnyView(DetailRecommendationsScreenshotView(item: detailTrailersItem))
            ]
        case "detail-deep-dive":
            return [
                AnyView(
                    DetailCastScreenshotView(
                        item: detailCastItem,
                        recommendations: Array(allItems.dropFirst(20).prefix(8)),
                        similar: Array(allItems.dropFirst(12).prefix(8))
                    )
                ),
                AnyView(DetailRecommendationsScreenshotView(item: detailTrailersItem)),
                AnyView(DetailScreenshotView(item: detailItem))
            ]
        default:
            return []
        }
    }
}

private struct PreviewVideoManifestEntry: Decodable {
    let id: String
    let xcodeTest: String
    let outputFile: String
    let durationSeconds: Double
    let trimStartSeconds: Double?
    let sceneDurationSeconds: Double?
}

private enum PreviewVideoManifestLoader {
    static func load(file: StaticString = #filePath) throws -> [PreviewVideoManifestEntry] {
        let manifestURL = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .appendingPathComponent("preview_video_scenarios.json")

        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            XCTFail("Expected preview video manifest at \(manifestURL.path)")
            return []
        }

        let data = try Data(contentsOf: manifestURL)
        return try JSONDecoder().decode([PreviewVideoManifestEntry].self, from: data)
    }

    static func scenario(withID id: String, file: StaticString = #filePath) throws -> PreviewVideoManifestEntry {
        let manifest = try load(file: file)
        guard let scenario = manifest.first(where: { $0.id == id }) else {
            throw NSError(
                domain: "PreviewVideoManifestLoader",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No scenario with id '\(id)' in preview video manifest."]
            )
        }
        return scenario
    }
}

private struct PreviewVideoScenarioPlayerView: View {
    let scenes: [AnyView]
    let dwellSeconds: Double
    @State private var currentIndex = 0

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
        .task {
            guard scenes.count > 1 else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(dwellSeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.65)) {
                    currentIndex = (currentIndex + 1) % scenes.count
                }
            }
        }
    }
}
