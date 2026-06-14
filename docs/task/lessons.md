# Mac Speech to AI to Text — Lessons Learned

<!-- Add lessons after user corrections to prevent repeating mistakes. -->

- 2026-03-30: In marketing copy, surface AI cleanup/refinement and AI provider/model flexibility early when they are core product differentiators; do not bury them after generic voice-input benefits.
- 2026-04-01: For overlay waveform requests, match the requested visualization literally; a bar meter is not an acceptable substitute when the user asks for a sine wave.
- 2026-04-01: Distinguish between a mathematical sine wave and an audio waveform envelope; when the user wants an "audio wave," prefer a speech-reactive waveform shape with stronger amplitude contrast, not a regular oscillation.
- 2026-04-01: When the user references macOS Voice Memos, match the single centerline waveform style specifically; do not render mirrored top/bottom envelopes unless explicitly requested.
- 2026-04-01: A real audio waveform should be driven from signed PCM samples so silence stays centered; a line synthesized from dB loudness cannot satisfy that behavior.

## 2026-05-19 — Mic failures need persistent logs

- When a user reports intermittent microphone startup failures that cannot be reproduced reliably, add a persistent app-owned diagnostic log before claiming the issue is fixed. OSLog/live Console output alone is not enough for after-the-fact debugging.
- If the user says a settings page looks wrong after a functional fix, inspect the actual rendered app window and repair visual regressions in the same batch.

## 2026-05-19 — Exact OK insert phrase must match Speech `okay`

When a user configures a spoken trigger as `OK`/`ok`, always include exact `okay` as an equivalent speech-recognition variant. Do not only handle `ok ...` phrases with trailing words.

## 2026-05-23 — Version bump and relaunch after every change

After any source/code change in Mac Speech to AI to Text, always bump both `CFBundleShortVersionString` and `CFBundleVersion`, rebuild/package/sign the app, close the old running app, and reopen the newly built app before reporting completion. The app must also show the visible version/build so the user can quickly confirm the rebuilt binary is running.

## 2026-05-24 — Speech command fixes need buffer-level evidence

When a spoken command listener starts but the user reports that the command does nothing, do not stop at "listener started" logs. Log whether audio buffers are actually arriving and whether Speech partials are produced, then fix the recognizer lifecycle/routing based on that distinction.

## 2026-05-24 — Short command listeners need a non-Speech fallback

For one-word post-completion commands like "insert", do not rely only on `SFSpeechRecognizer`; if Speech receives audio but emits no partials, a short voice-activity command after completion should trigger the pending insert and log that fallback explicitly.

## 2026-05-24 — Fallbacks must beat completed-state dismissal races

If the completed-state insert listener detects voice activity, trigger the pending insert immediately rather than waiting for a long silence window. A delayed fallback can be cancelled if the overlay or pipeline returns to idle milliseconds after the user says the command.
