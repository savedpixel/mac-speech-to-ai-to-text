# Audio System

<!-- Voice capture, recording sessions, media pause/resume, beep signals. -->

<!-- Updated: 2026-03-30 -->

---

## Architecture

- **Recording:** AVAudioEngine / AVAudioRecorder for microphone capture
- **Microphone Selection:** Explicit core audio node device routing utilizing `kAudioOutputUnitProperty_CurrentDevice` on the input node's audio unit. Listeners automatically restart upon routing changes.
- **Playback:** AVAudioPlayer for in-app recording playback
- **Media Control:** System-level media pause/resume via MediaPlayer framework or AppleScript
- **Audio Signals:** Short beep playback to indicate recording start/stop
- **Send Phrase Detection:** Silence threshold monitoring after spoken trigger phrase

## Key Behaviors

- Background media (Spotify, YouTube, etc.) is paused before recording starts
- A readiness beep plays after media is paused to signal recording is active
- Recording continues until send phrase + silence threshold is met
- After transcription completes, paused media can optionally resume
- **Recordings are always preserved:** Audio is copied to history directory before transcription begins
- Failed transcriptions retain the audio file for later re-transcription

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
