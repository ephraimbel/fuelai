import AuthenticationServices
import Supabase

actor AuthService {
    private let supabase: SupabaseClient

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> UserProfile {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw FuelError.authFailed("Invalid Apple credential")
        }

        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: tokenString)
        )

        if let existing = try? await fetchProfile(userId: session.user.id) {
            return existing
        }

        let profile = UserProfile(
            id: session.user.id,
            email: credential.email ?? session.user.email,
            displayName: [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ").nilIfEmpty,
            isPremium: false,
            streakCount: 0,
            longestStreak: 0,
            unitSystem: .imperial,
            createdAt: Date(),
            updatedAt: Date()
        )

        try await supabase.from("profiles").insert(profile).execute()
        return profile
    }

    func fetchProfile(userId: UUID) async throws -> UserProfile {
        try await supabase.from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func restoreSession() async throws -> UserProfile? {
        guard let session = try? await supabase.auth.session else { return nil }
        return try? await fetchProfile(userId: session.user.id)
    }

    /// Ensure a session exists — creates an anonymous one if needed.
    /// Anonymous sessions let users scan food immediately without signing in.
    /// When they later sign in with Apple, the anonymous session upgrades automatically.
    func ensureSession() async {
        // Already have a session? Done.
        if Constants.supabase.auth.currentSession != nil { return }
        do {
            try await supabase.auth.signInAnonymously()
            #if DEBUG
            print("[Auth] Created anonymous session")
            #endif
        } catch {
            #if DEBUG
            print("[Auth] Anonymous sign-in failed: \(error)")
            #endif
        }
    }
}
