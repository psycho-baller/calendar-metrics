//
//  IntentAppModel.swift
//  Intent
//
//  Created by Codex on 2026-03-10.
//

import AppKit
import Combine
import Foundation

@MainActor
final class IntentAppModel: ObservableObject {
    @Published var configuration: IntentLocalConfiguration {
        didSet {
            configuration.persist()
        }
    }

    @Published var deviceState: IntentDeviceState?
    @Published var activeReview: IntentReviewContext?
    @Published var isBootstrapping = false
    @Published var isSubmittingReview = false
    @Published var isPulling = false
    @Published var connectionStatus = "Needs setup"
    @Published var lastError: String?
    @Published var lastNotice: String?
    @Published var lastSuccessfulPollAt: Date?

    private var pollingTask: Task<Void, Never>?
    private var isPullInFlight = false
    private var startFocusInFlight = Set<String>()
    private var completeFocusInFlight = Set<String>()
    private var presentedReviewInFlight = Set<String>()
    private var startFocusRetryAfter = [String: Date]()
    private var completeFocusRetryAfter = [String: Date]()
    private var knownShortcutNames = Set<String>()
    private var lastShortcutRefreshAt: Date?
    private var unavailableShortcuts = Set<String>()

    private let pollIntervalSeconds: TimeInterval = 2
    private let shortcutRefreshIntervalSeconds: TimeInterval = 60

    init() {
        let configuration = IntentLocalConfiguration.load()
        self.configuration = configuration
        if configuration.isPaired {
            connectionStatus = "Ready"
        }
    }

    var hasCompletedSetup: Bool {
        configuration.isPaired
    }

    var currentSessionTitle: String {
        deviceState?.activeSession?.displayTitle ?? "No active session"
    }

    var pendingReviewsCount: Int {
        deviceState?.pendingReviewsCount ?? 0
    }

