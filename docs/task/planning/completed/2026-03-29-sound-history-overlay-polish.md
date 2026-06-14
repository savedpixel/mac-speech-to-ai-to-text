# Plan: Sound Quality, History Resilience, Overlay Feedback & UI Polish

> **Status:** Complete
> **Created:** 2026-03-29
> **Estimated steps:** 11
> **Risk level:** Medium

---

## Context

Several UX issues identified during testing:

1. **Beep sounds are scratchy/robotic** — the current `AudioSignalPlayer` synthesises raw sine waves via `AVAudioEngine` per-tone (creating and destroying an engine each time). The result is scratchy and robotic. User wants a library of pleasant sounds to choose from.
2. **Recording lost when app killed mid-transcription** — audio IS already copied to history before transcription (line 175 `PipelineCoordinator`), and failed records ARE saved (line 241). However, if the app is force-killed during the async transcription, neither the catch block nor the success block runs, so no `TranscriptionRecord` is ever persisted. The record needs to be saved *immediately* after the audio file is copied, before transcription begins.
3. **Re-transcription doesn't show progress overlay** — `performRetranscription()` in `HistoryListView.swift` (line 417) runs async with just a small inline spinner. The transcription works but the user gets no real feedback — the spinner appears briefly then disappears, and the updated text is only visible when clicking away and back. Should show the same overlay that appears during a live recording (transcribing → cleaning → complete stages).
4. **History list items don't always respond to clicks** — the `List(filteredRecords, selection: $selectedIDs)` with multi-selection (`Set<UUID>`) plus `onChange(of: selectedIDs)` uses a first-match lookup. When the list is re-filtering or the `onChange` fires before `filteredRecords` updates, the click appears to be swallowed. Fix: derive `selectedRecord` directly from `selectedIDs` as a computed binding rather than a delayed `onChange`.
5. **AI cleanup failure not visually obvious** — overlay shows a subtle secondary caption "AI cleanup failed — showing raw transcription". Should be red text + red icon + include the failure reason. Transcription success should show green.
6. **TranscriptionResult doesn't carry failure reason** — `cleanupFailed: Bool` loses the error message. Need `cleanupFailureReason: String?`.
7. **History detail layout issues** — Copy button is centered next to text (should be top-right aligned). Folder picker stretches full width at the bottom (should be compact at top). Model Used is buried at bottom (should be at top as metadata). GroupBox "Recording" label has leading space misalignment.
8. **Settings form layout not native** — uses `TextField` with `.roundedBorder` + separate labels. macOS native `Form` with `.formStyle(.grouped)` puts labels left, controls right automatically. Wake phrase input and other text fields have alignment issues. Should follow macOS native form patterns (label left, control right, no manual borders).

---

## Current State

### AudioSignalPlayer (`MacVoice/Audio/AudioSignalPlayer.swift`)
- Creates a new `AVAudioEngine` + `AVAudioPlayerNode` for every single tone
- Raw sine wave synthesis with minimal fade (5ms)
- 0.12s duration → very short, clipped, scratchy
- No harmonic content → robotic sound
- No sound selection — hardcoded frequencies

### Recording persistence (`MacVoice/Core/PipelineCoordinator.swift`, lines 161–250)
- `historyStore.copyAudioFile(from: url)` runs on line 175 — audio IS saved
- But `historyStore.addRecord(record)` only runs at line 221 (success) or line 241 (catch) — if app killed between line 175 and either of those, no record exists for that audio file

### Re-transcription UI (`MacVoice/UI/HistoryListView.swift`, lines 270–460)
- `performRetranscription()` shows a small inline `ProgressView` + "Re-transcribing…" text
- No overlay appears — user has no pipeline-stage feedback
- `HistoryDetailView` takes `let record: TranscriptionRecord` — stale value copy
- `HistoryContentView` already uses `liveRecord` computed property (~line 95) which looks up from store — but this only works if `selectedRecord` is set

### History list selection (`MacVoice/UI/HistoryListView.swift`, lines 85–100)
- `onChange(of: selectedIDs)` does a `filteredRecords.first(where:)` lookup
- Race between filter update and selection change makes clicks feel unresponsive

### Overlay failure display (`MacVoice/UI/RecordingOverlayView.swift`, lines 115–120)
- `if result.cleanupFailed` → `.font(.caption).foregroundStyle(.secondary)` — barely visible
- No failure reason displayed

