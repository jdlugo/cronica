# Arcade persona playthrough findings

This is the pre-improvement baseline. The subsequent [guided-play delivery and validation](2026-10-01-arcade-guided-play-validation.md) changes the starting choices, adds knowledge help and Spanish copy, and records fresh visual Scramble play. The 70 original cells remain unchanged as historical evidence.

Seven assigned persona policies were actually executed against all ten games in the iPhone simulator. The selected comparison contains **70 unique runtime traces and 215 screenshot previews**, with matching original trace checksums and no missing cells. These are synthetic, coached simulator scenarios, not human interviews, enjoyment scores or retention/revenue measurements.

[Interactive grid](../evidence/arcade-70-playthroughs-2026-10-01/index.html) · [CSV comparison](../evidence/arcade-70-playthroughs-2026-10-01/comparison.csv) · [Evidence and reproducibility](../evidence/arcade-70-playthroughs-2026-10-01/README.md) · [Frozen policies](2026-10-01-arcade-70-playthrough-protocol.md)

## Comparison

C = completed without requested help; H = completed with help; S = declared knowledge/language stop followed by administrative reveal. C* = earned 3/3 before forced relaunch, then completed practice intentionally opened fresh. A completion can include mistakes and reduced points. Stops are not dislike or product defects.

P1 Sam: visual newcomer; P2 Alex: movie fan; P3 Jordan: interrupted player; P4 Casey: movie discovery; P5 Morgan: XXXL text; P6 Riley: skeptical buyer; P7 Taylor: Spanish locale, weaker English.

| Game | P1 | P2 | P3 | P4 | P5 | P6 | P7 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Scene Spotter | C | C | C* | C | C | C | C |
| Movie Scramble | H | H | H | H | H | H | H |
| Casting Call | S | C | C* | C | C | C | S |
| Before or After? | S | C | S | S | C | S | S |
| Odd Movie Out | S | C | S | S | C | S | S |
| Double Feature | S | C | S | S | C | S | S |
| Movie Detective | H | H | H | H | H | H | S |
| Poster Memory | C | C | C | C | C | C | C |
| Movie Heist | S | C | S | S | C | S | S |
| Director’s Cut | S | C | S | S | C | S | S |

The raw terminal outcomes are 27 earned, 13 earned with help and 30 stops/reveals. Two of those later stops followed the already-earned P3 results, so 42 cells reached an earned result at some point. No selected cell ended as a UI block or automation failure. This is a count of assigned fixtures, not a population success rate.

## Findings game by game

### Scene Spotter

All seven policies recognized the current Toy Story image and earned a result, including P3 before its forced terminal relaunch. P6 recovered from one assigned wrong answer. This fixture is a quick recognition task, often one answer tap; it does not establish challenging puzzle depth or sustained replay.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-scene.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-scene.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-scene.json) | C* | 0/3 points | 1 / 0 | Earned 3/3 first; forced relaunch intentionally opened fresh practice |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-scene.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-scene.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-scene.json) | C | 2/3 points | 2 / 0 | Earned result |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-scene.json) | C | 3/3 points | 1 / 0 | Earned result |

### Movie Scramble

All seven completed with Assemble for Me, followed by recognition of the restored image. P6 also recovered from its assigned wrong guess. No persona independently swapped the tiles into place. The assistance route works; unaided visual assembly and its appeal remain untested.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-scramble.json) | H | 2/3 points | 2 / 1 | Earned result |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-scramble.json) | H | 2/3 points | 2 / 1 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-scramble.json) | H | 2/3 points | 2 / 1 | Earned result; compared visible state preserved |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-scramble.json) | H | 2/3 points | 2 / 1 | Earned result |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-scramble.json) | H | 2/3 points | 2 / 1 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-scramble.json) | H | 1/3 points | 3 / 1 | Earned result |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-scramble.json) | H | 2/3 points | 2 / 1 | Earned result |

### Casting Call

P2/P4/P5/P6 earned results, and P3 earned before terminal relaunch. P1 stopped at actor knowledge; P7 stopped at English instructions. P6 recovered from an assigned wrong actor choice. Familiar-film recognition alone does not unlock the cast task.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-casting.json) | S | 0/3 points | 0 / 0 | Actor knowledge required beyond title recognition |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-casting.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-casting.json) | C* | 0/3 points | 1 / 0 | Earned 3/3 first; forced relaunch intentionally opened fresh practice |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-casting.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-casting.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-casting.json) | C | 2/3 points | 2 / 0 | Earned result |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-casting.json) | S | 0/3 points | 0 / 0 | Untranslated English knowledge-dependent instructions |

### Before or After?