    func start() {
        guard pollingTask == nil, configuration.isPaired else {
            return
        }

        pollingTask = Task { [weak self] in
            guard let self else { return }
            await self.pollLoop()
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func updateConfiguration(_ update: (inout IntentLocalConfiguration) -> Void) {
        var next = configuration
        update(&next)
        configuration = next
        knownShortcutNames.removeAll()
        lastShortcutRefreshAt = nil
        unavailableShortcuts.removeAll()

        if next.isPaired {
            start()
        }
    }

    func bootstrap() async {
        guard !isBootstrapping else {
            return
        }

        isBootstrapping = true
        defer { isBootstrapping = false }

        do {
            let baseURL = try normalizedBackendBaseURL(from: configuration.backendBaseURL)
            if configuration.backendBaseURL != baseURL.absoluteString {
                updateConfiguration { configuration in
                    configuration.backendBaseURL = baseURL.absoluteString
                }
            }

            try await verifyBackend(baseURL: baseURL)

            let response: IntentBootstrapResponse = try await post(
                path: "/intent/bootstrap",
                body: IntentBootstrapRequest(
                    setupKey: configuration.setupKey,
                    deviceName: configuration.deviceName,
                    platform: "macos",
                    settings: deviceSettingsPayload
                )
            )

            updateConfiguration { configuration in
                configuration.deviceId = response.device.deviceId
                configuration.deviceSecret = response.device.deviceSecret
            }

            lastError = response.webhook.reason
            lastNotice = nil
            connectionStatus = response.webhook.configured ? "Connected" : "Paired"
            start()
            await pollOnce()
        } catch {
            lastNotice = nil
            lastError = displayMessage(for: error)
            connectionStatus = "Setup failed"
        }
    }

    func pollOnce() async {
        guard configuration.isPaired else {
            connectionStatus = "Needs setup"
            return
        }

        do {
            let response: IntentDevicePollEnvelope = try await post(
                path: "/intent/device/poll",
                body: IntentDevicePollRequest(
                    deviceId: configuration.deviceId,
                    deviceSecret: configuration.deviceSecret,
                    settings: deviceSettingsPayload
                )
            )

            deviceState = response.state
            lastSuccessfulPollAt = Date()
            connectionStatus = "Connected"
            if let lastWebhookError = response.state.integration.lastWebhookError,
               !lastWebhookError.isEmpty {
                lastError = lastWebhookError
            } else {
                lastError = nil
            }

            await handle(response.state)
        } catch {
            connectionStatus = "Disconnected"
            lastNotice = nil
            lastError = displayMessage(for: error)
        }
    }

    func pullNow() async {
        guard configuration.isPaired else {
            return
        }

        do {
            _ = try await performPull(showNotice: true)
            await pollOnce()
        } catch {
            lastNotice = nil
            lastError = displayMessage(for: error)
        }
    }

    func submitActiveReview() async {
        guard let activeReview, !isSubmittingReview else {
            return
        }

        isSubmittingReview = true
        defer { isSubmittingReview = false }

        do {
            let draft = activeReview.draft
            let _: IntentOKResponse = try await post(
                path: "/intent/device/review/submit",
                body: IntentSubmitReviewRequest(
                    deviceId: configuration.deviceId,
                    deviceSecret: configuration.deviceSecret,
                    sessionId: activeReview.session.id,
                    focusScore: draft.focusScore,
                    planAdherence: draft.planAdherence,
                    energy: draft.energy,
                    distraction: draft.distraction,
                    taskCategory: draft.taskCategory,
                    performanceGrade: draft.performanceGrade,
                    reflection: draft.reflection.isEmpty ? nil : draft.reflection,
                    nextIntent: draft.nextIntent.isEmpty ? nil : draft.nextIntent
                )
            )

            self.activeReview = nil
            await pollOnce()
        } catch {
            lastNotice = nil
            lastError = displayMessage(for: error)
        }
    }

    func dismissReview() {
        activeReview = nil
    }

    func openPendingReview() {
        guard let pendingReview = deviceState?.pendingReview else {
            return
        }

        activeReview = IntentReviewContext(
            session: pendingReview,
            draft: IntentReviewDraft(existingReview: pendingReview.existingReview)
        )
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func resetPairing() {
        stop()
        deviceState = nil
        activeReview = nil
        startFocusInFlight.removeAll()
        completeFocusInFlight.removeAll()
        presentedReviewInFlight.removeAll()
        startFocusRetryAfter.removeAll()
        completeFocusRetryAfter.removeAll()
        knownShortcutNames.removeAll()
        lastShortcutRefreshAt = nil
        unavailableShortcuts.removeAll()

        updateConfiguration { configuration in
            configuration.deviceId = ""
            configuration.deviceSecret = ""
        }

        connectionStatus = "Needs setup"
        lastError = nil
        lastNotice = nil
    }

    private var deviceSettingsPayload: IntentDeviceSettingsPayload {
        IntentDeviceSettingsPayload(
            autoStartFocus: configuration.autoStartFocus,
            autoCompleteFocus: configuration.autoCompleteFocus,
            autoShowReview: configuration.autoShowReview,
            startShortcutName: configuration.startShortcutName,
            completeShortcutName: configuration.completeShortcutName,
            bundleId: configuration.bundleID
        )
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            await pollOnce()

            do {
                try await Task.sleep(
                    nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000)
                )
            } catch {
                return
            }
        }
    }

    private func handle(_ state: IntentDeviceState) async {
        if let session = state.pendingFocusComplete {
            await maybeCompleteFocus(for: session)
        }

        if let session = state.pendingFocusStart {
            await maybeStartFocus(for: session)
        }

        if let pendingReview = state.pendingReview {
            await maybePresentReview(pendingReview)
        }
    }

    private func maybeStartFocus(for session: IntentSessionSummary) async {
        guard startFocusInFlight.insert(session.id).inserted else {
            return
        }

        defer { startFocusInFlight.remove(session.id) }

        if let retryAfter = startFocusRetryAfter[session.id], retryAfter > Date() {
            return
        }
        startFocusRetryAfter.removeValue(forKey: session.id)

        guard configuration.autoStartFocus else {
            return
        }

        let shortcutName = configuration.startShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            guard try await ensureShortcutExists(named: shortcutName) else {
                unavailableShortcuts.insert(shortcutName)
                lastNotice = nil
                lastError = "Shortcut \"\(shortcutName)\" was not found in Apple Shortcuts. Create it, change the configured name, or turn off Auto-start Raycast Focus."
                return
            }
        } catch {
            lastNotice = nil
            lastError = displayMessage(for: error)
            return
        }

        if unavailableShortcuts.contains(shortcutName) {
            return
        }

        do {
            try await runShortcut(named: configuration.startShortcutName)
            let _: IntentOKResponse = try await post(
                path: "/intent/device/focus/start",
                body: IntentSessionActionRequest(
                    deviceId: configuration.deviceId,
                    deviceSecret: configuration.deviceSecret,
                    sessionId: session.id
                )
            )
            startFocusRetryAfter.removeValue(forKey: session.id)
        } catch {
            startFocusRetryAfter[session.id] = Date().addingTimeInterval(30)
            if isMissingShortcutError(error) {
                unavailableShortcuts.insert(shortcutName)
            }
            lastNotice = nil
            lastError = displayMessage(for: error)
        }
    }

