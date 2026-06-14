# Plan: Multi-Shortcut Prompts, Insert Phrase, Copy Behavior, UI Polish & Whisper Model Fix

> **Status:** Complete
> **Created:** 2026-03-29
> **Estimated steps:** 13
> **Risk level:** Medium

---

## Context

Four improvements requested by the user:

1. **Multi-shortcut prompt mappings** — Multiple keyboard shortcuts, each tied to a different AI cleanup prompt. Currently there is one global shortcut wired to a single `activate()` call with whatever prompt is selected in PromptStore.
2. **Insert phrase** — A configurable voice phrase (default: "Insert") that, while the completed overlay is visible, triggers `insertResult()` without clicking. (Analogous to the send phrase but fires during the *completed* state, not the *recording* state.)
3. **Copy overlay behavior** — Option to keep the overlay open when the user clicks Copy (currently always dismisses). Configurable: close immediately, keep open, or auto-dismiss after N seconds.
4. **Fix completed icon** — The overlay shows a danger triangle (`exclamationmark.triangle.fill`) when AI cleanup fails while the heading reads "Complete". User finds this confusing — successful completion should always look clean; failures should be communicated without a danger badge on the "Complete" header.
5. **Fix Whisper model not loading on relaunch** — After closing and reopening the app, transcription fails with "model not loaded" and a Hub lookup error: `modelsUnavailable("No models found matching \"openai/openai_whisper-large-v3-turbo/\"")`. Root cause: `loadModel()` passes `model: "openai_whisper-\(modelName)"` to `WhisperKitConfig`; WhisperKit parses the `openai_` prefix as an org name and constructs a Hub filter `"openai/openai_whisper-large-v3-turbo/"` which doesn't exist in `argmaxinc/whisperkit-coreml`. The model is already downloaded locally at `openai_whisper-large-v3_turbo/` (underscore) but this path is never used.

---

## Current State

### Shortcut system
- `Settings.swift` stores a single shortcut: `shortcutKeyCode: UInt16` + `shortcutModifiers: UInt`
- `ShortcutManager.swift` registers one `HotKey` from `HotKey` package, calls `onActivate: () -> Void`
- `PipelineCoordinator.activate()` takes no parameters — uses `promptStore.selectedPromptID` globally

### Overlay on Copy
- `PipelineCoordinator.copyResult()` (line ~235): copies to pasteboard then calls `dismiss()` unconditionally

### Completed state icon
- `RecordingOverlayView.completedContent()` (~line 140): shows `exclamationmark.triangle.fill` (yellow) when `result.cleanupFailed == true`, displayed inline with "Complete" text
- User has AI cleanup enabled but likely misconfigured, so `cleanupFailed` is frequently true

### Insert phrase
- No voice trigger exists for the completed overlay state. The only voice triggers are: wake phrase (starts recording) and send phrase (ends recording).
- `SendPhraseDetector` pattern reusable: buffers mic input through `SFSpeechAudioBufferRecognitionRequest`

### Whisper model loading on relaunch
- `TranscriptionEngine.loadModel()` (~line 115): builds `WhisperKitConfig(model: "openai_whisper-\(modelName)")` — e.g. `"openai_whisper-large-v3-turbo"`
- WhisperKit parses `openai_` as an org, constructs Hub filter `"openai/openai_whisper-large-v3-turbo/"` → not found in `argmaxinc/whisperkit-coreml`
- `scanDownloadedModels()` strips `openai_whisper-` from folder names; folder on disk is `openai_whisper-large-v3_turbo` (underscore) → stored as `large-v3_turbo`
- `Settings.init()` migration converts `large-v3_turbo` → `large-v3-turbo` (hyphen), so disk name (underscore) no longer matches stored setting (hyphen)
- Net result: model is on disk but never loaded from there; Hub lookup fails

---

## Target State

