import Foundation

// Run with scripts/test_daily_puzzle_reminders.sh; no app or Firebase startup required.
@main
struct ReminderTests {
    @MainActor static func main() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
        let morning = date("2026-09-28T14:00:00Z")
        let dates = DailyPuzzleReminderPolicy.dates(now: morning, calendar: calendar, completedAt: nil)
        precondition(dates.count == 7)
        precondition(dates.first == date("2026-09-28T22:00:00Z"))
        precondition(Set(dates.map { calendar.startOfDay(for: $0) }).count == 7)
        let finished = DailyPuzzleReminderPolicy.dates(now: morning, calendar: calendar, completedAt: morning)
        precondition(finished.first == date("2026-09-29T22:00:00Z"))
        let evening = DailyPuzzleReminderPolicy.dates(now: date("2026-09-28T23:00:00Z"), calendar: calendar, completedAt: nil)
        precondition(evening.first == date("2026-09-29T22:00:00Z"))
        let boundary = DailyPuzzleReminderPolicy.dates(now: date("2026-09-28T22:00:00Z"), calendar: calendar, completedAt: nil)
        precondition(boundary.first == date("2026-09-29T22:00:00Z"))
        let dst = DailyPuzzleReminderPolicy.dates(now: date("2026-10-31T14:00:00Z"), calendar: calendar, completedAt: nil)
        precondition(dst[0] == date("2026-10-31T22:00:00Z"))
        precondition(dst[1] == date("2026-11-01T23:00:00Z"))
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let japan = DailyPuzzleReminderPolicy.dates(now: date("2026-09-28T01:00:00Z"), calendar: calendar, completedAt: nil)
        precondition(japan.first == date("2026-09-28T09:00:00Z"))

        let center = FakeReminderCenter()
        let coordinator = DailyPuzzleReminderCoordinator(center: center)
        center.pending["daily-puzzle-fallback-old"] = morning
        center.pending["movie-release"] = morning
        await coordinator.refresh(enabled: true, now: morning, calendar: calendar, completedAt: nil).value
        precondition(center.pending.count == 8)
        precondition(center.pending["daily-puzzle-fallback-old"] == nil)
        precondition(center.pending["movie-release"] == morning)
        await coordinator.refresh(enabled: true, now: morning, calendar: calendar, completedAt: nil).value
        precondition(center.pending.count == 8, "Refresh must not duplicate reminders")
        await coordinator.refresh(enabled: false, now: morning, calendar: calendar, completedAt: nil).value
        precondition(center.pending.count == 1, "Opt-out must clear only puzzle reminders")

        center.pauseNextAdd = true
        let first = coordinator.refresh(enabled: true, now: morning, calendar: calendar, completedAt: nil)
        while center.pausedAdd == nil { await Task.yield() }
        let optOut = coordinator.refresh(enabled: false, now: morning, calendar: calendar, completedAt: nil)
        center.pausedAdd?.resume()
        center.pausedAdd = nil
        await first.value
        await optOut.value
        precondition(center.pending.count == 1, "In-flight add must not restore reminders after opt-out")

        center.pauseNextAdd = true
        let unfinished = coordinator.refresh(enabled: true, now: morning, calendar: calendar, completedAt: nil)
        while center.pausedAdd == nil { await Task.yield() }
        let completed = coordinator.refresh(enabled: true, now: morning, calendar: calendar, completedAt: morning)
        center.pausedAdd?.resume()
        center.pausedAdd = nil
        await unfinished.value
        await completed.value
        precondition(!center.pending.filter { $0.key != "movie-release" }.values.contains { calendar.isDate($0, inSameDayAs: morning) })
        precondition(center.pending.count == 8)
        print("PASS: local time, DST, date boundary, completion, idempotence, legacy cleanup, opt-out and scheduling races")
    }
}

@MainActor final class FakeReminderCenter: DailyPuzzleReminderCenter {
    var pending: [String: Date] = [:]
    var pauseNextAdd = false
    var pausedAdd: CheckedContinuation<Void, Never>?
    func pendingIdentifiers() async -> [String] { Array(pending.keys) }
    func remove(identifiers: [String]) { for id in identifiers { pending.removeValue(forKey: id) } }
    func add(identifier: String, date: Date, calendar: Calendar) async throws {
        if pauseNextAdd {
            pauseNextAdd = false
            await withCheckedContinuation { pausedAdd = $0 }
        }
        pending[identifier] = date
    }
}
