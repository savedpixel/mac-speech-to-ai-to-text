# Logic Documentation Index

<!-- Generated with generate-rules.prompt.md | ruleset: index-driven-doc-maintenance-v1 -->

<!-- Updated: 2026-05-24 -->

Use this index to route source changes under `MacSpeechToAIToText/**` and package/config changes to the correct feature documentation.

| Source / Concern | Primary Doc | Notes |
| --- | --- | --- |
| `MacSpeechToAIToText/Audio/**` | `docs/logic/audio.md` | Recording, playback, media controls, signal sounds, send phrase, silence detection |
| `MacSpeechToAIToText/Transcription/**` | `docs/logic/transcription.md` | WhisperKit, model loading, transcription results, cleanup handoff |
| `MacSpeechToAIToText/Input/**` | `docs/logic/input.md` | Shortcuts, wake/insert phrase listeners, AX text insertion, focus restoration |
| `MacSpeechToAIToText/UI/**` | `docs/logic/menubar-ui.md` | SwiftUI/AppKit windows, menu bar, overlay, preferences, history UI |
| `MacSpeechToAIToText/App/**`, `MacSpeechToAIToText/Core/**`, `Package.swift`, `Info.plist` | `docs/logic/core.md` | App lifecycle, settings, stores, permissions, pipeline orchestration, dependencies, logging |
| `scripts/build-app.sh`, `scripts/generate-icon.swift`, app packaging/signing | `docs/logic/core.md` | Build/package/relaunch behavior, generated bundle metadata, signing, copied resources |

When a change spans multiple concerns, update every relevant doc and this index if routing changes.
