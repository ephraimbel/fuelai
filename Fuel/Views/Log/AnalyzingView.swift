import SwiftUI

// MARK: - Photo Scan Overlay (Enterprise scanning animation over captured photo)

struct PhotoScanOverlay: View {
    let imageData: Data

    @State private var messageIndex = 0
    @State private var appeared = false
    @State private var animationTask: Task<Void, Never>?
    private let startDate = Date()

    private let messages = [
        "Identifying foods",
        "Estimating portions",
        "Calculating macros",
        "Finalizing results"
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)

            GeometryReader { geo in
                ZStack {
                    // Captured photo — full bleed
                    if let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }

                    // Dark vignette overlay
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.5)
                        ],
                        center: .center,
                        startRadius: geo.size.width * 0.15,
                        endRadius: geo.size.width * 0.85
                    )

                    // Scan line with glow — driven by TimelineView
                    scanLine(geo: geo, elapsed: elapsed)
                        .opacity(appeared ? 1 : 0)

                    // Corner brackets with breathing
                    scanBrackets(geo: geo, elapsed: elapsed)
                        .opacity(appeared ? 1 : 0)

                    // Particle dots floating up
                    particleField(geo: geo, elapsed: elapsed)
                        .opacity(appeared ? 0.6 : 0)

                    // Bottom status pill
                    VStack {
                        Spacer()

                        HStack(spacing: 10) {
                            // Spinning arc — driven by TimelineView
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 2)
                                    .frame(width: 18, height: 18)

                                Circle()
                                    .trim(from: 0, to: 0.3)
                                    .stroke(
                                        FuelColors.flame,
                                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                                    )
                                    .frame(width: 18, height: 18)
                                    .rotationEffect(.degrees(elapsed * 300))
                            }

                            Text(messages[min(messageIndex, messages.count - 1)])
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.4), value: messageIndex)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [
                                                    .white.opacity(0.3),
                                                    .white.opacity(0.08)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 0.5
                                        )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 36)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            startMessageCycle()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    // MARK: - Scan Line (smooth sine wave motion)

    private func scanLine(geo: GeometryProxy, elapsed: TimeInterval) -> some View {
        let travelTop = geo.size.height * 0.12
        let travelBottom = geo.size.height * 0.78
        // Smooth sine wave: ping-pong between top and bottom over ~3 seconds
        let t = (sin(elapsed * 0.8) + 1) / 2 // 0...1
        let currentY = travelTop + (travelBottom - travelTop) * t
        let scanWidth = geo.size.width

        return ZStack {
            // Glow zone above line
            LinearGradient(
                colors: [.clear, FuelColors.flame.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: scanWidth, height: 60)
            .offset(y: -35)

            // Main scan line — bright center, fading edges
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            FuelColors.flame.opacity(0.3),
                            FuelColors.flame.opacity(0.7),
                            .white.opacity(0.9),
                            FuelColors.flame.opacity(0.7),
                            FuelColors.flame.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: scanWidth, height: 2)
                .shadow(color: FuelColors.flame.opacity(0.5), radius: 8, y: 0)
                .shadow(color: FuelColors.flame.opacity(0.2), radius: 20, y: 0)

            // Shimmer traveling along the scan line
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.8))
                .frame(width: 40, height: 2)
                .offset(x: shimmerX(width: scanWidth, elapsed: elapsed))

            // Glow zone below line
            LinearGradient(
                colors: [FuelColors.flame.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: scanWidth, height: 70)
            .offset(y: 40)
        }
        .position(x: geo.size.width / 2, y: currentY)
    }

    private func shimmerX(width: CGFloat, elapsed: TimeInterval) -> CGFloat {
        let period = 1.5
        let t = (elapsed.truncatingRemainder(dividingBy: period)) / period
        return (t - 0.5) * width * 0.8
    }

    // MARK: - Scan Brackets (breathing + subtle rotation)

    private func scanBrackets(geo: GeometryProxy, elapsed: TimeInterval) -> some View {
        let w = geo.size.width * 0.76
        let h = geo.size.height * 0.52
        let cx = geo.size.width / 2
        let cy = geo.size.height / 2 - 20
        let cornerLen: CGFloat = 36
        let lw: CGFloat = 2.5
        let r: CGFloat = 14
        // Subtle breathing scale
        let breathe = 1.0 + sin(elapsed * 1.2) * 0.008

        return ZStack {
            // Top-left
            ScanCorner(length: cornerLen, radius: r)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: cornerLen, height: cornerLen)
                .position(x: cx - w / 2 + cornerLen / 2, y: cy - h / 2 + cornerLen / 2)

            // Top-right
            ScanCorner(length: cornerLen, radius: r)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: cornerLen, height: cornerLen)
                .rotationEffect(.degrees(90))
                .position(x: cx + w / 2 - cornerLen / 2, y: cy - h / 2 + cornerLen / 2)

            // Bottom-left
            ScanCorner(length: cornerLen, radius: r)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: cornerLen, height: cornerLen)
                .rotationEffect(.degrees(-90))
                .position(x: cx - w / 2 + cornerLen / 2, y: cy + h / 2 - cornerLen / 2)

            // Bottom-right
            ScanCorner(length: cornerLen, radius: r)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: cornerLen, height: cornerLen)
                .rotationEffect(.degrees(180))
                .position(x: cx + w / 2 - cornerLen / 2, y: cy + h / 2 - cornerLen / 2)
        }
        .scaleEffect(breathe)
    }

    // MARK: - Floating Particles

    private func particleField(geo: GeometryProxy, elapsed: TimeInterval) -> some View {
        let particles: [(x: CGFloat, speed: Double, size: CGFloat, delay: Double)] = [
            (0.15, 12, 3, 0), (0.3, 15, 2, 1.2), (0.5, 10, 4, 0.5),
            (0.7, 13, 2.5, 2.0), (0.85, 11, 3, 0.8), (0.25, 14, 2, 1.8),
            (0.6, 9, 3.5, 0.3), (0.4, 16, 2, 2.5), (0.8, 12, 3, 1.5),
        ]

        return ZStack {
            ForEach(0..<particles.count, id: \.self) { i in
                let p = particles[i]
                let adjustedTime = max(0, elapsed - p.delay)
                let yProgress = (adjustedTime * p.speed).truncatingRemainder(dividingBy: Double(geo.size.height))
                let y = geo.size.height - yProgress
                let opacity = adjustedTime > 0 ? min(1.0, yProgress / 100) * (1.0 - yProgress / Double(geo.size.height)) : 0

                Circle()
                    .fill(FuelColors.flame.opacity(opacity * 0.5))
                    .frame(width: p.size, height: p.size)
                    .position(x: geo.size.width * p.x, y: y)
            }
        }
    }

    // MARK: - Message Cycle

    private func startMessageCycle() {
        animationTask = Task { @MainActor in
            for i in 1..<messages.count {
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled else { return }
                messageIndex = i
            }
        }
    }
}

