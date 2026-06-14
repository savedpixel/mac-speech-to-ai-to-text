# Documentation Parity Audit

<!-- Updated: 2026-05-24 -->

Prompt: `.github/prompts/update-documentation.prompt.md`  
Audit mode: **forced full re-audit**

## Baseline

No usable prior documentation parity report was found. `docs/reports/2026-03-30-marketing-website-brief.md` is a product/marketing brief, not a docs parity baseline. The committed repository history also does not currently track `docs/**`, because `.gitignore` ignores the entire `docs/` tree.

## History Reviewed

Committed history through `HEAD` was reviewed from `cad86c4 init` to `79e6427 fix(build): remove hardcoded signing identity from build script`:

- Initial workflow/instruction prompt scaffold under `.github/`.
- SPM package and build scripts.
- UI prompt-list/editor additions.
- Full app rename to **Mac Speech to AI to Text**, including source tree, sounds, history/prompt stores, preferences, overlay, menu bar, transcription, input, and README.
- Build script signing identity cleanup.

The current working tree was also compared because substantial runtime behavior is uncommitted locally, including microphone stability, diagnostics, version display, target restoration, and insert phrase reliability work.

## Docs and Indexes Updated

- `docs/0-index.md`
  - Updated marker to 2026-05-24.
  - Added this sweep as the current parity baseline.
  - Noted that `docs/` is local/internal because it is ignored by `.gitignore`.
- `docs/logic/0-index.md`
  - Updated marker to 2026-05-24.
  - Added packaging/build script routing to `docs/logic/core.md`.
- `docs/logic/audio.md`
  - Clarified send phrase detection and recorder-fed Speech recognition behavior.
  - Removed stale AVAudioSession guidance for macOS routing and replaced it with AVAudioEngine/CoreAudio routing guidance.
- `docs/logic/core.md`
  - Added build/package/relaunch behavior and app launch version/beep preload diagnostics.
  - Corrected stale history pruning language from count-based pruning to age-based retention.
- `docs/logic/input.md`
  - Corrected insert phrase routing language to selected-microphone reuse plus immediate voice-activity fallback.
- `docs/logic/menubar-ui.md`
  - Added explicit version footer behavior for visual build verification.
- `docs/logic/transcription.md`
  - Updated marker and documented model integrity scanning for downloaded Whisper models.

## Remaining Gaps

| Gap | Impact | Follow-up |
| --- | --- | --- |
| `docs/` is ignored by `.gitignore` | Documentation parity reports and indexes are local-only and do not appear in committed history | Decide whether internal docs should remain ignored or whether selected docs/reports should be tracked |
| Current source changes are uncommitted | Committed history does not yet represent the v1.0.20 runtime behavior documented locally | At commit time, stage explicit paths only and include the relevant docs if the ignore policy changes |
| Existing release build emits warnings in unrelated areas | Build still succeeds, but deprecation/Sendable/CoreAudio pointer warnings remain | Address separately in a warning-cleanup task |

## Verification

- Started routing from `docs/0-index.md`, then followed `docs/logic/0-index.md`.
- Reviewed committed history with `git log --name-status` and compared against current source/docs.
- Confirmed affected docs contain `<!-- Updated: 2026-05-24 -->` markers.
- Cross-posted the ignored-docs parity risk to `docs/agent-observations/anomalies.md`.
