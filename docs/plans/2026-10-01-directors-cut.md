# Director’s Cut and complete arcade playthroughs

## Requirements
Add a ninth free-play mini-game: arrange a three-film feature in chronological release order by tapping posters. Three distinct years, never start in sorted order, reveal years only when correctly placed, mark placed films, permit recovery after a wrong choice, avoid repeated penalties for the same wrong choice at a position, retain progress across process restart. No typing or timer. Preserve the existing Daily Mix schedule.

## Implementation
Uses the bundled catalog and pure arcade rules. Correct picks build the cut; a wrong pick is disabled until the next correct placement. Final reveal lists all three films and years in order. Accessibility layouts stack the posters; accessibility labels expose placement status. Validates restored selected positions against the chronological prefix.

## Verification
- Initial rules harness: 9,483 checks passed across 40 seeds and 10 round types.
- Full iPhone simulator completion matrix passed, without using skip: Casting Call, Movie Detective, Double Feature, Poster Memory plus year bonus, Odd Movie Out, Movie Scramble, Before or After, Movie Heist, Director’s Cut and Scene Spotter.
- New recovery scenario: wrong choice, first placement, process restart, finish remaining placements at maximum Dynamic Type.
- These are simulator interactions; no physical-device or subjective enjoyment claim. No App Store submission.

## Final results
- iPhone 17 Pro: 11/11 UI scenarios passed, zero failures. Every one of the nine mini-games plus Scene Spotter reached its completion screen; the extra scenario covered Director’s Cut recovery at maximum text size.
- iPad Air 13-inch: 2/2 new-game scenarios passed, including restart recovery and maximum text size.
- Final rules rerun: 9,483 checks passed; existing movie quiz suite passed; diff whitespace check passed.
- Inspected iPhone board and iPad normal/large-text screenshots. Evidence: `/tmp/movie-arcade-all-complete-retry.xcresult`, `/tmp/movie-directors-cut-ipad.xcresult`.
- First build stopped before testing with a simulator-watch code-signing error while disk space was about 150 MB. Removed disposable artifacts from earlier validation runs, recovered about 1 GB, verified signing and retried successfully. Signed release archives and source checkouts were retained.
