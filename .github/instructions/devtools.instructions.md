---
description: Browser DevTools and local development access
applyTo: '*'
---

# DevTools & Local Development

## Build & Run

Mac Voice is a native macOS app. Verification is done via Xcode build + run, not browser DevTools.

```bash
cd /Volumes/Byron\ Beats/savedpixel/mac-voice
swift build          # CLI build
swift test           # Run tests
open Package.swift   # Open in Xcode for GUI build/run
```

## Verification Protocol

Since this is a macOS menu bar app (not a web app), visual verification uses:

1. **Build the project** — `swift build` must succeed with zero errors
2. **Run tests** — `swift test` must pass
3. **Rebuild and relaunch** — Always rebuild the app bundle and relaunch after code changes:
   ```bash
   swift build
   kill $(pgrep -f "Mac Voice") 2>/dev/null
   bash scripts/build-app.sh
   open "/Volumes/Byron Beats/savedpixel/mac-voice/build/Mac Voice.app"
   ```
4. **Test features** — Trigger shortcuts, verify audio recording, check preferences window

### Visual Verification for UI Changes

For UI-affecting changes, use screenshot-based verification:

1. **Before changes**: Take a screenshot with `screencapture` to baseline
2. **After changes**: Rebuild, relaunch, capture again
3. **Compare** before/after — confirm the issue is resolved
4. Use `screencapture -R "x,y,w,h"` to capture specific regions
5. Use AppleScript to get window position:
   ```bash
   osascript -e 'tell application "System Events" to tell process "MacVoice" to get position of window "Mac Voice"'
   ```

## Accessibility Permissions

The app requires these macOS permissions for full functionality:

- **Accessibility** — For text field detection and insertion (System Preferences → Privacy & Security → Accessibility)
- **Microphone** — For audio recording (granted via system prompt on first use)
- **Input Monitoring** — For global keyboard shortcuts (System Preferences → Privacy & Security → Input Monitoring)

## Debug Logging

Use Console.app to view OSLog output:

```bash
log stream --predicate 'subsystem == "com.macvoice.app"' --level debug
```
