# Daily Puzzle Hands-Off Automation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Daily Puzzle run with near-zero daily operator effort while improving retention through automated quality control, resilience, and nudging.

**Architecture:** Keep the existing TMDb -> OpenAI -> Firestore -> FCM pipeline, then wrap it in three automation layers: (1) pre-publish quality gate with retry, (2) self-healing scheduler that backfills missed days, and (3) app-side fallback nudges + milestone loops that run automatically from persisted puzzle progress. Admin endpoints remain manual kill switches.

**Tech Stack:** Firebase Functions v2, Firestore, FCM topic notifications, TypeScript, Vitest, SwiftUI, UserDefaults-backed stores, XCTest.

### Task 1: Add Server-Side Puzzle Quality Gate + Retry

**Files:**
- Create: `functions/src/puzzleQuality.ts`
- Test: `functions/src/__tests__/puzzleQuality.test.ts`
- Modify: `functions/src/generator.ts`
- Modify: `functions/src/__tests__/generator.test.ts`

**Step 1: Write failing tests for quality rules**

Add tests in `functions/src/__tests__/puzzleQuality.test.ts` for:
1. Accept puzzle when `emoji_clue` has 3-5 grapheme clusters and hints do not leak title words.
2. Reject when `hint_1` or `hint_2` contains normalized title token (`Titanic` in any case/punctuation variant).
3. Reject when emoji clue has fewer than 3 or more than 5 symbols.
4. Reject when `accepted_answers` does not include the normalized canonical title.

Example test scaffold:

```ts
it("rejects hint title leak", () => {
  expect(() =>
    assertPuzzleQuality({
      title: "Titanic",
      emojiClue: "🚢🧊❤️",
      hint1: "Rose falls in love on Titanic",
      hint2: "Released in 1997",
      acceptedAnswers: ["titanic"]
    })
  ).toThrow(/hint contains title/i);
});
```

**Step 2: Run tests and confirm RED**

Run:

```bash
cd /Users/johndlugokecki/dev/Cronica/functions && npm test -- src/__tests__/puzzleQuality.test.ts
```

Expected: FAIL (missing `assertPuzzleQuality`).

**Step 3: Implement minimal quality module**

Create `functions/src/puzzleQuality.ts` with:
1. `countGraphemes(value: string): number` using `Intl.Segmenter`.
2. `normalizeTitleTokens(title: string): string[]` removing punctuation and short stop words.
3. `assertPuzzleQuality(input)` that throws explicit errors for rule violations.

Example shape:

```ts
export function assertPuzzleQuality(input: {
  title: string;
  emojiClue: string;
  hint1: string;
  hint2: string;
  acceptedAnswers: string[];
}): void {
  // throw on invalid quality state
}
```

**Step 4: Integrate retry into generator**

In `functions/src/generator.ts`:
1. Add `maxAiAttempts` option defaulting to `3`.
2. Wrap AI generation in loop.
3. For each attempt: normalize payload, merge canonical title answer, run `assertPuzzleQuality`.
4. Return first valid document; if all attempts fail, throw a single aggregated error.

Pseudo-code:

```ts
let lastError: unknown;
for (let attempt = 1; attempt <= maxAiAttempts; attempt += 1) {
  try {
    // existing generate + normalize
    assertPuzzleQuality(...);
    return validateDailyPuzzleDocument(document);
  } catch (error) {
    lastError = error;
  }
}
throw new Error(`Failed to generate a quality puzzle after ${maxAiAttempts} attempts: ${String(lastError)}`);
```

**Step 5: Expand generator tests**

Add tests in `functions/src/__tests__/generator.test.ts`:
1. Retries after first invalid AI payload and succeeds on second payload.
2. Throws after all attempts invalid.

**Step 6: Verify GREEN**

Run:

```bash
cd /Users/johndlugokecki/dev/Cronica/functions && npm test -- src/__tests__/puzzleQuality.test.ts src/__tests__/generator.test.ts
```

Expected: PASS.

**Step 7: Commit**

```bash
git add \
  /Users/johndlugokecki/dev/Cronica/functions/src/puzzleQuality.ts \
  /Users/johndlugokecki/dev/Cronica/functions/src/generator.ts \
  /Users/johndlugokecki/dev/Cronica/functions/src/__tests__/puzzleQuality.test.ts \
  /Users/johndlugokecki/dev/Cronica/functions/src/__tests__/generator.test.ts

git commit -m "feat: add daily puzzle quality gate and retry loop"
```

### Task 2: Add Self-Healing Scheduler (Backfill Missing Day Automatically)

**Files:**
- Create: `functions/src/pipeline.ts`
- Test: `functions/src/__tests__/pipeline.test.ts`
- Modify: `functions/src/index.ts`
- Modify: `functions/src/__tests__/handlers.test.ts`

