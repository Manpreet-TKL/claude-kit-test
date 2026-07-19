---
name: reference-claude-code-mcp-config-location
description: "Claude Code loads MCP servers from ~/.claude.json (claude mcp add) or .mcp.json - NOT from ~/.claude/settings.json's mcpServers key."
metadata: 
  node_type: memory
  type: reference
  originSessionId: a1182574-cdb1-4438-8c33-2b4edc98ee62
---

Claude Code does **not** read MCP server definitions from `~/.claude/settings.json`. A `mcpServers` block placed there is valid JSON but silently ignored - no server launches, no logs, no container, and restarting never helps. Confirmed empirically: the same config that was inert in settings.json connected (`✔ Connected`) the moment it was registered via `claude mcp add-json`.

MCP servers live in:
- `~/.claude.json` - added with `claude mcp add` / `claude mcp add-json <name> <json> -s <scope>`. Scopes: `user` (auto-loads in every session/project - the right one for a personal Jira/Atlassian server), `local` (this project only), `project` (checked-in `.mcp.json`, shared).
- a project-root `.mcp.json` (project scope).

Verify/manage with `claude mcp list` / `claude mcp get <name>` / `claude mcp remove <name> -s <scope>`. MCP tools bind at **session startup**, so a newly-added server isn't live until the next restart. Gotcha (2026-07-19): `claude mcp get <name>` health-checks by **actually launching the server command** - against claude-kit's gated registrations that consumes the one-shot `generated/mcp-on/<name>` flag; check registration by reading `~/.claude.json` with jq instead (install.sh's verify does exactly this).

**Applies to claude-kit:** `install.sh` registers atlassian/github/codex via `claude mcp add-json <name> "$json" -s user` (teardown: `claude mcp remove <name> -s user`) - the earlier jq-merge into `settings.json` was the bug this memory caught. See [[project_atlassian_scoped_token_gateway]] for the token flavour the atlassian server needs.
