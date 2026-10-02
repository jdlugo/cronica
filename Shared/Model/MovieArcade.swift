import Foundation

/// Use the same localized copy for SwiftUI, saved feedback and offline clues.
func arcadeText(_ key: String, _ arguments: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "Movie Arcade")
    return arguments.isEmpty ? format : String(format: format, locale: Locale.current, arguments: arguments)
}

struct ArcadeFilm: Equatable, Identifiable {
    let id: Int
    let title: String
    let year: Int
    let leadID: Int
    let cast: [Int]
    let plot: String
    var localizedPlot: String { arcadeText(plot) }
}
struct ArcadeActor: Equatable, Identifiable { let id: Int; let name: String }

enum ArcadeKind: String, Codable, CaseIterable, Identifiable {
    case scene, scramble, casting, timeline, oddOneOut, doubleFeature, detective, memory, heist, directorsCut
    var id: String { rawValue }
    static var miniGames: [Self] { allCases.filter { $0 != .scene } }
    var title: String {
        switch self {
        case .directorsCut: arcadeText("Director’s Cut")
        case .heist: arcadeText("Movie Heist")
        case .scene: arcadeText("Scene Spotter")
        case .scramble: arcadeText("Movie Scramble")
        case .casting: arcadeText("Casting Call")
        case .timeline: arcadeText("Before or After?")
        case .oddOneOut: arcadeText("Odd Movie Out")
        case .doubleFeature: arcadeText("Double Feature")
        case .detective: arcadeText("Movie Detective")
        case .memory: arcadeText("Poster Memory")
        }
    }
    var symbol: String {
        switch self {
        case .directorsCut: "film.stack"
        case .heist: "lock.shield"
        case .scene: "photo"
        case .scramble: "square.grid.2x2"
        case .casting: "person.crop.rectangle.stack"
        case .timeline: "arrow.left.arrow.right"
        case .oddOneOut: "magnifyingglass"
        case .doubleFeature: "link"
        case .detective: "eye"
        case .memory: "rectangle.on.rectangle"
        }
    }
    var instruction: String {
        switch self {
        case .directorsCut: arcadeText("Build a triple feature in release order. Tap the earliest movie first, then work forward.")
        case .heist: arcadeText("Crack three locks: a scene, a star, and a secret plot. Each correct answer reveals a vault digit.")
        case .scene: arcadeText("Recognize the scene? Tap the movie.")
        case .scramble: arcadeText("Hold and drag a tile onto another to swap. Or tap two tiles. Build the scene, then name the movie.")
        case .casting: arcadeText("Which actor appears in this movie? Tap a portrait.")
        case .timeline: arcadeText("Before or after the anchor movie? Place three films in time.")
        case .oddOneOut: arcadeText("Three movies came out in the 1990s. Which one did not?")
        case .doubleFeature: arcadeText("Pair movies starring the same actor. Each star connects two movies.")
        case .detective: arcadeText("Choose the clues you want, then name the movie. Fewer clues earn more points.")
        case .memory: arcadeText("Flip two cards to find a matching pair. Find all three to finish; the year question is optional.")
        }
    }
}

enum ArcadeEraRule: Int, CaseIterable {
    case nineties, before2000, since2000, since2010
    var description: String {
        switch self {
        case .nineties: arcadeText("in the 1990s")
        case .before2000: arcadeText("before 2000")
        case .since2000: arcadeText("in 2000 or later")
        case .since2010: arcadeText("in 2010 or later")
        }
    }
    func includes(_ year: Int) -> Bool {
        switch self {
        case .nineties: (1990...1999).contains(year)
        case .before2000: year < 2000
        case .since2000: year >= 2000
        case .since2010: year >= 2010
        }
    }
}

enum ArcadeClue: String, Codable, CaseIterable { case plot, cast, year }
enum ArcadeAction {
    case choose(Int), tile(Int), card(Int), timeline(Bool), clue(ArcadeClue)
    case swapTiles(from: Int, to: Int)
    case nextHeist, nextTimeline, clearMismatch, assemble, finishMatching, skip
}

/// Seeded, offline rules. UI animation and storage never decide a round's outcome.
struct ArcadeRound: Codable, Equatable {
    let kind: ArcadeKind
    let seed: Int
    let films: [Int]
    let options: [Int]
    let answer: Int
    var board: [Int] = []
    var selected: [Int] = []
    var matched: Set<Int> = []
    var eliminated: Set<Int> = []
    var clues: Set<ArcadeClue> = []
    var mistakes = 0
    var step = 0
    var awaitingNext = false
    var assisted = false
    var isComplete = false
    var skipped = false
    var feedback: String?
    // Optional fields keep saves from the original rules decodable.
    var pairActors: [Int]?
    var matchingPoints: Int?
    var memoryBonusAnswered: Bool?

