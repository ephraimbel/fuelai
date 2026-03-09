import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isActive = false

    // Rich, warm celebration palette
    private let colors: [Color] = [
        Color(hex: "F2A65A"),  // warm gold
        Color(hex: "E8915C"),  // terracotta
        Color(hex: "D4A373"),  // tan
        Color(hex: "C9B99A"),  // wheat
        Color(hex: "F26522"),  // brand flame
        Color(hex: "E6C48E"),  // champagne
        Color(hex: "FFD700"),  // bright gold
        Color(hex: "FF8C42"),  // deep orange
    ]

    private let shapes: [ConfettiShape] = [.circle, .roundedRect, .strip, .circle, .strip, .roundedRect, .star]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let elapsed = now - particle.startTime
                    guard elapsed > 0 && elapsed < particle.duration else { continue }

                    let progress = elapsed / particle.duration

                    // Softer gravity for longer hang time
                    let gravity = 200.0 * elapsed * elapsed * 0.5
                    let sway = sin(elapsed * particle.swayFrequency) * particle.swayAmplitude
                    let x = particle.startX * size.width + particle.horizontalDrift * elapsed + sway
                    let y = particle.startY * size.height + particle.velocity * elapsed + gravity

                    // Fade out in last 30%
                    let opacity = progress < 0.7 ? 1.0 : 1.0 - ((progress - 0.7) / 0.3)

                    guard y < size.height + 40 else { continue }

                    context.opacity = opacity
                    context.translateBy(x: x, y: y)

                    let rotation = Angle.degrees(particle.rotationSpeed * elapsed)
                    context.rotate(by: rotation)

                    // 3D flip effect via scaleX oscillation
                    let flipScale = abs(cos(elapsed * particle.flipSpeed))

                    switch particle.shape {
                    case .circle:
                        let r = particle.size * 0.5
                        let rect = CGRect(x: -r, y: -r, width: r * 2 * flipScale, height: r * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(particle.color))

                    case .roundedRect:
                        let w = particle.size * flipScale
                        let h = particle.size * particle.aspectRatio
                        let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
                        context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(particle.color))

                    case .strip:
                        let w = particle.size * 0.3 * flipScale
                        let h = particle.size * 2.5
                        let rect = CGRect(x: -w / 2, y: -h / 2, width: max(w, 0.5), height: h)
                        context.fill(Path(rect), with: .color(particle.color))

                    case .star:
                        let s = particle.size * 0.7
                        let path = starPath(size: s * flipScale)
                        context.fill(path, with: .color(particle.color))
                    }

                    context.rotate(by: -rotation)
                    context.translateBy(x: -x, y: -y)
                    context.opacity = 1
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            // Big initial burst from center-top
            spawnBurst(count: 60, spread: 1.0, yRange: -0.15...0.0, velocityRange: -220...(-60))
            isActive = true

            // Second wave — wider, slightly delayed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                spawnBurst(count: 40, spread: 1.2, yRange: -0.1...0.05, velocityRange: -180...(-30))
            }

            // Third wave — gentle shower
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                spawnBurst(count: 25, spread: 1.4, yRange: -0.2...(-0.05), velocityRange: -120...(-20))
            }

            // Side cannons — left
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                spawnBurst(count: 20, spread: 0.3, centerX: 0.05, yRange: 0.2...0.4, velocityRange: -200...(-80), driftRange: 40...140)
            }

            // Side cannons — right
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                spawnBurst(count: 20, spread: 0.3, centerX: 0.95, yRange: 0.2...0.4, velocityRange: -200...(-80), driftRange: -140...(-40))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                isActive = false
            }
        }
    }

    private func spawnBurst(
        count: Int = 60,
        spread: Double = 1.0,
        centerX: Double = 0.5,
        yRange: ClosedRange<Double> = -0.15...0.0,
        velocityRange: ClosedRange<Double> = -220...(-60),
        driftRange: ClosedRange<Double> = -70...70
    ) {
        let now = Date.now.timeIntervalSinceReferenceDate
        let newParticles = (0..<count).map { _ in
            ConfettiParticle(
                startX: Double.random(in: (centerX - spread / 2)...(centerX + spread / 2)),
                startY: Double.random(in: yRange),
                velocity: Double.random(in: velocityRange),
                horizontalDrift: Double.random(in: driftRange),
                swayAmplitude: Double.random(in: 10...35),
                swayFrequency: Double.random(in: 1.5...5),
                flipSpeed: Double.random(in: 2...7),
                size: Double.random(in: 5...12),
                aspectRatio: Double.random(in: 0.5...1.6),
                rotationSpeed: Double.random(in: -280...280),
                color: colors.randomElement() ?? .orange,
                shape: shapes.randomElement() ?? .circle,
                duration: Double.random(in: 3.0...5.0),
                startTime: now + Double.random(in: 0...0.3)
            )
        }
        particles.append(contentsOf: newParticles)
    }

    private func starPath(size: Double) -> Path {
        Path { path in
            let points = 5
            let outerRadius = size
            let innerRadius = size * 0.4
            for i in 0..<(points * 2) {
                let angle = Double(i) * .pi / Double(points) - .pi / 2
                let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
                let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }
}

private enum ConfettiShape {
    case circle, roundedRect, strip, star
}

private struct ConfettiParticle {
    let startX: Double
    let startY: Double
    let velocity: Double
    let horizontalDrift: Double
    let swayAmplitude: Double
    let swayFrequency: Double
    let flipSpeed: Double
    let size: Double
    let aspectRatio: Double
    let rotationSpeed: Double
    let color: Color
    let shape: ConfettiShape
    let duration: Double
    let startTime: Double
}
