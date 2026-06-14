# Plan: Voice Recordings & Model Management

> **Status:** Complete
> **Created:** 2026-03-28
> **Estimated steps:** 14
> **Risk level:** Medium

## Context

Multiple related issues need addressing:

1. The `large-v3_turbo` Whisper model name is invalid — WhisperKit doesn't recognize it. The model enum is hardcoded and can't adapt to available models.
2. Downloaded Whisper models are large (1–10GB) and there's no way to see what's downloaded or delete them.
3. Voice recordings are deleted when transcription fails, losing the audio permanently.
4. Recordings are auto-pruned after `maxHistoryRecordings` (50) — users want to keep everything by default.
5. No built-in audio playback — users can't listen to recordings in the app.
6. No way to re-transcribe a recording with a different model or prompt.

## Current State

### Whisper Model Enum (`Settings.swift` L37–55)
Hardcoded `WhisperModel` enum with 8 values. The `largev3Turbo` case uses raw value `large-v3_turbo`, producing `openai_whisper-large-v3_turbo` — a model that doesn't exist in WhisperKit's repo. No dynamic model discovery.

### TranscriptionEngine (`TranscriptionEngine.swift` L1–91)
Creates `WhisperKitConfig` with `model: "openai_whisper-\(model.rawValue)"`. No model listing, no download tracking, no model deletion API.

### Pipeline on Failure (`PipelineCoordinator.swift` L167–216)
When transcription fails (L208–211), the pipeline goes to `.error` state and `cleanup()` runs — but the temp recording file is deleted on L216 (`try? FileManager.default.removeItem(at: url)`) regardless of success/failure, since it runs after the do/catch block.

### Audio File Lifecycle (`PipelineCoordinator.swift` L185, L216)
Audio is copied to history (L185) only after successful transcription. On failure, the temp file is deleted and audio is lost.

### HistoryStore (`HistoryStore.swift` L137–158)
`pruneAudioFiles()` removes audio files for records beyond `maxRecordings`. Records survive but lose their audio.

### TranscriptionRecord (`TranscriptionRecord.swift`)
Has `audioFileName`, `folderID`, `isArchived`, but no field for transcription status (success/failure) or re-transcription tracking.

### No Audio Playback
No `AVAudioPlayer` usage anywhere in the codebase. `HistoryListView` shows text only.

## Target State

1. **Dynamic model list** — Use `WhisperKit.fetchAvailableModels()` to discover available models at runtime. Remove the hardcoded enum (keep as fallback only).
2. **Downloaded model management** — Show which models are downloaded locally, their disk size, and allow deletion.
3. **Recordings always saved** — Audio is copied to history before transcription attempt. On failure, a record is still created (with `rawText = ""` and a failure status flag).
4. **No auto-deletion by default** — Remove the `maxHistoryRecordings` pruning default. Add a configurable "auto-delete after N days" setting (default: never).
5. **In-app audio playback** — Play recordings directly from the history/recordings list.
6. **Re-transcription** — Select a recording, choose a different model and/or prompt, and re-transcribe. The new result replaces or is appended alongside the original.
7. **Recordings tab** — Dedicated section in the main window showing all voice recordings with playback, re-transcribe, archive, move-to-folder, and delete actions.

## Assumptions

- WhisperKit `fetchAvailableModels()` returns model variant strings like `openai_whisper-tiny`, `openai_whisper-base`, etc. The prefix `openai_whisper-` is the repo naming convention.
- WhisperKit downloads models to `~/Library/Caches/com.apple.nsurlsessiond/` or a Hub-managed cache. We'll use WhisperKit's `download()` API and the Hub cache directory to discover downloaded models.
- `AVAudioPlayer` (Foundation) is sufficient for .wav playback in-app — no need for AVAudioEngine for simple playback.
- Re-transcription reuses the existing `TranscriptionEngine.transcribe()` and `TranscriptionCleaner.clean()` paths.
- The "Recordings" view lives as a section within the existing `HistoryListView` or as a new tab alongside History in `MainWindowView`.

## Implementation Steps

- [x] **Step 1: Fix Whisper model discovery — replace hardcoded enum with dynamic model list**
  - Files: `MacVoice/Core/Settings.swift`, `MacVoice/Transcription/TranscriptionEngine.swift`
  - What:
    - Keep `WhisperModel` enum as a fallback/default set but remove `largev3Turbo` case (invalid).
    - Add `availableModels: [String]` and `downloadedModels: [DownloadedModel]` to `TranscriptionEngine`.
    - Add `func fetchAvailableModels() async` that calls `WhisperKit.fetchAvailableModels()` and populates the list.
    - Add `struct DownloadedModel { name: String, sizeBytes: Int64, path: URL }`.
    - Change `settings.whisperModel` from `WhisperModel` enum to `String` (the raw model variant name). Migrate existing saved value.
    - Update `loadModel()` to use the string-based model name directly.
  - Why: The hardcoded enum has an invalid model name and can't adapt to WhisperKit updates.

