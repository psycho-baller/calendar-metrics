//
//  ContentView.swift
//  Intent
//
//  Created by Codex on 2026-05-11.
//

import Charts
import SwiftUI

private enum IntentTab: String, Hashable {
    case home
    case trends
    case settings
}

struct ContentView: View {
    @ObservedObject var model: IntentionalityAppModel
    @State private var selectedTab: IntentTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            IntentionalityHomeView(model: model)
                .tag(IntentTab.home)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            IntentionalityTrendsView(model: model)
                .tag(IntentTab.trends)
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }

            IntentionalitySettingsView(model: model)
                .tag(IntentTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(IntentTheme.accent)
        .onAppear {
            model.start()
        }
    }
}

private struct IntentionalityHomeView: View {
    @ObservedObject var model: IntentionalityAppModel

    var body: some View {
        IntentScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderView(model: model)

                    if !model.isPaired {
                        PairingPrompt()
                    }

                    QuickRecordPanel(model: model)

                    if let snapshot = model.snapshot {
                        SnapshotGrid(snapshot: snapshot)
                        RecentSignalChart(snapshot: snapshot)
                        TodayHourStrip(snapshot: snapshot)
                        RecentEntriesList(snapshot: snapshot)
                    } else {
                        LoadingPanel(isPaired: model.isPaired)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct IntentionalityTrendsView: View {
    @ObservedObject var model: IntentionalityAppModel

    var body: some View {
        IntentScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Trends")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(IntentTheme.textPrimary)

                            Text("Hourly intentionality")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(IntentTheme.textSecondary)
                        }

                        Spacer(minLength: 12)

                        WindowPicker(model: model)
                    }

                    if let snapshot = model.snapshot {
                        DailyAverageChart(snapshot: snapshot)
                        HourOfDayChart(snapshot: snapshot)
                    } else {
                        LoadingPanel(isPaired: model.isPaired)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct IntentionalitySettingsView: View {
    @ObservedObject var model: IntentionalityAppModel

    var body: some View {
        IntentScreenBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Settings")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(IntentTheme.textPrimary)

                        Text(model.connectionStatus)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(IntentTheme.textSecondary)
                    }

                    IntentPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledInput(
                                title: "Backend URL",
                                text: Binding(
                                    get: { model.configuration.backendBaseURL },
                                    set: { value in
                                        model.updateConfiguration { configuration in
                                            configuration.backendBaseURL = value
                                        }
                                    }
                                ),
                                keyboardType: .URL,
                                isSecure: false
                            )

                            LabeledInput(
                                title: "Setup key",
                                text: Binding(
                                    get: { model.configuration.setupKey },
                                    set: { value in
                                        model.updateConfiguration { configuration in
                                            configuration.setupKey = value
                                        }
                                    }
                                ),
                                keyboardType: .default,
                                isSecure: true
                            )

                            LabeledInput(
                                title: "Device name",
                                text: Binding(
                                    get: { model.configuration.deviceName },
                                    set: { value in
                                        model.updateConfiguration { configuration in
                                            configuration.deviceName = value
                                        }
                                    }
                                ),
                                keyboardType: .default,
                                isSecure: false
                            )

                            Button {
                                Task {
                                    await model.pair()
                                }
                            } label: {
                                HStack {
                                    if model.isPairing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "link")
                                    }
                                    Text(model.isPaired ? "Pair again" : "Pair")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(IntentTheme.accent)
                            .disabled(model.isPairing)
                        }
                    }

                    IntentPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Data Window")
                                .font(.headline)
                                .foregroundStyle(IntentTheme.textPrimary)

                            WindowPicker(model: model)
                        }
                    }

                    StatusMessages(model: model)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }
}

private struct IntentScreenBackground<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            IntentTheme.background
                .ignoresSafeArea()

            StarfieldView(starCount: 38, showShootingStars: false)
                .opacity(0.36)
                .ignoresSafeArea()

            content()
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var model: IntentionalityAppModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Intent")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(IntentTheme.textPrimary)

                Text(Date(), format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IntentTheme.textSecondary)
            }

            Spacer(minLength: 10)

            StatusPill(text: model.connectionStatus)
        }
    }
}

private struct StatusPill: View {
    let text: String

    var color: Color {
        text == "Connected" ? IntentTheme.mint : IntentTheme.amber
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(IntentTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(IntentTheme.panelStrong, in: Capsule())
    }
}

private struct QuickRecordPanel: View {
    @ObservedObject var model: IntentionalityAppModel

