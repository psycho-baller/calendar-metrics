import SwiftUI

struct OnboardingContainerView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @ObservedObject var vaultManager: VaultManager
    @Environment(\.colorScheme) var colorScheme

    @State private var path: [OnboardingStep] = []

    var theme: AppTheme {
        themeManager.currentTheme(for: colorScheme)
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStepView(theme: theme)
                .navigationDestination(for: OnboardingStep.self) { step in
                    destinationView(for: step)
                }
        }
        .tint(theme.accent)
        .preferredColorScheme(themeManager.colorScheme)
    }

    @ViewBuilder
    private func destinationView(for step: OnboardingStep) -> some View {
        switch step {
        case .problem:
            ProblemStepView(theme: theme)
        case .solution:
            SolutionStepView(theme: theme)
        case .features:
            FeaturesStepView(theme: theme)
        case .vaultPicker:
            VaultPickerStepView(theme: theme, vaultManager: vaultManager)
        }
    }
}

#Preview {
    OnboardingContainerView(vaultManager: VaultManager())
}
