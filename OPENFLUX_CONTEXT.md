# OpenFlux Project - Full Context Reference
Project name: OpenFlux (internal targets/bundle still named "Flux").

**Last Updated:** January 29, 2026  
**Status:** ✅ Build succeeded (0 errors, 0 warnings)  
**Purpose:** Native macOS game launcher for Windows games via Wine, with optional GPTK for DirectX → Metal translation

---

## 1. Project Overview

### What is OpenFlux?
A native SwiftUI macOS application that:
- Detects Windows games from multiple launchers (Steam, Epic Games, GOG, Ubisoft)
- Manages Wine prefixes for Windows game compatibility
- Detects and orchestrates both Wine (external Homebrew installation) and GPTK (Apple Game Porting Toolkit) as independent runtimes
- Launches games via Wine (always) with optional GPTK per-user/per-game
- Provides comprehensive logging, system detection, and game library management
- Creates a calm, intentional first-boot experience

### Target Platform
- **OS:** macOS 13.0+
- **Architecture:** Universal (arm64 native + x86_64, via `lipo`)
- **UI Framework:** SwiftUI
- **Swift Version:** 5+

### Build System
- **Xcode:** 14.0+ required
- **Build Tool:** xcodebuild
- **Project File:** Flux.xcodeproj/project.pbxproj (manually maintained)
- **Last Build:** ✅ BUILD SUCCEEDED

---

## 1.5 Quick Navigation Guide (Start Here)

**New to this codebase? Use this routing table:**

| I want to... | Go to... | Key Files |
|---|---|---|
| **Run the app** | Section 7: Build & Run | Terminal commands |
| **Understand the big picture** | Section 2: Critical Architecture | AppState, Wine/GPTK split (GPTK optional) |
| **Fix a startup crash** | Section 12: Debugging Reference | Circular dependencies, initialization |
| **Implement game launching** | LaunchCoordinator.swift + Section 11 | GameLauncher, LaunchCoordinator, WineEnvironmentBuilder |
| **Add a new persistent setting** | SettingsManager.swift + Section 11 | UserDefaults pattern |
| **Detect a new runtime** | WineDetector.swift as template | Create detector service + add to SystemDetector |
| **Add a new UI view** | ContentView.swift + Section 11 | Create view, add to switch statement |
| **Understand first-boot flow** | Section 3: First-Boot Experience | FluxApp.swift, FirstBootView |
| **See all files & their purposes** | Section 5: Project Structure | 31 Swift files listed |
| **Know what's completed vs planned** | Sections 8-9: Features Checklists | ✅ and ❌ lists |
| **Debug Wine/GPTK detection (GPTK optional)** | WineDetector.swift, GPTKDetector.swift + Section 12 | Debugging section |
| **Understand data flow** | Section 2: AppState, Section 6: Fixes | Lazy initialization pattern |

**Pro tip:** Search this document for any Swift filename or class name - it appears with context and purpose.

---

## 2. Critical Architecture & Patterns

### AppState - Single Source of Truth (Spine Pattern)
**File:** `Models/AppState.swift`

AppState is the **spine** - everything flows through it:
- `@ObservableObject` that owns all app state
- **NOT** for UI state (use @State/@StateObject in views)
- **IS** for app-level data: games, logs, system info, services, detection results
- Shared via singleton: `AppState.shared`

**Key properties:**
- `@Published var games: [Game]` - detected games
- `@Published var logs: [LogEntry]` - application logs
- `@Published var systemInfo: SystemDetector.SystemInfo` - system detection (Wine, GPTK, GPU)
- Services: `settingsManager`, `processMonitor`, lazy `launcher`, lazy `dependencyManager`

### Wine and GPTK - Separate Independent Detection
**Files:** `Services/WineDetector.swift` and `Services/GPTKDetector.swift`

**Critical Insight (Jan 28, 2026):** Wine and GPTK are now separate Homebrew dependencies, NOT bundled.

#### WineDetector
- **Purpose:** Detects standalone Wine installation (64-bit executable)
- **Search Pattern:** 
  1. Custom `wineDirectory` path (if set in Settings)
  2. `/opt/homebrew/bin/wine` (Homebrew ARM native)
  3. `/usr/local/bin/wine` (Homebrew Intel)
  4. Wine Stable.app (official installer)
