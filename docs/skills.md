# CLAUDE.md vs SKILL.md

Two parallel mechanisms inject knowledge into Claude Code. They look similar but behave differently.

## `CLAUDE.md` - always-on context

A `CLAUDE.md` in the project root (or `~/.claude/CLAUDE.md` globally) is **prepended to every prompt** in that scope. Use it for:

- Coding standards that apply to *every* file (e.g. the Karpathy guidelines this kit installs at `~/.claude/CLAUDE.md`).
- Domain rules that aren't safe to forget on any task.

Caveats:

- Cost: every token here is paid for on every turn.
- Drift: people stop reading large CLAUDE.md files. Keep it short.

## `SKILL.md` - invoked on demand

A skill lives at `~/.claude/skills/<name>/SKILL.md`. It has frontmatter:

```yaml
---
name: short-kebab-case-name
description: One-line summary used for skill selection. Be specific.
disable-model-invocation: true   # optional - see below
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

**Setting this flag is the default for a new skill.** Most kit skills set it - they're large, repo-specific, or preflight checks you want to fire deliberately, so you don't want the model auto-pulling them in for unrelated tasks. The user (or an agent that knows the repo) invokes them by name.

Five skills **omit** the flag and therefore auto-load when their `description` matches the task: **`c-ascii`, `c-frontend-design`, `a-oe-docs`, `c-oe-helm`, `c-oe-ui`**. They're guard-rails / mental models you want applied whenever the model touches that kind of work. For an auto-load skill the `description:` *is* the trigger - write it to fire on the right task and nothing else.

## Two body conventions every kit skill follows

1. **"Context loaded" ack.** The body's first line is *"When loaded as context with no task, reply only `Context loaded.`"* So invoking a skill purely to prime context returns a one-word ack instead of a multi-hundred-token summary. The five preflight skills (`awsmcp`, `codexmcp`, `devopstickets`, `githubmcp`, `jiramcp`) are the deliberate exception - they actually run a check and report its result.
2. **One-line `description:`.** Keep it <= ~78 chars so the whole thing is readable on one terminal row when you search skills inside Claude.

Keep each `SKILL.md` **under ~2,000 tokens** (~ 8 KB) so loading is cheap; move volatile detail into `subs/*.md` (below). Two skills intentionally exceed this - `create-oe-module` and `c-oe-coding-standards` - because they're reference-dense.

## Sub-skills (`subs/`)

A SKILL.md can refer to companion files in a `subs/` directory next to it. Convention this kit uses:

- `SKILL.md` holds the **stable mental model** - architecture, naming conventions, invariants.
- `subs/*.md` holds the **volatile detail** - pinned versions, current rc-tied gotchas, module catalogues, environment-variable tables.

The model is expected to read the SKILL.md fully and then read whichever sub it needs. That keeps the always-pulled chunk small and lets you update the volatile bits without re-reviewing the whole skill.

## Skill names - house convention

- **Prefix user-authored skills by role.** Use `a-<topic>` for an action or workflow and `c-<topic>` for context-only knowledge. Imported and built-in skills keep their upstream names. Do not guess provenance or mass-rename existing skills without the user's classification.
- Skill names are case-/separator-sensitive - use the directory name exactly as it sits in `~/.claude/skills/` (e.g. `/c-oe-helm`).

## Agent availability and ordering

| Target | Inclusion rule |
|---|---|
| Claude | Included by default. `agents/claude.yaml` containing `enabled: false` opts out. |
| Codex | Included only when `agents/openai.yaml` exists. Its generated fields are refreshed from `SKILL.md`; a missing file is never created automatically. |

This makes a skill with no agent metadata Claude-only, a skill with `openai.yaml` available to both agents, and a skill with both `openai.yaml` and the Claude opt-out Codex-only. The Unix installers create links and manifests in C-locale skill-name order; the Windows installer copies skills in name order. This gives each client a deterministic alphabetical source order, although a client UI may apply its own display sort.

## Where the skills come from

Skill source-of-truth lives in this kit at `skills/<name>/`. The installer (`syncSkills`) symlinks each Claude-enabled `skills/<name>/` into `~/.claude/skills/<name>/`, so editing in the kit reflects live without re-installing. If a destination `~/.claude/skills/<name>` already exists as a real directory (not a symlink), the installer skips it and warns - it won't clobber hand-edited skills.

**Pruning removed or disabled skills.** `syncSkills` records every skill it links in `~/.claude/.claude-kit-skills`. On each run it re-links current eligible skills and then removes any managed `~/.claude/skills/<name>` **symlink** for a skill that no longer exists or is no longer enabled for Claude. Codex uses the same pruning when `agents/openai.yaml` is removed. It only ever removes symlinks: a real directory (your own skill) and a symlink pointing outside this kit are both left untouched.
