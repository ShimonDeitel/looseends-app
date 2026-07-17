import Foundation

/// Client for the shared, keyless AI proxy. Two jobs: triage a raw captured
/// fragment into a bucket + structured fields, and write the plain-language
/// honesty check-in question for one stored item. Every failure path is
/// handled by the caller with a graceful fallback — this feature must never
/// crash the app or leave a fragment stuck in limbo.
final class AIProxyClient {
    static let shared = AIProxyClient()

    private let endpoint = URL(string: "https://apps-ai-proxy.s0533495227.workers.dev/text")!

    enum ProxyError: Error, LocalizedError {
        case network
        case badResponse
        case empty

        var errorDescription: String? {
            switch self {
            case .network:
                return "Couldn't reach the sorting service. Check your connection and try again."
            case .badResponse:
                return "The sorting service returned something unexpected."
            case .empty:
                return "The sorting service came back empty."
            }
        }
    }

    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatRequestBody: Codable {
        let messages: [ChatMessage]
    }

    private struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }

    private static let triageSystemPrompt = """
    You are Loose Ends' triage engine for a scattered-thoughts capture app \
    used by people who need help offloading mental clutter, often with ADHD. \
    You will be given one raw, unstructured sentence or fragment the user \
    just typed or spoke, plus a reference date/time. Classify it into \
    exactly one bucket: "reminder" (a task to do with no specific external \
    event), "calendar" (a specific appointment or event, usually with a \
    time), "shopping" (something to buy), or "followup" (anything vague, a \
    person to follow up with, or unclear). If explicitly present or clearly \
    implied by the reference date, extract a date/time in ISO 8601 \
    (e.g. 2026-07-18T15:00:00), a short item name (what needs doing or \
    buying), and a person's name if one is mentioned. Reply with ONLY a \
    single JSON object, no markdown, no explanation, exactly these keys: \
    {"bucket":"reminder|calendar|shopping|followup","itemName":string or \
    null,"personName":string or null,"date":string or null}. Never invent a \
    detail that isn't stated or clearly implied.
    """

    private static let checkInSystemPrompt = """
    You write short, direct, plain-language honesty check-in questions for \
    Loose Ends, an app that follows up on things a user previously said \
    they needed to do. Given one previously captured raw thought and any \
    extracted details, write exactly one short, direct question asking \
    whether the user actually did or handled it, addressed to them in \
    second person, ending in a question mark. No preamble, no markdown, no \
    quotation marks around the whole thing, one sentence only.
    """

    /// Classifies a raw captured fragment. Always resolves — even the
    /// "success" case may have fallen back to a default Follow-up
    /// classification if the model's reply couldn't be understood.
    func triage(rawText: String, referenceDate: Date = Date()) async -> Result<TriageResult, ProxyError> {
        let isoFormatter = ISO8601DateFormatter()
        let userPrompt = "Reference date/time: \(isoFormatter.string(from: referenceDate))\nText: \"\(rawText)\""

        switch await send(system: Self.triageSystemPrompt, user: userPrompt) {
        case .success(let content):
            return .success(TriageParser.parse(content))
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Generates the plain-language yes/no check-in question for one item.
    func checkInQuestion(for item: Item) async -> Result<String, ProxyError> {
        var lines = ["Captured thought: \"\(item.rawText)\""]
        if let itemName = item.extractedItemName { lines.append("Extracted item: \(itemName)") }
        if let personName = item.extractedPersonName { lines.append("Extracted person: \(personName)") }
        if let bucket = item.bucket { lines.append("Bucket: \(bucket.rawValue)") }
        let userPrompt = lines.joined(separator: "\n")

        return await send(system: Self.checkInSystemPrompt, user: userPrompt)
    }

    // MARK: - Networking

    private func send(system: String, user: String) async -> Result<String, ProxyError> {
        let body = ChatRequestBody(messages: [
            ChatMessage(role: "system", content: system),
            ChatMessage(role: "user", content: user)
        ])

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return .failure(.badResponse)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .failure(.badResponse)
            }
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !content.isEmpty
            else {
                return .failure(.empty)
            }
            return .success(content)
        } catch is DecodingError {
            return .failure(.badResponse)
        } catch {
            return .failure(.network)
        }
    }
}
