# Daily Reel Rollout Ledger

## Objective

Increase repeat puzzle sessions, social acquisition, and revenue per active user with a cohesive three-act daily movie challenge. Do not increase interstitial pressure while reach and repeat play remain the primary constraints.

## Primary hypothesis

`Decode -> Connect -> Arrange -> Challenge` creates a more satisfying run than one isolated emoji answer. The complete run should increase puzzle completion, rounds per session, next-day return, and challenge-driven starts without degrading crash-free use or existing Daily Puzzle engagement.

## Production guard

- PostHog flag: `daily-reel-rollout`
- PostHog flag ID: `853475`
- Variant: `reel`
- Current rollout: `0%`
- Evaluation: iOS, web, and server
- Production endpoint deployed: no
- Production content published: no
- Exposure allowed: no

## Instrumented funnel

1. `daily_reel_session_started`
2. `daily_reel_act_viewed`
3. `daily_reel_attempt_submitted`
4. `daily_reel_assist_requested`
5. `daily_reel_act_revealed`
6. `daily_reel_completed`
7. `daily_reel_challenge_created`
8. `daily_reel_challenge_claimed`
9. `daily_reel_challenge_creation_failed`

Never attach session capabilities, challenge capabilities, or challenge URLs to telemetry.

## Decision metrics

| Stage | Metric | Initial decision rule |
| --- | --- | --- |
| Exposure | Eligible users and sessions by surface and variant | Do not interpret rates without absolute counts |
| Activation | Session start / exposed user | Investigate entry clarity if below the existing Daily Puzzle open rate |
| Engagement | Acts completed and rounds per session | Keep if users commonly reach Act 2 and median depth improves |
| Completion | Completed run / session start | Change content difficulty if completion is below 45% after 100 starts |
| Stickiness | D1 and D7 return after a completed run | Expand only with a positive directional lift and adequate sample |
| Social | Challenge create / completion and claim / created challenge | Keep if users create links and at least 10% are claimed |
| Monetization | AdMob revenue / Daily Reel starter and active user | Never compensate for low volume with more interstitial pressure |
| Reliability | Crash-free sessions, server errors, App Check failures | Revert exposure on material reliability regression |

## Change log

### 2026-08-28: implementation checkpoint

- Added server-authoritative sessions, frozen PostHog assignment, request throttling, App Check validation, and 48-hour one-opponent challenges.
- Added native iOS transport, Keychain capability storage, three-act UI, guarded Home entry, deterministic debug preview, and challenge share sheet.
- Added dependency-free web PWA with the same state machine, challenge fragment consumption, immediate address-bar cleanup, and capability-safe telemetry.
- Created the production PostHog flag at `0%`; no user is exposed.
- Web tests: 9 passed.
- iOS app: simulator build and launch passed on iOS 26.3.
- Xcode focused test product compiled, but XcodeBuildMCP's test runner timed out before returning results; do not count the native tests as passed for this checkpoint.

### Visual evidence

- `.build/daily-reel-evidence/native-home.jpg`
- `.build/daily-reel-evidence/native-decode.png`
- `.build/daily-reel-evidence/native-connect.png`
- `.build/daily-reel-evidence/native-arrange.png`
- `.build/daily-reel-evidence/native-results.png`
- `.build/daily-reel-evidence/native-challenge-ready.png`
- `.build/daily-reel-web-results.png`
- `.build/daily-reel-web-mobile.png`

## Gates before first exposure

- Publish one approved Daily Reel and verify all supported locales.
- Configure Firebase App Check for the web client and enforce it for the production function.
- Set Functions secrets for the capability HMAC, PostHog project token, and real challenge share base URL.
- Deploy the Daily Reel API and run create, resume, mutate, challenge, and expired-link smoke checks against production.
- Resolve the native test-runner timeout and execute the focused suite.
- Confirm PostHog receives only sanitized events and AdMob remains unaffected.
- Start with an internal property-based cohort before changing the global rollout percentage.
## Cross-platform implementation checkpoint - 2026-08-28

