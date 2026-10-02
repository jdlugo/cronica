# Marketing Iterations

This ledger keeps storefront changes tied to a hypothesis, measurable outcomes, and an explicit publish decision.

## Position

Cronica is the daily movie game that turns a solved clue into a useful movie-night decision:

1. Play a new emoji movie puzzle.
2. Find where the answer streams locally.
3. Save it now and watch it later.

## Iterations

| ID | State | Change | Hypothesis | Primary KPI | Guardrails |
|---|---|---|---|---|---|
| MKT-INTL-001 | Control prepared in App Store Connect | Feature-led Daily Puzzle and Movie Tracker pages | Localized pages should outperform the generic default page | Product-page conversion by page and territory | D1 retention, puzzle guess-start rate, revenue per DAU |
| MKT-INTL-002 | Local package ready for validation | Outcome-led Play -> Find -> Save headlines, tighter promotional text, and fully localized watchlist proof | A coherent three-frame story will increase qualified downloads without reducing downstream engagement | Relative product-page conversion lift versus the pre-publish territory baseline | D1 retention no worse than -10% relative; puzzle guess-start and ad revenue per activated user do not decline |

## MKT-INTL-002 Checkpoints

| Checkpoint | Evidence | Decision |
|---|---|---|
| Pre-publish | Five locales, two device classes, three acquisition frames, no alpha, valid dimensions, copy <= 170 characters | Replace the unsubmitted draft only after the package passes |
| Day 3 | Impressions, page views, first-time downloads, conversion, PostHog activation, AdMob revenue | Directional only; do not reverse on small samples |
| Day 7 | Same funnel by France, Spain, Mexico, and Brazil | Evaluate when a page has at least 100 views and 20 downloads; otherwise extend to Day 14 |
| Day 14 | Conversion and downstream quality versus the territory baseline | Keep when conversion improves and guardrails hold; revise the weakest frame otherwise |
| Day 28 | Revenue per territory and retained-user quality | Promote the winning message to the default page or create the next iteration |

## Attribution Limits

This is a sequential pre/post rollout, not a randomized A/B test. Compare equivalent weekdays, app versions, territories, and acquisition sources. Treat low-volume movement as directional until sample thresholds are met.

## Publish Gate

The V2 package may update editable custom-product-page drafts after local validation. It must not submit pages for review, attach the unshipped Daily Puzzle deep link, or modify the pending app-version submission without a separate release decision.

## Execution checkpoint: 2026-08-28

Iteration: `MKT-INTL-002`

Position: `Play -> Find -> Save`

State: The two App Store Connect custom product-page drafts are fully updated but have not been submitted for review.

- Daily Puzzle page: https://apps.apple.com/us/app/streaming-now-tv-movies/id455556959?ppid=76c15a6b-c125-4166-8436-947f7d2ec893
- Movie Tracker page: https://apps.apple.com/us/app/streaming-now-tv-movies/id455556959?ppid=fdfcdda2-b6a9-49b5-8e42-938423fa3548
- Localizations: `en-US`, `fr-FR`, `es-ES`, `es-MX`, `pt-BR`
- Screenshot sets: 20 total, with exactly 3 screenshots per page, locale, and device class
- Screenshot assets: 60 complete, 0 pending uploads, 0 stale assets
- Promotional text: all 10 page-localization combinations match `manifest-v2.json`
- English search intent: `daily puzzle`, `emoji game`, `movie tracker`, `where to watch`, and `watchlist` assigned
- International tracker intent: existing locale-specific tracker keywords retained
- International puzzle intent: 12 requested terms deferred until those terms enter Apple's approved app keyword pool through the next app-version metadata

Validation evidence:

- Marketing snapshot suite: 4 tests, 30 screenshots, 0 failures
- Corrected localization snapshot suite: 2 tests, 20 screenshots, 0 failures
- App Store asset validation: 30 iPhone RGB images at 1320x2868 and 30 iPad RGB images at 2064x2752
- Custom-page sync tests: 18 passed
- Post-apply App Store reconciliation: 60 skipped by exact file hash, 0 uploads, 0 stale files, final count 3 in every set

Measurement boundary:

- Start acquisition measurement only after the custom pages are approved and visible.
- Treat results before five first-time downloads per page as insufficient for Apple's page-level analytics.
- Review implementation health at day 3, directional acquisition at day 7, activation and revenue quality at day 14, and keep/change/expand decisions at day 28.
- Do not raise interstitial pressure while request and impression volume are the primary revenue constraint.
- Compare Apple page conversion with PostHog puzzle activation and retention, then AdMob revenue per active user and impressions per session by territory.

### Review submission

Submitted: `2026-08-28`

Submission ID: `a13149bc-18d5-46f6-bbd8-f6932013d507`

Submission state after reconciliation: `COMPLETE` (`a13149bc-18d5-46f6-bbd8-f6932013d507`)

- Daily Puzzle custom page version 1: `PREPARE_FOR_SUBMISSION`; not yet approved
- Movie Tracker custom page version 1: `PREPARE_FOR_SUBMISSION`; not yet approved
- App version `4.25.40 (11)`: `READY_FOR_SALE`; production release observed on 2026-08-30
- Submission tooling: `scripts/submit_custom_product_pages.py`

### Post-submission verification

