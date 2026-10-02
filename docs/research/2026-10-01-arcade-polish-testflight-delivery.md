# Arcade polish TestFlight delivery

4.25.44 (17) is processed and available to internal TestFlight testers: Apple build ID `f5f4967e-9706-463c-ae9c-3db50d9cfa6b`, `VALID`, `IN_BETA_TESTING`. The verified package includes Scramble long-press drag and tap fallback, clearer controls, brighter Memory imagery, short transitions, and Reduce Motion support. Test notes are saved and independently verified.

The signed release archive used clean local commit `a1729f0e`. GitHub publication uses source commit `d40d38c1` on `codex/arcade-polish-testflight`; all app, extension, test code, scripts, and backend source are identical. The original local branch is preserved. The published branch excludes generated image-baseline files, store screenshots, and preview videos: two pushes of the old branch failed with HTTP 500, and its approximately 12 GB of unique generated-media history includes a 225 MB ZIP over GitHub file limits. Original image references remain accessible on the local branch.

Fresh validation comprises 284 unit tests, three startup/settings/Daily Mix UI checks, four final standard/reduced-motion iPhone and large-text iPad complete-flow checks, 10,361 engine checks, 96 analytics checks, 173 localization keys, and the production ad-unit gate. Initial paid-default and wrong-tab failures were retained; after clearing only the simulator fixture paid flag and restoring Home, all units and launch passed with unchanged source.

Archive and exported IPA signatures were verified separately. Main, widget, and watch bundle versions all match 4.25.44 (17); push and CloudKit entitlements are production, and debugger attachment is disabled. Crashlytics confirmed all four symbol slices under the user's existing approval. Apple separately confirmed upload acceptance and completed processing.

Signed artifacts and original results remain under `/private/tmp/`. [Release evidence](../evidence/arcade-polish-testflight-2026-10-01/README.md) records hashes, processing receipt, test counts, source-publication mapping, and upload logs.

Physical TestFlight playthrough, CloudKit synchronization, current-build production analytics receipt, and human motion/accessibility comfort remain unverified. No production App Store review or external beta review was submitted.
