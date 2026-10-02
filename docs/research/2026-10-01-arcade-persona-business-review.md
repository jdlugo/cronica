# Arcade personas: movie utility and purchase trust

October 1, 2026; local baseline `6b249b89`. This is a bounded source walkthrough using invented P4/P6 reference constraints. It is not a human playtest, a transaction test, a fresh analytics query or evidence of purchase intent. No production changes or account access were performed.

## P4 Casey: installed to find something to watch

**Source-derived scenario:** Home → Movie Arcade → completed practice result → seek movie details/watchlist/availability → return to discovery.

Arcade appears before Up Next, Upcoming Watchlist, pins and Trending ([HomeView.swift:65](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/Shared/View/Navigation/HomeView.swift:65)). The result renders an image/reveal and offers Play Another/Try a Different Game; the Daily Mix offers progression and a score/share summary ([MovieArcadeView.swift:527](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/Shared/View/Navigation/MovieArcadeView.swift:527)). Its scene image explicitly disables hit testing (line 602). There is no result action to inspect the recovered film, save it or check availability.

**Fixture outcome:** Casey reaches the declared stopping condition: no useful next action for the movie-discovery job. This identifies a missing connection, not an observed player's dislike or abandonment.

**Disconfirming evidence:** reveals teach movie/cast/year connections; movie discovery remains available on Home, and Close returns from the sheet. Some people may value learning without saving a film. Therefore “Arcade harms discovery” is unproved. Home order creates a possible displacement cost, not measured harm.

**Small objective:** add one optional Explore Film action to single-film results using existing detail routing, retaining Play Another as the primary action. For multiple-film results, define which recovered film is offered before coding. Acceptance: correct movie ID opens details, back returns to the earned result, replay remains available, and entry/result/detail/watchlist outcomes can be reconciled. Human test: a discovery-oriented participant independently finds something useful to watch/save; measure useful actions per eligible completed result, with replay and overall discovery as guardrails.

## P6 Riley: skeptical potential buyer

**Source-derived scenario:** free Home/gameplay → earned result → optional Remove Ads in Settings → purchase/restore → continued ad-free use.

The English footer accurately says an optional one-time purchase removes ads throughout Streaming Now ([Localizable.strings:74](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/Shared/Localization/en.lproj/Localizable.strings:74)). Runtime configuration requests `AdFreeUpgrade`; the local non-consumable fixture now matches it. The purchase row uses StoreKit display name, description and price rather than a hard-coded live price ([TipJarSetting.swift:67](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/Shared/View/Settings/TipJarSetting.swift:67)). Game completion/replay does not require payment. No result upsell exists.

**Disconfirming evidence against “monetization is broken”:** verified purchase sets the persisted paid flag, and app-open/native/interstitial/rewarded gates consult it ([StoreKitManager.swift:44](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/Shared/Manager/StoreKitManager.swift:44), [AdCoordinator.swift:689](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/Shared/Configuration/AdCoordinator.swift:689)). Existing mocked ad-gating tests provide narrower evidence; they do not establish a successful purchase or restore.

**Unresolved trust risks:** restore calls `try? await AppStore.sync()` without visible success/error feedback (TipJarSetting lines 30–35); purchase errors likewise have no presented recovery state. Entitlement reconciliation refreshes `purchasedTipJar` but does not directly synchronize/reset the persisted paid flag; a row's change callback can set it positively ([StoreKitManager.swift:94](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/Shared/Manager/StoreKitManager.swift:94), TipJarSetting lines 81–84). Clean-install restoration, refunds/revocations and product-load races need reproduction; no failure is claimed.

Foreground presentation consults paid status/cooldown/inventory, without a first-value condition ([StreamingNowApp.swift:161](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/Shared/Configuration/StreamingNowApp.swift:161)). Existing historical evaluation observed a test ad before Home. Arcade fixture runs suppress monetization, so their completion evidence cannot answer Riley's surprise-ad concern or ad interruptions on foreground resume.

**Fixture outcome:** payment is optional and explained, but the promised live benefit cannot be verified. Riley stops at that evidence boundary; this is not unwillingness to pay. Before any offer experiment, test actual catalog/price, purchase/cancel/pending/error, clean-install restore, relaunch and revoked entitlement, with visible feedback and suppression checks across all placements. Do not introduce an upsell merely to satisfy this persona.

## Eight questions: what this review actually answers

| Question | Current conclusion / next discriminating evidence |
| --- | --- |
| 1. Voluntary second round? | Replay controls exist; willingness remains a human observation. |
| 2. Tomorrow's value? | Daily rotation exists; twelve films limit the proposition. Multi-day novelty probes plus an optional human return are needed. |
| 3. Drop-off/funnel trust? | Schema-2 contract exists; reconcile one real-device event trace before attributing exits to difficulty. |
| 4. Invest in which games? | Curated three are hypotheses. Compare comprehension, independent replay and repeated-content recognition before ranking preferences. |
| 5. Ad trade-off? | Startup exposure is plausible and previously observed; causal retention/revenue cost is unknown. Test separately from entry changes. |
| 6. Paid value works? | Static product/copy agreement only; live transaction and suppression gates remain. |
| 7. Strengthens discovery? | Direct result bridge is absent; prototype one useful action and assess displacement as well as uptake. |
| 8. Smallest useful release? | Existing improvements plus validated transactions/events, then a 6–8-person study. No new game or subscription is required. |

The October 1 historical report records no arcade events, incomplete environment/session coverage and unavailable current AdMob earnings ([growth objectives:11](/Users/johndlugokecki/.codex/worktrees/86e4/Cronica/docs/investigations/2026-10-01-arcade-growth-objectives.md:11)). Absence is not zero demand; cached earnings are not current revenue. Revenue per experiment arm needs verified purchase proceeds and attributable ad paid-value data or an explicitly aggregate design. Current source has no randomized assignment. No retention or revenue improvement follows from these personas.

Priority: **(1)** transaction and event reconciliation; **(2)** human first-value/ad/discovery observation; **(3)** one reversible discovery bridge. A purchase offer remains gated on demonstrated value and reliable revenue measurement.
