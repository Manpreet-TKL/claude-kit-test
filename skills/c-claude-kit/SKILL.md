---
name: c-claude-kit
description: How ~/claude-kit works + skill-authoring rules
disable-model-invocation: false
---

# claude-kit

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

`~/claude-kit` is Manpreet's git-tracked, single-script setup for Claude Code - the **source of truth**; `~/.claude/` is generated from it. **As much as possible the kit links rather than copies** - `CLAUDE.md`, `statusline.sh`, and every skill live in `~/.claude/` as symlinks back into the kit, so editing a kit file is live with no re-install; only `settings.json` (jq-merged) needs an `install.sh` re-run. `install.sh` configures `~/.claude/` idempotently: re-runnable, backs up `settings.json`/`CLAUDE.md` to `.bak` only when content changes, rebuilds skill symlinks every run. It also **manages the CLI itself** - installs Claude Code if `~/.claude` is absent, otherwise runs `claude update` (skip with `--no-update`/`-U`). Auth, `history.jsonl`, and `projects/` are never touched, except by `--fresh`, which backs them up and restores them across a full wipe.

## Layout

- `install.sh` - the only entry point. Run with no flags it errors and prints the help; `-q` / `--quick` is the no-questions run (yolo tier unless `-p` given, implies `-y`). Lifecycle flags: `-p ultra-safe|standard|trusted|yolo` (rule-set), `-m default|plan|acceptEdits|auto|dontAsk|bypassPermissions` (session start mode / `defaultMode`, independent of `-p`; omit -> `auto` (`DEFAULT_MODE`); `auto` = classifier-judged), `-y`, `--reset` (`-r`), `--fresh` (`-F`), `--no-update` (`-U`); MCP flags: `--with/without-atlassian|github|codex` - every MCP server registers behind a **one-shot startup gate**: a new session starts NO MCP containers (each server shows "failed" in /mcp); to start one mid-session `touch ~/claude-kit/generated/mcp-on/<atlassian|github|codex>` and reconnect it in /mcp (tools bind on the late connect; the flag is consumed on start, so the next session is gated again). install.sh **pre-arms** the flag for every server it (re-)registers, so the first session after a `-x`/`-a`/`-g` run connects with no manual touch. `-x` also wires **codex compat**: `~/.codex/AGENTS.md` and `~/.codex/skills/<name>` symlink back into the kit (manifest `~/.codex/.claude-kit-skills`; `-X` unwires), and it registers the flagship defaults `gpt-5.6-sol` at `xhigh` - see `docs/codex.md` + `knowledge/codex-compatibility.md`; maintenance flags: `-s on|off` / `--skills-auto` (set `disable-model-invocation` across all kit skills - `on` makes every skill auto-invokable, `off` restores the exact prior per-skill state; flag-less always-auto skills are never touched; omitted -> `off`, so a plain run undoes a prior `-s on`), `-d <days|date>` / `--prune-sessions` (archive-then-delete conversations last active before the cutoff - transcript + sidecar + `session-env`/`file-history`/`tasks` move to `~/.claude-backups/<ts>-pruned/`, dropping them from `claude --resume`), `-l codex|github|atlassian|all` / `--logout` (STANDALONE: clear the MCP's stored credentials - for github/atlassian also the token-embedding `~/.claude.json` registration - then exit without running anything else; always-allowed on every permission tier for exactly that reason).
- `claude-md/CLAUDE.md` - symlinked into `~/.claude/CLAUDE.md` (editing it is live).
- `settings/permissions/<tier>.json` - the four permission tiers (deny -> ask -> allow).
- `settings/{shift-enter,mcp-atlassian}.json` - jq-merged settings fragments.
- `skills/<name>/` - each symlinked into `~/.claude/skills/<name>`.
- `memory/<project-slug>/` - Claude's auto-memory, adopted from `~/.claude/projects/<slug>/memory/` and symlinked back (git-tracked = versioned backup; edits live). Maintained with the `compact-memories` skill (verify, merge, archive, rewrite MEMORY.md).
- `scripts/` - host helpers; notably `screen5_install.sh` (GNU screen 5 from source + the claude-in-screen alias, via managed blocks in `~/.screenrc`/`~/.bash_aliases`). install.sh's `screenHint` probes both and points at it when a piece is missing.
- `knowledge/` - learnings from previous projects, read on demand when a topic comes up; fed by `compact-memories` archiving resolved work.
- `handoff/` - handoff documents written by the `c-handoff` skill; contents gitignored (transient, may carry residual sensitive context); never read unless asked.
- `docker/codex/` - Dockerfile for the locally-built `claude-kit-codex` image; `-x` builds it and runs the codex MCP server containerised (host `codex` binary only used when Docker is absent).
- `docs/` - permissions, skills, statusline, sandbox, atlassian, github, codex.

## What install.sh writes into ~/.claude

- `settings.json` - statusLine (with `refreshInterval` 5s so the bar stays fresh through long turns; `STATUSLINE_REFRESH=<n|0>` to tune/disable), autocompact env, permissions, shift-enter, `cleanupPeriodDays` (Claude Code's transcript retention; kit default 365 days vs the built-in 30, override with `CLEANUP_PERIOD_DAYS=<n>`) - all jq-merged, never text-appended.
- `statusline.sh` - token-usage status bar (5h / weekly rolling windows); symlinked from the kit.
- `CLAUDE.md` - global rules (never commit/push; condensed coding guidelines); symlinked from the kit.
- `skills/*` - symlinks back to this kit, so editing a skill here is live - no re-install.
- `.claude-kit-skills` - manifest of skill names this script symlinked, used to prune links for skills later removed from the kit.
- With `-x`, also outside `~/.claude`: the `~/.codex` compat links above, plus - in the kit itself - `skills/<name>/agents/openai.yaml`, generated **every run** from each SKILL.md's frontmatter after any `-s` flip (Codex display name/description; `allow_implicit_invocation: false` mirrors `disable-model-invocation: true`). Re-run install.sh to regenerate; don't hand-edit them.

To change config: `settings.json` is jq-merged, so edit the kit file and re-run `install.sh` to roll it out. `CLAUDE.md`, `statusline.sh`, and skills are live symlinks - just edit the kit file, no re-run needed.

## Skill loading model

Two ways a skill's `SKILL.md` reaches Claude's context:

- **Auto-load** (no `disable-model-invocation`): Claude reads `name`+`description` at startup and pulls the body in *itself* when a task matches. The `description:` is the trigger. Currently only: `c-ascii`, `c-frontend-design`, `c-oe-docs`, `c-oe-helm`, `c-oe-ui`. (`install.sh -s on|off` flips everything else to auto and back - see Layout.)
- **Manual** (`disable-model-invocation: true`): never auto-loaded; enters context only when invoked by name (`/c-oe-code`). Everything else in the kit.

Conventions for kit skills - apply these to every new skill:

- **`c-` prefix for context skills** - a context-loading (read-only knowledge) skill is named `c-<topic>`; action / workflow / preflight skills (`create-pr`, `create-oe-module`, `new-feature`, the MCP-preflight set) stay unprefixed. User-chosen exceptions: `c-handoff` and `c-grill-me` are action skills that keep the `c-` name.
- **Default to manual** - set `disable-model-invocation: true` so the model never auto-pulls a new skill on its own; omit the flag only for a deliberate auto-load (the named exceptions above).
- **One-line `description:`** - <= ~78 chars so it's fully readable when searching skills in Claude.
- **"Context loaded" ack + context-only contract** - a context-only (`c-*`) skill's body starts with *"When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation."* - the ack stops a summary dump, the contract stops unprompted action. Action skills (`create-*`, `new-feature`, `performance-indexes-rollup`) keep only the ack sentence - invoked with a task, they do act. `devopstickets` is a full action skill (a triage workflow); the three MCP skills (`codexmcp`, `githubmcp`, `jiramcp`) are context-plus-one-action - they load how their MCP works and, if the `mcp__<name>__*` tools are absent, touch the startup-gate flag (`~/claude-kit/generated/mcp-on/<name>`) and advise the user to reconnect the server in /mcp; beyond that touch they run nothing. Built on codexmcp's preflight: `codex-grill` (adversarial plan review on `gpt-5.6-sol` at `xhigh`) and `codex-swarm` (split a task into 40+ `luna`/`terra` agents) - both confirm the billable cost before spawning. `c-handoff` writes a handoff doc into `handoff/`; `c-grill-me` runs a one-question-at-a-time requirements interview; `compact-memories` maintains `memory/` (verify, merge, archive to `knowledge/`, rewrite MEMORY.md).
- **Keep it lean** - aim < ~2,000 tokens (~ 8 KB) per `SKILL.md` so loading is cheap; push anything not always needed into `subs/*.md` and let the model open it on demand. `create-oe-module` and `c-oe-coding-standards` intentionally exceed this (reference-dense).

## Symlink pruning

`install.sh` records each skill it links in `~/.claude/.claude-kit-skills`. Every run: re-links current kit skills, then **removes** any `~/.claude/skills/<name>` *symlink* it had created but that is no longer in `skills/`. Safety floors - a **real directory** (your own skill) is skipped with a warning; a **symlink pointing outside this kit** is left alone. Only kit-created symlinks are ever removed.

## --reset vs --fresh

- `--reset` archives auto-generated bloat (`file-history`, `paste-cache`, `backups`, `shell-snapshots`, `stats-cache`, `session-env`, `plugins`, `tasks`) to `~/.claude-backups/<ts>/`, then installs over the top. Auth/history/projects stay in place.
- `--fresh` is nuke-and-pave: back up `projects/` + `history.jsonl` + `.credentials.json` to `~/.claude-backups/<ts>-fresh/`, **`rm -rf ~/.claude`**, fresh-install the CLI, restore those three, re-apply the kit. Everything else regenerates clean. Interactive runs require typing `fresh` to confirm (skipped by `-y`). Supersedes `--reset`.
