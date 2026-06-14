# Documentation Index

<!-- Generated with generate-rules.prompt.md | ruleset: index-driven-doc-maintenance-v1 -->

<!-- Updated: 2026-05-24 -->

This index is the source of truth for documentation routing. Agents must consult this file before choosing which documentation to read or update, then follow any nested `0-index.md` files in the selected area.

## Documentation Areas

| Area | Index / File | Use when |
| --- | --- | --- |
| Logic architecture | `docs/logic/0-index.md` | Source changes under `MacSpeechToAIToText/**`, `Package.swift`, app lifecycle, audio, transcription, input, UI, permissions, or persistence |
| Task tracking | `docs/task/todo.md`, `docs/task/logs/`, `docs/task/planning/` | Planning, execution, task logs, and lifecycle state |
| Lessons | `docs/task/lessons-active.md`, `docs/task/lessons-index.json`, `docs/task/lessons.md` | User corrections, evergreen rules, and path-aware lesson lookup |
| Agent observations | `docs/agent-observations/critical.md`, `recommendations.md`, `anomalies.md` | Risks, follow-ups, drift, and pre-commit disclosure |
| Reports | `docs/reports/YYYY-MM-DD-{slug}.md` | Saved audits, feature reports, and work summaries |

## Routing Rules

1. Start here for documentation routing; do not rely on long-lived hardcoded source-to-doc mappings alone.
2. For source changes, read `docs/logic/0-index.md` and then the relevant feature document(s).
3. Update every touched Markdown file's `<!-- Updated: YYYY-MM-DD -->` marker.
4. If a new documentation area is added, add or update the nearest `0-index.md` in the same change.
5. If no documentation update is needed, state why in the verification/close-out summary.

## Current Sweep Baseline

- Latest documentation parity sweep: `docs/reports/2026-05-24-documentation-parity-audit.md`.
- Current docs are local/internal artifacts because `docs/` is ignored by `.gitignore`; treat reports as local evidence unless that ignore rule is changed.
