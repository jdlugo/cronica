# Movie Arcade requirements and execution

## Outcome
Seven different tap-first movie mini-games, individually playable from Home and combined into a four-round daily mix. Existing Daily Puzzle remains available. User authorized requirements, implementation, testing and iterative simulator play; this work is not a release submission.

## Shared requirements
- Bundle a verified 12-film starter pack with posters, textless scenes and actor portraits; no network dependency during play. Record TMDB sources. Honest starter-pack scope; do not imply an endless catalog.
- Daily Mix: scene recognition first, then three distinct rotating mini-games; stable local-date seed, shuffle answers, preserve progress across close/relaunch. Practice cycles through fresh challenges; no impact on the existing puzzle streak.
- Four-round summary with points, encouraging feedback, replay/practice, and system sharing. No automatic sharing.
- Explain each mechanic inline; no typing, countdown, lives or ad interruption. Wrong choices give corrective information and permit continuation. Every round can reveal/skip for zero points.
- Three points maximum per round; mistakes and requested help reduce to minimum one for a completed round. Completion must be idempotent; invalid/repeated taps cannot score. State changes persist before navigation.
- Accessible names and selected/matched states; 44pt minimum targets; Dynamic Type layouts; Reduce Motion support; decorative images do not disclose hidden answers to VoiceOver.
- Analytics for start, round completion, abandon and mix completion with mode/game/catalog version and result, without personal input. Do not alter existing puzzle metrics.

## Games and acceptance
1. Movie Scramble: swap two of four image quadrants; never start solved; highlight selected tile; assembled image unlocks four title choices. Rearranging itself has no penalty. Show-image assistance available.
2. Casting Call: poster plus four named actor portraits, exactly one credited cast member. Wrong portraits disable, correct answer reveals actor and movie.
3. Before or After: place three incoming movies relative to a visible anchor. Distinct release years; ties excluded. Each answer reveals the actual year and builds a chronological timeline; final feedback reflects mistakes.
4. Odd Movie Out: four posters with an explicit, objective release-era rule, exactly one exception. Wrong choices explain why that movie belongs; correct choice explains the exception.
5. Double Feature: match six posters into three pairs by the same lead actor. Unique, verified pairs; wrong pair remains visible until explicit retry, matched pairs lock and name the shared actor. No auto-dismiss race.
6. Movie Detective: start with a cropped scene, choose plot/cast/year clues in any order, each revealed at most once and with visible score cost. Four title choices; completed reveal combines movie and clues.
7. Poster Memory: six cards, three poster pairs. Keep mismatches visible until explicit retry. Matching completes the board, then a four-choice release-year bonus question; same-card/repeated taps cannot match. No timers.

## Implementation units / checklist
- [x] Verified catalog and bundled imagery; model/rules with standalone regression tests.
- [x] All seven game controls, answer reveals, soundless haptics/motion, instructions.
- [x] Home arcade entry, Daily Mix, practice, persistence, summaries/sharing, telemetry.
- [x] Model edge cases and persistence round-trip; UI playthrough for every game and daily progression.
- [x] iPhone and iPad simulator build/tests; Dynamic Type, close/reopen, screenshot review; improve friction found.
- [x] Final review, record actual evidence and limitations.

## Verification scenarios
Deterministic date and practice variation; unique answer/cast filtering; shuffled solvable tile board; invalid and double taps; match mismatch recovery; timeline ties excluded; clue scoring floor and repeated-clue guard; skipping; terminal-state immutability; daily rollover; corrupt save fallback; resuming partially matched/revealed rounds; daily completion once; no production puzzle progress mutation.

## Iteration findings
- First simulator pass: 7/9 new UI scenarios passed. Scramble and large-text checks required scrolling before asserting lazy-grid choices exist; test helper corrected. No failing user interaction was established by those two early assertions.
- Reviewed screenshots: moved timeline year feedback above Next; added actor portraits to Detective cast clues; four rotating era rules for Odd Movie Out; no immediate repeat in free play or duplicate title-guessing answers in one mix.
- Standalone rules/storage/assets checks: 7,222 passed across 40 seeds, all eight round types (seven new games plus familiar scene anchor), including mixed action sequences.

- Subsequent Scramble test exposed a real cropped-image hit-testing defect: image descendants expanded tile touch/accessibility frames. Fixed with bounded content shapes, hidden decorative children and explicit accessible button actions. Regression asserts no overlap and completes two swaps plus a correct guess. Enlarged secondary actions inside their button labels to ensure real 44pt targets.
- Clean iPhone full-suite rerun passed: 265 XCTest unit + 14 Swift Testing + 23 UI tests (302 total), zero failures. iPad arcade suite: 10/10 passed. Results: `/tmp/movie-arcade-final-full.xcresult` and `/tmp/movie-arcade-ipad.xcresult`.

- Screenshot inspection caught horizontal overflow at the largest Dynamic Type size despite successful navigation tests. Constrained content to the viewport, stacked score/result headers at accessibility sizes, and added a title-bounds regression. The assertion then exposed remaining scene-image overflow; scene images now render inside a bounded GeometryReader. Final focused validation passed on iPhone and iPad (2/2 each), including bounded title and real Scramble taps. Corrected phone screenshots visually inspected.

## Final validation and limits
- iPhone 17 Pro and iPad Air 13-inch (M4), iOS 26.3.1 simulators.
- Full iPhone suite: 302/302 passed before the final isolated layout adjustment; all 10 arcade UI scenarios also passed on iPad.
- Final layout regression: 2/2 on each device using the final compiled source (`/tmp/movie-arcade-bounded-scene.xcresult`, `/tmp/movie-arcade-ipad-bounded-scene.xcresult`).
- Standalone arcade harness: 7,222 checks passed; existing movie quiz harness passed. Xcode project plist and diff whitespace checks passed.
- Visual review covered phone lobby, actor portraits, memory board, timeline feedback, summary, Scramble and largest accessibility text; iPad portraits/timeline also reviewed.
- English 12-film starter pack and three fixed actor connections. Physical-device feel and retention are unmeasured. Automated completion cannot establish subjective fun; ready for hands-on play at Home → Movie Arcade. No new App Store submission.

## Follow-up rendering polish
- Casting Call uses bounded, full portraits instead of tightly cropped landscape strips. Screenshot review caught a forehead-only crop at accessibility sizes during the first iteration; aspect-fit rendering corrected it.
- Double Feature titles wrap without a three-line cap at accessibility sizes. Daily Mix score rows stack vertically at those sizes.
- Added a maximum-text-size portrait regression checking every answer card stays inside the screen and remains playable.
- Initial focused checks passed 3/3 on iPhone (portrait sizes and matching) and 3/3 on iPad (portrait sizes and Daily Mix). Final portrait-fit iPhone checks passed 2/2; corrected screenshots visually inspected. Final iPad portrait-fit checks also passed 2/2. Result bundles: `/tmp/movie-arcade-portrait-fit.xcresult` and `/tmp/movie-arcade-ipad-portrait-fit.xcresult`.
- The user's attached Google OAuth error screenshot was unrelated to arcade rendering; no authentication configuration was changed.
