# Transcription System

<!-- Local Whisper model integration for speech-to-text + AI cleanup post-processing. -->

<!-- Updated: 2026-03-28 -->

---

## Architecture

- **Whisper Model:** Locally running Whisper model via WhisperKit
- **Model Discovery:** Dynamic model list fetched from WhisperKit remote; fallback to built-in list if offline
- **Model Management:** Downloaded models tracked with disk size; users can delete models to reclaim space
- **Pipeline:** Audio buffer → Whisper inference → Text output → (optional) AI cleanup
- **AI Cleanup:** Cloud-based post-processing via OpenAI-compatible API
- **Re-transcription:** Existing recordings can be re-transcribed with different models/prompts
- **No cloud dependency for base transcription:** All transcription happens on-device; AI cleanup is opt-in

## Key Behaviors

- Recorded audio is sent to Whisper after recording session ends
- Audio is saved to history **before** transcription — never lost on failure
- Transcription runs asynchronously to avoid blocking the UI
- Failed transcriptions create a record with `.failed` status and preserved audio
- After transcription, text optionally passes through `TranscriptionCleaner` for AI cleanup
- Cleaned text is presented to the user in a floating overlay (not auto-inserted)
- User chooses: Copy, Insert, or Dismiss

## Model Management

- **Discovery:** `TranscriptionEngine.fetchAvailableModels()` queries WhisperKit for available model variants
- **Downloaded models:** `TranscriptionEngine.scanDownloadedModels()` scans Hub cache at `~/Library/Caches/huggingface/hub/models--argmaxinc--whisperkit-coreml/snapshots/`
- **Deletion:** `TranscriptionEngine.deleteModel(_:)` removes a model's local cache directory
- **Settings:** `whisperModel` is stored as a plain `String` (not an enum) for forward compatibility
- **UI:** Settings shows dynamic model picker, downloaded model list with sizes, and delete buttons

## Re-transcription

- Users can re-transcribe any recording that has an audio file
- Re-transcription lets the user pick a different Whisper model and/or cleanup prompt
- If the selected model differs from the currently loaded one, it's loaded first
- Results update the existing `TranscriptionRecord` and append to `retranscriptionHistory`
- Re-transcription is blocked while the main recording pipeline is active

## Failure Tracking

- `TranscriptionRecord.transcriptionStatus`: `.success`, `.failed(String)`, or `.pending`
- `TranscriptionRecord.whisperModel`: which model was used
- `TranscriptionRecord.retranscriptionHistory`: array of previous re-transcription attempts
- Failed records appear in a dedicated "Failed" filter in History sidebar
- All new fields are optional with backward-compatible defaults for existing JSON data

## Post-Processing: AI Cleanup

- **Service:** `TranscriptionCleaner` (actor-isolated for thread safety)
- **API:** OpenAI-compatible chat completions endpoint (configurable)
- **Default model:** `gpt-4o-mini`
- **Timeout:** 15 seconds
- **Prompt system:** User-defined cleanup prompts stored in `PromptStore`
  - One built-in default prompt (not deletable)
  - User can create custom prompts
  - Default prompt selected in Settings, always used for cleanup
- **Fallback:** On API failure, raw transcription shown with warning badge
- **API key:** Stored in macOS Keychain (never in UserDefaults or plaintext)

## Common Patterns

- Use WhisperKit for on-device inference
- Handle model loading at app launch for faster first transcription
- Support multiple model sizes configurable by user (dynamic list from WhisperKit)
- Actor isolation for `TranscriptionCleaner` ensures thread safety
