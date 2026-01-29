# OpenFlux – Game Porting Toolkit Launcher
Project name: OpenFlux (internal targets/bundle still named "Flux").
## Complete Implementation Guide

This document provides comprehensive setup and implementation details for building, configuring, and extending OpenFlux.

---

## Project Overview

**OpenFlux** is a minimal, utility-first macOS launcher designed specifically for running Windows games via Apple's Game Porting Toolkit (GPTK). It eliminates the need to run Steam inside a Wine prefix and provides a clean interface for game management, logging, and system configuration.

### Core Principles

1. **Minimal UI** – Clean, uncluttered interface without gamer aesthetics
2. **Utility-First** – Focus on functionality over visual effects
3. **Reliability** – Robust error handling and detailed logging
4. **No Bloat** – Direct Wine (GPTK optional) execution without Proton/DXVK overhead
5. **User Control** – Clear system information and manual configuration options

---

## Project Structure

```
OpenFlux/
├── FluxApp.swift                  # SwiftUI @main entry point
├── Models/
│   ├── AppState.swift             # Central application state (Combine)
│   └── Game.swift                 # Data models for games, prefixes, configs
├── Services/
│   ├── SteamLibraryDetector.swift # Steam game discovery & VDF parsing
│   ├── GameLauncher.swift         # Launch entry point (delegates to coordinator)
│   ├── LaunchCoordinator.swift    # Launch policy + flow
│   ├── WineEnvironmentBuilder.swift # Env vars + GPTK wiring
│   ├── WineProcessRunner.swift    # Process execution + logging
│   ├── DLLInjector.swift          # Optional per-game DLL injection
│   ├── DependencyManager.swift    # DLL verification & installation
│   ├── LogManager.swift           # Real-time logging system
│   ├── SettingsManager.swift      # Persistent configuration storage
│   ├── ProcessMonitor.swift       # Running game tracking
│   └── MetalDeviceDetector.swift  # Metal GPU detection
├── Views/
│   ├── ContentView.swift          # Main window with NavigationSplitView
│   ├── DashboardView.swift        # Recents and quick actions
│   ├── GamesView.swift            # Game browser & launcher
│   ├── PrefixesView.swift         # Wine prefix management
│   ├── LogsView.swift             # Real-time log viewer
│   └── SettingsView.swift         # Configuration panel
├── Tests/
│   └── LaunchEnvironmentTests.swift # Env + command snapshot tests
├── Resources/
│   └── OpenFlux.icns              # App icon
├── Info.plist                     # macOS app metadata
├── README.md                      # User documentation
├── build.sh                       # Build script
└── Flux.xcodeproj/project.pbxproj # Project manifest
```

---

## Building & Running

### Method 1: Using Xcode (Recommended for Development)

```bash
# Open project in Xcode
open Flux.xcodeproj

# Build and run
xcodebuild build -scheme Flux -configuration Debug
```

### Method 2: Command-line Build

```bash
# Make build script executable
chmod +x build.sh

# Run build
./build.sh

# Launch the app
open build/Flux.app
```

### Method 3: SwiftUI Previews

Each view includes `#Preview` blocks for SwiftUI canvas preview:

```bash
# In Xcode, select View → Canvas or press Cmd+Option+Return
# Previews update in real-time as you edit
```

---

## Core Components Deep Dive

### 1. AppState (Models/AppState.swift)

Central `@ObservableObject` managing application state using Combine framework with reactive updates.

**Key Published Properties:**
- `@Published var games: [Game]` – Detected Steam games (sorted alphabetically)
- `@Published var prefixes: [GamePrefix]` – Wine prefix configurations
- `@Published var isLoading: Bool` – Game detection in progress
- `@Published var errorMessage: String` – User-facing error messages

**Key Methods:**
```swift
detectGames()              // Scan Steam, detect games, check dependencies
launchGame(_:)             // Validate and launch game with GPTK
createPrefix(name:)        // Create new Wine prefix
deletePrefix(_:)           // Remove Wine prefix from storage
loadPrefixes()             // Restore saved prefixes from SettingsManager
```

**Service Integration:**
AppState coordinates between services through method calls:
```swift
private let detector = SteamLibraryDetector()
private lazy var launcher = GameLauncher(appState: self)
private let dependencyManager = DependencyManager(appState: self)
private let settingsManager = SettingsManager.shared
private let logManager = LogManager.shared
```

