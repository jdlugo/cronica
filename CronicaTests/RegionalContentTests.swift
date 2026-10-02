import XCTest
@testable import StreamingNow

final class RegionalContentTests: XCTestCase {
    func testNewTargetMarketInstallUsesAndPersistsSupportedLocaleRegion() {
        for (code, expected) in [("FR", AppContentRegion.fr),
                                 ("MX", AppContentRegion.mx),
                                 ("BR", AppContentRegion.br)] {
            let resolution = WatchRegionPreferenceResolver.resolve(
                storedPreference: nil,
                deviceRegionCode: code
            )

            XCTAssertEqual(resolution.region, expected)
            XCTAssertEqual(resolution.source, .localeDefault)
            XCTAssertTrue(resolution.shouldPersist)
        }
    }

    func testExistingExplicitUSPreferenceIsPreserved() {
        let resolution = WatchRegionPreferenceResolver.resolve(
            storedPreference: AppContentRegion.us.rawValue,
            deviceRegionCode: "FR"
        )

        XCTAssertEqual(resolution.region, .us)
        XCTAssertEqual(resolution.source, .existingPreference)
        XCTAssertFalse(resolution.shouldPersist)
    }

    func testUnsupportedLocaleFallsBackWithoutPersistingPreference() {
        let resolution = WatchRegionPreferenceResolver.resolve(
            storedPreference: nil,
            deviceRegionCode: "AQ"
        )

        XCTAssertEqual(resolution.region, .us)
        XCTAssertEqual(resolution.source, .unsupportedLocaleFallback)
        XCTAssertFalse(resolution.shouldPersist)
    }

    func testReleaseRegionPrefersUserThenProductionThenUS() {
        XCTAssertEqual(
            DatesManager.preferredReleaseRegion(
                availableRegions: ["US", "GB", "FR"],
                userRegion: "FR",
                productionRegion: "GB"
            ),
            "FR"
        )
        XCTAssertEqual(
            DatesManager.preferredReleaseRegion(
                availableRegions: ["US", "GB"],
                userRegion: "FR",
                productionRegion: "GB"
            ),
            "GB"
        )
        XCTAssertEqual(
            DatesManager.preferredReleaseRegion(
                availableRegions: ["US"],
                userRegion: "FR",
                productionRegion: "GB"
            ),
            "US"
        )
    }

    func testWatchProviderURLUsesResolvedRegion() throws {
        let url = try XCTUnwrap(
            NetworkService.watchProviderServicesURL(for: .movie, region: .fr)
        )
        let components = try XCTUnwrap(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )
        let region = components.queryItems?.first(where: {
            $0.name == "watch_region"
        })?.value

        XCTAssertEqual(region, AppContentRegion.fr.rawValue)
    }
}
