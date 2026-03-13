import Foundation

// MARK: - AI Response Models

struct PlannerEnvelope: Codable {
    let response: PlannerResponse
}

/// Response from template population AI analysis
public struct TemplatePopulationResponse: Codable {
    /// List of updates to apply to the daily note
    public let updates: [TemplateUpdate]

    /// Brief summary for logging/debugging
    public let processingNotes: String?

    enum CodingKeys: String, CodingKey {
        case updates
        case processingNotes = "processing_notes"
    }
}

/// Represents a single update to a section of the daily note.
public struct TemplateUpdate: Codable, Equatable {
    /// The exact heading or field name (e.g., "## Things I Learned", "Sleep Hours", "Mood")
    public let field: String

    /// The value to insert. For text sections, this is the content to append.
    /// For metrics, this is the value (number as string). null if nothing relevant in transcript.
    public let value: String?

    /// The type of update: "append" (add to existing), "replace" (overwrite), or "metric" (insert number)
    public let updateType: UpdateType

    public enum UpdateType: String, Codable {
        case append    // Add content to section (e.g., bullet points)
        case replace   // Overwrite section content
        case metric    // Insert a single value (number, toggle, etc.)
    }
}

/// Legacy response for backward compatibility (simple insight extraction)
public struct AIResponse: Codable {
    public let summary: String
    public let insights: [String]
    public let actionItems: [String]
    public let tags: [String]

    enum CodingKeys: String, CodingKey {
        case summary
        case insights
        case actionItems = "action_items"
        case tags
    }
}
