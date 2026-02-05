import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showEmailLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    
    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                Text("Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if authManager.isAuthenticated, let user = authManager.currentUser {
                    // Authenticated view
                    authenticatedContent(user: user)
                } else {
                    // Login view
                    loginContent
                }
                
                Spacer()
            }
            .padding()
        }
        .background(themeColors.background)
    }
    
    // MARK: - Authenticated Content
    
    @ViewBuilder
    private func authenticatedContent(user: AuthUser) -> some View {
        // User Profile
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(themeColors.primary.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Text(user.initials)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(themeColors.primary)
            }
            
            VStack(spacing: 4) {
                if let name = user.displayName {
                    Text(name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeColors.text)
                }
                
                Text(user.email)
                    .font(.body)
                    .foregroundStyle(themeColors.text.opacity(0.7))
                
                HStack(spacing: 6) {
                    Image(systemName: providerIcon(user.provider))
                        .font(.caption)
                    Text("Signed in with \(user.provider.rawValue)")
                        .font(.caption)
                }
                .foregroundStyle(themeColors.text.opacity(0.5))
                .padding(.top, 4)
            }
        }
        .padding(.vertical)
        
        // iCloud Status
        VStack(alignment: .leading, spacing: 12) {
            Text("iCloud Status")
                .font(.headline)
                .foregroundStyle(themeColors.text)
            
            HStack {
                Image(systemName: appState.iCloudAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(appState.iCloudAvailable ? .green : .red)
                
                Text(appState.iCloudAvailable ? "Connected" : "Not Available")
                    .foregroundStyle(themeColors.text.opacity(0.8))
                
                Spacer()
            }
            .padding()
            .background(themeColors.cardBackground)
            .cornerRadius(8)
            
            if !appState.iCloudAvailable {
                Text("Sign in to iCloud in System Settings to enable sync")
                    .font(.caption)
                    .foregroundStyle(themeColors.text.opacity(0.6))
            }
        }
        
        // CloudKit Sync
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Settings")
                .font(.headline)
                .foregroundStyle(themeColors.text)
            
            Toggle(isOn: Binding(
                get: { appState.cloudKitManager.syncEnabled },
                set: { appState.setSyncEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud Sync")
                        .foregroundStyle(themeColors.text)
                    Text("Sync preferences and settings across devices")
                        .font(.caption)
                        .foregroundStyle(themeColors.text.opacity(0.6))
                }
            }
            .disabled(!appState.iCloudAvailable)
            .padding()
            .background(themeColors.cardBackground)
            .cornerRadius(8)
            
            if let lastSync = appState.lastSyncDate {
                HStack {
                    Text("Last synced:")
                        .foregroundStyle(themeColors.text.opacity(0.6))
                    Text(lastSync, style: .relative)
                        .foregroundStyle(themeColors.text.opacity(0.8))
                    Text("ago")
                        .foregroundStyle(themeColors.text.opacity(0.6))
                }
                .font(.caption)
            }
            
            // Sync state indicator
            HStack {
                Image(systemName: syncStateIcon)
                    .foregroundStyle(syncStateColor)
                Text(appState.syncState.description)
                    .foregroundStyle(themeColors.text.opacity(0.8))
                
                if case .syncing = appState.syncState {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .font(.caption)
            .padding(.horizontal)
            
            if appState.cloudKitManager.syncEnabled {
                let isSyncing = appState.syncState == .syncing
                Button(action: {
                    appState.forceFullSync()
                }) {
                    HStack {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isSyncing ? "Syncing…" : "Sync Now")
                    }
                    .foregroundStyle(isSyncing ? themeColors.text.opacity(0.5) : themeColors.primary)
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)
                .padding()
                .frame(maxWidth: .infinity)
                .background(themeColors.cardBackground)
                .cornerRadius(8)
            }
        }
        
        // Account Info
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Information")
                .font(.headline)
                .foregroundStyle(themeColors.text)
            
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Created", value: user.createdAt.formatted(date: .abbreviated, time: .omitted))
                InfoRow(label: "Last Login", value: user.lastLoginAt.formatted(date: .abbreviated, time: .shortened))
                InfoRow(label: "User ID", value: String(user.id.prefix(16)) + "...")
            }
            .padding()
            .background(themeColors.cardBackground)
            .cornerRadius(8)
        }
        
        // Sign Out Button
        Button(action: {
            authManager.signOut()
        }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .padding()
        .frame(maxWidth: .infinity)
        .background(themeColors.cardBackground)
        .cornerRadius(8)
    }
    
    // MARK: - Login Content
    
    @ViewBuilder
    private var loginContent: some View {
        VStack(spacing: 24) {
            // Welcome message
            VStack(spacing: 8) {
                Image(systemName: "person.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(themeColors.primary.opacity(0.7))
                
                Text("Welcome to OpenFlux")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeColors.text)
                
                Text("Sign in to sync your preferences across devices")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(themeColors.text.opacity(0.7))
            }
            .padding(.vertical)
            
            if showEmailLogin {
                emailLoginForm
            } else {
                providerButtons
            }
            
            if let error = authManager.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private var providerButtons: some View {
        VStack(spacing: 12) {
            // Sign in with Apple
            SignInWithAppleButton(
                onRequest: { _ in },
                onCompletion: { result in
                    switch result {
                    case .success:
                        Task {
                            try? await authManager.signInWithApple()
                        }
                    case .failure(let error):
                        print("Apple Sign In failed: \(error)")
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 44)
            .cornerRadius(8)
            
            // Sign in with Google
            Button(action: {
                Task {
                    try? await authManager.signInWithGoogle()
                }
            }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Continue with Google")
                }
                .foregroundStyle(themeColors.text)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeColors.cardBackground)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(authManager.isLoading)
            
            // Sign in with Microsoft
            Button(action: {
                Task {
                    try? await authManager.signInWithMicrosoft()
                }
            }) {
                HStack {
                    Image(systemName: "building.2.fill")
                    Text("Continue with Microsoft")
                }
                .foregroundStyle(themeColors.text)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeColors.cardBackground)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(authManager.isLoading)
            
            // Divider
            HStack {
                Rectangle()
                    .fill(themeColors.text.opacity(0.2))
                    .frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(themeColors.text.opacity(0.5))
                Rectangle()
                    .fill(themeColors.text.opacity(0.2))
                    .frame(height: 1)
            }
            .padding(.vertical, 8)
            
            // Sign in with Email
            Button(action: {
                showEmailLogin = true
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Continue with Email")
                }
                .foregroundStyle(themeColors.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeColors.cardBackground)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(authManager.isLoading)
            
            if authManager.isLoading {
                ProgressView()
                    .padding()
            }
        }
    }
    
    @ViewBuilder
    private var emailLoginForm: some View {
        VStack(spacing: 16) {
            // Back button
            HStack {
                Button(action: {
                    showEmailLogin = false
                    isSignUp = false
                    email = ""
                    password = ""
                    displayName = ""
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(themeColors.primary)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            Text(isSignUp ? "Create Account" : "Sign In")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(themeColors.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Email field
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.caption)
                    .foregroundStyle(themeColors.text.opacity(0.7))
                
                TextField("your@email.com", text: $email)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(themeColors.cardBackground)
                    .cornerRadius(8)
            }
            
            if isSignUp {
                // Display name field (optional for sign up)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Name (optional)")
                        .font(.caption)
                        .foregroundStyle(themeColors.text.opacity(0.7))
                    
                    TextField("John Doe", text: $displayName)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(themeColors.cardBackground)
                        .cornerRadius(8)
                }
            }
            
            // Password field
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.caption)
                    .foregroundStyle(themeColors.text.opacity(0.7))
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(themeColors.cardBackground)
                    .cornerRadius(8)
                
                if isSignUp {
                    Text("At least 8 characters")
                        .font(.caption2)
                        .foregroundStyle(themeColors.text.opacity(0.5))
                }
            }
            
            // Submit button
            Button(action: {
                Task {
                    do {
                        if isSignUp {
                            try await authManager.signUpWithEmail(
                                email: email,
                                password: password,
                                displayName: displayName.isEmpty ? nil : displayName
                            )
                        } else {
                            try await authManager.signInWithEmail(email: email, password: password)
                        }
                    } catch {
                        print("Auth error: \(error)")
                    }
                }
            }) {
                Text(isSignUp ? "Create Account" : "Sign In")
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeColors.primary)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
            
            // Toggle sign up/sign in
            Button(action: {
                isSignUp.toggle()
            }) {
                Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                    .font(.caption)
                    .foregroundStyle(themeColors.primary)
            }
            .buttonStyle(.plain)
            
            if authManager.isLoading {
                ProgressView()
                    .padding()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func providerIcon(_ provider: AuthProvider) -> String {
        switch provider {
        case .apple:
            return "apple.logo"
        case .google:
            return "g.circle.fill"
        case .microsoft:
            return "building.2.fill"
        case .email:
            return "envelope.fill"
        }
    }
    
    private var syncStateIcon: String {
        switch appState.syncState {
        case .idle:
            return "checkmark.circle.fill"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disabled:
            return "pause.circle.fill"
        case .noAccount:
            return "person.crop.circle.badge.xmark"
        }
    }
    
    private var syncStateColor: Color {
        switch appState.syncState {
        case .idle:
            return .green
        case .syncing:
            return .blue
        case .error:
            return .red
        case .disabled:
            return .gray
        case .noAccount:
            return .orange
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(themeColors.text.opacity(0.6))
            Spacer()
            Text(value)
                .foregroundStyle(themeColors.text.opacity(0.9))
                .font(.system(.body, design: .monospaced))
        }
        .font(.caption)
    }
}
