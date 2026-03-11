//
//  ReviewSheetView.swift
//  Intent
//
//  Created by Codex on 2026-03-10.
//

import AppKit
import SwiftUI

struct ReviewSheetView: View {
    @Binding var context: IntentReviewContext
    let isSubmitting: Bool
    let taskCategorySuggestions: [String]
    let onSubmit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                headerSection
                categorySection
                numericSignalsSection
                countSignalsSection
                reflectionSection
                footerSection
            }
            .padding(28)
        }
        .frame(minWidth: 760, minHeight: 820)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Post-Session Reflection")
                .font(.system(size: 28, weight: .black, design: .rounded))

            Text(context.session.displayTitle)
                .font(.title3.bold())

            Text(sessionWindow)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var categorySection: some View {
        ReviewSectionCard(title: "Task Category", subtitle: "Open-ended, with suggestions from prior completions.") {
            TextField("Task category", text: draftBinding(\.taskCategory))
                .textFieldStyle(.roundedBorder)
                .textInputSuggestions(filteredTaskCategorySuggestions, id: \.self) { suggestion in
                    Label(suggestion, systemImage: "arrow.turn.down.right")
                        .textInputCompletion(suggestion)
                }
        }
    }

    private var numericSignalsSection: some View {
        ReviewSectionCard(title: "Signals", subtitle: "Rate each signal from 0 to 10.") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 190, maximum: 260), spacing: 14)],
                spacing: 14
            ) {
                ForEach(IntentReviewCatalog.numericMetricDefinitions) { metric in
                    MetricSliderCard(
                        title: metric.title,
                        value: numericMetricBinding(for: metric.id),
                        tint: tint(for: metric.id)
                    )
                }
            }
        }
    }

    private var countSignalsSection: some View {
        ReviewSectionCard(title: "Counts", subtitle: "Track discrete events that affected the block.") {
            VStack(spacing: 14) {
                ForEach(IntentReviewCatalog.countMetricDefinitions) { metric in
                    CountMetricSliderRow(
                        title: metric.title,
                        value: countMetricBinding(for: metric.id)
                    )
                }
            }
        }
    }

    private var reflectionSection: some View {
        ReviewSectionCard(title: "Reflection", subtitle: "Keep it honest, concrete, and causal.") {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What went well. And why")
                        .font(.headline)
                    TextEditor(text: draftBinding(\.whatWentWell))
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(fieldBackground)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What didn't go well. And why")
                        .font(.headline)
                    TextEditor(text: draftBinding(\.whatDidntGoWell))
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(fieldBackground)
                }
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Button("Later", role: .cancel) {
                onDismiss()
            }

            Spacer()

            Button("Save review") {
                onSubmit()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || context.draft.taskCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private var filteredTaskCategorySuggestions: [String] {
        let trimmed = context.draft.taskCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        return taskCategorySuggestions
            .filter { suggestion in
                guard suggestion.lowercased() != lowered else {
                    return false
                }

                if lowered.isEmpty {
                    return true
                }

                return suggestion.lowercased().contains(lowered)
            }
            .prefix(8)
            .map { $0 }
    }

    private var sessionWindow: String {
        let start = Date(timeIntervalSince1970: TimeInterval(context.session.startTimeMs) / 1000)
        let stop = context.session.stopTimeMs.map {
            Date(timeIntervalSince1970: TimeInterval($0) / 1000)
        }
        let startText = Self.timeFormatter.string(from: start)
        let stopText = stop.map { Self.timeFormatter.string(from: $0) } ?? "Running"
        return "\(startText) - \(stopText)"
    }

    private func tint(for metricID: String) -> Color {
        switch metricID {
        case "focus":
            return .blue
        case "energy":
            return .orange
        case "discipline":
            return .mint
        case "adherence":
            return .green
        case "intentionality":
            return .purple
        default:
            return .teal
        }
    }

    private func draftBinding<Value>(_ keyPath: WritableKeyPath<IntentReviewDraft, Value>) -> Binding<Value> {
        Binding(
            get: {
                context.draft[keyPath: keyPath]
            },
            set: { newValue in
                context.draft[keyPath: keyPath] = newValue
            }
        )
    }

    private func numericMetricBinding(for key: String) -> Binding<Int> {
        Binding(
            get: {
                context.draft.numericMetricValue(for: key)
            },
            set: { newValue in
                context.draft.setNumericMetricValue(newValue, for: key)
            }
        )
    }

    private func countMetricBinding(for key: String) -> Binding<Int> {
        Binding(
            get: {
                context.draft.countMetricValue(for: key)
            },
            set: { newValue in
                context.draft.setCountMetricValue(newValue, for: key)
            }
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ReviewSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct MetricSliderCard: View {
    let title: String
    @Binding var value: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: 0 ... 10,
                step: 1
            )
            .tint(tint)

            HStack {
                Text("0")
                Spacer()
                Text("5")
                Spacer()
                Text("10")
            }
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct CountMetricSliderRow: View {
    let title: String
    @Binding var value: Int

    private let presets = [0, 1, 2, 3, 5, 8, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text("Count how many times it happened during the session.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Int($0.rounded()) }
                    ),
                    in: 0 ... 10,
                    step: 1
                )
                .tint(.orange)

                Text(valueLabel)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button(action: {
                        value = preset
                    }) {
                        Text(preset == 10 ? "10+" : "\(preset)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .background(
                        Capsule(style: .continuous)
                            .fill(value == preset ? Color.orange.opacity(0.18) : Color.primary.opacity(0.06))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        value == preset ? Color.orange.opacity(0.32) : Color.primary.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .foregroundStyle(value == preset ? Color.orange : .primary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var valueLabel: String {
        value >= 10 ? "10+" : "\(value)"
    }
}
