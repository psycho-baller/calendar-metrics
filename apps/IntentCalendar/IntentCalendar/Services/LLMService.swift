import Foundation

enum LLMError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenAI API key in Settings before using AI planning."
        case .invalidResponse:
            return "The AI response could not be parsed."
        case let .apiError(statusCode, message):
            return "AI request failed (\(statusCode)): \(message)"
        }
    }
}

final class LLMService: ObservableObject {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    func planDay(
        snapshot: PlanningContextSnapshot,
        model: PlannerModel
    ) async throws -> PlannerResponse {
        guard let apiKey = KeychainManager.shared.getAPIKey(), !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }

        let snapshotData = try JSONEncoder().encode(snapshot)
        let snapshotJSON = String(decoding: snapshotData, as: UTF8.self)

        let systemPrompt = """
        You are IntentCalendar, a concise day-planning assistant.

        Your job:
        1. Read the planning windows, fixed commitments, optional Obsidian context, and prior conversation.
        2. Either ask brief clarification questions if the plan still has important gaps, or return a complete proposed schedule.

        Rules:
        - Ask questions only when necessary to avoid a weak schedule.
        - If you ask questions, keep it to 1 to 3 short questions.
        - If you propose a schedule, every block must reference a provided planning window by exact windowID.
        - Proposed start and end times must be in 24-hour HH:mm local time.
        - Respect existing fixed commitments.
        - Use the Obsidian context only as supporting evidence, never as a reason to ignore explicit user instructions.
        - Keep the summary short and practical.
        """

        let userPrompt = """
        Build the next IntentCalendar response from this snapshot.

        \(snapshotJSON)
        """

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "outcome": [
                    "type": "string",
                    "enum": ["questions", "plan"]
                ],
                "summary": ["type": "string"],
                "questions": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "prompt": ["type": "string"],
                            "rationale": ["type": ["string", "null"]]
                        ],
                        "required": ["id", "prompt", "rationale"]
                    ]
                ],
                "plannedBlocks": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "title": ["type": "string"],
                            "windowID": ["type": "string"],
                            "startLocalTime": ["type": "string"],
                            "endLocalTime": ["type": "string"],
                            "detail": ["type": ["string", "null"]],
                            "rationale": ["type": ["string", "null"]]
                        ],
                        "required": ["id", "title", "windowID", "startLocalTime", "endLocalTime", "detail", "rationale"]
                    ]
                ]
            ],
            "required": ["outcome", "summary", "questions", "plannedBlocks"]
        ]

        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "input": [
                [
                    "role": "system",
                    "content": [
                        [
                            "type": "input_text",
                            "text": systemPrompt
                        ]
                    ]
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": userPrompt
                        ]
                    ]
                ]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "planner_response",
                    "schema": schema,
                    "strict": true
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown API error."
            throw LLMError.apiError(statusCode: statusCode, message: body)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)

        let rawJSON: String
        if let outputText = decoded.outputText, !outputText.isEmpty {
            rawJSON = outputText
        } else if let contentText = decoded.flattenedText {
            rawJSON = contentText
        } else {
            throw LLMError.invalidResponse
        }

        guard let jsonData = rawJSON.data(using: .utf8) else {
            throw LLMError.invalidResponse
        }

        return try JSONDecoder().decode(PlannerResponse.self, from: jsonData)
    }

    func processJournalEntry(text: String) async throws -> AIResponse {
        let summary = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortSummary = summary.isEmpty ? "No text provided." : String(summary.prefix(220))
        return AIResponse(summary: shortSummary, insights: [], actionItems: [], tags: [])
    }

    func populateTemplate(transcript: String, existingNote: String, date: Date = Date()) async throws -> TemplatePopulationResponse {
        TemplatePopulationResponse(updates: [], processingNotes: "Compatibility shim for legacy journal flows.")
    }

    func inferTemplate(from samples: [DailyNoteSample]) async throws -> InferredTemplate {
        InferredTemplate(
            template: samples.first?.content ?? "",
            variables: [],
            confidence: 0.0,
            notes: "IntentCalendar does not infer templates from daily notes in v1."
        )
    }
}

private struct OpenAIResponsesResponse: Decodable {
    struct OutputItem: Decodable {
        struct Content: Decodable {
            let text: String?
        }

        let content: [Content]?
    }

    let outputText: String?
    let output: [OutputItem]?

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }

    var flattenedText: String? {
        output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n")
    }
}
