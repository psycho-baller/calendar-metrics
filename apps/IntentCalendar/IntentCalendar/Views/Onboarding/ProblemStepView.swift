import SwiftUI

// MARK: - Step 2: The Pain (Visual + Context)

struct ProblemStepView: View {
    var theme: AppTheme

    @State private var showContent = false
    @State private var showVisual = false
    @State private var showSteps = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // The visual metaphor: Ideas fading away
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        ThoughtBubble(
                            icon: ["lightbulb.fill", "star.fill", "bolt.fill"][index],
                            color: [theme.accent, Color(hex: "#FFD700"), Color(hex: "#FF6B6B")][index],
                            offset: CGSize(width: [-60, 60, 0][index], height: [-40, -30, 40][index]),
                            delay: Double(index) * 0.3
                        )
                    }
                }
                .frame(height: 140)
                .opacity(showVisual ? 1 : 0)

                // Headline
                VStack(spacing: 8) {
                    Text("Your best ideas")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)

                    Text("disappear before you can capture them.")
                        .font(.title3)
                        .foregroundColor(theme.textSecondary)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .opacity(showContent ? 1 : 0)

                // The friction journey - connected steps
                VStack(spacing: 0) {
                    frictionStep(
                        number: "1",
                        title: "Open the app",
                        subtitle: "Wait for it to load...",
                        icon: "hourglass",
                        isLast: false
                    )

                    frictionStep(
                        number: "2",
                        title: "Find the right note",
                        subtitle: "Scroll, search, navigate...",
                        icon: "magnifyingglass",
                        isLast: false
                    )

                    frictionStep(
                        number: "3",
                        title: "Type it out",
                        subtitle: "By now, the thought is gone.",
                        icon: "xmark.circle.fill",
                        isLast: true,
                        isNegative: true
                    )
                }
                .padding(.horizontal, 30)
                .opacity(showSteps ? 1 : 0)

                Spacer()

                NavigationLink(value: OnboardingStep.solution) {
                    Text("There's a better way")
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
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showVisual = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                showSteps = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
                showButton = true
            }
        }
    }

    private func frictionStep(number: String, title: String, subtitle: String, icon: String, isLast: Bool, isNegative: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Number circle
                ZStack {
                    Circle()
                        .fill(isNegative ? Color(hex: "#FF6B6B").opacity(0.2) : theme.accent.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isNegative ? Color(hex: "#FF6B6B") : theme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isNegative ? Color(hex: "#FF6B6B") : theme.textSecondary)
                }

                Spacer()
            }

            // Connector line
            if !isLast {
                HStack {
                    Rectangle()
                        .fill(theme.accent.opacity(0.2))
                        .frame(width: 2, height: 16)
                        .padding(.leading, 17)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Animated Thought Bubble

private struct ThoughtBubble: View {
    let icon: String
    let color: Color
    let offset: CGSize
    let delay: Double

    @State private var isVisible = false
    @State private var isFading = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 50, height: 50)
                .blur(radius: 8)

            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
        }
        .offset(offset)
        .opacity(isFading ? 0.3 : (isVisible ? 1 : 0))
        .scaleEffect(isVisible ? 1 : 0.5)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                isVisible = true
            }
            withAnimation(.easeInOut(duration: 2.5).delay(delay + 0.8).repeatForever(autoreverses: true)) {
                isFading = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProblemStepView(theme: ThemeManager.shared.currentTheme(for: .dark))
    }
}