    var heistFilm: ArcadeFilm { ArcadeCatalog.film(films[min(step, films.count - 1)]) }
    var heistAnswer: Int { step == 1 ? heistFilm.leadID : heistFilm.id }
    var heistOptions: [Int] {
        var rng = ArcadeRandom(seed: UInt64(truncatingIfNeeded: seed &+ step &* 131))
        let wrong = step == 1
            ? ArcadeCatalog.actors.filter { !heistFilm.cast.contains($0.id) }.map(\.id)
            : ArcadeCatalog.films.filter { $0.id != heistFilm.id }.map(\.id)
        return ([heistAnswer] + wrong.shuffled(using: &rng).prefix(3)).shuffled(using: &rng)
    }
    var vaultCode: String { films.map { String($0 % 10) }.joined() }
    var eraRule: ArcadeEraRule { Self.eraRule(seed: seed) }
    private static func eraRule(seed: Int) -> ArcadeEraRule { ArcadeEraRule.allCases[Int(UInt64(truncatingIfNeeded: seed) % 4)] }
    var instruction: String {
        if kind == .oddOneOut { return arcadeText("Three movies came out %@. Which one did not?", eraRule.description) }
        if kind == .doubleFeature {
            return arcadeText("Pair movies starring the same actor: %@.", pairingActorIDs.map(Self.pairActorName).joined(separator: ", "))
        }
        return kind.instruction
    }
    var availablePoints: Int { max(1, 3 - mistakes - clues.count - (assisted ? 1 : 0)) }
    var points: Int { isComplete && !skipped ? (kind == .memory ? matchingPoints ?? availablePoints : availablePoints) : 0 }
    var canFinishMatching: Bool { kind == .memory && matched.count == 6 && !isComplete }
    var film: ArcadeFilm { ArcadeCatalog.film(films[0]) }
    /// Only disclosed answers belong in discovery; future rounds stay hidden.
    var discoveryFilmIDs: [Int] {
        guard isComplete else { return [] }
        switch kind {
        case .oddOneOut: return [answer]
        case .heist, .memory, .doubleFeature, .timeline, .directorsCut: return films
        default: return [film.id]
        }
    }
    var canGuess: Bool {
        switch kind {
        case .scramble: board == [0, 1, 2, 3]
        case .memory: matched.count == 6
        case .timeline, .doubleFeature, .heist, .directorsCut: false
        default: true
        }
    }
    /// One optional guide per trivia round. The player still makes every choice.
    var knowledgeClue: ArcadeClue? {
        guard !isComplete, !awaitingNext else { return nil }
        switch kind {
        case .casting, .doubleFeature: return .cast
        case .timeline, .oddOneOut, .directorsCut: return .year
        case .heist: return step == 1 ? .cast : nil
        default: return nil
        }
    }
    var reveal: String {
        switch kind {
        case .heist: arcadeText("Vault %@ opened! Recovered: %@.\nThree locks. One clean getaway.", vaultCode, ArcadeCatalog.film(films[2]).title)
        case .casting: arcadeText("%@ appears in %@.", ArcadeCatalog.actor(answer).name, film.title)
        case .timeline, .directorsCut: films.map { ArcadeCatalog.film($0) }.sorted { $0.year < $1.year }.map { "\($0.year) · \($0.title)" }.joined(separator: "\n")
        case .oddOneOut: arcadeText("%@ was released in %@. The other three came out %@.", ArcadeCatalog.film(answer).title, String(ArcadeCatalog.film(answer).year), eraRule.description)
        case .doubleFeature:
            (0..<3).map { index in
                "\(ArcadeCatalog.film(films[index * 2]).title) + \(ArcadeCatalog.film(films[index * 2 + 1]).title) · \(Self.pairActorName(pairingActorIDs[index]))"
            }.joined(separator: "\n")
        case .memory: memoryBonusAnswered == false ? arcadeText("All three poster pairs found!") : arcadeText("%@ was released in %@.", film.title, String(film.year))
        default: "\(film.title) (\(film.year))\n\(film.localizedPlot)"
        }
    }

