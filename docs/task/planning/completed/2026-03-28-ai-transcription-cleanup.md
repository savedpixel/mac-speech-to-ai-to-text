# Plan: AI Transcription Cleanup + Recording Overlay + Full App UI

> **Status:** Complete
> **Created:** 2026-03-28
> **Estimated steps:** 20
> **Risk level:** High

## Context

When using speech-to-text for task creation, raw transcriptions contain filler words, repetitions, and messy grammar. The user needs:

1. **AI cleanup** — Post-processing via a lightweight cloud LLM to clean transcriptions while preserving meaning.
2. **Recording overlay** — A floating popup that shows a live audio waveform during recording, then shows transcribing/cleaning/success states with action buttons.
3. **Multiple cleanup prompts** — User-defined prompt templates that can be selected before or during use.
4. **Transcription history** — Browse all past recordings and their results.
5. **Full app UI** — Transition from menu-bar-only utility to a proper Dock app with a main window for history, prompts, and settings.

## Current State

**App structure** ([MacVoiceApp.swift](MacVoice/App/MacVoiceApp.swift) L1–L12): SwiftUI `@main` app with only an empty `Settings` scene. All logic lives in `AppDelegate` via `@NSApplicationDelegateAdaptor`. App runs as menu-bar-only (no Dock icon, no main window).

**Pipeline flow** ([PipelineCoordinator.swift](MacVoice/Core/PipelineCoordinator.swift) L127–L155):
1. Stop recording → transcribe via WhisperKit (local)
2. `removeSendPhrase(from:)` strips send phrase
3. `textInserter.insertTextAndSubmit(cleanText)` inserts result directly — no user review step

**Pipeline states** ([PipelineState.swift](MacVoice/Core/PipelineState.swift) L3–L9):
`idle → preparingToRecord → recording → transcribing → inserting → idle`

**Audio** ([AudioRecorder.swift](MacVoice/Audio/AudioRecorder.swift) L180–L200): Already computes real-time RMS level in `currentAudioLevel` (dB) and is `@Observable`. The waveform data source already exists.

**Menu bar** ([MenuBarController.swift](MacVoice/UI/MenuBarController.swift) L1–L140): NSStatusItem with state-based icon changes. No overlay/popup.

**Settings** ([Settings.swift](MacVoice/Core/Settings.swift)): `@Observable`, UserDefaults-backed. No API key, no prompt management, no history.

**Preferences** ([PreferencesView.swift](MacVoice/UI/PreferencesView.swift)): Two tabs (General, Permissions). Basic settings only.

**No cloud/network features exist. No data persistence beyond UserDefaults. No main window.**

## Target State

### A. AI Cleanup Pipeline
1. `TranscriptionCleaner` service — sends text to OpenAI API for cleanup
2. New `.cleaning` pipeline state between `.transcribing` and new `.completed` state
3. Settings: API key (Keychain), endpoint URL, model name
4. On failure: show raw transcription with a small warning badge indicating AI cleanup failed

### B. Recording Overlay Window
1. Floating panel appears **centered on screen** when recording starts
2. **System material** styling (adapts to light/dark mode)
3. **Recording state**: Live audio waveform visualization + "Listening…" + Cancel
4. **Transcribing state**: Spinner + "Transcribing…"
5. **Cleaning state**: Spinner + "Cleaning up via AI…"
6. **Completed state**: Shows final text + "Copy" / "Insert" / "Dismiss" buttons. **Stays indefinitely** until user acts (no auto-dismiss)
7. Insert action uses the **cursor position captured at recording start** (existing TextInserter behavior)
8. User can cancel at any stage via overlay button or shortcut

### C. Cleanup Prompts
1. `CleanupPrompt` model — id, name, system prompt text, isBuiltIn flag
2. Persisted via JSON file in Application Support
3. One built-in default prompt, user can add/edit/delete custom prompts in Settings
4. **Default prompt always used** — set in Settings, no per-recording picker

### D. Transcription History with Folder Management
1. `TranscriptionRecord` model — id, date, raw text, cleaned text, prompt used, audio file ref, folderID, isArchived
2. `HistoryFolder` model — id, name, color/icon, createdDate
3. Persisted via JSON in Application Support
4. **Browseable list** — select, multi-select, search/filter
5. **Folder system** — create folders for different projects, move records between folders
6. **Archive** — archive records (hidden from default view, visible in "Archived" section)
7. **Batch operations** — select multiple → delete, move to folder, archive
8. Audio files pruned at configurable limit (default 50); text records kept until user deletes

