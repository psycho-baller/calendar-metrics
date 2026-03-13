import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: IntentCalendarAppModel
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var vaultManager: VaultManager
    @ObservedObject private var transcriptionSettings = TranscriptionSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = KeychainManager.shared.getAPIKey() ?? ""
    @State private var isFolderImporterPresented = false

    init(model: IntentCalendarAppModel? = nil) {
        let resolvedModel = model ?? IntentCalendarAppModel(
            draftManager: DraftManager(),
            transcriberService: TranscriberService(),
            vaultManager: VaultManager(),
            settingsStore: AppSettingsStore()
        )
        _model = ObservedObject(wrappedValue: resolvedModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI") {
                    SecureField("OpenAI API key", text: $apiKey)
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
                }

                Section("Transcription") {
                    Picker("Model", selection: $transcriptionSettings.selectedModel) {
                        ForEach(TranscriptionModel.allCases) { model in
                            Text("\(model.displayName) • \(model.accuracyDescription)").tag(model)
                        }
                    }
                }

                Section("Calendar roles") {
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
                }

                Section("Obsidian Daily Notes") {
                    if let url = vaultManager.vaultURL {
                        Text(url.path)
                            .font(.caption)
                    }

                    Button(vaultManager.isVaultConfigured ? "Change Daily Notes folder" : "Choose Daily Notes folder") {
                        isFolderImporterPresented = true
                    }

                    if vaultManager.isVaultConfigured {
                        Button("Disconnect folder", role: .destructive) {
                            vaultManager.reset()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        KeychainManager.shared.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                vaultManager.setVaultFolder(url)
            }
        }
    }
}
