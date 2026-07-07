---
name: codexmcp
description: Preflight Codex MCP, then fan out Codex agents
disable-model-invocation: true
---

# Codex agents (OpenAI Codex via MCP)

Confirm the Codex MCP server is connected, fail fast if it isn't, then delegate work
to one or more autonomous Codex coding agents. Everything goes through the
`mcp__codex__*` MCP tools — never shell out to `codex exec`/`codex` yourself, never
read `~/claude-kit/generated/.codex.env`, never touch `~/.codex/auth.json`.

The server runs `codex mcp-server` inside a locally-built docker container
(`claude-kit-codex`, from `~/claude-kit/docker/codex/`; the host `codex` binary is
the fallback only when Docker is absent) and is registered with its defaults baked in
(set by `install.sh -x`): the **flagship model at high reasoning effort**, sandboxed,
`approval_policy=never` so agents run unattended. In docker mode the **container is
the sandbox** — only the project dir and `~/.codex` are mounted; in host mode it's
codex's own **workspace-write, network-off** sandbox. It exposes two tools:

- `mcp__codex__codex` — start a fresh Codex agent on a self-contained task.
- `mcp__codex__codex-reply` — continue a specific agent's thread (give follow-ups,
  feed back test output, ask for a revision) using the conversation id it returned.

## Check — fail fast

1. **Tools present?** If the `mcp__codex__*` tools are not in your toolset, the server
   didn't connect at startup. Run the remediation block, tell the user to **restart
   Claude Code** (MCP tools bind at startup), and stop.
2. **Signed in?** Codex auth is the ChatGPT login in `~/.codex`. Check
   `[ -f ~/.codex/auth.json ]` (read-only; don't open the file). If absent, give the
   user the container sign-in command from the remediation block and stop — agent
   calls will fail until then.

Do **not** "ping" by spawning a throwaway `codex` call — every `mcp__codex__codex` call
is a billable agent run against the ChatGPT plan. Tool-presence + login status is the
whole check.

Interpret:
- **Tools present and `~/.codex/auth.json` exists** → print a one-line `Codex ✔` and proceed.
- **Permission denied calling the tool** → the `mcp__codex` allow rule is missing for
  this tier. Codex is allowed on `standard`/`trusted`/`yolo` but **prompts on `ultra-safe`**
  (it writes files). Either approve the prompt, or re-run `~/claude-kit/install.sh -p
  <tier>` for a tier that allows it, then stop.
- **Connection error / "not connected" / timeout** → run remediation, restart, stop.
- **Not signed in / 401** → have the user sign in via the container login command in
  the remediation block, then stop.

## Spawning agents — one or many, at the best model

The defaults are already pinned at the server, so a **bare prompt is enough** — you do
not need to pass model/sandbox per call. Each `mcp__codex__codex` call is an independent
agent with its own context and its own sandboxed shell.

- **Run several at once:** issue multiple `mcp__codex__codex` calls **in a single
  message** to fan them out concurrently. Give each a self-contained brief — agents do
  not share state, so spell out the file paths, the goal, and the acceptance check in
  every prompt.
- **Decompose first.** Split the work into independent slices (per module, per file,
  per failing test) so agents don't collide on the same files. Overlapping writes race.
- **Set the working directory.** Pass the repo/subdir as the agent's `cwd` so it edits
  the right tree; default is the session's directory.
- **Iterate with `codex-reply`.** Keep the conversation id each agent returns; use
  `mcp__codex__codex-reply` to send "tests still red, here's the output…" rather than
  starting a fresh agent that has lost the context.
- **Then review.** Treat agent output as a proposal: read the diffs it made, run the
  tests/build yourself, and only keep what verifies. You own the result.

A good agent prompt is a closed loop: *what to change · where (paths) · how to know it's
done (the command that must pass)*. Example shape — "In `protected/modules/foo`, make
`BarController::actionBaz` return JSON; run `./yiic test foo` until green; don't touch
other modules."

## Safety — agents have their own shell, outside Claude's permission rules

A Codex agent runs commands in **its own sandbox**, so the kit's `permissions.deny`
rules and the hard floor in `~/.claude/CLAUDE.md` do **not** gate it. The registration
defends this instead:

- **No push.** Docker mode: the container carries **no git credentials** (no `~/.ssh`,
  no helpers), so `git push` fails auth even though the container has network for the
  OpenAI API. Host mode: `workspace-write` + `network_access=false` blocks the network
  outright. Either way the never-push floor holds.
- **Never commit.** `git commit` is local, so no sandbox can block it — **instruct
  every agent not to commit or stage**; the human commits (see `create-oe-pr`). Reject
  any agent output that committed.
- **Workspace-only writes.** Docker mode mounts only the project dir (plus `~/.codex`);
  host mode confines writes to the agent's `cwd` tree. Don't point an agent at `~` or `/`.
- If a task genuinely needs network or wider access, that's a deliberate `install.sh -x`
  re-run to a looser sandbox — and only in a throwaway container/VM. Don't work around
  the sandbox by running `codex` from the shell yourself.

## Remediation (shell/CLI only)

```bash
docker image inspect claude-kit-codex >/dev/null 2>&1 \
  || echo "image missing — (cd ~/claude-kit && ./install.sh -x -p trusted -y) builds it"
[ -f ~/.codex/auth.json ] \
  || echo 'not signed in — run: docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$HOME/.codex:/home/codex/.codex" claude-kit-codex login'
claude mcp get codex >/dev/null 2>&1 \
  || (cd ~/claude-kit && ./install.sh -x -p trusted -y)   # register the server if absent
claude mcp list                                           # expect: codex … ✔ Connected
```

`codex mcp-server` is launched by Claude Code itself on (re)start — you cannot start it
out of band into this session. Once the image is built, you're signed in, and the
server is registered, a restart brings the tools online. (Older Codex builds used
`codex mcp` to run the server; current builds use `codex mcp-server` and reserve
`codex mcp` for managing client entries — `install.sh` registers the current form.)

## Config (what the agents inherit)

Set by `install.sh -x`, recorded non-secretly in `~/claude-kit/generated/.codex.env`:

- `CODEX_MODEL` — the model id agents run (default the flagship, e.g. `gpt-5.5`).
- `CODEX_REASONING_EFFORT` — default `high` (`xhigh` on models that support it).
- `CODEX_SANDBOX` — default `workspace-write` (network off); **host mode only** — in
  docker mode the container is the sandbox and this knob is ignored at launch.

To change any of these, edit `generated/.codex.env` and re-run `./install.sh -x -y`,
then restart Claude Code. The ChatGPT login itself lives in `~/.codex`, never in the kit.
