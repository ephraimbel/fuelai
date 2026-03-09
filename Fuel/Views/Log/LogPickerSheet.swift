import SwiftUI

struct LogPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: FuelSpacing.md) {
            Text("Log Food")
                .font(FuelType.section)
                .foregroundStyle(FuelColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, FuelSpacing.lg)

            pickerCard(
                icon: "camera.fill",
                title: "Scan Food",
                subtitle: "Take a photo of your meal",
                accent: FuelColors.flame,
                mode: .camera
            )

            pickerCard(
                icon: "magnifyingglass",
                title: "Search Food",
                subtitle: "Type what you ate",
                accent: FuelColors.ink,
                mode: .search
            )

            pickerCard(
                icon: "barcode.viewfinder",
                title: "Scan Barcode",
                subtitle: "Scan a product barcode",
                accent: FuelColors.ink,
                mode: .barcode
            )

            Spacer()
        }
        .padding(.horizontal, FuelSpacing.xl)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }

    private func pickerCard(icon: String, title: String, subtitle: String, accent: Color, mode: LogMode) -> some View {
        Button {
            FuelHaptics.shared.tap()
            appState.selectedLogMode = mode
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                appState.showingLogFlow = true
            }
        } label: {
            HStack(spacing: FuelSpacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: FuelRadius.sm)
                        .fill(accent.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(FuelType.iconLg)
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FuelType.cardTitle)
                        .foregroundStyle(FuelColors.ink)

                    Text(subtitle)
                        .font(FuelType.caption)
                        .foregroundStyle(FuelColors.stone)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(FuelType.iconSm)
                    .foregroundStyle(FuelColors.fog)
            }
            .padding(FuelSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: FuelRadius.card)
                    .fill(FuelColors.cloud)
            )
        }
    }
}
