# Plan: Initial Mac Speech to AI to Text Project Scaffold & Core Infrastructure

> **Status:** Complete
> **Created:** 2026-03-26
> **Estimated steps:** 18
> **Risk level:** Medium

## Context

Mac Speech to AI to Text is a greenfield macOS menu bar application. All architecture is documented in `docs/logic/` but zero Swift code exists. This plan covers the full initial implementation: Swift package setup, app lifecycle, menu bar UI, audio recording pipeline, transcription integration, input handling (global shortcuts, wake phrase, text insertion), and the orchestration state machine that ties everything together.

## Current State

- **No Swift source code exists.** No `Package.swift`, no `MacVoice/` directory, no `.swift` files.
- Architecture is fully documented across 5 logic docs: `core.md`, `audio.md`, `input.md`, `menubar-ui.md`, `transcription.md`.
- Process infrastructure (instructions, prompts, task tracking) is in place.
- Git is initialized but no commits exist.

## Target State

A buildable, runnable macOS menu bar application with:
1. SPM project structure with all dependencies declared
2. Menu bar agent app (no dock icon) with status item and dropdown menu
3. Preferences window (SwiftUI) for configuring shortcut, silence threshold, send phrase, model size
4. Audio recording via AVAudioEngine with silence detection
5. Background media pause/resume
6. Ready beep playback
7. Global shortcut detection (double-tap configurable key)
8. Wake phrase detection ("okay, voice") via Speech framework
9. Local Whisper transcription via whisper.cpp / WhisperKit
10. Text insertion into active field via Accessibility API
11. Auto-submit via simulated Enter key
12. Central state machine orchestrating the full pipeline: idle → recording → transcribing → inserting → idle
13. Permission management (Accessibility, Microphone, Input Monitoring)
14. OSLog-based structured logging throughout

## Assumptions

1. **WhisperKit** (from Argmax) will be used over raw whisper.cpp — it's a Swift-native package with better SPM integration and Apple Silicon optimization.
2. **MASShortcut** or HotKey will be used for global shortcut registration — decided at implementation time based on SPM availability.
3. The app targets **macOS 14.0+ (Sonoma)** to leverage latest Swift concurrency and observation APIs.
4. **LSUIElement** is set via Info.plist to hide the dock icon.
5. The initial Whisper model bundled will be **"tiny"** for fast iteration; larger models configurable later.
6. Media pause uses **`NowPlayingMediaController`** or AppleScript bridge — implementation will determine which is more reliable.
7. The send phrase defaults to **"OK, send"** with a **2-second** silence threshold.
8. Wake phrase detection uses Apple's **Speech framework** (`SFSpeechRecognizer`) for low-latency, always-on listening — separate from Whisper.

## Implementation Steps

### Phase 1: Project Setup & App Lifecycle

- [ ] **Step 1: Create SPM package and directory structure**
  - Files: `Package.swift`, `MacVoice/` directory tree
  - What: Initialize Swift package with macOS 14.0+ target. Create directory structure:
    ```
    MacVoice/
      App/           — App entry point, AppDelegate
      Audio/         — Recording, media control, beep
      Core/          — State machine, coordinator, permissions
      Input/         — Shortcuts, wake phrase, text insertion
      Transcription/ — Whisper integration
      UI/            — Menu bar, preferences
      Resources/     — Audio assets (beep sound), Info.plist
    ```
    Add dependencies: WhisperKit (SPM), HotKey or similar shortcut library.
  - Why: Foundation for all subsequent work.

- [ ] **Step 2: Create App entry point and AppDelegate**
  - Files: `MacVoice/App/MacVoiceApp.swift`, `MacVoice/App/AppDelegate.swift`
  - What: Create `@main` SwiftUI App struct that uses `NSApplicationDelegateAdaptor` to bridge to an `AppDelegate`. AppDelegate handles `applicationDidFinishLaunching`, sets up the menu bar status item, and kicks off permission checks. Set `LSUIElement = true` in Info.plist so the app has no dock icon.
  - Why: macOS menu bar apps require AppKit integration for NSStatusItem; SwiftUI App provides the lifecycle.

- [ ] **Step 3: Implement permission management**
  - Files: `MacVoice/Core/PermissionManager.swift`
  - What: Create a `PermissionManager` actor that checks and requests:
    - Accessibility: `AXIsProcessTrusted()` with options to prompt
    - Microphone: `AVCaptureDevice.requestAccess(for: .audio)`
    - Input Monitoring: Guide user to System Preferences (no programmatic API)
  - Expose permission status as published properties for UI binding.
  - Why: All three permissions are required. App must check at launch and before recording.

### Phase 2: Menu Bar UI & Preferences

