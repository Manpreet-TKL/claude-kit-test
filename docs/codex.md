# OpenAI Codex agents via `codex mcp-server`

This kit can wire Claude Code into **OpenAI Codex** so Claude can hand a coding task —
or many in parallel — to autonomous Codex agents. Unlike the Atlassian and GitHub
integrations (which run a Docker image), Codex runs the **host `codex` binary** as
`codex mcp-server` over MCP's stdio transport. Nothing is containerised; you install
the Codex CLI and sign in once.

The server exposes two tools, surfaced in Claude Code as `mcp__codex__codex` (start an
agent on a task) and `mcp__codex__codex-reply` (continue one). Claude fans agents out by
calling `codex` several times in one message. Drive it through the **`codexmcp`** skill —
run `/codexmcp` before delegating, and follow its rules.

## What you get

Once configured, Claude can:

- spawn a single Codex agent on a self-contained task, or **several at once** (one per
  module / file / failing test) that run concurrently;
- continue any agent's thread with `codex-reply` (feed back test output, ask for a fix);
- have each agent run at the **flagship model + high reasoning effort**, in a
  **workspace-write, network-off sandbox** (`approval_policy=never`, so unattended).

Agent output is a **proposal**: Claude reads the diffs, runs the build/tests, and keeps
only what verifies. You still own the commit — the human commits and pushes.

## Prerequisites

1. **The Codex CLI on PATH.** `install.sh` checks for `codex` and stops with a clear
   message if it's missing:

   ```bash
   npm install -g @openai/codex      # or: brew install codex
   ```

2. **A ChatGPT sign-in.** This kit registers Codex to authenticate with your ChatGPT
   plan (Plus / Pro / Team / Enterprise), not an API key — so **no token is stored in
   the kit**. Sign in once on the host:

   ```bash
   codex login                       # opens a browser; auth saved to ~/.codex
   codex login status                # verify
   ```

   ChatGPT-plan auth is subject to your plan's rate limits, which can throttle a wide
   fan-out. If you'd rather bill per-token via an API key (recommended by OpenAI for
   heavy programmatic use), set `OPENAI_API_KEY` in the environment and re-run — Codex
   falls back to it when no ChatGPT session is present.

## Setup

```bash
cd ~/claude-kit
./install.sh -x -p standard
```

Interactively, install.sh prompts for three **non-secret** knobs (defaults shown),
saves them to `generated/.codex.env` (mode 600), then registers the server at **user
scope** via `claude mcp add-json codex … -s user` (stored in `~/.claude.json`, not
`settings.json`). The knobs become `-c key=value` launch overrides, so every spawned
agent inherits them:

| Knob | Default | Becomes |
|---|---|---|
| `CODEX_MODEL` | `gpt-5.5` (flagship) | `-c model="…"` |
| `CODEX_REASONING_EFFORT` | `high` | `-c model_reasoning_effort="…"` |
| `CODEX_SANDBOX` | `workspace-write` | `-c sandbox_mode="…"` (+ `network_access=false`) |

`approval_policy=never` is always set so agents don't block on prompts. Restart Claude
Code to pick up the server, then run `/codexmcp` to verify.

## Changing the model or sandbox

Edit `generated/.codex.env` and re-apply silently:

```bash
./install.sh -x -p standard -y    # re-reads the knobs, re-registers
```

- **Model.** `gpt-5.5` is the flagship/most-capable as of mid-2026; `gpt-5.3-codex` is
  the coding-tuned workhorse (better throughput/cost for a parallel fan-out). Point
  `CODEX_MODEL` at whatever is current — update it when OpenAI ships the next one.
- **Reasoning effort.** `high` is the default; `xhigh` is available on some models only.
- **Sandbox.** Keep `workspace-write` (network off) so agents can't `git push`. Only
  widen to `danger-full-access` inside a throwaway container/VM.

## Why workspace-write, network-off, and never-commit

A Codex agent runs commands in **its own sandbox** — the kit's `permissions.deny` list
and the never-`git push`/never-`git commit` floor in `~/.claude/CLAUDE.md` do **not**
gate it, because that shell isn't Claude's `Bash` tool. The registration enforces the
equivalent another way:

- **Network off** (`workspace-write` + `sandbox_workspace_write.network_access=false`)
  means an agent literally cannot reach the network, so it **cannot `git push`** or
  fetch — the sandbox analogue of the never-push hard floor.
- **`git commit` is local**, so the sandbox can't block it. The `codexmcp` skill
  therefore instructs every agent **not to commit or stage**, and to reject output that
  did. The human commits (see the `create-oe-pr` skill).
- **Writes are confined to the agent's `cwd` tree** — point agents at the repo, never at
  `~` or `/`.

This is also why `mcp__codex` is allowed on the `standard`/`trusted`/`yolo` tiers but
**not on `safe`**: spawning an autonomous writer is a write action, and the read-mostly
`safe` tier prompts before it. On `safe` you'll get a permission prompt the first time.

## Teardown

```bash
./install.sh --without-codex -p standard -y      # -X
```

Deregisters the server (`claude mcp remove codex -s user`). `generated/.codex.env` and
your `~/.codex` login are left in place — delete them manually, and run `codex logout`
if you want to clear the ChatGPT session.

## The config file

`generated/.codex.env` is plain shell and **holds no secret** (auth is in `~/.codex`):

```bash
CODEX_MODEL=gpt-5.5
CODEX_REASONING_EFFORT=high
CODEX_SANDBOX=workspace-write
```

It lives in the kit's single `generated/` folder (gitignored wholesale) alongside the
Atlassian/GitHub creds, so one backup of that folder survives a `git reset --hard`.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `codex CLI not found` | Install it (`npm install -g @openai/codex`), then re-run `-x`. |
| MCP server shows `failed` in `/mcp` | Not signed in — run `codex login` on the host. |
| Agent calls return an auth/401 error | ChatGPT session expired — `codex login` again. |
| "rate limit" / throttling on a wide fan-out | ChatGPT-plan limits — narrow the fan-out, or switch to `OPENAI_API_KEY`. |
| An agent couldn't `git push` / fetch | Expected — the `workspace-write` sandbox has network off. |
| `codex mcp` errors instead of serving | Old vs new CLI: current builds serve via `codex mcp-server`; `codex mcp` now manages client entries. Update the Codex CLI. |
| Tools missing after setup | Restart Claude Code — MCP servers bind at startup. |
| Permission prompt on every spawn | You're on the `safe` tier (by design). Use `standard`+ or approve the prompt. |
