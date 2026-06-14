# AI Cleanup Provider Response and Latency Fix

<!-- Updated: 2026-06-01 -->

Status: Completed (agent verification pass + diagnostics review done on "try now"; user live provider test of Test Connection / cleanup remains for final sign-off). Sprint 1 (Grok app improvement) is now the active driver per audit.

## User Request

Fix AI cleanup returning `Invalid API response`, especially with DeepSeek and other OpenAI-compatible providers, and improve slow AI cleanup / translation / extraction post-processing behavior.

## Scope

- Inspect `TranscriptionCleaner`, provider endpoint/model configuration, cleanup retry paths, and history re-transcription cleanup paths.
- Fix provider-compatible response parsing and error reporting so real provider errors are visible instead of collapsing into generic `Invalid API response`.
- Improve perceived latency for cleanup/translation/extraction prompts by adding request tuning, faster defaults where safe, and diagnostics around request timing.
- Add tests for parser/error/endpoint behavior without requiring live API keys.
- Update relevant transcription/core docs, task todo/logs, and bundle version/build.
- Build/package/sign/reopen the app after source changes.

## Out of Scope

- Posting or exposing API keys.
- Changing Whisper transcription model behavior unless inspection shows it is directly causing the reported post-processing slowness.
- Committing, staging, pushing, or deploying without explicit separate approval.

## Relevant Lessons

- After any MacVoice source/code change, bump both bundle version fields, rebuild/package/sign, close the old app, and reopen the rebuilt app before reporting completion.
- For user-reported runtime failures, prefer persistent app-owned diagnostics and concrete error messages over generic failure labels.

## Initial Findings

- Current cleanup code uses one `URLSession.shared.data(for:)` request with a 15 second timeout and parses only `choices[0].message.content`.
- Any non-2xx status, provider error body, malformed response, or alternate compatible response shape is reported as generic `Invalid API response`.
- The app has provider presets for DeepSeek and other OpenAI-compatible services; DeepSeek official docs still describe an OpenAI-compatible `/chat/completions` response with `choices[0].message.content` and examples using `base_url=https://api.deepseek.com`.
- Repo is already dirty with many pre-existing source/doc/script changes. I will avoid unrelated changes and inspect diffs before editing overlapping files.

## Question Gate

No open questions. Recommended answers are already assumed:

1. Provider compatibility target: support OpenAI-compatible chat completion responses first, with provider-specific diagnostic details for non-2xx/error JSON.
2. Latency target: prioritize faster cleanup defaults and request instrumentation without weakening cleanup quality unexpectedly.
3. Verification target: use unit/smoke tests and local build/package/reopen; live provider calls only if the user later chooses to provide/confirm API-key testing.

## Implementation Checklist

- [x] Step 1: Inspect AI cleanup request/response code, settings provider mappings, history re-transcription, and any prompt types used for cleanup/translation/extraction.
- [x] Step 2: Implement robust AI response parsing and provider error extraction with safe diagnostics.
- [x] Step 3: Improve latency: reusable tuned `URLSession`, provider-aware request fields, lower-cost prompt defaults where appropriate, timing diagnostics, and avoid unnecessary main-actor blocking.
- [x] Step 4: Add/adjust tests for success parsing, provider error extraction, DeepSeek-compatible endpoints, and timeout/error labels.
- [x] Step 5: Update docs/task tracking and logic docs for changed behavior.
- [x] Step 6: Bump visible version/build, run automated tests, build/package/sign, close old app, reopen rebuilt app, and verify visible version/build.

## Verification Plan

### Automated

- `swift test`
- `swift build`
- `bash scripts/build-app.sh`

### Manual / Runtime

- Relaunch the packaged app from `build/Mac Speech to AI to Text.app`.
- Verify the running app reports the new visible version/build.
- If API-key testing is available in local settings, use the app's Test API Key / cleanup retry path for the selected provider; otherwise disclose live provider calls as not tested.

### Regression

- Ensure cleanup disabled still returns raw text without AI request.
- Ensure missing API key remains a clear error.
- Ensure provider HTTP error bodies show actionable messages without logging secrets.
- Ensure history re-transcription still records cleanup failure reason instead of losing raw transcription.

