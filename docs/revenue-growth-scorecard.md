# Revenue Growth Scorecard

## Objective

Increase sustainable revenue per daily active user by increasing valuable Daily Puzzle sessions and converting eligible ad opportunities without degrading continuation or retention.

## Metric hierarchy

### North star

- Revenue per daily active user: AdMob estimated earnings divided by PostHog DAU for the same reporting window.

### Product drivers

- Daily Puzzle open rate
- Open-to-guess rate
- Terminal rounds per puzzle session
- Solve rate
- Next Puzzle continuation rate
- Next Puzzle load rate
- D1 and D7 retention by first-seen build

### Monetization drivers

- Native eligible slots per puzzle session
- Rewarded hint attempts, completed rewards, and impressions
- Interstitial opportunities, presentations, and impressions
- Interstitial impressions per puzzle session
- AdMob match rate, show rate, eCPM, and estimated earnings

### Guardrails

- No forced interstitial before or immediately after the first Daily Puzzle.
- At most one forced interstitial per configured session window.
- At least 150 seconds between forced interstitial presentations.
- Next Puzzle load rate above 95%.
- Solve rate at or above 65%.
- Open-to-guess rate does not regress by more than 5 percentage points.
- Paid and preview-mode users do not receive monetization surfaces.

## Baseline

Recorded 2026-08-27 before RG-001:

| Metric | Baseline | Interpretation |
|---|---:|---|
| AdMob match rate | 100% | Inventory matching was not the observed constraint. |
| AdMob show rate | 31.6% | Matched requests frequently did not become impressions; placement and presentation reasons require separation. |
| Build 8 PostHog users in the observed window | 2 | Sample was too small for aggressive cadence decisions. |

### Released-build behavioral baseline

Recorded 2026-08-28 for App Store build `4.25.40 (9)`, before RG-004 through RG-006 ship:

| Metric | Baseline | Interpretation |
|---|---:|---|
| Unique PostHog users | 5 | Directional only; not decision-grade. |
| Instrumented launches | 5 | Use as the released-build exposure denominator. |
| Daily Puzzle opens | 22 | Puzzle entry is active, but repeated opens can exceed users and launches. |
| Daily Puzzle solves | 0 | Do not infer difficulty or abandonment until the released feature build has terminal-session telemetry. |
| Ad impressions | 12 | Combined interstitial, rewarded, and app-open impressions; AdMob remains revenue truth. |

The previous `daily_puzzle_opened / daily_puzzle_open_requested` calculation is invalid because open requests cover only explicit CTA intent while opens include every entry source. Production comparisons now use strict runtime-session funnels and report entry-source volume separately.

## Change ledger

Append one row for every revenue-affecting release. Do not rewrite historical hypotheses after results arrive.

