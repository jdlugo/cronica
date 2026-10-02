# Seven-persona, ten-game simulator protocol

User explicitly requested actual play as every reference persona, findings by game and a comparison grid. Baseline `6b8986f3`. Fresh assigned simulator play only; no human participants or organic replay claims.

## Run boundary

Every P1–P7 × ten ArcadeKind combination gets a fresh seed-0 fixture session with ads/onboarding disabled, English except P7 Spanish locale, accessibility XXXL for P5. Identical starting content supports comparing constraints; it does not test long-term content variety. These are assigned tasks with mechanics known to the scripted controller, not natural discovery or human reading tests. Personas are operationalized as explicit policies, not feelings.

Player actions may use current UI text, visible state, revealed card names, screen geometry and a declared prior-knowledge list. They must not read engine state, saved app data, the correct answer field, predetermined seed answers or prior functional-test tap sequences. Scramble can use the explicitly spoken section-order labels (record this assist), or Assemble for Me; do not pretend numeric labels are visual reasoning. Memory learns card identities only after turning them over. P2 uses declared movie facts; unknown questions require visible feedback, elimination, help or a stop. Identifiers may address controls, not encode answer selection. No production modifications.

At a policy stop, capture the exact reason and screen first. An administrative Reveal may then show the terminal result for inspection; record `outcome=revealed_after_stop`, never earned completion. Unreachable controls and automation failures are distinct from a persona's stop. Per-cell safety cap 45 gameplay tap attempts and 150 seconds of active automation runtime, excluding bounded live screenshot decisions (maximum 180 seconds each); these are runner limits, not human difficulty metrics.

## Policies

- P1 visual newcomer: Memory matching, limited help, recognizes Toy Story/Matrix/Jurassic Park by name; no years/actors. After an unknown title/actor/year requirement or two failed guesses, stop. Scramble may restore with the declared assistance but must record the title gate.
- P2 movie fan: explicit catalog title/year/lead/shared-actor facts allowed; seeks complete rounds and starts one scripted fresh replay after each earned result. Replay is a policy choice, not voluntary human replay.
- P3 interrupted player: moderate declared knowledge; one deliberate terminate/relaunch after first observed accepted action, then continue from preserved UI. One retry or clue allowed. Compare points, progress labels and selected/matched cards; mark this as partial visible recovery, not proof that every clue/feedback/board field persisted. If the first action finishes a round, label the check terminal-result recovery. Stop if the compared state changes.
- P4 discovery-first: ordinary title knowledge, limited trivia retry; inspect the earned/revealed result for film details/watchlist/availability. Stop replaying when no useful movie action is available.
- P5 larger-text controls: accessibility XXXL, UI-readable labels and declared facts; complete through visible controls when reachable. VoiceOver and Reduce Motion are separate untested conditions. Record spoken Scramble ordering assistance and any scrolling/control issues.
- P6 skeptical buyer: moderate facts; one recoverable wrong-first attempt where possible, then feedback/help/elimination with bounded effort. Inspect result for mandatory payment and optional next round; do not test live purchase or infer pay intent. Ads are disabled, so ad tolerance remains unanswered.
- P7 multilingual viewer: Spanish locale; weak-English fixture constraint, image matching and title recognition only. Record untranslated instructions observed; stop at an untranslated knowledge-dependent gate. A controller finding a button does not prove native-language comprehension.

## Trace schema

Each cell attaches JSON named `persona-cell-Pn-game.json`: `schema`, `persona`, `game`, `seed`, `locale`, `large_text`, `outcome`, `stop_reason`, `actions` (ordered type/target/visible feedback), `action_count`, `help_count`, `attempt_count`, `mistake_evidence`, `points_label`, `result_text`, `resumed`, `resume_verified`, `replay_started`, `utility_action_found`, `payment_gate_found`, `limitations`. Start/stop/result screenshots named with the same cell ID. No identifiers outside fixture controls or personal data are recorded.

Valid outcomes: `earned`, `earned_with_help`, `revealed_after_stop`, `ui_blocked`, `automation_failed`. The comparison grid must contain all 70 unique combinations and link every cell to its runtime trace. Missing data is explicit, never silently filled with a source prediction.

## Team/time limits

Policy, harness and grid preparation agents have disjoint file ownership and ten-minute maximum handoff, no child agents/network/production edits/Xcode runs/commits. Checkpoint at five minutes; blocked investigation max90sec. Root owns project registration and serial simulator execution. After handoff, agents stop and may receive one bounded trace-review task. Root target is around 40 minutes of run time; the run is monitored rather than left unattended. A completed scenario is recorded accurately even when its declared stop occurs. One demonstrated harness issue may receive a focused retry before resuming.

## Completed execution

All70 unique cells were executed and validated, with215 previews and21 live judgment captures. Root's initial 40-minute target was exceeded; bounded agents handed off, and root continued serially through a transport failure, disk-full capture loss and focused controller corrections. The final report records narrower persona coverage, mixed harness revisions and actual stops. The manual suite now requires TEST_RUNNER_ARCADE_PERSONA_PLAYTHROUGH=1; default execution skips instead of waiting unattended. See the evidence README, validation summaries and findings for final outcomes.
