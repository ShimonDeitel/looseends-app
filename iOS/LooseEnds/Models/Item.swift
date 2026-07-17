import Foundation

/// The four destinations a captured thought can land in.
enum Bucket: String, Codable, CaseIterable, Hashable, Identifiable {
    var id: String { rawValue }

    case reminder
    case calendarEvent = "calendar"
    case shopping
    case followUp = "followup"

    var shortLabel: String {
        switch self {
        case .reminder: return "Reminders"
        case .calendarEvent: return "Calendar"
        case .shopping: return "Shopping"
        case .followUp: return "Follow-ups"
        }
    }

    var symbolName: String {
        switch self {
        case .reminder: return "checklist"
        case .calendarEvent: return "calendar"
        case .shopping: return "cart"
        case .followUp: return "arrow.turn.up.right"
        }
    }

    /// Case/whitespace-tolerant lookup used when parsing the AI's response.
    static func lenient(from raw: String) -> Bucket? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "reminder", "reminders", "task": return .reminder
        case "calendar", "calendar event", "calendarevent", "event": return .calendarEvent
        case "shopping", "shopping item", "shoppingitem", "buy": return .shopping
        case "followup", "follow-up", "follow up", "general follow-up", "general followup": return .followUp
        default: return nil
        }
    }
}

/// Whether — and how — a captured item's proactive check-in has gone.
enum CheckInStatus: String, Codable {
    /// Not yet surfaced to the user.
    case none
    /// Surfaced, but the user hasn't answered (e.g. dismissed without a tap).
    case asked
    /// User confirmed they actually handled it.
    case answeredYes
    /// User admitted they let it die.
    case answeredNo
}

/// A single captured brain-dump fragment, from the raw scattered-note state
/// through filing and (Pro) an eventual honesty check-in.
struct Item: Identifiable, Codable, Equatable {
    let id: UUID
    var rawText: String
    var createdAt: Date

    /// `nil` until filed — a `nil` bucket is what makes a note render as a
    /// loose, unfiled scrap on the capture screen.
    var bucket: Bucket?
    var wasAutoTriaged: Bool

    var extractedDate: Date?
    var extractedItemName: String?
    var extractedPersonName: String?

    var checkInStatus: CheckInStatus
    var checkInAskedAt: Date?
    var checkInAnsweredAt: Date?
    var checkInQuestion: String?

    init(
        id: UUID = UUID(),
        rawText: String,
        createdAt: Date = Date(),
        bucket: Bucket? = nil,
        wasAutoTriaged: Bool = false,
        extractedDate: Date? = nil,
        extractedItemName: String? = nil,
        extractedPersonName: String? = nil,
        checkInStatus: CheckInStatus = .none,
        checkInAskedAt: Date? = nil,
        checkInAnsweredAt: Date? = nil,
        checkInQuestion: String? = nil
    ) {
        self.id = id
        self.rawText = rawText
        self.createdAt = createdAt
        self.bucket = bucket
        self.wasAutoTriaged = wasAutoTriaged
        self.extractedDate = extractedDate
        self.extractedItemName = extractedItemName
        self.extractedPersonName = extractedPersonName
        self.checkInStatus = checkInStatus
        self.checkInAskedAt = checkInAskedAt
        self.checkInAnsweredAt = checkInAnsweredAt
        self.checkInQuestion = checkInQuestion
    }
}
