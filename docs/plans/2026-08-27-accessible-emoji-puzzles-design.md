# Accessible Emoji Puzzle Design

## Goal

Increase guess participation by making the puzzle catalog approachable to casual movie viewers. The target mix is 85% easy puzzles and 15% medium puzzles, with no intentionally hard puzzles.

## Difficulty policy

- Choose globally recognizable movies with broad theatrical, franchise, family, or cultural reach.
- Use three to five emojis tied directly to the title, iconic characters, or central premise.
- Require at least two obvious associations with the answer.
- Avoid minor scenes, actor references, abstract symbolism, and details only dedicated fans would know.
- Make the first hint immediately useful and the second nearly decisive without including title words.
- Accept common shortened titles, punctuation variants, and regional titles.

## Implementation

- Rebalance seven hard archive entries with accessible animated movies.
- Apply the same replacements to the manual Firestore seed catalog.
- Strengthen the OpenAI generation prompt so future clues follow the accessibility policy.
- Weight TMDb lifetime vote count more heavily than short-term popularity and raise recognition thresholds.

## Measurement

Compare `daily_puzzle_guess_submitted / daily_puzzle_session_started`, solve rate, attempts per solve, hint use, and return sessions by build. The first success criterion is a material increase from the current 10% session-to-guess baseline without reducing puzzle opens.
