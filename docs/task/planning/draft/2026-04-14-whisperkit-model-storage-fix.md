# Plan: Fix WhisperKit Model Storage & Loading Reliability

> **Status:** Draft
> **Created:** 2026-04-14
> **Estimated steps:** 5
> **Risk level:** Medium
>
> **Status Lifecycle:**
> - `Questions Pending` → created with open questions (initial state)
> - `Draft` → all questions answered, plan awaiting approval
> - `In Progress` → user approved, implementation started (via execute-plan)
> - `Complete` → all gates passed, committed, plan moved to `completed/`

## Context

WhisperKit models fail to load after app restart. The error `Could not open .../TextDecoder.mlmodelc/weights/weight.bin` indicates the downloaded model is corrupt or incomplete. The app then re-downloads the entire model on every launch. Models are stored in `~/Documents/huggingface/` (Hub default), which uses a blob/snapshot/symlink structure that's fragile and prone to corruption.

## Current State

**TranscriptionEngine.swift** — Model loading (lines 121–162):
- `scanDownloadedModels()` checks only that a directory *exists* matching `openai_whisper-*` — no file integrity validation
- `loadModel()` passes the model subdirectory as `modelFolder` to WhisperKitConfig
- On load failure, `modelState` is set to `.failed` with no recovery attempt
- Models stored in `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` (Hub default)

**Failure sequence:**
1. App downloads model → stored in Hub cache with symlinks
2. App closes → symlinks or blob references may become stale
3. App reopens → `scanDownloadedModels()` finds directory (passes check)
4. `loadModel()` passes path to WhisperKit → CoreML can't open `weight.bin` → failure
5. User retries → falls through to "no local model" path → full re-download

## Target State

1. Models stored in `~/Library/Application Support/MacVoice/Models/` (standard, robust, no symlinks)
2. Model integrity validated before declaring "downloaded" (check for `.mlmodelc` dirs with `weight.bin`)
3. On load failure: auto-delete corrupt model directory and retry with fresh download (one retry)
4. Pass the **parent** models directory as `modelFolder` (not the model-specific subdirectory) — aligns with WhisperKit's API semantics

## Confirmed Inputs

- **Q1:** Model variant → `large-v3-turbo`
- **Q2:** Storage location → Application Support (hidden, standard macOS convention)

## Open Questions for User — BLOCKING

None — all questions resolved.

## Implementation Steps

- [ ] **Step 1: Add model storage directory in Application Support**
  - Files: `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift`
  - What: Add a computed property `modelStorageDirectory` that returns `~/Library/Application Support/MacVoice/Models/`. Create the directory on first access if it doesn't exist.
  - Why: Replaces the fragile `~/Documents/huggingface/` Hub cache with a stable, app-controlled directory.

- [ ] **Step 2: Update `scanDownloadedModels()` to use new path + validate integrity**
  - Files: `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift`
  - What: Change scan from `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` to `modelStorageDirectory`. Add validation: a model is only considered "downloaded" if it contains at least one `.mlmodelc` subdirectory that itself contains a `weights/weight.bin` file. Also scan the legacy Hub path — if valid models exist there, include them (for migration/backwards compat).
  - Why: Prevents corrupt/incomplete directories from being treated as usable models.

- [ ] **Step 3: Update `loadModel()` to use `modelFolder` correctly + auto-retry**
  - Files: `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift`
  - What:
    1. Pass `modelStorageDirectory` (the **parent** directory) as `modelFolder` in `WhisperKitConfig`, not the model-specific subdirectory. WhisperKit appends the model name internally.
    2. When loading, always specify `modelFolder` so WhisperKit downloads into our controlled directory (not Hub default).
    3. On load failure: log the error, delete the corrupt model directory, and retry **once** with a fresh download. If the retry also fails, set `.failed` state as before.
  - Why: Ensures models always go to the right place and corrupt downloads are auto-recovered.

- [ ] **Step 4: Update `deleteModel()` to handle both locations**
  - Files: `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift`
  - What: `deleteModel()` already works with the `path` property of `DownloadedModel`. Since scan now includes both legacy and new paths, deletion will work for either. No changes needed — just verify.
  - Why: Ensures user can still delete models from either location.

- [ ] **Step 5: Build, test, and verify**
  - What: Build with `swift build`. Rebuild app bundle. Launch app. Verify model downloads to Application Support. Close app, reopen, verify model loads from cache without re-download. Test model deletion from UI.
  - Why: End-to-end verification of the fix.

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `MacSpeechToAIToText/Transcription/TranscriptionEngine.swift` | Modify | New storage dir, integrity checks, retry logic, correct `modelFolder` usage |

## Dependencies & Risks

- **WhisperKit `modelFolder` semantics** — Need to confirm WhisperKit treats `modelFolder` as the parent directory (it appends model name). If it treats it as the exact model path, Step 3 adjusts accordingly.
- **Migration** — Users with existing models in `~/Documents/huggingface/` won't lose them. Scan checks both locations. Over time, models migrate naturally as users redownload.
- **Disk space** — No automatic migration/copy to avoid doubling storage. Old models stay until user deletes them or clears the Hub cache manually.
- **large-v3-turbo naming** — The model directory uses `large-v3_turbo` (underscore). The existing normalization in `localModelPath()` converts underscores to hyphens for matching. This should continue to work.

## Testing Plan — BLOCKING (execute BEFORE docs or completion)

### Automated Checks
- [ ] `swift build` compiles without errors
- [ ] `swift test` passes all tests

### Manual Verification

1. Build and launch the app
2. Select `large-v3-turbo` model in settings
3. Verify model downloads to `~/Library/Application Support/MacVoice/Models/`
4. Quit app completely
5. Reopen app — verify model loads from cache (no re-download)
6. Record and transcribe — verify transcription works
7. Check "Downloaded Models" section in settings — verify model appears with correct size

### Regression Checks
- [ ] Model picker in settings still shows available/downloaded models
- [ ] Model deletion from settings UI works
- [ ] Changing model in settings triggers download of new model to correct location

### Edge Cases
- [ ] Corrupt model directory (missing weight.bin) → auto-deletes and redownloads
- [ ] First launch with no models → downloads to Application Support
- [ ] Existing model in legacy ~/Documents/huggingface/ → appears in scan

**STOP: Do NOT proceed to docs or completion until ALL tests pass.**

## Rollback Plan

Revert the single changed file (`TranscriptionEngine.swift`) to its previous state. Models in Application Support can be deleted manually.

## Post-Implementation Checklist

**Gate 1 — Code complete:**
- [ ] All implementation steps complete

**Gate 2 — Testing (BLOCKING):**
- [ ] All automated checks passed
- [ ] All manual verification executed
- [ ] All regression checks executed

**Gate 3 — Documentation & logging (only after Gate 2):**
- [ ] Documentation updated
- [ ] Task logged
- [ ] Observations logged

**Gate 4 — Close out:**
- [ ] Plan status → **Complete**
- [ ] Plan file moved from `draft/` to `completed/`
