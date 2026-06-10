---
name: create-oe-pr
description: Package an OE change as a review-ready PR folder
disable-model-invocation: true
---

# Create-OE-PR playbook

When loaded as context with no task, reply only `Context loaded.`

Instructions only — it does not scan the tree, run `git status`, or diff to discover what changed; the caller supplies the change, the skill packages it. OE PRs ship across NHS trusts and private clinics: the title becomes a customer-facing release-notes line and the writeup is read by people with no context for the original reporter. **Never `git commit` / `git push` / `--no-verify`** — the human raises the PR. Suggest the `oe-coding-standards` skill before OE code is written (or now, if the change predates that suggestion). **The full PR.md template, Jira-type table, field rules, raise commands, and gotchas are in `subs/reference.md` — read it before writing the folder.**

## The deliverable: one folder, always

Default `~/oe-pr-<slug>/` (ticket ref in the slug if there is one, e.g. `oe-pr-OE-12345-archive-race/`):

- `PR.md` — a **form**, not prose. Top labels in order: Jira ticket title / Jira ticket type / Affects version / Fix version / Commit title(s) / GitHub PR description. The description is `##` sections (Description, Steps to Reproduce, Current Outcome, Expected Outcome, Solution, Files changed, Test, Notes for reviewer); headings stay OUT of the blockquotes, each body is one `> `-quoted block.
- `files/` — full content of every changed and new file at its repo-relative path, so raising is a copy, not a patch apply. **No `patches/`.** Mark new files `(new)`.

## Field judgements

- **Type, exactly one** of Bug / New Feature / Improvement / Internal Improvement / Story / Epic / Regression / EyeDraw Spec. Client-reported fault → usually **Regression** (worked in a prior version); never-correct → Bug. Improvement vs Internal turns on user-visibility.
- **Affects version** = where the symptom manifests, verbatim (`v25.4.1`); **Fix version** = where the fix lands + repo + target branch.
- **Commit titles verbatim**, ready for `git commit -m`; one block per commit; each commit self-contained and green.
- The Steps/Current/Expected triad fits Bug/Regression only — drop it for feature/planning types; skip lighter sections when self-evident; never pad or fabricate steps.
- **Client-agnostic everywhere**: no trust names, ticket numbers, credentials, sample-DB references, or real patient data — describe actors by role and data by kind.
- One logical change per PR: multiple commits yes, multiple unrelated tickets no — split them.

Not for non-OE repos (use `create-pr`), not a commit/push tool, not a change-finder.
