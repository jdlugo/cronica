# Arcade subtle motion validation

Implemented locally in `MovieArcadeView.swift`. Memory card faces crossfade over 0.16 seconds; Scramble sections retain their identity and move between positions over 0.18 seconds; game, replay, lobby expansion and summary navigation use a 0.2-second fade. The result icon no longer bounces. Game state updates and saves immediately, and animations never decide outcomes or delay input. The added animations are disabled when the system Reduce Motion preference is enabled.

## Final build validation

The final source compiled successfully through XcodeBuildMCP. After its transport closed during a long combined run, the following checks used the exact prepared test package through `xcodebuild test-without-building`, with a 150-second execution limit per test. All four checks passed, with no failures or skips. Both simulators ran iOS 26.3.1.

| Device | Check | Result |
|---|---|---|
| iPhone 17 Pro | Standard motion: Memory mismatch/retry, matching completion, replay, return to lobby, All Games expansion, Scramble drag completion and return to lobby | Passed |
| iPhone 17 Pro | Same flow with the actual Settings Reduce Motion switch enabled | Passed |
| iPad Air 13-inch (M4) | Accessibility XXXL Memory: all pairs, completion, fully visible replay control, fresh replay board | Passed |
| iPad Air 13-inch (M4) | Accessibility XXXL Scramble: drag to restore the scene, correct answer, 3/3 points | Passed |

The motion-setting tests verify the actual Settings switch before gameplay and verify restoration to its preceding value after gameplay. Settings exposes the whole row as a switch; the controller targets the switch at the right edge and waits for its value. This tests the real operating-system preference rather than a fixture override.

The final result bundles are `/private/tmp/arcade-motion-final-standard-2026-10-01.xcresult`, `/private/tmp/arcade-motion-final-reduced-2026-10-01.xcresult`, and `/private/tmp/arcade-motion-final-ipad-2026-10-01.xcresult`. Their exported summaries and source SHA-256 fingerprints are in `docs/evidence/arcade-subtle-motion-2026-10-01/`.

## Playback review and iteration

An initial conditional Memory face replacement appeared sharper than intended in the recorded frames. Both faces now remain mounted, with their opacity changing in place. The final recording shows intermediate blended frames and a short, smooth tile swap. This change retained the face-down accessibility label and hidden decorative posters. Final iPad screenshots were also reviewed: the replay button is entirely within the sheet, replay starts a fresh board, and Scramble completes at large text size.

Short previews: [Memory fade](../evidence/arcade-subtle-motion-2026-10-01/memory-fade.mp4) and [Scramble swap](../evidence/arcade-subtle-motion-2026-10-01/scramble-swap.mp4). Frame grids preserve the source sequence and are cropped to the control for inspection; full recordings remain in the corresponding xcresults.

Earlier in this pass, five functional checks passed for tap swaps, cancelled drops, drag/relaunch recovery, Memory replay and Daily Mix completion/summary persistence. Those preceded the final Memory fade adjustment and are additional navigation/regression evidence, not added to the final four-check count.

The initial Settings setup failure, a simulator runner launch failure, and the interrupted combined run are retained separately. They are not counted as passing final verification. Low disk space was handled by removing only regenerable build intermediates and an old screenshot export; prepared test products, signed release artifacts and original result bundles were retained. XcodeBuildMCP recording could not save its output, so the review used retained Xcode UI-test recordings instead.

## Scope and limits

This was a focused simulator check, not a new full ten-game playthrough or full unit suite. Physical-device motion comfort and VoiceOver user evaluation remain untested. No retention or revenue improvement has been measured. These changes are uncommitted and have not been uploaded to TestFlight or the App Store.

The implementation follows the existing SwiftUI animation and accessibility environment APIs described by [Apple's animation documentation](https://developer.apple.com/documentation/swiftui/animations) and [system accessibility testing documentation](https://developer.apple.com/documentation/accessibility/testing-system-accessibility-features-in-your-app).

## Subsequent release tracking

This report describes the local validation snapshot at the time of testing. The authorized commit, push, and TestFlight delivery are tracked in [the build 17 release plan](../plans/2026-10-01-arcade-polish-testflight.md).