**Error Handling Pattern:**
When services encounter errors:
1. Service logs error: `logManager.error("message", category: "Service")`
2. Service calls AppState completion handler with error
3. AppState sets errorMessage: `appState.errorMessage = error.localizedDescription`
4. UI displays error banner with dismiss button
5. User can dismiss error to continue working

**Example Error Flow:**
```swift
// In LaunchCoordinator
} catch {
    self.logManager.error(error.localizedDescription, category: "Games")
    completion(.failure(error))
}

// In AppState
launchGame(game) { result in
    switch result {
    case .failure(let error):
        self.errorMessage = "Failed to launch \(game.name): \(error.localizedDescription)"
    case .success:
        self.logManager.log("Game launched: \(game.name)", category: "Games")
    }
}
```

### 2. SteamLibraryDetector (Services/SteamLibraryDetector.swift)

Automatically discovers Steam installations and parses game metadata.

**Detection Process:**
1. Locate Steam directory (`~/Library/Application Support/Steam`)
2. Parse `libraryfolders.vdf` for additional Steam library locations
3. Scan each library's `steamapps/` for `.acf` manifest files
4. Extract game metadata: name, executable path, install directory, Steam ID
5. Return array of `Game` objects with populated properties

**VDF Parsing:**
The Steam manifest format uses Valve's VDF text format. The detector:
- Extracts key-value pairs from manifest files
- Handles quoted strings with embedded paths
- Supports multiple library installations
- Gracefully skips corrupted or unreadable manifests

### 3. GameLauncher + LaunchCoordinator (Services/GameLauncher.swift, Services/LaunchCoordinator.swift)

GameLauncher is a thin entry point that delegates to LaunchCoordinator. The coordinator owns launch policy (Steam vs EXE), dependency fast path, retry handling, and recents.

**Execution Flow:**
```
Game Launch
    ↓
Resolve per-game GPTK preference
    ↓
Steam fast path? (skip dependency checks)
    ↓
Build environment (WineEnvironmentBuilder)
    ↓
Build wine command
    ↓
Run process (WineProcessRunner)
    ↓
Monitor process completion
    ↓
Log results & cleanup
```

**Key Environment Variables:**
```bash
WINEPREFIX=~/.flux/prefix           # Wine prefix location
WINE=/opt/homebrew/bin/wine         # Wine executable
WINESERVER=/opt/homebrew/bin/wineserver
DYLD_LIBRARY_PATH=/opt/gptk/lib     # GPTK libraries (when enabled)
METAL_DEVICE_CAPTURE_ENABLED=1
SteamAppId=322170                   # Steam context (when available)
STAGING_SHARED_MEMORY=1             # Memory optimization
DXVK_HUD=off                        # Disable debug HUD
WINE_CPU_TOPOLOGY=[cores]
```

**Output Handling:**
- Captures stdout/stderr on separate threads
- Routes all output through LogManager
- Enables real-time log display in UI
- Preserves output for troubleshooting

### 4. DependencyManager (Services/DependencyManager.swift)

Verifies and installs required Windows components, grouped by category.

**Dependency Categories:**
```
Runtime Components
├── d3dx9_43.dll      (DirectX 9 runtime)
├── xinput1_3.dll     (XInput 1.3)
└── xaudio2_7.dll     (XAudio 2.7)

Game Files
└── steam_api64.dll   (Steam API, resolved from game/Steam install)

Graphics Backend (Optional)
└── dxvk_config.dll   (DXVK runtime configuration)
```

During direct EXE launches, OpenFlux shows a dependency prompt and asks for
explicit install consent before applying runtime/graphics components.

**DRM Detection:**
Games are checked against known DRM patterns:
- Denuvo (most common)
- SecuROM
- StarForce
- SecureDisc

Users are warned before launching, with option to proceed anyway.

### 5. LogManager (Services/LogManager.swift)

Real-time logging system with thread-safe concurrent access.

**Singleton Pattern:**
```swift
// Access from anywhere in the app
let logManager = LogManager.shared
```

