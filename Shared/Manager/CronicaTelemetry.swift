import Foundation
import os
#if !os(iOS)
import Aptabase
#else
import TelemetryDeck
#endif

struct CronicaTelemetry {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.unknown.app",
        category: String(describing: CronicaTelemetry.self)
    )
    static var shared = CronicaTelemetry()
    
#if os(iOS)
    private(set) var telemetryInitialized = false
#endif
    
    private init() { }
    
    func setup() {
#if !targetEnvironment(simulator) && !DEBUG
#if !os(iOS)
        guard let aptabaseKey = Key.aptabaseClientKey else { return }
        Aptabase.shared.initialize(appKey: aptabaseKey)
        Aptabase.shared.trackEvent("app_started")
#else
        guard let key = Key.telemetryClientKey else { return }
        let configuration = TelemetryDeck.Config(appID: key)
        TelemetryDeck.initialize(config: configuration)
        CronicaTelemetry.shared.telemetryInitialized = true
#endif
#endif
    }
    
    /// Send a signal using TelemetryDeck service (on iOS/iPadOS) or in Aptabase (macOS, watchOS, tvOS).
    ///
    /// If it is running in Simulator or Debug, it will send a warning on logger.
    func handleMessage(_ message: String, for id: String) {
#if targetEnvironment(simulator) || DEBUG
        logger.warning("\(message), for: \(id)")
#else
#if !os(iOS)
        Aptabase.shared.trackEvent(id, with: ["Message": message])
#else
        TelemetryDeck.signal(id, parameters: ["Message": message])
#endif
#endif
    }
    
#if os(iOS)
    var isTelemetryDeckInitialized: String {
        return telemetryInitialized.description
    }
#endif
}
