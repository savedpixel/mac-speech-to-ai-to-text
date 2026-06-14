
### AI Cleanup Key Persistence Repair (2026-06-02)

- [x] Reproduce Grok regression where old saved key/error remained visible
- [x] Verify provided DeepSeek key against provider API outside the app
- [x] Fix connection card so success requires Keychain save/read-back
- [x] Fix Keychain writes to update existing saved credentials instead of delete/add
- [x] Bump version/build, rebuild, sign, relaunch
- [x] Visually test save/test, repeat test, settings/dashboard navigation, and app relaunch persistence

# Mac Speech to AI to Text — Active Tasks

<!-- Updated: 2026-06-01 (Sprint 1 Grok improvement activated as primary effort per audit) -->

<!-- Add task items here as checkboxes. Remove completed items and log them in docs/task/logs/. -->

## Active

### Grok App Improvement — Sprint 1 (Trust, Setup, Sidebar, Core Cards)
> Source: `docs/reports/2026-06-01-grok-app-improvement-audit.md`  
> Execution Plan: `docs/task/planning/in-progress/2026-06-01-grok-improvement-sprint-1.md`  
> Goal: Make the app feel like a polished, self-explanatory macOS productivity tool. Highest-ROI fixes first: Dashboard readiness, clean sidebar, reusable status/recovery cards, model/AI clarity.

**Primary Deliverables (Sprint 1 only):**
- Persistent Dashboard readiness screen (permissions, model, AI, shortcuts, last result + actions).
- Sidebar cleanup (no dups/blank rows, clear App nav, Folders + only in header, version footer preserved).
- Reusable Model Readiness Card, AI Connection Card (enhanced), Failure Recovery Card.
- Settings top-level readiness summary + reordering + status chips.
- All recovery paths end-to-end verified (old + new failures).

**Strict Gates (every source batch):**
- Bump `CFBundleShortVersionString` + `CFBundleVersion` in Info.plist.
- `bash scripts/build-app.sh` (full package/sign).
- Kill old instance, open new packaged app.
- Verify exact version string visible in the running sidebar footer.
- Visual + scenario description immediately after relaunch.

- [ ] Phase 0: Tracking sync + lessons read + plan promoted (done in this session).
- [ ] Phase 1: Sidebar refactor (eliminate duplicates/blank "New Folder", clean sections, consistent + button, preserve version).
- [ ] Phase 1 gate: First bump + full build + relaunch + verify visible version + describe new sidebar.
- [ ] Phase 2: Model Readiness Card (exact states per audit, no contradictory copy, actions).
- [ ] Phase 2 gate: Bump + build + relaunch + verify.
- [ ] Phase 3: Enhanced AI Connection Card (Dashboard primary + Settings, status chips, privacy note).
- [ ] Phase 3 gate: Bump + build + relaunch + key test flow verify on both surfaces.
- [ ] Phase 4: Failure Recovery Card + wiring (history detail, overlay, "repair all failed").
- [ ] Phase 4 gate: Critical visual + end-to-end recovery on historical "Invalid API response" records.
- [ ] Phase 5: Complete Dashboard + Settings polish (readiness overview at top, chips, hierarchy).
- [ ] Phase 5 gate: Full visual sweep of all changed surfaces in running signed app.
- [ ] Phase 6: Docs (menubar-ui.md + logic), observations, applied lessons, user verification, close-out.

**Relevant Lessons:** Mandatory bump/rebuild/relaunch after any source change; visual inspection + repair in same batch for UI; persistent diagnostics preferred; preserve local-first + version footer.

### AI Cleanup Provider Response and Latency Fix (recently completed)
> Plan: `docs/task/planning/in-progress/2026-06-01-ai-cleanup-provider-latency-fix.md`

- [x] All steps + agent verification pass on "try now" (detailed ai-cleanup diagnostics, robust parsing, dynamic tokens, key UX test-before-save).
- [ ] User live confirmation of Test Connection + real cleanup with provider (DeepSeek etc.).