### TranscriptionResult (`MacVoice/Core/PipelineState.swift`, lines 3–11)
- `cleanupFailed: Bool` — no reason string

### History detail layout (`MacVoice/UI/HistoryListView.swift`, lines 238–360)
- Copy buttons are in `HStack` with text — visually centered alongside content
- Folder picker is a full-width `GroupBox("Folder")` at bottom
- Model Used is a `GroupBox` at bottom
- GroupBox("Recording") has normal label rendering

### Settings layout (`MacVoice/UI/MainWindowView.swift`, lines 265–310)
- Uses `TextField("Send Phrase:", text:)` with `.textFieldStyle(.roundedBorder)` — manual bordered style
- `HStack { Text("Wake Phrase:") TextField(...) }` — manual layout instead of native
- Form uses `.formStyle(.grouped)` which should auto-layout labels, but the manual HStacks and roundedBorder fight the native form rendering

---

## Target State

1. **Sound library** — multiple pre-generated sound presets (e.g. "Gentle", "Chime", "Pop", "Minimal") stored as synthesised buffers. User selects preset in settings. Persistent `AVAudioEngine` reused across plays. Warmer tones with harmonics and proper envelopes.
2. **Recording never lost** — save a `pending` `TranscriptionRecord` immediately after audio copy, before transcription. Update it to `success` or `failed` after.
3. **Re-transcription shows overlay** — when user clicks Re-transcribe, show the same recording overlay panel with transcribing → cleaning → complete stages. Use the existing overlay infrastructure.
4. **Responsive history clicks** — remove the `onChange` indirection; derive selection directly.
5. **Obvious AI failure in overlay** — red icon + red "AI cleanup failed: {reason}". Green "Transcription successful" label.
6. **Failure reason in TranscriptionResult** — add `cleanupFailureReason: String?`.
7. **History detail polish** — metadata (folder, model) at top as compact inline fields. Copy buttons aligned top-right of their GroupBoxes. Clean alignment on recording section.
8. **Native macOS form layout** — remove `.textFieldStyle(.roundedBorder)` and manual `HStack` wrappers. Use SwiftUI `Form` + `.formStyle(.grouped)` with `TextField("Label", text:)` directly — this auto-renders label-left, control-right on macOS. Remove extraneous borders.

---

## Assumptions

- Sound presets are synthesised at init time and stored as `AVAudioPCMBuffer` arrays — no bundled audio files needed.
- The `pending` status already exists in `TranscriptionStatus` enum — confirmed.
- Re-transcription overlay can reuse `RecordingOverlayPanel` by driving `PipelineCoordinator` state changes, or by showing a simpler inline sheet. Using a sheet-based progress view is simpler than hijacking the pipeline coordinator state machine for a non-recording flow.
- macOS SwiftUI `Form { TextField("Label", text:) }` with `.formStyle(.grouped)` automatically renders label left, control right. No manual layout needed.
- `HistoryContentView.liveRecord` (line ~95) already resolves from the store, so the detail view refresh issue is about the binding chain, not missing infrastructure.

---

## Implementation Steps

### Step 1: Sound preset library in AudioSignalPlayer

- **File:** `MacVoice/Audio/AudioSignalPlayer.swift`
- **What:**
  - Define `enum SoundPreset: String, CaseIterable, Codable` with cases: `gentle`, `chime`, `pop`, `minimal`
  - Each preset defines frequency, harmonics, envelope, and duration parameters
  - Create a persistent `AVAudioEngine` + `AVAudioPlayerNode` in `init()`, start once
  - Pre-generate `AVAudioPCMBuffer` for each preset's ready/done/aiDone tones at init
  - `playReadyBeep()`, `playTranscriptionDoneBeep()`, `playAIDoneBeep()` look up the current preset from settings and schedule the matching pre-built buffer
  - Envelope: 30ms fade-in, sustain, 80ms fade-out. Harmonics: fundamental + 0.15× second + 0.05× third. Duration ~180ms.
  - Preset details:
    - **gentle**: 660 Hz, soft sine+harmonics, volume 0.15
    - **chime**: 880 Hz, brighter harmonics (0.25× second), volume 0.18
    - **pop**: 1000 Hz, short attack (10ms), minimal harmonics, volume 0.2
    - **minimal**: 520 Hz, pure sine only, volume 0.12
  - Engine restart fallback: if `engine.isRunning == false`, try `engine.start()` before scheduling