### E. Full App with Dock Presence
1. App activates in Dock (set `LSUIElement` to `NO` or use activation policy `.regular`)
2. **Main window opens automatically on launch**
3. Sidebar navigation: History (with folders), Prompts, Settings
4. Menu bar icon remains for quick access
5. App can be both in Dock and menu bar simultaneously

## Assumptions

1. **OpenAI API** — user provided API key. Default model: `gpt-4o-mini`, endpoint: `https://api.openai.com/v1/chat/completions`. Key stored in Keychain during implementation.
2. **API key in macOS Keychain** — Security framework, no extra dependency. Key was provided by user and will be stored securely (never in plaintext files).
3. **15-second API timeout** — on failure, show raw transcription with warning badge.
4. **No new SPM dependencies** — URLSession for API, SwiftUI for all new UI.
5. **Application Support directory** for history, prompts, folders JSON storage (`~/Library/Application Support/MacVoice/`).
6. **Overlay**: NSPanel, non-activating, centered on screen, system material styling, stays until user acts.
7. **Audio files pruned at 50** — text records kept until user explicitly deletes. Folders and archive are user-managed.
8. **Pipeline no longer auto-inserts** — transitions to `.completed`, overlay shows result. User chooses Copy/Insert/Dismiss.
9. **Default cleanup prompt always used** — no per-recording prompt picker. User selects default in Settings.
10. **Existing menu-bar behavior preserved** — the Dock icon is additive.
11. **Main window opens automatically on app launch.**
12. **Insert uses original cursor position** — captured at recording start, per existing TextInserter behavior.

## Implementation Steps

### Phase 1: Core Infrastructure (Steps 1–4)

- [ ] **Step 1: Add Keychain helper for API key storage**
  - Files: `MacVoice/Core/KeychainHelper.swift` (new)
  - What: Create a minimal Keychain wrapper with `save(key:value:)`, `read(key:)`, and `delete(key:)` using the Security framework. Service name: `"com.macvoice.app"`.
  - Why: API keys must not be stored in UserDefaults.

- [ ] **Step 2: Create data models for prompts, history, and folders**
  - Files: `MacVoice/Core/CleanupPrompt.swift` (new), `MacVoice/Core/TranscriptionRecord.swift` (new), `MacVoice/Core/HistoryFolder.swift` (new)
  - What:
    - `CleanupPrompt`: `Codable` struct with `id: UUID`, `name: String`, `systemPrompt: String`, `isBuiltIn: Bool`. Include a static `default` that contains the standard cleanup instructions.
    - `TranscriptionRecord`: `Codable` struct with `id: UUID`, `date: Date`, `rawText: String`, `cleanedText: String?`, `promptUsed: String?`, `audioFileName: String?`, `folderID: UUID?` (nil = unfiled), `isArchived: Bool` (default false).
    - `HistoryFolder`: `Codable` struct with `id: UUID`, `name: String`, `colorName: String?`, `createdDate: Date`.
  - Why: Foundation models needed before persistence or UI layers. Folder + archive fields enable project-based organization.

- [ ] **Step 3: Create persistence managers**
  - Files: `MacVoice/Core/PromptStore.swift` (new), `MacVoice/Core/HistoryStore.swift` (new)
  - What:
    - `PromptStore`: `@Observable` class. Loads/saves `[CleanupPrompt]` from `~/Library/Application Support/MacVoice/prompts.json`. CRUD operations. Seeds default prompt on first run. Tracks `selectedPromptID`.
    - `HistoryStore`: `@Observable` class. Manages:
      - **Records**: `[TranscriptionRecord]` from `history.json`. Add/delete/list/search.
      - **Folders**: `[HistoryFolder]` from `folders.json`. Create/rename/delete folders.
      - **Move**: `moveRecords(_:toFolder:)` — move one or more records to a folder (or nil for unfiled).
      - **Archive**: `archiveRecords(_:)`, `unarchiveRecords(_:)` — toggle `isArchived`.
      - **Batch delete**: `deleteRecords(_:)` — delete multiple records + their audio files.
      - **Audio pruning**: Auto-prune audio files beyond configured limit (default 50). Stores audio copies in `~/Library/Application Support/MacVoice/recordings/`.
      - **Filtered views**: Computed properties for `unfiledRecords`, `archivedRecords`, `records(inFolder:)`.
  - Why: JSON file persistence with full folder/archive/batch support.

