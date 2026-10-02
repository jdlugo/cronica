import Foundation

enum DailyReelContract {
    static let version = "daily-reel.v1"
    static let sessionVersion = "daily-reel-session.v1"
    static let scoringVersion = "daily-reel-score.v1"
    static let experienceVersion = "daily-reel-experience.v1"
    static let locales = ["en", "fr-FR", "es-ES", "es-MX", "pt-BR"]
}

struct DailyReel: Codable, Equatable, Sendable {
    let contractVersion: String
    let publicationId: String
    let contentVersion: String
    let scoringVersion: String
    let publicationWindow: DailyReelPublicationWindow
    let defaultLocale: String
    let supportedLocales: [String]
    let scoring: DailyReelScoringRules
    let localized: [String: DailyReelLocalizedContent]

    func content(for locale: String) -> DailyReelLocalizedContent? {
        localized[locale] ?? localized[defaultLocale]
    }
}

struct DailyReelPublicationWindow: Codable, Equatable, Sendable {
    let availableAt: String
    let expiresAt: String
}

struct DailyReelScoringRules: Codable, Equatable, Sendable {
    let maxScore: Int
    let perActMax: Int
    let maxIncorrectAttemptsPerAct: Int
}

struct DailyReelLocalizedContent: Codable, Equatable, Sendable {
    let theme: String
    let shareText: String
    let acts: [DailyReelAct]
}

enum DailyReelActRole: String, Codable, Equatable, Sendable {
    case decode
    case connect
    case arrange
}

enum DailyReelAssistKind: String, Codable, Equatable, Sendable {
    case titleLength
    case hint
}

struct DailyReelAssistOption: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let kind: DailyReelAssistKind
    let label: String
    let scoreImpact: Int
}

struct DailyReelFilm: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let posterPath: String?
}

struct DailyReelChoice: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let label: String
}

struct DailyReelDecodeAct: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let role: DailyReelActRole
    let prompt: String
    let emoji: [String]
    let assistOptions: [DailyReelAssistOption]
}

struct DailyReelConnectAct: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let role: DailyReelActRole
    let prompt: String
    let films: [DailyReelFilm]
    let choices: [DailyReelChoice]
    let assistOptions: [DailyReelAssistOption]
}

struct DailyReelArrangeAct: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let role: DailyReelActRole
    let prompt: String
    let films: [DailyReelFilm]
    let assistOptions: [DailyReelAssistOption]
}

enum DailyReelAct: Codable, Equatable, Sendable, Identifiable {
    case decode(DailyReelDecodeAct)
    case connect(DailyReelConnectAct)
    case arrange(DailyReelArrangeAct)

    var id: String {
        switch self {
        case let .decode(act): act.id
        case let .connect(act): act.id
        case let .arrange(act): act.id
        }
    }

    var role: DailyReelActRole {
        switch self {
        case .decode: .decode
        case .connect: .connect
        case .arrange: .arrange
        }
    }

    private enum CodingKeys: String, CodingKey {
        case role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(DailyReelActRole.self, forKey: .role) {
        case .decode:
            self = .decode(try DailyReelDecodeAct(from: decoder))
        case .connect:
            self = .connect(try DailyReelConnectAct(from: decoder))
        case .arrange:
            self = .arrange(try DailyReelArrangeAct(from: decoder))
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .decode(act):
            try act.encode(to: encoder)
        case let .connect(act):
            try act.encode(to: encoder)
        case let .arrange(act):
            try act.encode(to: encoder)
        }
    }
}

enum DailyReelActOutcome: String, Codable, Equatable, Sendable {
    case solved
    case revealed
    case exhausted
}

struct DailyReelActScoreInput: Codable, Equatable, Sendable {
    let outcome: DailyReelActOutcome
    let incorrectAttempts: Int
    let scoreAffectingClues: Int
    let freeClues: Int

    init(
        outcome: DailyReelActOutcome,
        incorrectAttempts: Int,
        scoreAffectingClues: Int,
        freeClues: Int = 0
    ) {
        self.outcome = outcome
        self.incorrectAttempts = incorrectAttempts
        self.scoreAffectingClues = scoreAffectingClues
        self.freeClues = freeClues
    }
}

enum DailyReelScoring {
    static let maximumActScore = 100
    static let maximumReelScore = 300

    static func scoreAct(_ input: DailyReelActScoreInput) -> Int {
        guard input.outcome == .solved else { return 0 }

        let assistanceEvents = max(0, input.incorrectAttempts) + max(0, input.scoreAffectingClues)
        switch assistanceEvents {
        case 0: return 100
        case 1: return 75
        default: return 50
        }
    }

    static func totalScore(_ actScores: [Int]) -> Int {
        min(maximumReelScore, actScores.reduce(0) { total, score in
            total + max(0, min(maximumActScore, score))
        })
    }
}

enum DailyReelActStatus: String, Codable, Equatable, Sendable {
    case playing
    case solved
    case revealed
    case exhausted
}

