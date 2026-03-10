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
    let focusScore: Int
    let planAdherence: String
    let energy: String
    let distraction: String
    let taskCategory: String
    let performanceGrade: Int?
    let reflection: String?
    let nextIntent: String?
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

struct IntentDeviceState: Decodable {
    let device: IntentDeviceInfo
    let integration: IntentIntegrationState
    let activeSession: IntentSessionSummary?
    let pendingFocusStart: IntentSessionSummary?
    let pendingFocusComplete: IntentSessionSummary?
    let pendingReview: IntentPendingReview?
    let pendingReviewsCount: Int
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
    let focusScore: Int
    let planAdherence: String
    let energy: String
    let distraction: String
    let taskCategory: String
    let performanceGrade: Int?
    let reflection: String
    let nextIntent: String
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

struct IntentReviewDraft: Equatable {
    var focusScore = 4
    var planAdherence = "yes"
    var energy = "ok"
    var distraction = "some"
    var taskCategory = "engineering"
    var performanceGrade: Int? = 4
    var reflection = ""
    var nextIntent = ""

    init(existingReview: IntentExistingReview?) {
        guard let existingReview else {
            return
        }

        focusScore = existingReview.focusScore
        planAdherence = existingReview.planAdherence
        energy = existingReview.energy
        distraction = existingReview.distraction
        taskCategory = existingReview.taskCategory
        performanceGrade = existingReview.performanceGrade
        reflection = existingReview.reflection
        nextIntent = existingReview.nextIntent
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
