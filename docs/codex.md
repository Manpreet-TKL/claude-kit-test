# OpenAI Codex agents via `codex mcp-server`

This kit can wire Claude Code into **OpenAI Codex** so Claude can hand a coding task -
or many in parallel - to autonomous Codex agents. Like the Atlassian and GitHub
integrations, Codex runs **in a Docker container**: OpenAI ships no official CLI image,
so `install.sh -x` builds one locally (`claude-kit-codex`, from `docker/codex/Dockerfile`)
and registers `codex mcp-server` inside it over MCP's stdio transport. **Nothing is
installed on the host** - a host `codex` binary is used only as the fallback when Docker
itself is absent.

The server exposes two tools, surfaced in Claude Code as `mcp__codex__codex` (start an
agent on a task) and `mcp__codex__codex-reply` (continue one). Claude fans agents out by
calling `codex` several times in one message. Drive it through the **`codexmcp`** skill -
run `/codexmcp` before delegating, and follow its rules.

## What you get

Once configured, Claude can:

- spawn a single Codex agent on a self-contained task, or **several at once** (one per
  module / file / failing test) that run concurrently;
- continue any agent's thread with `codex-reply` (feed back test output, ask for a fix);
- have each agent run at the **flagship model (`gpt-5.6-sol`) + `xhigh` reasoning
  effort**, sandboxed (`approval_policy=never`, so unattended). In docker mode the
  **container is the sandbox** - only the project dir, `~/.codex`, and the kit
  (read-only) are mounted, and it carries no git credentials; in host-fallback mode
  it's codex's own **workspace-write, network-off** sandbox.

Agent output is a **proposal**: Claude reads the diffs, runs the build/tests, and keeps
only what verifies. You still own the commit - the human commits and pushes.

## Prerequisites

1. **Docker.** The CLI lives in the locally-built `claude-kit-codex` image
   (`node:22-slim` + `npm install -g @openai/codex` + git/ripgrep); `install.sh -x`
   builds it on first run and reuses it afterwards. Refresh to a newer Codex CLI with:

   ```bash
   docker build --no-cache -t claude-kit-codex ~/claude-kit/docker/codex/
   ```

   If Docker is missing but a host `codex` binary exists, install.sh falls back to it;
   with neither present it stops and asks for Docker - it never installs anything on
   the host.

2. **A ChatGPT sign-in.** This kit registers Codex to authenticate with your ChatGPT
   plan (Plus / Pro / Team / Enterprise), not an API key - so **no token is stored in
   the kit**. Sign in once through the container (auth lands in `~/.codex` on the host,
   which every agent container mounts). When it finds no sign-in, `install.sh -x`
   prints this command itself and **waits** for the credentials to land - run it in
   another terminal and the install continues on its own (Enter skips the wait):

   ```bash
   docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$HOME/.codex:/home/codex/.codex" claude-kit-codex login --device-auth
   ls ~/.codex/auth.json             # verify
   ```

   `--device-auth` is the device-code flow: it prints a code to enter on the ChatGPT
   device page from any browser, so it works on headless hosts - but "Allow device
   code login" must be enabled in your ChatGPT security settings first. Drop the flag
   for the browser-callback flow instead (`--network host` lets the browser reach the
   callback on `localhost:1455`). The image ENTRYPOINT is already `codex`, so the
   command ends `claude-kit-codex login --device-auth` - no extra `codex` word.

   ChatGPT-plan auth is subject to your plan's rate limits, which can throttle a wide
   fan-out. If you'd rather bill per-token via an API key (recommended by OpenAI for
   heavy programmatic use), set `OPENAI_API_KEY` in the environment and re-run - Codex
   falls back to it when no ChatGPT session is present.

## Setup

```bash
cd ~/claude-kit
./install.sh -x -p standard
```

Interactively, install.sh prompts for the **non-secret** knobs (defaults shown; the
sandbox knob only in host-fallback mode), saves them to `generated/.codex.env`
(mode 600), then registers the server at **user scope** via
`claude mcp add-json codex ... -s user` (stored in `~/.claude.json`, not
`settings.json`). The knobs become `-c key=value` launch overrides, so every spawned
agent inherits them:

