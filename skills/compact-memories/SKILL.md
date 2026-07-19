---
name: compact-memories
description: Verify, merge, archive, and prune auto-memory; rewrite MEMORY.md.
disable-model-invocation: false
---

# Compact memories

When loaded as context with no task, reply only `Context loaded.`

Compact Claude's auto-memory in `~/claude-kit/memory/<project-slug>/` (the
git-tracked source of truth; `~/.claude/projects/<slug>/memory` symlinks to
it, so edits are live and every change is revertable).

## Procedure

1. Read MEMORY.md and every memory file for the slug being compacted.
2. Verify each fact is still true - check the file, flag, container, or repo
   it names. Delete memories that are wrong or superseded.
3. Merge tightly-related facts into one topic file each (e.g. several
   deploy-quirk memories about one stack). Keep the `description:` line sharp
   - recall keys off it - and keep `[[links]]` intact after renames.
4. Archive, do not carry: resolved incidents and finished projects move to
   `~/claude-kit/knowledge/<topic>.md`, trimmed to the durable lesson
   (pointers to runbook `.md` files survive as references). Delete the memory
   file afterwards.
5. Rewrite MEMORY.md - one line per surviving memory, matching the files
   exactly.
6. Report a move/merge/delete summary table, `git add` the kit changes, and
   stop - the human commits.

Rough target: halve the index once it has grown past ~30 lines, but never
drop a fact that is still load-bearing just to hit a number.
