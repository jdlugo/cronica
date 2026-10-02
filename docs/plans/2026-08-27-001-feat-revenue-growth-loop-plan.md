---
title: Measured Revenue Growth Loop
type: feat
status: active
date: 2026-08-27
---

# Measured Revenue Growth Loop

## Overview

Increase Cronica revenue by turning Daily Puzzle practice into a repeatable, measurable session loop. Monetization must happen only after demonstrated engagement, while PostHog and AdMob reporting must make every release comparable by app version and build.

## Problem Frame

Cronica already has native, interstitial, rewarded, and app-open ad infrastructure, plus a Daily Puzzle funnel and version-aware telemetry. The observed baseline had a 100% AdMob match rate but a 31.6% show rate, with too little production traffic to justify aggressive optimization. The immediate opportunity is to create more valuable puzzle rounds, convert eligible loaded inventory into impressions at a safe cadence, and distinguish product, inventory, presentation, and retention failures in reporting.

## Requirements Trace

- R1. The first Daily Puzzle remains uninterrupted by an interstitial.
- R2. Practice puzzles create a controlled interstitial opportunity only after three completed rounds.
- R3. Existing cooldown, paid-user exclusion, consent eligibility, preview-mode exclusion, and session-cap behavior remains authoritative.
- R4. Rewarded hints remain user initiated and measurable as a complete request-to-reward funnel.
- R5. Puzzle rounds, continuation, terminal outcomes, and monetization opportunities are attributable to app version, build, runtime session, puzzle index, and puzzle source.
- R6. A durable scorecard and change ledger records what changed, why, expected impact, guardrails, and post-release results.
- R7. Reports expose impressions per puzzle session and per active user without treating ad-request volume as success.

## Scope Boundaries

- Do not increase app-open frequency.
- Do not show an interstitial before the first solve or failed round.
- Do not add a subscription or change App Store products in this phase.
- Do not import the upstream architectural rewrite.
- Do not use click-through rate as the primary optimization target or encourage accidental ad interaction.

### Deferred to Separate Tasks

- Daily Puzzle widgets, Spotlight, and Shortcuts: acquisition and re-entry phase after the monetization baseline is trustworthy.
- Premium Taste Profile: subscription-value phase after retention and puzzle depth are established.
- Share Extension and web deep links: organic acquisition phase.

## Context & Research

### Relevant Code and Patterns

- `Shared/Configuration/AdConfiguration.swift`: centralized cooldown, cap, and engagement cadence.
- `Shared/Configuration/AdCoordinator.swift`: ad lifecycle tracking, inventory recovery, paid-user exclusion, and rewarded-hint flow.
- `Shared/ViewModel/DailyPuzzleFeature.swift`: puzzle state and Daily Puzzle analytics taxonomy.
- `Shared/View/Navigation/HomeView.swift`: Daily Puzzle session index, continuation loading, native placement, and hint actions.
- `Shared/Manager/CronicaTelemetry.swift`: version/build/runtime-session properties on every PostHog event.
- `scripts/posthog_audit.sh`: production funnel and release-health queries.
- `scripts/analyze_admob_weekly.py`: AdMob revenue, request, match, show, eCPM, and CTR comparisons.
- `CronicaTests/AdCoordinatorTests.swift` and `CronicaTests/SettingsStoreTests.swift`: dependency-injected behavior coverage.

### Institutional Learnings

- Normal simulator builds do not emit production PostHog telemetry; validate analytics with TestFlight or a supported production configuration.
- Match rate alone is insufficient. Track loaded inventory, presentation opportunities, attempted presentations, actual impressions, and suppression reasons separately.
- Increase useful sessions before increasing forced ad pressure.

## Key Technical Decisions

- Treat a completed puzzle round as the engagement unit: it aligns monetization with delivered user value.
- Use a trigger-specific cadence: puzzle completion uses every third round while existing detail/trailer engagement retains its current cadence.
- Present before loading the next practice puzzle, and always continue immediately when inventory is unavailable or policy blocks presentation.
- Preserve one forced interstitial per session window and the 150-second global cooldown.
- Record terminal failure explicitly; solved-only funnels hide difficulty and abandonment.
- Keep PostHog as behavioral attribution and AdMob as financial truth; correlate by date/build rather than attempting user-level revenue attribution.

