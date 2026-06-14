# Plan: Recording Overlay Waveform, Sound Defaults, Send/Insert Trigger Fixes

> **Status:** Complete
> **Created:** 2026-04-01
> **Estimated steps:** 5
> **Risk level:** Medium

---

## Context

The recording overlay regressed in several connected ways:

1. The live waveform is rendered as a red graph instead of a more neutral audio meter.
2. The elapsed time counter stays at `00:00,00` while recording.
3. The waveform does not visibly breathe with speech and feels zoomed too far out.
4. The notification sound picker can load with no selected value.
5. Finishing a recording via send phrase or the `Done` button gives no immediate audio acknowledgement.
6. The insert phrase path no longer triggers insertion after transcription completes.

These issues span the overlay UI, audio recorder state propagation, settings sanitization, signal playback timing, and post-transcription insert listening.

---

## Current State

### Overlay waveform and timer
- `RecordingOverlayView` passes plain value snapshots (`currentAudioLevel`, `recordingStartDate`) into `AudioWaveformView` and `RecordingTimeCounter`.
- `AudioWaveformView` appends waveform samples only when `audioLevel` changes, so the graph can stall instead of scrolling smoothly.
- The waveform color is hardcoded red.
- The current sample density keeps too much history on screen, so the graph reads as zoomed out.

### Sound preset selection
- `Settings.soundPreset` is stored as a raw string.
- If the stored string no longer matches an enum case, the `Picker` has no valid selected tag.
- Default registration currently targets a specific preset instead of the first menu option.

### Send phrase / Done acknowledgement
- The pipeline plays a ready beep at recording start and completion beeps after transcription/cleanup.
- There is no immediate sound when recording ends due to the send phrase or `Done`.

### Insert phrase
- `PipelineCoordinator.transition(to:)` only starts `InsertPhraseListener` in the completed state when `keepMicrophoneConnected` is enabled.
- That prevents insert phrase activation for the common on-demand mic flow.

---

## Target State

1. The overlay shows a responsive live waveform that updates continuously during recording, uses a non-red palette, and displays a visibly zoomed-in signal.
2. The recording timer increments reliably from the current recording start time.
3. The notification sound picker always resolves to a valid preset and defaults to the first dropdown entry.
4. Ending a recording with the send phrase or `Done` immediately plays an acknowledgement sound.
5. The insert phrase listener can activate after transcription completes even when the microphone is not kept connected while idle.

---

## Implementation Steps

### Step 1: Fix overlay waveform rendering and timer updates
- Update `MacVoice/UI/AudioWaveformView.swift` to render from live signed PCM sample history captured by `AudioRecorder`, so silence remains centered and speech moves above/below the baseline.
- Replace the hardcoded red visual treatment with a calmer waveform/cursor palette.
- Update `MacVoice/UI/RecordingOverlayView.swift` to pass the recorder object into waveform/time components.

### Step 2: Sanitize sound preset selection
- Update `MacVoice/Audio/AudioSignalPlayer.swift` and/or `MacVoice/Core/Settings.swift` so the first `SoundPreset.allCases` entry is the default.
- Normalize invalid persisted preset values back to a valid first option on load and assignment.

### Step 3: Add finish acknowledgement sound
- Update `MacVoice/Core/PipelineCoordinator.swift` to play an acknowledgement sound immediately after recording stops, for both send-phrase and manual `Done` completion paths.

### Step 4: Restore insert phrase activation
- Update `MacVoice/Core/PipelineCoordinator.swift` so the insert phrase listener starts in the completed state whenever insert phrase is enabled and permissions/runtime conditions allow, not only when the idle mic remains connected.
- Keep teardown behavior intact when leaving the completed state.

### Step 5: Build and verify
- Run `swift build`.
- Rebuild the app bundle and relaunch the app per project policy.
- Run `swift test` if the build passes.
- Manually verify the overlay animation, timer, sound preset default, send/done acknowledgement, and insert phrase behavior.

---

## Files Expected To Change

| File | Action | Purpose |
| --- | --- | --- |
| `MacVoice/UI/AudioWaveformView.swift` | Modify | Responsive waveform/timer data flow and visual tuning |
| `MacVoice/UI/RecordingOverlayView.swift` | Modify | Pass live recorder state into overlay subviews |
| `MacVoice/Core/Settings.swift` | Modify | Sanitize sound preset defaults |
| `MacVoice/Audio/AudioSignalPlayer.swift` | Modify | Sound preset default helper and finish acknowledgement playback reuse |
| `MacVoice/Core/PipelineCoordinator.swift` | Modify | Finish beep timing and insert phrase activation |

---

## Testing Plan — BLOCKING

### Automated Checks
- [x] `swift build` succeeds
- [x] `swift test` succeeds
- [x] App bundle rebuild succeeds

### Manual Verification
- [x] User verified that the waveform now behaves correctly as a centered audio waveform
- [x] User verified that the waveform presentation now matches the requested overlay direction well enough to continue
- [x] Open Sound settings and confirm the first sound is selected automatically
- [x] Finish recording by send phrase and hear an immediate acknowledgement sound
- [x] Finish recording by `Done` and hear the same acknowledgement sound
- [x] After transcription completes, say the insert phrase and confirm insertion occurs

### Not Tested
none

---

## Rollback Plan

- Revert overlay waveform/timer changes in `AudioWaveformView.swift` and `RecordingOverlayView.swift`
- Revert sound preset sanitization in `Settings.swift` / `AudioSignalPlayer.swift`
- Revert finish acknowledgement and insert phrase changes in `PipelineCoordinator.swift`
