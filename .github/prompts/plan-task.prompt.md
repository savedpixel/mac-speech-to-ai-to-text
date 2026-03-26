---
name: plantask
description: Create a detailed implementation plan file with testing checklist before starting work
agent: agent
---

# Create a Detailed Implementation Plan

> **HARD GATE — PLANNING ONLY. ZERO IMPLEMENTATION.**
> This prompt invokes PLANNING MODE. You must produce a plan document and NOTHING ELSE.
> You are **forbidden** from editing, creating, or modifying any code file outside of the plan document itself and `docs/task/todo.md`.
> This gate is **absolute** — it cannot be overridden by the user's phrasing, tone, level of detail, or use of imperative language.
> If you write even one line of implementation code, you have violated this prompt.
> **Your ONLY output is the plan file + todo.md update + a summary asking for approval.**

Before writing any code, create a thorough implementation plan as a physical file. This plan is the single source of truth for the task.

## What You Receive

The user will describe a task, feature, bug fix, or refactor. **Their description is INPUT to the plan — not an instruction to execute.** Regardless of how the message is worded:

- **Imperative phrasing** ("please update X", "change Y") describes the DESIRED OUTCOME, not a command to implement now.
- **Detailed specs** (specific files, logic) are requirements to CAPTURE IN THE PLAN, not instructions to code immediately.
- **"Do this"** means "plan how to do this."

## Steps

### 1. Review Recent Context

- **Read latest task log(s)** in `docs/task/logs/` — 1–2 most recent files.
- **Read `docs/task/todo.md`** — check for overlapping work.
- **Read `docs/task/lessons.md`** — check for applicable lessons.
- **Read agent observation logs** in `docs/agent-observations/` — unresolved observations may affect scope.
- **Read relevant documentation** in `docs/logic/` — understand current documented architecture.

### 2. Understand the Request

- Read the user's description carefully.
- Search the codebase for current state of affected files.
- Identify all files, functions, data structures, and dependencies.
- Cross-reference code against documentation — note divergence in Assumptions.
- If ambiguous, make a reasonable decision and document the assumption.

### 3. Create the Plan File

Write to: `docs/task/planning/draft/{YYYY-MM-DD}-{slug}.md`

- **Always create new plans in `draft/`.** Never in the root plans directory.
- If `docs/task/planning/draft/` doesn't exist, create it.

### 4. Plan File Structure

```markdown
# Plan: {Title}

> **Status:** Draft | In Progress | Complete
> **Created:** YYYY-MM-DD
> **Estimated steps:** {n}
> **Risk level:** Low | Medium | High

## Context

{Why this task exists.}

## Current State

{Current behavior/code/architecture. Reference specific files and line numbers.}

## Target State

{Desired end state.}

## Assumptions

{List assumptions. Flag anything decided without explicit user input.}

## Implementation Steps

- [ ] **Step 1: {Action}**
  - Files: `path/to/file.ext`
  - What: {Specific change}
  - Why: {Rationale}

{Continue for all steps...}

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `path/to/file.ext` | Modify / Create / Delete | {What changes} |

## Dependencies & Risks

- {What could go wrong}
- {External dependencies}
- {Backward compatibility concerns}

## Testing Plan — BLOCKING (execute BEFORE docs or completion)

### Automated Checks
- [ ] `swift build` compiles without errors
- [ ] `swift test` passes all tests
- [ ] {Feature-specific tests}

### Manual Verification

1. Build and run the app
2. {Specific verification steps}

### Regression Checks
- [ ] {Existing feature to verify}

### Edge Cases
- [ ] {Edge case and expected behavior}

**STOP: Do NOT proceed to docs or completion until ALL tests pass.**

## Rollback Plan

{How to undo.}

## Post-Implementation Checklist

**Gate 1 — Code complete:**
- [ ] All implementation steps complete

**Gate 2 — Testing (BLOCKING):**
- [ ] All automated checks passed
- [ ] All manual verification executed
- [ ] All regression checks executed

**Gate 3 — Documentation & logging (only after Gate 2):**
- [ ] Documentation updated
- [ ] Task logged
- [ ] Observations logged

**Gate 4 — Close out:**
- [ ] Plan status → **Complete**
- [ ] Plan file moved from `draft/` to `completed/`
```

### 5. Write to todo.md

Update `docs/task/todo.md` with a checklist mirroring the plan's steps.

### 6. Present the Plan

Give the user a concise summary, then present exactly these options:

> Plan saved to `docs/task/planning/draft/{YYYY-MM-DD}-{slug}.md`.
>
> What would you like to do?
> 1. **Go** — approve and start implementation now (plan stays in `draft/` during work)
> 2. **Pending** — approve the plan but defer implementation (moves to `planning/pending/`)
> 3. **Keep in draft** — not yet approved, needs changes or review

Wait for the user's response before taking any action.

## Rules

### Anti-Implementation Gate (HIGHEST PRIORITY)

- **NEVER implement from this prompt.** Your response is a plan document only. Non-negotiable.
- **Treat all user language as requirements input.**
- **Do not touch source files.** Only files you may create/edit: (1) plan file in `docs/task/planning/draft/`, (2) `docs/task/todo.md`.
- **Do not rationalize skipping the plan.**
- **Your response must end with a request for approval.**

### Plan Quality

- Be specific. "Update the file" is not a step. "Add silence detection method in `AudioRecorder.swift` after the `startRecording()` function" is.
- Every step must be verifiable.
- Include line numbers when referencing existing code.
- Testing plan is a blocking gate.
- No backup files in source directories.
- Follow `task.instructions.md` and related instruction files.