| ID | Build | Change | Hypothesis | Primary metric | Guardrail | Status | Observed result | Decision |
|---|---|---|---|---|---|---|---|---|
| IG-000 | Reporting only | Add checksum-safe App Store Analytics ingestion and a daily territory join across Apple, PostHog, and AdMob; freeze France, Mexico, Brazil, U.S., and China baseline cohorts. | A complete territory funnel will identify whether each market is constrained by discovery, conversion, activation, retention, or monetization and prevent optimizing from global averages. | Complete daily territory funnel and reproducible target-market baseline | No duplicate segment counts, incomplete dates presented as zero, user-level cross-vendor joins, or credential leakage | Validated locally; daily integration complete | 9 focused tests passed; 33 Apple segments verified; frozen 2026-08-14 through 2026-08-26 baseline reproduced from 37,318 Apple rows and joined with 1,060 AdMob rows | Keep IG-000; begin IG-001 locale and region telemetry |
| IG-001 | Telemetry only | Add app locale, device region, selected content region, puzzle locale, and puzzle localization source to PostHog; report target-territory field coverage and activation/monetization signals by build. | Reliable locale and region dimensions will show whether France, Mexico, and Brazil are losing users at acquisition, activation, retention, or monetization rather than hiding those differences in worldwide averages. | At least 95% property coverage on the first shipping build; territory puzzle activation, solve, and ad-impression signals available | No user-level Apple/PostHog/AdMob joins, inferred puzzle language, false fallback geography, or raw identifiers in reports | Implemented locally; release pending | 3 focused Xcode tests passed; current puzzle content is explicitly tagged en/legacy_default; production field coverage is unavailable until this build ships | Keep implementation; validate property coverage at the 72-hour release checkpoint |
| IG-002 | Daily Puzzle localization | Add backward-compatible fr-FR, es-MX, and pt-BR puzzle maps; resolve exact locale, language fallback, then canonical content; localize Daily Puzzle and Daily Run copy; seed one localized practice puzzle. | Culturally legible titles, hints, aliases, and sharing will improve international puzzle activation, solve rate, continuation, and retention without fragmenting streaks. | Target-territory puzzle activation and solve rate; localization-source distribution; continuation rate | Stable puzzle IDs, canonical fallback for old records, no empty aliases, all locale quality gates pass, no production latest-alias mutation | Validated locally; Functions deployment pending | 34 backend tests and TypeScript build passed; 7 focused Simulator tests passed; 4 string tables linted; fr-FR/es-MX/pt-BR UI evidence saved under .build/international-growth/evidence; existing latest record correctly used canonical fallback | Keep implementation; deploy generator, verify the first localized daily record, then evaluate at 72 hours and 14 days |
| RG-001 | TBD | Remove immediate puzzle-completion interstitial; offer one after every third completed round; isolate trigger counters; preserve puzzle metadata through ad callbacks; add failure and native-opportunity events. | Delivering three rounds before a forced ad will increase puzzle depth and continuation while producing higher-quality interstitial opportunities. | Terminal rounds and interstitial impressions per puzzle session | Next-load rate, solve rate, D1/D7 retention | Implemented locally; validation pending | Pending | Pending |

## Release checkpoint

### Before TestFlight

- Focused `AdCoordinatorTests` cover third-round cadence, isolated counters, runtime suppression, and continuation.
- Focused Daily Puzzle tests cover one-time terminal failure and puzzle-index context.
- UI flow reaches a fresh fourth puzzle after an eligible interstitial is dismissed, blocked, or unavailable.
- Release ad-unit gate passes.

### TestFlight smoke

- First Daily Puzzle completes with no forced interstitial.
- First and second Next Puzzle transitions are immediate.
- Third completed round creates no more than one interstitial presentation.
- Dismissing that ad opens a fresh fourth puzzle.
- Rewarded hint unlock occurs only after reward completion or the documented fallback path.
- Paid/preview paths show no monetization surface.

### Observation window

- Use at least one complete seven-day period when traffic permits.
- Compare by app version and build.
- Report absolute users and sessions beside every rate.
- Use AdMob for revenue/impression truth and PostHog for behavioral attribution.

### Decision rules

- Keep RG-001 if puzzle depth or revenue per DAU improves and no guardrail materially regresses.
- Revert or relax cadence if Next Puzzle load rate falls below 95% or retention/open-to-guess declines materially.
- Do not increase forced frequency until the current build has enough sessions for a stable directional read.

## Operating commands

Production release-health refresh:

```bash
set -a
source .env
set +a
scripts/release_health.sh
```

The generated reports are:

- `docs/posthog_release_health.txt`
- `docs/admob_weekly_report.md`

## Next phases

1. Daily Puzzle widget and quick action to increase daily re-entry.
2. Shareable puzzle deep links to increase organic acquisition.
3. Taste Profile and advanced statistics to create premium value.
4. Premium entitlement design only after retention and puzzle depth are established.

## Implementation checkpoint: 2026-08-27

- RG-001 focused simulator verification: passed.
- Scope: `CronicaTests/AdCoordinatorTests` and `CronicaTests/DailyPuzzleViewModelTests`.
- Result: 79 passed, 0 failed, 0 skipped on iPad Air 11-inch (M3), latest iOS simulator.
- Proven: per-trigger cadence isolation, third-round puzzle interstitial opportunity, runtime-disabled continuation, failed-puzzle telemetry, ad-opportunity telemetry, and event-specific metadata precedence.
- Remaining gate: full app build/UI smoke test and TestFlight production-telemetry validation.

## RG-002: Native ad validator compliance - 2026-08-27

