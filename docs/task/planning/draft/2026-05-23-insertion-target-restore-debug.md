# Insertion Target Restore Debug and Fix

<!-- Updated: 2026-05-23 -->

Relevant Lessons:

- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.
- Intermittent microphone/input failures need persistent app-owned diagnostic logs before claiming the issue is fixed.

## Problem

The insert phrase now triggers, but when recording starts from the Codex textbox, then the user switches to a browser and says `insert`, the app does not return to Codex and does not paste text.

## Goals

1. Make insertion-target restoration independent of the currently frontmost app.
2. Add enough diagnostics to see whether app activation, AX focus, mouse-click focus, paste, and submit were attempted.
3. Add a reusable local test/debug harness so the behavior can be exercised without repeatedly asking the user.
4. Bump version/build and rebuild/package/reopen after the fix.

## Plan

### Step 1 — Inspect current diagnostic path

- Review `TextInserter`, `PipelineCoordinator`, and the latest diagnostic logs for insertion restore failures.

### Step 2 — Harden target restoration

- Store target app PID, bundle ID, app URL, AX focused element, and element bounds.
- Restore target with multiple strategies: running app activation, AX application frontmost/raise, workspace open by URL/bundle ID, AX focus, and click-at-saved-element-center fallback.
- Add small delays and verification logs after each restore step.
- Ensure paste/enter logs show whether the active app after restore is the expected target.

### Step 3 — Add local test aid

- Add a script that opens a local text-input fixture in the browser and can generate/use typed fixture text for insertion-target testing. Where microphone automation is not possible, the script should at least provide deterministic foreground-switch and target-box verification instructions/log points.

### Step 4 — Versioned verification

- Bump `CFBundleShortVersionString` and `CFBundleVersion`.
- Run `swift build`.
- Run `bash scripts/build-app.sh` to close/package/sign/reopen.
- Verify visible version and report any scenarios still requiring live microphone/Codex interaction.
