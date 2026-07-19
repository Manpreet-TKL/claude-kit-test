---
name: codex-swarm
description: Split a task or plan into 40+ small Codex subagents (luna or terra).
disable-model-invocation: false
---

# Codex swarm

When loaded as context with no task, reply only `Context loaded.`

Split the current task or plan into many small Codex subagents and fan them
out. Meant for work with genuine fan-out grain - dozens of independent,
same-shaped slices.

## Flow

1. Preflight: if the `mcp__codex__*` tools are absent, touch
   `~/claude-kit/generated/mcp-on/codex`, ask the user to reconnect codex in
   /mcp (tools bind on the late connect), and wait.
2. Decompose into self-contained, non-overlapping slices. Each slice states
   what to do, where (exact paths), and its acceptance check. Aim for 40+
   slices when the work has that grain; if it does not, say so and propose the
   natural count instead of padding.
3. Judge the model per slice - smaller than sol, sized to the work:
   - `gpt-5.6-luna`: mechanical, repeatable, fully specified (renames, porting
     a fixed pattern, boilerplate); effort low or medium.
   - `gpt-5.6-terra`: needs judgment (ambiguous code, refactors, test
     authoring); effort medium or high.
4. ASK before spawning (AskUserQuestion): slice count, the luna/terra split,
   and a cost warning - every call is a billable Codex run on the user's
   account.
5. Fan out in waves of ~8-10 `mcp__codex__codex` calls per message, each with
   per-call `model`, `config: {"model_reasoning_effort": "..."}`, `cwd`, and a
   self-contained prompt (the agent shares none of your context). Tell every
   agent: never run `git add`, `git commit`, or `git push` - the orchestrator
   stages and the human commits. Keep each `threadId`; rework a slice with
   `mcp__codex__codex-reply` on its thread.
6. Collate: read the diffs, run each slice's acceptance check, and report a
   pass/fail table with follow-ups.

Safety rails from /codexmcp apply: never shell out to codex directly, never
read `~/claude-kit/generated/.codex.env`, never touch `~/.codex/auth.json`.
