# Version Visibility and Mandatory Rebuild Rule

<!-- Updated: 2026-05-23 -->

Relevant Lessons:

- Apply the user's correction that every code/source change must bump the app version/build, rebuild, package, close/reopen, and expose the visible version before handing back for testing.

## Goal

Make versioning visible in the app and make the version-bump/rebuild/reopen workflow impossible to miss in repo rules, lessons, and Codex memory.

## Scope

1. Add a visible app version/build label in the bottom-left sidebar directly above `New Folder`.
2. Bump the app bundle version and build for this change.
3. Update repo agent rules and lessons with the mandatory version bump + rebuild/package/reopen workflow.
4. Add a Codex memory note with the same preference.
5. Rebuild, package, close/reopen the app before reporting back.

## Verification

- Run `swift build`.
- Run `bash scripts/build-app.sh` to close, rebuild/package/sign, and reopen the app.
- Verify build output reports success.
- Visual verification of the live app may require user-side confirmation if UI automation/screenshot access is unavailable.
