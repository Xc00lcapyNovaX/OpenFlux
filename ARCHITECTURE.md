# OpenFlux Architecture & Design Patterns
Project name: OpenFlux (internal targets/bundle still named "Flux").

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        OpenFlux App                              │
│                     (SwiftUI + Combine)                      │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
        ┌───────▼─────────┐        ┌────────▼────────┐
        │  ContentView    │        │   AppState      │
        │ (Main Layout)   │        │ (ObservableObj) │
        └───────┬─────────┘        └────────┬────────┘
                │                           │
        ┌───────▼────────────────────┬──────▼────────────────────┐
        │                            │                           │
    ┌───▼────┐  ┌─────────┐  ┌───────▼────┐  ┌────────────┐    │
    │ Games  │  │Prefixes │  │ LogManager │  │ Settings   │    │
    │ View   │  │ View    │  │ (Logging)  │  │ Manager    │    │
    └───┬────┘  └─────────┘  └────────────┘  └────────────┘    │
        │                                                         │
        │                    Service Layer                        │
        ▼                                                         ▼
┌────────────────────────────────────────────────────────────────────┐
│                                                                    │
│  ┌─────────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │ Steam Library   │  │Game Launcher │  │ Dependency Manager   │ │
│  │ Detector        │  │(Wine (GPTK optional))   │  │(DLL Management)      │ │
│  └────────┬────────┘  └──────┬───────┘  └──────────────────────┘ │
│           │                  │                                    │
│  ┌────────▼──────────┐  ┌────▼──────────┐  ┌────────────────┐   │
│  │ Process Monitor   │  │ Metal Device  │  │Settings Manager│   │
│  │(Running games)    │  │ Detector      │  │(Persistent)    │   │
│  └───────────────────┘  └───────────────┘  └────────────────┘   │
└────────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
        ┌───────▼──────────┐       ┌────────▼────────┐
        │  FileSystem      │       │  macOS APIs     │
        │  (~/.flux/)      │       │  (Process,      │
        │                 │       │   system info)  │
        └──────────────────┘       └─────────────────┘
```

## Data Flow Diagram

### Game Launch Sequence

```
User Action
    │
    ▼
┌─────────────────────────────────┐
│ GamesView: "Launch" Button      │
│ appState.launchGame(game)       │
└────────────┬────────────────────┘
             │
             ▼
    ┌─────────────────────────────────┐
    │ AppState                        │
    │ → Verify game data              │
    │ → Queue background task         │
    └────────┬────────────────────────┘
             │
             ▼ (userInitiated QoS)
    ┌─────────────────────────────────┐
    │ GameLauncher.launch()           │
    └────────┬────────────────────────┘
             │
             ▼
    ┌─────────────────────────────────┐
    │ DependencyManager               │
    │ .checkDependencies(game)        │
    │ ├─ Check DLL presence           │
    │ ├─ Detect DRM                   │
    │ └─ Log warnings                 │
    └────────┬────────────────────────┘
             │
             ▼
    ┌─────────────────────────────────┐
    │ WineEnvironmentBuilder          │
    │ ├─ WINEPREFIX                   │
    │ ├─ DYLD_LIBRARY_PATH           │
    │ ├─ Metal device info            │
    │ └─ D3D settings                 │
    └────────┬────────────────────────┘
             │
             ▼
    ┌─────────────────────────────────┐
    │ Process.run()                   │
    │ wine /path/to/game.exe        │
    └────────┬────────────────────────┘
             │
    ┌────────┴──────────┐
    │ Dual Output       │
    │ Capture Threads   │
    │                   │
    ▼ (bg queue)    ▼ (bg queue)
 stdout          stderr
    │                 │
    └────────┬────────┘
             │
             ▼
    ┌─────────────────────────────────┐
    │ LogManager.log()                │
    │ ├─ Timestamp entry              │
    │ ├─ Add to @Published logs array │
    │ └─ Trim if > 1000 entries       │
    └────────┬────────────────────────┘
             │
             ▼ (MainThread)
    ┌─────────────────────────────────┐
    │ LogsView                        │
    │ Updates display in real-time    │
    └─────────────────────────────────┘
```

## State Management Pattern

### Combine + SwiftUI Integration

```
┌────────────────────────────────────┐
│  AppState (ObservableObject)       │
│  @Published properties:            │
│  ├─ games: [Game]                  │
│  ├─ prefixes: [GamePrefix]         │
│  ├─ isLoading: Bool                │
│  ├─ errorMessage: String?          │
│  └─ runningGames: [UUID: ProcInfo] │
└─────────────┬──────────────────────┘
              │ Combine @Published
              │ Automatically notifies
              ▼
┌────────────────────────────────────┐
│  Views (Subscribed to AppState)    │
│  @EnvironmentObject var appState   │
│  └─ Receives updates automatically │
│     on any @Published change       │
└────────────────────────────────────┘

Thread Safety:
  • State mutations: Main thread
  • Background work: Background QoS
  • Results: DispatchQueue.main.async
