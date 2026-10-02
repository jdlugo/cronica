# Persona play review

October 1, 2026; local commit `6b249b89`. P1/P2/P3/P7 are invented reference constraints. This is a source walkthrough and inspection of saved October 1 simulator evidence, not new simulator play, interviews, or a fun/retention measurement. References below are repository paths and one-based lines.

## P1 Sam — visual newcomer

**Walkthrough:** Home → Arcade lobby → Poster Memory → reveal two cards → retain matching posters or turn a mismatch over → find three pairs → Finish round → inspect Play another / Try a different game. Compare the alternative featured Scramble path: swap four image tiles into place → select the film title.

**Evidence:** Source-derived: Memory instruction explicitly permits matching-only completion (`Shared/Model/MovieArcade.swift:56`); completion preserves earned matching points (`:243–246`, `:314–318`). Observed local, reused: `memory-optional-bonus.png` shows three matched pairs and a prominent “Finish round · 3 points” before trivia; `memory-matching-win.png` shows the earned result and next actions. The fixture test verifies matching-only completion and a scripted next round (`CronicaUITests/CronicaUITests.swift:523–535`). Images are in `docs/evidence/arcade-growth-delivery-2026-10-01/`.

**Disconfirming evidence:** The lobby highlights Daily Mix most prominently and lists Scramble before Memory (`Shared/View/Navigation/MovieArcadeView.swift:186–199`); novice discovery of Memory is untested. Scramble's visual reconstruction unlocks title choices rather than completion (`:403–406`; `Shared/Model/MovieArcade.swift:277–283`). Sam's explicit “visual task still requires unknown trivia” stopping condition therefore applies to Scramble. Help and a zero-point reveal prevent a hard trap (`MovieArcadeView.swift:261`, `:408–409`), but do not prove a satisfying earned win.

**Persona hypothesis:** Memory is the strongest demonstrated first-win route for low movie knowledge; the featured games are not equally knowledge-independent. “Optional bonus” cannot raise frozen matching points in the current model, so test what reward that label implies rather than assuming it motivates play.

**Next human test:** Unfamiliar, low-knowledge participants choose freely from the lobby. Observe chosen route, first independent success, help/skip use, and whether they voluntarily start another round. Do not direct them to Memory or equate the scripted replay with desire.

## P2 Alex — repeat movie fan

**Walkthrough:** Start each featured mode → complete → Play another twice; inspect seven date fixtures for meaningful new films/connections rather than positions. Record first repeated concept and its exact identity.

**Evidence:** Source-derived: Double Feature has seven six-film sets (`Shared/Model/MovieArcade.swift:216–223`). Practice history excludes the last two targets with at most 48 candidate attempts (`:467–488`); for Double Feature a target is the film set, for Memory/Scramble the first film. Daily Mix limits within-mix overlap (`:389–415`). Historical model comparison over 28 dates improved repeated film slots 47→24 (`docs/evidence/arcade-growth-delivery-2026-10-01/content-variety.json`); this is not a seven-day participant test.

**Disconfirming evidence:** Only 12 films exist (`Shared/Model/ArcadeCatalog.swift:6–19`). Seven Double Feature boards reuse just six distinct named actor connections. Memory history tracks one film, not its entire three-film board. Daily optimization is within a date, not across previous dates; no cross-day history appears in generation. Different seeds/layouts cannot establish new knowledge or prevent later repetition. The older transcript's Toy Story → Matrix → Toy Story repetition predates the fix and is not current failure evidence.

**Persona hypothesis:** Improved immediate variety is credible; a week of sustained novelty is unresolved and content breadth is the main constraint. Root's new deterministic persona probes should report exact repeated challenges separately from this static review.

**Next human test:** Movie fans choose three rounds and return for a week. Ask them to identify repeated facts/images and observe whether they continue; distinguish repetition they dislike from familiar material they enjoy.

## P3 Jordan — interrupted routine player

**Walkthrough:** Find one Memory pair → terminate/relaunch → reopen Memory → finish; complete Daily Mix → return to lobby → reopen today's score. Separately inspect cross-midnight and mismatch interruption boundaries.

**Evidence:** Source-derived: each accepted action persists immediately (`Shared/View/Navigation/MovieArcadeView.swift:59–64`, `:86`); incomplete practice loads instead of regenerating (`:37–44`); completed today's mix opens a summary (`:30–35`). Observed local, reused: the relaunch test retains one of three pairs (`CronicaUITests/CronicaUITests.swift:508–520`); Daily summary retains 3/12 after reopening (`:568–581` under the added large-text regression test). All 18 distinct arcade UI checks have passing evidence across runs, not one clean final suite (`docs/evidence/arcade-growth-delivery-2026-10-01/validation.json`).

**Disconfirming evidence:** Those scripted tests do not cover every card-selection/mismatch/background/force-quit state or physical-device behavior. Daily loading requires the current day (`Shared/Model/MovieArcade.swift:450–454`), so yesterday's unfinished mix is not resumed through today's Daily Mix. There is no shared Daily Puzzle streak (`MovieArcadeView.swift:214`).

**Persona hypothesis:** Same-day recovery supports a routine; cross-midnight continuity and the separate score/streak expectation need explicit product decisions.

**Next human test:** Interrupt participants after one card, mismatch, completed pairing and daily round; relaunch, then cross midnight in a controlled device test. Verify preserved board/score before asking whether the resumed task is understandable.

## P7 Taylor — multilingual movie viewer

**Walkthrough:** Inspect lobby → Memory without trivia → Scramble title guess → Double Feature actor connection → help/reveal in a supported non-English language.

**Evidence:** Source-derived: titles/instructions are English runtime strings (`Shared/Model/MovieArcade.swift:17–57`), plot/title catalog is English (`Shared/Model/ArcadeCatalog.swift:6–19`), and help includes English plot/cast/year phrases (`Shared/View/Navigation/MovieArcadeView.swift:612–620`). Representative arcade instruction/label searches found no matching localization keys in `Shared/Localization/*.lproj/Localizable.strings`. Saved screenshots are English only.

**Disconfirming evidence:** Memory requires image matching, not title/year knowledge; taps remove typing friction. Purchase/reminder localization does not establish puzzle localization, native-language comprehension, or regionally familiar films.

**Persona hypothesis:** Memory may travel best; English instructions and a Hollywood starter catalog remain access constraints.

**Next human test:** Native speakers with weaker English attempt Memory and one knowledge-dependent game without translation/coaching. Record instruction misunderstandings separately from unfamiliar films; test translated control/instruction copy before expanding trivia content.

## Root follow-up evidence

The completed model probes and their exact sampled repeat counts are in `docs/evidence/arcade-personas-2026-10-01/model-probes.json`; the synthesis is `docs/research/2026-10-01-arcade-persona-results.md`. The probes confirm same-date recovery and the next-date Daily Mix boundary, the Scramble title gate, and Memory's unchanged score after the optional correct answer. These are known-state model checks, not the voluntary playthroughs described as future human tasks above.
