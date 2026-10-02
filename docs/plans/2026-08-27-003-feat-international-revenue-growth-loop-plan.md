---
title: International Revenue Growth Loop
type: feat
status: active
date: 2026-08-27
origin: user-request
related_plan: docs/plans/2026-08-27-001-feat-revenue-growth-loop-plan.md
---

# International Revenue Growth Loop

## Overview

Increase sustainable international revenue by improving the complete territory funnel for France, Mexico/Spanish, and Brazil:

```text
App Store impression
  -> product-page view or direct Get
  -> first-time download
  -> first launch
  -> Daily Puzzle opened
  -> first guess submitted
  -> puzzle completed
  -> retained user
  -> eligible ad impression
  -> AdMob revenue
```

This plan extends the existing measured revenue loop instead of creating a separate analytics system. `docs/revenue-growth-scorecard.md` remains the authoritative change ledger, PostHog remains behavioral truth, AdMob remains financial truth, and App Store Connect becomes acquisition truth.

The first cycle is a coordinated product and storefront release followed by 72-hour, 14-day, and 28-day checkpoints. After that release, change one major lever per market per decision window so subsequent results remain interpretable.

## Problem Frame

International traffic is already material, but it converts and activates less efficiently than U.S. traffic. The current store pages are translated but position Cronica as a generic movie tracker. The strongest differentiator, Daily Emoji Movie Puzzle, appears in the U.S. subtitle but is absent from the target-market proposition. The puzzle backend is English-first, selected watch providers default to the U.S. for new storage, international storefronts have little or no rating evidence, and the current reporting system cannot join acquisition, activation, retention, and revenue by territory.

The objective is not to maximize impressions or ad clicks independently. It is to increase valuable retained users and target-market revenue without increasing forced ad pressure or degrading puzzle continuation.

## Requirements Trace

| ID | Requirement |
|---|---|
| IR-1 | Treat France, Mexico, and Brazil as the first target-market cohort. Report Spain separately as a secondary Spanish-language observation market. |
| IR-2 | Reposition each target storefront around Daily Emoji Movie Puzzle, with puzzle-first, provider-second, and watchlist-third screenshots. |
| IR-3 | Localize puzzle titles, accepted answers, hints, result text, run-sharing text, and analytics context for `fr-FR`, `es-MX`, and `pt-BR`. |
| IR-4 | Preserve English top-level puzzle fields as a backward-compatible fallback for older clients and unsupported locales. |
| IR-5 | Initialize content/provider region from the device region only when the user has not made an explicit selection. |
| IR-6 | Remove avoidable U.S.-only presentation paths while retaining a documented final fallback when no regional data exists. |
| IR-7 | Request an App Store review only after an earned positive milestone and enforce local cooldown, active-day, and version gates. |
| IR-8 | Publish puzzle-first and tracker-first custom product pages with localized assets and non-overlapping intent keywords where App Store Connect supports them. |
| IR-9 | Build a daily territory report joining App Store Connect, PostHog, and AdMob at aggregate date/territory/build level. |
| IR-10 | Record every shipped growth change, hypothesis, primary metric, guardrail, result, and decision in the existing append-only revenue scorecard. |
| IR-11 | Use pre/post market cohorts for the first cycle. Do not start a randomized product-page optimization test in this phase. |
| IR-12 | Keep credentials and raw downloaded reports out of committed artifacts; commit only aggregate, redacted scorecards and fixtures. |

## Scope Boundaries

- Do not increase interstitial, app-open, rewarded, or native ad frequency in this initiative.
- Do not optimize toward accidental ad clicks or use click-through rate as the north star.
- Do not introduce a subscription, paid acquisition campaign, or new App Store product.
- Do not expand the first implementation cycle beyond French, Mexican Spanish, Brazilian Portuguese, and the English fallback.
- Do not treat China as part of the first optimization cohort. Report it separately because its traffic volume can distort global aggregates.
- Do not perform user-level joins between Apple, PostHog, and AdMob. Correlate aggregate daily territory and release cohorts only.
- Do not overwrite user-selected content or watch-provider regions during migration.
- Do not interact with GitHub, upstream pull requests, or remote repository workflows.

## Baseline Snapshot

Baseline acquisition reports were downloaded on 2026-08-27 from the active App Store Connect Analytics Reports request.

