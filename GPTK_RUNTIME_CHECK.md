# GPTK Runtime-Only Checking
Project name: OpenFlux (internal targets/bundle still named "Flux").

## Summary

GPTK (Game Porting Toolkit) checks are now **deferred from build/startup to runtime only**. This means:

- ✅ App builds and runs without checking for GPTK
- ✅ GPTK is only verified when actually launching a game
- ✅ No GPTK warnings during startup or in Settings verification

## Changes Made

### 1. **DependencyManager.swift**

Split `verifyInstallation()` into three methods:

#### `checkWineInstallation() -> Bool`
- Checks Wine only (used at build/startup)
- Logs to debug level
- No GPTK involvement

#### `checkGPTKInstallation() -> Bool`
- Checks GPTK only (used at runtime)
- Logs to debug level
- Called only when launching games

#### `verifyInstallation() -> (wineValid: Bool, gptkValid: Bool)`
- Legacy method for Settings
- Combines both checks for full verification
- Used in SettingsView to show complete status

### 2. **GameLauncher.swift**

Updated `launch(_ game: Game)` method:

```swift
// Verify GPTK at runtime only (when launching games)
if settingsManager.useGPTK {
    let gptkValid = dependencyManager.checkGPTKInstallation()
    if !gptkValid {
        appState.error("GPTK enabled but not found at \(settingsManager.gptkPath)", 
                      category: .dependencies)
    }
}
```

- GPTK verification happens only when launching
- Users only see GPTK warnings if they try to run a game with GPTK enabled

## Behavior Timeline

### App Startup
```
1. FluxApp.init()
2. SettingsManager.setupDirectories()
3. AppState.shared.detectSystem()
   └─ SystemDetector.detectSystem()
      └─ Detects: Steam, GPU, updates, mods
      └─ Does NOT check GPTK
4. App ready to use
```

### Normal Settings View
```
1. User opens Settings
2. Can see Wine status (verified at startup)
3. Can manually click "Verify Installation"
   └─ Shows both Wine and GPTK status
   └─ User explicitly requested full check
```

### Game Launch
```
1. User clicks "Play" on a game
2. GameLauncher.launch() called
3. If useGPTK is true:
   └─ checkGPTKInstallation() called
   └─ User sees error if GPTK not found
4. Game launches if all checks pass
```

## Benefits

✅ **Faster startup** - No GPTK filesystem checks on app init
✅ **Cleaner logs** - No false GPTK warnings at startup
✅ **Better UX** - Users only see GPTK errors when needed
✅ **Flexible** - Optional GPTK doesn't block app functionality
✅ **Settings control** - Full verification available in Settings when needed

## Code Locations

| File | Method | Purpose |
|------|--------|---------|
| `Services/DependencyManager.swift` | `checkWineInstallation()` | Build/startup check |
| `Services/DependencyManager.swift` | `checkGPTKInstallation()` | Runtime check |
| `Services/GameLauncher.swift` | `launch()` | Runtime verification |
| `Views/SettingsView.swift` | `verifyInstallation()` | Manual full check |
| `flux-terminal.sh` | `system_check()` | Terminal system check (GPTK excluded) |

## System Check Output

Running `./flux-terminal.sh system-check` now shows:
```
✅ Swift: Apple Swift version 6.2.3
✅ Xcode: /Library/Developer/CommandLineTools
⚠️  Wine not found (needed for running games)
✅ Steam: Installed
✅ Metal GPU: Apple M4
✅ All required tools found!
```

**Note:** GPTK is no longer listed because it's deferred to runtime.