1. **Multi-shortcut**: User can define N shortcut bindings in settings. Each binding has a key combo + an optional prompt override. Pressing a shortcut activates the pipeline with that specific prompt (overriding the global selected prompt for that session).
2. **Insert phrase**: A `InsertPhraseListener` runs only while the overlay is in `.completed` state, listening for the configurable insert phrase. When heard, it calls `insertResult()`.
3. **Copy behavior**: New settings `keepOverlayOpenOnCopy: Bool` (default `false`) and `copyAutoDismissDelay: Int` (seconds, 0 = never, default 0). When keep-open is true, Copy does not dismiss; if auto-dismiss delay > 0, a timer fires dismiss after that many seconds.
4. **Clean completed icon**: Replace the inline warning badge with a green checkmark icon on "Complete". Move AI cleanup failure info to a small secondary caption below the result text. Error state keeps its existing full red icon treatment.

---

## Assumptions

- The existing `PromptStore` + `CleanupPrompt` model is sufficient as the prompt backing store — no changes needed to that model.
- Multi-shortcut bindings are persisted in `UserDefaults` as JSON-encoded `[ShortcutBinding]`, replacing the single `shortcutKeyCode`/`shortcutModifiers` pair. The old single-shortcut keys are migrated on first launch.
- The insert phrase listener reuses `SFSpeechRecognizer` directly (same as `WakePhraseListener`), not `SendPhraseDetector`, because it runs separately from recording.
- Insert phrase listener is only active during `.completed` state and stops on any transition away.
- Keep-open-on-copy auto-dismiss is a simple `DispatchWorkItem` timer; re-clicking Copy resets the timer.
- `keepOverlayOpenOnCopy` defaults to `false` to preserve current behavior.
- `PreferencesView` currently lives in a `TabView` frame of 450×360. Adding shortcuts list may require a height increase or a dedicated "Shortcuts" tab.

---

## Implementation Steps

### Step 0: Fix Whisper model loading — use local path when available
- **File:** `MacVoice/Transcription/TranscriptionEngine.swift`
- **What:**
  - Add `private func localModelPath(for modelName: String) -> String?` — iterates `downloadedModels`; normalises both `modelName` and each `DownloadedModel.name` to lowercase with `_` replaced by `-`; returns `model.path.path` if they match
  - In `loadModel()`, call `scanDownloadedModels()` first if `downloadedModels.isEmpty`, then call `localModelPath(for: settings.whisperModel)`
  - If a local path is found: `WhisperKitConfig(model: "openai_whisper-\(modelName)", modelFolder: localPath, ...)` — the `modelFolder` param bypasses Hub lookup
  - If not found locally: keep existing behaviour (`model: "openai_whisper-\(modelName)"` only, allowing remote download)
  - Log which path is taken: "Loading from local path: ..." vs "No local model found, attempting download..."
  - Remove the `large-v3_turbo` → `large-v3-turbo` migration in `Settings.init()` — it breaks disk name matching. Store and use the raw name from disk. Handle display-name normalisation in `whisperModelDisplayName(_:)` which already handles both variants.

### Step 1: Create `ShortcutBinding` model
- **File:** `MacVoice/Core/ShortcutBinding.swift` (new)
- **What:** `struct ShortcutBinding: Identifiable, Codable, Equatable` with fields: `id: UUID`, `keyCode: UInt16`, `modifiers: UInt`, `promptID: UUID?` (nil = use selected prompt), `label: String` (user-defined display label, optional)
- A `displayString: String` computed from `Settings.buildDisplayString(keyCode:modifiers:)`

### Step 2: Migrate Settings to multi-shortcut bindings
- **File:** `MacVoice/Core/Settings.swift`
- **What:**
  - Add `static let shortcutBindings = "shortcutBindings"` key
  - Add `var shortcutBindings: [ShortcutBinding]` property with `didSet` persisting to UserDefaults as JSON
  - On `init()`: if `shortcutBindings` key is absent, migrate existing `shortcutKeyCode`/`shortcutModifiers` into a single default `ShortcutBinding` and persist
  - Keep `shortcutKeyCode` / `shortcutModifiers` / `shortcutDisplayString` / `onShortcutChanged` for backwards compat during migration only; remove them in a follow-up clean-up (out of scope for this plan — mark as deprecated)
  - `onShortcutChanged` changed to `onShortcutBindingsChanged: (() -> Void)?`
  - Add `insertPhrase: String` (default `"Insert"`) + `insertPhraseEnabled: Bool` (default `true`)
  - Add `keepOverlayOpenOnCopy: Bool` (default `false`) + `copyAutoDismissDelay: Int` (default `0` seconds, 0 = no auto-dismiss)
  - Register all new defaults in `UserDefaults.register(defaults:)`

