# Audio System

<!-- Voice capture, recording sessions, media pause/resume, beep signals. -->

<!-- Updated: 2026-03-26 -->

---

## Architecture

- **Recording:** AVAudioEngine / AVAudioRecorder for microphone capture
- **Media Control:** System-level media pause/resume via MediaPlayer framework or AppleScript
- **Audio Signals:** Short beep playback to indicate recording start/stop
- **Send Phrase Detection:** Silence threshold monitoring after spoken trigger phrase

## Key Behaviors

- Background media (Spotify, YouTube, etc.) is paused before recording starts
- A readiness beep plays after media is paused to signal recording is active
- Recording continues until send phrase + silence threshold is met
- After transcription completes, paused media can optionally resume

## Common Patterns

- Use AVAudioSession for managing audio routing
- Monitor audio levels for silence detection
- Configurable silence threshold duration in user preferences
