# Daily Puzzle Universal Push Workflow

This runbook is for sending a one-time universal Firebase push campaign to all eligible users of the iOS app.

## Defaults

- Project: `admob-app-id-9658087638`
- App bundle: `com.dlugokecki.qscanlite`
- Notification title: `Daily Puzzle 🎬`
- Push body format: `<emoji> + <emoji> + <emoji> = ______`
- Additional options:
  - Sound: `Enabled`
  - Apple badge: `1`
- Custom data:
  - `type=daily_puzzle`
  - `puzzle_id=<YYYY-MM-DD>`
  - `puzzle_date=<YYYY-MM-DD>`

## Step 1: Generate campaign values

From repo root:

```bash
./scripts/prepare_universal_daily_puzzle_push.sh
```

Optional:

```bash
# prepare a specific date
./scripts/prepare_universal_daily_puzzle_push.sh 2026-02-27

# also open Firebase compose screen in browser (macOS)
OPEN_CONSOLE=1 ./scripts/prepare_universal_daily_puzzle_push.sh
```

The script prints copy/paste values for title, body, name, and custom data.

## Step 2: Create campaign in Firebase Console

1. Open [Messaging compose](https://console.firebase.google.com/project/admob-app-id-9658087638/notification/compose).
2. Fill Notification title/text/name using script output.
3. In Target:
   - choose `User segment`
   - choose app `com.dlugokecki.qscanlite`
   - do not add extra filters
4. In Scheduling:
   - choose `Send now`
5. In Additional options:
   - set `Sound` to `Enabled`
   - set `Apple badge` to `1`
6. In Custom data:
   - `type=daily_puzzle`
   - `puzzle_id=<value from script>`
   - `puzzle_date=<value from script>`
7. Click `Review` and then `Publish`/`Start campaign`.

## Step 3: Verify immediately

In Messaging -> Campaigns table:

- the new row should show `Active` (then `Completed` after send finishes)
- target should be Apple iOS app users
- campaign content should match the script output

## Stop / rollback

If needed, open campaign actions and click `Stop campaign`.
