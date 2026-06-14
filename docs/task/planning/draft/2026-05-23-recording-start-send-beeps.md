# Recording Start and Send Phrase Beep Reliability

<!-- Updated: 2026-05-23 -->

Relevant Lessons:

- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.
- Intermittent microphone/input failures need persistent app-owned diagnostic logs before claiming the issue is fixed.

## Problem

The user does not hear an audible beep when shortcut recording starts, and does not hear a beep when the send phrase is accepted and the app transitions into transcription.

## Goal

Make the two signal points reliable and explicit:

1. When the shortcut activates the mic and recording is actually live, play an audible recording-start beep.
2. When the send phrase confirms the voice note was sent, play an audible send-accepted/transcribing-start beep.

## Plan

- Move recording-start confirmation to after `audioRecorder.startRecording()` succeeds, instead of fire-and-forget before recorder startup.
- Add a dedicated send-accepted beep method and call it during finalize before transcription begins.
- Log both signal attempts to diagnostics so failures can be traced.
- Keep the existing transcription/AI completion beeps unchanged.
- Bump version/build, run Swift build, package/sign/reopen, and verify the visible app version.
