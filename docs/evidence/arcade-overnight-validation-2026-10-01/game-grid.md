# Current-source game comparison

Deterministic simulator flows use known fixture answers. These outcomes describe mechanics and layout; they are not persona playtesting, human difficulty judgments, or evidence of retention/revenue.

| Game | iPhone complete flow | iPad complete flow | Exercised behavior |
| --- | --- | --- | --- |
| Scene Spotter | Passed, 3/3 | Passed | Scene, movie choices, result and fully visible replay |
| Movie Scramble | Passed, 3/3 | Passed | Actual hold/drag swaps, termination, saved board recovery and completion |
| Casting Call | Passed, 2/3 | Passed | Wrong portrait disabled, correct portrait selected, result; controller scrolls to the lazy iPad row |
| Director's Cut | Passed, 3/3 | Passed | Chronological triple feature; separate large-text wrong-pick/relaunch recovery |
| Movie Heist | Passed, 3/3 | Passed | Three locks, recovered movie and replay; separate large-text unlocked-digit recovery |
| Before or After? | Passed, 2/3 | Passed | Wrong placement feedback, revealed years and three completed placements |
| Odd Movie Out | Passed, 2/3 | Passed | Incorrect choice, explained rule and correct conclusion |
| Double Feature | Passed, 2/3 | Passed | Mismatch, retry and three correct actor connections |
| Movie Detective | Passed, 1/3 | Passed | Player-selected clue order, help cost and completion |
| Poster Memory | Passed, 3/3 | Passed | Three matched pairs, optional trivia bypass, replay; separate matched-pair relaunch and bonus |

All ten iPhone flows reached the result and asserted the complete replay button fits inside the game sheet. The retained [iPhone result grid](iphone-all-games.jpg) shows all ten terminal states.

Additional current-source iPhone checks passed for the full library, Daily Mix score reopening, large-text Director's Cut/Heist/Memory/Scramble, Mexican Spanish Memory, structural Memory/Scramble audits, legitimate matched-pair relaunch, and both system motion settings. These do not establish physical gesture comfort or VoiceOver usability.

The iPhone main suite had **19 passed / 1 failed**, with the sole failure in the expanded-lobby structural audit. The four focused recovery/motion checks had **3 passed / 1 failed**, again solely the lobby audit. After title wrapping was fixed, two clipping findings remained without an associated element or frame. Bringing the footer fully into view did not clear them. The strict structural failure remains visible and blocks declaring a new release ready.

The broad unit/startup/settings run had **286 passed / 0 failed / 0 skipped**: 284 unit tests and two UI checks. The standalone game model had 10,606 checks, analytics 96, localization 173 keys, and the production ad-unit gate passed.

The iPad main suite had **20 passed / 1 failed / 0 skipped**, with the sole failure again in the expanded-lobby structural audit. All ten game flows, matching-pair recovery, large-text flows and Memory/Scramble structural audits passed. A final lobby-only change widens the iPad cards from three columns to two; the source-hash proof confirms the gameplay bodies are unchanged, and focused lobby/navigation checks cover that change.

Final lobby/navigation checks had **1 passed / 1 failed / 0 skipped on each device**. The named title warnings cleared; two unmapped clipping reports remain on iPhone and four on iPad. These strict failures are retained and a new upload is held. Contrast reports also remain separate review diagnostics. The [iPad result grid](ipad-all-games.jpg) crops the center sheet for readability; the result bundle retains the complete original screenshots.
