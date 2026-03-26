# Core System

<!-- App lifecycle, permissions, system integration, and orchestration. -->

<!-- Updated: 2026-03-26 -->

---

## Architecture

- **App Lifecycle:** NSApplication-based menu bar agent app
- **Permissions:** Accessibility (AXIsProcessTrusted), Microphone (AVCaptureDevice), Input Monitoring
- **Orchestration:** Central coordinator managing the recording → transcription → insertion pipeline
- **Package Manager:** Swift Package Manager (SPM)

## Key Behaviors

- App requests required permissions on first launch
- Graceful degradation if permissions are denied (show guidance in menu)
- Pipeline coordinator manages state transitions: idle → recording → transcribing → inserting → idle
- Error handling for each pipeline stage with user-visible status updates

## Common Patterns

- Use a state machine or enum-based state management for the pipeline
- Check permissions at launch and before each recording session
- Log errors to Console.app via os.log / OSLog
