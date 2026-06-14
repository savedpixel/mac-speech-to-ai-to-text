# Plan: Settings UI — Save Indicator, Test API Key, Multi-Provider AI, Send Phrase Toggle, Done Button

> **Status:** Complete
> **Created:** 2026-03-28
> **Estimated steps:** 11
> **Risk level:** Medium

## Context

The Settings panel currently saves changes instantly via `didSet` on Settings properties, but gives zero visual feedback. Users don't know if changes are persisted. The AI Cleanup section has a single free-text endpoint/model field with no provider awareness. Additionally, there is no way to disable the send phrase or manually finish a recording from the overlay. Need: save indicators, API key testing, structured multi-provider dropdown, send phrase toggle, and a manual "Done" button on the recording overlay.

## Current State

- **Settings model** (`MacVoice/Core/Settings.swift`): `@Observable` class. Properties save via `didSet` to `UserDefaults`/Keychain immediately. AI fields: `aiCleanupEnabled` (Bool), `aiCleanupModel` (String), `aiCleanupEndpoint` (String), `aiCleanupAPIKey` (String via Keychain).
- **Settings UI** (`MacVoice/UI/MainWindowView.swift`, lines 176–303, `SettingsContentView`): SwiftUI Form with sections. AI Cleanup section shows toggle, SecureField for API key, free-text model/endpoint fields. Voice Input section has TextField for sendPhrase and Slider for silenceThreshold. No save feedback, no test button, no provider concepts, no send phrase toggle.
- **TranscriptionCleaner** (`MacVoice/Transcription/TranscriptionCleaner.swift`): Actor. Uses `settings.aiCleanupEndpoint` + `settings.aiCleanupModel` + Bearer auth. Sends OpenAI-compatible chat completion request.
- **PipelineCoordinator** (`MacVoice/Core/PipelineCoordinator.swift`): `setupCallbacks()` (line 56) unconditionally wires audio buffers → `sendPhraseDetector.appendBuffer()`, silence → `sendPhraseDetector.checkSilenceAfterPhrase()`. `runPipeline()` (line 109) always calls `sendPhraseDetector.startMonitoring()`. No way to manually finish recording.
- **RecordingOverlayView** (`MacVoice/UI/RecordingOverlayView.swift`, lines 51–66): `recordingContent` shows AudioWaveformView, "Listening…" text, and a "Cancel" button. No "Done" / "Finish" button.
- **Settings.swift** (lines 56–58): `sendPhrase` property (String, default `"OK, send"`). No `sendPhraseEnabled` toggle exists.

## Target State

1. **Save indicator**: When any setting changes, show a brief "Saved" checkmark/fade animation near the changed field (or a global "Settings auto-saved" indicator).
2. **Test API Key button**: In the AI Cleanup section, a "Test API Key" button that sends a minimal chat completion request to the selected provider and shows success/failure.
3. **Provider dropdown**: Replace free-text endpoint/model with a structured picker:
   - Select an AI provider (OpenAI, Groq, Mistral, etc.)
   - Provider selection auto-populates the endpoint
   - Model picker shows only that provider's available models
   - Still allow "Custom" provider for manual endpoint/model entry
4. **TranscriptionCleaner** adapts to use the provider's endpoint from the new config.
5. **Send phrase toggle**: New `sendPhraseEnabled` setting (Bool, default `true`). When disabled, the send phrase detector is not started during recording. The send phrase text field and silence threshold slider are dimmed in settings.
6. **"Done" button on recording overlay**: Always visible in the `.recording` state regardless of `sendPhraseEnabled`. Pressing it manually finishes the recording (same path as send phrase confirmation).

## Assumptions

- **OpenAI-compatible providers only** for initial implementation. Anthropic and Cohere use incompatible APIs and are excluded (can be added later with adapters).
- The provider/model catalog is **hardcoded** in the app — no runtime fetching of model lists. This keeps it simple and avoids API calls just to populate settings.
- "Custom" provider option lets power users set any endpoint/model manually (preserves current behavior).
- Save indicator uses auto-save (current behavior) with visual feedback, NOT a manual save button — since `didSet` already persists instantly, adding a save button would be misleading. A brief "Saved ✓" indicator after each change is more honest.
- The "Done" button triggers the same `finalizePipeline()` path as the send phrase — stops recording and proceeds to transcription.
- When send phrase is disabled, `removeSendPhrase(from:)` in PipelineCoordinator still runs safely — it simply won't find the phrase to remove.
- Default `sendPhraseEnabled = true` — no change for existing users.

## Provider & Model Catalog (Research-Based)

### OpenAI-Compatible Providers

