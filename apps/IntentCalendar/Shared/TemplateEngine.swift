import Foundation
import os

// MARK: - Template Engine

/// Engine for rendering templates with date-based variable substitution
public class TemplateEngine {

    /// Renders a template by substituting all {{variable:format}} placeholders
    /// - Parameters:
    ///   - template: The InferredTemplate containing the template string
    ///   - date: The target date for variable substitution
    /// - Returns: Fully rendered markdown string
    public static func render(_ template: InferredTemplate, for date: Date) -> String {
        return render(template.template, for: date)
    }

    /// Renders a raw template string by substituting all {{variable:format}} placeholders
    /// - Parameters:
    ///   - templateString: Raw template with {{variable}} placeholders
    ///   - date: The target date for variable substitution
    /// - Returns: Fully rendered markdown string
    public static func render(_ templateString: String, for date: Date) -> String {
        var result = templateString

        // Regex to match {{variable}} or {{variable:format}}
        let pattern = #"\{\{(\w+)(?::([^}]+))?\}\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            Logger.template.error("Failed to compile template regex")
            return templateString
        }

        let range = NSRange(templateString.startIndex..., in: templateString)
        let matches = regex.matches(in: templateString, range: range)

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let variableRange = Range(match.range(at: 1), in: templateString) else { continue }
            let variableName = String(templateString[variableRange])

            var format: String? = nil
            if match.numberOfRanges > 2, let formatRange = Range(match.range(at: 2), in: templateString) {
                format = String(templateString[formatRange])
            }

            let replacement = substituteVariable(name: variableName, format: format, for: date)

            if let fullRange = Range(match.range, in: result) {
                result.replaceSubrange(fullRange, with: replacement)
            }
        }

        return result
    }

    // MARK: - Variable Substitution

    private static func substituteVariable(name: String, format: String?, for date: Date) -> String {
        let calendar = Calendar.current

        switch name.lowercased() {
        case "date":
            return formatDate(date, format: format ?? "yyyy-MM-dd")

        case "weekday":
            return weekdayName(for: date, short: format == "short")

        case "weekday_short":
            return weekdayName(for: date, short: true)

        case "yesterday":
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: date) {
                return formatDate(yesterday, format: format ?? "yyyy-MM-dd")
            }
            return ""

        case "tomorrow":
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
                return formatDate(tomorrow, format: format ?? "yyyy-MM-dd")
            }
            return ""

        case "week_number", "weeknumber":
            return String(calendar.component(.weekOfYear, from: date))

        case "year":
            if let yearFormat = format, yearFormat.lowercased() == "yy" {
                return formatDate(date, format: "yy")
            }
            return String(calendar.component(.year, from: date))

        case "month":
            return monthName(for: date, short: format == "short")

        case "month_short":
            return monthName(for: date, short: true)

        case "month_number":
            return String(calendar.component(.month, from: date))

        case "day":
            return String(calendar.component(.day, from: date))

        case "time":
            return formatDate(date, format: format ?? "HH:mm")

        default:
            Logger.template.warning("Unknown template variable: \(name)")
            return "{{\(name)\(format.map { ":\($0)" } ?? "")}}"
        }
    }

    // MARK: - Formatting Helpers

    private static func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        // Convert common formats to DateFormatter format
        formatter.dateFormat = convertToDateFormat(format)
        return formatter.string(from: date)
    }

    /// Converts common template format strings to DateFormatter format strings
    private static func convertToDateFormat(_ format: String) -> String {
        var result = format

        // Common conversions (case-sensitive)
        result = result.replacingOccurrences(of: "YYYY", with: "yyyy")
        result = result.replacingOccurrences(of: "YY", with: "yy")
        result = result.replacingOccurrences(of: "DD", with: "dd")
        result = result.replacingOccurrences(of: "D", with: "d")

        return result
    }

    private static func weekdayName(for date: Date, short: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = short ? "EEE" : "EEEE"
        return formatter.string(from: date)
    }

    private static func monthName(for date: Date, short: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = short ? "MMM" : "MMMM"
        return formatter.string(from: date)
    }
}

// MARK: - Logger Extension

extension Logger {
    static let template = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Ignite", category: "Template")
}
