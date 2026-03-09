import SwiftUI

// MARK: - Animation Presets

enum FuelAnimation {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.75)
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let gentle = Animation.spring(response: 0.8, dampingFraction: 0.7)
    static let quick = Animation.spring(response: 0.25, dampingFraction: 0.9)

    // Chat-specific
    static let messagePop = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let smooth = Animation.easeOut(duration: 0.3)

    static func stagger(_ index: Int) -> Double {
        Double(index) * 0.08
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(FuelAnimation.quick, value: configuration.isPressed)
    }
}

// MARK: - Staggered Appear Modifier

struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                FuelAnimation.spring.delay(FuelAnimation.stagger(index)),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, FuelColors.onDark.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func pressable() -> some View {
        buttonStyle(PressableButtonStyle())
    }

    func chatAppear(from edge: HorizontalEdge = .leading) -> some View {
        modifier(ChatAppearModifier(edge: edge))
    }
}

// MARK: - Chat Appear Modifier

struct ChatAppearModifier: ViewModifier {
    let edge: HorizontalEdge
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .animation(FuelAnimation.messagePop, value: appeared)
            .onAppear { appeared = true }
    }
}
