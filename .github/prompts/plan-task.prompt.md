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
- Cross-reference code against documentation — note divergence in Open Questions.
- **Do NOT assume.** If something is ambiguous, add it to Open Questions (step 2.5).

### 2.5. Question Gate (Iterative)

Before writing the plan, you MUST identify any open questions about scope, approach, or constraints. This replaces silent assumptions.

**Rules:**
- Assign stable IDs to each question: Q1, Q2, Q3, … (never renumber across rounds)
- Present questions as a numbered list with a brief recommended answer for each
- Wait for the user to answer before proceeding to step 3
- If the user's answers raise new questions, add them with the next available ID (e.g., Q4, Q5) and ask again
- Repeat until zero open questions remain
- Questions answered in earlier rounds move to the **Confirmed Inputs** section of the plan
- **Once all questions are resolved:** update the plan file `Status` from `Questions Pending` to `Draft`

**Question categories to consider:**
- Inclusion/exclusion of optional features
- Ambiguous scope boundaries
- Technology or approach choices
- Backward compatibility requirements
- Existing code to preserve vs. replace

> **On plan revision:** If a plan is revised after initial creation, any new questions use the next available ID (continuing the sequence, not restarting). Previously answered questions retain their original IDs in Confirmed Inputs.

### 3. Create the Plan File

Write to: `docs/task/planning/draft/{YYYY-MM-DD}-{slug}.md`

- **Always create new plans in `draft/`.** Never in the root plans directory.
- If `docs/task/planning/draft/` doesn't exist, create it.

### 4. Plan File Structure

```markdown
# Plan: {Title}

> **Status:** Questions Pending | Draft | In Progress | Complete
> **Created:** YYYY-MM-DD
> **Estimated steps:** {n}
> **Risk level:** Low | Medium | High
>
> **Status Lifecycle:**
> - `Questions Pending` → created with open questions (initial state)
> - `Draft` → all questions answered, plan awaiting approval
> - `In Progress` → user approved, implementation started (via execute-plan)
> - `Complete` → all gates passed, committed, plan moved to `completed/`

## Context

{Why this task exists.}

## Current State

{Current behavior/code/architecture. Reference specific files and line numbers.}

## Target State

{Desired end state.}

## Confirmed Inputs

{Answers from the Question Gate. Each entry references its question ID.}

- **Q1:** {question} → {user's answer}
- **Q2:** {question} → {user's answer}

## Open Questions for User — BLOCKING

{Any remaining questions. If all questions are answered, state: "None — all questions resolved."}

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