- **Never assumes wine64:** Apple Silicon doesn't have it; looks only for `wine` executable
- **Caching:** Lazy-initialized cached properties prevent repeated filesystem scans
- **Validation:** Uses `isExecutableFile(atPath:)` not just `fileExists()`
- **Methods:**
  - `isAvailable: Bool` - cached result of detection
  - `wineExecutablePath: String?` - full path to wine binary
  - `wineserverPath: String?` - path to wineserver (for potential hangs)
  - `version: String?` - wine version via process call

#### GPTKDetector
- **Purpose:** Detects Apple Game Porting Toolkit (separate from Wine)
- **Location:** `/opt/gptk/lib` (standard installation path)
- **Check:** File existence of GPTK libraries
- **Methods:**
  - `isAvailable: Bool` - GPTK is installed
  - `libraryPath: String` - full path to GPTK lib directory

### Initialization Pattern - Lazy Initialization for Circular Dependencies
**Problem Solved:** Recursive dispatch_once deadlock on app startup (Jan 27, 2026)

**Solution Applied:**
All services that access `AppState.shared` during their init are made **lazy** in AppState:
```swift
private lazy var launcher = GameLauncher(appState: self)
private lazy var dependencyManager = DependencyManager(appState: self)
```

**Why it works:**
- Lazy properties defer creation until first access (after AppState.__init__ completes)
- Services receive AppState as init parameter instead of accessing singleton
- Breaks circular dependency chain

### System Detection - Split Launchers & Runtimes
**File:** `Services/SystemDetector.swift`

**Pattern:** Check for file existence, NOT running processes

**Current Detections:**
- **Game Launchers:** Steam, Epic, GOG, Ubisoft (file-based paths in `launcherFilePaths`)
- **Runtimes:** Wine (required, via WineDetector), GPTK (optional, via GPTKDetector)
- **GPU:** Metal GPU support and capabilities
- **Architecture:** x86_64 and arm64 support

**Key Method:**
```swift
public func getLaunchReadiness() -> ExecutionEnvironment.LaunchReadiness
```
Returns: which runtimes are available, GPU capabilities, full system state

### Settings Persistence
**File:** `Services/SettingsManager.swift`

**Pattern:** UserDefaults with prefix namespace
```swift
private let prefix = "com.flux."  // All keys prefixed
```

**Properties:**
- `wineDirectory` - Custom Wine installation path (if not default)
- `gptkPath` - Custom GPTK path (if not standard)
- `useGPTK` - Opt-in GPTK toggle (Wine remains the base runtime)
- `selectedLauncher` - "steam" | "epic" | "gog" | "ubisoft"
- `hasCompletedOnboarding` - First-time setup flag
- `enableLogging` - Enable debug logging
- `gptkModeOverrides` - Per-game GPTK mode (inherit / enabled / disabled)
- `graphicsAPIOverrides` - Per-game graphics API metadata

---

## 3. First-Boot Experience (NEW - Jan 28, 2026)

### FirstBootView - Intentional, Not Intrusive
**File:** `Views/SplashView.swift` (contains `FirstBootView` struct)

**Architecture:**
- Backed by `@AppStorage("hasCompletedFirstBoot")` in FluxApp
- Shows **only once** - then persisted forever
- No behavior changes on normal app launches

**Design Principles:**
- ✅ **Calm:** Dark background (not OS cosplay), minimal identity
- ✅ **Intentional:** Game controller icon + "OpenFlux" title + subtle hint text
- ✅ **Gentle:** 0.6s delay before hint appears, 0.4s fade-out transition
- ✅ **Respectful:** Click anywhere to continue, then automatic transition
- ✅ **System-level:** Communicates "OpenFlux is a layer" not "OpenFlux is pretending to be macOS"

**UX Flow:**
1. App launches
2. If `hasCompletedFirstBoot == false`: Show FirstBootView
3. Hint text fades in after 0.6s
4. User clicks anywhere
5. Smooth 0.4s fade transition
6. Transitions to main OpenFlux UI (onboarding or menu)
7. Flag set to true, persists
8. Next launch: Skips directly to main UI

**Code Pattern:**
```swift
// In FluxApp.swift
@AppStorage("hasCompletedFirstBoot") private var hasCompletedFirstBoot = false

var body: some Scene {
    WindowGroup {
        if hasCompletedFirstBoot {
            ContentView()  // Main OpenFlux UI
        } else {
            FirstBootView {
                hasCompletedFirstBoot = true  // Sets @AppStorage
            }
        }
    }
}
```

---

## 4. UI Architecture

### App Entry Point
**File:** `FluxApp.swift`

