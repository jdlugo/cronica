import Foundation
import Testing
@testable import StreamingNow

private actor DailyReelFeatureTestClient: DailyReelClientProtocol {
    var startEnvelope: DailyReelSessionEnvelope
    var resumedSession: DailyReelSessionProjection
    var mutationSession: DailyReelSessionProjection
    var mutationError: Error?
    private(set) var submittedRequestIDs: [String] = []
    private(set) var resumeCount = 0

    init(session: DailyReelSessionProjection) {
        startEnvelope = DailyReelSessionEnvelope(capability: "session-capability", session: session)
        resumedSession = session
        mutationSession = session
    }

    func start(
        publicationID: String,
        locale: String,
        mode: DailyReelSessionMode,
        scopeID: String?
    ) async throws -> DailyReelSessionEnvelope {
        startEnvelope
    }

    func resume(capability: String) async throws -> DailyReelSessionProjection {
        resumeCount += 1
        return resumedSession
    }

    func submitAttempt(
        capability: String,
        expectedSequence: Int,
        requestID: String,
        answer: DailyReelAnswer
    ) async throws -> DailyReelMutationEnvelope {
        submittedRequestIDs.append(requestID)
        if let mutationError { throw mutationError }
        return DailyReelMutationEnvelope(session: mutationSession)
    }

    func requestAssist(
        capability: String,
        expectedSequence: Int,
        requestID: String,
        kind: DailyReelAssistKind
    ) async throws -> DailyReelMutationEnvelope {
        if let mutationError { throw mutationError }
        return DailyReelMutationEnvelope(session: mutationSession)
    }

    func reveal(
        capability: String,
        expectedSequence: Int,
        requestID: String
    ) async throws -> DailyReelMutationEnvelope {
        if let mutationError { throw mutationError }
        return DailyReelMutationEnvelope(session: mutationSession)
    }

    func setMutation(session: DailyReelSessionProjection, error: Error? = nil) {
        mutationSession = session
        mutationError = error
    }

    func requests() -> [String] {
        submittedRequestIDs
    }

    func resumes() -> Int {
        resumeCount
    }
}

private actor DailyReelFeatureTestTelemetry: DailyReelTelemetryTracking {
    private(set) var events: [DailyReelTelemetryEvent] = []

    func track(_ event: DailyReelTelemetryEvent) async {
        events.append(event)
    }

    func recordedEvents() -> [DailyReelTelemetryEvent] {
        events
    }
}

@MainActor
@Suite("Daily Reel feature")
struct DailyReelFeatureTests {
    @Test("starts, persists, and resumes an opaque session")
    func startAndResume() async {
        let client = DailyReelFeatureTestClient(session: Self.playingSession)
        let store = InMemoryDailyReelCapabilityStore()
        let telemetry = DailyReelFeatureTestTelemetry()
        let first = DailyReelFeature(
            client: client,
            capabilities: store,
            telemetry: telemetry,
            publicationID: "2026-08-28",
            locale: "en"
        )
        await first.load()
        #expect(first.phase == .playing)
        #expect(first.capability == "session-capability")

        let second = DailyReelFeature(
            client: client,
            capabilities: store,
            telemetry: telemetry,
            publicationID: "2026-08-28",
            locale: "en"
        )
        await second.load()
        #expect(second.phase == .playing)
        #expect(await client.resumes() == 1)
    }

    @Test("retains the same idempotency key for an explicit retry")
    func retryUsesSameRequestID() async {
        let client = DailyReelFeatureTestClient(session: Self.playingSession)
        let feature = DailyReelFeature(
            client: client,
            capabilities: InMemoryDailyReelCapabilityStore(),
            publicationID: "2026-08-28",
            locale: "en",
            requestID: { "request-12345678" }
        )
        await feature.load()
        await client.setMutation(
            session: Self.playingSession,
            error: DailyReelClientError.server(code: "temporary", message: "Retry", statusCode: 503)
        )
        await feature.submit(.text("Titanic"))
        #expect(feature.isRetryAvailable)

        await client.setMutation(session: Self.nextActSession)
        await feature.retry()
        #expect(await client.requests() == ["request-12345678", "request-12345678"])
        #expect(feature.session?.currentActIndex == 1)
    }

    @Test("stale sequence reconciles instead of replaying a new mutation")
    func staleSequenceReconciles() async {
        let client = DailyReelFeatureTestClient(session: Self.playingSession)
        let feature = DailyReelFeature(
            client: client,
            capabilities: InMemoryDailyReelCapabilityStore(),
            publicationID: "2026-08-28",
            locale: "en"
        )
        await feature.load()
        await client.setMutation(
            session: Self.playingSession,
            error: DailyReelClientError.server(
                code: "session.stale_sequence",
                message: "Refresh",
                statusCode: 409
            )
        )
        await feature.submit(.choice("answer-a"))
        #expect(feature.phase == .playing)
        #expect(feature.isRetryAvailable == false)
        #expect(await client.resumes() == 1)
    }

    @Test("server completion drives results and telemetry")
    func completion() async {
        let client = DailyReelFeatureTestClient(session: Self.playingSession)
        let telemetry = DailyReelFeatureTestTelemetry()
        let feature = DailyReelFeature(
            client: client,
            capabilities: InMemoryDailyReelCapabilityStore(),
            telemetry: telemetry,
            publicationID: "2026-08-28",
            locale: "en"
        )
        await feature.load()
        await client.setMutation(session: Self.completedSession)
        await feature.submit(.order(["a", "b", "c"]))
        #expect(feature.phase == .completed)
        #expect(await telemetry.recordedEvents().contains(.completed(score: 2470)))
    }

    private static let playingSession = makeSession(
        sequence: 0,
        index: 0,
        role: .decode
    )

    private static let nextActSession = makeSession(
        sequence: 1,
        index: 1,
        role: .connect
    )

    private static let completedSession = makeSession(
        sequence: 3,
        index: 3,
        role: nil,
        totalScore: 2470,
        completedAt: "2027-01-15T09:21:40.000Z"
    )

    private static func makeSession(
        sequence: Int,
        index: Int,
        role: DailyReelActRole?,
        totalScore: Int? = nil,
        completedAt: String? = nil
    ) -> DailyReelSessionProjection {
        DailyReelSessionProjection(
            contractVersion: "daily-reel-session.v1",
            sessionID: "session-1",
            publicationID: "2026-08-28",
            contentVersion: "v1",
            scoringVersion: "daily-reel-score.v1",
            configID: "config-1",
            locale: "en",
            mode: .daily,
            assignmentSource: "posthog",
            status: completedAt == nil ? "active" : "completed",
            sequence: sequence,
            currentActIndex: index,
            theme: "time-travel",
            currentAct: role.map { DailyReelSessionAct(id: $0.rawValue, role: $0) },
            acts: role.map {
                DailyReelActProgress(
                    actID: $0.rawValue,
                    role: $0,
                    status: .playing,
                    incorrectAttempts: 0,
                    scoreAffectingClues: 0,
                    requestedClueIDs: [],
                    score: nil
                )
            }.map { [$0] } ?? [],
            totalScore: totalScore ?? 0,
            completedAt: completedAt
        )
    }
}
