# Daily AI Emoji Puzzle + Streaks Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ship a 1-2 week MVP daily game where users solve one AI-generated emoji movie/TV puzzle per day, maintain a streak, and receive a daily reminder notification.

**Architecture:** Generate one puzzle per day server-side (GitHub Actions + OpenAI + TMDb), publish JSON to a static path in this repo, fetch puzzle from app, and track streak/progress locally on device. For MVP, use local reminder notifications (not APNs remote push) to keep scope low while still delivering “daily push” behavior.

**Tech Stack:** SwiftUI, Foundation, UserDefaults (`@AppStorage`), URLSession, XCTest, GitHub Actions, TypeScript/Node script, OpenAI API, TMDb API.

## Scope Lock (MVP)

- Include: daily emoji puzzle, two unlockable hints, guess validation, streaks, best streak, local notification reminder, share result text.
- Exclude: leaderboard, friends, anti-cheat, APNs server push, paid hint economy.
- Assumption: “Push notifications” in MVP means **local scheduled daily reminder**.
- Notification copy lock (MVP default):
  - Title: `Daily Puzzle 🎬`
  - Body pattern: `<emoji> + <emoji> + <emoji> = ______`
  - Example: `🚢 + 🧊 + ❤️ = ______`
  - No hints in push body for MVP.

## Data Contracts

### Puzzle JSON (published daily)

```json
{
  "date": "2026-02-15",
  "puzzle_id": "2026-02-15",
  "media_type": "movie",
  "tmdb_id": 597,
  "emoji_clue": "🚢🧊❤️",
  "hint_1": "Released in 1997",
  "hint_2": "Directed by James Cameron",
  "accepted_answers": ["titanic"],
  "source": "ai+tmdb",
  "generated_at": "2026-02-15T05:00:00Z"
}
```

### Local Progress State

```swift
struct DailyPuzzleProgress: Codable, Equatable {
    var puzzleID: String
    var solved: Bool
    var attempts: Int
    var unlockedHintCount: Int
    var solvedAt: Date?
}
```

---

### Task 1: Puzzle Domain + Streak Engine

**Files:**
- Create: `Shared/Model/DailyPuzzle.swift`
- Create: `Shared/Manager/DailyPuzzleStreakStore.swift`
- Create: `CronicaTests/DailyPuzzleStreakStoreTests.swift`

**Step 1: Write the failing tests**

```swift
func testSolveOnConsecutiveDayIncrementsStreak() {
    var store = DailyPuzzleStreakStore(storage: .inMemory)
    store.recordSolved(on: ISO8601DateFormatter().date(from: "2026-02-15T12:00:00Z")!)
    store.recordSolved(on: ISO8601DateFormatter().date(from: "2026-02-16T12:00:00Z")!)
    XCTAssertEqual(store.currentStreak, 2)
}

func testMissingDayResetsStreakToOne() {
    var store = DailyPuzzleStreakStore(storage: .inMemory)
    store.recordSolved(on: ISO8601DateFormatter().date(from: "2026-02-15T12:00:00Z")!)
    store.recordSolved(on: ISO8601DateFormatter().date(from: "2026-02-18T12:00:00Z")!)
    XCTAssertEqual(store.currentStreak, 1)
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CronicaTests/DailyPuzzleStreakStoreTests
```

Expected: FAIL with missing type `DailyPuzzleStreakStore`.

**Step 3: Write minimal implementation**

```swift
final class DailyPuzzleStreakStore {
    @AppStorage("dailyPuzzleCurrentStreak") private(set) var currentStreak = 0
    @AppStorage("dailyPuzzleBestStreak") private(set) var bestStreak = 0
    @AppStorage("dailyPuzzleLastSolvedDate") private var lastSolvedISO = ""

    func recordSolved(on date: Date) { /* consecutive-day logic */ }
}
```

**Step 4: Run test to verify it passes**

Run same command as Step 2.
Expected: PASS.

**Step 5: Commit**

```bash
git add Shared/Model/DailyPuzzle.swift Shared/Manager/DailyPuzzleStreakStore.swift CronicaTests/DailyPuzzleStreakStoreTests.swift
git commit -m "feat: add daily puzzle domain and streak engine"
```

---

### Task 2: Puzzle Fetch + Cache + Answer Validation

**Files:**
- Create: `Shared/Manager/DailyPuzzleService.swift`
- Create: `Shared/Manager/DailyPuzzleCache.swift`
- Create: `CronicaTests/DailyPuzzleServiceTests.swift`
- Modify: `Shared/Network/NetworkError.swift`

**Step 1: Write the failing tests**

