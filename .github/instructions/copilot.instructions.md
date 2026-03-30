---
description: Mac Voice project coding guidelines — auto-doc sync for app, features, and infrastructure
applyTo: '*'
---

# Mac Voice — Copilot Instructions

## Project Overview

Mac Voice is a macOS menu bar application built in Swift that provides system-wide voice-to-text input for active text fields, using local Whisper transcription, global shortcuts, and wake-phrase activation.

- **App:** `MacVoice/` — Swift source code, SwiftUI views, audio pipeline, input handling
- **Docs:** `docs/` — Architecture, deployment, and task documentation
- **Logic Docs:** `docs/logic/` — Feature-level architecture and behavior references

## Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (preferences window) · AppKit (NSStatusItem menu bar)
- **Audio:** AVAudioEngine · AVAudioRecorder · AVAudioSession
- **Transcription:** whisper.cpp (or WhisperKit) — local on-device Whisper inference
- **Input:** CGEvent (global shortcuts, key simulation) · Accessibility API (AXUIElement)
- **Speech Detection:** Speech framework (wake phrase) · Audio level monitoring (silence detection)
- **Persistence:** UserDefaults / @AppStorage
- **Package Manager:** Swift Package Manager (SPM)
- **Testing:** XCTest
- **Logging:** OSLog

---

## CRITICAL: Never Push to Live

You must **never** push, deploy, or sync code to the live/production environment. All live deployments are the user's responsibility. This includes:

- Running any deploy command that targets production
- Triggering any CI/CD pipeline that pushes to live
- Using `git push` to production branches

You may deploy to **local** or **staging** environments only.

---

## CRITICAL: Always Follow task.instructions.md

Before starting **any** task, you **MUST** read and follow the rules in `.github/instructions/task.instructions.md`. This includes:

- Planning before implementation (Plan Node)
- Writing checklists to `docs/task/todo.md` **for planned, multi-step work**
- Updating `docs/task/lessons.md` after any user correction
- Verification before marking work complete (3-tier verification gate pipeline)
- The full Task Management Protocol

These rules apply to **every** task. **Never skip this.** If `task.instructions.md` is missing or unreadable, stop and report it to the user.

> **The `manage_todo_list` IDE tool is NOT a substitute for `docs/task/todo.md`.** For planned multi-step work, you MUST write task checklists to the file. The IDE tool is supplementary only.

---

## CRITICAL: Document & Commit at Batch Boundaries (Session-Aware)

During iterative chat sessions, **implement changes immediately** but **defer** the documentation and commit cycle until a **batch boundary**.

### What is a batch boundary?

1. **User signals completion** — says "done", "commit", "push", "wrap up", or similar
2. **User changes topic** — moves to a clearly different task or feature area
3. **You reach ~5 accumulated changes** — auto-trigger
4. **Session is ending** — user says goodbye
5. **User explicitly asks to commit** — always commit immediately when asked

### At each batch boundary, run the full cycle ONCE:

0. **Pre-verification gates (BLOCKING):**
   - **a. Agent Self-Evaluation Gate** — *"Is this the best solution?"* If NO, re-implement.
   - **b. Visual Verification Gate** — If UI affected, verify with browser/Xcode preview. If purely back-end, auto-passes.
   - **c. User Verification Gate** — Summarize changes + verification. Ask user to verify. Wait for response.
   - **d. Scenario Evidence Rule** — All behavior-path scenarios must be executed end-to-end.
   - Trivial changes (typos, comments) may skip all gates.
   - **Steps 1–7 are LOCKED until step 0 completes.**
1. **Log agent observations (BLOCKING GATE)** — Follow `agent-observations.instructions.md`.
2. **Update the daily task log** — `docs/task/logs/YYYY-MM-DD.md`
3. **Update affected documentation** — per `doc-sync.instructions.md`
4. **Get explicit user approval before committing**
5. **Verification gate (BLOCKING)** — All verification steps must have passed.
6. **Commit & push (ONLY after explicit user approval)** — follow `commit.prompt.md`.

### Between batch boundaries:

- Implement changes as requested — no logging/commit overhead
- Keep mental track of changes

---

## CRITICAL: Never Auto-Commit or Auto-Push

You must **NEVER** commit or push without **explicit user approval**. When ready to commit:
1. Summarize what changed
2. Ask: "Ready to commit?"
3. **Wait for yes** before `git commit`
4. After committing, ask before pushing
5. **Wait for explicit approval** before `git push`

When committing, follow **all** rules in `commit.prompt.md`.

---

## CRITICAL: Date-Prefix All Generated Files

Every file you create inside `docs/` date-scoped subdirectories **MUST** include a date prefix: `YYYY-MM-DD-{slug}.md`.

- **Plans:** `docs/task/planning/draft/YYYY-MM-DD-{slug}.md`
- **Reports:** `docs/reports/YYYY-MM-DD-{slug}.md`

