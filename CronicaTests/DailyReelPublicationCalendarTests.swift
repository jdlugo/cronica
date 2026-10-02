import Foundation
import Testing
@testable import StreamingNow

struct DailyReelPublicationCalendarTests {
    @Test("Daily Reel publication changes at 05:00 UTC")
    func publicationBoundary() throws {
        let formatter = ISO8601DateFormatter()
        let before = try #require(formatter.date(from: "2026-09-03T04:59:59Z"))
        let boundary = try #require(formatter.date(from: "2026-09-03T05:00:00Z"))

        #expect(DailyReelPublicationCalendar.publicationID(for: before) == "2026-09-02")
        #expect(DailyReelPublicationCalendar.publicationID(for: boundary) == "2026-09-03")
    }
}
