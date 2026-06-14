# Grok Build Stress-Test Brief — Mac Speech to AI to Text Improvement Audit

<!-- Updated: 2026-06-01 -->

Prepared for: Grok agent / external implementation agent  
Target repo: `/Volumes/Byron Beats/savedpixel/mac-voice`  
Current observed app: `Mac Speech to AI to Text` v1.0.23 build 24  
Source of evidence: current user/Codex thread, task logs, logic docs, live visual inspection of the running macOS app, and recent commits.

---

## 0. Executive Summary

This app already has a real, useful core: global shortcut voice capture, local WhisperKit transcription, optional AI cleanup, history, prompt management, model management, insert/copy workflow, and diagnostic logging. The current weak points are not a lack of features; they are **product coherence, layout hierarchy, recovery UX, reliability transparency, and workflow polish**.

The user wants a dramatic improvement, not a small bug-fix pass. The biggest gains should come from:

1. **Rebuilding the app shell and layout hierarchy** so it feels like a polished macOS utility instead of a debug/admin panel.
2. **Making the voice pipeline trustworthy** with state visibility, speed feedback, diagnostics surfaced in plain English, and reliable fallback actions.
3. **Separating everyday user workflows from advanced configuration**; Settings is currently a long technical scroll full of mixed concerns.
4. **Improving history, prompts, and post-processing UX** so recordings become a usable workspace, not just a log dump.
5. **Reducing perceived latency** through better progress states, queueing, model warmup clarity, and fast default paths.
6. **Adding a first-run/onboarding and recovery system** that explains permissions, shortcut usage, model readiness, API key status, and failure resolution.

The app should be treated as a premium macOS productivity product: compact, calm, clear, fast-feeling, keyboard-first, and highly reliable.

---

## 1. Current Product Mental Model

### What the app is supposed to do

A system-wide voice-to-text utility:

1. User presses shortcut or speaks wake phrase.
2. App records audio.
3. Local WhisperKit transcribes audio.
4. Optional AI cleanup transforms the transcript.
5. User copies/inserts/dismisses the result.
6. App stores recording, transcript, cleanup result, model, prompt, and history metadata.

### Current core surfaces

- **Primary sidebar:** App actions, Prompts, Settings, Library filters, Folders, Archive, Failed, version footer, New Folder.
- **History list/detail:** Date + transcript snippets, folder assignment, model label, recording playback, re-transcribe, re-clean, raw/cleaned text.
- **Prompts:** Prompt list and prompt editor, built-in default prompt protection, default indicator.
- **Settings:** Voice input, shortcuts, sound, diagnostics, transcription/model management, AI cleanup/provider/API key, media, overlay, storage, permissions.
- **Recording overlay:** Non-activating floating panel with waveform/progress/actions.
- **Menu bar:** Quick access and state indicator.

---

## 2. Historical Issues Already Encountered

These are not theoretical. They occurred during prior work or in this chat.

### AI cleanup / provider failures

- Generic `Invalid API response` hid the real cause.
- DeepSeek API key was valid when tested directly, but the app tested a stale Keychain value.
- API key field visually showed bullets for an old key, making it look like the newly pasted key was saved when it was not.
- Cleanup, translation, and extraction felt very slow.
- Provider errors were not actionable enough.
- AI cleanup failure remains stored on old history rows, so the main app still displays stale `Invalid API response` even after the app was fixed.

### Microphone and recording instability

- Intermittent microphone startup failures.
- Bluetooth route churn and `AVAudioEngineConfigurationChange` events caused unreliable recording start.
- Mic indicator flicker and route switching delays.
- Passive wake/insert listeners competed with shortcut recording.
- Need for persistent diagnostic logs became clear because OSLog alone was insufficient.

### Insert phrase / target insertion failures

- `ok` / `okay` variants were not always matched.
- Insert phrase listener sometimes received audio but no Speech partials.
- Insert phrase fallback could race with the pipeline returning to idle.
- App/input restoration was unreliable: result could paste into the wrong app or not paste before the overlay dismissed.
- Need for target app capture, AX focus restore, AppleScript fallback, click fallback, and diagnostic logs.

### Audio cue / feedback issues

