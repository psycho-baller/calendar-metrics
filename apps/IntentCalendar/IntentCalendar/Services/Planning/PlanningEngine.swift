import Foundation

struct PlanningValidationResult {
    let proposedBlocks: [PlannedEventBlock]
    let previewOperations: [CalendarWriteOperation]
}

enum PlanningEngine {
    static func planningWindows(
        templateBlocks: [TemplateBlock],
        commitments: [ExistingCommitment],
        date: Date
    ) -> [PlanningWindow] {
        let flexibleTemplateBlocks = templateBlocks
            .filter { !$0.rule.isLocked }
            .sorted { $0.startDate < $1.startDate }

        if !flexibleTemplateBlocks.isEmpty {
            return flexibleTemplateBlocks.map { block in
                PlanningWindow(
                    id: block.id,
                    label: block.displayLabel,
                    startDate: block.startDate,
                    endDate: block.endDate,
                    allowedActivities: block.rule.allowedActivities,
                    planningHint: block.rule.planningHint,
                    templateBlockID: block.id
                )
            }
        }

        let calendar = Calendar.current
        let dayStart = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: date) ?? calendar.startOfDay(for: date)
        let dayEnd = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: date) ?? calendar.date(byAdding: .hour, value: 23, to: calendar.startOfDay(for: date)) ?? date
        let sortedCommitments = commitments.sorted { $0.startDate < $1.startDate }

        var windows: [PlanningWindow] = []
        var cursor = dayStart

        for commitment in sortedCommitments {
            guard commitment.endDate > dayStart && commitment.startDate < dayEnd else { continue }
            let start = max(cursor, dayStart)
            let end = min(commitment.startDate, dayEnd)
            if end.timeIntervalSince(start) >= 30 * 60 {
                windows.append(
                    PlanningWindow(
                        id: UUID().uuidString,
                        label: "Open block",
                        startDate: start,
                        endDate: end,
                        allowedActivities: [],
                        planningHint: "Open time between existing commitments.",
                        templateBlockID: nil
                    )
                )
            }
            cursor = max(cursor, commitment.endDate)
        }

        if dayEnd.timeIntervalSince(cursor) >= 30 * 60 {
            windows.append(
                PlanningWindow(
                    id: UUID().uuidString,
                    label: "Open block",
                    startDate: cursor,
                    endDate: dayEnd,
                    allowedActivities: [],
                    planningHint: "Open time before the day winds down.",
                    templateBlockID: nil
                )
            )
        }

        return windows
    }

    static func buildContextSnapshot(
        date: Date,
        planningWindows: [PlanningWindow],
        fixedCommitments: [ExistingCommitment],
        existingPlannedEvents: [ExistingCommitment],
        conversation: [PlanningMessage],
        obsidianContext: [DailyNoteContext]
    ) -> PlanningContextSnapshot {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        return PlanningContextSnapshot(
            dateLabel: formatter.string(from: date),
            timezoneIdentifier: TimeZone.current.identifier,
            planningWindows: planningWindows.map { window in
                PlanningContextSnapshot.SnapshotEvent(
                    id: window.id,
                    title: window.label,
                    startLocalTime: timeFormatter.string(from: window.startDate),
                    endLocalTime: timeFormatter.string(from: window.endDate),
                    label: window.label,
                    note: window.planningHint,
                    allowedActivities: window.allowedActivities
                )
            },
            fixedCommitments: fixedCommitments.map { event in
                PlanningContextSnapshot.SnapshotEvent(
                    id: event.id,
                    title: event.title,
                    startLocalTime: timeFormatter.string(from: event.startDate),
                    endLocalTime: timeFormatter.string(from: event.endDate),
                    label: event.calendarTitle,
                    note: event.isAllDay ? "All day" : nil,
                    allowedActivities: []
                )
            },
            existingPlannedEvents: existingPlannedEvents.map { event in
                PlanningContextSnapshot.SnapshotEvent(
                    id: event.id,
                    title: event.title,
                    startLocalTime: timeFormatter.string(from: event.startDate),
                    endLocalTime: timeFormatter.string(from: event.endDate),
                    label: event.calendarTitle,
                    note: "Existing IntentCalendar event",
                    allowedActivities: []
                )
            },
            obsidianContext: obsidianContext.map { note in
                let content = note.content
                    .split(separator: "\n")
                    .prefix(12)
                    .joined(separator: "\n")
                return "\(note.url.lastPathComponent)\n\(content)"
            },
            conversationTurns: conversation.map {
                PlanningContextSnapshot.SnapshotTurn(role: $0.role.rawValue, content: $0.content)
            }
        )
    }

    static func validate(
        plannerResponse: PlannerResponse,
        planningWindows: [PlanningWindow],
        fixedCommitments: [ExistingCommitment],
        existingPlannedEvents: [ExistingCommitment],
        planningCalendarID: String?
    ) throws -> PlanningValidationResult {
        guard let planningCalendarID else {
            throw PlanningValidationError.noPlanningCalendar
        }

        let windowsByID = Dictionary(uniqueKeysWithValues: planningWindows.map { ($0.id, $0) })
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        var proposedBlocks: [PlannedEventBlock] = []
        let occupiedRanges = fixedCommitments.map { DateInterval(start: $0.startDate, end: $0.endDate) }

        for block in plannerResponse.plannedBlocks {
            guard let window = windowsByID[block.windowID] else {
                throw PlanningValidationError.missingWindow(block.windowID)
            }

            guard let start = parse(localTime: block.startLocalTime, in: window.startDate, formatter: timeFormatter),
                  let end = parse(localTime: block.endLocalTime, in: window.startDate, formatter: timeFormatter)
            else {
                throw PlanningValidationError.invalidTime("\(block.startLocalTime) - \(block.endLocalTime)")
            }

            guard start >= window.startDate, end <= window.endDate, end > start else {
                throw PlanningValidationError.outsideWindow(window.label)
            }

            let proposedRange = DateInterval(start: start, end: end)

            if occupiedRanges.contains(where: { $0.intersects(proposedRange) }) ||
                proposedBlocks.contains(where: {
                    DateInterval(start: $0.startDate, end: $0.endDate).intersects(proposedRange)
                }) {
                throw PlanningValidationError.overlaps(block.title)
            }

            proposedBlocks.append(
                PlannedEventBlock(
                    id: block.id,
                    title: block.title,
                    startDate: start,
                    endDate: end,
                    detail: block.detail,
                    rationale: block.rationale,
                    destinationCalendarID: planningCalendarID,
                    sourceWindowID: block.windowID
                )
            )
        }

        let deleteOperations = existingPlannedEvents.map { event in
            CalendarWriteOperation(
                id: "delete-\(event.id)",
                operationType: .delete,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                calendarID: event.calendarID,
                notes: event.title,
                eventIdentifier: event.eventIdentifier
            )
        }

        let createOperations = proposedBlocks.map { block in
            CalendarWriteOperation(
                id: "create-\(block.id)",
                operationType: .create,
                title: block.title,
                startDate: block.startDate,
                endDate: block.endDate,
                calendarID: block.destinationCalendarID,
                notes: plannedEventNotes(for: block),
                eventIdentifier: nil
            )
        }

        return PlanningValidationResult(
            proposedBlocks: proposedBlocks.sorted { $0.startDate < $1.startDate },
            previewOperations: deleteOperations + createOperations
        )
    }

    private static func parse(localTime: String, in referenceDate: Date, formatter: DateFormatter) -> Date? {
        let parts = localTime.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: referenceDate
        )
    }

    private static func plannedEventNotes(for block: PlannedEventBlock) -> String {
        let metadata = AppOwnedEventMetadata(planID: block.id, sourceWindowID: block.sourceWindowID)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = (try? encoder.encode(metadata)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

        var sections: [String] = []
        if let detail = block.detail?.trimmingCharacters(in: .whitespacesAndNewlines), !detail.isEmpty {
            sections.append(detail)
        }
        if let rationale = block.rationale?.trimmingCharacters(in: .whitespacesAndNewlines), !rationale.isEmpty {
            sections.append("Why: \(rationale)")
        }
        sections.append("\(AppConstants.Metadata.plannedEventStart)\n\(json)\n\(AppConstants.Metadata.plannedEventEnd)")
        return sections.joined(separator: "\n\n")
    }
}
