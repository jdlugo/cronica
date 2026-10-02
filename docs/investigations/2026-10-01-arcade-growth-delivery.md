# Arcade growth delivery — October 1, 2026

## Delivered engineering slice

The bounded team implemented measurement, curated entry, optional Memory trivia, replay variety and purchase accuracy. The changes build on 2ec730a7 in the attached `codex/arcade-growth-delivery` worktree. The primary checkout remains unchanged by this delivery.

- Home opens a lobby with Daily Mix and three featured mechanics: Scramble, Memory and Double Feature. All Games preserves every existing practice mode.
- Memory can finish immediately after three poster pairs. Optional year mistakes cannot erase matching points; both the completion result and the displayed available score preserve them.
- Double Feature rotates seven verified six-film pairing sets using existing artwork. Practice generation remembers the last two targets per mode, including existing saved rounds. Daily Mix searches at most 48 candidates per round to reduce repeated films while preserving distinct guessing targets.
- Existing Daily Mix/partial practice saves stay valid. Legacy run identity is assigned once and persisted rather than discarding progress.
- Arcade analytics now separates Home/lobby exposure, actual visible start, first selection, attempts/help/bonus, terminal outcome, summary views and exits. Stable run/round identities and canonical content signatures distinguish resumed progress from fresh play and cosmetic reshuffling. Terminal callbacks and exits are deduplicated.
- Timing pauses for system overlays/background and conservatively drops an unclosed forced-quit interval. A tile cancellation does not count as a swap attempt. Shared telemetry labels simulator/debug/TestFlight/release and fixture runs; live ingestion remains unverified.
- All 15 supported localized purchase surfaces accurately describe the optional one-time app-wide ad-free upgrade. The local non-consumable StoreKit fixture now matches requested `AdFreeUpgrade`. Its price is simulation-only; no production price or entitlement changed.

The 12-film catalog still limits long-term novelty. No new mode, remote asset dependency, backend service, forced ad cadence, purchase offer or subscription was added. No A/B assignment or growth lift is claimed for the curated default.

## Team management

| Workstream | Limit | Result |
| --- | --- | --- |
| Analytics | Coding cutoff 12:15 UTC; five-minute checkpoint; max three-minute blocker investigation | Handed off before cutoff; one bounded two-minute review correction added overlay suspension |
| Content/model | Same 12:15 UTC cutoff | Handed off before cutoff, no assets/network/checkout changes |
| Purchase accuracy | Earlier 12:12 UTC cutoff | Handed off before cutoff; fixture/localizations/check only |
| Independent adversarial review | Seven minutes, read-only | Found concrete schema/visibility/timing/classification issues; root resolved them |
| Root integration | Single owner for SwiftUI/project registration; serial simulator checks | Prevented overlapping Xcode runs and shared-file edits |

Implementation agents had no child agents, network access, Xcode runs or independent commits. All agents are stopped. Source file ownership prevented conflicting edits. Root inspected diffs and reran the domain checks rather than trusting handoff claims.

## Validation

- Standalone model/rules suite: 9,759 checks across 40 seeds and all ten modes.
- Analytics suite: 87 checks, including legacy identity, optional bonus/matching completion, skip/mix outcomes, resume, bounded storage, inactive timing and deduplication.
- Purchase contract: one requested product matches its non-consumable fixture; copy checked in 15 locales; five deliberately invalid identity/type/copy mutations rejected.
- Deterministic content comparison over the same 28 October Daily Mix dates: distinct film slots 195→218, repeated slots 47→24. Independently rerun against base and current models. This measures content variety, not retention or enjoyment.
- iPhone 17 Pro / iOS 26.3: combined simulator build passed. The selected arcade suite passed 17 of 18 tests; its one lobby-test scrolling failure was corrected and the focused lobby rerun passed. All 18 distinct checks now have passing evidence across those runs, including completion of all ten games, saved progress/summary, replay, large text and both optional Memory paths. This is not a claim of a second clean full-suite run.
- Representative screenshots were inspected and saved alongside exact result-bundle references in `docs/evidence/arcade-growth-delivery-2026-10-01/`. No iPad, physical-device or native-speaker localization pass was performed in this delivery.

## Integration issues resolved

The machine initially ran out of disk while materializing committed screenshot baselines. Duplicate temporary exported screenshots were removed and the attached worktree excludes the large committed baselines via sparse checkout. A hash audit proved all 350 materialized changes matched the intended commit before repairing the incomplete checkout. No independent local edits were discarded.

The first build caught an inaccessible actor-pair property across workstreams; analytics now uses the public pair-key API. Independent review also caught a missing Home schema tag, inactive overlay timing and canceled-tile attempt classification, all corrected. The curated-library UI audit initially searched featured tiles in the old library order and scrolled away from a virtualized card. The first focused retry verified the entire library but failed to return to a featured card. The final test follows displayed order and uses the persistent disclosure to collapse the expanded grid before selecting Scramble; it passed without weakening the library assertions. These were test-navigation corrections, with no further product changes after the full arcade run.

The Xcode MCP response timed out while its test process continued. Root verified the active process and reads final Xcode logs/result bundles; a tool timeout is not counted as a test pass or failure.

## Remaining gates and next decisions

1. Verify the live App Store catalog/type/price and sandbox purchase/restore/ad suppression with the account/device owner. The local fixture and static check do not prove a real transaction.
2. Restore AdMob reporting through its account owner; the earlier invalid_grant/invalid_rapt response was not reauthenticated automatically. Current earnings remain unavailable.
3. Reconcile the new event sequence on a real release/sandbox device after shipping. Simulator PostHog capture is intentionally disabled. Receipt-based environment classification is a heuristic, not proof of App Store provenance; exclude known internal/preview traffic.
4. Use the prepared first-time study kit with 6–8 unfamiliar participants. No recruitment or human study occurred here. Establish a trustworthy exposure baseline and calculate sample size/MDE before randomization.
5. Invest next in a maintainable week of new content beyond the starter pack. A post-success purchase offer remains gated on verified product value, earnings and returning play.

The measurement contract specifies UTC diagnostics when client-local calendar context is unavailable. No D1/D7 or revenue improvement was measured. No App Store upload/submission was requested or performed in this delivery.
