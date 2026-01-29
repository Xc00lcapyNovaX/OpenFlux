# Dual Execution Environments – Architecture Guide
Project name: OpenFlux (internal targets/bundle still named "Flux").

## Overview

OpenFlux now supports **two Wine prefix environments** with independent prefixes and configurations:

| Environment | CPU | Use Case | Prefix | Performance |
|------------|-----|----------|--------|-------------|
| **x64 (Default)** (🧩) | macOS arm64 host | Most Windows apps/games (64-bit prefix, WOW64-capable) | `-native` | Best |
| **x86 (32-bit)** (🧱) | macOS arm64 host | Legacy 32-bit apps/installers (win32 prefix) | `-x86` | Compatible |

Both environments maintain **consistent macOS-style design** while running in their respective execution modes.
Note: This is about the Windows executable architecture (x86/x64). **Windows ARM64 EXEs are not supported**.

---

## Architecture

### Separate Wine Prefixes

Each environment has its own isolated Wine prefix:

```
~/.flux/
├── prefix-native/         # 64-bit Wine prefix (WOW64-capable)
│   ├── drive_c/
│   ├── system.reg
│   └── ...
└── prefix-x86/            # 32-bit Wine prefix (win32)
    ├── drive_c/
    ├── system.reg
    └── ...
```

**Benefits:**
- ✅ Independent DLL configurations per environment
- ✅ No conflicts between environments
- ✅ Easy to reinstall or reset one environment
- ✅ Separate game libraries per environment

### Execution Flow

```
User launches game
    ↓
Check execution environment in Game struct
    ↓
┌─────────────────────────────────────────┐
│ x64 (Default)      │ x86 (32-bit)        │
├─────────────────────────────────────────┤
│ • 64-bit prefix     │ • 32-bit prefix     │
│ • WOW64 capable     │ • win32 only        │
│ • GPTK optional     │ • GPTK optional     │
│ • Best compatibility│ • Legacy support    │
└─────────────────────────────────────────┘
    ↓              ↓
   Launch        Launch
   (x64)         (x86)
```

---

## Services

### ExecutionEnvironment.swift

Defines and manages the two environments:

```swift
enum ExecutionEnvironment: String, Codable {
    case native = "Native"      // 64-bit prefix (WOW64-capable)
    case x86 = "x86"            // 32-bit prefix (win32)
}
```

