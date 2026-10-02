#if os(iOS) || os(macOS)
import SwiftUI
import CoreData

/// This view provides quick information and utilities to the developer.
struct DeveloperView: View {
    @State private var item: ItemContent?
    @State private var person: Person?
    @State private var itemIdField = ""
    @State private var itemMediaType: MediaType = .movie
    @State private var isFetching = false
    @State private var isFetchingAll = false
    @State private var userAccessId = String()
    @State private var userAccessToken = String()
    @State private var v3SessionID = String()
    private let persistence = PersistenceController.shared
    private let service = NetworkService.shared
    @State private var showOnboarding = false
    @State private var dailyPuzzleAdminKey = ""
    @State private var dailyPuzzleAdminEnabled = true
    @State private var dailyPuzzleAdminPushEnabled = true
    @State private var dailyPuzzleAdminIsSaving = false
    @State private var dailyPuzzleAdminIsSendingTestPush = false
    @State private var dailyPuzzleAdminStatus = ""
    @State private var reviewPromptDebugRefresh = 0
    @State private var isUserSignedInWithTMDB = false
    private let dailyPuzzleAdminService = DailyPuzzleAdminConfigService()
    var body: some View {
        Form {
            Section("Network") {
                TextField("ID", text: $itemIdField)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                Picker("Media Type", selection: $itemMediaType) {
                    ForEach(MediaType.allCases) { media in
                        Text(media.title).tag(media)
                    }
                }
                Button {
                    Task {
                        if !itemIdField.isEmpty {
                            await MainActor.run {
                                withAnimation { isFetching = false }
                            }
                            if itemMediaType != .person {
                                let item = try? await service.fetchItem(id: Int(itemIdField)!, type: itemMediaType)
                                if let item {
                                    self.item = item
                                }
                            } else {
                                let person = try? await service.fetchPerson(id: Int(itemIdField)!)
                                guard let person else { return }
                                self.person = person
                            }
                        }
                        await MainActor.run {
                            withAnimation { isFetching = false }
                        }
                    }
                } label: {
                    if isFetching {
                        CenterHorizontalView {
                            ProgressView()
                        }
                    } else {
                        Text("Fetch")
                    }
                }
#if os(macOS)
                .buttonStyle(.link)
#endif
            }
            
            Section("Presentation") {
                Button("Show Onboarding") {
                    showOnboarding.toggle()
                }
                .sheet(isPresented: $showOnboarding) {
                    NavigationStack {
                        WelcomeView()
                            .interactiveDismissDisabled(false)
                    }
#if os(macOS)
                    .frame(width: 500, height: 700, alignment: .center)
#endif
                }
#if os(macOS)
                .buttonStyle(.link)
#endif
            }

            Section("Daily Puzzle Admin") {
                SecureField("Admin API Key", text: $dailyPuzzleAdminKey)
                Toggle("Generation Enabled", isOn: $dailyPuzzleAdminEnabled)
                Toggle("Push Enabled", isOn: $dailyPuzzleAdminPushEnabled)
                Button {
                    Task {
                        await updateDailyPuzzleAdminConfig()
                    }
                } label: {
                    if dailyPuzzleAdminIsSaving {
                        HStack {
                            ProgressView()
                            Text("Applying...")
                        }
                    } else {
                        Text("Apply Backend Config")
                    }
                }
                .disabled(dailyPuzzleAdminIsSaving)
#if os(macOS)
                .buttonStyle(.link)
#endif
                Button {
                    Task {
                        await sendDailyPuzzleTestPush()
                    }
                } label: {
                    if dailyPuzzleAdminIsSendingTestPush {
                        HStack {
                            ProgressView()
                            Text("Sending test push...")
                        }
                    } else {
                        Text("Send Test Push")
                    }
                }
                .disabled(dailyPuzzleAdminIsSendingTestPush || dailyPuzzleAdminIsSaving)
#if os(macOS)
                .buttonStyle(.link)
#endif
                if !dailyPuzzleAdminStatus.isEmpty {
                    Text(dailyPuzzleAdminStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section {
                Text("User Region: \(Locale.userRegion)")
                Text("User Lang: \(Locale.userLang)")
                Text("Is PostHog Initialized: \(CronicaTelemetry.shared.isPostHogInitialized)")
                Text("Last maintenance: \(BackgroundManager.shared.lastMaintenance?.convertDateToString() ?? "Nil")")
                Text("Last watching refresh: \(BackgroundManager.shared.lastWatchingRefresh?.convertDateToString() ?? "Nil")")
                Text("Last upcoming refresh: \(BackgroundManager.shared.lastUpcomingRefresh?.convertDateToString() ?? "Nil")")
                Text("Review active days: \(ReviewPromptCoordinator.shared.activeDayCount)")
                Text("Review milestones: \(ReviewPromptCoordinator.shared.earnedMilestones.map(\.rawValue).joined(separator: ", "))")
                Text("Review last attempt version: \(ReviewPromptCoordinator.shared.lastRequestVersion ?? "None")")
                Text("Is User Signed In With TMDB: \(isUserSignedInWithTMDB.description)")
                Button("Reset review attempt history") {
                    ReviewPromptCoordinator.shared.resetRequestHistory()
                    reviewPromptDebugRefresh += 1
                }
                .id(reviewPromptDebugRefresh)
                Button("Force SignOut") {
                    Task { await AccountManager.shared.logOut() }
                }
            }
            .onAppear {
                let data = KeychainHelper.standard.read(service: "access-token", account: "cronicaTMDB-Sync")
                let IdData = KeychainHelper.standard.read(service: "access-id", account: "cronicaTMDB-Sync")
                let sessionID = KeychainHelper.standard.read(service: "session-id", account: "cronicaTMDB-Sync")
                if data != nil && IdData != nil && sessionID != nil {
                    isUserSignedInWithTMDB = true
                }
            }
            
        }
        .navigationTitle("Developer Options")
        .sheet(item: $item) { item in
            NavigationStack {
                ItemContentDetails(title: item.itemTitle, id: item.id, type: item.itemContentMedia, handleToolbar: true)
                    .toolbar {
#if os(iOS)
                        ToolbarItem(placement: .navigationBarLeading) {
                            HStack {
                                Button("Done") {
                                    self.item = nil
                                }
                                Menu {
                                    Button {
                                        let watchlist = PersistenceController.shared.fetch(for: item.itemContentID)
                                        if let watchlist {
                                            CronicaTelemetry.shared.handleMessage("WatchlistItem: \(watchlist as Any)",
                                                                                  for: "DeveloperView.printObject")
                                        }
                                        CronicaTelemetry.shared.handleMessage("ItemContent: \(item as Any)",
                                                                              for: "DeveloperView.printObject")
                                    } label: {
                                        Label("Send Object to Developer", systemImage: "hammer.circle.fill")
                                    }
                                } label: {
                                    Image(systemName: "hammer")
                                }
                            }
                        }
#else
                        Button("Done") { self.item = nil }
#endif
                    }
                    .navigationDestination(for: ItemContent.self) { item in
                        ItemContentDetails(title: item.itemTitle, id: item.id, type: item.itemContentMedia)
                    }
                    .navigationDestination(for: Person.self) { item in
                        PersonDetailsView(name: item.name, id: item.id)
                    }
            }
        }
        .sheet(item: $person) { item in
            NavigationStack {
                PersonDetailsView(name: item.name, id: item.id)
                    .toolbar {
                        ToolbarItem {
                            Button("Done") {
                                self.person = nil
                            }
                        }
                    }
                    .navigationDestination(for: ItemContent.self) { item in
                        ItemContentDetails(title: item.itemTitle, id: item.id, type: item.itemContentMedia)
                    }
                    .navigationDestination(for: Person.self) { item in
                        PersonDetailsView(name: item.name, id: item.id)
                    }
            }
        }
#if os(macOS)
        .formStyle(.grouped)
#endif
    }

    @MainActor
    private func updateDailyPuzzleAdminConfig() async {
        dailyPuzzleAdminIsSaving = true
        defer { dailyPuzzleAdminIsSaving = false }

        do {
            try await dailyPuzzleAdminService.updateConfig(
                request: DailyPuzzleAdminConfigUpdateRequest(
                    enabled: dailyPuzzleAdminEnabled,
                    pushEnabled: dailyPuzzleAdminPushEnabled
                ),
                apiKey: dailyPuzzleAdminKey
            )
            dailyPuzzleAdminStatus = "Updated backend config successfully."
        } catch {
            dailyPuzzleAdminStatus = "Update failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func sendDailyPuzzleTestPush() async {
        dailyPuzzleAdminIsSendingTestPush = true
        defer { dailyPuzzleAdminIsSendingTestPush = false }

        do {
            try await dailyPuzzleAdminService.sendTestPush(apiKey: dailyPuzzleAdminKey)
            dailyPuzzleAdminStatus = "Sent test push successfully."
        } catch {
            dailyPuzzleAdminStatus = "Test push failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    DeveloperView()
}

struct DailyPuzzleAdminConfigUpdateRequest: Encodable {
    let enabled: Bool?
    let pushEnabled: Bool?
}

struct DailyPuzzleAdminConfigService {
    enum ServiceError: LocalizedError, Equatable {
        case missingEndpointURL
        case missingAdminKey
        case missingPayload
        case invalidResponse
        case badStatusCode(Int)

        var errorDescription: String? {
            switch self {
            case .missingEndpointURL:
                return "Missing admin endpoint URL."
            case .missingAdminKey:
                return "Admin API key is required."
            case .missingPayload:
                return "At least one config field must be set."
            case .invalidResponse:
                return "The server returned an invalid response."
            case let .badStatusCode(code):
                return "Server responded with status \(code)."
            }
        }
    }

    let session: URLSession
    let endpointURL: URL?
    let testPushEndpointURL: URL?

    init(
        session: URLSession = .shared,
        endpointURL: URL? = Key.dailyPuzzleAdminConfigURL,
        testPushEndpointURL: URL? = Key.dailyPuzzleAdminTestPushURL
    ) {
        self.session = session
        self.endpointURL = endpointURL
        self.testPushEndpointURL = testPushEndpointURL
    }

    func updateConfig(request: DailyPuzzleAdminConfigUpdateRequest, apiKey: String?) async throws {
        guard let endpointURL else { throw ServiceError.missingEndpointURL }
        guard request.enabled != nil || request.pushEnabled != nil else {
            throw ServiceError.missingPayload
        }
        let trimmedApiKey = try normalizedApiKey(apiKey)

        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(trimmedApiKey, forHTTPHeaderField: "x-admin-key")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (_, response) = try await session.data(for: urlRequest)
        try validateResponse(response)
    }

    func sendTestPush(apiKey: String?) async throws {
        guard let testPushEndpointURL else { throw ServiceError.missingEndpointURL }
        let trimmedApiKey = try normalizedApiKey(apiKey)

        var urlRequest = URLRequest(url: testPushEndpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(trimmedApiKey, forHTTPHeaderField: "x-admin-key")

        let (_, response) = try await session.data(for: urlRequest)
        try validateResponse(response)
    }

    private func normalizedApiKey(_ apiKey: String?) throws -> String {
        guard let apiKey else { throw ServiceError.missingAdminKey }
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedApiKey.isEmpty else { throw ServiceError.missingAdminKey }
        return trimmedApiKey
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ServiceError.badStatusCode(httpResponse.statusCode)
        }
    }
}
#endif