**Step 1: Write failing tests for pipeline runner**

In `functions/src/__tests__/pipeline.test.ts`, add tests for a new helper `runDailyPuzzlePipeline`:
1. Returns `{ generated: false, reason: "exists" }` when target date already exists.
2. Returns `{ generated: true, pushSent: true }` when generated + push allowed.
3. Returns `{ generated: true, pushSent: false }` when push disabled.

**Step 2: Run test and confirm RED**

```bash
cd /Users/johndlugokecki/dev/Cronica/functions && npm test -- src/__tests__/pipeline.test.ts
```

Expected: FAIL (missing module/function).

**Step 3: Implement shared pipeline helper**

Create `functions/src/pipeline.ts` to centralize dependencies currently duplicated in `index.ts` schedule handler. Keep it pure and dependency-injected so tests are cheap.

Signature example:

```ts
export async function runDailyPuzzlePipeline(input: {
  targetDate: Date;
  loadAdminConfig: () => Promise<DailyPuzzleAdminConfig>;
  loadExistingPuzzle: (targetDate: Date) => Promise<unknown | null>;
  generatePuzzle: (targetDate: Date) => Promise<DailyPuzzleDocument>;
  persistPuzzle: (puzzle: DailyPuzzleDocument) => Promise<boolean | void>;
  sendPush: (puzzle: DailyPuzzleDocument, pushBody: string) => Promise<void>;
  formatPushBody: (emojiClue: string) => string;
  logger: LoggerLike;
}): Promise<{ generated: boolean; pushSent: boolean }>;
```

Internally reuse `runGenerateDailyPuzzleTask`.

**Step 4: Add hourly repair scheduler**

In `functions/src/index.ts`:
1. Keep existing `generateDailyPuzzle` schedule (`5 5 * * *`).
2. Add `ensureDailyPuzzleCoverage` schedule (`17 * * * *`, UTC).
3. `ensureDailyPuzzleCoverage` runs the same pipeline for current UTC date; idempotency already prevents duplicates.

Example:

```ts
export const ensureDailyPuzzleCoverage = onSchedule(
  { schedule: "17 * * * *", timeZone: "Etc/UTC", secrets: [tmdbApiKeySecret, openAiApiKeySecret] },
  async () => {
    await runDailyPuzzlePipeline({ ...deps, targetDate: new Date() });
  }
);
```

**Step 5: Verify GREEN**

```bash
cd /Users/johndlugokecki/dev/Cronica/functions && npm test -- src/__tests__/pipeline.test.ts src/__tests__/handlers.test.ts
```

Expected: PASS.

**Step 6: Commit**

```bash
git add \
  /Users/johndlugokecki/dev/Cronica/functions/src/pipeline.ts \
  /Users/johndlugokecki/dev/Cronica/functions/src/index.ts \
  /Users/johndlugokecki/dev/Cronica/functions/src/__tests__/pipeline.test.ts \
  /Users/johndlugokecki/dev/Cronica/functions/src/__tests__/handlers.test.ts

git commit -m "feat: add self-healing daily puzzle scheduler"
```

### Task 3: Add App-Side Fallback Reminder + Streak Milestone Automation

**Files:**
- Modify: `Shared/Manager/NotificationManager.swift`
- Modify: `Shared/ViewModel/HomeViewModel.swift`
- Modify: `Shared/View/Navigation/HomeView.swift`
- Modify: `Shared/Store/SettingsStore.swift`
- Modify: `CronicaTests/SettingsStoreTests.swift`

**Step 1: Write failing tests**

Add tests in `CronicaTests/SettingsStoreTests.swift` for a new reminder rule:
1. If puzzle is opened but unsolved, schedule one local reminder later that day.
2. If puzzle is solved, cancel pending local daily-puzzle fallback reminder.
3. Never schedule fallback when notification auth is denied.
4. Card status copy shows milestone labels at streak 3/7/14 (e.g., `Streak 7 - Weekly Heat`).

**Step 2: Run test and confirm RED**

```bash
xcodebuild test -project /Users/johndlugokecki/dev/Cronica/Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:CronicaTests/DailyPuzzleViewModelTests
```

Expected: FAIL with missing fallback reminder APIs.

**Step 3: Implement fallback notification helpers**

In `NotificationManager` add:
1. `scheduleDailyPuzzleFallbackReminderIfNeeded(for puzzleID: String, at hour: Int = 20)`.
2. `cancelDailyPuzzleFallbackReminder(for puzzleID: String)`.
3. Use unique identifier like `daily-puzzle-fallback-<puzzleID>`.

In `DailyPuzzleViewModel`:
1. On first unsolved guess, call schedule helper (guard once per puzzle ID).
2. On solve, cancel fallback reminder.
3. Add streak milestone label mapping and expose on card status:
   - `3`: `Warm Streak`
   - `7`: `Weekly Heat`
   - `14`: `Two-Week Run`
   - `30`: `Legend Run`

