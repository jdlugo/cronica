# Movie Arcade: evaluation and prioritized growth objectives

## Decision
Prioritize trustworthy measurement, a faster first win, fresh repeat-play content, and an honest purchase path. The strongest near-term product hypothesis is that a curated entry and satisfying first success will earn more voluntary second rounds. The strongest retention hypothesis is fresh challenges in a few strong mechanics. Sustainable revenue needs both a reliable earnings baseline and returning players.

This is a design evaluation, not proof of human enjoyment or a measured revenue improvement. I built the games and knew some initial answers. New exploratory simulator rounds use visible UI choices and state; the runner sometimes guesses systematically, always chooses Before in the timeline, and solves memory with explicit notes. Automation time and its mistakes are not human pacing or difficulty measurements.

## Current evidence, October 1, 2026

- Local checkout: `2ec730a7` before this evaluation, version 4.25.43/build 15. These arcade commits have not been submitted in this conversation. App Store status was not rechecked during this product review.
- PostHog project 560852, rolling 14 days queried at 11:18 and 11:22 UTC: no `movie_arcade_*` events. This establishes no recorded arcade exposure, not zero demand. Version 4.25.42/build 14 has 124 distinct telemetry identifiers; 4.25.43/build 15 has one. IDs are not verified people and can overlap across builds.
- Build 14 has 12 puzzle-open events from six identifiers and no recorded puzzle guesses or solves in this window. These are primitive counts, not an ordered funnel or proof that difficulty caused exits.
- Build 14 app-open ads: 42 `presented` outcome events from 37 identifiers; 38 recorded impressions from 34. The 224 total `ad_app_open_present` events include attempts and blocked outcomes and must not be counted as 224 shown ads.
- A normal simulator launch showed a full-screen test ad before Home. The exploratory game runner suppresses monetization and uses an isolated fixture store. Its results do not validate free-user ad cadence.
- Version-42 adoption diagnostic: two of 19 mature identifiers returned on the next UTC calendar date after their first observed version-42 event in the query window. This is NOT new-install D1 retention; the cohort is left-censored and can include upgrades, test/review traffic, and prior users. No D7 cohort had matured under this definition; D7 is unavailable, not 0%.
- Across all queried events, 14,954/24,344 have runtime-session identity, 15,012 have app version, and none have an environment marker. A release/test-traffic exclusion and meaningful activity definition are needed.
- AdMob refresh failed with `invalid_grant` / `invalid_rapt`; no reauthentication was attempted. The cached history ends August 27. Current revenue, eCPM and a revenue-per-user baseline are unavailable; stale reports are not substituted as current.
- English Tip Jar footer claims the app will always remain free and ad-free, although ads appear in the free path. Runtime product configuration requests `AdFreeUpgrade`; the active local StoreKit configuration instead defines `CronicaTipJarLarge`. The production product catalog and price have not been verified. This is a confirmed local test/configuration mismatch, not a proven App Store purchase outage.

Aggregate query outputs are saved in `docs/evidence/arcade-evaluation-2026-10-01/`. No raw player identifiers or credentials were saved there.

## Play evaluation and mode decisions

Evidence from the earlier complete playthroughs, current UI/source inspection, and three-round exploratory replay is combined below. Ratings are design judgments; production retention by mode is unknown.