**Startup Sequence:**
1. Initialize SettingsManager directories
2. Log app launch
3. Load saved theme
4. Render window with conditional view:
   - If first boot: Show FirstBootView
   - Else if onboarding incomplete: Show StartupView
   - Else: Show main ContentView

### Startup/Onboarding Screen
**File:** `Views/StartupView.swift`

**Purpose:** First-time setup for launcher selection

**Features:**
- **Left Panel:** Launcher selection (Steam, Epic, GOG, Ubisoft)
- **Right Panel:** Login placeholder (Coming Soon)
- **Continue Button:** Saves selection, marks onboarding as complete

**Flow:**
1. User selects launcher
2. Clicks Continue
3. Settings saved to SettingsManager
4. View transitions to main OpenFlux UI

### Main Content View
**File:** `Views/ContentView.swift`

**Layout:**
- **Sidebar:** Games, Prefixes, Logs, Settings (List-based)
- **Content:** Dynamic based on sidebar selection (switch statement)

**Pattern:** Reactive state management via @EnvironmentObject AppState

### Dashboard + Recents (New)
**Files:** `Views/ContentView.swift`, `Models/AppState.swift`, `Services/LaunchCoordinator.swift`
- Added a Dashboard tab that shows recent launches
- Recent launches are tracked on every launch attempt
- Recents list shows name, method (Steam/Direct), and timestamp
- Launch failures show a Retry action in Games

### Dependency Prompt + Launcher Loading (New)
**Files:** `Views/GamesView.swift`, `Models/AppState.swift`, `Services/DependencyManager.swift`
- Direct EXE launches now show a loading overlay when the executable looks like a launcher/installer
- During loading, OpenFlux probes missing components and presents a categorized prompt
- Categories: Runtime Components, Game Files, Graphics Backend (DXVK optional)
- User must confirm required installs before launch

### Steam Fast Path (MVP)
**Files:** `Services/LaunchCoordinator.swift`, `Models/Game.swift`
- Steam-installed games skip DependencyManager checks
- Direct EXEs use dependency prompt + install flow
- Logs indicate when Steam fast path is used

### Open With (Finder)
**Files:** `FluxApp.swift`, `Models/AppState.swift`, `Info.plist`
- OpenFlux registers `.exe`/`.msi` as “Open with” document types
- Default launch environment is **x86** (configurable in Settings/Prefixes); 64-bit EXEs auto-fallback to **Native**
- Geometry Dash auto-detected by `app322170`/`GeometryDash.exe` → SteamAppId 322170

### Settings View
**File:** `Views/SettingsView.swift`

**Sections:**
- General settings (enable logging, etc.)
- Wine detection status (version, path)
- GPTK detection status (library path)
- LaunchReadiness summary (what runtimes are available)
- Wine smoke test utility (prefix init + cmd execution)
- Theme selection
- (Future) Custom paths for Wine/GPTK (GPTK optional)
- Patch notes visibility toggle is automatic; uses `SettingsManager.lastSeenVersion` to show a "What's New" sheet once per version.

---

## 5. Current Project Structure

```
OpenFlux/
├── FluxApp.swift                 # Entry point, window setup, first-boot logic
├── OpenFlux.icns                 # App icon
├── OPENFLUX_CONTEXT.md           # THIS FILE (updated Jan 29, 2026)
│
├── Models/
│   ├── AppState.swift            # Spine: central state management
│   └── Game.swift                # Game data model
│
├── Services/
│   ├── DLLInjector.swift          # Optional per-game DLL injection
│   ├── DependencyManager.swift    # Dependency/DLL checking
│   ├── DeveloperFeedback.swift    # Dev feedback system
│   ├── ExecutionEnvironment.swift # Execution modes (GPTK, Wine)
│   ├── GameLauncher.swift         # Game launching logic
│   ├── LaunchCoordinator.swift    # Launch policy and flow
│   ├── GPTKDetector.swift         # GPTK installation detection
│   ├── WineDetector.swift         # Wine installation detection (separate from GPTK)
│   ├── WineEnvironmentBuilder.swift # Wine/GPTK env construction
│   ├── HexColorPicker.swift       # Color utilities
│   ├── LogManager.swift           # Log file management
│   ├── MetalDeviceDetector.swift  # GPU detection
│   ├── ProcessMonitor.swift       # Process tracking
│   ├── SettingsManager.swift      # User settings persistence
│   ├── SteamLibraryDetector.swift # Steam integration
│   ├── SystemDetector.swift       # System environment detection
│   ├── ThemeExtension.swift       # Theme utilities
│   ├── ThemeManager.swift         # UI theme management
│   └── WineProcessRunner.swift    # Process execution + logging
│
├── Views/
│   ├── ContentView.swift          # Main layout (sidebar + content)
│   ├── DeveloperFeedbackView.swift # Dev tools UI
│   ├── GamesView.swift            # Games list & launch
│   ├── LogsView.swift             # Application logs viewer
│   ├── PrefixesView.swift         # Wine prefix management
│   ├── SettingsView.swift         # Application settings
│   ├── SplashView.swift           # FirstBootView (first-boot experience)
│   └── StartupView.swift          # Onboarding screen (launcher selection)
│
├── Tests/
│   └── LaunchEnvironmentTests.swift # Unit-style env/command checks
│
├── Flux.xcodeproj/
│   └── project.pbxproj            # Xcode project (manually maintained)
│
└── Info.plist                     # App metadata
```