- Beeps were sometimes missing because playback objects were not retained.
- Beep could be captured in the recording waveform when played after recorder startup.
- User needed clearer cues: shortcut accepted, recording live, send phrase accepted, transcription done, AI done, insert done.
- Signal sounds needed preloading and latency diagnostics.

### Model readiness / Whisper issues

- Selected model could fail after relaunch or appear downloaded but not prepared.
- App startup model loading slowed launch and could create confusing readiness states.
- Cached model path reuse needed hardening.
- UI currently says `Selected model not prepared` even while the selected downloaded model is listed, which is confusing.

### UI/layout issues reported or implied

- Settings page previously looked wrong after a functional fix.
- Fonts and spacing have felt too large / too zoomed in in related SavedPixel UI work; this app shows similar density problems in places.
- Sidebar has duplicate New Folder entries and an odd blank row.
- The settings page is a long technical scroll with low hierarchy.
- History detail is dominated by huge raw text blocks.
- Prompt editor looks like a debug form, not a polished writing interface.

---

## 3. Live Visual Inspection Notes

I inspected the running app visually via Computer Use.

### 3.1 History / detail view

Observed:

- Three-column layout: primary sidebar, history list, detail.
- Detail view shows a previous item with `AI cleanup failed — Invalid API response Raw Text`.
- The raw text is a very long, dense paragraph block.
- Copy button is tiny and floats near the text area.
- Re-transcribe / Re-transcribe & Clean / Re-clean buttons are present, but look like secondary debug controls rather than a polished recovery flow.
- Toolbar icons at the top duplicate some actions and are visually unclear.
- History list items are truncated and hard to scan.
- Sidebar includes duplicate `New Folder` entries and one blank row.
- Version footer is useful but visually disconnected from the rest of the navigation.

Problems:

- The main screen does not communicate “what should I do next?”
- Failure state is shown, but there is no guided fix: no “Retest AI key”, “Use saved new provider”, “Re-clean all failed”, or “Explain failure” action.
- Long transcriptions need structure: summary, raw transcript, cleaned text, metadata, recording controls.
- The current detail layout is not optimized for reading or acting.

### 3.2 Settings

Observed:

- Settings is one long scroll with sections: Voice Input, Shortcuts, Sound, Diagnostics, Transcription, AI Cleanup, Media, Overlay, Storage, Permissions.
- At the top, Voice Input has several technical controls with explanatory copy.
- Shortcuts show glyph-like buttons such as `⌥/` and `⇧⌘V`, but there is no clear “record shortcut” affordance.
- The Transcription section mixes model state, storage path, downloaded models, delete actions, and download controls in a dense list.
- AI Cleanup section shows provider/model/endpoint/key status and test button.
- DeepSeek field currently indicates a saved key ending in an old suffix; this is helpful but visually small.
- The page uses lots of thin dividers, wide rows, and small labels.

Problems:

- Settings needs tabs or groups. Current one-scroll layout is too long and makes important state hard to find.
- Danger actions like Delete model sit close to Use buttons without enough visual separation.
- Technical copy is too small and too dense.
- The active model state is contradictory: `Selected model not prepared` vs downloaded selected model shown below.
- API key replacement is safer now, but the section should show a clear validation state: Untested / Connected / Failed / Last tested.
- Permission status should be at the top during setup, not buried at bottom.

### 3.3 Prompts

Observed:

- Prompt list shows `Default Cleanup` and `New Prompt`.
- Built-in prompt name field is disabled.
- Main editor is a large grey text area using monospaced-looking text.
- Default status is tiny on the right.
- Add prompt is only a toolbar plus icon.

Problems:

- Prompt management feels unfinished.
- No prompt templates for cleanup, translation, extraction, summarization, rewrite, email, code, etc.
- No preview/test prompt flow using a sample transcript.
- No versioning, duplication, import/export, or restore defaults.
- Default/built-in state is visually too subtle.
- Editing prompt text should feel like writing/editing instructions, not editing a raw debug text area.

---

## 4. Highest Priority Product Improvements

### P0 — Make the app trustworthy and understandable

#### 1. Replace generic pipeline/failure output with guided recovery cards

