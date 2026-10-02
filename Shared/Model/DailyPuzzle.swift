import Foundation

enum DailyPuzzleMediaType: String, Codable, Equatable {
    case movie
    case tvShow = "tv"
}

struct DailyPuzzleLocalizedContent: Codable, Equatable {
    var title: String
    var emojiClue: String
    var hint1: String
    var hint2: String
    var acceptedAnswers: [String]

    enum CodingKeys: String, CodingKey {
        case title
        case emojiClue = "emoji_clue"
        case hint1 = "hint_1"
        case hint2 = "hint_2"
        case acceptedAnswers = "accepted_answers"
    }
}

enum DailyPuzzleLocalizationSource: String, Equatable {
    case exactLocale = "exact_locale"
    case languageFallback = "language_fallback"
    case canonical
}

struct DailyPuzzleLocalizationResolution: Equatable {
    let puzzle: DailyPuzzle
    let localeIdentifier: String
    let source: DailyPuzzleLocalizationSource
}

struct DailyPuzzle: Codable, Equatable, Identifiable {
    var id: String { puzzleID }
    var date: String
    var puzzleID: String
    var mediaType: DailyPuzzleMediaType
    var tmdbID: Int
    var title: String?
    var emojiClue: String
    var hint1: String
    var hint2: String
    var acceptedAnswers: [String]
    var localizations: [String: DailyPuzzleLocalizedContent]? = nil
    var source: String
    var generatedAt: String

    enum CodingKeys: String, CodingKey {
        case date
        case puzzleID = "puzzle_id"
        case mediaType = "media_type"
        case tmdbID = "tmdb_id"
        case title
        case emojiClue = "emoji_clue"
        case hint1 = "hint_1"
        case hint2 = "hint_2"
        case acceptedAnswers = "accepted_answers"
        case localizations
        case source
        case generatedAt = "generated_at"
    }
}

struct DailyPuzzleProgress: Codable, Equatable {
    var puzzleID: String
    var solved: Bool
    var attempts: Int
    var unlockedHintCount: Int
    var solvedAt: Date?
    var quizState: MovieQuizState? = nil
}

extension DailyPuzzle {
    static let sample = DailyPuzzle(
        date: "2026-02-15",
        puzzleID: "2026-02-15",
        mediaType: .movie,
        tmdbID: 597,
        title: "Titanic",
        emojiClue: "🚢🧊❤️",
        hint1: "Released in 1997",
        hint2: "Directed by James Cameron",
        acceptedAnswers: ["titanic"],
        source: "ai+tmdb",
        generatedAt: "2026-02-15T05:00:00.000Z"
    )

    static let developerSamples: [DailyPuzzle] = [
        .sample,
        DailyPuzzle(
            date: "2026-02-16",
            puzzleID: "2026-02-16",
            mediaType: .movie,
            tmdbID: 603,
            title: "The Matrix",
            emojiClue: "🕶️💊🤖",
            hint1: "Released in 1999",
            hint2: "Features Neo and Morpheus",
            acceptedAnswers: ["the matrix", "matrix"],
            source: "dev-sample",
            generatedAt: "2026-02-16T05:00:00.000Z"
        ),
        DailyPuzzle(
            date: "2026-02-17",
            puzzleID: "2026-02-17",
            mediaType: .movie,
            tmdbID: 329,
            title: "Jurassic Park",
            emojiClue: "🦖🌴🚙",
            hint1: "Directed by Steven Spielberg",
            hint2: "Dinosaurs are brought back to life",
            acceptedAnswers: ["jurassic park"],
            source: "dev-sample",
            generatedAt: "2026-02-17T05:00:00.000Z"
        ),
        DailyPuzzle(
            date: "2026-02-18",
            puzzleID: "2026-02-18",
            mediaType: .movie,
            tmdbID: 27205,
            title: "Inception",
            emojiClue: "😴🌀🏙️",
            hint1: "Released in 2010",
            hint2: "Dreams inside dreams",
            acceptedAnswers: ["inception"],
            source: "dev-sample",
            generatedAt: "2026-02-18T05:00:00.000Z"
        ),
        DailyPuzzle(
            date: "2026-02-19",
            puzzleID: "2026-02-19",
            mediaType: .movie,
            tmdbID: 346698,
            title: "Barbie",
            emojiClue: "🎀💄🏠",
            hint1: "Released in 2023",
            hint2: "Directed by Greta Gerwig",
            acceptedAnswers: ["barbie"],
            source: "dev-sample",
            generatedAt: "2026-02-19T05:00:00.000Z"
        ),
        DailyPuzzle(
            date: "2026-02-20",
            puzzleID: "2026-02-20",
            mediaType: .movie,
            tmdbID: 299534,
            title: "Avengers: Endgame",
            emojiClue: "🦸‍♂️🫰🌌",
            hint1: "Released in 2019",
            hint2: "Concludes Marvel's Infinity Saga",
            acceptedAnswers: ["avengers endgame", "avengers: endgame", "endgame"],
            source: "dev-sample",
            generatedAt: "2026-02-20T05:00:00.000Z"
        )
    ]

