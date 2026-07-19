---
name: codex-grill
description: Grill a difficult plan with Codex gpt-5.6-sol at xhigh reasoning.
disable-model-invocation: false
---

# Codex grill

When loaded as context with no task, reply only `Context loaded.`

Have Codex's flagship model adversarially review a difficult plan and grill it
until sign-off. Review-only: neither you nor the Codex agent edits any file.

## Cost

`gpt-5.6-sol` at `xhigh` is the expensive tier, and every call is a billable
Codex run on the user's account - confirm before the first call.

## Flow

1. Preflight: if the `mcp__codex__*` tools are absent, touch
   `~/claude-kit/generated/mcp-on/codex`, ask the user to reconnect codex in
   /mcp (tools bind on the late connect), and wait.
2. Assemble a self-contained plan brief - the Codex agent shares none of your
   context. Include the goal, the full plan text (or its file path under
   `cwd`), key constraints, and what "done" means.
3. Call `mcp__codex__codex` with per-call overrides `model: "gpt-5.6-sol"` and
   `config: {"model_reasoning_effort": "xhigh"}`, plus `cwd` = repo root. Cast
   Codex as an adversarial plan reviewer: find holes, hidden assumptions,
   ordering hazards, missing verification; return numbered hard questions,
   each with a severity (blocker/major/minor), plus an overall verdict; it may
   read files under `cwd` for facts but must modify nothing.
4. Relay Codex's questions to the user ONE at a time (AskUserQuestion where
   the options are clear). Send the answers back with `mcp__codex__codex-reply`
   on the same `threadId`; repeat until Codex signs off or the user stops.
5. Output the plan deltas the grilling produced and any residual risks as a
   numbered list. Update the plan document only if the user asks.

Safety rails from /codexmcp apply: never shell out to codex directly, never
read `~/claude-kit/generated/.codex.env`, never touch `~/.codex/auth.json`.
