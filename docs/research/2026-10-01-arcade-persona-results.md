# Arcade persona evaluation: results and next objectives

October 1, 2026. Baseline: local commit `6b249b89`; production behavior was not re-queried. Seven invented behavioral references were reviewed by three capped agents, with root-owned deterministic model probes and a focused simulator check. All review agents finished before their 13:05 UTC deadline. This is an executed synthetic inspection, not seven participants or a human usability study.

## Decision

Keep the current smaller entry and Memory's matching-only completion as candidates for human testing. Prioritize first-win clarity, meaningful content freshness, accessible evidence and a useful connection to movie discovery. Verify transactions and production events before testing an offer or interpreting revenue. The review supplies concrete failure scenarios; it does not rank what real people enjoy.

## Evidence legend

`Model` means executable rules/state checks. `Simulator` means a recorded local UI test with its date/device. `Source` means inspected implementation, without a reproduced live failure. `Hypothesis` means a consequence predicted from an invented constraint. `Open` means human, device, production or account evidence is required. There are no simulated enjoyment scores, user quotes, willingness-to-pay probabilities or retention estimates.

## Reference-persona outcomes

| Persona | Executed inspection / evidence | Constraint outcome and limit | Next discriminating test |
| --- | --- | --- | --- |
| P1 Sam: visual newcomer | Model: Memory finishes without a year answer and preserves matching points after a wrong answer. Scramble's restored board still requires a title guess; revealing instead yields zero points. Existing standard-size simulator Memory finish passed. | Memory supports the declared no-trivia route. Scramble reaches the scenario's trivia stopping condition. Neither result establishes satisfaction or voluntary replay. | Observe an unfamiliar, low-movie-knowledge person completing both without coaching; see whether assembly feels like a win and whether another round is independently selected. |
| P2 Alex: repeat fan | Model: seven days / 28 Daily Mix rounds include all 12 films by October 4 and 26 distinct mechanical signatures, with two repeats. Separate 12-round practice samples: Scramble 9 signatures, first repeat round 7; Memory 12, no repeated set in that sample; Double Feature 7, first repeat round 8. | Improved permutations have a finite novelty budget. A signature is an explicit mechanical proxy, not proof of perceived novelty or annoyance. Samples are forced generation, not organic replay. | Let a returning player identify what feels new/repeated and choose an optional next-day session; do not promise an endless catalog. |
| P3 Jordan: interrupted routine | Model: exact partial Daily Mix reload succeeds on the same date; requesting it the next date returns nil. Partial practice card selection reloads. Existing simulator recovery/summary checks cover specific states. | Same-day continuity supported. Overnight Daily Mix carryover is unavailable under current load rules, which may be intentional. No broad interruption or reminder-success claim. | Interrupt before/after a match and at a daily boundary on a device; ask whether users expect yesterday's round to remain available and compare completion versus starting today's mix. |
| P4 Casey: discovery-first | Source: solved-film results offer replay/progression and reveal, but no film details, watchlist or availability action. Home places Arcade before several discovery sections. | Scenario lacks its desired utility action. This does not prove discovery harm; returning to Home remains possible. | Give a discovery-oriented participant their ordinary watch-finding task; observe whether Arcade helps. Then test one optional Explore Film bridge with correct routing and a preserved earned result. |
| P5 Morgan: accessible controls | Source: adaptive text/grid layouts, state-aware Memory labels, explicit retry and reduced-motion paths. Existing large-text evidence covers four modes. Focused new Memory accessibility-XXXL result recorded below. Heist's first scene is hidden from accessibility with no equivalent textual clue; Scramble's section labels change the spoken task to numeric ordering. | Separate large-text, motion and VoiceOver cases. Source does not establish spoken focus, announcements or independent nonvisual play. | Real VoiceOver traversal of Memory, Scramble and Heist lock 1; separately inspect large text and Reduce Motion, with wrong answer, retry, result, relaunch and dismissal. |
| P6 Riley: skeptical buyer | Source/static: optional Remove Ads wording and local non-consumable product agree; completion is free. Restore suppresses sync errors; entitlement refresh does not directly reset/persist the paid flag. Foreground ad gating has no first-value condition. | Checkout/restore, revoked entitlement and promised live suppression remain open. These are source-derived risks, not reproduced purchase failures or evidence of pay intent. Existing fixture play suppresses monetization. | Test real catalog/price, purchase/cancel/pending/error, clean-install restore, relaunch, revocation and all ad placements; separately observe a normal unpaid first launch. |
| P7 Taylor: multilingual viewer | Source: tap interaction and imagery reduce typing; Arcade instructions, clues and starter catalog remain English. Purchase/push translations do not establish puzzle translation. | Translation and movie familiarity are distinct possible barriers. No native-language play session occurred. | Compare unfamiliar-film visual play with familiar-film English play; then review translated instructions with a native speaker. Attribute the obstacle before expanding languages or regional packs. |

The Memory question called an “optional bonus” currently adds no extra points. The model confirms both matching-only and correct-year completion award the frozen matching score. Treat “bonus” comprehension as a copy/reward hypothesis rather than asserting players are misled.

## Answers to the eight founder questions

