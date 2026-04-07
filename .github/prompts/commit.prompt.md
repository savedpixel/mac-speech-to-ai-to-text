---
description: Single source of truth for staging, committing, and pushing code changes
---

# Commit Your Changes

Stage, commit, and push **only the files you modified in this chat session** to the **current working branch**. Do not include files changed by other tasks or tools. This is the final step of every task.

---

## Branch Safety (BLOCKING GATE)

1. **Check the current branch** — run `git branch --show-current`.
2. **If on `master` or `main`** — **STOP immediately**. Do not stage, commit, or push. Tell the user and wait.
3. **If on `dev`** — you may commit, but **do NOT push automatically**. After committing, ask: "Committed. Ready to push to dev?" Wait for explicit approval.
4. **Stay on the branch you started on.** Never switch branches just to commit.
5. Never push or commit directly to `master` or `main` unless explicitly instructed.

---

## Verification Gate (BLOCKING)

Before committing, confirm that **ALL** required verification steps from the task plan have passed. If any verification is blocked or incomplete, do **NOT** commit. Report the blocker. See `task.instructions.md` → Blocker Protocol.

---

## Steps

1. **Check `git status --short`** — Review all modified and untracked files. Identify which ones you touched.

2. **Stage only your files** — Use `git add` with explicit file paths. Never use `git add -A` or `git add .` because they can capture unrelated changes. If unsure, check the diff first.

3. **Write a high-quality commit message** using **multiple `-m` flags**. Never use one long quoted multi-line string.

   ### Commit Subject Rules

   ```
   <type>(<optional-scope>): <action-oriented summary>
   ```

   **Allowed Types:** `feat`, `fix`, `refactor`, `docs`, `style`, `data`, `config`, `chore`, `merge`

   ### Commit Subject Standards

   - **Keep subjects under ~80 characters.**
   - Use **lowercase** for type and scope.
   - Start with a **clear verb** (add, fix, move, remove, migrate, refine, etc.).
   - Be **specific**, not generic.
   - **For multi-change sessions:** Summarize the *themes*, not every change. Put details in the body.

   ### Commit Body Rules

   Use additional `-m` flags for body. **Keep to 2–3 `-m` flags total.**

   The body should:
   - Summarize key changes in **one short paragraph** (3–5 sentences max)
   - Mention most important modules or areas
   - Explain *why* if not obvious
   - **Never enumerate every single change**
   - End with `Files: <key files touched>`

   ### Split vs Combine Rule

   Combine changes in one commit when tightly related. Do NOT combine unrelated concerns.

   ### Quick Subject Rewrite Guide

   - `Updated audio stuff` → `feat(audio): add silence threshold detection`
   - `fix transcription` → `fix(transcription): resolve Whisper model loading crash`
   - `update docs` → `docs: refresh audio pipeline documentation`

4. **Push to the current working branch** — If on `dev`, ask before pushing. On other branches, push immediately. If push fails, `git pull --rebase` first.

---

## Rules

- **Never stage files you did not change.**
- **Never use `git add .` or `git add -A`.** Always stage explicit paths.
- **Never use a vague commit subject.**
- **Do not include Copilot co-author trailers unless explicitly requested.**
- **Never force push.**
- **One commit per session batch.** Do not batch unrelated tasks.
- **ALWAYS ask for explicit user approval before committing.** Never commit on your own initiative.
- **ALWAYS present 3 commit message options.** Before committing, propose three short candidate commit messages (subject line only). Number them 1–3, ranging from most concise to most descriptive. Let the user pick one, modify one, or ask for more options. Only proceed with `git commit` after the user selects or approves.
- **ALWAYS ask before pushing.** After committing, ask the user before pushing.
