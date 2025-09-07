# Trakt API Integration Setup Guide

This guide explains how to set up and use the Trakt API integration in Cronica.

## Overview

The Trakt API integration provides bi-directional synchronization between Cronica and Trakt.tv, allowing users to:

- Sync watchlist items between Cronica and Trakt
- Sync watched status for movies and TV shows
- Sync ratings
- Sync custom lists
- Automatic background synchronization
- Manual sync options

## Prerequisites

1. Trakt.tv API credentials (Client ID and Client Secret)
2. iOS 15.0+ or macOS 12.0+
3. Xcode 14.0+

## Setup Instructions

### 1. Get Trakt API Credentials

1. Go to [https://trakt.tv/oauth/applications](https://trakt.tv/oauth/applications)
2. Click "Register New Application"
3. Fill in the application details:
   - **Name**: Cronica
   - **Description**: Movie and TV show tracking app with Trakt integration
   - **Website**: https://your-app-website.com
   - **Redirect URL**: `cronica://trakt-auth`
   - **JavaScript origins**: (leave empty)
   - **Permissions**: Check all required permissions for your use case
4. Click "Save Application"
5. Copy the **Client ID** and **Client Secret**

### 2. Configure API Credentials

Open `/Shared/Configuration/Key.swift` and add your Trakt API credentials:

```swift
struct Key {
    static let tmdbApi = "" // Your TMDB API key
    static let aptabaseClientKey: String? = "" // Your Aptabase key (optional)
    
    // Add Trakt API credentials
    static let traktClientId = "YOUR_CLIENT_ID"
    static let traktClientSecret = "YOUR_CLIENT_SECRET"
}
```

### 3. Update TraktService Configuration

Open `/Shared/Network/TraktService.swift` and update the API configuration:

```swift
// Replace these lines with your actual credentials
private let clientID = Key.traktClientId
private let clientSecret = Key.traktClientSecret
```

### 4. Configure URL Scheme

Trakt authentication uses a custom URL scheme. Make sure your app's Info.plist includes:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.cronica</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>cronica</string>
        </array>
    </dict>
</array>
```

### 5. Enable Background Modes

For background sync to work, enable Background Modes in your app's capabilities:

1. Select your app target in Xcode
2. Go to "Signing & Capabilities"
3. Click "+ Capability"
4. Add "Background Modes"
5. Check "Background fetch" and "Background processing"

## Features

### Authentication

The app uses OAuth 2.0 with PKCE for secure authentication:

- Users are redirected to Trakt.tv for authentication
- The app receives an authorization code via the custom URL scheme
- The code is exchanged for access and refresh tokens
- Tokens are stored securely in the Keychain
- Automatic token refresh is handled

### Synchronization Options

Users can configure which data types to sync:

- **Watchlist**: Sync items added to watchlist
- **Watched Status**: Sync watched/unwatched status
- **Ratings**: Sync user ratings (1-10 stars)
- **Custom Lists**: Sync user-created lists

### Sync Modes

1. **Full Sync**: Complete bidirectional synchronization
2. **Pull from Trakt**: Only import changes from Trakt
3. **Push to Trakt**: Only export local changes to Trakt

### Background Sync

- Automatic sync every 4 hours when app is in background
- Sync on app launch if last sync was more than 1 hour ago
- Manual sync triggers available in settings

## Data Model Extensions

The `WatchlistItem` Core Data entity has been extended with Trakt-specific fields:

- `traktId`: Trakt ID for the item
- `traktSlug`: Trakt slug for URL references
- `traktSyncedAt`: Timestamp of last sync with Trakt
- `traktNeedsSync`: Flag indicating item needs sync

## Usage

### For Users

1. Go to Settings → Trakt.tv
2. Tap "Connect to Trakt.tv"
3. Authenticate with your Trakt account
4. Enable sync options as desired
5. Use "Sync Now" to perform initial sync

### For Developers

#### Manual Sync

```swift
let syncEngine = TraktSyncEngine.shared
try await syncEngine.performFullSync()
```

#### Check Sync Status

```swift
let backgroundSync = TraktBackgroundSync.shared
let status = await backgroundSync.getSyncStatus()
```

#### Trigger Background Sync

```swift
let backgroundSync = TraktBackgroundSync.shared
backgroundSync.scheduleImmediateSync()
```

## Error Handling

The integration includes comprehensive error handling:

- Network errors
- API rate limiting
- Authentication failures
- Data conflicts
- Sync failures

Errors are logged and displayed to users in the UI.

## Testing

### Unit Tests

Test individual components:

```swift
func testTraktAuthentication() async throws {
    let traktService = TraktService.shared
    try await traktService.authenticate()
    XCTAssertTrue(traktService.isAuthenticated)
}
```

### Integration Tests

Test the complete sync flow:

```swift
func testFullSync() async throws {
    let syncEngine = TraktSyncEngine.shared
    try await syncEngine.performFullSync()
    // Verify data consistency
}
```

### UI Tests

Test the settings interface:

```swift
func testTraktSettingsNavigation() {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to Trakt settings
    app.tabBars["Settings"].tap()
    app.tables.staticTexts["Trakt.tv"].tap()
    
    // Verify UI elements
    XCTAssertTrue(app.buttons["Connect to Trakt.tv"].exists)
}
```

## Troubleshooting

### Common Issues

1. **Authentication Fails**
   - Verify Client ID and Client Secret are correct
   - Check redirect URL matches exactly
   - Ensure custom URL scheme is properly configured

2. **Sync Errors**
   - Check network connectivity
   - Verify API rate limits (1000 requests per 10 minutes)
   - Review Trakt API status

3. **Background Sync Not Working**
   - Ensure Background Modes are enabled
   - Check app permissions
   - Verify device settings allow background refresh

### Debug Logging

Enable debug logging in `TraktService.swift`:

```swift
private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: String(describing: TraktService.self)
)
```

Logs will appear in Console.app and Xcode debug console.

## API Reference

### TraktService

Main API client for Trakt.tv:

- `authenticate()`: Start OAuth authentication
- `fetchWatchlist()`: Get user's watchlist
- `fetchWatchedHistory()`: Get watched history
- `fetchRatings()`: Get user ratings
- `addToWatchlist()`: Add items to watchlist
- `markAsWatched()`: Mark items as watched
- `addRating()`: Rate items

### TraktSyncEngine

Handles synchronization logic:

- `performFullSync()`: Complete bidirectional sync
- `syncLocalChangesToTrakt()`: Push local changes
- `syncTraktChangesToLocal()`: Pull remote changes

### TraktBackgroundSync

Manages background synchronization:

- `scheduleBackgroundSync()`: Schedule periodic sync
- `triggerManualSync()`: Start immediate sync
- `getSyncStatus()`: Check current sync status

## Security Considerations

- All tokens are stored in Keychain
- OAuth 2.0 with PKCE for secure authentication
- HTTPS for all API communications
- No sensitive data logged
- Token refresh handled automatically

## Performance

- Efficient batching of API requests
- Rate limiting compliance
- Background processing optimized for battery life
- Conflict resolution minimizes data transfer
- Incremental sync reduces bandwidth usage

## Future Enhancements

- Support for more Trakt features (comments, recommendations)
- Enhanced conflict resolution options
- Sync progress indicators
- Offline sync capabilities
- Advanced scheduling options
- Multiple account support

## Contributing

When contributing to the Trakt integration:

1. Follow existing code style
2. Add comprehensive tests
3. Update documentation
4. Test on multiple iOS versions
5. Verify API compliance
6. Check rate limiting behavior

## Support

For issues or questions:

1. Check Trakt API documentation: https://trakt.docs.apiary.io/
2. Review existing issues on GitHub
3. Create new issue with detailed description
4. Include relevant logs and error messages