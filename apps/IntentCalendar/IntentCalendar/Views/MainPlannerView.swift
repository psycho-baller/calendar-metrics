import SwiftUI

struct MainPlannerView: View {
    @ObservedObject var model: IntentCalendarAppModel
    @EnvironmentObject private var draftManager: DraftManager
    @EnvironmentObject private var transcriberService: TranscriberService
    @StateObject private var audioRecorder = AudioRecorder()
    @StateObject private var fileImportManager = FileImportManager()
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var theme: AppTheme {
        themeManager.currentTheme(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            content
                .background(theme.backgroundGradient.ignoresSafeArea())
                .navigationTitle(formattedDate(model.session.selectedDate))
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button {
                            model.showingDrafts = true
                        } label: {
                            Image(systemName: "doc.text")
                        }

                        Button {
                            model.showingArchive = true
                        } label: {
                            Image(systemName: "archivebox")
                        }
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            Task {
                                await model.selectDate(Calendar.current.date(byAdding: .day, value: -1, to: model.session.selectedDate) ?? model.session.selectedDate)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }

                        Button {
                            Task {
                                await model.selectDate(Date())
                            }
                        } label: {
                            Image(systemName: "calendar")
                        }

                        Button {
                            Task {
                                await model.selectDate(Calendar.current.date(byAdding: .day, value: 1, to: model.session.selectedDate) ?? model.session.selectedDate)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                        }

                        Button {
                            model.showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
        .sheet(isPresented: $model.showingSettings) {
            SettingsView(model: model)
        }
        .sheet(isPresented: $model.showingDrafts) {
            DraftsListView(draftManager: draftManager, isPresented: $model.showingDrafts)
        }
        .sheet(isPresented: $model.showingArchive) {
            ArchiveListView(draftManager: draftManager, isPresented: $model.showingArchive)
        }
        .sheet(item: $model.selectedTemplateRuleBlock) { block in
            TemplateRuleEditorView(
                block: block,
                onSave: { rule in
                    Task {
                        await model.saveTemplateRule(for: block, rule: rule)
                    }
                }
            )
        }
        .fileImporter(
            isPresented: $fileImportManager.isImporterPresented,
            allowedContentTypes: fileImportManager.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            fileImportManager.handleImport(result: result) { finalResult in
                if case let .success(url) = finalResult {
                    processImportedFile(url)
                }
            }
        }
        .onReceive(audioRecorder.$recordingURL) { url in
            guard let url, !audioRecorder.isRecording else { return }
            Task {
                do {
                    let text = try await transcriberService.transcribe(audioURL: url)
                    model.ingestCapturedText(text.replacingOccurrences(of: "[BLANK_AUDIO]", with: ""))
                } catch {
                    model.errorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                plannerColumn
            } detail: {
                timelineColumn
            }
        } else {
            ScrollView {
                VStack(spacing: 18) {
                    plannerColumn
                    timelineColumn
                }
                .padding(18)
            }
        }
    }

    private var plannerColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            headlineCard
            conversationCard
            composerCard
            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(18)
    }

    private var timelineColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                timelineCard
                previewCard
            }
            .padding(18)
        }
    }

