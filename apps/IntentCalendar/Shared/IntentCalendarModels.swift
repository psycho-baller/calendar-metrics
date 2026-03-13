import Foundation

enum PlannerModel: String, Codable, CaseIterable, Identifiable {
    case gpt41Mini = "gpt-4.1-mini"
    case gpt4oMini = "gpt-4o-mini"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt41Mini:
            return "GPT-4.1 mini"
        case .gpt4oMini:
            return "GPT-4o mini"
        }
    }
}

struct CalendarDescriptor: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let source: String
    let allowsContentModifications: Bool
    let colorHex: String?
}

struct TemplateBlockRule: Codable, Equatable {
    var isLocked: Bool
    var blockLabel: String?
    var allowedActivities: [String]
    var planningHint: String?
    var destinationCalendarID: String?
    var minimumDurationMinutes: Int?
    var maximumDurationMinutes: Int?

    static let flexibleDefault = TemplateBlockRule(
        isLocked: false,
        blockLabel: nil,
        allowedActivities: [],
        planningHint: nil,
        destinationCalendarID: nil,
        minimumDurationMinutes: nil,
        maximumDurationMinutes: nil
    )
}

struct TemplateBlock: Identifiable, Equatable {
    let id: String
    let calendarItemIdentifier: String
    let calendarID: String
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String?
    let rule: TemplateBlockRule

    var displayLabel: String {
        if let blockLabel = rule.blockLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
           !blockLabel.isEmpty {
            return blockLabel
        }
        return title
    }
}

struct ExistingCommitment: Identifiable, Equatable {
    let id: String
    let eventIdentifier: String
    let calendarID: String
    let calendarTitle: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let isAppOwned: Bool
}

struct PlanningWindow: Identifiable, Equatable, Codable {
    let id: String
    let label: String
    let startDate: Date
    let endDate: Date
    let allowedActivities: [String]
    let planningHint: String?
    let templateBlockID: String?
}

struct PlannedEventBlock: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let detail: String?
    let rationale: String?
    let destinationCalendarID: String
    let sourceWindowID: String
}

struct PlanningContextSnapshot: Codable, Equatable {
    struct SnapshotEvent: Codable, Equatable {
        let id: String
        let title: String
        let startLocalTime: String
        let endLocalTime: String
        let label: String?
        let note: String?
        let allowedActivities: [String]
    }

    struct SnapshotTurn: Codable, Equatable {
        let role: String
        let content: String
    }

    let dateLabel: String
    let timezoneIdentifier: String
    let planningWindows: [SnapshotEvent]
    let fixedCommitments: [SnapshotEvent]
    let existingPlannedEvents: [SnapshotEvent]
    let obsidianContext: [String]
    let conversationTurns: [SnapshotTurn]
}

struct PlannerQuestion: Codable, Equatable, Identifiable {
    var id: String
    var prompt: String
    var rationale: String?
}

struct PlannerSuggestedBlock: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var windowID: String
    var startLocalTime: String
    var endLocalTime: String
    var detail: String?
    var rationale: String?
}

struct PlannerResponse: Codable, Equatable {
    enum Outcome: String, Codable {
        case questions
        case plan
    }

    let outcome: Outcome
    let summary: String
    let questions: [PlannerQuestion]
    let plannedBlocks: [PlannerSuggestedBlock]
}

struct PlanningMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    let content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct PlanningSessionState: Equatable {
    var selectedDate: Date
    var messages: [PlanningMessage]
    var templateBlocks: [TemplateBlock]
    var planningWindows: [PlanningWindow]
    var fixedCommitments: [ExistingCommitment]
    var existingPlannedEvents: [ExistingCommitment]
    var proposedBlocks: [PlannedEventBlock]
    var previewOperations: [CalendarWriteOperation]
    var pendingQuestions: [PlannerQuestion]
    var summary: String

    static func empty(for selectedDate: Date) -> PlanningSessionState {
        PlanningSessionState(
            selectedDate: selectedDate,
            messages: [],
            templateBlocks: [],
            planningWindows: [],
            fixedCommitments: [],
            existingPlannedEvents: [],
            proposedBlocks: [],
            previewOperations: [],
            pendingQuestions: [],
            summary: ""
        )
    }
}

struct CalendarWriteOperation: Identifiable, Equatable {
    enum OperationType: String, Codable {
        case create
        case update
        case delete
    }

    let id: String
    let operationType: OperationType
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarID: String
    let notes: String
    let eventIdentifier: String?
}

struct IntentCalendarConfiguration: Codable, Equatable {
    var hasCompletedOnboarding: Bool
    var selectedTemplateCalendarID: String?
    var selectedPlanningCalendarID: String?
    var selectedConstraintCalendarIDs: [String]
    var plannerModel: PlannerModel
    var selectedDateContextWindow: Int

    static let `default` = IntentCalendarConfiguration(
        hasCompletedOnboarding: false,
        selectedTemplateCalendarID: nil,
        selectedPlanningCalendarID: nil,
        selectedConstraintCalendarIDs: [],
        plannerModel: .gpt41Mini,
        selectedDateContextWindow: 2
    )
}

struct DailyNoteContext: Equatable {
    let url: URL
    let date: Date
    let content: String
}

struct EventDayContext: Equatable {
    let templateBlocks: [TemplateBlock]
    let fixedCommitments: [ExistingCommitment]
    let existingPlannedEvents: [ExistingCommitment]
}

struct AppOwnedEventMetadata: Codable, Equatable {
    let planID: String
    let sourceWindowID: String
}

enum PlanningValidationError: LocalizedError {
    case noPlanningCalendar
    case noTemplateCalendar
    case invalidTime(String)
    case missingWindow(String)
    case overlaps(String)
    case outsideWindow(String)

    var errorDescription: String? {
        switch self {
        case .noPlanningCalendar:
            return "Choose a planning calendar before applying a schedule."
        case .noTemplateCalendar:
            return "Choose a template calendar before asking the planner to build your day."
        case let .invalidTime(value):
            return "The planner returned an invalid time: \(value)."
        case let .missingWindow(value):
            return "The planner referenced an unknown window: \(value)."
        case let .overlaps(value):
            return "The proposed schedule overlaps with \(value)."
        case let .outsideWindow(value):
            return "The proposed block falls outside the allowed window: \(value)."
        }
    }
}
