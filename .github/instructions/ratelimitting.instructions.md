---
applyTo: '*'
---

# Rate Limit Prevention (CRITICAL)

**You cannot recover from rate limits — the chat session will stop completely. Prevention is essential.**

## Rules

- **Be concise**: Keep responses short and to the point.
- **Don't repeat back**: Don't echo the user's request.
- **Plan first**: Before major tool batches, decide the smallest sensible sequence.
- **Prefer fewer tool calls**: Only calls that materially move the task forward.
- **Batch when it helps**: Combine independent operations.
- **Reuse information**: Never re-fetch data you already have.
- **Keep exploration focused**: One targeted discovery pass when needed.
- **Checkpoint silently**: After significant work, briefly note progress.
- **If uncertain**: Make a reasonable decision and proceed.
- **Target small batches**: ~3–5 tool calls per response.

## Output Length Limits

- **Target ~300 lines per response**: Split if exceeding.
- **Prefer incremental file work**.
- **Truncate examples**: Essential snippets only.
- **Use summaries**: For large changes.
- **Continue automatically**: End with `... continuing` if splitting.

## Visibility

- `📦 BATCH: [what]` — combining operations
- `♻️ REUSE: [what]` — reusing data
- `⏭️ SKIP: [what]` — skipping unnecessary call
- `💾 CHECKPOINT: [summary]` — saving progress
- `✂️ SPLIT: [what]` — splitting output