| Mode | Strongest design property | Replay/friction risk | Recommendation | Confidence |
| --- | --- | --- | --- | --- |
| Movie Scramble | Manipulating a scene creates an understandable, nontrivia success before naming it. | Four pieces provide limited depth; the title question adds a second gate after assembly. Familiar images quickly become memorized. | KEEP; test assembly as the core payoff, with the title question optional. | Medium |
| Poster Memory | Clear visual task, recoverable mistakes, and skill independent of movie trivia. | Mandatory year bonus delays the payoff after all pairs are found; fixed six-card size limits progression. | IMPROVE; celebrate matching completion, make the trivia bonus optional. | High on flow; medium on retention |
| Double Feature | Recognizing a shared actor creates a meaningful connection. | All rounds reuse the same three actor/movie pairings; reshuffling positions supplies little conceptual novelty. | IMPROVE; expand verified pairings before treating it as a daily retention mode. | High on repetition |
| Movie Detective | Players choose which evidence to reveal; help has a clear cost. | Cropped scene and short plot are recognizable in a small catalog; points stop distinguishing help after the one-point floor. | KEEP; improve clue progression and varied cases. | Medium |
| Movie Heist | Three clue types and recovered digits give a round a narrative arc. | Code is a progress reward, not a separate deduction; two Next Lock taps can add ceremony without agency. | IMPROVE; test its pacing and use it as a daily wrapper rather than another competing destination. | Medium |
| Casting Call | Named portraits and an explicit cast question are easy to understand. | Voice casting can be obscure; repeated actor/film associations are learned quickly. Portrait choices require scrolling. | IMPROVE; curate starter difficulty and improve related distractors. | Medium |
| Director's Cut | Players build a three-film ordering with visible placement feedback. | Depends on release-year knowledge; overlaps Before or After. Wrong choices temporarily disable but don't add a new clue. | KEEP as the single featured chronology mechanic pending human comparison. | Medium |
| Before or After | Binary choice and year reveal are quick and legible. | Same knowledge as Director's Cut, with less manipulation and repeated acknowledgment taps. | REMOVE from the proposed curated entry experiment; retain as a reversible practice option. | Medium; not a recommendation to delete code |
| Odd Movie Out | The rule is explicit and objectively verifiable. | Current rules are release-era trivia rather than a richer visual deduction; overlaps chronology modes. | REDESIGN or hide from the curated entry until a distinctive challenge is validated. | Medium |
| Scene Spotter | Immediate recognizable image plus plot gives a good starter round. | Shares scenes/answers with other games; recognition becomes recall of the starter pack. | KEEP as the first-win anchor, not another lobby choice. | Medium |

Strongest mechanics to develop: Scramble, Memory, and actor connections. Weakest differentiation: Odd Movie Out, Before or After, and the separate lobby positioning of Heist. These rankings need human validation; they are not player preference results.

## Completed simulator evaluation

All ten modes reached their result three times: **30 practice rounds**, plus **four non-skipped Daily Mix rounds** entered through Home and the lobby. Device: iPhone 17 Pro, iOS 26.3. Fixture date: September 30, 2026; practice starts at seed 0, then Play Another produces fresh seeds. Ads/onboarding are disabled and the fixture store is isolated. This is functional exploratory evidence, not independent human enjoyment, organic replay, a seven-day content audit, or a free-user monetization test.

The first selected suite passed nine of ten tests. The Scramble audit mistakenly assumed that the tile's accessibility enabled state would be sufficient to distinguish a solved board. It stopped after the board was restored. After the diagnostic explicitly recognized the restored section order, its three-round rerun passed; the Home-to-Daily-Mix test also passed. No product change was needed for this diagnostic correction. Temporary test code was restored afterward. The initial suite's optional simulator diagnostics collection stalled; it was stopped after the test results were recorded, and the result bundle exported successfully.

| Mode | Completed rounds | Deliberate game taps in rounds 1, 2, 3 |
| --- | --- | --- |
| casting | 3 / 3 | 3, 1, 4 |
| detective | 3 / 3 | 3, 3, 4 |
| directorsCut | 3 / 3 | 6, 4, 5 |
| doubleFeature | 3 / 3 | 6, 6, 6 |
| heist | 3 / 3 | 10, 11, 8 |
| memory | 3 / 3 | 14, 13, 16 |
| oddOneOut | 3 / 3 | 4, 1, 1 |
| scene | 3 / 3 | 3, 3, 4 |
| scramble | 3 / 3 | 7, 9, 8 |
| timeline | 3 / 3 | 5, 5, 5 |

Tap counts exclude scrolling, entry, and replay initiation. They depend on the runner's systematic choices and are not minimum required actions or measured human effort. The Daily Mix exercised Scene Spotter, Double Feature, Detective and Memory (4, 6, 4 and 9 game taps respectively), then reached the 6/12 summary without skipping.

Observed novelty problems: Scene Spotter, Casting Call, Detective and Memory returned to Toy Story on the third practice round after The Matrix on the second. Double Feature reused exactly the same three actor pairings in all three rounds and in the Daily Mix. The Daily Mix's Matrix case also followed the Matrix/John Wick pairing round. These are direct observations supporting cross-mode repeat limits; the automated low scores are not evidence that the games are too hard.

Representative inspected screenshots show legible Memory cards, Double Feature posters, Director's Cut choices, the Heist payoff, Home entry and Daily Mix summary at standard text size. This does not validate all devices, large text or every animation. The immediate post-tap lobby screenshot caught the sheet transition and was excluded from saved representative evidence.

## Sequence, scope and ownership

