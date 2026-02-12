// Dependency Audit

// This document tracks third-party dependencies and recommended update targets as part of modernization.

// Note: Version ranges below are placeholders until we resolve actual versions from Package.swift / Podfile.

// ## Swift Package Manager
// - SDWebImageSwiftUI — update to latest compatible (check release notes for iOS 17/watchOS 10 compatibility).
// - YouTubePlayerKit — update to latest compatible.
// - Firebase (Core, Messaging) — prefer SPM integration if not already; update to latest.
// - GoogleMobileAds — prefer SPM integration if not already; update to latest.

// Action items:
// - [ ] Enumerate current versions (Xcode > Project > Package Dependencies).
// - [ ] For each package, read release notes and minimum OS.
// - [ ] Update one-by-one; build after each.
// - [ ] Remove unused packages (e.g., any placeholders or obsolete wrappers).

// ## CocoaPods / Carthage (if applicable)
// - If present, plan migration to SPM where feasible.
// - Otherwise, update pods/carthage frameworks to latest compatible versions.

// ## Risk Notes
// - Major version bumps may include breaking API changes (e.g., async/await adoption, renamed APIs).
// - Ads/analytics SDKs can require Info.plist changes; review integration guides.

// ## Next Steps (Assistant)
// Once Package.swift / Podfile are identified, I will:
// - Fill in current and target versions here.
// - Propose update order.
// - Provide code diffs for breaking changes where necessary.
