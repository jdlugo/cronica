import Foundation
import os
import PostHog

typealias TelemetryProperties = [String: Any]

struct CronicaTelemetry {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.unknown.app",
        category: String(describing: CronicaTelemetry.self)
    )
    static var shared = CronicaTelemetry()
    
    private(set) var posthogInitialized = false
    private let runtimeSessionID = UUID().uuidString
    private let runtimeSessionStartedAt = Date()
    
    private init() { }
    
    func setup() {
#if targetEnvironment(simulator)
        logger.info("PostHog is disabled on the simulator.")
#else
        guard let posthogProjectToken = Key.posthogProjectToken,
              !posthogProjectToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            logger.warning("PostHog setup skipped: missing or empty project token.")
            return
        }
        let configuration = PostHogConfig(projectToken: posthogProjectToken)
#if os(iOS)
        configuration.sessionReplay = true
        configuration.sessionReplayConfig.screenshotMode = true
        configuration.sessionReplayConfig.sampleRate = 1.0
#endif
        PostHogSDK.shared.setup(configuration)
#if os(iOS)
        PostHogSDK.shared.startSessionRecording()
#endif
        CronicaTelemetry.shared.posthogInitialized = true
        logger.info("PostHog initialization complete.")
#endif
    }
    
    /// Send a PostHog signal with normalized event properties.
    func capture(_ event: String, properties: TelemetryProperties = [:]) {
#if targetEnvironment(simulator)
        logger.debug("PostHog event \(event), properties: \(properties)")
#else
        guard posthogInitialized else {
            logger.warning("PostHog is not initialized.")
            return
        }
        PostHogSDK.shared.capture(
            event,
            properties: baseProperties()
                .merging(runtimeContextProperties(), uniquingKeysWith: { _, new in new })
                .merging(properties, uniquingKeysWith: { _, new in new })
        )
#endif
    }

    /// Send a signal using PostHog.
    ///
    /// If it is running in Simulator or Debug, it will send a warning on logger.
    func handleMessage(_ message: String, for id: String) {
        capture(id, properties: ["message": message])
    }

    private func baseProperties() -> TelemetryProperties {
        let info = Bundle.main.infoDictionary
        let appVersion = info?["CFBundleShortVersionString"] as? String
        let buildNumber = info?["CFBundleVersion"] as? String

        let platform: String
#if os(iOS)
        platform = "ios"
#elseif os(macOS)
        platform = "macos"
#elseif os(watchOS)
        platform = "watchos"
#elseif os(tvOS)
        platform = "tvos"
#else
        platform = "unknown"
#endif

        let properties: TelemetryProperties = [
            "telemetry_schema_version": "1",
            "platform": platform,
            "source": "app",
            "app_version": appVersion ?? "unknown",
            "build_number": buildNumber ?? "unknown"
        ]

        return properties.merging(Self.localeProperties(), uniquingKeysWith: { _, new in new })
    }

    static func localeProperties(
        appLocale: String? = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first,
        deviceRegion: String? = Locale.autoupdatingCurrent.language.region?.identifier,
        contentRegion: AppContentRegion = SettingsStore.shared.watchRegion
    ) -> TelemetryProperties {
        [
            "app_locale": normalizedTelemetryValue(appLocale) {
                $0.replacingOccurrences(of: "_", with: "-")
            },
            "device_region": normalizedTelemetryValue(deviceRegion) {
                $0.uppercased()
            },
            "content_region": contentRegion.rawValue.uppercased()
        ]
    }

    private static func normalizedTelemetryValue(
        _ value: String?,
        transform: (String) -> String
    ) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return "unknown"
        }
        return transform(value)
    }

    private func runtimeContextProperties() -> TelemetryProperties {
#if DEBUG
        let debugBuild = "true"
#else
        let debugBuild = "false"
#endif
        var properties: TelemetryProperties = [
            "runtime_session_id": runtimeSessionID,
            "runtime_session_started_at": ISO8601DateFormatter().string(from: runtimeSessionStartedAt),
            "has_purchased_tip_jar": SettingsStore.shared.hasPurchasedTipJar ? "true" : "false",
            "debug_build": debugBuild,
            "environment": Self.runtimeEnvironment,
            "is_test_run": ProcessInfo.processInfo.arguments.contains("--arcade-test")
        ]

#if os(iOS)
        properties["preview_monetization_disabled"] = PreviewVideoRuntime.shouldDisableMonetization() ? "true" : "false"
#endif

        return properties
    }

    private static var runtimeEnvironment: String {
#if targetEnvironment(simulator)
        let isSimulator = true
#else
        let isSimulator = false
#endif
#if DEBUG
        let isDebug = true
#else
        let isDebug = false
#endif
        return ArcadeTelemetryEnvironment.classify(
            isSimulator: isSimulator,
            isDebug: isDebug,
            receiptName: Bundle.main.appStoreReceiptURL?.lastPathComponent
        )
    }
    
    var isPostHogInitialized: String {
        return posthogInitialized.description
    }

    var isPostHogInitializedForRuntime: Bool {
        return posthogInitialized
    }
}
