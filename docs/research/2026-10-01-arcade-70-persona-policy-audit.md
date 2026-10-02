# Policy and inference audit: 70 assigned persona scenarios

October 1, 2026. Baseline `6b8986f3`. Scope: seven explicit decision policies, ten seed-0 games each. This audit distinguishes simulator behavior from the controller's assumptions. No human participants, measured enjoyment, willingness to pay, retention or revenue are involved.

## Frozen prior knowledge

Knowledge must be declared before a cell starts and remain independent of its seed. All personas may learn facts from visible feedback during their own cell; discoveries do not transfer between cells. Control identifiers may locate a button, but a numeric film ID must never decide its answer.

P2 and P5 may use this fixed familiar-film sheet, keyed by visible title:

| Film | Year | Familiar lead |
| --- | --- | --- |
| Titanic | 1997 | Leonardo DiCaprio |
| The Matrix | 1999 | Keanu Reeves |
| Jurassic Park | 1993 | Sam Neill |
| Inception | 2010 | Leonardo DiCaprio |
| Barbie | 2023 | Margot Robbie |
| Avengers: Endgame | 2019 | Robert Downey Jr. |
| John Wick | 2014 | Keanu Reeves |
| La La Land | 2016 | Ryan Gosling |
| Avatar | 2009 | Sam Worthington |
| Interstellar | 2014 | Matthew McConaughey |
| Toy Story | 1995 | Tom Hanks |
| Back to the Future | 1985 | Michael J. Fox |

Their declared relationship knowledge additionally includes Ryan Gosling in Barbie/La La Land, Michael Caine in Inception/Interstellar, Zoe Saldaña in Avatar/Endgame, and Samuel L. Jackson in Jurassic Park/Endgame. Familiar plot concepts may identify displayed descriptions: doomed liner; simulated reality; dinosaur park; entering dreams; doll entering the human world; reunited surviving heroes; retired assassin; Los Angeles actor/jazz musician; indigenous alien-moon community; wormhole migration; threatened cowboy toy; time-travel car. This is declared expertise, not discovered player knowledge.

P3, P4 and P6 have only the sheet facts and plot concepts for Titanic, The Matrix, Jurassic Park, Inception and Toy Story. No unknown-year sorting or unrelated actor pairing is permitted without feedback. P1/P7 recognize only Toy Story, The Matrix and Jurassic Park titles; they have no declared dates or cast relationships. Their titles alone cannot identify a hidden image or a plot. If an image is identified manually, record the screenshot and visual basis; a scripted controller may not infer it from an asset filename.

## Distinct decision policies

- **P1:** visual matching; bounded help; stop at an unknown trivia gate or two failed guesses. Administrative Reveal follows the recorded stop, never earns completion.
- **P2:** use declared expertise; complete where evidence supports it; one assigned replay after an earned result. This tests replay routing, not voluntary continuation or freshness.
- **P3:** deliberately terminate/relaunch after the first accepted action; compare preserved visible progress, selections and points. A fresh launch, wrong fixture, or lost automation handle is a harness defect until isolated.
- **P4:** inspect result for a useful film detail, watchlist or availability action. Gameplay completion and absent utility are independent findings. Stop optional replay if no utility route exists.
- **P5:** accessibility XXXL with broad declared knowledge. Reachable controls and readable bounds are layout evidence; no VoiceOver, reduced-motion or nonvisual-play claim. Numeric Scramble section labels are recorded assistance.
- **P6:** moderate knowledge, one deliberate recoverable mistake only when prior knowledge justifies which option is wrong; otherwise record an exploratory guess. Inspect mandatory payment and next-round routes. Disabled ads and simulated purchases cannot answer ad tolerance, checkout, restore or pay intent.
- **P7:** Spanish locale, weak English, title recognition and matching only. Record observed English instructions before stopping at an English knowledge gate. Controller recognition of an English label is not comprehension evidence.

## Per-game falsification checks

