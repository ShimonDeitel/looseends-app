import Foundation

/// The result of triaging one raw captured fragment, whether from the AI
/// proxy's JSON-in-text response or (in the failure/fallback path) a plain
/// default. `bucket` is always non-nil so a triage result can always file
/// an item — it just may carry no extracted detail.
struct TriageResult: Equatable {
    let bucket: Bucket
    let itemName: String?
    let personName: String?
    let date: Date?
}

/// Lenient parser for the AI proxy's triage response. The model is asked to
/// reply with a single JSON object, but real-world responses sometimes wrap
/// it in markdown fences, add a stray sentence, omit fields, or occasionally
/// fail to produce valid JSON at all. This parser tolerates all of that and
/// — critically — never throws or returns nil: a fragment that can't be
/// understood is filed as a bare Follow-up rather than silently dropped.
enum TriageParser {
    static let fallback = TriageResult(bucket: .followUp, itemName: nil, personName: nil, date: nil)

    static func parse(_ raw: String) -> TriageResult {
        guard let object = extractJSONObject(from: raw) else { return fallback }

        let bucketRaw = (object["bucket"] as? String) ?? ""
        let bucket = Bucket.lenient(from: bucketRaw) ?? .followUp

        let itemName = nonEmptyString(object["itemName"] ?? object["item"])
        let personName = nonEmptyString(object["personName"] ?? object["person"])
        let dateString = nonEmptyString(object["date"] ?? object["dateTime"])
        let date = dateString.flatMap(parseDate)

        return TriageResult(bucket: bucket, itemName: itemName, personName: personName, date: date)
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased() == "null" { return nil }
        return trimmed
    }

    /// Locates the outermost `{...}` span in the raw text and attempts to
    /// decode it as a JSON object, tolerating a markdown fence or stray
    /// prose around it. Returns `nil` on any failure.
    private static func extractJSONObject(from raw: String) -> [String: Any]? {
        guard let firstBrace = raw.firstIndex(of: "{"),
              let lastBrace = raw.lastIndex(of: "}"),
              firstBrace < lastBrace
        else { return nil }

        let jsonSubstring = raw[firstBrace...lastBrace]
        guard let data = jsonSubstring.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func parseDate(_ string: String) -> Date? {
        let isoWithFraction = ISO8601DateFormatter()
        isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFraction.date(from: string) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
