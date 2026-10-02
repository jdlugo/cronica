import Foundation

enum DailyReelSessionMode: String, Codable, Equatable, Sendable {
    case daily
    case challenge
    case encore
    case practice
}

enum DailyReelActRole: String, Codable, Equatable, Sendable {
    case decode
    case connect
    case arrange
}

enum DailyReelActStatus: String, Codable, Equatable, Sendable {
    case playing
    case solved
    case revealed
}

struct DailyReelChoice: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let label: String
}

struct DailyReelFilm: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let posterPath: String?
}

struct DailyReelAssistOption: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: String
    let label: String
    let scoreImpact: Int
}

struct DailyReelSessionAct: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let role: DailyReelActRole
    let title: String?
    let prompt: String?
    let clue: String?
    let emoji: [String]?
    let choices: [DailyReelChoice]?
    let films: [DailyReelFilm]?
    let assistOptions: [DailyReelAssistOption]?

    var emojis: [String]? { emoji }
    var options: [DailyReelChoice]? { choices }
    var items: [DailyReelChoice]? {
        films?.map { DailyReelChoice(id: $0.id, label: $0.title) }
    }

    init(
        id: String,
        role: DailyReelActRole,
        title: String? = nil,
        prompt: String? = nil,
        clue: String? = nil,
        emojis: [String]? = nil,
        options: [DailyReelChoice]? = nil,
        items: [DailyReelChoice]? = nil,
        assistOptions: [DailyReelAssistOption]? = nil
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.prompt = prompt
        self.clue = clue
        self.emoji = emojis
        self.choices = options
        self.films = items?.map { DailyReelFilm(id: $0.id, title: $0.label, posterPath: nil) }
        self.assistOptions = assistOptions
    }
}

struct DailyReelActProgress: Codable, Equatable, Sendable {
    let actID: String
    let role: DailyReelActRole
    let status: DailyReelActStatus
    let incorrectAttempts: Int
    let scoreAffectingClues: Int
    let requestedClueIDs: [String]
    let score: Int?

    enum CodingKeys: String, CodingKey {
        case actID = "actId"
        case role
        case status
        case incorrectAttempts
        case scoreAffectingClues
        case requestedClueIDs = "requestedClueIds"
        case score
    }

    var attempts: Int { incorrectAttempts }
    var usedFreeClue: Bool { requestedClueIDs.contains("title-length") }
    var usedScoreHint: Bool { scoreAffectingClues > 0 }
}

struct DailyReelExperienceConfiguration: Codable, Equatable, Sendable {
    let actCount: Int?
    let maximumAttemptsPerAct: Int?
    let assistance: String?
    let resultStyle: String?
    let rolloutVariant: String?

    init(
        actCount: Int? = nil,
        maximumAttemptsPerAct: Int? = nil,
        assistance: String? = nil,
        resultStyle: String? = nil,
        rolloutVariant: String? = nil
    ) {
        self.actCount = actCount
        self.maximumAttemptsPerAct = maximumAttemptsPerAct
        self.assistance = assistance
        self.resultStyle = resultStyle
        self.rolloutVariant = rolloutVariant
    }
}

struct DailyReelSessionProjection: Codable, Equatable, Sendable {
    let contractVersion: String
    let sessionID: String
    let publicationID: String
    let contentVersion: String
    let scoringVersion: String
    let configID: String
    let locale: String
    let mode: DailyReelSessionMode
    let assignmentSource: String
    let status: String
    let sequence: Int
    let currentActIndex: Int
    let theme: String
    let currentAct: DailyReelSessionAct?
    let acts: [DailyReelActProgress]
    let totalScore: Int
    let completedAt: String?

    var versionID: String { contentVersion }
    var experienceConfigHash: String { configID }
    var currentProgress: DailyReelActProgress? {
        acts.indices.contains(currentActIndex) ? acts[currentActIndex] : nil
    }

    var isComplete: Bool {
        status == "completed" || completedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case contractVersion
        case sessionID = "sessionId"
        case publicationID = "publicationId"
        case contentVersion
        case scoringVersion
        case configID = "configId"
        case locale
        case mode
        case assignmentSource
        case status
        case sequence
        case currentActIndex
        case theme
        case currentAct
        case acts
        case totalScore
        case completedAt
    }
}

struct DailyReelSessionEnvelope: Codable, Equatable, Sendable {
    let capability: String
    let session: DailyReelSessionProjection
}

enum DailyReelJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case array([DailyReelJSONValue])
    case object([String: DailyReelJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([DailyReelJSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: DailyReelJSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var displayText: String? {
        switch self {
        case .string(let value):
            return value
        case .array(let values):
            return values.compactMap(\.displayText).joined(separator: " -> ")
        case .object(let values):
            return values["text"]?.displayText
                ?? values["answer"]?.displayText
                ?? values["value"]?.displayText
        default:
            return nil
        }
    }
}

struct DailyReelMutationEnvelope: Codable, Equatable, Sendable {
    let session: DailyReelSessionProjection
    let correct: Bool?
    let assist: DailyReelJSONValue?
    let reveal: DailyReelJSONValue?

    init(
        session: DailyReelSessionProjection,
        correct: Bool? = nil,
        assist: DailyReelJSONValue? = nil,
        reveal: DailyReelJSONValue? = nil
    ) {
        self.session = session
        self.correct = correct
        self.assist = assist
        self.reveal = reveal
    }
}

enum DailyReelAnswer: Equatable, Sendable {
    case text(String)
    case choice(String)
    case order([String])
}

extension DailyReelAnswer: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value), .choice(let value):
            try container.encode(value)
        case .order(let values):
            try container.encode(values)
        }
    }
}

enum DailyReelAssistKind: String, Codable, Equatable, Sendable {
    case clue = "titleLength"
    case hint
}