Current issue:
- History shows failure text such as `AI cleanup failed — Invalid API response`, but the user must infer what to do.

Fix:
- Use structured failure cards with:
  - Stage: Recording / Transcription / Cleanup / Insertion.
  - Provider/model if AI failed.
  - Plain-English reason.
  - Last diagnostic event.
  - Suggested next action.
  - One-click actions: Retry, Test API Key, Switch provider, Re-clean, Copy raw, Open diagnostics.

Acceptance:
- A failed DeepSeek cleanup displays `DeepSeek rejected the saved API key` or exact provider reason.
- User can paste a new key, test, then re-clean from the same failure card.
- Old `Invalid API response` records can be reinterpreted or clearly marked as historical.

#### 2. Add a persistent top-level status dashboard

Current issue:
- User has to dig through Settings to know if the app is ready.

Fix:
- Create an `App` or `Dashboard` screen with readiness cards:
  - Microphone permission.
  - Accessibility permission.
  - Input Monitoring permission.
  - Selected microphone.
  - Shortcut configured.
  - Whisper model ready / preparing / missing.
  - AI cleanup connected / not configured / failing.
  - Last recording result.
  - Last failure.

Acceptance:
- On launch, user can see “Ready to record” or “2 setup items need attention”.
- Each problem has a direct action button.

#### 3. Improve AI provider setup and testing

Current issue:
- API key replacement was confusing and stale Keychain state caused a false failure.

Fix:
- AI setup should have a compact connection card:
  - Provider logo/name.
  - Endpoint.
  - Model.
  - Saved key suffix.
  - Last tested timestamp.
  - Connection status.
  - “Replace key” button that opens an explicit sheet.
  - “Test using pasted key before save” behavior.
  - Never prefill secrets.
- Add a provider compatibility test that runs a minimal live call and shows raw redacted response metadata.

Acceptance:
- Pasting a new DeepSeek key and testing shows `Connected: OK` and saves only after success.
- Saved old key cannot silently be used while replacement text is present.
- User can see exactly which key suffix was tested.

#### 4. Rework model readiness into a clear state machine

Current issue:
- The Settings page shows `Selected model not prepared` while the selected downloaded model is also listed.

Fix:
- Model states should be explicit:
  - Not downloaded.
  - Downloaded, not loaded.
  - Preparing.
  - Ready.
  - Failed preparation.
  - Corrupt / needs repair.
- Show a single selected model card instead of mixing status into a line of text.
- Include “Prepare now”, “Use smaller/faster model”, “Repair”, “Reveal storage”, and “Free space” actions.

Acceptance:
- User understands whether recording can start now and whether first transcription will be slow.
- No contradictory state copy.

---

## 5. P1 — Layout and UX Redesign Priorities

### 5.1 Redesign the main window shell

Problems:
- Sidebar is crowded and combines navigation, filters, folder creation, archive, failed state, version, and actions.
- Duplicate `New Folder` rows and a blank row make the app feel broken.
- The top-level `App` label is not visually obvious as a destination.

Recommendation:
- Use a cleaner macOS sidebar:
  - Section 1: Dashboard, History, Prompts, Settings.
  - Section 2: Library filters: All, Unfiled, Failed, Archive.
  - Section 3: Folders with inline add button.
  - Footer: version/build + diagnostics indicator.
- Remove duplicate New Folder rows.
- Put `New Folder` as a small plus button in the Folders header.
- Add icons with consistent visual weight.
- Use clearer selection colors and typography.

Acceptance:
- Sidebar never shows duplicate folder rows or blank selectable rows.
- A new user can immediately identify Dashboard, History, Prompts, Settings.

### 5.2 Split Settings into tabs or subsections

Problems:
- Settings is a long scroll.
- Critical permissions and connection status are buried.
- Advanced model controls compete with everyday settings.

Recommendation:
- Use a settings sidebar/segmented control:
  1. Setup & Permissions.
  2. Recording.
  3. Shortcuts & Phrases.
  4. Transcription Models.
  5. AI Cleanup.
  6. Output & Insertion.
  7. Sounds.
  8. Diagnostics.
  9. Storage.
- Move dangerous actions into confirmation sheets.
- Use cards for each setting group.
- Use inline help and “Why this matters”.