    func matches(guess: String) -> Bool {
        let normalizedGuess = Self.normalize(answer: guess)
        guard !normalizedGuess.isEmpty else { return false }
        // Display language must not determine which known release titles count.
        // Keep exact normalized matching: fuzzy matching can accept a different sequel.
        let localizedAnswers = (localizations ?? [:]).values.flatMap {
            [$0.title] + $0.acceptedAnswers
        }
        let candidates = acceptedAnswers + (title.map { [$0] } ?? []) + localizedAnswers
        return candidates.contains { Self.normalize(answer: $0) == normalizedGuess }
    }

    func localized(for locale: Locale) -> DailyPuzzleLocalizationResolution {
        localized(forLocaleIdentifier: locale.identifier)
    }

    func localized(forLocaleIdentifier localeIdentifier: String) -> DailyPuzzleLocalizationResolution {
        let requestedIdentifier = localeIdentifier.replacingOccurrences(of: "_", with: "-")
        guard let localizations, !localizations.isEmpty else {
            return .init(puzzle: self, localeIdentifier: "en", source: .canonical)
        }

        if let exactKey = localizations.keys.first(where: {
            $0.caseInsensitiveCompare(requestedIdentifier) == .orderedSame
        }), let content = localizations[exactKey] {
            return applying(content, localeIdentifier: exactKey, source: .exactLocale)
        }

        let requestedLanguage = requestedIdentifier
            .split(separator: "-", maxSplits: 1)
            .first?
            .lowercased()
        if let requestedLanguage,
           let fallbackKey = localizations.keys.sorted().first(where: {
               $0.split(separator: "-", maxSplits: 1).first?.lowercased() == requestedLanguage
           }),
           let content = localizations[fallbackKey] {
            return applying(content, localeIdentifier: fallbackKey, source: .languageFallback)
        }

        return .init(puzzle: self, localeIdentifier: "en", source: .canonical)
    }

    private func applying(
        _ content: DailyPuzzleLocalizedContent,
        localeIdentifier: String,
        source: DailyPuzzleLocalizationSource
    ) -> DailyPuzzleLocalizationResolution {
        var localizedPuzzle = self
        localizedPuzzle.title = content.title
        localizedPuzzle.emojiClue = content.emojiClue
        localizedPuzzle.hint1 = content.hint1
        localizedPuzzle.hint2 = content.hint2

        var seenAnswers = Set<String>()
        localizedPuzzle.acceptedAnswers = (
            content.acceptedAnswers + acceptedAnswers + [content.title] + (title.map { [$0] } ?? [])
        ).filter { answer in
            let normalized = Self.normalize(answer: answer)
            return !normalized.isEmpty && seenAnswers.insert(normalized).inserted
        }

        return .init(
            puzzle: localizedPuzzle,
            localeIdentifier: localeIdentifier,
            source: source
        )
    }

    fileprivate static func normalize(answer: String) -> String {
        let lowered = answer
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
        let components = lowered.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return components.joined()
    }

    static func starRating(for attempts: Int) -> Int {
        switch attempts {
        case 1...2: return 3
        case 3...4: return 2
        default: return 1
        }
    }

