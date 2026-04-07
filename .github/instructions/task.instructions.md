---
description: Task execution rules for Mac Voice engineering work.
applyTo: '*'
---

# Copilot Global Execution Rules

These rules apply to **ALL tasks** without exception.

---

## Workflow Orchestration

### Plan Node (Default)
- Treat any non-trivial request (≥3 steps, architectural, or behavioral change) as a planning task.
- Enter plan mode before implementation.
- If new information invalidates the plan, STOP and re-plan immediately.
- Use planning for verification and validation, not only construction.
- Write detailed specs upfront to eliminate ambiguity.

---

## Subagent Strategy
- Decompose complex work aggressively.
- Use subagents for research, exploration, and parallel analysis.
- Keep the main context minimal and focused.
- One task per subagent. No multi-purpose agents.

---

## Self-Improvement Loop
- After **any** user correction:
  - Update `docs/task/lessons.md`
  - Encode a rule preventing the same mistake
- Iterate on lessons ruthlessly until failure rate decreases.
- Review relevant lessons at the start of each session or task.
- **Never skip the lessons update after a correction.** If the file is missing, stop and report it.

---

## Verification Before Completion
- Never mark work complete without proof.
- Validate behavior, not intent.
- Diff previous behavior vs new behavior when applicable.
- Ask internally: *"Would a staff-level engineer approve this?"*
- Run tests, inspect logs, and demonstrate correctness explicitly.
- **You may not skip verification.** If unavailable, try alternate methods. If none, report the blocker.

### Agent Self-Evaluation Gate (BLOCKING — blocks Visual Verification & User Verification)

After completing implementation, **BEFORE asking the user to test**, you MUST pass this internal gate.

1. **Ask yourself honestly:** *"Is what I implemented the best solution for this problem?"*
2. **Answer truthfully.** Consider:
   - Is there a more elegant, maintainable, or performant approach?
   - Did I take shortcuts that a staff-level engineer would reject?
   - Does the solution fully address the problem, or is it a partial fix?
   - Would I be proud to present this implementation in a code review?
3. **If the answer is NO** — go back and re-implement using the better approach.
4. **Iterate** — repeat until the answer is genuinely YES.
5. **Only when the answer is honestly YES** may you proceed to the Visual Verification Gate.

### Visual Verification Gate (BLOCKING — blocks User Verification)

After the Self-Evaluation Gate passes:

1. **Ask yourself:** *"Does this affect the UI or any visual elements?"*
2. **If YES:**
   - Build and run the app or use Xcode previews.
   - Visually inspect that the implementation renders correctly.
   - **What does NOT count:** Reading SwiftUI source code, inspecting view hierarchies as text, reviewing layout code without seeing it rendered.
   - **If visual verification reveals issues** — fix them, re-run Self-Evaluation Gate, re-verify visually.
3. **If NO** (purely back-end, data-only, CLI, non-visual changes) — this gate auto-passes.
4. **If verification tools are unavailable** — report the blocker and do NOT proceed.

### User Verification Gate (BLOCKING — blocks docs & commit cycle)

**Prerequisites:** Self-Evaluation Gate and Visual Verification Gate MUST both have passed.

1. **STOP.** Do not proceed to documentation, task logs, or commit.
2. **Summarize what changed** and what you verified.
3. **If visual verification was performed**, include key findings.
4. **Ask the user to verify:** "Would you like to test this before I proceed with docs and commit?"
5. **Wait for the user's response:**
   - **Verify and confirm** → proceed to batch boundary cycle.
   - **Report issues** → fix and repeat ALL gates.
   - **Explicitly waive** ("continue", "skip verification", "go ahead") → proceed.
