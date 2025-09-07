//
//  TraktService.swift
//  Cronica
//
//  Created by Claude on 07/09/25.
//

import Foundation
import os
import AuthenticationServices
import CryptoKit

final class TraktService: Sendable, ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TraktService.self)
    )
    
    static let shared = TraktService()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // Trakt API Configuration
    private let clientID = "YOUR_CLIENT_ID" // Replace with actual client ID
    private let clientSecret = "YOUR_CLIENT_SECRET" // Replace with actual client secret
    private let redirectURI = "cronica://trakt-auth"
    private let baseURL = "https://api.trakt.tv"
    
    // Authentication state
    @Published public var isAuthenticated = false
    @Published public var username: String?
    
    // Token storage
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?
    
    // OAuth2 state
    private var authState: String?
    private var codeVerifier: String?
    
    private init() {
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        loadTokensFromKeychain()
    }
    
    // MARK: - Authentication
    
    public func authenticate() async throws {
        let (state, codeVerifier) = generateOAuth2State()
        self.authState = state
        self.codeVerifier = codeVerifier
        
        let authURL = buildAuthorizationURL(state: state, codeChallenge: generateCodeChallenge(from: codeVerifier))
        
        guard let url = authURL else {
            throw TraktError.invalidURL
        }
        
        // Handle authentication via ASWebAuthenticationSession
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "cronica") { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: TraktError.authenticationFailed(error))
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: TraktError.authenticationCancelled)
                    return
                }
                
                Task {
                    do {
                        try await self.handleAuthorizationCallback(callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }
    }
    
    private func handleAuthorizationCallback(_ callbackURL: URL) async throws {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw TraktError.invalidCallback
        }
        
        guard let state = queryItems.first(where: { $0.name == "state" })?.value,
              state == self.authState else {
            throw TraktError.invalidState
        }
        
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw TraktError.authorizationCodeMissing
        }
        
        try await exchangeCodeForToken(code)
    }
    
    private func exchangeCodeForToken(_ code: String) async throws {
        let tokenURL = URL(string: "\(baseURL)/oauth/token")!
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let tokenData = [
            "code": code,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: tokenData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            saveTokens(tokenResponse)
            await fetchUserProfile()
        } else {
            throw TraktError.tokenExchangeFailed
        }
    }
    
    private func refreshAccessToken() async throws {
        guard let refreshToken = refreshToken else {
            throw TraktError.noRefreshToken
        }
        
        let tokenURL = URL(string: "\(baseURL)/oauth/token")!
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let tokenData = [
            "refresh_token": refreshToken,
            "client_id": clientID,
            "client_secret": clientSecret,
            "redirect_uri": redirectURI,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: tokenData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
            saveTokens(tokenResponse)
        } else {
            throw TraktError.tokenRefreshFailed
        }
    }
    
    private func fetchUserProfile() async throws {
        let response: User = try await authenticatedRequest(path: "/users/me")
        await MainActor.run {
            self.username = response.username
            self.isAuthenticated = true
        }
    }
    
    public func signOut() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        username = nil
        isAuthenticated = false
        
        // Remove tokens from Keychain
        let keychain = Keychain(service: "com.cronica.trakt")
        try? keychain.remove("accessToken")
        try? keychain.remove("refreshToken")
        try? keychain.remove("tokenExpiry")
    }
    
    // MARK: - API Requests
    
    private func authenticatedRequest<T: Decodable>(path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        // Check if token needs refresh
        if let expiry = tokenExpiry, Date() > expiry {
            try await refreshAccessToken()
        }
        
        guard let accessToken = accessToken else {
            throw TraktError.notAuthenticated
        }
        
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw TraktError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("2", forHTTPHeaderField: "trakt-api-version")
        request.setValue(clientID, forHTTPHeaderField: "trakt-api-key")
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TraktError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            // Token might be expired, try refresh
            try await refreshAccessToken()
            return try await authenticatedRequest(path: path, method: method, body: body)
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw TraktError.apiError(httpResponse.statusCode)
        }
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Watchlist Operations
    
    public func fetchWatchlist() async throws -> [TraktItem] {
        let response: [TraktItem] = try await authenticatedRequest(path: "/sync/watchlist")
        return response
    }
    
    public func addToWatchlist(items: [TraktSyncItem]) async throws -> TraktSyncResponse {
        let data = try encoder.encode(["movies": items.filter { $0.type == .movie }, 
                                       "shows": items.filter { $0.type == .show }])
        return try await authenticatedRequest(path: "/sync/watchlist", method: "POST", body: data)
    }
    
    public func removeFromWatchlist(items: [TraktSyncItem]) async throws -> TraktSyncResponse {
        let data = try encoder.encode(["movies": items.filter { $0.type == .movie }, 
                                       "shows": items.filter { $0.type == .show }])
        return try await authenticatedRequest(path: "/sync/watchlist/remove", method: "POST", body: data)
    }
    
    // MARK: - Watched Status
    
    public func fetchWatchedHistory() async throws -> [TraktWatchedItem] {
        let response: [TraktWatchedItem] = try await authenticatedRequest(path: "/sync/watched/shows")
        return response
    }
    
    public func markAsWatched(items: [TraktSyncItem]) async throws -> TraktSyncResponse {
        let data = try encoder.encode(["movies": items.filter { $0.type == .movie }, 
                                       "shows": items.filter { $0.type == .show },
                                       "episodes": items.filter { $0.type == .episode }])
        return try await authenticatedRequest(path: "/sync/history", method: "POST", body: data)
    }
    
    public func markAsUnwatched(items: [TraktSyncItem]) async throws -> TraktSyncResponse {
        let data = try encoder.encode(["movies": items.filter { $0.type == .movie }, 
                                       "shows": items.filter { $0.type == .show },
                                       "episodes": items.filter { $0.type == .episode }])
        return try await authenticatedRequest(path: "/sync/history/remove", method: "POST", body: data)
    }
    
    // MARK: - Ratings
    
    public func fetchRatings() async throws -> [TraktRatingItem] {
        let response: [TraktRatingItem] = try await authenticatedRequest(path: "/sync/ratings")
        return response
    }
    
    public func addRating(item: TraktSyncItem, rating: Int) async throws -> TraktSyncResponse {
        let data = try encoder.encode([
            "movies": rating > 0 ? [item.withRating(rating)] : [],
            "shows": rating > 0 ? [item.withRating(rating)] : [],
            "episodes": rating > 0 ? [item.withRating(rating)] : []
        ])
        return try await authenticatedRequest(path: "/sync/ratings", method: "POST", body: data)
    }
    
    // MARK: - Lists
    
    public func fetchCustomLists() async throws -> [TraktList] {
        let response: [TraktList] = try await authenticatedRequest(path: "/users/me/lists")
        return response
    }
    
    public func createCustomList(name: String, description: String? = nil) async throws -> TraktList {
        let data = try encoder.encode([
            "name": name,
            "description": description ?? "",
            "privacy": "private",
            "display_numbers": false,
            "allow_comments": false
        ])
        return try await authenticatedRequest(path: "/users/me/lists", method: "POST", body: data)
    }
    
    public func addItemsToList(listId: String, items: [TraktSyncItem]) async throws -> TraktSyncResponse {
        let data = try encoder.encode(["movies": items.filter { $0.type == .movie }, 
                                       "shows": items.filter { $0.type == .show },
                                       "episodes": items.filter { $0.type == .episode }])
        return try await authenticatedRequest(path: "/users/me/lists/\(listId)/items", method: "POST", body: data)
    }
    
    // MARK: - Helper Methods
    
    private func generateOAuth2State() -> (state: String, codeVerifier: String) {
        let state = UUID().uuidString
        let codeVerifier = UUID().uuidString + UUID().uuidString
        return (state, codeVerifier)
    }
    
    private func generateCodeChallenge(from codeVerifier: String) -> String {
        let data = Data(codeVerifier.utf8)
        let hashedData = SHA256.hash(data: data)
        return hashedData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func buildAuthorizationURL(state: String, codeChallenge: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "trakt.tv"
        components.path = "/oauth/authorize"
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        return components.url
    }
    
    private func saveTokens(_ tokenResponse: TokenResponse) {
        self.accessToken = tokenResponse.accessToken
        self.refreshToken = tokenResponse.refreshToken
        self.tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        
        // Save to Keychain
        let keychain = Keychain(service: "com.cronica.trakt")
        try? keychain.set(tokenResponse.accessToken, key: "accessToken")
        try? keychain.set(tokenResponse.refreshToken, key: "refreshToken")
        try? keychain.set(String(tokenResponse.expiresIn), key: "tokenExpiry")
    }
    
    private func loadTokensFromKeychain() {
        let keychain = Keychain(service: "com.cronica.trakt")
        
        if let accessToken = try? keychain.get("accessToken") {
            self.accessToken = accessToken
        }
        
        if let refreshToken = try? keychain.get("refreshToken") {
            self.refreshToken = refreshToken
        }
        
        if let expiryString = try? keychain.get("tokenExpiry"),
           let expiryInterval = Double(expiryString) {
            self.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiryInterval))
        }
        
        // Check if token is still valid
        if let expiry = tokenExpiry, Date() < expiry, accessToken != nil {
            Task {
                try await fetchUserProfile()
            }
        }
    }
}