## High-Level Technical Design

> This is directional guidance for review, not implementation specification.

```text
Daily puzzle opened
  -> round started (index 1, no forced ad)
  -> solved or failed
  -> Next Puzzle tapped
  -> completed-round cadence evaluated
      -> deferred: load next immediately and keep inventory warm
      -> eligible: present one interstitial, then load next
      -> blocked/no inventory: record reason and load next immediately
  -> next round started (index N)
```

## Implementation Units

- [ ] **Unit 1: Revenue-safe puzzle cadence**

**Goal:** Create an interstitial opportunity after every third completed puzzle round without interrupting the first Daily Puzzle.

**Requirements:** R1, R2, R3

**Dependencies:** Existing `AdCoordinator` engagement presentation path.

**Files:**
- Modify: `Shared/Configuration/AdConfiguration.swift`
- Modify: `Shared/Configuration/AdCoordinator.swift`
- Modify: `Shared/View/Navigation/HomeView.swift`
- Test: `CronicaTests/AdCoordinatorTests.swift`

**Approach:**
- Add a puzzle-completion engagement trigger with its own interval.
- Maintain engagement counters per trigger so detail/trailer activity cannot advance the puzzle cadence.
- Route Next Puzzle continuation through the existing on-dismiss continuation.
- Attach puzzle index, prior puzzle ID, result, and attempts to ad lifecycle metadata.
- Keep paid-user, cooldown, session-cap, and missing-inventory behavior unchanged.

**Test scenarios:**
- Happy path: completing three rounds and requesting continuation presents one loaded interstitial before loading round four.
- Guardrail: the first and second completed rounds continue without presenting.
- Guardrail: a paid user continues immediately without loading or presenting forced inventory.
- Error path: missing inventory records the outcome and continues immediately.
- Integration: dismissal invokes the continuation exactly once.

**Verification:**
- The first Daily Puzzle has no forced interstitial and the fourth round remains reachable regardless of ad state.

- [ ] **Unit 2: Puzzle outcome and monetization telemetry**

**Goal:** Make round depth, failure, continuation, and ad opportunity measurable by build.

**Requirements:** R4, R5

**Dependencies:** Unit 1 metadata flow.

**Files:**
- Modify: `Shared/ViewModel/DailyPuzzleFeature.swift`
- Modify: `Shared/View/Navigation/HomeView.swift`
- Test: `CronicaTests/SettingsStoreTests.swift`

**Approach:**
- Emit an explicit terminal failure event.
- Include puzzle index and terminal result on continuation events.
- Record an event when an eligible native puzzle slot is rendered, without claiming it was an AdMob impression.
- Keep actual ad impressions sourced from Google full-screen callbacks and AdMob reports.

**Test scenarios:**
- Happy path: a solved round reports result, attempts, and puzzle index before continuation.
- Failure path: exhausting attempts emits one terminal failure event.
- Edge case: reopening an already terminal puzzle does not duplicate the terminal event.
- Integration: a continuation carries the same puzzle index into puzzle and ad lifecycle events.

**Verification:**
- Production events can distinguish opens, terminal rounds, next taps, next loads, ad opportunities, presentations, and impressions.

- [ ] **Unit 3: Revenue scorecard and change ledger**

**Goal:** Make each shipped monetization change auditable and comparable.

**Requirements:** R6, R7

**Dependencies:** Units 1 and 2 event names.

**Files:**
- Create: `docs/revenue-growth-scorecard.md`
- Modify: `docs/daily-puzzle-analytics-kpis.md`
- Modify: `scripts/posthog_audit.sh`

**Approach:**
- Define north-star, leading, monetization, and retention guardrail metrics.
- Add build-level queries for puzzle depth, continuation, impressions per puzzle session, and presentation suppression.
- Start an append-only release ledger with hypothesis, implementation, expected movement, and fields for observed results.

**Test scenarios:**
- Test expectation: none -- documentation and read-only reporting queries do not change app behavior.

**Verification:**
- A release-health run can compare puzzle engagement and monetization outcomes by app version/build.

- [ ] **Unit 4: Release checkpoint**

