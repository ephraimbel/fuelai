import SwiftUI

enum FuelColors {
    // Primary
    static let flame = Color(hex: "#FF4D00")
    static let ink = Color(hex: "#1C1917")
    static let white = Color(hex: "#FFFBF7")

    static let onDark = Color(hex: "#FFFBF7")    // text/icons on dark backgrounds
    static let shadow = Color(hex: "#1C1917")    // shadow color (use with opacity)

    // Neutrals — warm tones
    static let cloud = Color(hex: "#F5F0EB")
    static let mist = Color(hex: "#E8E2DC")
    static let stone = Color(hex: "#8C8279")
    static let fog = Color(hex: "#C4BBB2")

    // Macro Colors
    static let protein = Color(hex: "#8B5CF6")
    static let carbs = Color(hex: "#F59E0B")
    static let fat = Color(hex: "#3B82F6")

    // Status
    static let success = Color(hex: "#22C55E")
    static let warning = Color(hex: "#F59E0B")
    static let over = Color(hex: "#EF4444")

    // Gradients
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

extension Color {
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