**Properties:**
- `displayName` - "x64 (Default)" or "x86 (32-bit)"
- `description` - Detailed environment explanation
- `icon` - Visual indicator (⚡ for native, 🔲 for x86)
- `color` - UI color (#4DB8FF for native, #FF9D4D for x86)

### AppEnvironmentManager.swift

Manages environment setup and routing:

```swift
class AppEnvironmentManager {
    // Get Wine prefix path for environment
    func getPrefixPath(for environment: ExecutionEnvironment) -> String
    
    // Get Wine executable for environment
    func getWineExecutablePath(for environment: ExecutionEnvironment) -> String
    
    // Check if environment is configured
    func isEnvironmentAvailable(_ environment: ExecutionEnvironment) -> Bool
    
    // Get all available environments
    func availableEnvironments() -> [ExecutionEnvironment]
    
    // Log environment status
    func logEnvironmentStatus()
}
```

---

## Game Model Updates

Games now include execution environment:

```swift
struct Game: Identifiable, Codable {
    // ... existing fields ...
    var executionEnvironment: ExecutionEnvironment = .native
    
    init(..., environment: ExecutionEnvironment = .native) {
        // ...
        self.executionEnvironment = environment
    }
}

## Notes

- OpenFlux targets **Windows x86 and Windows x64** executables.
- **Windows ARM64** executables are currently not supported by this launcher (you need an x86/x64 build).
```

**Default:** All games default to `.native` (arm64) for maximum performance.

---

## GameLauncher Updates

Launch process now:

1. **Checks GPTK** - Verifies Game Porting Toolkit is available
2. **Validates Environment** - Ensures selected environment is configured
3. **Routes to Environment** - Uses correct Wine prefix and executable
4. **Sets Environment Variables** - Configures paths for selected environment
5. **Launches** - Runs in appropriate environment

```swift
func launch(_ game: Game) {
    // Verify GPTK
    guard gptkDetector.isAvailable else { ... }
    
    // Verify environment is available
    guard envManager.isEnvironmentAvailable(game.executionEnvironment) else { ... }
    
    // Setup environment-specific paths
    setupExecutionEnvironment(&environment, for: game, useGPTK: resolvedGPTK)
    
    // Launch
    executeGame(command: wineCommand, environment: environment, game: game)
}
```

---

## UI Integration Points

### Games List
Shows environment badge for each game:
```
My Game (⚡ Native)
Extra App (🔲 x86)
```

### Game Details
Display and allow changing execution environment:
```
Execution Environment: 🧩 x64 (Default)
              [Change to x86 (32-bit)]
```

### Settings
Show environment status:
```
📊 Execution Environments
  ✓ 🧩 x64 (Default)
  ✓ 🧱 x86 (32-bit)
```

---

## Usage Examples

### Launch Game in Native Environment
```swift
var game = Game(name: "Modern Game", ...)
game.executionEnvironment = .native
appState.launch(game)  // Runs in default x64 prefix
```

### Launch Legacy App in x86 Environment
```swift
var legacyApp = Game(name: "Old Utility", ...)
legacyApp.executionEnvironment = .x86
appState.launch(legacyApp)  // Runs in x86 32-bit prefix
```

### Switch Environment
```swift
// User clicks "Change Environment" button
game.executionEnvironment = 
    game.executionEnvironment == .native ? .x86 : .native
appState.updateGame(game)
```

---

## Environment Configuration

### x64 (Default) Prefix
- **Wine:** Standard `wine` executable (64-bit prefix, WOW64-capable)
- **Prefix:** `~/.flux/prefix-native`
- **Architecture:** Windows x64 (with WOW64 for x86 apps)
- **Performance:** Best compatibility
- **GPTK:** Optional (only when enabled per-game/global)
- **Use for:** Most games and modern Windows apps

### x86 (32-bit) Prefix
- **Wine:** Standard `wine` executable (win32 prefix)
- **Prefix:** `~/.flux/prefix-x86`
- **Architecture:** Windows x86 (32-bit only)
- **Performance:** Compatibility-first
- **GPTK:** Optional (only when enabled per-game/global)
- **Use for:** Legacy 32-bit apps and installers

---

## File Structure

```
Services/
├── ExecutionEnvironment.swift     # Defines environments
├── (AppEnvironmentManager lives in ExecutionEnvironment.swift)
├── GameLauncher.swift            # Uses environments
└── GPTKDetector.swift            # Detects GPTK availability

Models/
└── Game.swift                     # Includes executionEnvironment

Views/
├── GamesView.swift               # Shows environment badges
├── GameDetailsView.swift         # Edit environment
└── SettingsView.swift            # Show status
```

---

## Logging

Environment status logged at launch:

```
═══════════════════════════════════════════
Execution Environments Available:
═══════════════════════════════════════════
✓ 🧩 x64 (Default)
   Prefix: ~/.flux/prefix-native
   Wine: /opt/homebrew/bin/wine
✓ 🧱 x86 (32-bit)
   Prefix: ~/.flux/prefix-x86
   Wine: /opt/homebrew/bin/wine
```

---

## Benefits

✅ **Isolation** - Environments don't interfere with each other
✅ **Flexibility** - Choose right environment for each app
✅ **Consistency** - Both use same macOS design
✅ **Performance** - x64 default for most apps, x86 prefix for legacy
✅ **Easy Reset** - Delete prefix and recreate for one environment
✅ **Future Ready** - Can add more environments (Rosetta, etc)

---

## Status

✅ **Architecture:** Complete
✅ **Services:** ExecutionEnvironment, AppEnvironmentManager created
✅ **GameLauncher:** Updated to use dual environments
✅ **Game Model:** Updated with executionEnvironment field
✅ **Compilation:** All files compile with zero errors
✅ **Ready for UI:** Views can now display environment badges

---

**Version:** 1.0  
**Created:** January 27, 2026  
**Status:** Architecture Complete, Ready for UI Integration
