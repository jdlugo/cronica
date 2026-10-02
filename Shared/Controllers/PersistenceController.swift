import CoreData
import CloudKit

/// An environment singleton responsible for managing Watchlist Core Data stack, including handling saving,
/// tracking watchlists, and dealing with sample data.
struct PersistenceController {
    static let shared: PersistenceController = {
#if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--arcade-discovery-test") {
            let directory = URL.applicationSupportDirectory.appendingPathComponent("ArcadeDiscoveryTests", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("Watchlist.sqlite")
            if ProcessInfo.processInfo.arguments.contains("--arcade-reset") {
                for suffix in ["", "-wal", "-shm"] {
                    try? FileManager.default.removeItem(atPath: url.path + suffix)
                }
            }
            return PersistenceController(useCloudKit: false, storeURL: url)
        }
#endif
        return PersistenceController()
    }()
    private static let enableCloudKitInSimulatorArgument = "-EnableCloudKitInSimulator"
    private static let initializeCloudKitSchemaArgument = "-InitializeCloudKitSchema"
    private static let modelName = "Watchlist"
    private static let managedObjectModel: NSManagedObjectModel = {
        let bundles = [
            Bundle.main,
            Bundle(for: WatchlistItem.self),
        ]

        for bundle in bundles {
            guard let modelURL = bundle.url(forResource: modelName, withExtension: "momd") else {
                continue
            }
            if let model = NSManagedObjectModel(contentsOf: modelURL) {
                return model
            }
        }

        fatalError("Unable to load \(modelName).momd")
    }()
    
    // MARK: Preview sample - uses NSPersistentContainer (no CloudKit) for reliability
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true, useCloudKit: false)
        let viewContext = result.container.viewContext
        for item in ItemContent.examples {
            let newItem = WatchlistItem(context: viewContext)
            newItem.title = item.itemTitle
            newItem.id = Int64(item.id)
            newItem.image = item.cardImageMedium
            newItem.contentType = MediaType.movie.toInt
            newItem.notify = Bool.random()
        }
        do {
            try viewContext.save()
        } catch {
            print("Preview Core Data save error: \(error.localizedDescription)")
        }
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false, useCloudKit: Bool = true, storeURL: URL? = nil) {
        if Self.shouldUseCloudKit(useCloudKit) {
            container = NSPersistentCloudKitContainer(
                name: Self.modelName,
                managedObjectModel: Self.managedObjectModel
            )
        } else {
            container = NSPersistentContainer(
                name: Self.modelName,
                managedObjectModel: Self.managedObjectModel
            )
        }
        
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else if let storeURL {
            container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
        }
        
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("Core Data persistent store error: \(error), \(error.userInfo)")
            }
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
#if DEBUG && os(iOS)
        if !inMemory,
           ProcessInfo.processInfo.arguments.contains(Self.initializeCloudKitSchemaArgument),
           let cloudKitContainer = container as? NSPersistentCloudKitContainer {
            do {
                try cloudKitContainer.initializeCloudKitSchema()
            } catch {
                print("initializeCloudKitSchema: \(error.localizedDescription)")
            }
        }
#endif
    }

    private static func shouldUseCloudKit(_ useCloudKit: Bool) -> Bool {
        guard useCloudKit else { return false }
#if targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains(Self.enableCloudKitInSimulatorArgument)
#else
        return true
#endif
    }
    
    func save() {
        if container.viewContext.hasChanges {
            try? container.viewContext.save()
        }
    }
}