### Step 3: Update `ShortcutManager` for multiple shortcuts
- **File:** `MacVoice/Input/ShortcutManager.swift`
- **What:**
  - Change `init` signature: `init(settings: Settings, onActivate: @escaping (UUID?) -> Void)` where `UUID?` is the `promptID` override
  - Replace single `hotKey: HotKey?` with `var hotKeys: [UUID: HotKey]` (keyed by ShortcutBinding id)
  - `registerHotKeys()` replaces `registerHotKey()`: iterates `settings.shortcutBindings`, creates a `HotKey` per binding, stores in dict; calls `onActivate(binding.promptID)` on keyDown
  - Wire `settings.onShortcutBindingsChanged = { [weak self] in self?.registerHotKeys() }`
  - Remove old single-shortcut `registerHotKey()` method

### Step 4: Update `PipelineCoordinator.activate(promptID:)`
- **File:** `MacVoice/Core/PipelineCoordinator.swift`
- **What:**
  - Change signature: `func activate(promptID: UUID? = nil)`
  - Store `private var activePromptID: UUID?` — set in `activate()`, cleared in `cleanup()`
  - In `finalizePipeline()`, when `settings.aiCleanupEnabled`, use `activePromptID` to override `promptStore.selectedPromptID` for this call
  - `TranscriptionCleaner.clean(_:promptID:)` — add optional `promptID` param, defaulting to `nil` (uses selected)
  - Update `AppDelegate` to pass the new closure signature for `ShortcutManager`

### Step 5: Add `insertPhrase` settings entries
- **Already covered in Step 2** (insertPhrase, insertPhraseEnabled). Confirm defaults registered.

### Step 6: Create `InsertPhraseListener`
- **File:** `MacVoice/Input/InsertPhraseListener.swift` (new)
- **What:** `final class InsertPhraseListener: NSObject, SFSpeechRecognizerDelegate`
  - Same structure as `WakePhraseListener` but much simpler — no continuous restart loop
  - `startListening()`: creates `SFSpeechAudioEngineRecognitionRequest`; begins a fresh `AVAudioEngine` session; listens for `settings.insertPhrase` (exact + ok/okay variants); on match calls `onInsert()` once then calls `stopListening()`
  - `stopListening()`: tears down audio engine and recognition task
  - `onInsert: () -> Void` callback
  - Only active while overlay is `.completed`; start/stop is controlled externally

### Step 7: Wire `InsertPhraseListener` into `PipelineCoordinator`
- **File:** `MacVoice/Core/PipelineCoordinator.swift`
- **What:**
  - Add `private weak var insertPhraseListener: InsertPhraseListener?` (weak, held by AppDelegate)
  - In `transition(to:)`: when new state is `.completed` and `settings.insertPhraseEnabled`, call `insertPhraseListener?.startListening()`
  - In `cleanup()`: call `insertPhraseListener?.stopListening()`
  - `insertPhraseListener?.onInsert = { [weak self] in self?.insertResult() }` — wired in `AppDelegate`

### Step 8: Wire `InsertPhraseListener` in `AppDelegate`
- **File:** `MacVoice/App/AppDelegate.swift`
- **What:**
  - Create `insertPhraseListener = InsertPhraseListener(settings: settings) { [weak self] in self?.pipelineCoordinator.insertResult() }`
  - Pass to `PipelineCoordinator` via a new init parameter or `pipelineCoordinator.setInsertPhraseListener(insertPhraseListener)`
  - Update `PipelineCoordinator.init` to include `insertPhraseListener: InsertPhraseListener? = nil`

