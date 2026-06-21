---
name: create-pr
description: Package a non-OE change as a review-ready PR folder
disable-model-invocation: true
---

# Create-PR playbook

When loaded as context with no task, reply only `Context loaded.`

Instructions only — it does not scan the tree, run `git status`, or diff to discover what changed; the caller supplies the change, the skill packages it. The title becomes the PR headline and the writeup is read by reviewers with no context for the original request. **Never `git commit` / `git push` / `--no-verify`** — the human raises the PR. **The full PR.md template, Jira-type table, field rules, raise commands, and gotchas are in `subs/reference.md` — read it before writing the folder.**

## The deliverable: one folder, always

Always under `~/pullrequests/` — `~/pullrequests/<repo>-pr-<slug>/` (ticket ref in the slug if there is one, e.g. `notes-pr-ENG-1421-archive-race/`):

- `PR.md` — a **form**, not prose. Top labels in order: Jira ticket title / Jira ticket type / Affects version / Fix version / Commit title(s) / GitHub PR description. The description is `##` sections (Description, Solution, Files changed, Test, Notes for reviewer); headings stay OUT of the blockquotes, each body is one `> `-quoted block. **No Steps to Reproduce / Current Outcome / Expected Outcome** — fold the user-visible symptom into Description.
- `<repo>/` — a **full git clone of the repo**, cloned from its `origin` (so push targets the real remote), checked out on a new branch `<branch>` off the base, with every change applied in the working tree and **left uncommitted** — the human commits and pushes. The clone *is* the change: **no `files/`, no `patches/`.** Mark new files `(new)` in the Files changed list. See `subs/reference.md` → *Building the clone*.

## The shared index: `~/pullrequests.md`

After writing the folder, append **exactly one line** to `~/pullrequests.md` (create it if absent) — a markdown link to the PR folder plus an em-dash, single-line summary (reuse the Jira ticket title). One line per PR, newest at the bottom; never touch existing lines. This file is a shareable register of every PR raised, shared with `create-oe-pr`.

```
- [<repo>-pr-<slug>](pullrequests/<repo>-pr-<slug>/) — <single-line explanation of the PR>
```

## Field judgements

- **Type, exactly one** of Bug / New Feature / Improvement / Internal Improvement / Story / Epic / Regression. Worked before and broke later → **Regression**; never-correct → Bug. Improvement vs Internal turns on user-visibility.
- **Affects version** = where the symptom manifests, verbatim; **Fix version** = where the fix lands + repo + target branch. N/A is fine for types with no affected release or repos that don't cut versions.
- **Commit titles verbatim**, ready for `git commit -m`; one block per commit; each commit self-contained and green.
- Skip lighter sections when self-evident; never pad.
- **No secrets or client specifics anywhere**: no credentials, tokens, client names, or internal hostnames — describe actors by role and data by kind.
- One logical change per PR: multiple commits yes, multiple unrelated tickets no — split them.

Not for OE repos (use `create-oe-pr`), not a commit/push tool, not a change-finder.
