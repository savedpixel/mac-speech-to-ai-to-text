---
description: Generate a report on completed work, a feature area, or a specific topic — saved to docs/reports/
agent: agent
---

# Generate Report

You are generating a structured report. The report will be saved as a permanent markdown file in `docs/reports/`.

**CRITICAL — Voice & Authorship:** The report must be written **in the user's voice**. Never reference yourself (the agent, Copilot, AI, etc.) anywhere. Use first person ("I", "my") or neutral professional voice.

## What You Receive

The user may ask you to report on completed work, a specific feature area, or a topic. If unspecified, default to summarizing all work completed in this session.

## Steps

### 1. Gather Context

- Scan conversation for changes made.
- Check recent task logs in `docs/task/logs/`.
- Read relevant documentation in `docs/logic/`.
- Read agent observation logs in `docs/agent-observations/`.

### 2. Determine Report Type & Title

| Type | When to use |
|------|------------|
| `work-summary` | Summarizing completed work |
| `feature-report` | Deep dive on a feature |
| `audit` | Quality, security, performance analysis |
| `architecture` | Decisions, patterns, tech debt |
| `incident` | Bug investigation, root cause, resolution |
| `comparison` | Evaluating options |
| `status` | Sprint/project status |
| `custom` | Anything else |

### 3. Generate the Report File

**File path:** `docs/reports/{YYYY-MM-DD}-{slug}.md`

### 4. Report Structure

```markdown
# {Report Title}

> **Type:** {type}
> **Date:** YYYY-MM-DD
> **Scope:** {Brief scope description}

---

## Summary
## Context
## Details

### Files Involved

| File | Role |
|---|---|

## Findings / Outcomes
## Recommendations / Next Steps
```

### 5. Capture Recommendations & Anomalies (MANDATORY)

Scan report findings. If unresolved items exist, append to `docs/agent-observations/` logs. If none: `Observations: none.`

### 6. Save & Confirm

## Rules

- Always save to `docs/reports/`. Never inline-only.
- Be thorough but concise.
- Use specific file references.
- Don't fabricate information.
- Date-prefix filenames.
- Write in the user's voice. Never reference Copilot/AI/agent.
- No backup files in source directories.
- Cross-post observations to observation logs.