| Order | Objective | Why now | Scope / effort estimate | Owner |
| --- | --- | --- | --- | --- |
| P0 | Reconcile measurement and the purchase promise | No recorded arcade baseline; earnings unavailable; purchase copy/configuration mismatch | Small-to-medium engineering audit; account access is an external dependency | Engineering + account owner |
| P1 | Earn a first win and a voluntary second round | Two competing daily entries and nine practice choices; startup ad observed | Small entry prototype + first-time study; ad experiment separate | Product/design + engineering |
| P2 | Make a week of play meaningfully fresh | Identical actor pairs; initial film repeats on round three in several modes | Medium content pipeline and curation effort; recurring cost must be budgeted | Content/product + engineering |
| P3 | Explain and convert the existing paid benefit | Value and checkout must be verified before measuring conversion | Small offer experiment after P0; 28-day revenue observation | Growth + engineering |
| P4 | Connect solved movies to useful discovery | Potentially strengthens the app's core purpose | Small result-action experiment; lower confidence | Product + engineering |

Effort categories are planning estimates, not completed work or promised delivery dates. P0 and the qualitative P1 study can proceed together. Run quantitative entry/ad/content tests sequentially given the observed traffic. The top three product bets are activation, freshness, and an optional honest purchase offer; measurement is their prerequisite.

## Priority 0: make retention and revenue decisions trustworthy

Objective: establish a reliable shipped-build funnel and a current revenue baseline before drawing growth conclusions.

Work:
1. Add rendered Home/arcade exposure, actual round visibility and first-action events; durable run/round/challenge IDs, fresh/resumed/summary entry type, content version, attempt/help counts, and terminal outcome. Deduplicate abandonment. Reopening a completed Daily Mix summary must not emit a new game start.
2. Add release/internal/TestFlight environment classification and fixed experiment assignment. Preserve privacy; no personal guesses are required.
3. Restore AdMob reporting through the account owner; reconcile live product identity, localized price, purchase, restore and ad suppression. Correct Tip Jar copy and the local StoreKit fixture. Do not invent a live price or claim purchases are broken without verification.
4. Define skipped/revealed rounds separately from earned completions. The existing skipped flag helps, but current arcade events lack a full exposure/interaction funnel.

Acceptance: replay a known start/mistake/help/relaunch/completion/summary sequence and reconcile exactly one event per transition; no simulator/internal traffic in the release cohort; current completed-day earnings available; purchase/restore and promised benefit verified in sandbox. Owner: engineering plus account owner for AdMob access.

Measure retained users AND revenue per eligible user. DAU and sessions alone are insufficient; revenue/DAU can look better when low-revenue users disappear.

## Priority 1: earn a first win and a voluntary second round

Hypothesis: a clear recommended start and fewer competing choices will improve activation. Startup ads may be obstructing the first value moment.

Primary metric: distinct eligible assigned users with one non-skipped arcade completion in their first exposure session / distinct eligible assigned users exposed to the arcade entry. Secondary: voluntary second fresh challenge completion in that same session. Reopens and summary views do not count.

Test separately, to avoid confounding:
- Entry subtraction: current nine-game lobby versus Daily Mix plus three featured modes (Scramble, Memory, Double Feature), with the full library behind All Games.
- First-value ad policy: current eligible startup behavior versus suppressing app-open ads until the first meaningful success. Restrict to unpaid users eligible for startup ads; assess separately from entry layout.

Start with six to eight first-time participants of varied film knowledge because the current game-engaged traffic is too small to assume a quick powered A/B test. Then establish exposure baselines and calculate sample size/MDE before randomizing. Account for repeat users and sticky assignment.

Guardrails: Home-to-first-input friction, genuine completion, app discovery/watchlist actions, crashes, D1/D7 returns, and revenue per assigned user. No forced ad during a round. Falsification: fewer choices do not reduce confusion or improve voluntary continuation; the ad change lowers mature revenue without a credible activation/retention benefit.

Decision: fix reproduced usability blockers; ship an entry/ad experiment only with reconciled instrumentation. Do not call a small directional difference a win. Revise if users still cannot find a first challenge; stop a test that repeatedly harms guardrails. Reversal cost is low.

## Priority 2: give players a fresh reason to return

Hypothesis: content novelty and improving at a small set of mechanics are more valuable than rearranging a familiar twelve-film pack.

Work: curate a seven-day content schedule with explicit cross-mode repeat limits; broaden verified actor connections; make Memory's year bonus optional; reduce duplicated chronology placement; add progression only where it changes meaningful decisions. Prototype a Daily Heist that packages distinct modes into one short themed mission with a preview of the next day's theme. Keep any reminder opt-in and locally timed.

Primary metric: D7 meaningful app return per eligible assigned user exposed to the daily experience. Secondary: arcade play on distinct days and genuine daily completion. Also report conditional D7 among starters, but do not substitute it for the intent-to-treat metric.

