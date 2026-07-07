---
name: githubmcp
description: GitHub MCP context + gate enable (read-only)
disable-model-invocation: true
---

# GitHub MCP (read-only) - context + gate enable

Load how the kit's GitHub MCP works, make its tools available (enabling the startup gate if needed), and load the project context for GitHub work. Everything goes through the `mcp__github__*` MCP tools - never `curl` the GitHub API, never read `~/claude-kit/generated/.github.env`.

The server is registered **read-only** (`GITHUB_READ_ONLY=1`): it exposes only read tools, so creating PRs/branches, pushing, commenting, and merging are impossible by construction. This mirrors the hard rule "never write out to GitHub." The human raises PRs - see the `create-oe-pr` skill; never use `gh` or `git push`/`git commit` to do it for them.

## Check - tools present, or touch the gate

1. **Tools present?** If the `mcp__github__*` tools are in your toolset, print a one-line `GitHub OK` and the project context below, then proceed to whatever the user asked for.
2. **Tools absent?** Run `touch ~/claude-kit/generated/mcp-on/github` - the **only** shell command this skill runs - then reply with exactly this one line and nothing else (no explanation of the gate, no advice dump) and stop: `github MCP ungated - reconnect: /mcp -> github -> reconnect`. Once the user has reconnected, continue with the task.

Beyond that one `touch`, take no other action: no docker commands, no `install.sh` runs, and never a fallback to `curl` or the REST API - when a call fails, stop and relay the matching advice below; the user runs the fix.

- **Permission denied** -> the `mcp__github` allow rule is missing for this tier - advise `~/claude-kit/install.sh -p <tier> -y` (or adding `mcp__github` to `permissions.allow`).
- **401 / bad credentials** -> the PAT in `generated/.github.env` is missing, expired, or lacks access - advise minting a fresh fine-grained read-only PAT and re-running `~/claude-kit/install.sh -g -p <tier> -y`.
- **Reconnect still fails** -> advise restarting Claude Code, touching the flag, and reconnecting in `/mcp` (or touching the flag before launch). The stdio container is launched by Claude Code itself - only the `/mcp` reconnect (or a restart) spawns it.

## Project context (the token's visible scope)

GitHub org: `openeyes`, repo links: `https://github.com/openeyes/<repo>`.

- The OpenEyes repos are **private** - anonymous access 401s. The PAT must be a fine-grained token with read access to the `openeyes` org's repos; without org access, reads return 404/empty.
- The token is **read-only** by design. Use `mcp__github__*` for reading code, commits, PRs, issues, CI runs, and code search. There are no write tools to call.
- Writes are out of scope: the human raises commits/PRs (`create-oe-pr` packages the PR; the human runs `git commit`/`git push`).
