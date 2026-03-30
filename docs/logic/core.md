# Core System

<!-- App lifecycle, permissions, system integration, orchestration, and data persistence. -->

<!-- Updated: 2026-03-28 -->

---

## Architecture

- **App Lifecycle:** Full Dock app with menu bar companion (LSUIElement = NO)
- **Permissions:** Accessibility (AXIsProcessTrusted), Microphone (AVCaptureDevice), Input Monitoring
- **Orchestration:** Central coordinator managing the recording → transcription → cleanup → completion pipeline
- **Data Persistence:** JSON files in `~/Library/Application Support/MacVoice/`
- **Package Manager:** Swift Package Manager (SPM)

## Pipeline States

```
idle → preparingToRecord → recording → transcribing → cleaning → completed → idle
                                                     ↘ completed (if cleanup disabled)
Any active state → idle (cancellation)
Any state → error → idle (auto-reset after 5s)
```

- `.completed(TranscriptionResult)` — holds raw text, cleaned text, and cleanup failure flag
- `.cleaning` — AI cleanup in progress
- No more `.inserting` — user chooses action from overlay

## Data Stores

- **PromptStore:** `@Observable`, persists `[CleanupPrompt]` to `prompts.json`
- **HistoryStore:** `@Observable`, persists `[TranscriptionRecord]` to `history.json`, `[HistoryFolder]` to `folders.json`
  - Folder management: create, rename, delete folders
  - Archive/unarchive records
  - Batch operations: multi-select delete, move to folder
  - Audio file pruning at configurable limit (default 50)
- **KeychainHelper:** Secure API key storage via Security framework

## Key Behaviors

- App requests required permissions on first launch
- Graceful degradation if permissions are denied (show guidance in menu)
- Pipeline coordinator manages state transitions through the full pipeline
- Error handling for each pipeline stage with user-visible status updates
- Recording overlay shows during pipeline, stays until user acts (Copy/Insert/Dismiss)

## Common Patterns

- Use a state machine with `TranscriptionResult` associated value for completion
- Check permissions at launch and before each recording session
- Log errors to Console.app via OSLog
- JSON files with atomic writes for data persistence
- Keychain for sensitive data (API keys)