- Read-only copy and media reconciliation now follows the latest custom-page version after submission while apply modes remain restricted to editable drafts.
- Sync and submission unit tests: 25 passed.
- Marketing snapshot comparison: 4 tests covering 30 screenshots, 0 failures.
- Final App Store reconciliation: 2 pages, 10 localizations, 20 screenshot sets, 60 exact matches, 0 pending uploads, 0 stale screenshots.
- Review state: both custom page versions and submission `a13149bc-18d5-46f6-bbd8-f6932013d507` are `WAITING_FOR_REVIEW`.

## Launch-readiness checkpoint: 2026-08-31

Iteration: `MKT-INTL-002`

Decision state: `PREPARED_NOT_SUBMITTED`

Safety boundary:

- App version `4.25.40 (11)` remains untouched and `READY_FOR_SALE`.
- No current app-version submission was rejected, replaced, or modified.
- No new custom-product-page review submission was created or submitted.
- The prior submission `a13149bc-18d5-46f6-bbd8-f6932013d507` remains historical evidence; the current page versions are editable `PREPARE_FOR_SUBMISSION` drafts.

### Custom-page package

- Daily Puzzle launch URL: https://apps.apple.com/us/app/streaming-now-tv-movies/id455556959?ppid=76c15a6b-c125-4166-8436-947f7d2ec893
- Movie Tracker launch URL: https://apps.apple.com/us/app/streaming-now-tv-movies/id455556959?ppid=fdfcdda2-b6a9-49b5-8e42-938423fa3548
- Copy reconciliation: 2 pages unchanged.
- Media reconciliation: 20 page/locale/device sets, 60 exact screenshots, 3 screenshots in every set, 0 uploads, and 0 deletions.
- Assigned Daily Puzzle keywords: France `jeu`, `devinette`, `quotidien`; Spain and Mexico `juego`, `emoji`, `diario`; Brazil `jogo`, `emoji`, `diario`.
- Deferred English keywords: `daily puzzle`, `emoji game`, `movie tracker`, and `where to watch` remain unavailable in Apple's assignable pool. `watchlist` remains assigned.
- Review preview: would create one separate custom-page submission and attach exactly 2 pages; `would_submit=false` and `submitted=false`.

### Pre-launch acquisition baseline

Apple source window: engagement through `2026-08-29`; downloads through `2026-08-30`.

| Market | Impressions | Page views | First downloads | Count-based download yield |
|---|---:|---:|---:|---:|
| France | 3,181 | 221 | 74 | 2.33% |
| Spain | 563 | 21 | 8 | 1.42% |
| Mexico | 1,427 | 74 | 19 | 1.33% |
| Brazil | 21,395 | 438 | 48 | 0.22% |

Custom-page baseline: 0 first downloads attributed to either new page. Do not start the day 3/7/14/28 clock until both page versions are explicitly `APPROVED` and visible. Continue treating each page as insufficient until it records at least 5 first-time downloads.

### Pre-launch product baseline

Fresh PostHog audit window: 14 days ending `2026-08-31`.

- Build 11 strict puzzle funnel: 3 opened sessions, 3 started sessions, 1 guessing session, and 0 terminal sessions.
- Build 11 Daily Run funnel: 3 runs started, 0 completed, 0 shared, and 0 continued.
- Weekly Movie Goal: 0 observed outcome rows.
- France build 11: 2 unique users, 2 launched users, 0 puzzle-open users, and 1 ad impression.
- Spain build 11: no row observed; sample unavailable rather than a measured zero.
- Mexico build 11: 1 unique user, 1 launched user, 0 puzzle-open users, and 1 ad impression.
- Brazil build 11: 4 unique users, 3 launched users, 0 puzzle-open users, and 3 ad impressions.
- Sample sizes are too small for a keep, change, expand, or revert decision.

The aggregate international report's PostHog join currently ends on `2026-08-21`; use the independent `docs/posthog_release_health.txt` audit for fresh build-level behavior until that join is corrected.

### Pre-launch monetization baseline

AdMob source window ends `2026-08-27`. Refresh is blocked by Google OAuth `invalid_grant` / `invalid_rapt`; do not present these values as current after that date.

| Market | Requests | Impressions | Earnings |
|---|---:|---:|---:|
| France | 292 | 5 | $0.0135 |
| Spain | 97 | 1 | $0.0055 |
| Mexico | 128 | 68 | $0.2220 |
| Brazil | 135 | 56 | $0.1108 |

All-market AdMob daily baseline for `2026-08-21` through `2026-08-27`: $0.9765 revenue, 445.29 requests, 144.29 impressions, 32.40% show rate, $6.7682 eCPM, and 8.12% CTR. Request and impression volume remain the primary constraint, so do not increase interstitial pressure.

### Web acquisition gate

- `https://streaming-now-daily-reel.web.app` returns `200` with the deployed game.
- `www.streamingnowapp.com` resolves to Firebase and returns `301` to `https://streamingnowapp.com/`.
- The apex verification TXT is public: `hosting-site=streaming-now-daily-reel`.
- `https://streamingnowapp.com` currently returns Firebase `404`; the apex custom-domain association is not launch-ready.
- Do not change DNS again. Recheck Firebase ownership/host state after Google CLI reauthentication or Firebase reconciliation, then require an apex `200` before using the custom domain in campaigns.

### Next release decision

The package is ready for a separate custom-product-page review submission after the apex web gate is resolved or explicitly waived. The only App Store Connect write remaining is the deliberate submit action, which requires a separate yes/no approval.
