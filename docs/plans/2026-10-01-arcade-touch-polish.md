# Arcade touch polish

Make Scramble rearranging feel direct, make secondary actions visibly tappable, and give Poster Memory a brighter card treatment without exposing face-down answers.

- [x] Add drag regression checks before implementation; verify they fail because dragging is unavailable.
- [x] Add an atomic tile swap that rejects invalid positions, completed boards and unrelated games, preserves score and survives saved progress.
- [x] Add hold-and-drag with a lifted tile, destination highlight, cancellation outside the board, and tap/VoiceOver fallback.
- [x] Improve card backs, revealed poster contrast and matched-state presentation; retain readable large-text layouts and reduced-motion behavior.
- [x] Add borders, icons and pressed feedback to secondary actions and answer cards.
- [x] Translate new instructions in English, Spanish and Mexican Spanish.
- [x] Verify regression tests fail for the intended reason, then pass with real model and simulator interaction.
- [x] Verify edge cases, save/restore, full Scramble and Memory playthroughs, iPhone/iPad and large text.
- [x] Review screenshots and logs; record evidence and any limits before reporting completion.

No new production release is part of this UI pass. The existing TestFlight build remains unchanged until another build is uploaded.