Acceptance:
- No settings screen requires scrolling through every unrelated feature to reach AI Cleanup or model management.
- Permission problems are visible on first open.

### 5.3 Redesign history detail as a document workspace

Problems:
- Current detail view is one long raw text block.
- Cleaned/raw/failure states are not organized.
- Re-transcribe controls look like debug buttons.

Recommendation:
- Detail view layout:
  - Header: title/date/status/model/prompt/folder.
  - Recording card: play/progress/duration/waveform mini-view.
  - Result tabs: Cleaned, Raw, Diff, Metadata.
  - Action bar: Copy, Insert, Re-clean, Re-transcribe, Export.
  - Failure card only when needed.
- Add “Make cleaned result primary” and show raw vs cleaned differences.
- Add generated title/summary for each transcript.

Acceptance:
- Long transcripts are readable without endless paragraph scanning.
- User can recover from AI failure from the detail screen.

### 5.4 Redesign prompt editor

Problems:
- Current prompt editor is too raw and grey.
- Built-in/default status is subtle.
- No prompt testing.

Recommendation:
- Prompt detail card:
  - Name, type, default status.
  - Prompt body with better editor styling.
  - Variables/format guide.
  - Test area: paste sample transcript, run against selected provider, preview output.
  - Duplicate built-in prompt.
  - Restore default.
  - Assign shortcut.
- Add prompt categories: Cleanup, Translate, Extract, Summarize, Rewrite, Custom.

Acceptance:
- User can create a translation/extraction prompt and test it before assigning it to a shortcut.

### 5.5 Improve recording overlay polish

Known needs:
- Overlay is central to the experience and should feel premium.

Recommendations:
- Better state transitions: Preparing → Listening → Recording → Processing → Cleaning → Done.
- Use clearer microcopy: “Recording from System Default”, “Say ‘go’ to finish”, “AI cleanup via DeepSeek”.
- Show elapsed time and optional audio level confidence.
- Add timeout/retry states for mic acquisition.
- Add cancel-safe behavior: “Keep recording in history?” if cancellation happens after audio exists.
- Completion overlay should show text in a compact card with Copy/Insert as primary actions.

Acceptance:
- User always knows whether the app is waiting for mic, recording, transcribing, cleaning, or done.

---

## 6. P1 — Reliability and Speed Improvements

### 6.1 Make perceived speed 500% better

Actual latency may remain from Whisper/AI, but perceived latency can be dramatically improved.

Recommendations:
- Warm selected Whisper model only when user wants “fast first transcription” mode.
- Add a readiness toggle: “Fast mode: keep model warm” vs “Battery saver: load on demand”.
- Show stage timers and expected remaining time.
- Stream AI cleanup if provider supports it, updating text as it arrives.
- For short voice notes, use fast models/prompts by default.
- Cache provider validation and avoid retesting on every cleanup.
- Use a “quick cleanup” prompt path with small `max_tokens` and no unnecessary verbosity.
- Add cancellation for AI cleanup without losing raw transcription.

Acceptance:
- User sees useful progress within 300ms of each stage starting.
- Short dictation cleanup feels nearly instant with a fast provider.

### 6.2 Add pipeline timeline diagnostics for users

Current diagnostics are file-based and technical.

Recommendation:
- For every recording, store a pipeline timeline:
  - Shortcut accepted at T+0.
  - Mic live at T+X.
  - Recording done at T+Y.
  - Whisper started/finished.
  - AI request started/finished.
  - Insert/copy action.
- Show this in a collapsible “Diagnostics” panel per recording.

Acceptance:
- User can tell exactly where slowness happened.

### 6.3 Harden AI cleanup for provider differences

Already improved, but Grok should go further:

- Add provider-specific request adapters.
- Add model capability metadata: supports streaming, max output, tool use, JSON mode.
- Add retry policy for transient 429/5xx with backoff.
- Add “provider fallback” chain: DeepSeek → OpenAI → local raw.
- Add redacted request/response debug capture.
- Add tests with fixtures for OpenAI, DeepSeek, Groq, Mistral, OpenRouter, Gemini-compatible responses.

Acceptance:
- Provider failures are actionable, not generic.
- Transcripts are never lost because cleanup failed.

