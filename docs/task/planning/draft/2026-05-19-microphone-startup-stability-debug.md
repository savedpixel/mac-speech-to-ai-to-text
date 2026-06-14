# Microphone Startup Stability Debug

<!-- Updated: 2026-05-19 -->

## Goal

Make shortcut-triggered recording reliable while other microphone-capable apps remain open. The app should recover from transient microphone route/contention failures without requiring the user to close Codex, browser, meeting apps, or other current apps.

## Current Symptoms

- The macOS microphone indicator flickers when Mac Speech to AI to Text attempts to start recording.
- Recording frequently fails before becoming live.
- The failure is worse when other apps that can access the microphone are open.

## Constraints

- Keep the existing signing/certificate flow intact.
- Bump the app bundle version for each implementation change.
- Rebuild and relaunch after code changes.
- Avoid broad redesigns; root-cause the startup failure and keep impact focused.
- Do not commit or push without explicit user approval.

## Investigation Plan

1. Capture current app build/runtime state, signing metadata, and recent audio logs.
2. Inspect all mic-owning components: `AudioRecorder`, `WakePhraseListener`, `InsertPhraseListener`, settings toggles, and app lifecycle wiring.
3. Reproduce recording startup with the current open-app environment and identify the exact failure mode.

## Implementation Plan

1. Harden recorder startup so transient `AVAudioEngine`/route failures retry with short backoff before surfacing an error.
2. Make wake/insert phrase listener teardown deterministic before shortcut recording claims the microphone.
3. Avoid passive mic listeners automatically competing with active recording or immediate post-recording transcription.
4. Add targeted OSLog instrumentation for mic acquisition, retries, route changes, and selected input fallback.
5. Bump app version/build while preserving signing identity configuration.

## Verification Plan

1. Run `swift build` after the change.
2. Rebuild/sign/relaunch with `scripts/build-app.sh`.
3. Manually trigger recording multiple times with current apps still open.
4. Confirm the overlay reaches live recording and captures non-empty audio repeatedly.
5. Check logs for retry/recovery behavior and absence of persistent mic acquisition failures.

## Completion Criteria

- Shortcut-triggered recording works repeatedly without closing existing apps.
- Mic indicator may turn on, but should not flicker and fail as the normal outcome.
- App is rebuilt, signed, relaunched, and version-bumped.
- Remaining untested edge cases are explicitly listed for user verification.