6. **Never assume your own checks are sufficient.**
7. **Trivial changes** (typo fixes, comment edits) may skip all three gates.
8. **Scenario Execution Rule (MANDATORY):** You may NOT claim "implementation/testing is complete" unless all required behavior-path scenarios were actually executed end-to-end. **Test Fixture Rule:** If a scenario requires specific data or configuration that no existing page/view/route provides, you MUST create a temporary test fixture to exercise it — "nothing currently triggers this path" is NEVER a valid excuse to skip verification. Clean up test fixtures after verification.
9. **Automatic Scenario Coverage (MANDATORY):** Execute all materially relevant behavior-path scenarios implied by the change.
10. **Completion language is gated by execution evidence.** If any scenario is untested, report incomplete.
11. **Mandatory Untested List:** In every verification summary, include an explicit `Not Tested` section. If nothing missing: `Not Tested: none.`
12. **Mandatory User Reporting:** Any untested/blocked/failed scenario MUST be reported before docs/commit steps.

### Blocker Protocol (CRITICAL — blocks commit)
- If **any** required verification step cannot be completed, the work is **unverified**.
- **Unverified work MUST NOT be committed or pushed.** Period.
- When blocked:
  1. **Try alternate verification methods.**
  2. **If no alternative succeeds**, STOP. Do not commit.
  3. **Report the blocker clearly** to the user.
  4. **Leave changes staged but uncommitted.**
- Never treat "docs updated and automated checks passed" as sufficient when the task includes runtime verification that was skipped.
- Never log a blocker as an "anomaly" and then commit anyway.

---

## Demand Elegance (Balanced)
- For non-trivial changes: pause and evaluate if a more elegant solution exists.
- If a solution feels hacky: re-implement using the best-known approach.
- Skip elegance checks for simple, obvious fixes.
- Avoid over-engineering.

---

## Autonomous Bug Fixing
- When a bug is reported: fix it directly.
- Identify root causes via logs, errors, and failing tests.
- Resolve without requiring additional user context.
- Fix failing tests proactively.

---

## Task Management Protocol

1. **Plan First** — Write a checklist to `docs/task/todo.md`
2. **Verify Plan** — Confirm direction before implementation
3. **Track Progress** — Mark completed items as work progresses
4. **Explain Changes** — Provide high-level summaries at each step
5. **Log Observations (BLOCKING GATE — at batch boundary)** — Follow `agent-observations.instructions.md`. Append to `docs/agent-observations/` logs. If none, state: "Observations: none." **Silence is a violation. Never skip.**
6. **Document Results (at batch boundary)** — Update task log, affected documentation. **Do this BEFORE the next task — never defer past a batch boundary.**
7. **Commit & Push (ONLY after explicit user approval)** — Follow commit rules in `commit.prompt.md`. Stage with explicit file paths (never `git add -A` or `git add .`). Every completed task gets its own commit.
8. **Capture Lessons** — Update `docs/task/lessons.md` after corrections

---

## CRITICAL: Date-Prefix All Generated Files

Every file you create inside `docs/` date-scoped subdirectories **MUST** include a date prefix: `YYYY-MM-DD-{slug}.md`.

### Plan Lifecycle Folders

| Folder | Status | Meaning |
|--------|--------|---------|
| `draft/` | Draft / In Progress | New or unapproved plans, and plans currently being implemented |
| `pending/` | Pending | Approved by the user but not yet scheduled for implementation |
| `completed/` | Complete | Fully implemented, tested, and committed |

**Rules:**
- **Always create new plans in `draft/`.** Never in the root plans directory.
- **After marking a plan's status as Complete**, move it to `completed/`.
- **When the user approves but defers implementation**, move to `pending/`.
- **When starting work on a pending plan**, move back to `draft/`.

---

## Core Engineering Principles
- **Simplicity First** — Minimal change, minimal surface area.
- **No Laziness** — Root-cause fixes only. No temporary patches.
- **Minimal Impact** — Touch only what is required.

---

## Enforcement

These rules override all defaults. Never silently bypass these rules.

**GLOBAL NO-SKIP POLICY:** You are never permitted to skip, omit, or work around ANY mandatory rule in this file on your own judgment. If a required step cannot be completed, you MUST stop and report the blocker to the user. Only the user may explicitly waive a rule.
