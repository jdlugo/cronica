# Accessible-controls persona and adversarial review

October 1, 2026; reviewed local commit `6b249b89`, existing source, recorded simulator validation and two saved large-text attachments. This is a constrained reference-persona inspection, not an accessibility participant session. No new simulator, VoiceOver, physical-device or human playthrough was performed.

## P5 Morgan: evidence and limits

Scenario: navigate the featured entry, identify Memory cards, recover from a wrong answer, finish without trivia, and reach a result action with larger text or spoken controls. Large text, reduced motion and VoiceOver are separate constraints; success under one does not establish the others.

**Observed local, reused evidence:** `docs/evidence/arcade-growth-delivery-2026-10-01/validation.json` records iPhone 17 Pro/iOS 26.3 simulator evidence. Existing accessibility-XXXL tests cover Casting choices within screen bounds; Director’s Cut and Heist recover after mistakes/relaunch; Detective reaches a result and returns to the lobby. The viewed Casting attachment shows wrapping names inside cards, although “Matthew McConaughey” breaks across several lines. The viewed Detective result shows very large text and substantial scrolling. These are narrow layout observations, not judgments of ease or VoiceOver usability. Tests do not cover the featured lobby or Memory at accessibility text sizes.

**Source-derived positive controls:** `Shared/View/Navigation/MovieArcadeView.swift:219` switches the lobby to one column at accessibility sizes. Choices also become one column; matching uses two. Memory labels at line 478 disclose a film title only when selected/matched and otherwise say “Face-down card N.” Values identify selected/matched states, and mismatches wait for an explicit retry. Thus source inspection does not reveal a face-down title leak. Matching can finish before optional trivia (`:486`), with earned points preserved; existing standard-size tests verify that route. The source disables movement animation and result bounce when Reduce Motion is enabled (`:532`, `:605`); runtime behavior is unverified.

**Source-derived gaps requiring a focused test:**

1. Heist’s first lock presents a scene and asks which movie (`:315`). The shared scene helper is accessibility-hidden (`:602`) and that lock has no alternative plot clue. A player unable to see the scene has no equivalent evidence for the answer. Actual spoken traversal is untested, but the missing source-level alternative is concrete.
2. Scramble labels expose each section’s intended order (`:397–398`). This provides an actionable nonvisual ordering task rather than revealing the film title, but changes the visual puzzle into numeric sorting. Test whether this is satisfying independent play; do not claim equivalent challenge.
3. Feedback and completion replace content and scroll to the top, but the view defines no explicit accessibility focus/announcement handling. Whether focus lands usefully, feedback is spoken, and a revealed Memory card’s new label is announced remains unknown. A screenshot cannot resolve it.

**P5 outcome:** layout support is partially evidenced; independent spoken play remains unanswered. Prioritize Memory, Scramble and the Heist first lock on a real VoiceOver device, including mismatch, retry, result, next round, dismissal and relaunch. Separately test the featured lobby and Memory at accessibility XXXL and Reduce Motion. Record task success, assistance, focus loss and puzzle-information availability, without inferring enjoyment from success.

## Adversarial methodology and strategic failure modes

- **Synthetic conformity:** agents can follow known correct answers and explicit routes; unfamiliar humans may never discover those routes or decline another game. Seven successful persona walkthroughs would not answer voluntary replay, retention or willingness to pay. Keep those questions explicitly unresolved; use the profiles to select disconfirming human tasks.
- **Preset stop rules:** “first repeated challenge” is a useful variety probe, but repeated familiar content can also appeal. A triggered stop is a scenario failure, not evidence that a market segment abandons. Preserve raw repeat counts and obtain actual reasons for stopping.
- **Conflated constraints:** P5 mixes low vision, motion preference and blindness; P7 mixes translation and cultural familiarity. Run these as separate scenarios before attributing a failure to either cause. The profiles are not representative market segments and must not be averaged into a fun score.
- **Right product, wrong proxy:** all games could work perfectly while adding little to Streaming Now’s discovery job. P4’s result-to-film/watchlist path is a load-bearing strategic test. More rounds or more games alone could consume development time without improving the core product or revenue.
- **Content supply before feature supply:** improved permutations of a 12-film catalog do not guarantee meaningful novelty tomorrow. Human replay and conceptual repetition should determine whether to expand content or narrow supported modes; further mini-games should wait for that evidence.
- **Release-as-experiment discipline:** transaction, accessibility and telemetry gates establish the ability to learn safely, not a business win. Predefine which observable human/live results cause investment, revision or retirement; do not turn synthetic predictions into retention targets.

The smallest useful next study is a few unfamiliar participants with contrasting movie knowledge, plus a separate accessibility session, allowed to stop without prompts. Observe first independent success and unprompted continuation; then compare movie discovery and paid-value comprehension. No contacts or recruitment were performed in this review.

## Root follow-up evidence

After this agent handed off, root added and ran `testArcadeMemoryLargeTextCanFinishWithoutTrivia`: one pass on iPhone 17 Pro/iOS 26.3 at accessibility XXXL. Matching-only completion preserved 3/3 points, the title stayed inside horizontal bounds and replay was reachable after scrolling. Two screenshots were inspected and saved in `docs/evidence/arcade-personas-2026-10-01/`. This narrows the Memory large-text gap above; the featured lobby, Reduce Motion runtime behavior and VoiceOver remain unverified in this review.
