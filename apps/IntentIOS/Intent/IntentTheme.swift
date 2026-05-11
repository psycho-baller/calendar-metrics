//
//  IntentTheme.swift
//  Intent
//
//  Created by Codex on 2026-05-11.
//

import SwiftUI
import UIKit

enum IntentTheme {
    static let background = LinearGradient(
        colors: [
            Color(hex: "#081316"),
            Color(hex: "#0f2426"),
            Color(hex: "#1b1712")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let panel = Color.white.opacity(0.105)
    static let panelStrong = Color.white.opacity(0.16)
    static let border = Color.white.opacity(0.14)
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#afbab7")
    static let accent = Color(hex: "#6FDCC4")
    static let mint = Color(hex: "#6FDCC4")
    static let amber = Color(hex: "#f2b84b")
    static let coral = Color(hex: "#ee6a55")
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
            (a, r, g, b) = (255, 255, 255, 255)
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

struct IntentPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(IntentTheme.border, lineWidth: 1)
            )
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let caption: String
    let systemImage: String
    let tint: Color

    var body: some View {
        IntentPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(IntentTheme.textPrimary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(IntentTheme.textPrimary.opacity(0.82))

                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(IntentTheme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }
}