### Step 9: Update `copyResult()` for copy behavior setting
- **File:** `MacVoice/Core/PipelineCoordinator.swift`
- **What:**
  - Add `private var copyDismissWorkItem: DispatchWorkItem?`
  - `copyResult()`:
    - Copy to pasteboard (unchanged)
    - If `settings.keepOverlayOpenOnCopy == false`: call `dismiss()` (current behavior — default unchanged)
    - If `true`:
      - Log "keeping overlay open after copy"
      - Cancel any pending dismiss work item
      - If `settings.copyAutoDismissDelay > 0`: schedule a new `DispatchWorkItem` after that delay to call `dismiss()`, store as `copyDismissWorkItem`
  - In `cleanup()`: cancel `copyDismissWorkItem`

### Step 10: Fix completed-state icon in overlay
- **File:** `MacVoice/UI/RecordingOverlayView.swift`
- **What:** In `completedContent(_:)`:
  - Replace the conditional warning-in-header `if result.cleanupFailed { Image(systemName: "exclamationmark.triangle.fill") }` with always showing `Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)` in the header
  - Below the result `ScrollView`, add a conditional secondary caption: `if result.cleanupFailed { Text("AI cleanup failed — showing raw transcription").font(.caption).foregroundStyle(.secondary) }`
  - This keeps "Complete ✓" always looking positive; failure info is shown as a subtle footnote

### Step 11: Update `TranscriptionCleaner` for prompt override
- **File:** `MacVoice/Transcription/TranscriptionCleaner.swift`
- **What:**
  - Add `promptStore: PromptStore` dependency (already has it via constructor or settings)
  - Change `clean(_ text: String)` to `clean(_ text: String, promptID: UUID? = nil) async throws -> String`
  - If `promptID != nil`, look up that prompt from `promptStore`; otherwise use `promptStore.selectedPrompt`
  - `PipelineCoordinator` already calls `transcriptionCleaner.clean(rawText)` — update to `transcriptionCleaner.clean(rawText, promptID: activePromptID)`

### Step 12: Update `PreferencesView` for new settings
- **File:** `MacVoice/UI/PreferencesView.swift`
- **What:**
  - Add a **Shortcuts** tab (new `TabItem`) with:
    - A `List` of `ShortcutBinding` rows — each row shows label, key combo display string, and associated prompt name
    - `+` button to add a new binding (defaults to ⌘⇧V + no prompt override)
    - Swipe-to-delete / Delete button per row
    - Tapping a row opens an inline editor: label text field, `ShortcutRecorderButton`, prompt picker (from PromptStore)
  - **Voice Input section** additions:
    - `TextField("Insert Phrase:", text: $settings.insertPhrase)`
    - `Toggle("Insert Phrase Enabled", isOn: $settings.insertPhraseEnabled)`
  - **Overlay section** (new or added to General):
    - `Toggle("Keep Overlay Open After Copy", isOn: $settings.keepOverlayOpenOnCopy)`
    - If keep-open: `Stepper("Auto-dismiss after: \(settings.copyAutoDismissDelay)s", value: $settings.copyAutoDismissDelay, in: 0...60, step: 5)` with "Never" label for 0
  - Increase frame height or switch to scrollable form to accommodate new fields

---

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `MacVoice/Transcription/TranscriptionEngine.swift` | Modify | Local model path lookup; fix Hub name construction |
| `MacVoice/Core/ShortcutBinding.swift` | Create | New `ShortcutBinding` model |
| `MacVoice/Core/Settings.swift` | Modify | Add shortcutBindings, insertPhrase, keepOverlayOpenOnCopy, copyAutoDismissDelay; remove faulty migration |
| `MacVoice/Input/ShortcutManager.swift` | Modify | Support multiple HotKey registrations |
| `MacVoice/Input/InsertPhraseListener.swift` | Create | New voice listener active during `.completed` state |
| `MacVoice/Core/PipelineCoordinator.swift` | Modify | activate(promptID:), insertPhraseListener wiring, copyResult behavior, activePromptID |
| `MacVoice/App/AppDelegate.swift` | Modify | Create InsertPhraseListener, update ShortcutManager closure, pass to coordinator |
| `MacVoice/Transcription/TranscriptionCleaner.swift` | Modify | Add promptID override parameter |
| `MacVoice/UI/RecordingOverlayView.swift` | Modify | Fix completed icon (checkmark), move failure caption |
| `MacVoice/UI/PreferencesView.swift` | Modify | Add Shortcuts tab, insert phrase, copy behavior settings |

