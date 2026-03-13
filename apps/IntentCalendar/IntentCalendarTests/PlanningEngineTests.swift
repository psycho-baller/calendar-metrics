import XCTest
@testable import IntentCalendar

final class PlanningEngineTests: XCTestCase {
    func testPlanningWindowsIgnoreLockedTemplateBlocks() {
        let date = makeDate(hour: 6, minute: 0)
        let flexible = TemplateBlock(
            id: "flexible",
            calendarItemIdentifier: "flexible",
            calendarID: "template",
            title: "Focus",
            startDate: makeDate(hour: 9, minute: 0),
            endDate: makeDate(hour: 11, minute: 0),
            notes: nil,
            rule: TemplateBlockRule(
                isLocked: false,
                blockLabel: "Focus block",
                allowedActivities: ["Deep work"],
                planningHint: nil,
                destinationCalendarID: nil,
                minimumDurationMinutes: nil,
                maximumDurationMinutes: nil
            )
        )
        let locked = TemplateBlock(
            id: "locked",
            calendarItemIdentifier: "locked",
            calendarID: "template",
            title: "Prayer",
            startDate: makeDate(hour: 12, minute: 30),
            endDate: makeDate(hour: 13, minute: 0),
            notes: nil,
            rule: TemplateBlockRule(
                isLocked: true,
                blockLabel: "Prayer",
                allowedActivities: [],
                planningHint: nil,
                destinationCalendarID: nil,
                minimumDurationMinutes: nil,
                maximumDurationMinutes: nil
            )
        )

        let windows = PlanningEngine.planningWindows(
            templateBlocks: [locked, flexible],
            commitments: [],
            date: date
        )

        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.id, "flexible")
        XCTAssertEqual(windows.first?.label, "Focus block")
    }

    func testValidateRejectsOverlapWithExistingCommitment() {
        let window = PlanningWindow(
            id: "focus",
            label: "Focus block",
            startDate: makeDate(hour: 9, minute: 0),
            endDate: makeDate(hour: 11, minute: 0),
            allowedActivities: [],
            planningHint: nil,
            templateBlockID: nil
        )
        let commitment = ExistingCommitment(
            id: "meeting",
            eventIdentifier: "meeting",
            calendarID: "constraints",
            calendarTitle: "Work",
            title: "Standup",
            startDate: makeDate(hour: 9, minute: 30),
            endDate: makeDate(hour: 10, minute: 0),
            isAllDay: false,
            isAppOwned: false
        )
        let response = PlannerResponse(
            outcome: .plan,
            summary: "Plan",
            questions: [],
            plannedBlocks: [
                PlannerSuggestedBlock(
                    id: "ship",
                    title: "Ship feature",
                    windowID: "focus",
                    startLocalTime: "09:00",
                    endLocalTime: "10:00",
                    detail: nil,
                    rationale: nil
                )
            ]
        )

        XCTAssertThrowsError(
            try PlanningEngine.validate(
                plannerResponse: response,
                planningWindows: [window],
                fixedCommitments: [commitment],
                existingPlannedEvents: [],
                planningCalendarID: "planning"
            )
        ) { error in
            guard case let PlanningValidationError.overlaps(title) = error else {
                return XCTFail("Expected overlap error, got \(error)")
            }
            XCTAssertEqual(title, "Ship feature")
        }
    }

    func testValidateProducesDeleteAndCreateOperations() throws {
        let window = PlanningWindow(
            id: "admin",
            label: "Admin",
            startDate: makeDate(hour: 16, minute: 0),
            endDate: makeDate(hour: 18, minute: 0),
            allowedActivities: [],
            planningHint: nil,
            templateBlockID: nil
        )
        let existing = ExistingCommitment(
            id: "old-plan",
            eventIdentifier: "event-123",
            calendarID: "planning",
            calendarTitle: "IntentCalendar Plan",
            title: "Old plan",
            startDate: makeDate(hour: 16, minute: 0),
            endDate: makeDate(hour: 16, minute: 30),
            isAllDay: false,
            isAppOwned: true
        )
        let response = PlannerResponse(
            outcome: .plan,
            summary: "Plan",
            questions: [],
            plannedBlocks: [
                PlannerSuggestedBlock(
                    id: "admin-task",
                    title: "Inbox cleanup",
                    windowID: "admin",
                    startLocalTime: "16:30",
                    endLocalTime: "17:00",
                    detail: "Reply to priority messages.",
                    rationale: "This is a lighter-energy task."
                )
            ]
        )

        let result = try PlanningEngine.validate(
            plannerResponse: response,
            planningWindows: [window],
            fixedCommitments: [],
            existingPlannedEvents: [existing],
            planningCalendarID: "planning"
        )

        XCTAssertEqual(result.proposedBlocks.count, 1)
        XCTAssertEqual(result.previewOperations.map(\.operationType), [.delete, .create])
        XCTAssertEqual(result.previewOperations.last?.calendarID, "planning")
        XCTAssertTrue(result.previewOperations.last?.notes.contains(AppConstants.Metadata.plannedEventStart) == true)
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let base = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)!
    }
}
