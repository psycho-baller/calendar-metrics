import SwiftUI

// MARK: - Step 3: The Solution (Visual Transformation)

struct SolutionStepView: View {
    var theme: AppTheme

    @State private var showBefore = false
    @State private var showArrow = false
    @State private var showAfter = false
    @State private var showFlow = false
    @State private var showButton = false

    var body: some View {
        ZStack {
            theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 25) {
                Spacer()

                // Before → After Visual
                HStack(spacing: 24) {
                    // Before
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#FF6B6B").opacity(0.15))
                                .frame(width: 70, height: 70)

                            Image(systemName: "brain")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                        }

                        Text("Scattered")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.textSecondary)
                    }
                    .opacity(showBefore ? 1 : 0)
                    .offset(x: showBefore ? 0 : -15)

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.accent)
                        .opacity(showArrow ? 1 : 0)
                        .scaleEffect(showArrow ? 1 : 0.5)

                    // After
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#4CD964").opacity(0.15))
                                .frame(width: 70, height: 70)

                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "#4CD964"))
                        }

                        Text("Organized")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.textSecondary)
                    }
                    .opacity(showAfter ? 1 : 0)
                    .offset(x: showAfter ? 0 : 15)
                }

                // Headline
                VStack(spacing: 8) {
                    Text("You Speak. We organize.")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)

                    Text("Your voice goes straight to your daily note,\nin exactly the right place.")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .opacity(showAfter ? 1 : 0)

                // The flow
                VStack(spacing: 0) {
                    flowStep(icon: "waveform", title: "You speak", subtitle: "No typing required", color: theme.accent, isLast: false)
                    flowStep(icon: "text.alignleft", title: "Instant transcription", subtitle: "On-device, private", color: Color(hex: "#5AC8FA"), isLast: false)
                    flowStep(icon: "doc.badge.gearshape", title: "AI finds the right spot", subtitle: "Matches your template", color: Color(hex: "#FFD700"), isLast: false)
                    flowStep(icon: "checkmark.circle.fill", title: "Saved to your vault", subtitle: "Never forget any important thought", color: Color(hex: "#4CD964"), isLast: true)
                }
                .padding(.horizontal, 30)
                .opacity(showFlow ? 1 : 0)

                Spacer()

                NavigationLink(value: OnboardingStep.features) {
                    Text("See it in action")
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
            withAnimation(.easeOut(duration: 0.4)) {
                showBefore = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
                showArrow = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
                showAfter = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showFlow = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.9)) {
                showButton = true
            }
        }
    }

    private func flowStep(icon: String, title: String, subtitle: String, color: Color, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.textPrimary)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()
            }

            if !isLast {
                HStack {
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(width: 2, height: 12)
                        .padding(.leading, 18)
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SolutionStepView(theme: ThemeManager.shared.currentTheme(for: .dark))
    }
}
