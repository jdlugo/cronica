# Arcade subtle motion

Use brief animation to show a state change, without delaying input or deciding game outcomes. Fade Memory cards over 0.16 seconds, preserve Scramble section identity so swaps move over 0.18 seconds, and fade game/replay/summary navigation over 0.2 seconds. Remove the bouncing result symbol. Disable these animations when the system Reduce Motion preference is enabled. Retain score, persistence, gestures and accessibility labels.

- [x] Inspect existing feedback and choose a small set of useful transitions.
- [x] Implement fades and stable tile identity; retain the existing tap/drag guards.
- [x] Run full Memory, Scramble and Daily Mix flows, including replay and recovery.
- [x] Enable the simulator's actual Reduce Motion setting and exercise both games.
- [x] Check large text on iPad, review captured evidence and record validation limits.

This pass stays local; it does not upload a new build.