Exceptions: `todo.md`, `lessons.md`, daily logs (`YYYY-MM-DD.md`), observation files, existing reference docs.

---

## CRITICAL: No Backups in Source Directories

Never create backup files or temporary artifacts inside source directories. If you need a backup, place it in `docs/backups/` with a descriptive subfolder and timestamp.

---

## MANDATORY: Auto-Update Documentation

When working on files under `MacVoice/`, documentation sync rules apply via `doc-sync.instructions.md`.

- Update relevant docs **in the same response** as the code change
- Update "Last updated" dates on every doc edit
- Log completed work to today's task ledger: `docs/task/logs/YYYY-MM-DD.md`

### Quick Triage — Which Doc to Read First

| If this is broken… | Read first |
|---------------------|------------|
| Recording / audio capture | `docs/logic/audio.md` |
| Whisper / transcription | `docs/logic/transcription.md` |
| Shortcuts / text insertion | `docs/logic/input.md` |
| Menu bar / preferences | `docs/logic/menubar-ui.md` |
| Permissions / app lifecycle | `docs/logic/core.md` |

---

## Related Instruction Files

| When working on… | Read… |
|-------------------|-------|
| **ALL tasks (always read first)** | **`.github/instructions/task.instructions.md`** |
| **Rate limit prevention (always active)** | **`.github/instructions/ratelimitting.instructions.md`** |
| **Source code changes (doc sync rules)** | **`.github/instructions/doc-sync.instructions.md`** |
| **Pre-commit observations (source code work)** | **`.github/instructions/agent-observations.instructions.md`** |
| Documenting completed work | `.github/prompts/document-task.prompt.md` |
| Planning a task before implementation | `.github/prompts/plan-task.prompt.md` |
| Executing a planned task | `.github/prompts/execute-plan.prompt.md` |
| Generating a report | `.github/prompts/report.prompt.md` |
| Committing and pushing changes | `.github/prompts/commit.prompt.md` |

> **`.github/instructions/task.instructions.md` applies to EVERY task. Read it before starting ANY work.**

---

## MANDATORY: Task Tracking

Follow the full task lifecycle in `task.instructions.md`:

1. Add task item(s) in `docs/task/todo.md` before implementation
2. Create `docs/task/planning/draft/{YYYY-MM-DD}-{slug}.md` for multi-step tasks
3. Track progress in `docs/task/todo.md`
4. Move completed items out of `docs/task/todo.md`
5. Append a row to today's daily task log `docs/task/logs/YYYY-MM-DD.md`

### Task Ledger — Daily Log Files (`docs/task/logs/YYYY-MM-DD.md`)

```markdown
# Task Log — MM/DD/YYYY

> 0 tasks

| Title | Description | Start Date | End Date | Category | Type |
| --- | --- | --- | --- | --- | --- |
```

**Categories:** `Audio` · `Transcription` · `Input` · `UI` · `Core` · `Permissions` · `Bug` · `Docs`

**Types:** `Task` (single-scope) · `Sprint` (grouped multi-item work)

---

## Coding Conventions

### Swift

- Use Swift concurrency (async/await, actors) for all asynchronous work
- Prefer value types (structs, enums) over reference types where practical
- Use `@Observable` / `@ObservationTracking` (Swift 5.9+) over older `ObservableObject`
- Error handling with typed throws or custom error enums
- Use `OSLog` for structured logging, not `print()`
- Follow Swift API Design Guidelines for naming

### Components / Views

- SwiftUI for all new UI (preferences, overlays)
- AppKit only where SwiftUI lacks API (NSStatusItem, CGEvent taps)
- Keep views thin — business logic in dedicated managers/services
- Use `@AppStorage` for simple preferences, dedicated settings manager for complex config

### File Naming

- Swift files: PascalCase matching the primary type (`AudioRecorder.swift`, `ShortcutManager.swift`)
- Group by feature domain: `Audio/`, `Input/`, `Transcription/`, `UI/`
- Tests mirror source structure: `MacVoiceTests/Audio/AudioRecorderTests.swift`

---

## Dev Server & Build

```bash
cd /Volumes/Byron\ Beats/savedpixel/mac-voice
swift build          # Build the project
swift test           # Run tests
open Package.swift   # Open in Xcode
```

### CRITICAL: Always Build and Relaunch After Code Changes

After **any** source code change, you **MUST** build, rebuild the app bundle, and relaunch. Never leave the old app running.

```bash
cd /Volumes/Byron\ Beats/savedpixel/mac-voice
swift build
kill $(pgrep -f "Mac Voice") 2>/dev/null
bash scripts/build-app.sh
open "/Volumes/Byron Beats/savedpixel/mac-voice/build/Mac Voice.app"
```

This applies to every change — not just UI changes. Always build + relaunch immediately after editing source files. Never skip this step.
