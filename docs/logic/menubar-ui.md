# Menu Bar UI & Application Window

<!-- macOS menu bar + Dock app with main window, recording overlay, and preferences. -->

<!-- Updated: 2026-06-02 -->

---

## Architecture

- **Menu Bar:** NSStatusItem with NSMenu for quick access
- **Main Window:** SwiftUI window with an explicit primary sidebar for App and Library sections, plus history detail navigation
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
  - App actions (`Prompts`, `Settings`) appear at the top of the primary sidebar.
  - Library and folder/archive filters remain in the same sidebar so Settings is always visible and not hidden in a bottom safe area.
  - The sidebar footer shows the current app version/build directly above `New Folder` so testers can confirm they are using the rebuilt binary.
- **History:** Folder-based organization with All/Unfiled/Folders/Archive/Failed sections
  - Multi-select with batch operations (delete, move, archive)
  - Search/filter
  - Failed transcription indicators (red exclamation icon)
  - Detail view with raw/cleaned text, copy buttons, folder picker
  - Audio playback bar (play/pause, seek, progress, duration)
  - Re-transcribe button with model/prompt picker sheet
- **Prompts:** List with editor, default selection, built-in prompt protection
- **Settings:** Voice input, shortcut, sound, diagnostics, transcription (active model display, downloaded model management with `Use`, on-demand local preparation status, separate `Download & Use` control for undownloaded models), AI cleanup, media, permissions, storage auto-delete settings
  - AI cleanup API key entry no longer pre-fills the secret into the field; it shows the saved key suffix and treats pasted text as a replacement.
  - AI cleanup connection card tests pasted replacement keys before saving, verifies Keychain persistence by reading the key back, clears the replacement field only after a successful save, and shows the saved suffix in the success result.
- **Version Footer:** The primary sidebar footer displays `v<short-version> (<build>)` above `New Folder`, making rebuilt binaries visually verifiable after relaunch.

## Menu Bar

- State-based icon: mic.circle (idle), mic.fill (recording), text.bubble (transcribing), sparkles (cleaning), checkmark.circle (completed), exclamationmark.triangle (error)
- "Show Mac Speech to AI to Text" menu item opens main window
- "Preferences…" opens main window to Settings tab
- Start/Stop Recording toggle
- Quit

## Key Behaviors

- Diagnostics section includes a file-logging toggle, current log path, Reveal Log File, and Copy Log Path controls.
- Menu bar icon reflects all pipeline states
- Menu bar acts as quick-access companion to the full app
- Overlay lifecycle tied to pipeline — appears on activation, disappears on user action
- Insert action uses cursor position captured at recording start
- Finishing a recording by send phrase or `Done` now plays an immediate acknowledgement sound before transcription starts
