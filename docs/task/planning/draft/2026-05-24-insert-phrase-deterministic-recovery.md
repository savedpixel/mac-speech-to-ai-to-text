# Insert Phrase Deterministic Recovery

<!-- Updated: 2026-05-24 -->

Relevant Lessons:

- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.
- Intermittent microphone/input failures need persistent app-owned diagnostic logs before claiming the issue is fixed.
- When a spoken trigger is configured as `OK`/`ok`, include exact `okay` as an equivalent speech-recognition variant.

## Problem

The insert phrase is still not reliable in real use. It can start listening but fail to insert when the user says `insert`.

## Goal

Make post-completion insertion deterministic enough to debug and recover from Speech framework stalls:

1. Log every insert listener phase with current pipeline state.
2. If the listener receives no partials, restart it quickly and repeatedly while the overlay remains complete.
3. Avoid stale recognition tasks and request objects.
4. Make matching less brittle.
5. Preserve original target insertion and return-app behavior.

## Verification

- Inspect latest diagnostics before changing code.
- Run `swift build`.
- Run `bash scripts/build-app.sh` to package/sign/reopen.
- Verify visible version.
