# Jira via the mcp-atlassian Docker image

This kit wires Claude Code into Jira using the community `mcp-atlassian` server,
run as a container (`docker run -i --rm … ghcr.io/sooperset/mcp-atlassian:latest`)
over MCP's stdio transport. Nothing Python-related is installed on the host — only
Docker is required. Credentials are kept in a gitignored env file, not in the kit
repo itself.

## What you get

Once configured, Claude Code can call tools like:

- `searchJiraIssues`, `getJiraIssue`, `addJiraComment`, `transitionJiraIssue`
- `createJiraIssue`, `updateJiraIssue`

…scoped to whichever Jira projects you set in `JIRA_PROJECTS_FILTER`.

## Prerequisites

Docker. install.sh checks for it and stops with a clear message if it's missing.
The image (`ghcr.io/sooperset/mcp-atlassian:latest`) is public on GHCR — no `docker
login` needed — and is pulled automatically by Docker the first time Claude Code
starts the MCP server.

You also need a Jira API token. See the notes app: search "Atlassian - Generate an API token".

## Setup

Configure Jira only:

```bash
cd ~/claude-kit
./install.sh -j -p standard
```

Configure Confluence only:

```bash
./install.sh -c -p standard
```

Configure both at once:

```bash
./install.sh --with-atlassian -p standard   # shorthand for -j -c
```

If `generated/.atlassian.env` does not already contain the relevant values,
install.sh prompts interactively:

**Jira** (`-j`): `JIRA_URL`, `JIRA_USERNAME`, `JIRA_API_TOKEN`, `JIRA_PROJECTS_FILTER`

**Confluence** (`-c`): `CONFLUENCE_URL`, `CONFLUENCE_USERNAME`, `CONFLUENCE_API_TOKEN`,
`CONFLUENCE_SPACES_FILTER` — defaults to the Jira values entered in the same run, since
for Atlassian Cloud the URL and credentials are usually the same.

All values are saved to `generated/.atlassian.env` (mode 600, gitignored). install.sh
then registers the server at **user scope** via `claude mcp add-json atlassian … -s user`
(stored in `~/.claude.json`, not `settings.json` — Claude Code reads MCP servers only
from there). Running `-j` alone preserves any previously configured Confluence vars in
the file, and vice versa. Restart Claude Code to pick up the changes.

## Token rotation

Edit `generated/.atlassian.env` to replace the old token, then re-run with `-y` to
apply silently:

```bash
./install.sh -j -p standard -y   # re-applies Jira from env file
./install.sh -c -p standard -y   # re-applies Confluence from env file
```

## Teardown

```bash
./install.sh --without-atlassian -p standard -y
```

Deregisters the server (`claude mcp remove atlassian -s user`). The credentials file
`generated/.atlassian.env` is left in place — delete it manually to clear tokens.

To clear the credentials in one go, `./install.sh -l atlassian` (allowed on every
permission tier) deregisters the server AND removes `generated/.atlassian.env`, then
exits — revoke the API token itself at
https://id.atlassian.com/manage-profile/security/api-tokens.

## The credentials file

`generated/.atlassian.env` is plain shell:

```bash
JIRA_URL=https://toukanlabs.atlassian.net
JIRA_USERNAME=you@toukanlabs.com
JIRA_API_TOKEN=your-token-here
JIRA_PROJECTS_FILTER=TKLS,OE
```

It is listed in `.gitignore` and never committed. It is also never touched by
`--without-atlassian` — only a manual `rm generated/.atlassian.env` removes it.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `docker not found` | Install Docker, then re-run install.sh. |
| First call to the server is slow / hangs briefly | Docker is pulling the image on first use. Pre-pull with `docker pull ghcr.io/sooperset/mcp-atlassian:latest`. |
| MCP server shows as `failed` in `/mcp` | Bad token or wrong URL — check `generated/.atlassian.env` and re-run `--with-atlassian`. |
| `401` from Jira even though the token shows as recently "accessed" in id.atlassian.com | The token is a **scoped** API token. Scoped tokens are refused at the site URL (`https://<site>.atlassian.net`) and only work through the gateway (`https://api.atlassian.com/ex/jira/<cloudId>`), which this server's basic-auth mode never calls. The gateway returns `{"code":401,"message":"Unauthorized; scope does not match"}` rather than a bad-credential error. Use a **classic (unscoped)** API token, or switch to OAuth 2.0 (see "Using a scoped token instead" below). |
| `searchJiraIssues` returns nothing for known tickets | Project key not in `JIRA_PROJECTS_FILTER` — add it and re-run `--with-atlassian -y`. |
| Settings applied but Claude Code says "no servers" | Restart Claude Code — MCP config is read at startup. |

## Using a scoped token instead (OAuth 2.0)

A *scoped* (least-privilege) Atlassian API token will **not** work with the
basic-auth setup above: scoped tokens are rejected at the site URL and only
authenticate through Atlassian's gateway (`https://api.atlassian.com/ex/jira/<cloudId>`),
which this server's API-token mode never calls. The server's scoped path is
OAuth 2.0 — note this is a *different credential* (an OAuth app, not the API
token you generated), and a heavier one-time setup:

1. Create an OAuth 2.0 (3LO) app at https://developer.atlassian.com/console/myapps
   — enable the Jira (and Confluence) APIs, add scopes
   `read:jira-work write:jira-work read:jira-user offline_access` (add
   `read:confluence-content.all write:confluence-content` for Confluence), and
   set the callback URL to `http://localhost:8080/callback`. Copy the **Client
   ID** and **Secret**.

2. Run the one-time setup wizard (opens a browser to authorize). It needs the
   port published and a volume mounted, and it writes a refresh token into
   `~/.mcp-atlassian/`:

   ```bash
   docker run --rm -i -p 8080:8080 \
     -v "${HOME}/.mcp-atlassian:/home/app/.mcp-atlassian" \
     ghcr.io/sooperset/mcp-atlassian:latest --oauth-setup -v
   ```

3. The MCP entry changes shape. Instead of `JIRA_API_TOKEN` it carries the OAuth
   vars, and it **must mount the token cache** so the `--rm` container keeps the
   refresh token between runs:

   - args: add `-v`, `${HOME}/.mcp-atlassian:/home/app/.mcp-atlassian` to the
     `docker run` list
   - env: `ATLASSIAN_OAUTH_CLIENT_ID`, `ATLASSIAN_OAUTH_CLIENT_SECRET`,
     `ATLASSIAN_OAUTH_REDIRECT_URI`, `ATLASSIAN_OAUTH_SCOPE`,
     `ATLASSIAN_OAUTH_CLOUD_ID`, `ATLASSIAN_OAUTH_ENABLE=true` — get the cloud id
     from `https://<site>.atlassian.net/_edge/tenant_info`

The refresh token auto-renews while the `offline_access` scope is present; if it
goes stale, re-run the wizard. `install.sh` does not yet wire this mode — it
configures the classic-token path only.

## Why Docker stdio over SSE

The previous SSE approach (`type: "sse", url: "https://mcp.atlassian.com/v1/sse"`)
used Atlassian's hosted OAuth server. The Docker stdio approach runs
`ghcr.io/sooperset/mcp-atlassian` locally with API-token env vars — no host Python
install, and you pin exactly which projects/spaces are visible to Claude via
`JIRA_PROJECTS_FILTER` / `CONFLUENCE_SPACES_FILTER`. The bare `-e VAR` args mean the
tokens live only in the `env` block, never on the `docker` command line.