| Source | Complete event dates | Notes |
|---|---|---|
| App Store Discovery and Engagement Standard | 2026-08-14 through 2026-08-26 | Worldwide counts by territory and source. |
| App Downloads Standard | 2026-08-15 through 2026-08-26 | Worldwide first-time downloads, redownloads, and updates. |
| Public storefront lookup | 2026-08-27 | Version `4.25.39` reported released after the acquisition baseline ended. |

### Baseline funnel

| Scope | Impressions | Product-page views | Get taps | First-time downloads | Count-based downloads per impression |
|---|---:|---:|---:|---:|---:|
| U.S. | 5,550 | 360 | 113 | 51 | 0.92% |
| International | 164,498 | 3,840 | 1,380 | 495 | 0.30% |
| Worldwide | 170,048 | 4,200 | 1,493 | 546 | 0.32% |

The count-based ratio is directional and is not Apple's unique-device conversion-rate metric. The implementation must ingest the correct Apple metric when available and label count-based fallbacks explicitly.

### Target-market baseline

| Market | Store locale | Impressions | Page views | Get taps | First-time downloads | Directional download yield | Initial interpretation |
|---|---|---:|---:|---:|---:|---:|---|
| France | `fr-FR` | 2,775 | 212 | 172 | 64 | 2.31% | Strong current relevance; improve activation, ratings, and revenue depth. |
| Mexico | `es-MX` | 1,223 | 72 | 23 | 12 | 0.98% | Promising conversion but small sample; validate the Spanish proposition. |
| Brazil | `pt-BR` | 19,101 | 367 | 155 | 49 | 0.26% | High exposure and absolute installs; primary conversion opportunity. |
| U.S. comparator | `en-US` | 5,550 | 360 | 113 | 51 | 0.92% | Release and seasonality comparator, not a randomized control. |
| China observation | `zh-Hans` | 85,874 | 1,494 | 371 | 129 | 0.15% | Report separately; do not allow it to dominate international averages. |

### Acquisition mix

| Source | Impressions | First-time downloads |
|---|---:|---:|
| App Store search | 168,606 | 538 |
| App Store browse | 1,442 | 4 |
| App referrer | Not present in impression report | 4 |
| Web referrer | Not present in impression report | 0 |

### Social-proof baseline

The U.S. storefront reported five ratings with a 3.6 average. The checked France, Mexico, Brazil, Germany, India, Japan, and China storefronts reported no ratings. Capture rating count and average weekly because ratings are storefront-specific and too sparse for daily decisions.

## Success Metric Hierarchy

### Business outcome

- Target-market total AdMob estimated earnings per complete 28-day window.
- Target-market AdMob revenue per daily active user.

Both metrics are required. Total revenue prevents optimizing a tiny efficient cohort, while revenue per DAU prevents buying low-quality volume with degraded engagement.

### Acquisition drivers

- Unique-device App Store impressions by territory.
- Product-page view rate by territory.
- App Store conversion rate by territory.
- First-time downloads by territory and source.
- Default versus custom product-page first-time downloads.
- Rating count and average by storefront.

### Activation drivers

- First-launch coverage relative to first-time downloads, reported as directional because Apple and PostHog populations differ.
- Daily Puzzle open rate among new users.
- Puzzle open-to-first-guess rate.
- Solve and terminal-completion rate.
- Next Puzzle continuation and load rate.
- Localized-puzzle fallback rate.

### Retention drivers

- D1 and D7 retention by first-seen build and device country.
- D1 and D7 puzzle-active retention by puzzle locale.
- Puzzle rounds per runtime session.
- Distinct active days before review eligibility.

### Monetization drivers

- AdMob impressions and estimated earnings by country.
- Revenue per DAU by country.
- Revenue per first-time download at D7 and D28, reported at aggregate cohort level.
- Revenue per 1,000 App Store impressions.
- Match rate, show rate, and eCPM by country and format.
- Rewarded-hint completion rate without increasing forced-ad frequency.

### Guardrails

- Next Puzzle load rate remains above 95%.
- Open-to-first-guess does not regress by more than 5 percentage points within a market.
- D1 or D7 retention does not regress by more than 5 percentage points when the sample is decision-grade.
- Crash-free sessions do not regress materially by target locale/build.
- No review request occurs during onboarding, an ad presentation, or before an earned milestone.
- No user-selected provider region is overwritten.
- No target-market release uses English puzzle copy when a valid target localization exists.

## Cohort and Attribution Contract

### Canonical dimensions