- Trigger: integrated iPad simulator smoke test exposed `Advertiser assets outside native ad view`.
- Change: replaced third-party `.card` rendering with `CronicaNativeAdCardView`; retained the existing native ad loader, unit IDs, refresh interval, and large-banner renderer.
- Coverage: Home, Daily Puzzle, Puzzle Archive, and iPad detail card placements.
- Automated checkpoint: 93 passed, 0 failed, 0 skipped across ad configuration, ad coordinator, and Daily Puzzle view-model suites.
- Integrated checkpoint: simulator build/install/launch succeeded; first puzzle solved; `Next Puzzle` loaded a fresh second round with attempts reset and no first-round interstitial.
- Live AdMob validator: `No implementation issues found` on both Home and Daily Puzzle card placements.
- Evidence: `docs/evidence/2026-08-27-revenue-loop-admob-validator-clean.png`.
- Remaining gate: confirm the same layout and production telemetry in TestFlight on a physical iPhone.

## RG-003: Onboarding contrast repair - 2026-08-27

- Trigger: dark app theme produced white onboarding text over a UIKit light sheet background.
- Change: `WelcomeView` now owns a full-size presentation background derived from the same SwiftUI color scheme as its adaptive text.
- Verification: simulator build/install/launch succeeded; production onboarding sheet presented through `-showOnboarding YES`; all headings, descriptions, and actions are visually readable in dark mode.
- Evidence: `docs/evidence/2026-08-27-onboarding-dark-contrast-fixed.png`.
- Measurement: monitor onboarding completion and first Daily Puzzle open after the next TestFlight/App Store release.

## RG-004: Three-round Daily Run

- Date: 2026-08-27
- Status: implemented locally; release and production measurement pending
- Hypothesis: a clear three-round goal and completion payoff will increase puzzle depth, repeat play, share intent, and qualified third-round ad opportunities without increasing ad frequency.
- Product change: visible Round N of 3 progress, cumulative run state, a third-round summary, spoiler-free Share Run, and user-initiated Keep Playing.
- Monetization behavior: Keep Playing reuses the existing third-completed-round interstitial opportunity, cooldown, paid-user bypass, and session cap. No new ad placement or frequency increase was added.
- Primary metrics: run completion rate, run share rate, run continuation rate, completed third-round ad opportunities, and revenue per puzzle starter.
- Guardrails: next-puzzle load failure rate, puzzle abandonment by round, interstitial failure rate, day-1/day-7 retention, and review sentiment.
- Verification: 83 focused simulator tests passed, including DailyPuzzleRunStateTests, DailyPuzzleViewModelTests, and AdCoordinatorTests.
- Decision checkpoint: evaluate after one complete seven-day production cohort; retain when depth and revenue per starter improve without a material retention or load-failure regression.
- Simulator checkpoint: completed a live three-puzzle run, verified the cumulative summary and accessible Share Run/Keep Playing controls, observed the existing third-round test interstitial, and confirmed the next puzzle reset to Round 1 of 3.

## RG-005: Five-day Weekly Movie Goal

- Date: 2026-08-27
- Status: implemented locally; release and production measurement pending
- Hypothesis: an attainable five-unique-days goal gives completed-run users a concrete reason to return tomorrow, increasing weekly active days and qualified ad sessions without adding ad pressure.
- Product change: persist one completed Daily Run per local calendar day, reset by ISO week, and display weekly progress and completion payoff inside the run summary.
- Monetization behavior: no ad placements, caps, cooldowns, or paid-user behavior changed. Revenue impact must come from higher return frequency and deeper voluntary engagement.
- Primary metrics: next-day return after goal exposure, weekly goal completion rate, active puzzle days per user, and revenue per puzzle starter.
- Guardrails: run completion, next-puzzle load failures, ad presentation failures, notification opt-outs, day-1/day-7 retention, and review sentiment.
- Verification: 87 focused simulator tests passed, including DailyPuzzleWeeklyGoalTests, DailyPuzzleRunStateTests, DailyPuzzleViewModelTests, and AdCoordinatorTests.
- Decision checkpoint: compare the first complete seven-day production cohort by app build; retain when next-day return and revenue per starter improve without a material guardrail regression.
- Simulator checkpoint: completed a live three-puzzle run on iOS 26.3 and verified `dailyPuzzle.weeklyGoal` reports `1 of 5 days complete` in the rendered summary.

