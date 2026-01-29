# Quick Start: Geometry Dash + MegaHack v9 Pro

## What Changed
✓ Fixed Wine architecture issue (was trying 32-bit, now uses 64-bit)
✓ Added DLL injection support for mods like MegaHack
✓ Updated test launcher to use proper environment

## Setup (Quick Steps)

### 1. Get Geometry Dash Windows Edition
You need the Windows version, not the macOS version. Options:
- Download from Steam (Windows store version)
- Download from GoG.com (Windows version)  
- Extract to a folder

### 2. Set up DLL Injection for MegaHack
```bash
mkdir -p ~/.flux/dlls

# Copy MegaHack v9 Pro DLLs here
# Download from: https://github.com/Capeling/MegaHack-v9-Pro/releases
# Extract and copy all .dll files to ~/.flux/dlls/

ls ~/.flux/dlls/
# Should show: MegaHackV9.dll, etc.
```

### 3. Copy Geometry Dash to OpenFlux Games
```bash
mkdir -p ~/Games/GeometryDash

# Copy your Geometry Dash Windows installation
cp -r /path/to/geometry/dash/windows/* ~/Games/GeometryDash/

# Should have GeometryDash.exe in this directory
ls ~/Games/GeometryDash/GeometryDash.exe
```

### 4. Launch from OpenFlux

When you launch GeometryDash.exe from OpenFlux:
1. Open the app (it's already running)
2. Look at the **Logs** tab  
3. You should see:
   ```
   DLL Injection enabled: MegaHackV9.dll, ...
   ```
4. If setup correctly, MegaHack will load inside Geometry Dash

## Testing the Fixed Architecture

The test game should now work:
1. Click the "🧪 Test" button in the Games tab
2. You'll see logs like:
   ```
   Wine prefix: /Users/efealibel/.flux/prefix-x86-native
   Wine executable: /opt/homebrew/bin/wine
   GPTK enabled: true
   ```
3. The batch file should execute without the wow64 error

## Files Modified
- `Services/LaunchCoordinator.swift` - Fixed test launcher to use 64-bit
- Added DLL injection support in test launcher
- `SETUP_GEOM_DASH.md` - Full setup guide

## Next Steps
1. Provide Geometry Dash Windows EXE location
2. Provide MegaHack v9 Pro DLL files
3. I can help debug if it doesn't work

For full details, see [SETUP_GEOM_DASH.md](./SETUP_GEOM_DASH.md)
