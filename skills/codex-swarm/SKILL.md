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

## Cost-aware execution

For large corpora or repetitive files, run deterministic local preprocessing
first. A local Python, SQLite, or shell pass consumes no model tokens; a local
Codex CLI run still consumes Codex usage. MCP parallelism improves elapsed time
but normally increases aggregate usage because each subagent is a separate,
billable run with its own prompt, context, and reasoning. Do not use a swarm to
perform work that scripts can do exactly.

After preprocessing, create compact candidate cards and run a small stratified
pilot. Record candidate counts, card sizes, estimated tokens, and projected
calls before asking to fan out. Use the swarm only for candidates requiring
judgement, and reserve deeper or stronger models for ambiguous and high-risk
records. If the pilot does not justify the projected cost, finish locally or
use a small natural slice count instead of padding the task to 40 agents.

## Flow

1. Select the available transport:
   - Prefer Codex's native collaboration tools when `spawn_agent` is
     available. This mode has no Claude Code, MCP, gate, or Docker dependency.
   - Otherwise use `mcp__codex__codex` and `mcp__codex__codex-reply` when
     available.
   - If neither transport exists, do not assume this is an MCP gate problem.
     In Claude Code only, touch `~/claude-kit/generated/mcp-on/codex`, ask the
     user to reconnect codex in /mcp, and wait. In any other client, report
     that no subagent transport is available.
2. Decompose into self-contained, non-overlapping slices. Each slice states
   what to do, where (exact paths), and its acceptance check. Aim for 40+
   slices when the work has that grain; if it does not, say so and propose the
   natural count instead of padding.
3. Judge the model per slice - smaller than sol, sized to the work:
   - `gpt-5.6-luna`: mechanical, repeatable, fully specified (renames, porting
     a fixed pattern, boilerplate); effort low or medium.
   - `gpt-5.6-terra`: needs judgment (ambiguous code, refactors, test
     authoring); effort medium or high.
4. Ask before spawning: give the slice count, proposed model use, and a cost
   warning because every subagent is a billable Codex run. In native mode,
   omit model and reasoning overrides unless the user explicitly approves
   them; the subagent otherwise inherits the current session.
5. Fan out in waves of about 8-10 agents, or fewer when the configured limit
   is lower. Every prompt must be self-contained and include the exact working
   directory. Tell every agent never to run `git add`, `git commit`, or
   `git push`; leave new work unstaged unless asked to stage. The human commits.
   - Native mode: use `spawn_agent` with `fork_turns: "none"` because every
     prompt is self-contained. Keep each agent id, use `followup_task` for
     rework, `wait_agent` only when a result blocks progress, `list_agents` to
     account for live work, and `interrupt_agent` only to stop work that is no
     longer needed.
   - MCP mode: use `mcp__codex__codex` with the approved model, reasoning
     effort, `cwd`, and prompt. Keep each thread id and use
     `mcp__codex__codex-reply` for rework.
6. Collate: review every result, run each slice's acceptance check, and report
   a pass/fail table with follow-ups.

Never shell out to codex directly, read
`~/claude-kit/generated/.codex.env`, or touch `~/.codex/auth.json`.
