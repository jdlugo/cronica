# Custom Product Pages

Cronica will launch two focused custom product pages instead of seven generic
variants. The pages separate the two strongest acquisition intents while keeping
measurement interpretable.

## Pages

| Reference name | Search intent | First three screenshots |
|---|---|---|
| Daily Puzzle - International | movie puzzle, emoji game, daily challenge | Puzzle-first Home, regional providers, watchlist |
| Movie Tracker - International | movie tracker, watchlist, episode tracker | Watchlist, regional providers, Home |

Localized promotional text and non-overlapping keyword assignments for France,
Spain, Mexico, and Brazil are defined in `fastlane/custom_product_pages/manifest.json`.

## Build the package

```bash
python3 scripts/prepare_custom_product_pages.py --validate-only
python3 scripts/prepare_custom_product_pages.py
```

The generated package is written to
`.build/international-growth/custom-product-pages`. It contains 48 verified
assets: 2 pages x 4 locales x 3 screens x 2 device classes.

## App Store Connect setup

1. Create each page using the exact reference name in the manifest.
2. Add the four localizations and their promotional text.
3. Upload each locale's staged screenshots in numbered order.
4. Submit both pages for review.
5. After the default metadata containing the target keywords is approved,
   assign each manifest keyword to its matching page and publish visibility.

Apple permits up to 70 custom pages. Each page can localize screenshots,
previews, promotional text, and keywords. Keywords should remain unique across
pages so search intent is unambiguous.

## Measurement gate

Apple exposes page-level analytics after a page receives at least five
first-time downloads. The release-health job downloads detailed Analytics
reports and writes:

- `docs/international_growth_report.md`
- `.build/international-growth/territory_daily.csv`
- `.build/international-growth/product_page_daily.csv`

Review each page weekly by territory using impressions, page views, first-time
downloads, PostHog puzzle activation, and AdMob revenue. Keep absolute counts
next to every rate and do not interpret incomplete source dates as zero.
