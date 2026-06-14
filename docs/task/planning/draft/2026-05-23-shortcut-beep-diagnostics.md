# Shortcut Beep Diagnostics

<!-- Updated: 2026-05-23 -->

Relevant Lessons:

- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.
- Intermittent audio/microphone failures need persistent app-owned diagnostic logs before claiming the issue is fixed.

## Goal

When the shortcut is pressed and recording starts, diagnostics must clearly show whether the recording-start beep was attempted and whether AVAudioPlayer reported playback started.

## Plan

- Make `AudioSignalPlayer.playRecordingStartedBeep()` return a Bool playback result.
- Log beep enabled state, volume, preset, recording URL, and playback result from the pipeline immediately after recorder startup.
- Keep lower-level beep logs for file/player failures.
- Bump version/build, rebuild/package/reopen, and verify the visible version.
