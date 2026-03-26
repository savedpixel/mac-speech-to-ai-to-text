---
description: Document the task(s) just completed — update task log, sync docs
agent: agent
---

# Document & Log Completed Work

You just helped me complete one or more tasks in this chat session. Now document everything per the project rules.

## Steps

1. **Review what was done** — Scan this conversation to identify all completed work. Note which files were touched.

2. **Update today's task log** — Append row(s) to `docs/task/logs/YYYY-MM-DD.md` (use today's date). Create the file if it doesn't exist. Follow this format exactly:

```markdown
# Task Log — MM/DD/YYYY

> {n} tasks

| Title | Description | Start Date | End Date | Category | Type |
| --- | --- | --- | --- | --- | --- |
| {Action-oriented title} | {Concise outcome-focused description} | MM/DD/YYYY | MM/DD/YYYY | {Category} | {Type} |
```

- **Category**: `Audio` · `Transcription` · `Input` · `UI` · `Core` · `Permissions` · `Bug` · `Docs`
- **Type**: `Task` · `Sprint`
- Consolidate related sub-tasks into one row when same scope
- Keep descriptions outcome-focused
- Update the `> {n} tasks` counter

3. **Log agent observations (BLOCKING GATE)** — Follow `.github/instructions/agent-observations.instructions.md`. Append entries to `docs/agent-observations/`:

   - `critical.md` — Blocking issues, data inconsistencies, security concerns, broken assumptions
   - `recommendations.md` — Improvement suggestions, optimization opportunities, follow-up tasks
   - `anomalies.md` — Inconsistencies, drift between docs and code, oddities

   If no observations: `Observations: none.` **Silence is a violation.**

4. **Update affected documentation** — Based on which files changed, update the relevant docs. Check each rule in `doc-sync.instructions.md`:

   - Audio recording/playback changes → `docs/logic/audio.md`
   - Whisper/transcription changes → `docs/logic/transcription.md`
   - Shortcut/text insertion changes → `docs/logic/input.md`
   - Menu bar/preferences changes → `docs/logic/menubar-ui.md`
   - App lifecycle/permissions changes → `docs/logic/core.md`

   If no docs need updating (rare), explicitly state why.

5. **Confirm completion** — List what was logged, what observations were recorded (or "none"), and which docs were updated.

## Rules

- Never defer documentation — do it all now
- Never leave observations undocumented
- Never create backup files in source directories
- Don't ask for confirmation — just do it
- Group same-scope work into single rows