| Knob | Default | Becomes |
|---|---|---|
| `CODEX_MODEL` | `gpt-5.6-sol` (flagship) | `-c model="..."` |
| `CODEX_REASONING_EFFORT` | `xhigh` | `-c model_reasoning_effort="..."` |
| `CODEX_SANDBOX` | `workspace-write` | host mode only: `-c sandbox_mode="..."` (+ `network_access=false`) |

In docker mode the sandbox knob isn't prompted for and is ignored at launch: codex's
own bwrap sandbox cannot start inside a container (user-namespace/loopback `EPERM`,
even `--privileged`), so the registration pins `sandbox_mode="danger-full-access"`
**inside** the container and the container provides the isolation instead - the MCP
server runs as your uid with three bind mounts: `~/.codex` (auth, plus the global
`AGENTS.md` and skills links), the project dir Claude Code was started in (also the
workdir), and `~/claude-kit` **read-only** so those kit symlinks resolve in-container
(the kit mount is skipped when the project dir IS the kit); everything else dies with
the `--rm` container. `approval_policy=never` is always set so agents don't block on
prompts. Restart Claude Code to pick up the server, then run `/codexmcp` to verify.

## Lazy start (the gate)

The registration is wrapped in a **one-shot startup gate**: a new Claude Code session
does **not** start the codex container - the server shows `failed` in `/mcp` until you
request it. To start it mid-session, run `touch ~/claude-kit/generated/mcp-on/codex`
and reconnect the server in `/mcp`; the `mcp__codex` tools bind on the late connect.
The flag is consumed on start, so every session begins gated - touch it just before
launching Claude Code to have codex up from the start. Gated-off sessions exit before
the container-reuse step, so they never kill a codex container another session enabled.

`install.sh` **pre-arms** the flag for every server it (re-)registers, so right after
an `-x` run codex connects on the next session start - or immediately via `/mcp` ->
codex -> reconnect - without the manual touch. That first start consumes the flag;
sessions after it begin gated as usual. (A `failed` entry in `/mcp` on later sessions
is therefore the gate working, not a broken registration - the `-32000 Connection
closed` line in the MCP log is the gate wrapper exiting.)

## Changing the model or sandbox

Edit `generated/.codex.env` and re-apply silently:

```bash
./install.sh -x -p standard -y    # re-reads the knobs, re-registers
```

- **Model.** The GPT-5.6 family as of mid-2026: `gpt-5.6-sol` (flagship - complex,
  ambiguous, or high-value work), `gpt-5.6-terra` (everyday workhorse),
  `gpt-5.6-luna` (fast/cheap repeatable tasks). Point `CODEX_MODEL` at whatever is
  current - update it when OpenAI ships the next one.
- **Reasoning effort.** `xhigh` is the default; the family accepts
  low/medium/high/xhigh/max/ultra.
- **Sandbox.** Host mode only: keep `workspace-write` (network off) so agents can't
  `git push`. Docker mode ignores this knob - the container is the sandbox.

The registration values are only **defaults**: the `codex` MCP tool accepts `model`
and `config` (e.g. `{"model_reasoning_effort": "low"}`) per call, so a single agent
can run on a different tier without re-registering - the `codex-grill` (sol at xhigh)
and `codex-swarm` (luna/terra) skills pick their tiers exactly this way.

## Why the sandbox, and never-commit

A Codex agent runs commands in **its own sandbox** - the kit's `permissions.deny` list
and the never-`git push`/never-`git commit` floor in `~/.claude/CLAUDE.md` do **not**
gate it, because that shell isn't Claude's `Bash` tool. The registration enforces the
equivalent another way:

- **No push.** Docker mode: the container holds **no git credentials** - no `~/.ssh`,
  no `.gitconfig`, no credential helpers - so a push fails auth even though the
  container has network for the OpenAI API. Host mode: `workspace-write` +
  `sandbox_workspace_write.network_access=false` means an agent cannot reach the
  network at all. Either way, the sandbox analogue of the never-push hard floor.
- **`git commit` is local**, so no sandbox can block it. The `codexmcp` skill
  therefore instructs every agent **not to commit or stage**, and to reject output that
  did. The human commits (see the `create-oe-pr` skill).
