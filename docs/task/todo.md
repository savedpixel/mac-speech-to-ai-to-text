# Mac Voice — Active Tasks

<!-- Updated: 2026-04-02 -->

<!-- Add task items here as checkboxes. Remove completed items and log them in docs/task/logs/. -->

## Active

### Beep Reliability, History Failure Handling, Copy Feedback, Folder Display & Send Phrase Fix
> Plan: `docs/task/planning/draft/2026-04-07-beep-reliability-history-polish.md`

- [ ] Step 1: Fix audio session for reliable beep playback
- [ ] Step 2: Add `cleanupFailed` and `cleanupFailureReason` to TranscriptionRecord
- [ ] Step 3: Persist cleanup failure state in PipelineCoordinator
- [ ] Step 4: Show cleanup-failed records in "Failed" section
- [ ] Step 5: Add "Retry Cleanup" button to RecordingOverlayView
- [ ] Step 6: Separate re-transcribe, re-clean, and combined actions in HistoryDetailView
- [ ] Step 7: Add "Copied" feedback to all copy buttons
- [ ] Step 8: Fix folder display in HistoryDetailView
- [ ] Step 9: Fix send phrase false-positive auto-send
- [ ] Step 10: Build, test, and verify all features

### Microphone Connection Mode & Spotify Shortcut Pause

- [ ] Add persistent setting for keeping the microphone connected or off by default
- [ ] Disable wake phrase when microphone is off by default
- [ ] Pause Spotify with the keyboard play/pause key before shortcut-triggered recording
- [ ] Restore off-by-default microphone behavior after the pipeline finishes
- [ ] Build and verify menu bar + settings behavior

### Sound Quality, History Resilience, Overlay Feedback & UI Polish
> Plan: `docs/task/planning/draft/2026-03-29-sound-history-overlay-polish.md`

- [ ] Step 1: Sound preset library in AudioSignalPlayer
- [ ] Step 2: Save pending record before transcription (crash-safe)
- [ ] Step 3: Add `cleanupFailureReason` to TranscriptionResult
- [ ] Step 4: Make AI failure obvious in overlay (red icon + reason)
- [ ] Step 5: Fix history list click responsiveness
- [ ] Step 6: Re-transcription shows progress overlay/sheet
- [ ] Step 7: History detail layout polish
- [ ] Step 8: Native macOS form layout for settings
- [ ] Step 9: Sound preset picker in settings
- [ ] Step 10: Wire AudioSignalPlayer to use settings preset
- [ ] Step 11: Build, test, and verify

### Multi-Shortcut Prompts, Insert Phrase, Copy Behavior, UI Polish & Whisper Model Fix
> Plan: `docs/task/planning/draft/2026-03-29-shortcuts-insert-phrase-copy-behavior.md`

- [ ] Step 0: Fix Whisper model loading — use local path when available (`TranscriptionEngine.swift`)
- [ ] Step 1: Create `ShortcutBinding` model (`MacVoice/Core/ShortcutBinding.swift`)
- [ ] Step 2: Migrate Settings to multi-shortcut + add insertPhrase / copy behavior keys
- [ ] Step 3: Update `ShortcutManager` for multiple HotKey registrations
- [ ] Step 4: Update `PipelineCoordinator.activate(promptID:)` with active prompt override
- [ ] Step 5: Create `InsertPhraseListener` (`MacVoice/Input/InsertPhraseListener.swift`)
- [ ] Step 6: Wire `InsertPhraseListener` into `PipelineCoordinator`
- [ ] Step 7: Wire `InsertPhraseListener` in `AppDelegate`
- [ ] Step 8: Update `TranscriptionCleaner.clean(_:promptID:)` for prompt override
- [ ] Step 9: Update `copyResult()` for keep-open / auto-dismiss behavior
- [ ] Step 10: Fix completed-state icon in `RecordingOverlayView`
- [ ] Step 11: Update `PreferencesView` (Shortcuts tab, insert phrase, copy behavior)
- [ ] Step 12: Build, test, and verify all features

### Initial Project Scaffold & Core Infrastructure
> Plan: `docs/task/planning/draft/2026-03-26-initial-project-scaffold.md`

**Phase 1: Project Setup & App Lifecycle**
- [ ] Step 1: Create SPM package and directory structure
- [ ] Step 2: Create App entry point and AppDelegate
- [ ] Step 3: Implement permission management

**Phase 2: Menu Bar UI & Preferences**
- [ ] Step 4: Create menu bar status item and dropdown
- [ ] Step 5: Create preferences window
- [ ] Step 6: Create Settings model

**Phase 3: Audio Pipeline**
- [ ] Step 7: Implement audio recorder with silence detection
- [ ] Step 8: Implement send phrase + silence detector
- [ ] Step 9: Implement media controller
- [ ] Step 10: Implement beep/audio signal player

**Phase 4: Input Handling**
- [ ] Step 11: Implement global shortcut manager
- [ ] Step 12: Implement wake phrase listener
- [ ] Step 13: Implement text insertion and auto-submit

**Phase 5: Transcription**
- [ ] Step 14: Integrate WhisperKit for local transcription

