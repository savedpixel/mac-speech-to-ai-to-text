# Mac Voice — Lessons Learned

<!-- Add lessons after user corrections to prevent repeating mistakes. -->

- 2026-03-30: In marketing copy, surface AI cleanup/refinement and AI provider/model flexibility early when they are core product differentiators; do not bury them after generic voice-input benefits.
- 2026-04-01: For overlay waveform requests, match the requested visualization literally; a bar meter is not an acceptable substitute when the user asks for a sine wave.
- 2026-04-01: Distinguish between a mathematical sine wave and an audio waveform envelope; when the user wants an "audio wave," prefer a speech-reactive waveform shape with stronger amplitude contrast, not a regular oscillation.
- 2026-04-01: When the user references macOS Voice Memos, match the single centerline waveform style specifically; do not render mirrored top/bottom envelopes unless explicitly requested.
- 2026-04-01: A real audio waveform should be driven from signed PCM samples so silence stays centered; a line synthesized from dB loudness cannot satisfy that behavior.
