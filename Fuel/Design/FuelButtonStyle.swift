import SwiftUI

struct FuelPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FuelType.cardTitle)
            .foregroundStyle(FuelColors.onDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FuelSpacing.lg)
            .background(FuelColors.ink)
            .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(FuelAnimation.quick, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FuelPrimaryButtonStyle {
    static var fuelPrimary: FuelPrimaryButtonStyle { FuelPrimaryButtonStyle() }
}