| Provider | Base URL | Endpoint Path | Models |
|---|---|---|---|
| **OpenAI** | `https://api.openai.com` | `/v1/chat/completions` | gpt-4o, gpt-4o-mini, gpt-4.1, gpt-4.1-mini, gpt-4.1-nano, o3-mini, o4-mini |
| **Groq** | `https://api.groq.com` | `/openai/v1/chat/completions` | llama-3.3-70b-versatile, llama-3.1-8b-instant, qwen/qwen3-32b |
| **Mistral** | `https://api.mistral.ai` | `/v1/chat/completions` | mistral-large-latest, mistral-medium-latest, mistral-small-latest, codestral-latest |
| **DeepSeek** | `https://api.deepseek.com` | `/chat/completions` | deepseek-chat, deepseek-reasoner |
| **xAI (Grok)** | `https://api.x.ai` | `/v1/chat/completions` | grok-4, grok-3, grok-3-mini |
| **Together AI** | `https://api.together.xyz` | `/v1/chat/completions` | deepseek-ai/DeepSeek-V3.1, meta-llama/Llama-3.3-70B-Instruct-Turbo, Qwen/Qwen3-235B-A22B-Instruct-2507-tput, mistralai/Mistral-Small-24B-Instruct-2501 |
| **Fireworks AI** | `https://api.fireworks.ai` | `/inference/v1/chat/completions` | accounts/fireworks/models/deepseek-v3p1, accounts/fireworks/models/llama-v3-70b-instruct, accounts/fireworks/models/qwen2-72b-instruct |
| **OpenRouter** | `https://openrouter.ai` | `/api/v1/chat/completions` | openai/gpt-4o, anthropic/claude-sonnet-4-6, google/gemini-2.5-flash, deepseek/deepseek-chat, meta-llama/llama-3.3-70b-instruct |
| **Perplexity** | `https://api.perplexity.ai` | `/v1/chat/completions` | sonar, sonar-pro, sonar-reasoning-pro |
| **Google Gemini** | `https://generativelanguage.googleapis.com` | `/v1beta/openai/chat/completions` | gemini-2.5-pro, gemini-2.5-flash, gemini-2.5-flash-lite |
| **Custom** | (user-defined) | (user-defined) | (user-defined) |

### Excluded (Incompatible API)
- **Anthropic** — uses `x-api-key` header + `/v1/messages` format (not OpenAI-compatible)
- **Cohere** — uses `/v2/chat` with different request/response format

## Implementation Steps

- [ ] **Step 1: Create AIProvider data model**
  - Files: `MacVoice/Core/AIProvider.swift` (new)
  - What: Create an enum `AIProvider` with cases for each provider + `.custom`. Each case provides: `displayName`, `baseURL`, `endpointPath`, `models: [AIModel]`. `AIModel` is a struct with `id` (API string) and `displayName`. Computed `fullEndpointURL` concatenates baseURL + endpointPath. Conform to `Codable`, `CaseIterable`, `Identifiable`.
  - Why: Centralizes provider/model knowledge. Clean separation from UI and Settings.

