import Foundation
import os

/// LLM service for the Share Extension.
/// Mirrors the main app's implementation for processing journal entries.
final class LLMService {
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    init() {}

    /// Processes a journal entry and returns structured AI insights.
    func processJournalEntry(text: String) async throws -> AIResponse {
        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }

        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        let systemPrompt = """
        You are an intelligent journaling assistant. Your job is to analyze the user's stream-of-consciousness entry and extract structured insights.

        Output valid JSON only matching this schema:
        {
          "summary": "2-3 sentences summarizing the entry",
          "insights": ["List of key realizations or patterns"],
          "action_items": ["List of actionable tasks mentioned or implied"],
          "tags": ["List of 3-5 relevant hashtags without # symbol"]
        }

        Only include information explicitly stated or directly implied. Do not fabricate.
        """

        let userPrompt = "Date: \(dateString)\n\nJournal Entry:\n\(text)"

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.3
        ]

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        if statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError(statusCode: statusCode, message: body)
        }

        struct OpenAIChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let chatResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let jsonString = chatResponse.choices.first?.message.content,
              let jsonData = jsonString.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }

        return try JSONDecoder().decode(AIResponse.self, from: jsonData)
    }
}

enum LLMError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Please add your OpenAI API Key in Settings."
        case .invalidResponse: return "The AI returned an invalid response."
        case .apiError(let code, let msg): return "AI Error (\(code)): \(msg)"
        }
    }
}