**Total Files:** 31 Swift files (includes launch split components + tests)  
**Build Status:** ✅ Compiles with 0 errors, 0 warnings

---

## 6. Key Fixes & Architecture Decisions (Session Jan 27-28)

### Fix #1: Project File Corruption (Jan 27, Morning)
**Symptom:** Project file truncated to 79 lines  
**Solution:** Regenerated complete Xcode project.pbxproj  
**Result:** ✅ Project builds

### Fix #2: 12+ Compilation Errors (Jan 27, Morning)
**Examples:** SettingsView duplication, DeveloperFeedback property conflicts, UIColor → NSColor  
**Result:** ✅ All 23 files compile successfully

### Fix #3: Recursive Initialization Deadlock (Jan 27, Afternoon)
**Crash:** `BUG IN CLIENT OF LIBDISPATCH: trying to lock recursively`  
**Solution:** Made `launcher` and `dependencyManager` lazy, pass AppState as parameter  
**Result:** ✅ App launches without recursive lock

### Fix #4: Circular Dependency in SystemDetector (Jan 27, Afternoon)
**Solution:** Made `systemDetector` and `developerFeedback` lazy  
**Result:** ✅ No more circular dependencies

### Fix #5: Dispatch Queue Deadlock in Logging (Jan 27, Late Afternoon)
**Solution:** Simplified nested dispatch pattern to safe pattern  
**Result:** ✅ Clean, thread-safe logging

### Fix #6: Wine and GPTK Architecture Refactor (Jan 28, Morning)
**Change:** User provided critical insight: "Wine and GPTK are separate dependencies, not bundled"
**Solution:** 
- Created separate `WineDetector.swift` service
- `GPTKDetector.swift` remains independent
- Each has own detection logic, caching, validation
- `LaunchCoordinator.swift` checks both independently
- Never assumes wine64 on ARM Macs

**Result:** ✅ Correct 2026 architecture for separate runtimes

### Fix #7: WineDetector Performance & Validation (Jan 28, Morning)
**Changes:**
- Added `private lazy var cachedWinePath` - prevents repeated filesystem scans
- Replaced `fileExists` with `isExecutableFile` - validates executability not just existence
- Added `wineserverPath` detection - prevents future "Wine launches but hangs" bugs
- Logging only on initial detection, not on property access - cleaner debugging

**Result:** ✅ Optimized, robust Wine detection

### Fix #8: First-Boot Architecture (Jan 28, Morning)
**Requirement:** First-boot screen should appear only once, never annoy users on normal launches
**Solution:**
- `@AppStorage("hasCompletedFirstBoot")` in FluxApp - persists across restarts
- Conditional rendering: if first boot → show FirstBootView, else → normal flow
- Gentle UX: 0.6s hint delay, 0.4s fade transition, click to continue
- No keyboard input (macOS 13 compatible, `onKeyPress` requires 14+)

**Result:** ✅ Professional, non-intrusive first-boot experience

---

## 7. Build & Run

### Quick Build
```bash
cd /Users/efealibel/OpenFlux
xcodebuild build
```

### Launch
```bash
open build/Release/Flux.app
```

### Clean
```bash
xcodebuild clean
```

### Verify Build Success
```bash
xcodebuild build 2>&1 | tail -5
# Should output: ** BUILD SUCCEEDED **
```

---

## 8. Completed Features (Jan 28, 2026)

✅ **Project Setup & Architecture**
- AppState spine pattern with lazy initialization
- Circular dependency resolution
- Thread-safe logging

✅ **Wine & GPTK Detection**
- Independent WineDetector service (separate from GPTK)
- GPTK detection via file paths
- Caching for performance
- Executable validation (not just file existence)
- Wineserver detection (prevents future hangs)
- Never assumes wine on ARM

