# 2026-08-24 ARPU-First Ad Pacing & Measurement Plan

## Goal
Increase short-term ARPU by reducing interruption fatigue from interstitials while increasing monetized session yield from high-intent moments.

## Prioritized order (do this first)
### 1) Interstitial throttling (foundational)
Reduce frequency and improve UX safety in `AdConfiguration` and `AdCoordinator` before changing placement logic.  
Action: increase cooldown and per-session caps; enforce app-open cooldown and app-open session caps.  
Expected effect: fewer “ad fatigue” exits and higher completion confidence, with lower ad-block/retry churn.

### 2) Placement quality over volume
Keep interstitials for value moments only:
- puzzle completion
- occasional trailer/detail interactions
- occasional app-open

Implementation: add source-aware metadata to ad calls from puzzle completion, hint flow, trailer launch, and detail open; retain engagement gating (`presentInterstitialForEngagement`) but raise interval.  
Expected effect: better signal quality for ad-serving and easier measurement of which placements are profitable.

### 3) Measurement for optimization
Attach puzzle/content context directly into ad lifecycle events (`metadata`), and track ad call outcomes for:
- source/trigger
- puzzle or trailer identifiers
- user outcome (attempt, solved/failed, inventory fallback)

Expected effect: data-rich dashboards for immediate ROI tuning (not just volume-based intuition).

## Checkpoints
1. Verify no syntax/compile regressions in:
   - `/Users/johndlugokecki/dev/Cronica/Shared/Configuration/AdConfiguration.swift`
   - `/Users/johndlugokecki/dev/Cronica/Shared/Configuration/AdCoordinator.swift`
2. Confirm call-site behavior:
   - `/Users/johndlugokecki/dev/Cronica/Shared/View/Navigation/HomeView.swift`
   - `/Users/johndlugokecki/dev/Cronica/Shared/View/ItemContent/ItemContentDetails.swift`
   - `/Users/johndlugokecki/dev/Cronica/Shared/View/Trailers/TrailerItemView.swift`
3. Capture one hour of PostHog raw funnel output for:
   - `ad_interstitial_present`
   - `daily_puzzle_*` completion + ad metadata events
4. Reassess after 24–48 hours and tune only one variable at a time.
