# OpenFlux - Missing DLL Dependencies Guide

## Problem Statement

When running Windows executables like `SteamSetup.exe` on macOS via Wine, you may encounter errors due to missing `.dll` dependencies such as:
- `steam_api64.dll` - Steam client API
- `steam_api.dll` - Older Steam API
- `vcruntime140.dll` - Visual C++ runtime
- `msvcp140.dll` - Visual C++ standard library
- Other Windows system DLLs

These dependencies are often:
1. Not available in Wine's default prefix
2. Not distributed with the executable
3. Required from a Windows installation or SDK

## Solutions Implemented in OpenFlux

OpenFlux now provides **automatic dependency handling**:

### 1. Dependency Analysis
When launching any executable, OpenFlux automatically:
- Scans the executable for DLL imports
- Checks if required DLLs exist in the Wine prefix
- Reports missing dependencies

### 2. Stub DLL Generation
For missing dependencies, OpenFlux can create **minimal stub DLLs** that:
- Allow executables to load without crashing
- Don't provide full functionality
- Prevent "DLL not found" errors
- Work with Wine's DLL load mechanism

### 3. Dependency Resolution
The system maintains a database of common missing DLLs and their purposes:
- Steam client APIs
- Visual C++ runtimes
- DirectX components
- Windows system libraries

## Using OpenFlux with Missing Dependencies

### Scenario 1: Running SteamSetup.exe

```bash
# Copy SteamSetup.exe to a games directory
mkdir -p ~/Games/SteamSetup
cp ~/Downloads/SteamSetup.exe ~/Games/SteamSetup/

# Launch from OpenFlux Games tab
# OpenFlux will automatically:
# 1. Detect missing steam_api64.dll
# 2. Create a stub DLL
# 3. Launch the executable
```

**What to expect:**
- Logs showing: "Missing 1 DLL dependencies for SteamSetup.exe"
- Message: "steam_api64.dll: Steam client API (64-bit) - Required for Steam games"
- Message: "Creating stub DLLs to allow execution..."
- Game launches (may have limited Steam functionality)

### Scenario 2: Running Geometry Dash Windows Setup

```bash
# Copy GeometryDash.exe or installer
mkdir -p ~/Games/GeometryDash
cp ~/Downloads/GeometryDash.exe ~/Games/GeometryDash/

# Or if using installer:
cp ~/Downloads/GeometryDashSetup.exe ~/Games/GeometryDash/

# Launch from OpenFlux
# Automatically handles missing dependencies
```

## How Stub DLLs Work

When OpenFlux creates a stub DLL:

1. **File Creation**: Minimal PE (Portable Executable) file is created in Wine prefix
   - Path: `~/.flux/prefix-native/drive_c/windows/system32/missing.dll`
   - Contains minimal DLL header structure
   - Can be loaded by Wine without crashing

2. **DLL Loading**: Wine loads the stub instead of failing
   - Prevents crash on missing import
   - May have limited functionality
   - Often sufficient for initialization/setup

3. **Function Calls**: When executable tries to call functions from stub:
   - May fail gracefully (returns NULL/error code)
   - May succeed if not critical to execution
   - Depends on how robust the calling code is

## Advanced: Providing Real DLLs

If stub DLLs aren't sufficient, you can provide real implementations:

### Option 1: Copy from Windows Installation
```bash
# If you have access to Windows installation media:
cp "Windows/System32/steam_api64.dll" ~/.flux/prefix-native/drive_c/windows/system32/

# Then restart OpenFlux to reload
```

### Option 2: Extract from Installed Software
```bash
# Visual C++ runtime can often be found in:
# C:\Program Files\Microsoft Visual Studio\...
# C:\Windows\System32\

# Copy to Wine prefix
cp ~/extracted_dlls/*.dll ~/.flux/prefix-native/drive_c/windows/system32/
```

### Option 3: Use DXVK or Proton DLLs
```bash
# Download pre-built DLL packages
# From: https://github.com/lutris/docs/blob/master/Runners.md

mkdir -p ~/.flux/dll-packages
# Extract downloaded DLLs here
```

