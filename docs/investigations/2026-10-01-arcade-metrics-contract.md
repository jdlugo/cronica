# Arcade growth measurement contract

This local delivery instruments a curated default entry. It is not an A/B test and has no randomized experiment assignment. Before claiming causal lift, establish a release baseline and implement stable assignment with a predeclared primary metric and guardrails.

## Event contract

All arcade events use `arcade_schema_version=2` and `entry_layout=curated_v1`. Shared telemetry supplies app/build/platform, runtime session, environment and test-run classification. Exclude simulator/debug/TestFlight, test runs and unknown environment from the release baseline; never silently mix historic unclassified traffic.

| Event | Trigger / denominator use |
| --- | --- |
| movie_arcade_exposed | Home card or lobby appears; `entry` distinguishes surfaces. Aggregate unique users/runtime sessions instead of treating every view callback as a new player. |
| movie_arcade_started | First rendered unfinished round of a durable run. Creating a session alone does not count. |
| movie_arcade_round_visible | An unfinished round appears or resumes. Can repeat; started stays deduplicated. |
| movie_arcade_first_action | First accepted gameplay selection, answer or help per round; skip/navigation excluded. |
| movie_arcade_action | Accepted interaction with selection/attempt/help/progress/skip role and accumulated counters. Same-tile cancellation is progress, not a swap attempt. |
| movie_arcade_bonus_attempt | Optional year question attempt. A correct answer can finish the round exactly once; mistakes preserve the matching score. |
| movie_arcade_round_completed | Accepted terminal transition, `outcome=solved` or `skipped`, separate skip flag and counts. |
| movie_arcade_mix_completed | Last Daily Mix transition; `genuine_round_count`, `skipped_round_count`, solved/contains_skips distinguish success. |
| movie_arcade_summary_viewed | Completed summary appears; never emits a fresh start. |
| movie_arcade_left | Unfinished run leaves by background/dismissal. Deduplicated within a visit; a genuine resume permits a later new exit. System overlays pause timing without an exit. |

`run_id` persists with the saved session; `round_id` combines run and ordinal; `challenge_id` includes catalog, kind, seed and deterministic content fingerprint. `content_signature` ignores cosmetic shuffling, permitting novelty analysis across different seeds. No raw guesses, actor selections or personal identifiers are copied into these properties.

The journal retains 32 runs, prioritizing unfinished saves. Timing pauses during overlays/background. Process termination conservatively discards its unclosed interval; it does not count overnight wall time as play. `elapsed_active_seconds` is per round, including resumed intervals; mix duration is the sum of relevant round durations, not the last-round field alone.

## Baseline metrics

1. Activation: distinct release identities with a solved, non-skipped first run-round in the first observed exposure runtime session / identities exposed to the Home arcade entry in that session. Also report Home→lobby→round-visible→first-action→completion absolute counts. Identity is not proof of a distinct person.
2. Voluntary continuation: distinct identities starting and completing a second fresh practice run after an earned result / identities with an earned first result. Different `run_id`, same runtime session; required Daily Mix advancement and summary reopens do not count as replay.
3. Novelty: distinct canonical content signatures, repeated target/content across consecutive runs, and skips/help per mode. A new seed alone is not new content.
4. Retention: meaningful app/game action on a subsequent date, mature exposure cohorts only. Distinguish first observed release adoption from verified installation. User-local D1/D7 requires client calendar metadata; without it, explicitly report UTC-date diagnostics rather than calling them local-date retention.
5. Revenue: mature 28-day net revenue per eligible assigned unpaid identity after a future purchase experiment. Current AdMob access and live purchase/catalog validation remain prerequisites. Requests, presentations and observed checkout taps are not earnings.

Do not call missing events zero demand. Reconcile a real-device release/sandbox sequence in PostHog after shipping before promoting this contract to a verified production funnel. Simulator capture is intentionally disabled.
