# Transcription System

<!-- Local Whisper model integration for speech-to-text + AI cleanup post-processing. -->

<!-- Updated: 2026-06-01 -->

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
- **Downloaded models:** `TranscriptionEngine.scanDownloadedModels()` scans the configured Hub base path at `.../models/argmaxinc/whisperkit-coreml/` and falls back to the legacy default under `~/Documents/huggingface/`
- **Deletion:** `TranscriptionEngine.deleteModel(_:)` removes a model's local cache directory
- **Settings:** `whisperModel` is stored as a plain `String` (not an enum) for forward compatibility
- **Selection persistence:** Downloaded models are the primary active-model selector in Settings, and that selection persists through `Settings.whisperModel`
- **Cache reuse:** Local cached-model loads pass both the exact model folder and the configured base path so WhisperKit can also reuse the matching tokenizer cache on relaunch
- **Recovery:** Failed local loads only trigger delete-and-redownload when the on-disk model files are missing or unreadable; tokenizer/path failures leave the cached model intact
- **Integrity scan:** Downloaded models are only listed when their local folders contain compiled model assets and weights.
- **On-demand loading:** App launch now scans local models and restores the selected model name without immediately initializing WhisperKit; actual model loading happens when transcription starts or when a new model is explicitly downloaded
- **Startup readiness:** `TranscriptionEngine.transcribe(...)` waits for the selected model load to finish instead of failing fast when the model is not yet initialized in memory
- **Preparation vs download:** Local cached-model warmup is surfaced separately from true model download state
- **UI:** Settings shows the active model, downloaded model list with sizes and `Use`, plus a separate `Download & Use` control for models not yet stored locally

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
- **Timeouts:** 20 seconds per request and 30 seconds per resource through a reusable ephemeral `URLSession`
- **Prompt system:** User-defined cleanup prompts stored in `PromptStore`
  - One built-in default prompt (not deletable)
  - User can create custom prompts
  - Default prompt selected in Settings, always used for cleanup
- **Fallback:** On API failure, raw transcription shown with warning badge
- **Provider diagnostics:** HTTP error bodies are parsed for provider messages, and diagnostic logs record provider/model/status/elapsed time without API keys
- **Response parsing:** Accepts standard OpenAI-compatible `choices[].message.content`, text-completion `choices[].text`, and text-part arrays used by compatible providers
- **Latency behavior:** Short cleanup/translation/extraction prompts use a smaller dynamic `max_tokens` ceiling while longer prompts can still use up to 2048 tokens
- **API key:** Stored in macOS Keychain (never in UserDefaults or plaintext)

## Common Patterns

- Use WhisperKit for on-device inference
- Keep selection persistence separate from runtime model initialization
- Always gate transcription on selected-model readiness instead of relying on app-launch preloading
- Support multiple model sizes configurable by user (dynamic list from WhisperKit)
- Actor isolation for `TranscriptionCleaner` ensures thread safety