- [ ] **Step 4: Add AI cleanup + prompt settings to `Settings.swift`**
  - Files: `MacVoice/Core/Settings.swift`
  - What: Add after `wakePhraseEnabled` block (~L88):
    - `aiCleanupEnabled: Bool` (default: `false`)
    - `aiCleanupModel: String` (default: `"gpt-4o-mini"`)
    - `aiCleanupEndpoint: String` (default: `"https://api.openai.com/v1/chat/completions"`)
    - Computed `aiCleanupAPIKey: String` via `KeychainHelper`
    - `maxHistoryRecordings: Int` (default: `50`)
    - Add corresponding `Key` constants
  - Why: Centralize configuration.

### Phase 2: AI Cleanup Service (Steps 5–6)

- [ ] **Step 5: Create `TranscriptionCleaner` service**
  - Files: `MacVoice/Transcription/TranscriptionCleaner.swift` (new)
  - What: Actor-isolated service:
    - `init(settings: Settings, promptStore: PromptStore)`
    - `func clean(_ text: String) async throws -> String` — calls OpenAI-compatible chat completions API using the currently selected prompt from `PromptStore`
    - Uses `URLSession` with 15-second timeout
    - Parses standard OpenAI JSON response
    - Error enum: `CleanerError { case disabled, noAPIKey, networkError(Error), invalidResponse, timeout }`
  - Why: Isolated service for thread safety plus prompt store integration.

- [ ] **Step 6: Update pipeline states and coordinator**
  - Files: `MacVoice/Core/PipelineState.swift`, `MacVoice/Core/PipelineCoordinator.swift`
  - What:
    - **PipelineState**: Add `.cleaning` case and `.completed(TranscriptionResult)` case (where `TranscriptionResult` holds rawText, cleanedText, error info). Update `==`, `displayName`, `canTransition`. Remove `.inserting` state (replaced by `.completed` — user decides action). Transitions: `transcribing → cleaning → completed`, `transcribing → completed` (if cleanup disabled), `completed → idle`.
    - **PipelineCoordinator**: Add `transcriptionCleaner: TranscriptionCleaner`, `historyStore: HistoryStore` properties + init params. In `finalizePipeline()` (L127–L155): after transcription + send phrase removal, optionally run cleanup, then transition to `.completed(result)` instead of `.inserting`. Add new public methods: `copyResult()` (copies to clipboard), `insertResult()` (uses TextInserter), `dismiss()` (transitions to idle). Save `TranscriptionRecord` to `HistoryStore` on completion.
  - Why: Pipeline no longer auto-inserts — it presents the result for user action via the overlay.

### Phase 3: Recording Overlay (Steps 7–10)

- [ ] **Step 7: Create `AudioWaveformView` SwiftUI component**
  - Files: `MacVoice/UI/AudioWaveformView.swift` (new)
  - What: SwiftUI view that takes `audioLevel: Float` (the existing `currentAudioLevel` from `AudioRecorder`) and renders an animated waveform/bar visualization. Use a rolling buffer of ~40 recent levels rendered as vertical bars with smooth animation. Update via `TimelineView` or `withAnimation` on level changes.
  - Why: Provides visual feedback that recording is active and capturing audio.

- [ ] **Step 8: Create `RecordingOverlayView` SwiftUI view**
  - Files: `MacVoice/UI/RecordingOverlayView.swift` (new)
  - What: Single SwiftUI view that observes `PipelineCoordinator` and `AudioRecorder` state. Renders different content based on pipeline state:
    - **`.recording`**: `AudioWaveformView` + "Listening…" label + Cancel button
    - **`.transcribing`**: `ProgressView()` spinner + "Transcribing…" label
    - **`.cleaning`**: `ProgressView()` spinner + "Cleaning up via AI…" label
    - **`.completed(result)`**: Shows cleaned (or raw) text in a scrollable `Text` view + "Copy" button + "Insert" button + "Dismiss" button. If cleanup failed, show small warning badge next to raw text. **No auto-dismiss — overlay stays until user acts.**
    - **`.error`**: Error message + Dismiss button
    - Compact design: ~300×200pt, rounded corners, **system material** background (`.ultraThinMaterial`)
  - Why: This is the primary user-facing feedback for the entire recording → result flow.

