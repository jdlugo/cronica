# Daily Puzzle ASO + UX Rollout Notes

## Objective
Align in-app Daily Puzzle engagement loops with App Store messaging so acquisition intent ("daily game" + "movie tracker") matches retained usage (daily solve + streak).

## In-App Experience Checklist
- Home shows a persistent Daily Puzzle card with direct play CTA.
- Puzzle completion supports spoiler-free sharing.
- Notification prompt is only shown after a meaningful interaction (first non-empty guess).
- Notifications settings include a Daily Puzzle explanation and direct "Play Daily Puzzle" action.
- Developer options can update backend admin toggles (`enabled`, `pushEnabled`) through the secure function endpoint.

## ASO Message Stack (en-US)
- Subtitle: `Track Shows + Daily Puzzle`
- Promo text: emphasizes daily emoji puzzle + streak + reminders + sharing.
- Description: Daily Puzzle value proposition appears before discovery/watchlist detail.
- Keywords: include `daily puzzle` and `emoji game` while preserving core tracker intent.

## Experiment Plan (30 Days)
1. Week 1: Release metadata + in-app UX updates together and benchmark conversion + D1 retention.
2. Week 2: Launch Daily Puzzle CPP and compare CVR versus default page.
3. Week 3: Iterate screenshot order for puzzle-first narrative (card -> game -> solved share).
4. Week 4: Rebalance keyword-to-CPP mapping based on ranking and conversion deltas.

## Metrics to Watch
- App Store conversion rate (impressions -> installs).
- D1/D7 retention for users who open Daily Puzzle on day 0.
- Daily Puzzle open rate from push notifications.
- Puzzle completion rate and average attempts.
- Share action rate from solved state.

## Guardrails
- Keep reminder notifications optional and user-controlled.
- Avoid spoiler text in push body or share templates.
- Treat admin config key as internal-only (never hardcode production secret in public client flows).
