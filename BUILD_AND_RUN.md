# OpenFlux – Build & Run Guide
Project name: OpenFlux (internal targets/bundle still named "Flux").

**Single source of truth for building, running, and distributing OpenFlux.**

---

## Overview

OpenFlux is a macOS game launcher for Windows games via Wine, with optional GPTK for DirectX → Metal translation. This guide covers all methods to build and run the application from source.

---

## System Requirements

### Full Xcode Installation
- **macOS:** 13.0 or later
- **Xcode:** 14.0+ from App Store or developer.apple.com
- **Swift:** 5.9+
- **Memory:** 4GB minimum (8GB recommended)
- **Disk Space:** 15GB+ (Xcode) + 2GB for build artifacts

### Command Line Tools Only
- **macOS:** 13.0 or later
- **Command Line Tools:** Latest via `xcode-select --install`
- **Swift:** 5.9+
- **Memory:** 4GB minimum
- **Disk Space:** 2GB for build artifacts

### Runtime Requirements (to play games)
- **Wine (Required):** Homebrew Wine (base `wine` binary on Apple Silicon)
  - Install: `brew install --cask wine-stable`
- **GPTK (Optional):** Apple Game Porting Toolkit (DirectX → Metal translation)
  - Download: https://developer.apple.com/download/all/
  - Installation: Extract to `/opt/gptk` (or custom location in Settings)
- **Steam:** For game detection (optional but recommended)

---

## Quick Start

### Installation Check

```bash
# Check Xcode installation
xcode-select -p
# Output: /Applications/Xcode.app/Contents/Developer

# Check Command Line Tools only
which clang
# If output shows /usr/bin/clang, you have CLT

# Check Swift version
swift --version
# Should be 5.9+
```

---

## Building with Xcode (Full IDE)

**Requirements:** Full Xcode installed from App Store or developer.apple.com

```bash
# Navigate to project
cd ~/OpenFlux

# Open in Xcode
open Flux.xcodeproj

# Build & Run with Keyboard
# Press Cmd+R or select Product → Run

# Build without running
# Press Cmd+B or select Product → Build

# Archive for distribution
# Select Product → Archive
```

**Keyboard Shortcuts:**
- `Cmd+R` - Build and run
- `Cmd+B` - Build only
- `Cmd+Shift+K` - Clean build folder
- `Cmd+Shift+I` - Install dependencies

---

## Terminal Build Methods (Both Xcode & CLI Tools)

### Method 1: xcodebuild (Requires Full Xcode)

**Note:** This only works with full Xcode installed. Command Line Tools alone cannot build SwiftUI macOS apps.

```bash
cd ~/Projects/OpenFlux

# Build Debug configuration
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -scheme Flux \
  -configuration Debug

# Build Release configuration
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build \
  -scheme Flux \
  -configuration Release

# Archive for distribution
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild archive \
  -scheme Flux \
  -archivePath build/OpenFlux.xcarchive
```

### Method 2: flux-terminal.sh Script (Works with Both)

```bash
# Navigate to project
cd ~/OpenFlux

# Make script executable (first time only)
chmod +x flux-terminal.sh

# Build debug
./flux-terminal.sh build

# Build release
./flux-terminal.sh build-release

# Build and run debug
./flux-terminal.sh run

# Build and run release
./flux-terminal.sh run-release

# Clean build artifacts
./flux-terminal.sh clean

# Check system requirements
./flux-terminal.sh system-check

# Show current status
./flux-terminal.sh status

# Show help
./flux-terminal.sh help
```

**Script Location:** `./flux-terminal.sh` in project root

### Method 3: Direct Swift Compilation (NOT Recommended for SwiftUI)

```bash
# ⚠️ WARNING: Swift compiler alone cannot fully compile SwiftUI macOS apps
# This will likely fail - use Xcode or flux-terminal.sh instead

cd ~/Projects/OpenFlux

# Attempt to parse all Swift files (syntax check only)
swift -parse \
    FluxApp.swift \
    Models/*.swift \
    Services/*.swift \
    Views/*.swift

# This will show parse errors if any
```

