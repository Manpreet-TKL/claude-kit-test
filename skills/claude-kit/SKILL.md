---
name: claude-kit
description: Concise context for what ~/claude-kit is — Manpreet's single-script, git-tracked Claude Code setup. Load when the user mentions claude-kit / "the kit" / install.sh under ~/claude-kit, or asks how their ~/.claude (settings.json, statusline, permission tiers, global CLAUDE.md, skills) is configured or installed.
---

# claude-kit

`~/claude-kit` is Manpreet's git-tracked, single-script setup for Claude Code. It is the **source of truth**; `~/.claude/` is generated from it. Running `~/claude-kit/install.sh` configures `~/.claude/` idempotently — re-runnable, backs up `settings.json`/`CLAUDE.md` to `.bak` only when content changes, rebuilds skill symlinks every run, and bootstraps a from-scratch Claude install when `~/.claude` is absent. Auth, `history.jsonl`, and `projects/` are never touched.

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
- `skills/*` — symlinks back to this kit (so editing a skill here is live, no re-install).

To change config: edit the file here and re-run `install.sh`. Skills are live symlinks — just edit. Real (non-symlink) skill dirs in `~/.claude/skills/` are left untouched.
