import SwiftUI

struct AppTheme {
    let backgroundGradient: LinearGradient
    let cardBackground: Color
    let textPrimary: Color
    let textSecondary: Color
    let accent: Color
    let success: Color
    let warning: Color
    let actionPrimary: Color
    let actionSecondary: Color
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    static let scheduleBlue = Color(hex: "#9CEBD6")
    static let sunriseGold = Color(hex: "#F4B942")
    static let ember = scheduleBlue
    static let obsidianPurple = scheduleBlue

    private static let nightTheme = AppTheme(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#07191C"),
                Color(hex: "#0E2E2A"),
                Color(hex: "#173D36")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardBackground: Color(hex: "#0C2724").opacity(0.88),
        textPrimary: .white,
        textSecondary: Color(hex: "#B7D9D0"),
        accent: scheduleBlue,
        success: Color(hex: "#7BD389"),
        warning: sunriseGold,
        actionPrimary: scheduleBlue,
        actionSecondary: Color(hex: "#17423B")
    )

    private static let lightTheme = AppTheme(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#F2FFFB"),
                Color(hex: "#E4F8F2"),
                Color(hex: "#D4F2EA")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardBackground: Color.white.opacity(0.92),
        textPrimary: Color(hex: "#123630"),
        textSecondary: Color(hex: "#50736A"),
        accent: scheduleBlue,
        success: Color(hex: "#2A9D8F"),
        warning: sunriseGold,
        actionPrimary: scheduleBlue,
        actionSecondary: Color.white.opacity(0.76)
    )

    enum ThemeMode: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }
    }

    @AppStorage("IntentCalendarThemeMode") var themeMode: ThemeMode = .system {
        didSet { objectWillChange.send() }
    }

    var themeColor: Color {
        Self.scheduleBlue
    }

    func currentTheme(for scheme: ColorScheme) -> AppTheme {
        switch themeMode {
        case .light:
            return Self.lightTheme
        case .dark:
            return Self.nightTheme
        case .system:
            return scheme == .dark ? Self.nightTheme : Self.lightTheme
        }
    }

    var colorScheme: ColorScheme? {
        switch themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
