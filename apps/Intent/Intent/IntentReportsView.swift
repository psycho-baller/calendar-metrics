//
//  IntentReportsView.swift
//  Intent
//
//  Created by Codex on 2026-03-15.
//

import AppKit
import SwiftUI

struct IntentReportsView: View {
    @ObservedObject var model: IntentAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if model.dailyReports.isEmpty {
                    emptyState
                } else {
                    ForEach(model.dailyReports) { report in
                        reportCard(report)
                    }
                }
            }
            .padding(28)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reports")
                    .font(.system(size: 40, weight: .black, design: .rounded))

                Text("Daily wrap-ups built from the tracked work window ending at your configured report time.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 12) {
                Button("Generate latest completed report") {
                    Task {
                        await model.generateLatestCompletedDailyReport()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.configuration.isPaired || model.isGeneratingDailyReport)

                if model.isGeneratingDailyReport {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private var emptyState: some View {
        ReportSurface {
            VStack(alignment: .leading, spacing: 14) {
                Text("No reports yet")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Turn on Daily report scheduling in Settings, or generate the latest completed report manually.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func reportCard(_ report: IntentGeneratedDailyReport) -> some View {
        ReportSurface {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(report.title)
                            .font(.system(size: 28, weight: .black, design: .rounded))

                        Text(report.headline)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))

                        Text(intervalLabel(for: report))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 10) {
                        ReportBadge(
                            title: report.source == .ai ? "AI" : "Fallback",
                            tone: report.source == .ai ? .teal : .orange
                        )
                        Button("Copy") {
                            copy(report)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text(report.overview)
                    .font(.body)

                if !report.stats.isEmpty {
                    section(title: "Stats", items: report.stats)
                }

                if !report.whatWentWell.isEmpty {
                    section(title: "What went well", items: report.whatWentWell)
                }

                if !report.whatDidntGoWell.isEmpty {
                    section(title: "What didn't go well", items: report.whatDidntGoWell)
                }

                if !report.improvements.isEmpty {
                    section(title: "For tomorrow", items: report.improvements)
                }
            }
        }
    }

    private func section(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.teal.opacity(0.8))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        Text(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func intervalLabel(for report: IntentGeneratedDailyReport) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(formatter.string(from: report.intervalStartDate)) to \(formatter.string(from: report.intervalEndDate))"
    }

    private func copy(_ report: IntentGeneratedDailyReport) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(renderedText(for: report), forType: .string)
    }

    private func renderedText(for report: IntentGeneratedDailyReport) -> String {
        var lines = [String]()
        lines.append(report.title)
        lines.append(report.headline)
        lines.append("")
        lines.append(report.overview)

        if !report.stats.isEmpty {
            lines.append("")
            lines.append("Stats")
            lines.append(contentsOf: report.stats.map { "- \($0)" })
        }

        if !report.whatWentWell.isEmpty {
            lines.append("")
            lines.append("What went well")
            lines.append(contentsOf: report.whatWentWell.map { "- \($0)" })
        }

        if !report.whatDidntGoWell.isEmpty {
            lines.append("")
            lines.append("What didn't go well")
            lines.append(contentsOf: report.whatDidntGoWell.map { "- \($0)" })
        }

        if !report.improvements.isEmpty {
            lines.append("")
            lines.append("For tomorrow")
            lines.append(contentsOf: report.improvements.map { "- \($0)" })
        }

        return lines.joined(separator: "\n")
    }
}

private struct ReportSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

private struct ReportBadge: View {
    let title: String
    let tone: Color

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.opacity(0.14))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(tone.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundStyle(tone)
    }
}
