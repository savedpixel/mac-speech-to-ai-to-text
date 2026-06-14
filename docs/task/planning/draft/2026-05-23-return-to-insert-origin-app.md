# Return to Insert-Origin App After Target Paste

<!-- Updated: 2026-05-23 -->

Relevant Lessons:

- After any MacVoice source/code change, bump the visible bundle version/build, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.

## Goal

When a recording starts in one app/input, the user switches to another app, and then triggers insertion from that second app, MacVoice should:

1. Restore the original recording target app/input.
2. Paste and submit the transcription there.
3. Return focus to the app the user was using when insertion was triggered.

## Implementation

- Capture the current frontmost app immediately when insertion is requested.
- Exclude the original insertion target and the MacVoice app from return-app restoration.
- After paste/submit completes, reactivate the return app using normal activation, AX frontmost/raise, and AppleScript fallback.
- Log the return app capture and restore result.
- Bump app version/build and rebuild/package/reopen.
