# Arcade touch polish validation

Movie Scramble now supports holding a tile for 0.25 seconds and dragging it onto another position to swap. The tile lifts above the board and the destination is highlighted. Dropping outside the board or back onto the original slot preserves the board and score. Tap-to-swap and the existing accessibility action remain available.

Secondary actions now have visible borders and backgrounds. Answer cards have selection icons and stronger outlines, and lobby game cards have play icons. Buttons provide pressed feedback. Poster Memory has brighter card backs with a tap cue, modestly increased poster saturation/contrast, and corner match badges that leave the artwork visible. Card backs remain identical and disclose no movie identity.

New copy is translated into English, Spanish and Mexican Spanish. Motion effects respect the existing Reduce Motion environment.

## Verification

The standalone engine passed **10,361 checks across 40 seeds and all ten game types**, including invalid drops, prior tap selections, score preservation, saved progress and completed-round rejection. Analytics passed **96 checks**; localization passed **173 keys**; `git diff --check` passed.

iPhone 17 Pro, iOS 26.3.1: six distinct checks passed across two final bundles: tap completion, lobby navigation, memory completion/replay, cancelled drag followed by tapping, drag completion with relaunch recovery, and drag completion at Accessibility XXXL text size. An earlier memory large-text pass is retained separately and is not included in this six-check count.

iPad Air 13-inch (M4), iOS 26.3.1: four distinct checks passed across two bundles: memory completion/replay at Accessibility XXXL text size, drag completion with relaunch recovery, large-text drag completion, and cancelled drag followed by tap completion. Three checks were repeated with stricter viewport validation and all passed. There are ten distinct passing device/test combinations across iPhone and iPad, not ten human playtests.

Screenshot review exposed a weakness in the earlier controller: it checked button visibility against the full app window, allowing a partially visible iPad replay button to count as usable. The controller now scrolls against the game sheet's actual viewport, asserts that the whole replay button fits inside it, and activates replay to verify a fresh board appears.

The initial drag test failed on the old implementation because tiles did not move. Intermediate runs caught short-tap interference and a zero-size layout warning; the final implementation handles short taps independently of the long-press sequence and clamps temporary geometry sizes. Fixture controllers now explicitly open Home instead of inheriting a previously selected Watchlist tab. The original failing result bundles are retained under `/private/tmp/arcade-touch-*.xcresult`.

The drag sequence follows [Apple's gesture composition guidance](https://developer.apple.com/documentation/SwiftUI/Composing-SwiftUI-Gestures). The direct tile control exposes button traits and an accessibility action without a competing native button touch handler.

## Evidence and boundaries

Passing summaries and screenshots are in [the evidence directory](../evidence/arcade-touch-polish-2026-10-01/). Screenshots were visually reviewed for card contrast, board layout and button visibility. JPEGs are format-converted XCTest attachments; originals remain in result bundles.

These are fixture-based simulator checks. No physical VoiceOver, human enjoyment, retention or revenue outcome is claimed. Unrelated existing compiler warnings remain. This UI pass has not been uploaded; internal TestFlight build 4.25.44 (16) contains the earlier implementation.

## Subsequent release tracking

This report describes the local validation snapshot at the time of testing. The authorized commit, push, and TestFlight delivery are tracked in [the build 17 release plan](../plans/2026-10-01-arcade-polish-testflight.md).
