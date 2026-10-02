import Foundation
import Observation

protocol DailyReelCapabilityPersisting: Sendable {
    func load(publicationID: String, mode: DailyReelSessionMode) async -> String?
    func save(_ capability: String, publicationID: String, mode: DailyReelSessionMode) async
    func clear(publicationID: String, mode: DailyReelSessionMode) async
}

actor InMemoryDailyReelCapabilityStore: DailyReelCapabilityPersisting {
    private var values: [String: String] = [:]

    func load(publicationID: String, mode: DailyReelSessionMode) async -> String? {
        values[key(publicationID: publicationID, mode: mode)]
    }

    func save(_ capability: String, publicationID: String, mode: DailyReelSessionMode) async {
        values[key(publicationID: publicationID, mode: mode)] = capability
    }

    func clear(publicationID: String, mode: DailyReelSessionMode) async {
        values.removeValue(forKey: key(publicationID: publicationID, mode: mode))
    }

    private func key(publicationID: String, mode: DailyReelSessionMode) -> String {
        "\(mode.rawValue):\(publicationID)"
    }
}

enum DailyReelTelemetryEvent: Equatable, Sendable {
    case sessionStarted(mode: DailyReelSessionMode, configHash: String)
    case sessionResumed(mode: DailyReelSessionMode, configHash: String)
    case actViewed(index: Int, role: DailyReelActRole)
    case attemptSubmitted(index: Int, role: DailyReelActRole)
    case assistRequested(index: Int, kind: DailyReelAssistKind)
    case actRevealed(index: Int)
    case completed(score: Int)
    case challengeCreated
    case challengeCreationFailed(code: String)
    case failed(code: String)
}

protocol DailyReelTelemetryTracking: Sendable {
    func track(_ event: DailyReelTelemetryEvent) async
}

struct NoopDailyReelTelemetryTracker: DailyReelTelemetryTracking {
    func track(_ event: DailyReelTelemetryEvent) async {}
}

@MainActor
@Observable
final class DailyReelFeature {
    enum Phase: Equatable {
        case idle
        case loading
        case playing
        case submitting
        case completed
        case unavailable
        case failed(String)
    }

    enum Feedback: Equatable {
        case correct
        case incorrect
        case assist(String)
        case revealed(String?)
    }

    private enum PendingMutation: Equatable {
        case attempt(answer: DailyReelAnswer, requestID: String, sequence: Int)
        case assist(kind: DailyReelAssistKind, requestID: String, sequence: Int)
        case reveal(requestID: String, sequence: Int)
    }

    private let client: any DailyReelClientProtocol
    private let capabilities: any DailyReelCapabilityPersisting
    private let telemetry: any DailyReelTelemetryTracking
    private let publicationID: String
    private let locale: String
    private let mode: DailyReelSessionMode
    private let requestID: () -> String

    private(set) var phase: Phase = .idle
    private(set) var session: DailyReelSessionProjection?
    private(set) var capability: String?
    private(set) var isRetryAvailable = false
    private(set) var feedback: Feedback?
    private var pendingMutation: PendingMutation?

    init(
        client: any DailyReelClientProtocol,
        capabilities: any DailyReelCapabilityPersisting,
        telemetry: any DailyReelTelemetryTracking = NoopDailyReelTelemetryTracker(),
        publicationID: String,
        locale: String,
        mode: DailyReelSessionMode = .daily,
        requestID: @escaping () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.client = client
        self.capabilities = capabilities
        self.telemetry = telemetry
        self.publicationID = publicationID
        self.locale = locale
        self.mode = mode
        self.requestID = requestID
    }

    func load() async {
        guard phase == .idle || phase == .unavailable || isFailurePhase else { return }
        phase = .loading
        if let savedCapability = await capabilities.load(publicationID: publicationID, mode: mode) {
            do {
                let resumed = try await client.resume(capability: savedCapability)
                capability = savedCapability
                await accept(resumed, resumed: true)
                return
            } catch let error as DailyReelClientError {
                if case .server(let code, _, _) = error,
                   ["session.not_found", "session.expired", "content.unavailable"].contains(code) {
                    await capabilities.clear(publicationID: publicationID, mode: mode)
                } else {
                    await fail(error)
                    return
                }
            } catch {
                await fail(error)
                return
            }
        }

        do {
            let started = try await client.start(
                publicationID: publicationID,
                locale: locale,
                mode: mode,
                scopeID: nil
            )
            capability = started.capability
            await capabilities.save(started.capability, publicationID: publicationID, mode: mode)
            await accept(started.session, resumed: false)
        } catch let error as DailyReelClientError {
            if case .server(let code, _, let statusCode) = error,
               statusCode == 404 || code == "experience.ineligible" || code == "content.unavailable" {
                phase = .unavailable
                await telemetry.track(.failed(code: code))
            } else {
                await fail(error)
            }
        } catch {
            await fail(error)
        }
    }

