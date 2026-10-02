# International Growth Rollout

Last updated: 2026-08-28

## Objective

Increase revenue by improving qualified international acquisition, activation, retention, and valuable sessions before increasing ad pressure.

## Target storefronts

1. France
2. Spain
3. Mexico
4. Brazil

## Baseline

The current comparison windows are not perfectly aligned. Treat conversion yield as directional until Apple, PostHog, and AdMob have complete overlapping dates.

| Territory | Apple impressions | Product-page views | Get taps | First downloads | Directional download yield | PostHog launches | Puzzle opens | AdMob revenue |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| France | 2,775 | 212 | 172 | 64 | 2.31% | 29 | 0 | $0.0135 |
| Spain | 450 | 20 | 14 | 9 | 2.00% | No current sample | No current sample | $0.0055 |
| Mexico | 1,223 | 72 | 23 | 12 | 0.98% | 4 | 0 | $0.2655 |
| Brazil | 19,101 | 367 | 155 | 49 | 0.26% | 6 | 0 | $0.1891 |

Baseline source ranges:

- Apple engagement: 2026-08-14 through 2026-08-26
- Apple downloads: 2026-08-15 through 2026-08-26
- PostHog: 2026-08-16 through 2026-08-21
- AdMob: 2026-08-14 through 2026-08-27

## Change ledger

| Change | Hypothesis | Primary KPI | Guardrail | State |
| --- | --- | --- | --- | --- |
| Stable territory, locale, provider-region, and content-source event properties | Territory funnels become attributable across acquisition, product usage, and revenue | Events with complete dimensions | No user-identifying properties | Implemented for next app build |
| Localized puzzle titles, aliases, hints, and sharing | Solvable local-language puzzles increase starts, completions, shares, and return visits | Puzzle open-to-completion and D7 return | Wrong-answer rate and hint dependence | Implemented for next app build |
| Storefront-region provider defaults and removal of U.S.-only fallbacks | Relevant streaming availability increases detail and provider engagement | Provider-view and provider-tap rate | Empty-provider result rate | Implemented for next app build |
| Localized review prompt after meaningful success | Asking after delivered value improves ratings without interrupting early sessions | Prompt-to-rating movement | Prompt frequency and early-session interruption | Implemented for next app build |
| Localized metadata for 15 storefront locales | Local-language listings improve page-view and download conversion | Page-view-to-download rate | Metadata rejection rate | Prepared locally |
| Puzzle-first screenshots for France, Spain, Mexico, and Brazil | Showing the differentiating daily puzzle first improves qualified downloads | First-download yield and post-install puzzle activation | Store page abandonment | Uploaded to draft custom pages |
| Daily Puzzle custom product page | Puzzle-intent traffic activates and returns more often than generic traffic | Download-to-puzzle-open, completion, D7, revenue per download | Crash-free sessions and ad impressions per starter | Draft, not submitted |
| Movie Tracker custom product page | Tracker-intent traffic creates more watchlist and provider value | Download-to-watchlist-add, provider taps, D7, revenue per download | Crash-free sessions and ad impressions per active user | Draft, not submitted |
| `qscanlite://daily-puzzle` activation route | Sending qualified users directly to the game increases post-install activation | Deep-link open-to-puzzle-open and completion | Broken legacy content URLs | Implemented and UI-tested for a later compatible build; not set on the live draft |
| Daily territory funnel | Daily comparison exposes where additional acquisition effort produces retained, monetizable users | Apple to PostHog to AdMob funnel by territory and product page | Minimum sample sizes and aligned dates | Active daily at 9:15 AM ET |

## Custom product-page state

- `Daily Puzzle - International`: `PREPARE_FOR_SUBMISSION`
- `Movie Tracker - International`: `PREPARE_FOR_SUBMISSION`
- Each page has `en-US`, `fr-FR`, `es-ES`, `es-MX`, and `pt-BR` localizations.
- Each page has three ordered screenshots for `APP_IPHONE_67` and `APP_IPAD_PRO_3GEN_129` in every locale.
- Total managed screenshots: 60.
- Movie Tracker has 12 exact localized keyword links.
- Daily Puzzle terms are present in the local next-release keyword metadata but are not available in the currently live App Store keyword resources.
- The Daily Puzzle deep link remains unset in App Store Connect until a build containing the route is available to users.

## Release gate

App version `4.25.40` is currently `WAITING_FOR_REVIEW`. The custom pages show behavior from that build and must remain unsubmitted until `4.25.40` is `READY_FOR_SALE`.

Go criteria:

1. Version `4.25.40` is `READY_FOR_SALE`.
2. Both custom pages still report five localizations and 60 managed screenshots collectively.
3. A media dry run reports zero missing uploads.
4. Promotional text and screenshots accurately reflect the live build.
5. The user authorizes custom-page submission.

## Measurement checkpoints

1. Day 0: Record custom-page approval and activation timestamps.
2. Day 3: Check delivery, attribution, crashes, and obvious funnel breaks; do not optimize on conversion with a tiny sample.
3. Day 7: Compare product-page conversion, activation, puzzle completion or watchlist activation, D7 return where available, and revenue per first download.
4. Day 14: Keep, revise, or retire each page based on absolute users and confidence, not rates alone.
5. Day 28: Decide whether to expand the winning position to additional storefronts.

## Daily artifacts

- `docs/international_growth_report.md`
- `docs/admob_weekly_report.md`
- `.build/international-growth/territory_daily.csv`
- `.build/international-growth/product_page_daily.csv`
- `.build/international-growth/custom-product-pages-sync.json`
- `.build/international-growth/custom-product-page-media-sync.json`
- `.build/international-growth/deep-link-ui-attachments/`

## Commands

```bash
scripts/release_health.sh
python3 scripts/sync_custom_product_pages.py --template-version 4.25.39
python3 scripts/sync_custom_product_page_media.py
```

The sync commands are read-only unless their explicit apply flags are provided.