## RG-006: Contextual Rewarded Hints

- Date: 2026-08-27
- Status: implemented locally; release and production measurement pending
- Hypothesis: offering a clearly labeled rewarded hint only after demonstrated difficulty will improve voluntary ad conversion and puzzle completion while reducing pre-game ad clutter.
- Product change: hide the hint-ad CTA at attempt zero, reveal it after a wrong guess, label the exact next hint, and attribute offer, tap, and granted reward events.
- Monetization behavior: user-initiated rewarded flow only; no interstitial frequency, cooldown, session cap, or paid-user behavior changed. A hint remains locked when no ad completion callback occurs.
- Primary metrics: offer tap rate, reward delivery rate, reward-assisted solve rate, rewarded revenue per offer, and revenue per puzzle starter.
- Guardrails: puzzle abandonment, max-attempt failures, run completion, unavailable-ad outcomes, time-to-solve, and review sentiment.
- Verification: 7 targeted simulator tests passed, including contextual policy, event contracts, rewarded fallback, paid-user bypass, and no-ad/no-reward behavior.
- Decision checkpoint: compare the first complete seven-day production cohort by build; retain when rewarded revenue per starter and solve completion improve without a material abandonment regression.
- Simulator checkpoint: verified no hint offer at attempt zero, `dailyPuzzle.hintOffer` appeared after one wrong guess as `Reveal Hint 1 with a short ad`, and tapping it presented the AdMob test ad.

## IG-003: First-Launch Regional Content Defaults

- Date: 2026-08-27
- Status: implemented and simulator-verified locally; release and production measurement pending
- Hypothesis: defaulting provider and release-date behavior to the user's supported region will increase internationally relevant content discovery, watch-provider engagement, and retained monetizable sessions.
- Product change: preserve every existing region preference, initialize only absent preferences for supported device regions, leave unsupported fallback non-persistent, and remove view-time preference rewrites.
- Regional behavior: release dates now resolve user region, production region, then U.S. only as the final available-data fallback; provider service requests use the effective saved region.
- Telemetry: `watch_region_resolved` records effective region, device region, resolution source, and whether initialization persisted a preference; `app_launched` also records the resolution source.
- Primary metrics: target-territory provider engagement, activated users by content region, watchlist additions, retained sessions, and AdMob revenue per activated user.
- Guardrails: provider-load failures, release-date availability, explicit-region preservation, unsupported-region persistence, and app-launch health.
- Verification: 5 focused `RegionalContentTests` passed and three clean iOS 26.3 simulator builds launched successfully.
- Simulator checkpoint: clean first launches persisted `fr`, `mx`, and `br` respectively while French, Mexican Spanish, and Brazilian Portuguese UIs loaded localized regional content without manual setup.
- Evidence: `.build/international-growth/evidence/region-default-fr-FR.jpg`, `.build/international-growth/evidence/region-default-es-MX.jpg`, and `.build/international-growth/evidence/region-default-pt-BR.jpg`.
- Decision checkpoint: compare the first complete seven-day production cohort by build; retain when target-territory activation, provider engagement, or revenue per activated user improves without provider-load or launch regressions.

## IG-004: Earned Localized Review Prompt

- Date: 2026-08-27
- Status: implemented and simulator-verified locally; release and production rating measurement pending
- Hypothesis: asking for an App Store review only after repeated use and an earned success will improve rating volume and international social proof without interrupting low-intent users.
- Product change: replace the 30-launch review banner with one coordinator requiring three distinct active days, a qualifying milestone, a new app version, and a 180-day cooldown.
- Qualifying milestones: canonical Daily Puzzle solved, three-round Daily Run completed, or at least five watchlist items.
- Suppression behavior: onboarding, any blocking Home presentation, and any full-screen ad prevent the request attempt; the manual Settings review action remains unchanged.
- Telemetry: `review_prompt_milestone_earned`, `review_prompt_eligibility_evaluated`, and `review_prompt_request_attempted`; no event claims Apple displayed a prompt or that a user submitted a rating.
- Primary metrics: eligible-to-attempt rate, App Store rating count and average by target storefront, activation-to-rating lag, retained sessions, and revenue per activated user.
- Guardrails: day-1 interruption rate, suppression distribution, repeat attempts by version, ad/prompt overlap, review sentiment, and app-launch health.
- Verification: 6 focused coordinator boundary tests and 58 existing AdCoordinator tests passed with no failures; the app built successfully on iOS 26.3.
- Simulator checkpoint: an eligible debug-seeded path emitted `outcome=eligible` and `review_prompt_request_attempted`; a clean first-day path emitted `insufficient_active_days` and no request attempt.
- Evidence: `.build/international-growth/evidence/review-prompt-eligible-path.log` and `.build/international-growth/evidence/review-prompt-first-day-suppressed.log`.
- Decision checkpoint: evaluate the first complete 28-day production window because review outcomes are sparse; retain when target-storefront rating volume improves without interruption, sentiment, or retention regressions.

