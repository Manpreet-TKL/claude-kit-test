---
name: claude-kit
description: What ~/claude-kit is and how install.sh builds ~/.claude
disable-model-invocation: true
---

# claude-kit

When loaded as context with no task, reply only `Context loaded.`

`~/claude-kit` is Manpreet's git-tracked, single-script setup for Claude Code — the **source of truth**; `~/.claude/` is generated from it. `install.sh` configures `~/.claude/` idempotently: re-runnable, backs up `settings.json`/`CLAUDE.md` to `.bak` only when content changes, rebuilds skill symlinks every run, bootstraps a from-scratch install when `~/.claude` is absent. Auth, `history.jsonl`, and `projects/` are never touched.

## Layout

- `install.sh` — the only entry point (`-p safe|standard|trusted|yolo`, `-y`, `--reset`, `--with/without-atlassian`).
- `claude-md/CLAUDE.md` — wholesale-copied to `~/.claude/CLAUDE.md`.
- `settings/permissions/<tier>.json` — the four permission tiers (deny → ask → allow).
- `settings/{shift-enter,mcp-atlassian}.json` — jq-merged settings fragments.
- `skills/<name>/` — each symlinked into `~/.claude/skills/<name>`.
- `docs/` — permissions, skills, statusline, sandbox, atlassian.

## What install.sh writes into ~/.claude

- `settings.json` — statusLine, autocompact env, permissions, shift-enter (jq-merged, never text-appended).
- `statusline.sh` — token-usage status bar (5h / weekly rolling windows).
- `CLAUDE.md` — global rules (never commit/push; condensed coding guidelines).
- `skills/*` — symlinks back to this kit, so editing a skill here is live — no re-install.

To change config: edit the file here and re-run `install.sh`. Skills are live symlinks — just edit. Real (non-symlink) skill dirs in `~/.claude/skills/` are left untouched.