- [ ] **Step 9: Create `RecordingOverlayPanel` (NSPanel wrapper)**
  - Files: `MacVoice/UI/RecordingOverlayPanel.swift` (new)
  - What: `NSPanel` subclass (or wrapper class) configured as:
    - `.floating` level (above other windows)
    - Non-activating (`NSPanel.StyleMask.nonactivatingPanel`) so it doesn't steal focus
    - `.fullSizeContentView`, `.borderless` with rounded corners
    - **Positioned: centered on screen** (both horizontally and vertically)
    - Hosts `RecordingOverlayView` via `NSHostingView`
    - Public API: `show()`, `dismiss()` with fade animation
    - **No auto-dismiss** — stays visible until user interacts
  - Why: NSPanel is the correct AppKit primitive for non-activating floating overlays.

- [ ] **Step 10: Wire overlay into pipeline lifecycle**
  - Files: `MacVoice/Core/PipelineCoordinator.swift`, `MacVoice/App/AppDelegate.swift`
  - What:
    - `AppDelegate`: Create and hold `RecordingOverlayPanel`. Pass `PipelineCoordinator` and `AudioRecorder` as observed objects.
    - `PipelineCoordinator`: Call `overlayPanel.show()` on `activate()` (entering `.preparingToRecord`). Call `overlayPanel.dismiss()` only when user clicks Dismiss/Copy/Insert (no auto-dismiss). The overlay's buttons call back to coordinator's `copyResult()`, `insertResult()`, `dismiss()`.
  - Why: The overlay's lifecycle is tied to the pipeline — it appears on activation and disappears only on user action.

### Phase 4: Full App UI (Steps 11–16)

- [ ] **Step 11: Enable Dock presence**
  - Files: `MacVoice/Info.plist`, `MacVoice/App/MacVoiceApp.swift`
  - What:
    - `Info.plist`: Set `LSUIElement` to `NO` (or remove it) so the app appears in the Dock.
    - `MacVoiceApp.swift`: Add a `WindowGroup` scene for the main app window alongside the existing `Settings` scene. Use `Window("Mac Speech to AI to Text", id: "main")` for a single-instance window.
  - Why: Transitioning from menu-bar-only to a full Dock app.

- [ ] **Step 12: Create main app window with sidebar navigation**
  - Files: `MacVoice/UI/MainWindowView.swift` (new)
  - What: SwiftUI `NavigationSplitView` with sidebar containing:
    - **History** (list icon)
    - **Prompts** (text.quote icon)
    - **Settings** (gear icon)
    With `@State private var selectedTab` and detail views that swap based on selection. Pass `HistoryStore`, `PromptStore`, `Settings`, `PermissionManager` as environment/bindings.
  - Why: Standard macOS sidebar-driven app layout.

- [ ] **Step 13: Create `HistoryListView`, `HistoryDetailView`, and folder management UI**
  - Files: `MacVoice/UI/HistoryListView.swift` (new), `MacVoice/UI/HistoryDetailView.swift` (new), `MacVoice/UI/HistoryFolderSidebar.swift` (new)
  - What:
    - **`HistoryFolderSidebar`**: Left sidebar in NavigationSplitView. Sections:
      - **All** (shows everything unarchived)
      - **Unfiled** (records with `folderID == nil`, not archived)
      - **Folders** (user-created folders). Context menu: rename, delete. "New Folder" button at bottom.
      - **Archive** (shows all `isArchived == true` records)
    - **`HistoryListView`**: Center pane. Lists `TranscriptionRecord`s for the selected sidebar item, sorted by date descending. Each row: date, preview of cleaned text (truncated), prompt name. Search/filter bar. **Multi-select** with Shift/Cmd-click. Toolbar batch actions on selection:
      - Move to Folder (picker)
      - Archive / Unarchive
      - Delete (with confirmation)
    - Context menu on each row: Copy cleaned text, Move to Folder, Archive, Delete.
    - **`HistoryDetailView`**: Right pane. Shows full raw text, cleaned text (if available), date, prompt used. "Copy Raw" and "Copy Cleaned" buttons. "Delete" button. "Move to Folder" picker. "Archive" toggle.
  - Why: Full folder-based history management with archive support and batch operations for project organization.

