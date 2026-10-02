import Foundation

@main struct ArcadeTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message); checks += 1
        }
        for kind in [ArcadeKind.memory, .doubleFeature] {
            for seed in 0..<40 {
                var round = ArcadeRound.make(kind: kind, seed: seed)
                let partner = round.board.indices.first { $0 != 0 && round.pairKey(round.board[$0]) == round.pairKey(round.board[0]) }!
                let unrelated = round.board.indices.first { round.pairKey(round.board[$0]) != round.pairKey(round.board[0]) }!
                round.matched = [0, partner]
                expect(round.isValid, "A complete saved pair remains resumable")
                round.matched = [0]
                expect(!round.isValid, "A half-matched saved pair would leave one card impossible to match")
                round.matched = [0, unrelated]
                expect(!round.isValid, "An even count of mismatched saved cards is still invalid")
            }
        }
        for seed in 0..<40 {
            var dragged = ArcadeRound.make(kind: .scramble, seed: seed)
            let original = dragged
            expect(!dragged.apply(.swapTiles(from: -1, to: 1)), "Off-board drags are ignored")
            expect(!dragged.apply(.swapTiles(from: 0, to: 4)), "Invalid destination is ignored")
            expect(!dragged.apply(.swapTiles(from: 0, to: 0)), "Dropping on the source is a no-op")
            expect(dragged == original, "Cancelled drags preserve every saved field")
            _ = dragged.apply(.tile(2))
            expect(dragged.apply(.swapTiles(from: 0, to: 1)), "Drag swaps the specified slots, ignoring tap selection")
            expect(dragged.board[0] == original.board[1] && dragged.board[1] == original.board[0], "Dragged tiles exchange positions")
            expect(dragged.selected.isEmpty && dragged.availablePoints == 3, "A drag clears selection without costing points")
            let restored = try JSONDecoder().decode(ArcadeRound.self, from: JSONEncoder().encode(dragged))
            expect(restored == dragged && restored.isValid, "Drag progress restores without losing its board")
            while !dragged.canGuess {
                let target = dragged.board.indices.first { dragged.board[$0] != $0 }!
                expect(dragged.apply(.swapTiles(from: dragged.board.firstIndex(of: target)!, to: target)), "Drags can finish the board")
            }
            expect(!dragged.apply(.swapTiles(from: 0, to: 1)), "Solved boards cannot be scrambled again")
            expect(dragged.apply(.choose(dragged.answer)) && dragged.points == 3, "Drag completion retains the full reward")
            expect(!dragged.apply(.swapTiles(from: 0, to: 1)), "Completed rounds reject late drag callbacks")
        }
        for kind in ArcadeKind.allCases where kind != .scramble {
            var round = ArcadeRound.make(kind: kind, seed: 0)
            let original = round
            expect(!round.apply(.swapTiles(from: 0, to: 1)) && round == original, "Other games reject tile drags")
        }
        for kind in ArcadeKind.allCases {
            var round = ArcadeRound.make(kind: kind, seed: 0)
            expect(round.discoveryFilmIDs.isEmpty, "Discovery cannot reveal an unfinished answer: \(kind)")
            _ = round.apply(.skip)
            let expected: [Int]
            switch kind {
            case .oddOneOut: expected = [round.answer]
            case .heist, .memory, .doubleFeature, .timeline, .directorsCut: expected = round.films
            default: expected = [round.film.id]
            }
            expect(round.discoveryFilmIDs == expected, "Every revealed film is discoverable: \(kind)")
            let restored = try JSONDecoder().decode(ArcadeRound.self, from: JSONEncoder().encode(round))
            expect(restored.discoveryFilmIDs == expected, "Discovery survives a restored result")
        }
        var discoveryMix = ArcadeSession.daily(day: "2026-10-01")
        expect(discoveryMix.discoveryFilmIDs.isEmpty, "A fresh mix exposes no future movies")
        _ = discoveryMix.rounds[0].apply(.choose(discoveryMix.current.answer))
        let firstDiscovery = discoveryMix.current.discoveryFilmIDs
        expect(discoveryMix.discoveryFilmIDs == firstDiscovery, "An unfinished mix includes completed movies only")
        for index in 1..<discoveryMix.rounds.count { _ = discoveryMix.rounds[index].apply(.skip) }
        let discovered = discoveryMix.discoveryFilmIDs
        expect(Set(discovered).count == discovered.count, "Summary movies are deduplicated")
        expect(discoveryMix.rounds.allSatisfy { Set($0.discoveryFilmIDs).isSubset(of: Set(discovered)) }, "Summary retains all disclosed movies")
        // A hint teaches the missing fact, but the player still performs the game.
        for (kind, clue) in [(ArcadeKind.casting, ArcadeClue.cast), (.doubleFeature, .cast),
                             (.timeline, .year), (.oddOneOut, .year), (.directorsCut, .year)] {
            var helped = ArcadeRound.make(kind: kind, seed: 0)
            expect(helped.apply(.clue(clue)), "Knowledge help must be available: \(kind)")
            expect(!helped.isComplete && !helped.skipped && helped.availablePoints == 2, "Help preserves gameplay and costs one point")
            expect(!helped.apply(.clue(clue)) && helped.availablePoints == 2, "Repeated help cannot double charge")
            let restored = try JSONDecoder().decode(ArcadeRound.self, from: JSONEncoder().encode(helped))
            expect(restored == helped && restored.isValid, "Knowledge help survives restore: \(kind)")
            expect(!helped.apply(.clue(clue == .cast ? .year : .cast)), "Unrelated clues are rejected")
        }
        var helpedHeist = ArcadeRound.make(kind: .heist, seed: 0)
        expect(!helpedHeist.apply(.clue(.cast)), "Cast help cannot be spent at the scene lock")
        _ = helpedHeist.apply(.choose(helpedHeist.heistAnswer))
        expect(!helpedHeist.apply(.clue(.cast)), "No help charged between locks")
        _ = helpedHeist.apply(.nextHeist)
        expect(helpedHeist.apply(.clue(.cast)), "Unfamiliar Heist cast has a recovery route")
        _ = helpedHeist.apply(.choose(helpedHeist.heistAnswer)); _ = helpedHeist.apply(.nextHeist)
        expect(helpedHeist.availablePoints == 2 && !helpedHeist.apply(.clue(.cast)), "Help cost persists into final lock")
        _ = helpedHeist.apply(.choose(helpedHeist.heistAnswer))
        expect(helpedHeist.points == 2 && helpedHeist.isValid, "Helped Heist can earn a real result")
        var pairingSets: Set<[Int]> = []
        for seed in 0..<16 {
            let round = ArcadeRound.make(kind: .doubleFeature, seed: seed)
            pairingSets.insert(round.films.sorted())
            let connections = Dictionary(grouping: round.films, by: round.pairKey)
            expect(connections.count == 3 && connections.values.allSatisfy { $0.count == 2 }, "Three unambiguous actor pairs")
            for actor in connections.keys {
                expect(round.films.filter { ArcadeCatalog.film($0).cast.contains(actor) }.count == 2, "Each named actor connects exactly two visible films")
            }
            for id in round.films {
                expect(ArcadeCatalog.film(id).cast.contains(round.pairKey(id)), "Every generated pairing uses a credited actor")
                expect(round.reveal.contains(ArcadeCatalog.film(id).title), "Reveal reflects this pairing board")
            }
        }
        expect(pairingSets.count >= 3, "Repeat play offers several distinct actor pairing sets")
        var optionalMemory = ArcadeRound.make(kind: .memory, seed: 0)
        expect(!optionalMemory.apply(.finishMatching), "Cannot finish before matching all cards")
        for i in optionalMemory.board.indices where !optionalMemory.matched.contains(i) {
            let j = optionalMemory.board.indices.first { $0 != i && optionalMemory.board[$0] == optionalMemory.board[i] }!
            _ = optionalMemory.apply(.card(i)); _ = optionalMemory.apply(.card(j))
        }
        expect(optionalMemory.canFinishMatching, "Matching success offers a finish without trivia")
        var bonusMemory = optionalMemory
        expect(optionalMemory.apply(.finishMatching) && optionalMemory.isComplete && optionalMemory.points == 3, "Finish keeps earned matching points")
        expect(optionalMemory.reveal.contains("pairs"), "Non-trivia finish acknowledges matching")
        _ = bonusMemory.apply(.choose(bonusMemory.options.first { $0 != bonusMemory.answer }!))
        var answeredBonus = bonusMemory
        expect(answeredBonus.apply(.choose(answeredBonus.answer)) && answeredBonus.points == 3 && answeredBonus.isValid, "Original year-answer route remains playable without erasing matching points")
        expect(bonusMemory.apply(.finishMatching) && bonusMemory.points == 3, "Optional trivia mistakes cannot take away matching points")
        let restoredMemory = try JSONDecoder().decode(ArcadeRound.self, from: JSONEncoder().encode(optionalMemory))
        expect(restoredMemory == optionalMemory && restoredMemory.isValid, "Optional finish survives save and restore")
        for seed in 0..<40 {
            for kind in ArcadeKind.allCases {
                var r = ArcadeRound.make(kind: kind, seed: seed)
                expect(r.isValid, "Generated state is valid: \(kind)")
                expect(r == ArcadeRound.make(kind: kind, seed: seed), "Stable seed")
                expect(!r.apply(.choose(-1)), "Invalid answer ignored")
                switch kind {
                case .directorsCut:
                    expect(Set(r.films.map { ArcadeCatalog.film($0).year }).count == 3, "Three distinct release years")
                    let ordered = r.films.sorted { ArcadeCatalog.film($0).year < ArcadeCatalog.film($1).year }
                    expect(r.board != ordered, "Order puzzle never starts solved")
                    expect(r.apply(.choose(ordered[2])), "Recoverable out-of-order pick")
                    expect(!r.apply(.choose(ordered[2])), "Wrong pick charged only once per position")
                    for id in ordered { expect(r.apply(.choose(id)), "Build chronological cut") }
                case .heist:
                    expect(Set(r.films).count == 3, "Three different locks")
                    for lock in 0..<3 {
                        expect(r.heistOptions.count == 4, "Four lock choices")
                        expect(r.apply(.choose(r.heistAnswer)), "Crack lock")
                        if lock < 2 {
                            expect(!r.apply(.choose(r.heistAnswer)), "Double tap cannot open next lock")
                            expect(r.apply(.nextHeist), "Continue to next lock")
                        }
                    }
                case .scramble:
                    expect(r.board != [0,1,2,3], "Never start solved")
                    expect(!r.apply(.tile(-1)), "Invalid tile ignored")
                    expect(!r.apply(.choose(r.answer)), "Solve image before guessing")
                    while r.board != [0,1,2,3] {
                        let i = r.board.indices.first { r.board[$0] != $0 }!
                        let j = r.board.firstIndex(of: i)!
                        _ = r.apply(.tile(i)); _ = r.apply(.tile(j))
                    }
                    expect(r.apply(.choose(r.answer)), "Assembled image unlocks answers")
                case .casting:
                    let film = ArcadeCatalog.film(r.films[0])
                    expect(r.options.filter { film.cast.contains($0) }.count == 1, "Exactly one credited actor")
                    _ = r.apply(.choose(r.answer))
                case .timeline:
                    expect(Set(r.films.map { ArcadeCatalog.film($0).year }).count == 4, "No year ties")
                    for step in 0..<3 {
                        let later = ArcadeCatalog.film(r.films[step+1]).year > ArcadeCatalog.film(r.films[0]).year
                        expect(r.apply(.timeline(later)), "Place movie")
                        if step < 2 {
                            expect(!r.apply(.timeline(later)), "Cannot answer twice before continuing")
                            expect(r.apply(.nextTimeline), "Reveal acknowledged")
                        }
                    }
                case .oddOneOut:
                    let exception = r.films.filter { !r.eraRule.includes(ArcadeCatalog.film($0).year) }
                    expect(exception == [r.answer], "Exactly one film outside the explicit era")
                    _ = r.apply(.choose(r.answer))
                case .doubleFeature, .memory:
                    expect(!r.apply(.card(-1)), "Invalid card ignored")
                    for i in r.board.indices where !r.matched.contains(i) {
                        let j = r.board.indices.first { $0 != i && !r.matched.contains($0) && r.pairKey(r.board[$0]) == r.pairKey(r.board[i]) }!
                        _ = r.apply(.card(i)); expect(!r.apply(.card(i)), "Same card cannot match itself")
                        _ = r.apply(.card(j))
                    }
                    if kind == .memory { expect(!r.isComplete, "Memory has bonus question"); _ = r.apply(.choose(r.answer)) }
                case .detective:
                    expect(r.apply(.clue(.plot)), "Choose clue")
                    expect(!r.apply(.clue(.plot)), "Clue is charged once")
                    _ = r.apply(.clue(.cast)); _ = r.apply(.clue(.year))
                    expect(r.availablePoints == 1, "Assistance score floor")
                    _ = r.apply(.choose(r.answer))
                case .scene: _ = r.apply(.choose(r.answer))
                }
                expect(r.isComplete && (1...3).contains(r.points), "Round completes")
                let done = r
                expect(!r.apply(.skip) && r == done, "Completed round immutable")
                let restored = try JSONDecoder().decode(ArcadeRound.self, from: JSONEncoder().encode(r))
                expect(restored == r, "Round-trip persistence")
                var skipped = ArcadeRound.make(kind: kind, seed: seed)
                _ = skipped.apply(.skip)
                expect(skipped.isComplete && skipped.points == 0, "Skip permits continuation without score")
            }
        }
        for lock in 0..<3 {
            var heist = ArcadeRound.make(kind: .heist, seed: 0)
            for _ in 0..<lock { _ = heist.apply(.choose(heist.heistAnswer)); _ = heist.apply(.nextHeist) }
            let wrong = heist.heistOptions.first { $0 != heist.heistAnswer }!
            expect(heist.apply(.choose(wrong)), "Heist wrong choice is recoverable")
            expect(!heist.apply(.choose(wrong)), "Eliminated choice cannot charge twice")
            heist = try JSONDecoder().decode(ArcadeRound.self, from: JSONEncoder().encode(heist))
            expect(heist.isValid && heist.eliminated.contains(wrong), "Heist restores eliminated options")
            expect(heist.apply(.choose(heist.heistAnswer)), "Restored lock is playable")
            let restored = try JSONDecoder().decode(ArcadeRound.self, from: JSONEncoder().encode(heist))
            expect(restored == heist && restored.isValid, "Unlocked digit survives relaunch")
            if lock < 2 {
                expect(heist.apply(.nextHeist) && heist.eliminated.isEmpty, "Next lock clears old eliminations")
                expect(!heist.apply(.nextHeist), "Cannot skip unanswered lock")
            }
        }
        var brokenHeist = ArcadeRound.make(kind: .heist, seed: 0)
        brokenHeist.isComplete = true
        expect(!brokenHeist.isValid, "Cannot restore premature vault completion")
        brokenHeist.isComplete = false; brokenHeist.step = 2; brokenHeist.awaitingNext = true
        expect(!brokenHeist.isValid, "No fourth lock in restored state")
        var mismatch = ArcadeRound.make(kind: .memory, seed: 4)
        let j = mismatch.board.firstIndex { $0 != mismatch.board[0] }!
        _ = mismatch.apply(.card(0)); _ = mismatch.apply(.card(j))
        expect(mismatch.mistakes == 1 && mismatch.selected.count == 2, "Mismatch stays visible")
        expect(!mismatch.apply(.card(2)), "No third card while mismatch open")
        expect(mismatch.apply(.clearMismatch) && mismatch.selected.isEmpty, "Explicit retry clears mismatch")
        for i in mismatch.board.indices where !mismatch.matched.contains(i) {
            let partner = mismatch.board.indices.first { $0 != i && mismatch.board[$0] == mismatch.board[i] }!
            _ = mismatch.apply(.card(i)); _ = mismatch.apply(.card(partner))
        }
        expect(mismatch.matchingPoints == 2, "Actual matching mistakes still reduce earned matching score")
        var matchedSkip = mismatch
        expect(matchedSkip.apply(.skip) && matchedSkip.points == 0 && matchedSkip.isValid, "A skipped Memory bonus remains a skip, not a genuine completion")
        _ = mismatch.apply(.choose(mismatch.options.first { $0 != mismatch.answer }!))
        _ = mismatch.apply(.finishMatching)
        expect(mismatch.points == 2 && mismatch.isValid, "Optional finish preserves earned points after matching and trivia mistakes")
        var mix = ArcadeSession.daily(day: "2026-09-30")
        expect(mix.rounds.count == 4 && mix.rounds[0].kind == .scene, "Daily mix has familiar anchor")
        expect(Set(mix.rounds.map(\.kind)).count == 4, "Distinct daily games")
        expect(mix.rounds == ArcadeSession.daily(day: "2026-09-30").rounds, "Stable daily challenges despite distinct run IDs")
        expect(mix.rounds != ArcadeSession.daily(day: "2026-10-01").rounds, "Date rotates challenges rather than only identity")
        expect(!mix.advance(), "Cannot bypass active round")
        for i in 0..<4 { _ = mix.rounds[i].apply(.skip); if i < 3 { expect(mix.advance(), "Advance completed round") } }
        expect(mix.isComplete && mix.points == 0 && !mix.advance(), "Mix ends once")
        var corrupt = ArcadeRound.make(kind: .memory, seed: 3); corrupt.board = [999]
        expect(!corrupt.isValid, "Corrupt saved board rejected")
        for seed in 0..<30 {
            for kind in ArcadeKind.allCases {
                var round = ArcadeRound.make(kind: kind, seed: seed)
                let actions: [ArcadeAction] = [.card(0), .card(0), .card(1), .card(5), .clearMismatch,
                    .tile(0), .tile(2), .choose(round.options.first ?? -1), .clue(.plot), .clue(.plot),
                    .timeline(false), .timeline(true), .nextTimeline, .assemble, .choose(round.answer), .skip]
                for action in actions {
                    _ = round.apply(action)
                    expect(round.isValid, "Any action sequence preserves valid save state")
                }
            }
        }
        let suite = "ArcadeRulesTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ArcadeProgressStore(defaults: defaults)
        let daily = ArcadeSession.daily(day: "2026-09-30")
        store.save(daily)
        expect(store.load(isDaily: true, day: "2026-09-30") == daily, "Daily saves resume")
        expect(store.load(isDaily: true, day: "2026-10-01") == nil, "New day does not inherit old score")
        var practice = ArcadeSession.practice(.memory, number: 4)
        _ = practice.rounds[0].apply(.card(0))
        store.save(practice)
        expect(store.load(isDaily: false, kind: .memory) == practice, "Face-up card persists")
        expect(store.load(isDaily: true, day: "2026-09-30") == daily, "Practice cannot overwrite daily")
        defaults.set(Data("broken".utf8), forKey: store.key(isDaily: true, kind: .scene))
        expect(store.load(isDaily: true, day: "2026-09-30") == nil, "Corrupt JSON falls back safely")
        practice.rounds[0].board = [-1]
        defaults.set(try JSONEncoder().encode(practice), forKey: store.key(isDaily: false, kind: .memory))
        expect(store.load(isDaily: false, kind: .memory) == nil, "Malformed board cannot load")
        expect(store.nextPracticeNumber() == 1 && store.nextPracticeNumber() == 2, "Practice variation persists")
        for kind in [ArcadeKind.memory, .doubleFeature] {
            var brokenPair = ArcadeSession.practice(kind, number: 0)
            brokenPair.rounds[0].matched = [0]
            defaults.set(try JSONEncoder().encode(brokenPair), forKey: store.key(isDaily: false, kind: kind))
            expect(store.load(isDaily: false, kind: kind) == nil, "Half-matched saved pair must fall back to a fresh game")
            let recovered = store.nextPracticeSession(kind)
            store.save(recovered)
            expect(recovered.current.matched.isEmpty && store.load(isDaily: false, kind: kind) == recovered,
                   "Rejected matching save can be replaced by a playable fresh game")
        }
        for kind in ArcadeKind.allCases {
            // An old or fixture-created first round must be included in the replay history.
            let first = ArcadeSession.practice(kind, number: 0)
            store.save(first)
            let second = store.nextPracticeSession(kind); store.save(second)
            let third = store.nextPracticeSession(kind)
            let identities = [first, second, third].map { kind == .doubleFeature ? $0.current.films.sorted() : [kind == .oddOneOut ? $0.current.answer : $0.current.films[0]] }
            expect(Set(identities).count == 3, "Three practice rounds avoid quickly recycled targets: \(kind)")
        }
        var legacyObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(daily)) as! [String: Any]
        legacyObject.removeValue(forKey: "runID")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        defaults.set(legacyData, forKey: store.key(isDaily: true, kind: .scene))
        let migrated = store.load(isDaily: true, day: daily.day)!
        expect(migrated.rounds == daily.rounds && migrated.runID != nil, "Legacy daily migrates identity without discarding progress")
        expect(store.load(isDaily: true, day: daily.day)?.runID == migrated.runID, "Migrated run identity persists across reloads")
        expect(ArcadeSession.practice(.scene, number: 0).runID != ArcadeSession.practice(.scene, number: 0).runID, "Separate runs have distinct identities")
        var legacyPairs = ArcadeRound(kind: .doubleFeature, seed: 3, films: [597, 27205, 603, 245891, 346698, 313369], options: [], answer: ArcadeRound.make(kind: .doubleFeature, seed: 3).answer, board: [597, 27205, 603, 245891, 346698, 313369])
        _ = legacyPairs.apply(.card(0))
        let oldPairRound = try JSONDecoder().decode(ArcadeRound.self, from: JSONEncoder().encode(legacyPairs))
        expect(oldPairRound.isValid && oldPairRound.selected == [0], "Legacy fixed pairing board remains resumable")
        var legacyMatched = oldPairRound
        expect(legacyMatched.apply(.card(1)) && legacyMatched.matched == [0, 1] && legacyMatched.isValid,
               "The stricter validator preserves complete pairs in legacy Double Feature saves")
        var repeatedDailyFilmSlots = 0
        for day in 1...28 {
            let run = ArcadeSession.daily(day: String(format: "2026-10-%02d", day))
            let ids = run.rounds.filter { $0.kind != .doubleFeature }.map { $0.kind == .oddOneOut ? $0.answer : $0.films[0] }
            expect(Set(ids).count == ids.count, "Daily guessing rounds do not repeat a title")
            let films = run.rounds.flatMap(\.films)
            repeatedDailyFilmSlots += films.count - Set(films).count
        }
        expect(repeatedDailyFilmSlots <= 28, "Daily Mix averages at most one repeated film across four modes in the test month")
        for film in ArcadeCatalog.films {
            expect(film.cast.contains(film.leadID), "Correct portrait is credited")
            expect(FileManager.default.fileExists(atPath: "Shared/Assets.xcassets/MovieQuiz\(film.id).imageset"), "Offline scene exists")
            expect(FileManager.default.fileExists(atPath: "Shared/Assets.xcassets/MovieQuizPoster\(film.id).imageset"), "Offline poster exists")
            expect(FileManager.default.fileExists(atPath: "Shared/Assets.xcassets/ArcadeActor\(film.leadID).imageset"), "Offline portrait exists")
        }
        let pairs = ArcadeRound.make(kind: .doubleFeature, seed: 5)
        for id in pairs.board { expect(ArcadeCatalog.film(id).cast.contains(pairs.pairKey(id)), "Shared actor actually appears in paired film") }
        print("Movie Arcade: \(checks) checks passed across 40 seeds and all \(ArcadeKind.allCases.count) round types")
    }
}