- Web behavior: 11 automated tests passed, including challenge fragment consumption, capability redaction, and fail-closed Firebase App Check behavior.
- Native behavior: 13 focused tests passed on iPad Air 11-inch (M3), iOS 26.3.1, covering transport, state transitions, play interaction, and fail-closed rollout assignment.
- Native visual proof: Home entry, Decode, Connect, Arrange, Results, and challenge-link-ready states captured under `.build/daily-reel-evidence/`.
- Social loop: native challenge creation and web first-claim flow are implemented; share capabilities remain URL-fragment-only and are excluded from PostHog events.
- Exposure: PostHog flag `daily-reel-rollout` remains active at 0%; no production users are eligible.
- Remaining release gates: hosted share origin, reCAPTCHA Enterprise-backed Web App Check, production publication, Functions secrets, and guarded deployment.
## Guarded production-preparation checkpoint - 2026-08-28

- Candidate: `reel-6249b00b4cf58589262d0d14` for publication `2026-09-02`, content version `daily-reel-2026-09-02.1`; local state `awaitingApproval`, zero quality findings, not staged remotely.
- Content: easy Decode, easy Connect, medium Arrange; five localized public/private variants; current TMDb poster paths and factual snapshots for seven movies.
- Backend: daily availability window enforced; 05:07 UTC idempotent publisher plus hourly post-05:00 recovery wired; iOS and Web Firebase App IDs allowlisted.
- Backend proof: 157 tests passed across 26 files, 3 intentionally skipped; Functions TypeScript build passed.
- Web proof: 12 tests passed; explicit `?preview=1` is preview-only; default is fail-closed live mode; fresh service-worker install produced `daily-reel-shell-v2`; forced offline reload rendered the app shell.
- Native proof: 14 focused tests passed on iPad Air 11-inch (M3), iOS 26.3.1, including the shared 05:00 UTC publication boundary.
- Hosting: local target `daily-reel` is configured but deliberately has no remote site mapping.
- Exposure: PostHog flag `daily-reel-rollout` remains at 0%; no production users are eligible.
- Remaining gates: authenticate Google Cloud as `john@catapultlabs.net`; enable Hosting/reCAPTCHA Enterprise APIs; create and bind the dedicated site; create/register the Enterprise App Check key; set Functions secrets; stage/approve the candidate; deploy; smoke test; only then consider a small internal rollout.

## 2026-08-29 - Cloud foundation and protected prelaunch smoke

### Deployment state

- Firebase project: `admob-app-id-9658087638` under `john@catapultlabs.net`.
- Dedicated Hosting site: `https://streaming-now-daily-reel.web.app` linked to web app `1:315021799865:web:87aad9db62c09193a54668`.
- Firebase App Check: reCAPTCHA Enterprise configured for only the `.web.app` and `.firebaseapp.com` production domains.
- Gen 2 Node.js 22 functions deployed in `us-central1`: `dailyReelAPI`, `publishDailyReel`, and `ensureDailyReelPublished`.
- Existing Secret Manager values are preserved on repeat applies; no secret values are recorded here.
- Candidate `reel-6249b00b4cf58589262d0d14`, content version `daily-reel-2026-09-02.1`, was validated with zero findings and prepublished for `2026-09-02`.
- Public daily access remains blocked until `2026-09-02T05:00:00Z`.

### Rollout state

- PostHog flag `daily-reel-rollout` (`853475`) remains a `0%` catch-all for ordinary users.
- Flag version 2 adds one higher-priority internal condition for the `daily-reel-live-smoke-20260829` test installation only.
- The internal condition is applied to both the browser installation ID and the server's privacy-preserving HMAC identity.
- PostHog test evaluation: internal identity = `reel`, condition 0; control identity = `false`, condition 1.
- Decision: **HOLD** general exposure at 0% until a successful post-window end-to-end playthrough.

### Live evidence

- Hosting root returned `200` with title `Daily Reel | Streaming Now`.
- Versioned PWA manifest and icon returned `200`; a clean browser load produced zero console errors and zero warnings.
- A real browser obtained a reCAPTCHA Enterprise App Check token accepted by `dailyReelAPI`.
- Internal smoke identity reached Firestore content resolution and received `404 content.unavailable` with message `Published Reel is outside its daily window`, proving eligibility and the time gate both work.
- Live control identity received `403 experience.ineligible`, proving ordinary users remain excluded.

### Deployment hardening completed

