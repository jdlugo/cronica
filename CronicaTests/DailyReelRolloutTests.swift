import Testing
@testable import StreamingNow

private struct DailyReelRolloutTestProvider: DailyReelRolloutProviding {
    let value: DailyReelRolloutAssignment
    func assignment() async -> DailyReelRolloutAssignment { value }
}

@MainActor
@Suite("Daily Reel rollout")
struct DailyReelRolloutTests {
    @Test("unknown and false values fail closed")
    func failClosed() {
        #expect(DailyReelRolloutAssignment.resolve(rawValue: nil) == .disabled)
        #expect(DailyReelRolloutAssignment.resolve(rawValue: false) == .disabled)
        #expect(DailyReelRolloutAssignment.resolve(rawValue: "off") == .disabled)
    }

    @Test("boolean and multivariate assignments enable a named cohort")
    func enabledAssignments() {
        #expect(DailyReelRolloutAssignment.resolve(rawValue: true).isEnabled)
        #expect(DailyReelRolloutAssignment.resolve(rawValue: "internal") == .init(
            isEnabled: true,
            variant: "internal"
        ))
    }

    @Test("controller resolves the gate once")
    func controller() async {
        let controller = DailyReelRolloutController(
            provider: DailyReelRolloutTestProvider(
                value: .init(isEnabled: true, variant: "beta")
            )
        )
        await controller.refresh()
        #expect(controller.state == .enabled(variant: "beta"))
    }
}