| Dimension | Source of truth | Use |
|---|---|---|
| App Store territory | App Store Connect | Acquisition and storefront conversion. |
| Device country | PostHog GeoIP/device context | Product activation and retention segmentation. |
| Device locale | App runtime | UI language and localization behavior. |
| Content region | App settings | TMDb and release-content behavior. |
| Puzzle locale | Resolved puzzle payload | Puzzle-language quality and fallback behavior. |
| Revenue country | AdMob | Monetization truth. |
| App version/build | App telemetry and release ledger | Release cohort comparison. |

Do not present these dimensions as if they identify the same individual. Join only by normalized ISO territory, complete date, and release observation window.

### Required PostHog properties

Add these common properties to relevant production events:

| Property | Meaning |
|---|---|
| `app_locale` | Effective app UI locale. |
| `device_region` | Device region code. |
| `content_region` | Effective content/watch-provider region. |
| `puzzle_locale` | Locale selected for the puzzle payload. |
| `puzzle_localization_source` | `exact`, `language_fallback`, or `canonical_fallback`. |
| `app_version` | Existing release version property. |
| `build_number` | Existing build property. |
| `runtime_session_id` | Existing session correlation property. |

Do not add raw title guesses, personal identifiers, or full user-entered text to analytics.

## Key Technical Decisions

### Localized puzzle schema

Keep the current top-level English-compatible fields and add locale-specific content under a backward-compatible map:

```text
puzzle_id
tmdb_id
media_type
title
emoji_clue
hint_1
hint_2
accepted_answers
localizations
  fr-FR
    title
    emoji_clue
    hint_1
    hint_2
    accepted_answers
  es-MX
  pt-BR
```

The exact persisted representation is an implementation decision, but it must preserve these behaviors:

- Old clients continue reading canonical top-level fields.
- New clients resolve exact locale, then language-compatible localization, then canonical top-level fields.
- The puzzle ID remains stable across locales so streaks and completion records do not split.
- Localized accepted answers include common local release titles and normalized variants.
- The canonical title remains accepted when appropriate.
- Analytics records which fallback path was used without sending the user's guess.

### Region initialization

`SettingsStore` must distinguish an absent region preference from an explicit `.us` selection. A new install initializes a supported region from `Locale.userRegion`; an existing or explicit user preference remains unchanged. Unsupported regions use a documented fallback without rewriting storage.

Release-date lookup order becomes user region, production region, then U.S. only as the final data fallback. Search result presentation must not skip directly to U.S. when regional data exists.

### Review prompt ownership

Create one eligibility coordinator instead of adding another direct `requestReview()` call to feature code. The coordinator evaluates state and returns an eligibility decision; the SwiftUI view owns the environment call.

Initial eligibility contract:

- At least three distinct active days.
- At least one earned positive milestone: canonical Daily Puzzle solved, three-round run completed, or fifth watchlist item added.
- No request in the same app version.
- At least 180 days since the previous request attempt.
- No active onboarding, blocking sheet, or full-screen ad.
- Telemetry records eligibility, request attempt, and suppression reason, but never claims that Apple displayed the prompt.

The existing manual review action in Settings remains available.

### Storefront positioning

Use the metadata generator as source of truth. Do not hand-edit generated target-locale files without updating `scripts/generate_localized_metadata.py`.

Target-market creative order:

| Position | Promise | Required proof |
|---|---|---|
| 1 | Daily Emoji Movie Puzzle | Localized puzzle UI with readable emoji, answer controls, and daily/streak value. |
| 2 | Find where to watch | Target-region provider selection or clearly regional content. |
| 3 | Keep a watchlist | Watchlist organization and sync value. |
| 4+ | Discovery, reminders, cast, trailers | Supporting breadth after the differentiator. |

Store copy should use market-native search language and lead with the puzzle while retaining movie/series tracking terms. A native-language quality review is a publication gate for French, Mexican Spanish, and Brazilian Portuguese.

### Custom product pages

Start with two pages, not all seven pages described in `fastlane/CUSTOM_PRODUCT_PAGES.md`:

| Page | Search intent | First asset |
|---|---|---|
| Puzzle First | Daily puzzle, emoji game, guess the movie | Localized Daily Puzzle result/playing screen. |
| Tracker First | Movie tracker, series tracker, watchlist, where to watch | Localized watchlist/provider screen. |

Use non-overlapping keyword assignments. Store page IDs and localized asset manifests in the repository, support dry-run output, and require explicit authorization before a mutating App Store Connect sync. Update `fastlane/CUSTOM_PRODUCT_PAGES.md` during implementation if its U.S.-only assumptions no longer match current App Store Connect behavior.