- [ ] **Step 4: Create menu bar status item and dropdown**
  - Files: `MacVoice/UI/MenuBarController.swift`
  - What: Create `MenuBarController` that owns an `NSStatusItem`. Builds an `NSMenu` with items:
    - Status indicator (idle/listening/recording/transcribing)
    - "Start Recording" / "Stop Recording" toggle
    - Separator
    - "Preferences…" (opens preferences window)
    - "Quit Mac Speech to AI to Text"
  - Update the status item icon/title based on app state.
  - Why: Primary user interface per `docs/logic/menubar-ui.md`.

- [ ] **Step 5: Create preferences window**
  - Files: `MacVoice/UI/PreferencesView.swift`, `MacVoice/UI/PreferencesWindowController.swift`
  - What: SwiftUI view with sections:
    - **Shortcut:** Record/display the global activation shortcut
    - **Send Phrase:** Text field for the trigger phrase (default: "OK, send")
    - **Silence Threshold:** Slider for seconds (0.5–5.0, default 2.0)
    - **Whisper Model:** Picker for model size (tiny/base/small)
    - **Auto-Resume Media:** Toggle
    - **Permissions:** Status indicators with "Open System Preferences" buttons
  - Use `@AppStorage` for persistence. `PreferencesWindowController` manages an `NSWindow` hosting the SwiftUI view.
  - Why: Users need to configure app behavior per `docs/logic/menubar-ui.md`.

- [ ] **Step 6: Create Settings model**
  - Files: `MacVoice/Core/Settings.swift`
  - What: `@Observable` class wrapping `UserDefaults` via `@AppStorage` for all configurable values: shortcut key code, send phrase, silence threshold, model size, auto-resume media toggle. Provides defaults and validation.
  - Why: Central settings source shared across all components.

### Phase 3: Audio Pipeline

- [ ] **Step 7: Implement audio recorder with silence detection**
  - Files: `MacVoice/Audio/AudioRecorder.swift`
  - What: Actor-based `AudioRecorder` using `AVAudioEngine`:
    - Install a tap on the input node to capture audio buffers
    - Write buffers to a temporary WAV file for Whisper
    - Monitor RMS audio levels from buffers for silence detection
    - Expose `isRecording`, `currentAudioLevel` properties
    - Methods: `startRecording() async throws -> URL`, `stopRecording() -> URL`
    - Silence detection: track last time audio level exceeded threshold; fire delegate/callback when silence duration exceeds configured threshold
  - Why: Core audio capture per `docs/logic/audio.md`.

- [ ] **Step 8: Implement send phrase + silence detector**
  - Files: `MacVoice/Audio/SendPhraseDetector.swift`
  - What: Uses Apple Speech framework (`SFSpeechRecognizer`) to do live partial recognition on the recording audio stream. Watches for the configured send phrase in partial results. Once detected, starts a silence timer. If silence persists for the configured threshold, signals recording complete. If speech resumes, resets the timer.
  - Why: The send phrase is not an instant trigger — it requires silence validation per project spec.

- [ ] **Step 9: Implement media controller**
  - Files: `MacVoice/Audio/MediaController.swift`
  - What: `MediaController` that pauses system media playback before recording and optionally resumes after. Strategy: use `MRMediaRemoteCommandInfo` private API or fallback to sending a media play/pause key event via CGEvent. Track whether media was actually playing before pause to avoid resuming media that was already paused.
  - Why: Background audio must be silenced for clean capture per `docs/logic/audio.md`.

- [ ] **Step 10: Implement beep/audio signal player**
  - Files: `MacVoice/Audio/AudioSignalPlayer.swift`, `MacVoice/Resources/ready-beep.aiff`
  - What: Simple player using `AVAudioPlayer` or `NSSound` to play a short ready beep. Bundle a system-standard or custom beep sound. Methods: `playReadyBeep() async`.
  - Why: Audible signal that recording has started per `docs/logic/audio.md`.

### Phase 4: Input Handling

- [ ] **Step 11: Implement global shortcut manager**
  - Files: `MacVoice/Input/ShortcutManager.swift`
  - What: Register a global hotkey using HotKey library (or CGEvent tap for double-tap detection). Default: double-tap Control key. On trigger, notify the coordinator to start the recording pipeline. Support reconfiguring the shortcut from preferences.
  - Why: Primary activation method per `docs/logic/input.md`.

- [ ] **Step 12: Implement wake phrase listener**
  - Files: `MacVoice/Input/WakePhraseListener.swift`
  - What: Always-on listener using `SFSpeechRecognizer` with `SFSpeechAudioBufferRecognitionRequest` on a separate `AVAudioEngine` instance (or shared with careful routing). Listens for "okay, voice" in partial transcription results. On detection, notifies the coordinator to begin the recording pipeline. Must handle audio session interruptions and restart gracefully.
  - Why: Secondary hands-free activation per `docs/logic/input.md`.

