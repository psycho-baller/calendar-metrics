import Foundation

// MARK: - Template Inference Models

/// Represents an inferred template from AI analysis of existing daily notes
public struct InferredTemplate: Codable, Equatable {
    /// The raw template string with {{variable:format}} placeholders
    public let template: String

    /// List of detected variables in the template
    public let variables: [TemplateVariable]

    /// AI's confidence in the inferred template (0.0 - 1.0)
    public let confidence: Double

    /// Optional notes from the AI explaining its analysis
    public let notes: String?

    public init(template: String, variables: [TemplateVariable], confidence: Double, notes: String? = nil) {
        self.template = template
        self.variables = variables
        self.confidence = confidence
        self.notes = notes
    }
}

/// Represents a detected variable in the template
public struct TemplateVariable: Codable, Equatable {
    /// Variable name (e.g., "date", "weekday", "yesterday")
    public let name: String

    /// Format string if applicable (e.g., "YYYY-MM-DD", "full")
    public let format: String?

    /// Human-readable description of what this variable represents
    public let description: String?

    public init(name: String, format: String? = nil, description: String? = nil) {
        self.name = name
        self.format = format
        self.description = description
    }
}

/// A sample daily note used for template inference
public struct DailyNoteSample {
    public let date: Date
    public let content: String

    public init(date: Date, content: String) {
        self.date = date
        self.content = content
    }
}
