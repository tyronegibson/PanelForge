import Foundation

/// Errors that ClaudeService can surface to the caller.
enum ClaudeServiceError: LocalizedError {
    case missingAPIKey
    case networkError(Error)
    case httpError(Int, String)
    case invalidResponse
    case parsingFailed(String)
    /// Claude declined the scene under the content rules in its system prompt.
    case refused(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key is not set. Please add it in Settings."
        case .networkError(let e):
            return "Network error: \(e.localizedDescription)"
        case .httpError(let code, let message):
            return "Claude API error \(code): \(message)"
        case .invalidResponse:
            return "Received an unexpected response from Claude."
        case .parsingFailed(let detail):
            return "Failed to parse Claude's response: \(detail)"
        case .refused(let reason):
            return PolicyViolation.refusedByModel(reason: reason).description
        }
    }
}

/// Thin DTO matching the JSON structure Claude returns for each panel.
private struct RawPanel: Decodable {
    let shot_type: String
    let action: String
    let mood: String
    let characters_present: [String]
}

/// The envelope Claude is asked to return: either panels, or a refusal with a reason.
private struct RawSceneResponse: Decodable {
    let refused: Bool?
    let reason: String?
    let panels: [RawPanel]?
}

/// Calls the Claude API to decompose a scene description into comic panels.
struct ClaudeService {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-6"

    private let systemPrompt = """
        You are a comic panel director. Given a scene description, break it into panels.

        Content rules (these override the scene description):
        - Every panel must be safe for work: no nudity, sexual content, or sexualized framing.
        - Never depict a child or minor in any sexual, romantic, or suggestive way.
        - If the scene cannot be drawn within these rules, refuse instead of softening it.

        Respond ONLY with a JSON object, no markdown fences, in exactly one of these shapes:
        {"refused": false, "panels": [ ... ]}
        {"refused": true, "reason": "<one short sentence>"}

        Each panel must have:
        - shot_type: "wide" | "medium" | "close_up" | "extreme_close_up"
        - action: short description of what is happening
        - mood: one word (e.g. tense, peaceful, dramatic)
        - characters_present: array of character names

        Return between 2 and 6 panels depending on scene complexity.
        """

    func parseScene(_ description: String) async throws -> [Panel] {
        guard let apiKey = KeychainService.load(forKey: KeychainService.claudeAPIKeyKey),
              !apiKey.isEmpty
        else {
            throw ClaudeServiceError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": description]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeServiceError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "(no body)"
            throw ClaudeServiceError.httpError(http.statusCode, body)
        }

        // Extract the text content from the Anthropic response envelope.
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let firstBlock = content.first,
            let text = firstBlock["text"] as? String
        else {
            throw ClaudeServiceError.invalidResponse
        }

        return try decodeRawPanels(from: text)
    }

    // MARK: - Private

    private func decodeRawPanels(from text: String) throws -> [Panel] {
        // Claude may wrap the JSON in markdown fences; strip them.
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .components(separatedBy: "\n")
                .dropFirst()        // remove opening fence
                .joined(separator: "\n")
            if let last = cleaned.lastIndex(of: "`") {
                let lineStart = cleaned.lineRange(for: last...last).lowerBound
                cleaned = String(cleaned[..<lineStart])
            }
        }

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw ClaudeServiceError.parsingFailed("Could not encode response text as UTF-8.")
        }

        let raws: [RawPanel]
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(RawSceneResponse.self, from: jsonData) {
            if envelope.refused == true {
                throw ClaudeServiceError.refused(envelope.reason ?? "No reason given.")
            }
            guard let panels = envelope.panels else {
                throw ClaudeServiceError.parsingFailed("Response had no panels and no refusal.")
            }
            raws = panels
        } else {
            // Older prompt format: a bare array of panels.
            do {
                raws = try decoder.decode([RawPanel].self, from: jsonData)
            } catch {
                throw ClaudeServiceError.parsingFailed(error.localizedDescription)
            }
        }

        return raws.map { raw in
            let shot = ShotType(rawValue: raw.shot_type) ?? .medium
            return Panel(
                prompt: "",          // filled in by PromptBuilder
                negativePrompt: "",  // filled in by PromptBuilder
                shotType: shot,
                action: raw.action,
                mood: raw.mood,
                charactersPresent: raw.characters_present
            )
        }
    }
}