- [ ] **Step 13: Implement text insertion and auto-submit**
  - Files: `MacVoice/Input/TextInserter.swift`
  - What: Uses Accessibility API (`AXUIElement`) to:
    1. At recording start: capture the focused element reference (`kAXFocusedUIElementAttribute` from system-wide element)
    2. At insertion time: re-focus the captured element, set its `kAXValueAttribute` to the transcribed text (or use clipboard paste via CGEvent Cmd+V as fallback)
    3. Simulate Enter key press via `CGEvent` to submit
  - Why: Text must go into the field that was active when recording started, then auto-submit per `docs/logic/input.md`.

### Phase 5: Transcription

- [ ] **Step 14: Integrate WhisperKit for local transcription**
  - Files: `MacVoice/Transcription/TranscriptionEngine.swift`
  - What: `TranscriptionEngine` actor that:
    - Loads the configured Whisper model at app launch (async, background)
    - Exposes `transcribe(audioFileURL: URL) async throws -> String`
    - Handles model download/caching (WhisperKit manages this)
    - Reports progress for UI status updates
  - Why: All transcription is local per `docs/logic/transcription.md`.

### Phase 6: Orchestration

- [ ] **Step 15: Create pipeline state machine**
  - Files: `MacVoice/Core/PipelineState.swift`
  - What: Define an enum-based state machine:
    ```swift
    enum PipelineState {
      case idle
      case preparingToRecord   // pausing media, playing beep
      case recording           // actively capturing audio
      case transcribing        // Whisper processing
      case inserting           // placing text + submitting
      case error(Error)
    }
    ```
    With valid transitions enforced. Observable for UI binding.
  - Why: Central state management per `docs/logic/core.md`.

- [ ] **Step 16: Create pipeline coordinator**
  - Files: `MacVoice/Core/PipelineCoordinator.swift`
  - What: `@Observable` class that orchestrates the full pipeline:
    1. Receive activation signal (from shortcut or wake phrase)
    2. Capture active text field reference
    3. Transition to `.preparingToRecord` → pause media → play beep
    4. Transition to `.recording` → start audio recorder + send phrase detector
    5. On send phrase + silence confirmed → stop recording → transition to `.transcribing`
    6. Send audio to `TranscriptionEngine` → get text
    7. Transition to `.inserting` → insert text → send Enter
    8. Transition to `.idle` → optionally resume media
    - Error handling at each stage with rollback to `.idle`
  - Why: Central coordinator tying all subsystems together per `docs/logic/core.md`.

### Phase 7: Integration & Polish

- [ ] **Step 17: Wire all components in AppDelegate**
  - Files: `MacVoice/App/AppDelegate.swift` (modify)
  - What: In `applicationDidFinishLaunching`:
    1. Initialize `Settings`
    2. Initialize `PermissionManager`, check permissions
    3. Initialize `PipelineCoordinator` with all dependencies
    4. Initialize `MenuBarController` bound to pipeline state
    5. Register global shortcut via `ShortcutManager`
    6. Start wake phrase listener (if permissions allow)
    7. Begin WhisperKit model loading in background
  - Why: Final assembly connecting all subsystems.

- [ ] **Step 18: Add OSLog logging throughout**
  - Files: All `MacVoice/` source files
  - What: Add structured logging using `os.Logger` with subsystem `"com.macvoice.app"` and per-module categories: `audio`, `input`, `transcription`, `ui`, `core`. Log state transitions, errors, and key events at appropriate levels (debug, info, error).
  - Why: Debugging and monitoring per project conventions.

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `Package.swift` | Create | SPM package manifest with targets and dependencies |
| `MacVoice/App/MacVoiceApp.swift` | Create | SwiftUI @main entry point |
| `MacVoice/App/AppDelegate.swift` | Create | NSApplicationDelegate, component wiring |
| `MacVoice/Core/PermissionManager.swift` | Create | Permission checking and requesting |
| `MacVoice/Core/Settings.swift` | Create | @Observable settings with @AppStorage |
| `MacVoice/Core/PipelineState.swift` | Create | Enum state machine for pipeline |
| `MacVoice/Core/PipelineCoordinator.swift` | Create | Central orchestrator |
| `MacVoice/Audio/AudioRecorder.swift` | Create | AVAudioEngine recording + silence detection |
| `MacVoice/Audio/SendPhraseDetector.swift` | Create | SFSpeechRecognizer send phrase + silence timer |
| `MacVoice/Audio/MediaController.swift` | Create | System media pause/resume |
| `MacVoice/Audio/AudioSignalPlayer.swift` | Create | Ready beep playback |
| `MacVoice/Resources/ready-beep.aiff` | Create | Beep audio asset |
| `MacVoice/Resources/Info.plist` | Create | LSUIElement, bundle ID, permissions descriptions |
| `MacVoice/UI/MenuBarController.swift` | Create | NSStatusItem + NSMenu |
| `MacVoice/UI/PreferencesView.swift` | Create | SwiftUI preferences window |
| `MacVoice/UI/PreferencesWindowController.swift` | Create | NSWindow host for SwiftUI prefs |
| `MacVoice/Input/ShortcutManager.swift` | Create | Global hotkey registration |
| `MacVoice/Input/WakePhraseListener.swift` | Create | Always-on "okay, voice" listener |
| `MacVoice/Input/TextInserter.swift` | Create | AXUIElement text insertion + Enter |
| `MacVoice/Transcription/TranscriptionEngine.swift` | Create | WhisperKit integration |
| `MacVoiceTests/` | Create | Test target with initial test files |

