# OpenFlux Project - Full Context Reference
Project name: OpenFlux (internal targets/bundle still named "Flux").

**Last Updated:** January 29, 2026  
**Status:** ✅ Running and stable  
**Purpose:** macOS game launcher for Windows games via Wine, with optional GPTK for DirectX → Metal translation

---

## 1. Project Overview

### What is OpenFlux?
A native SwiftUI macOS application that:
- Detects games from multiple launchers (Steam, Epic Games, GOG, Ubisoft)
- Manages Wine prefixes for Windows game compatibility
- Launches games through Wine (GPTK optional)
- Provides logging, system detection, and game library management

### Target Platform
- **OS:** macOS 13.0+
- **Architecture:** arm64 (Apple Silicon native)
- **UI Framework:** SwiftUI
- **Swift Version:** 5.9+

### Build System
- **Xcode:** 14.0+ required
- **Build Tool:** xcodebuild + custom flux-terminal.sh wrapper
- **Project File:** Flux.xcodeproj/project.pbxproj (manually maintained)

---

## 2. Critical Architecture & Patterns

### AppState - Single Source of Truth (Spine Pattern)
**File:** `Models/AppState.swift`

AppState is the **spine** - everything flows through it:
- `@ObservableObject` that owns all app state
- **NOT** for UI state (use @State/@StateObject in views)
- **IS** for app-level data: games, logs, system info, services
- Shared via singleton: `AppState.shared`

**Key properties:**
- `@Published var games: [Game]` - detected games
- `@Published var logs: [LogEntry]` - application logs
- `@Published var systemInfo: SystemDetector.SystemInfo` - system detection
- Services: `settingsManager`, `processMonitor`, lazy `launcher`, lazy `dependencyManager`

### Initialization Pattern - Lazy Initialization for Circular Dependencies
**Problem Solved:** Recursive dispatch_once deadlock on app startup

**Solution Applied:**
All services that access `AppState.shared` during their init are made **lazy** in AppState:
```swift
private lazy var launcher = GameLauncher(appState: self)
private lazy var dependencyManager = DependencyManager(appState: self)
private lazy var systemDetector = SystemDetector()
private lazy var developerFeedback = DeveloperFeedback.shared
```

**Why it works:**
- Lazy properties defer creation until first access (after AppState.__init__ completes)
- Services receive AppState as init parameter instead of accessing singleton
- Breaks circular dependency chain: AppState init → Service → AppState.shared (deadlock)

**Critical Detail:** Services that need AppState must accept it as a parameter, NOT access the singleton during init:
```swift
class GameLauncher {
    private let appState: AppState  // Passed in, not accessed via .shared
    
    init(appState: AppState) {
        self.appState = appState
    }
}
```

### System Detection - File-Based Checks
**File:** `Services/SystemDetector.swift`

**Pattern:** Check for file existence, NOT running processes
- Launcher detection uses file paths in `launcherFilePaths` dictionary
- Public method: `isLauncherInstalled(_ launcherId: String) -> Bool`
- Checks: `~/Library/Application Support/...` and `/Applications/...`

**Current Implementation:**
- Detects Steam, Epic, GOG, Ubisoft by looking for installation directories
- Checks for Metal GPU support
- Verifies architecture support (x86/x64)
- **NOT YET:** Epic/GOG/Ubisoft game scanning

### Settings Persistence
**File:** `Services/SettingsManager.swift`

**Pattern:** UserDefaults with prefix namespace
```swift
private let prefix = "com.flux."  // All keys prefixed with this
```

**Properties:**
- `wineDirectory` - Wine prefix location
- `gptkPath` - Game Porting Toolkit installation (optional)
- `useGPTK` - Opt-in GPTK toggle (Wine remains required)
- `gptkModeOverrides` - Per-game GPTK mode (inherit / enabled / disabled)
- `graphicsAPIOverrides` - Per-game graphics API metadata
- `enableLogging` - Boolean flag
- `selectedLauncher` - "steam" | "epic" | "gog" | "ubisoft"
- `hasCompletedOnboarding` - Boolean flag

