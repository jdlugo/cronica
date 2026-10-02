import Foundation

/// Capability and content probes only. Direct state inspection deliberately
/// supplies known answers; these are not human play, pacing or preference tests.
@main struct ArcadePersonaProbes {
    static func main() throws {
        var checks = 0
        func check(_ value: Bool, _ message: String) {
            precondition(value, message); checks += 1
        }
        func paired(_ original: ArcadeRound) -> ArcadeRound {
            var round = original
            for i in round.board.indices where !round.matched.contains(i) {
                let j = round.board.indices.first { $0 != i && !round.matched.contains($0) && round.pairKey(round.board[i]) == round.pairKey(round.board[$0]) }!
                check(round.apply(.card(i)), "first card accepted")
                check(round.apply(.card(j)), "matching card accepted")
            }
            return round
        }
        func core(_ round: ArcadeRound) -> String {
            switch round.kind {
            case .memory: return "memory:" + round.films.sorted().map(String.init).joined(separator: ",")
            case .doubleFeature:
                return "doubleFeature:" + (0..<3).map { pair in
                    "\(round.pairKey(round.films[pair * 2])):" + Array(round.films[pair * 2..<pair * 2 + 2]).sorted().map(String.init).joined(separator: ",")
                }.sorted().joined(separator: ";")
            case .scene, .scramble, .detective: return "\(round.kind.rawValue):\(round.films[0])"
            case .casting: return "casting:\(round.films[0]):\(round.answer)"
            case .oddOneOut: return "oddOneOut:\(round.eraRule.rawValue):" + round.films.sorted().map(String.init).joined(separator: ",")
            default:
                var session = ArcadeSession.practice(round.kind, number: round.seed)
                session.rounds[0] = round
                return ArcadeAnalyticsContext(session: session).contentSignature
            }
        }

        var memory = paired(.make(kind: .memory, seed: 0))
        check(!memory.isComplete && memory.canFinishMatching, "matching unlocks optional finish")
        let earned = memory.matchingPoints!
        let wrongYear = memory.options.first { $0 != memory.answer }!
        check(memory.apply(.choose(wrongYear)), "wrong optional answer accepted")
        check(memory.apply(.finishMatching), "finish requires no year answer")
        check(memory.points == earned && !memory.skipped, "matching score preserved")
        var correctBonus = paired(.make(kind: .memory, seed: 0))
        check(correctBonus.apply(.choose(correctBonus.answer)), "correct optional answer accepted")
        check(correctBonus.points == earned, "bonus currently adds no extra points")

        var scramble = ArcadeRound.make(kind: .scramble, seed: 0)
        check(scramble.apply(.assemble), "assistance can restore visual board")
        check(scramble.canGuess && !scramble.isComplete, "restored Scramble still gates completion on title")
        check(scramble.apply(.skip) && scramble.points == 0, "bypassing title is a zero-point reveal")

        let suite = "ArcadePersonaProbes." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ArcadeProgressStore(defaults: defaults)
        var daily = ArcadeSession.daily(day: "2026-10-01")
        check(daily.rounds[0].apply(.choose(daily.current.answer)), "known first daily answer")
        check(daily.advance(), "partial daily progression")
        store.save(daily)
        check(store.load(isDaily: true, day: "2026-10-01") == daily, "same-day resume exact state")
        check(store.load(isDaily: true, day: "2026-10-02") == nil, "yesterday's unfinished mix unavailable today")

        var partialMemory = ArcadeSession.practice(.memory, number: 0)
        check(partialMemory.rounds[0].apply(.card(0)), "partial card selection")
        store.save(partialMemory)
        check(store.load(isDaily: false, kind: .memory) == partialMemory, "practice survives reload")

        var dailyRows: [[String: Any]] = []
        var seenFilms = Set<Int>(), seenCore = Set<String>()
        var repeatCore = 0, catalogueCoveredOn: String?
        for day in 1...7 {
            let date = String(format: "2026-10-%02d", day)
            let session = ArcadeSession.daily(day: date)
            check(session.isValid, "daily generation valid")
            for round in session.rounds {
                let signature = core(round)
                let repeated = !seenCore.insert(signature).inserted
                if repeated { repeatCore += 1 }
                seenFilms.formUnion(round.films)
                dailyRows.append(["day": date, "mode": round.kind.rawValue, "films": round.films.map { ArcadeCatalog.film($0).title }, "core_signature": signature, "core_seen_before": repeated])
            }
            if catalogueCoveredOn == nil && seenFilms.count == ArcadeCatalog.films.count { catalogueCoveredOn = date }
        }
        var practices: [[String: Any]] = []
        for kind in [ArcadeKind.scramble, .memory, .doubleFeature] {
            defaults.removePersistentDomain(forName: suite)
            var signatures: [String] = [], firstRepeat: Int?
            for number in 1...12 {
                let session = store.nextPracticeSession(kind)
                check(session.isValid, "practice valid")
                let signature = core(session.current)
                if signatures.contains(signature) && firstRepeat == nil { firstRepeat = number }
                signatures.append(signature)
                store.save(session)
            }
            practices.append(["mode": kind.rawValue, "generated_rounds": 12, "distinct_core_signatures": Set(signatures).count, "first_repeated_core_round": firstRepeat as Any? ?? NSNull(), "first_three_core_signatures": Array(signatures.prefix(3))])
        }
        let result: [String: Any] = [
            "schema": 1, "evidence_type": "deterministic model probe", "checks": checks,
            "limits": "Known state supplies answers. No participant, enjoyment, pacing, voluntary replay, conversion or retention result. Signatures are defined mechanical proxies, not proven perceived novelty. Generated practice is forced, not organic replay.",
            "core_signature_definition": "Memory ignores optional year/anchor and card shuffle; Double Feature preserves actor/movie pair groups; visual identification modes use target film; remaining modes preserve meaningful configured content.",
            "memory": ["matching_only_finish": true, "wrong_bonus_preserves_points": true, "correct_bonus_adds_points": false],
            "scramble": ["assembled_board_finishes_round": false, "no_title_reveal_points": 0],
            "recovery": ["same_day_daily_state": true, "next_day_previous_daily_available": false, "practice_selection_reloaded": true],
            "catalog": ["film_count": ArcadeCatalog.films.count, "earliest_year": ArcadeCatalog.films.map(\.year).min()!, "latest_year": ArcadeCatalog.films.map(\.year).max()!],
            "seven_day_daily": ["rounds": dailyRows.count, "distinct_films": seenFilms.count, "all_catalog_films_seen_by": catalogueCoveredOn as Any? ?? NSNull(), "distinct_core_signatures": seenCore.count, "repeated_core_rounds": repeatCore, "rows": dailyRows],
            "practice": practices
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