    static func make(kind: ArcadeKind, seed: Int) -> Self {
        var rng = ArcadeRandom(seed: UInt64(truncatingIfNeeded: seed))
        let pool = ArcadeCatalog.films.shuffled(using: &rng)
        let film = pool[0]
        var films = [film.id]
        var answer = film.id
        var options = ([film] + Array(pool.dropFirst().prefix(3))).map(\.id).shuffled(using: &rng)
        var board: [Int] = []
        switch kind {
        case .casting:
            answer = film.leadID
            let wrong = ArcadeCatalog.actors.filter { !film.cast.contains($0.id) }.shuffled(using: &rng).prefix(3).map(\.id)
            options = ([answer] + wrong).shuffled(using: &rng)
        case .timeline:
            var years: Set<Int> = [film.year]
            for candidate in pool.dropFirst() where !years.contains(candidate.year) && films.count < 4 {
                films.append(candidate.id); years.insert(candidate.year)
            }
            options = []
        case .oddOneOut:
            let rule = eraRule(seed: seed)
            let inside = pool.filter { rule.includes($0.year) }.prefix(3)
            let outside = pool.first { !rule.includes($0.year) }!
            answer = outside.id
            films = (inside.map(\.id) + [answer]).shuffled(using: &rng)
            options = films
        case .doubleFeature:
            let pairing = pairingSets[Int(UInt64(truncatingIfNeeded: seed) % UInt64(pairingSets.count))]
            films = pairing.films
            board = films.shuffled(using: &rng); options = []
        case .memory:
            films = Array(pool.prefix(3)).map(\.id)
            board = (films + films).shuffled(using: &rng)
            answer = film.year
            options = [film.year, film.year - 5, film.year + 3, film.year + 8].shuffled(using: &rng)
        case .scramble:
            board = [0,1,2,3].shuffled(using: &rng)
            if board == [0,1,2,3] { board.swapAt(0, 3) }
        case .directorsCut:
            var years: Set<Int> = []
            films = pool.filter { years.insert($0.year).inserted }.prefix(3).map(\.id)
            board = films.shuffled(using: &rng)
            let ordered = films.sorted { ArcadeCatalog.film($0).year < ArcadeCatalog.film($1).year }
            if board == ordered { board.swapAt(0, 2) }
            options = board
        case .heist: films = Array(pool.prefix(3)).map(\.id)
        case .scene, .detective: break
        }
        var result = Self(kind: kind, seed: seed, films: films, options: options, answer: answer, board: board)
        if kind == .doubleFeature { result.pairActors = pairingSets[Int(UInt64(truncatingIfNeeded: seed) % UInt64(pairingSets.count))].actors }
        return result
    }

    private struct PairingSet {
        let films: [Int]
        let actors: [Int]
    }
    // Every relationship is checked against the starter pack's verified credit lists.
    // Alternate sets use existing posters and never require a new portrait asset.
    private static let pairingSets: [PairingSet] = [
        .init(films: [597, 27205, 603, 245891, 346698, 313369], actors: [6193, 6384, 30614]),
        .init(films: [27205, 157336, 603, 245891, 346698, 313369], actors: [3895, 6384, 30614]),
        .init(films: [597, 27205, 329, 299534, 346698, 313369], actors: [6193, 2231, 30614]),
        .init(films: [27205, 157336, 19995, 299534, 603, 245891], actors: [3895, 8691, 6384]),
        .init(films: [597, 27205, 19995, 299534, 346698, 313369], actors: [6193, 8691, 30614]),
        .init(films: [27205, 157336, 329, 299534, 346698, 313369], actors: [3895, 2231, 30614]),
        .init(films: [597, 27205, 19995, 299534, 603, 245891], actors: [6193, 8691, 6384])
    ]
    private var pairingActorIDs: [Int] { pairActors ?? [6193, 6384, 30614] }
    static func pairActorName(_ id: Int) -> String {
        switch id {
        case 3895: return "Michael Caine"
        case 8691: return "Zoe Saldaña"
        case 2231: return "Samuel L. Jackson"
        default: return ArcadeCatalog.actors.first { $0.id == id }?.name ?? "Unknown actor"
        }
    }
    func pairKey(_ id: Int) -> Int {
        guard kind == .doubleFeature else { return id }
        guard let index = films.firstIndex(of: id), pairingActorIDs.indices.contains(index / 2) else { return -1 }
        return pairingActorIDs[index / 2]
    }

