---
name: codex-grill
description: Grill a difficult plan with Codex gpt-6-astra at max reasoning.
disable-model-invocation: false
---

# Codex grill

When loaded as context with no task, reply only `Context loaded.`

Have Codex's flagship model adversarially review a difficult plan and grill it
until sign-off. Review-only: neither you nor the Codex agent edits any file.

## Cost

`gpt-6-astra` at `max` is the expensive tier, and every call is a billable
Codex run on the user's account - confirm before the first call.

## Flow

1. Select the available transport:
   - In standalone Codex, use the native collaboration tools (`spawn_agent`,
     `followup_task`, and `wait_agent`). This path has no MCP startup gate.
   - In Claude Code, use `mcp__codex__codex` and
     `mcp__codex__codex-reply` when present.
   - If neither is present in Claude Code, touch
     `~/claude-kit/generated/mcp-on/codex`, ask the user to reconnect codex in
     `/mcp`, and wait. In any other client, report that no Codex review
     transport is available.
2. Assemble a self-contained plan brief - the Codex agent shares none of your
   context. Include the goal, the full plan text (or its file path under
   `cwd`), key constraints, and what "done" means.
3. After the cost confirmation, request `gpt-6-astra` at `max` explicitly:
   - Native mode: use `spawn_agent` with `fork_turns: "none"`, the approved
     model and reasoning override, and a read-only review prompt. Keep its id
     and use `followup_task` for the user's answers.
   - MCP mode: call `mcp__codex__codex` with `model: "gpt-6-astra"`,
     `config: {"model_reasoning_effort": "max"}`, and `cwd` = repo root.
     Continue the returned thread with `mcp__codex__codex-reply`.
   Cast the reviewer to find holes, hidden assumptions, ordering hazards, and
   missing verification; return numbered hard questions with blocker, major,
   or minor severity plus an overall verdict. It may read files under `cwd`
   for facts but must modify nothing.
4. Relay questions to the user ONE at a time. Use the client's structured
   question facility when the options are clear; otherwise ask one numbered
   plain-text question. Send each answer back on the same native agent or MCP
   thread; repeat until the reviewer signs off or the user stops.
5. Output the plan deltas the grilling produced and any residual risks as a
   numbered list. Update the plan document only if the user asks.

Safety rails from `codexmcp` apply: never shell out to codex directly, never
read `~/claude-kit/generated/.codex.env`, never touch `~/.codex/auth.json`.