**Phase 6: Orchestration**
- [ ] Step 15: Create pipeline state machine
- [ ] Step 16: Create pipeline coordinator

**Phase 7: Integration & Polish**
- [ ] Step 17: Wire all components in AppDelegate
- [ ] Step 18: Add OSLog logging throughout

### AI Transcription Cleanup + Recording Overlay + Full App UI
> Plan: `docs/task/planning/draft/2026-03-28-ai-transcription-cleanup.md`

**Phase 1: Core Infrastructure**
- [ ] Step 1: Add Keychain helper for API key storage
- [ ] Step 2: Create data models for prompts, history, and folders
- [ ] Step 3: Create persistence managers (PromptStore, HistoryStore with folders/archive/batch)
- [ ] Step 4: Add AI cleanup + prompt settings to Settings.swift

**Phase 2: AI Cleanup Service**
- [ ] Step 5: Create TranscriptionCleaner service
- [ ] Step 6: Update pipeline states and coordinator

**Phase 3: Recording Overlay**
- [ ] Step 7: Create AudioWaveformView SwiftUI component
- [ ] Step 8: Create RecordingOverlayView (centered, system material, no auto-dismiss, warning badge on AI failure)
- [ ] Step 9: Create RecordingOverlayPanel (NSPanel, centered on screen)
- [ ] Step 10: Wire overlay into pipeline lifecycle (dismiss only on user action)

**Phase 4: Full App UI**
- [ ] Step 11: Enable Dock presence
- [ ] Step 12: Create main app window with sidebar navigation (auto-open on launch)
- [ ] Step 13: Create History UI (HistoryListView, HistoryDetailView, HistoryFolderSidebar with folders/archive/batch)
- [ ] Step 14: Create PromptListView and PromptEditorView
- [ ] Step 15: Migrate PreferencesView into main window Settings tab
- [ ] Step 16: Update MenuBarController to open main window

**Phase 5: Wiring & Polish**
- [ ] Step 17: Update AppDelegate composition root
- [ ] Step 18: Update MacVoiceApp scene definition
- [ ] Step 19: Update MenuBarController icon for new states

**Phase 6: Documentation**
- [ ] Step 20: Update documentation

### Settings UI — Save Indicator, Test API Key, Multi-Provider AI, Send Phrase Toggle, Done Button
> Plan: `docs/task/planning/draft/2026-03-28-settings-ai-providers.md`

- [ ] Step 1: Create AIProvider data model (`MacVoice/Core/AIProvider.swift`)
- [ ] Step 2: Update Settings.swift for provider-based config + migration
- [ ] Step 3: Update TranscriptionCleaner to use resolved endpoint/model
- [ ] Step 4: Add API key test function to TranscriptionCleaner
- [ ] Step 5: Redesign AI Cleanup section in SettingsContentView
- [ ] Step 6: Add auto-save indicator to SettingsContentView
- [ ] Step 7: Write unit tests (AIProvider, Settings migration)
- [ ] Step 8: Update PreferencesView if still used
- [ ] Step 9: Add `sendPhraseEnabled` to Settings + toggle in Voice Input UI
- [ ] Step 10: Conditionally start SendPhraseDetector + add `finishRecording()`
- [ ] Step 11: Add "Done" button to RecordingOverlayView

### Voice Recordings & Model Management
> Plan: `docs/task/planning/completed/2026-03-28-recordings-models-management.md`

- [x] Step 1: Fix Whisper model discovery — replace hardcoded enum with dynamic model list
- [x] Step 2: Add downloaded model discovery and deletion
- [x] Step 3: Build Model Management UI
- [x] Step 4: Update TranscriptionRecord for failure tracking and re-transcription
- [x] Step 5: Save recordings before transcription, preserve on failure
- [x] Step 6: Replace max-recordings pruning with time-based auto-deletion
- [x] Step 7: Add audio playback capability (AudioPlayer.swift)
- [x] Step 8: Add playback UI to recording detail view
- [x] Step 9: Add re-transcription capability
- [x] Step 10: Add re-transcription UI
- [x] Step 11: Update auto-delete settings UI
- [x] Step 12: Update HistoryListView for failed-transcription indicators
- [x] Step 13: Wire new components into AppDelegate
- [x] Step 14: Update documentation

---

## Completed

### Recording Overlay Waveform, Sound Defaults, Send/Insert Trigger Fixes (2026-04-02)

- [x] Step 1: Replace the overlay with a PCM-driven centered audio waveform and live timer updates
- [x] Step 2: Default notification sound to the first preset and sanitize invalid saved values
- [x] Step 3: Play an acknowledgement sound when recording is finished by send phrase or Done
- [x] Step 4: Restore insert phrase listening so it can trigger insertion after transcription
- [x] Step 5: Build, relaunch, and user-verify the overlay behavior

### Resume Media When Transcription Starts (2026-03-30)

- [x] Step 1: Trace current media pause/resume timing in the pipeline
- [x] Step 2: Resume media when recording stops and transcription begins
- [x] Step 3: Build and verify playback no longer waits for copy/insert

### Voice Recordings & Model Management (2026-03-28)
