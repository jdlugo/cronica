# Arcade release candidate 4.25.44 (16)

Scope: retire the ad-free purchase offer, preserve prior buyer benefits, and validate live movie discovery, free-user launch and simulator layouts, then archive, export and upload the current code to TestFlight. No production review submission is part of this pass.

- [x] Confirm live App Store state: 4.25.43 (15), READY_FOR_SALE, VALID.
- [x] Recover space by deleting automation browser downloads, duplicate exported screenshots, and discarded simulator containers; preserve original result bundles and archives.
- [x] Read live App Store purchase catalog: com.dlugokecki.qscan.adfree, non-consumable, APPROVED.
- [x] Found runtime/fixture product-ID mismatch; user subsequently retired the offer, so the product requests and fixture were removed.
- [x] User retired the ad-free upgrade; remove purchase UI, product loading, checkout and local StoreKit fixture; preserve legacy verified ownership and existing ad-free flags.
- [x] Run fixture-free movie discovery/save/relaunch with normal free-user launch settings on iPhone and iPad simulators.
- [x] Run applicable regression suites and signed Release archive/export.
- [x] Upload new binary to TestFlight and independently confirm VALID / IN_BETA_TESTING for internal testers.
- [ ] Physical iPhone/TestFlight smoke and current Arcade PostHog receipt: blocked by locked iPhone Mirroring; user unlock requested.
- [x] New purchase/cancellation testing removed from scope by the user. Legacy entitlement compatibility remains covered without new product requests.

Keep synthetic/local StoreKit checks distinct from sandbox transactions, simulator storage distinct from CloudKit sync, and upload success distinct from processed TestFlight availability.