    var body: some View {
        IntentPanel(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Hour")
                            .font(.headline)
                            .foregroundStyle(IntentTheme.textPrimary)
                        Text("Manual fallback")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(IntentTheme.textSecondary)
                    }

                    Spacer()

                    Text(scoreText(model.pendingScore))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(IntentTheme.accent)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Slider(value: $model.pendingScore, in: 0...10, step: 1)
                    .tint(IntentTheme.accent)

                Button {
                    Task {
                        await model.recordCurrentHour()
                    }
                } label: {
                    HStack {
                        if model.isRecording {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Record")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(IntentTheme.accent)
                .disabled(!model.isPaired || model.isRecording)
            }
        }
    }
}

private struct SnapshotGrid: View {
    let snapshot: IntentionalitySnapshot

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            MetricTile(
                title: "Today",
                value: optionalScoreText(snapshot.todayAverage),
                caption: deltaCaption(snapshot.deltaFromYesterday),
                systemImage: "sun.max.fill",
                tint: IntentTheme.amber
            )

            MetricTile(
                title: "Current Hour",
                value: optionalScoreText(snapshot.currentHourScore),
                caption: "latest hourly entry",
                systemImage: "clock.fill",
                tint: IntentTheme.accent
            )

            MetricTile(
                title: "7 Day Capture",
                value: "\(Int(snapshot.responseRate7d.rounded()))%",
                caption: "\(snapshot.totalEntries) entries in view",
                systemImage: "calendar.badge.checkmark",
                tint: IntentTheme.mint
            )

            MetricTile(
                title: "Streak",
                value: "\(snapshot.currentStreakDays)d",
                caption: snapshot.bestHourOfDay.map { "best at \($0.label)" } ?? "no best hour yet",
                systemImage: "flame.fill",
                tint: IntentTheme.coral
            )
        }
    }
}

private struct RecentSignalChart: View {
    let snapshot: IntentionalitySnapshot

    private var series: [IntentionalityEntry] {
        Array(snapshot.recentEntries.sorted { $0.hourStartMs < $1.hourStartMs }.suffix(36))
    }

    var body: some View {
        ChartCard(title: "Recent Signal", subtitle: "last \(series.count) captured hours") {
            if series.isEmpty {
                EmptyChartState()
            } else {
                Chart {
                    ForEach(series) { entry in
                        AreaMark(
                            x: .value("Hour", entry.date),
                            y: .value("Score", entry.score)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [IntentTheme.accent.opacity(0.34), IntentTheme.accent.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Hour", entry.date),
                            y: .value("Score", entry.score)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(IntentTheme.accent)

                        PointMark(
                            x: .value("Hour", entry.date),
                            y: .value("Score", entry.score)
                        )
                        .symbolSize(36)
                        .foregroundStyle(IntentTheme.textPrimary)
                    }
                }
                .chartYScale(domain: 0...10)
                .chartYAxis {
                    AxisMarks(values: [0, 2, 4, 6, 8, 10])
                }
                .frame(height: 210)
            }
        }
    }
}

private struct DailyAverageChart: View {
    let snapshot: IntentionalitySnapshot

    var body: some View {
        ChartCard(title: "Daily Average", subtitle: "\(snapshot.windowDays)-day window") {
            if snapshot.dailyAverages.isEmpty {
                EmptyChartState()
            } else {
                Chart {
                    ForEach(snapshot.dailyAverages) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Average", day.average)
                        )
                        .foregroundStyle(IntentTheme.mint)
                    }
                }
                .chartYScale(domain: 0...10)
                .frame(height: 240)
            }
        }
    }
}

private struct HourOfDayChart: View {
    let snapshot: IntentionalitySnapshot

    var body: some View {
        ChartCard(title: "Hour of Day", subtitle: "average score by local hour") {
            Chart {
                ForEach(snapshot.hourlyAverages) { hour in
                    if let average = hour.average {
                        BarMark(
                            x: .value("Hour", hour.label),
                            y: .value("Average", average)
                        )
                        .foregroundStyle(hour.hour >= 8 && hour.hour <= 18 ? IntentTheme.accent : IntentTheme.amber)
                    }
                }
            }
            .chartYScale(domain: 0...10)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6))
            }
            .frame(height: 250)
        }
    }
}

private struct TodayHourStrip: View {
    let snapshot: IntentionalitySnapshot

    private var todayEntries: [IntentionalityEntry] {
        let todayKey = snapshot.recentEntries.first?.dayKey
        return snapshot.recentEntries
            .filter { todayKey == nil || $0.dayKey == todayKey }
            .sorted { $0.hourStartMs < $1.hourStartMs }
    }