    @discardableResult mutating func apply(_ action: ArcadeAction) -> Bool {
        guard !isComplete else { return false }
        switch action {
        case .finishMatching:
            guard canFinishMatching else { return false }
            if matchingPoints == nil { matchingPoints = availablePoints }
            memoryBonusAnswered = false; isComplete = true; feedback = nil
        case .skip:
            skipped = true; isComplete = true; selected = []; feedback = nil
        case .nextHeist:
            guard kind == .heist, awaitingNext, step < 2 else { return false }
            step += 1; awaitingNext = false; eliminated = []; feedback = nil
        case .choose(let id):
            if kind == .directorsCut {
                guard let index = board.firstIndex(of: id), !selected.contains(index), !eliminated.contains(id) else { return false }
                let ordered = films.sorted { ArcadeCatalog.film($0).year < ArcadeCatalog.film($1).year }
                if id == ordered[selected.count] {
                    selected.append(index); eliminated = []
                    feedback = arcadeText("%@ · %@. In the cut!", ArcadeCatalog.film(id).title, String(ArcadeCatalog.film(id).year))
                    if selected.count == 3 { isComplete = true } else { step += 1 }
                } else {
                    eliminated.insert(id); mistakes += 1
                    feedback = arcadeText("There’s an earlier film still on the board. Try that one first.")
                }
                return true
            }
            if kind == .heist {
                guard !awaitingNext, heistOptions.contains(id), !eliminated.contains(id) else { return false }
                if id == heistAnswer {
                    feedback = arcadeText("Lock %@ cracked. Digit %@ recovered!", String(step + 1), String(films[step] % 10))
                    if step == 2 { isComplete = true } else { awaitingNext = true }
                } else {
                    eliminated.insert(id); mistakes += 1
                    feedback = arcadeText("The lock held. That option is ruled out—try another.")
                }
                return true
            }
            guard canGuess, options.contains(id), !eliminated.contains(id) else { return false }
            if id == answer {
                if kind == .memory {
                    if matchingPoints == nil { matchingPoints = availablePoints }
                    memoryBonusAnswered = true
                }
                isComplete = true; feedback = nil
            }
            else {
                eliminated.insert(id); mistakes += 1
                switch kind {
                case .casting: feedback = arcadeText("%@ is not in this cast. Try another portrait.", ArcadeCatalog.actor(id).name)
                case .oddOneOut: feedback = arcadeText("%@ came out in %@, so it belongs in the “%@” group.", ArcadeCatalog.film(id).title, String(ArcadeCatalog.film(id).year), eraRule.description)
                case .memory: feedback = arcadeText("Not that year. Think of the %@s.", String(film.year / 10 * 10))
                default: feedback = film.localizedPlot
                }
            }
        case .tile(let index):
            guard kind == .scramble, board.indices.contains(index), board != [0,1,2,3] else { return false }
            if selected == [index] { selected = [] }
            else if let first = selected.first {
                board.swapAt(first, index); selected = []
                feedback = board == [0,1,2,3] ? arcadeText("Scene restored! Now name the movie.") : nil
            } else { selected = [index] }
        case .swapTiles(let source, let destination):
            guard kind == .scramble, board != [0,1,2,3], source != destination,
                  board.indices.contains(source), board.indices.contains(destination) else { return false }
            board.swapAt(source, destination); selected = []
            feedback = board == [0,1,2,3] ? arcadeText("Scene restored! Now name the movie.") : nil
        case .assemble:
            guard kind == .scramble, board != [0,1,2,3] else { return false }
            board = [0,1,2,3]; selected = []; assisted = true
            feedback = arcadeText("Scene restored. Which movie is it?")
        case .card(let index):
            guard kind == .memory || kind == .doubleFeature,
                  board.indices.contains(index), !matched.contains(index), !selected.contains(index), selected.count < 2 else { return false }
            selected.append(index)
            if selected.count == 2 {
                if pairKey(board[selected[0]]) == pairKey(board[selected[1]]) {
                    matched.formUnion(selected)
                    feedback = kind == .doubleFeature ? arcadeText("Connected by %@!", Self.pairActorName(pairKey(board[index]))) : arcadeText("A perfect pair!")
                    selected = []
                    if matched.count == 6 {
                        if kind == .doubleFeature { isComplete = true }
                        else {
                            matchingPoints = availablePoints
                            feedback = arcadeText("All pairs found! Finish now, or try the optional year question.")
                        }
                    }
                } else { mistakes += 1; feedback = arcadeText("Not a pair. Take a look, then try again.") }
            }
        case .clearMismatch:
            guard (kind == .memory || kind == .doubleFeature), selected.count == 2 else { return false }
            selected = []; feedback = nil
        case .clue(let clue):
            guard (kind == .detective || knowledgeClue == clue), !clues.contains(clue) else { return false }
            clues.insert(clue)
        case .timeline(let later):
            guard kind == .timeline, !awaitingNext, step < 3 else { return false }
            let incoming = ArcadeCatalog.film(films[step + 1])
            let correct = (incoming.year > film.year) == later
            if !correct { mistakes += 1 }
            feedback = arcadeText(incoming.year < film.year ? "%@ came out in %@, before %@ (%@)." : "%@ came out in %@, after %@ (%@).", incoming.title, String(incoming.year), film.title, String(film.year))
            if step == 2 { isComplete = true } else { awaitingNext = true }
        case .nextTimeline:
            guard kind == .timeline, awaitingNext, step < 2 else { return false }
            step += 1; awaitingNext = false; feedback = nil
        }
        return true
    }

