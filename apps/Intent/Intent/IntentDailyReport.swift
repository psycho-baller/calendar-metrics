//
//  IntentDailyReport.swift
//  Intent
//
//  Created by Codex on 2026-03-15.
//

import Foundation

enum IntentDailyReportError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case storageFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenAI API key in Settings before generating daily reports with AI."
        case .invalidResponse:
            return "The daily report response could not be parsed."
        case .storageFailed:
            return "The daily report could not be saved locally."
        }
    }
}

struct IntentDailyReportWindow: Equatable {
    let dayKey: String
    let startDate: Date
    let endDate: Date

    var title: String {
        "Daily report for \(Self.titleFormatter.string(from: startDate))"
    }

    private static let titleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

struct IntentDailyReportPayload: Codable, Equatable {
    let headline: String
    let overview: String
    let stats: [String]
    let whatWentWell: [String]
    let whatDidntGoWell: [String]
    let improvements: [String]
}

enum IntentDailyReportScheduler {
    static func mostRecentCompletedWindow(
        relativeTo now: Date,
        minutesAfterMidnight: Int,
        calendar: Calendar = .current
    ) -> IntentDailyReportWindow {
        let clampedMinutes = max(0, min(minutesAfterMidnight, 1_439))
        let dayStart = calendar.startOfDay(for: now)
        let scheduledToday = calendar.date(byAdding: .minute, value: clampedMinutes, to: dayStart) ?? dayStart
        let windowEnd = now >= scheduledToday
            ? scheduledToday
            : (calendar.date(byAdding: .day, value: -1, to: scheduledToday) ?? scheduledToday)
        let windowStart = calendar.date(byAdding: .day, value: -1, to: windowEnd) ?? windowEnd

        return IntentDailyReportWindow(
            dayKey: dayKey(for: windowStart, calendar: calendar),
            startDate: windowStart,
            endDate: windowEnd
        )
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

final class IntentDailyReportStore {
    static let shared = IntentDailyReportStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bundleDirectory = appSupportDirectory
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "studio.orbitlabs.Intent", isDirectory: true)
        self.fileURL = bundleDirectory.appendingPathComponent("daily-reports.json", isDirectory: false)
    }

    func load() -> [IntentGeneratedDailyReport] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([IntentGeneratedDailyReport].self, from: data)
                .sorted { $0.intervalStartMs > $1.intervalStartMs }
        } catch {
            return []
        }
    }

    func upsert(_ report: IntentGeneratedDailyReport) throws -> [IntentGeneratedDailyReport] {
        var reports = load()
        reports.removeAll { $0.dayKey == report.dayKey }
        reports.insert(report, at: 0)

        if reports.count > 180 {
            reports = Array(reports.prefix(180))
        }

        try persist(reports)
        return reports
    }

    private func persist(_ reports: [IntentGeneratedDailyReport]) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let data = try encoder.encode(reports)
        try data.write(to: fileURL, options: .atomic)
    }
}