struct DailyReelActProgress: Codable, Equatable, Sendable {
    let status: DailyReelActStatus
    let incorrectAttempts: Int
    let scoreAffectingClues: Int
    let requestedClueIDs: [String]
    let score: Int?

    static let initial = DailyReelActProgress(
        status: .playing,
        incorrectAttempts: 0,
        scoreAffectingClues: 0,
        requestedClueIDs: [],
        score: nil
    )

    private enum CodingKeys: String, CodingKey {
        case status
        case incorrectAttempts
        case scoreAffectingClues
        case requestedClueIDs = "requestedClueIds"
        case score
    }

    func applying(_ event: DailyReelActEvent, maxIncorrectAttempts: Int = 3) -> DailyReelActProgress {
        guard status == .playing else { return self }

        switch event {
        case let .requestClue(id, affectsScore):
            let clueID = id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clueID.isEmpty, !requestedClueIDs.contains(clueID) else { return self }
            return DailyReelActProgress(
                status: status,
                incorrectAttempts: incorrectAttempts,
                scoreAffectingClues: scoreAffectingClues + (affectsScore ? 1 : 0),
                requestedClueIDs: requestedClueIDs + [clueID],
                score: score
            )

        case .correct:
            return DailyReelActProgress(
                status: .solved,
                incorrectAttempts: incorrectAttempts,
                scoreAffectingClues: scoreAffectingClues,
                requestedClueIDs: requestedClueIDs,
                score: DailyReelScoring.scoreAct(
                    DailyReelActScoreInput(
                        outcome: .solved,
                        incorrectAttempts: incorrectAttempts,
                        scoreAffectingClues: scoreAffectingClues
                    )
                )
            )

        case .reveal:
            return DailyReelActProgress(
                status: .revealed,
                incorrectAttempts: incorrectAttempts,
                scoreAffectingClues: scoreAffectingClues,
                requestedClueIDs: requestedClueIDs,
                score: 0
            )

        case .incorrect:
            let nextIncorrectAttempts = incorrectAttempts + 1
            if nextIncorrectAttempts >= max(1, maxIncorrectAttempts) {
                return DailyReelActProgress(
                    status: .exhausted,
                    incorrectAttempts: nextIncorrectAttempts,
                    scoreAffectingClues: scoreAffectingClues,
                    requestedClueIDs: requestedClueIDs,
                    score: 0
                )
            }
            return DailyReelActProgress(
                status: status,
                incorrectAttempts: nextIncorrectAttempts,
                scoreAffectingClues: scoreAffectingClues,
                requestedClueIDs: requestedClueIDs,
                score: score
            )
        }
    }
}

enum DailyReelActEvent: Equatable, Sendable {
    case incorrect
    case correct
    case requestClue(id: String, affectsScore: Bool)
    case reveal
}

enum DailyReelSessionMode: String, Codable, Equatable, Sendable {
    case daily
    case challenge
    case encore
    case practice
}

enum DailyReelSessionStatus: String, Codable, Equatable, Sendable {
    case active
    case completed
}

struct DailyReelSessionActProgress: Codable, Equatable, Sendable {
    let actId: String
    let role: DailyReelActRole
    let status: DailyReelActStatus
    let incorrectAttempts: Int
    let scoreAffectingClues: Int
    let requestedClueIDs: [String]
    let score: Int?

    private enum CodingKeys: String, CodingKey {
        case actId
        case role
        case status
        case incorrectAttempts
        case scoreAffectingClues
        case requestedClueIDs = "requestedClueIds"
        case score
    }
}

struct DailyReelSessionState: Codable, Equatable, Sendable {
    let contractVersion: String
    let sessionId: String
    let publicationId: String
    let contentVersion: String
    let scoringVersion: String
    let configId: String
    let mode: DailyReelSessionMode
    let status: DailyReelSessionStatus
    let currentActIndex: Int
    let acts: [DailyReelSessionActProgress]
    let totalScore: Int
    let completedAt: String?
}

struct DailyReelExperienceConfig: Codable, Equatable, Sendable {
    let configVersion: String
    let configId: String
    let scoringVersion: String
    let maxIncorrectAttemptsPerAct: Int
    let actOrder: [DailyReelActRole]
    let assistance: DailyReelExperienceAssistance
    let results: DailyReelExperienceResults
    let festival: DailyReelExperienceFestival
}

struct DailyReelExperienceAssistance: Codable, Equatable, Sendable {
    let titleLength: DailyReelExperienceAssistRule
    let standardHint: DailyReelExperienceAssistRule
}

struct DailyReelExperienceAssistRule: Codable, Equatable, Sendable {
    let enabled: Bool
    let scoreImpact: Int
}

struct DailyReelExperienceResults: Codable, Equatable, Sendable {
    let rematchProminence: String
    let pickTonightEnabled: Bool
}

struct DailyReelExperienceFestival: Codable, Equatable, Sendable {
    let targetDistinctReels: Int
    let encoreRewardCount: Int
}