```

## Service Layer Pattern (Singleton Architecture)

### Singleton Services

All core services use the singleton pattern to ensure single source of truth:

```swift
// Shared singleton instances
let logManager = LogManager.shared           // Thread-safe logging
let settingsManager = SettingsManager.shared  // Persistent config

// These are accessed from AppState and all services
```

### Service Dependencies

```
Presentation Layer (SwiftUI Views)
    ├─ @EnvironmentObject appState
    ├─ @EnvironmentObject logManager
    └─ @ObservedObject settingsManager = SettingsManager.shared
    ↓
Application Logic Layer (AppState)
    ├─ Services communicate with AppState via completion handlers
    └─ AppState updates @Published properties
    ↓
Service Layer (Singleton Pattern)
    ├─ LogManager.shared               (Thread-safe logging)
    ├─ SettingsManager.shared          (Persistent configuration)
    ├─ SteamLibraryDetector           (Game detection - stateless)
    ├─ GameLauncher                   (Game execution - stateless)
    ├─ DependencyManager              (Dependency checking - stateless)
    ├─ ProcessMonitor                 (Process tracking - stateless)
    └─ MetalDeviceDetector            (GPU detection - stateless)
    ↓
Foundation/Darwin APIs
    ├─ Process management (Foundation)
    ├─ FileSystem (FileManager)
    ├─ System profiling (Darwin)
    └─ User preferences (UserDefaults)

Key Benefit: No duplicate instances means:
  • Single source of truth
  • Proper state synchronization
  • Simplified dependency management
  • Predictable error handling
```

### Separation of Concerns

```
Presentation Layer (SwiftUI Views)
    ↓
Application Logic Layer (AppState)
    ├─ State management
    ├─ Coordination
    └─ Business logic
    ↓
Service Layer (Game*, Dependency*, Log*, etc.)
    ├─ Specific responsibilities
    ├─ Stateless operations
    └─ Platform interactions
    ↓
Foundation/Darwin APIs
    ├─ Process management
    ├─ FileSystem
    ├─ System profiling
    └─ User preferences
```

## MVVM Pattern Application

### Model-View-ViewModel Structure

```
Model Layer (Models/)
├─ Game                    (Identifiable, Codable)
├─ GamePrefix              (Identifiable, Codable)
└─ GameConfig              (Codable)

ViewModel Layer (AppState)
├─ Manages state (@Published)
├─ Coordinates services
├─ Transforms model data
└─ Handles user actions

View Layer (Views/)
├─ GamesView              (Displays games)
├─ PrefixesView           (Manages prefixes)
├─ LogsView               (Shows logs)
├─ SettingsView           (Configuration)
└─ ContentView            (Main layout)

Services (Helpers to ViewModel)
├─ SteamLibraryDetector   (Find games)
├─ GameLauncher           (Execute)
├─ DependencyManager      (Verify DLLs)
├─ LogManager             (Collect logs)
├─ SettingsManager        (Persist config)
└─ MetalDeviceDetector    (GPU info)
```

## Concurrency Model

### Thread Safety Guarantees

```
Main Thread (UIThread)
    ├─ All @Published updates
    ├─ All View updates
    └─ All SwiftUI state mutations

Background Threads
    ├─ Game detection (userInitiated QoS)
    ├─ Process execution (userInitiated QoS)
    ├─ Output capture (background QoS)
    ├─ Logging (serial queue)
    └─ File operations (userInitiated QoS)

Thread Bridging
    └─ DispatchQueue.main.async for results
       back to MainThread
```

### Process Execution Flow

```
Main Thread: appState.launchGame(game)
             │
             ├─→ DispatchQueue.global(qos: .userInitiated)
             │   └─ launcher.launch(game)
             │      ├─ WineEnvironmentBuilder.buildEnvironment()
             │      ├─ buildWineCommand()
             │      └─ Process.run()
             │         │
             │         ├─→ DispatchQueue.global()
             │         │   └─ Capture stdout
             │         │      └─ logManager.log()
             │         │         └─ DispatchQueue.main.async
             │         │
             │         └─→ DispatchQueue.global()
             │             └─ Capture stderr
             │                └─ logManager.error()
             │                   └─ DispatchQueue.main.async
             │
             └─ @Published change triggers
                View update on MainThread
```

## Error Handling Strategy

### Error Propagation

```
User Action
    ↓
Validation
├─ Game exists?
├─ Path valid?
└─ Wine available?
    │
    ├─ YES → Continue execution
    │
    └─ NO → Set errorMessage
            ├─ Display in UI
            ├─ Log to Logs view
            └─ Offer recovery action
```

### Graceful Degradation

```
Missing Wine Executable
    └─ Display: "Wine not found"
       Action: "Configure path in Settings"
       
Missing GPTK
    └─ Display: "GPTK not found"
       Action: "Install GPTK from Apple Developer"
       
Missing Game DLLs
    └─ Display: "Missing dependencies"
       Action: "Install from Settings"
       
DRM-Protected Game
    └─ Display: "DRM detected"
       Action: "Proceed anyway / Cancel"
