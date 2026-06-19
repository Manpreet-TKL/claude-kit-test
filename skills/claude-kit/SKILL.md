---
name: claude-kit
description: How ~/claude-kit works and the rules for authoring its skills
---

# claude-kit

When loaded as context with no task, reply only `Context loaded.`

`~/claude-kit` is Manpreet's git-tracked, single-script setup for Claude Code — the **source of truth**; `~/.claude/` is generated from it. `install.sh` configures `~/.claude/` idempotently: re-runnable, backs up `settings.json`/`CLAUDE.md` to `.bak` only when content changes, rebuilds skill symlinks every run. It also **manages the CLI itself** — installs Claude Code if `~/.claude` is absent, otherwise runs `claude update` (skip with `--no-update`/`-U`). Auth, `history.jsonl`, and `projects/` are never touched, except by `--fresh`, which backs them up and restores them across a full wipe.

## Layout

- `install.sh` — the only entry point. Lifecycle flags: `-p safe|standard|trusted|yolo`, `-y`, `--reset` (`-r`), `--fresh` (`-F`), `--no-update` (`-U`); MCP flags: `--with/without-atlassian|github|codex`.
- `claude-md/CLAUDE.md` — symlinked into `~/.claude/CLAUDE.md` (editing it is live).
- `settings/permissions/<tier>.json` — the four permission tiers (deny → ask → allow).
- `settings/{shift-enter,mcp-atlassian}.json` — jq-merged settings fragments.
- `skills/<name>/` — each symlinked into `~/.claude/skills/<name>`.
- `docs/` — permissions, skills, statusline, sandbox, atlassian, github, codex.

## What install.sh writes into ~/.claude

- `settings.json` — statusLine, autocompact env, permissions, shift-enter (jq-merged, never text-appended).
- `statusline.sh` — token-usage status bar (5h / weekly rolling windows); symlinked from the kit.
- `CLAUDE.md` — global rules (never commit/push; condensed coding guidelines); symlinked from the kit.
- `skills/*` — symlinks back to this kit, so editing a skill here is live — no re-install.
- `.claude-kit-skills` — manifest of skill names this script symlinked, used to prune links for skills later removed from the kit.

To change config: `settings.json` is jq-merged, so edit the kit file and re-run `install.sh` to roll it out. `CLAUDE.md`, `statusline.sh`, and skills are live symlinks — just edit the kit file, no re-run needed.

## Skill loading model

Two ways a skill's `SKILL.md` reaches Claude's context:

- **Auto-load** (no `disable-model-invocation`): Claude reads `name`+`description` at startup and pulls the body in *itself* when a task matches. The `description:` is the trigger. Currently: `claude-kit`, `create-oe-module`, `note-style`, `oe-helm`, `oe-ui`. (`claude-kit` is a deliberate auto-load so the authoring rules below surface whenever you work on the kit.)
- **Manual** (`disable-model-invocation: true`): never auto-loaded; enters context only when invoked by name (`/oe-code`). Everything else in the kit.

Conventions for kit skills — apply these to every new skill:

- **Default to manual** — set `disable-model-invocation: true` so the model never auto-pulls a new skill on its own; omit the flag only for a deliberate auto-load (the named exceptions above).
- **One-line `description:`** — ≤ ~78 chars so it's fully readable when searching skills in Claude.
- **"Context loaded" ack** — a context-only skill's body starts with *"When loaded as context with no task, reply only `Context loaded.`"* so priming context doesn't dump a summary. The four MCP-preflight skills (`codexmcp`, `devopstickets`, `githubmcp`, `jiramcp`) are the deliberate exception — they actually run a check and report.
- **Keep it lean** — aim < ~2,000 tokens (≈ 8 KB) per `SKILL.md` so loading is cheap; push anything not always needed into `subs/*.md` and let the model open it on demand. `create-oe-module` and `oe-coding-standards` intentionally exceed this (reference-dense).

## Symlink pruning

`install.sh` records each skill it links in `~/.claude/.claude-kit-skills`. Every run: re-links current kit skills, then **removes** any `~/.claude/skills/<name>` *symlink* it had created but that is no longer in `skills/`. Safety floors — a **real directory** (your own skill) is skipped with a warning; a **symlink pointing outside this kit** is left alone. Only kit-created symlinks are ever removed.

## --reset vs --fresh

- `--reset` archives auto-generated bloat (`file-history`, `paste-cache`, `backups`, `shell-snapshots`, `stats-cache`, `session-env`, `plugins`, `tasks`) to `~/.claude-backups/<ts>/`, then installs over the top. Auth/history/projects stay in place.
- `--fresh` is nuke-and-pave: back up `projects/` + `history.jsonl` + `.credentials.json` to `~/.claude-backups/<ts>-fresh/`, **`rm -rf ~/.claude`**, fresh-install the CLI, restore those three, re-apply the kit. Everything else regenerates clean. Interactive runs require typing `fresh` to confirm (skipped by `-y`). Supersedes `--reset`.
