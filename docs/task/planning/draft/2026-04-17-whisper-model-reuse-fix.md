# Plan: Fix Whisper Model Reuse On Relaunch

> **Status:** In Progress
> **Created:** 2026-04-17
> **Estimated steps:** 3
> **Risk level:** Medium

## Context

With a custom model storage path set to `~/Documents/macvoice`, the app still redownloads `large-v3_turbo` after a full app quit or system restart. The model is already present on disk and still appears in the Downloaded Models UI, but transcription fails at startup because the model never becomes ready in time.

## Current State

- `Settings.modelStoragePath` is persisted correctly and currently resolves to `/Users/chiefkeef/Documents/macvoice`
- The custom storage folder already contains:
  - `models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3_turbo`
  - `models/openai/whisper-large-v3/tokenizer.json`
- `TranscriptionEngine.loadModel()` loads a local cached model with `modelFolder` only
- When `downloadBase` is omitted on that local path, WhisperKit does not reuse the tokenizer cache under the custom base path
- Any local-load failure currently triggers model deletion and a full redownload, even if the failure is tokenizer/path related rather than model corruption

## Root Cause

The local cached-model path and the custom tokenizer cache path are split. On relaunch, the app points WhisperKit at the local model folder but does not also provide the same custom `downloadBase`, so tokenizer resolution falls back away from the chosen storage root. That failure is then misclassified as a corrupt local model, which causes a healthy model directory to be deleted and redownloaded.

## Target State

1. A cached model in the configured storage path loads directly on relaunch without redownloading
2. Local loads reuse the same `downloadBase` as downloads so tokenizer lookup stays inside the chosen storage root
3. Delete-and-redownload recovery only runs for genuine local model file corruption, not tokenizer/path failures

## Implementation Steps

- [x] **Step 1: Patch local cached-model loading**
  - Files: `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift`
  - Pass `downloadBase` alongside `modelFolder` when loading an already-downloaded model
  - Keep using the exact model folder for model binaries

- [x] **Step 2: Narrow the recovery path**
  - Files: `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift`
  - Only delete and redownload when the error indicates missing/unreadable local model files
  - Leave the cached model intact for tokenizer/path/network failures

- [x] **Step 3: Build and verify relaunch behavior**
  - Run `swift build` and `swift test`
  - Rebuild and relaunch the app
  - Verify the existing model under `~/Documents/macvoice` loads from cache on startup without a new download

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift` | Modify | Fix local model reuse and retry classification |
| `docs/logic/transcription.md` | Modify | Document custom storage + relaunch reuse behavior |

## Testing Plan

- [x] `swift build`
- [ ] `swift test`
- [x] Launch app with custom model storage path already populated
- [x] Confirm startup loads `large-v3_turbo` from cache
- [ ] Confirm transcription works immediately after launch
- [x] Confirm no model deletion/redownload occurs for the healthy cached model