### 6.4 Add “Repair failed records” flow

Current issue:
- Old records still show stale cleanup failure.

Recommendation:
- Failed filter should include batch actions:
  - Re-clean all failed with current provider.
  - Re-transcribe selected.
  - Mark resolved.
  - Export diagnostics.

Acceptance:
- After fixing an API key, user can repair old failed cleanup records in one pass.

---

## 7. P2 — Feature Enhancements That Would Make the App Feel Advanced

### 7.1 Prompt shortcuts become “workflows”

Current shortcut rows map shortcuts to prompts, but the UX is unclear.

Recommendation:
- Introduce “Voice Workflows”:
  - Name: “Clean Dictation”, “Translate to English”, “Extract Tasks”, “Write Email”.
  - Shortcut.
  - Finish phrase.
  - AI prompt.
  - Output behavior: copy, insert, keep overlay, auto-submit.
  - Provider/model override.
- Replace the raw shortcut list with workflow cards.

Acceptance:
- User can have different shortcuts for cleanup, translation, extraction, and direct insert.

### 7.2 Add translation and extraction as first-class modes

User specifically mentioned translation and extraction slowness.

Recommendation:
- Add built-in modes:
  - Clean up.
  - Translate.
  - Extract action items.
  - Extract structured JSON/Markdown.
  - Summarize.
  - Rewrite as message/email.
- Each mode has optimized prompt + output formatting + max token profile.

Acceptance:
- User does not need to handcraft every common AI transformation.

### 7.3 Add transcript titles and search improvements

Recommendation:
- Generate short title and tags for each record.
- Search should support transcript, title, prompt, folder, model, date, status.
- Add filters: Failed AI, Failed transcription, Has audio, Cleaned, Raw-only.

Acceptance:
- History becomes a usable library, not a chronological dump.

### 7.4 Add export/share

Recommendation:
- Export selected transcript as Markdown, TXT, JSON, or audio+metadata bundle.
- Copy cleaned/raw/diff.
- “Copy for agent” format: includes prompt, raw text, cleaned text, model, failure reason.

Acceptance:
- User can use MacVoice outputs in agent workflows immediately.

### 7.5 Add onboarding

Recommendation:
- First-run setup wizard:
  1. Permissions.
  2. Select microphone.
  3. Configure shortcut.
  4. Download/select model.
  5. Optional AI provider.
  6. Test recording.
- Include a one-minute “try it now” test.

Acceptance:
- A new user can get to first successful transcript without opening raw Settings.

---

## 8. P2 — Visual Design System Recommendations

### Current visual problems

- UI feels like plain SwiftUI defaults in many places.
- Green accent is strong and inconsistent with macOS utility calmness.
- Spacing is uneven: some pages feel too sparse; long text pages feel cramped.
- Dividers are very subtle; hierarchy is weak.
- Buttons do not communicate primary vs secondary vs destructive importance.
- Long text fields and raw prompt editors look like debug surfaces.

### Design direction

Aim for: **Raycast + CleanShot + Audio Hijack + macOS Settings**.

Design tokens:

- Accent: keep green but reduce saturation; use as success/active, not every selected surface.
- Backgrounds: sidebar subtle material, content cards with slightly raised backgrounds.
- Typography:
  - Sidebar labels: 13px medium.
  - Section headings: 13-14px semibold uppercase or title case.
  - Body: 13px.
  - Transcript text: readable 14-15px with line height.
  - Monospace only for diagnostics/code-like raw data, not normal prompt editing.
- Cards:
  - 12px corner radius.
  - 12-16px internal padding.
  - consistent vertical rhythm.
- Buttons:
  - Primary: Copy/Insert/Start Recording/Test Connection.
  - Secondary: Re-clean/Re-transcribe/Refresh.
  - Destructive: Delete model/Delete record, always red or in confirmation.

### Must-fix visual details

1. Remove duplicate `New Folder` rows.
2. Remove blank selectable sidebar row.
3. Make Dashboard/App top-level item visible and clickable.
4. Replace tiny toolbar icons with labeled actions or tooltips + clear location.
5. Make model management readable as cards/list rows with clear status chips.
6. Replace giant grey prompt editor with polished editor.
7. Use status chips: Ready, Needs setup, Failed, Connected, Untested, Preparing.
8. Add empty states for no folder/no prompt/no history/filter results.
9. Improve contrast of secondary text.
10. Use consistent button sizing.