---

## Xcode vs Command Line Tools

### Full Xcode Installation

**Pros:**
- ✅ IDE for development, debugging, code completion
- ✅ Interface Builder for StoryBoard/XIB files
- ✅ Full simulator support
- ✅ `xcodebuild` works perfectly
- ✅ Git integration built-in
- ✅ Performance profiling tools

**Cons:**
- ❌ ~15GB disk space
- ❌ Long installation time
- ❌ Large application

**Build Commands Work:** ✅ All methods
- `xcodebuild`
- `flux-terminal.sh`
- Xcode UI

### Command Line Tools Only

**Pros:**
- ✅ ~200MB lightweight install
- ✅ Fast download/install
- ✅ Good for CI/CD servers
- ✅ Minimal disk footprint

**Cons:**
- ❌ No IDE - use VS Code or other editor
- ❌ `xcodebuild` command not available
- ❌ Cannot build SwiftUI macOS apps with just `swift` or `swiftc`
- ❌ No Simulator
- ❌ Limited debugging

**Build Commands Work:** ⚠️ Limited
- ✅ `flux-terminal.sh run` - Use Xcode to build locally first
- ✅ Syntax checking: `swift -parse`
- ❌ `xcodebuild` - NOT AVAILABLE
- ❌ Full compilation of SwiftUI apps

### Recommendation

| Use Case | Recommendation |
|----------|-----------------|
| Active development | **Full Xcode** - Better IDE, debugging, hot reload |
| Building on CI/CD | **Command Line Tools** + pre-built `.xcarchive` |
| Production builds | **Full Xcode** - More reliable, complete toolchain |
| Quick changes | **Full Xcode** - Faster edit-build-test cycle |
| Lightweight setup | **Command Line Tools** + VS Code for editing |

---

## Build & Run Scripts

### Using flux-terminal.sh (Recommended)

Already works with Command Line Tools:

```bash
# Make executable (first time only)
chmod +x flux-terminal.sh

# Run build & launch
./flux-terminal.sh run

# Or build for release
./flux-terminal.sh build-release

# Full help
./flux-terminal.sh help
```

### Using build.sh (Xcode Only)

```bash
# Requires Full Xcode
chmod +x build.sh

# Run build script
./build.sh

# The app will be at: build/Flux.app
# Launch it:
open build/Flux.app
```

### build.sh Contents

```bash
#!/bin/bash
set -e

echo "🔨 Building OpenFlux..."

# Clean previous build
xcodebuild clean -scheme Flux 2>/dev/null || true

# Build for release
xcodebuild build \
    -scheme Flux \
    -configuration Release \
    -derivedDataPath build

echo "✅ Build complete!"
echo "📦 App location: build/Release/Flux.app"
echo "🚀 To run: open build/Release/Flux.app"
```

---

## Running the Application

### Launch from Xcode
```
Product → Run (Cmd+R)
```

### Launch from Finder
1. Build the app (using any method above)
2. Navigate to `build/Debug/` or `build/Release/`
3. Double-click `Flux.app`

### Launch from Terminal
```bash
# Direct executable run
./OpenFlux

# Using open command
open Flux.app

# Using open with absolute path
open /path/to/build/Debug/Flux.app
```

### Launch with Debug Logging
```bash
# Enable verbose logging
FLUX_DEBUG=1 open Flux.app

# View real-time logs
FLUX_DEBUG=1 ./OpenFlux | tail -f
```

---

## Development Workflow

### First Time Setup

```bash
# Clone repository
git clone https://github.com/yourusername/OpenFlux.git
cd OpenFlux

# Install dependencies (if using CocoaPods/SPM)
# xcode automatically handles native frameworks

# Open in Xcode
open Flux.xcodeproj
```

### During Development

```bash
# Build frequently
Cmd+B

# Run to test
Cmd+R

# View build output
Command+9 (Show Build Errors/Warnings)

# Check runtime logs
View → Navigators → Logs (Cmd+7)
```