✅ **First-Boot Experience**
- FirstBootView appears once on first launch
- Persistent flag via @AppStorage
- Calm, intentional design (not OS cosplay)
- Gentle animations and transitions
- macOS 13 compatible

✅ **UI Layout & Navigation**
- Sidebar with Games, Prefixes, Logs, Settings
- Onboarding screen (launcher selection)
- Main content area with tab-based navigation
- Theme management (light/dark)
- Per-game GPTK mode selection (inherit / enabled / disabled)
- Per-game Graphics API metadata (unknown / directx / opengl / vulkan)

✅ **Settings & Persistence**
- UserDefaults with prefix namespace
- Launcher selection persists
- Onboarding state persists
- Wine/GPTK paths configurable (GPTK optional)
- Per-game GPTK mode + graphics API metadata persisted

✅ **System Detection**
- Game launcher detection (Steam, Epic, GOG, Ubisoft)
- Wine availability detection
- GPTK availability detection
- GPU/Metal detection
- LaunchReadiness reporting

✅ **Logging System**
- Console logging with timestamps
- App-level LogEntry tracking
- Thread-safe implementation
- Logs viewer in UI

---

## 9. NOT YET Implemented (Future Work)

❌ **Game Operations**
- Steam game scanning
- Epic/GOG/Ubisoft game detection
- Game launching via Wine (GPTK optional)
- Game installation tracking

❌ **Wine Management**
- Prefix creation
- Prefix configuration UI
- Wine environment variable setup
- Prefix listing and management

❌ **GPTK Integration**
- GPTK launch environment
- Metal GPU optimization
- Performance monitoring

❌ **User Accounts**
- Google login
- Apple login
- Microsoft login
- Email login

❌ **Network Features**
- Game library sync
- Cloud saves
- Online multiplayer coordination

---

## 10. Known Constraints & Patterns

### ✅ Established Patterns
- **Spine Pattern (AppState):** All state flows through AppState.shared
- **Lazy Initialization:** All services that need AppState accept it as parameter
- **Reactive UI:** @Published + @EnvironmentObject for automatic re-renders
- **File-Based Detection:** Never run processes to detect installations
- **UserDefaults Persistence:** All settings use com.flux. prefix
- **Thread Safety:** Main dispatch for UI updates, async for background work

### ⚠️ Constraints
- **No background tasks:** All work happens on main thread (for now)
- **Simple async:** Use DispatchQueue.main.async, avoid complex patterns
- **Local files only:** No network calls yet
- **Settings via UserDefaults:** Don't implement custom persistence
- **macOS 13.0+:** Don't use APIs requiring macOS 14+

---

## 11. Important Files by Category

### Entry & Configuration
- **FluxApp.swift** - App entry point, first-boot logic
- **SettingsManager.swift** - All persistent settings
- **ThemeManager.swift** - Color and theme management

### State Management
- **AppState.swift** - Central spine for all app state
- **Models/Game.swift** - Game data structure (launch method, GPTK mode, graphics API)

### Detection Services
- **WineDetector.swift** - Wine installation detection
- **GPTKDetector.swift** - GPTK installation detection
- **SystemDetector.swift** - General system environment checks
- **MetalDeviceDetector.swift** - GPU detection

### Game Management
- **GameLauncher.swift** - Launch entry point (Wine required, GPTK optional)
- **LaunchCoordinator.swift** - Launch policy, retries, recents
- **WineEnvironmentBuilder.swift** - Env + GPTK wiring
- **WineProcessRunner.swift** - Process execution
- **DLLInjector.swift** - Optional per-game DLL injection
- **DependencyManager.swift** - Dependency checking
- **ExecutionEnvironment.swift** - Runtime selection logic

### UI Views
- **ContentView.swift** - Main layout (sidebar + content)
- **StartupView.swift** - Onboarding/launcher selection
- **SplashView.swift** - FirstBootView (first-boot screen)
- **SettingsView.swift** - Settings UI
- **GamesView.swift** - Games list
- **PrefixesView.swift** - Wine prefixes management

---

## 12. Debugging Reference

### App Won't Launch
- Check: Recursive initialization (services accessing AppState.shared in __init__)
- Solution: Make service lazy, pass AppState as parameter

### First-Boot Screen Stuck
- Check: `@AppStorage("hasCompletedFirstBoot")` value
- Reset: `defaults delete com.flux.hasCompletedFirstBoot`
- Verify: `FluxApp` has conditional rendering