| Question | What the executed review can answer | What remains open / decision evidence |
| --- | --- | --- |
| 1. Voluntary second round? | Completion and replay routes exist; one featured visual task retains a trivia gate. | Human unprompted continuation. A scripted replay is excluded. |
| 2. Tomorrow's reason? | Catalog exposure and sampled mechanical repetition are quantified; daily rotation exists. | Perceived freshness, improving skill and actual desire to return. Seeing all films does not exhaust every possible challenge. |
| 3. Where do players leave / funnel trust? | Local schema/identity contract and prior analytics checks exist; candidate friction points are identified. | Reconciled real-device events and eligible production counts. Do not infer drop-off from these persona stop rules. |
| 4. Which games deserve investment? | Memory, Scramble and connections offer distinct candidate mechanics with concrete constraints. | Preference and independent replay by real people; no winner declared. |
| 5. Ad trade-off? | Source lacks a first-value gate; historical evaluation saw a test ad before Home. | Current unpaid behavior, attributable earnings and a separate mature ad-policy comparison. No fresh revenue query occurred. |
| 6. Paid benefit works? | Accurate local promise/configuration; specific recovery/entitlement questions. | Actual transaction, restoration and benefit delivery; comprehension before conversion. |
| 7. Strengthens discovery? | Direct result-to-film bridge is absent. | Useful watchlist/detail/availability actions and whole-app return, including users who ignore Arcade. |
| 8. Smallest useful release? | Existing scoped build plus evidence reconciliation can support a small study. | Device/layout, spoken accessibility, actual transactions and release gates. No additional game is required to answer the first questions. |

## Prioritized objectives

These are proposals from this inspection, not implemented fixes or proven growth bets.

| Order | Objective / owner | Smallest next action | Acceptance and stop rule |
| --- | --- | --- | --- |
| P0 | Trust the value promise and measurement / engineering + account owner | Reproduce purchase/restore/entitlement cases and one known production event trace; add clear recovery only where gaps are confirmed. Audit Heist's missing nonvisual clue before claiming accessible play. | Successful benefit delivery and reconciled transitions, with cancellation/error/unknown states visible. No upsell experiment while a benefit or funnel cannot be verified. |
| P1 | Earn a visual first win / product + engineering | Test assembly as Scramble's payoff with optional title knowledge; clarify Memory's “bonus” wording/reward. First use existing flows in neutral study; prototype only after observing comprehension. | First independent success and voluntary continuation recorded, including people who stop. Retire the variant if trivia removal erases the desired challenge without reducing confusion. |
| P2 | Sustain one fresh week / content + product | Curate a week with explicit repeated-film/relationship constraints and effort budget; prioritize new meaningful content over a new mode. | Valid unique answers and observed freshness; specify weekly maintenance cost. Revise if people recognize equivalent challenges or the content cost cannot be maintained. |
| P3 | Make a solved film useful / product + engineering | One optional Explore Film result action with existing detail routing; keep replay prominent. | Correct movie, back preserves result, useful discovery action, and no repeated replay/discovery obstruction in observation. |
| P4 | Broaden access where it matters / design + localization | Separate VoiceOver, large text, motion, translation and film familiarity tasks. Fix demonstrated barriers; localize instructions before claiming localized puzzles. | Independent controls and equivalent puzzle evidence verified in each tested condition. Do not infer market demand from translated text alone. |

## Executed test ledger

- New deterministic probe: `bash scripts/test_arcade_personas.sh`; **70 asserted checks passed**. Raw seven-date rows, 36 generated practice samples and declared signature semantics are saved in `docs/evidence/arcade-personas-2026-10-01/model-probes.json`.
- Direct model inspection supplies matching identities and correct answers to reach preconditions. It does not simulate a novice's memory, expertise, reading speed or time budget.
- Reused baseline: combined iPhone simulator build and 18 distinct arcade UI checks with passing evidence across the October 1 full/focused runs. No clean second full-suite claim. Prior 9,759 model and 87 analytics checks are historical validation of the unchanged product source, not rerun counts for this review.
- New focused UI check: `testArcadeMemoryLargeTextCanFinishWithoutTrivia`, iPhone 17 Pro/iOS 26.3, accessibility XXXL: **1 passed, 0 failed**, with matching-only completion, full points, title bounds and reachable replay. Exact result and two inspected screenshots are recorded in the accompanying evidence ledger. It is a functional/layout check, not a VoiceOver or human-play result; the featured lobby remains untested at this size in this review.
- Three independent review documents cover all seven profiles. Their source-derived findings were reconciled against current files; no live account, interview or production analytics query was performed.
- A final 90-second adversarial pass corrected “catalog exhaustion” to “catalog exposure”: the sampled repeats do not exhaust all combinations or prove perceived novelty. No other unsupported behavior claim was found in that bounded pass.

## Next real-study tasks

Use 6–8 unfamiliar participants with contrasting movie knowledge and motivations; recruit a separate relevant accessibility participant if the sample cannot cover that condition. This is qualitative convenience sampling, not a representative cohort or powered experiment. Compensation must not depend on completion or returning.

1. Neutral discovery: “Explore this app as you normally would. You can stop whenever you want.” Do not mention Arcade until independent discovery has been recorded. Record exposure, attempts, assistance and stopping as well as completion.
2. If a relevant route was not reached, record that before assigning a focused Memory/Scramble task. Separate unaided results from assigned/coached tasks; counterbalance assigned game order.
3. Offer a genuine interruption/relaunch scenario and ask expectations around the daily boundary. Do not coach the recovery route.
4. Observe an ordinary film-discovery task and optional second fresh round. Ask what they expected after taps and what felt repeated, rather than telling them the intended improvement.
5. After free play, show the actual purchase page and ask what it changes; separate comprehension from hypothetical price preference and a verified transaction.
6. Invite an optional next-day session without a return-specific reward. Record the choice and reason; recruited attendance is not organic D1 retention.

For each session record build/device, familiarity, scenario, independent versus assigned/coached actions, first success, skip/help/error, stopping reason, independent second round, useful movie action, purchase comprehension and optional return. No invented time threshold becomes a release target. After each few sessions prioritize reproduced blockers, then predeclare the metric, eligibility, maturity window and trade-offs for any adequately powered production experiment.
