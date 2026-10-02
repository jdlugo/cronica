# Movie image quiz — September 30, 2026

User-authorized replacement of typed emoji guessing with movie imagery and four tap answers. The existing three-round Daily Run now records points, first-try answers, and a separate participation streak. Wrong choices are disabled and reveal a clue; reveal-answer lets players continue without solve credit. Results show title, poster when available, and existing factual hints. The archive uses the same input flow. The difficulty survey is collapsed below results so it does not obstruct completion.

Online alternatives come from localized popular titles for the first round, a mix of popular/recommended titles for the second, and recommendations for the third. This is a difficulty heuristic, not a measured or editorially guaranteed difficulty rating. Answer sets exclude duplicate IDs, equivalent titles, and known aliases of the answer; order and progress persist. Continuation excludes both puzzle IDs and films already seen in the session. Prior solved history cannot auto-complete a new continuation round.

Quiz media/catalog requests are parallel and bounded to eight seconds each. Images tagged with a language are excluded from remote clues to reduce title giveaways. The first six familiar films have bundled images and reveal posters; other unavailable images explicitly fall back to text clues. This does not introduce a new backend contract or require a server deployment. Existing localized daily records and push schedules remain compatible. UI and reminder copy covers English, French, Mexican Spanish and Brazilian Portuguese.

## Bundled imagery provenance

Downloaded from TMDb on September 30, 2026. Backdrops use w780; reveal posters use w342. Existing app TMDb attribution remains in place. Each film page identifies the source; image paths below identify the exact assets.

| Film ID | TMDb source | Backdrop path | Poster path |
|---|---|---|---|
| 597 | https://www.themoviedb.org/movie/597 | `/xXCuto8YVp5RFqBJ7yKmVmLOWpF.jpg` | `/9xjZS2rlVxm8SFx8kPC3aIGCOYQ.jpg` |
| 603 | https://www.themoviedb.org/movie/603 | `/tlm8UkiQsitc8rSuIAscQDCnP8d.jpg` | `/dXNAPwY7VrqMAo51EKhhCJfaGb5.jpg` |
| 329 | https://www.themoviedb.org/movie/329 | `/4SyDTF02R5BepqSdQmOaNCHObzF.jpg` | `/d9mtMGQDLANKieb9PbD3yK7xxzo.jpg` |
| 27205 | https://www.themoviedb.org/movie/27205 | `/8ZTVqvKDQ8emSGUEMjsS4yHAwrp.jpg` | `/xlaY2zyzMfkhk0HSC5VUwzoZPU1.jpg` |
| 346698 | https://www.themoviedb.org/movie/346698 | `/1esAE8sLJRWWFsLLeh5r3g2WanI.jpg` | `/iuFNMS8U5cb6xfzi51Dbkovj7vM.jpg` |
| 299534 | https://www.themoviedb.org/movie/299534 | `/7RyHsO4yDXtBv1zUU3mTpHeQ0d5.jpg` | `/ulzhLuWrPK07P1YkdWQLZnQh1JL.jpg` |

## Validation

- The initial model checks failed before implementation, then passed for unique stable choices, invalid/repeated taps, clues, scoring, persistence, reveal-answer and daily participation boundaries. Command: `bash scripts/test_movie_quiz.sh`.
- A live French TMDb response for film 550 decoded successfully using the production media model, selecting a textless image and producing four unique choices.
- Expanded simulator validation passed 263 tests (254 unit tests and nine UI tests). After the final cleanup and duplicate-film regression test, a focused rerun passed all 31 service/UI tests with zero failures or skips. Results: `/tmp/movie-quiz-validation.xcresult` and `/tmp/movie-quiz-final-ui.xcresult`.
- Final screenshots were inspected: all four answers fit on screen, and the completed run shows its poster, score, participation streak, sharing and continuation before the collapsed survey.
- The standalone quiz harness and existing notification scheduling regression harness passed. All four changed localization files passed `plutil -lint`; `git diff --check` passed.

No upload, deployment, or App Store submission is part of this implementation.
