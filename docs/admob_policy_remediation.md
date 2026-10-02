# AdMob Site Behavior: Navigation Remediation

## Notice

- AdMob app: Shows with Friends (the current App Store product is Streaming Now)
- Platform: iOS
- Issue: Site Behavior: Navigation
- Original report date: August 27, 2019
- Current status shown in Policy Center: Restricted ad serving

## Remediation implemented

- Removed interstitial ads that appeared after a detail page loaded.
- Removed interstitial ads before trailer playback.
- Removed interstitial ads after puzzle submission and after the user tapped Next Puzzle.
- Removed native ads from Settings, Search, detail overview, iPad detail, and puzzle screens.
- Kept one native ad in the Home content feed, after a populated content section, with an explicit Advertisement label and fixed spacing from interactive controls.
- Hide the Home native ad whenever a Home modal, popover, alert, or action overlay is presented so navigation never overlaps an ad.
- Increased native-ad refresh timing from 30 seconds to 60 seconds.
- Stopped preloading regular interstitial inventory at startup and foreground transitions.
- Kept rewarded hints strictly user initiated, with no regular-interstitial fallback or delayed auto-presentation.
- Kept the dedicated app-open format.

The app discovers and tracks movies and TV shows and links users to provider information. It does not host or claim to stream the titles itself.

## Release gate

Do not request AdMob review until all of these are true:

- The remediation build has passed device navigation checks using test ads.
- The remediation build has been uploaded to App Store Connect.
- The build is available through the App Store for the AdMob reviewer.
- The AdMob app record points to the current App Store listing and its displayed name is no longer misleading or stale.

## Policy Center selection

Select:

> I've uploaded a new version of the app which contains the fix

Do not select "There are no issues on this app." The existing implementation contained placements that could interrupt or be confused with navigation.

## Review response

Prepared for App Store version 4.25.40, build 11:

> We reviewed and corrected the ad implementation for this iOS app, currently listed in the App Store as Streaming Now. In version 4.25.40, build 11, we removed interstitial ads that could interrupt navigation after opening movie or TV detail pages, before trailer playback, after puzzle submission, or after tapping Next Puzzle. We also removed native ads from Settings, Search, detail, and puzzle screens where ads could appear near navigation or interactive controls. The remaining native placement appears only after a populated Home content section, is explicitly labeled "Advertisement," has fixed separation from controls, and is removed whenever a modal, popover, alert, or action overlay is presented. Regular interstitial inventory is not preloaded or presented by the updated production flows. Rewarded hints remain user initiated and never fall back to another format or auto-present later. App-open inventory uses Google's dedicated app-open format. Core content and navigation work without an ad being available. The app is a movie and TV discovery and watchlist tool that provides links to third-party streaming-provider information; it does not claim to host or stream titles. Please re-review the updated App Store build.

## Verification evidence

- Full iOS simulator suite: 235 passed, 0 failed, 0 skipped on iPad Air 11-inch (M3), iOS 26.3.
- Release archive: succeeded for version 4.25.40, build 11.
- App Store Connect upload: accepted on August 28, 2026.
- Home native placement: [home-native-ad.jpg](evidence/admob-policy/home-native-ad.jpg)
- Search without an ad placement: [search-no-ad.jpg](evidence/admob-policy/search-no-ad.jpg)
- Settings overlay with the Home ad removed: [settings-overlay-no-ad.jpg](evidence/admob-policy/settings-overlay-no-ad.jpg)
- Detail navigation without an ad placement: [detail-no-ad.jpg](evidence/admob-policy/detail-no-ad.jpg)
- Solved puzzle with Next Puzzle and no interstitial: [puzzle-next-cta.png](evidence/admob-policy/puzzle-next-cta.png)
- Follow-up puzzle loaded without an interstitial: [puzzle-follow-up-loaded.png](evidence/admob-policy/puzzle-follow-up-loaded.png)