### Code Changes Workflow

1. **Edit code** in Xcode
2. **Press Cmd+B** to check for errors
3. **Press Cmd+R** to run and test
4. **Check Logs** in app's Logs tab for issues
5. **Use SwiftUI Previews** for UI testing (`Cmd+Option+Return`)

---

## Distribution Builds

### Creating a Release Build

```bash
# Build with optimizations
xcodebuild build \
    -scheme Flux \
    -configuration Release \
    -derivedDataPath build

# App location
open build/Release/Flux.app
```

### Creating a Distribution Archive

```bash
# Archive for App Store or manual distribution
xcodebuild archive \
    -scheme Flux \
    -archivePath build/OpenFlux.xcarchive \
    -derivedDataPath build

# Export archive
xcodebuild -exportArchive \
    -archivePath build/OpenFlux.xcarchive \
    -exportPath build/Distributions \
    -exportOptionsPlist ExportOptions.plist
```

### Manual Distribution

```bash
# Create ZIP for distribution
cd build/Release
zip -r ../OpenFlux.zip Flux.app
# Share OpenFlux.zip with users
```

---

## Project Structure for Building

```
OpenFlux/
├── FluxApp.swift                 # App entry point
├── Models/
│   ├── AppState.swift
│   └── Game.swift
├── Services/
│   ├── LogManager.swift         # ⭐ Core logging
│   ├── SettingsManager.swift    # ⭐ Core state
│   ├── GameLauncher.swift
│   ├── DependencyManager.swift
│   ├── SteamLibraryDetector.swift
│   ├── ProcessMonitor.swift
│   └── MetalDeviceDetector.swift
├── Views/
│   ├── ContentView.swift
│   ├── GamesView.swift
│   ├── PrefixesView.swift
│   ├── LogsView.swift
│   └── SettingsView.swift
├── Info.plist                    # App metadata
├── Flux.xcodeproj               # Xcode project
├── build.sh                      # Build script
├── build.config                  # Build configuration
└── README.md                     # Documentation
```

---

## Build Configuration

### Debug Build
- **Optimization:** None (-Onone)
- **Assertions:** Enabled
- **Symbols:** Full debug symbols
- **Size:** Larger
- **Speed:** Slower compilation, easier debugging

### Release Build
- **Optimization:** Full (-O)
- **Assertions:** Disabled
- **Symbols:** Minimal
- **Size:** Smaller
- **Speed:** Fastest execution

### Setting Build Configuration

**In Xcode:**
1. Select Scheme → Edit Scheme (Cmd+<)
2. Select Run tab
3. Set Build Configuration to Debug or Release
4. Close and run

**From Terminal:**
```bash
xcodebuild build -configuration Debug   # or Release
```

---

## Troubleshooting Build Issues

### Build Fails with "Module not found"
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Rebuild
xcodebuild clean -scheme Flux
xcodebuild build -scheme Flux
```

### Xcode Hangs During Build
```bash
# Kill Xcode processes
killall Xcode

# Restart and rebuild
open Flux.xcodeproj
```

### "Team ID" Error
1. Open Flux.xcodeproj
2. Select project in navigator
3. Select Signing & Capabilities tab
4. Set Team to your Apple ID or personal team

### Swift Compiler Errors
```bash
# Check Swift version
swift --version

# Ensure minimum requirement
# macOS 13.0, Swift 5.9+
```

### Linking Errors
```bash
# Ensure all frameworks are linked
# In Xcode: Target → Build Phases → Link Binary With Libraries

# Required frameworks:
# - AppKit
# - Foundation
# - SwiftUI
# - Combine
```

---

## Performance Optimization

### Faster Builds

```bash
# Use incremental builds (default in Xcode)
# Only changed files recompile

# Disable debug symbols for faster builds (use with caution)
xcodebuild build \
    -scheme Flux \
    -configuration Release \
    GCC_GENERATE_DEBUGGING_SYMBOLS=NO
