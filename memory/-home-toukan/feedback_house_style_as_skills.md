---
name: feedback-house-style-as-skills
description: "When capturing Manpreet's house style for a class of artifact (bash scripts, yiic commands, notes, etc), write a user-level skill in ~/claude-kit/skills/<name>/ (symlinked into ~/.claude/skills) — not a project CLAUDE.md, not a memory file."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 26d9fae1-fbc8-457f-8433-b7cd2e3ef36e
---

When Manpreet asks for a style guide / conventions file for a class of artifact (bash scripts, OpenEyes yiic commands, TKL knowledge-base notes, future categories), write it as a **user-level skill** with a clear `description:` trigger in the frontmatter — and it must **live in `~/claude-kit/skills/<kebab-name>/`** (his git-tracked kit, the source of truth; see [[c-claude-kit]] skill for conventions), with a symlink at `~/.claude/skills/<kebab-name>` pointing back to it, matching what `install.sh` produces. "I only want things to live in ~/claude-kit" (2026-07-03) — never create a real directory under `~/.claude/skills`; add the name to `~/.claude/.claude-kit-skills` so pruning stays correct.

**Why:**
- A skill is loaded on-demand by description match, so it's invisible during unrelated work and active when relevant.
- It's available across every project Manpreet works in, not scoped to one repo.
- He explicitly chose this approach over project CLAUDE.md ("CLAUDE.md always loads") and over memory files. Pattern is established by `bash-style`, `yiic-command-style`, and `note-style` skills.

**How to apply:**
- Folder: `~/claude-kit/skills/<kebab-name>/SKILL.md`, then `ln -s` it into `~/.claude/skills/` (one folder per skill).
- Frontmatter `description:` must clearly state the trigger conditions AND what to skip (e.g. "Trigger when writing .sh files; skip for one-line shell snippets").
- Body distils the conventions with copy-paste-able examples drawn from the canonical reference files Manpreet points at.
- Don't also leave a duplicate `CLAUDE.md` in the source folder — move to the skill and delete the local copy.
- Don't save the style rules themselves to memory; the skill is the durable record.
