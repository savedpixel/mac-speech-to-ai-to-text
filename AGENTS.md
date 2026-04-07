# Mac Voice — Agent Instructions

Mac Voice is a macOS menu bar app (Swift/SwiftUI) that provides system-wide voice-to-text: trigger by shortcut or wake phrase → record → transcribe locally with Whisper → AI cleanup → insert into any text field.

---

## Stack

- **Language:** Swift 5.9+ · **UI:** SwiftUI + AppKit (NSStatusItem)
- **Audio:** AVAudioEngine · **Transcription:** WhisperKit (local Whisper inference)
- **Input:** CGEvent (global shortcuts, key simulation) · Accessibility API (AXUIElement)
- **Speech:** Speech framework (wake phrase) · Audio level monitoring (silence detection)
- **Persistence:** UserDefaults / @AppStorage · **Secrets:** Keychain
- **Package Manager:** SPM · **Testing:** XCTest · **Logging:** OSLog

## Project Structure

```
MacVoice/
  App/          — AppDelegate, MacVoiceApp (entry point)
  Audio/        — AudioRecorder, AudioPlayer, MediaController, SendPhraseDetector, AudioSignalPlayer
  Core/         — Settings, PipelineCoordinator, PipelineState, HistoryStore, PermissionManager, AIProvider
  Input/        — ShortcutManager, TextInserter, InsertPhraseListener, WakePhraseListener
  Transcription/ — TranscriptionEngine, TranscriptionCleaner
  UI/           — MenuBarController, RecordingOverlayView, PreferencesView, HistoryListView, MainWindowView
docs/
  logic/        — Feature-level architecture (audio.md, transcription.md, input.md, menubar-ui.md, core.md)
  task/         — todo.md, lessons.md, logs/, planning/
  agent-observations/ — critical.md, recommendations.md, anomalies.md
  reports/
scripts/        — build-app.sh, generate-icon.swift
```

---

## Build & Run

```bash
cd /Volumes/Byron\ Beats/savedpixel/mac-voice
swift build          # Build
swift test           # Run tests
open Package.swift   # Open in Xcode
```

**After ANY code change, always rebuild and relaunch:**

```bash
swift build
kill $(pgrep -f "Mac Voice") 2>/dev/null
bash scripts/build-app.sh
open "build/Mac Voice.app"
```

**Debug logging:**

```bash
log stream --predicate 'subsystem == "com.macvoice.app"' --level debug
```

**Required macOS permissions:** Accessibility, Microphone, Input Monitoring.

---

## Coding Conventions

- Swift concurrency (async/await, actors) for all async work
- Prefer value types (structs, enums) over reference types
- Use `@Observable` (Swift 5.9+), not `ObservableObject`
- Error handling with typed throws or custom error enums
- `OSLog` for logging, never `print()`
- SwiftUI for all new UI; AppKit only where SwiftUI lacks API
- Keep views thin — business logic in managers/services
- File naming: PascalCase matching primary type, grouped by domain
- Tests mirror source: `MacVoiceTests/Audio/AudioRecorderTests.swift`

---

## Hard Rules

### Never Push to Production
All live deployments are the user's responsibility. You may deploy to local or staging only.

### Never Auto-Commit or Auto-Push
Always get **explicit user approval** before `git commit` or `git push`. Present 3 commit message options. Never use `git add .` or `git add -A` — stage explicit file paths only. Never commit to `master` or `main` unless explicitly instructed.

### No Backups in Source Directories
Place backups in `docs/backups/` with descriptive subfolder and timestamp.

### Date-Prefix Generated Files
Files in `docs/` date-scoped directories: `YYYY-MM-DD-{slug}.md`.

---

## Task Workflow

### 1. Plan First
Non-trivial requests (≥3 steps, architectural, behavioral) require a plan before implementation. Write to `docs/task/planning/draft/YYYY-MM-DD-{slug}.md`.

### 2. Track in todo.md
Add checklist items to `docs/task/todo.md` before implementation. Track progress. Move completed items out.

### 3. Lessons
After any user correction, update `docs/task/lessons.md` with a rule preventing the same mistake.

### 4. Batch Boundaries
Implement changes immediately. Defer documentation/commit until a batch boundary:
- User signals completion, changes topic, or asks to commit
- ~5 accumulated changes
- Session ending

At each boundary, run the full cycle:
1. Pre-verification gates (self-evaluation → visual verification → user verification)
2. Log observations → Update task log → Sync docs → Get approval → Commit

### 5. Task Log
Append completed work to `docs/task/logs/YYYY-MM-DD.md`:

```markdown
| Title | Description | Start Date | End Date | Category | Type |
```

Categories: `Audio` · `Transcription` · `Input` · `UI` · `Core` · `Permissions` · `Bug` · `Docs`
Types: `Task` · `Sprint`

### 6. Plan Lifecycle

| Folder | Meaning |
|--------|---------|
| `draft/` | New, unapproved, or in-progress |
| `pending/` | Approved but deferred |
| `completed/` | Fully implemented and tested |

---

## Verification Gates (Blocking)

All three gates must pass before docs/commit:

### Gate A: Agent Self-Evaluation
*"Is this the best solution?"* — If NO, re-implement. Iterate until honestly YES.

### Gate B: Visual Verification
If UI affected: build, run, visually confirm. Reading code doesn't count. If purely back-end: auto-passes.

### Gate C: User Verification
Summarize changes and verification. Ask user to test. Wait for response. Include a `Not Tested` section listing any unexecuted scenarios.

**Blocker Protocol:** If any gate can't complete → try alternatives → if none succeed, STOP, do not commit, report the blocker.

---

## Documentation Sync

When modifying `MacVoice/` files, update relevant docs in the same response:

| Changed area | Update |
|---|---|
| Audio recording/playback | `docs/logic/audio.md` |
| Whisper/transcription | `docs/logic/transcription.md` |
| Shortcuts/text insertion | `docs/logic/input.md` |
| Menu bar/preferences | `docs/logic/menubar-ui.md` |
| App lifecycle/permissions | `docs/logic/core.md` |

Update `<!-- Updated: YYYY-MM-DD -->` on every doc edit.

---

## Agent Observations

Before every commit, log findings to `docs/agent-observations/`:

- **`critical.md`** — Blocking issues, security concerns, data corruption risks
- **`recommendations.md`** — Improvement suggestions, follow-up tasks
- **`anomalies.md`** — Doc/code drift, unused components, mismatched config

If none: state `Observations: none.` Silence is a violation.

Resolved items move to `docs/agent-observations/closed/`.

---

## Commit Rules

```
<type>(<scope>): <action-oriented summary>
```

Types: `feat`, `fix`, `refactor`, `docs`, `style`, `data`, `config`, `chore`, `merge`

- Subject under ~80 chars, lowercase type/scope, start with clear verb
- Body: 2–3 `-m` flags max, summarize key changes in 3–5 sentences
- End body with `Files: <key files>`
- Present 3 candidate messages, let user pick
- Ask before pushing

---

## Rate Limit Prevention

- Be concise. Don't repeat the user's request.
- Plan before tool batches. Target ~3–5 calls per response.
- Batch independent operations. Reuse data already fetched.
- Target ~300 lines per response. Split if exceeding.

---

## Core Principles

- **Simplicity First** — Minimal change, minimal surface area
- **No Laziness** — Root-cause fixes only, no temporary patches
- **Minimal Impact** — Touch only what is required
- **Demand Elegance** — Pause on non-trivial changes to evaluate better approaches
- **Autonomous Bug Fixing** — Fix directly using logs, errors, and failing tests