Guardrails: repeated film/challenge exposure, skips, assistance, errors, notification disablement, and completion. Operational acceptance: the planned week passes content freshness constraints, every puzzle has a unique valid answer, and the team can maintain the next week's content at an explicit effort budget.

Experiment: existing rotating starter pack versus curated themed daily packs, randomized when enough eligible users exist. First test the return proposition with a voluntary next-day human session. Falsification: participants cannot identify what is new, see equivalent content in other modes, or return no more often despite better content. Stop when the content cost cannot be sustained. Avoid adding streak punishment to compensate for weak novelty.

## Priority 3: convert satisfaction into an honest paid benefit

Prerequisites: priority-0 product/revenue verification and sufficient returning play. Objective: test the existing ad-free purchase before building subscriptions or new premium inventory.

Experiment: Settings-only purchase discovery versus an optional, clearly labeled app-wide ad-free offer after repeated genuine successes. Keep the next-round action prominent; use StoreKit's actual price; explain that arcade rounds already contain no inserted ads. Do not imply payment is needed to finish a game or promise an endless catalog.

Primary metric: 28-day net revenue per eligible randomized unpaid user, with fixed assignment and mature cohorts. Diagnostics: offer visibility, purchase initiation, verified transaction, restore and entitlement delivery. Guardrails: voluntary continuation, D7 return, cancellations/refunds, purchase errors and dissatisfaction.

Revenue attribution must be designed: AdMob aggregate earnings cannot be joined to individual PostHog identities or experiment arms. Use validated impression paid-value instrumentation with assignment where available, or an explicitly aggregate revenue comparison; reconcile estimates to source reports. Purchase telemetry is not settlement truth.

Falsification: the offer adds interruption or fails to explain value; conversion/revenue gains are offset by return loss. Ship only after a mature, predeclared comparison supports the tradeoff. Do not increase forced-ad cadence based on missing earnings data.

## Priority 4: make the arcade reinforce movie discovery

Hypothesis: a solved film can become a watchlist addition or a useful where-to-watch lookup, strengthening the main app's reason to remain installed.

Experiment: existing result versus one optional Save Film / Explore Film action for the recovered movie, while retaining Play Another. Primary metric: useful discovery/watchlist action per eligible completion; guardrail: replay and D7 return. Treat this as a later, lower-confidence bet. It can outperform more game depth if movie utility is the user's core motive.

## Metric definitions and decision rules

- Eligible: assigned, stable app identity on the tested release/build, appropriate paid/unpaid status, release environment, and actual entry exposure. Report absolute counts and identity limitations.
- Genuine completion: completed outcome with skipped=false. Record help separately. Meaningful activity is a round interaction, film-detail interaction, watchlist change, or where-to-watch action. An app start/ad callback alone is not meaningful activity.
- Voluntary replay: user initiates a second fresh challenge after a completed first challenge. Forced playtest rounds are excluded.
- D1/D7: meaningful app activity on the exact next/seventh user-local calendar date after eligible exposure. Only fully elapsed dates are eligible. Report arcade-specific return separately; distinguish new install from first observed release adoption.
- Revenue window: 28 days after assignment, matured cohorts. Use consistent app/platform/territory/currency/time windows; reconcile AdMob estimated earnings and App Store net proceeds. Never mix stale dates or call requests/present attempts revenue.
- Pick one primary metric per experiment; calculate MDE/sample size from the observed baseline. Declare maturity window, stopping rule and acceptable guardrail tradeoffs before reading results. Run fewer tests sequentially at current traffic. If power is infeasible, use qualitative evidence and report uncertainty rather than manufacture significance.

## Human study

Recruit six to eight people unfamiliar with the app across low/moderate/high film knowledge. Neutral task: “Explore this app as you normally would; stop whenever you want.” Observe discovery, instruction comprehension, first success and whether another round is independently chosen. Then invite an optional next-day session without coaching or a promised reward for playing.

Ask: “What were you trying to do?”, “What did you expect after that tap?”, “What would make you come back tomorrow?”, “Which experience would you choose again?”, and, after exploring existing benefit copy, “What would you expect this purchase to change?” Collect behavior before preference ratings. Track where content is recognized as repeated and separate face/film familiarity from reasoning. Do not interpret incentivized attendance as organic retention.

## Immediate next step

Build the exposure-to-first-win measurement contract and reconcile the ad-free product promise, then conduct the small first-time study of a curated entry. This is the most useful next engineering/research package. Content freshness is the next substantive product investment; a purchase offer is gated on verified value and revenue data.
