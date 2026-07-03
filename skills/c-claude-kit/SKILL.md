---
name: c-claude-kit
description: How ~/claude-kit works + skill-authoring rules
disable-model-invocation: true
---

# claude-kit

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself — it just loads knowledge; act only on instructions given in the conversation.

`~/claude-kit` is Manpreet's git-tracked, single-script setup for Claude Code — the **source of truth**; `~/.claude/` is generated from it. **As much as possible the kit links rather than copies** — `CLAUDE.md`, `statusline.sh`, and every skill live in `~/.claude/` as symlinks back into the kit, so editing a kit file is live with no re-install; only `settings.json` (jq-merged) needs an `install.sh` re-run. `install.sh` configures `~/.claude/` idempotently: re-runnable, backs up `settings.json`/`CLAUDE.md` to `.bak` only when content changes, rebuilds skill symlinks every run. It also **manages the CLI itself** — installs Claude Code if `~/.claude` is absent, otherwise runs `claude update` (skip with `--no-update`/`-U`). Auth, `history.jsonl`, and `projects/` are never touched, except by `--fresh`, which backs them up and restores them across a full wipe.

## Layout

- `install.sh` — the only entry point. Lifecycle flags: `-p ultra-safe|standard|trusted|yolo` (rule-set), `-m default|plan|acceptEdits|auto|dontAsk|bypassPermissions` (session start mode / `defaultMode`, independent of `-p`; omit → `auto` (`DEFAULT_MODE`); `auto` = classifier-judged), `-y`, `--reset` (`-r`), `--fresh` (`-F`), `--no-update` (`-U`); MCP flags: `--with/without-atlassian|github|codex`.
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

- **Auto-load** (no `disable-model-invocation`): Claude reads `name`+`description` at startup and pulls the body in *itself* when a task matches. The `description:` is the trigger. Currently only: `c-frontend-design`, `c-oe-helm`, `c-oe-ui`.
- **Manual** (`disable-model-invocation: true`): never auto-loaded; enters context only when invoked by name (`/c-oe-code`). Everything else in the kit.

Conventions for kit skills — apply these to every new skill:

- **`c-` prefix for context skills** — a context-loading (read-only knowledge) skill is named `c-<topic>`; action / workflow / preflight skills (`create-pr`, `create-oe-module`, `new-feature`, the MCP-preflight set) stay unprefixed.
- **Default to manual** — set `disable-model-invocation: true` so the model never auto-pulls a new skill on its own; omit the flag only for a deliberate auto-load (the named exceptions above).
- **One-line `description:`** — ≤ ~78 chars so it's fully readable when searching skills in Claude.
- **"Context loaded" ack + context-only contract** — a context-only (`c-*`) skill's body starts with *"When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself — it just loads knowledge; act only on instructions given in the conversation."* — the ack stops a summary dump, the contract stops unprompted action. Action skills (`create-*`, `new-feature`, `performance-indexes-rollup`) keep only the ack sentence — invoked with a task, they do act. The four MCP-preflight skills (`codexmcp`, `devopstickets`, `githubmcp`, `jiramcp`) are the deliberate exception — they actually run a check and report.
- **Keep it lean** — aim < ~2,000 tokens (≈ 8 KB) per `SKILL.md` so loading is cheap; push anything not always needed into `subs/*.md` and let the model open it on demand. `create-oe-module` and `c-oe-coding-standards` intentionally exceed this (reference-dense).

## Symlink pruning

`install.sh` records each skill it links in `~/.claude/.claude-kit-skills`. Every run: re-links current kit skills, then **removes** any `~/.claude/skills/<name>` *symlink* it had created but that is no longer in `skills/`. Safety floors — a **real directory** (your own skill) is skipped with a warning; a **symlink pointing outside this kit** is left alone. Only kit-created symlinks are ever removed.

## --reset vs --fresh

- `--reset` archives auto-generated bloat (`file-history`, `paste-cache`, `backups`, `shell-snapshots`, `stats-cache`, `session-env`, `plugins`, `tasks`) to `~/.claude-backups/<ts>/`, then installs over the top. Auth/history/projects stay in place.
- `--fresh` is nuke-and-pave: back up `projects/` + `history.jsonl` + `.credentials.json` to `~/.claude-backups/<ts>-fresh/`, **`rm -rf ~/.claude`**, fresh-install the CLI, restore those three, re-apply the kit. Everything else regenerates clean. Interactive runs require typing `fresh` to confirm (skipped by `-y`). Supersedes `--reset`.
