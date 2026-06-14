# Diagnostic Logging and Settings Repair

<!-- Updated: 2026-05-19 -->

## Goal

Make microphone startup failures traceable when another app, especially Codex, has just used the microphone, and repair the settings page if the UI has drifted visually.

## Symptoms

- After Codex uses the microphone, Mac Speech to AI to Text can appear to do nothing when the shortcut is used.
- OSLog alone is not enough because live logs are hard to capture after the fact.
- User reports the settings page looks wrong and needs visual correction.

## Plan

1. Add persistent diagnostic file logging that can be enabled from Settings.
2. Log every shortcut activation, pipeline state change, microphone permission state, mic acquisition attempt, selected mic routing, retry/failure, config-change decision, stop, and insert/listener handoff.
3. Store logs under Application Support so they survive relaunches and can be inspected later.
4. Add Settings controls for diagnostic logging and log-file access/status.
5. Visually inspect the current settings page, then repair the layout with minimal changes.
6. Bump version/build, rebuild/sign/relaunch, and verify shortcut + logging behavior with current apps open.

## Verification

- `swift build`
- `scripts/build-app.sh`
- Trigger shortcut after relaunch and confirm a new diagnostic log file contains the mic startup sequence.
- Visually inspect Settings page after rebuild.
