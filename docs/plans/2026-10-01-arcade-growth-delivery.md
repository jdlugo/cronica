# Arcade Growth Delivery Implementation Plan

> Execution: bounded subagent development in this chat, authorized by the user. Root integrates and reviews each workstream.

**Goal:** Deliver trustworthy arcade events, a simpler recommended entry, less repetitive play, and accurate purchase copy/configuration in a tested local build.

**Architecture:** Preserve the existing Codable arcade engine and SwiftUI player. Add small pure analytics state with stable run identity and distinct exposure/action/outcome events; use the existing telemetry sink. Keep practice library and saved Daily Mix compatible. No new backend or analytics dependency.

**Tech stack:** Swift/Foundation, SwiftUI, StoreKit, standalone Swift regression tests, Xcode simulator UI tests.

## Team limits

- Three agents, disjoint file ownership, no child agents, network, independent Xcode runs, commits or new features beyond the assigned scope.
- Agent coding deadline: 12:15 UTC October 1. Progress at five minutes. Investigations capped at three minutes; report a blocker instead of repeating.
- Root owns UI, Xcode project registration, integration, review and one serial simulator run. Target complete validation around 12:30 UTC; fix demonstrated failures within a bounded retry.
- Time limits reduce scope or trigger a handoff; they never justify claiming untested completion.
- External dependencies: AdMob account recovery, actual App Store product verification, human recruitment and mature retention/revenue results remain explicitly unverified. Do not invent results or silently reauthenticate accounts.

## Task 1 — Analytics (agent)

Own new `Shared/Model/ArcadeAnalytics.swift`, `Shared/Manager/CronicaTelemetry.swift`, and uniquely named standalone analytics tests. Do not edit MovieArcadeView.swift or MovieArcade.swift.
1. Write failing tests for stable identity, visible/start distinction, first action, terminal event, summary reopen and duplicate abandonment.
2. Implement a minimal event journal/contract with stable run/round/challenge IDs, attempts/help counts, outcome/skip, environment classification and privacy-safe properties.
3. Run fast Swift tests; hand off exact integration API to root. No production growth claims.

## Task 2 — Content/model (agent)

Own `Shared/Model/MovieArcade.swift`, `scripts/tests/movie_arcade_tests.swift`, and `scripts/test_movie_arcade.sh`.
1. Write failing tests for actor-pair variety, repeated-target avoidance, optional Memory bonus preserving earned matching score, and decoding existing saved sessions.
2. Implement several valid distinct actor-pair sets using the existing catalog/cast; avoid immediately recycled film targets in daily/practice generation where feasible. Do not add remote assets or invent actor credits.
3. Add optional persisted run ID with safe legacy migration if required by analytics.
4. Add an explicit finish-matching action; keep bonus available separately, preserving old saved state and skip behavior.
5. Run deterministic standalone tests and hand off UI actions/data needs to root.

## Task 3 — Purchase accuracy (agent)

Own `Shared/Cronica.storekit`, relevant Tip Jar strings, and uniquely named consistency check script/docs. Do not change checkout/entitlements or prices in production.
1. Verify `Shared/ProductList.plist` requested IDs against the local StoreKit fixture.
2. Correct the false always-ad-free promise in supported localizations; describe the existing app-wide ad-free upgrade without changing the entitlement.
3. Align local fixture identity/type with runtime requested product; local price remains simulation-only.
4. Run a static configuration/copy consistency check; document that real App Store catalog, purchase/restore, and AdMob refresh need external verification.

## Task 4 — Entry and integration (root)

Own `Shared/View/Navigation/MovieArcadeView.swift`, `CronicaUITests/CronicaUITests.swift`, project registration and delivery report.
1. Feature Daily Mix plus Scramble, Memory, Double Feature, with All Games disclosure preserving every mode.
2. Make matching success sufficient to finish Memory; bonus remains optional and clearly labeled.
3. Wire exposure/round visibility/first action and terminal events, no started event for reopening a completed summary, deduplicated abandonment across callbacks. No experiment lift claims from changing the default UI.
4. Add meaningful UI checks for curated entry/full library, optional bonus, replay and saved summary; retain existing all-game coverage.
5. Register new source files, build/test serially on iPhone 17 Pro iOS 26.3, inspect representative screenshots.

## Review and delivery

- Root reviews diffs after each handoff, then uses a fresh agent for a bounded read-only final review (six minutes, actionable defects only).
- Resolve critical/important regressions, run changed-domain tests and simulator checks, preserve unrelated primary-checkout changes.
- Save exact evidence, residual external requirements and next experiment definition. Commit locally when validation passes; no upload/submission in this request.
