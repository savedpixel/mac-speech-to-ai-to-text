# Plan: Generate Copilot and Codex Instruction Rules

> **Status:** Complete
> **Created:** 2026-05-23
> **Estimated steps:** 6
> **Risk level:** Medium
>
> **Status Lifecycle:** Draft → In Progress → Complete

## Context

The user asked to action `/Volumes/Byron Beats/agentic.documents/generators/generate-rules.prompt.md` and selected targets `1, 3`: GitHub Copilot and Codex. The generator requires update-mode behavior: read existing artifacts, preserve project-specific rules, upgrade legacy surfaces, add missing current-generation files, and exclude Slack/VPS workflows unless explicitly requested.

## Current State

- Existing Copilot files are present under `.github/instructions/` and `.github/prompts/`.
- Root `AGENTS.md` exists but lacks generator marker/current-generation Codex skill references.
- `.agents/skills/` does not exist.
- `docs/task/lessons.md` exists, but `docs/task/lessons-active.md` and `docs/task/lessons-index.json` are missing.
- Existing documentation routing points at `MacVoice/**`, while the actual source package path is `MacSpeechToAIToText/**`.
- No docs index files are present, so index-driven documentation routing needs a bootstrap index.

## Target State

- Copilot artifacts are current-generation and reference index-driven docs plus the 3-layer lessons system.
- Codex has a consolidated `AGENTS.md` and native `.agents/skills/` workflow skills.
- Missing docs/lesson index files are created.
- Conditional admin/page-editor/merge-master/Slack/VPS workflows are not generated because they do not apply or were not requested.

## Relevant Lessons

- Reused prior memory-derived rule: ask for generator target selection first and generate only selected targets.

## Implementation Steps

- [x] **Step 1: Bootstrap routing and lessons support files**
  - Files: `docs/0-index.md`, `docs/logic/0-index.md`, `docs/task/lessons-active.md`, `docs/task/lessons-index.json`
  - What: Add source-of-truth documentation and lesson routing metadata.
  - Why: Required by the generator's current index-driven and 3-layer lessons rules.

- [x] **Step 2: Upgrade Copilot instruction files**
  - Files: `.github/instructions/*.instructions.md`
  - What: Update main, task, doc-sync, observations, devtools, and ratelimiting instructions.
  - Why: Bring legacy artifacts in line with current generator rules.

- [x] **Step 3: Upgrade Copilot prompt files**
  - Files: `.github/prompts/*.prompt.md`
  - What: Update plan/execute/document/report/commit/commit-all prompts and add update-documentation prompt.
  - Why: Current generator requires richer workflow gates and documentation refresh support.

- [x] **Step 4: Upgrade Codex baseline**
  - Files: `AGENTS.md`
  - What: Replace legacy consolidated instructions with current-generation AGENTS guidance under 32 KiB.
  - Why: Codex target requires a root `AGENTS.md` universal fallback.

- [x] **Step 5: Add Codex workflow skills**
  - Files: `.agents/skills/*/SKILL.md`
  - What: Add plan-task, execute-plan, document-task, commit, commit-all, report, visual-verification, and update-documentation skills.
  - Why: Codex target uses native skills in place of Copilot prompts.

- [x] **Step 6: Audit generated artifacts**
  - Files: all generated/updated artifacts
  - What: Verify required files exist, key contracts are present, and skipped conditionals are justified.
  - Why: Generator requires artifact-by-artifact and full-system checks.

## Testing Plan — BLOCKING

### Automated Checks
- [x] Validate required files exist for targets 1 and 3.
- [x] Verify `AGENTS.md` is below 32 KiB.
- [x] Search generated artifacts for stale `MacVoice/**` source globs where `MacSpeechToAIToText/**` should be used.
- [x] Search for excluded Slack/VPS workflow artifacts.

### Manual Verification
- [x] Review representative Copilot and Codex artifacts for project-specific accuracy.
- [x] Confirm no source Swift files were modified by instruction generation.

## Not Tested

- Native app runtime behavior is not tested because this task edits agent instruction/docs workflow files only.

## Post-Implementation Checklist

- [x] All implementation steps complete
- [x] Automated artifact checks passed
- [x] Observations logged or explicitly none
- [x] Task log updated
- [x] Plan status set to Complete
