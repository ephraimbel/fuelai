import SwiftUI

struct BuildingPlanView: View {
    let onContinue: () -> Void

    @State private var hasStarted = false
    @State private var completedSteps: Set<Int> = []
    @State private var activeStep: Int = 0
    @State private var progress: CGFloat = 0
    @State private var checkTrim: [Int: CGFloat] = [:]
    @State private var showDone = false
    @State private var sequenceTask: Task<Void, Never>?

    private let steps: [(icon: String, label: String, done: String)] = [
        ("person.text.rectangle", "Analyzing your profile", "Profile analyzed"),
        ("function", "Calculating your macros", "Macros calculated"),
        ("chart.bar.fill", "Optimizing meal plan", "Meal plan optimized"),
        ("FlameIcon", "Building your plan", "Plan ready"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Title
            VStack(spacing: FuelSpacing.sm) {
                Text("Crafting your plan")
                    .font(FuelType.title)
                    .foregroundStyle(FuelColors.ink)

                Text("This takes just a moment")
                    .font(FuelType.body)
                    .foregroundStyle(FuelColors.stone)
            }
            .opacity(showDone ? 0 : 1)
            .animation(FuelAnimation.smooth, value: showDone)

            Spacer().frame(height: FuelSpacing.section)

            // Step cards
            VStack(spacing: FuelSpacing.sm) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepCard(index: index, icon: step.icon, label: step.label, doneLabel: step.done)
                }
            }
            .padding(.horizontal, FuelSpacing.xl)

            Spacer().frame(height: FuelSpacing.xxl)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FuelColors.cloud)
                        .frame(height: 6)

                    Capsule()
                        .fill(FuelColors.flameGradient)
                        .frame(width: max(0, progress * geo.size.width), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, FuelSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            runSequence()
        }
        .onDisappear {
            sequenceTask?.cancel()
        }
    }

    // MARK: - Step Card

    private func stepCard(index: Int, icon: String, label: String, doneLabel: String) -> some View {
        let isCompleted = completedSteps.contains(index)
        let isActive = activeStep == index && !isCompleted
        let isUpcoming = index > activeStep

        return HStack(spacing: FuelSpacing.md) {
            // Checkmark / icon
            ZStack {
                if isCompleted {
                    Circle()
                        .fill(FuelColors.success.opacity(0.12))
                        .frame(width: 32, height: 32)

                    CheckmarkShape()
                        .trim(from: 0, to: checkTrim[index] ?? 0)
                        .stroke(FuelColors.success, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .frame(width: 14, height: 14)
                } else {
                    Circle()
                        .fill(isActive ? FuelColors.flame.opacity(0.1) : FuelColors.cloud)
                        .frame(width: 32, height: 32)

                    Group {
                        if icon == "FlameIcon" {
                            Image("FlameIcon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(isActive ? FuelColors.flame : FuelColors.stone)
                        }
                    }
                }
            }
            .animation(FuelAnimation.snappy, value: isCompleted)

            // Label
            Text(isCompleted ? doneLabel : label)
                .font(FuelType.cardTitle)
                .foregroundStyle(isCompleted ? FuelColors.ink : (isActive ? FuelColors.ink : FuelColors.stone))
                .contentTransition(.opacity)
                .animation(FuelAnimation.smooth, value: isCompleted)

            Spacer()

            // Active spinner
            if isActive {
                ProgressView()
                    .controlSize(.small)
                    .tint(FuelColors.flame)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, FuelSpacing.lg)
        .padding(.vertical, FuelSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: FuelRadius.sm)
                .fill(isActive ? FuelColors.cloud : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: FuelRadius.sm)
                        .fill(isActive ? FuelColors.white.opacity(0.5) : Color.clear)
                        .shimmerIf(isActive)
                )
        )
        .opacity(isUpcoming ? 0.5 : 1)
        .offset(y: isUpcoming ? 4 : 0)
        .animation(FuelAnimation.spring, value: activeStep)
        .animation(FuelAnimation.snappy, value: isCompleted)
    }

    // MARK: - Sequence

    private func runSequence() {
        let stepDuration = 0.7
        let totalSteps = steps.count

        // Animate progress bar across full duration
        let totalDuration = stepDuration * Double(totalSteps) + 0.3
        withAnimation(.easeInOut(duration: totalDuration)) {
            progress = 1.0
        }

        sequenceTask = Task { @MainActor in
            for i in 0..<totalSteps {
                // Activate step
                if i > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                }
                withAnimation(FuelAnimation.spring) {
                    activeStep = i
                }
                FuelHaptics.shared.tap()
                FuelSounds.shared.tick()

                // Complete step
                try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
                withAnimation(FuelAnimation.snappy) {
                    completedSteps.insert(i)
                }
                // Draw checkmark
                withAnimation(.easeOut(duration: 0.3)) {
                    checkTrim[i] = 1.0
                }
                FuelHaptics.shared.selection()
                FuelSounds.shared.pop()
            }

            // Final completion (0.2s after last step completes)
            try? await Task.sleep(nanoseconds: 200_000_000)
            FuelHaptics.shared.logSuccess()
            FuelSounds.shared.chime()
            onContinue()
        }
    }
}

// MARK: - Checkmark Shape

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.width * 0.35, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
    }
}

// MARK: - Conditional Shimmer

private extension View {
    @ViewBuilder
    func shimmerIf(_ condition: Bool) -> some View {
        if condition {
            self.shimmer()
        } else {
            self
        }
    }
}