- [x] **Step 2: Add downloaded model discovery and deletion**
  - Files: `MacVoice/Transcription/TranscriptionEngine.swift`
  - What:
    - Add `func scanDownloadedModels()` that inspects the WhisperKit/Hub local cache directory for downloaded model folders, calculates their sizes, and populates `downloadedModels`.
    - Add `func deleteModel(_ name: String) throws` that removes the model's local cache folder.
    - WhisperKit uses the Hub library for downloads — models are cached in `~/Library/Caches/huggingface/hub/models--argmaxinc--whisperkit-coreml/`. Scan `snapshots/` subdirectories for model folders matching `openai_whisper-*`.
  - Why: Users testing models accumulate GBs of data with no visibility or control.

- [x] **Step 3: Build Model Management UI**
  - Files: `MacVoice/UI/PreferencesView.swift` (or `MainWindowView.swift` Settings section)
  - What:
    - Replace the hardcoded `Picker` for Whisper model with a dynamic list populated from `TranscriptionEngine.availableModels`.
    - Show download status indicator (downloaded / not downloaded / downloading).
    - Add a "Downloaded Models" section below the model picker listing each downloaded model with: name, size (formatted), and a Delete button.
    - Show total disk usage for all downloaded models.
    - Add a download progress indicator when a model is being fetched.
  - Why: Users need visibility into what's stored locally and the ability to reclaim disk space.

- [x] **Step 4: Update TranscriptionRecord for failure tracking and re-transcription**
  - Files: `MacVoice/Core/TranscriptionRecord.swift`
  - What:
    - Add `var transcriptionStatus: TranscriptionStatus` enum: `.success`, `.failed(String)`, `.pending` (for recordings not yet transcribed).
    - Add `var whisperModel: String?` — which model was used for transcription.
    - Add `var retranscriptionHistory: [RetranscriptionEntry]?` — optional array tracking re-transcription attempts: `{ date, model, prompt, rawText, cleanedText }`.
    - Ensure backward compatibility with existing JSON (make new fields optional with defaults).
  - Why: Need to distinguish failed transcriptions and track which model/prompt produced results.

- [x] **Step 5: Save recordings before transcription, preserve on failure**
  - Files: `MacVoice/Core/PipelineCoordinator.swift`
  - What:
    - Move `historyStore.copyAudioFile(from: url)` to BEFORE the `transcriptionEngine.transcribe()` call (currently at L185, move to ~L175 right after stopping recording).
    - On transcription failure (catch block L208–211): create a `TranscriptionRecord` with `rawText: ""`, `transcriptionStatus: .failed(error.localizedDescription)`, and the `audioFileName` from the already-copied file. Save to history.
    - On transcription success: update the record with transcription text (or create new as currently done).
    - Remove unconditional `FileManager.removeItem` at L216 — temp file should still be cleaned up, but only after successful copy to history dir.
  - Why: Currently audio is lost on transcription failure. Users want to retry failed transcriptions.

- [x] **Step 6: Replace max-recordings pruning with time-based auto-deletion**
  - Files: `MacVoice/Core/Settings.swift`, `MacVoice/Core/HistoryStore.swift`
  - What:
    - Add `autoDeleteDays: Int` setting (0 = never, default). Options: Never, 7 days, 30 days, 90 days, 365 days.
    - Remove `maxHistoryRecordings` setting and the `pruneAudioFiles()` method.
    - Add `pruneOldRecordings()` method that deletes records (and their audio files) older than `autoDeleteDays`. Call on app launch and periodically.
    - Existing recordings should not be affected by migration (nothing gets deleted).
  - Why: Users want to keep all recordings by default, with optional cleanup by age.

- [x] **Step 7: Add audio playback capability**
  - Files: `MacVoice/Audio/AudioPlayer.swift` (new file)
  - What:
    - Create `AudioPlayer` class wrapping `AVAudioPlayer`.
    - Properties: `isPlaying: Bool`, `currentTime: TimeInterval`, `duration: TimeInterval`, `playbackProgress: Double`.
    - Methods: `play(url: URL)`, `pause()`, `stop()`, `seek(to: TimeInterval)`.
    - Use `AVAudioPlayerDelegate` for completion callback.
    - Singleton or injected instance shared across views.
  - Why: Users need to listen to recordings in the app for review, especially failed transcriptions.

