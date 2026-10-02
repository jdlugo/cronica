# Touch polish evidence

Passing summaries: `iphone-taps-summary.json` (1), `iphone-flows-summary.json` (5), `ipad-summary.json` (3), and `ipad-visible-controls-summary.json` (3, including two repeated checks). These represent ten distinct device/test combinations. Earlier failure bundles remain under `/private/tmp/arcade-touch-*.xcresult`; no failed iteration is counted as passing.

Screenshots are format-converted XCTest attachments. iPhone images come from the final five-flow run. The iPad replay/restarted images come from the stricter viewport run, which requires the whole replay button to fit in the game sheet before tapping it. Other iPad images come from the first passing iPad run.

`verification.json` records current source fingerprints, the base commit, local result paths and script check counts. `review.json` records the adversarial review and remaining evidence boundaries. Simulator fixtures suppress production analytics and use a separate progress store. No upload or physical-device validation is claimed for these changes.
