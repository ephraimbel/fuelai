import SwiftUI

struct StreakPillView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: FuelSpacing.xs) {
            Text("\(streak)")
                .font(FuelType.caption.weight(.semibold))
                .foregroundStyle(streak > 0 ? FuelColors.ink : FuelColors.fog)
            Text(streak == 1 ? "day" : "days")
                .font(FuelType.micro)
                .foregroundStyle(FuelColors.fog)
        }
        .padding(.horizontal, FuelSpacing.md)
        .padding(.vertical, FuelSpacing.sm)
        .background(streak > 0 ? FuelColors.flame.opacity(0.08) : FuelColors.cloud)
        .clipShape(Capsule())
    }
}