- [ ] **Step 14: Create `PromptListView` and `PromptEditorView`**
  - Files: `MacVoice/UI/PromptListView.swift` (new), `MacVoice/UI/PromptEditorView.swift` (new)
  - What:
    - `PromptListView`: Lists all `CleanupPrompt`s from `PromptStore`. Shows name, preview. "Add", "Delete" toolbar actions. Radio/checkmark to select the active prompt. Built-in prompt is not deletable.
    - `PromptEditorView`: Edit `name` and `systemPrompt` fields. Full-height `TextEditor` for the prompt body. "Save" / "Cancel". Built-in prompt's `systemPrompt` is read-only but can be duplicated.
  - Why: User-defined prompt templates for different cleanup styles.

- [ ] **Step 15: Migrate `PreferencesView` into main window's Settings tab**
  - Files: `MacVoice/UI/PreferencesView.swift` (modify), `MacVoice/UI/MainWindowView.swift` (modify)
  - What:
    - Refactor `PreferencesView` to work as a standalone view (remove `TabView` wrapper).
    - Add AI Cleanup section: Toggle, SecureField for API Key, TextField for Model, TextField for Endpoint. Show fields conditionally when enabled.
    - Embed in the Settings tab of `MainWindowView`.
    - The old `PreferencesWindowController` still works from the menu bar (opens main window to Settings tab).
  - Why: Settings now live in the main window but remain accessible from the menu bar.

- [ ] **Step 16: Update `MenuBarController` to open main window**
  - Files: `MacVoice/UI/MenuBarController.swift`
  - What: Update "Preferences…" menu action to open the main app window's Settings tab (via `NSApp.activate()` + window management) instead of a standalone preferences window. Add "Show Mac Speech to AI to Text" menu item that opens the main window.
  - Why: Menu bar now acts as a quick-access companion to the full app.

### Phase 5: Wiring & Polish (Steps 17–19)

- [ ] **Step 17: Update `AppDelegate` composition root**
  - Files: `MacVoice/App/AppDelegate.swift`
  - What: Instantiate all new services: `KeychainHelper` (static), `PromptStore`, `HistoryStore`, `TranscriptionCleaner(settings:promptStore:)`. Pass to `PipelineCoordinator`. Create `RecordingOverlayPanel`. Wire overlay show/dismiss to pipeline state changes. Make stores accessible to SwiftUI views (via `@Environment` or direct binding through `MacVoiceApp`).
  - Why: Composition root must wire all new components.

- [ ] **Step 18: Update `MacVoiceApp` scene definition**
  - Files: `MacVoice/App/MacVoiceApp.swift`
  - What: Replace `EmptyView()` Settings scene with a `Window` scene hosting `MainWindowView`. Pass stores from `AppDelegate` into the view hierarchy. Configure window size/behavior (min size ~700×500, resizable).
  - Why: The app entry point must declare the new window scene.

- [ ] **Step 19: Update `MenuBarController` icon for `.cleaning` and `.completed` states**
  - Files: `MacVoice/UI/MenuBarController.swift`
  - What: Add cases in `updateIcon()` (~L52–L67):
    - `.cleaning` → `"sparkles"` (or `"brain"`)
    - `.completed` → `"checkmark.circle"`
  - Why: Menu bar icon should reflect all pipeline states.

### Phase 6: Documentation (Step 20)