## Implementation Units

### Unit 0: Freeze the measurement contract and baseline

**Goal:** Make the pre-change state reproducible before product or storefront changes ship.

**Requirements:** IR-9, IR-10, IR-11, IR-12

**Files:**

- Modify: `docs/revenue-growth-scorecard.md`
- Create: `scripts/pull_app_store_analytics.py`
- Create: `scripts/analyze_international_growth.py`
- Modify: `scripts/release_health.sh`
- Create: `scripts/tests/test_pull_app_store_analytics.py`
- Create: `scripts/tests/test_analyze_international_growth.py`
- Create: `scripts/tests/fixtures/app_store_engagement.tsv`
- Create: `scripts/tests/fixtures/app_store_downloads.tsv`

**Approach:**

- Download existing ongoing App Store Analytics report segments into an ignored `.build/international-growth/` workspace.
- Track segment IDs/checksums so reruns do not double-count previously processed batches.
- Normalize Apple, PostHog, and AdMob territory codes into one aggregate daily table.
- Add target-market, U.S. comparator, China observation, and non-target aggregate sections.
- Emit a redacted Markdown summary and append decisions manually to the authoritative scorecard.
- Make missing credentials or delayed reports explicit rather than silently emitting zeros.

**Test scenarios:**

- Multiple report instances and late segments are processed once.
- A rerun with the same segment IDs produces identical totals.
- Unknown territory codes are preserved as `Unknown` and reported separately.
- Privacy-suppressed or missing metrics render as unavailable, not zero.
- Apple dates, PostHog dates, and AdMob dates normalize to one reporting timezone.
- No API token, private key contents, signed URL, or raw user data appears in generated Markdown.

**Checkpoint:** Baseline totals reproduce the table in this plan and the report states its completeness dates.

### Unit 1: Add international telemetry dimensions

**Goal:** Make activation, retention, and puzzle behavior measurable by locale and content region.

**Requirements:** IR-9, IR-10, IR-12

**Files:**

- Modify: `Shared/Manager/CronicaTelemetry.swift`
- Modify: `Shared/ViewModel/DailyPuzzleFeature.swift`
- Modify: `scripts/posthog_audit.sh`
- Modify: `docs/daily-puzzle-analytics-kpis.md`
- Test: `CronicaTests/DailyPuzzleViewModelTests.swift`
- Test: `CronicaTests/SettingsStoreTests.swift`

**Approach:**

- Register stable app locale, device region, and content region properties.
- Attach puzzle locale and fallback source to Daily Puzzle events.
- Add target-market acquisition-to-activation and puzzle funnels to the PostHog audit.
- Preserve production-only telemetry behavior for normal simulator/debug configurations.

**Test scenarios:**

- Every Daily Puzzle funnel event includes puzzle locale and fallback source.
- Locale changes between launches update common properties without changing release identity.
- No guess text or localized title is emitted.
- Telemetry-disabled runtime behavior remains disabled.

**Checkpoint:** A production-capable/TestFlight session from each target locale appears in PostHog with the expected dimensions.

### Unit 2: Localize Daily Puzzle content end to end

**Goal:** Serve solvable, culturally legible puzzles in French, Mexican Spanish, and Brazilian Portuguese.

**Requirements:** IR-3, IR-4

**Files:**

- Modify: `functions/src/puzzleSchema.ts`
- Modify: `functions/src/puzzleQuality.ts`
- Modify: `functions/src/tmdb.ts`
- Modify: `functions/src/index.ts`
- Modify: `Shared/Model/DailyPuzzle.swift`
- Modify: `Shared/ViewModel/DailyPuzzleFeature.swift`
- Modify: `Shared/Resources/Localizable.xcstrings`
- Modify: `scripts/seed_daily_puzzles_firestore.sh`
- Modify: `scripts/seed_practice_puzzles_firestore.sh`
- Test: `functions/src/__tests__/puzzleSchema.test.ts`
- Test: `functions/src/__tests__/puzzleQuality.test.ts`
- Test: `functions/src/__tests__/tmdb.test.ts`
- Test: `CronicaTests/DailyPuzzleViewModelTests.swift`
- Create test: `CronicaTests/DailyPuzzleLocalizationTests.swift`

**Approach:**

