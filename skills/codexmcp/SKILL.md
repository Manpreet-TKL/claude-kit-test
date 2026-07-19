---
name: codexmcp
description: Codex MCP context + gate enable, then fan out agents
disable-model-invocation: false
---

# Codex agents (OpenAI Codex via MCP)

Load how the kit's Codex MCP works, make its tools available (enabling the startup
gate if needed), then delegate work to one or more autonomous Codex coding agents.
Everything goes through the `mcp__codex__*` MCP tools - never shell out to
`codex exec`/`codex` yourself, never read `~/claude-kit/generated/.codex.env`, never
touch `~/.codex/auth.json`.

The server runs `codex mcp-server` inside a locally-built docker container
(`claude-kit-codex`, from `~/claude-kit/docker/codex/`; the host `codex` binary is
the fallback only when Docker is absent) and is registered with its defaults baked in
(set by `install.sh -x`): the **flagship model (`gpt-5.6-sol`) at `xhigh` reasoning
effort**, sandboxed,
`approval_policy=never` so agents run unattended. In docker mode the **container is
the sandbox** - only the project dir and `~/.codex` are mounted; in host mode it's
codex's own **workspace-write, network-off** sandbox. It exposes two tools:

- `mcp__codex__codex` - start a fresh Codex agent on a self-contained task.
- `mcp__codex__codex-reply` - continue a specific agent's thread (give follow-ups,
  feed back test output, ask for a revision) using the conversation id it returned.

## Check - tools present, or touch the gate

1. **Tools present?** If the `mcp__codex__*` tools are in your toolset, print a
   one-line `Codex OK` and proceed.
2. **Tools absent?** Run `touch ~/claude-kit/generated/mcp-on/codex` - the **only**
   shell command this skill runs - then reply with exactly this one line and nothing
   else (no explanation of the gate, no advice dump) and stop:

   `codex MCP ungated - reconnect: /mcp -> codex -> reconnect`

   Once the user has reconnected, continue with the task.

Do **not** "ping" by spawning a throwaway `codex` call - every `mcp__codex__codex` call
is a billable agent run against the ChatGPT plan. Tool presence is the whole check.
Beyond that one `touch`, take no other action: no docker commands, no `install.sh`
runs, no probing `~/.codex` - everything below is context and advice for the user,
not commands to run.

## Permissions - two prompts are normal, approve them

Using this skill can raise up to two permission prompts; neither is an error:

1. The gate `touch` itself may prompt as a Bash command on stricter tiers -
   approve it; it is the only shell command this skill runs.
2. The first `mcp__codex__*` call prompts when the tier lacks the `mcp__codex`
   allow rule: allowed on `standard`/`trusted`/`yolo`, **always prompts on
   `ultra-safe`** (agents write files) - approve it, or switch tier with
   `~/claude-kit/install.sh -p <tier>`.

## Spawning agents - one or many, at the best model

The defaults are already pinned at the server, so a **bare prompt is enough** - you do
not need to pass model/sandbox per call. Each `mcp__codex__codex` call is an independent
agent with its own context and its own sandboxed shell. When a task wants a different
tier, override per call: the `codex` tool accepts `model` and `config` (e.g.
`{"model_reasoning_effort": "low"}`) alongside `prompt`/`cwd`, leaving the registration
defaults untouched - `codex-grill` and `codex-swarm` build on exactly this.

- **Run several at once:** issue multiple `mcp__codex__codex` calls **in a single
  message** to fan them out concurrently. Give each a self-contained brief - agents do
  not share state, so spell out the file paths, the goal, and the acceptance check in
  every prompt.
- **Decompose first.** Split the work into independent slices (per module, per file,
  per failing test) so agents don't collide on the same files. Overlapping writes race.
- **Set the working directory.** Pass the repo/subdir as the agent's `cwd` so it edits
  the right tree; default is the session's directory.
- **Iterate with `codex-reply`.** Keep the conversation id each agent returns; use
  `mcp__codex__codex-reply` to send "tests still red, here's the output..." rather than
  starting a fresh agent that has lost the context.
- **Then review.** Treat agent output as a proposal: read the diffs it made, run the
  tests/build yourself, and only keep what verifies. You own the result.

A good agent prompt is a closed loop: *what to change, where (paths), how to know it's
done (the command that must pass)*. Example shape - "In `protected/modules/foo`, make
`BarController::actionBaz` return JSON; run `./yiic test foo` until green; don't touch
other modules."

## Safety - agents have their own shell, outside Claude's permission rules

A Codex agent runs commands in **its own sandbox**, so the kit's `permissions.deny`
rules and the hard floor in `~/.claude/CLAUDE.md` do **not** gate it. The registration
defends this instead:

- **No push.** Docker mode: the container carries **no git credentials** (no `~/.ssh`,
  no helpers), so `git push` fails auth even though the container has network for the
  OpenAI API. Host mode: `workspace-write` + `network_access=false` blocks the network
  outright. Either way the never-push floor holds.
- **Never commit.** `git commit` is local, so no sandbox can block it - **instruct
  every agent not to commit or stage**; the human commits (see `create-oe-pr`). Reject
  any agent output that committed.
- **Workspace-only writes.** Docker mode mounts only the project dir (plus `~/.codex`);
  host mode confines writes to the agent's `cwd` tree. Don't point an agent at `~` or `/`.
- If a task genuinely needs network or wider access, that's a deliberate `install.sh -x`
  re-run to a looser sandbox - and only in a throwaway container/VM. Don't work around
  the sandbox by running `codex` from the shell yourself.

## If the reconnect still fails (advice to relay - the user runs these, not you)

- No codex auth present / not signed in (server reconnects but agent calls return auth/401 errors): `docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$HOME/.codex:/home/codex/.codex" claude-kit-codex login --device-auth` - device-code flow; needs "Allow device code login" enabled in ChatGPT security settings. (No extra `codex` word before `login` - the image ENTRYPOINT is already `codex`.)
- Image or registration missing: `cd ~/claude-kit && ./install.sh -x -p trusted -y` (builds `claude-kit-codex` if absent and re-registers the server)
- Anything else: restart Claude Code, touch the flag, reconnect in `/mcp` - or touch the flag before launching to have codex up from the start.

`codex mcp-server` is launched by Claude Code itself - only the `/mcp` reconnect (or a
restart) spawns it; you cannot start it out of band into this session. (Older Codex
builds used `codex mcp` to run the server; current builds use `codex mcp-server` and
reserve `codex mcp` for managing client entries - `install.sh` registers the current
form.)

## Config (what the agents inherit)

Set by `install.sh -x`, recorded non-secretly in `~/claude-kit/generated/.codex.env`:

- `CODEX_MODEL` - the model id agents run (default `gpt-5.6-sol`). GPT-5.6 family:
  `gpt-5.6-sol` (flagship - complex, ambiguous, or high-value work), `gpt-5.6-terra`
  (everyday workhorse), `gpt-5.6-luna` (fast/cheap repeatable tasks).
- `CODEX_REASONING_EFFORT` - default `xhigh` (the GPT-5.6 family accepts
  low/medium/high/xhigh/max/ultra).
- `CODEX_SANDBOX` - default `workspace-write` (network off); **host mode only** - in
  docker mode the container is the sandbox and this knob is ignored at launch.

To change any of these, edit `generated/.codex.env` and re-run `./install.sh -x -y`,
then restart Claude Code. The ChatGPT login itself lives in `~/.codex`, never in the kit.