// MARK: - Scan Corner Shape

private struct ScanCorner: Shape {
    let length: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: length))
        p.addLine(to: CGPoint(x: 0, y: radius))
        p.addQuadCurve(
            to: CGPoint(x: radius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        p.addLine(to: CGPoint(x: length, y: 0))
        return p
    }
}

// MARK: - Generic Analyzing View (text/barcode flows)

struct AnalyzingView: View {
    @State private var appeared = false
    @State private var messageIndex = 0
    @State private var progress: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    private let startDate = Date()

    private let messages = [
        "Identifying foods",
        "Estimating portions",
        "Calculating macros",
        "Finalizing results"
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    // Soft glow — pulsing
                    let pulseScale = 1.0 + sin(elapsed * 1.5) * 0.06
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [FuelColors.flame.opacity(0.12), .clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: 85
                            )
                        )
                        .frame(width: 170, height: 170)
                        .scaleEffect(pulseScale)

                    // Primary spinning arc
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(FuelColors.flame.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(elapsed * 180))

                    // Counter arc (slower, opposite)
                    Circle()
                        .trim(from: 0, to: 0.15)
                        .stroke(FuelColors.flame.opacity(0.2), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-elapsed * 120))

                    // Outer ring pulse
                    Circle()
                        .stroke(FuelColors.flame.opacity(0.08), lineWidth: 1)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)

                    // Center flame — subtle breathing
                    let flameScale = 1.0 + sin(elapsed * 2) * 0.04
                    Image("FlameIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .scaleEffect(flameScale)
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)
                .padding(.bottom, FuelSpacing.xxl)

                Text(messages[min(messageIndex, messages.count - 1)])
                    .font(FuelType.section)
                    .foregroundStyle(FuelColors.ink)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.4), value: messageIndex)

                // Progress bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(FuelColors.cloud)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [FuelColors.flame.opacity(0.8), FuelColors.flame],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(width: 160, height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(.top, FuelSpacing.lg)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .background(FuelColors.white)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            startAnimations()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    private func startAnimations() {
        animationTask = Task { @MainActor in
            withAnimation(.easeOut(duration: 2.5)) { progress = 0.45 }
            for i in 1..<messages.count {
                try? await Task.sleep(for: .seconds(2.0))
                guard !Task.isCancelled else { return }
                messageIndex = i
            }
            withAnimation(.easeOut(duration: 5.0)) { progress = 0.9 }
        }
    }
}