- Generate or fetch localized TMDb titles and common alternate titles for target locales.
- Add localized hints and accepted-answer aliases while preserving canonical fields.
- Resolve exact locale, language fallback, and canonical fallback deterministically on iOS.
- Localize run summaries, attempts, hints, streak, and sharing text through the string catalog.
- Apply the existing solvability bias independently in each language.

**Test scenarios:**

- `fr-FR`, `es-MX`, and `pt-BR` resolve their exact payloads.
- `fr-CA`, generic `es`, and generic `pt` use the expected language fallback when available.
- Unsupported locales use canonical fields without crashing or producing empty answers.
- French accents, Spanish punctuation/diacritics, and Portuguese diacritics normalize correctly.
- Local and canonical release titles are accepted when configured.
- Old top-level-only Firestore records remain playable.
- A localized puzzle retains the same puzzle ID and streak semantics across locales.

**Checkpoint:** Backend schema/quality tests and iOS localization tests pass, and one real puzzle is solved in each target locale on a simulator.

### Unit 3: Correct region defaults and U.S.-only fallbacks

**Goal:** Make content and watch-provider behavior relevant on first launch without overriding explicit preferences.

**Requirements:** IR-5, IR-6

**Files:**

- Modify: `Shared/Store/SettingsStore.swift`
- Modify: `Shared/Extensions/Locale-Extensions.swift`
- Modify: `Shared/Network/NetworkService.swift`
- Modify: `Shared/Manager/DatesManager.swift`
- Modify: `Shared/Extensions/SearchItemContent-Extension.swift`
- Modify: `Shared/View/WatchProviders/WatchProvidersList.swift`
- Test: `CronicaTests/SettingsStoreTests.swift`
- Create test: `CronicaTests/RegionalContentTests.swift`

**Approach:**

- Detect whether the provider-region preference is absent before applying a locale-derived default.
- Preserve explicit `.us` and all other user selections.
- Use user region consistently for provider and release-date presentation.
- Retain production-region and U.S. fallback only when regional data is unavailable.

**Test scenarios:**

- A new French, Mexican, and Brazilian install selects the supported local region.
- An existing explicit U.S. selection remains U.S. after update.
- An unsupported device region uses fallback behavior without persisting a false preference.
- Release dates prefer user region, then production region, then final U.S. fallback.
- Provider fetches use the effective region after migration.

**Checkpoint:** Locale-specific simulator launches show local provider settings and regional content without manual setup.

### Unit 4: Add an earned review-prompt coordinator

**Goal:** Build international social proof after demonstrated value without interrupting the user.

**Requirements:** IR-7, IR-9, IR-10

**Files:**

- Create: `Shared/Manager/ReviewPromptCoordinator.swift`
- Modify: `Shared/View/Navigation/HomeView.swift`
- Modify: `Shared/Store/SettingsStore.swift`
- Modify: `Shared/Resources/Localizable.xcstrings`
- Test: `CronicaTests/DailyPuzzleViewModelTests.swift`
- Create test: `CronicaTests/ReviewPromptCoordinatorTests.swift`

**Approach:**

- Track distinct active days and qualifying positive milestones locally.
- Return explicit eligible/suppressed decisions with testable reasons.
- Let `HomeView` invoke SwiftUI's `requestReview` only after the result UI settles and no full-screen ad is active.
- Keep manual Settings review actions unchanged.
- Record request attempts, not assumed prompt displays or ratings.

**Test scenarios:**

- A first-day solve is not eligible.
- A qualifying milestone after three active days is eligible.
- The same app version cannot request twice.
- A request within 180 days is suppressed.
- Onboarding, an active sheet, or a full-screen ad suppresses the request.
- Advancing the test clock/version produces eligibility at the correct boundary.

**Checkpoint:** A controlled simulator path reaches the request call only under eligible conditions; production rating changes remain an observation metric, not a test assertion.

### Unit 5: Reposition target storefronts and screenshots

**Goal:** Make the unique puzzle value obvious before download in France, Mexico, and Brazil.

**Requirements:** IR-1, IR-2, IR-10

**Files:**

