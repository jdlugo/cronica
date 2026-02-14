import XCTest
import SnapshotTesting
import SwiftUI
@testable import StreamingNow

/// Automated App Store screenshot generation using swift-snapshot-testing.
///
/// Run with `isRecording = true` to generate/update reference images.
/// Screenshots are saved to `__Snapshots__/ScreenshotTests/` alongside this file.
///
/// Images are loaded asynchronously by SDWebImage. The first run downloads from TMDB;
/// subsequent runs use SDWebImage's disk cache. A brief delay allows images to render.
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ScreenshotSetup.configure()
        // Set to true to generate/update screenshots
        // isRecording = true
    }

    override func tearDown() {
        ScreenshotSetup.tearDown()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Hosts a SwiftUI view in a real UIWindow, waits for async content (images),
    /// then takes the snapshot. This allows SDWebImage to load cached posters.
    private func snapshotView<V: View>(
        _ view: V,
        device: ScreenshotDevice,
        named name: String,
        precision: Float = 0.95,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        snapshotView(view, config: device.config, named: name, precision: precision, file: file, testName: testName, line: line)
    }

    /// Overload for watch devices — same UIWindow hosting approach.
    private func snapshotView<V: View>(
        _ view: V,
        device: WatchScreenshotDevice,
        named name: String,
        precision: Float = 0.95,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        snapshotView(view, config: device.config, named: name, precision: precision, file: file, testName: testName, line: line)
    }

    /// Core snapshot helper that accepts a raw ViewImageConfig.
    private func snapshotView<V: View>(
        _ view: V,
        config: ViewImageConfig,
        named name: String,
        precision: Float = 0.95,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
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

        assertSnapshot(
            of: hostingController,
            as: .image(on: config, precision: precision),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    // MARK: - Home

    func testHomeScreen() {
        let view = HomeScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Explore

    func testExploreScreen() {
        let view = ExploreScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Watchlist

    func testWatchlistScreen() {
        let view = WatchlistScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Search

    func testSearchScreen() {
        let view = SearchScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Detail

    func testDetailScreen() {
        let view = DetailScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Detail Cast & Recommendations

    func testDetailCastScreen() {
        let view = DetailCastScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Detail Trailers & Cast

    func testDetailTrailersScreen() {
        let view = DetailRecommendationsScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Watch Detail

    func testWatchDetailScreen() {
        let view = WatchDetailScreenshotView()
        for device in WatchScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Watch Watchlist

    func testWatchWatchlistScreen() {
        let view = WatchWatchlistScreenshotView()
        for device in WatchScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }

    // MARK: - Watch Trending

    func testWatchTrendingScreen() {
        let view = WatchTrendingScreenshotView()
        for device in WatchScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.screenshotName())
        }
    }
}
