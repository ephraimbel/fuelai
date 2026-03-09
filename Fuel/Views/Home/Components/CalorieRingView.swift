import SwiftUI

struct CalorieRingView: View {
    let progress: Double
    var size: CGFloat = 72
    var lineWidth: CGFloat = 8
    @State private var animatedProgress: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var iconScale: Double = 1.0
    @State private var ringScale: Double = 1.0

    private var clampedProgress: Double {
        min(max(animatedProgress, 0), 1)
    }

    private var ringColor: Color {
        if progress > 1.1 { return FuelColors.over }
        if progress > 0.9 { return FuelColors.warning }
        return FuelColors.flame
    }

    private var ringGradient: AngularGradient {
        let endAngle = -90 + 360 * clampedProgress
        if progress > 1.1 {
            return AngularGradient(
                colors: [FuelColors.over.opacity(0.5), FuelColors.over],
                center: .center,
                startAngle: .degrees(-90),
                endAngle: .degrees(endAngle)
            )
        }
        return AngularGradient(
            colors: [
                Color(hex: "#FF6B2B").opacity(0.4),
                Color(hex: "#FF4D00").opacity(0.7),
                Color(hex: "#FF4D00"),
                Color(hex: "#FF3D00")
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(endAngle)
        )
    }

    var body: some View {
        ZStack {
            // Ambient glow — pulses on fill
            Circle()
                .fill(ringColor.opacity(0.12))
                .frame(width: size + 20, height: size + 20)
                .blur(radius: 12)
                .opacity(glowOpacity)

            // Track with subtle inner depth
            Circle()
                .stroke(FuelColors.mist.opacity(0.6), lineWidth: lineWidth)
            Circle()
                .stroke(FuelColors.cloud.opacity(0.3), lineWidth: lineWidth - 2)

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.3), radius: 4, y: 2)

            // Bright tip cap
            if clampedProgress > 0.03 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.9), ringColor],
                            center: .center,
                            startRadius: 0,
                            endRadius: lineWidth * 0.8
                        )
                    )
                    .frame(width: lineWidth, height: lineWidth)
                    .shadow(color: ringColor.opacity(0.5), radius: 4)
                    .offset(y: -size / 2)
                    .rotationEffect(.degrees(360 * clampedProgress - 90))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(ringScale)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.3)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            let increased = newValue > oldValue

            // Animate the ring fill
            withAnimation(.spring(response: 0.9, dampingFraction: 0.5)) {
                animatedProgress = newValue
            }

            guard increased else { return }

            // Ring scale bounce
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                ringScale = 1.06
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                    ringScale = 1.0
                }
            }

            // Icon pop
            withAnimation(.spring(response: 0.2, dampingFraction: 0.3).delay(0.05)) {
                iconScale = 1.25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    iconScale = 1.0
                }
            }

            // Glow pulse
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
