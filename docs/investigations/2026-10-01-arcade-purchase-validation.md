# Arcade delivery: purchase configuration and copy

**Superseded on October 1:** The user retired the ad-free offer for 4.25.44. Its UI, product requests, checkout code and StoreKit fixture are removed. Legacy buyer benefits are retained. The verification below describes the earlier implementation, not the release candidate.

Verified locally on October 1, 2026. This change corrects local test configuration and purchase descriptions; it does not change checkout, entitlement handling or production pricing.

`Shared/ProductList.plist` requests `AdFreeUpgrade`. `StoreKitManager` loads those IDs, reads `Transaction.currentEntitlements`, and sets the persisted `hasPurchasedTipJar` flag after a verified purchase. Existing ad gates use that flag to suppress advertising. A non-consumable fixture matches this persistent upgrade behavior; the fixture remains `NonConsumable` and now uses the requested `AdFreeUpgrade` ID.

The StoreKit fixture's English and Brazilian Portuguese descriptions now describe removing ads. Its existing `2.99` display price, internal identifier and family-sharing flag are unchanged local simulation settings, not verified production catalog facts. The iOS scheme already references this fixture.

The `tipJarTitle`, `tipJar`, `tipJarDescription` and `tipJarFooter` entries now describe the optional ad-free purchase in all 15 supported locales. The footer states that a one-time purchase removes ads throughout Streaming Now and supports development. It no longer promises that the free app is always ad-free or offers small, medium and large tips that the runtime does not request.

Validation:

```sh
python3 scripts/check_arcade_purchase_contract.py --self-test
```

Result: one runtime-requested product matches its fixture; all 15 localization files parse and have required purchase descriptions. Five invalid mutations are rejected: unrequested fixture ID, consumable upgrade, duplicate product, missing copy and the old unconditional free/ad-free promise. Running the check before the correction reproduced the product mismatch and stale copy in every locale. The check is static; localized wording and rendering have not been reviewed by native speakers or through all localized screens.

Required external validation remains open:

- Verify the actual App Store product ID, product type, availability, localized metadata and displayed price with the local StoreKit configuration disabled.
- Test sandbox purchase, cancellation, pending/error handling, purchase restoration on a clean install, and ad suppression after relaunch. No successful live or sandbox transaction is claimed by this check.
- Recover AdMob reporting access through the account owner, then refresh earnings. Previous `invalid_grant` / `invalid_rapt` authentication failure is not resolved by this code change; no account reauthentication was performed.
