import SwiftUI

struct StreakPillView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: FuelSpacing.xs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12))
                .foregroundStyle(FuelColors.flame)
            Text("\(streak)")
                .font(FuelType.caption)
                .foregroundStyle(FuelColors.ink)
        }
        .padding(.horizontal, FuelSpacing.md)
        .padding(.vertical, FuelSpacing.sm)
        .background(streak > 0 ? FuelColors.flame.opacity(0.1) : FuelColors.cloud)
        .clipShape(Capsule())
    }
}
