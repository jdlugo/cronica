# Daily puzzle reminder migration

## Production configuration
Firebase project: `admob-app-id-9658087638`.
Firestore `adminSettings/dailyPuzzle`: keep `enabled=true`, `pushEnabled=false`.
The generation and hourly recovery jobs must not send the old global broadcast.

Campaign `6912042139514438378` (Daily Puzzle — 6 PM device local time) was published on September 28, 2026. It starts September 29, repeats at 18:00 recipient time, limits sends to once per day, and expires undelivered messages after one hour. Payload: `type=daily_puzzle`.
On September 28 its targeting was changed and verified saved: app `com.dlugokecki.qscanlite` AND app version `<= 4.25.41`.
Do not remove that version condition: version 4.25.42 and later own delivery locally.

## Client 4.25.42 / build 14
- Unsubscribe from the old daily-puzzle topic, including token refresh.
- Replace legacy 20:00 fallback notifications with at most seven upcoming 18:00 device-local calendar reminders, replenished on launch, foreground and timezone changes.
- Both the global notification preference and Daily Puzzle preference must be enabled, with OS authorization.
- Turning either preference off removes pending puzzle reminders. Unrelated release reminders remain untouched.
- Solving or exhausting attempts on the daily puzzle suppresses the current local day's reminder. Practice/archive rounds do not suppress it.
- Serialize notification-center writes so completion/opt-out during a suspended add cannot resurrect a stale request.
- Foreground presentation suppresses remote puzzle broadcasts and checks local preference, completion and hour again.
- Notification taps retain the puzzle route and distinguish `local_reminder` from `push_notification` in analytics.

## Why local scheduling
The app can cancel a local request immediately when preferences or completion change. A Firebase console campaign cannot consult that local state. Topic unsubscribe alone does not exclude a device from a console campaign targeted by app. A server-owned alternative requires device registration, preference/completion sync, token cleanup and timezone-aware per-device dispatch.

## Limits and rollout
This needs an app update; it does not retrofit preference or completion handling into older installed builds. Older clients can still have their 20:00 fallback until updated. Campaign version classification can lag an upgrade, and an already queued remote notification may still be delivered during migration. iOS Focus/Scheduled Summary may delay presentation independently of scheduling. Seven-day local scheduling intentionally stops reminders to inactive installs until they next open the app.
The App Store submission 4.25.41/build 13 remains separate; do not silently replace its submitted build.

## Validation
`bash scripts/test_daily_puzzle_reminders.sh` exercises DST, local time, day boundary, completion, repeated refresh, legacy cleanup, opt-out and in-flight add races using the actual scheduling coordinator.
Targeted iOS tests cover view-model completion vs practice, legacy topic removal, foreground preference gates, and notification routing. Validate real device receipt separately after distributing 4.25.42.

Firebase documents app-version targeting in its [console messaging guide](https://firebase.google.com/docs/cloud-messaging/send/firebase-console). The live criteria were additionally reopened and verified after publishing.

Verified September 28: 33 targeted iOS tests passed with no failures or skips on iPhone 17 Pro / iOS 26.3.1. Result bundle: `/tmp/puzzle-reminder-tests-final.xcresult`. Standalone coordinator suite and `git diff --check` passed. No new app binary has been distributed.
