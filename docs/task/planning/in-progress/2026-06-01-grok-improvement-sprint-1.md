# Grok App Improvement Implementation — Sprint 1 (Trust, Setup, Sidebar, Core Cards)

<!-- Created from approved plan mode session 2026-06-01 -->
<!-- Updated: 2026-06-01 -->
<!-- Status: In Progress — Phase 1 (Sidebar) complete with gate passed; ready for Phase 2 -->

**Source Audit:** `docs/reports/2026-06-01-grok-app-improvement-audit.md`  
**Approved Plan (full detail):** Session plan at time of approval (see `.grok/sessions/.../plan.md` or agent transcript for complete Q&A + rationale). This file is the executable project copy.

## Goal (from Audit + Approved Plan)
Deliver the highest-ROI "trust and setup" improvements so the app feels like a polished, self-explanatory macOS productivity tool on first launch and after any failure.

**Primary Deliverables for Sprint 1:**
- Persistent top-level **Dashboard** readiness screen (permissions, model, AI connection, shortcuts, last result).
- **Sidebar** cleaned: no duplicates/blank rows, "New Folder" as + in header, clear Dashboard/History/Prompts/Settings navigation, version footer preserved.
- Reusable **Model Readiness Card**, **AI Connection Card**, **Failure Recovery Card** (stage + plain-English reason + one-click actions).
- Incremental Settings polish (readiness summary at top, critical sections reordered, status chips, no contradictory model copy).
- All recovery paths wired and verified on historical + live failures.
- Strict adherence to version bump + `scripts/build-app.sh` + visible sidebar verification + visual inspection after every source batch.

**Out of Scope (Sprint 1):** Full Settings tabs, History document workspace redesign, Voice Workflows, onboarding wizard, streaming, P2/P3 backlog items.

**Success Criteria (Acceptance Matrix subset):**
- Launch shows Dashboard with "Ready" or "N items need attention" + direct action buttons.
- Model card never shows contradictory "Selected model not prepared" when a downloaded selected model exists.
- Paste + test new AI key from Dashboard or Settings → "Connected: OK", suffix visible, old key never silently reused.
- Historical "AI cleanup failed — Invalid API response" record in detail shows guided recovery card; Re-clean succeeds and clears failure flags.
- Sidebar: zero duplicate "New Folder", zero blank selectable rows, + only in Folders header.
- All changes visually verified in the running signed app post-rebuild; version in sidebar matches Info.plist.

---

## Relevant Lessons Applied (will be updated at close-out)
- Mandatory post-edit: bump Info.plist (short + build), `bash scripts/build-app.sh`, close old app, reopen new, **verify visible sidebar version** before any further work or handoff.
- Visual inspection + repair in same batch for any layout change.
- Concrete provider-specific errors + persistent diagnostics preferred over generic failure text.
- Preserve local-first transcription; cloud AI remains optional.
- Update routing docs (menubar-ui.md for UI/nav, core.md for stores/settings, transcription.md for model/AI).

---

## Question Gate — Answers (Approved with Recommended)
All 7 questions in the detailed plan were answered with the **recommended** options (phased Sprint 1 only; Dashboard first + default; incremental Settings + cards; full-stage FailureRecoveryCard; new component files; agent+user visual capture + description; bump per logical sub-deliverable). No overrides requested on approval.

---

## Implementation Phases (Strict Order)

**Phase 0 — Setup (Complete)**
- [x] Plan approved by user.
- [x] todo.md updated with Sprint 1 checklist.
- [x] This draft plan created in proper location.
- [x] Recent logs, observations, audit, logic docs re-read.
- [x] No blocking open questions.

**Phase 1 — Sidebar + Dashboard Shell (Current)**
- [ ] Extend `HistorySection` (`.dashboard` etc.).
- [ ] Refactor primary sidebar (clear top-level items, Folders + button only, titled sections, no blanks/dups).
- [ ] New `DashboardView.swift` stub (placeholder cards).
- [ ] Wire + default to `.dashboard`.
- [ ] **First mandatory bump + build + relaunch + visual verify** (describe exact running sidebar + Dashboard placeholder).

**Phase 2 — Model Readiness Card**
- [ ] Helpers in TranscriptionEngine (or extension) for audit-exact states + `canRecordImmediately`.
- [ ] New `ModelReadinessCard.swift` (chips, actions: Prepare/Use smaller/Reveal/etc.).
- [ ] Replace contradictory text in Settings + use in Dashboard.
- [ ] Bump + build + relaunch + verify (no contradictions, actions work, accurate states).

**Phase 3 — AI Connection Card**
- [ ] New `AIConnectionCard.swift` (provider, suffix, last-tested status chip, Test/Replace).
- [ ] Wire to Dashboard (primary) + Settings (replaces/augments current section); preserve recent pasted-key test behavior.
- [ ] Privacy note ("What is sent").
- [ ] Bump + build + verify (sync between surfaces, test flow identical, suffix + status correct).

**Phase 4 — Failure Recovery Card + Integration**
- [ ] New `FailureRecoveryCard.swift` (stage, reason, actionable buttons for all stages).
- [ ] Overlay `.completed(failed)` + HistoryDetail top integration; re-clean paths update records + flags.
- [ ] "Repair all failed" action (Failed filter or Dashboard).
- [ ] Graceful handling of old generic failures.
- [ ] Bump + build + **critical visual + scenario verify** (historical failure record recovery works end-to-end; overlay shows card; raw never lost).

**Phase 5 — Dashboard Complete + Settings Polish + Final Verify**
- [ ] Full Dashboard (all cards + shortcut summary + last result + celebratory/attention states).
- [ ] Settings: top Readiness Overview (cards), reorder Permissions/AI/Transcription higher, status chips everywhere, button hierarchy.
- [ ] Minor polish (resize, empty states).
- [ ] Final bump + full visual sweep of Dashboard (clean + problems), Settings top, History detail recovery, overlay, sidebar states.

**Phase 6 — Docs, Close-out, User Verify**
- [ ] Update `docs/logic/menubar-ui.md`, `core.md`, `transcription.md`, 0-index.
- [ ] Task logs + todo close + observations.
- [ ] "Applied lessons: ..." statement.
- [ ] Before/after visual descriptions.
- [ ] Explicit user verification of rebuilt app (Dashboard, recovery on old failure, version match, no regressions).
- [ ] No commit discussion until all gates passed.

---

## Verification Gates (Every Phase)
- `swift build` after edits.
- `bash scripts/build-app.sh` (quit + package + sign + reopen) at bump points.
- Visible sidebar version **exactly** matches the Info.plist just edited.
- Agent describes running app state for changed surfaces immediately after relaunch.
- User confirmation for final deliverable.

See the full approved plan for detailed file list, risks, acceptance matrix, Not Tested disclosure, and guardrails.

**Progress:**
- Phase 0 complete (tracking, lessons read, todo + plan promotion).
- Phase 1 complete: Sidebar refactored + first mandatory bump (1.0.25 / 39) + full build + relaunch gate passed. Verified version in running sidebar footer and diagnostics. New sidebar has no duplicate New Folder rows or blank selectable items; Folders + lives only in header; sections cleaned per audit.

**Next Immediate Action:** Proceed to Phase 2 (Model Readiness Card) or await user confirmation / direction on next sub-deliverable. All gates followed.

---

**Plan complete for execution. All guardrails from AGENTS.md and the 2026-06-01 audit are incorporated.**