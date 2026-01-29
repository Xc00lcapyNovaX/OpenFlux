import SwiftUI

/// First-boot-only welcome screen (shown once, then never again)
/// Communicates OpenFlux as a system layer, not a launcher
/// Transitions smoothly on any user input (click or key)
struct FirstBootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isRevealed = false
    @State private var isTransitioning = false
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Calm, neutral background - not pretending to be macOS
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Minimal OpenFlux identity
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white.opacity(0.8))

                    Text("OpenFlux")
                        .font(.system(size: 42, weight: .medium, design: .default))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                // Subtle hint - appears after delay
                if isRevealed {
                    VStack(spacing: 8) {
                        Text("Click or press any key to continue")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundStyle(.white.opacity(0.5))
                            .transition(.opacity)
                    }
                    .opacity(isTransitioning ? 0 : 1)
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .focusable(true)
        .onAppear {
            // Reveal hint after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isRevealed = true
                }
            }
        }
        .onTapGesture {
            complete()
        }
    }

    private func complete() {
        guard !isTransitioning else { return }

        withAnimation(.easeInOut(duration: 0.4)) {
            isTransitioning = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onComplete()
        }
    }
}

#if canImport(PreviewsMacros)
    #Preview {
        FirstBootView {
            print("First boot completed")
        }
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
        .environmentObject(ThemeManager.shared)
    }
#endif