### Documentation Parity Sweep
> Plan: `docs/task/planning/draft/2026-05-24-documentation-parity-sweep.md`

- [x] Step 1: Run forced full documentation audit from `docs/0-index.md`
- [x] Step 2: Refresh stale logic docs and indexes
- [x] Step 3: Save audit report and cross-post unresolved observations


### Insert Phrase Deterministic Fix
> Plan: `docs/task/planning/draft/2026-05-24-insert-phrase-deterministic-fix.md`

- [x] Step 1: Inspect latest insert phrase diagnostics for no-partial listener stalls
- [x] Step 2: Make insert phrase recognition avoid fragile on-device/stale sessions and log audio buffer health
- [x] Step 3: Add copied off-thread Speech buffer appends and voice-activity fallback insertion after the v1.0.18 test still stalled
- [x] Step 4: Update docs, bump version/build, build/package/reopen, and verify visible version


### Audio Signal Preload Optimization
> Plan: `docs/task/planning/draft/2026-05-23-audio-signal-preload-optimization.md`

- [x] Step 1: Preload/cache bundled beep assets and warm the selected preset
- [x] Step 2: Use cached audio data for signal playback and log latency/result diagnostics
- [x] Step 3: Update docs, bump version/build, build/package/reopen, and verify visible version


### Insert Phrase Regression Fix
> Plan: `docs/task/planning/draft/2026-05-23-insert-phrase-regression-fix.md`

- [x] Step 1: Inspect latest insert phrase diagnostics and lifecycle code
- [x] Step 2: Fix insert phrase listener startup/restart/matching regression
- [x] Step 3: Update docs, bump version/build, build/package/reopen, and verify visible version


### Shortcut Press Beep Before Recording
> Plan: `docs/task/planning/draft/2026-05-23-shortcut-press-beep-before-recording.md`

- [x] Step 1: Play/await shortcut beep before recorder startup
- [x] Step 2: Remove post-recorder-start beep so it is not captured in waveform
- [x] Step 3: Update docs, bump version/build, build/package/reopen, and verify visible version


### Shortcut Beep Diagnostics
> Plan: `docs/task/planning/draft/2026-05-23-shortcut-beep-diagnostics.md`

- [x] Step 1: Add recording-start beep playback result logging tied to shortcut activation
- [x] Step 2: Update docs and bump version/build
- [x] Step 3: Build/package/reopen and verify visible version


### Recording Start and Send Phrase Beep Reliability
> Plan: `docs/task/planning/draft/2026-05-23-recording-start-send-beeps.md`

- [x] Step 1: Move recording-start beep to after recorder startup succeeds
- [x] Step 2: Add explicit send-phrase accepted/transcribing-start beep and diagnostics
- [x] Step 3: Update docs, bump version/build, build/package/reopen, and verify visible version


### Return to Insert-Origin App After Target Paste
> Plan: `docs/task/planning/draft/2026-05-23-return-to-insert-origin-app.md`

- [x] Step 1: Capture frontmost return app when insertion is requested
- [x] Step 2: Reactivate return app after target paste/submit
- [x] Step 3: Update docs, bump version/build, build/package/reopen, and verify visible version


### Insertion Target Restore Debug and Fix
> Plan: `docs/task/planning/draft/2026-05-23-insertion-target-restore-debug.md`

- [x] Step 1: Inspect insertion restore code and diagnostic logs
- [x] Step 2: Harden app/input restore with multi-strategy focus and paste diagnostics
- [x] Step 3: Add a reusable local insertion-target test aid
- [x] Step 4: Bump version/build, build, package, reopen, and verify visible version


### Version Visibility and Mandatory Rebuild Rule
> Plan: `docs/task/planning/draft/2026-05-23-version-visibility-and-rebuild-rule.md`

- [x] Step 1: Update repo rules, lesson layers, and Codex memory with the mandatory version bump/rebuild/reopen rule
- [x] Step 2: Add visible bundle version/build label above New Folder in the sidebar
- [x] Step 3: Bump `CFBundleShortVersionString` and `CFBundleVersion` for this change
- [x] Step 4: Build, package, reopen, and report verification



