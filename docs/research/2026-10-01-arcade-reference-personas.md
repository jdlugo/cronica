# Arcade reference personas

Created October 1, 2026 against local commit `6b249b89`. These are invented behavioral reference profiles, not interview participants, inferred market segments or demographic claims. Names are labels only. Time budgets and stopping conditions are test fixtures, not observed averages. No weighting, conversion probability, enjoyment score or retention rate is assigned.

## Personas

| ID / reference name | Job and context | Knowledge / constraints | Review scenario and explicit stopping condition | Return / purchase hypothesis to challenge |
| --- | --- | --- | --- | --- |
| P1 Sam — visual newcomer | Wants a brief, satisfying puzzle during a break; has never used Arcade | Recognizes shapes and repeated posters; little movie/year/cast knowledge; two-minute scenario budget | Discover a recommended game, solve by visual reasoning, then assess the next action. Stop if a completed visual task still requires unknown trivia to earn a result. | Matching success might earn another round; trivia gates might prevent it. Payment is irrelevant until value exists. |
| P2 Alex — repeat movie fan | Wants varied movie connections rather than a generic trivia quiz | High movie/cast knowledge; tests three rounds per featured mode and seven daily dates | Audit conceptual repetition, not just card positions or seeds. Stop the simulated scenario at the first repeated challenge and record the cause; do not pretend this predicts abandonment frequency. | Verified new connections could invite a return; memorizing the starter catalog could exhaust value. |
| P3 Jordan — interrupted routine player | Wants a short daily ritual that survives interruptions | Moderate movie knowledge; can be interrupted at any point; no timer tolerance | Complete part of a round, background/relaunch, resume, finish, reopen the summary. Stop if progress or earned points are lost or a resumed summary looks like fresh work. | Reliable continuation could support a habit; reminder preference and actual next-day return require humans. |
| P4 Casey — movie-discovery user | Installed Streaming Now to decide what to watch and maintain a watchlist | Game interest is incidental; does not want browsing displaced | Find Arcade from Home, inspect a solved-film result, look for a useful film/watchlist/where-to-watch action, then return to discovery. Stop if the round produces no useful next step for this job. | Arcade may support discovery, or add little value for this audience. More gameplay alone is not success. |
| P5 Morgan — accessible-controls player | Wants independent play with larger text and reduced motion | Uses accessibility text size; may use VoiceOver; visual recognition cannot be assumed to work through spoken labels | Inspect featured entry, Memory cards, wrong-answer feedback and result actions at accessibility sizes; audit hidden-state labels. Stop if controls become unreachable or spoken labels erase the puzzle. | Inclusion requires tested controls plus a meaningful task; layout screenshots cannot establish VoiceOver playability. |
| P6 Riley — skeptical potential buyer | Wants an enjoyable free trial and a clear optional purchase | Will consider an ad-free benefit after repeated value; sensitive to surprise ads and misleading promises | Examine launch/ad placement evidence, result-to-next-round path, Remove Ads wording, configured product and restore flow. Stop if payment is implied to finish or the promised benefit cannot be verified. | Satisfaction could precede purchase; neither a synthetic review nor a fixture price proves willingness to pay or real checkout. |
| P7 Taylor — multilingual movie viewer | Wants a tap-based movie game without English-reading friction | Comfortable recognizing images; weaker English instructions and unfamiliar with some US-centered film/cast references | Inspect language coverage and how many tasks require title, actor or release-year knowledge. Stop if correct interaction depends on untranslated instructions or unfamiliar trivia with no useful help. | Visual mechanics may broaden access, but localized reminders/purchase text do not prove localized puzzles or suitable content. |

## Eight decision questions

1. Do unfamiliar players voluntarily choose another round?
2. What makes tomorrow worth opening the app for?
3. Where do real players lose interest, and can the production funnel be trusted?
4. Which two or three games deserve further investment?
5. Are ads costing future revenue or retention before players experience value?
6. Why would a happy player pay, and does purchase/restore/ad suppression work?
7. Does Arcade strengthen movie discovery and overall app retention?
8. What is the smallest release that can answer these questions?

## Evaluation rules

- Review each profile against the same source/build and known screenshots. Record the exact flow, observable evidence, disconfirming evidence, inferred risk and next test.
- Label outcomes `observed local`, `model probe`, `source-derived`, `persona hypothesis`, `historical snapshot` or `unanswered human/live`. A scripted second round is not voluntary replay; an agent choosing to continue is not a participant.
- Use explicit constraints rather than asking an agent to improvise liking the app. Do not invent quotations, emotional responses, elapsed play times, D1/D7, willingness to pay or user counts.
- Diagnose inability to proceed separately from dislike and lack of movie knowledge. Include stopping/skip paths and users who do not want games.
- Existing simulator evidence is reusable with its date and scope. New source/model checks are not new simulator or human playthroughs.
- Any release or monetization recommendation must name its unresolved device, transaction and measurement gates. Do not recruit or contact people or change live accounts in this review.

## Bounded execution

Three agents own distinct review files, no production edits, Xcode jobs, network, commits or child agents. Handoff deadline: 13:05 UTC, October 1. Checkpoint at three minutes; blocker investigations limited to 90 seconds. Root owns reference profiles, executable model probes, evidence synthesis and the local result. Target finish around 13:12 UTC. Human and live-account questions stay open when evidence is unavailable.
