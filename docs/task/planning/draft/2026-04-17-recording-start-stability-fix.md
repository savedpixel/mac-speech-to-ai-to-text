# Plan: Fix Recording Start Stability

> **Status:** In Progress
> **Created:** 2026-04-17
> **Estimated steps:** 3
> **Risk level:** Medium

## Context

Recording startup is inconsistent. The overlay can enter the recording state before the microphone is actually live, the timer feels glitchy, and the first words are sometimes missed. Recent app logs also show bursts of `Audio engine config changed — rebuilding engine` immediately after recording starts.

## Current State

- `PipelineCoordinator.runPipeline()` transitions to `.recording` before `AudioRecorder.startRecording()` finishes
- `AudioRecorder.startRecording()` always runs a route-settling probe and waits `800ms` whenever the probe succeeds, even for non-Bluetooth devices
- Current logs show the selected microphone is a USB device, but it still pays the same startup penalty
- `AudioRecorder.handleConfigChange()` rebuilds the engine immediately on every notification, which can cause a rebuild loop while the route is still settling

## Root Cause

The app currently combines three problems:

1. The overlay says recording has started before the recorder is actually ready
2. Non-Bluetooth microphones still incur Bluetooth-specific startup delay
3. Configuration change handling is not debounced, so one route churn event can trigger repeated rebuilds and unstable capture

## Target State

1. The overlay stays in `Preparing…` until the recorder is live
2. Only Bluetooth microphones pay the extra route-settling probe cost
3. Engine configuration changes are coalesced into a single rebuild after the route settles

## Implementation Steps

- [x] **Step 1: Stabilize recorder startup path**
  - Files: `MacSpeechToAIToText/Audio/AudioRecorder.swift`
  - Gate the route-settling probe behind Bluetooth transport detection
  - Skip the long startup wait for wired/USB microphones

- [x] **Step 2: Debounce engine config rebuilds**
  - Files: `MacSpeechToAIToText/Audio/AudioRecorder.swift`
  - Replace immediate rebuild-on-notification with a short debounce window
  - Ignore re-entrant notifications while a rebuild is already in progress

- [x] **Step 3: Align UI state with actual recorder readiness**
  - Files: `MacSpeechToAIToText/Core/PipelineCoordinator.swift`, `docs/logic/audio.md`
  - Keep the pipeline in `Preparing…` until `startRecording()` succeeds
  - Build, relaunch, and verify the startup log flow

## Testing Plan

- [x] `swift build`
- [ ] `swift test`
- [x] Rebuild app bundle and relaunch
- [ ] Start recording with the current USB microphone
- [ ] Confirm the overlay stays in `Preparing…` until the recorder is active
- [ ] Confirm logs no longer show rapid repeated `Audio engine config changed — rebuilding engine` loops during startup
- [ ] Confirm speech is captured immediately once the recorder becomes active
