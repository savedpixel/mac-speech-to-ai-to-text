# Plan: Fix Whisper Model Selection Persistence And Startup Readiness

> **Status:** In Progress
> **Created:** 2026-04-17
> **Estimated steps:** 3
> **Risk level:** Medium

## Context

After a force quit or relaunch, the app can reach transcription before the selected Whisper model is ready in memory. When that happens, the pipeline throws `Whisper model is not loaded`, and the user may then see the app fall back into an unnecessary download flow even though the model already exists on disk. The settings UI also exposes downloaded models only as deletable items, with no explicit way to mark one as the model that should always be used.

## Current State

- `AppDelegate` starts a background `transcriptionEngine.loadModel()` task at launch
- `PipelineCoordinator.finalizePipeline()` calls `transcriptionEngine.transcribe(...)` directly
- `TranscriptionEngine.transcribe(...)` throws immediately when `whisperKit` is still nil
- The main settings screen lists downloaded models with a `Delete` action only
- The selected model persists in `settings.whisperModel`, but the downloaded-models UI does not surface that selection clearly

## Root Cause

The app currently relies on startup preloading to finish before the user reaches transcription, which is not safe for large models or after force-quit recovery. There is no explicit "ensure the selected model is ready now" step on the critical transcription path, and the settings UI does not give the user a direct "use this downloaded model" action that maps clearly onto the persisted selection.

## Target State

1. The selected Whisper model is treated as the source of truth and persists across relaunches
2. Starting a transcription waits for the selected model to be ready instead of failing fast
3. Downloaded models in settings expose the only active-model selection control
4. The UI clearly distinguishes local model preparation from an actual download
5. A model is downloaded only when the selected model does not already exist locally

## Implementation Steps

- [x] **Step 1: Make transcription block on selected-model readiness**
  - Files: `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift`, `MacSpeechToAIToText/Core/PipelineCoordinator.swift`
  - Add an "ensure selected model is loaded" path before transcription starts
  - Reuse any in-flight load instead of starting duplicate loads

- [x] **Step 2: Make downloaded models the primary selection UI**
  - Files: `MacSpeechToAIToText/UI/MainWindowView.swift`
  - Remove the redundant active-model dropdown
  - Make `Use` on a downloaded model the source of truth for active model selection
  - Prevent accidental duplicate reloads and deletion of the selected model

- [x] **Step 3: Separate local preparation state from download state**
  - Files: `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift`, `MacSpeechToAIToText/UI/MainWindowView.swift`
  - Show local cached-model warmup as preparation, not download
  - Only expose cancel affordance for actual download work if needed

- [ ] **Step 4: Sync docs and verify relaunch behavior**
  - Files: `docs/logic/transcription.md`, `docs/logic/menubar-ui.md`
  - Rebuild and relaunch the app
  - Confirm the selected local model is reused after a relaunch or force quit

## Testing Plan

- [x] `swift build`
- [ ] `swift test`
- [x] Rebuild app bundle and relaunch
- [ ] Confirm a first transcription after relaunch waits for the selected model instead of failing with `modelNotLoaded`
- [ ] Confirm clicking `Use` updates the active model and persists it across restart without any redundant picker interaction
- [ ] Confirm local cached-model startup shows preparation instead of download wording
- [ ] Confirm no redownload occurs when the selected model already exists locally
