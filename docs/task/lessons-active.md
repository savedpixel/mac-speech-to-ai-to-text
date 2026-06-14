# Active Lessons

<!-- Generated with generate-rules.prompt.md | ruleset: index-driven-doc-maintenance-v1 -->

<!-- Updated: 2026-05-23 -->

Consult this file first before planning or executing work. It contains evergreen lessons promoted from `docs/task/lessons.md`.

## Evergreen Rules

- For overlay waveform requests, match the requested visualization literally; do not substitute a different waveform style.
- When debugging intermittent microphone startup failures, add persistent app-owned diagnostic logging before claiming the issue is fixed.
- If a settings page looks wrong after a functional fix, inspect the actual rendered app window and repair visual regressions in the same batch.
- When a spoken trigger is configured as `OK`/`ok`, include exact `okay` as an equivalent speech-recognition variant.
- For instruction-generation work, generate only the targets the user selected and exclude Slack/VPS workflows unless explicitly requested.
- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.

## Promotion Rule

After any user correction, append the full lesson to `docs/task/lessons.md`, promote evergreen guidance here, and add or update a matching entry in `docs/task/lessons-index.json`.
