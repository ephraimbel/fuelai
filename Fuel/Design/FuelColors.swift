import SwiftUI

enum FuelColors {
    // MARK: - Primary (same in both modes)
    static let flame = Color(hex: "#FF4D00")

    // MARK: - Adaptive Colors

    /// Main text color
    static let ink = Color.adaptive(light: "#1C1917", dark: "#F5F0EB")

    /// Always-dark surface for buttons and user bubbles (not for text)
    static let inkSurface = Color.adaptive(light: "#1C1917", dark: "#2A2725")

    /// App background — warm off-white / warm charcoal
    static let white = Color.adaptive(light: "#FFFBF7", dark: "#1C1A19")

    /// Text/icons on dark backgrounds (buttons, badges)
    static let onDark = Color(hex: "#FFFBF7")

    /// Button fill — ink in light, flame in dark
    static let buttonFill = Color.adaptive(light: "#1C1917", dark: "#FF4D00")

    /// Shadow base color
    static let shadow = Color(hex: "#1C1917")

    // MARK: - Neutrals

    /// Light surface — cloud / dark elevated surface
    static let cloud = Color.adaptive(light: "#F5F0EB", dark: "#2A2725")

    /// Subtle dividers/tracks
    static let mist = Color.adaptive(light: "#E8E2DC", dark: "#3A3633")

    /// Secondary text
    static let stone = Color.adaptive(light: "#8C8279", dark: "#9A9490")

    /// Tertiary/disabled
    static let fog = Color.adaptive(light: "#C4BBB2", dark: "#5A5552")

    // MARK: - Macro Colors (slightly brighter in dark mode for visibility)
    static let protein = Color.adaptive(light: "#8B5CF6", dark: "#A78BFA")
    static let carbs = Color.adaptive(light: "#F59E0B", dark: "#FBBF24")
    static let fat = Color.adaptive(light: "#3B82F6", dark: "#60A5FA")

    // MARK: - Micro Colors
    static let sugar = Color.adaptive(light: "#EC4899", dark: "#F472B6")
    static let sodium = Color.adaptive(light: "#F97316", dark: "#FB923C")

    // MARK: - Water
    static let water = Color.adaptive(light: "#06B6D4", dark: "#22D3EE")
    static let waterGradient = LinearGradient(
        colors: [Color(hex: "#06B6D4"), Color(hex: "#22D3EE")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Status
    static let success = Color.adaptive(light: "#22C55E", dark: "#4ADE80")
    static let warning = Color.adaptive(light: "#F59E0B", dark: "#FBBF24")
    static let over = Color.adaptive(light: "#EF4444", dark: "#F87171")

    // MARK: - Card & Page
    static let cardShadow = Color(hex: "#1C1917").opacity(0.06)
    static let cardBackground = Color.adaptive(light: "#F0EBE5", dark: "#252220")
    static let pageBackground = Color.adaptive(light: "#F5F0EB", dark: "#1C1A19")

    // MARK: - Page gradient
    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#FF4D00").opacity(0.03),
                Color.clear,
            ],
            startPoint: .top,
            endPoint: .init(x: 0.5, y: 0.4)
        )
    }

    // MARK: - Gradients
    static let flameGradient = LinearGradient(
        colors: [Color(hex: "#FF4D00"), Color(hex: "#FF6B2B")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let inkGradient = LinearGradient(
        colors: [Color(hex: "#1C1917"), Color(hex: "#292524")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Adaptive Color Helper

extension Color {
    /// Creates a color that adapts to light/dark mode using UIKit trait collection
    static func adaptive(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: dark))
                : UIColor(Color(hex: light))
        })
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
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
