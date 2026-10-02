import XCTest
@testable import StreamingNow

final class DailyPuzzleLocalizationResolverTests: XCTestCase {
    func testExactTargetLocalesResolveLocalizedContentWithoutChangingPuzzleID() {
        let puzzle = makePuzzle()

        let french = puzzle.localized(forLocaleIdentifier: "fr_FR")
        let spanish = puzzle.localized(forLocaleIdentifier: "es-MX")
        let portuguese = puzzle.localized(forLocaleIdentifier: "pt-BR")

        XCTAssertEqual(french.puzzle.puzzleID, puzzle.puzzleID)
        XCTAssertEqual(french.puzzle.title, "Le Fabuleux Destin d'Amélie Poulain")
        XCTAssertEqual(french.source, .exactLocale)
        XCTAssertEqual(spanish.puzzle.hint1, "Una joven camarera cambia la vida de quienes la rodean.")
        XCTAssertEqual(portuguese.puzzle.title, "O Fabuloso Destino de Amélie Poulain")
    }

    func testLanguageAndCanonicalFallbacksAreDeterministic() {
        let puzzle = makePuzzle()

        let canadianFrench = puzzle.localized(forLocaleIdentifier: "fr-CA")
        let genericSpanish = puzzle.localized(forLocaleIdentifier: "es")
        let unsupported = puzzle.localized(forLocaleIdentifier: "de-DE")

        XCTAssertEqual(canadianFrench.localeIdentifier, "fr-FR")
        XCTAssertEqual(canadianFrench.source, .languageFallback)
        XCTAssertEqual(genericSpanish.localeIdentifier, "es-MX")
        XCTAssertEqual(genericSpanish.source, .languageFallback)
        XCTAssertEqual(unsupported.puzzle.title, "Amelie")
        XCTAssertEqual(unsupported.localeIdentifier, "en")
        XCTAssertEqual(unsupported.source, .canonical)
    }

    func testLocalizedAndCanonicalTitlesMatchWithoutDiacriticsOrPunctuation() {
        let french = makePuzzle().localized(forLocaleIdentifier: "fr-FR").puzzle

        XCTAssertTrue(french.matches(guess: "Le Fabuleux Destin d Amelie Poulain"))
        XCTAssertTrue(french.matches(guess: "Amelie"))
        XCTAssertFalse(french.matches(guess: "Titanic"))
    }

    func testLegacyPuzzleWithoutLocalizationRemainsPlayable() {
        var puzzle = makePuzzle()
        puzzle.localizations = nil

        let resolution = puzzle.localized(forLocaleIdentifier: "pt-BR")

        XCTAssertEqual(resolution.source, .canonical)
        XCTAssertEqual(resolution.puzzle.puzzleID, puzzle.puzzleID)
        XCTAssertTrue(resolution.puzzle.matches(guess: "Amelie"))
    }

    @MainActor
    func testViewModelReportsLocalizationFallbackInEveryPuzzleEvent() {
        let tracker = LocalizationAnalyticsTracker()
        let viewModel = DailyPuzzleViewModel(
            puzzle: makePuzzle(),
            analyticsTracker: tracker,
            locale: Locale(identifier: "fr-CA")
        )

        viewModel.trackOpened(source: "localization_test")

        let opened = tracker.events.first { $0.name == "daily_puzzle_opened" }
        XCTAssertEqual(opened?.metadata["puzzle_locale"], "fr-FR")
        XCTAssertEqual(opened?.metadata["puzzle_localization_source"], "language_fallback")
    }

    private func makePuzzle() -> DailyPuzzle {
        DailyPuzzle(
            date: "2026-08-27",
            puzzleID: "2026-08-27",
            mediaType: .movie,
            tmdbID: 194,
            title: "Amelie",
            emojiClue: "👩☕💌",
            hint1: "A shy waitress helps strangers in Paris.",
            hint2: "The story takes place around Montmartre.",
            acceptedAnswers: ["amelie"],
            localizations: [
                "fr-FR": DailyPuzzleLocalizedContent(
                    title: "Le Fabuleux Destin d'Amélie Poulain",
                    emojiClue: "👩☕💌",
                    hint1: "Une serveuse timide aide les gens autour d'elle.",
                    hint2: "L'histoire se déroule à Montmartre.",
                    acceptedAnswers: ["amélie", "le fabuleux destin d'amélie poulain"]
                ),
                "es-MX": DailyPuzzleLocalizedContent(
                    title: "Amélie",
                    emojiClue: "👩☕💌",
                    hint1: "Una joven camarera cambia la vida de quienes la rodean.",
                    hint2: "La historia ocurre en Montmartre.",
                    acceptedAnswers: ["amélie", "amelie"]
                ),
                "pt-BR": DailyPuzzleLocalizedContent(
                    title: "O Fabuloso Destino de Amélie Poulain",
                    emojiClue: "👩☕💌",
                    hint1: "Uma jovem garçonete transforma a vida das pessoas ao redor.",
                    hint2: "A história se passa em Montmartre.",
                    acceptedAnswers: ["amélie", "o fabuloso destino de amélie poulain"]
                )
            ],
            source: "ai+tmdb",
            generatedAt: "2026-08-27T05:00:00.000Z"
        )
    }
}

private final class LocalizationAnalyticsTracker: DailyPuzzleAnalyticsTracking {
    var events = [DailyPuzzleAnalyticsEvent]()

    func track(event: DailyPuzzleAnalyticsEvent) {
        events.append(event)
    }
}
