# Shortcut Press Beep Before Recording

<!-- Updated: 2026-05-23 -->

Relevant Lessons:

- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.

## Problem

The recording-start beep is visible in the waveform, which means it is playing after the microphone is already recording. The user wants the beep immediately when pressing the shortcut key, before recording starts.

## Goal

Play the audible confirmation beep at shortcut activation time before recorder startup, and do not play the recording-start beep after the recorder is live.

## Plan

- Trigger the beep immediately in `PipelineCoordinator.runPipeline()` before `audioRecorder.startRecording()`.
- Await the beep before starting the recorder so it is not captured in the recording waveform.
- Remove the post-recorder-start beep.
- Log shortcut-press beep settings/result.
- Bump version/build, build/package/reopen, and verify visible version.
