import Foundation

class GameLauncher {
    private let coordinator: LaunchCoordinator

    init(appState: AppState) {
        let environmentBuilder = WineEnvironmentBuilder(appState: appState)
        let processRunner = WineProcessRunner(appState: appState)
        let dllInjector = DLLInjector(appState: appState)
        self.coordinator = LaunchCoordinator(
            appState: appState,
            environmentBuilder: environmentBuilder,
            processRunner: processRunner,
            dllInjector: dllInjector
        )
    }

    func launch(_ game: Game) {
        coordinator.launch(game)
    }

    /// Launch a hardcoded test game using Wine (and GPTK if enabled)
    /// This is the MVP to prove the Flux launch pipeline works
    func launchTestGame() {
        coordinator.launchTestGame()
    }
}
