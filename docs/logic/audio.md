# Audio System

<!-- Voice capture, recording sessions, media pause/resume, beep signals. -->

<!-- Updated: 2026-04-02 -->

---

## Architecture

- **Recording:** AVAudioEngine-backed microphone capture with rolling PCM waveform sampling for the live overlay
- **Microphone Selection:** Explicit core audio node device routing utilizing `kAudioOutputUnitProperty_CurrentDevice` on the input node's audio unit. Listeners automatically restart upon routing changes.
- **Playback:** AVAudioPlayer for in-app recording playback
- **Media Control:** System-level media pause/resume via MediaPlayer framework or AppleScript
- **Audio Signals:** Short beep playback to indicate recording start, recording finish, and transcription milestones
- **Send Phrase Detection:** Silence threshold monitoring after spoken trigger phrase

## Key Behaviors

- Background media (Spotify, YouTube, etc.) is paused before recording starts
- A readiness beep plays after media is paused to signal recording is active
- A second acknowledgement beep plays immediately when recording is finished by the send phrase or the `Done` button
- Recording continues until send phrase + silence threshold is met
- As soon as recording stops and transcription begins, paused media can optionally resume
- **Recordings are always preserved:** Audio is copied to history directory before transcription begins
- Failed transcriptions retain the audio file for later re-transcription

## Recording Overlay Waveform

- `AudioRecorder` now keeps a rolling window of signed PCM samples from the live microphone tap
- The recording overlay renders that sample history as a single centerline waveform, so silence naturally sits in the middle and speech moves above/below the baseline
- The overlay timer is driven directly from `recordingStartDate` on the live recorder instead of a copied snapshot

## Notification Sound Defaults

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

- Use AVAudioSession for managing audio routing
- Monitor audio levels for silence detection
- Configurable silence threshold duration in user preferences
