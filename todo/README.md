# todo

Queued work for Claude and the plans behind it. Nothing here loads
automatically - open `TODO.md` when asked what is queued, when told to pick an
item up, or when the current task touches a plan that lives here. Never start
a queued item unprompted.

## Contents

- `TODO.md` - the queue. One task per line, newest at the bottom:
  `- [ ] YYYY-MM-DD - <task> (plan: <file>)`. The date is when it was queued;
  the plan reference is optional. Status notes go on the same line in
  brackets. Remove the line when the task is done - git history is the
  archive, so no "done" section.
- `<slug>-plan.md` - a plan being developed or awaiting execution. Draft here,
  refine here (`c-grill-me`, `codex-grill`), execute from here. When the plan is
  finished, delete it and fold anything durable into `knowledge/` or the
  matching context skill; when it is dropped, just delete it.

## What does not belong here

- Learnings from finished work - `knowledge/`.
- Handoff snapshots of an in-flight conversation - `handoff/`.
- Anything secret or client-identifying. This folder is git-tracked in a public
  repo, same footing as the rest of the kit.