**Log Entry Structure:**
```swift
struct LogEntry: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date        // When event occurred
    let level: LogLevel        // DEBUG, INFO, WARNING, ERROR
    let message: String        // Log message
    let category: String       // Games, Prefixes, Settings, Services
}

enum LogLevel: String, CaseIterable {
    case debug
    case info
    case warning
    case error
}
```

**Features:**
- **Thread-Safe** - Concurrent dispatch queue with barrier for safe reads/writes
- **Categorized** - Organized by component (Games, Prefixes, Settings, Services)
- **Auto-Trimming** - Maintains max 1000 entries to prevent memory issues
- **Filtering** - Filter by log level in UI
- **Export** - Copy to clipboard or save to file

**Usage:**
```swift
logManager.log("Message", category: "Games")
logManager.debug("Debug info", category: "Services")
logManager.warning("Warning", category: "Prefixes")
logManager.error("Error occurred", category: "Settings")
```

### 6. SettingsManager (Services/SettingsManager.swift)

Persistent configuration storage using `UserDefaults` with singleton pattern.

**Singleton Pattern:**
```swift
// Access from anywhere in the app
let settingsManager = SettingsManager.shared

// Called once on app launch
SettingsManager.shared.setupDirectories()
```

**Stored Settings:**
```swift
@Published var wineDirectory: String    // Wine installation path
@Published var gptkPath: String         // GPTK installation path
@Published var useGPTK: Bool           // Enable/disable GPTK
@Published var enableLogging: Bool      // Log game output
```

**Directory Structure:**
```
~/.flux/
├── prefix/              # Default Wine prefix (WINEPREFIX)
├── prefixes/            # Additional prefixes (per-game or custom)
├── logs/                # Game session logs
└── config.json          # Serialized settings
```

**Key Methods:**
```swift
setupDirectories()           // Create ~/.flux structure (called on app launch)
createDirectoryIfNeeded(_:)  // Ensure directory exists
getPrefixDirectory(_:)       // Get prefix path for specific prefix
getPrefixesDirectory()       // Get prefixes directory
getLogsDirectory()           // Get logs directory
save()                       // Save settings to UserDefaults
```

### 7. ProcessMonitor (Services/ProcessMonitor.swift)

Tracks running game processes and provides system statistics.

**Tracked Information:**
- Process ID (PID)
- Process name/game title
- Start time
- CPU usage (Darwin APIs)
- Memory consumption
- Process state

**Methods:**
```swift
startMonitoring(pid:, gameName:)  // Begin tracking
stopMonitoring(pid:)              // Stop tracking
isProcessRunning(pid:)            // Check if still running
terminateProcess(pid:, force:)    // Kill gracefully or forcefully
getProcessStats(pid:)             // Get CPU/memory stats
```

### 8. MetalDeviceDetector (Services/MetalDeviceDetector.swift)

Detects and reports Metal GPU capabilities.

**Detected Information:**
```swift
struct MetalInfo {
    let deviceName: String          // "M1 Max", "M3 Pro", etc.
    let architecture: String        // "Apple Silicon" or "Intel"
    let maxThreads: Int            // CPU core count
    let supportsD3D11: Bool        // GPTK support
    let supportsD3D12: Bool        // GPTK support
}
```

---

## UI Components

### Environment Object Injection Pattern

All views receive required dependencies through `@EnvironmentObject`:

```swift
// In FluxApp.swift
@StateObject var appState = AppState()
@EnvironmentObject(LogManager.shared)

// All views receive:
struct GamesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logManager: LogManager
    @ObservedObject var settingsManager = SettingsManager.shared
}
```

This ensures:
- Single source of truth for app state
- No duplicate service instances
- Reactive updates propagate automatically
- Proper error handling and logging throughout

### ContentView (Main Layout)

Uses `NavigationSplitView` with dynamic content switching:

1. **Sidebar** – Navigation buttons (Games, Prefixes, Logs, Settings)
2. **Content** – Dynamic view based on selection
3. **Error Banner** – Displayed in relevant views when errors occur

```swift
NavigationSplitView {
    // Sidebar with Games/Prefixes/Logs/Settings
} content: {
    // Dynamic content based on selection
    // Error messages shown in banner at top
}
```

### GamesView

Displays detected games in a searchable, sortable list.

**Features:**
- Real-time Steam detection
- Game status indicators (DRM warnings, missing DLLs)
- Play time tracking
- Last launch date
- Quick launch with confirmation
- Refresh button for re-scanning