    private func maybeCompleteFocus(for session: IntentSessionSummary) async {
        guard completeFocusInFlight.insert(session.id).inserted else {
            return
        }

        defer { completeFocusInFlight.remove(session.id) }

        if let retryAfter = completeFocusRetryAfter[session.id], retryAfter > Date() {
            return
        }
        completeFocusRetryAfter.removeValue(forKey: session.id)

        guard configuration.autoCompleteFocus else {
            return
        }

        let shortcutName = configuration.completeShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            guard try await ensureShortcutExists(named: shortcutName) else {
                unavailableShortcuts.insert(shortcutName)
                lastNotice = nil
                lastError = "Shortcut \"\(shortcutName)\" was not found in Apple Shortcuts. Create it, change the configured name, or turn off Auto-complete Raycast Focus."
                return
            }
        } catch {
            lastNotice = nil
            lastError = displayMessage(for: error)
            return
        }

        if unavailableShortcuts.contains(shortcutName) {
            return
        }

        do {
            try await runShortcut(named: configuration.completeShortcutName)
            let _: IntentOKResponse = try await post(
                path: "/intent/device/focus/complete",
                body: IntentSessionActionRequest(
                    deviceId: configuration.deviceId,
                    deviceSecret: configuration.deviceSecret,
                    sessionId: session.id
                )
            )
            completeFocusRetryAfter.removeValue(forKey: session.id)
        } catch {
            completeFocusRetryAfter[session.id] = Date().addingTimeInterval(30)
            if isMissingShortcutError(error) {
                unavailableShortcuts.insert(shortcutName)
            }
            lastNotice = nil
            lastError = displayMessage(for: error)
        }
    }

    private func maybePresentReview(_ review: IntentPendingReview) async {
        if activeReview?.id == review.id {
            return
        }

        guard presentedReviewInFlight.insert(review.id).inserted else {
            return
        }

        defer { presentedReviewInFlight.remove(review.id) }

        activeReview = IntentReviewContext(
            session: review,
            draft: IntentReviewDraft(existingReview: review.existingReview)
        )

        NSApplication.shared.activate(ignoringOtherApps: true)

        do {
            let _: IntentOKResponse = try await post(
                path: "/intent/device/review/presented",
                body: IntentSessionActionRequest(
                    deviceId: configuration.deviceId,
                    deviceSecret: configuration.deviceSecret,
                    sessionId: review.id
                )
            )
        } catch {
            lastNotice = nil
            lastError = displayMessage(for: error)
        }
    }

    private func normalizedBackendBaseURL(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw URLError(.badURL)
        }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate), let host = components.host else {
            throw URLError(.badURL)
        }

        if host.hasSuffix(".convex.cloud") {
            let deploymentName = String(host.dropLast(".convex.cloud".count))
            components.host = "\(deploymentName).convex.site"
        }

        components.path = ""
        components.query = nil
        components.fragment = nil

        guard let normalizedURL = components.url else {
            throw URLError(.badURL)
        }

        return normalizedURL
    }

    private func url(for path: String) throws -> URL {
        let base = try normalizedBackendBaseURL(from: configuration.backendBaseURL)
        return URL(string: path, relativeTo: base)?.absoluteURL ?? base
    }

    private func verifyBackend(baseURL: URL) async throws {
        var request = URLRequest(url: URL(string: "/intent/health", relativeTo: baseURL)?.absoluteURL ?? baseURL)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            try validate(response: response, data: data)
        } catch {
            throw errorForBackendReachability(error, baseURL: baseURL)
        }
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        var request = URLRequest(url: try url(for: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ResponseBody.self, from: data)
    }

    private func errorForBackendReachability(_ error: Error, baseURL: URL) -> Error {
        let nsError = error as NSError

        if nsError.domain == "IntentAPI", nsError.code == 404 {
            return NSError(
                domain: "IntentSetup",
                code: 404,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Intent backend not found at \(baseURL.absoluteString). Use your Convex HTTP Actions URL ending in .convex.site."
                ]
            )
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotFindHost, .dnsLookupFailed:
                return NSError(
                    domain: "IntentSetup",
                    code: Int(urlError.errorCode),
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Could not resolve \(baseURL.host() ?? baseURL.absoluteString). Convex HTTP actions use the .convex.site host. If that host is already correct, this is a local DNS/network issue on the Mac."
                    ]
                )
            default:
                break
            }
        }

        return error
    }

    private func displayMessage(for error: Error) -> String {
        let nsError = error as NSError
        if !nsError.localizedDescription.isEmpty {
            return nsError.localizedDescription
        }

        return error.localizedDescription
    }

    private func isMissingShortcutError(_ error: Error) -> Bool {
        let message = displayMessage(for: error)
        return message.contains("was not found in Apple Shortcuts")
    }

    private func performPull(showNotice: Bool) async throws -> IntentPullResponse {
        guard !isPullInFlight else {
            return IntentPullResponse(
                ok: true,
                pulled: false,
                reason: showNotice ? "A Toggl sync is already in progress." : nil
            )
        }

        isPullInFlight = true
        if showNotice {
            isPulling = true
        }

        defer {
            isPullInFlight = false
            if showNotice {
                isPulling = false
            }
        }

        let response: IntentPullResponse = try await post(
            path: "/intent/device/pull",
            body: IntentDevicePollRequest(
                deviceId: configuration.deviceId,
                deviceSecret: configuration.deviceSecret,
                settings: deviceSettingsPayload
            )
        )

        if showNotice {
            lastNotice = response.reason
            lastError = nil
        }

        return response
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(IntentAPIError.self, from: data) {
                throw NSError(
                    domain: "IntentAPI",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: apiError.error]
                )
            }

            throw NSError(
                domain: "IntentAPI",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Request failed with status \(httpResponse.statusCode)."]
            )
        }
    }

    private func runShortcut(named name: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw NSError(
                domain: "IntentShortcut",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Shortcut name cannot be empty."]
            )
        }

        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", trimmedName]

            let errorPipe = Pipe()
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                throw NSError(
                    domain: "IntentShortcut",
                    code: Int(process.terminationStatus),
                    userInfo: [
                        NSLocalizedDescriptionKey: errorOutput?.isEmpty == false
                            ? Self.shortcutFailureMessage(from: errorOutput!, shortcutName: trimmedName)
                            : "Shortcut \(trimmedName) failed."
                    ]
                )
            }
        }.value
    }

    private func ensureShortcutExists(named name: String) async throws -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return false
        }

        if unavailableShortcuts.contains(trimmedName) {
            return false
        }

        let now = Date()
        if let lastShortcutRefreshAt,
           now.timeIntervalSince(lastShortcutRefreshAt) < shortcutRefreshIntervalSeconds,
           !knownShortcutNames.isEmpty {
            return knownShortcutNames.contains(trimmedName)
        }

        let shortcutNames = try await loadShortcutNames()
        knownShortcutNames = shortcutNames
        lastShortcutRefreshAt = now

        if shortcutNames.contains(trimmedName) {
            unavailableShortcuts.remove(trimmedName)
            return true
        }

        return false
    }

    private func loadShortcutNames() async throws -> Set<String> {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                throw NSError(
                    domain: "IntentShortcut",
                    code: Int(process.terminationStatus),
                    userInfo: [
                        NSLocalizedDescriptionKey: errorOutput?.isEmpty == false
                            ? errorOutput!
                            : "Failed to list Apple Shortcuts."
                    ]
                )
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            return Set(
                output
                    .split(whereSeparator: \.isNewline)
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }.value
    }

    nonisolated private static func shortcutFailureMessage(from output: String, shortcutName: String) -> String {
        if output.contains("Couldn't find shortcut") || output.contains("Couldn’t find shortcut") {
            return "Shortcut \"\(shortcutName)\" was not found in Apple Shortcuts. Create it or update the configured shortcut name."
        }

        return output
    }
}

private struct IntentOKResponse: Decodable {
    let ok: Bool
}