- [ ] **Step 20: Update documentation**
  - Files: `docs/logic/transcription.md`, `docs/logic/core.md`, `docs/logic/menubar-ui.md`
  - What:
    - `transcription.md`: Add "Post-Processing: AI Cleanup" section — TranscriptionCleaner, prompt system, fallback behavior
    - `core.md`: Update pipeline state diagram (add `.cleaning`, `.completed`, remove `.inserting`). Document new data stores (prompts, history). Document Dock activation.
    - `menubar-ui.md`: Document recording overlay panel, main window layout, updated menu bar behavior
  - Why: Doc-sync rules.

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `MacVoice/Core/KeychainHelper.swift` | Create | Secure API key storage |
| `MacVoice/Core/CleanupPrompt.swift` | Create | Prompt data model |
| `MacVoice/Core/TranscriptionRecord.swift` | Create | History record data model (with folderID, isArchived) |
| `MacVoice/Core/HistoryFolder.swift` | Create | Folder data model for project grouping |
| `MacVoice/Core/PromptStore.swift` | Create | Prompt CRUD + persistence |
| `MacVoice/Core/HistoryStore.swift` | Create | History persistence + audio pruning + folder CRUD + archive + batch ops |
| `MacVoice/Core/Settings.swift` | Modify | Add AI cleanup + history settings |
| `MacVoice/Transcription/TranscriptionCleaner.swift` | Create | OpenAI-compatible cleanup API client |
| `MacVoice/Core/PipelineState.swift` | Modify | Add `.cleaning`, `.completed`, remove `.inserting` |
| `MacVoice/Core/PipelineCoordinator.swift` | Modify | Integrate cleaner, history, overlay lifecycle, user-action methods |
| `MacVoice/UI/AudioWaveformView.swift` | Create | Live waveform visualization |
| `MacVoice/UI/RecordingOverlayView.swift` | Create | Multi-state overlay content |
| `MacVoice/UI/RecordingOverlayPanel.swift` | Create | Non-activating floating panel |
| `MacVoice/UI/MainWindowView.swift` | Create | Sidebar-driven main window |
| `MacVoice/UI/HistoryListView.swift` | Create | Transcription history browser with multi-select + batch actions |
| `MacVoice/UI/HistoryDetailView.swift` | Create | Single record detail + folder/archive controls |
| `MacVoice/UI/HistoryFolderSidebar.swift` | Create | Folder sidebar (All, Unfiled, Folders, Archive) |
| `MacVoice/UI/PromptListView.swift` | Create | Prompt management list |
| `MacVoice/UI/PromptEditorView.swift` | Create | Prompt editor |
| `MacVoice/UI/PreferencesView.swift` | Modify | Add AI Cleanup section, refactor for embedding |
| `MacVoice/UI/MenuBarController.swift` | Modify | New states, open main window |
| `MacVoice/App/AppDelegate.swift` | Modify | Wire new services + overlay |
| `MacVoice/App/MacVoiceApp.swift` | Modify | Add Window scene |
| `MacVoice/Info.plist` | Modify | Dock presence (`LSUIElement`) |
| `docs/logic/transcription.md` | Modify | AI cleanup docs |
| `docs/logic/core.md` | Modify | Updated state diagram + data stores |
| `docs/logic/menubar-ui.md` | Modify | Overlay + main window docs |

## Dependencies & Risks

- **Scope increase** — This is a significant expansion from a menu-bar utility to a full app. Risk of scope creep. Mitigated by phased implementation — each phase is independently testable.
- **NSPanel focus behavior** — The overlay must NOT steal focus from the active text field. If NSPanel non-activating mode doesn't work perfectly, the Insert button may fail. Mitigated by: testing with multiple app contexts (VS Code, Safari, Terminal).
- **Network dependency** — First cloud feature. Mitigated by: off by default, graceful fallback.
- **API key security** — Keychain storage. API key never logged.
- **Data persistence** — JSON files can corrupt. Mitigated by: atomic writes, backup on load failure.
- **Dock activation** — Changing `LSUIElement` means the app shows in Cmd+Tab. Some users may not want this. Could add a toggle later.
- **Pipeline behavior change** — Removing auto-insert (`.inserting`) changes the existing UX. The user now must interact with the overlay. Mitigated by: this matches the user's explicit request.
- **Privacy** — Transcription text sent to third-party API. User opts in. Local Ollama supported.

## Testing Plan — BLOCKING (agent-executed, production-ready delivery)

> **All testing is performed by the agent.** The user receives a tested, production-ready build. The agent has full access to the Mac environment: terminal, Xcode build tools, app launching, screenshot capture, and accessibility APIs. No test step may be deferred to the user.

### Testing Methodology

The agent will execute all verification using these capabilities:
- **Build verification**: `swift build` and `swift test` via terminal
- **App launch**: Run the built app via `open` command or direct binary execution
- **UI verification**: Take screenshots of the running app to verify visual correctness of overlay, main window, preferences, and all states
- **Interaction testing**: Use accessibility APIs / AppleScript / `osascript` to simulate clicks, keyboard shortcuts, and text input where feasible
- **Network testing**: Use `curl` or mock server to verify API integration behavior
- **File system verification**: Inspect Application Support directory for correct JSON persistence, Keychain entries via `security` CLI
- **State machine testing**: Unit tests + integration tests that exercise every pipeline transition

