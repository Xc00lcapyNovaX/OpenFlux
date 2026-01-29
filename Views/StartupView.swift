import SwiftUI

struct StartupView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedLauncher: String = "steam"
    @State private var isLoading = false
    @State private var hasLoggedIn = false  // Track login state for this session
    @State private var selectedLoginMethod: String = ""  // Track which login was tapped

    let launchers = [
        ("steam", "Steam", "💨"),
        ("epic", "Epic Games", "🎮"),
        ("ubisoft", "Ubisoft+", "🎯"),
        ("gog", "GOG", "🕹️"),
    ]

    var themeColors: ThemeManager.Colors {
        themeManager.colors(for: themeManager.currentTheme)
    }

    // Continue button is only enabled if launcher selected AND logged in
    var isContinueEnabled: Bool {
        !selectedLauncher.isEmpty && hasLoggedIn
    }

    var body: some View {
        ZStack {
            themeColors.background.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left side - Launcher selection
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Welcome to OpenFlux")
                            .font(.title.bold())
                            .foregroundStyle(themeColors.text)

                        Text("Let's get you set up")
                            .font(.subheadline)
                            .foregroundStyle(themeColors.text.opacity(0.85))
                    }

                    VStack(spacing: 16) {
                        Text("Which game launcher do you use?")
                            .font(.headline)
                            .foregroundStyle(themeColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(launchers, id: \.0) { id, name, emoji in
                            LauncherButton(
                                id: id,
                                name: name,
                                emoji: emoji,
                                isSelected: selectedLauncher == id,
                                colors: themeColors
                            )
                            .onTapGesture {
                                selectedLauncher = id
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Text("You can change this anytime in Settings")
                            .font(.caption)
                            .foregroundStyle(themeColors.secondaryText)

                        Button(action: continueOnboarding) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(.white)
                            } else {
                                Text("Continue")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isContinueEnabled ? themeColors.primary : themeColors.secondaryText
                        )
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                        .disabled(!isContinueEnabled)
                        .opacity(isContinueEnabled ? 1.0 : 0.5)

                        if !hasLoggedIn {
                            Text("⚠️ Please log in first")
                                .font(.caption2)
                                .foregroundStyle(themeColors.warning)
                        }
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(themeColors.secondaryBackground)

                Divider()
                    .ignoresSafeArea()

                // Right side - Login panel
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundStyle(themeColors.text)

                        if hasLoggedIn {
                            Text("✅ Logged in")
                                .font(.caption)
                                .foregroundStyle(themeColors.success)
                        } else {
                            Text("TBA - Please select an option")
                                .font(.caption)
                                .foregroundStyle(themeColors.warning)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        Button(action: { handleLogin(with: "Google") }) {
                            LoginOptionButton(
                                name: "Google",
                                icon: "g.circle.fill",
                                colors: themeColors,
                                isEnabled: true,
                                isSelected: selectedLoginMethod == "Google"
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: { handleLogin(with: "Apple") }) {
                            LoginOptionButton(
                                name: "Apple",
                                icon: "apple.logo",
                                colors: themeColors,
                                isEnabled: true,
                                isSelected: selectedLoginMethod == "Apple"
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: { handleLogin(with: "Microsoft") }) {
                            LoginOptionButton(
                                name: "Microsoft",
                                icon: "m.circle.fill",
                                colors: themeColors,
                                isEnabled: true,
                                isSelected: selectedLoginMethod == "Microsoft"
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: { handleLogin(with: "Email") }) {
                            LoginOptionButton(
                                name: "Email",
                                icon: "envelope.fill",
                                colors: themeColors,
                                isEnabled: true,
                                isSelected: selectedLoginMethod == "Email"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Text("Login features coming soon")
                        .font(.caption2)
                        .foregroundStyle(themeColors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(themeColors.background)
            }
        }
        .onAppear {
            selectedLauncher = AppState.shared.settingsManager.selectedLauncher
        }
    }

    private func continueOnboarding() {
        isLoading = true

        // Use explicit AppState method to complete onboarding
        // This ensures proper notification and state synchronization
        AppState.shared.completeOnboarding(with: selectedLauncher)

        // ContentView will automatically re-render when
        // settingsManager.hasCompletedOnboarding changes via @Published notification
    }

    private func handleLogin(with provider: String) {
        selectedLoginMethod = provider
        hasLoggedIn = true
        appState.log("Login initiated with \(provider)", category: .ui)
    }
}

struct LauncherButton: View {
    let id: String
    let name: String
    let emoji: String
    let isSelected: Bool
    let colors: ThemeManager.Colors

    var body: some View {
        HStack(spacing: 16) {
            Text(emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(colors.text)

                Text("Detect games from \(name)")
                    .font(.caption)
                    .foregroundStyle(colors.secondaryText)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? colors.primary : colors.secondaryText)
        }
        .padding(16)
        .background(isSelected ? colors.primary.opacity(0.15) : colors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? colors.primary : Color.clear,
                    lineWidth: 2
                )
        )
    }
}

struct LoginOptionButton: View {
    let name: String
    let icon: String
    let colors: ThemeManager.Colors
    let isEnabled: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 24)

            Text(name)
                .font(.headline)

            Spacer()

            Text("TBA")
                .font(.caption)
                .foregroundStyle(colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(isSelected ? colors.primary.opacity(0.15) : colors.cardBackground)
        .foregroundStyle(isEnabled ? colors.text : colors.secondaryText)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? colors.primary : Color.clear,
                    lineWidth: 2
                )
        )
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

#if canImport(PreviewsMacros)
#if canImport(PreviewsMacros)
#Preview {
    StartupView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
#endif
#endif
