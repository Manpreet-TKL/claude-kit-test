---
name: githubmcp
description: GitHub MCP context + gate enable (read-only)
disable-model-invocation: false
---

# GitHub MCP (read-only) - context + gate enable

Load how the kit's GitHub MCP works, make its tools available (enabling the startup gate if needed), and load the project context for GitHub work. Use the `mcp__github__*` tools for reads; do not read `~/.claude/mcp-env/.github.env`. Explicit writes follow the rule below through an already authorized route, if available.

The server is registered **read-only** (`GITHUB_READ_ONLY=1`): it exposes only read tools, so creating PRs/branches, pushing, commenting, and merging are impossible by construction. GitHub writes need the user's explicit action and target. That exception does not make this MCP writable, authorize new writable credentials, or allow `git push`/`git commit`. Prepare human-run steps when no authorized write route exists; see `create-oe-pr`.

## Check - tools present, or touch the gate

1. **Tools present?** If the `mcp__github__*` tools are in your toolset, print a one-line `GitHub OK` and the project context below, then proceed to whatever the user asked for.
2. **Tools absent?** Run `touch ~/claude-kit/generated/mcp-on/github` - the **only** shell command this skill runs - then stop. In standalone Codex, reply with exactly `github MCP armed - restart Codex to load it`. In a client that supports reconnecting a gated server, reply with exactly `github MCP ungated - reconnect: /mcp -> github -> reconnect`. Once the user has restarted or reconnected, continue with the task.

Beyond that one `touch`, take no other action: no docker commands, no `install.sh` runs, and never a fallback to `curl` or the REST API - when a call fails, stop and relay the matching advice below; the user runs the fix.

- **Permission denied** -> the `mcp__github` allow rule is missing for this tier - advise `~/claude-kit/install.sh -p <tier> -y` (or adding `mcp__github` to `permissions.allow`).
- **401 / bad credentials** -> the PAT in `~/.claude/mcp-env/.github.env` is missing, expired, or lacks access - advise minting a fresh fine-grained read-only PAT and re-running `~/claude-kit/install.sh -g -p <tier> -y`.
- **Reconnect still fails** -> in standalone Codex, advise touching the flag and
  restarting Codex. In a reconnect-capable client, advise restarting the
  client, touching the flag, and reconnecting in `/mcp`. Only a fresh Codex
  session or the client's MCP reconnect starts the stdio container.

## Project context (the token's visible scope)

GitHub org: `openeyes`, repo links: `https://github.com/openeyes/<repo>`.

- The OpenEyes repos are **private** - anonymous access 401s. The PAT must be a fine-grained token with read access to the `openeyes` org's repos; without org access, reads return 404/empty.
- The token is **read-only** by design. Use `mcp__github__*` for reading code, commits, PRs, issues, CI runs, and code search. There are no write tools to call.
- Writes are out of scope: the human raises commits/PRs (`create-oe-pr` packages the PR; the human runs `git commit`/`git push`).
