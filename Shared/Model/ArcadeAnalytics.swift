import Foundation

/// A content identity is shared by the same seeded challenge. A round identity
/// belongs to one saved playthrough, so replay is distinguishable from resume.
struct ArcadeAnalyticsContext {
    let runID: String
    let roundID: String
    let challengeID: String
    let contentSignature: String
    let game: String
    let mode: String
    let roundNumber: Int
    let roundCount: Int
    let catalogVersion: Int
    let points: Int
    let mistakes: Int
    let skipped: Bool
    let totalPoints: Int
    let roundComplete: Bool
    let runComplete: Bool
    let genuineRoundCount: Int
    let skippedRoundCount: Int

    init(session: ArcadeSession) {
        let round = session.current
        // Store loads migrate old sessions to a UUID. The fallback also keeps
        // callers decoding legacy JSON directly stable rather than inventing a
        // different run on every view callback.
        runID = session.runID ?? "legacy-\(session.isDaily ? "daily" : "practice")-\(session.day)-\(session.rounds[0].kind.rawValue)-\(session.rounds[0].seed)"
        roundNumber = session.index + 1
        roundID = "\(runID):\(roundNumber)"
        contentSignature = Self.contentSignature(round)
        challengeID = "v\(session.catalogVersion):\(round.kind.rawValue):\(round.seed):\(contentSignature)"
        game = round.kind.rawValue
        mode = session.isDaily ? "daily_mix" : "practice"
        roundCount = session.rounds.count
        catalogVersion = session.catalogVersion
        points = round.points
        mistakes = round.mistakes
        skipped = round.skipped
        totalPoints = session.points
        roundComplete = round.isComplete
        runComplete = session.isComplete
        genuineRoundCount = session.rounds.filter { $0.isComplete && !$0.skipped }.count
        skippedRoundCount = session.rounds.filter(\.skipped).count
    }

    var properties: [String: Any] {
        [
            "arcade_schema_version": 2,
            "run_id": runID, "round_id": roundID, "challenge_id": challengeID,
            "content_signature": contentSignature,
            "game": game, "mode": mode, "round": roundNumber,
            "round_count": roundCount, "catalog_version": catalogVersion,
            "points": points, "mistakes": mistakes, "skipped": skipped,
            "total_points": totalPoints
        ]
    }

    private static func contentSignature(_ round: ArcadeRound) -> String {
        let films: String
        switch round.kind {
        case .doubleFeature:
            // Pair grouping and credited actors matter, card positions do not.
            films = (0..<3).map { pair in
                let titles = Array(round.films[(pair * 2)..<(pair * 2 + 2)]).sorted().map(String.init).joined(separator: ",")
                return "\(round.pairKey(round.films[pair * 2])):\(titles)"
            }.sorted().joined(separator: ";")
        case .heist:
            films = round.films.map(String.init).joined(separator: ",")
        case .timeline, .memory:
            // The anchor/bonus movie is meaningful even with the same film set.
            films = "\(round.films[0]):" + round.films.dropFirst().sorted().map(String.init).joined(separator: ",")
        default:
            films = round.films.sorted().map(String.init).joined(separator: ",")
        }
        let rule = round.kind == .oddOneOut ? String(round.eraRule.rawValue) : ""
        let content = "\(round.kind.rawValue)|\(films)|\(round.options.sorted().map(String.init).joined(separator: ","))|\(rule)"
        let hash = content.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        return String(hash, radix: 16)
    }
}

struct ArcadeAnalyticsEvent {
    let name: String
    let properties: [String: Any]
}

enum ArcadeDiscoverySurface: String { case result, summary }

/// These are actual navigation/save actions, separate from gameplay completion.
enum ArcadeDiscoveryEvent {
    enum Action { case opened, added }
    static func make(_ action: Action, filmID: Int, surface: ArcadeDiscoverySurface,
                     session: ArcadeSession) -> ArcadeAnalyticsEvent? {
        if surface == .summary && !session.isComplete { return nil }
        let sourceIndex: Int?
        if surface == .result {
            sourceIndex = session.current.discoveryFilmIDs.contains(filmID) ? session.index : nil
        } else {
            sourceIndex = session.rounds.firstIndex { $0.discoveryFilmIDs.contains(filmID) }
        }
        guard let sourceIndex else { return nil }
        var source = session
        source.index = sourceIndex
        var properties = ArcadeAnalyticsContext(session: source).properties
        properties["movie_id"] = filmID
        properties["discovery_surface"] = surface.rawValue
        return ArcadeAnalyticsEvent(name: action == .opened ? "movie_arcade_movie_opened" : "movie_arcade_watchlist_added",
                                    properties: properties)
    }
}

