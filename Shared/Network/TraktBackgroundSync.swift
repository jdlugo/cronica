//
//  TraktBackgroundSync.swift
//  Cronica
//
//  Created by Claude on 07/09/25.
//

import Foundation
import BackgroundTasks
import os

final class TraktBackgroundSync {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TraktBackgroundSync.self)
    )
    
    static let shared = TraktBackgroundSync()
    
    // Background task identifiers
    private let traktSyncIdentifier = "com.cronica.trakt-sync"
    private let traktSyncIdentifierLegacy = "com.cronica.trakt-sync.legacy"
    
    private init() {
        registerBackgroundTasks()
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: traktSyncIdentifier,
            using: nil
        ) { task in
            Task {
                await self.handleBackgroundSync(task: task as! BGAppRefreshTask)
            }
        }
        
        // Register legacy processing task for iOS < 13
        if #available(iOS 13.0, *) {
            // Already registered above
        } else {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: traktSyncIdentifierLegacy,
                using: nil
            ) { task in
                Task {
                    await self.handleBackgroundSync(task: task as! BGProcessingTask)
                }
            }
        }
    }
    
    // MARK: - Background Sync Scheduling
    
    public func scheduleBackgroundSync() {
        let settings = SettingsStore.shared
        
        guard settings.isUserConnectedWithTrakt && settings.isTraktSyncEnabled else {
            Self.logger.info("Trakt sync not enabled, skipping background task scheduling")
            return
        }
        
        cancelBackgroundSync()
        
        let request = BGAppRefreshTaskRequest(identifier: traktSyncIdentifier)
        
        // Schedule sync every 4 hours
        let earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)
        request.earliestBeginDate = earliestBeginDate
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Self.logger.info("Scheduled background Trakt sync")
        } catch {
            Self.logger.error("Failed to schedule background Trakt sync: \(error.localizedDescription)")
        }
    }
    
    public func scheduleImmediateSync() {
        let settings = SettingsStore.shared
        
        guard settings.isUserConnectedWithTrakt && settings.isTraktSyncEnabled else {
            Self.logger.info("Trakt sync not enabled, skipping immediate sync")
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: traktSyncIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            Self.logger.info("Scheduled immediate Trakt sync")
        } catch {
            Self.logger.error("Failed to schedule immediate Trakt sync: \(error.localizedDescription)")
        }
    }
    
    public func cancelBackgroundSync() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: traktSyncIdentifier)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: traktSyncIdentifierLegacy)
        Self.logger.info("Cancelled background Trakt sync tasks")
    }
    
    // MARK: - Background Task Handling
    
    private func handleBackgroundSync(task: BGTask) async {
        Self.logger.info("Starting background Trakt sync")
        
        // Schedule the next background task
        scheduleBackgroundSync()
        
        let settings = SettingsStore.shared
        
        guard settings.isUserConnectedWithTrakt && settings.isTraktSyncEnabled else {
            Self.logger.info("Trakt sync not enabled, cancelling background sync")
            task.setTaskCompleted(success: true)
            return
        }
        
        // Check if enough time has passed since last sync
        if let lastSync = settings.traktLastSync,
           Date().timeIntervalSince(lastSync) < 30 * 60 { // 30 minutes
            Self.logger.info("Last sync was too recent, skipping background sync")
            task.setTaskCompleted(success: true)
            return
        }
        
        do {
            // Perform the sync
            let syncEngine = TraktSyncEngine.shared
            try await syncEngine.syncTraktChangesToLocal()
            
            Self.logger.info("Background Trakt sync completed successfully")
            task.setTaskCompleted(success: true)
            
        } catch {
            Self.logger.error("Background Trakt sync failed: \(error.localizedDescription)")
            
            // Don't mark as failed, just try again later
            task.setTaskCompleted(success: false)
        }
    }
    
    // MARK: - App Lifecycle Integration
    
    public func handleAppBecomeActive() {
        let settings = SettingsStore.shared
        
        guard settings.isUserConnectedWithTrakt && settings.isTraktSyncEnabled else { return }
        
        // Check if we should perform a sync on app launch
        if let lastSync = settings.traktLastSync,
           Date().timeIntervalSince(lastSync) > 60 * 60 { // 1 hour
            Task {
                do {
                    let syncEngine = TraktSyncEngine.shared
                    try await syncEngine.syncTraktChangesToLocal()
                    Self.logger.info("App launch Trakt sync completed successfully")
                } catch {
                    Self.logger.error("App launch Trakt sync failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func handleAppDidEnterBackground() {
        // Schedule background sync for when app is in background
        scheduleBackgroundSync()
    }
    
    // MARK: - Manual Sync Trigger
    
    public func triggerManualSync() async throws {
        let settings = SettingsStore.shared
        
        guard settings.isUserConnectedWithTrakt && settings.isTraktSyncEnabled else {
            throw TraktError.notAuthenticated
        }
        
        Self.logger.info("Starting manual Trakt sync")
        
        let syncEngine = TraktSyncEngine.shared
        try await syncEngine.performFullSync()
        
        Self.logger.info("Manual Trakt sync completed successfully")
    }
    
    // MARK: - Sync Status Monitoring
    
    public func getSyncStatus() async -> SyncStatus {
        let settings = SettingsStore.shared
        
        guard settings.isUserConnectedWithTrakt else {
            return .notAuthenticated
        }
        
        guard settings.isTraktSyncEnabled else {
            return .disabled
        }
        
        if TraktSyncEngine.shared.isSyncing {
            return .syncing
        }
        
        if let lastSync = settings.traktLastSync {
            let timeSinceSync = Date().timeIntervalSince(lastSync)
            
            if timeSinceSync < 5 * 60 { // 5 minutes
                return .recent
            } else if timeSinceSync < 60 * 60 { // 1 hour
                return .upToDate
            } else {
                return .needsSync
            }
        }
        
        return .neverSynced
    }
}

// MARK: - Sync Status

enum SyncStatus {
    case notAuthenticated
    case disabled
    case syncing
    case recent
    case upToDate
    case needsSync
    case neverSynced
    
    var description: String {
        switch self {
        case .notAuthenticated:
            return "Not connected to Trakt"
        case .disabled:
            return "Trakt sync disabled"
        case .syncing:
            return "Syncing with Trakt..."
        case .recent:
            return "Recently synced"
        case .upToDate:
            return "Up to date"
        case .needsSync:
            return "Needs sync"
        case .neverSynced:
            return "Never synced"
        }
    }
    
    var color: String {
        switch self {
        case .notAuthenticated, .disabled:
            return "gray"
        case .syncing:
            return "blue"
        case .recent, .upToDate:
            return "green"
        case .needsSync:
            return "orange"
        case .neverSynced:
            return "yellow"
        }
    }
}

// MARK: - App Lifecycle Observer

class TraktSyncLifecycleObserver: ObservableObject {
    private let backgroundSync = TraktBackgroundSync.shared
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleAppBecomeActive() {
        backgroundSync.handleAppBecomeActive()
    }
    
    @objc private func handleAppDidEnterBackground() {
        backgroundSync.handleAppDidEnterBackground()
    }
}