## Dependencies & Risks

- **WhisperKit availability:** Requires SPM-compatible WhisperKit package. If unavailable or broken, fallback to whisper.cpp Swift bindings.
- **Private APIs for media control:** `MRMediaRemote` is a private framework. May use simulated media key events instead to stay App Store–compatible.
- **Accessibility API reliability:** AXUIElement text insertion can be fragile across different apps. Clipboard-paste fallback (Cmd+V) is the safety net.
- **Wake phrase battery impact:** Always-on `SFSpeechRecognizer` may consume significant resources. May need an on/off toggle.
- **Double-tap shortcut detection:** Standard shortcut libraries don't support double-tap natively. May need custom CGEvent tap with timing logic.
- **macOS permissions UX:** Users must manually grant Accessibility and Input Monitoring. Onboarding flow needs to be clear.
- **Model size vs. speed tradeoff:** Larger Whisper models are more accurate but slower. Default to "tiny" for responsiveness.
- **Audio session conflicts:** Recording while wake phrase listener is active requires careful audio engine management to avoid conflicts.

## Testing Plan — BLOCKING (execute BEFORE docs or completion)

### Automated Checks
- [ ] `swift build` compiles without errors
- [ ] `swift test` passes all tests
- [ ] Unit tests for `PipelineState` transitions (valid and invalid)
- [ ] Unit tests for `Settings` defaults and validation
- [ ] Unit tests for `PermissionManager` status reporting

### Manual Verification

1. Build and run the app from Xcode
2. Verify menu bar icon appears (no dock icon)
3. Click menu bar icon → dropdown shows status, preferences, quit
4. Open preferences → verify all settings render and persist
5. Trigger global shortcut → verify media pauses, beep plays, recording starts
6. Speak and say send phrase → verify recording stops after silence
7. Verify transcribed text appears in a test text field
8. Verify Enter is simulated after insertion
9. Test wake phrase "okay, voice" triggers the same pipeline
10. Verify permission prompts appear on first use

### Regression Checks
- [ ] App launches without crash on clean install
- [ ] Menu bar persists after sleep/wake
- [ ] Preferences persist after app restart

### Edge Cases
- [ ] Send phrase spoken mid-sentence (should NOT trigger submit — silence required)
- [ ] No microphone permission → graceful error in menu
- [ ] No accessibility permission → text insertion fails gracefully
- [ ] Recording with no speech → empty transcription handled
- [ ] Multiple rapid shortcut triggers → only one recording session active
- [ ] Wake phrase spoken during active recording → ignored

**STOP: Do NOT proceed to docs or completion until ALL tests pass.**

## Rollback Plan

Since this is a greenfield project with no existing code, rollback is straightforward:
- Delete `Package.swift` and the `MacVoice/` directory
- Remove `MacVoiceTests/` if created
- The `docs/` structure remains untouched

## Post-Implementation Checklist

**Gate 1 — Code complete:**
- [ ] All 18 implementation steps complete

**Gate 2 — Testing (BLOCKING):**
- [ ] All automated checks passed
- [ ] All manual verification executed
- [ ] All regression checks executed

**Gate 3 — Documentation & logging (only after Gate 2):**
- [ ] `docs/logic/` files updated with implementation specifics (actual file paths, line numbers)
- [ ] Task logged in `docs/task/logs/2026-03-26.md`
- [ ] Agent observations logged

**Gate 4 — Close out:**
- [ ] Plan status → **Complete**
- [ ] Plan file moved from `draft/` to `completed/`
