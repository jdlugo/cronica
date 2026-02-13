import XCTest
@testable import StreamingNow

/// Tests for SettingsStore default values and persistence behavior.
/// Critical for ensuring ad gating works correctly across app launches.
final class SettingsStoreTests: XCTestCase {

    private let tipJarKey = "userHasPurchasedTipJar"

    override func tearDown() {
        // Clean up any test state
        UserDefaults.standard.removeObject(forKey: tipJarKey)
        super.tearDown()
    }

    // MARK: - Tip Jar Defaults

    func testTipJarDefaultIsFalse() {
        UserDefaults.standard.removeObject(forKey: tipJarKey)
        XCTAssertFalse(SettingsStore.shared.hasPurchasedTipJar,
                        "Tip jar should default to false for new users")
    }

    func testTipJarPersistsTrue() {
        UserDefaults.standard.set(true, forKey: tipJarKey)
        XCTAssertTrue(SettingsStore.shared.hasPurchasedTipJar)
    }

    func testTipJarPersistsFalse() {
        UserDefaults.standard.set(false, forKey: tipJarKey)
        XCTAssertFalse(SettingsStore.shared.hasPurchasedTipJar)
    }

    // MARK: - Other Defaults

    func testDefaultWatchProviderEnabled() {
        XCTAssertTrue(SettingsStore.shared.isWatchProviderEnabled,
                       "Watch providers should be enabled by default")
    }

    func testDefaultNotificationSettings() {
        #if os(iOS)
        XCTAssertTrue(SettingsStore.shared.allowNotifications,
                       "Notifications should be enabled by default on iOS")
        XCTAssertTrue(SettingsStore.shared.notifyMovieRelease)
        XCTAssertTrue(SettingsStore.shared.notifyNewEpisodes)
        #endif
    }

    // MARK: - Singleton

    func testSharedInstanceIsConsistent() {
        let a = SettingsStore.shared
        let b = SettingsStore.shared
        XCTAssertTrue(a === b, "SettingsStore.shared should always return the same instance")
    }
}