- [ ] **Step 2: Update Settings.swift for provider-based config**
  - Files: `MacVoice/Core/Settings.swift`
  - What: Replace `aiCleanupModel` (String) and `aiCleanupEndpoint` (String) with `aiCleanupProvider` (AIProvider, stored as rawValue string), `aiCleanupModelID` (String, the selected model's API ID). Keep `aiCleanupEndpoint` only for `.custom` provider. Add `aiCleanupCustomModel` for custom provider. Add computed `resolvedEndpoint` and `resolvedModel` that return the right values based on provider selection. Update `init()` defaults and UserDefaults registration. Preserve backward compatibility: if existing `aiCleanupEndpoint` matches a known provider, migrate to that provider on init.
  - Why: Structured provider config instead of free-text.

- [ ] **Step 3: Update TranscriptionCleaner to use resolved endpoint/model**
  - Files: `MacVoice/Transcription/TranscriptionCleaner.swift`
  - What: Change `settings.aiCleanupEndpoint` → `settings.resolvedEndpoint` and `settings.aiCleanupModel` → `settings.resolvedModel`. No other changes needed since all providers use OpenAI-compatible format.
  - Why: Adapts to the new settings structure.

- [ ] **Step 4: Add API key test function to TranscriptionCleaner**
  - Files: `MacVoice/Transcription/TranscriptionCleaner.swift`
  - What: Add `func testAPIKey() async -> Result<String, CleanerError>`. Sends a minimal request (e.g. `messages: [{"role":"user","content":"Hi"}]`, `max_tokens: 5`) to the configured provider. Returns `.success("Model responded: {first few chars}")` or `.failure(error)`. Uses same auth/endpoint logic as `clean()`.
  - Why: Lets users verify their API key + endpoint works before relying on it.

- [ ] **Step 5: Redesign AI Cleanup section in SettingsContentView**
  - Files: `MacVoice/UI/MainWindowView.swift` (SettingsContentView)
  - What: Replace the current AI Cleanup section with:
    - Toggle: "Enable AI Cleanup" (unchanged)
    - **Provider picker**: `Picker("Provider:", selection: $settings.aiCleanupProvider)` showing all `AIProvider.allCases` by `displayName`
    - **Model picker**: `Picker("Model:", selection: $settings.aiCleanupModelID)` showing `settings.aiCleanupProvider.models` — or free-text TextField if provider is `.custom`
    - **Endpoint**: Read-only display of computed endpoint URL (or editable TextField if `.custom`)
    - **API Key**: SecureField (unchanged)
    - **Custom endpoint/model**: Show TextField for endpoint and model only when provider is `.custom`
    - **Test API Key button**: Button "Test Connection" → calls `testAPIKey()` → shows inline result (spinner while testing, green checkmark + response preview on success, red X + error on failure)
  - Why: Structured provider selection with model awareness.

- [ ] **Step 6: Add auto-save indicator to SettingsContentView**
  - Files: `MacVoice/UI/MainWindowView.swift` (SettingsContentView)
  - What: Add a `@State private var showSavedIndicator = false` and a small overlay/banner reading "Settings saved ✓" that fades in and out. Trigger it via `.onChange` on key settings properties (or use a debounced approach: any setting change sets `showSavedIndicator = true`, then a 1.5s timer sets it false). Place the indicator at the top of the ScrollView or as an overlay on the Form.
  - Why: Visual confirmation that changes persist.

- [ ] **Step 7: Write unit tests**
  - Files: `MacVoiceTests/MacVoiceTests.swift`
  - What: Add tests for:
    - `AIProvider` — verify all cases have non-empty models, correct endpoint URLs, displayNames
    - `AIProvider.custom` — verify it has empty models array
    - `Settings` resolved endpoint/model computation for each provider type vs custom
    - Backward compatibility: migrate legacy endpoint string to correct provider
  - Why: Verify the data model and migration logic.

- [ ] **Step 8: Update PreferencesView (legacy) if still used**
  - Files: `MacVoice/UI/PreferencesView.swift`
  - What: Check if `PreferencesView` still references old `aiCleanupModel`/`aiCleanupEndpoint` fields. If so, update to match new provider-based config. If PreferencesView is defunct (replaced by MainWindowView Settings tab), note it for cleanup.
  - Why: Prevent stale references from breaking the build.

- [ ] **Step 9: Add `sendPhraseEnabled` to Settings + toggle in Voice Input UI**
  - Files: `MacVoice/Core/Settings.swift`, `MacVoice/UI/MainWindowView.swift`
  - What: Add `var sendPhraseEnabled: Bool` property (with `didSet` saving to UserDefaults) after `sendPhrase` (line 58). Add `Key.sendPhraseEnabled` constant. Register default `true` in `init()`. In SettingsContentView's "Voice Input" section (line 155), add `Toggle("Send Phrase", isOn: $settings.sendPhraseEnabled)` before the send phrase TextField. Apply `.disabled(!settings.sendPhraseEnabled)` + `.opacity(settings.sendPhraseEnabled ? 1.0 : 0.5)` to the TextField and Slider so they dim when disabled.
  - Why: Lets users turn off send phrase detection entirely.

- [ ] **Step 10: Conditionally start SendPhraseDetector + add `finishRecording()` to PipelineCoordinator**
  - Files: `MacVoice/Core/PipelineCoordinator.swift`
  - What:
    - In `setupCallbacks()` (line 56): Wrap `onAudioBuffer` to only forward buffers to `sendPhraseDetector` when `settings.sendPhraseEnabled`.
    - In `setupCallbacks()` (line 63): Wrap `onSilenceDetected` to only call `sendPhraseDetector.checkSilenceAfterPhrase()` when `settings.sendPhraseEnabled`.
    - In `runPipeline()` (line 109): Only call `sendPhraseDetector.startMonitoring()` if `settings.sendPhraseEnabled`. Update log message accordingly.
    - Add public `func finishRecording()` near `cancel()` (line 96) that guards `state == .recording` then calls `finalizePipeline()`. This is the entry point for the overlay's "Done" button.
  - Why: Prevents unnecessary speech recognition when disabled; provides a public API for manual recording finish.

- [ ] **Step 11: Add "Done" button to RecordingOverlayView**
  - Files: `MacVoice/UI/RecordingOverlayView.swift`
  - What: In `recordingContent` (lines 51–66), replace the standalone "Cancel" button with an `HStack` containing both "Cancel" (`.bordered`) and "Done" (`.borderedProminent`) buttons. "Done" calls `pipelineCoordinator.finishRecording()`. The "Done" button is **always visible** regardless of `sendPhraseEnabled`.
  - Why: Provides manual recording termination. Always visible so users always have a way to finish.

## Files Affected

| File | Action | Description |
| --- | --- | --- |
| `MacVoice/Core/AIProvider.swift` | Create | Provider enum + model catalog |
| `MacVoice/Core/Settings.swift` | Modify | Add provider-based config, resolved endpoint/model, migration, `sendPhraseEnabled` |
| `MacVoice/Transcription/TranscriptionCleaner.swift` | Modify | Use resolved endpoint/model, add testAPIKey() |
| `MacVoice/UI/MainWindowView.swift` | Modify | Redesign AI Cleanup section, add save indicator, send phrase toggle |
| `MacVoice/UI/RecordingOverlayView.swift` | Modify | Add "Done" button to recording state |
| `MacVoice/Core/PipelineCoordinator.swift` | Modify | Conditional send phrase wiring, `finishRecording()` method |
| `MacVoice/UI/PreferencesView.swift` | Modify | Update or mark deprecated |
| `MacVoiceTests/MacVoiceTests.swift` | Modify | Add AIProvider + Settings migration tests |

## Dependencies & Risks

- **Model catalog staleness**: Hardcoded model lists will go stale as providers add/remove models. Mitigation: include "Custom" option and document update process.
- **Provider API differences**: All selected providers are OpenAI-compatible but may have minor differences in error response format. Mitigation: the test button will surface issues immediately.
- **Backward compatibility**: Users with existing `aiCleanupEndpoint` values need seamless migration. Mitigation: Step 2 includes migration logic in `init()`.
- **Keychain per-provider**: Currently one API key. If users switch providers, they lose the key. Could store per-provider keys. Decision: **keep single key for now** — users switch providers infrequently and can re-enter.
- **Send phrase toggle is low risk**: Default `true` preserves existing behavior. When disabled, `SendPhraseDetector` simply isn't started — no code paths broken.

## Testing Plan — BLOCKING (execute BEFORE docs or completion)

### Automated Checks
- [ ] `swift build` compiles without errors
- [ ] `swift test` passes all tests (existing 32 + new ~8)
- [ ] AIProvider enum has correct endpoint URLs for all providers
- [ ] Settings migration correctly identifies known providers from legacy endpoint strings

### Manual Verification
1. Build and run the app
2. Open Settings → AI Cleanup → Enable
3. Select each provider → verify model picker updates with correct models
4. Select "Custom" → verify free-text endpoint/model fields appear
5. Enter an API key → click "Test Connection" → verify success/failure display
6. Change any setting → verify "Settings saved ✓" indicator appears briefly
7. Quit and relaunch → verify provider/model selection persists
8. Verify existing transcription cleanup still works end-to-end
9. **Send phrase enabled (default):** trigger recording → overlay shows "Done" + "Cancel" → say send phrase → recording auto-finishes (existing behavior preserved)
10. **Done button:** trigger recording → press "Done" → recording finishes, proceeds to transcription
11. **Disable send phrase:** toggle off in Settings → verify TextField and Slider dim → trigger recording → say old send phrase → nothing happens → press "Done" → finishes normally

### Regression Checks
- [ ] Existing non-AI features unaffected (recording, transcription, shortcuts)
- [ ] History/Prompts tabs still work correctly
- [ ] Menu bar status item still functions
- [ ] Cancel button still works during recording

### Edge Cases
- [ ] Empty API key + Test button → shows "No API key" error
- [ ] Invalid API key + Test button → shows network/auth error
- [ ] Switch from OpenAI to Groq → endpoint updates, model resets to first available
- [ ] Legacy settings (pre-provider) → migrates correctly on launch
- [ ] Custom provider with empty endpoint → handled gracefully
- [ ] Press "Done" immediately after recording starts (very short recording) → should still transcribe
- [ ] Send phrase disabled + no "Done" press + cancel → clean return to idle

**STOP: Do NOT proceed to docs or completion until ALL tests pass.**

## Rollback Plan

Revert changes to `Settings.swift`, `MainWindowView.swift`, `TranscriptionCleaner.swift`, `PipelineCoordinator.swift`, `RecordingOverlayView.swift`. Delete `AIProvider.swift`. Remove new tests.

## Post-Implementation Checklist

**Gate 1 — Code complete:**
- [ ] All 11 implementation steps complete

**Gate 2 — Testing (BLOCKING):**
- [ ] All automated checks passed
- [ ] All manual verification executed
- [ ] All regression checks executed

**Gate 3 — Documentation & logging (only after Gate 2):**
- [ ] `docs/logic/transcription.md` updated (provider support)
- [ ] `docs/logic/core.md` updated (Settings changes, finishRecording pipeline path)
- [ ] `docs/logic/audio.md` updated (send phrase disable option)
- [ ] Task logged in `docs/task/logs/2026-03-28.md`
- [ ] Observations logged

**Gate 4 — Close out:**
- [ ] Plan status → **Complete**
- [ ] Plan file moved from `draft/` to `completed/`