### Phase-by-Phase Verification (agent-executed after each phase)

**After Phase 1 (Core Infrastructure):**
- [ ] `swift build` compiles without errors
- [ ] `swift test` passes — unit tests for KeychainHelper, CleanupPrompt, TranscriptionRecord, HistoryFolder, PromptStore, HistoryStore
- [ ] Verify `~/Library/Application Support/MacVoice/` directory auto-creates
- [ ] Verify `prompts.json` seeds with default prompt
- [ ] Verify `history.json` CRUD and prune operations
- [ ] Verify folder CRUD (create/rename/delete folders in `folders.json`)
- [ ] Verify move-to-folder, archive/unarchive, batch delete operations
- [ ] Verify Keychain save/read/delete via `security` CLI cross-check

**After Phase 2 (AI Cleanup Service):**
- [ ] `swift build` compiles
- [ ] `swift test` passes — unit tests for TranscriptionCleaner mock response parsing, error fallback, timeout behavior
- [ ] Unit test: PipelineState transitions for `.cleaning`, `.completed`, removal of `.inserting`
- [ ] Integration test: Pipeline coordinator runs through full flow with mock/stubbed cleaner

**After Phase 3 (Recording Overlay):**
- [ ] `swift build` compiles
- [ ] Launch app → take screenshot: verify overlay appears when shortcut is triggered
- [ ] Take screenshot: overlay in recording state (waveform visible)
- [ ] Take screenshot: overlay in transcribing state (spinner visible)
- [ ] Take screenshot: overlay in cleaning state (spinner + "Cleaning up via AI…")
- [ ] Take screenshot: overlay in completed state (text + Copy/Insert/Dismiss buttons)
- [ ] Verify overlay is NSPanel non-activating — launch TextEdit, trigger shortcut, confirm TextEdit stays focused (test via AppleScript `frontmost` check)
- [ ] Test Cancel button dismisses overlay and resets pipeline to idle
- [ ] Test Copy button puts text in clipboard (verify via `pbpaste`)
- [ ] Test Dismiss button closes overlay

**After Phase 4 (Full App UI):**
- [ ] `swift build` compiles
- [ ] Launch app → take screenshot: verify Dock icon appears
- [ ] Take screenshot: main window with sidebar (History, Prompts, Settings)
- [ ] Take screenshot: History tab with folder sidebar (All, Unfiled, Folders, Archive sections)
- [ ] Create a folder, move records into it, verify sidebar updates
- [ ] Archive a record, verify it appears in Archive section
- [ ] Multi-select records → batch delete with confirmation
- [ ] Take screenshot: Prompts tab (default prompt visible)
- [ ] Take screenshot: Settings tab (AI Cleanup section visible)
- [ ] Add a custom prompt via UI → verify it persists in `prompts.json`
- [ ] Verify menu bar "Show Mac Speech to AI to Text" opens main window

**After Phase 5 (Wiring & Polish):**
- [ ] `swift build` compiles
- [ ] `swift test` passes all tests
- [ ] Full end-to-end flow: trigger shortcut → overlay appears → speak → send phrase → transcribe → clean → completed → copy → verify clipboard
- [ ] Verify history record saved after completion
- [ ] Verify menu bar icons update for all states (`.cleaning` → sparkles, `.completed` → checkmark)

### Automated Unit Tests (agent writes and runs)
- [ ] `KeychainHelper`: save/read/delete cycle, overwrite existing key, read nonexistent key returns nil
- [ ] `CleanupPrompt`: Codable roundtrip, static default has correct fields
- [ ] `TranscriptionRecord`: Codable roundtrip with nil optional fields
- [ ] `PromptStore`: CRUD, persistence to disk, default seeding, selectedPromptID
- [ ] `HistoryStore`: add/delete/list, prune beyond limit, audio file cleanup, folder CRUD, move-to-folder, archive/unarchive, batch delete, filtered views (unfiled, archived, byFolder)
- [ ] `HistoryFolder`: Codable roundtrip, creation with defaults
- [ ] `TranscriptionCleaner`: parse valid API response, handle malformed JSON, handle network error, handle timeout, handle empty API key
- [ ] `PipelineState`: all new transitions valid, old `.inserting` transitions removed, `.completed` equality

