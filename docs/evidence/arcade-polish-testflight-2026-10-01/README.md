# Arcade polish release evidence

The user requested commit, push, and TestFlight delivery. Local release commit `a1729f0e` contains the final app source, regression evidence, and 4.25.44 (17) metadata. The signed archive and IPA were built from that clean commit.

The original branch was never published and contains approximately 12 GB of unique generated-media history, including a 225 MB ZIP. Two HTTPS pushes failed with HTTP 500. Preserve `codex/arcade-growth-delivery` locally; publish `codex/arcade-polish-testflight` from the current source snapshot instead, with the user fork main branch as parent. The release branch omits generated screenshot references, store screenshots, and preview exports. All application, extension, test code, scripts, and backend source match the archived commit. The original snapshot comparison images remain available on the preserved local branch; a fresh clone of the publication branch requires regenerating or recovering those references before running image-baseline comparisons. The release regression tests do not depend on those image references.

`preflight.json` separates 284 unit tests, three startup/settings/Daily Mix UI checks, four final iPhone/iPad motion/layout checks, 10,361 engine checks, 96 analytics checks, and 173 localization keys. The initial regression result retains simulator fixture contamination (five paid-default failures and one wrong-tab launch failure); the clean baseline passes all 284 units and launch, with unchanged source.

`export-verification.json` records the IPA hash, matching main/widget/watch metadata, verified distribution signing, production push and CloudKit entitlements, and disabled debugger entitlement. `source-publication.json` proves that only generated media and its ignore rules differ between the archived and published source snapshots.

Original signed artifacts, test results, and diagnostic logs remain outside Git under `/private/tmp/`. Physical TestFlight installation, current-build production telemetry, and real-user motion comfort remain unverified. Internal beta availability does not establish App Store approval.

Apple independently confirmed build `f5f4967e-9706-463c-ae9c-3db50d9cfa6b` as **VALID / IN_BETA_TESTING**. Upload, crash symbols (four slices), and English TestFlight test notes succeeded. This establishes availability to internal testers; it is not a physical-device install or an App Store review submission.
