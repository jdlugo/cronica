import XCTest
import SnapshotTesting
import SwiftUI
@testable import StreamingNow

/// Localized App Store screenshot generation using swift-snapshot-testing.
///
/// Generates screenshots for all non-English locales by reusing existing screenshot
/// wrapper views with bundle swizzling for UI chrome and locale-specific content JSON.
///
/// Run with `isRecording = true` to generate/update reference images.
/// Screenshots are saved to `__Snapshots__/LocalizedScreenshotTests/{locale}/`.
final class LocalizedScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ScreenshotSetup.configure()
        // Set to true to generate/update localized screenshots
        // isRecording = true
    }

    override func tearDown() {
        ScreenshotLocaleHelper.resetLanguage()
        ScreenshotSetup.tearDown()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Snapshot a view for every locale and every device, organized into locale subfolders.
    private func localizedSnapshot<V: View>(
        _ viewBuilder: @autoclosure @escaping () -> V,
        screen: String,
        devices: [ScreenshotDevice] = ScreenshotDevice.allCases
    ) {
        for locale in ScreenshotLocale.allCases {
            // Set bundle swizzle (NSLocalizedString) + content override (ItemContent.examples)
            ScreenshotLocaleHelper.setLanguage(locale.lprojName)

            // Build the view AFTER setting the locale so ItemContent.examples picks up localized content
            let baseView = viewBuilder()

            for device in devices {
                // Set SwiftUI locale environment (handles Text("key") auto-localization + RTL)
                let localizedView: AnyView
                if locale.isRTL {
                    localizedView = AnyView(
                        baseView
                            .environment(\.locale, Locale(identifier: locale.code))
                            .environment(\.layoutDirection, .rightToLeft)
                    )
                } else {
                    localizedView = AnyView(
                        baseView
                            .environment(\.locale, Locale(identifier: locale.code))
                    )
                }

                snapshotView(
                    localizedView,
                    config: device.config,
                    named: device.screenshotName(locale: locale.code),
                    testName: screen,
                    snapshotDirectory: snapshotDir(for: locale)
                )
            }
        }
    }

    /// Same for watch devices.
    private func localizedWatchSnapshot<V: View>(
        _ viewBuilder: @autoclosure @escaping () -> V,
        screen: String
    ) {
        for locale in ScreenshotLocale.allCases {
            ScreenshotLocaleHelper.setLanguage(locale.lprojName)

            let baseView = viewBuilder()

            for device in WatchScreenshotDevice.allCases {
                let localizedView: AnyView
                if locale.isRTL {
                    localizedView = AnyView(
                        baseView
                            .environment(\.locale, Locale(identifier: locale.code))
                            .environment(\.layoutDirection, .rightToLeft)
                    )
                } else {
                    localizedView = AnyView(
                        baseView
                            .environment(\.locale, Locale(identifier: locale.code))
                    )
                }

                snapshotView(
                    localizedView,
                    config: device.config,
                    named: device.screenshotName(locale: locale.code),
                    testName: screen,
                    snapshotDirectory: snapshotDir(for: locale)
                )
            }
        }
    }

    private func snapshotDir(for locale: ScreenshotLocale) -> String {
        URL(fileURLWithPath: "\(#filePath)", isDirectory: false)
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
            .appendingPathComponent("LocalizedScreenshotTests")
            .appendingPathComponent(locale.code)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            renderExpectation.fulfill()
        }
        waitForExpectations(timeout: 5)

        let failure = verifySnapshot(
            of: hostingController,
            as: .image(on: config, precision: precision, perceptualPrecision: 0.90),
            named: name,
            snapshotDirectory: snapshotDirectory,
            file: file,
            testName: testName,
            line: line
        )
        if let message = failure {
            XCTFail(message, file: file, line: line)
        }
    }

    // MARK: - iOS Screenshots

    func testHomeScreen() {
        localizedSnapshot(HomeScreenshotView(), screen: "HomeScreen")
    }

    func testExploreScreen() {
        localizedSnapshot(ExploreScreenshotView(), screen: "ExploreScreen")
    }

    func testWatchlistScreen() {
        localizedSnapshot(WatchlistScreenshotView(), screen: "WatchlistScreen")
    }

    func testSearchScreen() {
        localizedSnapshot(SearchScreenshotView(), screen: "SearchScreen")
    }

    func testDetailScreen() {
        localizedSnapshot(DetailScreenshotView(), screen: "DetailScreen")
    }

    func testDetailCastScreen() {
        localizedSnapshot(DetailCastScreenshotView(), screen: "DetailCastScreen")
    }

    func testDetailTrailersScreen() {
        localizedSnapshot(DetailRecommendationsScreenshotView(), screen: "DetailTrailersScreen")
    }

    // MARK: - Watch Screenshots

    func testWatchDetailScreen() {
        localizedWatchSnapshot(WatchDetailScreenshotView(), screen: "WatchDetailScreen")
    }

    func testWatchWatchlistScreen() {
        localizedWatchSnapshot(WatchWatchlistScreenshotView(), screen: "WatchWatchlistScreen")
    }

    func testWatchTrendingScreen() {
        localizedWatchSnapshot(WatchTrendingScreenshotView(), screen: "WatchTrendingScreen")
    }
}
