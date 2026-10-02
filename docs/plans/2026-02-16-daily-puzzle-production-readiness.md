# Daily Puzzle Production Readiness Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this gate task-by-task.

**Goal:** Ship Daily Puzzle with strict release gates, deterministic rollback, and low-risk validation paths.

**Architecture:** Use multi-layer gates: automated pre-release checks, backend emulator integration checks, targeted iOS suite checks, then manual device QA and controlled rollout. If any gate fails, do not ship. If post-release KPIs or errors regress, immediately disable generation/push via admin endpoint and redeploy last known-good backend revision.

**Tech Stack:** Firebase Functions v2, Firestore, FCM topic push, iOS SwiftUI app, Xcode test runner, Vitest, Firestore emulator.

## Release Gates (Go/No-Go)

### Automation Status
Implemented CI workflows:
1. `/Users/johndlugokecki/dev/Cronica/.github/workflows/daily-puzzle-backend-ci.yml`
2. `/Users/johndlugokecki/dev/Cronica/.github/workflows/daily-puzzle-ios-ci.yml`
3. `/Users/johndlugokecki/dev/Cronica/.github/workflows/daily-puzzle-deploy.yml`

Implemented executable local gate:
1. `/Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh`

The release-gate script now auto-detects an available iOS Simulator destination when `IOS_DESTINATION` is not provided.
It also runs endpoint smoke checks for `getLatestDailyPuzzle` schema sanity and conditionally runs `sendDailyPuzzleTestPush` when `DAILY_PUZZLE_ADMIN_KEY` is set.

### Gate 0: Configuration and Access (blocking)
1. Confirm secrets exist in backend runtime:
- `TMDB_API_KEY`
- `OPENAI_API_KEY`
- `DAILY_PUZZLE_ADMIN_KEY`
2. Confirm admin endpoints are reachable:
- `getLatestDailyPuzzle`
- `updateDailyPuzzleAdminConfig`
- `sendDailyPuzzleTestPush`
3. Confirm app endpoints point to intended environment in:
- `/Users/johndlugokecki/dev/Cronica/Shared/Configuration/Key.swift`

**No-go conditions**
- Missing secret, wrong endpoint, or unauthorized admin access.

### Gate 1: Automated Release Gate (blocking)
Run:

```bash
/Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh
```

This runs:
1. `functions` unit tests
2. `functions` build
3. Firestore emulator integration tests
4. iOS targeted Daily Puzzle suite

**No-go conditions**
- Any failing or skipped required test (other than expected non-emulator integration skip in default `npm test`).
- Any build failure.

### Gate 2: Manual Device QA Matrix (blocking for first launch)
Test on at least:
1. iOS latest major
2. iOS previous major
3. One low-memory/older device class

Test matrix:
1. New user, notifications `notDetermined`, first guess flow -> permission prompt shown only after first meaningful guess.
2. Existing user, notifications denied -> puzzle playable, no repeated permission nag.
3. Existing user, notifications authorized + reminders enabled -> receives test push and opens puzzle.
4. Home card discoverability -> opens puzzle, source tracked as `home_card`.
5. Notification settings shortcut -> opens Home->Puzzle flow, source tracked as `notification_settings`.
6. Push tap flow -> opens puzzle, source tracked as `push_notification`.
7. Solved flow -> share text contains puzzle ID/attempts/clue only (no title leak).
8. Wrong guess progression -> hint 1 unlock at attempt 2, hint 2 at attempt 4.
9. Admin config toggles -> backend accepts update; generation/push behavior follows config.
10. Admin test push button -> test push sent and received on opted-in device.

**No-go conditions**
- Any broken open path, prompt logic regression, hint progression bug, or share spoiler leak.

### Gate 3: Observability Baseline (blocking)
Before rollout, define dashboards/alerts for:
1. `daily_puzzle_opened`
2. `daily_puzzle_guess_submitted`
3. `daily_puzzle_solved`
4. `daily_puzzle_prompt_shown`
5. `daily_puzzle_prompt_response`
6. `daily_puzzle_reminders_toggle_changed`
7. Backend function error logs for generation/send push endpoints

**No-go conditions**
- No way to observe failures or engagement drop in first 24h.

## No-Touch Weekly Checklist (CI/Command-Driven)

1. Trigger backend checks (no manual local patching):

```bash
gh workflow run daily-puzzle-backend-ci.yml --ref main
```

2. Trigger protected deploy workflow (includes backend checks + functions-only deploy + post-deploy smoke):

```bash
gh workflow run daily-puzzle-deploy.yml --ref main \
  -f firebase_project_id=admob-app-id-9658087638 \
  -f functions_base_url=https://us-central1-admob-app-id-9658087638.cloudfunctions.net
```

3. Watch the deploy run to completion and require green status:

```bash
gh run watch --exit-status
```

4. Run command-only local verification when needed (CI-parity backend-only gate):

```bash
SKIP_IOS=1 /Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh
```

5. Run command-only local verification with admin smoke when key is available:

```bash
SKIP_IOS=1 DAILY_PUZZLE_ADMIN_KEY=... /Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh
```

6. Weekly check is complete only when:
- deploy workflow passes backend checks, deploy, and both post-deploy smoke calls.
- local release-gate command passes with no manual edits to scripts or configs.

## Rollout Strategy

1. Soft launch window: first 24 hours.
2. Keep admin toggles ready for immediate mitigation:
- `enabled=false`
- `pushEnabled=false`
3. Use admin test push after deploy as first smoke.
4. Review first-day KPI guardrails:
- Open rate
- Completion rate
- Prompt conversion
- Reminder disable rate

## Rollback and Mitigation Runbook

### Immediate blast-radius stop (<= 5 min)
Disable generation and push:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "x-admin-key: ${DAILY_PUZZLE_ADMIN_KEY}" \
  -d '{"enabled": false, "pushEnabled": false}' \
  "https://us-central1-admob-app-id-9658087638.cloudfunctions.net/updateDailyPuzzleAdminConfig"
```

### Validate stop action
1. Call admin endpoint again and verify `enabled=false`, `pushEnabled=false`.
2. Confirm no new scheduler writes for current day.
3. Confirm no new `daily-puzzle` push sends.

### Backend rollback
1. Identify last known-good backend commit SHA.
2. Redeploy Functions from that SHA.
3. Re-run:
- `npm test`
- `npm run build`
- `npm run test:firestore`
4. Re-enable toggles only after post-rollback smoke passes.

## Post-Deploy First-Hour Smoke Checklist

1. `getLatestDailyPuzzle` returns a valid schema document.
2. Admin test push endpoint returns `200` and device receives notification.
3. Tapping notification opens puzzle screen.
4. One guess event and one open event appear in telemetry.
5. No new backend errors in function logs.

## Required Evidence to Mark Release Green

Attach:
1. Output of `/Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh`.
2. Device QA matrix checklist with pass/fail notes.
3. Screenshot/log evidence of successful admin test push.
4. Confirmation of rollback command readiness and secret availability.

## Latest Execution Evidence

Executed on **February 15, 2026 (local machine time)**:

1. `/Users/johndlugokecki/dev/Cronica/scripts/daily-puzzle-release-gate.sh`
- Functions unit tests: `6` files passed, `1` integration file skipped in default run, `36` tests passed.
- Functions build: passed.
- Functions Firestore emulator integration: `2` tests passed.
- iOS Daily Puzzle targeted suite: `TEST SUCCEEDED` (includes admin test-push service tests).
- Final marker: `✅ Daily Puzzle release gate passed.`
