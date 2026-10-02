# Arcade movie discovery

Turn a completed game into a useful movie-night choice. Reuse the real movie details and watchlist, with no purchase gate or claims about streaming availability.

- Offer completed/revealed films only; never expose future answers. Multi-film games include every film involved, and Daily Mix deduplicates completed films.
- Keep replay/next-game actions prominent. Offer discovery underneath, with bundled posters, release years, and accessible labels. Preserve the score on returning from details.
- Track detail opens and successful watchlist additions with the source round/run and result/summary surface. Loading an already-saved film must not count as an addition.
- Confirm save success before changing the Add button or emitting the addition event. Show an actionable failure and allow retry.
- Validate all ten game mappings with the engine suite and telemetry guards with the analytics suite. Run focused simulator flows for saving/relaunch, existing saves, retry, large text, Spanish and Daily Mix continuation. Use an isolated persistent fixture store; test-only metadata never enters release builds.
- Bound this delivery to the discovery route, accurate save feedback and focused validation. Record actual checks and limitations; commit locally. Human retention, revenue and production telemetry remain separate evidence.
