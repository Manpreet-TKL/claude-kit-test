---
name: one-line-cli-commands
description: Runnable CLI commands go on ONE line (up to 200 chars) - never backslash-wrapped
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 90622c1e-2d06-4856-bcca-ada4f4ab01ac
---

Any command intended to be copy-pasted into a terminal - echoed advice from scripts, doc code blocks, chat answers - must be a single line; up to 200 characters on one line is fine. Never split with backslash continuations.

**Why:** Manpreet copy-pastes these into a terminal; wrapped commands are fiddly to select and error-prone to paste (2026-07-07, the codex container login command).

**How to apply:** When printing or documenting a runnable command, keep it on one line if it fits in 200 chars; if genuinely longer, prefer a small script over a wrapped one-liner. Related: [[bash-house-style]].
