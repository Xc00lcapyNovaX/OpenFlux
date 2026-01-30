# OpenFlux – Windows Game Compatibility Layer for macOS
Project name: OpenFlux (internal targets/bundle still named "Flux").

A clean, minimal macOS launcher for running Windows games via Wine, with optional GPTK for DirectX → Metal translation.

## Features

- **Steam Game Detection** - Automatically discovers installed Steam games
- **Run Button** - Quick access to run any Windows executable from the Dashboard
- **Finder Integration** - Right-click .exe/.msi/.dll files and "Open With → OpenFlux"
- **Open With (.exe/.msi/.dll)** - Run Windows executables via Wine (GPTK optional)
- **Automatic Dependency Handling** - Detects missing DLLs and creates stub DLLs for compatibility
- **Per-Game GPTK Mode** - Inherit / Enabled / Disabled per title
- **Targeted Dependency Prompt** - For launcher-like EXEs, probe common runtime components and ask before installing
- **Wine Prefix Split** - x64 (default) vs x86 (32-bit) prefixes
- **DLL Injection Support** - Inject mods (e.g., MegaHack v9 Pro) via `~/.flux/dlls/`
- **Comprehensive Logging** - Real-time logs and categorized system events
- **Wine Smoke Test** - Validate that Wine can run basic commands from inside OpenFlux
- **Developer Feedback** - Built-in feedback button to send reports to developers
- **Dashboard with Recents** - View recently launched games and quick actions

## System Requirements

- macOS 13.0 or later
- Apple Silicon or Intel Mac with Metal support
- Wine installed (required, base `wine` binary; `wine64` is not present on Apple Silicon)
- Apple Game Porting Toolkit (GPTK) installed (optional, recommended for DirectX)
- Windows ARM64 executables are not supported (Windows x86/x64 only)

## Architecture

### Core Services (Singleton Pattern)

All core services use the singleton pattern to ensure a single source of truth:

- **LogManager.shared** - Centralized logging with thread-safe concurrent queue
- **SettingsManager.shared** - Configuration storage and directory management
- **SteamLibraryDetector** - Parses Steam installation and game manifests
- **GameLauncher** - Thin wrapper that delegates launch flow
- **LaunchCoordinator** - Launch policy and failure handling (Steam vs EXE, retries)
- **WineEnvironmentBuilder** - Environment variables and GPTK wiring
- **WineProcessRunner** - Process execution and logging
- **DLLInjector** - Optional per-game DLL injection
- **DependencyManager** - Verifies and installs required DLLs, detects DRM
- **ProcessMonitor** - Tracks running game processes and resource usage
- **MetalDeviceDetector** - Detects Metal device capabilities

### State Management (MVVM + Reactive)

- **AppState** - Central @ObservableObject managing game detection, launching, and prefix lifecycle
- **Environment Objects** - All views receive @EnvironmentObject for appState and logManager
- **Reactive Binding** - UI automatically updates when services publish changes
- **DLLDependencyResolver** - Analyzes executables for missing DLLs and generates stubs for compatibility

### User Interface

- **ContentView** - NavigationSplitView main layout with sidebar navigation
- **GamesView** - Browse detected games with launch confirmation and dependency warnings
- **PrefixesView** - Create, delete, and manage Wine prefixes
- **LogsView** - Real-time log display with filtering and export
- **SettingsView** - Configure GPTK/Wine paths, verify installation, access utilities
- **DependenciesView** - Manage missing DLLs and create stubs (planned)

## Installation

```bash
# Clone repository
git clone https://github.com/yourusername/openflux.git
cd OpenFlux

# Build the app
xcodebuild -scheme Flux -configuration Release
```

## How It Works

### Service Integration

Services communicate through a cohesive pattern:

1. **AppState** coordinates high-level game operations
2. **Services** (LogManager, SettingsManager, etc.) are accessed via singleton instances
3. **Views** receive AppState and LogManager through environment objects
4. **Error handling** flows from services → AppState → UI error messages
5. **Logging** is categorized (Games, Prefixes, Settings, etc.) for organized output

