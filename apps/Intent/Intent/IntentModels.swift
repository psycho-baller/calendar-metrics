//
//  IntentModels.swift
//  Intent
//
//  Created by Codex on 2026-03-10.
//

import Foundation

struct IntentLocalConfiguration: Codable, Equatable {
    var backendBaseURL = ""
    var setupKey = ""
    var deviceName = Host.current().localizedName ?? "Intent Mac"
    var deviceId = ""
    var deviceSecret = ""
    var autoStartFocus = true
    var autoCompleteFocus = true
    var autoShowReview = true
    var startShortcutName = "Start Focus Session"
    var completeShortcutName = "Complete Focus Session"
    var bundleID = Bundle.main.bundleIdentifier ?? "studio.orbitlabs.Intent"

    var isPaired: Bool {
        !backendBaseURL.isEmpty && !deviceId.isEmpty && !deviceSecret.isEmpty
    }

    static let storageKey = "intent.local.configuration"

    static func load() -> IntentLocalConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(IntentLocalConfiguration.self, from: data)
        else {
            return IntentLocalConfiguration()
        }

        return decoded
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }

        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

struct IntentBootstrapRequest: Encodable {
    let setupKey: String
    let deviceName: String
    let platform: String
    let settings: IntentDeviceSettingsPayload
}

struct IntentDeviceSettingsPayload: Encodable {
    let autoStartFocus: Bool
    let autoCompleteFocus: Bool
    let autoShowReview: Bool
    let startShortcutName: String
    let completeShortcutName: String
    let bundleId: String
}

struct IntentDevicePollRequest: Encodable {
    let deviceId: String
    let deviceSecret: String
    let settings: IntentDeviceSettingsPayload
}

struct IntentSessionActionRequest: Encodable {
    let deviceId: String
    let deviceSecret: String
    let sessionId: String
}

struct IntentSubmitReviewRequest: Encodable {
    let deviceId: String
    let deviceSecret: String
    let sessionId: String
    let numericMetrics: [String: Int]
    let countMetrics: [String: Int]
    let booleanMetrics: [String: Bool]
    let taskCategory: String
    let whatWentWell: String?
    let whatDidntGoWell: String?
}

struct IntentBootstrapResponse: Decodable {
    let ok: Bool
    let device: IntentRegisteredDevice
    let integration: IntentIntegrationState
    let webhook: IntentWebhookStatus
}

struct IntentRegisteredDevice: Decodable {
    let deviceId: String
    let deviceSecret: String
    let isDefault: Bool
}

struct IntentWebhookStatus: Decodable {
    let configured: Bool
    let reason: String?
    let workspaceId: Int?
    let callbackUrl: String?
    let subscriptionId: Int?
    let validatedAt: Int?
}

struct IntentDevicePollEnvelope: Decodable {
    let ok: Bool
    let state: IntentDeviceState
}

struct IntentPullResponse: Decodable {
    let ok: Bool
    let pulled: Bool
    let reason: String?
}

struct IntentDeviceState: Decodable {
    let device: IntentDeviceInfo
    let integration: IntentIntegrationState
    let activeSession: IntentSessionSummary?
    let pendingFocusStart: IntentSessionSummary?
    let pendingFocusComplete: IntentSessionSummary?
    let pendingReview: IntentPendingReview?
    let pendingReviewsCount: Int
    let recentSessions: [IntentDashboardSession]
}

struct IntentDeviceInfo: Decodable {
    let id: String
    let name: String
    let platform: String
    let isDefault: Bool
    let autoStartFocus: Bool
    let autoCompleteFocus: Bool
    let autoShowReview: Bool
    let startShortcutName: String?
    let completeShortcutName: String?
    let lastSeenAt: Int?
}

struct IntentIntegrationState: Decodable {
    let defaultDeviceId: String?
    let togglWorkspaceId: Int?
    let togglWebhookSubscriptionId: Int?
    let togglWebhookUrl: String?
    let togglWebhookValidatedAt: Int?
    let lastWebhookAt: Int?
    let lastWebhookAction: String?
    let lastWebhookTimeEntryId: String?
    let lastWebhookError: String?
}

struct IntentSessionSummary: Decodable, Identifiable, Equatable {
    let id: String
    let source: String
    let sourceTimeEntryId: String
    let workspaceId: Int
    let togglUserId: Int?
    let togglProjectId: Int?
    let togglTaskId: Int?
    let description: String
    let tags: [String]
    let billable: Bool?
    let startTimeMs: Int
    let stopTimeMs: Int?
    let durationMs: Int?
    let status: String
    let focusStatus: String
    let reviewStatus: String
    let sourceUpdatedAt: Int
    let createdAt: Int
    let updatedAt: Int

    var displayTitle: String {
        description.isEmpty ? "Untitled session" : description
    }
}

struct IntentExistingReview: Decodable, Equatable {
    let numericMetrics: [String: Int]
    let countMetrics: [String: Int]
    let booleanMetrics: [String: Bool]
    let taskCategory: String
    let whatWentWell: String
    let whatDidntGoWell: String

