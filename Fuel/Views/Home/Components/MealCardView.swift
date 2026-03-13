import SwiftUI

struct MealCardView: View {
    let meal: Meal
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    @State private var showingDelete = false

    /// Check for locally cached image first (available instantly after logging)
    private var localImage: UIImage? {
        let path = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("meal-images")
            .appendingPathComponent("\(meal.id.uuidString).jpg")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

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
                // Photo thumbnail — local cache first, then remote URL, then placeholder
                if let local = localImage {
                    Image(uiImage: local)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
                } else if let imageUrl = meal.imageUrl, let url = URL(string: imageUrl) {
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
                            .font(FuelType.labelNum)
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
            .fuelCard()
            .offset(x: offset)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(meal.displayName), \(meal.totalCalories) calories. Protein \(Int(meal.totalProtein))g, Carbs \(Int(meal.totalCarbs))g, Fat \(Int(meal.totalFat))g")
            .accessibilityAction(named: "Delete") { onDelete() }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if showingDelete {
                            // Allow dragging back to dismiss delete button
                            offset = min(0, -70 + value.translation.width)
                        } else if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(FuelAnimation.snappy) {
                            if showingDelete {
                                // If swiped right enough, dismiss delete
                                if value.translation.width > 30 {
                                    offset = 0
                                    showingDelete = false
                                } else {
                                    offset = -70
                                }
                            } else if value.translation.width < -60 {
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
                .font(FuelType.microNum)
                .foregroundStyle(FuelColors.stone)
        }
    }
}
