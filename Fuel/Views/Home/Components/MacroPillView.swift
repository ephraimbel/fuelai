import SwiftUI

struct MacroPillView: View {
    let label: String
    let remaining: Double
    let target: Double
    let consumed: Double
    let color: Color
    let icon: String
    @State private var animatedProgress: Double = 0
    @State private var ringScale: Double = 1.0
    @State private var iconScale: Double = 1.0
    @State private var glowOpacity: Double = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return consumed / target
    }

    private var isOver: Bool { consumed > target }

    var body: some View {
        VStack(spacing: FuelSpacing.sm) {
            ZStack {
                // Glow layer
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .blur(radius: 8)
                    .opacity(glowOpacity)

                // Track
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 4)

                // Progress ring with gradient
                Circle()
                    .trim(from: 0, to: min(animatedProgress, 1))
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.4), color],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * min(animatedProgress, 1))
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.2), radius: 3, y: 1)

                // Center icon
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                    .scaleEffect(iconScale)
            }
            .frame(width: 42, height: 42)
            .scaleEffect(ringScale)

            // Consumed / target
            VStack(spacing: 1) {
                Text("\(Int(consumed))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(isOver ? FuelColors.over : FuelColors.ink)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: consumed)

                Text("/ \(Int(target))g")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FuelColors.fog)
            }

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(FuelColors.stone)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FuelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.card)
                .fill(FuelColors.cloud)
                .overlay(
                    RoundedRectangle(cornerRadius: FuelRadius.card)
                        .stroke(FuelColors.mist, lineWidth: 0.5)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(consumed))g of \(Int(target))g")
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.4)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            let increased = newValue > oldValue

            withAnimation(.spring(response: 0.9, dampingFraction: 0.5)) {
                animatedProgress = newValue
            }

            guard increased else { return }

            // Ring bounce
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                ringScale = 1.12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    ringScale = 1.0
                }
            }

            // Icon pop
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3).delay(0.05)) {
                iconScale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    iconScale = 1.0
                }
            }

            // Glow
            withAnimation(.easeIn(duration: 0.25)) {
                glowOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 1.0)) {
                    glowOpacity = 0
                }
            }
        }
    }
}
