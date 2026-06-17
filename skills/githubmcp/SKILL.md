---
name: githubmcp
description: Read-only GitHub MCP preflight — run before reading repos/PRs/CI
disable-model-invocation: true
---

# GitHub MCP preflight (read-only)

Confirm the GitHub MCP server is connected, fail fast if it isn't, then load the project context for GitHub work. Everything goes through the `mcp__github__*` MCP tools — never `curl` the GitHub API, never read `~/claude-kit/generated/.github.env`.

The server is registered **read-only** (`GITHUB_READ_ONLY=1`): it exposes only read tools, so creating PRs/branches, pushing, commenting, and merging are impossible by construction. This mirrors the hard rule "never write out to GitHub." The human raises PRs — see the `create-oe-pr` skill; never use `gh` or `git push`/`git commit` to do it for them.

## Check — fail fast

1. **Tools present?** If the `mcp__github__*` tools are not in your toolset, the server didn't connect at startup. Run the remediation block, tell the user to **restart Claude Code** (MCP tools bind at startup), and stop.
2. **Ping:** `mcp__github__get_me` with `{}` — the cheapest read; returns the authenticated user.

Interpret the call:
- **Returns the user with no error** → healthy.
- **Permission denied** → the `mcp__github` allow rule is missing from settings. Tell the user to re-run `~/claude-kit/install.sh -p <tier> -y` (or add `mcp__github` to `permissions.allow`) and stop.
- **Connection error / "not connected" / timeout** → run the remediation block, tell the user to restart, and stop.
- **401 / bad credentials** → the PAT in `generated/.github.env` is missing, expired, or lacks access. Tell the user to mint a fresh fine-grained read-only PAT and re-run `~/claude-kit/install.sh -g -p <tier> -y`, then stop.

**Fail fast:** if the ping fails, stop here — do not fall back to `curl` or the REST API. Only when it succeeds, print a one-line `GitHub ✔` and the project context below, then proceed to whatever the user asked for.

Remediation (shell/CLI only — none of this touches the GitHub REST API):

```bash
docker info >/dev/null 2>&1 || echo "Docker daemon is not running — start Docker."
docker image inspect ghcr.io/github/github-mcp-server >/dev/null 2>&1 \
  || docker pull ghcr.io/github/github-mcp-server          # pull the image if absent
claude mcp get github >/dev/null 2>&1 \
  || (cd ~/claude-kit && ./install.sh -g -p trusted -y)    # register the server if absent
claude mcp list                                            # expect: github … ✔ Connected
```

The stdio container is launched by Claude Code itself on (re)start — you cannot `docker run` it into this session out of band. Once the image is present and the server is registered, a restart brings the tools online.

## Project context (the token's visible scope)

GitHub org: `openeyes` · repo links: `https://github.com/openeyes/<repo>`.

- The OpenEyes repos are **private** — anonymous access 401s. The PAT must be a fine-grained token with read access to the `openeyes` org's repos; without org access, reads return 404/empty.
- The token is **read-only** by design. Use `mcp__github__*` for reading code, commits, PRs, issues, CI runs, and code search. There are no write tools to call.
- Writes are out of scope: the human raises commits/PRs (`create-oe-pr` packages the PR; the human runs `git commit`/`git push`).
