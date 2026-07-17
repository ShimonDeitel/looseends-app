import XCTest
@testable import LooseEnds

/// Hand-verified tests for the three pure-logic engines that power Loose
/// Ends without ever touching the network or the UI: `TriageParser` (the
/// AI response's lenient JSON-in-text parsing and its never-lose-it
/// fallback), `CheckInScheduler` (when an item becomes due for its honesty
/// check-in), and `HonestyEngine` (the streak/closed/let-go math).
final class LooseEndsLogicTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    // MARK: - TriageParser

    func testTriageParser_parsesFullValidJSON() {
        let raw = #"{"bucket":"reminder","itemName":"call the dentist","personName":null,"date":"2026-07-18T15:00:00Z"}"#
        let result = TriageParser.parse(raw)

        XCTAssertEqual(result.bucket, .reminder)
        XCTAssertEqual(result.itemName, "call the dentist")
        XCTAssertNil(result.personName)
        XCTAssertEqual(result.date, date(2026, 7, 18, hour: 15))
    }

    func testTriageParser_parsesMarkdownFencedJSON() {
        let raw = """
        ```json
        {"bucket":"shopping","itemName":"milk","personName":null,"date":null}
        ```
        """
        let result = TriageParser.parse(raw)

        XCTAssertEqual(result.bucket, .shopping)
        XCTAssertEqual(result.itemName, "milk")
        XCTAssertNil(result.personName)
        XCTAssertNil(result.date)
    }

    func testTriageParser_fallsBackToFollowUpOnMalformedInput() {
        let raw = "Sorry, I can't help with that request."
        let result = TriageParser.parse(raw)

        XCTAssertEqual(result, TriageParser.fallback)
        XCTAssertEqual(result.bucket, .followUp)
        XCTAssertNil(result.itemName)
        XCTAssertNil(result.personName)
        XCTAssertNil(result.date)
    }

    func testTriageParser_unrecognizedBucketDefaultsToFollowUpButKeepsFields() {
        // "grocery" isn't a recognized bucket string — the item must still
        // land somewhere (Follow-up) rather than being dropped, but the
        // fields the model *did* extract are not thrown away.
        let raw = #"{"bucket":"grocery","itemName":"eggs","personName":null,"date":null}"#
        let result = TriageParser.parse(raw)

        XCTAssertEqual(result.bucket, .followUp)
        XCTAssertEqual(result.itemName, "eggs")
    }

    func testTriageParser_parsesDateOnlyString() throws {
        let raw = #"{"bucket":"calendar","itemName":"Team meeting","personName":"Sam","date":"2026-08-01"}"#
        let result = TriageParser.parse(raw)

        XCTAssertEqual(result.bucket, .calendarEvent)
        XCTAssertEqual(result.personName, "Sam")
        let date = try XCTUnwrap(result.date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 1)
    }

    // MARK: - CheckInScheduler

    func testCheckInScheduler_defaultDelayBoundary() {
        let created = date(2026, 1, 1)
        let item = Item(rawText: "buy milk", createdAt: created, bucket: .shopping)

        let notYetDue = CheckInScheduler.itemsDueForCheckIn(
            items: [item],
            asOf: created.addingTimeInterval(CheckInScheduler.defaultDelay - 1)
        )
        XCTAssertTrue(notYetDue.isEmpty)

        let due = CheckInScheduler.itemsDueForCheckIn(
            items: [item],
            asOf: created.addingTimeInterval(CheckInScheduler.defaultDelay)
        )
        XCTAssertEqual(due.map(\.id), [item.id])
    }

    func testCheckInScheduler_dateAwareDelayBoundary() {
        let created = date(2026, 1, 1)
        let extracted = date(2026, 1, 5) // 4 days after capture
        let item = Item(rawText: "Team meeting", createdAt: created, bucket: .calendarEvent, extractedDate: extracted)

        let expectedDueDate = extracted.addingTimeInterval(CheckInScheduler.postDueGrace)
        XCTAssertEqual(CheckInScheduler.dueDate(for: item), expectedDueDate)

        let notYetDue = CheckInScheduler.itemsDueForCheckIn(items: [item], asOf: expectedDueDate.addingTimeInterval(-1))
        XCTAssertTrue(notYetDue.isEmpty)

        let due = CheckInScheduler.itemsDueForCheckIn(items: [item], asOf: expectedDueDate)
        XCTAssertEqual(due.map(\.id), [item.id])
    }

    func testCheckInScheduler_excludesAnsweredAndUnfiledItems() {
        let created = date(2026, 1, 1)
        let farFuture = date(2030, 1, 1)

        let alreadyAnswered = Item(
            rawText: "already asked",
            createdAt: created,
            bucket: .reminder,
            checkInStatus: .answeredYes,
            checkInAnsweredAt: created.addingTimeInterval(3600)
        )
        let stillUnfiled = Item(rawText: "not filed yet", createdAt: created, bucket: nil)

        let due = CheckInScheduler.itemsDueForCheckIn(items: [alreadyAnswered, stillUnfiled], asOf: farFuture)
        XCTAssertTrue(due.isEmpty)
    }

    // MARK: - HonestyEngine

    func testHonestyEngine_computesStreakAndTotals() {
        let base = date(2026, 1, 1)
        // Chronological answers: yes, yes, no, yes.
        let items = [
            Item(rawText: "A", createdAt: base, bucket: .reminder, checkInStatus: .answeredYes, checkInAnsweredAt: base.addingTimeInterval(1)),
            Item(rawText: "B", createdAt: base, bucket: .reminder, checkInStatus: .answeredYes, checkInAnsweredAt: base.addingTimeInterval(2)),
            Item(rawText: "C", createdAt: base, bucket: .reminder, checkInStatus: .answeredNo, checkInAnsweredAt: base.addingTimeInterval(3)),
            Item(rawText: "D", createdAt: base, bucket: .reminder, checkInStatus: .answeredYes, checkInAnsweredAt: base.addingTimeInterval(4))
        ]

        let stats = HonestyEngine.stats(for: items)

        // Trailing streak only counts the most recent run of "yes" answers —
        // the run stops the moment a "no" is hit walking backwards, so only
        // the final "yes" (D) counts, not A/B before the "no" (C).
        XCTAssertEqual(stats.currentStreak, 1)
        XCTAssertEqual(stats.totalClosed, 3)
        XCTAssertEqual(stats.totalLetGo, 1)
    }

    func testHonestyEngine_emptyItemsYieldsZeroStats() {
        let stats = HonestyEngine.stats(for: [])
        XCTAssertEqual(stats, HonestyStats(currentStreak: 0, totalClosed: 0, totalLetGo: 0))
    }
}
