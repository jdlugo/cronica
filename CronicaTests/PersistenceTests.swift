import XCTest
import CoreData
@testable import StreamingNow

/// Expanded persistence tests covering Core Data CRUD, custom lists, and edge cases.
final class PersistenceTests: XCTestCase {

    var persistence: PersistenceController!

    override func setUpWithError() throws {
        persistence = PersistenceController(inMemory: true, useCloudKit: false)
    }

    override func tearDownWithError() throws {
        persistence = nil
    }

    // MARK: - Basic CRUD

    func testSaveAndRetrieveItem() {
        let item = ItemContent.previewMock
        persistence.save(item)
        XCTAssertTrue(persistence.isItemSaved(id: item.itemContentID))
    }

    func testDeleteItem() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let fetched = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist after save")
            return
        }
        persistence.delete(fetched)
        XCTAssertFalse(persistence.isItemSaved(id: item.itemContentID))
    }

    func testFetchNonExistentItemReturnsNil() {
        let result = persistence.fetch(for: "nonexistent_id")
        XCTAssertNil(result, "Fetching a non-existent ID should return nil")
    }

    // MARK: - Flags (Watched, Favorite, Archive, Pin)

    func testWatchedToggle() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let fetched = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist")
            return
        }

        // Toggle on
        persistence.updateWatched(for: fetched)
        XCTAssertTrue(persistence.isMarkedAsWatched(id: item.itemContentID))

        // Toggle off
        persistence.updateWatched(for: fetched)
        XCTAssertFalse(persistence.isMarkedAsWatched(id: item.itemContentID))
    }

    func testFavoriteToggle() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let fetched = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist")
            return
        }

        persistence.updateFavorite(for: fetched)
        XCTAssertTrue(persistence.isMarkedAsFavorite(id: item.itemContentID))

        persistence.updateFavorite(for: fetched)
        XCTAssertFalse(persistence.isMarkedAsFavorite(id: item.itemContentID))
    }

    func testArchiveToggle() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let fetched = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist")
            return
        }

        persistence.updateArchive(for: fetched)
        XCTAssertTrue(persistence.isItemArchived(id: item.itemContentID))

        persistence.updateArchive(for: fetched)
        XCTAssertFalse(persistence.isItemArchived(id: item.itemContentID))
    }

    func testPinToggle() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let fetched = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist")
            return
        }

        persistence.updatePin(for: fetched)
        XCTAssertTrue(persistence.isItemPinned(id: item.itemContentID))

        persistence.updatePin(for: fetched)
        XCTAssertFalse(persistence.isItemPinned(id: item.itemContentID))
    }

    // MARK: - Edge Cases

    func testSaveSameItemTwiceDoesNotCrash() {
        let item = ItemContent.previewMock
        persistence.save(item)
        persistence.save(item)
        XCTAssertTrue(persistence.isItemSaved(id: item.itemContentID))
    }

    func testDeleteAlreadyDeletedItemDoesNotCrash() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let fetched = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist")
            return
        }
        persistence.delete(fetched)
        // Item is already deleted from context — accessing it again shouldn't crash
        XCTAssertFalse(persistence.isItemSaved(id: item.itemContentID))
    }

    func testMultipleItemsSaveAndRetrieve() {
        let items = ItemContent.examples
        for item in items {
            persistence.save(item)
        }
        for item in items {
            XCTAssertTrue(persistence.isItemSaved(id: item.itemContentID),
                          "Item \(item.itemContentID) should be saved")
        }
    }

    // MARK: - Custom Lists

    func testCreateCustomList() {
        let list = persistence.createList(title: "My List",
                                          description: "Test list",
                                          items: Set(),
                                          isPin: false)
        XCTAssertNotNil(list, "Custom list creation should succeed")
    }

    func testAddItemToCustomList() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let watchlistItem = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist")
            return
        }

        guard let list = persistence.createList(title: "Favorites",
                                                description: "",
                                                items: Set([watchlistItem]),
                                                isPin: false) else {
            XCTFail("List creation should succeed")
            return
        }

        XCTAssertTrue(persistence.isItemOnList(id: item.itemContentID, list: list))
    }

    func testRemoveItemFromCustomList() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let watchlistItem = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist")
            return
        }

        guard let list = persistence.createList(title: "Test",
                                                description: "",
                                                items: Set([watchlistItem]),
                                                isPin: false) else {
            XCTFail("List creation should succeed")
            return
        }

        persistence.removeItemsFromList(of: list, with: Set([watchlistItem]))
        XCTAssertFalse(persistence.isItemOnList(id: item.itemContentID, list: list))
    }

    func testItemOnMultipleLists() {
        let item = ItemContent.previewMock
        persistence.save(item)
        guard let watchlistItem = persistence.fetch(for: item.itemContentID) else {
            XCTFail("Item should exist")
            return
        }

        let list1 = persistence.createList(title: "List 1", description: "",
                                           items: Set([watchlistItem]), isPin: false)
        let list2 = persistence.createList(title: "List 2", description: "",
                                           items: Set([watchlistItem]), isPin: false)

        XCTAssertNotNil(list1)
        XCTAssertNotNil(list2)

        let count = persistence.isItemOnHowManyLists(id: item.itemContentID)
        XCTAssertEqual(count, 2, "Item should be on 2 lists")
    }

    func testUpdateListTitle() {
        guard let list = persistence.createList(title: "Old Title",
                                                description: "",
                                                items: Set(),
                                                isPin: false) else {
            XCTFail("List creation should succeed")
            return
        }

        persistence.updateListTitle(of: list, with: "New Title")
        XCTAssertEqual(list.title, "New Title")
    }
}
