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

    static let scheduleBlue = Color(hex: "#1768AC")
    static let sunriseGold = Color(hex: "#F4B942")
    static let ember = Color(hex: "#D8572A")
    static let obsidianPurple = scheduleBlue

    private static let nightTheme = AppTheme(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#10212F"),
                Color(hex: "#203A43"),
                Color(hex: "#2C5364")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardBackground: Color(hex: "#11293A").opacity(0.88),
        textPrimary: .white,
        textSecondary: Color(hex: "#A8C5D6"),
        accent: sunriseGold,
        success: Color(hex: "#7BD389"),
        warning: sunriseGold,
        actionPrimary: scheduleBlue,
        actionSecondary: Color(hex: "#21455F")
    )

    private static let lightTheme = AppTheme(
        backgroundGradient: LinearGradient(
            colors: [
                Color(hex: "#FFF7E8"),
                Color(hex: "#F8EDE3"),
                Color(hex: "#E3F2FD")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        cardBackground: Color.white.opacity(0.92),
        textPrimary: Color(hex: "#183642"),
        textSecondary: Color(hex: "#5C7285"),
        accent: ember,
        success: Color(hex: "#2A9D8F"),
        warning: sunriseGold,
        actionPrimary: ember,
        actionSecondary: Color.white.opacity(0.7)
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
