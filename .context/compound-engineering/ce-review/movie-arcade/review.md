# Movie Arcade review

Scope: new MovieArcade model/store, ArcadeCatalog, MovieArcadeView, Home entry, project registrations, content assets and tests. Excludes existing docs/posthog_release_health.txt deletion and unrelated untracked files. Reviewed sequentially in the main thread, following the user-provided agent-tool mapping; no independent reviewer-agent claim.

## Correctness and persistence
- Actions reject invalid IDs, repeat answers, matched/same cards, third-card taps, premature guesses and post-completion changes.
- Matching has no timer/callback race: mismatches remain visible until explicit retry. Navigation requires completed rounds.
- Saved sessions validate catalog version, challenge identity, board permutation, indices and completed prior rounds before rendering. Corrupt JSON and malformed boards fall back safely. Daily and practice storage are isolated; dates use the local calendar.
- Repeat-play review found same-title guessing rounds could repeat in one mix. Fixed by choosing a different seeded challenge. Practice avoids repeating identical boards/challenges immediately.
- Scores have a one-point completion floor, with zero for deliberate reveal/skip. Repeated clue taps cannot charge again.

## Content and UI
- Verified credits and years against TMDB, including all three Double Feature actor connections. Distractors exclude the entire cast. Twelve films have bundled scenes/posters; all lead portraits exist.
- Odd Movie Out rotates four objective release-era rules and always generates exactly one exception. No timeline year ties.
- Timeline feedback moved above the next action after screenshot review. Detective cast clues include portraits. Existing Daily Puzzle remains unchanged; arcade explains separate daily scoring.
- VoiceOver labels preserve hidden memory cards and scene answers. Scramble exposes numbered scene sections so nonvisual users can assemble the board. Reduced Motion skips explicit game animations and symbol bounce. Dynamic Type uses single-column answers and two-column matching boards at accessibility sizes.

## Test review
- Standalone harness covers every kind across 40 seeds, all transitions, invalid inputs, scoring, serialization, mixed action sequences, daily rollover, corrupt saves, practice isolation and content assets (7,222 checks).
- UI scenarios cover all seven games, daily summary, persisted memory pairs after process relaunch, Home entry and accessibility text sizes. Initial lazy-grid existence assertions were corrected to scroll before requiring offscreen choices.
- Clean full rerun: all 302 tests passed (265 XCTest unit, 14 Swift Testing, 23 UI). All 10 arcade UI tests also passed on iPad. A later screenshot review found large-text horizontal overflow; viewport bounds and vertically stacked accessibility headers were added, with a new bounds assertion. Scene images were also bounded to prevent intrinsic-size overflow. Final layout regression passed 2/2 on both iPhone and iPad; corrected phone screenshots visually inspected.

## Operational validation after a future release
Owner: app maintainer. Observe the first 7 days, with denominators by game/mode/catalog_version. Events: movie_arcade_started, movie_arcade_round_completed, movie_arcade_mix_completed, movie_arcade_left. Inspect round completion, skips, mistakes, points and daily completion; compare game-specific exits rather than mixing with the older daily_puzzle funnel. Investigate any game with starts but no completions or a concentration of skips; fix or temporarily remove its lobby entry if a reproducible blocker is found. Simulator analytics are intentionally disabled. No live analytics outcome is claimed.

Limits: curated English starter pack; three fixed actor pairings in Double Feature. This is a playable first catalog, not unlimited content. Physical-device play and production retention remain unmeasured. No new release submission is part of this implementation.

## Confirmed UI defect and fix
Scramble image descendants extended beyond clipped cells, creating overlapping touch/AX bounds and selecting the wrong tile. Corrected hit shape and accessibility grouping, with explicit button trait/action. A regression checks non-overlapping tile rectangles and completes the real two-swap interaction. Also moved secondary button minimum sizes inside labels so their touch areas meet 44pt. Latest iPhone targeted run: 2/2 passed (Scramble and largest Dynamic Type).
