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
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let hostingController = UIHostingController(rootView: view)
        let size = device.config.size ?? CGSize(width: 440, height: 956)
        hostingController.view.frame = CGRect(origin: .zero, size: size)

        let window = UIWindow(frame: hostingController.view.frame)
        window.rootViewController = hostingController
        window.makeKeyAndVisible()

        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        // Wait for SDWebImage to load posters from network/cache
        let renderExpectation = expectation(description: "Render \(name)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            renderExpectation.fulfill()
        }
        waitForExpectations(timeout: 5)

        assertSnapshot(
            of: hostingController,
            as: .image(on: device.config, precision: 0.99),
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
            snapshotView(view, device: device, named: device.rawValue)
        }
    }

    // MARK: - Explore

    func testExploreScreen() {
        let view = ExploreScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.rawValue)
        }
    }

    // MARK: - Watchlist

    func testWatchlistScreen() {
        let view = WatchlistScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.rawValue)
        }
    }

    // MARK: - Search

    func testSearchScreen() {
        let view = NavigationStack {
            SearchView()
        }
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.rawValue)
        }
    }

    // MARK: - Detail

    func testDetailScreen() {
        let view = DetailScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.rawValue)
        }
    }

    // MARK: - Detail Cast & Recommendations

    func testDetailCastScreen() {
        let view = DetailCastScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.rawValue)
        }
    }

    // MARK: - Detail Trailers & Cast

    func testDetailTrailersScreen() {
        let view = DetailRecommendationsScreenshotView()
        for device in ScreenshotDevice.allCases {
            snapshotView(view, device: device, named: device.rawValue)
        }
    }
}
