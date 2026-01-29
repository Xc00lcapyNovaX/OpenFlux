# Wine & GPTK Architecture - The Correct Approach
Project name: OpenFlux (internal targets/bundle still named "Flux").

## Why This Changed

Apple no longer ships Wine with GPTK. GPTK 1.2+ is **only** the DirectX/Metal translation layer.

**Old (Incorrect):** GPTK includes Wine → Single dependency
**New (Correct):** Wine and GPTK are independent (GPTK optional) → Two separate dependencies

---

## What You Need to Install

### Wine (Required for all games)

```bash
# Option 1: Homebrew (Recommended)
brew install --cask wine-stable

# Option 2: Wine-Staging for cutting edge features
brew tap homebrew/cask-versions
brew install --cask wine-staging

# Verify installation
which wine
# Output: /opt/homebrew/bin/wine
```

**Wine provides:**
- The Wine runtime (`wine` executable)
- Win32/Win64 API compatibility layer
- OpenGL support built-in

### GPTK (Required only for D3D games)

```bash
# Download from Apple
# https://developer.apple.com/download/
# Extract to /opt/gptk (or configure in OpenFlux settings)

# Verify installation
ls -la /opt/gptk/lib
# Should contain: libdxvk*.dylib, libd3d11*.dylib, etc.
```

**GPTK provides:**
- DirectX → Metal translation layer (`d3d11`, `dxvk`, etc.)
- Runtime Metal GPU support
- Only needed for D3D games

---

## How OpenFlux Architecture Works

### The Detection Split

```swift
// Wine: Always checked first
func launch(_ game: Game) {
    guard WineDetector.shared.isAvailable else {
        // Wine is missing - can't launch ANY game
        return
    }
    
    // GPTK: Only checked for D3D games and only if enabled
    if settingsManager.useGPTK, game.config.graphicsAPI == .directX {
        guard GPTKDetector.shared.isAvailable else {
            // GPTK missing but it's needed for this game's D3D
            return
        }
    }
    
    // Both checks passed, launch
}
```

### What OpenFlux Can Do Now

| Condition | Can Launch Non-D3D | Can Launch D3D |
|-----------|-------------------|----------------|
| Wine only | ✅ Yes | ❌ No (needs GPTK) |
| GPTK only | ❌ No (needs Wine) | ❌ No (needs Wine) |
| Wine (GPTK optional) | ✅ Yes | ✅ Yes |
| Neither | ❌ No | ❌ No |

---

## No More False Failures

**Before:** "System check failed" (unclear why)
**After:** Specific error message:
- "Wine is required but not installed"
- "GPTK is required for this D3D game but not installed"
- "Ready for OpenGL games (GPTK needed for DirectX)"

---

## How Other Tools Do It

- **Whisky** (macOS Wine wrapper): Bundles Wine, requires GPTK separately
- **CrossOver** (Commercial): Bundles Wine, requires GPTK separately
- **Parallels** (Virtualization): Uses Windows Arm64 natively, no Wine needed

This is the standard approach in 2026.

---

## Environment Variables Setup

When launching games, OpenFlux sets:

```bash
WINEPREFIX=~/.flux/prefix        # Wine data directory
DYLD_LIBRARY_PATH=/opt/gptk/lib  # GPTK translation libs (D3D only)
PATH=$WINE_BIN:$PATH             # wine in search path
```

This happens automatically - no manual configuration needed.

---

## Troubleshooting

### "Wine not found"
```bash
brew install --cask wine-stable
# Then restart OpenFlux
```

### "D3D game won't launch (Wine is available)"
```bash
# GPTK is missing
# Download from Apple Developer
# Extract to /opt/gptk
# Or configure custom path in OpenFlux settings
```

### "Game runs but crashes"
Check OpenFlux logs for:
- Wine environment variables
- GPTK library loading
- Prefix initialization

---

## Technical Details

### Wine Search Paths
1. Custom path (from OpenFlux settings)
2. `/opt/homebrew/bin/wine` (Homebrew ARM64)
3. `/usr/local/bin/wine` (Homebrew Intel)
4. `/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine`

### GPTK Search Paths
1. `/opt/gptk/lib` (standard)
2. Custom path (from OpenFlux settings)

### Graphics API Detection
OpenFlux now tracks each game's graphics API:
- `DirectX` (D3D11, D3D12) → Requires GPTK
- `OpenGL` → Wine only (no GPTK needed)
- `Vulkan` → Wine only (native macOS Vulkan)
- `Unknown` → Conservative - requires both