P2/P5 correctly placed all three films before or after the visible anchor, 3/3. The other five stopped under year or language limits; moderate profiles did not know the incoming Endgame year. The anchor supplies context, but cannot supply an unknown incoming date.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-timeline.json) | S | 0/3 points | 0 / 0 | Before/after year knowledge required |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-timeline.json) | C | 3/3 points | 5 / 0 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-timeline.json) | S | 0/3 points | 0 / 0 | Incoming title/year outside declared knowledge: Avengers: Endgame |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-timeline.json) | S | 0/3 points | 0 / 0 | Incoming title/year outside declared knowledge: Avengers: Endgame |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-timeline.json) | C | 3/3 points | 5 / 0 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-timeline.json) | S | 0/3 points | 0 / 0 | Incoming title/year outside declared knowledge: Avengers: Endgame |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-timeline.json) | S | 0/3 points | 0 / 0 | Untranslated English knowledge-dependent instructions |

### Odd Movie Out

P2/P5 selected the out-of-era movie and earned 3/3. The other five stopped under declared year or language limits. The policy conservatively requires known years for every option; this does not prove a person with partial familiarity could not infer the answer.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-oddOneOut.json) | S | 0/3 points | 0 / 0 | Release-era trivia outside declared knowledge |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-oddOneOut.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-oddOneOut.json) | S | 0/3 points | 0 / 0 | One or more release years outside declared knowledge |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-oddOneOut.json) | S | 0/3 points | 0 / 0 | One or more release years outside declared knowledge |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-oddOneOut.json) | C | 3/3 points | 1 / 0 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-oddOneOut.json) | S | 0/3 points | 0 / 0 | One or more release years outside declared knowledge |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-oddOneOut.json) | S | 0/3 points | 0 / 0 | Untranslated English knowledge-dependent instructions |

### Double Feature

P2/P5 completed all three relationships. P3/P4/P6 connected the familiar Titanic/Inception pair, then stopped at unknown relationships; P6 first exercised mismatch feedback. P1/P7 stopped at knowledge or language requirements. A graduated relationship clue is an actionable hypothesis.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-doubleFeature.json) | S | 0/3 points | 0 / 0 | Shared-actor knowledge required; persona has title recognition only |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-doubleFeature.json) | C | 3/3 points | 6 / 0 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-doubleFeature.json) | S | 0/3 points | 2 / 0 | Remaining connection outside declared actor knowledge; compared visible state preserved |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-doubleFeature.json) | S | 0/3 points | 2 / 0 | Remaining connection outside declared actor knowledge |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-doubleFeature.json) | C | 3/3 points | 6 / 0 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-doubleFeature.json) | S | 0/3 points | 5 / 0 | Remaining connection outside declared actor knowledge |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-doubleFeature.json) | S | 0/3 points | 0 / 0 | Untranslated English knowledge-dependent instructions |

### Movie Detective

Six English-locale profiles completed after opening the plot clue. Corrected P2/P3/P4 and P5 identified the film directly from declared plot familiarity and earned 2/3; P1 guessed then used feedback, while P6 deliberately guessed wrong first, each ending at 1/3. P7 stopped at the English plot. Earlier parser mistakes were superseded and are not player-confusion evidence.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-detective.json) | H | 1/3 points | 3 / 1 | Earned result |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-detective.json) | H | 2/3 points | 2 / 1 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-detective.json) | H | 2/3 points | 2 / 1 | Earned result; compared visible state preserved |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-detective.json) | H | 2/3 points | 2 / 1 | Earned result |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-detective.json) | H | 2/3 points | 2 / 1 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-detective.json) | H | 1/3 points | 3 / 1 | Earned result |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-detective.json) | S | 0/3 points | 1 / 1 | Plot clue is untranslated English; no declared native-language inference |

### Poster Memory

All seven learned identities after actual flips, matched all three pairs and finished without optional year trivia. Each scripted policy made two mismatches and earned 1/3. This is the broadest complete puzzle path in these constrained runs; it does not establish different human memory skills or voluntary replay.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-memory.json) | C | 1/3 points | 13 / 0 | Earned result |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-memory.json) | C | 1/3 points | 13 / 0 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-memory.json) | C | 1/3 points | 13 / 0 | Earned result; compared visible state preserved |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-memory.json) | C | 1/3 points | 13 / 0 | Earned result |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-memory.json) | C | 1/3 points | 13 / 0 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-memory.json) | C | 1/3 points | 13 / 0 | Earned result |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-memory.json) | C | 1/3 points | 13 / 0 | Earned result |

### Movie Heist

