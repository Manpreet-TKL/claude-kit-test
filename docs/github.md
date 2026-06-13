# GitHub via the github-mcp-server Docker image (read-only)

This kit wires Claude Code into GitHub using GitHub's official `github-mcp-server`,
run as a container (`docker run -i --rm … ghcr.io/github/github-mcp-server`) over
MCP's stdio transport. Nothing is installed on the host — only Docker is required.
The token is kept in a gitignored env file, not in the kit repo itself.

**The server is registered read-only.** `install.sh` bakes `GITHUB_READ_ONLY=1` into
the registration as a fixed constant — the GitHub project documents this as "a strict
security filter that takes precedence over any other configuration," disabling every
tool that is not read-only. So the server never even exposes create-PR / push / comment
/ merge tools. This is the GitHub-API analogue of the kit's hard floor that denies
`git push` / `git commit` on every tier. Read-only is **not** configurable through the
env file — editing credentials cannot turn it off.

## What you get

Once configured, Claude Code can call **read** tools like:

- `get_me`, `search_repositories`, `search_code`, `get_file_contents`
- `list_commits`, `get_commit`, `list_pull_requests`, `get_pull_request`, `get_pull_request_files`
- `list_issues`, `get_issue`, and CI/Actions read tools

…governed by the access of the PAT you supply. There are no write tools — by design.

## Prerequisites

Docker. install.sh checks for it and stops with a clear message if it's missing. The
image (`ghcr.io/github/github-mcp-server`) is public on GHCR — no `docker login` needed
— and is pulled automatically by Docker the first time Claude Code starts the server.

You also need a **fine-grained, read-only** GitHub personal access token. At
https://github.com/settings/personal-access-tokens:

1. **Resource owner:** the `openeyes` org (the repos are private — the token must have
   org access or reads return 404/empty).
2. **Repository access:** the repos you need (or all org repos).
3. **Permissions (Repository), all read-only:** Contents → Read, Metadata → Read
   (mandatory), Pull requests → Read, Issues → Read. Add others (Actions → Read, etc.)
   only if you need them. Grant **no** write permissions.

A fine-grained PAT is preferred over a classic token; grant only what you need.

## Setup

```bash
cd ~/claude-kit
./install.sh -g -p standard
```

If `settings/.github.env` does not already contain the token, install.sh prompts for
`GITHUB_PERSONAL_ACCESS_TOKEN` (hidden) and an optional `GITHUB_TOOLSETS` filter. The
value is saved to `settings/.github.env` (mode 600, gitignored). install.sh then
registers the server at **user scope** via `claude mcp add-json github … -s user`
(stored in `~/.claude.json`, not `settings.json` — Claude Code reads MCP servers only
from there). Restart Claude Code to pick up the changes, then run `/githubmcp` to verify.

## The registered MCP server JSON

There is no committed `settings/mcp-github.json` fragment. Atlassian ships a static
`settings/mcp-atlassian.json` that is jq-merged into `settings.json`, but GitHub can't:
the server JSON embeds the secret PAT, which must never be committed. So `install.sh`
builds the object and registers it into `~/.claude.json` (user scope) via
`claude mcp add-json github … -s user`. For reference, the registered object looks like:

```json
{
  "command": "docker",
  "args": [
    "run", "-i", "--rm",
    "-e", "GITHUB_PERSONAL_ACCESS_TOKEN",
    "-e", "GITHUB_READ_ONLY",
    "ghcr.io/github/github-mcp-server"
  ],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "github_pat_…",
    "GITHUB_READ_ONLY": "1"
  }
}
```

`GITHUB_READ_ONLY` is always `"1"` — baked in, never sourced from the env file. If
`GITHUB_TOOLSETS` is set in `settings/.github.env` it is added both as an
`-e GITHUB_TOOLSETS` arg and an `env` key; when blank it is dropped entirely. The bare
`-e VAR` args mean each value is read from the `env` block, so the token never appears on
the `docker` command line. Inspect the live registration with `claude mcp get github`.

## Token rotation

Edit `settings/.github.env` to replace the old token, then re-run with `-y` to apply
silently:

```bash
./install.sh -g -p standard -y   # re-applies GitHub from the env file
```

## Teardown

```bash
./install.sh --without-github -p standard -y
```

Deregisters the server (`claude mcp remove github -s user`). The credentials file
`settings/.github.env` is left in place — delete it manually to clear the token, and
revoke the PAT at https://github.com/settings/personal-access-tokens.

## The credentials file

`settings/.github.env` is plain shell:

```bash
GITHUB_PERSONAL_ACCESS_TOKEN=github_pat_...
GITHUB_TOOLSETS=repos,pull_requests,issues   # optional; blank = server default
```

It is listed in `.gitignore` and never committed. It does **not** hold
`GITHUB_READ_ONLY` — that constant lives in `install.sh` so read-only can't be disabled
by editing this file. The file is never touched by `--without-github` — only a manual
`rm settings/.github.env` removes it.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `docker not found` | Install Docker, then re-run install.sh. |
| First call to the server is slow / hangs briefly | Docker is pulling the image on first use. Pre-pull with `docker pull ghcr.io/github/github-mcp-server`. |
| MCP server shows as `failed` in `/mcp` | Bad/expired token — check `settings/.github.env` and re-run `-g`. |
| `401` / bad credentials | The PAT is missing, expired, or revoked. Mint a fresh fine-grained read-only PAT and re-run `-g -y`. |
| Reads of a known repo return 404 / empty | The fine-grained PAT lacks access to that repo or the `openeyes` org. Re-mint with the org as resource owner and the repos selected. |
| A write tool is missing | Expected — read-only mode (`GITHUB_READ_ONLY=1`) hides all write tools. The human raises PRs (see the `create-oe-pr` skill). |
| Settings applied but Claude Code says "no servers" | Restart Claude Code — MCP config is read at startup. |

## Why read-only

The user's hard rule is "never write out to GitHub." Rather than relying only on a
permission `deny` list (which would have to enumerate every write tool), the strongest
guarantee is to make the server itself read-only: with `GITHUB_READ_ONLY=1` the write
tools never exist in the session, so there is nothing to deny and nothing to slip
through. The bare `-e VAR` docker args mean the token lives only in the `env` block,
never on the `docker` command line.
