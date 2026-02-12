// Modernization Plan (2026)

This document is a living plan to modernize the app: raise minimum OS versions, update dependencies, migrate to modern APIs, and prepare a safe rollout.

## Goals and Scope
- Raise deployment targets to unlock modern platform features.
- Update third-party dependencies safely and remove unused packages.
- Adopt Swift Concurrency and modern SwiftUI (where applicable).
- Improve performance, accessibility, and test coverage.
- Ship a stable update with phased rollout and monitoring.

## Target Platform Baselines
- iOS/iPadOS: 17.0
- macOS: 14 (Sonoma)
- watchOS: 10
- tvOS: 17 (if applicable)
- visionOS: 1.2+ (if applicable)

## Branching and Workflow
- Create a feature branch: `modernization/2026`.
- Use small, focused commits with clear messages.
- After each dependency update or migration step, build and run tests.
- Use PRs to review breaking changes and track migration progress.

## Pre‑Flight Checklist
- [ ] Xcode 26.1 installed and set as default.
- [ ] Clean build succeeds on current main branch.
- [ ] Enable Xcode “Recommended Settings” in Project Settings.
- [ ] Ensure CI (if any) runs against Xcode 26.1 images.
- [ ] Back up signing certificates/profiles or ensure CI-managed signing is stable.

## Step 1: Raise Deployment Targets
- In Xcode, select each target and set:
  - iOS/iPadOS: 17.0
  - macOS: 14.0
  - watchOS: 10.0
  - tvOS: 17.0
- If you maintain internal Swift packages, update `Package.swift` platform constraints accordingly.
- Remove legacy availability checks that are now unconditional (e.g., `if #available(iOS 14, *)`).
- Commit: `chore: raise deployment targets (iOS 17, macOS 14, watchOS 10, tvOS 17)`

### Attaching xcconfigs (Option A)
- In Xcode, select the project (top of the navigator), then each target > Build Settings.
- Under Configurations, assign:
  - Debug: Config/Deployment.xcconfig and Config/Warnings.xcconfig (use both by chaining via a base config if you prefer; otherwise place shared flags in Warnings and set Deployment as the base)
  - Release: Config/Deployment.xcconfig and Config/Warnings.xcconfig
- Alternatively, set these manually in Build Settings if you don’t want to use xcconfigs:
  - iOS 17.0 / macOS 14.0 / watchOS 10.0 / tvOS 17.0
  - Swift Language Version = 6.0
  - SWIFT_STRICT_CONCURRENCY = targeted
  - Add the warnings from Config/Warnings.xcconfig

After you’ve attached the xcconfigs and built successfully, proceed to Step 3 and remove legacy availability checks for ContentUnavailableView and symbolEffect where present.

## Step 2: Dependency Audit and Updates
- Enumerate all dependencies (Swift Package Manager, CocoaPods, Carthage if any).
- For Swift Package Manager:
  - Use Xcode > Project > Package Dependencies > "Check for Updates".
  - Update one package at a time (especially major bumps). Build and run tests after each.
  - Read release notes for breaking changes.
  - Remove unused packages to reduce app size and risk.
- If using CocoaPods/Carthage:
  - Update to latest compatible versions. Consider migrating to SPM for long-term maintenance.
- Fallback strategies for unmaintained packages:
  - Replace with maintained alternatives.
  - Fork and pin temporarily while migrating.
  - Re-implement narrow functionality in-house if small.
- Commands (optional, for SPM workspaces):