**Display Elements:**
```
Game Name
├── Missing dependencies: [List]
├── DRM detected: [Lock icon]
└── Steam ID: 123456

Install Path: /path/to/game
Last played: 3 days ago
Playtime: 45 hours
```

### PrefixesView

Manages Wine prefixes for game isolation or custom configurations.

**Features:**
- Create new prefixes
- Delete unused prefixes
- Set default prefix
- Display Wine version per prefix
- Display GPTK version per prefix
- Show creation date and modification date

### LogsView

Real-time display of game output and system events.

**Features:**
- Color-coded log levels
- Filtering by level (All, Debug, Info, Warning, Error)
- Auto-scroll to latest entry
- Manual scroll control
- Copy individual log entries
- Export all logs
- Clear log history
- Timestamp display

### SettingsView

Configuration panel for GPTK, Wine, and launch options.

**Sections:**

1. **Wine & GPTK Configuration**
   - Wine directory path
   - GPTK installation path
   - Toggle GPTK usage

2. **System Information**
   - Wine version detection
   - GPTK version detection
   - Metal device detection

3. **Launch Options**
   - DXVK HUD toggle
   - Shared memory toggle
   - Shader compilation logging

4. **Utilities**
   - Verify installation (check paths)
   - Open prefix directory in Finder
   - Reset to defaults

---

## Technical Implementation Details

### Swift Language Features Used

**SwiftUI:**
- `@main` app entry point
- Declarative UI composition
- State management with `@State`, `@StateObject`, `@EnvironmentObject`
- Property wrappers for data binding
- List and navigation components
- Custom view modifiers

**Combine:**
- `ObservableObject` pattern
- `@Published` property wrappers
- Reactive state updates
- DispatchQueue integration for background tasks

**Foundation:**
- `Process` for executing Wine commands
- `FileManager` for file system operations
- `UserDefaults` for persistent storage
- `URLSession` (future networking)
- `Combine` for async operations

**Darwin APIs:**
- `kill()` for process termination
- `system_profiler` for hardware detection
- `os_log` for system logging

### Execution Architecture

**Game Launch Process:**

```swift
appState.launchGame(game)
    ↓
launcher.launch(game)
    ↓
launchCoordinator.launch(game)
    ↓
dependencyManager.checkDependencies()  (skipped for Steam games)
    ↓
WineEnvironmentBuilder.buildEnvironment()
    ↓
WineEnvironmentBuilder.buildCommand()
    ↓
WineProcessRunner.run()
    ↓
Capture stdout/stderr → LogManager
    ↓
Monitor process → ProcessMonitor
    ↓
await process.waitUntilExit()
    ↓
Log exit status
```

**Threading Model:**

- **Main Thread:** UI updates, state changes
- **User Initiated Queue:** Game detection, Steam scanning
- **Background Queue:** Process execution, output capture
- **Custom Serial Queue:** Logging (thread-safe)

---

## Configuration Files

### Info.plist

Standard macOS app bundle metadata:

```xml
<key>CFBundleIdentifier</key>
<string>com.flux.launcher</string>

<key>NSLocalNetworkUsageDescription</key>
<string>OpenFlux needs local network access to manage game processes.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Games may require microphone access.</string>

<key>NSCameraUsageDescription</key>
<string>Games may require camera access.</string>

<key>LSApplicationCategoryType</key>
<string>public.app-category.utilities</string>
```

### build.config

Compiler and build flags:

```
SWIFT_VERSION = 5.9
MINIMUM_OS_VERSION = 13.0
SWIFT_OPTIMIZATION_LEVEL = -O
```

---

## Extension Points

### Adding New Views

1. Create file in `Views/` directory
2. Define SwiftUI `View` struct
3. Add `@EnvironmentObject var appState: AppState`
4. Add navigation case in `ContentView.swift`
5. Add sidebar button with `NavigationLink`

Example:

```swift
struct NewView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            // Your UI here
        }
    }
}
```

### Adding Game Metadata

Extend `Game` model in `Models/Game.swift`:

```swift
struct Game: Identifiable, Codable {
    // Existing properties...
    
    // Add new properties:
    var customNotes: String = ""
    var launchArgs: String = ""
    var graphicsProfile: String = "Default"
}
```