- **File:** `MacVoice/Core/Settings.swift`
  - Add `soundPreset: String` property (default `"gentle"`) + UserDefaults key

### Step 2: Save pending record before transcription

- **File:** `MacVoice/Core/PipelineCoordinator.swift`
- **What:**
  - In `finalizePipeline()`, immediately after `let audioFileName = historyStore.copyAudioFile(from: url)` (line 175):
    ```swift
    var pendingRecord = TranscriptionRecord(rawText: "", audioFileName: audioFileName, transcriptionStatus: .pending, whisperModel: settings.whisperModel)
    historyStore.addRecord(pendingRecord)
    let pendingID = pendingRecord.id
    ```
  - On success: build `updated` from `pendingRecord` instead of creating new, set `updated.id = pendingID`, call `historyStore.updateRecord(updated)` instead of `addRecord`
  - On failure: same — update the pending record to `.failed` status

### Step 3: Add `cleanupFailureReason` to TranscriptionResult

- **File:** `MacVoice/Core/PipelineState.swift`
  - Add `let cleanupFailureReason: String?` to `TranscriptionResult` (default `nil`)
  - Update `==` conformance to compare the new field
- **File:** `MacVoice/Core/PipelineCoordinator.swift`
  - Capture `error.localizedDescription` in AI cleanup catch block into `var cleanupFailureReason: String?`
  - Pass to `TranscriptionResult(rawText:cleanedText:cleanupFailed:cleanupFailureReason:)`

### Step 4: Make AI failure obvious in overlay

- **File:** `MacVoice/UI/RecordingOverlayView.swift`
- **What:** In `completedContent(_:)`:
  - Replace the subtle `if result.cleanupFailed` caption block with:
    ```swift
    if result.cleanupFailed {
        HStack(spacing: 4) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
            Text("AI cleanup failed")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
        }
        if let reason = result.cleanupFailureReason {
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
    ```
  - Add green transcription success label above the ScrollView:
    ```swift
    Label("Transcription successful", systemImage: "checkmark.circle.fill")
        .font(.caption)
        .foregroundStyle(.green)
    ```

### Step 5: Fix history list click responsiveness

- **File:** `MacVoice/UI/HistoryListView.swift`
- **What:**
  - Remove `onChange(of: selectedIDs)` block (lines ~89–94)
  - Remove `onChange(of: section)` block (lines ~96–103)
  - Instead, add a computed property:
    ```swift
    private var firstSelectedRecord: TranscriptionRecord? {
        guard let id = selectedIDs.first else { return nil }
        return filteredRecords.first(where: { $0.id == id })
    }
    ```
  - Change `$selectedRecord` binding in the parent to be driven by `firstSelectedRecord` — use `onChange(of: selectedIDs)` that ONLY sets `selectedRecord = firstSelectedRecord` synchronously (no async delay)
  - On `onAppear` and `onChange(of: section)`: auto-select first item synchronously

### Step 6: Re-transcription shows progress overlay/sheet

- **File:** `MacVoice/UI/HistoryListView.swift`
- **What:**
  - Replace the inline spinner approach with a sheet-based progress view
  - Add `@State private var retranscribeProgress: RetranscribeProgress = .idle`
  - Define local enum: `enum RetranscribeProgress { case idle, transcribing, cleaning, done(String), failed(String) }`
  - When `performRetranscription()` runs, show a `.sheet` with a view that mirrors the overlay stages:
    - `.transcribing` → ProgressView + "Transcribing…"
    - `.cleaning` → ProgressView + "Cleaning up via AI…"
    - `.done(text)` → checkmark + text preview + "Done" button to dismiss
    - `.failed(msg)` → red error + dismiss button
  - This gives the user clear feedback about each stage
  - Remove the old `isRetranscribing` state and inline spinner

### Step 7: History detail layout polish

