import SwiftUI

// MARK: - Star Model
struct Star: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let initialOpacity: Double
    let twinkleDuration: Double
    let delay: Double
}

// MARK: - Shooting Star Data
struct ShootingStarData: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let duration: Double
}

// MARK: - Starfield Background View
struct StarfieldView: View {
    let starCount: Int
    let showShootingStars: Bool

    @State private var stars: [Star] = []
    @State private var shootingStar: ShootingStarData?
    @State private var screenSize: CGSize = .zero

    init(starCount: Int = 40, showShootingStars: Bool = true) {
        self.starCount = starCount
        self.showShootingStars = showShootingStars
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Twinkling stars layer
                ForEach(stars) { star in
                    TwinklingStar(star: star)
                }

                // Shooting star layer
                if let star = shootingStar {
                    AnimatedShootingStar(data: star) {
                        // Cleanup and schedule next
                        shootingStar = nil
                        scheduleNextShootingStar()
                    }
                }
            }
            .onAppear {
                // Wait a brief moment for geometry to settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if geometry.size.width > 0 && geometry.size.height > 0 {
                        screenSize = geometry.size
                        generateStars(in: geometry.size)
                        if showShootingStars {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2...4)) {
                                triggerShootingStar()
                            }
                        }
                    }
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                // Regenerate stars if size changes significantly (initial layout)
                if newSize.width > 0 && newSize.height > 0 {
                    let sizeChanged = abs(screenSize.width - newSize.width) > 10 || abs(screenSize.height - newSize.height) > 10
                    if stars.isEmpty || sizeChanged {
                        screenSize = newSize
                        generateStars(in: newSize)
                    }
                }
            }
        }
    }

    private func generateStars(in size: CGSize) {
        stars = (0..<starCount).map { _ in
            Star(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 1.5...3.5),
                initialOpacity: Double.random(in: 0.3...0.8),
                twinkleDuration: Double.random(in: 1.5...4.0),
                delay: Double.random(in: 0...3.0)
            )
        }
    }

    private func scheduleNextShootingStar() {
        let delay = Double.random(in: 4...7)  // Reduced from 5-9s for 25% more frequent
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            triggerShootingStar()
        }
    }

    private func triggerShootingStar() {
        guard screenSize.width > 0 else { return }

        // Start from upper portion, travel diagonally down-right
        let startX = CGFloat.random(in: screenSize.width * 0.1...screenSize.width * 0.5)
        let startY = CGFloat.random(in: 0...screenSize.height * 0.25)

        // Travel distance
        let travelX = CGFloat.random(in: 150...250)
        let travelY = CGFloat.random(in: 100...180)

        shootingStar = ShootingStarData(
            startX: startX,
            startY: startY,
            endX: startX + travelX,
            endY: startY + travelY,
            duration: Double.random(in: 0.8...1.2)
        )
    }
}

// MARK: - Animated Shooting Star with Trail
struct AnimatedShootingStar: View {
    let data: ShootingStarData
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var opacity: Double = 0

    private var currentX: CGFloat {
        data.startX + (data.endX - data.startX) * progress
    }

    private var currentY: CGFloat {
        data.startY + (data.endY - data.startY) * progress
    }

    var body: some View {
        ZStack {
            // Trail effect using multiple fading circles
            ForEach(0..<8, id: \.self) { i in
                let trailProgress = max(0, progress - CGFloat(i) * 0.04)
                let trailX = data.startX + (data.endX - data.startX) * trailProgress
                let trailY = data.startY + (data.endY - data.startY) * trailProgress
                let trailOpacity = Double(8 - i) / 10.0
                let trailSize = CGFloat(4 - i / 3)

                Circle()
                    .fill(Color.white)
                    .frame(width: trailSize, height: trailSize)
                    .blur(radius: CGFloat(i) * 0.3)
                    .opacity(trailOpacity * opacity)
                    .position(x: trailX, y: trailY)
            }

            // Bright head of shooting star
            Circle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
                .blur(radius: 0.5)
                .shadow(color: .white, radius: 3)
                .opacity(opacity)
                .position(x: currentX, y: currentY)
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Fade in quickly
        withAnimation(.easeIn(duration: 0.1)) {
            opacity = 1.0
        }

        // Animate movement
        withAnimation(.easeOut(duration: data.duration)) {
            progress = 1.0
        }

        // Fade out near end
        DispatchQueue.main.asyncAfter(deadline: .now() + data.duration * 0.7) {
            withAnimation(.easeOut(duration: data.duration * 0.3)) {
                opacity = 0
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + data.duration + 0.1) {
            onComplete()
        }
    }
}

// MARK: - Individual Twinkling Star
struct TwinklingStar: View {
    let star: Star
    @State private var opacity: Double = 0.3

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: star.size, height: star.size)
            .opacity(opacity)
            .blur(radius: star.size > 2.5 ? 0.5 : 0)
            .position(x: star.x, y: star.y)
            .onAppear {
                // Delay start of animation for each star
                DispatchQueue.main.asyncAfter(deadline: .now() + star.delay) {
                    withAnimation(
                        .easeInOut(duration: star.twinkleDuration)
                        .repeatForever(autoreverses: true)
                    ) {
                        opacity = star.initialOpacity
                    }
                }
            }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "#0c1445"), Color(hex: "#2c1e5e")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        StarfieldView()
    }
}
