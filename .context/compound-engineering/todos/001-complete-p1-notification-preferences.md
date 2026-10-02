---
status: complete
priority: p1
issue_id: "001"
tags: [notifications, retention]
dependencies: []
---
# Notification preferences and duplicate reminders
## Problem Statement
The new 18:00 recipient-timezone Firebase campaign ignores in-app preferences and completion. Existing clients can also schedule a 20:00 fallback.
## Findings
The daily-puzzle topic is unconditionally subscribed. The campaign targets all installs independently of that topic. Local fallback checks only the puzzle toggle; completion cancellation covers solves but not failed terminal attempts.
## Proposed Solutions
1. Migrate updated clients to one local-time reminder schedule and restrict the legacy campaign to older versions.
2. Register device preferences/completion on a server and replace all campaign sending with a per-device scheduler (larger deployment and data lifecycle).
3. Only change topic subscription (insufficient: campaign bypasses topic).
## Recommended Action
Verify campaign version exclusion, then implement a single local reminder owner with regression coverage. Keep the overnight broadcaster disabled.
## Acceptance Criteria
- [x] Confirm source and campaign boundaries.
- [x] Reproduce preference and terminal-state defects in tests.
- [x] Implement one daily delivery path with opt-out and completion cancellation.
- [x] Prevent legacy campaign duplication during migration.
- [x] Verify scheduling, timezone/day rollover, cancellation and preference races.
- [x] Run build/tests and record any blockers.
## Work Log
2026-09-28: User authorized implementation. Xcode license currently blocks simulator builds; requested user review/accept while independent work continues.

2026-09-28: Implemented client 4.25.42/build 14, saved Firebase campaign version <=4.25.41, and verified by reopening. 33 targeted iOS tests passed (0 failures/skips); standalone scheduling/DST/cancellation-race suite passed. Xcode license blocker resolved by user. App distribution and real-device receipt remain release validation, not yet completed.