**Step 4: Verify GREEN**

Run:

```bash
xcodebuild test -project /Users/johndlugokecki/dev/Cronica/Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:CronicaTests/DailyPuzzleViewModelTests \
  -only-testing:CronicaTests/DailyPuzzlePushTopicManagerTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add \
  /Users/johndlugokecki/dev/Cronica/Shared/Manager/NotificationManager.swift \
  /Users/johndlugokecki/dev/Cronica/Shared/ViewModel/HomeViewModel.swift \
  /Users/johndlugokecki/dev/Cronica/Shared/Store/SettingsStore.swift \
  /Users/johndlugokecki/dev/Cronica/CronicaTests/SettingsStoreTests.swift

git commit -m "feat: add automated daily puzzle fallback reminder"
```

### Task 4: Automate Deployment Safety and Ongoing Health Checks

**Files:**
- Create: `.github/workflows/daily-puzzle-deploy.yml`
- Modify: `.github/workflows/daily-puzzle-backend-ci.yml`
- Modify: `/Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh`
- Modify: `/Users/johndlugokecki/dev/Cronica/docs/plans/2026-02-16-daily-puzzle-production-readiness.md`

**Step 1: Add deploy workflow (manual + protected)**

`daily-puzzle-deploy.yml` should:
1. Trigger on `workflow_dispatch`.
2. Run backend CI job first.
3. Deploy only functions scope after tests pass.
4. Call `sendDailyPuzzleTestPush` endpoint post-deploy as smoke.

**Step 2: Add explicit smoke checks in release script**

Extend script to optionally call:
1. `getLatestDailyPuzzle` schema sanity check.
2. `sendDailyPuzzleTestPush` when `DAILY_PUZZLE_ADMIN_KEY` is set.

**Step 3: Update runbook**

Add a “No-touch weekly checklist” where checks are command-driven and can be run by CI, not manual ad-hoc operation.

**Step 4: Verify workflow syntax**

```bash
rg -n "daily-puzzle-deploy|workflow_dispatch|firebase deploy" /Users/johndlugokecki/dev/Cronica/.github/workflows -S
```

Expected: deploy workflow includes gated test + deploy steps.

**Step 5: Commit**

```bash
git add \
  /Users/johndlugokecki/dev/Cronica/.github/workflows/daily-puzzle-deploy.yml \
  /Users/johndlugokecki/dev/Cronica/.github/workflows/daily-puzzle-backend-ci.yml \
  /Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh \
  /Users/johndlugokecki/dev/Cronica/docs/plans/2026-02-16-daily-puzzle-production-readiness.md

git commit -m "chore: automate daily puzzle deploy and smoke checks"
```

### Task 5: Full Verification Gate

**Files:**
- No code changes.

**Step 1: Functions verification**

```bash
cd /Users/johndlugokecki/dev/Cronica/functions && npm test
cd /Users/johndlugokecki/dev/Cronica/functions && npm run build
cd /Users/johndlugokecki/dev/Cronica/functions && npm run test:firestore
```

Expected: all pass.

**Step 2: iOS targeted verification**

```bash
xcodebuild test -project /Users/johndlugokecki/dev/Cronica/Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing:CronicaTests/DailyPuzzleViewModelTests \
  -only-testing:CronicaTests/DailyPuzzleServiceTests \
  -only-testing:CronicaTests/DailyPuzzlePushTopicManagerTests \
  -only-testing:CronicaTests/DailyPuzzleLaunchIntentStoreTests \
  -only-testing:CronicaTests/DailyPuzzleAdminConfigServiceTests
```

Expected: `TEST SUCCEEDED`.

**Step 3: Local release gate**

```bash
/Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh
```

Expected: `✅ Daily Puzzle release gate passed.`

**Step 4: Production smoke (post-deploy)**

1. `getLatestDailyPuzzle` returns current day document.
2. `sendDailyPuzzleTestPush` returns `200`.
3. Push tap opens Home -> Daily Puzzle and tracks `daily_puzzle_open_requested` with source `push_notification`.

**Step 5: Capture evidence**

Update `/Users/johndlugokecki/dev/Cronica/docs/plans/2026-02-16-daily-puzzle-production-readiness.md` with:
1. Date/time of gate run.
2. Key command output summary.
3. Any mitigations used.

## Acceptance Criteria

1. Daily puzzle still publishes at scheduled time.
2. If scheduled run misses or fails, hourly self-healing run backfills automatically.
3. Low-quality AI output is automatically retried/rejected before publish.
4. Users who engage but do not solve receive one non-spammy same-day fallback reminder.
5. End-to-end test/deploy/smoke path is executable from CI without manual patching.