### Audio, Insert Phrase, and Target Restoration Stability
> Plan: `docs/task/planning/draft/2026-05-23-audio-insert-target-stability.md`

- [x] Step 1: Capture and restore the triggering app/input before all insertion paths
- [x] Step 2: Retain audio signal playback so beeps reliably complete
- [x] Step 3: Harden insert phrase listening against mic/recognizer startup failures
- [x] Step 4: Preserve mic-release behavior while avoiding listener contention
- [ ] Step 5: User-verify real-world microphone/Codex insertion scenarios after successful build/relaunch


### Insert Phrase Confirmation Beep

- [x] Add a confirmation beep only after insert phrase successfully inserts text
- [x] Bump app version/build and rebuild/relaunch signed app
- [x] Verify insert phrase path is wired to the confirmation beep


### Microphone Startup Stability Debug
> Plan: `docs/task/planning/draft/2026-05-19-microphone-startup-stability-debug.md`

- [x] Step 1: Capture current runtime/log failure mode with existing apps open
- [x] Step 2: Harden microphone acquisition and retry behavior
- [x] Step 3: Prevent passive wake/insert listeners from competing with shortcut recording
- [x] Step 4: Bump bundle version without changing signing identity
- [x] Step 5: Build, relaunch, and manually verify multiple recording attempts


### Whisper Model Selection Persistence & Startup Readiness
> Plan: `docs/task/planning/draft/2026-04-17-whisper-model-selection-persistence-fix.md`

- [x] Step 1: Make transcription wait for the selected Whisper model instead of failing when startup loading is still in progress
- [x] Step 2: Make downloaded-model `Use` the primary active-model control and remove the redundant active-model picker
- [x] Step 3: Split local model preparation from download state in the UI so startup status is accurate
- [ ] Step 4: Build, relaunch, and verify that force-quit recovery uses the selected local model without redownloading

### Whisper Model Reuse On Relaunch
> Plan: `docs/task/planning/draft/2026-04-17-whisper-model-reuse-fix.md`

- [x] Step 1: Fix local cached-model loading so it reuses the configured storage base
- [x] Step 2: Restrict delete-and-redownload recovery to real model corruption
- [x] Step 3: Build, relaunch, and verify cache reuse at startup

### Recording Start Stability
> Plan: `docs/task/planning/draft/2026-04-17-recording-start-stability-fix.md`

- [x] Step 1: Remove unnecessary route-settling delay for non-Bluetooth microphones
- [x] Step 2: Debounce audio engine config rebuilds during startup
- [x] Step 3: Keep the overlay in `Preparing…` until recording is actually live

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

### Insert Phrase OK Fix (2026-05-19, stopped before live verification)

- [x] Add exact `ok` / `okay` single-word matching
- [x] Add insert listener diagnostic logs and normal-end restart handling
- [x] Bump version/build for final bundle
- [ ] User stopped live verification before confirmed insert test

### Diagnostic Logging and Settings Repair (2026-05-19)

- [x] Add persistent diagnostic logging setting and file writer
- [x] Instrument shortcut, pipeline, microphone startup, retry, route-change, and listener handoff paths
- [x] Repair and visually verify Settings page layout
- [x] Bump version/build and rebuild/sign/relaunch
- [x] Trigger shortcut and confirm diagnostic log file captures the mic sequence

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
### Generate Copilot and Codex Instruction Rules (2026-05-23)

- [x] Created docs indexes and 3-layer lessons support
- [x] Upgraded Copilot instructions/prompts for targets 1 and 3
- [x] Added Codex `AGENTS.md` baseline and `.agents/skills/` workflows
- [x] Audited generated artifacts and skipped non-selected/conditional workflows

### Generate Rules Second-Pass Audit (2026-05-23)

- [x] Re-read generated Copilot + Codex artifacts
- [x] Compare against selected-target generator contracts
- [x] Repair implicit or thin workflow contract language
- [x] Align Codex skills with generated-agent ignore policy
- [x] Re-run artifact checks
