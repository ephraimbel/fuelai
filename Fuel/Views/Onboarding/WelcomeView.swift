import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void
    @State private var appeared = false

    private let rows: [[String]] = [
        ["food_01", "food_02", "food_03", "food_04"],
        ["food_05", "food_06", "food_07", "food_08"],
        ["food_09", "food_10", "food_11", "food_12"],
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: FuelSpacing.section)

            // Logo + brand
            Image("FuelLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.9)
            .animation(FuelAnimation.spring.delay(0.1), value: appeared)

            Spacer().frame(height: FuelSpacing.xl)

            // Title
            VStack(spacing: FuelSpacing.md) {
                VStack(spacing: 2) {
                    Text("Track smarter.")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(FuelColors.ink)
                    Text("Eat better.")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(FuelColors.flame)
                }
                .multilineTextAlignment(.center)

                Text(Constants.appTagline)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FuelSpacing.xxl)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(FuelAnimation.spring.delay(0.3), value: appeared)

            Spacer().frame(height: FuelSpacing.xxl)

            // Scrolling food carousel — overlay so wide HStack doesn't expand parent layout
            Color.clear
                .frame(height: 300)
                .overlay {
                    VStack(spacing: FuelSpacing.sm) {
                        ForEach(0..<3, id: \.self) { rowIndex in
                            InfiniteScrollRow(
                                images: rows[rowIndex],
                                direction: rowIndex == 1 ? .right : .left,
                                speed: 25,
                                offset: rowIndex == 1 ? -40 : CGFloat(rowIndex * 20)
                            )
                        }
                    }
                }
                .clipped()
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.05),
                            .init(color: .black, location: 0.95),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(appeared ? 1 : 0)
                .animation(FuelAnimation.spring.delay(0.5), value: appeared)

            Spacer()

            // Button
            Button {
                FuelHaptics.shared.send()
                FuelSounds.shared.swoosh()
                onContinue()
            } label: {
                Text("Get Started")
                    .font(FuelType.cardTitle)
                    .foregroundStyle(FuelColors.onDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FuelSpacing.lg)
                    .background(FuelColors.ink)
                    .clipShape(RoundedRectangle(cornerRadius: FuelRadius.md))
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.bottom, FuelSpacing.lg)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(FuelAnimation.spring.delay(0.8), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FuelColors.white)
        .onAppear { appeared = true }
    }
}

// MARK: - Infinite Scroll Row

private struct InfiniteScrollRow: View {
    let images: [String]
    let direction: Direction
    let speed: Double
    let offset: CGFloat

    enum Direction { case left, right }

    @State private var scrollOffset: CGFloat = 0

    private let tileSize: CGFloat = 92
    private let spacing: CGFloat = 10

    // Width of one full set of images
    private var setWidth: CGFloat {
        CGFloat(images.count) * (tileSize + spacing)
    }

    var body: some View {
        // 3 copies ensures seamless looping at any screen width
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { _ in
                ForEach(images, id: \.self) { name in
                    Image(name)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: tileSize, height: tileSize)
                        .clipShape(RoundedRectangle(cornerRadius: FuelRadius.lg))
                }
            }
        }
        .offset(x: scrollOffset + offset)
        .onAppear {
            // Start already shifted so tiles fill the screen
            let initial: CGFloat = direction == .left ? 0 : -setWidth
            scrollOffset = initial

            let target = direction == .left ? -setWidth : 0
            let duration = setWidth / speed

            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                scrollOffset = target
            }
        }
    }
}
