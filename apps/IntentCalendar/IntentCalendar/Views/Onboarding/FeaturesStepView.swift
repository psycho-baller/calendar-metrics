import SwiftUI

// MARK: - Step 4: Features (Visual Demo)

struct FeaturesStepView: View {
    var theme: AppTheme

    @State private var showContent = false
    @State private var currentExample = 0
    @State private var showButton = false

    private let examples: [(voice: String, result: String, icon: String, color: Color)] = [
        ("\"I slept 7 hours\"", "Sleep: 7", "moon.fill", Color(hex: "#5AC8FA")),
        ("\"Call Mom tomorrow\"", "- [ ] Call Mom", "checkmark.circle", Color(hex: "#4CD964")),
        ("\"Feeling grateful for...\"", "## Gratitude\n- ...", "heart.fill", Color(hex: "#FF6B6B"))
    ]

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Headline
                Text("It understands your template")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)

                // Animated example card
                TabView(selection: $currentExample) {
                    ForEach(0..<examples.count, id: \.self) { index in
                        exampleCard(example: examples[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 200)
                .opacity(showContent ? 1 : 0)

                // The promise
                HStack(spacing: 20) {
                    promiseBadge(icon: "lock.shield.fill", text: "Private")
                    promiseBadge(icon: "bolt.fill", text: "Instant")
                    promiseBadge(icon: "doc.text", text: "Your files")
                }
                .opacity(showContent ? 1 : 0)

                Spacer()

                NavigationLink(value: OnboardingStep.vaultPicker) {
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
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showButton = true
            }
        }
    }

    private func exampleCard(example: (voice: String, result: String, icon: String, color: Color)) -> some View {
        VStack(spacing: 20) {
            // Voice input
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundColor(theme.accent)
                Text(example.voice)
                    .font(.body)
                    .foregroundColor(theme.textSecondary)
                    .italic()
            }

            // Arrow
            Image(systemName: "arrow.down")
                .font(.caption)
                .foregroundColor(theme.textSecondary.opacity(0.5))

            // Result in template
            HStack(spacing: 12) {
                Image(systemName: example.icon)
                    .font(.system(size: 20))
                    .foregroundColor(example.color)

                Text(example.result)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(theme.textPrimary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(example.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(example.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardBackground)
        )
    }

    private func promiseBadge(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#4CD964"))

            Text(text)
                .font(.caption2)
                .foregroundColor(theme.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        FeaturesStepView(theme: ThemeManager.shared.currentTheme(for: .dark))
    }
}
