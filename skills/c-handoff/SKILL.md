---
name: c-handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
disable-model-invocation: false
---

# Handoff document

When loaded as context with no task, reply only `Context loaded.`

Write a handoff document summarising the current conversation so a fresh agent
- with none of this context - can continue the work.

## Where

Always `~/claude-kit/handoff/`, as Markdown. List the folder first and pick a
unique name: `<yyyy-mm-dd>-<topic-slug>.md`, suffixing `-2`, `-3`, ... if the
name is taken. Never overwrite an existing handoff.

## What goes in

Be very certain to include everything the new agent needs to start work:

- Goal and current status - done, in flight, not started.
- Decisions made and why, including options rejected.
- Constraints and gotchas discovered - traps, footguns, ordering requirements.
- Exact paths, hosts, branches, container names, URLs - nothing vague.
- Ordered next steps, each with its verify check.
- Open questions only the user can answer.
- **Suggested skills** - kit skills the next agent should invoke (`/name`),
  one line each on why.

## Rules

- Do not duplicate content already captured in other artifacts (specs, plans,
  ADRs, issues, commits, diffs) - reference them by path or URL instead.
- Redact sensitive information - API keys, passwords, tokens, PII - writing
  `<redacted:what-it-was>` in its place.
- Plain ASCII, professional tone; the reader is another agent, not the user.
