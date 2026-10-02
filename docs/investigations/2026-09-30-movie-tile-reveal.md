# Movie tile reveal

The image is now a playable clue: a 3×3 cover starts with its center open, each tap uncovers a chosen tile, and a correct answer clears the remaining covers in a short staggered animation. The player can uncover the entire image or reveal the answer without a timer or lives. Four title choices remain visible below the image.

## Scoring and compatibility

One to three visible tiles offer three points, four to six offer two, and seven to nine offer one. Wrong guesses and requested text clues reduce the available score, with a minimum of one for a correct tiled answer. Skips earn zero. Tile choices persist on reopening. Prior saved quizzes without tile state retain their full image and original scoring; completed results are immutable.

Unavailable imagery falls back to factual text clues without charging for an automatic hint. Images fit inside the canvas to preserve their complete frame. Covered tiles have numbered accessibility labels and a full-image button; Reduced Motion suppresses tile animation and confetti. Copy is localized in English, French, Mexican Spanish, and Brazilian Portuguese.

## Analytics

`movie_quiz_tile_revealed` includes tile index, total revealed count and available points. Answer events include revealed count, whether tile mode is active and whether imagery failed. Use these to evaluate recognition difficulty alongside completion and repeat play; passing tests does not establish engagement improvements.

## Validation

- Pure Swift harness covers score thresholds, invalid/repeated taps, persistence, legacy decoding and terminal immutability.
- Simulator tests cover reopening a partially uncovered image and the full-image assist, alongside existing quiz and continuation scenarios.
- Final simulator run passed all 70 tests: 59 service/view-model and 11 UI tests, zero failures/skips. Result bundle: `/tmp/tile-reveal-final.xcresult`.
- The first run caught a tile accessibility identifier inherited from the image container. Removing the container identifier restored individual targeting; the unchanged failing interaction test passed in the final run.
- Final partially revealed and solved screenshots were visually inspected. All four localizations passed `plutil -lint`; the standalone quiz harness and `git diff --check` passed.
- Unsolved archive thumbnails stay covered; archive star totals use reveal scores while preserving imported legacy ratings.

## Zoom-out follow-up

New second rounds use a close-up instead of tiles, with three centered image scales: 3×, 1.8×, and the complete frame. Each zoom-out lowers the maximum score by one, retaining the one-point correct-answer minimum. The image smoothly widens on request and fully reveals on completion; Reduced Motion removes the animation. The first and third rounds retain tiles. Persisted pre-existing rounds keep their original reveal mode.

Clue and zoom buttons stop advertising a point cost when another assist cannot lower the score. The clue caption also respects the original zero-point floor of older saved quizzes. Zoom state and reveal analytics persist just like tile progress. Shuffled-image modes remain future work.

Zoom follow-up: all 52 tests passed (40 view-model and 12 UI), including the mixed tiles/zoom/tiles sequence and the one-point full-image result. The pure Swift harness, four localization lint checks and diff checks passed. Screenshot review caught confetti persisting into the next question; resetting the celebration subtree for each puzzle addresses that transition. Both targeted transition tests passed after that change (`/tmp/movie-zoom-clean-transition.xcresult`); the new close-up screenshot was inspected and no longer has leftover confetti.

## Additional polish

The full-image assist now discloses its resulting score before the tap. Individual tile accessibility hints describe the resulting score too. Reveal controls switch to a vertical arrangement when their natural text widths do not fit, including larger accessibility text sizes. Correct and incorrect answers have distinct haptic feedback. Missing-image fallback no longer repeats the same clues above the choices.

Validation: 12 normal-size UI regression checks passed, including the free-clue assertion at the one-point floor. The initial XXXL test checked state before the update finished; an explicit status wait passed on rerun. The scrolling helper was also strengthened to bring the full control into view, and the final targeted XXXL playthrough passed (`/tmp/movie-polish-large-final.xcresult`). Its screenshot was visually inspected. The standalone scoring harness, all four localization lints, and diff checks passed.

## Four-round daily run

The daily run now contains four puzzles, alternating tiles and zoom-out. The maximum score derives from the configured round count (4 × 3 = 12) in both the results and sharing text. Completion, weekly participation and the daily run share action remain behind the completed-run check, so finishing three puzzles no longer awards a completed run. Continued play starts another four-round run. Previously saved per-puzzle progress and reveal modes remain compatible.

Four-round validation passed all 61 tests (48 run-state/view-model and 13 UI), including no early completion after the third puzzle, 12/12 and 4/4 results, continued play, and large text. Result bundle: `/tmp/four-round-quiz.xcresult`. The summary screenshot was inspected. The standalone scoring harness, all four localization lints and diff checks also passed.
