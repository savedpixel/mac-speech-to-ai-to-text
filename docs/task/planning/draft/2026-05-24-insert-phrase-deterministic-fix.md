# Insert Phrase Deterministic Fix

Date: 2026-05-24

## Problem

The spoken insert phrase still intermittently fails after the transcription is complete. Diagnostics show the completed-state listener starts, but the Speech recognizer can sit for 10 seconds with no partial transcripts before restarting, so the user can say "insert" and nothing happens.

## Plan

- Inspect the latest persistent diagnostics for insert phrase startup, audio buffers, partial transcripts, and insert handoff.
- Make the insert phrase Speech listener less fragile by recreating recognizer sessions, avoiding forced on-device recognition for this short command, and adding explicit audio-buffer health diagnostics.
- Keep the listener self-healing when Speech stalls, but make the logs clearly show whether the failure is no input buffers or no Speech partials.
- Update input docs, lessons/todo/logs, bump the visible app version/build, rebuild/package/sign, close the old app, reopen the new app, and verify the visible version.

## Verification

- `swift build`
- `bash scripts/build-app.sh`
- Visual verification that the reopened app shows the bumped version/build.
- Persistent diagnostics should show first-buffer and listener-mode details during the next real-world test.