## DLL Injection for Mods (MegaHack v9 Pro)

Separate from dependency handling, OpenFlux supports **DLL injection for mods**:

```bash
mkdir -p ~/.flux/dlls

# Copy MegaHack DLLs
cp ~/Downloads/MegaHackV9.dll ~/.flux/dlls/
cp ~/Downloads/MegaHackPro.dll ~/.flux/dlls/

# Launch Geometry Dash - mods will be injected automatically
```

**Difference from stub DLLs:**
- Stub DLLs: Auto-created for missing system/Steam DLLs
- Injection DLLs: User-provided mod/enhancement DLLs

## Troubleshooting

### "DLL not found" still appearing after launch
- Check `~/.flux/prefix-native/drive_c/windows/system32/` for stub DLLs
- Verify logs show "Created stub DLL: ..."
- Some executables may require real DLLs (non-stub versions)

### Executable crashes even with stub DLLs
- Stub DLLs provide minimal functionality
- The executable may require actual implementations
- Try: Obtain real DLL files from Windows installation
- Or: Modify game settings to not require missing DLL

### Multiple missing DLLs
- OpenFlux creates stubs for all missing DLLs automatically
- Each is logged separately
- Check Logs tab for full list

### GPTK + Missing Dependencies
- GPTK (Graphics) is independent from DLL stubs (system)
- Both can be used together
- Enable GPTK in Settings if experiencing graphics issues

## DLL Database

OpenFlux tracks these common missing DLLs:

| DLL | Purpose | Type |
|-----|---------|------|
| steam_api64.dll | Steam client API (64-bit) | Steam |
| steam_api.dll | Steam client API (32-bit) | Steam |
| vcruntime140.dll | Visual C++ Runtime 2015 | Runtime |
| vcruntime140_1.dll | Visual C++ Runtime 2015 Update 1 | Runtime |
| msvcp140.dll | Visual C++ Standard Library | Runtime |
| d3d11.dll | DirectX 11 Graphics | Graphics |
| d3d9.dll | DirectX 9 Graphics | Graphics |
| dinput8.dll | DirectInput (Input Devices) | Input |
| dsound.dll | DirectSound (Audio) | Audio |
| dxgi.dll | DirectX Graphics Infrastructure | Graphics |
| mscoree.dll | .NET Framework Runtime | Runtime |
| kernel32.dll | Windows Kernel Core | System |
| ntdll.dll | Windows NT Runtime | System |
| user32.dll | Windows User Interface | System |
| gdi32.dll | Graphics Device Interface | System |
| advapi32.dll | Advanced API Services | System |

## For Geometry Dash Specifically

Since you can't access the native Geometry Dash executable:

### Option 1: Use Setup/Installer
```bash
# If you have GeometryDashSetup.exe:
mkdir -p ~/Games/GeometryDash
cp ~/Downloads/GeometryDashSetup.exe ~/Games/GeometryDash/

# Run installer through OpenFlux
# It will create the actual game executable
# Then you can launch that executable directly
```

### Option 2: Extract from Portable Build
```bash
# Some distributions provide portable/standalone builds
# These can be extracted and run without installation
```

### Option 3: Use in Steam through Wine
```bash
# If you have Steam installed in Wine:
# Use Wine's Steam to download Windows version
# OpenFlux will handle the dependencies automatically
```

## Next Steps

1. **Test with provided test game**: Click "🧪 Test" button
2. **Try SteamSetup.exe**: Copy to ~/Games/SteamSetup/ and launch
3. **Monitor logs**: Check Logs tab to see what's happening
4. **Report issues**: Include full log output when debugging

## Key Files

- `Services/DLLDependencyResolver.swift` - Dependency analysis and stub generation
- `Services/LaunchCoordinator.swift` - Integration with launch process
- `~/.flux/prefix-native/drive_c/windows/system32/` - Wine system DLLs location
- `~/.flux/dlls/` - User-provided mod DLLs for injection

---

**Last Updated**: January 29, 2026
**Status**: Active - Automatic dependency handling implemented
