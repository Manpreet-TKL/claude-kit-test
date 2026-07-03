---
name: create-oe-pr
description: Package an OE change as a review-ready PR folder
disable-model-invocation: true
---

# Create-OE-PR playbook

When loaded as context with no task, reply only `Context loaded.`

Instructions only — it does not scan the tree, run `git status`, or diff to discover what changed; the caller supplies the change, the skill packages it. **Only for these three OE repos** — everything else uses `create-pr`:

- `git@github.com:openeyes/openeyes.git`
- `git@github.com:openeyes/IOLMasterImport.git`
- `git@github.com:openeyes/PayloadProcessor.git`

OE PRs ship across NHS trusts and private clinics: the title becomes a customer-facing release-notes line and the writeup is read by people with no context for the original reporter. **Never `git commit` / `git push` / `--no-verify`** — you push it yourself. Suggest the `c-oe-coding-standards` skill before OE code is written (or now, if the change predates that suggestion). **The full PR.md template, Jira-type table, field rules, and gotchas are in `subs/reference.md` — read it before writing the folder.**

## The deliverable: one folder, always

Always under `~/pullrequests/`, named by repo (ticket ref in the slug if there is one):

- `openeyes` → `oe-pr-<slug>/` (e.g. `oe-pr-OE-12345-archive-race/`)
- `IOLMasterImport` → `oe-iol-pr-<slug>/`
- `PayloadProcessor` → `oe-pay-pr-<slug>/`

Each folder holds:

- `PR.md` — a **form**, not prose. Top labels in order: Jira ticket title / Jira ticket type / Affects version / Fix version / Commit title(s) / GitHub PR description. The description is `##` sections (Description, Steps to Reproduce, Current Outcome, Expected Outcome, Solution, Files changed, Test, Notes for reviewer); headings stay OUT of the blockquotes, each body is one `> `-quoted block.
- `<repo>/` — a **fresh full git clone of the OE repo**, cloned from its `origin` (so push targets the real remote), checked out on a new branch `<branch>` cut from the right base (see below), with every change — additions, edits, **and deletions** — applied in the working tree and **left uncommitted**; you push it yourself. A clean clone per PR so you can copy the folder down and push up with **no dangling files from anything else tried in an earlier clone**. The clone *is* the change: **no `files/`, no `patches/`.** Mark new files `(new)` in the Files changed list. See `subs/reference.md` → *Building the clone*.

## Base branch: the nearest `release/*.x`

**`openeyes`** ships from `release/<major>.<minor>.x` lines (e.g. `release/26.0.x`, `release/11.0.x`). Resolve the clone's base from the **Fix version**: list the remote release branches (`git ls-remote --heads origin 'release/*'`) and check out the matching `release/<major>.<minor>.x`. If there's no exact match, pick the nearest existing line and **say which one and why**; if more than one is plausible (e.g. a back-port spanning the 26.x and 11.x lines), **list the candidates and let the user pick** — never guess silently. Cut the PR `<branch>` from that release branch.

`IOLMasterImport` and `PayloadProcessor` don't cut `release/*.x` lines — resolve their base from `origin`'s default branch (or the release/tag branch the user names) and **state which one you used**.

## The shared index: `~/pullrequests.md`

After writing the folder, append **exactly one line** to `~/pullrequests.md` (create it if absent) — a markdown link to the PR folder plus an em-dash, single-line summary (reuse the Jira ticket title). One line per PR, newest at the bottom; never touch existing lines. This file is a shareable register of every PR raised, shared across `create-pr` and `create-oe-pr`.

```
- [oe-pr-<slug>](pullrequests/oe-pr-<slug>/) — <single-line explanation of the PR>
```

Use the repo-appropriate folder prefix in the link (`oe-pr` / `oe-iol-pr` / `oe-pay-pr`). Once you've pushed a PR, move its folder into `~/pullrequests/pushed/`; the index line stays as-is.

## Field judgements

- **Type, exactly one** of Bug / New Feature / Improvement / Internal Improvement / Story / Epic / Regression / EyeDraw Spec. Client-reported fault → usually **Regression** (worked in a prior version); never-correct → Bug. Improvement vs Internal turns on user-visibility.
- **Affects version** = where the symptom manifests, verbatim (`v25.4.1`); **Fix version** = where the fix lands + repo + target branch.
- **Commit titles verbatim**, ready for `git commit -m`; one block per commit; each commit self-contained and green.
- The Steps/Current/Expected triad fits Bug/Regression only — drop it for feature/planning/performance types; skip lighter sections when self-evident; never pad or fabricate steps. For the Steps to Reproduce, run `c-oe-repro` if they aren't already in this conversation — it owns the rules.
- **Client-agnostic everywhere**: no trust names, ticket numbers, credentials, sample-DB references, or real patient data — describe actors by role and data by kind.
- One logical change per PR: multiple commits yes, multiple unrelated tickets no — split them.

Not for non-OE repos (use `create-pr`), not a commit/push tool, not a change-finder.