/// Roles describe accepted interactions, never the selected film or typed input.
/// A decision (answer, completed card pair or tile swap) is an attempt; selecting
/// the first card/tile is a selection, while navigating feedback is progress.
/// Selection/help are gameplay; skip/progress do not count as a first action.
enum ArcadeAnalyticsActionRole: String {
    case attempt, selection, help, progress, skip, bonus
}

/// A bounded local journal deduplicates terminal callbacks and survived resumes.
/// Call visible from a rendered play view, not when a button creates a session;
/// call acceptedAction only after the rules engine accepts a mutation.
struct ArcadeAnalyticsJournal {
    private struct RoundState: Codable {
        var firstAction = false
        var terminal = false
        var actionCount = 0
        var attemptCount = 0
        var helpCount = 0
        var bonusAttemptCount = 0
        var accumulatedSeconds: Double = 0
        var activeSince: Date?
    }
    private struct RunState: Codable {
        var started = false
        var terminal = false
        var activeVisit = false
        var rounds: [String: RoundState] = [:]
        var updatedAt = Date()
    }
    private let defaults: UserDefaults
    private let storageKey = "movieArcade.analytics.v2"
    private var runs: [String: RunState]
    private let maximumRuns = 32

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        runs = defaults.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode([String: RunState].self, from: $0) } ?? [:]
        // Persisted clocks cannot tell when the previous process was killed.
        // Keep measured accumulated time; discard its unclosed active interval
        // rather than counting hours outside the app as play time.
        for runID in Array(runs.keys) {
            runs[runID]?.activeVisit = false
            for roundID in Array(runs[runID]?.rounds.keys ?? Dictionary<String, RoundState>().keys) {
                runs[runID]?.rounds[roundID]?.activeSince = nil
            }
        }
    }

    mutating func exposed(entry: String) -> [ArcadeAnalyticsEvent] {
        [ArcadeAnalyticsEvent(name: "movie_arcade_exposed", properties: [
            "arcade_schema_version": 2, "entry": entry
        ])]
    }

    mutating func visible(_ context: ArcadeAnalyticsContext, now: Date = Date()) -> [ArcadeAnalyticsEvent] {
        guard !context.roundComplete else { return [] }
        var run = runs[context.runID] ?? RunState()
        var round = run.rounds[context.roundID] ?? RoundState()
        guard !run.terminal && !round.terminal else { return [] }
        var events: [ArcadeAnalyticsEvent] = []
        if !run.started {
            run.started = true
            events.append(event("movie_arcade_started", context, round, now: now))
        }
        if round.activeSince == nil { round.activeSince = now }
        run.activeVisit = true
        run.rounds[context.roundID] = round
        run.updatedAt = now
        runs[context.runID] = run
        persist()
        events.append(event("movie_arcade_round_visible", context, round, now: now))
        return events
    }

    mutating func summaryVisible(_ context: ArcadeAnalyticsContext) -> [ArcadeAnalyticsEvent] {
        guard context.runComplete else { return [] }
        return [ArcadeAnalyticsEvent(name: "movie_arcade_summary_viewed", properties: context.properties)]
    }

    mutating func acceptedAction(_ role: ArcadeAnalyticsActionRole, context: ArcadeAnalyticsContext, now: Date = Date()) -> [ArcadeAnalyticsEvent] {
        guard var run = runs[context.runID], run.started,
              var round = run.rounds[context.roundID] else { return [] }
        guard !round.terminal else { return [] }
        var events: [ArcadeAnalyticsEvent] = []
        round.actionCount += 1
        if role == .attempt { round.attemptCount += 1 }
        if role == .help { round.helpCount += 1 }
        if role == .bonus { round.bonusAttemptCount += 1 }
        if !round.firstAction && (role == .attempt || role == .selection || role == .help || role == .bonus) {
            round.firstAction = true
            events.append(event("movie_arcade_first_action", context, round, now: now))
        }
        var actionProperties = event("movie_arcade_action", context, round, now: now).properties
        actionProperties["action_role"] = role.rawValue
        events.append(ArcadeAnalyticsEvent(name: role == .bonus ? "movie_arcade_bonus_attempt" : "movie_arcade_action", properties: actionProperties))
        if context.roundComplete {
            round.terminal = true
            round.accumulatedSeconds = elapsed(round, now: now)
            round.activeSince = nil
            var properties = event("movie_arcade_round_completed", context, round, now: now).properties
            properties["outcome"] = context.skipped ? "skipped" : "solved"
            events.append(ArcadeAnalyticsEvent(name: "movie_arcade_round_completed", properties: properties))
            if context.mode == "daily_mix", context.runComplete, !run.terminal {
                var mixProperties = properties
                mixProperties["genuine_round_count"] = context.genuineRoundCount
                mixProperties["skipped_round_count"] = context.skippedRoundCount
                mixProperties["outcome"] = context.skippedRoundCount == 0 ? "solved" : "contains_skips"
                events.append(ArcadeAnalyticsEvent(name: "movie_arcade_mix_completed", properties: mixProperties))
            }
            if context.runComplete { run.terminal = true; run.activeVisit = false }
        }
        run.rounds[context.roundID] = round
        run.updatedAt = now
        runs[context.runID] = run
        persist()
        return events
    }

    /// Permission sheets and other inactive overlays pause the clock without
    /// treating the player as having left. visible restarts the interval.
    mutating func suspend(_ context: ArcadeAnalyticsContext, now: Date = Date()) {
        guard var run = runs[context.runID], run.activeVisit,
              var round = run.rounds[context.roundID], round.activeSince != nil else { return }
        round.accumulatedSeconds = elapsed(round, now: now)
        round.activeSince = nil
        run.rounds[context.roundID] = round
        run.updatedAt = now
        runs[context.runID] = run
        persist()
    }

    mutating func abandon(_ context: ArcadeAnalyticsContext, now: Date = Date()) -> [ArcadeAnalyticsEvent] {
        guard !context.runComplete, var run = runs[context.runID], run.activeVisit else { return [] }
        var round = run.rounds[context.roundID] ?? RoundState()
        round.accumulatedSeconds = elapsed(round, now: now)
        round.activeSince = nil
        run.activeVisit = false
        run.rounds[context.roundID] = round
        run.updatedAt = now
        runs[context.runID] = run
        persist()
        return [event("movie_arcade_left", context, round, now: now)]
    }

    private func event(_ name: String, _ context: ArcadeAnalyticsContext, _ round: RoundState, now: Date) -> ArcadeAnalyticsEvent {
        var properties = context.properties
        properties["action_count"] = round.actionCount
        properties["attempt_count"] = round.attemptCount
        properties["help_count"] = round.helpCount
        properties["bonus_attempt_count"] = round.bonusAttemptCount
        properties["elapsed_active_seconds"] = elapsed(round, now: now)
        return ArcadeAnalyticsEvent(name: name, properties: properties)
    }

    private func elapsed(_ round: RoundState, now: Date) -> Double {
        round.accumulatedSeconds + (round.activeSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    private mutating func persist() {
        if runs.count > maximumRuns {
            // Saved unfinished modes stay resumable while old completed replays
            // are evicted first. The journal never grows beyond 32 run records.
            let retained = Set(runs.sorted {
                if $0.value.terminal != $1.value.terminal { return !$0.value.terminal }
                return $0.value.updatedAt > $1.value.updatedAt
            }.prefix(maximumRuns).map(\.key))
            runs = runs.filter { retained.contains($0.key) }
        }
        if let data = try? JSONEncoder().encode(runs) { defaults.set(data, forKey: storageKey) }
    }
}

/// Release sandbox receipts identify TestFlight; DEBUG takes precedence because
/// local StoreKit testing also produces a sandbox receipt.
enum ArcadeTelemetryEnvironment {
    static func classify(isSimulator: Bool, isDebug: Bool, receiptName: String?) -> String {
        if isSimulator { return "simulator" }
        if isDebug { return "debug" }
        return receiptName == "sandboxReceipt" ? "testflight" : "release"
    }
}
