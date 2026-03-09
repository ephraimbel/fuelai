import SwiftUI

enum FuelType {
    // Serif headings (New York) — warm, editorial, CALORIQ-inspired
    static let hero = Font.system(size: 40, weight: .bold, design: .serif)
    static let title = Font.system(size: 28, weight: .bold, design: .serif)
    static let stat = Font.system(size: 22, weight: .semibold, design: .serif)
    static let section = Font.system(size: 17, weight: .semibold, design: .serif)

    // Sans-serif body (SF Pro) — clean, readable
    static let cardTitle = Font.system(size: 15, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let label = Font.system(size: 13, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .regular, design: .default)
    static let micro = Font.system(size: 11, weight: .medium, design: .default)

    // Icon tokens — consistent sizing for SF Symbols
    static let iconLg = Font.system(size: 20, weight: .semibold)
    static let iconMd = Font.system(size: 16, weight: .medium)
    static let iconSm = Font.system(size: 14, weight: .medium)
    static let iconXs = Font.system(size: 12, weight: .semibold)
    static let badgeMicro = Font.system(size: 10, weight: .bold)
}