### Edge Cases

- Non-JSON HTTP error body.
- OpenAI-compatible response with `message.content` as an array of text parts.
- Empty successful content.
- Timeout vs network failure vs provider status error.

### Visual / Native App

- No intentional UI redesign. Native verification is limited to build/relaunch/version visibility unless a UI regression appears.

## Not Tested

- Live DeepSeek/OpenAI/Gemini/etc. API calls are not yet tested in this plan because API keys and provider balances are user-local secrets.
- `swift test` is currently blocked by the repository test target importing `Testing` on a toolchain that reports `no such module Testing`; parser tests were added but could not be executed in this environment.

## Follow-up API Key UI Fix

- Screenshot evidence showed DeepSeek was rejecting a different stored key suffix than the new key the user intended to use.
- Updated Settings so the API key field starts empty, displays only the saved key suffix, and saves pasted replacement text before Test Connection.
- Bumped app version/build again for this source/UI change.

## Live DeepSeek Verification Follow-up

- Direct live API test with the user-provided DeepSeek key returned HTTP 200 and assistant content `OK`, proving the key and endpoint work.
- App failure source was stale Keychain usage while replacing a key.
- Updated Test Connection to test the pasted replacement key directly and save it only after a successful test.
- Bumped app version/build again for this source/UI behavior change.

## Agent Verification Pass (executed on "try now")

- Safely terminated any running app instances (pkill of executable name).
- Launched the packaged app: `open "build/Mac Speech to AI to Text.app"`.
- Confirmed via `macvoice-diagnostics-2026-06-01.log`: fresh `App launching version=1.0.24 build=38` entry.
- The prior runs in the same log already show the improved diagnostics in action:
  - `[ai-cleanup] Request started purpose=test provider=DeepSeek model=deepseek-chat maxTokens=8 endpointHost=api.deepseek.com`
  - `[ai-cleanup] Response received purpose=test provider=DeepSeek status=200 bytes=466 elapsedMs=733`
  - Later 401 responses similarly detailed with status/bytes/elapsed (no longer swallowed as generic "Invalid API response").
- Source review of `TranscriptionCleaner.swift` (lines ~5-265):
  - Tuned ephemeral `URLSession` (20s/30s timeouts, no cache, connection limits).
  - Per-request `DiagnosticLogger` writes for start + response (status, bytes, elapsedMs, provider, purpose).
  - `extractAssistantContent` handles `choices[].message.content` (string or `[[text]]` parts for compat), legacy `text`, and delta.
  - `extractProviderErrorMessage` surfaces `error.message`/`code`, top-level message, or raw non-JSON body prefix.
  - `CleanerError` now produces actionable `apiError(statusCode, message)` and `invalidResponse(reason)`.
  - `maxResponseTokens(...)` dynamically lowers ceiling for short inputs (min 384, ~input/2.8 +160) to cut latency/cost.
  - `testAPIKey(overrideAPIKey:)` supports the direct-pasted-key test path.
- Source review of `AIConnectionCard.swift` (lines ~74-218):
  - Never prefills full key or bullets; shows only `Key saved (…last4)`.
  - Paste field explicitly labeled "to replace stored key".
  - Button dynamically "Test Connection" vs "Save & Test Connection".
  - `testConnection()` only assigns to `settings.aiCleanupAPIKey` on `.success` for replacements; prefixes failure messages with "New pasted key failed:".
- No source changes performed in this verification turn (git was clean at start). Packaged binary already built from the fixed sources at b38.
- App relaunched cleanly with all permissions previously granted; no crashes on launch.
- `swift build` / full `scripts/build-app.sh` not re-executed here (already matched packaged state); `swift test` remains blocked by toolchain missing Swift Testing module (pre-existing).

**Ready for user live test:** In the running app (v1.0.24 b38), go to main window → AI Cleanup card (or Settings), paste your DeepSeek (or other) key if needed, hit "Save & Test Connection", then do a real shortcut-triggered recording + cleanup. Expect concrete status in diagnostics and no more opaque "Invalid API response" for provider errors.
