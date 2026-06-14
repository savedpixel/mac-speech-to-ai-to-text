# Anomalies

| Date | Source | Observation | Impact | Action | Status |
| --- | --- | --- | --- | --- | --- |
| 2026-05-19 | Microphone Stability Debug | MediaController AppleScript checks are denied Apple Events access to System Events in the current runtime logs. | Minor | If Spotify pause/resume must be guaranteed, grant/confirm Automation permission or keep relying on the media-key fallback where possible. | Open |
| 2026-05-24 | Documentation Parity Audit | `.gitignore` ignores `docs/`, so documentation indexes and parity reports are local-only and are not represented in committed history. | Medium | Decide whether internal docs should stay ignored or whether selected docs/reports should be tracked with explicit path staging. | Open |
