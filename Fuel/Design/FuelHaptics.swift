import UIKit

@MainActor
final class FuelHaptics {
    static let shared = FuelHaptics()

    func logSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    func goalHit() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let second = UIImpactFeedbackGenerator(style: .medium)
            second.impactOccurred()
        }
    }

    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    func scan() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    /// Cascading tick pattern for menu reveal
    func cascade(count: Int) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                let g = UIImpactFeedbackGenerator(style: i == 0 ? .medium : .light)
                g.impactOccurred(intensity: 1.0 - Double(i) * 0.12)
            }
        }
    }

    func send() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