    /// Check decoded saves before indexing them in the UI. Catalog updates invalidate old saves.
    var isValid: Bool {
        let fresh = Self.make(kind: kind, seed: seed)
        // Original Double Feature saves used one fixed set and have no pairActors field.
        let legacyPairing = kind == .doubleFeature && pairActors == nil
        let expectedFilms = legacyPairing ? Self.pairingSets[0].films : fresh.films
        guard films == expectedFilms,
              kind != .doubleFeature || legacyPairing || pairActors == fresh.pairActors,
              matchingPoints == nil || (kind == .memory && matched.count == 6 && (1...3).contains(matchingPoints!)),
              memoryBonusAnswered == nil || (kind == .memory && matched.count == 6 && isComplete && !skipped) else { return false }
        if kind == .directorsCut {
            let ordered = films.sorted { ArcadeCatalog.film($0).year < ArcadeCatalog.film($1).year }
            guard selected.allSatisfy(board.indices.contains),
                  selected.map({ board[$0] }) == Array(ordered.prefix(selected.count)),
                  isComplete || selected.count < 3 else { return false }
        }
        if kind == .heist {
            guard (0...2).contains(step), !(awaitingNext && step == 2),
                  !isComplete || skipped || step == 2 else { return false }
        }
        guard options == fresh.options, answer == fresh.answer,
              board.sorted() == (legacyPairing ? expectedFilms.sorted() : fresh.board.sorted()), Set(selected).count == selected.count,
              selected.count <= (kind == .directorsCut ? 3 : kind == .scramble ? 1 : 2), selected.allSatisfy(board.indices.contains),
              matched.allSatisfy(board.indices.contains), selected.allSatisfy({ !matched.contains($0) }),
              eliminated.isSubset(of: Set(kind == .heist ? heistOptions : options)), (kind == .directorsCut || !eliminated.contains(kind == .heist ? heistAnswer : answer)), mistakes >= 0,
              (0...2).contains(step), !skipped || isComplete else { return false }
        return true
    }
}

