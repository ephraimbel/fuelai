import SwiftUI

// MARK: - Photo Scan Overlay (Premium scanning animation over captured photo)

struct PhotoScanOverlay: View {
    let imageData: Data

    @State private var scanning = false
    @State private var messageIndex = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var appeared = false
    @State private var dotCount = 0

    private let messages = [
        "Identifying foods",
        "Estimating portions",
        "Calculating macros",
        "Cross-referencing database",
        "Finalizing results"
    ]

    var body: some View {
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

                // Gradient vignette overlay (darkens edges, keeps center visible)
                RadialGradient(
                    colors: [
                        .black.opacity(0.1),
                        .black.opacity(0.25),
                        .black.opacity(0.55)
                    ],
                    center: .center,
                    startRadius: geo.size.width * 0.25,
                    endRadius: geo.size.width * 0.75
                )

                // Scanning beam — a horizontal gradient bar that sweeps
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    // Smooth back-and-forth sweep (period ~2.8s)
                    let cycle = time.truncatingRemainder(dividingBy: 2.8) / 2.8
                    let position = cycle < 0.5
                        ? easeInOut(cycle * 2.0)
                        : easeInOut((1.0 - cycle) * 2.0)
                    let yOffset = -geo.size.height * 0.42 + geo.size.height * 0.84 * position

                    // Scan line with soft glow
                    VStack(spacing: 0) {
                        // Pre-glow
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        FuelColors.flame.opacity(0),
                                        FuelColors.flame.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 60)

                        // Core beam
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        FuelColors.flame.opacity(0),
                                        FuelColors.flame.opacity(0.6),
                                        .white.opacity(0.3),
                                        FuelColors.flame.opacity(0.6),
                                        FuelColors.flame.opacity(0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 2)

                        // Post-glow
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        FuelColors.flame.opacity(0.08),
                                        FuelColors.flame.opacity(0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 80)
                    }
                    .offset(y: yOffset)
                    .opacity(appeared ? 1 : 0)
                }

                // Corner brackets (scan area indicator)
                scanBrackets(geo: geo)
                    .opacity(appeared ? 1 : 0)

                // Subtle grid pattern inside brackets
                scanGrid(geo: geo)
                    .opacity(appeared ? 0.15 : 0)

                // Bottom status card
                VStack {
                    Spacer()

                    VStack(spacing: 12) {
                        // Progress dots
                        HStack(spacing: 6) {
                            ForEach(0..<messages.count, id: \.self) { i in
                                Circle()
                                    .fill(i <= messageIndex ? FuelColors.flame : .white.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(i == messageIndex ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: messageIndex)
                            }
                        }

                        HStack(spacing: 10) {
                            // Animated spinner
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.15), lineWidth: 2)
                                    .frame(width: 20, height: 20)

                                Circle()
                                    .trim(from: 0, to: 0.3)
                                    .stroke(FuelColors.flame, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                    .frame(width: 20, height: 20)
                                    .rotationEffect(.degrees(scanning ? 360 : 0))
                                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: scanning)
                            }

                            Text(messages[min(messageIndex, messages.count - 1)] + String(repeating: ".", count: dotCount))
                                .font(FuelType.cardTitle)
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                                .animation(.easeInOut(duration: 0.25), value: messageIndex)
                                .animation(.easeInOut(duration: 0.2), value: dotCount)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.2),
                                                .white.opacity(0.05)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                    )
                    .padding(.bottom, geo.safeAreaInsets.bottom + 32)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            scanning = true
            startMessageCycle()
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    // MARK: - Scan Brackets

    private func scanBrackets(geo: GeometryProxy) -> some View {
        let w = geo.size.width * 0.78
        let h = geo.size.height * 0.55
        let cx = geo.size.width / 2
        let cy = geo.size.height / 2 - 20
        let cornerLen: CGFloat = 28
        let lw: CGFloat = 2.5
        let r: CGFloat = 10

        return ZStack {
            // Four corner brackets
            ScanCorner(length: cornerLen, radius: r)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: cornerLen, height: cornerLen)
                .position(x: cx - w / 2 + cornerLen / 2, y: cy - h / 2 + cornerLen / 2)

            ScanCorner(length: cornerLen, radius: r)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: cornerLen, height: cornerLen)
                .rotationEffect(.degrees(90))
                .position(x: cx + w / 2 - cornerLen / 2, y: cy - h / 2 + cornerLen / 2)

            ScanCorner(length: cornerLen, radius: r)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: cornerLen, height: cornerLen)
                .rotationEffect(.degrees(-90))
                .position(x: cx - w / 2 + cornerLen / 2, y: cy + h / 2 - cornerLen / 2)

            ScanCorner(length: cornerLen, radius: r)
                .stroke(.white.opacity(0.8), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: cornerLen, height: cornerLen)
                .rotationEffect(.degrees(180))
                .position(x: cx + w / 2 - cornerLen / 2, y: cy + h / 2 - cornerLen / 2)
        }
    }

    // MARK: - Scan Grid

    private func scanGrid(geo: GeometryProxy) -> some View {
        let w = geo.size.width * 0.78
        let h = geo.size.height * 0.55
        let cx = geo.size.width / 2
        let cy = geo.size.height / 2 - 20

        return Canvas { context, _ in
            let left = cx - w / 2
            let top = cy - h / 2
            let cols = 4
            let rows = 3

            for i in 1..<cols {
                let x = left + w * CGFloat(i) / CGFloat(cols)
                var path = Path()
                path.move(to: CGPoint(x: x, y: top + 8))
                path.addLine(to: CGPoint(x: x, y: top + h - 8))
                context.stroke(path, with: .color(.white), lineWidth: 0.5)
            }
            for i in 1..<rows {
                let y = top + h * CGFloat(i) / CGFloat(rows)
                var path = Path()
                path.move(to: CGPoint(x: left + 8, y: y))
                path.addLine(to: CGPoint(x: left + w - 8, y: y))
                context.stroke(path, with: .color(.white), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Animation Helpers

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }

    private func startMessageCycle() {
        animationTask = Task {
            // Cycle through messages
            for i in 1..<messages.count {
                // Dot animation within each message
                for d in 1...3 {
                    try? await Task.sleep(for: .seconds(0.5))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation { dotCount = d }
                    }
                }
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation {
                        messageIndex = i
                        dotCount = 0
                    }
                }
            }

            // After last message, keep animating dots
            while !Task.isCancelled {
                for d in 1...3 {
                    try? await Task.sleep(for: .seconds(0.5))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        withAnimation { dotCount = d }
                    }
                }
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation { dotCount = 0 }
                }
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

    private let messages = [
        "Identifying foods",
        "Estimating portions",
        "Calculating macros",
        "Finalizing results"
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // --- Flame Animation (TimelineView for reliable continuous animation) ---
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let rotation = time.truncatingRemainder(dividingBy: 3.0) / 3.0 * 360
                let slowRotation = time.truncatingRemainder(dividingBy: 5.0) / 5.0 * 360
                let pulse = 1.0 + 0.06 * sin(time * 2.5)
                let flamePulse = 1.0 + 0.04 * sin(time * 3.0)
                let glowPulse = 0.08 + 0.04 * sin(time * 2.0)

                ZStack {
                    // Outermost soft glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    FuelColors.flame.opacity(glowPulse * 0.5),
                                    FuelColors.flame.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulse)

                    // Primary spinning arc
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    FuelColors.flame.opacity(0.0),
                                    FuelColors.flame.opacity(0.5),
                                    FuelColors.flame.opacity(0.0)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(rotation))

                    // Secondary arc (counter-rotating, slower)
                    Circle()
                        .trim(from: 0.0, to: 0.2)
                        .stroke(
                            FuelColors.flame.opacity(0.18),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 130, height: 130)
                        .rotationEffect(.degrees(-slowRotation))

                    // Inner warm glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    FuelColors.flame.opacity(glowPulse),
                                    FuelColors.flame.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulse)

                    // Ember particles
                    ForEach(0..<6, id: \.self) { i in
                        let particleTime = time + Double(i) * 0.9
                        let cycle = particleTime.truncatingRemainder(dividingBy: 2.4) / 2.4
                        let angle = Double(i) * 60 + time * 30
                        let radius = 20 + cycle * 40
                        let opacity = cycle < 0.7 ? cycle / 0.7 * 0.6 : (1 - cycle) / 0.3 * 0.6

                        Circle()
                            .fill(FuelColors.flame)
                            .frame(width: 3 - cycle * 1.5, height: 3 - cycle * 1.5)
                            .offset(
                                x: cos(angle * .pi / 180) * radius,
                                y: sin(angle * .pi / 180) * radius - cycle * 20
                            )
                            .opacity(opacity)
                    }

                    // Center flame icon
                    Image(systemName: "flame.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.55, blue: 0.0),
                                    FuelColors.flame,
                                    FuelColors.flame.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(flamePulse)
                }
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.7)
            .padding(.bottom, FuelSpacing.xxl)

            // --- Status Message ---
            Text(messages[min(messageIndex, messages.count - 1)])
                .font(FuelType.section)
                .foregroundStyle(FuelColors.ink)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.35), value: messageIndex)

            // --- Progress Bar ---
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
            .frame(width: 160, height: 5)
            .padding(.top, FuelSpacing.lg)

            Spacer()
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
        animationTask = Task {
            // Animate progress bar smoothly
            await MainActor.run {
                withAnimation(.easeOut(duration: 2.5)) {
                    progress = 0.45
                }
            }

            // Cycle through messages
            for i in 1..<messages.count {
                try? await Task.sleep(for: .seconds(2.0))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation { messageIndex = i }
                }
            }

            // Slow creep to 90%
            await MainActor.run {
                withAnimation(.easeOut(duration: 5.0)) {
                    progress = 0.9
                }
            }
        }
    }
}
