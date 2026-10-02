# Puzzle engagement investigation — September 29, 2026

Read-only production investigation; no app or backend behavior changed.

## Evidence
PostHog project 560852, rolling seven-day window queried around 13:00 UTC. Counts are distinct telemetry identifiers, not verified people. Internal/review traffic is not reliably separable because there is no environment marker on the inspected events.

- Build 11/version 4.25.40: 19 puzzle openers, two guessers. Both guesses solved the built-in sample (`2026-02-15`), not a current daily puzzle.
- 16 notification-driven openers had no guess events anywhere in the same window. This is a user-level diagnostic count, not an ordered conversion funnel.
- All 20 continuation failures belong to the two sample solvers: 12 on September 24 and eight on September 27. Their events report attempts=1, terminal_result=solved and reason=NSURLError.
- The same users' service logs contain offline/no-network-route errors (-1009). Continuation events omit the error code, so individual historical failure codes cannot be conclusively recovered from those events.
- Latest-puzzle Firestore read, random endpoint and collection read all returned HTTP 200 during this investigation. Random endpoint took 13.14 seconds on this single probe; this is not a latency distribution or proof of historical availability.
- Current production clue was nonempty and valid Unicode. Collection returned 100 records plus nextPageToken; client ignores pagination. This limits variety but does not explain offline errors.

## Confirmed failure path
`DailyPuzzleModalOpenLoader.refreshViewModelForOpen` falls back to the fixed sample when remote loading fails. Solving it enables continuation. `fetchNextPuzzle` uses the network for both primary and fallback sources; it has no offline alternative. Its error is caught in `HomeView.loadNextDailyPuzzleFromModal`, which only emits telemetry and preserves the previous solved puzzle. The loading state then clears without visible error feedback, allowing another identical failed retry.

Reproduced using the actual extracted DailyPuzzleService and actual DailyPuzzle model in a temporary Swift executable, injecting a URLProtocol that returns NSURLErrorNotConnectedToInternet. Opening falls back to 2026-02-15; three continuation attempts each fail with NSURLErrorDomain -1009. No repository source modifications were required. Harness: /tmp/puzzle-offline-repro.swift.

## Why the open-to-guess cause is not established
`trackOpened` emits both opened and session_started before `showDailyPuzzle = true`, not after the game appears. Session-ended telemetry is emitted only for solved/failed games, not abandonment. There is no first-input signal. Thus current events cannot distinguish failed/obstructed presentation, immediate dismissal, difficulty, or lack of interest.

Guess telemetry is emitted immediately after accepting any nonblank guess on an unfinished puzzle, before correctness evaluation. It uses the same tracker as opened; there is no obvious separate tracking gate. Successfully recorded sample guesses show the pathway can work, but do not prove the notification path works on affected devices.

## Recommended focused changes and tests
1. Make continuation failure visible, retain the current puzzle/progress, and provide a deliberate retry. Offer the existing bundled archive for offline play. Record a sanitized error category/code, not raw NSError descriptions or URLs.
2. Add actual-screen-visible, first-input and abandoned-session events with per-puzzle presentation identity. Keep entry intent distinct from visibility; update the funnel accordingly.
3. Add an offline continuation UI test that asserts a visible error and retained progress; add service tests for both remote sources failing. Existing next-puzzle test covers successful retry after receiving the current puzzle, not offline feedback.
4. Add a notification-launch UI test that asserts the game appears and accepts a first guess, including restored completed progress and competing presentation states. Add analytics tests for one visibility event per presentation and abandonment without a guess.

These changes can address the confirmed retry dead end and resolve the measurement gap. They cannot yet be claimed to fix the notification open-to-guess drop. Inspect affected session recordings or reproduce the production notification presentation path before attributing that drop to puzzle difficulty or UI obstruction.

## Implemented follow-up
The user authorized the recovery and measurement changes. The daily game now presents localized Retry, Stay Here and Offline Puzzles actions on continuation failure, keeps solved progress, and opens the archive after sheet dismissal without competing with the reminder prompt. Failure events include sanitized URL error codes. Actual game visibility, first input (without text) and unfinished dismissal have per-presentation telemetry.

Validation: the first-input regression initially failed (zero events rather than one). Final simulator run passed 29 tests (27 view-model tests and two UI tests), with zero failures or skips: `/tmp/puzzle-recovery-final.xcresult`. UI coverage exercises notification launch → first guess → solved, and forced offline continuation → Retry → retained progress → bundled archive. A test-fixture launch-intent leak was isolated between UI launches. Four locale files passed plist lint, and diff whitespace checks passed. Recovery alert visually checked in `/tmp/puzzle-recovery-live.png`.

The notification test injects the same launch-intent store consumed by the app; it does not establish actual APNs delivery. Existing restored-progress tests remain in the view-model suite. No claim is made that these changes explain the production notification drop-off; the new events enable that diagnosis after release. Changes are local and have not been uploaded or submitted.

## Reminder opt-in follow-up
Replaced the post-dismissal alert with a nonblocking action in the solved daily puzzle's visible completion bar. The first screenshot exposed that placing the action in the scrolling content left it below the fold; the final UI test requires it to be tappable without scrolling. The offer explains 18:00 local delivery and completion suppression. Settings shares permission handling and confirmation. Full authorization restores both preferences, provisional permission requests full alerts, and denied permission links to Settings. Earlier declines do not permanently remove the inline offer. Copy covers English, French, Mexican Spanish and Brazilian Portuguese.

Choice and outcome events are separate; opening Settings is not reported as granted permission. Offer telemetry now comes from the rendered action. Local saved-insight definitions use confirmed enabled outcomes; no dashboard import was performed.

Validation: 45 tests passed with zero failures in `/tmp/puzzle-optin-visible.xcresult` (43 unit tests, two UI tests). Authorization unit tests cover undetermined/provisional, authorized, denied, refusal, errors, and remaining provisional. UI tests cover visible opt-in after a notification-intent solve and offline continuation recovery. `bash scripts/test_daily_puzzle_reminders.sh` passed local-time, DST, completion, duplicate, opt-out and scheduling-race checks. Four translation files passed plist lint. Final screenshot inspected at `/tmp/puzzle-optin-visible-attachments/80AAC593-D2AC-441D-B419-D074B3DD176B.png`.

Real-device OS permission-dialog interaction, a round trip through iOS Settings, and actual next-day delivery are not established by these tests. The changes are local, not uploaded or submitted.
