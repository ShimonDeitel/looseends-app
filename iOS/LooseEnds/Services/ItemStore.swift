import Foundation

/// UserDefaults-backed persistence for every captured item. Loose Ends has
/// no account and no server-side store — this is the entire data layer,
/// on-device only.
@MainActor
final class ItemStore: ObservableObject {
    @Published private(set) var items: [Item] = []

    private let defaults: UserDefaults
    private let itemsKey = "looseends.items.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    // MARK: - Capture / mutation

    @discardableResult
    func capture(_ rawText: String) -> Item {
        let item = Item(rawText: rawText)
        items.append(item)
        persist()
        return item
    }

    func file(itemID: UUID, bucket: Bucket, result: TriageResult? = nil, autoTriaged: Bool) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].bucket = bucket
        items[index].wasAutoTriaged = autoTriaged
        if let result {
            items[index].extractedItemName = result.itemName
            items[index].extractedPersonName = result.personName
            items[index].extractedDate = result.date
        }
        persist()
    }

    /// Marks an item as surfaced for a check-in. The question text itself
    /// arrives slightly later (from the AI proxy, or a client-built
    /// fallback) via `setCheckInQuestion`, so this can be called the moment
    /// an item is queued, before that text is ready.
    func markCheckInAsked(itemID: UUID, at date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].checkInStatus = .asked
        items[index].checkInAskedAt = date
        persist()
    }

    func setCheckInQuestion(itemID: UUID, question: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].checkInQuestion = question
        persist()
    }

    func answerCheckIn(itemID: UUID, handled: Bool, at date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].checkInStatus = handled ? .answeredYes : .answeredNo
        items[index].checkInAnsweredAt = date
        persist()
    }

    func removeItem(_ itemID: UUID) {
        items.removeAll { $0.id == itemID }
        persist()
    }

    func resetAll() {
        items = []
        persist()
    }

    // MARK: - Derived

    var unfiledItems: [Item] {
        items.filter { $0.bucket == nil }
    }

    func items(in bucket: Bucket) -> [Item] {
        items.filter { $0.bucket == bucket }
    }

    func count(in bucket: Bucket) -> Int {
        items.lazy.filter { $0.bucket == bucket }.count
    }

    var honestyStats: HonestyStats {
        HonestyEngine.stats(for: items)
    }

    func dueCheckIns(asOf date: Date = Date()) -> [Item] {
        CheckInScheduler.itemsDueForCheckIn(items: items, asOf: date)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: itemsKey),
              let decoded = try? JSONDecoder().decode([Item].self, from: data)
        else { return }
        items = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: itemsKey)
    }
}
