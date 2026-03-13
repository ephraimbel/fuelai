import SwiftUI

enum FuelSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let section: CGFloat = 40
}

enum FuelRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 22
    static let card: CGFloat = 22
    static let full: CGFloat = 999
}

// MARK: - 3D Card Modifier

struct FuelCard: ViewModifier {
    var radius: CGFloat = FuelRadius.card
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(FuelColors.cardBackground)
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color(hex: "#1C1917").opacity(0.06),
                        radius: colorScheme == .dark ? 4 : 8,
                        y: colorScheme == .dark ? 2 : 3
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.clear
                            : Color(hex: "#1C1917").opacity(0.02),
                        radius: 1, y: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

extension View {
    func fuelCard(radius: CGFloat = FuelRadius.card) -> some View {
        modifier(FuelCard(radius: radius))
    }
}