**Key method:** `save()` - persists all @Published properties to UserDefaults

---

## 3. Critical Fixes Applied (Session History)

### Fix #1: Project File Corruption (Jan 27, Morning)
**Symptom:** Project file truncated to 79 lines (was 400+)  
**Solution:** Regenerated complete Xcode project.pbxproj with all 23 source files  
**Result:** ✅ Project now loads and builds

### Fix #2: 12+ Compilation Errors (Jan 27, Morning)
**Examples Fixed:**
- SettingsView: Removed 636 lines of duplication
- DeveloperFeedback: Fixed property/method name conflict (isAuthenticated)
- HexColorPicker: UIColor → NSColor (macOS compatibility)
- Multiple Views: Fixed onChange signatures, optional unwrapping

**Result:** ✅ All 23 files compile successfully

### Fix #3: Recursive Initialization Deadlock (Jan 27, Afternoon)
**Crash:** `BUG IN CLIENT OF LIBDISPATCH: trying to lock recursively`  
**Root Cause:** 
```
FluxApp.init() → AppState.shared → GameLauncher() 
  → GameLauncher.init() accesses AppState.shared (still initializing!)
  → dispatch_once deadlock
```
**Solution:** Made `launcher` and `dependencyManager` lazy, pass AppState as parameter  
**Result:** ✅ App launches without recursive lock

### Fix #4: Circular Dependency in SystemDetector (Jan 27, Afternoon)
**Crash:** Same recursive deadlock  
**Root Cause:** 
```
AppState.init() → detectSystem() 
  → accesses systemDetector (not lazy)
  → SystemDetector.init() accesses AppState.shared
```
**Solution:** 
- Made `systemDetector` and `developerFeedback` lazy in AppState
- Deferred `detectSystem()` and `detectGames()` to async after init
- Removed `AppState.shared` reference from SystemDetector init

**Result:** ✅ No more circular dependencies

### Fix #5: Dispatch Queue Deadlock in Logging (Jan 27, Late Afternoon)
**Problem:** Nested dispatch pattern in AppState logging
```swift
// BAD: Nested dispatch + barrier pattern
logQueue.async(flags: .barrier) { 
    DispatchQueue.main.async { 
        self.logs.append(entry) 
    } 
}
```
**Solution:** Simplified to safe pattern
```swift
// GOOD: Console sync, then main-thread UI update
print("[\(timestamp)] message")
DispatchQueue.main.async { [weak self] in
    self?.logs.append(entry)
}
```
**Result:** ✅ Clean, thread-safe logging with no deadlock potential

---

## 4. UI Improvements & Startup Flow

### Startup Screen (OnBoarding)
**File:** `Views/StartupView.swift`

**Purpose:** First-time setup for launcher selection and login placeholder

**Features:**
- **Left Panel:** Launcher selection (Steam, Epic, GOG, Ubisoft)
  - File emoji icons for each launcher
  - Descriptions ("Detect games from X")
  - Selection indicator (checkmark)
- **Right Panel:** Login placeholder (Coming Soon)
  - Google, Apple, Microsoft, Email buttons
  - All marked as "TBA" (To Be Announced)
  - Non-functional but clearly labeled

### Patch Notes Sheet (New)
**Files:** `Models/AppState.swift`, `Views/ContentView.swift`
- Shows once per app version when a new build launches
- Content stored in `AppState.latestPatchNotes`
- Persistence via `SettingsManager.lastSeenVersion`
- Dismiss with "Got it" (stores version + hides until next version)

**Flow:**
1. User selects preferred launcher
2. Clicks "Continue" button
3. Settings saved to SettingsManager
4. `hasCompletedOnboarding` set to `true`
5. View automatically transitions to main UI

### Sidebar Text Brightness
**File:** `Views/ContentView.swift`

**Change:** Increased sidebar label opacity from default to 0.95
```swift
.foregroundStyle(themeColors.text.opacity(0.95))  // Brighter text
```

**Result:** ✅ Sidebar menu is now readable