- **File:** `MacVoice/UI/HistoryListView.swift` (in `HistoryDetailView`)
- **What:**
  - Reorder the VStack content:
    1. **Header** (date + status badges + archive/delete buttons) — unchanged
    2. **Metadata row** — compact `HStack` with folder picker (compact Picker, not full-width GroupBox) + model badge + prompt badge
    3. **Playback bar** — GroupBox("Recording") with proper padding (no leading space issue)
    4. **Re-transcribe button**
    5. **Transcription text** — GroupBox("Cleaned Text") and GroupBox("Raw Text") with Copy buttons aligned top-right:
      ```swift
      GroupBox("Cleaned Text") {
          VStack(alignment: .leading, spacing: 8) {
              HStack {
                  Spacer()
                  Button("Copy") { ... }
                      .buttonStyle(.bordered)
                      .controlSize(.small)
              }
              Text(cleaned)
                  .textSelection(.enabled)
                  .frame(maxWidth: .infinity, alignment: .leading)
          }
      }
      ```
  - Folder picker: inline `Picker` with `.pickerStyle(.menu)` next to "Folder:" label, not a full-width GroupBox
  - Model Used: inline `Text` label like "Model: Large v3 Turbo" on the metadata row, not a GroupBox

### Step 8: Native macOS form layout for settings

- **File:** `MacVoice/UI/MainWindowView.swift` (SettingsContentView sections)
- **What:** In `voiceInputSection` and other sections:
  - Remove `.textFieldStyle(.roundedBorder)` from all TextFields — the Form handles styling
  - Remove manual `HStack { Text("Label:") TextField(...) }` wrappers — use `TextField("Label", text:)` directly, which Form renders as label-left, control-right
  - Before:
    ```swift
    HStack {
        Text("Wake Phrase:")
        TextField("e.g. Ok Voice", text: $settings.wakePhrase)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 200)
    }
    ```
  - After:
    ```swift
    TextField("Wake Phrase", text: $settings.wakePhrase)
    ```
  - Apply same pattern to: Send Phrase, Insert Phrase, Silence Threshold, Wake Phrase, and AI Cleanup fields
  - Remove `.frame(maxWidth: 200)` constraints — let the Form manage width
  - Keep Toggles and Pickers as-is — they already render correctly in Form
- **File:** `MacVoice/UI/PreferencesView.swift`
  - Same treatment: remove `.textFieldStyle(.roundedBorder)` from TextFields

### Step 9: Sound preset picker in settings

- **File:** `MacVoice/UI/MainWindowView.swift` (SettingsContentView)
  - Add a "Sound" section with a Picker for sound preset:
    ```swift
    Section("Sound") {
        Picker("Notification Sound", selection: $settings.soundPreset) {
            ForEach(SoundPreset.allCases, id: \.self) { preset in
                Text(preset.displayName).tag(preset.rawValue)
            }
        }
        Button("Preview") { audioSignalPlayer.playReadyBeep() }
    }
    ```
  - Requires passing `AudioSignalPlayer` reference through to settings view (or use a preview callback)
- **File:** `MacVoice/UI/PreferencesView.swift`
  - Add matching sound preset picker

### Step 10: Wire AudioSignalPlayer to use settings preset

- **File:** `MacVoice/Audio/AudioSignalPlayer.swift`
  - Add `settings: Settings` dependency to `init`
  - `playReadyBeep()` / `playTranscriptionDoneBeep()` / `playAIDoneBeep()` read `settings.soundPreset` to select which pre-built buffer to schedule
- **File:** `MacVoice/App/AppDelegate.swift`
  - Pass `settings` to `AudioSignalPlayer(settings: settings)`

### Step 11: Build, test, and verify

- `swift build` — zero errors
- `swift test` — all tests pass
- Manual verification of all features (see Testing Plan)

---

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `MacVoice/Audio/AudioSignalPlayer.swift` | Modify | Sound preset library, persistent engine, settings integration |
| `MacVoice/Core/PipelineCoordinator.swift` | Modify | Save pending record before transcription, pass failure reason |
| `MacVoice/Core/PipelineState.swift` | Modify | Add `cleanupFailureReason` to `TranscriptionResult` |
| `MacVoice/Core/Settings.swift` | Modify | Add `soundPreset` setting |
| `MacVoice/UI/RecordingOverlayView.swift` | Modify | Red failure display with reason, green success label |
| `MacVoice/UI/HistoryListView.swift` | Modify | Fix click responsiveness, re-transcribe progress sheet, detail layout polish |
| `MacVoice/UI/MainWindowView.swift` | Modify | Native form layout, sound preset picker, pass audioSignalPlayer |
| `MacVoice/UI/PreferencesView.swift` | Modify | Native form layout, sound preset picker |
| `MacVoice/App/AppDelegate.swift` | Modify | Pass settings to AudioSignalPlayer |