**Goal:** Define the explicit validation and rollout boundary before publishing.

**Requirements:** R1-R7

**Dependencies:** Units 1-3.

**Files:**
- Modify: `docs/revenue-growth-scorecard.md`

**Approach:**
- Record focused unit/UI scenarios, production telemetry constraints, TestFlight smoke path, and the minimum observation window.
- Do not change cadence again until the build has enough sessions to evaluate retention and impressions per session together.

**Test scenarios:**
- Integration: solve three practice rounds, observe at most one interstitial, continue to a fresh fourth puzzle, and confirm no blocked continuation.
- Integration: request a rewarded hint and verify reward delivery only after completion.
- Guardrail: paid and preview modes show no monetization surfaces.

**Verification:**
- The checkpoint identifies exact go/no-go outcomes without relying on ad revenue alone.

## System-Wide Impact

- **Interaction graph:** Daily Puzzle result CTA -> Home continuation coordinator -> AdCoordinator policy/inventory -> next-puzzle service -> replacement view model.
- **Error propagation:** Ad load/presentation failures remain non-blocking and invoke continuation.
- **State lifecycle risks:** Repeated taps must not double-present ads or load multiple next puzzles.
- **API surface parity:** Archive/developer puzzle views retain rewarded hints but do not gain forced continuation ads unless they use the Home continuation flow.
- **Integration coverage:** Unit tests cannot prove Google callbacks or production PostHog ingestion; TestFlight smoke and release-health reporting remain required.
- **Unchanged invariants:** Daily streak records only the canonical daily puzzle; practice rounds remain excluded.

## Success Metrics

- Puzzle open-to-guess rate does not regress by more than 5 percentage points.
- Solve rate remains at or above 65%.
- Next Puzzle tap-to-load rate remains above 95%.
- Median puzzle rounds per session increases release over release.
- Interstitial impressions per puzzle session increases without reducing D1/D7 retention.
- Rewarded hint completion and reward delivery can be measured separately from attempted presentations.
- AdMob show rate improves from the observed 31.6% baseline, interpreted with traffic volume and placement mix.

## Risks & Dependencies

| Risk | Mitigation |
|---|---|
| Interstitial harms continuation | Delay until three completed rounds and preserve one-per-session cap. |
| No inventory blocks gameplay | Always invoke continuation on skip or failure. |
| Small sample creates false conclusions | Compare absolute counts and unique users; require an observation window before changing cadence. |
| PostHog and AdMob counts differ | Treat PostHog as product-flow attribution and AdMob as billing truth. |
| Duplicate terminal events inflate funnels | Persist or guard terminal emission per view-model lifecycle. |

## Phased Delivery

### Phase 1: Measured puzzle monetization

- Trigger-specific three-round cadence.
- Failure and monetization opportunity telemetry.
- Build-level scorecard.

### Phase 2: Retention acquisition

- Daily Puzzle widget and quick action.
- Shareable puzzle deep links.

### Phase 3: Premium conversion

- Taste Profile and advanced statistics.
- Ad-free and personalized puzzle entitlement design.

## Operational / Rollout Notes

- Production/TestFlight traffic is required because normal simulator telemetry is disabled.
- Compare at least one complete seven-day period when traffic permits.
- Roll back cadence independently if puzzle continuation or retention degrades.
- Never optimize toward accidental clicks; prioritize completed sessions, opted-in rewarded views, and retained users.

## Verification checkpoint: 2026-08-27

- Revenue loop implementation and focused telemetry/ad tests complete.
- XcodeBuildMCP result: 79 passed, 0 failed, 0 skipped.
- Full app/UI and TestFlight validation remain separate release checkpoints.

## Native ad compliance checkpoint: 2026-08-27

- Found and fixed Google native-ad validator error: advertiser asset outside the native ad view.
- Added a local card renderer with registered asset containment and a regression test.
- Focused result: 93 passed, 0 failed, 0 skipped.
- Integrated simulator build and Daily Puzzle continuation smoke test passed.
- Google live validator reports no implementation issues; evidence is `docs/evidence/2026-08-27-revenue-loop-admob-validator-clean.png`.
- Physical-device TestFlight telemetry remains the release measurement gate.
