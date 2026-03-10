//
//  ReviewSheetView.swift
//  Intent
//
//  Created by Codex on 2026-03-10.
//

import SwiftUI

struct ReviewSheetView: View {
    @Binding var context: IntentReviewContext
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Session Review")
                    .font(.title2.bold())

                Text(context.session.displayTitle)
                    .font(.headline)

                Text(sessionWindow)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Form {
                Picker("Focus score", selection: draftBinding(\.focusScore)) {
                    ForEach(1 ..< 6, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }

                Picker("Plan adherence", selection: draftBinding(\.planAdherence)) {
                    Text("Yes").tag("yes")
                    Text("Partly").tag("partly")
                    Text("No").tag("no")
                }

                Picker("Energy", selection: draftBinding(\.energy)) {
                    Text("Low").tag("low")
                    Text("OK").tag("ok")
                    Text("High").tag("high")
                }

                Picker("Distraction", selection: draftBinding(\.distraction)) {
                    Text("None").tag("none")
                    Text("Some").tag("some")
                    Text("A lot").tag("a_lot")
                }

                Picker("Task category", selection: draftBinding(\.taskCategory)) {
                    Text("Engineering").tag("engineering")
                    Text("Planning").tag("planning")
                    Text("Prompting").tag("prompting")
                    Text("Testing").tag("testing")
                    Text("Research").tag("research")
                    Text("Writing").tag("writing")
                    Text("Admin").tag("admin")
                    Text("Other").tag("other")
                }

                Picker("Performance grade", selection: draftBinding(\.performanceGrade, defaultValue: 3)) {
                    ForEach(1 ..< 6, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Reflection")
                    TextEditor(text: draftBinding(\.reflection))
                        .frame(minHeight: 120)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Next intent")
                    TextEditor(text: draftBinding(\.nextIntent))
                        .frame(minHeight: 90)
                }
            }

            HStack {
                Button("Later", role: .cancel) {
                    onDismiss()
                }

                Spacer()

                Button("Save review") {
                    onSubmit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSubmitting)
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 620)
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

    private func draftBinding(
        _ keyPath: WritableKeyPath<IntentReviewDraft, Int?>,
        defaultValue: Int
    ) -> Binding<Int> {
        Binding(
            get: {
                context.draft[keyPath: keyPath] ?? defaultValue
            },
            set: { newValue in
                context.draft[keyPath: keyPath] = newValue
            }
        )
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