### Singleton Usage Example

```swift
// In services
private let logManager = LogManager.shared
private let settingsManager = SettingsManager.shared

// In views
@EnvironmentObject var appState: AppState
@EnvironmentObject var logManager: LogManager
@ObservedObject var settingsManager = SettingsManager.shared
```

### Error Message Flow

When an error occurs:
1. Service logs the error with category
2. Service sets errorMessage on AppState
3. UI displays error banner with details
4. User can dismiss error to continue

## Usage

### Running Windows Executables

**Method 1: Dashboard Run Button**
1. Launch OpenFlux
2. Go to Dashboard
3. Click the "Run" button
4. Select a .exe, .msi, or .dll file from Finder
5. The game/application will launch with Wine

**Method 2: Finder "Open With"**
1. Right-click any .exe, .msi, or .dll file in Finder
2. Select "Open With" → "OpenFlux"
3. The executable will be launched automatically

**Method 3: Steam Games**
1. Launch OpenFlux
2. Games are automatically detected from Steam library
3. Click a game to select it
4. Click "Launch" to start the game
5. Monitor output in the Logs tab
6. Configure GPTK and Wine settings as needed

## Configuration

Settings are stored in `~/.flux/` directory:

```
~/.flux/
├── prefix-native     # Default x64 Wine prefix (WOW64-capable)
├── prefix-x86        # x86 Wine prefix (win32)
└── logs/             # App logs
```

## Troubleshooting

### Games Not Detected
- Ensure Steam is properly installed
- Check `Settings` → verify installation paths
- Review logs for detection errors

### Missing Dependencies
- OpenFlux will alert about missing DLLs
- Use "Install Dependencies" in game context menu
- Or run dependency installer from Settings

### DRM Protected Games
- Games with DRM (Denuvo, etc.) show a lock icon
- These may not work even with GPTK
- Check game-specific compatibility reports

## Development

### Building

```bash
xcodebuild build -scheme Flux
```

### Testing

```bash
xcodebuild test -scheme Flux
```

### Project Structure

```
OpenFlux/
├── FluxApp.swift              # App entry point
├── Models/
│   ├── AppState.swift         # Application state
│   └── Game.swift             # Data models
├── Services/
│   ├── SteamLibraryDetector.swift
│   ├── GameLauncher.swift
│   ├── LaunchCoordinator.swift
│   ├── WineEnvironmentBuilder.swift
│   ├── WineProcessRunner.swift
│   ├── DLLInjector.swift
│   ├── DependencyManager.swift
│   └── LogManager.swift
├── Tests/
│   └── LaunchEnvironmentTests.swift
├── Resources/
│   └── OpenFlux.icns
└── Views/
    ├── ContentView.swift      # Main layout
    ├── GamesView.swift        # Games browser
    ├── PrefixesView.swift     # Prefix management
    ├── LogsView.swift         # Log viewer
    └── SettingsView.swift     # Settings panel
```

## Technical Notes

### Initialization Flow

1. **FluxApp.swift** - App entry point
   - Calls `SettingsManager.setupDirectories()` to ensure ~/.flux exists
   - Provides @StateObject AppState to all views
   - Provides @EnvironmentObject LogManager for logging

2. **SettingsManager** - Configuration storage
   - Singleton pattern ensures single instance
   - Creates directory structure on first run
   - UserDefaults for persistent configuration

3. **LogManager** - Thread-safe logging
   - Concurrent dispatch queue with barrier for thread safety
   - Categories: Games, Prefixes, Settings, Services
   - Accessible from all views via environment object

### Game Detection Flow

1. User opens app or clicks Refresh
2. AppState.detectGames() calls SteamLibraryDetector
3. SteamLibraryDetector parses Steam manifests
4. DependencyManager checks each game for missing DLLs and DRM
5. Games sorted alphabetically and displayed
6. Errors logged and displayed in error banner

### Game Launch Flow

