---
description: Mandatory agent observation logging — anomalies, recommendations, and critical findings must be disclosed before commit
applyTo: 'MacVoice/**'
---

# Agent Observation Logs — Mandatory Disclosure System

## Purpose

During any task, you will encounter information the user needs to know. **You MUST proactively disclose these findings.** Silence is a violation.

---

## Directory Structure

```
docs/agent-observations/
├── critical.md
├── recommendations.md
├── anomalies.md
└── closed/
    ├── critical.md
    ├── recommendations.md
    └── anomalies.md
```

- **Root files** = open/in-progress items only.
- **Closed files** = append-only resolved archives.

---

## The Three Observation Logs

### 1. `critical.md` — Blocking Issues
Data inconsistencies, security misconfigurations, broken assumptions, regression risks, data corruption.

### 2. `recommendations.md` — Improvement Suggestions
Follow-up tasks, optimization opportunities, architectural improvements.

### 3. `anomalies.md` — Inconsistencies & Drift
Doc/code divergence, unused components, mismatched config values.

---

## Entry Format

```markdown
| {date} | {source} | {observation} | {impact} | {action} | Open |
```

---

## When to Write Observations

### During Implementation (MANDATORY)
1. Data consistency
2. Code/doc alignment
3. Assumption validation
4. Side effects of changes
5. Things outside your task scope

### During Planning / During Reporting
Log anything unexpected, cross-post findings.

---

## The Observation Gate — BLOCKING

Before you commit:
1. Review your work.
2. Classify observations.
3. Append entries.
4. If no observations: `Observations: none.`

**Silence is a violation. CRITICAL — NO SKIPPING.**

---

## Closing Observations — Move to `closed/`

1. Remove row from root file.
2. Append to `closed/` file with `Closed` status and date/reason.
3. Critical: only user can authorize closing. Recommendations/anomalies: you may close if fixed.

---

## Cross-References

- **Reports:** cross-post findings.
- **Plans:** read logs first.
- **Execution:** check for relevant items.
- **Task Documentation:** observation gate runs BEFORE docs.

---

## Enforcement Summary

| Situation | Action |
|---|---|
| Broken/dangerous | Append to `critical.md` immediately |
| Improvement suggestion | Append to `recommendations.md` before commit |
| Inconsistency | Append to `anomalies.md` before commit |
| No observations | State "Observations: none" |
| Generating report | Cross-post to observation logs |
| Creating plan | Read observation logs first |
| About to commit | Verify logged or "none" |
| Resolved | Move root → `closed/` |
