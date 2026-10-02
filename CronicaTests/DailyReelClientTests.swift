import Foundation
import Testing
@testable import StreamingNow

private actor DailyReelClientTestTransport: DailyReelHTTPTransporting {
    private(set) var requests: [URLRequest] = []
    var data: Data
    var statusCode: Int

    init(data: Data, statusCode: Int = 200) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }

    func lastRequest() -> URLRequest? {
        requests.last
    }
}

private struct DailyReelClientTestTokenProvider: DailyReelAppCheckTokenProviding {
    func token() async throws -> String { "app-check-token" }
}

private struct DailyReelClientTestIdentity: DailyReelInstallationIdentifying {
    func installationID() async throws -> String { "install-123" }
}

@Suite("Daily Reel client")
struct DailyReelClientTests {
    @Test("start sends App Check and anonymous identity without putting capabilities in the URL")
    func startRequest() async throws {
        let transport = DailyReelClientTestTransport(data: Self.startEnvelopeData)
        let client = LiveDailyReelClient(
            baseURL: URL(string: "https://example.test/api/")!,
            transport: transport,
            appCheck: DailyReelClientTestTokenProvider(),
            identity: DailyReelClientTestIdentity()
        )

        let envelope = try await client.start(
            publicationID: "2026-08-28",
            locale: "fr-FR",
            mode: .daily,
            scopeID: nil
        )

        #expect(envelope.capability == "opaque-session-capability")
        let request = try #require(await transport.lastRequest())
        #expect(request.url?.path == "/api/daily-reel/session/start")
        #expect(request.url?.query == nil)
        #expect(request.value(forHTTPHeaderField: "X-Firebase-AppCheck") == "app-check-token")
        let object = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        #expect(object["anonymousId"] as? String == "install-123")
        #expect(object["locale"] as? String == "fr-FR")
    }

    @Test("mutation capabilities remain in the POST body")
    func mutationRequest() async throws {
        let transport = DailyReelClientTestTransport(data: Self.mutationEnvelopeData)
        let client = LiveDailyReelClient(
            baseURL: URL(string: "https://example.test/")!,
            transport: transport,
            appCheck: DailyReelClientTestTokenProvider(),
            identity: DailyReelClientTestIdentity()
        )

        _ = try await client.submitAttempt(
            capability: "secret-capability",
            expectedSequence: 2,
            requestID: "request-12345678",
            answer: .order(["first", "second"])
        )

        let request = try #require(await transport.lastRequest())
        #expect(request.url?.absoluteString.contains("secret-capability") == false)
        let object = try #require(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        #expect(object["capability"] as? String == "secret-capability")
        #expect(object["anonymousId"] as? String == "install-123")
        #expect(object["expectedSequence"] as? Int == 2)
        #expect(object["answer"] as? [String] == ["first", "second"])
    }

    @Test("typed server errors preserve retry decisions")
    func serverError() async throws {
        let data = Data(#"{"code":"session.stale_sequence","message":"Refresh first"}"#.utf8)
        let transport = DailyReelClientTestTransport(data: data, statusCode: 409)
        let client = LiveDailyReelClient(
            baseURL: URL(string: "https://example.test/")!,
            transport: transport,
            appCheck: DailyReelClientTestTokenProvider(),
            identity: DailyReelClientTestIdentity()
        )

        await #expect(throws: DailyReelClientError.server(
            code: "session.stale_sequence",
            message: "Refresh first",
            statusCode: 409
        )) {
            _ = try await client.resume(capability: "capability")
        }
    }

    private static let startEnvelopeData = Data(
        #"{"capability":"opaque-session-capability","session":{"contractVersion":"daily-reel-session.v1","sessionId":"session-1","publicationId":"2026-08-28","contentVersion":"v1","scoringVersion":"daily-reel-score.v1","configId":"config-1","locale":"fr-FR","mode":"daily","assignmentSource":"posthog","status":"active","sequence":0,"currentActIndex":0,"theme":"ocean","currentAct":{"id":"decode","role":"decode","prompt":"Name the movie","emoji":["ship","ice"],"assistOptions":[]},"acts":[{"actId":"decode","role":"decode","status":"playing","incorrectAttempts":0,"scoreAffectingClues":0,"requestedClueIds":[],"score":null}],"totalScore":0,"completedAt":null}}"#.utf8
    )

    private static let mutationEnvelopeData = Data(
        #"{"session":{"contractVersion":"daily-reel-session.v1","sessionId":"session-1","publicationId":"2026-08-28","contentVersion":"v1","scoringVersion":"daily-reel-score.v1","configId":"config-1","locale":"en","mode":"daily","assignmentSource":"posthog","status":"active","sequence":3,"currentActIndex":2,"theme":"time","currentAct":{"id":"arrange","role":"arrange","films":[],"assistOptions":[]},"acts":[{"actId":"arrange","role":"arrange","status":"playing","incorrectAttempts":0,"scoreAffectingClues":0,"requestedClueIds":[],"score":null}],"totalScore":0,"completedAt":null}}"#.utf8
    )
}
