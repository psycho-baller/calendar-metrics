//
//  ContentView.swift
//  Intent
//
//  Created by Codex on 2026-03-10.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: IntentAppModel

    var body: some View {
        NavigationStack {
            Form {
                setupSection
                deviceSection
                statusSection
                sessionSection
                controlsSection
            }
            .formStyle(.grouped)
            .navigationTitle("Intent")
        }
        .frame(minWidth: 760, minHeight: 680)
        .sheet(
            isPresented: Binding(
                get: { model.activeReview != nil },
                set: { isPresented in
                    if !isPresented {
                        model.dismissReview()
                    }
                }
            )
        ) {
            if let reviewBinding = activeReviewBinding {
                ReviewSheetView(
                    context: reviewBinding,
                    isSubmitting: model.isSubmittingReview,
                    onSubmit: {
                        Task {
                            await model.submitActiveReview()
                        }
                    },
                    onDismiss: {
                        model.dismissReview()
                    }
                )
            } else {
                EmptyView()
            }
        }
        .task {
            model.start()
        }
    }

    private var setupSection: some View {
        Section("Connection") {
            TextField("Backend base URL", text: configBinding(\.backendBaseURL))

            SecureField("Setup key", text: configBinding(\.setupKey))

            TextField("Device name", text: configBinding(\.deviceName))
            TextField("Bundle ID", text: configBinding(\.bundleID))

            Toggle("Auto-start Raycast Focus", isOn: configBinding(\.autoStartFocus))
            Toggle("Auto-complete Raycast Focus", isOn: configBinding(\.autoCompleteFocus))
            Toggle("Auto-show review popup", isOn: configBinding(\.autoShowReview))

            TextField("Start shortcut name", text: configBinding(\.startShortcutName))
            TextField("Complete shortcut name", text: configBinding(\.completeShortcutName))

            HStack {
                Button(model.hasCompletedSetup ? "Re-run setup" : "Pair device") {
                    Task {
                        await model.bootstrap()
                    }
                }
                .disabled(
                    model.isBootstrapping ||
                    model.configuration.backendBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    model.configuration.setupKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                if model.hasCompletedSetup {
                    Button("Reset pairing", role: .destructive) {
                        model.resetPairing()
                    }
                }

                if model.isBootstrapping {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private var deviceSection: some View {
        Section("Device") {
            LabeledContent("Status") {
                Text(model.connectionStatus)
            }

            LabeledContent("Device ID") {
                Text(model.configuration.deviceId.isEmpty ? "Not paired" : model.configuration.deviceId)
                    .textSelection(.enabled)
                    .font(.footnote.monospaced())
            }

            LabeledContent("Pending reviews") {
                Text("\(model.pendingReviewsCount)")
            }

            if let lastSeenAt = model.deviceState?.device.lastSeenAt {
                LabeledContent("Last heartbeat") {
                    Text(Self.dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(lastSeenAt) / 1000)))
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Backend") {
            if let workspaceID = model.deviceState?.integration.togglWorkspaceId {
                LabeledContent("Toggl workspace") {
                    Text(String(workspaceID))
                }
            } else {
                LabeledContent("Toggl workspace") {
                    Text("Not configured")
                }
            }

            LabeledContent("Webhook") {
                Text(model.deviceState?.integration.togglWebhookUrl ?? "Not configured")
                    .textSelection(.enabled)
                    .font(.footnote)
            }

            if let validatedAt = model.deviceState?.integration.togglWebhookValidatedAt {
                LabeledContent("Webhook validated") {
                    Text(Self.dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(validatedAt) / 1000)))
                }
            }

            if let lastWebhookAt = model.deviceState?.integration.lastWebhookAt {
                LabeledContent("Last webhook event") {
                    Text(Self.dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(lastWebhookAt) / 1000)))
                }
            }

            if let lastAction = model.deviceState?.integration.lastWebhookAction,
               let entryID = model.deviceState?.integration.lastWebhookTimeEntryId {
                LabeledContent("Last Toggl event") {
                    Text("\(lastAction) / \(entryID)")
                }
            }

            if let lastSuccessfulPollAt = model.lastSuccessfulPollAt {
                LabeledContent("Last sync") {
                    Text(Self.dateFormatter.string(from: lastSuccessfulPollAt))
                }
            }

            if let lastError = model.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var sessionSection: some View {
        Section("Session") {
            if let session = model.deviceState?.activeSession {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.displayTitle)
                        .font(.headline)

                    Text(Self.sessionSummary(for: session))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !session.tags.isEmpty {
                        Text(session.tags.joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No running Toggl session detected.")
                    .foregroundStyle(.secondary)
            }

            if let pendingReview = model.deviceState?.pendingReview {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next review")
                        .font(.headline)
                    Text(pendingReview.displayTitle)
                    Text(Self.sessionSummary(for: pendingReview))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var controlsSection: some View {
        Section("Actions") {
            HStack {
                Button("Poll now") {
                    Task {
                        await model.pollOnce()
                    }
                }

                if model.deviceState?.pendingReview != nil {
                    Button("Open review") {
                        model.openPendingReview()
                    }
                }
            }
        }
    }

    private func configBinding<Value>(_ keyPath: WritableKeyPath<IntentLocalConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: {
                model.configuration[keyPath: keyPath]
            },
            set: { newValue in
                model.updateConfiguration { configuration in
                    configuration[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var activeReviewBinding: Binding<IntentReviewContext>? {
        guard model.activeReview != nil else {
            return nil
        }

        return Binding(
            get: {
                model.activeReview ?? IntentReviewContext(
                    session: IntentPendingReview(
                        id: "",
                        source: "toggl",
                        sourceTimeEntryId: "",
                        workspaceId: 0,
                        togglUserId: nil,
                        togglProjectId: nil,
                        togglTaskId: nil,
                        description: "",
                        tags: [],
                        billable: nil,
                        startTimeMs: 0,
                        stopTimeMs: nil,
                        durationMs: nil,
                        status: "completed",
                        focusStatus: "completed",
                        reviewStatus: "pending",
                        sourceUpdatedAt: 0,
                        createdAt: 0,
                        updatedAt: 0,
                        existingReview: nil
                    ),
                    draft: IntentReviewDraft(existingReview: nil)
                )
            },
            set: { newValue in
                model.activeReview = newValue
            }
        )
    }

    private static func sessionSummary(for session: IntentSessionSummary) -> String {
        let start = Date(timeIntervalSince1970: TimeInterval(session.startTimeMs) / 1000)
        let stop = session.stopTimeMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        let startText = shortTimeFormatter.string(from: start)
        let stopText = stop.map { shortTimeFormatter.string(from: $0) } ?? "Running"
        return "\(startText) - \(stopText)"
    }

    private static func sessionSummary(for session: IntentPendingReview) -> String {
        let start = Date(timeIntervalSince1970: TimeInterval(session.startTimeMs) / 1000)
        let stop = session.stopTimeMs.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        let startText = shortTimeFormatter.string(from: start)
        let stopText = stop.map { shortTimeFormatter.string(from: $0) } ?? "Running"
        return "\(startText) - \(stopText)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