---

## Dependencies & Risks

- **HotKey library**: `HotKey` package wraps `Carbon` event taps — registering many shortcuts simultaneously should be fine, but key conflicts between bindings must be caught gracefully (warn, don't crash)
- **InsertPhraseListener mic contention**: starts a new `AVAudioEngine` session while recording is done; should be fine, but if any other Mac audio process holds exclusive access it may fail — needs graceful fallback
- **Settings migration**: the old `shortcutKeyCode` / `shortcutModifiers` must be migrated on first run without data loss to prevent losing the user's existing shortcut
- **TranscriptionCleaner signature change**: all callers updated in one pass to avoid build breaks
- **PreferencesView height**: adding a Shortcuts tab with a list will require layout changes — possible SwiftUI form scrolling issues on small screens

---

## Testing Plan — BLOCKING

### Automated Checks
- [ ] `swift build` compiles without errors or warnings
- [ ] `swift test` passes all existing tests (48/48)

### Manual Verification

1. **Whisper model fix**: Close and reopen the app with `large-v3-turbo` selected. Transcription must succeed. Runtime log must show "Loading from local path" not "model not found" or Hub error. Also test with a model not downloaded — should fall back to Hub download.
2. **Multi-shortcut**: Add a second binding in Preferences → Shortcuts tab. Assign a different prompt. Press the new shortcut — verify that AI cleanup uses that specific prompt. Remove the binding — verify it unregisters.
2. **Insert phrase**: With overlay in `.completed` state, speak the insert phrase ("Insert") — verify the text is inserted and overlay dismisses. Test with speech recognition unavailable — verify it fails gracefully (no crash).
3. **Copy behavior — close immediately**: Default off, click Copy — overlay dismisses (current behavior preserved).
4. **Copy behavior — keep open**: Enable keep-open, click Copy — overlay stays open. Set 5s auto-dismiss — overlay dismisses automatically after 5s. Click Copy twice quickly — timer resets correctly.
5. **Completed icon**: Trigger a successful transcription (no AI cleanup) — verify green checkmark + "Complete", no warning. Enable AI cleanup with bad key — verify green checkmark + "Complete" + small failure caption below result. Verify error state still shows full red triangle.
6. **Regression**: Wake phrase, send phrase, auto-insert, transcription, history all continue working.

### Edge Cases
- [ ] Two shortcut bindings with identical key combo — warn in log, second registration silently skipped
- [ ] `insertPhrase` set to same phrase as `sendPhrase` — unlikely but should document behavior (both detect during recording, insert only during completed)
- [ ] `copyAutoDismissDelay = 0` with `keepOverlayOpenOnCopy = true` — overlay stays open indefinitely until manually dismissed

---

## Rollback Plan

Each step is additive or localized. To rollback:
- Revert `ShortcutBinding.swift` creation (delete file)
- Revert `Settings.swift` edits — restore single shortcut keys
- Revert `ShortcutManager.swift` to single-hotkey model
- Revert `PipelineCoordinator.swift` to `activate()` with no param
- Delete `InsertPhraseListener.swift`
- Revert `RecordingOverlayView.swift` header change

---

## Post-Implementation Checklist

**Gate 1 — Code complete:**
- [ ] All 12 implementation steps complete

**Gate 2 — Testing (BLOCKING):**
- [ ] `swift build` clean
- [ ] `swift test` 48/48
- [ ] Manual: multi-shortcut with distinct prompts
- [ ] Manual: insert phrase triggers insert
- [ ] Manual: copy behavior setting works
- [ ] Manual: completed icon is clean (no warning triangle)
- [ ] Regression checks passed

**Gate 3 — Documentation & logging (only after Gate 2):**
- [ ] `docs/logic/input.md` updated (shortcuts, insert phrase)
- [ ] Task logged to `docs/task/logs/2026-03-29.md`
- [ ] Observations logged

**Gate 4 — Close out:**
- [ ] Plan status → **Complete**
- [ ] Plan file moved from `draft/` to `completed/`
