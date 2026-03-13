import SwiftUI

struct ContentView: View {
    @ObservedObject var model: IntentCalendarAppModel
    @EnvironmentObject private var transcriberService: TranscriberService

    var body: some View {
        ZStack {
            if model.shouldShowOnboarding {
                OnboardingView(model: model)
            } else {
                MainPlannerView(model: model)
            }

            if transcriberService.isTranscribing || model.isPlanning || model.isApplying {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    ProgressView()
                        .scaleEffect(1.25)
                        .tint(.white)

                    Text(overlayTitle)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(28)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(radius: 14)
            }
        }
        .alert("IntentCalendar", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.errorMessage = nil
                }
            }
        )) {
            if !model.shouldShowOnboarding && model.currentErrorNeedsSettingsShortcut {
                Button("Open Settings") {
                    model.showingSettings = true
                    model.errorMessage = nil
                }
            }

            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var overlayTitle: String {
        if transcriberService.isTranscribing {
            return "Transcribing capture..."
        }
        if model.isApplying {
            return "Writing to your calendar..."
        }
        return "Planning your day..."
    }
}

#Preview {
    let draftManager = DraftManager()
    let transcriberService = TranscriberService()
    let vaultManager = VaultManager()
    let settingsStore = AppSettingsStore()

    ContentView(
        model: IntentCalendarAppModel(
            draftManager: draftManager,
            transcriberService: transcriberService,
            vaultManager: vaultManager,
            settingsStore: settingsStore
        )
    )
    .environmentObject(draftManager)
    .environmentObject(transcriberService)
    .environmentObject(vaultManager)
    .environmentObject(settingsStore)
}
