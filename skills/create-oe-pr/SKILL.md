---
name: create-oe-pr
description: Package an OE change as a review-ready PR folder
disable-model-invocation: false
---

# Create-OE-PR playbook

When loaded as context with no task, reply only `Context loaded.`

Instructions only - it does not scan the tree, run `git status`, or diff to discover what changed; the caller supplies the change, the skill packages it. **Only for these three OE repos** - everything else uses `create-pr`:

- `git@github.com:openeyes/openeyes.git`
- `git@github.com:openeyes/IOLMasterImport.git`
- `git@github.com:openeyes/PayloadProcessor.git`

OE PRs ship across NHS trusts and private clinics: the title becomes a customer-facing release-notes line and the writeup is read by people with no context for the original reporter. **Never `git commit` / `git push` / `--no-verify`** - you push it yourself. Suggest the `c-oe-coding-standards` skill before OE code is written (or now, if the change predates that suggestion). **The full PR.md template, Jira-type table, field rules, and gotchas are in `subs/reference.md` - read it before writing the folder.**

## The deliverable: one folder, always

Always under `~/pullrequests/`, named by repo (ticket ref in the slug if there is one):

- `openeyes` -> `oe-pr-<slug>/` (e.g. `oe-pr-OE-12345-archive-race/`)
- `IOLMasterImport` -> `oe-iol-pr-<slug>/`
- `PayloadProcessor` -> `oe-pay-pr-<slug>/`

Each folder holds:

- `PR.md` - a **form**, not prose, split into two copy-paste sections. **`# JIRA`**: `Ticket name` (the Jira title) plus a `## Description box` block - `Jira ticket type` / `Affects version` / `Fix version` then `###` sections Description, Steps to Reproduce, Current Outcome, Expected Outcome - that pastes whole into the Jira ticket's description field. **`# GITHUB`**: `Apply onto` / `Commit title` / an `## Apply & push` command block (not a paste target - the far-side commands with concrete values), then a `## PR body` of `###` sections Summary, Scope of Changes (`####` Solution + Files changed + Test), Notes for Reviewers - each `###` block pastes into the matching section of the live OE PR template. The Description is reused verbatim as the Summary. `#`/`##`/`###` headings stay OUT of the blockquotes, each body is one `> `-quoted block. The live template's tickboxes, emoji headings and Do-No-Harm reminder are the user's to fill in after raising - the skill never reproduces that chrome.
- `changes.patch` - a single mbox-format (`git format-patch`-style) patch against the resolved base, capturing every change - additions, edits, **and deletions** - as content. No clone, no `files/`, no `patches/` - the patch is the whole change and stays tiny to copy away. Each mbox entry carries its commit message baked in (`From:` = the identity the target checkout commits as, `Subject: [PATCH] [OE-XXXXX] - <title>`), with the Jira key left as the literal `OE-XXXXX` placeholder - a **real** key is never emitted by the skill; **you** substitute it at apply time (find/replace in the patch file) and `git am -3 --keep-non-patch` creates the commit(s) as you. A multi-commit PR is simply N entries concatenated in the same file. `PR.md` records the base as `Apply onto: <branch> @ <sha>` and carries the exact apply commands in its `## Apply & push` block; a base that has moved on is no problem - `git am -3` degrades to a three-way merge (and the file stays `git apply --3way`-able, headers ignored). Mark new files `(new)` in the Files changed list. See `subs/reference.md` -> *Building the patch* and *Apply & push*.

## Base branch: the nearest `release/*.x`

**`openeyes`** ships from `release/<major>.<minor>.x` lines (e.g. `release/26.0.x`, `release/11.0.x`). Resolve the base from the **Fix version**: list the remote release branches (`git ls-remote --heads origin 'release/*'`) and pick the matching `release/<major>.<minor>.x`. If there's no exact match, pick the nearest existing line and **say which one and why**; if more than one is plausible (e.g. a back-port spanning the 26.x and 11.x lines), **list the candidates and let the user pick** - never guess silently.

`IOLMasterImport` and `PayloadProcessor` don't cut `release/*.x` lines - resolve their base from `origin`'s default branch (or the release/tag branch the user names) and **state which one you used**.

The patch is cut against that base, and `PR.md` records it as `Apply onto: <branch> @ <sha>` (the `git ls-remote` sha). The far side supplies the *current* base at apply time, so a base that has moved on since is no problem - `git am -3` re-bases the change onto today's tree (see `subs/reference.md` -> *Building the patch*). This is exactly why the patch, not a clone, is the deliverable: nothing is welded to a stale base.

## The shared index: `~/pullrequests.md`

After writing the folder, append **exactly one line** to `~/pullrequests.md` (create it if absent) - a markdown link to the PR folder plus an em-dash, single-line summary (reuse the Jira ticket title). One line per PR, newest at the bottom; never touch existing lines. This file is a shareable register of every PR raised, shared across `create-pr` and `create-oe-pr`.

```
- [oe-pr-<slug>](pullrequests/oe-pr-<slug>/) - <single-line explanation of the PR>
```

Use the repo-appropriate folder prefix in the link (`oe-pr` / `oe-iol-pr` / `oe-pay-pr`). Once you've pushed a PR, move its folder into `~/pullrequests/pushed/`; the index line stays as-is.

## Field judgements

- **Type, exactly one** of Bug / New Feature / Improvement / Internal Improvement / Story / Epic / Regression / EyeDraw Spec. Client-reported fault -> usually **Regression** (worked in a prior version); never-correct -> Bug. Improvement vs Internal turns on user-visibility.
- **Affects version** = where the symptom manifests, verbatim (`v25.4.1`); **Fix version** = where the fix lands + repo + target branch.
- **Commit titles** are baked into `changes.patch` as mbox `Subject:` lines (and listed in `PR.md` so they can be read without opening the patch) - the skill still never commits: `git am` writes the commit as **you**, and the key stays the literal `OE-XXXXX` placeholder until you find/replace the real one in at apply time - that subject line is what auto-updates the Jira ticket. Whole subject incl. prefix <= 72 chars (so <= 59 after `- `). **One commit near-always** - OE PRs are squashed on merge, so a split must be *very* beneficial to justify itself; a multi-commit PR is just more mbox entries in the same file. See `subs/reference.md` -> *Commit titles* and *Multiple commits*.
- **Branch naming**: branches are normally called `fix/OE-XXXXX` (bugfixes) or `feature/OE-XXXXX` (new features/improvements) - the real Jira key, substituted by you. `PR.md`'s `## Apply & push` block writes them with a sample key for you to replace.
- The Steps/Current/Expected triad lives in the `# JIRA` description box and fits Bug/Regression only - drop it for feature/planning/performance types; skip lighter sections when self-evident; never pad or fabricate steps. For the Steps to Reproduce, run `c-oe-repro` if they aren't already in this conversation - it owns the rules.
- **Client-agnostic everywhere**: no trust names, ticket numbers, credentials, sample-DB references, or real patient data - describe actors by role and data by kind.
- **Author's voice, never "we"**: every generated block reads as the user's own writing - impersonal and singular. No first-person plural (`we`/`our`/`us`); say what the change does ("the change removes...", "an explicit `userDataDir` is deliberately not passed") so it transcribes cleanly into Jira/GitHub with no team voice.
- One logical change per PR - one commit near-always; multiple unrelated tickets never (split those into separate PRs).

Not for non-OE repos (use `create-pr`), not a commit/push tool, not a change-finder.