### Wine Detection Not Working
- Check: `/opt/homebrew/bin/wine` or `/usr/local/bin/wine` exists
- Check: File is executable (not just present)
- Check: `WineDetector.isAvailable` returns true
- Verify: `WineDetector.wineExecutablePath` is non-nil

### GPTK Detection Not Working
- Check: `/opt/gptk/lib` directory exists
- Verify: `GPTKDetector.isAvailable` returns true
- Check: Settings shows GPTK library path

### Settings Not Persisting
- Verify: `SettingsManager.save()` is called
- Check: UserDefaults key has `com.flux.` prefix
- Verify: Property has `@Published` annotation

### UI Not Updating
- Check: State property has `@Published`
- Check: View has `@EnvironmentObject` for AppState
- Verify: State change actually triggers property update

---

## 13. Architecture Decisions Explained

### Why Wine and GPTK are Separate (Jan 28, 2026)
- **Historical:** GPTK used to bundle its own Wine, no longer true
- **Current:** Users install Wine separately from Homebrew
- **Detection:** Each runtime has independent service (WineDetector, GPTKDetector)
- **Flexibility:** Users can run games on Wine-only, GPTK-only, or choose per-game
- **LaunchCoordinator:** Checks both, uses configured preference or user override

### Why Lazy Initialization is Critical
- Prevents recursive dispatch_once deadlock on app startup
- Allows all services to be initialized safely
- Enables proper Combine reactive patterns

### Why File-Based Detection
- Faster than running processes
- Safe (no subprocess overhead)
- Works offline
- Can happen on any thread

### Why Spine Pattern (AppState)
- Single source of truth
- Reactive with Combine
- Easy to debug
- All state in one place

---

## 14. Next Steps for Development

### Immediate (Ready to Implement)
1. **Expand Scanning:** Add Epic/GOG/Ubisoft library detection
2. **Launch Profiles:** Persist per-game launch method (Steam vs Direct)
3. **Prefix Management:** Per-game prefix creation and UI

### Medium-Term
1. **Graphics API Detection:** Infer DirectX/OpenGL/Vulkan from binaries
2. **Dependency Tiering:** Steam fast path vs raw EXE checks
3. **Environment Setup:** Configure WINEPREFIX, GPTK environment

### Advanced
1. **Multi-Runtime Selection:** Choose Wine vs GPTK per game
2. **Graphics API Detection:** Analyze game executables for DirectX/OpenGL/Vulkan
3. **Performance Monitoring:** Track game FPS, resource usage
4. **User Accounts:** Implement login system

---

## 15. Project Statistics

**Files:** 31 Swift source files + configuration  
**Lines of Code:** ~3,500 Swift + ~400 configuration  
**Build Time:** ~12 seconds (Debug)  
**Target:** macOS 13.0+ (arm64 + x86_64 universal)

**Latest Changes (Jan 28, 2026):**
- Added WineDetector.swift (156 lines)
- Refactored FirstBootView in SplashView.swift (85 lines)
- Updated FluxApp.swift with @AppStorage first-boot logic
- Removed splash state from AppState.swift and ContentView.swift
- Added per-version patch notes sheet (AppState + ContentView) gated by `lastSeenVersion`
- ✅ BUILD SUCCEEDED - 0 errors, 0 warnings

---

## 16. Contact & Version Info

**Project:** OpenFlux (formerly OpenFlux)  
**Renamed:** January 28, 2026 (to avoid naming conflicts during distribution)  
**Started:** January 27, 2026  
**Current Build:** Release configuration, arm64 native + x86_64 universal

**Current Status:**
- ✅ App launches cleanly
- ✅ First-boot experience works as designed
- ✅ Onboarding saves launcher selection
- ✅ Main UI accessible after onboarding
- ✅ Wine detection working
- ✅ GPTK detection working
- ✅ Settings persist across restarts
- ✅ All 31 files compile with 0 errors, 0 warnings

**Known Good:**
- First-boot persists via @AppStorage
- Wine detection caches results
- GPTK detection working
- LaunchReadiness reporting available
- Theme management functional
- Logging system thread-safe

**Ready For:**
- Game scanning implementation
- Game launch implementation
- Prefix management
- Advanced Wine (GPTK optional) orchestration

---

**END OF OPENFLUX CONTEXT REFERENCE**

*Last Updated: January 28, 2026 at 2:00 AM*  
*This document provides complete context for the OpenFlux project architecture, current state, and implementation roadmap.*
