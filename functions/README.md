# Cronica Firebase Functions

This module generates one daily movie puzzle and publishes it to Firestore.

## What it does

- Pulls movie candidates from TMDb discover endpoint.
- Filters for common/popular/topical movies (rejects obscure picks).
- Calls OpenAI to generate emoji clue + hints + accepted answers.
- Validates and normalizes puzzle schema.
- Stores puzzle under `dailyPuzzles/<YYYY-MM-DD>` and updates `dailyPuzzles/latest`.
- Serves latest puzzle via HTTPS function `getLatestDailyPuzzle`.
- Supports secure admin updates via HTTPS function `updateDailyPuzzleAdminConfig`.
- Supports secure manual push validation via HTTPS function `sendDailyPuzzleTestPush`.
- Sends FCM push to topic `daily-puzzle` using:
  - title: `Daily Puzzle 🎬`
  - body: `<emoji> + <emoji> + <emoji> = ______`
- Uses idempotent write semantics for scheduled generation:
  - skips generation if `dailyPuzzles/<YYYY-MM-DD>` already exists
  - uses create-only persistence so retries cannot overwrite existing daily puzzle docs
  - suppresses push send when persistence indicates the puzzle already exists

## Environment / secrets

- `TMDB_API_KEY`
- `OPENAI_API_KEY`
- `DAILY_PUZZLE_ADMIN_KEY` (required to call `updateDailyPuzzleAdminConfig`)

## Admin toggle (Firestore)

The scheduled function reads `adminSettings/dailyPuzzle`:

- `enabled` (boolean, default `true`): global generation on/off.
- `pushEnabled` (boolean, default `true`): send push on/off while still generating and storing puzzles.

## Admin update endpoint

- Function: `updateDailyPuzzleAdminConfig`
- Header: `x-admin-key: <DAILY_PUZZLE_ADMIN_KEY>`
- JSON body fields (at least one required):
  - `enabled` (boolean)
  - `pushEnabled` (boolean)

## Admin test-push endpoint

- Function: `sendDailyPuzzleTestPush`
- Header: `x-admin-key: <DAILY_PUZZLE_ADMIN_KEY>`
- Behavior:
  - loads `dailyPuzzles/latest`
  - formats push body from latest puzzle emoji clue
  - sends test push to topic `daily-puzzle` with notification title `Daily Puzzle 🎬 (Test)`
  - returns `404` if latest puzzle does not exist

## Run tests

```bash
cd functions
npm test
```

## Run Firestore integration tests (emulator)

```bash
cd functions
npm run test:firestore
```

This starts a local Firestore emulator, runs repository integration tests, then shuts the emulator down.

## CI automation

Daily Puzzle checks are automated in GitHub Actions:
- backend checks: `/.github/workflows/daily-puzzle-backend-ci.yml`
- iOS targeted checks: `/.github/workflows/daily-puzzle-ios-ci.yml`

## Dry run locally

```bash
cd functions
TMDB_API_KEY=... OPENAI_API_KEY=... npm run generate:dry -- --date 2026-02-15
```
