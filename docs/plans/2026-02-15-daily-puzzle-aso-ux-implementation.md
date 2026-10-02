# Daily Puzzle ASO + UX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve Daily Puzzle discoverability, retention loop quality, and App Store conversion positioning while adding a safe admin-control workflow for runtime toggles.

**Architecture:** Keep the backend generation pipeline unchanged, then strengthen user-facing experience in the iOS app (home card CTA, share loop, prompt timing, in-app entry points) and connect a developer-only admin client to the existing `updateDailyPuzzleAdminConfig` function. Pair this with ASO metadata + CPP documentation updates so store positioning matches shipped functionality.

**Tech Stack:** SwiftUI, UserDefaults/Keychain persistence, URLSession, Firebase Functions HTTPS endpoint, Fastlane metadata files, XCTest.

### Task 1: Tighten Daily Puzzle UX loop (discoverability + completion)

**Files:**
- Modify: `Shared/View/Navigation/HomeView.swift`
- Modify: `Shared/ViewModel/HomeViewModel.swift`
- Modify: `CronicaTests/SettingsStoreTests.swift`

**Step 1: Write failing tests**
- Add tests for:
  - Empty guess does not increment attempts.
  - Share text contains puzzle id + attempt count + clue and no title leak.
  - Card status text changes when solved.

**Step 2: Run tests to verify they fail**
- Run: `xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:CronicaTests/DailyPuzzleViewModelTests`
- Expected: one or more new tests fail.

**Step 3: Implement minimal code**
- Add guard for blank guesses.
- Add share-text formatter in `DailyPuzzleViewModel`.
- Improve puzzle card UI copy and CTA emphasis.
- Add `ShareLink` to solved state in puzzle sheet.

**Step 4: Run tests to verify pass**
- Re-run the same test target.

### Task 2: Add developer/admin toggle flow for backend runtime config

**Files:**
- Modify: `Shared/Configuration/Key.swift`
- Modify: `Shared/View/Settings/DeveloperView.swift`
- Modify: `CronicaTests/SettingsStoreTests.swift`
- (Optional helper in same file as existing small service types to avoid project-file churn)

**Step 1: Write failing tests**
- Add tests for `DailyPuzzleAdminConfigService`:
  - Missing API key rejects call.
  - Valid request uses `x-admin-key` header and JSON body.
  - Non-2xx status throws.

**Step 2: Verify RED**
- Run only new service tests and confirm fail.

**Step 3: Implement minimal code**
- Add admin endpoint key in `Key`.
- Add small service + request model.
- Add Developer Settings section:
  - API key input (not bundled in app)
  - Toggle `enabled`
  - Toggle `pushEnabled`
  - Save/apply button + result state

**Step 4: Verify GREEN**
- Run service tests.

### Task 3: Improve in-app settings discoverability (non-annoying path)

**Files:**
- Modify: `Shared/View/Settings/NotificationsSettingsView.swift`

**Step 1: Add UX affordances**
- Add short explanatory copy under Daily Puzzle reminders toggle.
- Add explicit “Play Daily Puzzle” action that returns user to Home if they came through settings.

**Step 2: Manual behavior check**
- Ensure toggling notifications updates topic subscription behavior unchanged.

### Task 4: ASO docs + metadata updates

**Files:**
- Modify: `fastlane/metadata/en-US/subtitle.txt`
- Modify: `fastlane/metadata/en-US/keywords.txt`
- Modify: `fastlane/metadata/en-US/promotional_text.txt`
- Modify: `fastlane/metadata/en-US/description.txt`
- Modify: `fastlane/metadata/en-US/release_notes.txt`
- Modify: `fastlane/CUSTOM_PRODUCT_PAGES.md`
- Create: `docs/plans/2026-02-15-daily-puzzle-aso-ux-rollout-notes.md`

**Step 1: Update text assets**
- Include Daily Puzzle + streak value prop in top lines.
- Keep keyword list <= 100 chars and aligned with CPP assignment.

**Step 2: Update CPP strategy**
- Add Daily Puzzle-focused CPP (or fold into Trending page with puzzle-first narrative).

**Step 3: Add rollout notes**
- Include event taxonomy, screenshot sequence recommendations, and 30-day experiment checklist.

### Task 5: Verification

**Files:**
- No code changes.

**Step 1: iOS targeted tests**
- Run:
  - `xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:CronicaTests/DailyPuzzleViewModelTests`
  - `xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:CronicaTests/DailyPuzzleServiceTests`
  - `xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:CronicaTests/DailyPuzzlePushTopicManagerTests`

**Step 2: Firebase functions checks**
- Run:
  - `cd functions && npm test`
  - `cd functions && npm run build`

**Step 3: Report residual gaps**
- Explicitly list what remains unimplemented or unverified.