```

## Caching Strategies

### Steam Game Detection Cache

```
First Run:
    SteamLibraryDetector.detectInstalledGames()
    ├─ Scan filesystem
    ├─ Parse VDF/ACF manifests
    ├─ Expensive (~3-10 seconds)
    └─ Results stored in AppState.games

Subsequent Runs:
    AppState.games already populated
    └─ No rescan until "Refresh" clicked

User Refresh:
    [Refresh Button]
    ├─ Re-run detection
    ├─ Update AppState.games
    └─ Show updated list
```

### Log Trimming

```
Logs added continuously
    ↓
Check length
    ├─ If < 1000: Keep all
    └─ If >= 1000: 
        Remove first 500 entries
        Keep newest 500
```

## Dependency Injection Pattern

### App Initialization (FluxApp.swift)

```swift
@main
struct FluxApp: App {
    @StateObject var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(LogManager.shared)
        }
        .onAppear {
            SettingsManager.shared.setupDirectories()
        }
    }
}
```

**Initialization Flow:**
1. App launches - FluxApp creates AppState as @StateObject
2. setupDirectories() called to ensure ~/.flux exists
3. LogManager.shared and SettingsManager.shared are accessible globally
4. Environment objects injected to all views
5. Views automatically subscribe to @Published changes

### Singleton Access Pattern

```swift
// In any service or view
private let logManager = LogManager.shared
private let settingsManager = SettingsManager.shared

// Log from anywhere
logManager.log("Message", category: "Games")

// Access config from anywhere
let prefix = settingsManager.getAppDirectory()
```

### Environment Object Pattern

```swift
struct GamesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logManager: LogManager
    @ObservedObject var settingsManager = SettingsManager.shared
    
    // Views automatically update when @Published properties change
    // Error messages from AppState display in banner
    // Logs from LogManager display in real-time
}
```
    // Objects automatically available
    // to child views without passing
}

// In Views:
GamesView()
    .environmentObject(appState)
    .environmentObject(logManager)
```

## Property Wrapper Usage

### @Published (State Binding)

```swift
@Published var games: [Game] = []
// Automatically notifies subscribers
// when value changes
```

### @State (Local View State)

```swift
@State private var selectedGame: Game?
// Local to view, persists across renders
// Updates trigger view recompute
```

### @StateObject (Lifecycle Management)

```swift
@StateObject private var appState = AppState()
// Created once per view lifetime
// Persisted across view redraws
// Proper cleanup on deinit
```

### @EnvironmentObject (Dependency Access)

```swift
@EnvironmentObject var appState: AppState
// Injected from parent
// Must be provided or crash
// Type-safe access
```

## Configuration Management

### UserDefaults Storage

```
com.flux.wineDirectory
    ↓ Get/Set
UserDefaults.standard[prefix + key]
    ↓ Synced to
~/Library/Preferences/com.flux.launcher.plist
```

### File System Storage

```
~/.flux/                       (Main directory)
├── prefix/                    (Wine WINEPREFIX)
│   └── drive_c/windows/system32/  (DLLs)
├── prefixes/                  (Additional prefixes)
├── logs/                      (Session logs)
└── config.json               (Serialized config)
```

## Testing Approach

### SwiftUI Canvas Preview Blocks

Each view includes preview blocks for real-time canvas testing:

```swift
#Preview {
    GamesView()
        .environmentObject(AppState())
        .environmentObject(LogManager.shared)
}
```

**Preview Features:**
- Updates in real-time as code changes
- Can test environment object injection
- Test UI with mock AppState data
- Verify layout and navigation
- Fast iteration during development

### Manual Testing Checklist

```
✓ Steam game detection
✓ Game launch execution
✓ Dependency checking
✓ Logging display with categories
✓ Settings persistence
✓ Wine version detection
✓ Metal device detection
✓ Process termination
✓ Error message display and dismissal
✓ Prefix creation/deletion
✓ Singleton instance sharing
✓ Environment object injection
✓ LogManager thread safety
✓ SettingsManager directory setup
```

---

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Time (typical) |
|-----------|-----------|---|
| Detect games | O(n*m) | 3-10s |
| Launch game | O(1) | 2-5s |
| Check DLL | O(k) | <100ms |
| Capture logs | O(1) | <10ms |

Where:
- n = number of Steam libraries
- m = games per library
- k = number of DLLs to check

### Space Complexity

| Object | Size | Growth |
|--------|------|--------|
| Game object | ~500 bytes | Linear with # games |
| Log entry | ~200 bytes | Max 1000 entries |
| AppState | ~50KB | Relatively fixed |

## Design Principles Applied

1. **Single Responsibility** – Each class has one job
2. **Open/Closed** – Open for extension, closed for modification
3. **Liskov Substitution** – Services are interchangeable
4. **Interface Segregation** – Minimal required interfaces
5. **Dependency Inversion** – Depend on abstractions
6. **DRY** – Don't Repeat Yourself
7. **KISS** – Keep It Simple, Stupid

---

**Architecture Version:** 1.0  
**Pattern Reference:** SwiftUI + Combine Best Practices  
**Last Updated:** January 27, 2026
