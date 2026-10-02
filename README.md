# Cronica

<p align="center">
    <img src="https://github.com/MadeiraAlexandre/Cronica/blob/main/Shared/Assets.xcassets/MacAppIcon.appiconset/icon_512x512.png?raw=true" alt="Cronica Icon" width="150" height="150" />
</p>

<p align="center">
    Cronica is a minimalist watchlist app that reminds you about upcoming releases.
</p>

<p align="center">
    <a href="https://twitter.com/CronicaApp">
        <img src="https://img.shields.io/badge/Twitter-@CronicaApp-blue.svg?style=flat" alt="Twitter: @CronicaApp" />
    </a>
<img src="https://img.shields.io/github/license/MadeiraAlexandre/Cronica" alt="GitHub license MIT badge" />

</p>


<p align="center">
    <img src="https://raw.githubusercontent.com/MadeiraAlexandre/Cronica/main/Screenshots/iPhone.webp" alt="Cronica Home view Screenshot" minWidth="220" maxWidth="440" height="380">
</p>

## About

Cronica is built using Swift and SwiftUI, it uses Core Data to persist the user's watchlist, and CloudKit to sync the list effortlessly between the user's device. 

To provide release notifications, the app takes advantage of local notifications to notify users about new episodes or a movie release. To keep notifications useful, there's a background task that updates item values with new information using TMDb API, if needed.

Thanks to CloudKit and SwiftUI, Cronica also can run on every Apple device, and the information will automatically sync.

## Project Organization
If you want to contribute with code, here are some important details about the project's organization:

- The code-base for the Mac, iPhone, iPad, and Apple TV versions is shared and resides within the "Shared" folder.
- While the Apple Watch also utilizes the same networking as the other platforms, it has a different user interface (UI) design. The Apple Watch-specific UI components are located in the "Apple Watch" folder. However, certain UI components are shared among all platforms and can be found in the "Shared" folder.
- The views are organized based on their relationship with models or functionality. For instance, the "ItemContent" struct represents data fetched from the TMDb service, which can refer to a movie or a TV show. The UI elements associated with this struct are grouped under the "ItemContent" group in the "Views" folder. An example of such a UI element is the details page that users see when they open a movie.
- The logic for most of the views is separated using extensions, primarily to help maintain the project in the long run.
- If you have any questions, feel free to reach out to me via email, Twitter, or iMessage. I'll be happy to assist you.

##  Build information

#### This project targets iOS 26, iPadOS 26, watchOS 10,  macOS 14, tvOS 17 and requires Xcode 26.

To get started you'll need to:

- Get an API key to use TMDb API, you can get yours at their [website](https://www.themoviedb.org/documentation/api),  after that, go to Shared/Configuration/Key and replace the value of *tmdbApi* with your own key.

## Automated Preview Videos

Generate iOS preview videos with Swift XCTest scenarios + simulator recording:

```bash
python3 scripts/record_preview_videos.py --output-dir fastlane/preview_videos
# optional:
python3 scripts/record_preview_videos.py --scenario home-discovery
fastlane ios preview_videos
```

Detailed guide: `docs/preview-video-automation.md`.

## Daily Puzzle Backend Ops

Seed Firestore with the default daily puzzle bank:

```bash
bash scripts/seed_daily_puzzles_firestore.sh
```

Verify seeding + endpoint health in one command:

```bash
bash scripts/verify_daily_puzzle_backend.sh
```

Prepare values for a universal Daily Puzzle push campaign (Firebase Console):

```bash
./scripts/prepare_universal_daily_puzzle_push.sh
```

Workflow reference: `docs/daily-puzzle-universal-push-workflow.md`.

Note: deploying HTTPS Cloud Functions for daily puzzle endpoints requires the Firebase project to be on the Blaze plan.

## App Store

### iOS/iPadOS

<p align="center">
	<img src="https://raw.githubusercontent.com/MadeiraAlexandre/Cronica/main/Screenshots/iPad.webp" alt="Cronica running on iPad displaying the details page for the TV Show Kaguya-sama: Love Is War." minWidth="220" maxWidth="440" maxHeight="340">
</p>
<p align="center">
<a href="https://apple.co/38SXpVJ">
	<img src="https://alexandremadeira.dev/resources/img/cronica/AppStoreBadge.svg" alt="Badge for download Cronica on App Store" width="160" height="80">
</a>
</p>

### Apple Watch

<p align="center">
	<img src="https://raw.githubusercontent.com/MadeiraAlexandre/Cronica/main/Screenshots/Apple%20Watch.webp" alt="Cronica running on Apple Watch S7." minWidth="220" maxWidth="440" height="240">
</p>
<p align="center"> 
<a href="https://apps.apple.com/app/cronica/id1614950275">
	<img src="https://alexandremadeira.dev/resources/img/cronica/AppStoreBadge.svg" alt="Badge for download Cronica on Apple Watch App Store" width="160" height="80">
</a>
</p>

### Mac

<p align="center">
	<img src="https://raw.githubusercontent.com/MadeiraAlexandre/Cronica/main/Screenshots/Mac.webp" alt="Cronica running on MacBook Air displaying details for Top Gun: Maverick." maxWidth="220" maxWidth="440" >
</p>
<p align="center">
<a href="https://apple.co/38SXpVJ">
	<img src="https://raw.githubusercontent.com/MadeiraAlexandre/Cronica/main/Screenshots/Badges/Mac.svg" alt="Badge for download Cronica on Mac App Store" width="160" height="80">
</a>
</p>

### Apple TV
<p align="center">
	<img src="https://raw.githubusercontent.com/MadeiraAlexandre/Cronica/main/Screenshots/TV.webp" alt="Cronica running on Apple TV displaying details for Top Gun: Maverick." maxWidth="220" maxWidth="560" minWidth="40" minHeight="60">
</p>
<p align="center">
<a href="https://apple.co/38SXpVJ">
	<img src="https://raw.githubusercontent.com/MadeiraAlexandre/Cronica/main/Screenshots/Badges/AppleTV.svg" alt="Badge for download Cronica on Apple TV App Store" maxWidth="160" maxHeight="80"> 
</a>
</p>


### QR Code
<p align="center">
    <a href="https://apple.co/38SXpVJ">
            <img src="https://tools-qr-production.s3.amazonaws.com/output/apple-toolbox/5ca3ba169cdec742cc5e32287e7167e0/2af0b32529e05debc3de4aed62551429.png" alt="App Store QR Code" minWidth="250" minHeight="250" width="300" height="300">
    </a>
 </p>

### TestFlight
<p>
You can also download the latest beta from <a href="https://testflight.apple.com/join/T8kwk6Gb">TestFlight</a>
</p>


## Contact

- If you any question, you can send me an email at <a href = "mailto: contact@alexandremadeira.dev"> contact@alexandremadeira.dev</a>, I'll try to answer as quick as I can.<br>
- I'm also availabe at iMessage, you can send a message at the **same email address above**.<br>
- Follow Cronica on Twitter: [CronicaApp](https://twitter.com/CronicaApp).
