import XCTest

final class CronicaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsHomeAndDailyPuzzleCard() {
        let app = makeApp()

        app.launch()

        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["dailyPuzzle.homeCard"].waitForExistence(timeout: 40))
    }

    func testTappingDailyPuzzleCardOpensAndDismissesModal() {
        let app = makeApp()

        app.launch()

        let homeCard = app.buttons["dailyPuzzle.homeCard"]
        XCTAssertTrue(homeCard.waitForExistence(timeout: 40))

        homeCard.tap()

        let modal = app.descendants(matching: .any)["dailyPuzzle.modal"]
        XCTAssertTrue(modal.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["movieQuiz.choice.597"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["movieQuiz.skip"].waitForExistence(timeout: 10))

        let dismissButton = app.buttons["dailyPuzzle.dismiss"]
        XCTAssertTrue(dismissButton.waitForExistence(timeout: 10))
        dismissButton.tap()

        XCTAssertTrue(waitForNonExistence(of: modal, timeout: 10))
        XCTAssertTrue(homeCard.waitForExistence(timeout: 10))
    }

    func testDailyPuzzleLaunchIntentOpensModalOnLaunch() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test")

        app.launch()

        let modal = app.descendants(matching: .any)["dailyPuzzle.modal"]
        XCTAssertTrue(modal.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["movieQuiz.choice.597"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["dailyPuzzle.dismiss"].waitForExistence(timeout: 10))
    }

    func testDailyPuzzleDeepLinkOpensModal() throws {
        let app = makeApp()
        app.launch()
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 20))

        let url = try XCTUnwrap(URL(string: "qscanlite://daily-puzzle"))
        app.open(url)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let openButton = springboard.buttons["Open"]
        if openButton.waitForExistence(timeout: 2) {
            openButton.tap()
        }

        let modal = app.descendants(matching: .any)["dailyPuzzle.modal"]
        XCTAssertTrue(modal.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["movieQuiz.choice.597"].waitForExistence(timeout: 10))
        attachScreenshot(named: "daily-puzzle-deep-link-opened")
    }

    func testFourRoundImageQuizCompletesAndAllowsExtraPlay() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test", forceFallbackPuzzle: true)
        app.launch()
        for id in [597, 603, 329, 27205] {
            let answer = app.buttons["movieQuiz.choice.\(id)"]
            XCTAssertTrue(answer.waitForExistence(timeout: 20))
            XCTAssertTrue(answer.isHittable)
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'movieQuiz.choice.'")).count, 4)
            XCTAssertFalse(app.textFields["dailyPuzzle.guessField"].exists)
            if id == 597 { attachScreenshot(named: "movie-quiz-four-choices") }
            answer.tap()
            if id == 329 {
                XCTAssertFalse(app.descendants(matching: .any)["dailyPuzzle.runSummary"].exists)
                XCTAssertFalse(app.buttons["dailyPuzzle.shareRunCTA"].exists)
            }
            if id != 27205 { app.buttons["dailyPuzzle.nextPuzzleCTA"].tap() }
        }
        let points = app.staticTexts["movieQuiz.runPoints"]
        XCTAssertTrue(points.waitForExistence(timeout: 10))
        XCTAssertTrue(points.label.contains("12 / 12"))
        XCTAssertTrue(app.staticTexts["4/4 solved"].exists)
        if !app.buttons["dailyPuzzle.shareRunCTA"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["dailyPuzzle.shareRunCTA"].isHittable)
        attachScreenshot(named: "movie-quiz-four-round-summary")
        app.buttons["dailyPuzzle.nextPuzzleCTA"].tap()
        XCTAssertTrue(app.buttons["movieQuiz.choice.346698"].waitForExistence(timeout: 10))
    }

    func testTileRevealsPersistWhenReopeningAndReduceAvailablePoints() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test", forceFallbackPuzzle: true)
        app.launch()
        let status = app.staticTexts["movieQuiz.revealStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        XCTAssertEqual(status.label, "1 of 9 tiles · Score up to 3")
        XCTAssertFalse(app.buttons["movieQuiz.tile.4"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'movieQuiz.tile.'")).count, 8)

        for tile in [0, 1, 2] {
            let cover = app.buttons["movieQuiz.tile.\(tile)"]
            XCTAssertTrue(cover.isHittable)
            cover.tap()
            XCTAssertTrue(waitForNonExistence(of: cover, timeout: 5))
        }
        XCTAssertEqual(status.label, "4 of 9 tiles · Score up to 2")
        attachScreenshot(named: "movie-quiz-four-tiles-revealed")

        app.buttons["dailyPuzzle.dismiss"].tap()
        let card = app.buttons["dailyPuzzle.homeCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertEqual(status.label, "4 of 9 tiles · Score up to 2")
        for tile in [0, 1, 2, 4] {
            XCTAssertFalse(app.buttons["movieQuiz.tile.\(tile)"].exists)
        }
        app.buttons["movieQuiz.choice.597"].tap()
        XCTAssertTrue(app.staticTexts["2 / 3 points"].waitForExistence(timeout: 10))
    }

    func testMixedRunAlternatesTilesAndZoomOutWithScoredReveals() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test", forceFallbackPuzzle: true)
        app.launch()
        let firstAnswer = app.buttons["movieQuiz.choice.597"]
        XCTAssertTrue(firstAnswer.waitForExistence(timeout: 20))
        firstAnswer.tap()
        app.buttons["dailyPuzzle.nextPuzzleCTA"].tap()

        let zoomStatus = app.staticTexts["movieQuiz.zoomStatus"]
        XCTAssertTrue(zoomStatus.waitForExistence(timeout: 20))
        XCTAssertEqual(zoomStatus.label, "Close-up · Score up to 3")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'movieQuiz.tile.'")).count, 0)
        let zoomOut = app.buttons["movieQuiz.zoomOut"]
        XCTAssertTrue(zoomOut.isHittable)
        XCTAssertEqual(zoomOut.label, "Zoom out · −1 point")
        attachScreenshot(named: "movie-quiz-zoom-close-up")

        zoomOut.tap()
        XCTAssertEqual(zoomStatus.label, "Wider view · Score up to 2")
        XCTAssertTrue(zoomOut.isHittable)
        zoomOut.tap()
        XCTAssertEqual(zoomStatus.label, "Full image · Score up to 1")
        XCTAssertTrue(waitForNonExistence(of: zoomOut, timeout: 5))
        attachScreenshot(named: "movie-quiz-zoom-full-image")

        app.buttons["movieQuiz.choice.603"].tap()
        XCTAssertTrue(app.staticTexts["1 / 3 points"].waitForExistence(timeout: 10))
        app.buttons["dailyPuzzle.nextPuzzleCTA"].tap()
        XCTAssertTrue(app.buttons["movieQuiz.choice.329"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["movieQuiz.revealStatus"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'movieQuiz.tile.'")).count, 8)
        XCTAssertFalse(app.buttons["movieQuiz.zoomOut"].exists)
    }

    func testUncoverImageAllowsAnswerWithoutTappingIndividualTiles() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test", forceFallbackPuzzle: true)
        app.launch()
        let uncover = app.buttons["movieQuiz.revealAll"]
        XCTAssertTrue(uncover.waitForExistence(timeout: 20))
        XCTAssertEqual(uncover.label, "Uncover image · score 1")
        XCTAssertTrue(uncover.isHittable)
        uncover.tap()
        XCTAssertTrue(waitForNonExistence(of: app.buttons["movieQuiz.tile.0"], timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'movieQuiz.tile.'")).count, 0)
        XCTAssertEqual(app.staticTexts["movieQuiz.revealStatus"].label, "9 of 9 tiles · Score up to 1")
        let clue = app.buttons["movieQuiz.showHint"]
        XCTAssertEqual(clue.label, "Show clue")
        clue.tap()
        XCTAssertEqual(app.staticTexts["movieQuiz.revealStatus"].label, "9 of 9 tiles · Score up to 1")
        let answer = app.buttons["movieQuiz.choice.597"]
        XCTAssertTrue(answer.isEnabled)
        answer.tap()
        XCTAssertTrue(app.staticTexts["1 / 3 points"].waitForExistence(timeout: 10))
        attachScreenshot(named: "movie-quiz-full-image-assisted-win")
    }

    func testLargeTextAllowsUncoveringImageAndFinishingRound() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test", forceFallbackPuzzle: true)
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()

        let status = app.staticTexts["movieQuiz.revealStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        let uncover = app.buttons["movieQuiz.revealAll"]
        scrollToVisible(uncover, in: app)
        XCTAssertTrue(uncover.isHittable)
        XCTAssertEqual(uncover.label, "Uncover image · score 1")
        attachScreenshot(named: "movie-quiz-large-text")
        uncover.tap()
        let revealed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "9 of 9 tiles · Score up to 1"),
            object: status
        )
        XCTAssertEqual(XCTWaiter.wait(for: [revealed], timeout: 10), .completed)
        XCTAssertEqual(status.label, "9 of 9 tiles · Score up to 1")

        let answer = app.buttons["movieQuiz.choice.597"]
        scrollToVisible(answer, in: app)
        XCTAssertTrue(answer.isHittable)
        answer.tap()
        XCTAssertTrue(app.staticTexts["1 / 3 points"].waitForExistence(timeout: 10))
    }

    func testWrongChoiceEliminatesAndRevealsFreeClue() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test", forceFallbackPuzzle: true)
        app.launch()
        let wrong = app.buttons["movieQuiz.choice.603"]
        XCTAssertTrue(wrong.waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["movieQuiz.hint"].exists)
        wrong.tap()
        XCTAssertFalse(wrong.isEnabled)
        XCTAssertTrue(app.otherElements["movieQuiz.hint"].exists || app.staticTexts["movieQuiz.hint"].exists)
        attachScreenshot(named: "movie-quiz-assisted-answer")
        app.buttons["movieQuiz.choice.597"].tap()
        XCTAssertTrue(app.staticTexts["2 / 3 points"].waitForExistence(timeout: 10))
    }

    func testNotificationLaunchAcceptsFirstGuess() {
        let app = makeApp(dailyPuzzleLaunchSource: "push_notification", forceFallbackPuzzle: true)
        app.launch()
        let answer = app.buttons["movieQuiz.choice.597"]
        XCTAssertTrue(answer.waitForExistence(timeout: 20))
        answer.tap()
        XCTAssertTrue(app.buttons["dailyPuzzle.nextPuzzleCTA"].waitForExistence(timeout: 10))
        let reminder = app.buttons["dailyPuzzle.reminderOptIn"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 10))
        XCTAssertTrue(reminder.isHittable)
        attachScreenshot(named: "movie-quiz-solved-reminder")
    }

    func testRevealAnswerContinuesRunWithoutKeyboard() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test", forceFallbackPuzzle: true)
        app.launch()
        let skip = app.buttons["movieQuiz.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 20))
        skip.tap()
        XCTAssertTrue(app.staticTexts["0 / 3 points"].waitForExistence(timeout: 10))
        app.buttons["dailyPuzzle.nextPuzzleCTA"].tap()
        XCTAssertTrue(app.buttons["movieQuiz.choice.603"].waitForExistence(timeout: 10))
    }

    func testOfflineContinuationShowsRecoveryAndPreservesSolvedPuzzle() {
        let app = makeApp(dailyPuzzleLaunchSource: "ui_test", forceFallbackPuzzle: true)
        app.launchArguments += ["--daily-puzzle-next-offline"]
        app.launch()
        let answer = app.buttons["movieQuiz.choice.597"]
        XCTAssertTrue(answer.waitForExistence(timeout: 20))
        answer.tap()
        let next = app.buttons["dailyPuzzle.nextPuzzleCTA"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        let alert = app.alerts["Couldn’t load the next puzzle"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        alert.buttons["Retry"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        alert.buttons["Stay Here"].tap()
        XCTAssertTrue(app.staticTexts["3 / 3 points"].exists)
        next.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        alert.buttons["Offline Puzzles"].tap()
        XCTAssertTrue(app.buttons["dailyPuzzle.archiveDismiss"].waitForExistence(timeout: 10))
    }

    private func makeApp(
        dailyPuzzleLaunchSource: String? = nil,
        developerMode: Bool = false,
        forceFallbackPuzzle: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--preview-video-disable-monetization", "--movie-quiz-fixture", "--daily-puzzle-use-fallback",
            "-AppleLanguages", "(en)",
            "-showOnboarding", "NO",
            "-selectedView", "home",
            "-userHasPurchasedTipJar", "YES",
            "-disableTranslucentBackground", "YES",
            "-displayDeveloperSettings", developerMode ? "YES" : "NO",
        ]

        for day in 15...20 {
            app.launchArguments += ["-dailyPuzzleProgress-2026-02-\(day)", "ui-test-empty"]
        }
        if let dailyPuzzleLaunchSource {
            app.launchArguments.append("--quiz-launch-source=" + dailyPuzzleLaunchSource)
        }

        if forceFallbackPuzzle {
            app.launchArguments.append("--daily-puzzle-use-fallback")
        }

        return app
    }

    private func arcadeApp(_ game: String, reset: Bool = true) -> XCUIApplication {
        let app = makeApp()
        app.launchArguments += ["-selectedView", "home", "--arcade-test", "--arcade-game=" + game]
        if reset { app.launchArguments.append("--arcade-reset") }
        return app
    }

    private func arcadeScrollTo(_ button: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if button.exists {
                let frame = button.frame
                let arcadeArea = app.scrollViews["arcade.scroll"]
                let screen = arcadeArea.exists ? arcadeArea.frame : app.frame
                let topInset: CGFloat = arcadeArea.exists ? 16 : 100
                let bottomInset: CGFloat = arcadeArea.exists ? 16 : 85
                if button.isHittable && frame.minY >= screen.minY + topInset && frame.maxY <= screen.maxY - bottomInset { return }
                if frame.minY < screen.minY + topInset { arcadeScroll(in: app, up: false); continue }
            }
            arcadeScroll(in: app, up: true)
        }
    }
    private func arcadeScroll(in app: XCUIApplication, up: Bool) {
        // Keep scroll gestures inside the sheet so a downward swipe cannot dismiss it.
        let roundArea = app.scrollViews.containing(.staticText, identifier: "arcade.roundTitle").firstMatch
        let arcadeArea = app.scrollViews["arcade.scroll"]
        let area = arcadeArea.exists ? arcadeArea : roundArea.exists ? roundArea : app.scrollViews.containing(.button, identifier: "arcade.daily").firstMatch
        guard area.exists else { return }
        area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.75 : 0.35))
            .press(forDuration: 0.05, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: up ? 0.35 : 0.75)))
    }

    private func arcadeTap(_ id: String, in app: XCUIApplication) {
        let button = app.buttons[id]
        _ = button.waitForExistence(timeout: 3)
        arcadeScrollTo(button, in: app)
        XCTAssertTrue(button.waitForExistence(timeout: 5), id)
        XCTAssertTrue(button.isHittable, id)
        button.tap()
    }

    private func assertArcadeResult(_ app: XCUIApplication, screenshot: String) {
        let replay = app.buttons["arcade.playAgain"]
        XCTAssertTrue(replay.waitForExistence(timeout: 10))
        arcadeScrollTo(replay, in: app)
        XCTAssertTrue(replay.isHittable)
        let viewport = app.scrollViews["arcade.scroll"].frame
        XCTAssertGreaterThanOrEqual(replay.frame.minY, viewport.minY + 16)
        XCTAssertLessThanOrEqual(replay.frame.maxY, viewport.maxY - 16)
        attachScreenshot(named: screenshot)
    }

    func testArcadeCuratedEntryKeepsFullLibrary() {
        let app = makeApp()
        app.launchArguments += ["-selectedView", "home", "--arcade-test", "--arcade-reset"]
        app.launch()
        arcadeTap("arcade.home", in: app)
        XCTAssertTrue(app.buttons["arcade.daily"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["arcade.game.memory"].exists)
        XCTAssertTrue(app.buttons["arcade.game.scene"].exists)
        XCTAssertFalse(app.buttons["arcade.game.scramble"].exists)
        XCTAssertFalse(app.buttons["arcade.game.doubleFeature"].exists)
        XCTAssertFalse(app.buttons["arcade.game.casting"].exists, "Other modes should be behind All Games")
        attachScreenshot(named: "arcade-curated-lobby")
        arcadeTap("arcade.allGames", in: app)
        for kind in ["scene", "scramble", "memory", "doubleFeature", "casting", "timeline", "oddOneOut", "detective", "heist", "directorsCut"] {
            let tile = app.buttons["arcade.game." + kind]
            arcadeScrollTo(tile, in: app)
            XCTAssertTrue(tile.exists)
        }
        attachScreenshot(named: "arcade-lobby-bottom")
        // The featured grid is virtualized while scrolled below All Games.
        // Navigate via the persistent disclosure, then select the featured game.
        arcadeTap("arcade.allGames", in: app)
        XCTAssertEqual(app.buttons["arcade.allGames"].value as? String, "Collapsed")
        arcadeTap("arcade.game.scene", in: app)
        XCTAssertTrue(app.staticTexts["arcade.roundTitle"].waitForExistence(timeout: 10))
        attachScreenshot(named: "arcade-scene-start")
    }

    func testArcadeConnectionsCanBeSolvedFromVisibleCastClues() {
        let app = arcadeApp("doubleFeature"); app.launch()
        arcadeTap("arcade.help", in: app)
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "Up to 2 points")
        XCTAssertTrue(app.descendants(matching: .any)["arcade.knowledgeHint"].exists)
        attachScreenshot(named: "arcade-connections-guided")
        // Read the newly displayed actor names, then connect equal names.
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'arcade.card.'")).allElementsBoundByIndex
        let pairs = Dictionary(grouping: cards.map { ($0.identifier, $0.label.components(separatedBy: ", ").last ?? "") }, by: { $0.1 })
        XCTAssertEqual(pairs.count, 3)
        for pair in pairs.values.sorted(by: { $0[0].1 < $1[0].1 }) {
            XCTAssertEqual(pair.count, 2)
            for card in pair { arcadeTap(card.0, in: app) }
        }
        assertArcadeResult(app, screenshot: "arcade-connections-guided-result")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "2/3 points")
    }

    func testArcadeHelpedHeistResumesCastClue() {
        let app = arcadeApp("heist"); app.launch()
        arcadeTap("arcade.choice.862", in: app)
        arcadeTap("arcade.heist.next", in: app)
        arcadeTap("arcade.help", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["arcade.knowledgeHint"].label.contains("Robert Downey Jr."))
        app.terminate()
        let resumed = arcadeApp("heist", reset: false); resumed.launch()
        XCTAssertTrue(resumed.staticTexts["arcade.heist.lock"].waitForExistence(timeout: 10))
        XCTAssertEqual(resumed.staticTexts["arcade.points"].label, "Up to 2 points")
        XCTAssertTrue(resumed.descendants(matching: .any)["arcade.knowledgeHint"].label.contains("Robert Downey Jr."))
        attachScreenshot(named: "arcade-heist-restored-help")
        arcadeTap("arcade.choice.3223", in: resumed)
        arcadeTap("arcade.heist.next", in: resumed)
        arcadeTap("arcade.choice.329", in: resumed)
        assertArcadeResult(resumed, screenshot: "arcade-heist-helped-result")
        XCTAssertEqual(resumed.staticTexts["arcade.points"].label, "2/3 points")
    }

    func testArcadeSpanishDetectiveHasTranslatedCluesAndResult() {
        let app = arcadeApp("detective")
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
        XCTAssertTrue(app.staticTexts["arcade.roundTitle"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["arcade.roundTitle"].label, "Detective de cine")
        XCTAssertEqual(app.buttons["arcade.clue.plot"].label.contains("Ver la pista de la trama"), true)
        arcadeTap("arcade.clue.plot", in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Un juguete vaquero se siente amenazado")).firstMatch.exists)
        attachScreenshot(named: "arcade-spanish-detective-clue")
        arcadeTap("arcade.choice.862", in: app)
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "2/3 puntos")
        XCTAssertEqual(app.buttons["arcade.playAgain"].label, "Jugar otra ronda")
        attachScreenshot(named: "arcade-spanish-detective-result")
    }

    func testArcadeMexicanSpanishMemoryLargeTextFinishesWithoutTrivia() {
        let app = arcadeApp("memory")
        app.launchArguments += ["-AppleLanguages", "(es-MX)", "-AppleLocale", "es_MX", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["arcade.roundTitle"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["arcade.roundTitle"].label, "Memoria de carteles")
        for card in [0, 2, 1, 4, 3, 5] { arcadeTap("arcade.card.\(card)", in: app) }
        XCTAssertEqual(app.staticTexts["arcade.pairs"].label, "3 de 3 parejas")
        arcadeTap("arcade.memory.finish", in: app)
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 puntos")
        XCTAssertEqual(app.buttons["arcade.playAgain"].label, "Jugar otra ronda")
        attachScreenshot(named: "arcade-mexican-spanish-memory-large-text-result")
    }

    func testArcadeYearGuideIsAvailableInChoiceAccessibility() {
        let app = arcadeApp("oddOneOut"); app.launch()
        arcadeTap("arcade.help", in: app)
        XCTAssertEqual(app.buttons["arcade.choice.603"].value as? String, "1999")
        XCTAssertEqual(app.buttons["arcade.choice.299534"].value as? String, "2019")
        attachScreenshot(named: "arcade-year-guide")
        arcadeTap("arcade.choice.299534", in: app)
        assertArcadeResult(app, screenshot: "arcade-year-guide-result")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "2/3 points")
    }

    func testArcadeDirectorYearGuideAtLargeText() {
        let app = arcadeApp("directorsCut")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        arcadeTap("arcade.help", in: app)
        XCTAssertEqual(app.buttons["arcade.choice.862"].value as? String, "1995, Unplaced")
        attachScreenshot(named: "arcade-director-year-guide-large-text")
        for id in [329, 862, 299534] { arcadeTap("arcade.choice.\(id)", in: app) }
        assertArcadeResult(app, screenshot: "arcade-director-year-guide-result")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "2/3 points")
    }

    func testArcadeScrambleAssemblesWithTwoSwaps() {
        let app = arcadeApp("scramble"); app.launch()
        XCTAssertTrue(app.buttons["arcade.tile.0"].waitForExistence(timeout: 10))
        let first = app.buttons["arcade.tile.0"].frame
        XCTAssertFalse(first.intersects(app.buttons["arcade.tile.1"].frame), "Cropped images must not expand adjacent tile hit regions")
        XCTAssertFalse(first.intersects(app.buttons["arcade.tile.2"].frame))
        for tile in [0, 1] { arcadeTap("arcade.tile.\(tile)", in: app) }
        XCTAssertEqual(app.buttons["arcade.tile.0"].label, "Position 1, scene section 1", "A tap swap must occur exactly once")
        for tile in [1, 2] { arcadeTap("arcade.tile.\(tile)", in: app) }
        arcadeTap("arcade.choice.862", in: app)
        assertArcadeResult(app, screenshot: "arcade-scramble-complete")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
    }

    func testArcadeScrambleHoldAndDragFinishesAndRestoresProgress() {
        let app = arcadeApp("scramble"); app.launch()
        let first = app.buttons["arcade.tile.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.press(forDuration: 0.4, thenDragTo: app.buttons["arcade.tile.1"])
        XCTAssertEqual(first.label, "Position 1, scene section 1")
        XCTAssertEqual(app.buttons["arcade.tile.1"].label, "Position 2, scene section 3")
        attachScreenshot(named: "arcade-scramble-drag-first-swap")
        app.terminate()
        let resumed = arcadeApp("scramble", reset: false); resumed.launch()
        XCTAssertTrue(resumed.buttons["arcade.tile.1"].waitForExistence(timeout: 10))
        XCTAssertEqual(resumed.buttons["arcade.tile.0"].label, "Position 1, scene section 1")
        resumed.buttons["arcade.tile.1"].press(forDuration: 0.4, thenDragTo: resumed.buttons["arcade.tile.2"])
        arcadeTap("arcade.choice.862", in: resumed)
        assertArcadeResult(resumed, screenshot: "arcade-scramble-drag-complete")
        XCTAssertEqual(resumed.staticTexts["arcade.points"].label, "3/3 points")
    }

    func testArcadeScrambleCancelledDragKeepsBoard() {
        let app = arcadeApp("scramble"); app.launch()
        let first = app.buttons["arcade.tile.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let before = first.label
        first.press(forDuration: 0.4, thenDragTo: app.staticTexts["arcade.roundTitle"])
        XCTAssertEqual(first.label, before)
        for tile in [0, 1, 1, 2] { arcadeTap("arcade.tile.\(tile)", in: app) }
        arcadeTap("arcade.choice.862", in: app)
        assertArcadeResult(app, screenshot: "arcade-scramble-cancel-then-tap-complete")
    }

    func testArcadeScrambleLargeTextCanDragToFinish() {
        let app = arcadeApp("scramble")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        arcadeScrollTo(app.buttons["arcade.tile.1"], in: app)
        XCTAssertTrue(app.buttons["arcade.tile.0"].isHittable)
        app.buttons["arcade.tile.0"].press(forDuration: 0.4, thenDragTo: app.buttons["arcade.tile.1"])
        arcadeScrollTo(app.buttons["arcade.tile.2"], in: app)
        app.buttons["arcade.tile.1"].press(forDuration: 0.4, thenDragTo: app.buttons["arcade.tile.2"])
        arcadeTap("arcade.choice.862", in: app)
        assertArcadeResult(app, screenshot: "arcade-scramble-large-text-drag-complete")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
    }

    /// Opt-in visual play. The external reviewer sees screenshots and control
    /// addresses, never tile-section labels, engine state or seeded solutions.
    func testArcadeScrambleLiveVisualRounds() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ARCADE_VISUAL_PLAY"] == "1", "Manual visual play is opt-in")
        let app = arcadeApp("scramble"); app.launch()
        arcadeTap("arcade.skip", in: app) // Discard the seed0 fixture already known to regression tests.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("arcade-visual-live", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for round in 1...3 {
            arcadeTap("arcade.playAgain", in: app)
            var resultReached = false
            for turn in 0..<16 {
                let prefix = "round-\(round)-turn-\(turn)"
                let screenshot = directory.appendingPathComponent(prefix + ".png")
                try app.screenshot().pngRepresentation.write(to: screenshot)
                let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'arcade.tile.'")).allElementsBoundByIndex
                    .filter { $0.exists && $0.isEnabled }.map(\.identifier)
                let choices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'arcade.choice.'")).allElementsBoundByIndex
                    .filter { $0.exists && $0.isEnabled }.map { ["id": $0.identifier, "title": $0.label] }
                let request: [String: Any] = ["round": round, "turn": turn, "screenshot": screenshot.path, "tiles": tiles, "choices": choices]
                try JSONSerialization.data(withJSONObject: request, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent(prefix + ".request.json"))
                print("ARCADE_VISUAL_REQUEST \(prefix)")
                let response = directory.appendingPathComponent(prefix + ".response.json")
                let deadline = Date().addingTimeInterval(90)
                while !FileManager.default.fileExists(atPath: response.path), Date() < deadline { Thread.sleep(forTimeInterval: 0.25) }
                guard let data = try? Data(contentsOf: response),
                      let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let taps = object["taps"] as? [String], !taps.isEmpty, taps.count <= 8 else {
                    XCTFail("No valid visual decision within 90 seconds"); return
                }
                let allowed = Set(tiles + choices.compactMap { $0["id"] })
                guard taps.allSatisfy(allowed.contains) else { XCTFail("Visual decision used an unavailable control"); return }
                for id in taps { arcadeTap(id, in: app) }
                if app.buttons["arcade.playAgain"].exists {
                    XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points", "Fresh round must finish without help or mistakes")
                    try app.screenshot().pngRepresentation.write(to: directory.appendingPathComponent("round-\(round)-result.png"))
                    attachScreenshot(named: "arcade-visual-scramble-round-\(round)-result")
                    resultReached = true; break
                }
            }
            XCTAssertTrue(resultReached, "Visual play exceeded its bounded turn budget")
            guard resultReached else { return }
        }
    }

    func testArcadeCastingWrongChoiceThenCorrectPortrait() {
        let app = arcadeApp("casting"); app.launch()
        arcadeScrollTo(app.buttons["arcade.choice.31"], in: app)
        XCTAssertTrue(app.buttons["arcade.choice.31"].waitForExistence(timeout: 10))
        attachScreenshot(named: "arcade-casting-portraits")
        arcadeTap("arcade.choice.3223", in: app)
        XCTAssertFalse(app.buttons["arcade.choice.3223"].isEnabled)
        arcadeTap("arcade.choice.31", in: app)
        assertArcadeResult(app, screenshot: "arcade-casting-complete")
    }

    func testArcadeDirectorsCutCompletesChronologicalTripleFeature() {
        let app = arcadeApp("directorsCut"); app.launch()
        XCTAssertTrue(app.staticTexts["arcade.cut.progress"].waitForExistence(timeout: 10))
        attachScreenshot(named: "arcade-directors-cut-board")
        for id in [329, 862, 299534] { arcadeTap("arcade.choice.\(id)", in: app) }
        assertArcadeResult(app, screenshot: "arcade-directors-cut-complete")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
    }

    func testArcadeDirectorsCutResumesAfterWrongPickAtLargeText() {
        let app = arcadeApp("directorsCut")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        arcadeTap("arcade.choice.299534", in: app)
        XCTAssertFalse(app.buttons["arcade.choice.299534"].isEnabled)
        arcadeTap("arcade.choice.329", in: app)
        app.terminate()
        let resumed = arcadeApp("directorsCut", reset: false)
        resumed.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        resumed.launch()
        XCTAssertTrue(resumed.staticTexts["arcade.cut.progress"].waitForExistence(timeout: 10))
        XCTAssertEqual(resumed.staticTexts["arcade.cut.progress"].label, "1 of 3 in your cut")
        for id in [862, 299534] { arcadeTap("arcade.choice.\(id)", in: resumed) }
        assertArcadeResult(resumed, screenshot: "arcade-directors-cut-large-text")
        XCTAssertEqual(resumed.staticTexts["arcade.points"].label, "2/3 points")
    }

    func testArcadeSceneSpotterCompletesWithoutSkipping() {
        let app = arcadeApp("scene"); app.launch()
        arcadeTap("arcade.choice.862", in: app)
        assertArcadeResult(app, screenshot: "arcade-scene-spotter-complete")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
    }

    func testArcadeHeistCracksThreeLocks() {
        let app = arcadeApp("heist"); app.launch()
        for (lock, answer) in [862, 3223, 329].enumerated() {
            XCTAssertEqual(app.staticTexts["arcade.heist.lock"].label, "LOCK \(lock + 1) OF 3")
            arcadeTap("arcade.choice.\(answer)", in: app)
            if lock < 2 { arcadeTap("arcade.heist.next", in: app) }
        }
        assertArcadeResult(app, screenshot: "arcade-heist-vault-open")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
    }

    func testArcadeHeistResumesUnlockedDigitAtLargeText() {
        let app = arcadeApp("heist")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        arcadeTap("arcade.choice.157336", in: app)
        XCTAssertFalse(app.buttons["arcade.choice.157336"].isEnabled)
        arcadeTap("arcade.choice.862", in: app)
        app.terminate()
        let resumed = arcadeApp("heist", reset: false)
        resumed.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        resumed.launch()
        arcadeTap("arcade.heist.next", in: resumed)
        XCTAssertEqual(resumed.staticTexts["arcade.heist.lock"].label, "LOCK 2 OF 3")
        arcadeTap("arcade.choice.3223", in: resumed)
        arcadeTap("arcade.heist.next", in: resumed)
        arcadeTap("arcade.choice.329", in: resumed)
        XCTAssertTrue(resumed.staticTexts["arcade.heist.code"].waitForExistence(timeout: 10))
        XCTAssertEqual(resumed.staticTexts["arcade.points"].label, "2/3 points")
        let title = resumed.staticTexts["arcade.roundTitle"].frame
        XCTAssertGreaterThanOrEqual(title.minX, resumed.frame.minX)
        XCTAssertLessThanOrEqual(title.maxX, resumed.frame.maxX)
        attachScreenshot(named: "arcade-heist-large-text-getaway")
    }

    func testArcadeCastingLargeTextKeepsPortraitChoicesInsideScreen() {
        let app = arcadeApp("casting")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for id in [3223, 30614, 31, 10297] {
            let choice = app.buttons["arcade.choice.\(id)"]
            arcadeScrollTo(choice, in: app)
            XCTAssertTrue(choice.exists)
            guard choice.exists else { continue }
            XCTAssertGreaterThanOrEqual(choice.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(choice.frame.maxX, app.frame.maxX)
        }
        attachScreenshot(named: "arcade-casting-large-text")
        arcadeTap("arcade.choice.31", in: app)
        assertArcadeResult(app, screenshot: "arcade-casting-large-text-result")
    }

    func testArcadeTimelineRevealsYearsAndCompletesThreePlacements() {
        let app = arcadeApp("timeline"); app.launch()
        arcadeTap("arcade.before", in: app) // Endgame is later: exercise a recoverable mistake.
        XCTAssertTrue(app.buttons["arcade.timeline.next"].exists)
        attachScreenshot(named: "arcade-timeline-year-reveal")
        arcadeTap("arcade.timeline.next", in: app)
        arcadeTap("arcade.before", in: app)
        arcadeTap("arcade.timeline.next", in: app)
        arcadeTap("arcade.before", in: app)
        assertArcadeResult(app, screenshot: "arcade-timeline-complete")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "2/3 points")
    }

    func testArcadeOddOneOutExplainsTheRule() {
        let app = arcadeApp("oddOneOut"); app.launch()
        arcadeTap("arcade.choice.603", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["arcade.feedback"].exists)
        arcadeTap("arcade.choice.299534", in: app)
        assertArcadeResult(app, screenshot: "arcade-odd-one-out-complete")
    }

    func testArcadeDoubleFeatureMismatchAndThreeConnections() {
        let app = arcadeApp("doubleFeature"); app.launch()
        for card in [0, 1] { arcadeTap("arcade.card.\(card)", in: app) }
        arcadeTap("arcade.retryPair", in: app)
        for card in [0, 3, 1, 5, 2, 4] { arcadeTap("arcade.card.\(card)", in: app) }
        assertArcadeResult(app, screenshot: "arcade-double-feature-complete")
    }

    func testArcadeDetectiveLetsPlayerChooseClueOrder() {
        let app = arcadeApp("detective"); app.launch()
        for clue in ["cast", "year", "plot"] { arcadeTap("arcade.clue." + clue, in: app) }
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "Up to 1 point")
        arcadeTap("arcade.choice.862", in: app)
        assertArcadeResult(app, screenshot: "arcade-detective-complete")
    }

    func testArcadeMemoryPersistsPairsAcrossRelaunchAndHasBonus() {
        let app = arcadeApp("memory"); app.launch()
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        attachScreenshot(named: "arcade-memory-board")
        arcadeTap("arcade.card.0", in: app); arcadeTap("arcade.card.2", in: app)
        XCTAssertEqual(app.staticTexts["arcade.pairs"].label, "1 of 3 pairs")
        app.terminate()
        let resumed = arcadeApp("memory", reset: false); resumed.launch()
        XCTAssertTrue(resumed.staticTexts["arcade.pairs"].waitForExistence(timeout: 15))
        XCTAssertEqual(resumed.staticTexts["arcade.pairs"].label, "1 of 3 pairs")
        for card in [1, 4, 3, 5] { arcadeTap("arcade.card.\(card)", in: resumed) }
        arcadeTap("arcade.choice.1995", in: resumed)
        assertArcadeResult(resumed, screenshot: "arcade-memory-complete")
    }

    func testArcadeMemoryCanFinishWithoutTrivia() {
        let app = arcadeApp("memory"); app.launch()
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        attachScreenshot(named: "arcade-memory-vivid-card-backs")
        arcadeTap("arcade.card.0", in: app)
        attachScreenshot(named: "arcade-memory-vivid-revealed-poster")
        for card in [2, 1, 4, 3, 5] { arcadeTap("arcade.card.\(card)", in: app) }
        XCTAssertEqual(app.staticTexts["arcade.pairs"].label, "3 of 3 pairs")
        XCTAssertTrue(app.buttons["arcade.memory.finish"].waitForExistence(timeout: 5))
        attachScreenshot(named: "arcade-memory-optional-bonus")
        arcadeTap("arcade.memory.finish", in: app)
        assertArcadeResult(app, screenshot: "arcade-memory-matching-win")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
        arcadeTap("arcade.playAgain", in: app)
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["arcade.playAgain"].exists)
    }

    func testArcadeMemoryLargeTextCanFinishWithoutTrivia() {
        let app = arcadeApp("memory")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        for card in [0, 2, 1, 4, 3, 5] { arcadeTap("arcade.card.\(card)", in: app) }
        XCTAssertEqual(app.staticTexts["arcade.pairs"].label, "3 of 3 pairs")
        arcadeTap("arcade.memory.finish", in: app)
        assertArcadeResult(app, screenshot: "arcade-memory-large-text-matching-win")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
        let title = app.staticTexts["arcade.roundTitle"].frame
        XCTAssertGreaterThanOrEqual(title.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(title.maxX, app.frame.maxX)
        arcadeScrollTo(app.buttons["arcade.playAgain"], in: app)
        XCTAssertTrue(app.buttons["arcade.playAgain"].isHittable)
        XCTAssertLessThanOrEqual(app.buttons["arcade.playAgain"].frame.maxY, app.scrollViews["arcade.scroll"].frame.maxY - 16)
        attachScreenshot(named: "arcade-memory-large-text-replay")
        arcadeTap("arcade.playAgain", in: app)
        arcadeScrollTo(app.buttons["arcade.card.0"], in: app)
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["arcade.playAgain"].exists)
        attachScreenshot(named: "arcade-memory-large-text-restarted")
    }

    func testArcadeMemoryBonusMistakeKeepsMatchingPoints() {
        let app = arcadeApp("memory"); app.launch()
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        for card in [0, 2, 1, 4, 3, 5] { arcadeTap("arcade.card.\(card)", in: app) }
        arcadeTap("arcade.choice.1990", in: app)
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "Up to 3 points")
        arcadeTap("arcade.memory.finish", in: app)
        assertArcadeResult(app, screenshot: "arcade-memory-bonus-safe")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
    }

    func testArcadeLobbyStructuralAccessibilityAudit() throws {
        let app = makeApp()
        app.launchArguments += ["-selectedView", "home", "--arcade-test", "--arcade-reset"]
        app.launch()
        arcadeTap("arcade.home", in: app)
        try auditArcadeAccessibility(app, name: "arcade-audit-featured-lobby")
        arcadeTap("arcade.allGames", in: app)
        arcadeScrollTo(app.buttons["arcade.game.directorsCut"], in: app)
        // Bring the footer fully into view to separate possible viewport clipping
        // from truncation inside the text's own layout.
        let notes = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "A 12-movie starter pack")).firstMatch
        XCTAssertTrue(notes.waitForExistence(timeout: 5))
        arcadeScrollTo(notes, in: app)
        let viewport = app.scrollViews["arcade.scroll"].frame
        XCTAssertGreaterThanOrEqual(notes.frame.minY, viewport.minY + 16)
        XCTAssertLessThanOrEqual(notes.frame.maxY, viewport.maxY - 16)
        try auditArcadeAccessibility(app, name: "arcade-audit-expanded-lobby")
    }

    func testArcadeMemoryStructuralAccessibilityAudit() throws {
        let app = arcadeApp("memory"); app.launch()
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        try auditArcadeAccessibility(app, name: "arcade-audit-memory-card-backs")
        for card in [0, 1] { arcadeTap("arcade.card.\(card)", in: app) }
        arcadeScrollTo(app.buttons["arcade.retryPair"], in: app)
        try auditArcadeAccessibility(app, name: "arcade-audit-memory-mismatch")
        arcadeTap("arcade.retryPair", in: app)
        for card in [0, 2, 1, 4, 3, 5] { arcadeTap("arcade.card.\(card)", in: app) }
        arcadeTap("arcade.memory.finish", in: app)
        assertArcadeResult(app, screenshot: "arcade-audit-memory-result")
        try auditArcadeAccessibility(app, name: "arcade-audit-memory-result-controls")
        arcadeTap("arcade.playAgain", in: app)
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        try auditArcadeAccessibility(app, name: "arcade-audit-memory-replay")
    }

    func testArcadeScrambleStructuralAccessibilityAudit() throws {
        let app = arcadeApp("scramble"); app.launch()
        XCTAssertTrue(app.buttons["arcade.tile.0"].waitForExistence(timeout: 10))
        try auditArcadeAccessibility(app, name: "arcade-audit-scramble-board")
        for tile in [0, 1, 1, 2] { arcadeTap("arcade.tile.\(tile)", in: app) }
        arcadeScrollTo(app.buttons["arcade.choice.862"], in: app)
        try auditArcadeAccessibility(app, name: "arcade-audit-scramble-choices")
        arcadeTap("arcade.choice.862", in: app)
        assertArcadeResult(app, screenshot: "arcade-audit-scramble-result")
        try auditArcadeAccessibility(app, name: "arcade-audit-scramble-result-controls")
    }

    private func auditArcadeAccessibility(_ app: XCUIApplication, name: String) throws {
        let viewport = app.scrollViews["arcade.scroll"]
        var previousFrame = CGRect.zero
        var settledSamples = 0
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard viewport.exists, app.buttons["arcade.close"].isHittable else { return false }
            let frame = viewport.frame
            guard frame.height > 100, app.frame.contains(frame) else { return false }
            settledSamples = frame == previousFrame ? settledSamples + 1 : 0
            previousFrame = frame
            return settledSamples >= 2
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed, "Arcade presentation must settle before auditing")
        attachScreenshot(named: name)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + "-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        var findings: [[String: String]] = []
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .textClipped, .trait]) { issue in
            findings.append([
                "type": String(issue.auditType.rawValue),
                "element": issue.element?.identifier ?? "",
                "label": issue.element?.label ?? "",
                "frame": String(describing: issue.element?.frame),
                "elementType": issue.element.map { String($0.elementType.rawValue) } ?? "",
                "summary": issue.compactDescription,
                "detail": issue.detailedDescription,
            ])
            return true // Retain every issue in the report, including contrast diagnostics.
        }
        let data = try JSONSerialization.data(withJSONObject: findings, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = name + "-issues"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Layered gradients/posters need visual contrast review; keep those findings
        // as diagnostics instead of equating them with structural audit failures.
        let structuralFindings = findings.filter { $0["type"] != String(XCUIAccessibilityAuditType.contrast.rawValue) }
        XCTAssertTrue(structuralFindings.isEmpty, "Structural accessibility issues at \(name): \(String(decoding: data, as: UTF8.self))")
    }

    func testArcadeReducedMotionCanMatchReplayAndDrag() {
        verifyArcadeMotion(reduced: true)
    }

    func testArcadeStandardMotionCanMatchReplayAndDrag() {
        verifyArcadeMotion(reduced: false)
    }

    private func verifyArcadeMotion(reduced: Bool) {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let app = arcadeApp("memory")
        settings.launch()
        let motionSwitch = settings.switches["Reduce Motion"].firstMatch
        if !motionSwitch.exists {
            let accessibility = settings.staticTexts["Accessibility"].firstMatch
            for _ in 0..<6 {
                if accessibility.exists && accessibility.isHittable { break }
                settings.swipeUp()
            }
            XCTAssertTrue(accessibility.waitForExistence(timeout: 5))
            accessibility.tap()
            let motion = settings.staticTexts["Motion"].firstMatch
            XCTAssertTrue(motion.waitForExistence(timeout: 5))
            motion.tap()
        }
        XCTAssertTrue(motionSwitch.waitForExistence(timeout: 5))
        let wasEnabled = motionSwitch.value as? String == "1"
        addTeardownBlock {
            app.terminate()
            settings.activate()
            let foreground = XCTNSPredicateExpectation(predicate: NSPredicate(format: "state == %d", XCUIApplication.State.runningForeground.rawValue), object: settings)
            XCTAssertEqual(XCTWaiter.wait(for: [foreground], timeout: 5), .completed)
            if (motionSwitch.value as? String == "1") != wasEnabled {
                motionSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            }
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", wasEnabled ? "1" : "0"), object: motionSwitch)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
            settings.terminate()
        }
        // Settings exposes the entire row as a switch; its center is the label.
        if wasEnabled != reduced { motionSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap() }
        let configured = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", reduced ? "1" : "0"), object: motionSwitch)
        XCTAssertEqual(XCTWaiter.wait(for: [configured], timeout: 5), .completed)
        let mode = reduced ? "reduced" : "standard"
        attachScreenshot(named: "arcade-system-\(mode)-motion")

        app.launch()
        for card in [0, 1] { arcadeTap("arcade.card.\(card)", in: app) }
        arcadeTap("arcade.retryPair", in: app)
        XCTAssertEqual(app.buttons["arcade.card.0"].label, "Face-down card 1")
        for card in [0, 2, 1, 4, 3, 5] { arcadeTap("arcade.card.\(card)", in: app) }
        XCTAssertEqual(app.staticTexts["arcade.pairs"].label, "3 of 3 pairs")
        arcadeTap("arcade.memory.finish", in: app)
        assertArcadeResult(app, screenshot: "arcade-\(mode)-motion-memory-result")
        arcadeTap("arcade.playAgain", in: app)
        XCTAssertTrue(app.buttons["arcade.card.0"].waitForExistence(timeout: 10))
        arcadeTap("arcade.games", in: app)
        arcadeTap("arcade.allGames", in: app)
        arcadeTap("arcade.game.scramble", in: app)
        arcadeScrollTo(app.buttons["arcade.tile.0"], in: app)
        app.buttons["arcade.tile.0"].press(forDuration: 0.4, thenDragTo: app.buttons["arcade.tile.1"])
        XCTAssertEqual(app.buttons["arcade.tile.0"].label, "Position 1, scene section 1")
        app.buttons["arcade.tile.1"].press(forDuration: 0.4, thenDragTo: app.buttons["arcade.tile.2"])
        arcadeTap("arcade.choice.862", in: app)
        assertArcadeResult(app, screenshot: "arcade-\(mode)-motion-scramble-result")
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
        arcadeTap("arcade.differentGame", in: app)
        XCTAssertTrue(app.buttons["arcade.game.memory"].waitForExistence(timeout: 10))
    }

    func testArcadeDailyMixFinishesAndPreservesSummary() {
        let app = arcadeApp("daily"); app.launch()
        arcadeTap("arcade.choice.19995", in: app)
        for _ in 0..<3 {
            arcadeTap("arcade.next", in: app)
            arcadeTap("arcade.skip", in: app)
        }
        arcadeTap("arcade.next", in: app)
        XCTAssertTrue(app.staticTexts["arcade.summaryScore"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["arcade.summaryScore"].label, "3 / 12")
        attachScreenshot(named: "arcade-daily-mix-summary")
        arcadeTap("arcade.keepPlaying", in: app)
        arcadeTap("arcade.daily", in: app)
        XCTAssertEqual(app.staticTexts["arcade.summaryScore"].label, "3 / 12")
    }

    private func discoveryApp(_ game: String, reset: Bool = true) -> XCUIApplication {
        let app = arcadeApp(game, reset: reset)
        app.launchArguments += ["--arcade-discovery-test", "-autoOpenCustomListSelector", "NO", "-showRemoveConfirmation", "NO"]
        return app
    }

    // Release gate: real Arcade progression, real TMDB, regular persistent store,
    // normal free-user monetization. No launch flag activates any fixture.
    func testReleaseCandidateLiveDiscoveryAndFreeUserPersistence() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-showOnboarding", "NO",
            "-userHasPurchasedTipJar", "NO", "-autoOpenCustomListSelector", "NO",
            "-showRemoveConfirmation", "NO", "-selectedView", "home"]
        app.launch()
        dismissReleaseTestAd(in: app)
        arcadeTap("arcade.home", in: app)
        arcadeTap("arcade.game.scene", in: app)
        if app.buttons["arcade.playAgain"].exists { arcadeTap("arcade.playAgain", in: app) }
        let choices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'arcade.choice.'"))
        arcadeScrollTo(choices.firstMatch, in: app)
        XCTAssertTrue(choices.firstMatch.waitForExistence(timeout: 15))
        let choiceIDs = choices.allElementsBoundByIndex.map(\.identifier)
        for id in choiceIDs {
            if app.buttons["arcade.playAgain"].exists { break }
            if app.buttons[id].isEnabled { arcadeTap(id, in: app) }
        }
        XCTAssertTrue(app.buttons["arcade.playAgain"].waitForExistence(timeout: 10))
        let movie = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'arcade.discovery.'")).firstMatch
        let movieID = movie.identifier
        let movieTitle = String(movie.label.dropFirst("Explore ".count).dropLast(6))
        XCTAssertFalse(movieID.isEmpty)
        arcadeTap(movieID, in: app)
        let watchlist = app.buttons["movieDetails.watchlist"]
        XCTAssertTrue(watchlist.waitForExistence(timeout: 30))
        let ready = NSPredicate(format: "isEnabled == true AND (label CONTAINS 'Add' OR label CONTAINS 'Remove')")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: watchlist)], timeout: 30), .completed,
            "Movie details must load from the live service")
        let addedByTest = watchlist.label.contains("Add")
        if addedByTest { detailWatchlist(in: app, label: "Add").tap() }
        _ = detailWatchlist(in: app, label: "Remove")
        attachScreenshot(named: "release-live-movie-saved-normal-ads")
        app.buttons["arcade.discovery.back"].tap()
        arcadeTap("arcade.playAgain", in: app)
        XCTAssertTrue(app.buttons["arcade.skip"].exists, "Player can continue after movie discovery")
        app.terminate()
        app.launch()
        dismissReleaseTestAd(in: app)
        let watchlistTab = app.buttons["Watchlist"].firstMatch
        XCTAssertTrue(watchlistTab.waitForExistence(timeout: 20))
        watchlistTab.tap()
        // Poster grids expose the movie as a button; list rows expose title text.
        let movieButton = app.buttons[movieTitle].firstMatch
        let movieText = app.staticTexts[movieTitle].firstMatch
        let savedMovie = movieButton.waitForExistence(timeout: 5) ? movieButton : movieText
        XCTAssertTrue(savedMovie.waitForExistence(timeout: 20), "Movie saved through live details survives relaunch")
        savedMovie.tap()
        let saved = detailWatchlist(in: app, label: "Remove")
        attachScreenshot(named: "release-live-movie-persisted-after-relaunch")
        if addedByTest { saved.tap(); _ = detailWatchlist(in: app, label: "Add") }
    }

    private func dismissReleaseTestAd(in app: XCUIApplication) {
        // Simulator AdMob serves a test creative. Only dismiss it; never tap
        // advertiser content, and keep the normal SDK/consent path enabled.
        let close = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS[c] 'Continue to app'")).firstMatch
        if close.waitForExistence(timeout: 15), close.isHittable { close.tap() }
    }

    func testSettingsNoLongerOffersAdFreePurchases() {
        let app = makeApp()
        app.launchArguments += ["-selectedView", "home"]
        app.launch()
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Remove Ads"].exists)
        XCTAssertFalse(app.buttons["Restore Purchases"].exists)
        attachScreenshot(named: "release-settings-without-purchase-offer")
    }

    private func detailWatchlist(in app: XCUIApplication, label: String) -> XCUIElement {
        let button = app.buttons["movieDetails.watchlist"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        let ready = NSPredicate(format: "isEnabled == true AND label CONTAINS %@", label)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: button)], timeout: 15), .completed)
        let area = app.scrollViews["movieDetails.scroll"]
        for _ in 0..<8 {
            if button.isHittable && button.frame.maxY < app.frame.maxY - 70 { break }
            area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        }
        XCTAssertTrue(button.isHittable)
        return button
    }

    func testArcadeDiscoverySavesMovieAndReturnsToReplay() {
        let app = discoveryApp("scene"); app.launch()
        XCTAssertFalse(app.buttons["arcade.discovery.862"].exists, "No answer exposed before play")
        arcadeTap("arcade.choice.862", in: app)
        arcadeTap("arcade.discovery.862", in: app)
        detailWatchlist(in: app, label: "Add").tap()
        _ = detailWatchlist(in: app, label: "Remove")
        attachScreenshot(named: "arcade-discovery-movie-saved")
        app.buttons["arcade.discovery.back"].tap()
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
        arcadeTap("arcade.playAgain", in: app)
        XCTAssertTrue(app.buttons["arcade.skip"].exists)
    }

    func testArcadeDiscoveryDailySummaryKeepsSavedMovieAcrossRelaunch() {
        let app = discoveryApp("daily"); app.launch()
        arcadeTap("arcade.choice.19995", in: app)
        arcadeTap("arcade.discovery.19995", in: app)
        detailWatchlist(in: app, label: "Add").tap()
        _ = detailWatchlist(in: app, label: "Remove")
        app.buttons["arcade.discovery.back"].tap()
        for _ in 0..<3 { arcadeTap("arcade.next", in: app); arcadeTap("arcade.skip", in: app) }
        arcadeTap("arcade.next", in: app)
        XCTAssertEqual(app.staticTexts["arcade.summaryScore"].label, "3 / 12")
        attachScreenshot(named: "arcade-discovery-daily-summary")
        app.terminate()
        let resumed = discoveryApp("daily", reset: false); resumed.launch()
        XCTAssertTrue(resumed.staticTexts["arcade.summaryScore"].waitForExistence(timeout: 10))
        XCTAssertEqual(resumed.staticTexts["arcade.summaryScore"].label, "3 / 12")
        arcadeTap("arcade.discovery.19995", in: resumed)
        _ = detailWatchlist(in: resumed, label: "Remove")
        attachScreenshot(named: "arcade-discovery-existing-save-after-relaunch")
        resumed.buttons["arcade.discovery.back"].tap()
        XCTAssertEqual(resumed.staticTexts["arcade.summaryScore"].label, "3 / 12")
        arcadeTap("arcade.keepPlaying", in: resumed)
        XCTAssertTrue(resumed.buttons["arcade.daily"].exists)
    }

    func testArcadeDiscoveryMovieLoadCanRetry() {
        let app = discoveryApp("scene")
        app.launchArguments.append("--arcade-detail-fail-once")
        app.launch()
        arcadeTap("arcade.choice.862", in: app)
        arcadeTap("arcade.discovery.862", in: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10))
        attachScreenshot(named: "arcade-discovery-load-retry")
        app.alerts.buttons["Retry"].tap()
        detailWatchlist(in: app, label: "Add").tap()
        _ = detailWatchlist(in: app, label: "Remove")
        app.buttons["arcade.discovery.back"].tap()
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
    }

    func testArcadeDiscoveryHeistKeepsMovieDetailsSeparate() {
        let app = discoveryApp("heist"); app.launch()
        arcadeTap("arcade.choice.862", in: app)
        arcadeTap("arcade.heist.next", in: app)
        arcadeTap("arcade.choice.3223", in: app)
        arcadeTap("arcade.heist.next", in: app)
        arcadeTap("arcade.choice.329", in: app)
        arcadeTap("arcade.discovery.862", in: app)
        detailWatchlist(in: app, label: "Add").tap()
        _ = detailWatchlist(in: app, label: "Remove")
        app.buttons["arcade.discovery.back"].tap()
        arcadeTap("arcade.discovery.299534", in: app)
        _ = detailWatchlist(in: app, label: "Add")
        XCTAssertTrue(app.staticTexts["Avengers: Endgame"].exists)
        attachScreenshot(named: "arcade-discovery-second-movie-independent")
        app.buttons["arcade.discovery.back"].tap()
        arcadeTap("arcade.discovery.862", in: app)
        _ = detailWatchlist(in: app, label: "Remove")
        app.buttons["arcade.discovery.back"].tap()
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 points")
    }

    func testArcadeDiscoverySpanishMemoryAtLargeText() {
        let app = discoveryApp("memory")
        app.launchArguments += ["-AppleLanguages", "(es)", "-AppleLocale", "es_ES", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for card in [0, 2, 1, 4, 3, 5] { arcadeTap("arcade.card.\(card)", in: app) }
        arcadeTap("arcade.memory.finish", in: app)
        arcadeTap("arcade.discovery.299534", in: app)
        detailWatchlist(in: app, label: "Añadir").tap()
        let savedButton = detailWatchlist(in: app, label: "Quitar")
        XCTAssertGreaterThan(savedButton.frame.width, app.frame.width * 0.7, "Watchlist action expands to show the full Spanish label")
        attachScreenshot(named: "arcade-discovery-spanish-large-text-saved")
        app.buttons["arcade.discovery.back"].tap()
        XCTAssertEqual(app.staticTexts["arcade.points"].label, "3/3 puntos")
        arcadeScrollTo(app.buttons["arcade.discovery.299534"], in: app)
        let card = app.buttons["arcade.discovery.299534"]
        XCTAssertTrue(card.label.contains("Explorar Avengers: Endgame, 2019"))
        XCTAssertGreaterThanOrEqual(card.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(card.frame.maxX, app.frame.maxX)
        XCTAssertLessThan(card.frame.height, app.frame.height - 150, "A large-text movie card must fit within one screen")
        attachScreenshot(named: "arcade-discovery-spanish-large-text-result")
    }

    func testArcadeLargeTextCanRevealAndContinue() {
        let app = arcadeApp("detective")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        arcadeTap("arcade.clue.plot", in: app)
        arcadeTap("arcade.choice.862", in: app)
        assertArcadeResult(app, screenshot: "arcade-large-text-result")
        let titleFrame = app.staticTexts["arcade.roundTitle"].frame
        XCTAssertGreaterThanOrEqual(titleFrame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(titleFrame.maxX, app.frame.maxX)
        XCTAssertGreaterThan(titleFrame.height, 0)
        arcadeTap("arcade.differentGame", in: app)
        XCTAssertTrue(app.buttons["arcade.daily"].exists)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollToVisible(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            let screen = app.frame
            let safeTop = screen.minY + 100
            let safeBottom = screen.maxY - 100
            let frame = element.frame
            if element.isHittable && frame.minY >= safeTop && frame.maxY <= safeBottom {
                return
            }
            if element.exists && frame.minY < safeTop {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
    }

    private func waitForNonExistence(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
