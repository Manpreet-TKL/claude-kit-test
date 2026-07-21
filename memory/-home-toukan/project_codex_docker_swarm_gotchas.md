---
name: codex-docker-swarm-gotchas
description: "Codex MCP agents in the kit's docker container need a per-call sandbox override and a local AGENTS.md, or they fail on bwrap and get derailed into invoking kit skills."
metadata: 
  node_type: memory
  type: project
  originSessionId: 1ced0e38-87c4-48ff-9d7d-7464777185b0
  modified: 2026-07-20T18:10:04.650Z
---

Two failures hit every codex swarm run in the `claude-kit-codex` container
(2026-07-20, 36-agent Jira triage):

1. **bwrap sandbox fails.** Agents abort with "bwrap: No permissions to create
   a new namespace" - codex tries to nest its own sandbox inside the container.
   Fix: pass `sandbox: "danger-full-access"` on every `mcp__codex__codex` call.
   The container (with only the project dir and `~/.codex` mounted, and no git
   credentials) remains the real boundary, which is the documented docker-mode
   model. The `-c sandbox_mode=` in the registration does not cover per-call
   defaults.

2. **Agents inherit the kit's instructions and skills.** `~/.codex/AGENTS.md`
   symlinks to `claude-kit/claude-md/CLAUDE.md` and `~/.codex/skills/` holds the
   kit skills, both visible in-container. Given Jira ticket work, agents dutifully
   invoked `jiramcp`/`devopstickets`, tried to touch the MCP gate flag under the
   read-only `~/claude-kit` mount, and returned "atlassian MCP ungated -
   reconnect" instead of doing the task. Roughly a third of one wave was lost
   this way. Fix: write an `AGENTS.md` in the agent's `cwd` that explicitly
   overrides - no Jira, no MCP, no skills, no network, everything is local -
   plus a matching first line in the prompt. Derailments stopped dead.

Also: long-running agents die at the harness idle timeout (no output for 1800s).
Tickets with huge comment threads need a "read once, write promptly" instruction
or a one-key slice. Three of 36 slices timed out and were re-dispatched cleanly.

Related: [[bulk-jira-download-bash-not-mcp]]