### Custom Environment Variables

Modify `buildEnvironment` in `Services/WineEnvironmentBuilder.swift`:

```swift
static func buildEnvironment(
    base: [String: String],
    prefixPath: String,
    wineExecutable: String,
    wineserverPath: String?,
    useGPTK: Bool,
    gptkPath: String,
    executionEnvironment: ExecutionEnvironment,
    steamAppId: Int
) -> [String: String] {
    var environment = base
    // Add custom variables:
    environment["CUSTOM_VAR"] = "value"
    environment["GAME_SPECIFIC_SETTING"] = "value"
    return environment
}
```

### Additional DLL Dependencies

Extend dependency definitions in `Services/DependencyManager.swift`:

```swift
let runtimeComponents = [
    ("DirectX 9 Runtime", "d3dx9_43.dll", "..."),
]
```

---

## Testing & Debugging

### Enable Debug Logging

```swift
// In LaunchCoordinator.swift
logManager.debug("Detailed debug info", category: "LaunchCoordinator")
```

### Preview Views in Canvas

Each view includes preview blocks:

```swift
#Preview {
    GamesView()
        .environmentObject(AppState())
        .environmentObject(LogManager.shared)
}
```

### Monitor Process Execution

Check logs tab for:
- Game launch command
- Environment variables
- Process PID
- stdout/stderr output
- Exit status

### System Profiler

Verify installations manually:

```bash
# Check Wine
wine --version

# Check GPTK
ls /opt/gptk/

# Check system GPU
system_profiler SPDisplaysDataType
```

---

## Troubleshooting Guide

### Games Not Detected

1. Check Steam installation path in Settings
2. Verify `~/.steam` or `~/Library/Application Support/Steam` exists
3. Review logs for parsing errors
4. Manually verify Steam libraries exist

### Missing DLLs Warning

1. Check `~/.flux/prefix/drive_c/windows/system32/` for DLL files
2. Use "Install Dependencies" option
3. Or manually copy DLLs from system32 backup
4. Restart game launcher

### Game Fails to Launch

1. Check System Information in Settings
2. Verify GPTK path is correct
3. Check Logs for error messages
4. Test Wine installation: `wine notepad.exe`

### Logs Not Appearing

1. Ensure "Enable Logging" is toggled in Settings
2. Check if game is actually running
3. Verify stdout/stderr capture in WineProcessRunner

---

## Performance Optimization

### Compiled Release Build

```bash
swiftc -O -Osize \
    -target arm64-apple-macosx13.0 \
    *.swift
```

### Memory Management

- LogManager automatically trims entries above 1000
- ProcessMonitor releases resources when processes exit
- AppState uses weak references to prevent cycles

### Concurrency Best Practices

- Game detection runs on `userInitiated` QoS queue
- Logging uses dedicated serial queue
- UI updates always marshal to main thread
- Process output captured on background queues

---

## Future Enhancement Ideas

1. **Game Profiles** – Per-game launch configurations
2. **Shader Cache** – Automatic DXVK/GPTK shader caching
3. **Performance Monitoring** – Real-time FPS/CPU/Memory display
4. **Mod Manager** – Game mod installation and management
5. **Cloud Sync** – Game settings sync via iCloud
6. **Network Games** – Connection quality detection
7. **Streaming** – Built-in streaming to Discord/Twitch
8. **Multiplayer Helper** – Friend detection and network optimization

---

## Support & Resources

### Documentation
- [Swift Language Guide](https://docs.swift.org/swift-book)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Combine Framework](https://developer.apple.com/documentation/combine)

### Game Porting Toolkit
- [Apple GPTK Documentation](https://developer.apple.com/game-porting-toolkit/)
- [Wine Documentation](https://wiki.winehq.org/)

### Debugging
- Xcode Console output
- Activity Monitor for process inspection
- system_profiler for system information

---

## License & Credits

OpenFlux is provided as-is for game compatibility testing.

**Built with:**
- Swift and SwiftUI
- Apple Game Porting Toolkit
- Wine
- macOS native APIs

**Not affiliated with:** Apple, Valve, or game publishers. Respect game licenses and DRM policies.

---

**Version:** 0.1.0  
**Last Updated:** January 27, 2026  
**macOS Compatibility:** 13.0+