    private var headlineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today’s planning surface")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .accessibilityIdentifier("planner.headline")
            Text("Use your template calendar as the skeleton, your existing commitments as constraints, and your conversation as the last missing layer.")
                .foregroundStyle(theme.textSecondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var conversationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Conversation")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView()
                }
            }

            if model.session.messages.isEmpty {
                Text("Start with what the day needs to contain, where you already have commitments, and anything you definitely don’t want to forget.")
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(model.session.messages) { message in
                    HStack {
                        if message.role == .assistant || message.role == .system {
                            messageBubble(message, tone: .assistant)
                            Spacer(minLength: 24)
                        } else {
                            Spacer(minLength: 24)
                            messageBubble(message, tone: .user)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick capture")
                .font(.headline)

            TextEditor(text: Binding(
                get: { draftManager.currentDraft?.content ?? "" },
                set: { draftManager.updateCurrentDraft(content: $0) }
            ))
            .frame(minHeight: 140)
            .padding(10)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 12) {
                Button {
                    if audioRecorder.isRecording {
                        audioRecorder.stopRecording()
                    } else {
                        audioRecorder.startRecording()
                    }
                } label: {
                    Label(audioRecorder.isRecording ? "Stop" : "Record", systemImage: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                }
                .buttonStyle(.bordered)

                Button {
                    fileImportManager.startImport()
                } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    Task {
                        await model.sendCurrentDraftToPlanner()
                    }
                } label: {
                    Label("Plan day", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.actionPrimary)
                .disabled(isPlanDayDisabled)
                .accessibilityIdentifier("planner.planDay")
            }
        }
        .padding(20)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var timelineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timeline preview")
                .font(.headline)

            if model.session.templateBlocks.isEmpty && model.session.fixedCommitments.isEmpty {
                Text("No template blocks or fixed commitments found for this day yet.")
                    .foregroundStyle(theme.textSecondary)
            }

            if !model.session.templateBlocks.isEmpty {
                timelineSection(title: "Template blocks") {
                    ForEach(model.session.templateBlocks) { block in
                        timelineRow(
                            title: block.displayLabel,
                            subtitle: timeRange(block.startDate, block.endDate),
                            tag: block.rule.isLocked ? "Locked" : "Flexible",
                            accent: block.rule.isLocked ? theme.warning : theme.success,
                            action: {
                                model.selectedTemplateRuleBlock = block
                            }
                        )
                    }
                }
            }

            if !model.session.fixedCommitments.isEmpty {
                timelineSection(title: "Existing commitments") {
                    ForEach(model.session.fixedCommitments) { event in
                        timelineRow(
                            title: event.title,
                            subtitle: "\(timeRange(event.startDate, event.endDate)) • \(event.calendarTitle)",
                            tag: "Busy",
                            accent: ThemeManager.ember,
                            action: nil
                        )
                    }
                }
            }

            if !model.session.proposedBlocks.isEmpty {
                timelineSection(title: "Proposed schedule") {
                    ForEach(model.session.proposedBlocks) { block in
                        timelineRow(
                            title: block.title,
                            subtitle: "\(timeRange(block.startDate, block.endDate))\(block.detail.map { " • \($0)" } ?? "")",
                            tag: "Planned",
                            accent: theme.actionPrimary,
                            action: nil
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apply preview")
                .font(.headline)

            if model.session.previewOperations.isEmpty {
                Text("Once the planner has enough context, the final EventKit writes will show up here before anything is saved.")
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(model.session.previewOperations) { operation in
                    HStack(alignment: .top) {
                        Text(operation.operationType.rawValue.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.actionPrimary)
                            .frame(width: 58, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(operation.title)
                            Text(timeRange(operation.startDate, operation.endDate))
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    Task {
                        await model.applyPreview()
                    }
                } label: {
                    Text("Apply to planning calendar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.actionPrimary)
                .accessibilityIdentifier("planner.applyPreview")
            }
        }
        .padding(20)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func messageBubble(_ message: PlanningMessage, tone: BubbleTone) -> some View {
        Text(message.content)
            .font(.body)
            .foregroundStyle(tone == .user ? Color.white : theme.textPrimary)
            .padding(14)
            .background(tone == .user ? theme.actionPrimary : Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func timelineSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func timelineRow(
        title: String,
        subtitle: String,
        tag: String,
        accent: Color,
        action: (() -> Void)?
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            Text(tag)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(accent.opacity(0.16))
                .clipShape(Capsule())

            if let action {
                Button("Edit", action: action)
                    .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func processImportedFile(_ url: URL) {
        if ["wav", "m4a", "mp3", "aac"].contains(url.pathExtension.lowercased()) {
            Task {
                do {
                    let text = try await transcriberService.transcribe(audioURL: url)
                    model.ingestCapturedText(text)
                } catch {
                    model.errorMessage = error.localizedDescription
                }
            }
            return
        }

        if let text = try? String(contentsOf: url, encoding: .utf8) {
            model.ingestCapturedText(text)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .complete, time: .omitted)
    }

    private func timeRange(_ start: Date, _ end: Date) -> String {
        "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }

    private var isPlanDayDisabled: Bool {
        let currentDraft = draftManager.currentDraft?.content
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return currentDraft.isEmpty || model.isPlanning
    }
}

private enum BubbleTone {
    case user
    case assistant
}
