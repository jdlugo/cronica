# Bounded overnight Arcade validation

This pass follows the user's instruction to keep working while they sleep. The baseline release, 4.25.44 (17), was already available in internal TestFlight. The changes here are subsequent source changes and are not included in that uploaded binary.

## Reproduced recovery defect

Memory and Double Feature accepted a decoded save with only one member of a pair marked as matched, or two unrelated cards marked as matched. Those disabled cards could never be matched again. This was reproduced with deliberately malformed saves; no production incident was observed.

The round validator now requires every saved matched group to contain both cards. The progress store rejects a broken save and can replace it with a fresh playable session. Local commit `7ccf0144` contains the model change and regression checks. The retained red log shows the original failure; the original green log records 10,605 checks across 40 seeds and all ten game types. A subsequent explicit legacy Double Feature matched-pair compatibility check also passes, bringing the final engine count to 10,606.

## Rendering and accessibility

Supporting text on the Arcade's fixed dark background uses an opaque light gray. Memory card captions have a dark backing and allow vertical wrapping. Lobby titles and symbols preserve their natural height. The test controller waits for stable sheet geometry before taking audit screenshots, scrolls to the lazy iPad Casting choice before waiting, and checks that replay controls fit completely inside the sheet.

Structural accessibility audits fail on touch-region, missing-description, clipping and trait findings. Every contrast diagnostic is retained separately for visual review. Contrast diagnostics are **not** treated as full accessibility passes: the automated checker continues to report some labels on gradients and layered posters. Representative solid pixels in two retained screenshots measured 12.52:1 for Scramble instructions and 13.41:1 for a Memory caption; those limited samples do not prove every glyph, state, or background meets a contrast standard. Apple explains both investigating individual audit findings and the possibility of contrast false positives in [Perform accessibility audits for your app](https://developer.apple.com/videos/play/wwdc2023/10035/).

The original broad audit failure reports and simulator results remain in `/private/tmp/`. An initial runner launch failed with the simulator's `Busy` preflight error before executing tests; restarting the simulator allowed the same compiled tests to run. This was a runner failure, not an in-game crash. Title wrapping and two wider lobby columns cleared the named title warnings. Final audits retain two unmapped clipping findings on iPhone and four on iPad. Bringing the footer fully into view did not clear them. Both final lobby navigation checks pass, while both strict structural audits remain failing: this pass does **not** establish readiness for a new upload, and those unmapped reports are not suppressed.

## Coverage and boundaries

The unchanged build-17 source completed all ten game flows on iPhone. The initial iPad pass completed nine and exposed the Casting controller's missing scroll. The rebuilt app then completed all ten games on both devices, including fully visible replay controls. The final subsequent change is only the lobby column declaration; `source-hashes.json` proves the gameplay bodies are unchanged. Both final lobby navigation checks cover that refinement. Exact pass/fail counts, device identifiers, result paths and remaining findings are recorded in `validation.json` and `game-grid.md`.

These are deterministic simulator interactions using known fixtures and answers. They prove mechanics and recovery for the exercised paths, not real-human fun, blind difficulty, retention, revenue, VoiceOver usability, CloudKit synchronization, or physical TestFlight behavior. No App Store review was submitted in this pass.

Publication continues on `codex/arcade-polish-testflight`; the original local branch and its generated snapshot media remain preserved. Publication excludes only the existing generated-media prefixes documented in the prior release evidence.