---

## 9. P3 — Engineering and Architecture Improvements

### 9.1 Add automated UI smoke tests where possible

- Launch app.
- Navigate Settings.
- Verify AI Cleanup fields.
- Verify prompt editor renders.
- Verify history detail renders.
- Verify version label.

### 9.2 Fix test target/toolchain issue

Current issue:
- `swift test` was blocked because the current toolchain reported `no such module Testing`.

Recommendations:
- Either pin/use a Swift version with Testing support or migrate tests to XCTest.
- CI should run build + tests on supported macOS.

### 9.3 Add fixture-driven provider tests

- Store sample JSON responses from DeepSeek/OpenAI/Groq/Mistral/OpenRouter/Gemini.
- Test error extraction.
- Test content arrays.
- Test empty choices.
- Test non-JSON bodies.

### 9.4 Separate source of truth for settings UI state

- Consider view models for Settings sections.
- Reduce direct calls from views into keychain/network actors.
- Add `AIConnectionState` object with saved key suffix, pending key, last test result, provider, model.

### 9.5 Privacy/security hardening

- Never show or store full API keys outside Keychain.
- Add “Rotate key” warning if key was pasted into logs/chat.
- Ensure diagnostics redact secrets from URLs/body/headers.
- Show what data is sent to cloud AI when cleanup is enabled.

---

## 10. Specific Bug/UX Backlog Ordered Highest to Lowest

### Highest priority

1. Build Dashboard readiness screen.
2. Fix sidebar duplication/blank row and clarify navigation.
3. Rework AI Cleanup setup card with direct pasted-key test, suffix tested, last tested state.
4. Replace generic old failure display with guided recovery cards.
5. Split Settings into tabs/sections.
6. Clarify model readiness and remove contradictory `Selected model not prepared` state.
7. Add transcript detail tabs: Cleaned / Raw / Diff / Metadata.
8. Add pipeline timeline per recording.
9. Add one-click re-clean all failed records.
10. Add prompt testing sandbox.

### High priority

11. Add Voice Workflows to replace raw shortcut/prompt mapping.
12. Add first-class Translate and Extract modes.
13. Stream AI cleanup output when possible.
14. Add provider fallback/retry policy.
15. Add onboarding wizard.
16. Improve recording overlay microcopy and stage transitions.
17. Make action hierarchy clear: primary/secondary/destructive.
18. Add status chips throughout app.
19. Add generated titles/tags for history.
20. Add richer history search and filters.

### Medium priority

21. Add batch operations for failed/archived/folder records.
22. Add prompt categories/templates.
23. Add duplicate/import/export prompts.
24. Add “copy for agent” export format.
25. Add model storage health/free space screen.
26. Add repair model action.
27. Add tooltip/help text for shortcut glyphs.
28. Add keyboard navigation across history and prompts.
29. Add compact/dense display option.
30. Add transcript formatting controls.

### Lower priority polish

31. Better app icon/menu bar state variants.
32. Theme/accent customization.
33. Mini floating command palette.
34. Optional menu bar-only mode.
35. Better sound preset preview UI.
36. Favorite folders/prompts.
37. Usage stats and time saved.
38. Local-only mode warning when AI cleanup disabled.
39. Share extension/services integration improvements.
40. Localization-ready strings.

---

## 11. Suggested Implementation Sprints for Grok

### Sprint 1 — Trust and setup

Goal: make the app self-explanatory and fix the most visible broken-feeling UI.

Tasks:
- Dashboard readiness screen.
- Sidebar cleanup.
- AI Cleanup connection card.
- Model readiness card.
- Failure recovery card.

Acceptance:
- User opens app and knows what is ready, broken, or needs setup.

### Sprint 2 — Settings redesign

Tasks:
- Split Settings into sections/tabs.
- Move permissions/setup to top.
- Rework shortcuts into clear cards.
- Rework model management.
- Rework diagnostics.

Acceptance:
- No long-scroll admin wall.