- Modify: `scripts/generate_localized_metadata.py`
- Modify: `scripts/fetch_localized_content.py`
- Modify: `CronicaTests/Screenshots/HomeScreenshotView.swift`
- Modify: `CronicaTests/Screenshots/MarketingScreenshotView.swift`
- Modify: `CronicaTests/Screenshots/MarketingHeadlines.swift`
- Modify: `CronicaTests/Screenshots/MarketingScreenshotTests.swift`
- Modify generated output: `fastlane/metadata/fr-FR/`
- Modify generated output: `fastlane/metadata/es-MX/`
- Modify generated output: `fastlane/metadata/es-ES/`
- Modify generated output: `fastlane/metadata/pt-BR/`
- Modify generated output: `fastlane/screenshots/fr-FR/`
- Modify generated output: `fastlane/screenshots/es-MX/`
- Modify generated output: `fastlane/screenshots/es-ES/`
- Modify generated output: `fastlane/screenshots/pt-BR/`
- Test: `CronicaTests/Screenshots/MarketingScreenshotTests.swift`
- Test: `CronicaTests/Screenshots/LocalizedScreenshotTests.swift`
- Create test: `scripts/tests/test_generate_localized_metadata.py`

**Approach:**

- Lead localized name/subtitle/promotional text with the daily puzzle while retaining high-intent tracking terms.
- Capture puzzle-first localized marketing screenshots.
- Show target-region provider/content proof in the second position.
- Regenerate through existing scripts and validate App Store character limits.
- Require native-language copy review before upload.

**Test scenarios:**

- Target-market name, subtitle, keywords, and promotional text stay within Apple limits.
- Puzzle-first screenshot is exported as position `01` for all target locales and required device sizes.
- Localized text does not clip at iPhone and iPad dimensions.
- The first three screenshots prove puzzle, provider, and watchlist promises in that order.
- Spanish Spain and Spanish Mexico remain intentionally distinct where copy or provider context differs.

**Checkpoint:** Reviewed target metadata and screenshot sets are ready for Fastlane upload and visually approved in all four store locales.

### Unit 6: Publish intent-specific custom product pages

**Goal:** Route puzzle and tracker search intent to the most relevant localized story.

**Requirements:** IR-8, IR-10, IR-12

**Files:**

- Modify: `fastlane/CUSTOM_PRODUCT_PAGES.md`
- Create: `fastlane/custom_product_pages/puzzle-first/`
- Create: `fastlane/custom_product_pages/tracker-first/`
- Create: `scripts/sync_custom_product_pages.py`
- Create test: `scripts/tests/test_sync_custom_product_pages.py`

**Approach:**

- Store page definitions, localization manifests, asset ordering, and keyword assignments in versioned files.
- Support validation and dry-run modes before any API mutation.
- Create or update idempotently by stable reference name.
- Publish only after the associated binary/default metadata is approved.
- Include page-level impressions, downloads, and conversion in the territory report.

**Test scenarios:**

- Dry-run renders the intended page/localization/keyword diff without network mutation.
- Re-running against existing page IDs does not create duplicates.
- Puzzle and tracker keyword sets do not overlap within a localization.
- Missing screenshots or unsupported locales block publication before mutation.
- API failure leaves the previous approved page visible and reports the partial state.
- Credentials and signed upload URLs are redacted.

**Checkpoint:** Both pages are approved, visible, and attributed separately in App Store Connect Analytics.

### Unit 7: Release, observe, and decide

**Goal:** Ship one measurable target-market release and turn results into the next bounded iteration.

**Requirements:** IR-1 through IR-12

**Files:**

- Modify: `docs/revenue-growth-scorecard.md`
- Modify: `docs/daily-puzzle-analytics-kpis.md`
- Modify: `fastlane/Fastfile`
- Modify: `fastlane/README.md`

**Approach:**

- Record the build, App Store version, metadata set, backend schema version, PostHog insight version, and custom-page IDs as one release observation unit.
- Validate backend, focused iOS tests, localized simulator flows, archive/signing, TestFlight telemetry, metadata, and public storefront rendering at separate gates.
- Begin the observation window only when the public version and target metadata are visible.
- Do not change ad pacing during the 28-day observation window unless a safety rollback is required.

**Test scenarios:**

- French, Mexican Spanish, and Brazilian Portuguese users can open, guess, solve, continue, share, and reach the earned review decision path.
- Missing localized backend content falls back safely and emits fallback telemetry.
- Paid, preview, and consent-ineligible paths preserve existing ad behavior.
- Fastlane validates target metadata and selected screenshot ordering before upload.
- TestFlight emits target locale/region properties and production ad events.
- Public storefront verification confirms localized copy, screenshots, version, and availability.

**Checkpoint:** Release ledger row is complete, the daily report recognizes the new build, and 72-hour monitoring begins.

