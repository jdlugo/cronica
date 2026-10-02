import XCTest

/// Assigned simulator policies, not humans or inferred enjoyment. Choices are selected
/// from displayed labels and declared facts; no engine, saved data or seed answer oracle.
final class ArcadePersonaPlaythroughTests: XCTestCase {
    private let games = ["scene", "scramble", "casting", "timeline", "oddOneOut", "doubleFeature", "detective", "memory", "heist", "directorsCut"]
    private struct Fact {
        let title: String
        let year: Int
        let actors: Set<String>
        let plotWords: [String]
    }
    // Declared prior movie knowledge, independent of fixture placement or answer IDs.
    private let facts: [Fact] = [
        Fact(title: "Titanic", year: 1997, actors: ["Leonardo DiCaprio"], plotWords: ["ocean liner"]),
        Fact(title: "The Matrix", year: 1999, actors: ["Keanu Reeves"], plotWords: ["simulation"]),
        Fact(title: "Jurassic Park", year: 1993, actors: ["Sam Neill", "Samuel L. Jackson"], plotWords: ["dinosaurs"]),
        Fact(title: "Inception", year: 2010, actors: ["Leonardo DiCaprio", "Michael Caine"], plotWords: ["dreams"]),
        Fact(title: "Barbie", year: 2023, actors: ["Margot Robbie", "Ryan Gosling"], plotWords: ["pink world"]),
        Fact(title: "Avengers: Endgame", year: 2019, actors: ["Robert Downey Jr.", "Zoe Saldaña", "Samuel L. Jackson"], plotWords: ["universe-changing"]),
        Fact(title: "John Wick", year: 2014, actors: ["Keanu Reeves"], plotWords: ["retired assassin"]),
        Fact(title: "La La Land", year: 2016, actors: ["Ryan Gosling"], plotWords: ["jazz musician"]),
        Fact(title: "Avatar", year: 2009, actors: ["Sam Worthington", "Zoe Saldaña"], plotWords: ["alien moon"]),
        Fact(title: "Interstellar", year: 2014, actors: ["Matthew McConaughey", "Michael Caine"], plotWords: ["wormhole"]),
        Fact(title: "Toy Story", year: 1995, actors: ["Tom Hanks"], plotWords: ["cowboy toy", "space-ranger"]),
        Fact(title: "Back to the Future", year: 1985, actors: ["Michael J. Fox"], plotWords: ["modified car"]),
    ]
    private struct DisplayedControl { let identifier: String; let label: String; let enabled: Bool }
    private enum PlayError: Error { case stop(String), blocked(String), harness(String) }
    private var app = XCUIApplication()
    private var persona = ""
    private var game = ""
    private var started = Date()
    private var actions: [[String: Any]] = []
    private var helpCount = 0
    private var attemptCount = 0
    private var acceptedCount = 0
    private var gameplayTapCount = 0
    private var visionWaitSeconds: TimeInterval = 0
    private var resultText = ""
    private var resultPoints = ""
    private var resultButtons: [String] = []
    private var resumed = false
    private var resumeVerified = false
    private var replayStarted = false
    private var limits: [String] = []
    private var mistakes: [String] = []
    private var didWrongFirst = false

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ARCADE_PERSONA_PLAYTHROUGH"] == "1",
                          "Manual persona suite: set TEST_RUNNER_ARCADE_PERSONA_PLAYTHROUGH=1 and provide live screenshot judgments.")
    }
    func testP1() { run("P1") }
    func testP2() { run("P2") }
    func testP3() { run("P3") }
    func testP4() { run("P4") }
    func testP5() { run("P5") }
    func testP5Recovery() { run("P5", kinds: games.filter { $0 != "casting" }) }
    func testP6() { run("P6") }
    func testP7() { run("P7") }
    func testClueRecovery() {
        for id in ["P1", "P2", "P3", "P4"] { run(id, kinds: ["detective"]) }
    }
    func testP5EvidenceRecovery() { run("P5", kinds: ["heist", "directorsCut"]) }
    func testP6EvidenceRecovery() { run("P6", kinds: ["heist"]) }

    private var titleOnly: Bool { persona == "P1" || persona == "P7" }
    private var fullFacts: Bool { persona == "P2" || persona == "P5" }
    private var knownFacts: [Fact] {
        if fullFacts { return facts }
        let names: Set<String> = titleOnly ? ["Toy Story", "The Matrix", "Jurassic Park"] : ["Toy Story", "The Matrix", "Jurassic Park", "Titanic", "Inception"]
        return facts.filter { names.contains($0.title) }.map { f in
            // Moderate policies know familiar leads, not the expert relationship sheet.
            Fact(title: f.title, year: f.year, actors: titleOnly ? [] : Set(f.actors.filter { !["Samuel L. Jackson", "Michael Caine"].contains($0) }), plotWords: titleOnly ? [] : f.plotWords)
        }
    }
    private var cellID: String { "persona-cell-\(persona)-\(game)" }
    private func makeApp(reset: Bool) -> XCUIApplication {
        let instance = XCUIApplication()
        instance.launchArguments = ["--preview-video-disable-monetization", "--movie-quiz-fixture", "--daily-puzzle-use-fallback", "--arcade-test", "--arcade-game=" + game,
            "-AppleLanguages", persona == "P7" ? "(es)" : "(en)", "-AppleLocale", persona == "P7" ? "es_ES" : "en_US",
            "-showOnboarding", "NO", "-userHasPurchasedTipJar", persona == "P6" ? "NO" : "YES", "-disableTranslucentBackground", "YES"]
        if reset { instance.launchArguments.append("--arcade-reset") }
        if persona == "P5" { instance.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        return instance
    }
    private func run(_ id: String, kinds: [String]? = nil) {
        persona = id
        for kind in kinds ?? games {
            print("PERSONA_CELL_START \(id) \(kind)")
            game = kind; started = Date(); actions = []; helpCount = 0; attemptCount = 0; acceptedCount = 0; gameplayTapCount = 0; visionWaitSeconds = 0; resultText = ""; resultPoints = ""; resultButtons = []
            resumed = false; resumeVerified = false; replayStarted = false; mistakes = []; didWrongFirst = false
            limits = ["Assigned scripted persona; no human enjoyment or voluntary replay evidence.", "Fresh seed-0 fixture; ads and onboarding disabled.", "Image decisions use the current screenshot and a bounded live root-agent vision judgment; declared facts and visible feedback guide other choices."]
            if persona == "P6" { limits.append("Unpaid fixture, monetization suppressed; no normal startup ad, live purchase or restore evidence. Payment scan covers only isolated game result controls.") }
            else { limits.append("Fixture purchase entitlement enabled; this run does not validate ordinary free-user monetization.") }
            if persona == "P5" { limits.append("Accessibility XXXL only; VoiceOver and Reduce Motion not exercised.") }
            if persona == "P7" { limits.append("Spanish locale; weak-English policy, controller can locate untranslated controls.") }
            var outcome = "automation_failed"
            var stopReason = ""
            app = makeApp(reset: true); app.launch()
            do {
                guard app.staticTexts["arcade.roundTitle"].waitForExistence(timeout: 15) else { throw PlayError.harness("Fixture round did not appear") }
                shot("start")
                if persona == "P7" {
                    let texts = visibleText()
                    if texts.contains("Who’s in the cast?") || texts.contains("Three movies came out") || texts.contains("Which came out first?") || texts.contains("Pair movies starring") || texts.contains("THE ANCHOR") {
                        throw PlayError.stop("Untranslated English knowledge-dependent instructions")
                    }
                }
                try play()
                guard isResult else { throw PlayError.harness("Policy exited without result or stop") }
                outcome = helpCount > 0 ? "earned_with_help" : "earned"
                captureResult(); shot("result")
                if persona == "P2" {
                    do {
                        try tapControl("arcade.playAgain", type: "scripted_replay", admin: true)
                        replayStarted = !isResult && app.staticTexts["arcade.roundTitle"].exists
                        shot("scripted-replay-start")
                    } catch { limits.append("Earned first round preserved; scripted replay check failed: \(error)") }
                    limits.append("Second round was started by assigned policy, not voluntary replay; not completed.")
                }
            } catch PlayError.stop(let reason) {
                stopReason = reason; shot("stop")
                do {
                    try tapControl("arcade.skip", type: "administrative_reveal", admin: true)
                    outcome = isResult ? "revealed_after_stop" : "automation_failed"
                    captureResult(); shot("result")
                } catch { outcome = "automation_failed"; limits.append("Administrative reveal failed: \(error)") }
            } catch PlayError.blocked(let reason) { outcome = "ui_blocked"; stopReason = reason; shot("stop") }
            catch { outcome = "automation_failed"; stopReason = String(describing: error); shot("stop") }
            attachTrace(outcome: outcome, reason: stopReason)
            app.terminate()
        }
    }
    private var isResult: Bool { app.buttons["arcade.playAgain"].exists }
    private func visibleText() -> String {
        let staticLabels = app.staticTexts.allElementsBoundByIndex.filter(\.exists).map(\.label)
        // SwiftUI Label can combine the opened Detective plot into an otherElement.
        // Read only declared phrases exposed by the current accessibility tree.
        var groupedClues: [String] = []
        if game == "detective" {
            let phrases = knownFacts.flatMap(\.plotWords)
            if !phrases.isEmpty {
                let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: phrases.map { NSPredicate(format: "label CONTAINS[cd] %@", $0) })
                let query = app.descendants(matching: .any).matching(predicate)
                for element in query.allElementsBoundByIndex where element.exists {
                    let label = element.label
                    if !label.isEmpty { groupedClues.append(label) }
                }
            }
        }
        return (staticLabels + Array(Set(groupedClues)).sorted()).joined(separator: "\n")
    }
    private func feedback() -> String {
        let element = app.descendants(matching: .any)["arcade.feedback"]
        return element.exists ? element.label : ""
    }
    private func stateSignature() -> String {
        let status = ["arcade.points", "arcade.pairs", "arcade.cut.progress", "arcade.heist.lock"].map { id in
            let element = app.staticTexts[id]; return element.exists ? id + ":" + element.label : ""
        }
        let chosen = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'arcade.card.' OR identifier BEGINSWITH 'arcade.choice.'")).allElementsBoundByIndex
            .filter { $0.exists && (($0.value as? String == "Selected") || ($0.value as? String == "Matched") || !$0.isEnabled) }
            .map { $0.identifier + ":" + $0.label + ":" + String(describing: $0.value ?? "") }.sorted()
        return (status + chosen).joined(separator: "|")
    }
    private func checkBudget() throws {
        if gameplayTapCount >= 45 { throw PlayError.stop("runner_limit: 45 UI gameplay taps") }
        if Date().timeIntervalSince(started) - visionWaitSeconds > 150 { throw PlayError.stop("runner_limit: 150 seconds automation runtime") }
    }
    private func reach(_ element: XCUIElement) -> Bool {
        if !element.exists {
            // Lazy children above the viewport cannot direct a scroll by their frame.
            for _ in 0..<5 { scroll(up: false) }
        }
        for _ in 0..<12 {
            if element.exists {
                let frame = element.frame
                if element.isHittable && frame.midY >= app.frame.minY + 105 && frame.midY <= app.frame.maxY - 70 { return true }
                if frame.midY < app.frame.minY + 105 { scroll(up: false); continue }
            }
            scroll(up: true)
        }
        return false
    }
    private func scroll(up: Bool) {
        // Keep the gesture inside content; an application-wide downward swipe
        // can dismiss this sheet and invalidate every subsequent query.
        let area = app.scrollViews.containing(.staticText, identifier: "arcade.roundTitle").firstMatch
        guard area.exists else { return }
        let start = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.75 : 0.35))
        let end = area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.35 : 0.75))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
    private func tapControl(_ id: String, type: String, admin: Bool = false) throws {
        try tap(app.buttons[id], type: type, admin: admin)
    }
    private func tap(_ element: XCUIElement, type: String, admin: Bool = false) throws {
        if !admin { try checkBudget() }
        guard reach(element), element.isEnabled else { throw PlayError.blocked("Requested control unreachable or disabled") }
        let targetID = element.identifier
        let targetLabel = element.label
        let signature = stateSignature()
        let beforeFeedback = feedback()
        element.tap()
        if !admin { gameplayTapCount += 1 }
        // XCTest waits for UI idleness; no arbitrary answer timing or engine read.
        let after = stateSignature()
        let accepted = signature != after || beforeFeedback != feedback() || isResult
        if !admin && accepted { acceptedCount += 1 }
        if type == "help" { helpCount += 1 }
        if type == "attempt" { attemptCount += 1 }
        let currentFeedback = feedback()
        if currentFeedback.contains("Not a pair") || currentFeedback.contains("ruled out") || currentFeedback.contains("not in this cast") || currentFeedback.contains("earlier film") || currentFeedback.contains("so it belongs") || currentFeedback.contains("Not that year") {
            mistakes.append(currentFeedback)
        }
        if type == "attempt", element.exists, element.value as? String == "Ruled out" { mistakes.append("Displayed option ruled out: " + targetLabel) }
        actions.append(["type": type, "target": targetID, "displayed_label": targetLabel, "visible_feedback": currentFeedback, "accepted_state_change": accepted, "before_signature": signature, "after_signature": after, "before_feedback": beforeFeedback, "points": app.staticTexts["arcade.points"].exists ? app.staticTexts["arcade.points"].label : ""])
        if persona == "P3" && !resumed && !admin && accepted {
            resumed = true
            let before = stateSignature()
            let terminalBeforeInterruption = isResult
            shot("before-interruption")
            app.terminate(); app = makeApp(reset: false); app.launch()
            guard app.staticTexts["arcade.roundTitle"].waitForExistence(timeout: 15) else { throw PlayError.harness("Relaunch did not return to the round") }
            resumeVerified = before == stateSignature()
            actions.append(["type": "terminate_relaunch", "before": before, "after": stateSignature(), "resume_verified": resumeVerified, "terminal_before_interruption": terminalBeforeInterruption])
            limits.append("Recovery comparison covers points, selected/matched cards and progress labels; it does not prove all clues, feedback or board state persisted.")
            if terminalBeforeInterruption { limits.append("First accepted action completed this round; interruption checked terminal-result recovery, not unfinished-round recovery.") }
            shot("after-interruption")
            if !resumeVerified { throw PlayError.stop("Visible progress or selected state changed across interruption") }
        }
    }
    private func discoverControls(prefix: String, expectedCount: Int) -> [DisplayedControl] {
        var seen: [String: DisplayedControl] = [:]
        var discoveryOrder: [String] = []
        func collect() {
            let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            for element in query.allElementsBoundByIndex where element.exists {
                // Freeze labels while the lazy element is instantiated; identifiers
                // only reacquire controls after scrolling, never choose the answer.
                let identifier = element.identifier
                if seen[identifier] == nil { discoveryOrder.append(identifier) }
                seen[identifier] = DisplayedControl(identifier: identifier, label: element.label, enabled: element.isEnabled)
            }
        }
        collect()
        if seen.count < expectedCount {
            for _ in 0..<5 { scroll(up: false) }
            for _ in 0..<8 {
                collect()
                if seen.count >= expectedCount { break }
                scroll(up: true)
            }
        }
        collect()
        return discoveryOrder.compactMap { seen[$0] }.filter(\.enabled)
    }
    private func choices() -> [DisplayedControl] {
        discoverControls(prefix: "arcade.choice.", expectedCount: game == "directorsCut" ? 3 : 4)
    }
    private func cards() -> [DisplayedControl] {
        discoverControls(prefix: "arcade.card.", expectedCount: 6)
    }
    private func fact(_ title: String) -> Fact? { knownFacts.first { $0.title == title } }
    private func play() throws {
        switch game {
        case "memory": try playMemory()
        case "doubleFeature": try playConnections()
        case "scramble":
            limits.append("Used Assemble for Me: assisted restoration, not autonomous visual reconstruction.")
            try tapControl("arcade.assemble", type: "help")
            try playTitleChoices()
        case "detective":
            try tapControl("arcade.clue.plot", type: "help")
            if persona == "P7" { throw PlayError.stop("Plot clue is untranslated English; no declared native-language inference") }
            try playTitleChoices()
        case "scene": try playTitleChoices()
        case "casting": try playCasting()
        case "oddOneOut": try playOddOne()
        case "directorsCut": try playOrder()
        case "timeline": try playTimeline()
        case "heist": try playHeist()
        default: throw PlayError.harness("Unknown game")
        }
    }
    private func playMemory() throws {
        var learned: [String: String] = [:]
        while !app.buttons["arcade.memory.finish"].exists {
            try checkBudget()
            if app.staticTexts["arcade.pairs"].exists && app.staticTexts["arcade.pairs"].label == "3 of 3 pairs" {
                try tapControl("arcade.memory.finish", type: "progress")
                return
            }
            if app.buttons["arcade.retryPair"].exists { try tapControl("arcade.retryPair", type: "progress") }
            let available = cards()
            guard !available.isEmpty else { throw PlayError.harness("No enabled memory cards before completion") }
            var first = available.first!
            if let candidate = available.first(where: { card in
                guard let label = learned[card.identifier] else { return false }
                return available.contains { $0.identifier != card.identifier && learned[$0.identifier] == label }
            }) { first = candidate }
            else if let unseen = available.first(where: { learned[$0.identifier] == nil }) { first = unseen }
            let firstID = first.identifier
            try tap(app.buttons[first.identifier], type: "selection")
            learned[firstID] = app.buttons[firstID].label
            let secondAvailable = cards().filter { $0.identifier != firstID }
            guard let second = secondAvailable.first(where: { learned[$0.identifier] == learned[firstID] }) ?? secondAvailable.first(where: { learned[$0.identifier] == nil }) ?? secondAvailable.first else {
                throw PlayError.harness("No second memory card")
            }
            let secondID = second.identifier
            try tap(app.buttons[second.identifier], type: "attempt")
            learned[secondID] = app.buttons[secondID].label
            actions.append(["type": "learned_visible_cards", "first": firstID, "first_title": learned[firstID] ?? "", "second": secondID, "second_title": learned[secondID] ?? ""])
        }
        try tapControl("arcade.memory.finish", type: "progress")
    }
    private func playConnections() throws {
        if titleOnly { throw PlayError.stop("Shared-actor knowledge required; persona has title recognition only") }
        var tried = Set<String>()
        while !isResult {
            try checkBudget()
            if app.buttons["arcade.retryPair"].exists { try tapControl("arcade.retryPair", type: "progress") }
            let available = cards()
            var candidates: [(DisplayedControl, DisplayedControl, Bool)] = []
            let text = visibleText()
            for i in available.indices {
                for j in available.indices where j > i {
                    let a = available[i], b = available[j]
                    let key = [a.identifier, b.identifier].sorted().joined(separator: "/")
                    guard !tried.contains(key) else { continue }
                    let shared = (fact(a.label)?.actors ?? []).intersection(fact(b.label)?.actors ?? [])
                    let knownPair = shared.contains { text.contains($0) }
                    candidates.append((a, b, knownPair))
                }
            }
            guard !candidates.isEmpty else { throw PlayError.stop("No new pair within declared facts and feedback") }
            let pair: (DisplayedControl, DisplayedControl, Bool)
            if persona == "P6" && !didWrongFirst, let exploratory = candidates.first(where: { !$0.2 }) { pair = exploratory; didWrongFirst = true; limits.append("Connection outside known relationships was an exploratory guess, not a guaranteed mistake.") }
            else if let known = candidates.first(where: { $0.2 }) { pair = known }
            else {
                if !fullFacts { throw PlayError.stop("Remaining connection outside declared actor knowledge") }
                pair = candidates[0]; limits.append("Unknown connection tested through visible mismatch feedback.")
            }
            tried.insert([pair.0.identifier, pair.1.identifier].sorted().joined(separator: "/"))
            let firstID = pair.0.identifier, secondID = pair.1.identifier
            try tap(app.buttons[firstID], type: "selection"); try tap(app.buttons[secondID], type: "attempt")
        }
    }
    private func playTitleChoices() throws {
        var failures = 0
        var visuallyRecognizedTitle: String?
        while !isResult {
            try checkBudget()
            let imageDecision = failures == 0 && (game == "scene" || game == "scramble" || (game == "heist" && app.staticTexts["arcade.heist.lock"].label.contains("1 OF 3")))
            var imageScreenshot: XCUIScreenshot?
            if imageDecision {
                let title = app.staticTexts["arcade.roundTitle"]
                for _ in 0..<5 {
                    if title.exists && title.frame.minY >= app.frame.minY + 100 { break }
                    scroll(up: false)
                }
                if persona == "P5" { scroll(up: true) }
                // Capture image before discovering choices below the fold; choice
                // scrolling must not replace the actual image used for judgment.
                imageScreenshot = app.screenshot()
            }
            let available = choices()
            guard !available.isEmpty else { throw PlayError.harness("No movie choices after bounded lazy-control discovery") }
            let text = visibleText()
            let recognized = titleOnly ? nil : knownFacts.first { f in f.plotWords.contains(where: { text.localizedCaseInsensitiveContains($0) }) }
            var choice: DisplayedControl?
            if imageDecision, let screenshot = imageScreenshot {
                choice = try liveImageChoice(available, screenshot: screenshot)
                visuallyRecognizedTitle = choice?.label
            } else if let title = visuallyRecognizedTitle, let remembered = available.first(where: { $0.label == title }) {
                // Retain this cell's actual image judgment after an assigned mistake;
                // remembered recognition is not a seed or hidden-state answer oracle.
                choice = remembered
            } else { choice = recognized.flatMap { known in available.first { $0.label == known.title } } }
            if choice == nil {
                let permitted = available.filter { fact($0.label) != nil }
                choice = permitted.first ?? (titleOnly ? nil : available.first)
                limits.append("No graphic recognition: candidate selected from known displayed title, then feedback/elimination.")
            }
            if persona == "P6" && !didWrongFirst, let preferred = choice, let different = available.first(where: { $0.label != preferred.label }) {
                choice = different; didWrongFirst = true
                if recognized == nil && !imageDecision { limits.append("Alternate title was an exploratory guess; no guaranteed wrong answer known.") }
            }
            guard let target = choice else { throw PlayError.stop("No displayed title recognized under persona policy") }
            try tap(app.buttons[target.identifier], type: "attempt")
            if isResult || app.buttons["arcade.heist.next"].exists { return }
            failures += 1
            if titleOnly && failures >= 2 { throw PlayError.stop("Two unsuccessful recognized-title guesses") }
            if !fullFacts && !titleOnly && failures >= 2 { throw PlayError.stop("Limited retry budget exhausted") }
            if persona == "P7" { throw PlayError.stop("English feedback/trivia required beyond title recognition") }
        }
    }
    private func liveImageChoice(_ available: [DisplayedControl], screenshot: XCUIScreenshot) throws -> DisplayedControl {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("arcade-persona-live", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        print("PERSONA_VISION_DIRECTORY \(directory.path)")
        let phase = game == "heist" ? "lock1" : "image"
        let identifier = cellID + "-" + phase + "-" + UUID().uuidString
        let imageURL = directory.appendingPathComponent(identifier + ".png")
        let requestURL = directory.appendingPathComponent(identifier + "-request.json")
        let replyURL = directory.appendingPathComponent(identifier + "-reply.json")
        try screenshot.pngRepresentation.write(to: imageURL, options: .atomic)
        let request: [String: Any] = ["request_id": identifier, "persona": persona, "game": game, "phase": phase,
            "screenshot_path": imageURL.path, "reply_path": replyURL.path,
            "displayed_choices": available.map(\.label), "permitted_prior_titles": knownFacts.map(\.title),
            "instructions": "Inspect this actual current runtime image. Return title and visual basis only if recognizable within declared familiarity; otherwise stop_reason. Do not use seeds, IDs, old tests or answer keys."]
        try JSONSerialization.data(withJSONObject: request, options: [.prettyPrinted, .sortedKeys]).write(to: requestURL, options: .atomic)
        let waiting = Date()
        defer { visionWaitSeconds += Date().timeIntervalSince(waiting) }
        while Date().timeIntervalSince(waiting) < 180 {
            if let data = try? Data(contentsOf: replyURL), let reply = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let stop = reply["stop_reason"] as? String { throw PlayError.stop("Live visual recognition stop: " + stop) }
                guard let title = reply["title"] as? String, let basis = reply["basis"] as? String,
                      knownFacts.contains(where: { $0.title == title }), let element = available.first(where: { $0.label == title }) else {
                    throw PlayError.harness("Live vision reply did not name a displayed, permitted title with a basis")
                }
                actions.append(["type": "live_visual_judgment", "displayed_title": title, "vision_basis": basis, "screenshot_path": imageURL.path, "request_id": identifier])
                return element
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        throw PlayError.harness("Bounded live vision handoff timed out after 180 seconds")
    }
    private func playCasting() throws {
        if titleOnly { throw PlayError.stop("Actor knowledge required beyond title recognition") }
        let text = visibleText()
        let movie = knownFacts.first { f in text.contains(f.title) }
        let available = choices()
        let preferred = available.first { movie?.actors.contains($0.label) == true }
        if persona == "P6", let answer = preferred, let other = available.first(where: { $0.label != answer.label }) { try tap(app.buttons[other.identifier], type: "attempt"); didWrongFirst = true }
        guard let target = choices().first(where: { movie?.actors.contains($0.label) == true }) else { throw PlayError.stop("Displayed film/cast outside declared actor knowledge") }
        try tap(app.buttons[target.identifier], type: "attempt")
    }
    private func playOddOne() throws {
        if titleOnly { throw PlayError.stop("Release-era trivia outside declared knowledge") }
        let text = visibleText()
        let includes: (Int) -> Bool
        if text.contains("1990s") { includes = { (1990...1999).contains($0) } }
        else if text.contains("before 2000") { includes = { $0 < 2000 } }
        else if text.contains("2010 or later") { includes = { $0 >= 2010 } }
        else if text.contains("2000 or later") { includes = { $0 >= 2000 } }
        else { throw PlayError.harness("Release-era instruction not readable") }
        let available = choices()
        guard available.allSatisfy({ fact($0.label) != nil }) else { throw PlayError.stop("One or more release years outside declared knowledge") }
        guard let target = available.first(where: { !includes(fact($0.label)!.year) }) else { throw PlayError.harness("No odd year from displayed facts") }
        let targetID = target.identifier
        if persona == "P6", let other = available.first(where: { $0.label != target.label }) { try tap(app.buttons[other.identifier], type: "attempt"); didWrongFirst = true }
        try tap(app.buttons[targetID], type: "attempt")
    }
    private func playOrder() throws {
        if titleOnly { throw PlayError.stop("Chronological release knowledge required") }
        while !isResult {
            try checkBudget()
            let available = choices()
            guard available.allSatisfy({ fact($0.label) != nil }), let target = available.min(by: { fact($0.label)!.year < fact($1.label)!.year }) else {
                throw PlayError.stop("Chronology includes a title/year outside declared knowledge")
            }
            let targetID = target.identifier
            if persona == "P6" && !didWrongFirst, let other = available.max(by: { fact($0.label)!.year < fact($1.label)!.year }), other.label != target.label {
                try tap(app.buttons[other.identifier], type: "attempt"); didWrongFirst = true
            }
            try tap(app.buttons[targetID], type: "attempt")
        }
    }
    private func playTimeline() throws {
        if titleOnly { throw PlayError.stop("Before/after year knowledge required") }
        while !isResult {
            try checkBudget()
            if app.buttons["arcade.timeline.next"].exists { try tapControl("arcade.timeline.next", type: "progress"); continue }
            let labels = app.staticTexts.allElementsBoundByIndex.filter(\.exists).map(\.label)
            guard let anchorIndex = labels.firstIndex(of: "THE ANCHOR"), anchorIndex + 2 < labels.count,
                  let anchorYear = Int(labels[anchorIndex + 2]) else {
                throw PlayError.harness("Visible anchor parser failed")
            }
            guard let progressIndex = labels.firstIndex(where: { $0.range(of: "^Movie [0-9]+ of 3$", options: .regularExpression) != nil }), progressIndex + 1 < labels.count else {
                throw PlayError.harness("Current timeline movie label parser failed")
            }
            let incomingTitle = labels[progressIndex + 1]
            guard let incoming = fact(incomingTitle) else {
                throw PlayError.stop("Incoming title/year outside declared knowledge: " + incomingTitle)
            }
            let id = incoming.year > anchorYear ? "arcade.after" : "arcade.before"
            let selectedID = persona == "P6" && !didWrongFirst ? (id == "arcade.after" ? "arcade.before" : "arcade.after") : id
            if persona == "P6" && !didWrongFirst { didWrongFirst = true }
            try tapControl(selectedID, type: "attempt")
        }
    }
    private func playHeist() throws {
        while !isResult {
            try checkBudget()
            if app.buttons["arcade.heist.next"].exists { try tapControl("arcade.heist.next", type: "progress"); continue }
            let lock = app.staticTexts["arcade.heist.lock"].label
            if lock.contains("2 OF 3") {
                if titleOnly { throw PlayError.stop("Heist cast lock requires unknown actor knowledge") }
                try playCasting()
            } else { try playTitleChoices() }
        }
    }
    private func shot(_ stage: String) {
        let screenshot = app.screenshot()
        try? screenshot.pngRepresentation.write(to: evidenceDirectory.appendingPathComponent(cellID + "-" + stage + ".png"), options: .atomic)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = cellID + "-" + stage; attachment.lifetime = .keepAlways; add(attachment)
    }
    private var evidenceDirectory: URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("arcade-persona-evidence", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    private func arcadeResultButtonLabels() -> [String] {
        let content = app.scrollViews.containing(.staticText, identifier: "arcade.roundTitle").firstMatch
        let labels = content.exists ? content.buttons.allElementsBoundByIndex.filter(\.exists).map(\.label) : []
        let toolbar = app.buttons.matching(NSPredicate(format: "identifier == 'arcade.games' OR identifier == 'arcade.close'")).allElementsBoundByIndex.filter(\.exists).map(\.label)
        return labels + toolbar
    }
    private func captureResult() {
        resultText = visibleText()
        resultPoints = app.staticTexts["arcade.points"].exists ? app.staticTexts["arcade.points"].label : ""
        resultButtons = arcadeResultButtonLabels()
        // Inspect the actual result's lower controls before any assigned replay.
        scroll(up: true); scroll(up: true)
        resultButtons += arcadeResultButtonLabels()
        resultButtons = Array(Set(resultButtons)).sorted()
        actions.append(["type": "result_inspection", "scope": "arcade_sheet", "displayed_buttons": resultButtons])
    }
    private func attachTrace(outcome: String, reason: String) {
        let text = resultText.isEmpty ? visibleText() : resultText
        let buttons = resultButtons
        let utility = buttons.contains { $0.localizedCaseInsensitiveContains("watchlist") || $0.localizedCaseInsensitiveContains("where to watch") || $0.localizedCaseInsensitiveContains("film details") }
        let payment = buttons.contains { $0.localizedCaseInsensitiveContains("purchase") || $0.localizedCaseInsensitiveContains("subscribe") || $0.localizedCaseInsensitiveContains("pay to") }
        let trace: [String: Any] = ["schema": 1, "harness_revision": "live-vision-retained-v3", "result_inspection_scope": "arcade_sheet", "persona": persona, "game": game, "seed": 0,
            "locale": persona == "P7" ? "es_ES" : "en_US", "large_text": persona == "P5",
            "outcome": outcome, "stop_reason": reason, "actions": actions, "action_count": gameplayTapCount, "accepted_action_count": acceptedCount, "action_count_definition": "Attempted UI gameplay taps; separate accepted_action_count requires visible state or feedback change",
            "help_count": helpCount, "attempt_count": attemptCount, "mistake_evidence": Array(Set(mistakes)).sorted(),
            "points_label": resultPoints.isEmpty ? (app.staticTexts["arcade.points"].exists ? app.staticTexts["arcade.points"].label : "") : resultPoints,
            "result_text": text, "resumed": resumed, "resume_verified": resumeVerified, "replay_started": replayStarted,
            "utility_action_found": utility, "payment_gate_found": payment, "result_controls_inspected": !resultButtons.isEmpty, "limitations": limits,
            "declared_prior_titles": knownFacts.map(\.title), "declared_prior_facts": knownFacts.map { ["title": $0.title, "year": titleOnly ? "unknown" : String($0.year), "actors": $0.actors.sorted().joined(separator: ", "), "plot_words": $0.plotWords.joined(separator: ", ")] }, "runtime_seconds": Date().timeIntervalSince(started), "vision_wait_seconds": visionWaitSeconds, "active_automation_seconds": Date().timeIntervalSince(started) - visionWaitSeconds]
        if let data = try? JSONSerialization.data(withJSONObject: trace, options: [.prettyPrinted, .sortedKeys]) {
            do { try data.write(to: evidenceDirectory.appendingPathComponent(cellID + ".json"), options: .atomic) }
            catch { XCTFail("Trace persistence failed for \(cellID): \(error)") }
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = cellID + ".json"; attachment.lifetime = .keepAlways; add(attachment)
        } else { XCTFail("Trace JSON serialization failed for \(cellID)") }
        print("PERSONA_CELL_COMPLETE \(persona) \(game) \(outcome) \(reason)")
    }
}