## RG-007: Puzzle Activation Assistance

- Date: 2026-08-28
- Status: implemented locally; focused verification and release pending
- Baseline: the latest mixed-build 14-day audit recorded 85 Daily Puzzle opens, 10 guess submissions, and 6 solves. These are event counts across multiple builds, not a stable unique-user cohort, but they identify open-to-first-guess as the first funnel constraint to address.
- Hypothesis: a free title-length clue, an optional title-pattern rescue after two misses, and explicit difficulty feedback will increase first-guess activation and solve completion while improving future puzzle calibration.
- Product change: show title word count before the first guess; offer a persisted, user-requested masked title pattern after two wrong guesses; collect one persisted too-easy, just-right, or too-hard rating after a terminal result.
- Telemetry: daily_puzzle_starter_clue_shown, daily_puzzle_answer_rescue_offered, daily_puzzle_answer_rescue_revealed, and daily_puzzle_difficulty_rated, with existing puzzle, locale, build, attempt, source, and terminal metadata.
- Monetization behavior: no ad placements, frequency, cooldowns, rewarded-hint rules, or paid-user behavior changed.
- Primary metrics: unique guessers per unique opener, solves per activated user, rescue reveal rate, post-rescue solve rate, attempt distribution, and difficulty-rating distribution by puzzle and locale.
- Guardrails: session completion, Next Puzzle success, rewarded-hint engagement, Daily Run completion, day-1 return, review sentiment, and revenue per puzzle starter.
- Decision checkpoint: evaluate after at least 50 unique puzzle openers and one complete seven-day cohort; keep when activation or completion improves without a material return, load, or monetization regression.
- Verification checkpoint: pending focused state/event tests and an iOS simulator pass covering starter clue, two-miss rescue, persisted pattern, terminal feedback, and Next Puzzle reset.

## MKT-INTL-002 pre-launch revenue baseline - 2026-08-31

- State: localized custom-page package prepared; no new review submission created and no live app submission modified.
- Exposure: France 3,181 impressions; Spain 563; Mexico 1,427; Brazil 21,395.
- Conversion: France 74 first downloads (2.33% count yield); Spain 8 (1.42%); Mexico 19 (1.33%); Brazil 48 (0.22%).
- Custom-page attribution: 0 first downloads for the two new pages; measurement clock has not started.
- Build 11 activation: 3 puzzle sessions opened, 3 started, 1 reached guessing, and 0 reached a terminal result.
- Build 11 retention loop: 3 Daily Runs started, 0 completed, and no Weekly Movie Goal outcome rows observed.
- Target-market build 11 users: France 2, Spain no observed row, Mexico 1, Brazil 4. None recorded a puzzle-open user in the target-territory query.
- Monetization through 2026-08-27: France $0.0135 from 5 impressions; Spain $0.0055 from 1; Mexico $0.2220 from 68; Brazil $0.1108 from 56.
- All-market AdMob daily baseline: $0.9765 revenue, 445.29 requests, 144.29 impressions, 32.40% show rate, $6.7682 eCPM, and 8.12% CTR.
- Data gap: AdMob refresh is blocked by `invalid_grant` / `invalid_rapt`; the aggregate international PostHog join is stale through 2026-08-21, while the independent build audit is fresh through 2026-08-31.
- Recommendation: `KEEP_PREPARED`. Do not increase ad pressure. Submit the localized pages only after explicit approval, then evaluate acquisition after at least 5 first-time downloads per page and product/revenue guardrails at the scheduled checkpoints.

