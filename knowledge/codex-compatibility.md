# Making claude-kit legible to OpenAI Codex

How the kit's instructions and skills are exposed to Codex agents (implemented
in `install.sh` `applyCodex` as of 2026-07; this file is the why and the
portable recipe).

## Global instructions: AGENTS.md

- Codex's analog of `~/.claude/CLAUDE.md` is `$CODEX_HOME/AGENTS.md` (default
  `~/.codex/AGENTS.md`), read at the start of every session.
- Precedence: `AGENTS.override.md` beats `AGENTS.md` at the same level; global
  is read first, then repo-root down to `cwd`, nearest last (most specific
  wins).
- The kit symlinks `~/.codex/AGENTS.md -> ~/claude-kit/claude-md/CLAUDE.md`,
  so both CLIs share one instructions file and kit edits are live for both.

## Skills

- Standalone Codex uses the official personal root, `~/.agents/skills`, with
  manifest `~/.agents/.claude-kit-skills`.
- The existing `install.sh -x` workflow keeps its MCP compatibility links in
  `~/.codex/skills` and remains independent of standalone setup.
- Symlinked skill directories are supported; a smoke test ("list your
  available skills") after rollout confirms in-container discovery.
- Explicit invocation from a Codex prompt: `$skill-name` (e.g. `$c-oe-code`).
- Per-skill Codex metadata lives in `agents/openai.yaml` beside `SKILL.md`. Its
  presence opts the skill into Codex; an absent file leaves the skill unlinked:

  ```yaml
  interface:
    display_name: "name"
    short_description: "one line"
  policy:
    allow_implicit_invocation: false
  ```

  `allow_implicit_invocation: false` is the analog of Claude's
  `disable-model-invocation: true`; install.sh updates existing metadata from
  each skill's frontmatter after any `-s` flip, so it never bakes a stale state
  or silently opts a Claude-only skill into Codex.

## Native subagents and concurrency

- Native Codex subagents do not require the Codex MCP server. Current Codex
  releases expose them directly.
- `[agents].max_concurrent_threads_per_session` is the supported numeric limit
  for concurrent open subagent threads. It excludes the primary agent. The
  older `agents.max_threads` name is a legacy alias.
- Configure the kit with
  `bash /home/toukan/claude-kit/codex-install.sh -t 50 -U -y`. The installer
  saves `CODEX_AGENT_THREADS=50` in `generated/.codex.env` and writes the
  native setting to `~/.codex/claude-kit.config.toml`.
- The setting is read when a Codex session starts. A running session keeps its
  existing limit, so restart after changing it.
- This is a concurrency limit, not a total-agent target. Large swarms can run
  in waves, and account or service limits can still cap effective concurrency.
  Shared browsers and mutable databases usually need narrower waves than
  independent code-reading tasks.

## Container reachability

- The registration mounts the kit at its **identical absolute path**,
  read-only: `-v "$HOME/claude-kit:$HOME/claude-kit:ro"`. Symlinks store the
  target path as text, so a link under `~/.codex` only resolves in-container
  when the target exists at the same path there - this mount is what makes
  the AGENTS.md and skills links work.
- Guard against a duplicate mount when the project dir IS the kit (docker
  errors on two mounts at one destination): skip the kit mount when
  `$PWD = $HOME/claude-kit`.

## Auth

- Container login (device-code flow, works headless; enable "Allow device
  code login" in ChatGPT security settings first): `docker run --rm -it --network host --user "$(id -u):$(id -g)" -v "$HOME/.codex:/home/codex/.codex" claude-kit-codex login --device-auth`
- The image ENTRYPOINT is already `codex` - no extra `codex` word before
  `login`. Drop `--device-auth` for the browser-callback flow on
  `localhost:1455`.

## What does NOT translate

Claude-side machinery with no Codex equivalent - do not try to port it:
permission tiers (`settings/permissions/*.json`; Codex has sandbox_mode +
approval_policy instead), the statusline, hooks/settings.json merging, and
auto-memory recall (`memory/` is Claude Code's; Codex only sees it as files).

## Copy-based alternative for other hosts

`npx skills add <owner>/<repo>` (skills.sh, from mattpocock/skills) installs
skill folders by copying into the agent's skills dir - no kit, no symlinks;
fine for a one-off machine, but copies drift, which is why this kit links.

## Sources

- https://learn.chatgpt.com/docs/agent-configuration/subagents
- https://learn.chatgpt.com/docs/config-file/config-reference
- https://developers.openai.com/codex/skills
- https://developers.openai.com/codex/agents-md
- https://github.com/openai/codex
- https://github.com/mattpocock/skills