| Game | Invalid shortcut / required distinction |
| --- | --- |
| Scene Spotter | A film ID or seed reveals no image recognition. Use a displayed plot plus declared familiarity, or a documented manual image judgment. |
| Movie Scramble | Numeric section ordering is assisted completion, not visual assembly. Restoring tiles and identifying the movie are separate gates. |
| Casting Call | Read visible film/portrait names; choose from declared credits. Recognizing a film title does not imply actor knowledge. |
| Before or After? | Visible anchor year is allowed; incoming year must be known or learned. A wrong placement may advance: terminal completion is not a correct chronology. |
| Odd Movie Out | Parse the displayed era rule. Do not use the hidden answer or assume the same rule for every seed; unknown years remain unknown. |
| Double Feature | Visible posters and declared relationships only. The engine's pair key is forbidden; correct blind guesses remain guesses. |
| Movie Detective | Record each requested clue and its point cost. Reading the final plot without opening its clue fabricates help-free recognition. |
| Poster Memory | Store identities only after visible flips. Hidden card IDs/board arrays are forbidden; matched labels may be used after they become visible. |
| Movie Heist | Treat its three locks separately. Lock one lacks a visible plot; film/asset IDs cannot supply its answer. Later facts do not retroactively explain first-lock recognition. |
| Director's Cut | Sort only known or visibly revealed years. Eliminated feedback can guide retries; a memorized seed-specific order cannot. |

## Evidence acceptance

Every cell needs its actual runtime trace, screenshots, outcome and explicit limitations. `earned`, `earned_with_help`, `revealed_after_stop`, `ui_blocked` and `automation_failed` must stay distinct. A policy stop is not dislike. Empty text, offscreen lazy controls, stale handles and a cap exceedance are not persona confusion without separate evidence. Inspect source only to diagnose mechanics after the trace; never silently substitute a predicted outcome for a missing run. Root-owned action/time caps prevent indefinite work; runtime is automation duration, not human solving time.

Static runner review found no engine, saved-state or seed oracle. Knowledge, feedback and current-title parsing fixes verified. Live image judgments require current screenshots. Monetization-suppressed fixtures cannot verify payment or ad behavior. Runtime evidence was pending at this initial static-review checkpoint; final closeout follows below.

## Runtime audit handoff, 14:59 UTC

Reviewed the saved P1–P4 traces (40 cells), P5 Casting (one cell), and the v2 controller source. P5 recovery, P6 and P7 were still running; their outcomes are outside this handoff. Earlier P5 Scene/Scramble automation failures remain preflight evidence until superseded by actual recovery traces. Mixed harness revisions must remain visible in the ledger.

