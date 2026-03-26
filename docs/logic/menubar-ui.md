# Menu Bar UI

<!-- macOS menu bar app interface, preferences, and settings. -->

<!-- Updated: 2026-03-26 -->

---

## Architecture

- **Menu Bar:** NSStatusItem with NSMenu for the menu bar icon and dropdown
- **Preferences:** Settings window (SwiftUI) for configuring shortcuts, thresholds, and behavior
- **State Display:** Menu bar icon reflects app state (idle, listening, recording, transcribing)

## Key Behaviors

- App runs as a menu bar agent (LSUIElement = true, no dock icon)
- Menu bar dropdown shows current status, start/stop controls, and preferences access
- Preferences window manages: shortcut key, silence threshold, send phrase, model size, auto-resume media

## Common Patterns

- Use NSStatusItem for menu bar presence
- SwiftUI for preferences window
- UserDefaults or @AppStorage for persisting settings
- NSApplication.shared.activate for bringing preferences window to front
