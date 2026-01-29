# ⚡ 5-Minute Quick Start
Project name: OpenFlux (internal targets/bundle still named "Flux").

## Do This Right Now

### Step 1: Get a Test Game (2 min)
```bash
# Option A: Create simple test directory
mkdir -p ~/Games/TestGame

# Option B: Use an existing Windows .exe
# Pick ANY simple Windows game or test app
# Copy it to ~/Games/TestGame/game.exe
```

### Step 2: Build OpenFlux (2 min)
```bash
cd ~/OpenFlux
xcodebuild build -scheme Flux -configuration Debug
```

### Step 3: Run & Test (1 min)
```bash
open build/Debug/Flux.app
```

Click the **🧪 Test** button in the Games view status bar.

---

## What to Expect

### ✅ Best Case (2-5 seconds)
Game window pops up → **YOU WON**

### ⚠️ Medium Case (immediate)
Logs show Wine error → Fix env vars, iterate

### ❌ Worst Case (timeout)
Nothing happens → Manually test Wine, debug

---

## What to Look For in Logs

```
TEST GAME LAUNCH - Minimal Viable Product
✅ Process started with PID: XXXXX
Game window appears OR wine error OR silent exit
```

---

## Three Outcomes = Three Victories

1. **Game launches** → Pipeline works! 🎉
2. **Wine error** → Found the issue! 🔧
3. **Silent fail** → Debug target identified! 🎯

All three mean progress.

---

## That's It

No settings.  
No configuration.  
No accounts.

Just click and see what happens.

**Read:** [MVP_TEST_GUIDE.md](MVP_TEST_GUIDE.md) for detailed troubleshooting.