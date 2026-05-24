# Jira + Confluence via the Atlassian MCP

This kit can wire Claude Code into Atlassian's hosted MCP server so the model can search issues, read pages, and post comments without you copying URLs around. Setup is opt-in, OAuth-based, and easy to tear down.

## What you get

Once authenticated, Claude Code can call tools like:

- `searchJiraIssues`, `getJiraIssue`, `addJiraComment`, `transitionJiraIssue`
- `searchConfluencePages`, `getConfluencePage`, `createConfluencePage`

…against any Atlassian Cloud workspace your account can reach.

## Setup

```bash
cd ~/claude-kit
./install.sh --with-atlassian -p standard -y
```

This merges `settings/mcp-atlassian.json` into `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "atlassian": {
      "type": "sse",
      "url": "https://mcp.atlassian.com/v1/sse"
    }
  }
}
```

Then, inside an interactive Claude Code session, run:

```
/mcp
```

Select `atlassian` and follow the browser prompt. Atlassian will OAuth-auth you against your workspace; the cached token lives in Claude Code's own credentials store (separately from this kit).

Once `/mcp` reports the server as `connected`, you're done. Test with:

> "Search Jira for tickets assigned to me with `status = "In Progress"` in the ENG project."

## Choosing the workspace

The Atlassian Remote MCP server is account-scoped. If you have access to multiple workspaces, the OAuth flow will let you pick which one to grant. You can re-run the OAuth flow (`/mcp` → `atlassian` → re-authenticate) to swap workspaces later.

## Permissions on the Atlassian side

The MCP only sees what your Atlassian account sees. The OAuth scopes Atlassian requests are read+write for Jira and Confluence; if your org restricts OAuth apps, an admin may need to approve the integration once. Without that approval the auth flow will fail with a clear error in the browser.

## Teardown

To remove the MCP server from this kit's settings:

```bash
./install.sh --without-atlassian -p <your-tier> -y
```

This deletes the `atlassian` entry from `settings.json`'s `mcpServers` block. If `mcpServers` becomes empty, it's removed entirely so the file stays tidy.

**Important:** `--without-atlassian` only deletes the config. The cached OAuth token still lives in Claude Code's credentials store. To revoke it fully:

1. Inside Claude Code, run `/mcp` → select `atlassian` → choose "disconnect" or "remove credentials" (label varies by version).
2. **And** revoke the app on Atlassian's side: <https://id.atlassian.com/manage-profile/security/connected-apps> → find "Claude" / "Anthropic" → Remove access.

Step 2 is the one that actually invalidates the token server-side. Step 1 just clears the local cache.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `/mcp` lists `atlassian` as `disconnected` | OAuth not completed yet — select the entry and follow the prompt. |
| Browser shows "App not approved for this workspace" | Your org's Atlassian admin needs to approve the Anthropic OAuth app. |
| `searchJiraIssues` returns nothing for queries you know match | The OAuth grant landed on a different workspace than you expected. Re-auth via `/mcp`. |
| MCP server stays `connected` but every tool call 401s | Cached token has expired or been revoked. Disconnect in `/mcp` and re-auth. |
| `settings.json` has `mcpServers` but Claude Code says "no servers" | Restart Claude Code — MCP config is read at startup. |

## Why the SSE transport (and not stdio)

Two MCP shapes exist for Atlassian:

- **SSE (used here):** `type: "sse", url: "https://mcp.atlassian.com/v1/sse"`. Hosted by Atlassian, OAuth-authed in the browser, zero local dependencies.
- **Stdio (community):** `command: "uvx", args: ["mcp-atlassian"]` with API-token env vars. Useful for self-hosted Server / Data Center instances and air-gapped setups.

The kit ships the SSE variant because it works for Atlassian Cloud out of the box and avoids storing long-lived API tokens in `settings.json`. If you need the stdio variant for a Data Center instance, swap `settings/mcp-atlassian.json` for the stdio config (the Sooperset `mcp-atlassian` repo has a worked example) and re-run `./install.sh --with-atlassian`.

## What this kit doesn't touch

- `~/.config/claude/mcp.json`, `~/.claude/mcp.json`, or any other MCP config file Claude Code may add in future versions. The kit only edits `~/.claude/settings.json` because that's the documented schema today.
- Your Atlassian API tokens. The SSE path uses OAuth; tokens never appear in this repo or in `settings.json`.
- `claude mcp add` / `claude mcp remove` — those manage a different config scope and are unaffected.
