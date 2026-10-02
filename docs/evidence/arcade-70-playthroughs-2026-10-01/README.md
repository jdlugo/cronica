# Arcade persona playthrough evidence

Complete: **70 unique runtime traces, 215 full-resolution screenshot previews and 21 linked live-image judgments**, covering seven assigned personas and ten games each. The comparison shows observed simulator outcomes, not enjoyment scores, voluntary replay, retention, conversion or revenue.

## Read the evidence

- [Interactive comparison](index.html): filter by persona, game and outcome; open a cell for ordered actions, screenshots and limitations.
- [Markdown comparison](comparison.md), [comparison CSV](comparison.csv), [individual observations CSV](observations.csv), [normalized data](cells.json).
- `traces/` preserves selected runtime JSON byte-for-byte. Normalized result-scan uncertainty and pre-relaunch wins are additional interpretation; they do not rewrite raw traces.
- `screenshots/` contains full-resolution JPEG previews, converted from actual simulator PNG captures with `sips`, quality 85. These are lossy previews, not generated images or guaranteed pixel-perfect originals. Early temporary PNG duplicates were removed after preservation because the host ran out of disk space.
- `preflight/` retains superseded larger-text, clue-reader, image-memory and capture attempts. These do not fill final grid cells.
- `validation/` records runner progress, finalized result summaries and artifact/browser checks. A passing XCTest case means the runner executed; a recorded policy stop is not an earned game completion.

## Execution and recovery

Baseline app source: `6b8986f3`. Device: iPhone 17 Pro simulator, iOS 26.3, UDID `54589BE9-B7F0-4E11-890E-E437D7D446EB`. Scheme `Story (iOS)`. Only UI-test registration, test tooling and evidence were changed; no production game code.

The initial full run began at 13:54:26 UTC. P1–P4 each finished a ten-game case. The Xcode MCP connection ended during P5; its result bundle never finalized. Raw traces and screenshot previews were rescued directly from the fixture's temporary evidence directory, and the progress log is retained. The incomplete duplicate bundle and rebuildable product copy were removed to free disk space. Simulator reinstalls relocated preserved image captures; stable request basenames recover the exact named images, while raw traces retain their original absolute paths. Do not interpret the initial run as one finalized seven-case pass.

A direct Xcode run resumed P5's nine remaining games and executed P6/P7. Larger-text discovery now scrolls lazy controls into existence and freezes displayed labels; identifiers only reacquire controls. Detective reads its opened grouped plot label. Result scans now stay within the Arcade sheet. One disk-full interval lost P5 Heist's trace and Director's Cut's start capture; both were repeated with complete captures.

Focused corrections repeated P1–P4 Detective, P5 Heist/Director's Cut, and P6 Heist. P6's earlier controller forgot an actual visual recognition after its assigned wrong guess, then made another guess; the correction retains the already-observed title within that cell. This is a controller correction, not a product-difficulty finding. Superseded evidence remains separate.

## Final validation

- 70/70 combinations; original JSON checksums match; ordered gameplay tap counts agree in every cell.
- 215 previews and 362 local comparison links resolve; all 21 live judgments have their exact named capture previews.
- Direct recovery:3 XCTest cases passed; focused corrections:3 passed. Initial P1–P4 case passes are retained in the rescued progress log, not a finalized full-run bundle.
- Manual suite default:11 skipped,0 failed. Browser:complete70-cell coverage, filters and detail panels passed,3 selected-cell previews loaded,0 page errors.
- Selected harness revisions:37 initial unversioned traces,26 lazy-control-recovery-v2,7 live-vision-retained-v3. Decision corrections are documented above and in preflight; the final provenance file records source and trace hashes.
- Root's original 40-minute target was exceeded by serial simulator execution, transport/capture issues and focused corrections. Agents had bounded preparation/review handoffs; no unattended agent work remains.

## Scope limits

- Fresh seed 0 per persona/game, one round, isolated fixture entry; ads and onboarding disabled. Most profiles have a fixture purchase entitlement; P6 is unpaid but monetization is still suppressed.
- P2's ten second-round starts are assigned and unfinished. No repeated-content or next-day-return test was executed.
- Every Scramble round uses Assemble for Me. Independent tile reconstruction remains untested.
- P3 compares only points, progress labels and selected/matched cards. Completed practice intentionally reopens fresh; its two first-earned results remain explicit in normalized data. No Daily Mix score-loss claim.
- P5 tests XXXL text, not VoiceOver, reduced motion or iPad. P7 uses Spanish locale, but the controller can locate English controls; completion does not establish Spanish comprehension.
- Early unscoped result scans include background Home controls and are normalized to Unknown. Later scoped scans show only controls reached by the fixture; they do not establish a working movie-discovery or purchase flow.
- Limits are45 gameplay tap attempts and150 active automation seconds per cell, excluding a maximum180-second live image handoff. Durations are automation time, not human solving speed. Persona stops are declared knowledge/language constraints, not observed dislike.
- This operationalizes a narrower subset of the reference profiles. Normal Home discovery, three rounds per featured game, seven daily dates, ordinary ad exposure, live purchases/restore and human willingness to return/pay remain open.

## Reproduce

This suite is manual and opt-in. Apple's local `xcodebuild` manual documents that `TEST_RUNNER_` variables pass to test runners with the prefix stripped. Without `TEST_RUNNER_ARCADE_PERSONA_PLAYTHROUGH=1`, persona cases skip to avoid unattended live-image waits during ordinary tests.

Run one simulator serially, explicitly selecting `testP1` through `testP7` in `CronicaUITests/ArcadePersonaPlaythroughTests`; do not select the whole class unless you also intend its subset recovery cases. Use the normal project/scheme and a fresh result bundle:

```sh
TEST_RUNNER_ARCADE_PERSONA_PLAYTHROUGH=1 xcodebuild \
  -project Story.xcodeproj -scheme 'Story (iOS)' \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:CronicaUITests/ArcadePersonaPlaythroughTests/testP1 \
  -resultBundlePath /private/tmp/persona-run.xcresult test
```

The example selects P1 only; add explicit P2–P7 selectors for all 70 cells. Each image request in the fixture temporary `arcade-persona-live/` directory needs a fresh screenshot inspection and a reply naming a displayed familiar title with a visual basis, or a stop reason. `scripts/arcade_persona_vision_bridge.py` forwards validated decisions only; its current simulator path is local to this capture host. Never infer an answer from seeds, asset filenames, numeric identifiers or the game engine.

Export the named JSON/screenshot attachments, or copy the fixture's `tmp/arcade-persona-evidence/` files plus image-judgment captures. When a cell is rerun, use only its latest trace and same-attempt screenshots; preserve superseded attempts outside the input directory. Then:

```sh
python3 scripts/build_arcade_persona_grid.py --input /path/to/export --output /path/to/grid
python3 scripts/validate_arcade_persona_evidence.py --evidence /path/to/grid --input /path/to/export
```

Both commands reject missing final coverage. `--allow-partial` is reserved for progress inspection and must not be used as final-delivery proof.
