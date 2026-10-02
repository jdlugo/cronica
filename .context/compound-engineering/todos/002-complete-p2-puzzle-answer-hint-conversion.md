---
status: complete
priority: p2
issue_id: "002"
tags: [puzzles, revenue, localization]
dependencies: []
---
# Answer acceptance and contextual rewarded hints
## Problem Statement
Correct known regional titles can be rejected outside the selected display locale. Optional hints are separated from wrong-answer feedback.
## Findings
Canonical matching only checks acceptedAnswers. Applying a localization unions only that locale. Hint ads are already opt-in with earned-reward callbacks and no interstitial substitution. Free hints unlock at two/four attempts.
## Proposed Solutions
Union known titles/aliases for matching without fuzzy matching or changed display language. Place the existing optional offer beside wrong-guess feedback; retain free hints and ad gating. Bind callbacks to the requested puzzle and hint level.
## Recommended Action
Implement the small client-only change for 4.25.42; measure with existing offer/open/completion/ad events. No production experiment or revenue lift is claimed.
## Acceptance Criteria
- [x] Reproduce known-title rejection and terminal-state reward defect.
- [x] Accept canonical and all provided regional aliases without accepting sequel mismatches.
- [x] Offer localized, opt-in hints beside wrong feedback; preserve free hints.
- [x] Guard stale/duplicate reward callbacks and retain conversion events.
- [x] Run relevant iOS tests and record results.
## Work Log
2026-09-28: User authorized answer-acceptance and rewarded-hint placement work.

2026-09-28: Implemented matching against all supplied titles/aliases, contextual localized hint offer, and reward target/level guards. Reproduced regional-title rejection and terminal reward defect before fixing. Verified 88 passing tests (87 unit, 1 UI), no failures or skips, in /tmp/puzzle-revenue-green.xcresult. UI screenshot reviewed: offer remains visible above the guess field with the keyboard open. Four localization files passed plutil lint; git diff --check passed. Prepared for a local-only commit; not released and no revenue impact measured.