    func numericMetric(_ key: String) -> Int? {
        numericMetrics[key]
    }

    func countMetric(_ key: String) -> Int? {
        countMetrics[key]
    }
}

struct IntentPendingReview: Decodable, Identifiable, Equatable {
    let id: String
    let source: String
    let sourceTimeEntryId: String
    let workspaceId: Int
    let togglUserId: Int?
    let togglProjectId: Int?
    let togglTaskId: Int?
    let description: String
    let tags: [String]
    let billable: Bool?
    let startTimeMs: Int
    let stopTimeMs: Int?
    let durationMs: Int?
    let status: String
    let focusStatus: String
    let reviewStatus: String
    let sourceUpdatedAt: Int
    let createdAt: Int
    let updatedAt: Int
    let existingReview: IntentExistingReview?

    var displayTitle: String {
        description.isEmpty ? "Untitled session" : description
    }
}

struct IntentDashboardSession: Decodable, Identifiable, Equatable {
    let id: String
    let source: String
    let sourceTimeEntryId: String
    let workspaceId: Int
    let togglUserId: Int?
    let togglProjectId: Int?
    let togglTaskId: Int?
    let description: String
    let tags: [String]
    let billable: Bool?
    let startTimeMs: Int
    let stopTimeMs: Int?
    let durationMs: Int?
    let status: String
    let focusStatus: String
    let reviewStatus: String
    let sourceUpdatedAt: Int
    let createdAt: Int
    let updatedAt: Int
    let existingReview: IntentExistingReview?

    var displayTitle: String {
        description.isEmpty ? "Untitled session" : description
    }
}

struct IntentReviewDraft: Equatable {
    var numericMetrics = IntentReviewCatalog.defaultNumericMetrics
    var countMetrics = IntentReviewCatalog.defaultCountMetrics
    var booleanMetrics = [String: Bool]()
    var taskCategory = IntentReviewCatalog.defaultTaskCategory
    var whatWentWell = ""
    var whatDidntGoWell = ""

    init(existingReview: IntentExistingReview?) {
        guard let existingReview else {
            return
        }

        taskCategory = existingReview.taskCategory
        numericMetrics.merge(existingReview.numericMetrics) { _, new in new }
        countMetrics.merge(existingReview.countMetrics) { _, new in new }
        booleanMetrics = existingReview.booleanMetrics
        whatWentWell = existingReview.whatWentWell
        whatDidntGoWell = existingReview.whatDidntGoWell
    }

    func numericMetricValue(for key: String) -> Int {
        numericMetrics[key] ?? IntentReviewCatalog.defaultNumericValue
    }

    mutating func setNumericMetricValue(_ value: Int, for key: String) {
        numericMetrics[key] = min(10, max(0, value))
    }

    func countMetricValue(for key: String) -> Int {
        countMetrics[key] ?? 0
    }

    mutating func setCountMetricValue(_ value: Int, for key: String) {
        countMetrics[key] = max(0, value)
    }
}

struct IntentReviewContext: Identifiable, Equatable {
    let session: IntentPendingReview
    var draft: IntentReviewDraft

    var id: String {
        session.id
    }
}

struct IntentAPIError: Decodable {
    let error: String
}

struct IntentReviewMetricDefinition: Identifiable, Hashable {
    let id: String
    let title: String
}

enum IntentReviewCatalog {
    static let defaultNumericValue = 5
    static let defaultTaskCategory = "engineering"

    static let numericMetricDefinitions: [IntentReviewMetricDefinition] = [
        IntentReviewMetricDefinition(id: "mindfulness", title: "Mindfulness"),
        IntentReviewMetricDefinition(id: "discipline", title: "Discipline"),
        IntentReviewMetricDefinition(id: "engagement", title: "Engagement"),
        IntentReviewMetricDefinition(id: "focus", title: "Focus"),
        IntentReviewMetricDefinition(id: "courage", title: "Courage"),
        IntentReviewMetricDefinition(id: "authenticity", title: "Authenticity"),
        IntentReviewMetricDefinition(id: "purpose", title: "Purpose"),
        IntentReviewMetricDefinition(id: "energy", title: "Energy"),
        IntentReviewMetricDefinition(id: "communication", title: "Communication"),
        IntentReviewMetricDefinition(id: "uniqueness", title: "Uniqueness"),
        IntentReviewMetricDefinition(id: "adherence", title: "Adherence"),
        IntentReviewMetricDefinition(id: "intentionality", title: "Intentionality"),
    ]

    static let countMetricDefinitions: [IntentReviewMetricDefinition] = [
        IntentReviewMetricDefinition(id: "distractions", title: "Distractions"),
    ]

    static let defaultNumericMetrics = Dictionary(
        uniqueKeysWithValues: numericMetricDefinitions.map { ($0.id, defaultNumericValue) }
    )

    static let defaultCountMetrics = Dictionary(
        uniqueKeysWithValues: countMetricDefinitions.map { ($0.id, 0) }
    )
}