    var equationPieces: [String] {
        Array(emojiClue).map(String.init).prefix(3).map { $0 }
    }

    var homeCardClueText: String {
        equationPieces.joined(separator: " + ")
    }

    func equationResultText(isSolved: Bool) -> String {
        guard isSolved, let title, !title.isEmpty else { return "?" }
        return title
    }

    // MARK: - Archive Puzzles (50 classic movies for offline play)

    static let archivePuzzles: [DailyPuzzle] = [
        DailyPuzzle(date: "archive", puzzleID: "archive-001", mediaType: .movie, tmdbID: 597,
                     title: "Titanic", emojiClue: "🚢🧊❤️",
                     hint1: "Released in 1997", hint2: "Directed by James Cameron",
                     acceptedAnswers: ["titanic", "the titanic"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-002", mediaType: .movie, tmdbID: 603,
                     title: "The Matrix", emojiClue: "🕶️💊🤖",
                     hint1: "Released in 1999", hint2: "Features Neo and Morpheus",
                     acceptedAnswers: ["the matrix", "matrix"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-003", mediaType: .movie, tmdbID: 329,
                     title: "Jurassic Park", emojiClue: "🦖🌴🚙",
                     hint1: "Directed by Steven Spielberg", hint2: "Dinosaurs are brought back to life",
                     acceptedAnswers: ["jurassic park"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-004", mediaType: .movie, tmdbID: 27205,
                     title: "Inception", emojiClue: "😴🌀🏙️",
                     hint1: "Released in 2010", hint2: "Dreams inside dreams",
                     acceptedAnswers: ["inception"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-005", mediaType: .movie, tmdbID: 346698,
                     title: "Barbie", emojiClue: "🎀💄🏠",
                     hint1: "Released in 2023", hint2: "Directed by Greta Gerwig",
                     acceptedAnswers: ["barbie"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-006", mediaType: .movie, tmdbID: 109445,
                     title: "Frozen", emojiClue: "❄️👸⛄",
                     hint1: "Released in 2013", hint2: "Features the song 'Let It Go'",
                     acceptedAnswers: ["frozen"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-007", mediaType: .movie, tmdbID: 8587,
                     title: "The Lion King", emojiClue: "🦁👑🌅",
                     hint1: "Released in 1994", hint2: "Set in the African savanna",
                     acceptedAnswers: ["the lion king", "lion king"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-008", mediaType: .movie, tmdbID: 808,
                     title: "Shrek", emojiClue: "🟢🧅🏰",
                     hint1: "Released in 2001", hint2: "Features a talking donkey sidekick",
                     acceptedAnswers: ["shrek"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-009", mediaType: .movie, tmdbID: 12,
                     title: "Finding Nemo", emojiClue: "🐠🔍🌊",
                     hint1: "Released in 2003", hint2: "A father searches the ocean for his son",
                     acceptedAnswers: ["finding nemo"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-010", mediaType: .movie, tmdbID: 862,
                     title: "Toy Story", emojiClue: "🤠🚀🧸",
                     hint1: "Released in 1995", hint2: "First fully computer-animated feature film",
                     acceptedAnswers: ["toy story"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-011", mediaType: .movie, tmdbID: 238,
                     title: "The Godfather", emojiClue: "🤵🌹🐴",
                     hint1: "Released in 1972", hint2: "Directed by Francis Ford Coppola",
                     acceptedAnswers: ["the godfather", "godfather"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-012", mediaType: .movie, tmdbID: 13,
                     title: "Forrest Gump", emojiClue: "🏃🍫🪶",
                     hint1: "Released in 1994", hint2: "Stars Tom Hanks on a park bench",
                     acceptedAnswers: ["forrest gump"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-013", mediaType: .movie, tmdbID: 20352,
                     title: "Despicable Me", emojiClue: "🦹‍♂️👧🍌",
                     hint1: "An animated comedy about a supervillain", hint2: "He adopts three sisters and has yellow helpers",
                     acceptedAnswers: ["despicable me"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-014", mediaType: .movie, tmdbID: 920,
                     title: "Cars", emojiClue: "🏎️🏁⚡",
                     hint1: "An animated racing adventure", hint2: "Lightning McQueen learns life is more than winning",
                     acceptedAnswers: ["cars", "disney cars", "pixar cars"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-015", mediaType: .movie, tmdbID: 155,
                     title: "The Dark Knight", emojiClue: "🦇🃏🌃",
                     hint1: "Released in 2008", hint2: "Features Heath Ledger as the Joker",
                     acceptedAnswers: ["the dark knight", "dark knight"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-016", mediaType: .movie, tmdbID: 157336,
                     title: "Interstellar", emojiClue: "🚀🕳️🌽",
                     hint1: "Released in 2014", hint2: "Directed by Christopher Nolan",
                     acceptedAnswers: ["interstellar"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-017", mediaType: .movie, tmdbID: 98,
                     title: "Gladiator", emojiClue: "⚔️🏟️👎",
                     hint1: "Released in 2000", hint2: "Stars Russell Crowe as a Roman general",
                     acceptedAnswers: ["gladiator"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-018", mediaType: .movie, tmdbID: 578,
                     title: "Jaws", emojiClue: "🦈🏖️🚤",
                     hint1: "Released in 1975", hint2: "Directed by Steven Spielberg",
                     acceptedAnswers: ["jaws"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-019", mediaType: .movie, tmdbID: 601,
                     title: "E.T. the Extra-Terrestrial", emojiClue: "👽🚲🌕",
                     hint1: "Released in 1982", hint2: "A boy befriends an alien",
                     acceptedAnswers: ["et", "e.t.", "et the extra-terrestrial", "e.t. the extra-terrestrial"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-020", mediaType: .movie, tmdbID: 105,
                     title: "Back to the Future", emojiClue: "🚗⚡🕐",
                     hint1: "Released in 1985", hint2: "Features a time-traveling DeLorean",
                     acceptedAnswers: ["back to the future"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-021", mediaType: .movie, tmdbID: 620,
                     title: "Ghostbusters", emojiClue: "👻🚫🔫",
                     hint1: "Released in 1984", hint2: "Who you gonna call?",
                     acceptedAnswers: ["ghostbusters", "ghost busters"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-022", mediaType: .movie, tmdbID: 671,
                     title: "Harry Potter and the Philosopher's Stone", emojiClue: "⚡🧙‍♂️🏰",
                     hint1: "Released in 2001", hint2: "A boy discovers he is a wizard",
                     acceptedAnswers: ["harry potter", "harry potter and the philosophers stone", "harry potter and the sorcerers stone"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-023", mediaType: .movie, tmdbID: 120,
                     title: "The Lord of the Rings: The Fellowship of the Ring", emojiClue: "💍🧝🌋",
                     hint1: "Released in 2001", hint2: "Directed by Peter Jackson",
                     acceptedAnswers: ["lord of the rings", "the lord of the rings", "fellowship of the ring", "the fellowship of the ring"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-024", mediaType: .movie, tmdbID: 11,
                     title: "Star Wars", emojiClue: "⭐⚔️🌌",
                     hint1: "Released in 1977", hint2: "Created by George Lucas",
                     acceptedAnswers: ["star wars", "star wars a new hope", "a new hope"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-025", mediaType: .movie, tmdbID: 85,
                     title: "Raiders of the Lost Ark", emojiClue: "🤠🐍📦",
                     hint1: "Released in 1981", hint2: "Stars Harrison Ford with a whip",
                     acceptedAnswers: ["raiders of the lost ark", "indiana jones", "indiana jones and the raiders of the lost ark"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-026", mediaType: .movie, tmdbID: 630,
                     title: "The Wizard of Oz", emojiClue: "🌪️👠🦁",
                     hint1: "Released in 1939", hint2: "Features a yellow brick road",
                     acceptedAnswers: ["the wizard of oz", "wizard of oz"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-027", mediaType: .movie, tmdbID: 1366,
                     title: "Rocky", emojiClue: "🥊🏃🔔",
                     hint1: "Released in 1976", hint2: "Stars Sylvester Stallone as a boxer",
                     acceptedAnswers: ["rocky"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-028", mediaType: .movie, tmdbID: 621,
                     title: "Grease", emojiClue: "🎤🚗💃",
                     hint1: "Released in 1978", hint2: "Stars John Travolta and Olivia Newton-John",
                     acceptedAnswers: ["grease"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-029", mediaType: .movie, tmdbID: 744,
                     title: "Top Gun", emojiClue: "✈️😎🏐",
                     hint1: "Released in 1986", hint2: "Stars Tom Cruise as a fighter pilot",
                     acceptedAnswers: ["top gun"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-030", mediaType: .movie, tmdbID: 585,
                     title: "Monsters, Inc.", emojiClue: "👹🚪😱",
                     hint1: "Animated monsters collect children's screams", hint2: "Sulley and Mike work behind magical closet doors",
                     acceptedAnswers: ["monsters inc", "monsters incorporated"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-031", mediaType: .movie, tmdbID: 9806,
                     title: "The Incredibles", emojiClue: "🦸‍♀️👨‍👩‍👧‍👦💥",
                     hint1: "An animated family hides its superpowers", hint2: "Mr. Incredible and Elastigirl return to hero work",
                     acceptedAnswers: ["the incredibles", "incredibles"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-032", mediaType: .movie, tmdbID: 771,
                     title: "Home Alone", emojiClue: "🏠😱🪤",
                     hint1: "Released in 1990", hint2: "A kid defends his house from burglars",
                     acceptedAnswers: ["home alone"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-033", mediaType: .movie, tmdbID: 9502,
                     title: "Kung Fu Panda", emojiClue: "🐼🥋🐉",
                     hint1: "An animated panda dreams of martial arts", hint2: "Po is unexpectedly chosen as the Dragon Warrior",
                     acceptedAnswers: ["kung fu panda"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-034", mediaType: .movie, tmdbID: 218,
                     title: "The Terminator", emojiClue: "🤖🔫⏳",
                     hint1: "Released in 1984", hint2: "Stars Arnold Schwarzenegger",
                     acceptedAnswers: ["the terminator", "terminator"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-035", mediaType: .movie, tmdbID: 150540,
                     title: "Inside Out", emojiClue: "😊😢🧠",
                     hint1: "Animated emotions guide a young girl's mind", hint2: "Joy and Sadness must restore Riley's memories",
                     acceptedAnswers: ["inside out", "insideout"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-036", mediaType: .movie, tmdbID: 19995,
                     title: "Avatar", emojiClue: "🔵🌿🏹",
                     hint1: "Released in 2009", hint2: "Set on the moon Pandora",
                     acceptedAnswers: ["avatar"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-037", mediaType: .movie, tmdbID: 354912,
                     title: "Coco", emojiClue: "🎸💀🌺",
                     hint1: "Released in 2017", hint2: "Set during the Day of the Dead",
                     acceptedAnswers: ["coco"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-038", mediaType: .movie, tmdbID: 14160,
                     title: "Up", emojiClue: "🎈🏠👴",
                     hint1: "Released in 2009", hint2: "A house flies with thousands of balloons",
                     acceptedAnswers: ["up"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-039", mediaType: .movie, tmdbID: 10681,
                     title: "WALL-E", emojiClue: "🤖🌱🚀",
                     hint1: "Released in 2008", hint2: "A lonely robot on a deserted Earth",
                     acceptedAnswers: ["wall-e", "wall e", "walle"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-040", mediaType: .movie, tmdbID: 2062,
                     title: "Ratatouille", emojiClue: "🐀👨‍🍳🍝",
                     hint1: "Released in 2007", hint2: "A rat who dreams of being a chef in Paris",
                     acceptedAnswers: ["ratatouille"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-041", mediaType: .movie, tmdbID: 557,
                     title: "Spider-Man", emojiClue: "🕷️🕸️🏙️",
                     hint1: "Released in 2002", hint2: "Stars Tobey Maguire",
                     acceptedAnswers: ["spider-man", "spider man", "spiderman"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-042", mediaType: .movie, tmdbID: 268,
                     title: "Batman", emojiClue: "🦇🌃🃏",
                     hint1: "Released in 1989", hint2: "Directed by Tim Burton",
                     acceptedAnswers: ["batman"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-043", mediaType: .movie, tmdbID: 1726,
                     title: "Iron Man", emojiClue: "🔴🤖💥",
                     hint1: "Released in 2008", hint2: "Stars Robert Downey Jr. as Tony Stark",
                     acceptedAnswers: ["iron man", "ironman"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-044", mediaType: .movie, tmdbID: 24428,
                     title: "The Avengers", emojiClue: "🦸‍♂️🦸‍♀️🌍",
                     hint1: "Released in 2012", hint2: "Earth's mightiest heroes assemble",
                     acceptedAnswers: ["the avengers", "avengers"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-045", mediaType: .movie, tmdbID: 297762,
                     title: "Wonder Woman", emojiClue: "👸⚔️🛡️",
                     hint1: "Released in 2017", hint2: "Stars Gal Gadot as an Amazon warrior",
                     acceptedAnswers: ["wonder woman"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-046", mediaType: .movie, tmdbID: 284054,
                     title: "Black Panther", emojiClue: "🐆👑🌍",
                     hint1: "Released in 2018", hint2: "Set in the fictional nation of Wakanda",
                     acceptedAnswers: ["black panther"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-047", mediaType: .movie, tmdbID: 277834,
                     title: "Moana", emojiClue: "🌊⛵🐔",
                     hint1: "Released in 2016", hint2: "A Polynesian girl sails across the ocean",
                     acceptedAnswers: ["moana"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-048", mediaType: .movie, tmdbID: 568124,
                     title: "Encanto", emojiClue: "🏠✨🦋",
                     hint1: "Released in 2021", hint2: "A magical family in Colombia",
                     acceptedAnswers: ["encanto"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-049", mediaType: .movie, tmdbID: 10144,
                     title: "The Little Mermaid", emojiClue: "🧜‍♀️🐚🏰",
                     hint1: "Released in 1989", hint2: "A mermaid trades her voice for legs",
                     acceptedAnswers: ["the little mermaid", "little mermaid"], source: "archive", generatedAt: ""),
        DailyPuzzle(date: "archive", puzzleID: "archive-050", mediaType: .movie, tmdbID: 269149,
                     title: "Zootopia", emojiClue: "🐰🦊🏙️",
                     hint1: "An animated city where animals live like people", hint2: "A rabbit police officer teams up with a fox",
                     acceptedAnswers: ["zootopia", "zootropolis"], source: "archive", generatedAt: ""),
    ]
}

// Identity-based answers avoid spelling, localization, and sequel ambiguity.
struct MovieQuizChoice: Codable, Equatable, Identifiable {
    let id: Int
    let title: String
}

struct MovieQuizRound: Codable, Equatable {
    let answerID: Int
    let choices: [MovieQuizChoice]
    let backdropPath: String?
    let posterPath: String?

    static func choices(answer: MovieQuizChoice, candidates: [MovieQuizChoice], seed: String) -> [MovieQuizChoice] {
        var ids: Set<Int> = [answer.id]
        var titles: Set<String> = [DailyPuzzle.normalize(answer: answer.title)]
        var result = [answer]
        for candidate in candidates {
            let title = DailyPuzzle.normalize(answer: candidate.title)
            guard !title.isEmpty, !ids.contains(candidate.id), !titles.contains(title) else { continue }
            ids.insert(candidate.id)
            titles.insert(title)
            result.append(candidate)
            if result.count == 4 { break }
        }
        guard result.count == 4 else { return [] }
        // Stable across relaunches; the correct answer is not tied to a fixed slot.
        func rank(_ id: Int) -> UInt64 {
            (seed + ":" + String(id)).utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        }
        return result.sorted { rank($0.id) < rank($1.id) }
    }
}

struct MovieQuizState: Codable, Equatable {
    let round: MovieQuizRound
    private(set) var eliminatedIDs: Set<Int> = []
    private(set) var isSolved = false
    private(set) var skipped = false
    private(set) var requestedHint = false
    private(set) var importedLegacyResult: Bool? = nil
    private(set) var revealedTiles: Set<Int>? = nil
    private(set) var zoomStep: Int? = nil
    private(set) var imageUnavailable: Bool? = nil
    var isFinished: Bool { isSolved || skipped }
    var attempts: Int { eliminatedIDs.count + (isSolved ? 1 : 0) }
    var hintRevealed: Bool { requestedHint || !eliminatedIDs.isEmpty || imageUnavailable == true }
    var visibleTileIndices: Set<Int> { revealedTiles ?? Set(0..<9) }
    var zoomScale: Double {
        switch zoomStep {
        case 0: return 3
        case 1: return 1.8
        default: return 1
        }
    }
    var availablePoints: Int {
        let penalty = zoomStep ?? revealedTiles.map { max(0, ($0.count - 1) / 3) } ?? 0
        let minimum = zoomStep != nil || revealedTiles != nil || imageUnavailable == true ? 1 : 0
        return max(minimum, 3 - penalty - eliminatedIDs.count - (requestedHint ? 1 : 0))
    }
    var points: Int { isSolved && importedLegacyResult != true ? availablePoints : 0 }

    mutating func enableTileReveal() {
        guard !isFinished, revealedTiles == nil, zoomStep == nil, imageUnavailable != true else { return }
        revealedTiles = [4]
    }

    mutating func enableZoomReveal() {
        guard !isFinished, zoomStep == nil, revealedTiles == nil, imageUnavailable != true else { return }
        zoomStep = 0
    }

    @discardableResult
    mutating func zoomOut() -> Bool {
        guard !isFinished, let step = zoomStep, (0..<2).contains(step) else { return false }
        zoomStep = step + 1
        return true
    }

    @discardableResult
    mutating func revealTile(_ index: Int) -> Bool {
        guard !isFinished, (0..<9).contains(index), var tiles = revealedTiles,
              tiles.insert(index).inserted else { return false }
        revealedTiles = tiles
        return true
    }

    mutating func disableTileRevealForUnavailableImage() {
        guard !isFinished else { return }
        revealedTiles = nil
        zoomStep = nil
        imageUnavailable = true
    }

    @discardableResult
    mutating func choose(_ id: Int) -> Bool {
        guard !isFinished, !eliminatedIDs.contains(id), round.choices.contains(where: { $0.id == id }) else { return false }
        if id == round.answerID { isSolved = true }
        else { eliminatedIDs.insert(id) }
        return true
    }

    mutating func restoreLegacyCompletion(solved: Bool) {
        importedLegacyResult = true
        isSolved = solved
        skipped = !solved
    }

    mutating func revealHint() { if !isFinished { requestedHint = true } }
    mutating func skip() { if !isFinished { skipped = true } }
}

struct MovieQuizParticipationStore {
    var defaults: UserDefaults = .standard
    var calendar: Calendar = .autoupdatingCurrent

    @discardableResult
    func recordCompletedRun(at date: Date = Date()) -> Int {
        let day = calendar.startOfDay(for: date)
        let previous = defaults.object(forKey: "movieQuizParticipationDate") as? Date
        let current = defaults.integer(forKey: "movieQuizParticipationStreak")
        if let previous, calendar.isDate(previous, inSameDayAs: day) { return current }
        let consecutive = previous.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
            .map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let streak = consecutive ? current + 1 : 1
        defaults.set(day, forKey: "movieQuizParticipationDate")
        defaults.set(streak, forKey: "movieQuizParticipationStreak")
        return streak
    }
}

struct MovieQuizMedia: Decodable {
    struct Recommendations: Decodable {
        struct Title: Decodable {
            let id: Int
            let title: String?
            let name: String?
            let adult: Bool?
        }
        let results: [Title]
    }
    struct Images: Decodable {
        struct Backdrop: Decodable {
            let filePath: String
            let iso6391: String?
            let voteAverage: Double?
        }
        let backdrops: [Backdrop]
    }
    let id: Int
    let title: String?
    let name: String?
    let posterPath: String?
    let recommendations: Recommendations?
    let images: Images?

    var textlessBackdropPath: String? {
        images?.backdrops.filter { $0.iso6391 == nil }
            .sorted { ($0.voteAverage ?? 0) > ($1.voteAverage ?? 0) }
            .first?.filePath
    }
}