## Release Gates

| Gate | Evidence required | Blocks |
|---|---|---|
| G0 Baseline | App Store, PostHog, and AdMob completeness dates and target-market baseline recorded. | Product implementation. |
| G1 Backend contract | Puzzle schema, quality, TMDb, and fallback tests pass. | Firebase deployment. |
| G2 iOS behavior | Focused localization, region, review, and puzzle tests pass. | Archive/TestFlight. |
| G3 Visual locale | Simulator evidence for `fr-FR`, `es-MX`, and `pt-BR`; no clipping or English fallback in target flows. | Store asset approval. |
| G4 Production telemetry | TestFlight events contain release, locale, region, and puzzle fallback properties. | App Store submission. |
| G5 Store metadata | Fastlane validation, native-language review, screenshot order, and custom-page dry-run pass. | Metadata upload. |
| G6 Public release | Public version, target metadata, screenshots, and availability verified separately from upload acceptance. | Observation window. |
| G7 Safety | 72 complete hours with no material crash, continuation, localization, or ad-policy regression. | Growth interpretation. |
| G8 Directional | 14 complete days plus minimum market samples where available. | First iteration decision. |
| G9 Durable | 28 complete days including D7 cohorts and AdMob revenue completeness. | Scale/expand decision. |

## Observation Cadence

### Daily automated report

- Refresh App Store report instances and segment checksums.
- Refresh PostHog target-market activation/retention queries.
- Refresh AdMob country/formats report.
- Render target, comparator, and China-observation sections.
- Flag missing data, report lag, fallback spikes, crash regressions, or Next Puzzle load below 95%.
- Do not make growth decisions from an incomplete date.

### Twice-weekly operational check

- Review absolute sample size beside every rate.
- Confirm public metadata and custom pages remain visible.
- Inspect puzzle localization fallback and wrong-answer concentration without collecting raw guesses.
- Verify rating-count movement and support feedback by storefront.

### 14-day directional review

- Compare each target market with its own pre-release baseline.
- Use the U.S. and non-target aggregate only to identify release-wide or seasonal movement.
- Choose one next lever per market: copy/keywords, screenshots, puzzle content, activation flow, or no change.
- Append the result and decision to `docs/revenue-growth-scorecard.md`.

### 28-day durable review

- Include complete D7 cohorts and AdMob revenue.
- Decide whether to scale, iterate, hold, or stop each market.
- Rank the next market using impression volume, conversion, activation, D7 retention, revenue per DAU, and localization cost.

## Decision Rules

### Sample labels

| Label | Minimum evidence | Allowed decision |
|---|---|---|
| Safety-only | Less than 2,000 impressions or less than 30 first-time downloads | Roll back defects only; do not claim growth. |
| Directional | At least 2,000 impressions and 30 first-time downloads | Continue, revise, or hold based on funnel-stage movement. |
| Decision-grade | At least 10,000 impressions and 100 first-time downloads, with a complete D7 cohort | Scale, stop, or select the next market. |

If a market does not reach a threshold in the stated window, extend the observation window rather than lowering the threshold after seeing results.

### Promote

Promote the current market treatment when:

- App Store conversion or first-time downloads improve by at least 15% relative to that market's baseline.
- Puzzle open-to-first-guess and D7 retention do not breach guardrails.
- Revenue per DAU is flat or improving.
- No rating, crash, continuation, or policy regression is present.

### Iterate

Choose one bounded iteration when:

- Impressions are healthy but page-view/Get/download yield does not improve: change storefront promise, keywords, or first screenshot.
- Downloads improve but puzzle activation remains more than 10 percentage points below the U.S. comparator: change onboarding, puzzle localization, or content relevance.
- Activation and retention improve but revenue per DAU does not: investigate AdMob show rate, format mix, and eCPM without increasing forced frequency.
- Fallback usage exceeds 5% in a target locale: fix content coverage before acquiring more users.

### Hold

Hold when metrics move in opposite directions and the sample is below decision-grade. Preserve the release, collect more complete data, and do not stack another change.

### Stop or roll back

Stop or roll back the responsible change when:

- Next Puzzle load falls below 95%.
- D1 or D7 retention declines by more than 5 percentage points at a decision-grade sample.
- Revenue per DAU declines by more than 15% without a compensating retained-user increase.
- Crash-free sessions materially regress in a target locale/build.
- Review prompting occurs outside the eligibility contract.
- A localized puzzle cannot be solved with its displayed local title or accepted aliases.

