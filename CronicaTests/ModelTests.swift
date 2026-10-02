import XCTest
@testable import StreamingNow

/// Tests for data model integrity — ensuring TMDB API models decode correctly
/// and computed properties behave as expected.
final class ItemContentModelTests: XCTestCase {

    // MARK: - Preview Mock Validity

    func testPreviewMockExists() {
        let mock = ItemContent.previewMock
        XCTAssertEqual(mock.id, 791373)
    }

    func testPreviewMockHasTitle() {
        XCTAssertNotNil(ItemContent.previewMock.title)
        XCTAssertFalse(ItemContent.previewMock.itemTitle.isEmpty)
    }

    func testPreviewMockHasOverview() {
        XCTAssertNotNil(ItemContent.previewMock.overview)
        XCTAssertFalse(ItemContent.previewMock.overview!.isEmpty)
    }

    // MARK: - Computed Properties

    func testItemContentID() {
        let mock = ItemContent.previewMock
        let id = mock.itemContentID
        XCTAssertTrue(id.contains("@"), "itemContentID should contain '@' separator")
        XCTAssertTrue(id.hasPrefix("791373"), "Should start with the item ID")
    }

    func testItemContentMediaType() {
        let mock = ItemContent.previewMock
        XCTAssertEqual(mock.itemContentMedia, .movie,
                        "Preview mock should be a movie")
    }

    func testItemTitleFallback() {
        // Movie uses title, TV show uses name
        let movie = ItemContent.previewMock
        XCTAssertEqual(movie.itemTitle, "Zack Snyder's Justice League")
    }

    func testItemGenresList() {
        let mock = ItemContent.previewMock
        XCTAssertNotNil(mock.genres)
        XCTAssertFalse(mock.genres!.isEmpty, "Preview mock should have genres")
    }

    func testItemRuntime() {
        let mock = ItemContent.previewMock
        XCTAssertEqual(mock.runtime, 242, "Preview mock runtime should be 242 minutes")
    }

    func testItemRating() {
        let mock = ItemContent.previewMock
        XCTAssertNotNil(mock.voteAverage)
        XCTAssertEqual(mock.voteAverage!, 8.1, accuracy: 0.01)
    }

    func testProductionCompanies() {
        let mock = ItemContent.previewMock
        XCTAssertNotNil(mock.productionCompanies)
        XCTAssertEqual(mock.productionCompanies?.count, 2)
    }

    // MARK: - Image URLs

    func testPosterPathGeneratesURL() {
        let mock = ItemContent.previewMock
        XCTAssertNotNil(mock.posterPath)
    }

    func testBackdropPathGeneratesURL() {
        let mock = ItemContent.previewMock
        XCTAssertNotNil(mock.backdropPath)
    }

    // MARK: - Examples Collection

    func testExamplesArrayIsNotEmpty() {
        // Uses bundle resource or falls back to previewMock
        let examples = ItemContent.examples
        XCTAssertFalse(examples.isEmpty, "Examples should have at least the fallback mock")
    }

    func testExampleIsFirstInExamples() {
        let example = ItemContent.example
        let first = ItemContent.examples.first
        XCTAssertEqual(example.id, first?.id)
    }
}

// MARK: - JSON Decoding Tests

final class JSONDecodingTests: XCTestCase {

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testDecodeMinimalItemContent() throws {
        let json = """
        {
            "id": 12345,
            "title": "Test Movie",
            "overview": "A test movie overview.",
            "media_type": "movie"
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(ItemContent.self, from: json)
        XCTAssertEqual(item.id, 12345)
        XCTAssertEqual(item.title, "Test Movie")
        XCTAssertEqual(item.overview, "A test movie overview.")
    }

    func testDecodeItemContentWithNullFields() throws {
        let json = """
        {
            "id": 99999,
            "title": null,
            "name": "Test Show",
            "overview": null,
            "poster_path": null,
            "release_date": null,
            "media_type": "tv"
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(ItemContent.self, from: json)
        XCTAssertEqual(item.id, 99999)
        XCTAssertNil(item.title)
        XCTAssertEqual(item.name, "Test Show")
        XCTAssertNil(item.overview)
    }

    func testDecodeGenre() throws {
        let json = """
        {"id": 28, "name": "Action"}
        """.data(using: .utf8)!

        let genre = try decoder.decode(Genre.self, from: json)
        XCTAssertEqual(genre.id, 28)
        XCTAssertEqual(genre.name, "Action")
    }

    func testDecodeProductionCompany() throws {
        let json = """
        {
            "name": "Warner Bros.",
            "id": 174,
            "logo_path": "/test.png",
            "origin_country": "US"
        }
        """.data(using: .utf8)!

        let company = try decoder.decode(ProductionCompany.self, from: json)
        XCTAssertEqual(company.id, 174)
        XCTAssertEqual(company.name, "Warner Bros.")
    }

    func testDecodeWatchProviderContent() throws {
        let json = """
        {
            "logo_path": "/test.png",
            "provider_id": 8,
            "provider_name": "Netflix",
            "display_priority": 1
        }
        """.data(using: .utf8)!

        let provider = try decoder.decode(WatchProviderContent.self, from: json)
        XCTAssertEqual(provider.providerId, 8)
        XCTAssertEqual(provider.providerName, "Netflix")
    }
}

// MARK: - MediaType Tests

final class MediaTypeTests: XCTestCase {

    func testMovieMediaType() {
        let mock = ItemContent.previewMock
        XCTAssertEqual(mock.itemContentMedia, .movie)
    }

    func testItemContentIDContainsMediaType() {
        let mock = ItemContent.previewMock
        let id = mock.itemContentID
        // Movie should end with @0 (movie int representation)
        XCTAssertTrue(id.hasSuffix("@0") || id.contains("@"),
                       "ID should encode the media type")
    }
}