```

### Profile Build Performance

```bash
# Show time breakdown
xcodebuild build \
    -scheme Flux \
    -configuration Release \
    OTHER_SWIFT_FLAGS=-Xfrontend \
    OTHER_SWIFT_FLAGS=-debug-time-compilation

# Analyze compile times
xcodebuild build \
    -scheme Flux \
    -showBuildTimingSummary
```

---

## Environment Variables

### During Build

```bash
# Custom Swift flags
SWIFTFLAGS=-Xcc -DRELEASE_BUILD xcodebuild build -scheme Flux

# Verbose compilation
VERBOSE_BUILD=1 xcodebuild build -scheme Flux
```

### During Runtime

```bash
# Developer mode
FLUX_DEVELOPER=1 open Flux.app

# Debug logging
FLUX_DEBUG=1 ./OpenFlux

# Custom Wine prefix
WINEPREFIX=/custom/path open Flux.app
```

---

## Running Tests (When Implemented)

```bash
# Run all tests
xcodebuild test -scheme Flux

# Run specific test
xcodebuild test -scheme Flux -only-testing:FluxTests/LaunchEnvironmentTests

# Generate coverage report
xcodebuild test \
    -scheme Flux \
    -configuration Release \
    -derivedDataPath build \
    -enableCodeCoverage YES
```

---

## Debugging

### Using Xcode Debugger

1. **Set Breakpoint:** Click line number (or Cmd+\)
2. **Run:** Cmd+R (pauses at breakpoint)
3. **Step:** F10 (step over), F11 (step into)
4. **View Variables:** Click variable or hover
5. **Console:** Cmd+Shift+Y to view output

### Viewing Runtime Logs

```bash
# In-app logs tab shows all output
# Or access via terminal:
log stream --predicate 'process == "OpenFlux"'
```

### Memory Profiling

```bash
# Use Xcode's Memory Debugger
# Debug → Gauge Debugger → Memory
# Shows memory usage and leaks
```

---

## Git Workflow (Development)

```bash
# Clone repository
git clone https://github.com/yourusername/OpenFlux.git
cd OpenFlux

# Create feature branch
git checkout -b feature/my-feature

# Make changes and commit
git add .
git commit -m "Add feature"

# Build and test
xcodebuild build -scheme Flux

# Push changes
git push origin feature/my-feature

# Create Pull Request on GitHub
```

---

## CI/CD Integration (GitHub Actions)

### Automated Build & Test

Create `.github/workflows/build.yml`:

```yaml
name: Build OpenFlux

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: xcodebuild build -scheme Flux -configuration Release
      - name: Archive
        run: |
          mkdir -p artifacts
          cp -r build/Release/Flux.app artifacts/
      - uses: actions/upload-artifact@v3
        with:
          name: Flux.app
          path: artifacts/Flux.app
```

---

## One-Line Commands

### Quick Build & Run
```bash
xcodebuild build -scheme Flux -configuration Debug && open build/Debug/Flux.app
```

### Release Build
```bash
xcodebuild build -scheme Flux -configuration Release && open build/Release/Flux.app
```

### Clean & Rebuild
```bash
xcodebuild clean -scheme Flux && xcodebuild build -scheme Flux -configuration Debug
```

### Full Test Suite
```bash
xcodebuild clean -scheme Flux && xcodebuild build -scheme Flux && xcodebuild test -scheme Flux
```

---

## Deployment Checklist

- [ ] Code compiles without warnings
- [ ] All tests pass
- [ ] Release build created
- [ ] No sensitive data in code
- [ ] Version number updated
- [ ] README documentation current
- [ ] CHANGELOG updated
- [ ] Archive created for distribution
- [ ] Code signed with certificate
- [ ] Ready for distribution

---

## Additional Resources

- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Xcode Build System](https://developer.apple.com/xcode/build/)
- [Swift Package Manager](https://swift.org/package-manager/)
- [macOS App Development](https://developer.apple.com/macos/app-development/)

---

**Version:** 1.0  
**Last Updated:** January 27, 2026  
**Status:** Production Ready

This is the single source of truth for all build and run operations.
