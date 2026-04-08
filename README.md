# Mac Speech to AI to Text

A macOS menu bar app that turns speech into refined, ready-to-send text anywhere you type — powered by local Whisper transcription and AI cleanup.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## What It Does

Trigger recording with a global shortcut or wake phrase, speak naturally, and have your words transcribed locally, refined with AI, and inserted directly into the active text field — whether that's a chat window, browser, editor, or AI tool.

No app switching. No copy-pasting. Just speak and send.

## Features

- **Global shortcut & wake phrase activation** — trigger from anywhere on your Mac
- **Local Whisper transcription** — privacy-first, on-device speech-to-text via [WhisperKit](https://github.com/argmaxinc/WhisperKit)
- **AI cleanup** — refine raw dictation into polished text with configurable prompts
- **Flexible AI providers** — OpenAI, Anthropic, or custom endpoints with selectable models
- **Direct text insertion** — results go straight into the active text field
- **Spoken send phrase** — hands-free recording control
- **Auto media pause/resume** — pauses Spotify/Apple Music while recording
- **Recording history** — browse, replay, and reuse past transcriptions
- **Custom prompt library** — save and switch between cleanup prompts
- **Multiple shortcut bindings** — assign different shortcuts to different prompts
- **Notification sounds** — configurable beep presets and volume
- **Menu bar app** — always available, never in the way

## How It Works

1. Press your shortcut (or say your wake phrase)
2. Background media pauses automatically
3. Speak your message
4. Say your send phrase or press the shortcut again to stop
5. Audio is transcribed locally with Whisper
6. AI cleanup refines the transcription (optional)
7. Text is inserted into the active text field or copied to clipboard

## Requirements

- macOS 14.0 (Sonoma) or later
- Microphone access
- Accessibility permission (for text field detection and insertion)
- Input Monitoring permission (for global keyboard shortcuts)

## Install

### Pre-built App

1. Download [`Mac-Speech-to-AI-to-Text.zip`](releases/Mac-Speech-to-AI-to-Text.zip) from the `releases/` folder
2. Unzip and drag **Mac Speech to AI to Text.app** to your Applications folder
3. Open the app — grant Microphone, Accessibility, and Input Monitoring permissions when prompted

### Build From Source

```bash
git clone https://github.com/yourusername/mac-speech-to-ai-to-text.git
cd mac-speech-to-ai-to-text
swift build
bash scripts/build-app.sh
open "build/Mac Speech to AI to Text.app"
```

Or open `Package.swift` in Xcode and run directly.

## Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI | SwiftUI + AppKit (NSStatusItem) |
| Audio | AVAudioEngine |
| Transcription | WhisperKit (local Whisper inference) |
| Input | CGEvent (shortcuts, key simulation), Accessibility API |
| Speech | Speech framework (wake/send phrase detection) |
| Persistence | UserDefaults / @AppStorage |
| Logging | OSLog |

## Project Structure

```
MacSpeechToAIToText/
  App/            — Entry point, AppDelegate
  Audio/          — Recording, playback, media control, signal sounds
  Core/           — Settings, pipeline coordinator, history, AI providers
  Input/          — Shortcuts, text insertion, wake/send phrase listeners
  Transcription/  — Whisper engine, AI cleanup
  UI/             — Menu bar, preferences, recording overlay, history
```

## Configuration

All settings are accessible from the app's main window:

- **Shortcuts** — Set global hotkeys, bind prompts to specific shortcuts
- **AI Cleanup** — Choose provider, model, and endpoint; toggle cleanup on/off
- **Prompts** — Create and manage cleanup prompt templates
- **Audio** — Select microphone, configure notification sounds
- **Send Phrase** — Set spoken phrase to stop recording hands-free
- **Wake Phrase** — Set spoken phrase to start recording hands-free
- **History** — Auto-delete old recordings, browse past transcriptions

## Privacy

- Core transcription runs **entirely on-device** using Whisper — no audio leaves your Mac
- AI cleanup (optional) sends only the transcribed text to your chosen provider
- No telemetry, no analytics, no accounts

## License

MIT