enum IntentDailyReportFallbackBuilder {
    static func build(
        context: IntentDailyReportContext,
        window: IntentDailyReportWindow
    ) -> IntentDailyReportPayload {
        let strongestReviewedSession = context.sessions
            .filter { $0.existingReview != nil }
            .max { left, right in
                (left.existingReview?.numericMetric("focus") ?? 0) < (right.existingReview?.numericMetric("focus") ?? 0)
            }
        let weakestReviewedSession = context.sessions
            .filter { $0.existingReview != nil }
            .min { left, right in
                (left.existingReview?.numericMetric("focus") ?? 10) < (right.existingReview?.numericMetric("focus") ?? 10)
            }

        var stats = [String]()
        stats.append("\(context.totalSessions) session\(context.totalSessions == 1 ? "" : "s") logged across \(durationText(context.trackedDurationMs)).")
        stats.append("\(context.completedSessions) completed and \(context.reviewedSessions) reviewed.")
        if let averageFocus = context.averageFocus {
            stats.append(String(format: "Average focus landed at %.1f out of 10.", averageFocus))
        }
        if let averageAdherence = context.averageAdherence {
            stats.append(String(format: "Average adherence landed at %.1f out of 10.", averageAdherence))
        }
        if context.totalDistractions > 0 {
            stats.append("\(context.totalDistractions) distraction event\(context.totalDistractions == 1 ? "" : "s") were recorded in reviewed blocks.")
        }
        if let topCategory = context.topCategories.first {
            stats.append("\(topCategory.label.capitalized) showed up most often (\(topCategory.count) block\(topCategory.count == 1 ? "" : "s")).")
        }

        var whatWentWell = context.sessions
            .compactMap { session in
                session.existingReview?.whatWentWell.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        if let strongestReviewedSession {
            whatWentWell.insert(
                "\(strongestReviewedSession.displayTitle) was the cleanest block of the day\(focusSuffix(for: strongestReviewedSession)).",
                at: 0
            )
        }
        if whatWentWell.isEmpty, context.trackedDurationMs > 0 {
            whatWentWell = [
                "You kept a real ledger for the day instead of relying on memory alone.",
                context.reviewedSessions > 0
                    ? "You closed the loop on part of the day with explicit reviews, which makes tomorrow easier to adjust."
                    : "The raw session history is there; adding reviews tomorrow will make the report sharper."
            ]
        }

        var whatDidntGoWell = context.sessions
            .compactMap { session in
                session.existingReview?.whatDidntGoWell.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        if context.pendingReviews > 0 {
            whatDidntGoWell.append("\(context.pendingReviews) block\(context.pendingReviews == 1 ? "" : "s") still need review, so part of the day stayed blurry.")
        }
        if let weakestReviewedSession, weakestReviewedSession.id != strongestReviewedSession?.id {
            whatDidntGoWell.insert(
                "\(weakestReviewedSession.displayTitle) carried the weakest focus signal\(focusSuffix(for: weakestReviewedSession)).",
                at: 0
            )
        }
        if whatDidntGoWell.isEmpty {
            whatDidntGoWell = [
                "The recorded data is still thin on what went wrong, which usually means the reviews were too light or skipped."
            ]
        }

        var improvements = [String]()
        if context.pendingReviews > 0 {
            improvements.append("Close each block with a review before starting the next one so the day does not go soft in hindsight.")
        }
        if let averageAdherence = context.averageAdherence, averageAdherence < 6.5 {
            improvements.append("Shrink the first planned block tomorrow and make the success condition more explicit so adherence has a chance to recover.")
        }
        if context.totalDistractions > max(1, context.reviewedSessions) {
            improvements.append("Protect the first deep block from context switching. Fewer toggles will matter more than adding more hours.")
        }
        if let topCategory = context.topCategories.first {
            improvements.append("Front-load the highest-value \(topCategory.label) block earlier, while energy is still available.")
        }
        if improvements.isEmpty {
            improvements = [
                "Repeat the conditions behind the strongest block first tomorrow, then keep the review cadence tight enough to catch drift early."
            ]
        }

        let headline = headlineText(context: context)
        let overview = overviewText(context: context, window: window)

        return IntentDailyReportPayload(
            headline: headline,
            overview: overview,
            stats: Array(stats.prefix(5)),
            whatWentWell: Array(deduplicated(whatWentWell).prefix(4)),
            whatDidntGoWell: Array(deduplicated(whatDidntGoWell).prefix(4)),
            improvements: Array(deduplicated(improvements).prefix(4))
        )
    }

    private static func headlineText(context: IntentDailyReportContext) -> String {
        if context.totalSessions == 0 {
            return "No tracked work blocks landed inside this report window."
        }

        if let averageFocus = context.averageFocus, averageFocus >= 7 {
            return "The day held together better than average once you got into the work."
        }

        if context.pendingReviews > 0 {
            return "The day has enough signal to learn from, but too much of it is still unreviewed."
        }

        return "The day was tracked clearly enough to see where momentum held and where it slipped."
    }

    private static func overviewText(
        context: IntentDailyReportContext,
        window: IntentDailyReportWindow
    ) -> String {
        if context.totalSessions == 0 {
            return "Nothing was logged between \(timeText(window.startDate)) and \(timeText(window.endDate)), so this report has no work signal to summarize yet."
        }

        let categoryText = context.topCategories.first?.label.capitalized ?? "mixed work"
        let focusText = context.averageFocus.map { String(format: "%.1f", $0) } ?? "n/a"
        return "Between \(timeText(window.startDate)) and \(timeText(window.endDate)), you logged \(durationText(context.trackedDurationMs)) across \(context.totalSessions) session\(context.totalSessions == 1 ? "" : "s"). The strongest concentration of work was in \(categoryText), and the reviewed blocks averaged \(focusText) for focus."
    }

    private static func durationText(_ milliseconds: Int) -> String {
        guard milliseconds > 0 else {
            return "0m"
        }

        let totalMinutes = milliseconds / 60_000
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private static func focusSuffix(for session: IntentDailyReportSession) -> String {
        guard let focus = session.existingReview?.numericMetric("focus") else {
            return ""
        }
        return " (\(focus)/10 focus)"
    }

    private static func deduplicated(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { item in
            let normalized = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                return false
            }
            if seen.contains(normalized) {
                return false
            }
            seen.insert(normalized)
            return true
        }
    }
}

struct IntentDailyReportGenerationService {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o-mini"

    func generate(
        context: IntentDailyReportContext,
        window: IntentDailyReportWindow
    ) async throws -> IntentDailyReportPayload {
        guard let apiKey = IntentSecretStore.openAIAPIKey(), !apiKey.isEmpty else {
            throw IntentDailyReportError.missingAPIKey
        }

        let requestBody = try makeRequestBody(context: context, window: window)
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

        let chatResponse = try JSONDecoder().decode(IntentDailyReportOpenAIChatResponse.self, from: data)
        let rawContent = chatResponse.choices.first?.message.content ?? ""
        let trimmedContent = Self.cleanedJSON(rawContent)
        guard let jsonData = trimmedContent.data(using: .utf8) else {
            throw IntentDailyReportError.invalidResponse
        }

        return try JSONDecoder().decode(IntentDailyReportPayload.self, from: jsonData)
    }

    private func makeRequestBody(
        context: IntentDailyReportContext,
        window: IntentDailyReportWindow
    ) throws -> [String: Any] {
        let payload = IntentDailyReportPromptContext(
            windowStartISO8601: Self.iso8601Formatter.string(from: window.startDate),
            windowEndISO8601: Self.iso8601Formatter.string(from: window.endDate),
            context: context
        )
        let payloadData = try JSONEncoder().encode(payload)
        let payloadText = String(decoding: payloadData, as: UTF8.self)

        let systemPrompt = """
        You are a blunt, useful end-of-day reporting assistant for a work tracking app.

        Build a grounded report from the provided tracked sessions and review data.

        Rules:
        - Use only the supplied data.
        - Do not invent events, emotions, causes, or wins that are not supported.
        - Keep the report concrete and operational, not motivational.
        - Prefer causal observations over generic praise.
        - Return valid JSON only. No markdown fences.
        - Each array should contain 1 to 4 short items when possible. Use an empty array if the data is too thin.
        """

        let userPrompt = """
        Return JSON with this exact shape:
        {
          "headline": "string",
          "overview": "string",
          "stats": ["string"],
          "whatWentWell": ["string"],
          "whatDidntGoWell": ["string"],
          "improvements": ["string"]
        }

        Reporting window title: \(window.title)

        Context JSON:
        \(payloadText)
        """

        return [
            "model": model,
            "temperature": 0.2,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt,
                ],
                [
                    "role": "user",
                    "content": userPrompt,
                ],
            ],
        ]
    }

    private static func cleanedJSON(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else {
            return trimmed
        }

        return trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func errorMessage(from data: Data) -> String? {
        if let envelope = try? JSONDecoder().decode(IntentDailyReportOpenAIAPIErrorEnvelope.self, from: data) {
            return envelope.error.message
        }

        return String(data: data, encoding: .utf8)
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct IntentDailyReportPromptContext: Codable {
    let windowStartISO8601: String
    let windowEndISO8601: String
    let context: IntentDailyReportContext
}

private struct IntentDailyReportOpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct IntentDailyReportOpenAIAPIErrorEnvelope: Decodable {
    struct ErrorBody: Decodable {
        let message: String
    }

    let error: ErrorBody
}

private func durationText(_ milliseconds: Int) -> String {
    guard milliseconds > 0 else {
        return "0m"
    }

    let totalMinutes = milliseconds / 60_000
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }

    return "\(minutes)m"
}
