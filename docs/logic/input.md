# Input System

<!-- Global shortcuts, wake phrase activation, text field insertion, and auto-submit. -->

<!-- Updated: 2026-05-24 -->

---

## Architecture

- **Global Shortcut:** Customizable hotkey (e.g., double-tap Control) via CGEvent tap or MASShortcut
- **Wake Phrase:** Always-listening "okay, voice" trigger using a lightweight speech recognizer
- **Text Insertion:** Accessibility API (AXUIElement) to locate active text field and insert text
- **Auto-Submit:** Simulated Enter key press via CGEvent after text insertion

## Speech Listener Stability

- Insert phrase listening now recreates its Speech recognizer session for each completed result, uses confirmation-mode command hints, contextual phrase strings, common `insert` misrecognition variants such as `insect`, selected-microphone reuse after recording, and a health watchdog that restarts stalled listeners.
- Insert phrase startup now checks Speech authorization, rejects invalid mic formats, avoids forcing on-device recognition for the short command, logs first-audio-buffer arrival, distinguishes no-audio-buffer stalls from no-Speech-partial stalls, and retries transient session endings while the completed overlay is waiting for insertion.
- Insert phrase audio buffers are copied and appended to Speech off the real-time audio tap so a blocked Speech append cannot stall microphone diagnostics. If the completed-state listener receives clear voice activity, it immediately treats that post-completion utterance as the insert command and logs `voiceActivityImmediateFallback`; the delayed `Voice activity fallback inserting` path remains as a backup if needed.
- Insert phrase matching treats single-word `ok` and `okay` as equivalent, normalizes basic punctuation in recognized partial transcripts, and logs listener partials/matches to the diagnostic file.
- Wake phrase comma variants are built with explicit `String` values so release/debug builds compile consistently.
- Insert phrase cancellation, no-speech, and Speech framework timeout callbacks are treated as normal listener shutdown events instead of user-facing errors.
- Insert phrase remains a post-completion convenience listener; shortcut recording still claims the microphone directly and does not require the idle microphone to stay connected.

## Key Behaviors

- After a successful target paste/submit, MacVoice restores the app that was frontmost when insertion was requested, unless that app was MacVoice or the original insertion target.
- Shortcut activation, ignored activations, listener cancellation, and insert handoff events are written to the diagnostic log when file logging is enabled.
- Insert phrase insertion now plays a confirmation beep after non-empty text is inserted so users know the spoken insert command completed.
- Global shortcut works system-wide regardless of focused application
- Wake phrase runs a separate lightweight recognizer (not Whisper) for low-latency detection
- Text insertion captures the triggering frontmost app, bundle URL, PID, focused AX element, and element frame at recording start, then uses running-app activation, AX frontmost/raise/focus, AppleScript activation, and saved-frame click fallback before clipboard paste so moving to another app during recording or transcription does not redirect the result
- Enter is sent automatically after text is inserted to submit the message
- Insert phrase listening now starts from the completed overlay state whenever insert phrase is enabled, auto-insert is off, and microphone permission is granted; it no longer depends on keeping the idle microphone connected

## Common Patterns

- `scripts/debug-insertion-target.sh` opens a browser fixture, tails insertion diagnostics, and can play a spoken `ok insert` prompt to help reproduce target-restore failures without repeatedly asking for manual user retests.
- Use Accessibility API permissions for text field detection and insertion
- Store the active app plus focused element reference at recording start, restore the app/focus before insertion, and keep clipboard paste as the universal fallback
- CGEvent for simulating keyboard input (Enter key)
