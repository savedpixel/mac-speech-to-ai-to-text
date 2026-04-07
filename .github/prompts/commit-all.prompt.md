---
name: commitall
description: Batch-commit all uncommitted changes, grouped by relevance, with 3 message options per batch
agent: agent
---

# Commit All Uncommitted Changes

Stage, commit, and push **all** uncommitted changes in the workspace — grouped by relevance so each commit is cohesive. This is for catching up on multiple accumulated changes, not for single-task commits.

---

## Branch Safety (BLOCKING GATE)

1. **Check the current branch** — run `git branch --show-current`.
2. **If on `master` or `main`** — **STOP immediately**. Do not stage, commit, or push. Tell the user and wait.
3. **Stay on the current branch.** Never switch branches.

---

## Steps

### 1. Assess All Changes

```bash
git status --short
git diff --stat
```

Review all modified, untracked, and deleted files.

### 2. Group Changes by Relevance

Cluster files into **commit batches** based on:
- Feature/module area (files that belong to the same feature go together)
- Change type (all doc updates can form one batch, all config changes another)
- Logical coupling (files that were changed for the same reason)

**Each batch becomes one commit.** Target 1–5 batches depending on change diversity. If all changes are related, one batch is fine.

### 3. For Each Batch — Present 3 Commit Message Options

Before committing each batch:
1. List the files in the batch
2. Present **3 numbered commit message options** (subject line only, concise → descriptive)
3. Wait for the user to pick one (e.g., "1", "2", "3") or provide their own
4. Only proceed with `git commit` after the user selects

### 4. Stage and Commit Each Batch

For each batch (after user selects a message):
```bash
git add <explicit-file-paths>
git commit -m "<type>(<scope>): <subject>" -m "<body>"
```

**Never use `git add .` or `git add -A`.** Always stage explicit paths per batch.

### 5. Push

After all batches are committed:
- If on `dev`, ask: "All batches committed. Ready to push to dev?"
- On other branches, ask: "All batches committed. Ready to push to <branch>?"
- **Wait for explicit approval** before pushing.

---

## Commit Message Rules

Follow the same rules as `commit.prompt.md`:
- Subject format: `<type>(<optional-scope>): <action-oriented summary>`
- Allowed types: `feat`, `fix`, `refactor`, `docs`, `style`, `data`, `config`, `chore`, `merge`
- Keep subjects under ~80 characters
- Body: 2–3 `-m` flags max, summarize key changes, end with `Files:` list
- **ALWAYS present 3 options per batch** — the user picks.

---

## Rules

- **Never stage files without showing what's in each batch first.**
- **Never combine unrelated changes into one commit.** Group by relevance.
- **Never skip the 3-option message presentation** for any batch.
- **One commit per batch, one push at the end.**
- **Always ask for explicit user approval** before both committing and pushing.
