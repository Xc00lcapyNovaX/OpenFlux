# Geometry Dash with MegaHack v9 Pro Setup Guide

## Overview
This guide helps you set up Geometry Dash (Windows) with MegaHack v9 Pro mod support in OpenFlux.

## Prerequisites
- OpenFlux installed and running
- Wine installed via Homebrew: `brew install --cask wine-stable`
- A Windows copy of Geometry Dash (not the macOS version)

## Setup Steps

### 1. Install Geometry Dash Windows Version
You have two options:

**Option A: Download from Steam (Windows)**
If you have access to a Windows machine or Windows partition:
- Download Geometry Dash from Steam (Windows version)
- Copy the game directory to your Mac

**Option B: Download standalone or GOG version**
- Visit geometrydash.com or GOG.com
- Download the Windows version
- Extract it to a location on your Mac

### 2. Create Game Directory Structure
```bash
mkdir -p ~/Windows Games/Geometry Dash
# Copy your Geometry Dash installation here
```

The directory should contain:
- `GeometryDash.exe` (main executable)
- `D3D11.dll`, `D3D9.dll` (rendering libraries)
- All game assets and data files

### 3. Install MegaHack v9 Pro DLL Files
```bash
mkdir -p ~/.flux/dlls

# Download MegaHack v9 Pro from: https://github.com/Capeling/MegaHack-v9-Pro
# Or use the pre-compiled version if available

# Copy MegaHack DLLs to ~/.flux/dlls
cp ~/Downloads/MegaHack_v9_*.dll ~/.flux/dlls/
```

MegaHack DLL files typically include:
- `MegaHackV9.dll` (main mod loader)
- `MegaHackPro.dll` (pro features)
- Any dependency DLLs

### 4. Configure in OpenFlux

#### Method 1: Direct Launch (Recommended)
1. Open OpenFlux
2. Go to **Games** tab
3. Navigate to your Geometry Dash directory using file browser
4. Click on `GeometryDash.exe` to launch

#### Method 2: Add to Steam Library
If you want OpenFlux to detect it automatically:
```bash
# Create a Steam-compatible structure
mkdir -p ~/Steam Games/steamapps/common/"Geometry Dash Windows"
cp -r ~/Windows\ Games/Geometry\ Dash/* ~/Steam\ Games/steamapps/common/"Geometry Dash Windows"/
```

Then create a manifest file:
```bash
cat > ~/Steam\ Games/steamapps/appmanifest_322170.acf << 'EOF'
"AppState"
{
    "appid"    "322170"
    "name"     "Geometry Dash Windows"
    "installdir"    "Geometry Dash Windows"
    "buildid"    "1"
}
EOF
```

### 5. Verify DLL Injection is Working
1. Launch Geometry Dash from OpenFlux
2. Check the **Logs** tab for the message:
   ```
   DLL Injection enabled: MegaHack_v9_*.dll
   ```
3. If MegaHack loads, you should see its interface in-game

## Troubleshooting

### "Wine architecture error (wow64 mode)"
- ✓ Already fixed! OpenFlux now uses 64-bit Wine by default for Apple Silicon

### MegaHack not loading
Check the following:
1. DLL files are in `~/.flux/dlls/`
2. DLL filenames end with `.dll` (lowercase)
3. OpenFlux logs show DLL injection is enabled
4. Wine can access the DLLs (permissions)

```bash
# Check DLL permissions
ls -la ~/.flux/dlls/
chmod 644 ~/.flux/dlls/*.dll
```

### Game won't launch
1. Check if `GeometryDash.exe` is 64-bit (use `file` command)
2. Verify Wine is at `/opt/homebrew/bin/wine`
3. Check OpenFlux logs for specific errors

```bash
# Check Wine installation
which wine
/opt/homebrew/bin/wine --version
```

### Performance Issues
- Adjust DXVK/Wine settings in Settings → Advanced
- Disable GPTK if not needed
- Check CPU/GPU usage in Activity Monitor

## Advanced Configuration

### Custom Wine Prefix
To use a custom Wine prefix for Geometry Dash:
1. Settings → Prefix Management
2. Create new prefix: `geom-dash-prefix`
3. Right-click Geometry Dash → Use prefix → `geom-dash-prefix`

### Custom DLL Overrides
Add custom DLL override rules in `~/.flux/wine.conf`:
```
[HKEY_CURRENT_USER\Software\Wine\DllOverrides]
"MegaHackV9"="native,builtin"
"d3d11"="native"
"d3d9"="native"
```

### GPTK Optimization
For better performance:
1. Settings → Graphics
2. Enable GPTK (Game Porting Toolkit)
3. Set GPU Device: "Apple M4" (if available)

## Next Steps
After setup, try:
1. Launch Geometry Dash to verify it runs
2. Test MegaHack features (if loading)
3. Adjust settings if needed for performance
4. Create a Wine prefix optimized for Geometry Dash

## Need Help?
- Check logs in **Logs** tab
- See [WINE_GPTK_ARCHITECTURE.md](./WINE_GPTK_ARCHITECTURE.md) for architecture details
- File issues with full log output
