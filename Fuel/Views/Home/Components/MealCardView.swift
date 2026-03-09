import SwiftUI

struct MealCardView: View {
    let meal: Meal
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var showingDelete = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            if showingDelete {
                Button {
                    withAnimation { onDelete() }
                } label: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(FuelColors.onDark)
                        .frame(width: 60)
                }
                .frame(maxHeight: .infinity)
                .frame(width: 60)
                .background(FuelColors.over)
                .clipShape(RoundedRectangle(cornerRadius: FuelRadius.card))
            }

            // Card content
            HStack(spacing: FuelSpacing.md) {
                // Photo thumbnail
                if let imageUrl = meal.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        FuelColors.mist
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                } else {
                    RoundedRectangle(cornerRadius: FuelRadius.md)
                        .fill(FuelColors.mist)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20))
                                .foregroundStyle(FuelColors.fog)
                        )
                }

                // Info
                VStack(alignment: .leading, spacing: FuelSpacing.xs) {
                    Text(meal.displayName)
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.ink)
                        .lineLimit(1)

                    HStack(spacing: FuelSpacing.xs) {
                        Text("\(meal.totalCalories) cal")
                            .font(FuelType.label)
                            .foregroundStyle(FuelColors.ink)
                            .contentTransition(.numericText())
                    }

                    // Macro dots
                    HStack(spacing: FuelSpacing.sm) {
                        MacroDot(color: FuelColors.protein, value: "\(Int(meal.totalProtein))g")
                        MacroDot(color: FuelColors.carbs, value: "\(Int(meal.totalCarbs))g")
                        MacroDot(color: FuelColors.fat, value: "\(Int(meal.totalFat))g")
                    }
                }

                Spacer()

                // Timestamp
                Text(meal.loggedAt.timeString)
                    .font(FuelType.micro)
                    .foregroundStyle(FuelColors.fog)
            }
            .padding(FuelSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: FuelRadius.card)
                    .fill(FuelColors.cloud)
                    .overlay(
                        RoundedRectangle(cornerRadius: FuelRadius.card)
                            .stroke(FuelColors.mist, lineWidth: 0.5)
                    )
            )
            .offset(x: offset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(meal.displayName), \(meal.totalCalories) calories. Protein \(Int(meal.totalProtein))g, Carbs \(Int(meal.totalCarbs))g, Fat \(Int(meal.totalFat))g")
            .accessibilityAction(named: "Delete") { onDelete() }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(FuelAnimation.snappy) {
                            if value.translation.width < -60 {
                                offset = -70
                                showingDelete = true
                            } else {
                                offset = 0
                                showingDelete = false
                            }
                        }
                    }
            )
        }
    }
}

private struct MacroDot: View {
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(value)
                .font(FuelType.micro)
                .foregroundStyle(FuelColors.stone)
        }
    }
}
