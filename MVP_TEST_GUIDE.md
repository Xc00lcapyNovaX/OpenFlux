# 🎯 OpenFlux MVP Test - Launch a Game
Project name: OpenFlux (internal targets/bundle still named "Flux").

**Goal:** Get one Windows EXE running through Wine (GPTK optional) via OpenFlux.

This is the **minimum viable product** to prove the pipeline works.

---

## ✅ Prerequisites

### 1. GPTK Installed
```bash
# Check if GPTK is installed
ls -la /opt/gptk

# If missing, download from:
# https://developer.apple.com/download/all/
# Search for "Game Porting Toolkit"
# Extract to: /opt/gptk
```

### 2. Wine Available
GPTK does not include Wine, so verify Wine separately:
```bash
ls -la /opt/homebrew/bin/wine
```

### 3. Test Game Ready
Create a test directory with a Windows EXE:
```bash
# Create directory
mkdir -p ~/Games/TestGame

# Copy a test game (replace with your file)
cp /path/to/your/game.exe ~/Games/TestGame/game.exe

# Verify
ls -la ~/Games/TestGame/game.exe
```

**What to test with:**
- ✅ DirectX sample app (easiest)
- ✅ Simple indie game (.exe only, no launcher)
- ✅ HelloWorld.exe or similar test binary
- ❌ DON'T use Steam games yet
- ❌ DON'T use complex launchers

---

## 🚀 How to Test

### Step 1: Build OpenFlux
```bash
cd ~/OpenFlux
xcodebuild build -scheme Flux -configuration Debug
```

### Step 2: Launch OpenFlux
```bash
open build/Debug/Flux.app
```

### Step 3: Click the Test Button
- Look for the **"🧪 Test"** button in the Games view
- Click it
- Watch the **Logs** tab for output

---

## 📊 Three Possible Outcomes

### ✅ Outcome 1: Game Window Appears
**You won.** The pipeline works.

Next: Try with different games, then integrate Steam.

### ⚠️ Outcome 2: Wine Error in Logs
Example errors:
```
Wine error: cannot find d3d12.dll
Wine error: STAGING_SHARED_MEMORY not supported
```

**This is good.** It means:
- ✅ OpenFlux launched
- ✅ Wine started
- ❌ Environment or DLL issue

Fix:
1. Check GPTK installation
2. Verify environment variables in logs
3. Try a different test game

### ❌ Outcome 3: Process Exits Silently
No output, game doesn't appear.

**Debug steps:**
1. Check logs for any error messages
2. Verify test EXE exists: `ls -la ~/Games/TestGame/game.exe`
3. Try running wine manually:
```bash
WINEPREFIX=~/.flux/prefix /opt/homebrew/bin/wine ~/Games/TestGame/game.exe
```

---

## 🔍 Reading the Logs

After clicking **"🧪 Test"**, open the **Logs** tab and look for:

### ✅ Success Pattern
```
TEST GAME LAUNCH - Minimal Viable Product
Test EXE found: /Users/...
Wine executable: /Users/.../.wine/bin/wine
GPTK path: /opt/gptk
═══════════════════════════════════════════
LAUNCHING: game.exe
Command: /Users/.../wine /Users/.../game.exe
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Process started with PID: 12345
⏳ Waiting for game to exit...
[game output here]
✅ Game exited successfully (status: 0)
TEST LAUNCH COMPLETE
```

### ⚠️ Error Pattern
```
❌ Test game not found at: /Users/.../game.exe
To test: mkdir -p ~/Games/TestGame && cp YOUR_GAME.exe ~/Games/TestGame/game.exe
```

---

## 🛠️ Troubleshooting

### Issue: "Test game not found"
```
Error: Test game not found at: /Users/efealibel/Games/TestGame/game.exe
```

**Fix:**
```bash
mkdir -p ~/Games/TestGame
cp /your/game/path/game.exe ~/Games/TestGame/
```

### Issue: "GPTK not available"
```
Error: GPTK not available. Install at /opt/gptk or configure in Settings.
```

**Fix:**
1. Download GPTK from https://developer.apple.com/download/all/
2. Extract to `/opt/gptk`
3. Or configure in Settings → GPTK Path

### Issue: Wine errors
```
Wine error: cannot load d3d11.dll
Wine error: STAGING_SHARED_MEMORY not supported
```

**This is expected** on first run. The DLL will be auto-installed on next run.

### Issue: Nothing happens
```
✅ Process started with PID: 12345
⏳ Waiting for game to exit...
[silence]
```

**Debug:**
1. Try manually:
```bash
WINEPREFIX=~/.flux/prefix /opt/homebrew/bin/wine ~/Games/TestGame/game.exe
```

2. Check if Wine prefix exists:
```bash
ls -la ~/.flux/prefix/
```

3. Verify the EXE is valid:
```bash
file ~/Games/TestGame/game.exe
```

---

## 🎮 Test Games to Try

### Option 1: DirectX Sample (Easiest)
Download DirectX samples from Microsoft, compile one, test it.

### Option 2: Small Indie Game
- Flappy Bird (Windows)
- Itch.io → Filter by Windows, Size < 10MB
- Zork or similar text adventures

### Option 3: Test Binary
```bash
# Create a simple batch file that displays text
echo "HELLO FROM WINE" > ~/Games/TestGame/test.bat

# Test it:
WINEPREFIX=~/.flux/prefix /opt/homebrew/bin/wine cmd.exe /c ~/Games/TestGame/test.bat
```

---

## ✅ Success Checklist

- [ ] GPTK installed at /opt/gptk
- [ ] Test EXE at ~/Games/TestGame/game.exe
- [ ] OpenFlux builds without errors
- [ ] "🧪 Test" button visible in OpenFlux
- [ ] Clicked button, checked logs
- [ ] One of three outcomes observed
- [ ] Documented which outcome and any errors

---

## 📋 Next Steps (After MVP Works)

1. **Multiple Test Games** - Confirm it works with 2-3 different games
2. **Steam Integration** - Replace hardcoded path with Steam game detection
3. **UI Improvements** - Show game list, launch selection
4. **Dependency Auto-Install** - DLL detection and installation
5. **DRM Handling** - Handle copy-protected games

---

## 🧪 MVP Test Code Location

The test code is in:
- **GameLauncher.swift** - `launchTestGame()` function
- **AppState.swift** - `launchTestGame()` wrapper
- **GamesView.swift** - "🧪 Test" button

To disable test mode, just remove the button and method calls.

---

**Start here. Get to "game window appears". Then iterate.**

**Estimated time:** 5-15 minutes.

**Success metric:** One Windows game launches via OpenFlux.