### Edge Case Testing (agent-executed)
- [ ] Empty transcription after send phrase removal → overlay shows empty completed state (screenshot)
- [ ] Very long transcription (simulate 1000+ word text) → overlay scrolls correctly (screenshot)
- [ ] API timeout → set API endpoint to non-routable IP, verify fallback within 15s (timed via terminal)
- [ ] No API key + cleanup enabled → verify warning log in Console + raw text used
- [ ] Invalid API key → verify graceful fallback (test with dummy key against real endpoint)
- [ ] Overlay dismiss during transcribing → verify pipeline cancels, state returns to idle
- [ ] Multiple rapid shortcut presses → verify guard in `activate()` prevents double pipeline
- [ ] Application Support directory deleted → verify auto-recreated on next operation
- [ ] Corrupt JSON file (write garbage to `prompts.json`) → verify graceful fallback to empty/default state
- [ ] Concurrent prompt store writes → verify no data corruption (actor isolation)

### Regression Tests (agent-executed)
- [ ] Normal transcription flow with AI cleanup disabled → raw text in completed overlay
- [ ] Send phrase detection still triggers pipeline finalization
- [ ] Media pause/resume still works (verify via `MediaController` logs)
- [ ] Wake phrase activation still works (if testable — may need mic input simulation)
- [ ] Global shortcut still works (verify via HotKey trigger)
- [ ] Menu bar icon reflects all pipeline states correctly

### Delivery Criteria
- [ ] All automated tests pass (`swift test` green)
- [ ] All screenshots captured and reviewed (no visual bugs)
- [ ] All edge cases tested with evidence (logs, clipboard content, file contents)
- [ ] Zero compiler warnings (or only pre-existing ones documented)
- [ ] App launches cleanly from cold start
- [ ] App handles restart gracefully (persisted data loads correctly)

**STOP: Do NOT proceed to docs or completion until ALL tests pass. The agent must have evidence for every checkbox.**

## Questions for User — RESOLVED

> All questions answered. Decisions incorporated into the plan above.

1. **Overlay position** → **(a) Centered on screen**
2. **Overlay auto-dismiss** → **(a) Stay until user acts** (no auto-dismiss)
3. **Insert behavior** → **(a) Insert at original cursor position** (captured when recording started)
4. **Main window on launch** → **(a) Open automatically**
5. **Overlay styling** → **(b) System material** (`.ultraThinMaterial`, adapts light/dark)
6. **Prompt selection** → **(a) Default from settings**, always used
7. **Default prompt** → **Approved as-is**
8. **API key** → **Provided by user** (stored in Keychain only). Use OpenAI directly, no Ollama fallback needed.
9. **Fallback behavior** → **(b) Show raw text + warning badge** when AI cleanup fails
10. **History retention** → **User-managed with folders, archive, and batch delete**. Text records kept until user deletes. Audio files pruned at limit. Users can browse, multi-select, delete, archive, and organize into folders for project grouping.
11. **Phase priority** → **(a) All phases at once**

## Rollback Plan

1. Phase-based: each phase can be reverted independently
2. Full rollback: revert all commits (feature is additive)
3. Restore `.inserting` state if `.completed` interaction model is rejected
4. Remove `LSUIElement` change to revert to menu-bar-only
5. Delete Application Support data directory if needed

## Post-Implementation Checklist

**Gate 1 — Code complete:**
- [ ] All 20 implementation steps complete

**Gate 2 — Agent Testing (BLOCKING — agent executes all tests):**
- [ ] All automated unit tests pass (`swift test`)
- [ ] All phase-by-phase verification completed with screenshots
- [ ] All edge cases tested with evidence (logs, file contents, clipboard)
- [ ] All regression tests pass
- [ ] Delivery criteria met (zero warnings, clean launch, persistence works)

**Gate 3 — User Delivery:**
- [ ] Agent presents: summary of changes, test evidence (screenshots, test output), known limitations
- [ ] User performs final acceptance (optional — product is already tested)

**Gate 4 — Documentation & logging (only after Gate 2):**
- [ ] Documentation updated (`transcription.md`, `core.md`, `menubar-ui.md`)
- [ ] Task logged in `docs/task/logs/2026-03-28.md`
- [ ] Observations logged

**Gate 5 — Close out:**
- [ ] Plan status → **Complete**
- [ ] Plan file moved from `draft/` to `completed/`