```swift
func testDecodePublishedPuzzleJSON() throws {
    let data = fixture("daily_puzzle_valid")
    let puzzle = try JSONDecoder().decode(DailyPuzzle.self, from: data)
    XCTAssertEqual(puzzle.puzzleID, "2026-02-15")
}

func testAnswerNormalizationAcceptsCaseAndWhitespaceDifferences() {
    XCTAssertTrue(DailyPuzzleAnswerValidator.matches(input: "  TITANIC ", acceptedAnswers: ["titanic"]))
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CronicaTests/DailyPuzzleServiceTests
```

Expected: FAIL with missing service/validator.

**Step 3: Write minimal implementation**

```swift
struct DailyPuzzleService {
    let session: URLSession = .shared
    func fetchPuzzle(for date: Date) async throws -> DailyPuzzle { /* GET static JSON URL */ }
}

enum DailyPuzzleAnswerValidator {
    static func matches(input: String, acceptedAnswers: [String]) -> Bool {
        normalize(input).map { acceptedAnswers.contains($0) }
    }
}
```

**Step 4: Run test to verify it passes**

Run same command as Step 2.
Expected: PASS.

**Step 5: Commit**

```bash
git add Shared/Manager/DailyPuzzleService.swift Shared/Manager/DailyPuzzleCache.swift Shared/Network/NetworkError.swift CronicaTests/DailyPuzzleServiceTests.swift
git commit -m "feat: add daily puzzle fetch, cache, and validation"
```

---

### Task 3: Game UI + Solve Flow

**Files:**
- Create: `Shared/View/Game/DailyPuzzleView.swift`
- Create: `Shared/View/Game/DailyPuzzleCard.swift`
- Create: `Shared/View/Game/DailyPuzzleResultShare.swift`
- Create: `CronicaTests/DailyPuzzleViewModelTests.swift`
- Modify: `Shared/View/Navigation/HomeView.swift`

**Step 1: Write the failing tests**

```swift
func testWrongGuessIncrementsAttemptsAndUnlocksHintAfterTwoAttempts() async {
    let vm = DailyPuzzleViewModel(puzzle: .fixture)
    vm.submitGuess("Avatar")
    vm.submitGuess("Up")
    XCTAssertEqual(vm.attempts, 2)
    XCTAssertEqual(vm.unlockedHintCount, 1)
}

func testCorrectGuessMarksSolvedAndStoresProgress() async {
    let vm = DailyPuzzleViewModel(puzzle: .fixture)
    vm.submitGuess("Titanic")
    XCTAssertTrue(vm.isSolved)
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CronicaTests/DailyPuzzleViewModelTests
```

Expected: FAIL with missing `DailyPuzzleViewModel`.

**Step 3: Write minimal implementation**

```swift
@MainActor
@Observable
final class DailyPuzzleViewModel {
    var puzzle: DailyPuzzle
    var attempts = 0
    var unlockedHintCount = 0
    var isSolved = false

    func submitGuess(_ raw: String) { /* validate + update progress */ }
}
```

Add to `HomeView` a card that opens `DailyPuzzleView`.

**Step 4: Run test to verify it passes**

Run same command as Step 2.
Expected: PASS.

**Step 5: Commit**

```bash
git add Shared/View/Game/DailyPuzzleView.swift Shared/View/Game/DailyPuzzleCard.swift Shared/View/Game/DailyPuzzleResultShare.swift Shared/View/Navigation/HomeView.swift CronicaTests/DailyPuzzleViewModelTests.swift
git commit -m "feat: add daily puzzle UI and solve flow"
```

---

### Task 4: Reminder Notification (MVP Push)

**Files:**
- Modify: `Shared/Store/SettingsStore.swift`
- Modify: `Shared/View/Settings/NotificationsSettingsView.swift`
- Modify: `Shared/Manager/NotificationManager.swift`
- Create: `CronicaTests/DailyPuzzleReminderSchedulerTests.swift`

**Step 1: Write the failing tests**

```swift
func testDefaultReminderTimeIsEightPM() {
    let schedule = DailyPuzzleReminderSchedule.default
    XCTAssertEqual(schedule.hour, 20)
    XCTAssertEqual(schedule.minute, 0)
}

func testReminderCanBeDisabled() {
    var schedule = DailyPuzzleReminderSchedule.default
    schedule.isEnabled = false
    XCTAssertFalse(schedule.isEnabled)
}
```

**Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CronicaTests/DailyPuzzleReminderSchedulerTests
```

Expected: FAIL due to missing schedule type.

**Step 3: Write minimal implementation**

```swift
@AppStorage("dailyPuzzleReminderEnabled") var dailyPuzzleReminderEnabled = true
@AppStorage("dailyPuzzleReminderHour") var dailyPuzzleReminderHour = 20
@AppStorage("dailyPuzzleReminderMinute") var dailyPuzzleReminderMinute = 0
```

Add `NotificationManager.scheduleDailyPuzzleReminderIfNeeded()` to register a repeating calendar notification.

**Step 4: Run test to verify it passes**

Run same command as Step 2.
Expected: PASS.

**Step 5: Commit**

```bash
git add Shared/Store/SettingsStore.swift Shared/View/Settings/NotificationsSettingsView.swift Shared/Manager/NotificationManager.swift CronicaTests/DailyPuzzleReminderSchedulerTests.swift
git commit -m "feat: add daily puzzle reminder settings and scheduler"
```

---

### Task 5: Daily AI Generator + Publish Pipeline

**Files:**
- Create: `scripts/daily-puzzle/package.json`
- Create: `scripts/daily-puzzle/tsconfig.json`
- Create: `scripts/daily-puzzle/src/generatePuzzle.ts`
- Create: `scripts/daily-puzzle/src/validatePuzzle.ts`
- Create: `.github/workflows/daily-puzzle.yml`
- Create: `daily-puzzles/YYYY-MM-DD.json` (initial seed file)
- Create: `daily-puzzles/latest.json` (latest pointer)
- Create: `scripts/daily-puzzle/README.md`

**Step 1: Write the failing tests (Node side)**

```ts
it("normalizes ai output into required puzzle schema", async () => {
  const raw = { emoji_clue: "🚢🧊❤️", hint_1: "Released in 1997" }
  const normalized = normalizePuzzle(raw)
  expect(normalized.puzzle_id).toBeDefined()
})
```

**Step 2: Run test to verify it fails**

Run:
```bash
cd scripts/daily-puzzle
npm test
```

Expected: FAIL with missing normalizer.

**Step 3: Write minimal implementation**

```ts
const prompt = `Return strict JSON with fields: emoji_clue, hint_1, hint_2, accepted_answers...`;
// 1) choose TMDb title
// 2) call OpenAI for clue/hints
// 3) validate schema
// 4) write daily-puzzles/<date>.json + latest.json
```

Workflow schedule:
- `cron: "5 5 * * *"` (runs daily)
- uses repo secrets: `OPENAI_API_KEY`, `TMDB_API_KEY`

**Step 4: Run test to verify it passes**

Run:
```bash
cd scripts/daily-puzzle
npm test
npm run generate -- --date 2026-02-15 --dry-run
```

Expected: PASS + valid JSON printed.

**Step 5: Commit**

```bash
git add scripts/daily-puzzle .github/workflows/daily-puzzle.yml daily-puzzles
git commit -m "feat: add daily ai puzzle generation pipeline"
```

---

### Task 6: End-to-End Wiring + QA + Release Guardrails

**Files:**
- Modify: `Shared/View/Changelog/ChangelogView.swift`
- Modify: `README.md`
- Create: `docs/daily-puzzle-ops.md`
- Modify: `fastlane/README.md`

**Step 1: Write the failing tests/checks**

- Add smoke test case in `CronicaTests/CronicaTests.swift` that decodes `daily-puzzles/latest.json` fixture and asserts required fields.

**Step 2: Run checks to show failure**

Run:
```bash
xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CronicaTests/CronicaTests
```

Expected: FAIL before fixture or decode path exists.

**Step 3: Implement minimal QA and docs wiring**

- Add release checklist in `docs/daily-puzzle-ops.md`:
  - Verify latest puzzle exists.
  - Verify clue is non-spoiler.
  - Verify hint quality.
  - Verify local reminder toggle/time works.

**Step 4: Run full verification**

Run:
```bash
xcodebuild test -project Story.xcodeproj -scheme "Story (iOS)" -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: PASS.

Manual verification (iOS):
- Open Home, enter Daily Puzzle, submit wrong + right guesses.
- Kill/relaunch app; progress persists.
- Toggle reminder off/on in Settings and verify notification exists.

**Step 5: Commit**

```bash
git add Shared/View/Changelog/ChangelogView.swift README.md fastlane/README.md docs/daily-puzzle-ops.md CronicaTests/CronicaTests.swift
git commit -m "docs: add daily puzzle launch checklist and app docs"
```

---

## Phase 2 (Post-MVP)

- Add remote APNs push from backend when new puzzle publishes.
- Add opt-in leaderboard (requires account identity + anti-cheat policy).
- Add streak freeze token + rewarded hint economy.

## Risks + Mitigations

- AI clue quality inconsistency: enforce schema + content lint + fallback regeneration in script.
- Spoiler clues: add banned phrase checks in `validatePuzzle.ts`.
- Cheating via static JSON: accepted for MVP; solve with signed API responses in phase 2.
- Notification fatigue: default 20:00 local; add quick disable toggle.

## Verification Checklist

- Unit tests pass for streak, answer validation, and reminder schedule.
- Daily generator produces valid JSON for a dry-run date.
- App handles missing puzzle gracefully (offline/error card + retry).
- Reminder scheduling behavior confirmed on physical device.

## Skills to Use During Implementation

- `@superpowers:test-driven-development`
- `@superpowers:testing-anti-patterns`
- `@superpowers:verification-before-completion`
- `@superpowers:requesting-code-review`