### Main Content View
**File:** `Views/ContentView.swift`

**Pattern:** Two-part conditional rendering
- If onboarding NOT complete: Show `StartupView`
- If onboarding complete: Show main UI (sidebar + content)

**Reactive:** Uses computed property `shouldShowStartup`:
```swift
var shouldShowStartup: Bool {
    !appState.settingsManager.hasCompletedOnboarding
}
```

**Why:** Automatically re-evaluates when SettingsManager changes (via @Published)

### Dashboard + Recents (New)
**Files:** `Views/ContentView.swift`, `Models/AppState.swift`, `Services/LaunchCoordinator.swift`
- Added a Dashboard tab that shows recent launches
- Recent launches are tracked on every launch attempt
- Recents list shows name, method (Steam/Direct), and timestamp
- Launch failures show a Retry action in Games

### Dependency Prompt + Launcher Loading (New)
**Files:** `Views/GamesView.swift`, `Models/AppState.swift`, `Services/DependencyManager.swift`
- Loading overlay appears for launcher-like EXEs during dependency probe
- Missing components are grouped by category (Runtime, Game Files, Graphics Backend)
- User confirms required installs before launch proceeds

### Steam Fast Path (MVP)
**Files:** `Services/LaunchCoordinator.swift`, `Models/Game.swift`
- Steam-installed games skip DependencyManager checks
- Direct EXEs use dependency prompt + install flow
- Logs indicate when Steam fast path is used

### Open With (Finder)
**Files:** `FluxApp.swift`, `Models/AppState.swift`, `Info.plist`
- Registers `.exe`/`.msi` for “Open with OpenFlux”
- Default launch environment is **x86** (configurable in Settings/Prefixes); 64-bit EXEs auto-fallback to **Native**
- Geometry Dash auto-detected by `app322170`/`GeometryDash.exe` → SteamAppId 322170

---

## 5. Onboarding Integration (Latest - Jan 27, Evening)

### How It Works
**File Changes:**
- `Views/ContentView.swift` - Simplified state logic
- `Views/StartupView.swift` - Clean continueOnboarding()

**Flow:**

1. **App Launch**
   - ContentView checks: `shouldShowStartup` computed property
   - If `hasCompletedOnboarding == false` → show StartupView
   - If `hasCompletedOnboarding == true` → show main UI

2. **User Selects Launcher**
   - `selectedLauncher` state variable updated in StartupView

3. **User Clicks Continue**
   - `continueOnboarding()` called:
     ```swift
     AppState.shared.settingsManager.selectedLauncher = selectedLauncher
     AppState.shared.settingsManager.hasCompletedOnboarding = true
     AppState.shared.settingsManager.save()
     ```

4. **SettingsManager Published Change**
   - `@Published hasCompletedOnboarding` notifies observers
   - ContentView re-renders
   - `shouldShowStartup` now returns `false`
   - Main UI appears automatically

5. **Next App Launch**
   - Onboarding skipped
   - Goes straight to main UI

**Key Pattern:** Reactive state management via @Published properties, no explicit navigation needed

### Patch Notes Sheet (New)
**Files:** `Models/AppState.swift`, `Views/ContentView.swift`

**What it does:**
- Detects app version on launch and shows a modal sheet of patch notes when the version changed.
- Stores `lastSeenVersion` in `SettingsManager` to avoid re-showing after dismissal.
- Uses theme colors and a simple "Got it" button to dismiss and persist.

**How to update:**
- Edit `latestPatchNotes` in `AppState` when bumping the version to keep highlights current.

---

## 6. Current Project Structure

