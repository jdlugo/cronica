//
//  TraktSyncEngine.swift
//  Cronica
//
//  Created by Claude on 07/09/25.
//

import Foundation
import CoreData
import os

final class TraktSyncEngine: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TraktSyncEngine.self)
    )
    
    static let shared = TraktSyncEngine()
    private let traktService = TraktService.shared
    private let persistenceController = PersistenceController.shared
    
    @Published public var isSyncing = false
    @Published public var lastSyncDate: Date?
    @Published public var syncProgress: Double = 0.0
    @Published public var syncErrors: [String] = []
    
    private init() {}
    
    // MARK: - Main Sync Operations
    
    public func performFullSync() async throws {
        guard traktService.isAuthenticated else {
            throw TraktError.notAuthenticated
        }
        
        await MainActor.run {
            self.isSyncing = true
            self.syncProgress = 0.0
            self.syncErrors.removeAll()
        }
        
        defer {
            Task { @MainActor in
                self.isSyncing = false
                self.lastSyncDate = Date()
                SettingsStore.shared.traktLastSync = self.lastSyncDate
            }
        }
        
        do {
            // Step 1: Fetch Trakt data
            await updateProgress(0.1, message: "Fetching Trakt data...")
            let traktWatchlist = try await traktService.fetchWatchlist()
            let traktWatched = try await traktService.fetchWatchedHistory()
            let traktRatings = try await traktService.fetchRatings()
            
            // Step 2: Get local data
            await updateProgress(0.2, message: "Loading local data...")
            let localItems = try await fetchLocalWatchlistItems()
            
            // Step 3: Sync watchlist
            await updateProgress(0.4, message: "Syncing watchlist...")
            try await syncWatchlist(localItems: localItems, traktItems: traktWatchlist)
            
            // Step 4: Sync watched status
            await updateProgress(0.6, message: "Syncing watched status...")
            try await syncWatchedStatus(localItems: localItems, traktWatched: traktWatched)
            
            // Step 5: Sync ratings
            await updateProgress(0.8, message: "Syncing ratings...")
            try await syncRatings(localItems: localItems, traktRatings: traktRatings)
            
            // Step 6: Push local changes to Trakt
            await updateProgress(0.9, message: "Pushing local changes...")
            try await pushLocalChangesToTrakt()
            
            await updateProgress(1.0, message: "Sync complete!")
            
        } catch {
            await MainActor.run {
                self.syncErrors.append(error.localizedDescription)
            }
            throw error
        }
    }
    
    public func syncLocalChangesToTrakt() async throws {
        guard traktService.isAuthenticated else {
            throw TraktError.notAuthenticated
        }
        
        await MainActor.run {
            self.isSyncing = true
            self.syncProgress = 0.0
            self.syncErrors.removeAll()
        }
        
        defer {
            Task { @MainActor in
                self.isSyncing = false
            }
        }
        
        try await pushLocalChangesToTrakt()
    }
    
    public func syncTraktChangesToLocal() async throws {
        guard traktService.isAuthenticated else {
            throw TraktError.notAuthenticated
        }
        
        await MainActor.run {
            self.isSyncing = true
            self.syncProgress = 0.0
            self.syncErrors.removeAll()
        }
        
        defer {
            Task { @MainActor in
                self.isSyncing = false
            }
        }
        
        try await pullTraktChangesToLocal()
    }
    
    // MARK: - Individual Sync Operations
    
    public func syncWatchlistItem(_ item: WatchlistItem) async throws {
        guard traktService.isAuthenticated else {
            throw TraktError.notAuthenticated
        }
        
        let syncItem = try await createTraktSyncItem(from: item)
        
        if item.isArchive {
            // Remove from Trakt watchlist
            _ = try await traktService.removeFromWatchlist(items: [syncItem])
        } else {
            // Add to Trakt watchlist
            _ = try await traktService.addToWatchlist(items: [syncItem])
        }
        
        // Update sync status
        await updateItemSyncStatus(item: item)
    }
    
    public func syncWatchedStatus(_ item: WatchlistItem) async throws {
        guard traktService.isAuthenticated else {
            throw TraktError.notAuthenticated
        }
        
        let syncItem = try await createTraktSyncItem(from: item)
        
        if item.watched {
            // Mark as watched on Trakt
            _ = try await traktService.markAsWatched(items: [syncItem])
        } else {
            // Mark as unwatched on Trakt
            _ = try await traktService.markAsUnwatched(items: [syncItem])
        }
        
        // Update sync status
        await updateItemSyncStatus(item: item)
    }
    
    public func syncRating(_ item: WatchlistItem) async throws {
        guard traktService.isAuthenticated else {
            throw TraktError.notAuthenticated
        }
        
        let syncItem = try await createTraktSyncItem(from: item)
        let rating = item.userRating > 0 ? Int(item.userRating) : 0
        
        _ = try await traktService.addRating(item: syncItem, rating: rating)
        
        // Update sync status
        await updateItemSyncStatus(item: item)
    }
    
    // MARK: - Private Helper Methods
    
    private func syncWatchlist(localItems: [WatchlistItem], traktItems: [TraktItem]) async throws {
        let settings = SettingsStore.shared
        
        guard settings.traktSyncWatchlist else { return }
        
        let traktIds = Set(traktItems.map { $0.id })
        let localTmdbIds = Set(localItems.map { $0.tmdbID })
        
        // Find items to add to Trakt
        let itemsToAdd = localItems.filter { localItem in
            guard let traktId = localItem.traktId else { return false }
            return !traktIds.contains(traktId) && !localItem.isArchive
        }
        
        // Find items to remove from Trakt
        let itemsToRemove = traktItems.filter { traktItem in
            guard let tmdbId = traktItem.movie?.ids.tmdb ?? traktItem.show?.ids.tmdb else { return false }
            return !localTmdbIds.contains(Int64(tmdbId)) || localItems.contains(where: { $0.tmdbID == Int64(tmdbId) && $0.isArchive })
        }
        
        // Add items to Trakt
        if !itemsToAdd.isEmpty {
            let syncItems = try await itemsToAdd.asyncMap { try await createTraktSyncItem(from: $0) }
            _ = try await traktService.addToWatchlist(items: syncItems)
        }
        
        // Remove items from Trakt
        if !itemsToRemove.isEmpty {
            let syncItems = itemsToRemove.map { item in
                let ids = item.movie?.ids ?? item.show?.ids ?? TraktIDs(trakt: item.id, slug: "", imdb: nil, tmdb: nil)
                return TraktSyncItem(ids: ids, type: item.type == "movie" ? .movie : .show)
            }
            _ = try await traktService.removeFromWatchlist(items: syncItems)
        }
    }
    
    private func syncWatchedStatus(localItems: [WatchlistItem], traktWatched: [TraktWatchedItem]) async throws {
        let settings = SettingsStore.shared
        
        guard settings.traktSyncWatched else { return }
        
        // Create a set of watched Trakt IDs
        var watchedTraktIds: Set<Int64> = []
        for watchedItem in traktWatched {
            watchedTraktIds.insert(Int64(watchedItem.show.ids.trakt))
            
            for season in watchedItem.seasons {
                for episode in season.episodes {
                    // Handle episode-level watched status if needed
                }
            }
        }
        
        // Sync watched status
        for item in localItems {
            guard let traktId = item.traktId else { continue }
            
            let isWatchedOnTrakt = watchedTraktIds.contains(traktId)
            
            if item.watched != isWatchedOnTrakt {
                // Conflict resolution: use the most recent update
                if let localUpdated = item.lastValuesUpdated,
                   let traktUpdated = item.traktSyncedAt,
                   localUpdated > traktUpdated {
                    // Local is newer, push to Trakt
                    try await syncWatchedStatus(item)
                } else {
                    // Trakt is newer, pull to local
                    await updateLocalWatchedStatus(item: item, watched: isWatchedOnTrakt)
                }
            }
        }
    }
    
    private func syncRatings(localItems: [WatchlistItem], traktRatings: [TraktRatingItem]) async throws {
        let settings = SettingsStore.shared
        
        guard settings.traktSyncRatings else { return }
        
        // Create a dictionary of Trakt ratings
        let traktRatingsDict = Dictionary(uniqueKeysWithValues: traktRatings.map { rating in
            let id = rating.movie?.ids.trakt ?? rating.show?.ids.trakt ?? rating.episode?.ids.trakt ?? 0
            return (Int64(id), rating.rating)
        })
        
        // Sync ratings
        for item in localItems {
            guard let traktId = item.traktId else { continue }
            
            let traktRating = traktRatingsDict[traktId] ?? 0
            let localRating = item.userRating > 0 ? Int(item.userRating) : 0
            
            if localRating != traktRating {
                // Conflict resolution: use the most recent update
                if let localUpdated = item.lastValuesUpdated,
                   let traktUpdated = item.traktSyncedAt,
                   localUpdated > traktUpdated {
                    // Local is newer, push to Trakt
                    try await syncRating(item)
                } else {
                    // Trakt is newer, pull to local
                    await updateLocalRating(item: item, rating: traktRating)
                }
            }
        }
    }
    
    private func pushLocalChangesToTrakt() async throws {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "traktNeedsSync == true")
        
        let itemsNeedingSync = try context.fetch(fetchRequest)
        
        for item in itemsNeedingSync {
            try await syncWatchlistItem(item)
            try await syncWatchedStatus(item)
            try await syncRating(item)
        }
    }
    
    private func pullTraktChangesToLocal() async throws {
        let traktWatchlist = try await traktService.fetchWatchlist()
        let traktWatched = try await traktService.fetchWatchedHistory()
        let traktRatings = try await traktService.fetchRatings()
        
        let localItems = try await fetchLocalWatchlistItems()
        
        try await syncWatchlist(localItems: localItems, traktItems: traktWatchlist)
        try await syncWatchedStatus(localItems: localItems, traktWatched: traktWatched)
        try await syncRatings(localItems: localItems, traktRatings: traktRatings)
    }
    
    // MARK: - Helper Methods
    
    private func fetchLocalWatchlistItems() async throws -> [WatchlistItem] {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<WatchlistItem> = WatchlistItem.fetchRequest()
        
        return try context.fetch(fetchRequest)
    }
    
    private func createTraktSyncItem(from item: WatchlistItem) async throws -> TraktSyncItem {
        let ids = TraktIDs(
            trakt: Int(item.traktId ?? 0),
            slug: item.traktSlug ?? "",
            imdb: item.imdbID,
            tmdb: Int(item.tmdbID)
        )
        
        let type: TraktItemType = {
            switch item.contentType {
            case 0: return .movie
            case 1: return .show
            default: return .movie
            }
        }()
        
        return TraktSyncItem(ids: ids, type: type)
    }
    
    private func updateItemSyncStatus(item: WatchlistItem) async {
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            context.perform {
                item.traktNeedsSync = false
                item.traktSyncedAt = Date()
                try? context.save()
            }
        }
    }
    
    private func updateLocalWatchedStatus(item: WatchlistItem, watched: Bool) async {
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            context.perform {
                item.watched = watched
                item.traktSyncedAt = Date()
                try? context.save()
            }
        }
    }
    
    private func updateLocalRating(item: WatchlistItem, rating: Int) async {
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            context.perform {
                item.userRating = Int64(rating)
                item.traktSyncedAt = Date()
                try? context.save()
            }
        }
    }
    
    private func updateProgress(_ progress: Double, message: String) async {
        await MainActor.run {
            self.syncProgress = progress
            Self.logger.info("Sync progress: \(progress, format: .percent) - \(message)")
        }
    }
    
    // MARK: - TMDB to Trakt ID Mapping
    
    public func fetchTraktId(for tmdbId: Int64, type: MediaType) async throws -> Int64? {
        // This would require a lookup service or API to map TMDB IDs to Trakt IDs
        // For now, we'll return nil and handle this in the sync logic
        return nil
    }
}

// MARK: - Array Extensions

extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []
        for element in self {
            result.append(try await transform(element))
        }
        return result
    }
}