- **Confined writes.** Docker mode: only the project dir, `~/.codex`, and the kit
  (read-only) are mounted - nothing else on the host is reachable, and the container
  fs is discarded on exit. Host mode: writes are confined to the agent's `cwd` tree.
  Point agents at the repo, never at `~` or `/`.

This is also why `mcp__codex` is allowed on the `standard`/`trusted`/`yolo` tiers but
**not on `ultra-safe`**: spawning an autonomous writer is a write action, and the
read-mostly `ultra-safe` tier prompts before it. On `ultra-safe` you'll get a permission
prompt the first time.

## Codex compatibility (AGENTS.md + skills)

`-x` also makes the kit legible to Codex itself: `~/.codex/AGENTS.md` is symlinked to
`claude-md/CLAUDE.md` (Codex's global-instructions file), every kit skill is symlinked
into `~/.codex/skills/` (manifest-pruned exactly like the Claude ones), and each kit
skill carries a generated `agents/openai.yaml` (display name, description, and
`allow_implicit_invocation: false` mirroring `disable-model-invocation: true`). Codex
agents invoke a skill explicitly with `$skill-name`. The read-only kit mount is what
lets those symlinks resolve inside the container. Full recipe and rationale:
`knowledge/codex-compatibility.md`.

## Teardown

```bash
./install.sh --without-codex -p standard -y      # -X
```

Deregisters the server (`claude mcp remove codex -s user`), disarms the gate flag,
removes the `~/.codex/AGENTS.md` link (only when it points into this kit), and prunes
the kit's codex skill links via their manifest. `generated/.codex.env`,
your `~/.codex` login, and the `claude-kit-codex` image are deliberately left in
place, so a later `-x` re-run needs no rebuild and no fresh sign-in. To clear those
out too:

```bash
./install.sh -l codex         # log out (removes ~/.codex/auth.json; allowed on every tier)
docker rmi claude-kit-codex   # delete the image
```

The logout is local-only - to revoke the session server-side, remove Codex from your
ChatGPT account's authorized apps. `-l codex` leaves the registration in place, so a
fresh container `login` brings the tools straight back without a re-run.

## The config file

`generated/.codex.env` is plain shell and **holds no secret** (auth is in `~/.codex`):

```bash
CODEX_MODEL=gpt-5.6-sol
CODEX_REASONING_EFFORT=xhigh
CODEX_SANDBOX=workspace-write
```

It lives in the kit's single `generated/` folder (gitignored wholesale) alongside the
Atlassian/GitHub creds, so one backup of that folder survives a `git reset --hard`.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `docker not found` | Install Docker (preferred), or put a host `codex` binary on PATH for the fallback. |
| `docker build` fails during `-x` | No network to npm, or a proxy - retry; the build only runs when the image is absent. |
| `claude mcp login codex` -> "doesn't support OAuth login" | Expected - that command is for HTTP/SSE remote servers (e.g. Atlassian). Codex is a **stdio** server; sign in with the container `login` command (see Prerequisites). |
| MCP server shows `failed` in `/mcp` | Gated off (the default at every session start) - `touch ~/claude-kit/generated/mcp-on/codex` and reconnect it in `/mcp`. If it fails again after that: not signed in - run the container `login` command (see Prerequisites). |
| Agent calls return an auth/401 error | ChatGPT session expired - run the container `login` command again. |
| "rate limit" / throttling on a wide fan-out | ChatGPT-plan limits - narrow the fan-out, or switch to `OPENAI_API_KEY`. |
| An agent can't see a file outside the repo | Expected - docker mode mounts only the project dir Claude Code started in. |
| An agent couldn't `git push` | Expected - no credentials in the container (docker) / network off (host mode). |
| Agent runs need a toolchain the image lacks (php, composer, ...) | Extend `docker/codex/Dockerfile`, rebuild with `--no-cache`, or let Claude run the build/tests itself on the host after the agent edits. |
| Sandbox errors in **host** mode | codex's bwrap sandbox needs user namespaces - check `sysctl kernel.unprivileged_userns_clone` / AppArmor userns restrictions. |
| Old registration still runs the host binary | Re-run `./install.sh -x -p <tier> -y` - it re-registers, docker-first. |
| Tools missing after setup | Restart Claude Code - MCP servers bind at startup. |
| Permission prompt on every spawn | You're on the `ultra-safe` tier (by design). Use `standard`+ or approve the prompt. |