## Change Ledger Contract

Append rows to the existing ledger using IDs in this series:

| ID | Change class | Primary metric |
|---|---|---|
| IG-000 | Baseline and joined reporting | Complete daily territory funnel. |
| IG-001 | Locale/region telemetry | Target-market event coverage. |
| IG-002 | Localized puzzle and regional defaults | Puzzle activation and fallback rate. |
| IG-003 | Earned review prompting | Rating count and request eligibility. |
| IG-004 | Target storefront repositioning | App Store conversion and first-time downloads. |
| IG-005 | Puzzle-first/tracker-first custom pages | Page-level conversion by intent. |

Every ledger row must include:

- App version and build.
- Backend schema/deployment identifier when applicable.
- Store locales and custom-page IDs affected.
- Exact public visibility timestamp.
- Hypothesis written before results.
- Primary metric and guardrail.
- Baseline window and observation window.
- Absolute sample counts.
- Observed result.
- Decision: promote, iterate, hold, stop, or roll back.
- Next single lever.

Historical hypotheses and thresholds must not be rewritten after results arrive.

## System-Wide Impact

- **Acquisition:** App Store metadata, screenshots, custom product pages, and keyword routing change target-market discovery and conversion.
- **Backend:** Firestore puzzle records gain locale-aware content while retaining canonical fields for old clients.
- **Client:** Puzzle decoding/resolution, sharing, regional defaults, review eligibility, and common telemetry properties change.
- **Analytics:** Apple, PostHog, and AdMob remain separate sources with aggregate joins and explicit data lag.
- **Release:** Storefront visibility, analytics completeness, and TestFlight telemetry are distinct gates from successful build/upload.
- **Privacy:** No raw guesses, person-level cross-platform joins, API credentials, or signed report URLs enter committed reports.
- **Operational:** A daily report supports safety monitoring; 14/28-day reviews govern growth changes.

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Apple reports lag by two to three days | Label completeness date and exclude incomplete dates from decisions. |
| Territory definitions differ across vendors | Normalize ISO codes but keep source-specific labels and avoid user-level attribution. |
| Small samples create false confidence | Use absolute counts, sample labels, fixed thresholds, and longer windows. |
| Coordinated release obscures causal attribution | Diagnose by funnel stage and change one major lever per market after the initial release. |
| Machine-translated store copy reduces trust | Require native-language publication review. |
| Local titles create answer ambiguity | Store multiple accepted aliases, preserve canonical answers, and test diacritics. |
| New locale schema breaks old clients | Keep top-level canonical fields and test top-level-only records. |
| Review prompt annoys users | Require earned milestone, active days, version gate, cooldown, and no active ad/sheet. |
| Custom-page API causes duplicate or partial pages | Use stable reference names, idempotent sync, dry-run, and failure reporting. |
| China dominates international averages | Report China separately and make decisions per target market. |
| Revenue improves through harmful ad pressure | Freeze ad cadence for the observation window and enforce retention/continuation guardrails. |

## Execution Order

1. Complete Unit 0 and freeze IG-000 before any user-facing change.
2. Implement Units 1 through 4 behind the same release branch, with backend compatibility first.
3. Produce Unit 5 storefront assets from the localized product, not preview-only mock behavior.
4. Pass G1 through G5, then deploy backend and submit the app/store metadata.
5. Verify G6 public visibility and start the observation clock.
6. Publish Unit 6 custom pages after the default release is approved and visible.
7. Run G7 at 72 complete hours, G8 at 14 complete days, and G9 at 28 complete days.
8. Select one bounded next lever per market and append the decision before implementation begins.

## Definition of Done

- France, Mexico, and Brazil have puzzle-first localized default product pages.
- Puzzle-first and tracker-first custom pages are approved and separately measurable.
- Daily Puzzle titles, answers, hints, results, and sharing resolve in French, Mexican Spanish, and Brazilian Portuguese with safe fallback.
- New installs default content/provider region from a supported device region without overriding existing preferences.
- Review prompting follows the centralized earned-milestone contract.
- The daily report joins App Store acquisition, PostHog behavior, and AdMob revenue by aggregate territory/date/build.
- IG-000 through the shipped change IDs are recorded in the existing scorecard.
- Test, TestFlight, public storefront, 72-hour safety, 14-day direction, and 28-day durable checkpoints are recorded.
- The next iteration is selected from evidence and changes only one major lever per market.