### Sprint 3 — History workspace

Tasks:
- Transcript detail redesign.
- Cleaned/raw/diff tabs.
- Recording card.
- Failure recovery actions.
- Batch re-clean failed.

Acceptance:
- History feels like a useful transcript library.

### Sprint 4 — Voice workflows and prompt testing

Tasks:
- Workflow model.
- Prompt templates.
- Prompt test sandbox.
- Translation/extraction modes.

Acceptance:
- User can configure different voice workflows without touching low-level settings.

### Sprint 5 — Speed and reliability polish

Tasks:
- Pipeline timeline.
- Streaming cleanup.
- Warm model mode.
- Provider retries/fallbacks.
- Automated smoke tests.

Acceptance:
- App feels fast even when stages take time.

---

## 12. Concrete Acceptance Test Matrix

### AI cleanup

- Paste new DeepSeek key → Save & Test → shows `Connected: OK` and saved suffix updates.
- Invalid key → shows exact provider auth error and does not overwrite working key unless user confirms.
- Cleanup failure → raw transcript remains, failure card has recovery actions.
- Re-clean old failed record → updates cleaned text and clears failure state.

### Recording

- Shortcut starts recording within an expected time and overlay says when mic is live.
- Send phrase `go` ends recording reliably.
- Insert phrase `insert`, `ok insert`, `okay`, and common variants work.
- Media pauses and resumes at expected stage.
- Beeps are audible but not captured in waveform.

### Transcription/model

- Launch does not block on model load.
- First transcription explains if model is preparing.
- Model card clearly shows Ready/Downloaded/Preparing/Failed.
- Deleting model requires confirmation and cannot delete active model without choosing replacement.

### UI/layout

- Sidebar has no duplicates/blank rows.
- Settings is split into usable sections.
- Detail view has Cleaned/Raw/Diff/Metadata tabs.
- Prompt editor supports test preview.
- Window works at small, medium, and large sizes.

### Diagnostics

- Per-record timeline exists.
- Diagnostic logs redacted for secrets.
- “Copy diagnostic summary” copies useful non-secret info for agents.

---

## 13. Non-Negotiable Guardrails for Grok

- Do not log API keys or paste secrets into docs/tests.
- Preserve local transcription as local-first; cloud AI must stay optional.
- Never lose recordings if transcription or cleanup fails.
- Do not remove the visible version/build footer; improve it if needed.
- After source changes, bump version/build, rebuild/package/sign, close old app, reopen new app, and verify visible version.
- Do not commit/push without explicit approval from the user.
- Keep user-facing wording clear and specific; avoid generic `Invalid API response`-style failures.
- Use visual verification for UI changes and inspect screenshots immediately.

---

## 14. Quick “Make It 600% Better” Checklist

If Grok only has time for one major pass, do this:

- [ ] New Dashboard readiness screen.
- [ ] Clean sidebar and folder list.
- [ ] Settings tabs/cards.
- [ ] AI connection card with tested suffix and last result.
- [ ] Model readiness card.
- [ ] History detail tabs and failure recovery card.
- [ ] Prompt testing sandbox.
- [ ] Voice workflows for cleanup/translate/extract.
- [ ] Pipeline timeline per recording.
- [ ] Streaming/progress UX for slow AI cleanup.
- [ ] Batch repair failed cleanups.
- [ ] Visual polish pass with consistent spacing, cards, typography, button hierarchy.

---

## 15. Evidence Notes

Visual inspection found:

- Main history screen still contains records with historical `AI cleanup failed — Invalid API response` labels.
- Sidebar has duplicate `New Folder` rows plus a blank row.
- Settings is one long scroll with high cognitive load.
- AI Cleanup settings now show saved key suffix, but needs stronger connection status UX.
- Transcription settings show confusing model readiness copy.
- Prompt editor feels like an unfinished raw text editor.

Recent engineering evidence:

- v1.0.23 build 24 includes direct pasted-key testing for DeepSeek and robust provider response parsing.
- Live DeepSeek curl with the user-provided key returned HTTP 200 and `OK` during the prior fix.
- `swift test` remains blocked in this environment by missing Swift Testing support; build/package/relaunch works.

