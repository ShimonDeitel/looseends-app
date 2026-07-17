import Foundation

/// Pure scheduling logic for the honesty-check quirky feature: decides
/// which filed items are due to be asked "did you actually handle it?"
/// as of a given moment, entirely independent of the UI or clock.
enum CheckInScheduler {
    /// An item with no extracted date becomes due for a check-in this long
    /// after it was captured.
    static let defaultDelay: TimeInterval = 24 * 60 * 60

    /// An item with an extracted date becomes due this long *after* that
    /// date/time — the check-in should land once the moment was supposed to
    /// happen, not before.
    static let postDueGrace: TimeInterval = 2 * 60 * 60

    /// How long after capture a given item becomes eligible for a check-in.
    static func delay(for item: Item) -> TimeInterval {
        guard let extractedDate = item.extractedDate else { return defaultDelay }
        let sinceCapture = extractedDate.timeIntervalSince(item.createdAt)
        // A mis-parsed date landing before capture would otherwise produce
        // a zero/negative delay; fall back to the default instead.
        guard sinceCapture > 0 else { return defaultDelay }
        return sinceCapture + postDueGrace
    }

    static func dueDate(for item: Item) -> Date {
        item.createdAt.addingTimeInterval(delay(for: item))
    }

    /// Items eligible to be surfaced as a check-in right now: filed (a
    /// scattered, unfiled note has nothing to check in on yet), never
    /// asked before, and past their computed due date.
    static func itemsDueForCheckIn(items: [Item], asOf date: Date) -> [Item] {
        items.filter { item in
            guard item.bucket != nil else { return false }
            guard item.checkInStatus == .none else { return false }
            return date >= dueDate(for: item)
        }
    }
}
