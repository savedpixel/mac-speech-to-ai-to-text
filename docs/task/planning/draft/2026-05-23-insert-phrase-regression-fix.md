# Insert Phrase Regression Fix

<!-- Updated: 2026-05-23 -->

Relevant Lessons:

- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.
- Intermittent microphone/input failures need persistent app-owned diagnostic logs before claiming the issue is fixed.
- When a spoken trigger is configured as `OK`/`ok`, include exact `okay` as an equivalent speech-recognition variant.

## Problem

The insert phrase stopped working after recent insertion/focus/audio changes.

## Goal

Restore reliable insert phrase detection after the completed state, with diagnostics showing why listener startup, restart, or recognition matching succeeds/fails.

## Plan

1. Inspect current diagnostics for `[insert]`, `[pipeline]`, and `[input]` events after completion.
2. Fix the most likely listener lifecycle issue without broad rewrites.
3. Keep target/return-app insertion behavior intact.
4. Bump version/build, build/package/sign/reopen, and verify visible version.
