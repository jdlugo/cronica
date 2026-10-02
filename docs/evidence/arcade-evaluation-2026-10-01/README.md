# Arcade evaluation evidence — October 1, 2026

Read the findings in `../../investigations/2026-10-01-arcade-growth-objectives.md`.

- Two PostHog JSON files preserve query time, aggregate results and query text. Counts are identifiers/events, not verified people or an ordered funnel. No credentials or raw player identifiers are saved.
- Eleven transcript files preserve visible result text and deliberate action counts: three rounds per ten practice modes plus four Daily Mix rounds. The visible text inventory can include accessibility text from the Home screen behind the sheet; it is not proof that all text appeared simultaneously on screen.
- Seven representative PNGs preserve inspected Home, game and completion states. Standard text on iPhone 17 Pro, iOS 26.3.
- Temporary XCTest audit ran with fixture date 2026-09-30, isolated progress, ads disabled, and prior answer knowledge. The runner systematically tried choices, always selected Before in timeline, paired known actors, and recorded Memory names only after flipping. These results establish completion, not human fun, difficulty or organic replay.
- Initial selected suite: 9 passed, 1 diagnostic failure. Follow-up: Scramble and Home/Daily Mix both passed, 2 tests / 0 failures. Final coverage: 30 practice + 4 Daily Mix non-skipped completions. UI test source restored exactly afterward.
- AdMob read-only refresh failed with invalid_grant / invalid_rapt. Current revenue is unavailable; cached August history was not treated as current.

Local raw bundles: `/tmp/arcade-fun-evaluation.xcresult`, `/tmp/arcade-evaluation-followup.xcresult`. These are temporary machine-local artifacts, not committed evidence or guaranteed durable paths.