1. User selects game and clicks Launch
2. AppState.launchGame() validates game path
3. AppState calls GameLauncher.launch()
4. GameLauncher delegates to LaunchCoordinator
5. DependencyManager probes missing components (runtime / game files / graphics backend)
6. OpenFlux prompts for install consent if missing
7. WineEnvironmentBuilder assembles environment variables (GPTK optional)
8. WineProcessRunner executes the process
9. ProcessMonitor tracks execution
10. Output streamed to LogManager in real-time

### Wine Execution (GPTK Optional)

Games are launched with:

```bash
WINEPREFIX=~/.flux/prefix \
wine /path/to/game.exe
```

When enabled, GPTK translates D3D11/12 calls to Metal without requiring DXVK or Proton.

### Environment Variables

Key variables set during launch:

- `WINEPREFIX` - Prefix path (~/.flux/prefix)
- `WINE` - Wine executable path
- `WINESERVER` - Wineserver executable path
- `DYLD_LIBRARY_PATH` - GPTK lib search path (when enabled)
- `METAL_DEVICE_CAPTURE_ENABLED` - GPTK capture support
- `SteamAppId` / `SteamGameId` - Steam context for Steam games
- `STAGING_SHARED_MEMORY` - Wine memory optimization
- `WINE_CPU_TOPOLOGY` - CPU topology hints for Wine

### Dependency Handling

Required DLLs are managed with user consent (non-Steam EXEs):

- `d3dx9_43.dll` - DirectX 9 extensions
- `xinput1_3.dll` - Xbox 360 controller support
- `xaudio2_7.dll` - XAudio2 audio system
- `steam_api64.dll` - Steam integration

Dependencies are grouped by category:
- **Runtime Components** (DirectX/XAudio/XInput) — installed into the Wine prefix
- **Game Files** (Steam API) — verified in the game folder, resolved via Steam when needed
- **Graphics Backend** (DXVK) — optional, enabled per user choice

### Logging Categories

All logs include category for easy filtering:

- **Games** - Game detection and launching
- **Prefixes** - Wine prefix creation and management
- **Settings** - Configuration changes
- **Services** - Service-level operations
- **Engine** - Game engine and runtime output

### Error Codes

OpenFlux uses structured error codes for easier debugging:

| Code | Category | Description |
|------|----------|-------------|
| OF-L001 | Launch | Wine is not installed |
| OF-L002 | Launch | Game executable not found |
| OF-L003 | Launch | Failed to start game process |
| OF-L004 | Launch | DRM detected - game may not run |
| OF-L005 | Launch | Wine prefix not found |
| OF-L006 | Launch | Unsupported architecture (ARM64) |
| OF-F001 | File | File not found |
| OF-F002 | File | Cannot access file |
| OF-F003 | File | Unsupported file type |
| OF-F004 | File | No executable found in folder |
| OF-S001 | Steam | Steam not installed |
| OF-S002 | Steam | Steam library not found |
| OF-S003 | Steam | Steam game not found |
| OF-D001 | Dependency | Missing dependency |
| OF-D002 | Dependency | Dependency installation failed |
| OF-D003 | Dependency | winetricks not installed |
| OF-N001 | Network | Failed to send feedback |
| OF-N002 | Network | Network request timed out |
| OF-X001 | System | Metal not supported |
| OF-X002 | System | Game Porting Toolkit not found |
| OF-X003 | System | Failed to create Wine prefix |

## License

Apache License 2.0 - See LICENSE file for details

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Support

For issues, feature requests, or questions:

- GitHub Issues: Report bugs and request features
- GitHub Discussions: Community support and discussions

## Roadmap

- [ ] Game configuration profiles
- [ ] Performance statistics and monitoring
- [ ] Automatic shader cache management
- [ ] DXVK shader compiler cache integration
- [ ] Network game support detection
- [ ] Custom launch scripts per game
- [ ] Game mod manager integration

## Credits

Built with:
- Swift and SwiftUI
- Apple Game Porting Toolkit
- Wine
- macOS native APIs

## Disclaimer

OpenFlux is provided as-is for compatibility testing. Not affiliated with Apple, Valve, or other game publishers. Respect game licenses and DRM policies.
