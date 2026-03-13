import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @ObservedObject var model: IntentCalendarAppModel
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var vaultManager: VaultManager
    @ObservedObject private var transcriptionSettings = TranscriptionSettings.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var apiKey = KeychainManager.shared.getAPIKey() ?? ""
    @State private var isFolderImporterPresented = false

    private var theme: AppTheme {
        themeManager.currentTheme(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    permissionCard
                    calendarSelectionCard
                    obsidianCard
                    aiCard
                    continueButton
                }
                .padding(20)
            }
            .background(theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("IntentCalendar")
        }
        .preferredColorScheme(themeManager.colorScheme)
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                vaultManager.setVaultFolder(url)
            }
        }
        .task {
            await model.refreshCalendars()
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plan the day before the day starts planning you.")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(theme.textPrimary)

            Text("IntentCalendar turns a quick back-and-forth into a clean schedule. It reads your recurring day structure from a template calendar, asks for the missing pieces, and only writes to your planning calendar after you approve the preview.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var permissionCard: some View {
        OnboardingCard(title: "Calendar access", subtitle: "Required") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Status: \(model.calendarPermissionsManager.accessState.title)")
                    .foregroundStyle(theme.textSecondary)

                Button("Allow calendar access") {
                    Task {
                        await model.requestCalendarAccess()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.actionPrimary)
            }
        }
    }

    private var calendarSelectionCard: some View {
        OnboardingCard(title: "Calendar roles", subtitle: "Required") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Template calendar", selection: Binding(
                    get: { settingsStore.selectedTemplateCalendarID ?? "" },
                    set: { settingsStore.selectedTemplateCalendarID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Choose one").tag("")
                    ForEach(model.availableCalendars) { calendar in
                        Text(calendar.title).tag(calendar.id)
                    }
                }

                Picker("Planning calendar", selection: Binding(
                    get: { settingsStore.selectedPlanningCalendarID ?? "" },
                    set: { settingsStore.selectedPlanningCalendarID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Choose one").tag("")
                    ForEach(model.availableCalendars.filter(\.allowsContentModifications)) { calendar in
                        Text(calendar.title).tag(calendar.id)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Constraint calendars")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)

                    ForEach(model.availableCalendars) { calendar in
                        Toggle(
                            isOn: Binding(
                                get: { settingsStore.selectedConstraintCalendarIDs.contains(calendar.id) },
                                set: { isOn in
                                    var ids = settingsStore.selectedConstraintCalendarIDs
                                    if isOn {
                                        ids.append(calendar.id)
                                    } else {
                                        ids.removeAll { $0 == calendar.id }
                                    }
                                    settingsStore.selectedConstraintCalendarIDs = Array(Set(ids))
                                }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.title)
                                Text(calendar.source)
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        .tint(theme.actionPrimary)
                    }
                }
            }
        }
    }

    private var obsidianCard: some View {
        OnboardingCard(title: "Obsidian Daily Notes", subtitle: "Optional") {
            VStack(alignment: .leading, spacing: 12) {
                Text(vaultManager.isVaultConfigured ? "Connected to \(vaultManager.vaultURL?.lastPathComponent ?? "Daily Notes")" : "Use today and recent daily notes as planning context. IntentCalendar reads them, but never writes back in v1.")
                    .foregroundStyle(theme.textSecondary)

                Button(vaultManager.isVaultConfigured ? "Change folder" : "Choose Daily Notes folder") {
                    isFolderImporterPresented = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var aiCard: some View {
        OnboardingCard(title: "AI + transcription", subtitle: "Required for planner") {
            VStack(alignment: .leading, spacing: 12) {
                SecureField("OpenAI API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Picker("Planner model", selection: Binding(
                    get: { settingsStore.plannerModel },
                    set: { settingsStore.plannerModel = $0 }
                )) {
                    ForEach(PlannerModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                Picker("Transcription", selection: $transcriptionSettings.selectedModel) {
                    ForEach(TranscriptionModel.allCases) { model in
                        Text("\(model.displayName) • \(model.accuracyDescription)").tag(model)
                    }
                }

                Text("Default cloud transcription uses gpt-4o-mini-transcribe. You can switch to local WhisperKit models later.")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var continueButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    await model.finishOnboarding(apiKey: apiKey)
                }
            } label: {
                Text("Start planning")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.actionPrimary)
            .disabled(!canContinue)
        }
    }

    private var canContinue: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        settingsStore.selectedTemplateCalendarID != nil &&
        settingsStore.selectedPlanningCalendarID != nil &&
        model.calendarPermissionsManager.accessState == .fullAccess
    }
}

private struct OnboardingCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            content
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