P2/P5 solved all three locks and earned 3/3. P1/P3/P4/P6/P7 recognized lock one, then stopped at an unfamiliar cast task. Corrected P6 retained its actual visual recognition after the assigned wrong guess and progressed to that cast boundary. The mixed-lock structure is observable; how much players enjoy the gate remains a human question.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-heist.json) | S | 0/3 points | 2 / 0 | Heist cast lock requires unknown actor knowledge |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-heist.json) | C | 3/3 points | 5 / 0 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-heist.json) | S | 0/3 points | 2 / 0 | Displayed film/cast outside declared actor knowledge; compared visible state preserved |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-heist.json) | S | 0/3 points | 2 / 0 | Displayed film/cast outside declared actor knowledge |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-heist.json) | C | 3/3 points | 5 / 0 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-heist.json) | S | 0/3 points | 3 / 0 | Displayed film/cast outside declared actor knowledge |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-heist.json) | S | 0/3 points | 2 / 0 | Heist cast lock requires unknown actor knowledge |

### Director’s Cut

P2/P5 ordered the three known release years correctly and earned 3/3. The other five stopped under year or language limits. This supports advanced film-knowledge routing. Conceptual variety versus the two other chronology games was not tested over repeated rounds.

| Persona | Recorded endpoint | Points | Gameplay taps / help | Stop or recovery evidence |
| --- | --- | --- | --- | --- |
| [P1 Sam · visual newcomer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P1-directorsCut.json) | S | 0/3 points | 0 / 0 | Chronological release knowledge required |
| [P2 Alex · movie fan](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P2-directorsCut.json) | C | 3/3 points | 3 / 0 | Earned result |
| [P3 Jordan · interrupted player](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P3-directorsCut.json) | S | 0/3 points | 0 / 0 | Chronology includes a title/year outside declared knowledge |
| [P4 Casey · discovery first](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P4-directorsCut.json) | S | 0/3 points | 0 / 0 | Chronology includes a title/year outside declared knowledge |
| [P5 Morgan · larger text](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P5-directorsCut.json) | C | 3/3 points | 3 / 0 | Earned result |
| [P6 Riley · skeptical buyer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P6-directorsCut.json) | S | 0/3 points | 0 / 0 | Chronology includes a title/year outside declared knowledge |
| [P7 Taylor · multilingual viewer](../evidence/arcade-70-playthroughs-2026-10-01/traces/persona-cell-P7-directorsCut.json) | S | 0/3 points | 0 / 0 | Untranslated English knowledge-dependent instructions |

## Prioritized objectives from these observations

1. **Use Memory and Scene Spotter as the initial paths to validate.** Every assigned profile reached an earned result; Memory adds a full matching loop without film-fact prerequisites. Ask real first-time players whether they choose another round. The one-tap Scene result alone does not establish stickiness.
2. **Bridge unfamiliar trivia with useful clues.** Double Feature leaves moderate profiles after one known relationship, and Heist stops them after a successful image lock. Test a relationship clue or an alternate visual lock that lets unfamiliar players finish meaningful work.
3. **Localize game instructions, clues and feedback.** P7 recorded six explicit English reading gates, plus the unfamiliar cast gate in Heist. English controls remain visible even in completed visual games; coached completion is not Spanish usability proof.
4. **Validate unaided Scramble and repeated content before promoting them.** These runs used assistance in every Scramble and only one seed per game. Three consecutive rounds and multiple daily dates still need an actual content-variety check.
5. **Connect solved films to movie discovery, then verify the commercial path.** In 33 explicitly scoped result inspections, no film utility or payment button was found among inspected controls; 37 earlier unscoped scans remain Unknown. P4's observed result offers Play another and Try a different game; no watchlist/availability route was exercised. A direct useful film action is a hypothesis to test, not an established retention or revenue benefit. Ordinary ads, purchase, restore and pay intent remain untested here.

## Practical limits

All modes used isolated seed0 fixtures with onboarding and ads suppressed. P2's ten replay starts were assigned and unfinished; tomorrow's return and content variety are unknown. P5 establishes reachable XXXL controls in these ten rounds, with considerable scrolling in observed screens; VoiceOver, reduced motion and iPad were not exercised. P3 has five matching partial observable-state comparisons, three knowledge stops before interruption, and two already-terminal results. The old Heist accepted-action proxy misses awaiting-next-lock changes; use ordered taps, progress and results rather than its accepted-action count.

Early controller gaps were corrected with actual repeats, and superseded traces/captures remain in preflight. Larger-text lazy-choice failures, the old Detective clue parser, the forgotten P6 Heist image judgment and lost disk-full captures are tooling issues, not evidence that players found the game confusing. The protocol's original 40-minute root target was exceeded; agents remained bounded, while serial simulator execution and these corrections required longer. No production game code, live account, release submission or purchase changed.
