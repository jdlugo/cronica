# Guided Arcade evidence

See [delivery and validation](../../research/2026-10-01-arcade-guided-play-validation.md) for changes, findings and limits.

- `guided-ui-summary.json`: finalized five-test batch.
- `accessibility-ui-summary.json`: finalized three-test batch after the accessibility fix.
- `accessibility-before-fix-summary.json`: reproduced missing accessible year.
- `visual-play-ui-summary.json`: finalized opt-in test executing three fresh visual Scramble rounds.
- `visual-default-skip-summary.json`: ordinary tests skip the manual runner.
- `rules-checks.log`, `analytics-checks.log`, `localization-checks.log`: focused checks.
- `screenshots/`: full-resolution JPEG previews from test attachments and actual visual-play captures.
- `visual-decisions/`: six raw screenshot requests and six reviewer replies. Local screenshot paths in requests refer to the simulator capture at execution time; matching previews use `screenshots/scramble-visual-<request stem>.jpg`.

Original `.xcresult` bundles remain under `/private/tmp/arcade-guided-ui-2026-10-01.xcresult`, `/private/tmp/arcade-guided-final-2026-10-01.xcresult`, `/private/tmp/arcade-year-red-2026-10-01.xcresult`, `/private/tmp/arcade-visual-scramble-2026-10-01.xcresult` and `/private/tmp/arcade-visual-default-skip-2026-10-01.xcresult`. Temporary paths can expire.

Reproduce the automatic cases using the named methods in `CronicaUITests/CronicaUITests.swift`. Manual screenshot play requires `TEST_RUNNER_ARCADE_VISUAL_PLAY=1`, one simulator, and a reviewer responding to request files under the test runner’s temporary `arcade-visual-live` directory. It is limited to three rounds, sixteen turns per round, eight taps per response, and ninety seconds waiting for each response. An absent reviewer fails within the response limit; this test skips by default.
