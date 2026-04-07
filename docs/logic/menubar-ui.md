# Menu Bar UI & Application Window

<!-- macOS menu bar + Dock app with main window, recording overlay, and preferences. -->

<!-- Updated: 2026-04-02 -->

---

## Architecture

- **Menu Bar:** NSStatusItem with NSMenu for quick access
- **Main Window:** SwiftUI `NavigationSplitView` with sidebar (History, Prompts, Settings)
- **Recording Overlay:** Floating NSPanel showing pipeline state with action buttons
- **Dock Presence:** App appears in Dock and Cmd+Tab (LSUIElement = NO)

## Recording Overlay

- **Type:** `NSPanel` (non-activating, floating, borderless)
- **Position:** Centered on screen
- **Styling:** `.ultraThinMaterial` background, rounded corners
- **States:**
  - Recording: Live single-line PCM waveform, running timer, Cancel, and Done
  - Transcribing: Spinner + "Transcribing…"
  - Cleaning: Spinner + "Cleaning up via AI…"
  - Completed: Text display + Copy/Insert/Dismiss buttons (stays until user acts)
  - Error: Error message + Dismiss
- **Non-activating:** Does not steal focus from the active text field

### Recording Overlay Notes

- The waveform is driven from live microphone sample history instead of dB-only level bars
- Silence stays visually centered; speech moves the line above and below the midpoint like a native audio waveform
- The recording timer is shown directly beneath the waveform and updates continuously during capture

## Main Window

- Opens automatically on launch
- Sidebar navigation: History, Prompts, Settings
  - Global sections (App Prompts, Library, Folders, Archival) appear in main list.
  - Setting button is uniquely pinned to the bottom of the sidebar.
- **History:** Folder-based organization with All/Unfiled/Folders/Archive/Failed sections
  - Multi-select with batch operations (delete, move, archive)
  - Search/filter
  - Failed transcription indicators (red exclamation icon)
  - Detail view with raw/cleaned text, copy buttons, folder picker
  - Audio playback bar (play/pause, seek, progress, duration)
  - Re-transcribe button with model/prompt picker sheet
- **Prompts:** List with editor, default selection, built-in prompt protection
- **Settings:** Voice input, shortcut, transcription (dynamic model picker with download status), AI cleanup, media, permissions, downloaded model management (list with sizes + delete), storage auto-delete settings

## Menu Bar

- State-based icon: mic.circle (idle), mic.fill (recording), text.bubble (transcribing), sparkles (cleaning), checkmark.circle (completed), exclamationmark.triangle (error)
- "Show Mac Voice" menu item opens main window
- "Preferences…" opens main window to Settings tab
- Start/Stop Recording toggle
- Quit

## Key Behaviors

- Menu bar icon reflects all pipeline states
- Menu bar acts as quick-access companion to the full app
- Overlay lifecycle tied to pipeline — appears on activation, disappears on user action
- Insert action uses cursor position captured at recording start
- Finishing a recording by send phrase or `Done` now plays an immediate acknowledgement sound before transcription starts