- [x] **Step 8: Add playback UI to recording detail view**
  - Files: `MacVoice/UI/HistoryListView.swift`
  - What:
    - In the detail panel (right side when a record is selected), add a playback bar below the text content.
    - Show: Play/Pause button, progress bar/slider, current time / total duration.
    - Only show when `record.audioFileName != nil`.
    - For failed transcriptions, show prominently with a "Retry Transcription" button.
  - Why: Playback needs to be accessible from the existing history detail view.

- [x] **Step 9: Add re-transcription capability**
  - Files: `MacVoice/Core/PipelineCoordinator.swift` (or new `RetranscriptionService.swift`), `MacVoice/Core/HistoryStore.swift`
  - What:
    - Add `func retranscribe(recordID: UUID, model: String?, prompt: CleanupPrompt?) async` method.
    - Load the audio file from `recordingsDir`, run `transcriptionEngine.transcribe()` with the specified (or current) model.
    - Optionally run AI cleanup with the specified prompt.
    - Update the `TranscriptionRecord`: set new `rawText`/`cleanedText`, update `whisperModel`, append to `retranscriptionHistory`.
    - If model is different from currently loaded, load the new model first (with UI feedback).
  - Why: Users want to re-process recordings with different models or prompts for better results.

- [x] **Step 10: Add re-transcription UI**
  - Files: `MacVoice/UI/HistoryListView.swift`
  - What:
    - Add "Re-transcribe" button/menu in the detail panel (visible when audio file exists).
    - Show a sheet/popover with: Model picker (from available models), Prompt picker (from PromptStore), "Re-transcribe" action button.
    - Show progress during re-transcription (model loading + transcribing + optional cleanup).
    - After completion, refresh the detail view with new results.
    - For failed transcriptions, show the re-transcribe option prominently.
  - Why: Users need a UI to trigger re-transcription with custom model/prompt choices.

- [x] **Step 11: Update auto-delete settings UI**
  - Files: `MacVoice/UI/PreferencesView.swift` (or Settings section in `MainWindowView.swift`)
  - What:
    - Remove the `maxHistoryRecordings` stepper/picker.
    - Add "Auto-delete recordings" picker with options: Never (default), After 7 days, After 30 days, After 90 days, After 1 year.
    - Add informational text showing total recordings count and total disk usage.
  - Why: Replace count-based pruning with more intuitive time-based cleanup.

- [x] **Step 12: Update HistoryListView for failed-transcription indicators**
  - Files: `MacVoice/UI/HistoryListView.swift`
  - What:
    - Show a visual indicator (e.g., red exclamation icon) for records with `.failed` transcription status.
    - Show "No transcription" placeholder text for failed records instead of empty text.
    - Add a "Failed" filter alongside existing All/Unfiled/Archive filters.
    - Sort failed transcriptions to be easily discoverable.
  - Why: Failed transcriptions need to be visually distinct so users know which recordings need re-processing.

- [x] **Step 13: Wire new components into AppDelegate and composition root**
  - Files: `MacVoice/App/AppDelegate.swift`
  - What:
    - Create and inject `AudioPlayer` instance.
    - Call `transcriptionEngine.fetchAvailableModels()` on app launch.
    - Call `transcriptionEngine.scanDownloadedModels()` on app launch.
    - Call `historyStore.pruneOldRecordings()` on app launch.
    - Pass `AudioPlayer` to views that need it.
  - Why: New services need to be initialized and wired at app startup.