```
OpenFlux/
├── FluxApp.swift                 # Entry point, window setup
├── OpenFlux.icns                 # App icon
├── BUILD_AND_RUN.md              # Build instructions
├── CONTEXT_REFERENCE.md          # THIS FILE
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
│   ├── GameLauncher.swift         # Launch entry point (delegates to coordinator)
│   ├── LaunchCoordinator.swift    # Launch policy and flow
│   ├── GPTKDetector.swift         # GPTK installation detection
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
│   ├── WineDetector.swift         # Wine installation detection (separate from GPTK)
│   └── WineProcessRunner.swift    # Process execution + logging
│   └── WineSmokeTestRunner.swift  # Functional Wine smoke test (prefix init + cmd)
│
├── Views/
│   ├── ContentView.swift          # Main layout (sidebar + content)
│   ├── DeveloperFeedbackView.swift # Dev tools UI
│   ├── GamesView.swift            # Games list & launch
│   ├── LogsView.swift             # Application logs viewer
│   ├── PrefixesView.swift         # Wine prefix management
│   ├── SettingsView.swift         # Application settings
│   └── StartupView.swift          # First-time onboarding
│
├── Tests/
│   └── LaunchEnvironmentTests.swift # Unit-style env/command checks
│
├── Flux.xcodeproj/
│   └── project.pbxproj            # Xcode project (manually maintained)
│
└── Info.plist                     # App metadata
```

**Total Files:** 31 Swift files + project config  
**Build Status:** ✅ Compiles with 0 errors, 0 warnings

---

## 7. Build & Run

### Quick Build
```bash
cd /Users/efealibel/OpenFlux
./flux-terminal.sh build
```

### Launch
```bash
open build/Build/Products/Debug/Flux.app
```

### Build + Run
```bash
./flux-terminal.sh run
```

### Clean
```bash
./flux-terminal.sh clean
```

### See full build script
```bash
./flux-terminal.sh help
```

---

## 8. Known Constraints & NOT YET Implemented

### ✅ Completed
- ✅ Project structure and compilation
- ✅ Basic UI layout (sidebar, content areas)
- ✅ App state management (AppState spine)
- ✅ Settings persistence (UserDefaults)
- ✅ Onboarding flow (launcher selection)
- ✅ System detection (file-based checks)
- ✅ Theme management (light/dark)
- ✅ Logging system

### ❌ NOT YET (Do NOT implement - future work)
- ❌ Steam game scanning
- ❌ Game launching via GPTK
- ❌ Wine prefix creation
- ❌ Dependency installation
- ❌ Login system (Google, Apple, Microsoft, Email)
- ❌ Game library sync
- ❌ Network features
- ❌ Performance optimization

### ⚠️ Constraints
- **No background tasks yet** - all work happens on main thread
- **No complex async patterns** - use simple DispatchQueue.main.async
- **File-based detection only** - don't run processes to detect launchers
- **Settings via UserDefaults** - don't implement custom persistence
- **Theme colors fixed** - don't add theme editor
- **No network calls** - all local file operations

---

## 9. Testing Checklist

### Startup Flow
- [ ] First launch shows onboarding screen
- [ ] Launcher selection highlights on tap
- [ ] "Continue" button saves selection
- [ ] View transitions to main UI (no crash)
- [ ] Second launch skips onboarding
- [ ] Sidebar text is readable

### App Stability
- [ ] No crashes on launch
- [ ] No crashes on navigation between tabs
- [ ] Logs display without errors
- [ ] Settings tab loads properly

### Persistence
- [ ] Selected launcher persists across restart
- [ ] Onboarding state persists across restart
- [ ] Settings values persist

---

## 10. Important Files to Know

### Configuration & State
- **AppState.swift** - Where app-level state lives, modify here first
- **Game.swift** - Game metadata (launch method, GPTK mode, graphics API)
- **SettingsManager.swift** - For new persistent settings, add property + save()
- **ThemeManager.swift** - Colors and theming

### Views
- **ContentView.swift** - Main layout, top-level navigation
- **StartupView.swift** - Onboarding screen, launcher selection
- **GamesView.swift** - Game list and launch UI

### Services
- **SystemDetector.swift** - Environment detection, add system checks here
- **GameLauncher.swift** - Launch entry point (delegates to coordinator)
- **LaunchCoordinator.swift** - Launch policy, retries, recents
- **WineEnvironmentBuilder.swift** - Environment construction (GPTK optional)
- **WineProcessRunner.swift** - Process execution + logging
- **SettingsManager.swift** - Persistent settings