---

## Dependencies & Risks

- **Persistent AVAudioEngine** — must handle audio session interruptions (e.g. Bluetooth disconnect). Add a restart-on-error fallback.
- **Pending record** — `TranscriptionStatus.pending` case already exists. No migration needed.
- **Re-transcribe sheet** — introducing a sheet-based progress view is simpler than hijacking PipelineCoordinator state, but means two different progress UIs exist (overlay for live, sheet for re-transcribe). This is acceptable since they serve different contexts.
- **Form layout change** — removing `.roundedBorder` and manual HStacks changes the visual appearance of all settings. Must verify every section still looks correct.
- **Sound preset storage** — stored as a raw string in UserDefaults. If preset name changes, falls back to default.

---

## Testing Plan — BLOCKING

### Automated Checks
- [ ] `swift build` compiles without errors
- [ ] `swift test` passes all tests

### Manual Verification

1. **Sound quality**: Open settings → Sound → select each preset → click Preview. All should sound pleasant, not scratchy. Trigger a live recording and verify tones play at each stage.
2. **Recording persistence**: Start recording, say something, trigger send phrase. While transcribing, force-quit the app (`kill -9`). Reopen app. Verify the recording appears in history as pending/failed with audio playable.
3. **AI failure overlay**: Configure AI with invalid API key. Record and transcribe. Overlay should show green "Transcription successful" + red "AI cleanup failed" with the specific error reason.
4. **Re-transcription progress**: Open a history record. Click Re-transcribe. Verify a sheet appears showing transcribing → cleaning → complete stages. Text updates in detail view without clicking away.
5. **History click responsiveness**: Click rapidly through different history entries. Each click should immediately show the selected record's detail.
6. **History detail layout**: Copy buttons are top-right. Folder and Model are compact at top. No misaligned "Recording" label.
7. **Settings form layout**: All text fields show label-left, control-right without manual borders. Wake Phrase, Send Phrase, Insert Phrase all aligned properly. No extra spacing or mis-aligned text.
8. **Regression**: Wake phrase, send phrase, insert phrase, cancel overlay, copy behavior, multi-shortcut all still work.

### Edge Cases
- [ ] Audio engine interruption during tone playback — should recover gracefully
- [ ] Sound preset changed while tone is playing — should finish current tone, use new preset next time
- [ ] Re-transcription while another transcription is in progress — sheet should show error or queue
- [ ] Empty history with no records — detail view shows placeholder
- [ ] Pending records in history — should show "Pending" status badge and allow re-transcription

---

## Rollback Plan

- Revert `AudioSignalPlayer.swift` — restore per-tone engine approach
- Revert `PipelineCoordinator.swift` — remove pending record logic
- Revert `PipelineState.swift` — remove `cleanupFailureReason`
- Revert `RecordingOverlayView.swift` — restore simple caption
- Revert `HistoryListView.swift` — restore original layout and selection logic
- Revert `MainWindowView.swift` — restore manual form layout
- Revert `PreferencesView.swift` — restore roundedBorder style
- Revert `Settings.swift` — remove `soundPreset`
- Revert `AppDelegate.swift` — remove settings from AudioSignalPlayer

---

## Post-Implementation Checklist

**Gate 1 — Code complete:**
- [ ] All 11 implementation steps complete

**Gate 2 — Testing (BLOCKING):**
- [ ] `swift build` clean
- [ ] `swift test` all pass
- [ ] Manual: sound presets verified (all 4 pleasant)
- [ ] Manual: recording persistence verified (force-kill test)
- [ ] Manual: AI failure overlay with reason verified
- [ ] Manual: re-transcription progress sheet verified
- [ ] Manual: history click responsiveness verified
- [ ] Manual: history detail layout polished
- [ ] Manual: settings form native layout verified
- [ ] Regression checks passed

**Gate 3 — Documentation & logging (only after Gate 2):**
- [ ] `docs/logic/audio.md` updated (sound presets)
- [ ] `docs/logic/core.md` updated (pending record flow)
- [ ] `docs/logic/menubar-ui.md` updated (detail layout, form layout)
- [ ] Task logged to `docs/task/logs/2026-03-29.md`
- [ ] Observations logged

**Gate 4 — Close out:**
- [ ] Plan status → **Complete**
- [ ] Plan file moved from `draft/` to `completed/`
