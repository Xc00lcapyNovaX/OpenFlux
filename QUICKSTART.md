# OpenFlux – Quick Start Guide
Project name: OpenFlux (internal targets/bundle still named "Flux").

## Prerequisites

Before building OpenFlux, ensure you have:

- macOS 13.0 or later
- Xcode 14.0+ with Command Line Tools
- Wine installed (required)
- [Apple Game Porting Toolkit (GPTK)](https://developer.apple.com/download/all/) installed (optional)
- Steam client installed with games in your library

## Installation & Setup

### Step 1: Clone or Download OpenFlux

```bash
cd ~/Projects
git clone https://github.com/yourusername/flux.git
cd flux
```

Or download the ZIP and extract to a folder.

### Step 2: Build the App

**Option A: Using Xcode (Recommended)**

```bash
# Open in Xcode
open Flux.xcodeproj

# Press Cmd+R to build and run
# Or: Product → Run
```

**Option B: Command Line**

```bash
# Build script method
chmod +x build.sh
./build.sh

# The app will be created at: build/Flux.app

# Run it
open build/Flux.app
```

**Option C: SwiftC (Manual)**

```bash
swiftc -parse-as-library -emit-executable \
    -o OpenFlux \
    -target arm64-apple-macosx13.0 \
    -framework AppKit -framework Foundation \
    -framework SwiftUI -framework Combine \
    FluxApp.swift Models/*.swift Services/*.swift Views/*.swift
```

### Step 3: Configure Wine (and GPTK if you enable it) (First Run)

On first launch, OpenFlux automatically:
1. Creates `~/.flux/` directory structure
2. Initializes Wine prefix at `~/.flux/prefix/`
3. Sets up default configuration

Then manually configure:
1. Click **Settings** in the sidebar
2. Verify or set:
   - Wine Directory: `/opt/homebrew/bin/wine` (or your installation)
   - GPTK Path: `/opt/gptk` (optional; only needed if enabled)
   - Toggle "Use Game Porting Toolkit" ON only if you want DirectX → Metal

3. Click **Verify Installation** to test paths
4. System info should show detected versions

### Step 4: Detect Games

1. Click **Games** in the sidebar
2. Click **Refresh** button to start detection
3. OpenFlux will scan Steam libraries and check dependencies
4. Wait for detection to complete (typically 3-10 seconds)
5. Your Steam games appear with indicators:
   - 🔒 Lock icon = DRM detected (may not work)
   - ⚠️ Warning = Missing dependencies
   - Steam ID and install path shown

### Step 5: Launch a Game

1. **Select** a game from the list (click it)
2. Click the **Launch** button
3. Confirm launch when prompted
4. Monitor **Logs** tab for real-time output:
   - Categorized by source (Games, Engine, Services)
   - Color-coded by level (Info, Warning, Error)
5. Game will run in Wine (GPTK translation if enabled)
6. Click game in Logs to see full output
7. Close game normally - OpenFlux tracks termination

## First Run Checklist

- [ ] Wine is installed and working
- [ ] GPTK is installed if you plan to enable it
- [ ] Steam client is installed
- [ ] Settings paths are correct
- [ ] Games were detected successfully
- [ ] Metal device is recognized
- [ ] Can launch a game (try a simple title first)

## Common Issues & Fixes

### General Troubleshooting
**Always check these first:**
- Look for **error banners** at top of views (orange background)
- Check **Logs** tab for detailed error messages with categories
- Error messages indicate exact problem location

### Path Configuration Issues

**"Wine not found" error**
- **Solution:** Set correct Wine path in Settings
- **Common paths:**
  - Homebrew (Apple Silicon): `/opt/homebrew/bin/wine`
  - Homebrew (Intel): `/usr/local/bin/wine`
  - Custom: Check where you installed Wine
- **Test:** Run `which wine` in Terminal to find installation

**"GPTK not found" error**
- **Solution:** Install Game Porting Toolkit from Apple Developer Downloads
- **Verify:** Check that `/opt/gptk/` exists or set custom path

### Game Detection Issues

**"No games detected"**
1. Verify Steam is installed: `ls ~/Library/Application\ Support/Steam/`
2. Ensure Steam has games in library
3. Click **Refresh** in Games view to rescan
4. Check **Logs** tab for detection errors
5. Check **Settings** → **Verify Installation** output

**"Games detected but missing dependencies warning"**
- This is **expected** and normal
- Games show ⚠️ indicator when DLLs are missing
- OpenFlux can auto-install dependencies or you can proceed anyway
- Check Logs for specific missing DLLs

**"DRM detected" warning (🔒 lock icon)**
- Games with Denuvo or other DRM may not work with GPTK
- **You can still try:** Click Launch - some DRM games work anyway
- Check game-specific compatibility reports online

### Game Launch Issues

**Game crashes immediately with no output**
1. Check **Logs** tab for error messages
2. Look for missing DLL messages
3. Verify game path exists and is readable
4. Try a different, simpler game first to test setup

**"Process failed" or timeout error**
- Wine may have crashed
- Check system logs: `log stream --predicate 'process == "wine"'`
- Try relaunching - sometimes transient
- If persistent, check Wine installation

**Game runs but no audio/graphics**
1. Check Metal device detected in Settings
2. Verify GPTK path is correct
3. Check Logs for D3D translation errors
4. Some games need environment variable tweaks - see Advanced section

### Manual Dependency Installation

When OpenFlux detects missing DLLs:
1. Note which DLLs are missing from Logs
2. Go to **Settings** → **Dependencies** (when available)
3. Or manually place `.dll` files in:
   ```
   ~/.flux/prefix/drive_c/windows/system32/
   ```
4. Common DLLs to install:
   - `d3dx9_43.dll` (DirectX 9)
   - `xinput1_3.dll` (Xbox 360 controller support)
   - `xaudio2_7.dll` (Audio)
   - `steam_api64.dll` (Steam integration)

## File Structure Overview

### Application Data (~/.flux/)

```
~/.flux/                          # OpenFlux app data directory (created on first run)
├── prefix/                       # Default Wine prefix (WINEPREFIX=~/.flux/prefix)
│   ├── drive_c/                 # Windows C: drive
│   │   ├── windows/
│   │   │   ├── system32/        # System DLLs and binaries
│   │   │   └── system64/        # 64-bit system DLLs
│   │   ├── Program Files/       # Installed applications
│   │   └── Users/               # User documents and data
│   ├── drive_d/                 # Optional D: drive (if configured)
│   ├── system.reg               # Wine registry
│   └── user.reg                 # User registry
├── prefixes/                     # Additional prefixes for per-game isolation
│   ├── GameName1/              # Separate prefix per game
│   ├── GameName2/
│   └── ...
├── logs/                         # Session logs and game output
│   ├── game_2026-01-27.log     # Timestamped log files
│   └── ...
└── config.json                   # Saved user settings (paths, preferences)
```

### Project Structure

```
OpenFlux/                             # Project directory
├── FluxApp.swift                # App entry point (@main)
├── Models/
│   ├── AppState.swift           # Central state management
│   └── Game.swift               # Game, GamePrefix, GameConfig models
├── Services/                     # Business logic layer
│   ├── SteamLibraryDetector.swift
│   ├── GameLauncher.swift
│   ├── DependencyManager.swift
│   ├── LogManager.swift         # Singleton logging system
│   ├── SettingsManager.swift    # Singleton configuration storage
│   ├── ProcessMonitor.swift
│   └── MetalDeviceDetector.swift
├── Views/                        # SwiftUI user interface
│   ├── ContentView.swift        # Main layout with navigation
│   ├── GamesView.swift          # Game browser and launcher
│   ├── PrefixesView.swift       # Wine prefix management
│   ├── LogsView.swift           # Real-time log viewer
│   └── SettingsView.swift       # Configuration panel
├── Documentation/
│   ├── README.md                # Complete feature documentation
│   ├── QUICKSTART.md            # This file - quick setup guide
│   ├── IMPLEMENTATION.md        # Technical implementation details
│   ├── ARCHITECTURE.md          # System design and patterns
│   └── INTEGRATION_CHECKLIST.md # Verification of all components
├── Info.plist                   # macOS app metadata
└── Flux.pbxproj                # Xcode project file
```

## Tips & Tricks

### Environment Integration
- **Error banners** appear at top of view when issues occur
- **Logs are categorized** - Filter by type in Logs view:
  - **Games** - Game detection and launching
  - **Prefixes** - Prefix operations
  - **Settings** - Configuration changes
  - **Services** - Internal operations
  - **Engine** - Actual game output
- **Real-time updates** - Logs appear instantly as game runs
- **Export logs** - Copy logs to clipboard for troubleshooting

### Performance Tips
1. **Metal translation is fast** – GPTK overhead typically <5%
2. **Avoid SD cards** – Wine prefixes should be on fast SSD
3. **Shader caching helps** – First launch compiles shaders, subsequent launches are faster
4. **Monitor CPU usage** – Check Activity Monitor during gameplay

### Game Configuration
1. Create separate prefix for each game via **Prefixes** tab
   - Better isolation
   - Allows different Wine (GPTK optional) versions per game
   - Easier to troubleshoot game-specific issues
2. Use **Logs** to track game behavior
3. Save log output for reference
4. Note successful configurations for future launches

### Advanced Logging
1. **Open Logs tab** during troubleshooting
2. **Auto-scroll ON** keeps latest messages visible
3. **Filter by level** to focus on errors/warnings
4. **Copy individual entries** for bug reports
5. **Export all logs** to file for detailed analysis

### Testing Wine Directly
```bash
# Test Wine installation
WINEPREFIX=~/.flux/prefix wine cmd /c echo "Wine works!"

# Run a specific executable
WINEPREFIX=~/.flux/prefix wine /path/to/game.exe

# Check process info
ps aux | grep wine
```

### Testing Wine From Inside OpenFlux
OpenFlux includes a functional smoke test that verifies Wine can:
- initialize a clean prefix (`wineboot -u`)
- run a basic Windows command (`cmd /c echo`)

Run it from:
- **Settings** → **Run Wine Smoke Test**

## Performance Expectations

### Typical Launch Times
- **Game detection:** 3-10 seconds (varies with Steam library size)
- **First launch:** 5-15 seconds (prefix setup + shader compilation)
- **Subsequent launches:** 2-5 seconds (cached data)
- **Game start after Wine:** Depends on game (usually 10-30 seconds)

### Metal Translation Overhead
- **D3D11→Metal:** ~1-5% CPU overhead (very minimal)
- **Shader compilation:** First run only, subsequent cached
- **Memory usage:** ~1-2GB for OpenFlux + Game process

## Next Steps

✅ **You've completed basic setup!**

Now explore these:

- [ ] **Configure per-game prefixes** – Via Prefixes view for game isolation
- [ ] **Monitor performance** – Check Logs while playing
- [ ] **Review Settings** – Metal device info, Wine version detection
- [ ] **Export logs** – Save first successful game launch for reference
- [ ] **Explore IMPLEMENTATION.md** – Understand how OpenFlux works
- [ ] **Check ARCHITECTURE.md** – Learn the design patterns
- [ ] **Read INTEGRATION_CHECKLIST.md** – See all verified features

## Getting Help

### Self-Help Resources
1. **Logs are your friend** – Always check Logs tab first
2. **Error banners** – Pay attention to orange error messages
3. **Settings verification** – Click "Verify Installation" to test paths
4. **Documentation:**
   - QUICKSTART.md (this file) – Quick setup and common issues
   - README.md – Feature documentation and overview
   - IMPLEMENTATION.md – Technical details
   - ARCHITECTURE.md – System design and patterns

### Systematic Debugging
1. **Verify paths** – Most issues are path-related
2. **Check Wine (GPTK optional)** – Ensure both are installed correctly
3. **Test simple game** – Rules out game-specific issues  
4. **Review Logs carefully** – Look for actual error messages, not just warnings
5. **Test Wine directly** – `WINEPREFIX=~/.flux/prefix wine cmd /c echo "test"`

## Success Indicators

✅ **You're good to go when:**
- Games appear in Games list
- Game launches and shows output in Logs
- Metal device is detected in Settings
- Wine version displays correctly

🎮 **Now play something awesome!**

---

**OpenFlux Version:** 0.1.0  
**Last Updated:** January 27, 2026  
**macOS:** 13.0+
