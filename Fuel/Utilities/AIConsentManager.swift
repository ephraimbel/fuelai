import Foundation

/// Manages user consent for sending data to third-party AI (Anthropic Claude).
/// Required by Apple App Store Guideline 5.1.2(i) — effective Nov 2025.
enum AIConsentManager {
    private static let consentKey = "ai_data_consent_granted"

    static var hasConsented: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    static func grantConsent() {
        UserDefaults.standard.set(true, forKey: consentKey)
    }

    static func revokeConsent() {
        UserDefaults.standard.set(false, forKey: consentKey)
    }
}
