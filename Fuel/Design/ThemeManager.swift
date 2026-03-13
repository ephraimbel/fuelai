import SwiftUI

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var shortLabel: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor @Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "app_theme") }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: "app_theme") ?? "light"
        self.theme = AppTheme(rawValue: stored) ?? .light
    }

    /// Crossfade the entire window when switching themes so everything
    /// (including navigation bars) transitions in one clean pass.
    func setTheme(_ newTheme: AppTheme) {
        guard newTheme != theme else { return }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            UIView.transition(with: window, duration: 0.32, options: .transitionCrossDissolve) {
                self.theme = newTheme
            }
        } else {
            theme = newTheme
        }
    }
}
