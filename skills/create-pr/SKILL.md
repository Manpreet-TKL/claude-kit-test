---
name: create-pr
description: Package a non-OE change as a review-ready PR folder
disable-model-invocation: false
---

# Create-PR playbook

When loaded as context with no task, reply only `Context loaded.`

Instructions only - it does not scan the tree, run `git status`, or diff to discover what changed; the caller supplies the change, the skill packages it. The commit title becomes the PR headline and the description is read by reviewers with no context for the original request. **Never `git commit` / `git push` / `--no-verify`** - you push it yourself. **The full PR.md shape, field rules, and gotchas are in `subs/reference.md` - read it before writing the folder.**

For the three OpenEyes repos - `openeyes/openeyes`, `openeyes/IOLMasterImport`, `openeyes/PayloadProcessor` - use `create-oe-pr` instead (it carries the Jira release-notes form). Everything else uses this skill.

## The deliverable: one folder, always

Always under `~/pullrequests/` - `~/pullrequests/<repo>-pr-<slug>/` (ticket ref in the slug if there is one, e.g. `notes-pr-ENG-1421-archive-race/`):

- `PR.md` - a short **form**, not prose, carrying: an **Apply onto** base line (`<branch> @ <sha>`, so the patch can be rebased on the far side), **Branch** (must start `fix/` or `feature/`), **Commit title(s)** (suggested `git commit -m` message(s) you author yourself), a **Description** (a short what-and-why paragraph), and an **`## Apply`** command block - the far-side commands with concrete values. No Jira ticket / type / affects-version / fix-version fields - those live only in `create-oe-pr`. Full shape: `subs/reference.md`.
- `changes.patch` - a single unified-diff patch against the base, capturing every change - additions, edits, **and deletions** - as content, not commits. No clone, no `files/`, no `patches/`; the patch is the whole change and stays tiny to copy away. It carries **no commit messages** and applies as **unstaged working-tree changes only** (`git apply --3way`, never `git am`), so you review, stage, and author the commit(s) yourself on the far side. `PR.md` records the base as `Apply onto: <branch> @ <sha>` and carries the exact apply commands in its `## Apply` block; a moved base is no problem - `git apply --3way` re-bases it. Mark new files `(new)` in the Description. See `subs/reference.md` -> *Building the patch*.

## The shared index: `~/pullrequests.md`

After writing the folder, append **exactly one line** to `~/pullrequests.md` (create it if absent) - a markdown link to the PR folder plus an em-dash, single-line summary. One line per PR, newest at the bottom; never touch existing lines. This file is a shareable register of every PR raised, shared with `create-oe-pr`.

```
- [<repo>-pr-<slug>](pullrequests/<repo>-pr-<slug>/) - <single-line explanation of the PR>
```

Once you've pushed a PR, move its folder into `~/pullrequests/pushed/`; the index line stays as-is.

## Field judgements

- **Branch name** starts `fix/` (defect) or `feature/` (new behaviour), then a short slug.
- **Base branch** is the repo's mainline unless the user names one - `main` on newer repos (e.g. oe-deploy), `master` on older ones; check which exists rather than assuming.
- **Commit titles** are suggestions ready for you to paste into `git commit -m` on the far side - the skill never commits. **Default to one commit**; suggest multiple only when a split is genuinely beneficial. Each commit self-contained and green.
- **Description** leads with what the change does and why; keep it to a short paragraph. Skip detail when self-evident; never pad.
- **No secrets or client specifics anywhere**: no credentials, tokens, client names, or internal hostnames - describe actors by role and data by kind.
- One logical change per PR - one commit by default; multiple unrelated tickets never (split those into separate PRs).

Not for the three OE repos above (use `create-oe-pr`), not a commit/push tool, not a change-finder.
