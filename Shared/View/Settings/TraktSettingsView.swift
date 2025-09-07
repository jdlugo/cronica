//
//  TraktSettingsView.swift
//  Cronica
//
//  Created by Claude on 07/09/25.
//

import SwiftUI
import os

struct TraktSettingsView: View {
    @StateObject private var traktService = TraktService.shared
    @StateObject private var settingsStore = SettingsStore.shared
    @StateObject private var syncEngine = TraktSyncEngine.shared
    @StateObject private var backgroundSync = TraktBackgroundSync.shared
    @State private var showingAuthAlert = false
    @State private var authError: String?
    @State private var isSyncing = false
    @State private var syncProgress: Double = 0.0
    @State private var showingSyncError = false
    @State private var syncErrorMessage: String?
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: TraktSettingsView.self)
    )
    
    var body: some View {
        Form {
            Section("Account") {
                if traktService.isAuthenticated {
                    authenticatedAccountView
                } else {
                    unauthenticatedAccountView
                }
            }
            
            if traktService.isAuthenticated {
                Section("Sync Settings") {
                    syncSettingsView
                }
                
                Section("Sync Options") {
                    syncOptionsView
                }
                
                Section("Sync Status") {
                    syncStatusView
                }
                
                Section("Actions") {
                    actionsView
                }
            }
        }
        .navigationTitle("Trakt.tv")
        .alert("Authentication Error", isPresented: $showingAuthAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authError ?? "An unknown error occurred")
        }
        .alert("Sync Error", isPresented: $showingSyncError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(syncErrorMessage ?? "An unknown error occurred during sync")
        }
        .onReceive(traktService.$isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                settingsStore.isUserConnectedWithTrakt = true
                settingsStore.traktUsername = traktService.username
            } else {
                settingsStore.isUserConnectedWithTrakt = false
                settingsStore.traktUsername = nil
            }
        }
        .onReceive(syncEngine.$isSyncing) { syncing in
            isSyncing = syncing
        }
        .onReceive(syncEngine.$syncProgress) { progress in
            syncProgress = progress
        }
        .onReceive(syncEngine.$syncErrors) { errors in
            if let firstError = errors.first {
                syncErrorMessage = firstError
                showingSyncError = true
            }
        }
    }
    
    private var authenticatedAccountView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Connected")
                    .fontWeight(.semibold)
                Spacer()
                Button("Disconnect") {
                    disconnectFromTrakt()
                }
                .foregroundColor(.red)
            }
            
            if let username = traktService.username {
                Text("Username: \(username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var unauthenticatedAccountView: some View {
        Button(action: {
            connectToTrakt()
        }) {
            HStack {
                Image(systemName: "person.badge.plus")
                Text("Connect to Trakt.tv")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var syncSettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Enable Trakt Sync", isOn: $settingsStore.isTraktSyncEnabled)
            
            if settingsStore.isTraktSyncEnabled {
                Toggle("Sync Watchlist", isOn: $settingsStore.traktSyncWatchlist)
                Toggle("Sync Watched Status", isOn: $settingsStore.traktSyncWatched)
                Toggle("Sync Ratings", isOn: $settingsStore.traktSyncRatings)
                Toggle("Sync Custom Lists", isOn: $settingsStore.traktSyncCustomLists)
            }
        }
    }
    
    private var syncOptionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if settingsStore.isTraktSyncEnabled {
                HStack {
                    Text("Background Sync")
                    Spacer()
                    Text(backgroundSync.isBackgroundSyncEnabled ? "Enabled" : "Disabled")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Auto-sync on App Launch")
                    Spacer()
                    Text(settingsStore.traktLastSync != nil ? "Enabled" : "Disabled")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var syncStatusView: some View {
        if isSyncing {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Syncing...")
                        .fontWeight(.semibold)
                }
                
                ProgressView(value: syncProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(syncProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Last Sync")
                    Spacer()
                    Text(lastSyncDateString)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Sync Status")
                    Spacer()
                    Text(syncStatusText)
                        .foregroundColor(syncStatusColor)
                }
                
                if let itemCount = settingsStore.traktLastSync != nil ? "All items" : "Never synced" {
                    HStack {
                        Text("Items Synced")
                        Spacer()
                        Text(itemCount)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private var actionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !isSyncing {
                Button(action: {
                    performFullSync()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync Now")
                        Spacer()
                    }
                }
                .disabled(!settingsStore.isTraktSyncEnabled)
                
                Button(action: {
                    performQuickSync()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Pull from Trakt")
                        Spacer()
                    }
                }
                .disabled(!settingsStore.isTraktSyncEnabled)
                
                Button(action: {
                    performPushSync()
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle")
                        Text("Push to Trakt")
                        Spacer()
                    }
                }
                .disabled(!settingsStore.isTraktSyncEnabled)
            }
            
            if settingsStore.isTraktSyncEnabled {
                Button(action: {
                    resetSyncData()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Reset Sync Data")
                        Spacer()
                    }
                }
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var lastSyncDateString: String {
        guard let lastSync = settingsStore.traktLastSync else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
    
    private var syncStatusText: String {
        Task {
            let status = await backgroundSync.getSyncStatus()
            return status.description
        }
        
        if settingsStore.traktLastSync == nil {
            return "Never synced"
        } else if isSyncing {
            return "Syncing..."
        } else {
            let timeSinceSync = Date().timeIntervalSince(settingsStore.traktLastSync!)
            if timeSinceSync < 300 { // 5 minutes
                return "Up to date"
            } else if timeSinceSync < 3600 { // 1 hour
                return "Recent"
            } else {
                return "Needs sync"
            }
        }
    }
    
    private var syncStatusColor: Color {
        if settingsStore.traktLastSync == nil {
            return .gray
        } else if isSyncing {
            return .blue
        } else {
            let timeSinceSync = Date().timeIntervalSince(settingsStore.traktLastSync!)
            if timeSinceSync < 300 { // 5 minutes
                return .green
            } else if timeSinceSync < 3600 { // 1 hour
                return .orange
            } else {
                return .red
            }
        }
    }
    
    // MARK: - Actions
    
    private func connectToTrakt() {
        Task {
            do {
                try await traktService.authenticate()
                logger.info("Successfully connected to Trakt")
            } catch {
                logger.error("Failed to connect to Trakt: \(error.localizedDescription)")
                authError = error.localizedDescription
                showingAuthAlert = true
            }
        }
    }
    
    private func disconnectFromTrakt() {
        traktService.signOut()
        settingsStore.isTraktSyncEnabled = false
        settingsStore.traktLastSync = nil
        logger.info("Disconnected from Trakt")
    }
    
    private func performFullSync() {
        Task {
            do {
                try await syncEngine.performFullSync()
                logger.info("Full sync completed successfully")
            } catch {
                logger.error("Full sync failed: \(error.localizedDescription)")
                syncErrorMessage = error.localizedDescription
                showingSyncError = true
            }
        }
    }
    
    private func performQuickSync() {
        Task {
            do {
                try await syncEngine.syncTraktChangesToLocal()
                logger.info("Quick sync completed successfully")
            } catch {
                logger.error("Quick sync failed: \(error.localizedDescription)")
                syncErrorMessage = error.localizedDescription
                showingSyncError = true
            }
        }
    }
    
    private func performPushSync() {
        Task {
            do {
                try await syncEngine.syncLocalChangesToTrakt()
                logger.info("Push sync completed successfully")
            } catch {
                logger.error("Push sync failed: \(error.localizedDescription)")
                syncErrorMessage = error.localizedDescription
                showingSyncError = true
            }
        }
    }
    
    private func resetSyncData() {
        let alert = UIAlertController(
            title: "Reset Sync Data",
            message: "This will clear all Trakt sync data and timestamps. Are you sure?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            settingsStore.traktLastSync = nil
            settingsStore.traktUsername = nil
            logger.info("Reset Trakt sync data")
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Extensions

extension TraktBackgroundSync {
    var isBackgroundSyncEnabled: Bool {
        let settings = SettingsStore.shared
        return settings.isUserConnectedWithTrakt && settings.isTraktSyncEnabled
    }
}

#Preview {
    NavigationStack {
        TraktSettingsView()
    }
}