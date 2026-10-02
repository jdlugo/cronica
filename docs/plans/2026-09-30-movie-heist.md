# Movie Heist: four iterations

## Requirements
An eighth free-play mini-game, with three distinct films and three locks: recognize a scene, identify a credited actor from a poster, then infer the hidden film from an original plot clue. Each correct answer recovers one code digit. The final answer opens the vault and reveals the recovered movie. No typing, timer, ads or additional network dependency. Recoverable wrong answers, one-point score floor, explicit next-lock action, skip, persistence, large text and Reduce Motion support use the existing arcade shell.

Keep the existing seven-mode Daily Mix rotation stable so this update does not alter saved daily challenges. The vault code is a progress reward, not a separate arithmetic task.

## Iteration 1: rules
Seeded three-film selection, deterministic answer choices, full-cast distractor exclusion, duplicate-tap guards and per-lock transitions. Model suite: 8,422 checks passed. No new catalog or asset dependency.

## Iteration 2: playable heist
Three visual clue screens, persistent digit slots, explicit next-lock action and final recovered-film scene. iPhone simulator playthrough passed (`/tmp/movie-heist-iteration2.xcresult`). Inspected completed-vault screenshot; the generic result needed a more distinctive payoff.

## Iteration 3: recovery
Round-trip tests at each lock, including eliminated answers and unlocked digits; rejects prematurely completed saves and an impossible fourth lock. Model suite: 8,443 checks passed. Existing storage persists each accepted action.

## Iteration 4: payoff and navigation
Unlocked-vault icon, large code display, “You’re in.” result, lock feedback above the continuation button, and scroll reset when advancing a lock. Added simulator test for a mistake, process restart after recovering a digit, continued play at maximum Dynamic Type and horizontal title bounds. Lobby now advertises eight games.

## Final verification
Final iPhone iteration-4 suite: 3/3 passed (normal heist, large-text restart recovery, eight-game lobby). Final iPad regression: 3/3 passed (normal heist, large-text restart recovery, existing Daily Mix). Results: `/tmp/movie-heist-iteration4.xcresult` and `/tmp/movie-heist-final-ipad.xcresult`. Final model rerun: 8,443 checks passed; existing movie quiz rules suite also passed. Normal and maximum-text-size final reveal screenshots inspected; no horizontal clipping. Diff whitespace check passed. Subjective fun and physical-device feel still require human play; no new App Store submission.
