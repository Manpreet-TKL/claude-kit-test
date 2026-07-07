---
name: codex-per-task-delegation
description: "No standing \"prefer codex\" rule — delegate to codex MCP agents only on explicit ask"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 90622c1e-2d06-4856-bcca-ada4f4ab01ac
---

Manpreet does NOT want a standing rule that routes work to codex to save Claude tokens (decided 2026-07-07, chose per-task delegation over a CLAUDE.md rule).

**Why:** He doesn't always want codex; a global rule would auto-delegate work he'd rather Claude do directly.

**How to apply:** Delegate to `mcp__codex__codex` agents only when he explicitly asks (typically after `/codexmcp`). At most, *suggest* codex for large parallelisable implementations — never auto-delegate. Related: [[one-line-cli-commands]].