// MARK: - Data Models

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let scope: String
    let createdAt: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
        case createdAt = "created_at"
    }
}

struct User: Codable {
    let username: String
    let name: String?
    let vip: Bool
    let vipEp: Bool
    let ids: UserIDs
}

struct UserIDs: Codable {
    let slug: String
    let uuid: String
}

struct TraktItem: Codable {
    let id: Int
    let title: String
    let year: Int?
    let type: String
    let watchedAt: String?
    let movie: TraktMovie?
    let show: TraktShow?
}

struct TraktMovie: Codable {
    let title: String
    let year: Int
    let ids: TraktIDs
}

struct TraktShow: Codable {
    let title: String
    let year: Int
    let ids: TraktIDs
}

struct TraktIDs: Codable {
    let trakt: Int
    let slug: String
    let imdb: String?
    let tmdb: Int?
}

struct TraktSyncItem: Codable {
    let ids: TraktIDs
    let type: TraktItemType
    let rating?: Int
    
    func withRating(_ rating: Int) -> TraktSyncItem {
        TraktSyncItem(ids: ids, type: type, rating: rating)
    }
}

enum TraktItemType: String, Codable {
    case movie
    case show
    case episode
}

struct TraktSyncResponse: Codable {
    let added: AddedItems
    let existing: AddedItems
    let notFound: NotFoundItems
}

