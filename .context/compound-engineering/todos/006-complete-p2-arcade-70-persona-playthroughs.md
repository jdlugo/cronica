---
status: complete
priority: p2
issue_id: "006"
tags: [ios, product, personas, playthrough]
dependencies: ["005"]
---
## Problem Statement
Execute every persona-game combination in the simulator and provide a trace-backed comparison grid.
## Findings
Prior persona work inspected relevant flows rather than executing all 70 combinations. User explicitly requested the full matrix.
## Proposed Solutions
Bounded policy-driven UI sessions using visible state; explicit stops and administrative reveals; grid with all 70 unique evidence cells.
## Recommended Action
Execute docs/research/2026-10-01-arcade-70-playthrough-protocol.md; preserve simulated versus human evidence distinctions.
## Acceptance Criteria
- [x] Runner policies and declared prior knowledge reviewed; no hidden answer-state access.
- [x] All 70 fresh simulator combinations executed or explicitly recorded as blocked, with runtime evidence.
- [x] Persona stops, earned results, administrative reveals and automation failures distinguished.
- [x] Game-by-game findings and a comparable 10 × 7 grid generated from actual traces.
- [x] Independent trace review, representative screenshots and limitations recorded.
- [x] Reproducible artifacts saved and local delivery committed.
## Work Log
- October 1: user requested actual all-persona/all-game simulator play; protocol created on clean 6b8986f3.

- October 1 final:70 unique traces,215 previews,21 live image judgments verified; no UI blocks/automation failures in selected endpoints. Mixed harness versions and superseded attempts preserved. Direct recovery3cases passed, focused3 passed, manual default 11 skipped; browser filters/detail/previews passed. Findings and comparison generated.
