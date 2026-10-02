# Release candidate evidence

See `docs/releases/4.25.44.md` for the coverage and remaining gates.

- `iphone-summary.json`: finalized `/private/tmp/arcade-release-iphone-v3-2026-10-01.xcresult`; 286 passed, no failures/skips. Named UI attachments exported to `/private/tmp/arcade-release-iphone-attachments`; JPEGs show live movie persistence and Settings without the purchase offer.
- `ipad-initial-summary.json`: two game passes and two controller failures; `/private/tmp/arcade-release-ipad-2026-10-01.xcresult`.
- `ipad-settings-summary.json`: corrected Settings pass; remaining poster-grid selector failure; `/private/tmp/arcade-release-ipad-v2-2026-10-01.xcresult`.
- `ipad-live-summary.json`: final live discovery/save/relaunch pass; `/private/tmp/arcade-release-ipad-v3-2026-10-01.xcresult`. JPEG comes from its named `release-live-movie-persisted-after-relaunch` attachment.

Heist/Memory use deterministic game fixtures. The live discovery test sets no Arcade, network, metadata, puzzle, preview or monetization fixture flags, uses normal free-user monetization and the ordinary persistent store, and removes only a movie it added itself. The simulator's test ad was dismissed without following advertiser content. This is simulator disk persistence, not verified cross-device CloudKit sync or production ad revenue.

The normal scheme excludes seven screenshot/preview test classes. Counts describe the selected unit suites and named UI checks, not every UI test or every physical device. Original result bundles preserve failure history; passing summaries do not erase earlier failures.

`release-artifacts.json` ties clean source commit `46acf14b` to the signed archive, exported IPA hash, transport success and independent Apple processing result. Firebase Crashlytics confirmed successful upload of all four archived symbol slices after explicit user approval. No production review submission or physical TestFlight playthrough is claimed.
