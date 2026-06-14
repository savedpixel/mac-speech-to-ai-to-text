# Plan: Generate Rules Second-Pass Audit

> **Status:** Complete
> **Created:** 2026-05-23
> **Estimated steps:** 5
> **Risk level:** Low

## Context

The user requested another rigorous pass over the Copilot + Codex instruction-generation result.

## Relevant Lessons

- Apply the prior target-selection lesson: only targets 1 and 3 were selected, and unrequested Slack/VPS workflows remain excluded.

## Implementation Steps

- [x] Inspect generated artifacts and actual project paths.
- [x] Compare files against generator count/contract requirements for selected targets.
- [x] Repair thin or implicit contract language in prompts, instructions, and skills.
- [x] Align `.agents/` with the repo's existing generated-agent-file ignore policy.
- [x] Re-run artifact and forbidden-workflow checks.

## Verification

- [x] Required Copilot + Codex files exist.
- [x] `AGENTS.md` remains below 32 KiB.
- [x] No non-selected Cursor/Claude/OpenCode targets were generated.
- [x] No Slack/VPS/admin/page-editor/merge-master workflows were generated.
- [x] No stale `applyTo: 'MacVoice/**'` source glob remains in generated instruction files.

## Not Tested

- Native app runtime behavior is not tested because this pass only audits and repairs agent instruction artifacts.
