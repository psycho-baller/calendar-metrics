import SwiftUI

// MARK: - Step 1: Welcome

struct WelcomeStepView: View {
    var theme: AppTheme

    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showBadges = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 35) {
                Spacer()

                // Ignite Logo (Flame)
                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .blur(radius: 40)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#FF6B6B"), Color(hex: "#FFD700")], // Flame colors
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .opacity(showLogo ? 1 : 0)
                .scaleEffect(showLogo ? 1 : 0.8)

                // Headlines
                VStack(spacing: 12) {
                    Text("Ignite")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(theme.textPrimary)

                    Text("Speak your mind.")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)

                    Text("We'll handle the rest.")
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                }
                .multilineTextAlignment(.center)
                .opacity(showTitle ? 1 : 0)

                // Subtitle explanation
                Text("Voice-to-vault journaling for Obsidian.\nCapture thoughts instantly, organized automatically.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showSubtitle ? 1 : 0)

                // Trust badges
                HStack(spacing: 30) {
                    trustBadge(icon: "lock.shield.fill", label: "Private", sublabel: "Stays on device")
                    trustBadge(icon: "mic.fill", label: "Voice-first", sublabel: "Type if you want")
                    trustBadge(icon: "sparkles", label: "Personalized", sublabel: "Learns your template")
                }
                .opacity(showBadges ? 1 : 0)

                Spacer()

                NavigationLink(value: OnboardingStep.problem) {
                    Text("Get started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.actionPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(30)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                .opacity(showButton ? 1 : 0)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showLogo = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
                showSubtitle = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                showBadges = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
                showButton = true
            }
        }
    }

    private func trustBadge(icon: String, label: String, sublabel: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(theme.accent)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(theme.textPrimary)

            Text(sublabel)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeStepView(theme: ThemeManager.shared.currentTheme(for: .dark))
    }
}