    var body: some View {
        IntentPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Captured Hours")
                    .font(.headline)
                    .foregroundStyle(IntentTheme.textPrimary)

                if todayEntries.isEmpty {
                    Text("No hourly entries yet.")
                        .font(.subheadline)
                        .foregroundStyle(IntentTheme.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(todayEntries) { entry in
                                VStack(spacing: 5) {
                                    Text(entry.hourLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(IntentTheme.textSecondary)
                                        .lineLimit(1)

                                    Text(scoreText(entry.score))
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundStyle(IntentTheme.textPrimary)
                                        .monospacedDigit()
                                }
                                .frame(width: 62, height: 58)
                                .background(scoreColor(entry.score).opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(scoreColor(entry.score).opacity(0.55), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct RecentEntriesList: View {
    let snapshot: IntentionalitySnapshot

    var body: some View {
        IntentPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Latest")
                    .font(.headline)
                    .foregroundStyle(IntentTheme.textPrimary)

                ForEach(snapshot.recentEntries.prefix(8)) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.date, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(IntentTheme.textPrimary)
                            Text(entry.source.replacingOccurrences(of: "_", with: " "))
                                .font(.caption)
                                .foregroundStyle(IntentTheme.textSecondary)
                        }

                        Spacer()

                        Text(scoreText(entry.score))
                            .font(.title3.bold())
                            .foregroundStyle(scoreColor(entry.score))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)

                    if entry.id != snapshot.recentEntries.prefix(8).last?.id {
                        Divider()
                            .overlay(IntentTheme.border)
                    }
                }
            }
        }
    }
}

private struct PairingPrompt: View {
    var body: some View {
        IntentPanel {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "link.badge.plus")
                    .font(.title2)
                    .foregroundStyle(IntentTheme.amber)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pair Intent")
                        .font(.headline)
                        .foregroundStyle(IntentTheme.textPrimary)
                    Text("Add the Convex URL and setup key in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(IntentTheme.textSecondary)
                }
            }
        }
    }
}

private struct LoadingPanel: View {
    let isPaired: Bool

    var body: some View {
        IntentPanel {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(IntentTheme.textPrimary)
                Text(isPaired ? "Loading metrics" : "Waiting for setup")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(IntentTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EmptyChartState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundStyle(IntentTheme.textSecondary)
            Text("No data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(IntentTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
    }
}

private struct WindowPicker: View {
    @ObservedObject var model: IntentionalityAppModel

    var body: some View {
        Picker(
            "Window",
            selection: Binding(
                get: { model.configuration.windowDays },
                set: { model.setWindowDays($0) }
            )
        ) {
            Text("7D").tag(7)
            Text("30D").tag(30)
            Text("90D").tag(90)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 230)
    }
}

private struct StatusMessages: View {
    @ObservedObject var model: IntentionalityAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let notice = model.lastNotice {
                NoticeRow(text: notice, color: IntentTheme.mint, systemImage: "checkmark.circle.fill")
            }

            if let error = model.lastError {
                NoticeRow(text: error, color: IntentTheme.coral, systemImage: "exclamationmark.triangle.fill")
            }
        }
    }
}

private struct NoticeRow: View {
    let text: String
    let color: Color
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(IntentTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct LabeledInput: View {
    let title: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(IntentTheme.textSecondary)

            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .padding(12)
            .foregroundStyle(IntentTheme.textPrimary)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(IntentTheme.border, lineWidth: 1)
            )
        }
    }
}

private func scoreText(_ value: Double) -> String {
    if value.rounded() == value {
        return "\(Int(value))/10"
    }

    return String(format: "%.1f/10", value)
}

private func optionalScoreText(_ value: Double?) -> String {
    guard let value else {
        return "--"
    }

    return scoreText(value)
}

private func deltaCaption(_ value: Double?) -> String {
    guard let value else {
        return "no prior-day comparison"
    }

    if value == 0 {
        return "flat vs yesterday"
    }

    let prefix = value > 0 ? "+" : ""
    return "\(prefix)\(String(format: "%.1f", value)) vs yesterday"
}

private func scoreColor(_ value: Double) -> Color {
    if value >= 8 {
        return IntentTheme.mint
    }
    if value >= 6 {
        return IntentTheme.accent
    }
    if value >= 4 {
        return IntentTheme.amber
    }
    return IntentTheme.coral
}

#Preview {
    ContentView(model: IntentionalityAppModel())
}
