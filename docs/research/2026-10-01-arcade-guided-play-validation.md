# Guided Arcade delivery and validation

The follow-up to the 70-persona study implements easier starting choices, optional knowledge help and Spanish gameplay copy. The original [comparison grid](2026-10-01-arcade-persona-playthrough-findings.md) remains a baseline; its cells have not been rewritten as if every persona replayed this version.

## Changes

- Memory and Scene Spotter appear first, above Daily Mix. All ten games remain available under All games. Exposure and journey events identify this layout as `guided_v2`.
- Casting and the Heist cast lock offer a credited cast member. Double Feature can display actor names beneath the posters, turning unfamiliar relationships into visible matching work. Timeline, Odd Movie Out and Director’s Cut can display the release years. Help costs one point while more than one remains and is free at the one-point floor. It never completes or skips a round. Heist retains its help cost at the final lock.
- English, Spanish and Mexican Spanish include 163 copy keys covering game names, instructions, optional help, feedback, scores, accessibility text, replay/results and all twelve plot clues. Catalog movie and actor names keep their spelling. Other locales fall back to English. Existing saves stay compatible; feedback already stored in an older language can retain that language until the next action.
- A regression reproduced missing year values in choice accessibility. The fix exposes Odd Movie Out years and unplaced Director’s Cut years through accessibility values. This verifies the exposed values, not a complete VoiceOver experience.

## Actual validation

| Evidence | Result |
| --- | --- |
| Offline engine, 40 seeds across all ten modes | 9,795 checks passed; help, restore, legacy saves, completion and three-practice-target variation included |
| Analytics journal | 87 checks passed |
| Localization resources | All 163 keys present in three locales; valid resource syntax, no duplicate Arcade keys, matching format arguments |
| First simulator batch | 5 tests passed: complete guided connections; complete helped Heist after relaunch; lobby/library; Spanish Detective; Mexican Spanish Memory at Accessibility XXXL |
| Accessibility regression before fix | 1 expected reproduction failed: Odd Movie Out choice value was empty instead of 1999 |
| Final regression batch | 3 tests passed: accessible year guide; complete guided Director’s Cut at XXXL; deterministic two-swap Scramble regression |
| Live visual Scramble | 1 opt-in test passed; three fresh rounds actually completed from screenshots, with 3/3 each and no help/mistakes |
| Ordinary run of manual visual test | Skipped as intended without its opt-in environment variable |

Device: iPhone 17 Pro, iOS Simulator **26.3.1**, scheme `Story (iOS)`. Both app and test targets compiled successfully. Finalized result summaries and screenshots are in [the evidence directory](../evidence/arcade-guided-play-2026-10-01/README.md).

## Unaided visual Scramble

The seed0 fixture was administratively revealed and discarded because its swap sequence was already known to regression tests. Each subsequent round came from the app’s Play another control. The runner supplied a screenshot and control addresses; it did not supply tile-section labels, seed values, engine state or a solution. The reviewer inspected each initial image and supplied swaps based on visible continuity, then chose a displayed movie title after seeing the assembled scene. Screenshots and six decision records are preserved.

| Fresh round | Visible reasoning | Swaps / answer taps | Result |
| --- | --- | --- | --- |
| John Wick | Join the face/body split at the outer edges and the car seams | 2 swaps + 1 answer = 5 taps | 3/3, no help |
| La La Land | Put the clock/man above his legs and the white dress below the woman | 1 swap + 1 answer = 3 taps | 3/3, no help |
| The Matrix | Put sunglasses/faces above the leather coats and pistol; join bullet trails | 2 swaps + 1 answer = 5 taps | 3/3, no help |

The live test took 378 seconds including external reviewer waits. The three images and tile arrangements differed. This is a model’s screenshot-driven play, not seven personas independently solving Scramble, human enjoyment or voluntary replay.

## Remaining product questions

1. Recruit real first-time players and measure an earned first finish, voluntary second start **and finish**, and next-day return by game. The implemented event identities and `guided_v2` property support comparing this layout once it has users.
2. Evaluate whether help teaches enough while retaining a satisfying challenge. Year guidance changes knowledge recall into sorting; actor labels change recall into visible matching. These are deliberate recovery options, not measured retention gains.
3. Review Spanish wording with native speakers and test iPad, VoiceOver and reduced motion. XXXL controls were reachable; long titles/results still require substantial scrolling. Completed Scramble tiles also visibly dim as disabled controls, a remaining visual polish opportunity.
4. Add useful solved-film discovery actions and verify ordinary ads, purchase and restore separately. This task used offline fixtures and suppressed monetization; no commercial flow or revenue lift was established.

No release upload or App Store submission was performed.
