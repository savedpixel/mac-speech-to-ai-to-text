# Audio, Insert Phrase, and Target Restoration Stability

<!-- Updated: 2026-05-23 -->

## Problem

Shortcut recording and post-processing still have reliability issues:

- Beeps do not always play.
- Recording startup can be fragile when other microphone-using apps are open.
- Insert phrase handling is unreliable after transcription completion.
- Insertions currently paste into whichever app is frontmost at insertion time, not necessarily the app/input where recording was triggered.

## Goals

1. Make app sounds reliably play by retaining playback objects until each sound finishes.
2. Reduce microphone/listener contention around shortcut recording and insert phrase listening.
3. Make insert phrase listening more tolerant of recognizer/session endings and startup failures.
4. Capture the triggering app and focused accessibility element at activation time, then restore that target before auto-insert, insert phrase, send-phrase completion auto-insert, or manual Insert.
5. Keep changes minimal and avoid redesigning the overlay or settings UI.

## Implementation Plan

### Step 1 — Target capture and restore

- Extend `TextInserter` to save the frontmost app PID/bundle/name plus focused AX element.
- On insertion, reactivate the saved app and attempt to refocus the saved AX element before clipboard paste.
- Keep clipboard paste as the universal fallback for Electron, browsers, and VS Code/Codex-like inputs.
- Add small activation/focus delays before paste/submit so moving away during recording/transcription does not redirect the result.

### Step 2 — Reliable beep playback

- Replace short-lived `NSSound` local playback with retained `AVAudioPlayer` instances.
- Keep players alive for the audio duration and clean them up afterward.
- Log missing sound files and playback preparation failures.

### Step 3 — Insert phrase stability

- Request/check speech authorization before starting.
- Configure the recognition request for partial dictation/on-device recognition when available.
- Guard invalid input formats.
- Retry transient audio-engine or recognizer endings while completed-state listening is desired.
- Stop the listener cleanly once insertion is triggered.

### Step 4 — Pipeline/listener handoff

- Ensure activation captures the insertion target before the overlay/app can steal focus.
- Stop passive listeners during recording startup and avoid clearing the captured insertion target before result insertion.
- Keep mic release behavior intact after completion/dismiss.

### Step 5 — Docs and verification

- Update `docs/logic/audio.md`, `docs/logic/input.md`, and `docs/logic/core.md` as needed.
- Run `swift build`.
- Relaunch the app with the repo script if the build succeeds.
- Report any scenarios that still need user-side verification because they require real microphone/Codex UI interaction.