| Game | Evidence from this bounded review | Actionable interpretation / limitation |
| --- | --- | --- |
| Scene Spotter | P1/P2/P4 recognized the current Toy Story image and earned 3/3. P3 earned 3/3 before forced relaunch. | Familiar image recognition supports these assigned completions. P3's completed practice opens a fresh round on relaunch; its later 0-point administrative reveal is not evidence of unfinished-progress loss. |
| Movie Scramble | P1–P4 all used Assemble for Me, then recognized the restored Toy Story image; 2/3 each. P3's observable partial state survived relaunch. | This validates the assistance route and subsequent title gate. No persona independently swapped the tiles into place, so visual assembly, its difficulty and satisfaction remain untested. |
| Casting Call | P1 stopped at missing actor knowledge. P2/P4/P5 selected Tom Hanks and earned 3/3. P3 earned before terminal relaunch. | P5 establishes reachable casting controls at XXXL only. Its trace used the original controller. No VoiceOver claim; no P3 data-loss claim. |
| Before or After? | P2 placed all three films correctly, 3/3. P1/P3/P4 stopped under declared year limits; moderate roles lacked Endgame's year. | These are knowledge-policy stops, not dislike or observed comprehension failures. P3 never reached an interruption in this cell. |
| Odd Movie Out | P2 selected Endgame and earned 3/3. P1/P3/P4 stopped under year limits. | The conservative policy requires known dates for every choice. It does not establish that humans could not infer an answer with partial familiarity. |
| Double Feature | P2 completed all three relationships, 3/3. P3/P4 matched Inception/Titanic before stopping at unknown relationships; P1 stopped immediately. | Supported actor-knowledge dependence. P3 preserved a selected card across relaunch; a policy stop is separate from the successfully connected pair. |
| Movie Detective | P1–P4 opened the plot and completed after a wrong title guess, 1/3. P3's point/progress comparison matched after relaunch. | The original static-text parser missed the grouped plot label, then recognized the phrase in wrong-answer feedback. Do not blame expert comprehension or infer clue quality from these mistakes. V2 reads the grouped displayed clue; later traces must establish its effect. |
| Poster Memory | P1–P4 learned identities after flips, found all pairs and used Finish without year trivia, 1/3 each; two mismatches each. P3 preserved its selected card. | Strongest observed completion route independent of declared film trivia. Deduplicated mistake strings are not mistake counts. Identical scripted policies do not demonstrate different cognitive skill or enjoyment. |
| Movie Heist | P2 solved all three locks, 3/3. P1/P3/P4 recognized lock one's image, then stopped at the cast gate. P3 relaunched at lock two. | The old acceptance signature misses unlocked-awaiting states; successful answers marked `accepted=false` are controller false negatives. P3 interrupted after Next Lock, not its first answer. |
| Director's Cut | P2 ordered Jurassic Park, Toy Story and Endgame correctly, 3/3. P1/P3/P4 stopped under year limits. | Correct expert routing observed. Other roles' stops are assigned knowledge constraints; no P3 recovery attempt occurred. |

All ten P2 replays were explicitly assigned starts; none were completed. App-wide result scans included underlying Home Watchlist/Explore controls and are normalized to Unknown. They cannot establish a result-to-film utility route, payment gate or discovery benefit. V2 scopes result-button scans to the Arcade content and toolbar, discovers lazy controls from their displayed labels, and uses identifiers only to reacquire those controls; no engine/save/seed answer oracle was found. Original recovery comparisons cover points, card selections and progress labels, not every clue or board state. Human appeal, ordinary unpaid ad behavior, purchases and organic return remain unanswered.

## Root final runtime closeout

The selected evidence now contains70 unique traces,215 previews and21 exact live-image captures. Original trace hashes and ordered tap counts match; every cell has start and endpoint screenshots. Finalized direct recovery and focused correction bundles each report3 passed cases. Ordinary execution skips all 11 manual cases without opt-in.

P1–P4 Detective were actually repeated with the grouped-clue correction: P1 finishes through guess/feedback at 1/3; P2/P3/P4 read their declared clue at 2/3. P5 Heist and Director's Cut were repeated after disk-full capture losses, earning3/3 with complete previews. Corrected P6 Heist remembers the visible Toy Story recognition after its assigned mistake, then reaches the unfamiliar cast gate. These supersede the earlier controller/capture attempts; no selected endpoint is a UI block or automation failure.

A later bounded reviewer checkpoint covered26 recorded P5/P6/P7 cells and representative screenshots, without waiting on missing cells. Its safeguards were retained: XXXL completion is not VoiceOver evidence; coached Spanish-locale completion is not comprehension; earlier P6 recognition loss is a controller issue; scoped scans establish only inspected controls. Root reviewed the correction traces and representative P4/P5 result screens and validated all 70programmatically. This does not claim independent human or agent experience ratings across every current cell.

P5 earned all 10rounds with broad declared knowledge atXXXL. P7 earned Scene, assisted Scramble and Memory; six reading gates remained English and Heist stopped at unfamiliar cast knowledge. P6 recovered from assigned wrong answers in Scene, assisted Scramble, Casting and Detective. In33 scoped result inspections, the recorded buttons were only Close, Games, Play another and Try a different game;37 earlier unscoped scans remain Unknown. Ads, checkout, restore and voluntary replay/return remain unanswered. Selected versions are37 initial-unversioned,26 v2 and7 v3; recorded controller differences and limitations remain explicit.
