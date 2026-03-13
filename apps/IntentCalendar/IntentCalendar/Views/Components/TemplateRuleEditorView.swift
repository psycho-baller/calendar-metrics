import SwiftUI

struct TemplateRuleEditorView: View {
    let block: TemplateBlock
    let onSave: (TemplateBlockRule) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var isLocked: Bool
    @State private var blockLabel: String
    @State private var allowedActivitiesText: String
    @State private var planningHint: String
    @State private var minimumDuration: String
    @State private var maximumDuration: String

    init(block: TemplateBlock, onSave: @escaping (TemplateBlockRule) -> Void) {
        self.block = block
        self.onSave = onSave
        _isLocked = State(initialValue: block.rule.isLocked)
        _blockLabel = State(initialValue: block.rule.blockLabel ?? "")
        _allowedActivitiesText = State(initialValue: block.rule.allowedActivities.joined(separator: ", "))
        _planningHint = State(initialValue: block.rule.planningHint ?? "")
        _minimumDuration = State(initialValue: block.rule.minimumDurationMinutes.map(String.init) ?? "")
        _maximumDuration = State(initialValue: block.rule.maximumDurationMinutes.map(String.init) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Block") {
                    Text(block.title)
                    Text("\(block.startDate.formatted(date: .omitted, time: .shortened)) - \(block.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Rule") {
                    Toggle("Locked block", isOn: $isLocked)
                    TextField("Label override", text: $blockLabel)
                    TextField("Allowed activities (comma separated)", text: $allowedActivitiesText)
                    TextField("Planning hint", text: $planningHint, axis: .vertical)
                    TextField("Minimum duration minutes", text: $minimumDuration)
                        .keyboardType(.numberPad)
                    TextField("Maximum duration minutes", text: $maximumDuration)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Template rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            TemplateBlockRule(
                                isLocked: isLocked,
                                blockLabel: blockLabel.nilIfBlank,
                                allowedActivities: allowedActivitiesText
                                    .split(separator: ",")
                                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty },
                                planningHint: planningHint.nilIfBlank,
                                destinationCalendarID: block.rule.destinationCalendarID,
                                minimumDurationMinutes: Int(minimumDuration),
                                maximumDurationMinutes: Int(maximumDuration)
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
