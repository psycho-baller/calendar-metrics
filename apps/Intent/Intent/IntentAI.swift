//
//  IntentAI.swift
//  Intent
//
//  Created by Codex on 2026-03-11.
//

import Foundation
import Security

enum IntentAIError: LocalizedError {
    case missingAPIKey
    case emptyInput
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenAI API key in Settings before using AI quick capture."
        case .emptyInput:
            return "Add some text before asking AI to extract the review."
        case .invalidResponse:
            return "The AI response could not be parsed into the review schema."
        case let .apiError(statusCode, message):
            return "AI request failed (\(statusCode)): \(message)"
        }
    }
}

enum IntentSecretStore {
    private static let service = Bundle.main.bundleIdentifier ?? "studio.orbitlabs.Intent"
    private static let openAIAPIKeyAccount = "openai.apiKey"

    static func openAIAPIKey() -> String? {
        string(for: openAIAPIKeyAccount)
    }

    static func setOpenAIAPIKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            deleteValue(for: openAIAPIKeyAccount)
            return
        }

        let data = Data(trimmed.utf8)
        let query = baseQuery(for: openAIAPIKeyAccount)

        let existingStatus = SecItemCopyMatching(query as CFDictionary, nil)
        switch existingStatus {
        case errSecSuccess:
            let updateStatus = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(updateStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to update the OpenAI API key in Keychain."]
                )
            }
        case errSecItemNotFound:
            var attributes = query
            attributes[kSecValueData as String] = data
            let addStatus = SecItemAdd(attributes as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(
                    domain: NSOSStatusErrorDomain,
                    code: Int(addStatus),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to save the OpenAI API key in Keychain."]
                )
            }
        default:
            throw NSError(
                domain: NSOSStatusErrorDomain,
                code: Int(existingStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to access the OpenAI API key in Keychain."]
            )
        }
    }

    private static func string(for account: String) -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    private static func deleteValue(for account: String) {
        let status = SecItemDelete(baseQuery(for: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return
        }
    }

    private static func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

struct IntentReviewAIPatch: Equatable {
    let taskCategory: String?
    let numericMetrics: [String: Int]
    let countMetrics: [String: Int]
    let booleanMetrics: [String: Bool]
    let whatWentWell: String?
    let whatDidntGoWell: String?
    let processingNotes: String?

    var isEmpty: Bool {
        taskCategory?.isEmpty != false &&
        numericMetrics.isEmpty &&
        countMetrics.isEmpty &&
        booleanMetrics.isEmpty &&
        (whatWentWell?.isEmpty != false) &&
        (whatDidntGoWell?.isEmpty != false)
    }

    var appliedLabels: [String] {
        var labels = [String]()

        if let taskCategory, !taskCategory.isEmpty {
            labels.append("Task category")
        }

        labels.append(contentsOf: numericMetrics.keys.sorted().map(IntentReviewCatalog.title(for:)))
        labels.append(contentsOf: countMetrics.keys.sorted().map(IntentReviewCatalog.title(for:)))

        if let whatWentWell, !whatWentWell.isEmpty {
            labels.append("What went well")
        }

        if let whatDidntGoWell, !whatDidntGoWell.isEmpty {
            labels.append("What didn't go well")
        }

        return labels
    }
}

struct IntentReviewExtractionService {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o-mini"

    func extract(
        from rawText: String,
        session: IntentPendingReview,
        taskCategorySuggestions: [String]
    ) async throws -> IntentReviewAIPatch {
        let input = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            throw IntentAIError.emptyInput
        }

        guard let apiKey = IntentSecretStore.openAIAPIKey(), !apiKey.isEmpty else {
            throw IntentAIError.missingAPIKey
        }

        let requestBody = try requestBody(
            input: input,
            session: session,
            taskCategorySuggestions: taskCategorySuggestions
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard statusCode == 200 else {
            let message = Self.errorMessage(from: data) ?? "Unknown API error."
            throw IntentAIError.apiError(statusCode: statusCode, message: message)
        }

        let chatResponse = try JSONDecoder().decode(IntentOpenAIChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content,
              let jsonData = content.data(using: .utf8)
        else {
            throw IntentAIError.invalidResponse
        }

        let parsed = try JSONDecoder().decode(IntentAIReviewExtractionResponse.self, from: jsonData)
        return parsed.toPatch()
    }

    private func requestBody(
        input: String,
        session: IntentPendingReview,
        taskCategorySuggestions: [String]
    ) throws -> [String: Any] {
        let userPrompt = """
        SESSION TITLE: \(session.displayTitle)
        SESSION TAGS: \(session.tags.isEmpty ? "(none)" : session.tags.joined(separator: ", "))
        SESSION DURATION MINUTES: \(session.durationMs.map { String(max(0, $0 / 60_000)) } ?? "unknown")

        EXISTING TASK CATEGORY SUGGESTIONS:
        \(taskCategorySuggestions.prefix(12).map { "- \($0)" }.joined(separator: "\n"))

        REFLECTION NOTE:
        \(input)
        """

        return [
            "model": model,
            "temperature": 0.2,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are a precision extraction agent for a work-session reflection tool.

                    Convert the user's freeform note into structured review data.

                    Rules:
                    - Only extract values grounded in the note and session context.
                    - Use integers from 0 to 10 for numeric metrics.
                    - Leave uncertain fields as null. Do not guess aggressively.
                    - Always include every metric key in numericMetrics and countMetrics. Use null when unknown.
                    - For taskCategory, prefer an existing suggestion when it clearly fits. Otherwise return a short lowercase label.
                    - Keep whatWentWell and whatDidntGoWell concise, concrete, and causal.
                    - Do not output markdown, bullets, or commentary outside the schema.

                    Metric guidance:
                    - mindfulness: present, aware, not autopilot
                    - discipline: stayed with the chosen task
                    - engagement: absorbed, interested, involved
                    - focus: sustained attention and low drift
                    - courage: moved toward uncomfortable or high-leverage work
                    - authenticity: honest, not performative, not avoidant
                    - purpose: connected to something meaningful or important
                    - energy: mental and physical energy available in the block
                    - communication: clarity and quality of communication work
                    - uniqueness: originality versus generic or repetitive work
                    - adherence: how closely the block matched the intended plan
                    - intentionality: deliberate rather than reactive use of time
                    - distractions: count only meaningful distractions or context switches
                    """
                ],
                [
                    "role": "user",
                    "content": userPrompt
                ],
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "intent_review_extraction",
                    "strict": true,
                    "schema": Self.responseSchema,
                ],
            ],
        ]
    }

    private static var responseSchema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "taskCategory": [
                    "type": ["string", "null"],
                ],
                "numericMetrics": [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": numericMetricProperties,
                    "required": numericMetricKeys,
                ],
                "countMetrics": [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": countMetricProperties,
                    "required": countMetricKeys,
                ],
                "whatWentWell": [
                    "type": ["string", "null"],
                ],
                "whatDidntGoWell": [
                    "type": ["string", "null"],
                ],
                "processingNotes": [
                    "type": ["string", "null"],
                ],
            ],
            "required": [
                "taskCategory",
                "numericMetrics",
                "countMetrics",
                "whatWentWell",
                "whatDidntGoWell",
                "processingNotes",
            ],
        ]
    }

    private static var numericMetricKeys: [String] {
        IntentReviewCatalog.numericMetricDefinitions.map(\.id)
    }

    private static var countMetricKeys: [String] {
        IntentReviewCatalog.countMetricDefinitions.map(\.id)
    }

    private static var numericMetricProperties: [String: Any] {
        var properties = [String: Any]()
        for metric in IntentReviewCatalog.numericMetricDefinitions {
            properties[metric.id] = [
                "type": ["integer", "null"],
                "minimum": 0,
                "maximum": 10,
            ]
        }
        return properties
    }

    private static var countMetricProperties: [String: Any] {
        var properties = [String: Any]()
        for metric in IntentReviewCatalog.countMetricDefinitions {
            properties[metric.id] = [
                "type": ["integer", "null"],
                "minimum": 0,
                "maximum": 25,
            ]
        }
        return properties
    }

    private static func errorMessage(from data: Data) -> String? {
        if let apiError = try? JSONDecoder().decode(IntentOpenAIAPIErrorEnvelope.self, from: data) {
            return apiError.error.message
        }

        return String(data: data, encoding: .utf8)
    }
}

private struct IntentAIReviewExtractionResponse: Decodable {
    let taskCategory: String?
    let numericMetrics: IntentAIReviewNumericMetrics
    let countMetrics: IntentAIReviewCountMetrics
    let whatWentWell: String?
    let whatDidntGoWell: String?
    let processingNotes: String?

    func toPatch() -> IntentReviewAIPatch {
        IntentReviewAIPatch(
            taskCategory: taskCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
            numericMetrics: numericMetrics.asDictionary,
            countMetrics: countMetrics.asDictionary,
            booleanMetrics: [:],
            whatWentWell: whatWentWell?.trimmingCharacters(in: .whitespacesAndNewlines),
            whatDidntGoWell: whatDidntGoWell?.trimmingCharacters(in: .whitespacesAndNewlines),
            processingNotes: processingNotes?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private struct IntentAIReviewNumericMetrics: Decodable {
    let mindfulness: Int?
    let discipline: Int?
    let engagement: Int?
    let focus: Int?
    let courage: Int?
    let authenticity: Int?
    let purpose: Int?
    let energy: Int?
    let communication: Int?
    let uniqueness: Int?
    let adherence: Int?
    let intentionality: Int?

    var asDictionary: [String: Int] {
        [
            "mindfulness": mindfulness,
            "discipline": discipline,
            "engagement": engagement,
            "focus": focus,
            "courage": courage,
            "authenticity": authenticity,
            "purpose": purpose,
            "energy": energy,
            "communication": communication,
            "uniqueness": uniqueness,
            "adherence": adherence,
            "intentionality": intentionality,
        ]
        .compactMapValues { $0 }
    }
}

private struct IntentAIReviewCountMetrics: Decodable {
    let distractions: Int?

    var asDictionary: [String: Int] {
        [
            "distractions": distractions,
        ]
        .compactMapValues { $0 }
    }
}

private struct IntentOpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct IntentOpenAIAPIErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let message: String
    }

    let error: ErrorBody
}
