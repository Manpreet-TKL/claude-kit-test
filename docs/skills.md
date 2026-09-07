# Global instructions vs SKILL.md

Claude Code and Codex both receive global instructions and on-demand skills.
The filenames and explicit invocation syntax differ, but the kit keeps one
shared skill source.

## `CLAUDE.md` - always-on context

A `CLAUDE.md` in the project root (or `~/.claude/CLAUDE.md` globally) is **prepended to every prompt** in that scope. Use it for:

- Coding standards that apply to *every* file (e.g. the Karpathy guidelines this kit installs at `~/.claude/CLAUDE.md`).
- Domain rules that aren't safe to forget on any task.

Caveats:

- Cost: every token here is paid for on every turn.
- Drift: people stop reading large CLAUDE.md files. Keep it short.

## `SKILL.md` - invoked on demand

A source skill lives at `skills/<name>/SKILL.md` and is linked into each
eligible client's skill root. It has frontmatter:

```yaml
---
name: short-kebab-case-name
description: One-line summary used for skill selection. Be specific.
disable-model-invocation: true   # optional - see below
---
```

A SKILL.md is **only** loaded into context when:

1. The user explicitly invokes it (`/skill-name` in Claude Code,
   `$skill-name` in Codex, or "use the X skill"), **or**
2. The model decides to load it based on the `description` (unless `disable-model-invocation: true`).

Use SKILL.md for:

- Project-specific knowledge that isn't needed on every turn.
- House styles you only want to apply when actually writing that kind of code (e.g. a bash style only when working on a shell script).
- Module / runbook / mental-model docs that are too long to keep in CLAUDE.md.

## Invocation states

Every new skill states `disable-model-invocation` explicitly. Use `false` when
the agent may select it from its description and `true` when only an explicit
invocation should load it. The committed kit currently uses `false` for every
flagged skill. The `-s on|off` installer switch snapshots and changes these
values without touching the five deliberate exceptions.

Five skills **omit** the flag and therefore auto-load when their `description` matches the task: **`c-ascii`, `c-frontend-design`, `a-oe-docs`, `c-oe-helm`, `c-oe-ui`**. They're guard-rails / mental models you want applied whenever the model touches that kind of work. For an auto-load skill the `description:` *is* the trigger - write it to fire on the right task and nothing else.

For Codex, `agents/openai.yaml` mirrors `true` as
`policy.allow_implicit_invocation: false`. The installers generate that policy
from the shared frontmatter so the two clients do not drift.

## Two body conventions every kit skill follows

1. **"Context loaded" ack.** The body's first line is *"When loaded as context with no task, reply only `Context loaded.`"* So invoking a skill purely to prime context returns a one-word ack instead of a multi-hundred-token summary. The workflow/preflight exceptions (`awscli`, `codexmcp`, `devopstickets`, `githubmcp`, `jiramcp`) actually run a check or workflow and report its result.
2. **One-line `description:`.** Keep it <= ~78 chars so the whole thing is readable on one terminal row when you search skills in either client.

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

Current deliberate client-specific skills:

- `codexmcp` and `oe-probe-chrome` are Claude-only.
- `oe-probe-codex-chrome` is Codex-only.
- `codex-swarm`, `codex-grill`, `oe-probe-playwright`, `githubmcp` and
  `jiramcp` select a compatible transport at runtime and are shared.

## Validation

Normal installer verification runs
`bash /home/toukan/claude-kit/scripts/validate-skills.sh`. It checks the shared
frontmatter schema, invocation-policy synchronization, availability metadata,
and Codex-incompatible tool or model names in every Codex-enabled skill.
`codex-install.sh` adds `-c|--codex-runtime`, which calls `codex app-server` and
requires its installed `skills/list` response to contain the expected kit
skills with no errors. This parser check starts no model turn. The existing
installer `-n|--no-verify` flag skips both checks.
The kit does not use the bundled `quick_validate.py` as its install gate because
that validator rejects the Claude-compatible frontmatter extensions retained
here. The shared validator checks that combined contract, and the Codex runtime
check remains authoritative for Codex discovery.

## Where the skills come from

Skill source-of-truth lives in this kit at `skills/<name>/`. The installer (`syncSkills`) symlinks each Claude-enabled `skills/<name>/` into `~/.claude/skills/<name>/`, so editing in the kit reflects live without re-installing. If a destination `~/.claude/skills/<name>` already exists as a real directory (not a symlink), the installer skips it and warns - it won't clobber hand-edited skills.

**Pruning removed or disabled skills.** `syncSkills` records every skill it links in `~/.claude/.claude-kit-skills`. On each run it re-links current eligible skills and then removes any managed `~/.claude/skills/<name>` **symlink** for a skill that no longer exists or is no longer enabled for Claude. Codex uses the same pruning when `agents/openai.yaml` is removed. It only ever removes symlinks: a real directory (your own skill) and a symlink pointing outside this kit are both left untouched.
