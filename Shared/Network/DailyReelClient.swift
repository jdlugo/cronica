import Foundation

protocol DailyReelAppCheckTokenProviding: Sendable {
    func token() async throws -> String
}

protocol DailyReelInstallationIdentifying: Sendable {
    func installationID() async throws -> String
}

protocol DailyReelHTTPTransporting: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: DailyReelHTTPTransporting {}

actor UserDefaultsDailyReelInstallationIdentity: DailyReelInstallationIdentifying {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "dailyReel.anonymousInstallationID"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func installationID() async throws -> String {
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let identifier = UUID().uuidString.lowercased()
        defaults.set(identifier, forKey: key)
        return identifier
    }
}

enum DailyReelClientError: Error, Equatable, Sendable {
    case invalidEndpoint
    case invalidResponse
    case server(code: String, message: String, statusCode: Int)
}

protocol DailyReelClientProtocol: Sendable {
    func start(
        publicationID: String,
        locale: String,
        mode: DailyReelSessionMode,
        scopeID: String?
    ) async throws -> DailyReelSessionEnvelope
    func resume(capability: String) async throws -> DailyReelSessionProjection
    func submitAttempt(
        capability: String,
        expectedSequence: Int,
        requestID: String,
        answer: DailyReelAnswer
    ) async throws -> DailyReelMutationEnvelope
    func requestAssist(
        capability: String,
        expectedSequence: Int,
        requestID: String,
        kind: DailyReelAssistKind
    ) async throws -> DailyReelMutationEnvelope
    func reveal(
        capability: String,
        expectedSequence: Int,
        requestID: String
    ) async throws -> DailyReelMutationEnvelope
}

struct LiveDailyReelClient: DailyReelClientProtocol, Sendable {
    private let baseURL: URL
    private let transport: any DailyReelHTTPTransporting
    private let appCheck: any DailyReelAppCheckTokenProviding
    private let identity: any DailyReelInstallationIdentifying
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        transport: any DailyReelHTTPTransporting = URLSession.shared,
        appCheck: any DailyReelAppCheckTokenProviding,
        identity: any DailyReelInstallationIdentifying,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.appCheck = appCheck
        self.identity = identity
        self.encoder = encoder
        self.decoder = decoder
    }

    func start(
        publicationID: String,
        locale: String,
        mode: DailyReelSessionMode,
        scopeID: String? = nil
    ) async throws -> DailyReelSessionEnvelope {
        try await send(
            path: "daily-reel/session/start",
            body: StartRequest(
                anonymousId: try await identity.installationID(),
                publicationId: publicationID,
                locale: locale,
                mode: mode,
                scopeId: scopeID
            )
        )
    }

    func resume(capability: String) async throws -> DailyReelSessionProjection {
        let response: DailyReelMutationEnvelope = try await send(
            path: "daily-reel/session/resume",
            body: CapabilityRequest(
                anonymousId: try await identity.installationID(),
                capability: capability
            )
        )
        return response.session
    }

    func submitAttempt(
        capability: String,
        expectedSequence: Int,
        requestID: String,
        answer: DailyReelAnswer
    ) async throws -> DailyReelMutationEnvelope {
        try await send(
            path: "daily-reel/session/attempt",
            body: AttemptRequest(
                anonymousId: try await identity.installationID(),
                capability: capability,
                expectedSequence: expectedSequence,
                requestId: requestID,
                answer: answer
            )
        )
    }

    func requestAssist(
        capability: String,
        expectedSequence: Int,
        requestID: String,
        kind: DailyReelAssistKind
    ) async throws -> DailyReelMutationEnvelope {
        try await send(
            path: "daily-reel/session/assist",
            body: AssistRequest(
                anonymousId: try await identity.installationID(),
                capability: capability,
                expectedSequence: expectedSequence,
                requestId: requestID,
                kind: kind
            )
        )
    }

    func reveal(
        capability: String,
        expectedSequence: Int,
        requestID: String
    ) async throws -> DailyReelMutationEnvelope {
        try await send(
            path: "daily-reel/session/reveal",
            body: MutationRequest(
                anonymousId: try await identity.installationID(),
                capability: capability,
                expectedSequence: expectedSequence,
                requestId: requestID
            )
        )
    }

    private func send<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw DailyReelClientError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(try await appCheck.token(), forHTTPHeaderField: "X-Firebase-AppCheck")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await transport.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw DailyReelClientError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            let payload = try? decoder.decode(ErrorResponse.self, from: data)
            throw DailyReelClientError.server(
                code: payload?.code ?? "http_\(response.statusCode)",
                message: payload?.message ?? "Daily Reel request failed",
                statusCode: response.statusCode
            )
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw DailyReelClientError.invalidResponse
        }
    }
}

private struct StartRequest: Encodable {
    let anonymousId: String
    let publicationId: String
    let locale: String
    let mode: DailyReelSessionMode
    let scopeId: String?
}

private struct CapabilityRequest: Encodable {
    let anonymousId: String
    let capability: String
}

private struct MutationRequest: Encodable {
    let anonymousId: String
    let capability: String
    let expectedSequence: Int
    let requestId: String
}

private struct AttemptRequest: Encodable {
    let anonymousId: String
    let capability: String
    let expectedSequence: Int
    let requestId: String
    let answer: DailyReelAnswer
}

private struct AssistRequest: Encodable {
    let anonymousId: String
    let capability: String
    let expectedSequence: Int
    let requestId: String
    let kind: DailyReelAssistKind
}

private struct ErrorResponse: Decodable {
    let code: String
    let message: String
}
