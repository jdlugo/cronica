# Arcade movie discovery validation

Completed games now offer their disclosed movies as a route to the existing movie details and watchlist. Replay and Daily Mix continuation remain above discovery. Cards use bundled posters and release years; multi-film games include their complete movie set. Daily Mix deduplicates movies without exposing unfinished rounds.

Movie opens and successful additions use `movie_arcade_movie_opened` and `movie_arcade_watchlist_added`. Both carry movie ID, result/summary surface, source round/run/challenge identity, mode and score. Summary attribution uses the first completed round containing that movie. Revealed rounds retain `skipped=true`. Loading an existing watchlist entry, synchronizing another screen's addition, failed saves and removals do not emit an addition callback. Simulator Arcade events remain suppressed.

## Verified behavior

Device: iPhone 17 Pro, iOS Simulator 26.3.1, UDID `54589BE9-B7F0-4E11-890E-E437D7D446EB`; scheme `Story (iOS)`.

| Check | Result |
| --- | --- |
| Full configured CronicaTests target | 269 XCTest + 14 Swift Testing tests passed |
| Five discovery UI flows | All passed in the same finalized bundle; 288 total tests, zero failures/skips |
| Rules and save compatibility | 9,829 assertions across 40 seeds and all 10 game types |
| Analytics factory/journal | 96 assertions, including completed-only attribution and summary source rounds |
| Localization | 170 keys covered in English, Spanish and Mexican Spanish; placeholder parity and syntax pass |
| Missing-store recovery | Failed save keeps Add state, emits no callback, and succeeds after a store is restored |
| Duplicate handling | Repeated persistence save creates one entry; a preexisting entry never reports a new addition |

The five UI flows cover Scene Spotter completion → details → save → return → replay; Daily Mix save → continuation → summary → process restart → existing save → back to games; failed detail loading → Retry → successful save; a three-lock Heist → saving Toy Story → independently opening Endgame → reopening Toy Story; and Spanish poster matching without bonus trivia → discovery → save → return at Accessibility XXXL.

Two existing game regressions (Heist completion and Odd One Out year help) also passed in the initial focused run. Its bundle had two failing persistence tests, so it is retained as failure evidence rather than reported as a passing suite. Those tests reproduced Core Data's Objective-C exception when saving without a loaded store. The implementation now guards store availability before saving. Save success is confirmed before changing UI state, scheduling notifications or reporting an addition; failed insertions are removed without rolling back unrelated edits.

## Visual iteration

Inspection of the first Spanish large-text screenshots revealed discovery cards squeezing titles into narrow columns. Cards now stack their posters and full-width copy at accessibility sizes, and the test requires a card to fit within one screen. Existing movie-detail action labels were also clipped (for example, Quitar displayed as Q…). Accessibility-size actions now stack vertically and expand their labels. A final focused normal/large-text rerun passed both complete flows (two tests, zero failures/skips). It additionally verifies that the Spanish watchlist action expands beyond 70% of the screen width and that each discovery card fits within one screen.

## Evidence and limits

See [evidence](../evidence/arcade-discovery-2026-10-01/README.md) for finalized summaries and full-resolution JPEG previews. Original xcresult bundles are local under `/private/tmp/arcade-discovery-*2026-10-01.xcresult`.

UI tests use DEBUG simulator metadata for the twelve curated movies and a separate persistent SQLite store under `Application Support/ArcadeDiscoveryTests`. They exercise the real details view, callbacks, Core Data save and relaunch. The fake January 1 release dates are test fixtures, not catalog corrections. No streaming providers or recommendations are invented. The release route uses the existing network service; live TMDB/provider availability, production PostHog delivery, iPad, VoiceOver, native Spanish review and real-device coverage were not established in this delivery. The prior 70-persona grid remains a historical baseline; it was not rerun for this feature.

Retention and revenue have not been measured. After release, join movie opens/additions to eligible completed rounds by `round_id`, retaining counts beside rates. Report solved and revealed cohorts separately; exclude simulator/debug/test runs. Compare subsequent return visits for movie savers and non-savers as an observational signal, without treating that comparison as causal proof. No new purchase gate, upload or App Store submission is included.
