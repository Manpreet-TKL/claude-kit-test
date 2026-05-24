# CLAUDE.md vs SKILL.md

Two parallel mechanisms inject knowledge into Claude Code. They look similar but behave differently.

## `CLAUDE.md` — always-on context

A `CLAUDE.md` in the project root (or `~/.claude/CLAUDE.md` globally) is **prepended to every prompt** in that scope. Use it for:

- Coding standards that apply to *every* file (e.g. the Karpathy guidelines this kit installs at `~/.claude/CLAUDE.md`).
- Domain rules that aren't safe to forget on any task.

Caveats:

- Cost: every token here is paid for on every turn.
- Drift: people stop reading large CLAUDE.md files. Keep it short.

## `SKILL.md` — invoked on demand

A skill lives at `~/.claude/skills/<name>/SKILL.md`. It has frontmatter:

```yaml
---
name: short-kebab-case-name
description: One-line summary used for skill selection. Be specific.
disable-model-invocation: true   # optional — see below
---
```

A SKILL.md is **only** loaded into context when:

1. The user explicitly invokes it (e.g. `/skill-name` or "use the X skill"), **or**
2. The model decides to load it based on the `description` (unless `disable-model-invocation: true`).

Use SKILL.md for:

- Project-specific knowledge that isn't needed on every turn.
- House styles you only want to apply when actually writing that kind of code (e.g. a bash style only when working on a shell script).
- Module / runbook / mental-model docs that are too long to keep in CLAUDE.md.

## When to set `disable-model-invocation: true`

The kit's `notes`, `oe_code`, `oe_components`, `oe_db_schema`, `oe_coding_standards`, `oe-deploy`, and `oeimagebuilder` skills all set this flag. Reason: they're large, repo-specific, and you don't want the model auto-pulling them in for unrelated tasks. The user (or an agent that knows the repo) invokes them explicitly.

The style skills (`bash-style`, `note-style`, `yiic-command-style`, `create-oe-module`) **don't** set the flag — they auto-load when relevant, because they're guard-rails you want applied whenever the model touches that kind of file.

## Sub-skills (`subs/`)

A SKILL.md can refer to companion files in a `subs/` directory next to it. Convention this kit uses:

- `SKILL.md` holds the **stable mental model** — architecture, naming conventions, invariants.
- `subs/*.md` holds the **volatile detail** — pinned versions, current rc-tied gotchas, module catalogues, environment-variable tables.

The model is expected to read the SKILL.md fully and then read whichever sub it needs. That keeps the always-pulled chunk small and lets you update the volatile bits without re-reviewing the whole skill.

## Skill names — house convention

- Hyphens for styling skills: `bash-style`, `note-style`, `yiic-command-style`, `create-oe-module`.
- Repo-specific skills mix conventions: underscored (`oe_code`, `oe_components`, `oe_db_schema`, `oe_coding_standards`), hyphenated (`oe-deploy`), and a compound coined name (`oeimagebuilder`). Skill names are case-/separator-sensitive — use the directory name exactly as it sits in `~/.claude/skills/`.
- Project skills group under one prefix so they sort together (`oe_*` here).

## Where the skills come from

Skill source-of-truth lives in this kit at `skills/<name>/`. The installer (`syncSkills`) symlinks each `skills/<name>/` into `~/.claude/skills/<name>/`, so editing in the kit reflects live without re-installing. If a destination `~/.claude/skills/<name>` already exists as a real directory (not a symlink), the installer skips it and warns — it won't clobber hand-edited skills.
