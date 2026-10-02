import Foundation

@main struct ArcadeAnalyticsTests {
    static func main() throws {
        var checks = 0
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message); checks += 1
        }
        var discoveryRun = ArcadeSession.practice(.scene, number: 0)
        expect(ArcadeDiscoveryEvent.make(.opened, filmID: 862, surface: .result, session: discoveryRun) == nil, "No discovery telemetry before completion")
        _ = discoveryRun.rounds[0].apply(.choose(discoveryRun.current.answer))
        let detailEvent = ArcadeDiscoveryEvent.make(.opened, filmID: 862, surface: .result, session: discoveryRun)!
        expect(detailEvent.name == "movie_arcade_movie_opened", "Detail-open has a distinct event")
        expect(detailEvent.properties["round_id"] as? String == ArcadeAnalyticsContext(session: discoveryRun).roundID, "Open joins its source round")
        expect(detailEvent.properties["movie_id"] as? Int == 862 && detailEvent.properties["discovery_surface"] as? String == "result", "Movie and entry surface are explicit")
        expect(ArcadeDiscoveryEvent.make(.added, filmID: 862, surface: .result, session: discoveryRun)?.name == "movie_arcade_watchlist_added", "Successful addition joins the same journey")
        expect(ArcadeDiscoveryEvent.make(.opened, filmID: 597, surface: .result, session: discoveryRun) == nil, "Unknown/unplayed movies cannot be attributed")
        var discoveryDaily = ArcadeSession.daily(day: "2026-10-01")
        _ = discoveryDaily.rounds[0].apply(.skip)
        expect(ArcadeDiscoveryEvent.make(.opened, filmID: discoveryDaily.current.discoveryFilmIDs[0], surface: .summary, session: discoveryDaily) == nil, "Summary events require a finished mix")
        for index in discoveryDaily.rounds.indices { _ = discoveryDaily.rounds[index].apply(.skip) }
        discoveryDaily.index = discoveryDaily.rounds.count - 1
        let sourceID = discoveryDaily.rounds[0].discoveryFilmIDs[0]
        let summaryEvent = ArcadeDiscoveryEvent.make(.opened, filmID: sourceID, surface: .summary, session: discoveryDaily)!
        expect(summaryEvent.properties["round"] as? Int == 1, "Summary discovery points to the movie's source round, not the last round")
        expect(summaryEvent.properties["skipped"] as? Bool == true, "Revealed movies never masquerade as solved games")
        let suite = "ArcadeAnalyticsTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 1_000)
        var journal = ArcadeAnalyticsJournal(defaults: defaults)
        var run = ArcadeSession.practice(.scene, number: 41)
        let original = ArcadeAnalyticsContext(session: run)
        expect(original.roundID != original.challengeID, "Run occurrence and seeded content have separate identity")
        let restored = try JSONDecoder().decode(ArcadeSession.self, from: JSONEncoder().encode(run))
        expect(ArcadeAnalyticsContext(session: restored).roundID == original.roundID, "Stable identity across save/restore")
        var sameContent = ArcadeSession.practice(.scene, number: 99)
        sameContent.rounds[0] = ArcadeRound(kind: .scene, seed: 99, films: run.current.films,
                                          options: run.current.options.reversed(), answer: run.current.answer)
        let shuffled = ArcadeAnalyticsContext(session: sameContent)
        expect(shuffled.contentSignature == original.contentSignature, "Seed and choice order do not masquerade as new content")
        expect(shuffled.challengeID != original.challengeID, "Different exact generations remain distinct challenges")
        expect(journal.exposed(entry: "home").map(\.name) == ["movie_arcade_exposed"], "Exposure does not imply a start")
        expect(journal.exposed(entry: "home").count == 1, "A later genuine exposure remains measurable")
        let visible = journal.visible(original, now: start)
        expect(visible.map(\.name) == ["movie_arcade_started", "movie_arcade_round_visible"], "Start only when play is visible")
        expect(journal.visible(original, now: start).map(\.name) == ["movie_arcade_round_visible"], "Repeat visibility never repeats start")
        let help = journal.acceptedAction(.help, context: original, now: start.addingTimeInterval(1))
        expect(help.map(\.name).contains("movie_arcade_first_action"), "Help is an intentional gameplay action")
        let attempt = journal.acceptedAction(.attempt, context: original, now: start.addingTimeInterval(2))
        expect(!attempt.map(\.name).contains("movie_arcade_first_action"), "First action occurs once")
        expect(attempt.last?.properties["attempt_count"] as? Int == 1, "Answer attempts counted independently")
        expect(attempt.last?.properties["help_count"] as? Int == 1, "Help counted independently")
        _ = run.rounds[0].apply(.choose(run.current.answer))
        let done = ArcadeAnalyticsContext(session: run)
        let completion = journal.acceptedAction(.attempt, context: done, now: start.addingTimeInterval(3))
        expect(completion.filter { $0.name == "movie_arcade_round_completed" }.count == 1, "One terminal round event")
        expect(completion.last?.properties["outcome"] as? String == "solved", "Genuine solve distinguishable from skip")
        expect(journal.acceptedAction(.attempt, context: done).isEmpty, "Duplicate terminal callback ignored")
        expect(journal.visible(done).isEmpty, "Completed summary cannot start a game")
        expect(journal.summaryVisible(done).map(\.name) == ["movie_arcade_summary_viewed"], "Summary view separate from play start")
        expect(journal.abandon(done).isEmpty, "No abandonment after completion")
        var reopened = ArcadeAnalyticsJournal(defaults: defaults)
        expect(reopened.visible(done).isEmpty, "Saved completed summary does not restart after process relaunch")
        expect(reopened.acceptedAction(.attempt, context: done).isEmpty, "Persisted terminal deduplication")
        expect(reopened.acceptedAction(.bonus, context: done).isEmpty, "Completed rounds reject duplicate bonus callbacks")

        var memory = ArcadeSession.practice(.memory, number: 60)
        let memoryContext = ArcadeAnalyticsContext(session: memory)
        _ = reopened.visible(memoryContext, now: start)
        let firstFlip = reopened.acceptedAction(.selection, context: memoryContext, now: start.addingTimeInterval(1))
        expect(firstFlip.first?.name == "movie_arcade_first_action", "First flip is gameplay even before pair decision")
        expect(firstFlip.last?.properties["attempt_count"] as? Int == 0, "First flip is not a completed pair attempt")
        for i in memory.current.board.indices where !memory.current.matched.contains(i) {
            let j = memory.current.board.indices.first { $0 != i && !memory.current.matched.contains($0) && memory.current.board[$0] == memory.current.board[i] }!
            _ = memory.rounds[0].apply(.card(i)); _ = memory.rounds[0].apply(.card(j))
            _ = reopened.acceptedAction(.attempt, context: ArcadeAnalyticsContext(session: memory), now: start.addingTimeInterval(2))
        }
        _ = memory.rounds[0].apply(.choose(memory.current.answer))
        let bonus = reopened.acceptedAction(.bonus, context: ArcadeAnalyticsContext(session: memory), now: start.addingTimeInterval(3))
        expect(bonus.map(\.name) == ["movie_arcade_bonus_attempt", "movie_arcade_round_completed"], "Optional bonus answer still completes the saved round once")
        expect(bonus.first?.properties["bonus_attempt_count"] as? Int == 1, "Bonus attempts separate from matching")
        var optionalMemory = ArcadeSession.practice(.memory, number: 62)
        _ = reopened.visible(ArcadeAnalyticsContext(session: optionalMemory), now: start)
        for i in optionalMemory.current.board.indices where !optionalMemory.current.matched.contains(i) {
            let j = optionalMemory.current.board.indices.first { $0 != i && !optionalMemory.current.matched.contains($0) && optionalMemory.current.board[$0] == optionalMemory.current.board[i] }!
            _ = optionalMemory.rounds[0].apply(.card(i)); _ = optionalMemory.rounds[0].apply(.card(j))
            _ = reopened.acceptedAction(.attempt, context: ArcadeAnalyticsContext(session: optionalMemory), now: start.addingTimeInterval(2))
        }
        _ = optionalMemory.rounds[0].apply(.finishMatching)
        let finishMatching = reopened.acceptedAction(.progress, context: ArcadeAnalyticsContext(session: optionalMemory), now: start.addingTimeInterval(3))
        expect(finishMatching.last?.name == "movie_arcade_round_completed", "Matching-only finish counts genuine completion without bonus")
        expect(finishMatching.last?.properties["bonus_attempt_count"] as? Int == 0, "No bonus attempt invented when user finishes matching")
        var legacyObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(optionalMemory)) as! [String: Any]
        legacyObject.removeValue(forKey: "runID")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacySession = try JSONDecoder().decode(ArcadeSession.self, from: legacyData)
        expect(legacySession.runID == nil, "Old saved sessions remain decodable without run ID")
        expect(ArcadeAnalyticsContext(session: legacySession).runID == ArcadeAnalyticsContext(session: legacySession).runID, "Legacy fallback does not generate identity on each callback")
        let store = ArcadeProgressStore(defaults: defaults)
        store.save(legacySession)
        let migrated = store.load(isDaily: false, kind: .memory)!
        expect(migrated.runID != nil && migrated.runID == store.load(isDaily: false, kind: .memory)?.runID, "Store migration persists stable legacy identity")

        var other = ArcadeSession.practice(.detective, number: 50)
        let otherContext = ArcadeAnalyticsContext(session: other)
        _ = reopened.visible(otherContext, now: start)
        let left = reopened.abandon(otherContext, now: start.addingTimeInterval(4))
        expect(left.map(\.name) == ["movie_arcade_left"], "An unfinished visible visit can be abandoned")
        expect(left.first?.properties["elapsed_active_seconds"] as? Double == 4, "Elapsed time excludes later background time")
        expect(reopened.abandon(otherContext).isEmpty, "Back/Close/onDisappear duplicate cannot inflate abandonment")
        var afterRelaunch = ArcadeAnalyticsJournal(defaults: defaults)
        expect(afterRelaunch.abandon(otherContext).isEmpty, "Abandonment remains deduplicated after journal restore")
        expect(afterRelaunch.visible(otherContext, now: start.addingTimeInterval(100)).map(\.name) == ["movie_arcade_round_visible"], "Resume repeats visibility without run start")
        expect(afterRelaunch.abandon(otherContext, now: start.addingTimeInterval(106)).first?.properties["elapsed_active_seconds"] as? Double == 10, "Resumed visible time accumulates without background time")
        _ = other.rounds[0].apply(.skip)
        _ = afterRelaunch.visible(otherContext, now: start.addingTimeInterval(110))
        let skip = afterRelaunch.acceptedAction(.skip, context: ArcadeAnalyticsContext(session: other), now: start.addingTimeInterval(111))
        expect(!skip.map(\.name).contains("movie_arcade_first_action"), "Skipping is not a genuine first gameplay action")
        expect(skip.last?.properties["outcome"] as? String == "skipped", "Skip terminal explicit")
        expect(skip.last?.properties["skipped"] as? Bool == true, "Skip flag retained for compatible funnel queries")

        var mix = ArcadeSession.daily(day: "2026-10-01")
        for index in mix.rounds.indices {
            _ = afterRelaunch.visible(ArcadeAnalyticsContext(session: mix), now: start)
            _ = mix.rounds[index].apply(.skip)
            let terminal = afterRelaunch.acceptedAction(.skip, context: ArcadeAnalyticsContext(session: mix), now: start.addingTimeInterval(1))
            expect(terminal.filter { $0.name == "movie_arcade_round_completed" }.count == 1, "Every mix round gets its own terminal identity")
            if index < mix.rounds.count - 1 {
                expect(!terminal.map(\.name).contains("movie_arcade_mix_completed"), "Mix completion waits for last round")
                _ = mix.advance()
            } else {
                expect(terminal.last?.name == "movie_arcade_mix_completed", "One mix terminal after final round")
                expect(terminal.last?.properties["genuine_round_count"] as? Int == 0, "All-skipped mix never appears genuinely completed")
                expect(terminal.last?.properties["skipped_round_count"] as? Int == 4, "Mix skip count explicit")
            }
        }
        expect(afterRelaunch.acceptedAction(.skip, context: ArcadeAnalyticsContext(session: mix)).isEmpty, "Mix completion deduplicated")
        let killed = ArcadeAnalyticsContext(session: ArcadeSession.practice(.casting, number: 13))
        _ = afterRelaunch.visible(killed, now: start)
        var afterKill = ArcadeAnalyticsJournal(defaults: defaults)
        let newVisible = afterKill.visible(killed, now: start.addingTimeInterval(7_200))
        expect(newVisible.first?.name == "movie_arcade_round_visible", "Process recovery does not duplicate start")
        expect(newVisible.first?.properties["elapsed_active_seconds"] as? Double == 0, "Forced quit cannot turn off-app hours into active time")
        var partial = ArcadeSession.daily(day: "2026-10-02")
        _ = afterKill.visible(ArcadeAnalyticsContext(session: partial), now: start)
        _ = partial.rounds[0].apply(.skip)
        _ = afterKill.acceptedAction(.skip, context: ArcadeAnalyticsContext(session: partial), now: start.addingTimeInterval(2))
        expect(afterKill.abandon(ArcadeAnalyticsContext(session: partial)).first?.name == "movie_arcade_left", "Leaving between daily rounds is still run abandonment")
        expect(afterKill.abandon(ArcadeAnalyticsContext(session: partial)).isEmpty, "Between-round abandonment deduplicated")
        let unfinished = ArcadeAnalyticsContext(session: ArcadeSession.practice(.scramble, number: 123))
        _ = afterKill.visible(unfinished, now: start)
        _ = afterKill.abandon(unfinished, now: start.addingTimeInterval(1))
        for number in 0..<40 {
            var replay = ArcadeSession.practice(.scene, number: number)
            _ = afterKill.visible(ArcadeAnalyticsContext(session: replay), now: start.addingTimeInterval(Double(number + 10)))
            _ = replay.rounds[0].apply(.choose(replay.current.answer))
            _ = afterKill.acceptedAction(.attempt, context: ArcadeAnalyticsContext(session: replay), now: start.addingTimeInterval(Double(number + 11)))
        }
        let persisted = try JSONSerialization.jsonObject(with: defaults.data(forKey: "movieArcade.analytics.v2")!) as! [String: Any]
        expect(persisted.count == 32, "Journal storage stays bounded during repeated replay")
        var boundedReload = ArcadeAnalyticsJournal(defaults: defaults)
        expect(boundedReload.visible(unfinished).map(\.name) == ["movie_arcade_round_visible"], "Bounded journal retains resumable unfinished games before old completed replays")
        let overlay = ArcadeAnalyticsContext(session: ArcadeSession.practice(.timeline, number: 124))
        _ = boundedReload.visible(overlay, now: start)
        boundedReload.suspend(overlay, now: start.addingTimeInterval(3))
        boundedReload.suspend(overlay, now: start.addingTimeInterval(50))
        let overlayResume = boundedReload.visible(overlay, now: start.addingTimeInterval(100))
        expect(overlayResume.map(\.name) == ["movie_arcade_round_visible"], "Overlay resume does not invent another start")
        expect(overlayResume.first?.properties["elapsed_active_seconds"] as? Double == 3, "Inactive overlay time excluded; repeated suspension has no effect")
        let afterOverlay = boundedReload.acceptedAction(.attempt, context: overlay, now: start.addingTimeInterval(106))
        expect(afterOverlay.last?.properties["elapsed_active_seconds"] as? Double == 9, "Active intervals accumulate across overlay resume")
        boundedReload.suspend(overlay, now: start.addingTimeInterval(107))
        let backgroundAfterOverlay = boundedReload.abandon(overlay, now: start.addingTimeInterval(200))
        expect(backgroundAfterOverlay.first?.name == "movie_arcade_left", "Suspension preserves the visit for actual background abandonment")
        expect(backgroundAfterOverlay.first?.properties["elapsed_active_seconds"] as? Double == 10, "Background abandonment cannot count inactive time")
        expect(boundedReload.abandon(overlay).isEmpty, "Actual abandonment remains deduplicated after suspension")
        for event in visible + help + attempt + completion + left + skip {
            expect(!event.properties.keys.contains("guess") && !event.properties.keys.contains("answer") && !event.properties.keys.contains("email"), "No guess content or PII")
            if event.name != "movie_arcade_exposed" {
                expect(event.properties["run_id"] is String && event.properties["round_id"] is String && event.properties["challenge_id"] is String, "Journey events always carry joinable identity")
            }
        }
        expect(ArcadeTelemetryEnvironment.classify(isSimulator: true, isDebug: true, receiptName: "sandboxReceipt") == "simulator", "Simulator has explicit environment")
        expect(ArcadeTelemetryEnvironment.classify(isSimulator: false, isDebug: true, receiptName: "sandboxReceipt") == "debug", "Debug receipt not mislabeled TestFlight")
        expect(ArcadeTelemetryEnvironment.classify(isSimulator: false, isDebug: false, receiptName: "sandboxReceipt") == "testflight", "Sandbox receipt identifies TestFlight release build")
        expect(ArcadeTelemetryEnvironment.classify(isSimulator: false, isDebug: false, receiptName: "receipt") == "release", "Production release environment")
        expect(ArcadeTelemetryEnvironment.classify(isSimulator: false, isDebug: false, receiptName: nil) == "release", "No debug/sandbox marker is classified release")
        print("Arcade analytics: \(checks) checks passed")
    }
}
