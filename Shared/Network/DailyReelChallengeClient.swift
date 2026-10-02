#if os(iOS)
import Foundation

struct DailyReelChallengeProjection: Codable, Equatable, Sendable {
    let challengeID: String
    let status: String
    let publicationID: String
    let locale: String
    let senderNickname: String?
    let senderScore: Int?
    let opponentScore: Int?
    let experienceConfigHash: String
    let expiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case challengeID = "challengeId"
        case status
        case publicationID = "publicationId"
        case locale
        case senderNickname
        case senderScore
        case opponentScore
        case experienceConfigHash
        case expiresAt
    }
}

struct DailyReelChallengeCreateResponse: Codable, Equatable, Sendable {
    let challengeID: String
    let capability: String
    let shareURL: URL
    let expiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case challengeID = "challengeId"
        case capability
        case shareURL = "shareUrl"
        case expiresAt
    }
}

struct DailyReelChallengeClaimResponse: Codable, Equatable, Sendable {
    let sessionID: String
    let sessionCapability: String
    let challenge: DailyReelChallengeProjection

    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionId"
        case sessionCapability
        case challenge
    }
}

protocol DailyReelChallengeClientProtocol: Sendable {
    func create(
        sourceSessionCapability: String,
        requestID: String,
        nickname: String?
    ) async throws -> DailyReelChallengeCreateResponse
    func preview(capability: String) async throws -> DailyReelChallengeProjection
    func claim(capability: String) async throws -> DailyReelChallengeClaimResponse
    func refresh(capability: String) async throws -> DailyReelChallengeProjection
}

struct LiveDailyReelChallengeClient: DailyReelChallengeClientProtocol, Sendable {
    private let baseURL: URL
    private let transport: any DailyReelHTTPTransporting
    private let appCheck: any DailyReelAppCheckTokenProviding
    private let identity: any DailyReelInstallationIdentifying
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        baseURL: URL,
        transport: any DailyReelHTTPTransporting = URLSession.shared,
        appCheck: any DailyReelAppCheckTokenProviding,
        identity: any DailyReelInstallationIdentifying
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.appCheck = appCheck
        self.identity = identity
    }

    func create(
        sourceSessionCapability: String,
        requestID: String,
        nickname: String? = nil
    ) async throws -> DailyReelChallengeCreateResponse {
        try await send(
            path: "daily-reel/challenge/create",
            body: CreateRequest(
                anonymousId: try await identity.installationID(),
                sourceSessionCapability: sourceSessionCapability,
                requestId: requestID,
                nickname: nickname
            )
        )
    }

    func preview(capability: String) async throws -> DailyReelChallengeProjection {
        try await send(
            path: "daily-reel/challenge/preview",
            body: CapabilityRequest(
                anonymousId: try await identity.installationID(),
                capability: capability
            )
        )
    }

    func claim(capability: String) async throws -> DailyReelChallengeClaimResponse {
        try await send(
            path: "daily-reel/challenge/claim",
            body: CapabilityRequest(
                anonymousId: try await identity.installationID(),
                capability: capability
            )
        )
    }

    func refresh(capability: String) async throws -> DailyReelChallengeProjection {
        try await send(
            path: "daily-reel/challenge/refresh",
            body: CapabilityRequest(
                anonymousId: try await identity.installationID(),
                capability: capability
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
                message: payload?.message ?? "Daily Reel challenge request failed",
                statusCode: response.statusCode
            )
        }
        guard let decoded = try? decoder.decode(Response.self, from: data) else {
            throw DailyReelClientError.invalidResponse
        }
        return decoded
    }
}

private struct CreateRequest: Encodable {
    let anonymousId: String
    let sourceSessionCapability: String
    let requestId: String
    let nickname: String?
}

private struct CapabilityRequest: Encodable {
    let anonymousId: String
    let capability: String
}

private struct ErrorResponse: Decodable {
    let code: String
    let message: String
}
#endif
