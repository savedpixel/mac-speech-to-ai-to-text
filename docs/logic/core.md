# Core System

<!-- App lifecycle, permissions, system integration, orchestration, and data persistence. -->

<!-- Updated: 2026-06-02 -->

---

## Architecture

- **App Lifecycle:** Full Dock app with menu bar companion (LSUIElement = NO)
- **Permissions:** Accessibility (AXIsProcessTrusted), Microphone (AVCaptureDevice), Input Monitoring
- **Orchestration:** Central coordinator managing the recording → transcription → cleanup → completion pipeline
- **Data Persistence:** JSON files in `~/Library/Application Support/MacVoice/` plus optional persistent diagnostic logs under `~/Library/Application Support/MacVoice/Diagnostics/`
- **Package Manager:** Swift Package Manager (SPM)
- **Packaging:** `scripts/build-app.sh` reads `CFBundleShortVersionString` and `CFBundleVersion` from `MacSpeechToAIToText/Info.plist`, builds a release binary, copies bundled sounds, signs the `.app`, and reopens it.

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
  - Audio file pruning is age-based via the configurable storage retention setting; recordings are not count-pruned by default.
- **KeychainHelper:** Secure API key storage via Security framework. API key writes update existing generic-password items before falling back to adding a new item, so rebuilt apps can replace stale keys without leaving an old credential behind.

## Key Behaviors

- Pipeline diagnostics log recording-start and send-phrase-accepted beep attempts, including whether playback was skipped or succeeded.
- App launch diagnostics log visible bundle version/build and preload beep sound assets before normal use.
- Insertion diagnostics now log captured target app/element frame, activation/focus fallback results, frontmost app before paste, and submit completion for target-restore debugging.
- Every source/code change requires a bundle version/build bump followed by build/package/sign and relaunch before handoff, so the visible sidebar version proves the newest binary is running.
- Persistent diagnostic file logging is enabled from Settings by default and records lifecycle, permission, shortcut, pipeline, microphone startup, listener handoff, and AI cleanup request timing/status events to a dated local log file.
- Insert phrase-triggered insertion skips empty results and plays a confirmation beep only for non-empty inserted text.
- Shortcut-triggered recording now tolerates transient microphone acquisition and route-change churn before surfacing an error.
- Pipeline completion still restores the idle microphone-disconnected mode when `Keep Microphone Connected` is off, while post-completion insert phrase listening retries transient Speech framework/audio-engine endings until insertion or dismissal.
- App requests required permissions on first launch
- Graceful degradation if permissions are denied (show guidance in menu)
- Pipeline coordinator manages state transitions through the full pipeline
- Error handling for each pipeline stage with user-visible status updates
- Recording overlay shows during pipeline, stays until user acts (Copy/Insert/Dismiss)

## Common Patterns

- Use a state machine with `TranscriptionResult` associated value for completion
- Check permissions at launch and before each recording session
- Log errors to Console.app via OSLog and, when enabled, to the local diagnostic file for after-the-fact debugging
- JSON files with atomic writes for data persistence
- Keychain for sensitive data (API keys), with write/read-back verification before the UI reports a saved AI cleanup key
