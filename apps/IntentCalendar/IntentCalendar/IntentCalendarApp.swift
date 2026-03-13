import SwiftUI

@main
struct IntentCalendarApp: App {
    @StateObject private var draftManager: DraftManager
    @StateObject private var transcriberService: TranscriberService
    @StateObject private var vaultManager: VaultManager
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var model: IntentCalendarAppModel

    init() {
        let draftManager = DraftManager()
        let transcriberService = TranscriberService()
        let vaultManager = VaultManager()
        let settingsStore = AppSettingsStore()
        let model = IntentCalendarAppModel(
            draftManager: draftManager,
            transcriberService: transcriberService,
            vaultManager: vaultManager,
            settingsStore: settingsStore
        )

        _draftManager = StateObject(wrappedValue: draftManager)
        _transcriberService = StateObject(wrappedValue: transcriberService)
        _vaultManager = StateObject(wrappedValue: vaultManager)
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(ThemeManager.scheduleBlue)
                .environmentObject(draftManager)
                .environmentObject(transcriberService)
                .environmentObject(vaultManager)
                .environmentObject(settingsStore)
                .onOpenURL { url in
                    handleOpenURL(url)
                }
                .task {
                    model.start()
                }
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        if let content = components.queryItems?.first(where: { $0.name == "content" })?.value {
            model.ingestCapturedText(content)
            return
        }

        if url.host == "transcribe-audio",
           let filename = components.queryItems?.first(where: { $0.name == "file" })?.value {
            Task {
                await model.handleSharedAudio(filename: filename)
            }
            return
        }

        if url.host == "open-shared" {
            Task {
                await model.consumeSharedPayloadIfNeeded()
            }
        }
    }
}
