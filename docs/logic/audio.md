# Audio System

<!-- Voice capture, recording sessions, media pause/resume, beep signals. -->

<!-- Updated: 2026-05-24 -->

---

## Architecture

- **Recording:** AVAudioEngine-backed microphone capture with rolling PCM waveform sampling for the live overlay
- **Microphone Selection:** Explicit core audio node device routing utilizing `kAudioOutputUnitProperty_CurrentDevice` on the input node's audio unit. Listeners automatically restart upon routing changes.
- **Playback:** AVAudioPlayer for in-app recording playback
- **Media Control:** System-level media pause/resume via MediaPlayer framework or AppleScript
- **Audio Signals:** Retained `AVAudioPlayer` playback for short beeps indicating recording start, recording finish, transcription milestones, and insert confirmation
- **Send Phrase Detection:** Speech framework phrase recognition fed from the active recorder buffers, plus silence threshold monitoring after the spoken trigger phrase

## Key Behaviors

- Send phrase confirmation now plays an explicit double beep before transcription starts, confirming the voice note was accepted and sent.
- Send phrase detection restarts its Speech recognition request after normal no-speech/session-finished callbacks without rebuilding the recorder.
- Background media (Spotify, YouTube, etc.) is paused before recording starts
- The overlay stays in `Preparing…` until the recorder is fully live; it only switches to the recording state once capture actually starts
- A shortcut confirmation beep plays immediately after the shortcut is accepted and before recorder startup, so it is audible and is not captured in the recording waveform
- A second acknowledgement beep plays immediately when recording is finished by the send phrase or the `Done` button
- Recording continues until send phrase + silence threshold is met
- As soon as recording stops and transcription begins, paused media can optionally resume
- **Recordings are always preserved:** Audio is copied to history directory before transcription begins
- Failed transcriptions retain the audio file for later re-transcription

## Microphone Contention Recovery

- Recorder startup now retries transient `AVAudioEngine` start failures with short backoff before showing a recording error.
- Preferred microphone routing falls back to the current system input if the saved input device cannot be applied at startup.
- `AVAudioEngineConfigurationChange` notifications are treated as advisory: if the active format is unchanged, the recorder keeps the existing engine, or restarts that same engine if macOS stopped it during the configuration notification, instead of tearing the recorder down.
- This prevents Bluetooth/headset and speech-recognition route churn from causing repeated microphone flicker during an otherwise healthy recording.
- Send phrase recognition sessions can restart independently after normal Speech framework timeouts without forcing the recorder engine to rebuild.

## Diagnostic Logging

- Beep WAV data is preloaded and cached at launch; playback creates players from memory and logs data-load, creation, prepare, play-call, and total start latency to diagnose slow or scratchy signal timing.
- Shortcut pre-recording diagnostics now log beep enabled state, volume, preset, and whether AVAudioPlayer reported that playback started before recorder startup.
- Persistent diagnostic logging can be enabled from Settings and writes to `~/Library/Application Support/MacVoice/Diagnostics/macvoice-diagnostics-YYYY-MM-DD.log`.
- Audio startup logs include selected microphone ID, Bluetooth route priming, input format, engine start attempts, route/config-change decisions, same-format engine restarts, rebuild failures, and recording stop URLs.
- This file is intended to diagnose intermittent microphone contention after another app, such as Codex, has just used the microphone.

## Recording Startup Stability

- Bluetooth-specific route priming only runs for Bluetooth microphones; USB and wired microphones no longer pay the same fixed settle delay
- `AVAudioEngineConfigurationChange` handling is debounced so route churn coalesces into a single rebuild instead of repeated teardown/restart loops
- Recorder rebuilds reuse the current output file when a real rebuild is required, preventing stable recordings from losing the in-progress audio file

## Recording Overlay Waveform

- `AudioRecorder` now keeps a rolling window of signed PCM samples from the live microphone tap
- The recording overlay renders that sample history as a single centerline waveform, so silence naturally sits in the middle and speech moves above/below the baseline
- The overlay timer is driven directly from `recordingStartDate` on the live recorder instead of a copied snapshot

## Notification Sound Defaults

- Retained signal players keep beep playback objects alive until each sound finishes, preventing intermittent missing beeps caused by short-lived playback objects.
- Insert phrase completion uses the configured notification sound as a confirmation beep after non-empty text is inserted.
- The notification sound setting is sanitized on load and assignment
- If a stored preset is missing or invalid, settings fall back to the first `SoundPreset` entry automatically

## Media Resume Timing

- Media is paused during recording setup so speech capture starts cleanly
- If auto-resume is enabled, playback resumes at the recording → transcription handoff
- Copying or inserting the final text no longer delays media playback resumption

## Recording Retention

- Audio files stored in `~/Library/Application Support/MacVoice/recordings/`
- Each recording saved as `{UUID}.wav`
- **No count-based pruning:** Recordings are kept indefinitely by default
- **Time-based auto-delete:** Configurable deletion after N days (default: never)
  - Options: Never, 7 days, 30 days, 90 days, 1 year
  - `HistoryStore.pruneOldRecordings(olderThanDays:)` runs on app launch

## Audio Playback

- `AudioPlayer` wraps `AVAudioPlayer` for simple .wav playback
- Play, pause, stop, seek controls
- Real-time progress tracking (current time, duration, progress fraction)
- Playback UI integrated into History detail view
- Available for all recordings with an associated audio file

## Common Patterns

- Use `AVAudioEngine`, CoreAudio input-device routing, and `AVAudioEngineConfigurationChange` handling for managing microphone capture on macOS.
- Monitor audio levels and signed PCM buffers for silence detection, waveform display, and listener health diagnostics.
- Configurable silence threshold duration in user preferences
