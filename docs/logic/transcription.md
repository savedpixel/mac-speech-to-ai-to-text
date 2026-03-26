# Transcription System

<!-- Local Whisper model integration for speech-to-text. -->

<!-- Updated: 2026-03-26 -->

---

## Architecture

- **Whisper Model:** Locally running Whisper model (whisper.cpp or similar Swift binding)
- **Pipeline:** Audio buffer → Whisper inference → Text output
- **No cloud dependency:** All transcription happens on-device

## Key Behaviors

- Recorded audio is sent to Whisper after recording session ends
- Transcription runs asynchronously to avoid blocking the UI
- Transcribed text is passed to the text insertion module

## Common Patterns

- Use whisper.cpp Swift bindings or WhisperKit for on-device inference
- Handle model loading at app launch for faster first transcription
- Support multiple model sizes (tiny, base, small) configurable by user
