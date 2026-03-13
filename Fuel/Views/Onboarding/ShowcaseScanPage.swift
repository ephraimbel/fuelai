import SwiftUI

struct ShowcaseScanPage: View {
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var showFrame = false
    @State private var animCycle = 0

    // Animation states
    @State private var showBrackets = false
    @State private var showAnalyzing = false
    @State private var showResults = false
    @State private var showCalories = false
    @State private var showMacros = false
    @State private var showHealthScore = false
    @State private var showMicros = false
    @State private var showLogButton = false
    @State private var isCamera = true

    private let foodImageURL = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&q=80"

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: FuelSpacing.sm) {
                (Text("Snap. Track. ")
                    .foregroundColor(FuelColors.ink) +
                 Text("Done.")
                    .foregroundColor(FuelColors.flame))
                    .font(FuelType.title)
                    .multilineTextAlignment(.center)

                Text("Point your camera at any meal\nfor instant nutrition breakdown")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, FuelSpacing.xl)
            .padding(.top, FuelSpacing.xxl)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(FuelAnimation.spring.delay(0.0), value: appeared)

            Spacer()

            ShowcasePhoneFrame {
                ZStack {
                    // Base background — white for results, hidden behind camera image
                    FuelColors.white

                    // Camera phase
                    cameraContent
                        .opacity(isCamera ? 1 : 0)

                    // Results phase
                    resultsContent
                        .opacity(isCamera ? 0 : 1)
                }
                .animation(FuelAnimation.spring, value: isCamera)
            }
            .padding(.horizontal, 40)
            .opacity(showFrame ? 1 : 0)
            .scaleEffect(showFrame ? 1 : 0.95)
            .animation(FuelAnimation.spring.delay(0.2), value: showFrame)

            Spacer()

            Button {
                FuelHaptics.shared.tap()
                onContinue()
            } label: {
                Text("Continue")
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
        .onAppear {
            appeared = true
            showFrame = true
            runLoop()
        }
    }

    // MARK: - Camera

    private var cameraContent: some View {
        ZStack {
            // Dark background for camera phase (covers white base)
            Color(hex: "#1A1510")

            // GeometryReader prevents .fill image from inflating the parent ZStack
            GeometryReader { geo in
                AsyncImage(url: URL(string: foodImageURL)) { p in
                    if let img = p.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width + 30, height: geo.size.height + 20)
                            .offset(x: -15, y: -10)
                    } else { Color(hex: "#2D2520") }
                }
            }
            .clipped()

            // Vignette
            LinearGradient(
                colors: [Color.black.opacity(0.4), .clear, .clear, Color.black.opacity(0.5)],
                startPoint: .top, endPoint: .bottom
            )

            // Brackets
            viewfinderBrackets
                .opacity(showBrackets ? 1 : 0)
                .scaleEffect(showBrackets ? 1 : 1.06)
                .animation(FuelAnimation.spring, value: showBrackets)

            // Scan line
            if showBrackets && !showAnalyzing {
                ShowcaseScanLine()
            }

            // Top bar
            VStack {
                HStack {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.15)))
                    Spacer()
                    Image(systemName: "bolt.slash.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.15)))
                }
                .padding(.horizontal, 14)
                .padding(.top, 50)
                Spacer()
            }

            // Bottom bar
            VStack {
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(Image(systemName: "photo").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6)))
                    Spacer()
                    ZStack {
                        Circle().stroke(.white.opacity(0.8), lineWidth: 2.5).frame(width: 40, height: 40)
                        Circle().fill(.white).frame(width: 32, height: 32)
                    }
                    Spacer()
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            // Analyzing overlay
            if showAnalyzing {
                Color.black.opacity(0.55).transition(.opacity)
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(FuelColors.flame.opacity(0.15)).frame(width: 40, height: 40)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(FuelColors.flame)
                            .symbolEffect(.pulse, isActive: true)
                    }
                    Text("Analyzing...")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }

    // MARK: - Results

    private var resultsContent: some View {
        VStack(spacing: 0) {
            // Hero — GeometryReader prevents .fill from inflating parent
            GeometryReader { _ in
                AsyncImage(url: URL(string: foodImageURL)) { p in
                    if let img = p.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else { Color(hex: "#2D2520") }
                }
            }
            .frame(height: 130)
            .clipped()

            // Content card with rounded top corners overlapping hero
            VStack(spacing: 7) {
                    // Bookmark + time
                    HStack(spacing: 3) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 7))
                            .foregroundStyle(FuelColors.stone)
                        Text("12:34 PM")
                            .font(.system(size: 6))
                            .foregroundStyle(FuelColors.stone)
                        Spacer()
                    }

                    // Meal name + serving pill
                    HStack(alignment: .top, spacing: 4) {
                        Text("Grilled Chicken\nSalad Bowl")
                            .font(.system(size: 11, weight: .bold, design: .serif))
                            .foregroundStyle(FuelColors.ink)
                            .lineSpacing(1)
                        Spacer(minLength: 2)
                        HStack(spacing: 2) {
                            Text("1")
                                .font(.system(size: 7, weight: .semibold, design: .serif))
                                .foregroundStyle(FuelColors.ink)
                            Image(systemName: "fork.knife")
                                .font(.system(size: 5))
                                .foregroundStyle(FuelColors.stone)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(FuelColors.mist, lineWidth: 0.5))
                    }

                    // Calorie card
                    if showCalories {
                        HStack(spacing: 4) {
                            Image("FlameIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Calories")
                                    .font(.system(size: 5.5))
                                    .foregroundStyle(FuelColors.stone)
                                Text("420")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundStyle(FuelColors.ink)
                            }
                            Spacer()
                        }
                        .padding(7)
                        .background(RoundedRectangle(cornerRadius: 6).fill(FuelColors.cloud))
                        .transition(.opacity.combined(with: .offset(y: 3)))
                    }

                    // Macro pills
                    if showMacros {
                        HStack(spacing: 4) {
                            miniMacroPill("Protein", value: "38g", color: FuelColors.protein)
                            miniMacroPill("Carbs", value: "24g", color: FuelColors.carbs)
                            miniMacroPill("Fats", value: "18g", color: FuelColors.fat)
                        }
                        .transition(.opacity.combined(with: .offset(y: 3)))
                    }

                    // Health score
                    if showHealthScore {
                        VStack(spacing: 5) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(FuelColors.success)
                                Text("Health Score")
                                    .font(.system(size: 7, weight: .semibold))
                                    .foregroundStyle(FuelColors.ink)
                                Spacer()
                                Text("8/10")
                                    .font(.system(size: 8, weight: .bold, design: .serif))
                                    .foregroundStyle(FuelColors.ink)
                            }
                            GeometryReader { bar in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(
                                                colors: [.red.opacity(0.25), .orange.opacity(0.25), .yellow.opacity(0.25), .green.opacity(0.25)],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(
                                            LinearGradient(
                                                colors: [.green.opacity(0.7), FuelColors.success],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .frame(width: bar.size.width * 0.8)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(7)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(FuelColors.white)
                                .shadow(color: FuelColors.shadow.opacity(0.06), radius: 3, y: 1)
                        )
                        .transition(.opacity.combined(with: .offset(y: 3)))
                    }

                    // Micronutrients (matches real FoodResultsView)
                    if showMicros {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Micronutrients")
                                .font(.system(size: 8, weight: .semibold, design: .serif))
                                .foregroundStyle(FuelColors.ink)

                            HStack(spacing: 4) {
                                microPill("4.2g", label: "Fiber")
                                microPill("3.1g", label: "Sugar")
                                microPill("380mg", label: "Sodium")
                            }
                        }
                        .transition(.opacity.combined(with: .offset(y: 3)))
                    }

                    Spacer(minLength: 0)

                    // Bottom bar
                    if showLogButton {
                        VStack(spacing: 0) {
                            Rectangle().fill(FuelColors.mist).frame(height: 0.5)
                            HStack(spacing: 5) {
                                HStack(spacing: 2) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 6, weight: .semibold))
                                    Text("Fix Results")
                                        .font(.system(size: 7.5, weight: .semibold))
                                }
                                .foregroundStyle(FuelColors.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(FuelColors.mist, lineWidth: 0.5)
                                )

                                Text("Log Meal")
                                    .font(.system(size: 7.5, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(FuelColors.ink)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                        }
                        .transition(.opacity.combined(with: .offset(y: 4)))
                    }
                }
            .padding(.horizontal, 9)
            .padding(.top, 9)
            .padding(.bottom, showLogButton ? 0 : 9)
            .frame(maxHeight: .infinity)
            .background(FuelColors.white)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 12,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 12
                )
            )
            .offset(y: -12)
        }
    }

    private func miniMacroPill(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 1.5) {
                Circle()
                    .fill(color)
                    .frame(width: 3, height: 3)
                Text(label)
                    .font(.system(size: 5.5, weight: .medium))
                    .foregroundStyle(FuelColors.stone)
            }
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .serif))
                .foregroundStyle(FuelColors.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 5).fill(FuelColors.cloud))
    }

    private func microPill(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 8, weight: .semibold, design: .serif))
                .foregroundStyle(FuelColors.ink)
            Text(label)
                .font(.system(size: 5.5, weight: .medium))
                .foregroundStyle(FuelColors.stone)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 5).fill(FuelColors.cloud))
    }

    // MARK: - Looping Animation

    private func runLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                // Reset
                isCamera = true
                showBrackets = false
                showAnalyzing = false
                showResults = false
                showCalories = false
                showMacros = false
                showHealthScore = false
                showMicros = false
                showLogButton = false

                try? await Task.sleep(for: .seconds(0.5))

                // Camera phase
                withAnimation(FuelAnimation.spring) { showBrackets = true }
                try? await Task.sleep(for: .seconds(1.4))

                // Analyzing
                withAnimation(FuelAnimation.spring) { showAnalyzing = true }
                try? await Task.sleep(for: .seconds(0.9))

                // Switch to results
                withAnimation(FuelAnimation.spring) {
                    isCamera = false
                    showAnalyzing = false
                    showResults = true
                }
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(FuelAnimation.spring) { showCalories = true }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(FuelAnimation.spring) { showMacros = true }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(FuelAnimation.spring) { showHealthScore = true }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(FuelAnimation.spring) { showMicros = true }
                try? await Task.sleep(for: .seconds(0.15))
                withAnimation(FuelAnimation.spring) { showLogButton = true }

                // Hold results visible
                try? await Task.sleep(for: .seconds(2.5))

                animCycle += 1
            }
        }
    }

    // MARK: - Viewfinder

    private var viewfinderBrackets: some View {
        let size: CGFloat = 120
        let len: CGFloat = 20
        let lw: CGFloat = 2.5
        return ZStack {
            corner(len: len, lw: lw, sx: 1, sy: 1).offset(x: -size/2, y: -size/2)
            corner(len: len, lw: lw, sx: -1, sy: 1).offset(x: size/2, y: -size/2)
            corner(len: len, lw: lw, sx: 1, sy: -1).offset(x: -size/2, y: size/2)
            corner(len: len, lw: lw, sx: -1, sy: -1).offset(x: size/2, y: size/2)
        }
    }

    private func corner(len: CGFloat, lw: CGFloat, sx: CGFloat, sy: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: len))
            p.addLine(to: .zero)
            p.addLine(to: CGPoint(x: len, y: 0))
        }
        .stroke(FuelColors.flame, style: StrokeStyle(lineWidth: lw, lineCap: .round))
        .frame(width: len, height: len)
        .scaleEffect(x: sx, y: sy)
    }

}

// MARK: - Scan Line

private struct ShowcaseScanLine: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let y = sin(t.remainder(dividingBy: 2.0) / 2.0 * .pi) * 50
            Rectangle()
                .fill(
                    LinearGradient(colors: [.clear, FuelColors.flame.opacity(0.7), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 110, height: 2)
                .shadow(color: FuelColors.flame.opacity(0.4), radius: 4, y: 0)
                .offset(y: y)
        }
    }
}