struct ArcadeSession: Codable, Equatable {
    let catalogVersion: Int
    let day: String
    let isDaily: Bool
    var rounds: [ArcadeRound]
    var index = 0
    var runID: String? = UUID().uuidString
    var current: ArcadeRound { rounds[index] }
    var isComplete: Bool { index == rounds.count - 1 && current.isComplete }
    var points: Int { rounds.reduce(0) { $0 + $1.points } }
    var maximumPoints: Int { rounds.count * 3 }
    var discoveryFilmIDs: [Int] {
        var seen: Set<Int> = []
        return rounds.flatMap(\.discoveryFilmIDs).filter { seen.insert($0).inserted }
    }
    var isValid: Bool {
        catalogVersion == ArcadeCatalog.version && rounds.count == (isDaily ? 4 : 1)
        && rounds.indices.contains(index) && rounds.allSatisfy(\.isValid)
        && rounds.prefix(index).allSatisfy(\.isComplete)
    }
    static func daily(day: String) -> Self {
        let seed = stableSeed(day)
        let rotation = ArcadeKind.miniGames.filter { $0 != .heist && $0 != .directorsCut }
        let kinds = [ArcadeKind.scene] + (0..<3).map { rotation[(seed % rotation.count + $0) % rotation.count] }
        var usedFilms: Set<Int> = []
        var usedTargets: Set<Int> = []
        let rounds = kinds.enumerated().map { offset, kind in
            var roundSeed = seed &+ offset &* 97
            var round = ArcadeRound.make(kind: kind, seed: roundSeed)
            // Prefer fresh films across modes, with a bounded search for the small starter pack.
            // If every film cannot be distinct, preserve unique guessing targets first.
            var bestOverlap = Int.max
            for _ in 0..<(ArcadeCatalog.films.count * 4) {
                let candidate = ArcadeRound.make(kind: kind, seed: roundSeed)
                let target = kind == .oddOneOut ? candidate.answer : candidate.films[0]
                let overlap = Set(candidate.films).intersection(usedFilms).count
                if (kind == .doubleFeature || !usedTargets.contains(target)) && overlap < bestOverlap {
                    round = candidate; bestOverlap = overlap
                    if overlap == 0 { break }
                }
                roundSeed &+= 1
            }
            if kind != .doubleFeature { usedTargets.insert(kind == .oddOneOut ? round.answer : round.films[0]) }
            usedFilms.formUnion(round.films)
            return round
        }
        return Self(catalogVersion: ArcadeCatalog.version, day: day, isDaily: true, rounds: rounds)
    }
    static func practice(_ kind: ArcadeKind, number: Int) -> Self {
        Self(catalogVersion: ArcadeCatalog.version, day: "practice", isDaily: false,
             rounds: [.make(kind: kind, seed: number)])
    }
    @discardableResult mutating func advance() -> Bool {
        guard current.isComplete, index + 1 < rounds.count else { return false }
        index += 1; return true
    }
    static func dayKey(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    static func stableSeed(_ value: String) -> Int {
        let hash = value.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return Int(hash % 1_000_000)
    }
}

private struct ArcadeRandom: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed = seed &+ 0x9e3779b97f4a7c15
        var z = seed
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

struct ArcadeProgressStore {
    let defaults: UserDefaults
    private let prefix = "movieArcade.v1."
    func key(isDaily: Bool, kind: ArcadeKind) -> String { prefix + (isDaily ? "daily" : kind.rawValue) }
    func load(isDaily: Bool, kind: ArcadeKind = .scene, day: String = ArcadeSession.dayKey()) -> ArcadeSession? {
        guard let data = defaults.data(forKey: key(isDaily: isDaily, kind: kind)),
              var session = try? JSONDecoder().decode(ArcadeSession.self, from: data),
              session.isValid, session.isDaily == isDaily,
              isDaily ? session.day == day : session.current.kind == kind else { return nil }
        if session.runID == nil {
            session.runID = UUID().uuidString
            save(session)
        }
        return session
    }
    func save(_ session: ArcadeSession) {
        guard session.isValid, let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: key(isDaily: session.isDaily, kind: session.rounds[0].kind))
    }
    /// Keep the last two targets per mode, including sessions made by older app versions.
    /// History is tiny and retries are bounded; no content or behavior depends on the network.
    func nextPracticeSession(_ kind: ArcadeKind) -> ArcadeSession {
        let historyKey = prefix + "recentTargets." + kind.rawValue
        var recent = defaults.stringArray(forKey: historyKey) ?? []
        if let saved = load(isDaily: false, kind: kind) {
            let savedTarget = practiceTarget(saved.current)
            if recent.last != savedTarget { recent.append(savedTarget) }
        }
        recent = Array(recent.suffix(2))
        var session = ArcadeSession.practice(kind, number: nextPracticeNumber())
        for attempt in 0..<(ArcadeCatalog.films.count * 4) {
            if !recent.contains(practiceTarget(session.current)) { break }
            if attempt + 1 < ArcadeCatalog.films.count * 4 {
                session = ArcadeSession.practice(kind, number: nextPracticeNumber())
            }
        }
        recent.append(practiceTarget(session.current))
        defaults.set(Array(recent.suffix(2)), forKey: historyKey)
        return session
    }
    private func practiceTarget(_ round: ArcadeRound) -> String {
        if round.kind == .doubleFeature { return round.films.sorted().map(String.init).joined(separator: ",") }
        return String(round.kind == .oddOneOut ? round.answer : round.films[0])
    }
    func nextPracticeNumber() -> Int {
        let key = prefix + "practiceNumber"
        let next = (max(0, defaults.integer(forKey: key)) % 1_000_000) + 1
        defaults.set(next, forKey: key)
        return next
    }
}