    func submit(_ answer: DailyReelAnswer) async {
        guard let session else { return }
        await perform(.attempt(answer: answer, requestID: requestID(), sequence: session.sequence))
    }

    func requestAssist(_ kind: DailyReelAssistKind) async {
        guard let session else { return }
        await perform(.assist(kind: kind, requestID: requestID(), sequence: session.sequence))
    }

    func reveal() async {
        guard let session else { return }
        await perform(.reveal(requestID: requestID(), sequence: session.sequence))
    }

    func retry() async {
        guard let pendingMutation else { return }
        await perform(pendingMutation)
    }

    func recordChallengeCreated() async {
        await telemetry.track(.challengeCreated)
    }

    func recordChallengeCreationFailed(code: String) async {
        await telemetry.track(.challengeCreationFailed(code: code))
    }

    private var isFailurePhase: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func perform(_ mutation: PendingMutation) async {
        guard let capability, phase == .playing || isFailurePhase else { return }
        let mutationActIndex = session?.currentActIndex
        pendingMutation = mutation
        isRetryAvailable = false
        phase = .submitting
        do {
            let response: DailyReelMutationEnvelope
            switch mutation {
            case .attempt(let answer, let requestID, let sequence):
                response = try await client.submitAttempt(
                    capability: capability,
                    expectedSequence: sequence,
                    requestID: requestID,
                    answer: answer
                )
                if let act = session?.currentAct {
                    await telemetry.track(.attemptSubmitted(index: session?.currentActIndex ?? 0, role: act.role))
                }
            case .assist(let kind, let requestID, let sequence):
                response = try await client.requestAssist(
                    capability: capability,
                    expectedSequence: sequence,
                    requestID: requestID,
                    kind: kind
                )
                await telemetry.track(.assistRequested(index: session?.currentActIndex ?? 0, kind: kind))
            case .reveal(let requestID, let sequence):
                response = try await client.reveal(
                    capability: capability,
                    expectedSequence: sequence,
                    requestID: requestID
                )
                await telemetry.track(.actRevealed(index: session?.currentActIndex ?? 0))
            }
            pendingMutation = nil
            await accept(response.session, resumed: true, trackSessionEvent: false)
            let remainsOnMutationAct = !response.session.isComplete
                && response.session.currentActIndex == mutationActIndex
            if !remainsOnMutationAct {
                feedback = nil
            } else if let assist = response.assist {
                feedback = .assist(assist.displayText ?? "A new clue is ready.")
            } else if let reveal = response.reveal {
                feedback = .revealed(reveal.displayText)
            } else if let correct = response.correct {
                feedback = correct ? .correct : .incorrect
            }
        } catch let error as DailyReelClientError {
            if case .server(let code, _, _) = error, code == "session.stale_sequence" {
                await reconcile(capability: capability)
            } else {
                isRetryAvailable = true
                await fail(error)
            }
        } catch {
            isRetryAvailable = true
            await fail(error)
        }
    }

    private func reconcile(capability: String) async {
        do {
            let current = try await client.resume(capability: capability)
            pendingMutation = nil
            await accept(current, resumed: true, trackSessionEvent: false)
        } catch {
            isRetryAvailable = true
            await fail(error)
        }
    }

    private func accept(
        _ updatedSession: DailyReelSessionProjection,
        resumed: Bool,
        trackSessionEvent: Bool = true
    ) async {
        let previousActIndex = session?.currentActIndex
        if previousActIndex != updatedSession.currentActIndex {
            feedback = nil
        }
        session = updatedSession
        isRetryAvailable = false
        phase = updatedSession.isComplete ? .completed : .playing
        if trackSessionEvent {
            await telemetry.track(
                resumed
                    ? .sessionResumed(mode: updatedSession.mode, configHash: updatedSession.experienceConfigHash)
                    : .sessionStarted(mode: updatedSession.mode, configHash: updatedSession.experienceConfigHash)
            )
        }
        if previousActIndex != updatedSession.currentActIndex, let act = updatedSession.currentAct {
            await telemetry.track(.actViewed(index: updatedSession.currentActIndex, role: act.role))
        }
        if updatedSession.isComplete {
            await telemetry.track(.completed(score: updatedSession.totalScore))
        }
    }

    private func fail(_ error: Error) async {
        let code: String
        if let error = error as? DailyReelClientError,
           case .server(let serverCode, _, _) = error {
            code = serverCode
        } else {
            code = "network_or_decode"
        }
        phase = .failed(code)
        await telemetry.track(.failed(code: code))
    }
}