## Build 11 production checkpoint - 2026-09-12

- Measurement window: rolling 14 days for App Store build `4.25.40 (11)`; the build has been `READY_FOR_SALE` since the production release observed on 2026-08-30.
- Exposure: 522 unique PostHog users, 1,048 instrumented launches, 74 Daily Puzzle opens, and 375 combined ad impressions.
- Activation: 41 strict puzzle sessions opened and started; 7 reached a guess (17.1%) and 2 reached a terminal result (4.9% of starters; 28.6% of guessers).
- Depth: 14 completed-round events across 41 puzzle sessions (0.34 rounds per session), followed by only 1 `Next Puzzle` tap and 1 successful next load (7.1% continuation per completed-round event).
- Daily Run: 36 runs started, 0 completed, 0 shared, and 0 continued. Weekly Movie Goal updates remained at 0, so RG-004 is not producing the intended three-round payoff and RG-005 has no reachable retention loop in this cohort.
- Rewarded hints: 8 offers, 6 taps, and 3 granted rewards. This is directionally promising but below a decision-grade sample.
- Monetization guardrail: no build-11 puzzle-completion interstitial opportunities or impressions were recorded. AdMob revenue remains stale through 2026-08-27 because refresh is blocked by `invalid_grant` / `invalid_rapt`; do not increase ad pressure or infer current revenue lift.
- International acquisition through 2026-09-10: France 6,873 impressions / 420 page views / 108 first downloads (1.57% count yield); Spain 1,672 / 71 / 11 (0.66%); Mexico 3,601 / 156 / 28 (0.78%); Brazil 48,899 / 848 / 74 (0.15%). These are aggregate sequential counts, not custom-page attribution.
- Custom-page boundary: both page versions remain `PREPARE_FOR_SUBMISSION` with 0 attributable first downloads, so MKT-INTL-002's day 3/7/14/28 clock has not started.
- Recommendation: `CHANGE` the Daily Run continuation path before adding monetization. Keep the conservative ad cadence and rewarded-hint offer, diagnose why solved rounds rarely produce `Next Puzzle` progression, and repair the run-completion/weekly-goal telemetry contract before judging retention or revenue impact. Keep MKT-INTL-002 prepared but unmeasured until both pages are approved and visible.

## Daily Run continuation repair - 2026-09-21

- Trigger: a fresh 30-day PostHog audit confirmed the RG-004/RG-005 loop is still unreachable. Counts: 230 `daily_puzzle_opened` / `daily_puzzle_session_started`, 8 `daily_puzzle_next_tapped`, 92 `daily_puzzle_run_started`, 0 `daily_puzzle_run_completed`, 0 `daily_puzzle_run_shared`, 0 `daily_puzzle_run_continue_tapped`, and an empty `daily_puzzle_weekly_goal_updated` result set. Build 11 recorded 24 completed rounds against 1 `next_puzzle` tap for 4.2% continuation.
- Diagnosis: completion required three terminal rounds inside a single sheet presentation, while `daily_puzzle_run_started` fired on view appearance. The funnel denominator counted modal opens and the numerator was structurally unreachable, so the metric could never move off zero regardless of engagement.
- Change: a persistent bottom continue bar (`dailyPuzzle.continueRunBar`) now appears immediately after every terminal round with the round count and a large Keep Playing action, replacing the below-the-fold button and the toolbar chevron. `daily_puzzle_run_started` is emitted once when a run's first round reaches a terminal result instead of on appearance.
- Telemetry impact: run completion rate now measures completions per engaged run rather than completions per open. No event names, property names, or ad behavior changed, and the session-local three-round rule is unchanged.
- Verification: `DailyPuzzleRunStateTests`, `DailyPuzzleWeeklyGoalTests`, and the English localization-key test pass; the `testSolvedDailyPuzzleAdvancesToAnotherPuzzle` UI test passes against the new continue bar; the four string tables lint clean.
- Decision checkpoint: re-audit the run funnel once the next build has a complete seven-day production window; retain when continuation and run completion move off zero without a new-puzzle load-failure or retention regression.