struct AddedItems: Codable {
    let movies: Int
    let shows: Int
    let episodes: Int
}

struct NotFoundItems: Codable {
    let movies: [TraktIDs]
    let shows: [TraktIDs]
    let episodes: [TraktIDs]
}

struct TraktWatchedItem: Codable {
    let show: TraktShow
    let seasons: [TraktWatchedSeason]
}

struct TraktWatchedSeason: Codable {
    let number: Int
    let episodes: [TraktWatchedEpisode]
}

struct TraktWatchedEpisode: Codable {
    let number: Int
    let plays: Int
    let lastWatchedAt: String
}

struct TraktRatingItem: Codable {
    let ratedAt: String
    let rating: Int
    let type: String
    let movie: TraktMovie?
    let show: TraktShow?
    let episode: TraktEpisode?
}

struct TraktEpisode: Codable {
    let title: String
    let season: Int
    let number: Int
    let ids: TraktIDs
}

struct TraktList: Codable {
    let name: String
    let description: String
    let privacy: String
    let displayNumbers: Bool
    let allowComments: Bool
    let sortby: String
    let sorthow: String
    let createdAt: String
    let updatedAt: String
    let itemCount: Int
    let commentCount: Int
    let likes: Int
    let ids: TraktIDs
}

// MARK: - Errors

enum TraktError: Error, LocalizedError {
    case invalidURL
    case authenticationFailed(Error)
    case authenticationCancelled
    case invalidCallback
    case invalidState
    case authorizationCodeMissing
    case tokenExchangeFailed
    case tokenRefreshFailed
    case notAuthenticated
    case noRefreshToken
    case invalidResponse
    case apiError(Int)
    case rateLimited
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .authenticationFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        case .authenticationCancelled:
            return "Authentication was cancelled"
        case .invalidCallback:
            return "Invalid callback URL"
        case .invalidState:
            return "Invalid authentication state"
        case .authorizationCodeMissing:
            return "Authorization code missing"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for token"
        case .tokenRefreshFailed:
            return "Failed to refresh access token"
        case .notAuthenticated:
            return "Not authenticated"
        case .noRefreshToken:
            return "No refresh token available"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code):
            return "API error: \(code)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Network Error Handling

extension TraktError {
    static func from(_ error: Error) -> TraktError {
        if let traktError = error as? TraktError {
            return traktError
        }
        
        if let urlError = error as? URLError {
            return .networkError(urlError)
        }
        
        return .networkError(error)
    }
}

// MARK: - Keychain Helper

class Keychain {
    private let service: String
    
    init(service: String) {
        self.service = service
    }
    
    func set(_ value: String, key: String) throws {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
    }
    
    func get(_ key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status)
        }
        
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    func remove(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status)
        }
    }
}

enum KeychainError: Error {
    case unhandledError(OSStatus)
}