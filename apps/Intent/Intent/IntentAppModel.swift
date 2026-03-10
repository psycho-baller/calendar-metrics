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
    @Published var connectionStatus = "Needs setup"
    @Published var lastError: String?
    @Published var lastSuccessfulPollAt: Date?

    private var pollingTask: Task<Void, Never>?
    private var startFocusInFlight = Set<String>()
    private var completeFocusInFlight = Set<String>()
    private var presentedReviewInFlight = Set<String>()

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
            connectionStatus = response.webhook.configured ? "Connected" : "Paired"
            start()
            await pollOnce()
        } catch {
            lastError = error.localizedDescription
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
            lastError = error.localizedDescription
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
            lastError = error.localizedDescription
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

        updateConfiguration { configuration in
            configuration.deviceId = ""
            configuration.deviceSecret = ""
        }

        connectionStatus = "Needs setup"
        lastError = nil
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
                try await Task.sleep(nanoseconds: 2_000_000_000)
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

        guard configuration.autoStartFocus else {
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
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func maybeCompleteFocus(for session: IntentSessionSummary) async {
        guard completeFocusInFlight.insert(session.id).inserted else {
            return
        }

        defer { completeFocusInFlight.remove(session.id) }

        guard configuration.autoCompleteFocus else {
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
        } catch {
            lastError = error.localizedDescription
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
            lastError = error.localizedDescription
        }
    }

    private func url(for path: String) throws -> URL {
        let trimmed = configuration.backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let base = URL(string: trimmed) else {
            throw URLError(.badURL)
        }

        return URL(string: path, relativeTo: base)?.absoluteURL ?? base
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
                            ? errorOutput!
                            : "Shortcut \(trimmedName) failed."
                    ]
                )
            }
        }.value
    }
}

private struct IntentOKResponse: Decodable {
    let ok: Bool
}