- Pinned cloud automation to Firebase CLI `15.28.2` under Node.js 24 instead of the obsolete global Firebase CLI running Node.js 18.5.0.
- Made reCAPTCHA key lookup deterministic through JSON matching and added the Google user-project header to App Check registration.
- Corrected PWA manifest/icon paths and advanced the service-worker shell cache to `daily-reel-shell-v3` with a versioned manifest URL.

### Next checkpoint

- At or after `2026-09-02T05:00:00Z`, use only the internal smoke installation for one complete Decode -> Connect -> Arrange -> Final Cut -> share/challenge flow.
- Require successful session start, attempts, completion, PostHog event arrival, and no unexpected function errors before increasing rollout above 0%.

### Operational verification

- `firebase-schedule-publishDailyReel-us-central1`: enabled at `7 5 * * *` UTC.
- `firebase-schedule-ensureDailyReelPublished-us-central1`: enabled at minute `29` each hour.
- `dailyReelAPI` had zero error-severity Cloud Run logs from deployment through the prelaunch smoke requests.

## 2026-08-29 - Immediate public launch

### Launch decision

- User explicitly overrode the September 2 hold and approved launching immediately.
- The scheduled September 2 candidate remains unchanged.
- A distinct launch candidate was created for the current daily window: `reel-8e5b5325f4359fc84e53e0b3`, publication `2026-08-29`, content version `daily-reel-2026-08-29.1`.
- Availability window: `2026-08-29T05:00:00Z` through `2026-08-30T05:00:00Z`.
- Validation: passed with zero quality findings; staged, approved, and published by `john@catapultlabs.net` at `2026-08-29T11:05:54Z`.

### Release-gate evidence

- Internal protected session start returned `200` for the August 29 publication.
- Decode, Connect, and Arrange each returned `200`; the session completed at sequence 3 with score 300 and a completion timestamp.
- Completed-session resume returned `200`.
- Challenge creation returned `200` with an expiry, and first opponent claim returned `200`.
- Before public exposure, a control identity returned `403 experience.ineligible`.

### Public rollout

- PostHog flag `daily-reel-rollout` (`853475`) advanced from version 2 to version 3.
- The internal smoke condition remains first; the property-free catch-all condition changed from `0%` to `100%` with variant `reel`.
- Both a raw browser identity and the server's privacy-preserving HMAC identity evaluated enabled against condition 1.
- Public URL: `https://streaming-now-daily-reel.web.app/`.

### Launch defects found and corrected

- Root cause 1: browser-native `fetch` was stored unbound and invoked as an object method in both `PostHogBridge` and `LiveDailyReelClient`, causing an `Illegal invocation` and fail-closed rollout/API behavior.
- Fix 1: default fetch transports now call `globalThis.fetch(...)` through a wrapper while preserving dependency injection.
- Root cause 2: web telemetry sent `$distinct_id`; PostHog ingestion requires `properties.distinct_id`, producing HTTP `400`.
- Fix 2: corrected the capture property contract.
- Regression coverage: native-fetch receiver tests for PostHog and API transport plus an ingestion `distinct_id` contract test; complete web suite passed 15/15.
- Cache rollout: public entry advanced to `app.js?v=6`, corrected PostHog module to `v6`, and service-worker shell to `daily-reel-shell-v5`.

### Public launch proof and baseline

- Existing visitor: Decode visible; PostHog `/flags` `200`; protected session resume `200`; event ingestion `200`; zero console errors or warnings.
- Brand-new visitor: Decode visible; PostHog `/flags` `200`; protected session start `200`; event ingestion `200`; zero console errors or warnings.
- First stored PostHog launch baseline, last 30 minutes: `daily_reel_session_started` = 1 event / 1 user; `daily_reel_session_resumed` = 1 event / 1 user. Internal registration events are excluded from product interpretation.
- `dailyReelAPI` error-severity logs since publication: 0.

### Rollback and first decision checkpoint

- Immediate rollback: change only the property-free catch-all condition on flag `853475` from `100%` back to `0%`; retain the internal smoke condition and published content for diagnosis.
- Revert exposure on material App Check failures, API errors, crashes, capability leakage, or a broken start/completion path.
- Do not interpret engagement rates until absolute public counts are material; retain the existing 100-start completion checkpoint and 45% completion decision rule.
- Do not add interstitial pressure while reach and repeat play remain the primary constraints.
