import Foundation

enum DailyPuzzleReminderPolicy {
    static let identifierPrefix = "daily-puzzle-local-"

    static func owns(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix) || identifier.hasPrefix("daily-puzzle-fallback-")
    }

    // A bounded schedule avoids indefinitely nudging inactive users. Every foreground
    // refresh replenishes it. Calendar days (not 24-hour offsets) preserve 18:00 over DST.
    static func dates(now: Date, calendar: Calendar, completedAt: Date?) -> [Date] {
        (0...7).compactMap { offset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let delivery = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day),
                  delivery > now else { return nil }
            if let completedAt, calendar.isDate(delivery, inSameDayAs: completedAt) { return nil }
            return delivery
        }.prefix(7).map { $0 }
    }

    static func identifier(for date: Date, calendar: Calendar) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(identifierPrefix)\(day.year!)-\(day.month!)-\(day.day!)"
    }
}

@MainActor
protocol DailyPuzzleReminderCenter {
    func pendingIdentifiers() async -> [String]
    func remove(identifiers: [String])
    func add(identifier: String, date: Date, calendar: Calendar) async throws
}

@MainActor
final class DailyPuzzleReminderCoordinator {
    private let center: DailyPuzzleReminderCenter
    private let reportError: (Error) -> Void
    private var revision = 0
    private var worker: Task<Void, Never>?

    init(center: DailyPuzzleReminderCenter, reportError: @escaping (Error) -> Void = { _ in }) {
        self.center = center
        self.reportError = reportError
    }

    @discardableResult
    func refresh(enabled: Bool, now: Date, calendar: Calendar, completedAt: Date?) -> Task<Void, Never> {
        revision += 1
        let requestedRevision = revision
        let previous = worker
        let task = Task { @MainActor in
            // Serialize replacement even when UNUserNotificationCenter.add is suspended.
            await previous?.value
            guard requestedRevision == revision else { return }
            let pending = await center.pendingIdentifiers()
            guard requestedRevision == revision else { return }
            center.remove(identifiers: pending.filter(DailyPuzzleReminderPolicy.owns))
            guard enabled else { return }
            for date in DailyPuzzleReminderPolicy.dates(now: now, calendar: calendar, completedAt: completedAt) {
                guard requestedRevision == revision else { return }
                let identifier = DailyPuzzleReminderPolicy.identifier(for: date, calendar: calendar)
                do {
                    try await center.add(identifier: identifier, date: date, calendar: calendar)
                } catch {
                    reportError(error)
                }
                if requestedRevision != revision {
                    center.remove(identifiers: [identifier])
                    return
                }
            }
        }
        worker = task
        return task
    }
}