### Build System
- **Flux.xcodeproj/project.pbxproj** - Manually maintained, add new files here
- **flux-terminal.sh** - Build wrapper script

---

## 11. Quick Reference: Common Tasks

### Add a new persistent setting
1. Add `@Published var myProperty: Type` to `SettingsManager.init()`
2. Load from UserDefaults: `myProperty = defaults.string(forKey: prefix + "myProperty") ?? "default"`
3. Save in `save()` method: `defaults.set(myProperty, forKey: prefix + "myProperty")`
4. Access via: `AppState.shared.settingsManager.myProperty`

### Add a new view
1. Create file in `Views/` folder
2. Add to Xcode project (`project.pbxproj`)
3. Add to `ContentView.swift` switch statement
4. Import in needed files

### Add app-level state
1. Add `@Published var myState: Type` to `AppState` class
2. Initialize in `AppState.init()`
3. Access via `@EnvironmentObject var appState: AppState`

### Add a system detection check
1. Add method to `SystemDetector`
2. Call from `detectSystem()` method
3. Include result in returned `SystemInfo`

---

## 12. Debugging Tips

### Crash on Launch
- Check recursive initialization: Are services accessing `AppState.shared` in their init?
- Solution: Make property lazy, pass AppState as parameter

### Onboarding Not Appearing
- Check `SettingsManager.hasCompletedOnboarding` value
- Reset: `defaults delete com.flux.hasCompletedOnboarding`
- Verify: `ContentView.shouldShowStartup` computed property logic

### State Not Persisting
- Verify `SettingsManager.save()` is called
- Check UserDefaults key prefix: `com.flux.`
- Verify property has `@Published` annotation

### View Not Updating
- Check if state is `@Published`
- Check if view has `@EnvironmentObject` or `@StateObject`
- Check if state change triggers re-render (use Combine if needed)

---

## 13. Architecture Decisions Explained

### Why Spine Pattern (AppState)?
- Single source of truth prevents state inconsistencies
- Observable pattern (Combine) allows reactive UI
- Easier to debug - all state in one place

### Why Lazy Initialization?
- Breaks circular dependencies
- Allows services to access AppState after full initialization
- Defers expensive operations until needed

### Why File-Based Detection?
- No need to run processes (faster, safer)
- Can happen on any thread
- Simpler implementation

### Why Explicit Over Magic?
- No implicit side effects
- Easy to follow code flow
- Easier to debug and test

---

## 14. Next Developer Notes

**If you're picking this up:**

1. **Build first:** Run `./flux-terminal.sh build` to ensure compilation
2. **Understand AppState:** It's the center of everything
3. **Check SettingsManager:** Most state lives here
4. **Look at StartupView:** Most complex UI currently
5. **Test onboarding:** Most likely place for bugs

**Common first changes:**
- Add new persistent settings (easy)
- Add new detection in SystemDetector (medium)
- Add new view (medium)
- Add launcher detection (easy)

**Hard things to implement:**
- Game launching (requires system integration)
- Process management (needs error handling)
- Network features (not designed for yet)

---

## 15. Contact/Reference

**Project Started:** January 27, 2026  
**Last Major Update:** January 27, 2026 (Onboarding + UI + Architecture fixes)  
**Current Build:** Debug configuration, arm64 native macOS

**Known Working:**
- ✅ App launches
- ✅ Onboarding shows and saves selection
- ✅ Main UI displays after onboarding
- ✅ Theme management works
- ✅ Settings persist

**Ready for Implementation:**
- Game scanning from selected launcher
- Game launching via GPTK
- Prefix management UI
- Dependency checking

---

**END OF CONTEXT REFERENCE**

*Use this file to quickly get up to speed on the OpenFlux project architecture, decisions, and current state.*
### Per-Game Launch Metadata (New)
**File:** `Views/GamesView.swift`
- GPTK mode: inherit / enabled / disabled
- Graphics API: unknown / directx / opengl / vulkan
