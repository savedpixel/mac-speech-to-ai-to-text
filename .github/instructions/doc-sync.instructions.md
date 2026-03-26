---
description: Documentation sync rules — which docs to update when code changes
applyTo: 'MacVoice/**'
---

# Documentation Sync Rules

These rules apply when modifying files under `MacVoice/`. They define which documentation to update and when.

---

## MANDATORY: Auto-Update Documentation

Whenever you implement changes, you **MUST** update the relevant documentation files. Never skip this step. **If you are unsure which docs to update, consult the Documentation Trigger Map below and ask the user if needed — do not skip doc updates because you're uncertain.** Only the user may waive documentation requirements.

### Documentation Timing Gate (BLOCKING — requires user verification first)

**You may NOT update documentation, update task logs, or perform any batch-boundary step until ALL of the following gates have passed in order:**

1. **Agent Self-Evaluation Gate** — You confirmed this is the best solution (see `task.instructions.md`).
2. **Visual Verification Gate** — If the work affects UI/visual elements, you verified visually. If purely back-end, auto-passes.
3. **User Verification Gate** — The user has either tested and confirmed, OR explicitly waived testing.

**If the user has not yet responded to the verification prompt, you may NOT:**
- Edit any file in `docs/`
- Edit any file in `docs/task/logs/`
- Edit any file in `docs/agent-observations/`
- Stage, commit, or push any changes

**Scenario Evidence Requirement (BLOCKING):** Documentation is blocked until all required behavior-path scenarios were executed end-to-end.

**Untested Disclosure Requirement (BLOCKING):** The verification summary must include an explicit `Not Tested` section listing every unexecuted check/scenario (or `Not Tested: none`).

**CRITICAL — NO SKIPPING:** You are never permitted to bypass this timing gate on your own judgment.

### Update "Last updated" Date on Every Doc Edit

Whenever you edit **any** markdown file in `docs/`, you **MUST** also update its `<!-- Updated: YYYY-MM-DD -->` comment to today's date.

---

## Documentation Trigger Map

### 1. `docs/logic/audio.md` — Audio System

**Update when:**
- Changes to audio recording (AVAudioEngine, AVAudioRecorder usage)
- Changes to media pause/resume logic
- Changes to beep/signal playback
- Changes to silence detection or send phrase monitoring
- Changes to audio session configuration

**What to document:**
- Recording pipeline changes (buffer sizes, formats, routing)
- Media control approach changes
- Silence threshold behavior changes
- Audio signal timing changes

### 2. `docs/logic/transcription.md` — Transcription System

**Update when:**
- Changes to Whisper model integration (whisper.cpp, WhisperKit)
- Changes to transcription pipeline (audio buffer → text)
- Changes to model loading, selection, or configuration
- Changes to transcription error handling or fallback behavior

**What to document:**
- Model format/size changes
- Pipeline architecture changes
- Performance characteristics
- Error handling behavior

### 3. `docs/logic/input.md` — Input System

**Update when:**
- Changes to global shortcut registration or handling (CGEvent)
- Changes to wake phrase detection ("okay, voice")
- Changes to text field detection or insertion (Accessibility API)
- Changes to auto-submit (Enter key simulation)
- Changes to active element tracking

**What to document:**
- Shortcut registration approach
- Wake phrase recognizer configuration
- Text insertion method changes
- Focus management behavior

### 4. `docs/logic/menubar-ui.md` — Menu Bar UI

**Update when:**
- Changes to NSStatusItem or menu bar icon
- Changes to menu dropdown items or structure
- Changes to preferences window (SwiftUI views)
- Changes to settings/configuration options
- Changes to app state display in menu bar

**What to document:**
- Menu structure changes
- New/removed preferences
- State indicator behavior
- SwiftUI view hierarchy changes

### 5. `docs/logic/core.md` — Core System

**Update when:**
- Changes to app lifecycle (launch, activation, termination)
- Changes to permission requests or checks
- Changes to pipeline orchestration (state machine)
- Changes to Package.swift dependencies
- Changes to error handling strategy
- Changes to logging approach

**What to document:**
- Permission flow changes
- State machine transitions
- New dependencies and their purpose
- Architecture-level changes

---

## Task Ledger (Daily Files in `docs/task/logs/`)

Whenever you complete a task, you **MUST** append/update entries in today's daily task log file:

- `docs/task/logs/YYYY-MM-DD.md`

If the file doesn't exist yet, create it with the header format defined in `task.instructions.md`.

**Column definitions:**
- `Title` — Action-oriented, specific enough to be searchable
- `Description` — Concise, outcome-focused
- `Start Date` / `End Date` — `MM/DD/YYYY` format
- `Category` — One of: `Audio` · `Transcription` · `Input` · `UI` · `Core` · `Permissions` · `Bug` · `Docs`
- `Type` — `Task` or `Sprint`

**Never skip the task ledger update.** If you encounter an error, report it to the user and wait.

---

## Documentation Format Guidelines

- Use Markdown with clear headers and tables
- Include code snippets for function signatures and usage examples
- Keep entries concise
- Use tables for reference data
- Date-stamp significant additions with `<!-- Added: YYYY-MM-DD -->`
- Group related items under logical sections
- When adding to an existing doc, append to the relevant section — don't restructure unless necessary
