import CoreData
import CloudKit

/// An environment singleton responsible for managing Watchlist Core Data stack, including handling saving,
/// tracking watchlists, and dealing with sample data.
struct PersistenceController {
    static let shared = PersistenceController()
    
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
    
    init(inMemory: Bool = false, useCloudKit: Bool = true) {
        if useCloudKit {
            container = NSPersistentCloudKitContainer(name: "Watchlist")
        } else {
            container = NSPersistentContainer(name: "Watchlist")
        }
        
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
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
        if !inMemory, let cloudKitContainer = container as? NSPersistentCloudKitContainer {
            do {
                try cloudKitContainer.initializeCloudKitSchema()
            } catch {
                print("initializeCloudKitSchema: \(error.localizedDescription)")
            }
        }
#endif
    }
    
    func save() {
        if container.viewContext.hasChanges {
            try? container.viewContext.save()
        }
    }
}
