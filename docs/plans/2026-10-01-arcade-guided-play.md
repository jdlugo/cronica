# Arcade guided play implementation plan

> Execute with the Superpowers design, test-first and verification workflows in this existing worktree.

**Goal:** Help a first-time player finish meaningful movie games without needing a film-trivia background.

**Architecture:** Keep the deterministic offline engine and existing saves. Add opt-in clues using the existing persisted clue set and score calculation. Start the lobby with Memory and Scene Spotter. Use the existing Localizable.strings resources for Spanish copy, with English fallback elsewhere.

**Tech stack:** Swift, SwiftUI, Foundation, XCTest, iOS Simulator.

## Requirements and bounded tasks

1. Write engine tests for useful cast, connection and year clues; expect the current engine to reject them. Clues must not solve or skip a round, double charge, disappear on restore, or change existing unassisted scores. Heist cast help applies only at the cast lock and keeps its cost for the entire round.
2. Implement those rules in Shared/Model/MovieArcade.swift and expose an optional clue above the game board in Shared/View/Navigation/MovieArcadeView.swift. Connections display credited actors on cards; year clues display release years; cast clues identify a credited choice. Always show the current point cost.
3. Feature Memory and Scene Spotter in the lobby, retaining all ten games behind the disclosure. Keep Daily Mix available.
4. Localize instructions, clues, feedback, scores, accessibility labels, result/replay controls and all twelve plot clues into Spanish and Mexican Spanish. Film/actor proper names retain catalog spelling. Other locales use English fallback. Verify placeholder parity and resource syntax before simulator tests.
5. Test representative complete UI flows: lobby, helped connections, helped Heist through restart, Spanish Detective and Memory at large text. Inspect screenshots. Independently solve Scramble from its visible image and complete repeated rounds where practical; distinguish actual visual decisions from deterministic test assertions.
6. Run the existing rules and analytics suites, build the simulator target, run focused UI regressions, record concrete results and remaining limits, then commit locally.

## Validation commands

- `bash scripts/test_movie_arcade.sh`
- `bash scripts/test_arcade_analytics.sh`
- `python3 scripts/check_arcade_localization.py`
- `xcodebuild -project Story.xcodeproj -scheme 'Story (iOS)' -destination 'platform=iOS Simulator,id=54589BE9-B7F0-4E11-890E-E437D7D446EB' -parallel-testing-enabled NO -disableAutomaticPackageResolution -skipPackageUpdates -only-testing:CronicaUITests/CronicaUITests/<selected method> test`

No production retention or revenue improvement is asserted from scripted play. This delivery excludes purchase configuration and App Store submission.