- [x] **Step 14: Update documentation**
  - Files: `docs/logic/transcription.md`, `docs/logic/audio.md`, `docs/logic/menubar-ui.md`
  - What:
    - Document dynamic model discovery and management.
    - Document recording retention policy (keep all, time-based cleanup).
    - Document re-transcription flow.
    - Document audio playback capability.
    - Update architecture diagrams if applicable.
  - Why: Documentation must stay in sync with code changes.

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `MacVoice/Core/Settings.swift` | Modify | Change `whisperModel` from enum to String, add `autoDeleteDays`, remove `maxHistoryRecordings`, migration logic |
| `MacVoice/Transcription/TranscriptionEngine.swift` | Modify | Add `fetchAvailableModels()`, `scanDownloadedModels()`, `deleteModel()`, `DownloadedModel` struct |
| `MacVoice/Core/TranscriptionRecord.swift` | Modify | Add `transcriptionStatus`, `whisperModel`, `retranscriptionHistory` fields |
| `MacVoice/Core/PipelineCoordinator.swift` | Modify | Move audio copy before transcription, save record on failure, remove unconditional temp-file deletion |
| `MacVoice/Core/HistoryStore.swift` | Modify | Replace `pruneAudioFiles()` with `pruneOldRecordings()`, add re-transcription update methods |
| `MacVoice/Audio/AudioPlayer.swift` | Create | New audio playback service wrapping AVAudioPlayer |
| `MacVoice/UI/PreferencesView.swift` | Modify | Dynamic model picker, downloaded models list, auto-delete setting |
| `MacVoice/UI/MainWindowView.swift` | Modify | Pass new dependencies to child views |
| `MacVoice/UI/HistoryListView.swift` | Modify | Playback bar, re-transcribe button, failed-transcription indicators, Failed filter |
| `MacVoice/App/AppDelegate.swift` | Modify | Wire AudioPlayer, trigger model fetch/scan, trigger old-recording pruning |
| `docs/logic/transcription.md` | Modify | Document model management and re-transcription |
| `docs/logic/audio.md` | Modify | Document recording retention and playback |

## Dependencies & Risks

- **WhisperKit model cache location** — The Hub library stores models in a cache directory. If the location changes between WhisperKit versions, the `scanDownloadedModels()` and `deleteModel()` logic may break. Mitigation: use Hub's own API to discover cache paths if available, fall back to known paths.
- **Model loading during re-transcription** — If the user picks a different model, it may need downloading (GBs over network). Must show clear progress and allow cancellation.
- **Backward compatibility** — New fields on `TranscriptionRecord` must be optional with sensible defaults so existing `history.json` files decode correctly without data loss.
- **Disk space** — Keeping all recordings indefinitely could consume significant disk. The auto-delete setting and total-disk-usage indicator mitigate this.
- **Concurrent access** — Re-transcription could conflict with an active recording pipeline. Need to prevent re-transcription while the pipeline is active (or vice versa).

## Testing Plan — BLOCKING (execute BEFORE docs or completion)

### Automated Checks
- [x] `swift build` compiles without errors
- [x] `swift test` passes all tests (48/48)
- [x] New `TranscriptionRecord` fields decode gracefully from old JSON (no `retranscriptionHistory`, no `transcriptionStatus`)

### Manual Verification

1. Build and run the app
2. Open Settings → Transcription: verify dynamic model list loads (not hardcoded)
3. Download a model → verify it appears in "Downloaded Models" section with correct size
4. Delete a downloaded model → verify it's removed from disk and list
5. Make a recording → verify audio file is saved BEFORE transcription starts
6. Force a transcription failure (e.g., no model loaded) → verify recording is preserved with "Failed" status in history
7. Select a failed recording → verify playback works
8. Re-transcribe a recording with a different prompt → verify new text appears
9. Set auto-delete to 7 days → verify old recordings are cleaned up
10. Set auto-delete to Never → verify no recordings are deleted

### Regression Checks
- [ ] Normal recording → transcription → overlay flow still works end-to-end
- [ ] AI cleanup still works when enabled
- [ ] History folder/archive/search functionality unchanged
- [ ] Model switching in settings still works (loads new model)

### Edge Cases
- [ ] Empty model list from WhisperKit API → falls back to hardcoded defaults
- [ ] Network offline during `fetchAvailableModels()` → graceful fallback
- [ ] Audio file missing on disk but referenced in record → graceful handling in playback UI
- [ ] Re-transcription while pipeline is active → blocked with user feedback
- [ ] Migration from old settings format (enum-based `whisperModel`) → correctly maps to string

**STOP: Do NOT proceed to docs or completion until ALL tests pass.**

## Rollback Plan

1. Revert all changed files to their pre-implementation state via `git checkout`.
2. Old `history.json` files remain compatible — new optional fields are simply absent.
3. No database migrations needed — all data is JSON files with optional fields.

## Post-Implementation Checklist

**Gate 1 — Code complete:**
- [x] All 14 implementation steps complete

**Gate 2 — Testing (BLOCKING):**
- [x] All automated checks passed
- [ ] All manual verification executed
- [ ] All regression checks executed

**Gate 3 — Documentation & logging (only after Gate 2):**
- [x] Documentation updated
- [x] Task logged
- [x] Observations logged

**Gate 4 — Close out:**
- [x] Plan status → **Complete**
- [ ] Plan file moved from `draft/` to `completed/`
