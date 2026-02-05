import Foundation
import AuthenticationServices
import Security

/// Authentication provider types
enum AuthProvider: String, Codable {
    case apple = "Apple"
    case google = "Google"
    case microsoft = "Microsoft"
    case email = "Email"
}

/// User authentication state
struct AuthUser: Codable {
    let id: String
    let email: String
    let displayName: String?
    let provider: AuthProvider
    let createdAt: Date
    var lastLoginAt: Date
    
    var initials: String {
        if let name = displayName {
            let components = name.split(separator: " ")
            if components.count >= 2 {
                return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }
        return String(email.prefix(2)).uppercased()
    }
}

/// Authentication errors
enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case providerFailed(String)
    case keychainError
    case networkError
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in."
        case .invalidCredentials:
            return "Invalid email or password."
        case .providerFailed(let provider):
            return "\(provider) authentication failed."
        case .keychainError:
            return "Failed to store credentials securely."
        case .networkError:
            return "Network error. Check your connection."
        case .cancelled:
            return "Authentication cancelled."
        }
    }
}

/// Authentication Manager - Singleton for user authentication
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()
    
    // MARK: - Published State
    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var authError: String?
    
    // MARK: - Keychain Keys
    private let keychainService = "com.openflux.app.auth"
    private let userDataKey = "currentUser"
    private let tokenKey = "authToken"
    
    // MARK: - OAuth Configuration
    private let googleClientId = "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
    private let microsoftClientId = "YOUR_MICROSOFT_CLIENT_ID"
    private let appleTeamId = "YOUR_APPLE_TEAM_ID"
    
    private override init() {
        super.init()
        loadStoredUser()
    }
    
    // MARK: - Public API
    
    /// Sign in with Apple
    func signInWithApple() async throws {
        isLoading = true
        authError = nil
        
        do {
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.email, .fullName]
            
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            
            // This would normally use the async/await pattern with continuation
            // For now, using delegate pattern
            controller.performRequests()
            
        } catch {
            isLoading = false
            throw AuthError.providerFailed("Apple")
        }
    }
    
    /// Sign in with Google
    func signInWithGoogle() async throws {
        isLoading = true
        authError = nil
        
        // OAuth flow for Google
        // In production, use Google Sign-In SDK
        // https://developers.google.com/identity/sign-in/ios
        
        // For now, placeholder implementation
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let user = AuthUser(
            id: UUID().uuidString,
            email: "user@gmail.com",
            displayName: "Google User",
            provider: .google,
            createdAt: Date(),
            lastLoginAt: Date()
        )
        
        try await completeAuthentication(user: user, token: "google_token_placeholder")
    }
    
    /// Sign in with Microsoft
    func signInWithMicrosoft() async throws {
        isLoading = true
        authError = nil
        
        // OAuth flow for Microsoft
        // In production, use MSAL (Microsoft Authentication Library)
        // https://github.com/AzureAD/microsoft-authentication-library-for-objc
        
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let user = AuthUser(
            id: UUID().uuidString,
            email: "user@outlook.com",
            displayName: "Microsoft User",
            provider: .microsoft,
            createdAt: Date(),
            lastLoginAt: Date()
        )
        
        try await completeAuthentication(user: user, token: "microsoft_token_placeholder")
    }
    
    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        
        // Validate email format
        guard isValidEmail(email) else {
            isLoading = false
            throw AuthError.invalidCredentials
        }
        
        // In production, this would call your backend API
        // For now, demo implementation
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let user = AuthUser(
            id: UUID().uuidString,
            email: email,
            displayName: email.components(separatedBy: "@").first,
            provider: .email,
            createdAt: Date(),
            lastLoginAt: Date()
        )
        
        // Hash password before storing (NEVER store plaintext)
        let token = try hashPassword(password)
        
        try await completeAuthentication(user: user, token: token)
    }
    
    /// Sign up with email and password
    func signUpWithEmail(email: String, password: String, displayName: String?) async throws {
        isLoading = true
        authError = nil
        
        guard isValidEmail(email) else {
            isLoading = false
            throw AuthError.invalidCredentials
        }
        
        guard password.count >= 8 else {
            isLoading = false
            authError = "Password must be at least 8 characters"
            throw AuthError.invalidCredentials
        }
        
        // In production, call backend to create account
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let user = AuthUser(
            id: UUID().uuidString,
            email: email,
            displayName: displayName ?? email.components(separatedBy: "@").first,
            provider: .email,
            createdAt: Date(),
            lastLoginAt: Date()
        )
        
        let token = try hashPassword(password)
        try await completeAuthentication(user: user, token: token)
    }
    
    /// Sign out
    func signOut() {
        // Clear keychain
        deleteFromKeychain(key: userDataKey)
        deleteFromKeychain(key: tokenKey)
        
        // Clear state
        currentUser = nil
        isAuthenticated = false
        authError = nil
        
        print("[Auth] User signed out")
    }
    
    /// Refresh authentication token
    func refreshToken() async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }
        
        // In production, call backend to refresh token
        // For now, just update last login
        var updatedUser = user
        updatedUser.lastLoginAt = Date()
        currentUser = updatedUser
        
        try storeUserInKeychain(user: updatedUser)
    }
    
    // MARK: - Private Helpers
    
    private func completeAuthentication(user: AuthUser, token: String) async throws {
        // Store in keychain
        try storeUserInKeychain(user: user)
        try storeTokenInKeychain(token: token)
        
        // Update state on main thread
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            self.authError = nil
        }
        
        print("[Auth] User authenticated: \(user.email) via \(user.provider.rawValue)")
    }
    
    private func loadStoredUser() {
        guard let userData = loadFromKeychain(key: userDataKey),
              let user = try? JSONDecoder().decode(AuthUser.self, from: userData) else {
            return
        }
        
        // Verify token exists
        guard loadFromKeychain(key: tokenKey) != nil else {
            deleteFromKeychain(key: userDataKey)
            return
        }
        
        currentUser = user
        isAuthenticated = true
        print("[Auth] Loaded stored user: \(user.email)")
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func hashPassword(_ password: String) throws -> String {
        // In production, use proper password hashing (bcrypt, Argon2, etc.)
        // This is a placeholder
        guard let data = password.data(using: .utf8) else {
            throw AuthError.invalidCredentials
        }
        return data.base64EncodedString()
    }
    
    // MARK: - Keychain Operations
    
    private func storeUserInKeychain(user: AuthUser) throws {
        guard let data = try? JSONEncoder().encode(user) else {
            throw AuthError.keychainError
        }
        try storeInKeychain(key: userDataKey, data: data)
    }
    
    private func storeTokenInKeychain(token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw AuthError.keychainError
        }
        try storeInKeychain(key: tokenKey, data: data)
    }
    
    private func storeInKeychain(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.keychainError
        }
    }
    
    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return data
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userID = appleIDCredential.user
                let email = appleIDCredential.email ?? "noemail@privaterelay.appleid.com"
                let fullName = appleIDCredential.fullName
                
                var displayName: String? = nil
                if let givenName = fullName?.givenName, let familyName = fullName?.familyName {
                    displayName = "\(givenName) \(familyName)"
                }
                
                let user = AuthUser(
                    id: userID,
                    email: email,
                    displayName: displayName,
                    provider: .apple,
                    createdAt: Date(),
                    lastLoginAt: Date()
                )
                
                // Store Apple ID token
                let token = appleIDCredential.identityToken.map { String(data: $0, encoding: .utf8) ?? "" } ?? ""
                
                try await completeAuthentication(user: user, token: token)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            isLoading = false
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                authError = nil // User cancelled, don't show error
            } else {
                authError = "Apple Sign In failed: \(error.localizedDescription)"
            }
        }
    }
}
