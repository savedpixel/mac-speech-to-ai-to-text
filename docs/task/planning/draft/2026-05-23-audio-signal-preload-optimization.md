# Audio Signal Preload Optimization

<!-- Updated: 2026-05-23 -->

Relevant Lessons:

- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.
- Intermittent audio/microphone failures need persistent app-owned diagnostic logs before claiming the issue is fixed.

## Problem

Shortcut/start and send-confirmation sounds sometimes play, sometimes do not, and can feel scratchy/slow. The current signal path creates `AVAudioPlayer` from the bundled WAV URL at the moment the user presses the shortcut or the send phrase is accepted. That adds disk/player setup work exactly when the app is also changing microphone state.

## Goal

Make signal playback faster and more reliable by preparing sound assets before they are needed and logging timing/result details for each beep.

## Plan

1. Preload all bundled sound preset data at app launch and when `AudioSignalPlayer` is initialized.
2. Create players from cached in-memory data for each beep instead of reading the WAV from disk on demand.
3. Warm up the currently selected preset during launch.
4. Add timing diagnostics for player creation, prepare, play start, duration, volume, preset, and active-player count.
5. Keep current behavior: shortcut beep before recording starts; send-accepted double beep before transcription starts.
6. Bump version/build, run `swift build`, run `bash scripts/build-app.sh`, and verify visible version.
