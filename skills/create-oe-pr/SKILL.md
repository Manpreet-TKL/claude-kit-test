---
name: create-oe-pr
description: Write up an already-decided OpenEyes change as a review-ready PR folder (PR.md form + files/). Invoke by name.
disable-model-invocation: true
---

# Create-OE-PR playbook

This skill is **instructions only**. It does not look at the working tree, it does not run `git status`, it does not go hunting for what changed. The change to write up is whatever the current task already produced or decided — you bring that in; the skill tells you how to package it.

OpenEyes PRs face stricter review than a typical OSS repo: they ship across NHS trusts and private clinics, the title becomes a line in the customer-facing release notes, and the problem statement is read by people with no context for the original reporter. This skill enforces the OE conventions on top of the [[create-pr]] writeup.

Hard rules — same as [[create-pr]]:

- **Never `git commit`, never `git push`, never `--no-verify`.** You produce a folder of files plus one `.md`; the human raises the PR.
- **Suggest the [[oe_coding_standards]] skill** before any OE code is written. If the change predates that suggestion, suggest it now so the user can review the change against those rules before they commit.

## The deliverable: one folder, always

Every invocation produces exactly one folder. Never a loose `.md` at the repo root, never an in-place staged diff — a self-contained folder the user can read and raise from. Default its location to the user's home (`~/oe-pr-<slug>/`) unless the user names a path. Prefer the ticket ref in the slug if there is one (e.g. `oe-pr-OE-12345-archive-race/`).

```
oe-pr-<slug>/
  PR.md                 # the form — top labels (Jira ticket title, Jira ticket type,
                        #   Affects version, Fix version, Commit title(s), GitHub PR
                        #   description) then the description's quote-blocked sections
                        #   (Description, Steps to Reproduce, Current Outcome, Expected
                        #   Outcome, Solution, Files changed, Test, Notes)
  files/                # every changed and new file, full content, mirrored at its
                        #   repo-relative path so the user can copy each into place
                        #   — e.g. files/protected/models/Patient.php
```

**No `patches/`.** The skill does not diff the tree or generate patches. `files/` carries the full content of each changed file at its repo-relative path, and PR.md's "Files changed" field lists what changed in each file and why. `files/` mirrors the repo-relative path so PR.md never has to describe placement in prose for existing files — the path is the placement. For genuinely *new* files the mirrored path is also where they go; mark them `(new)` in the Files changed list so a reviewer can tell a new file from a moved one.

## PR.md structure

`PR.md` is a **form**, not a prose document — the user copies each labelled field straight into Jira / GitHub. Everything above the GitHub PR description is plain **`label: value`** metadata (one field per label, value on the same line or indented below it). The **top of PR.md always carries these labels, in this order**, so the copy-paste fields are never buried:

- **Jira ticket title** — the release-notes-style title (it is also the GitHub PR title).
- **Jira ticket type** — exactly one of Bug / New Feature / Improvement / Internal Improvement / Story / Epic / Regression / EyeDraw Spec. See the classification table below; for an OE client-reported fault the answer is most often **Regression**.
- **Affects version** — the OE version the client is experiencing the problem on (verbatim). Where the symptom manifests, not where the fix lands.
- **Fix version** — the OE version the fix targets (verbatim), the repo, and the target branch.
- **Commit title** — the exact, verbatim `git commit -m` message, on its own indented line, ready to copy straight into `git commit -m "<commit title>"`. Could be multiple: one block per commit, in order. Never leave the commit message implicit or buried in prose.
- **GitHub PR description** — the PR body that follows (could be multiple, if the branch raises more than one PR).

The **GitHub PR description** is the only markdown-formatted field. It is a sequence of `##` sections; **each `##` heading stays OUT of the blockquote** (they render as real markdown headings) and **only the body under each heading is a single blockquote** — every body line prefixed with `> ` — so each section pastes as one quoted block under a plain heading. The sections, in order:

1. **Description** — required; what the change does and why.
2. **Steps to Reproduce** — numbered, client-agnostic (Bug / Regression).
3. **Current Outcome** — the wrong behaviour the steps produce today.
4. **Expected Outcome** — the correct behaviour the steps should produce.
5. **Solution** — the approach taken, named not diffed.
6. **Files changed** — one bullet per file, one sentence on why each file changed.
7. **Test** — the test added, or why one is not applicable.
8. **Notes for reviewer** — very simple bullet points for edge cases to check.

Description is always present. The **Steps to Reproduce / Current Outcome / Expected Outcome** triad fits Bug and Regression tickets; for the feature and planning ticket types (New Feature, Improvement, Internal Improvement, Story, Epic, EyeDraw Spec) there is often nothing to reproduce — drop the triad and let Description + Solution carry the writeup. The other lighter sections may also be **skipped when the change is self-evident** (e.g. a slow page load fixed by a missing index needs little more than Description + Files changed) — include a section only when it carries information, and never pad. Sometimes the triad cannot be followed cleanly even for a fault (intermittent, data-dependent, or environment-specific symptoms) — say what you can and don't fabricate steps.

```
Jira ticket title:
<release-notes-style title — it doubles as a customer-facing release-notes entry.
Generic, outcome-shaped, imperative, under 70 chars, no trailing punctuation, no
client names, no ticket numbers. Reused as the GitHub PR title.
  Good: Fix archived patients reappearing in the default worklist after refresh
  Bad:  Fix bug Foo Clinic reported in ticket #1421>

Jira ticket type:
<exactly one of: Bug | New Feature | Improvement | Internal Improvement | Story |
Epic | Regression | EyeDraw Spec. For an OE client-reported fault this is most often
Regression — see "Jira ticket type — classify" below. Get it right; it drives triage.>

Affects version:
<the version the client is experiencing the problem on, verbatim — e.g. v25.4.1.
Where the symptom manifests, not where the fix lands. If a range, name the earliest
confirmed. Leave blank only for ticket types with no affected install (e.g. a New
Feature that never shipped).>

Fix version:
Raised in <version, verbatim — e.g. v26.0.0-rc3, v25.4.1>. Repo <openeyes/openeyes
or a satellite>. Target <branch — e.g. release/26.0.x>. Back-port? list both
(e.g. target master, cherry-pick to release/25.4).

Commit title:
(The verbatim `git commit -m` message — copied straight into git commit -m "<this>".
Imperative mood; the commit that carries the headline fix uses the Jira title. One
block per commit if there are several; see "Multiple commits" below.)

    <exact commit message, on its own indented line, ready for git commit -m>

GitHub PR description:
(The PR body — paste into the pull request's description box, or pass via
`gh pr create --body-file`. The "##" lines are real markdown headings and stay OUT
of the blockquotes; only each section body is quoted. Skip the triad for non-fault
ticket types, and skip a lighter section when the change is self-evident; never drop
Description.)

## Description
> What the change does and why, in plain language. Lead with the user-visible
> behaviour and the problem it fixes. Generic and non-client-specific — a reader at
> a different trust should recognise it.
> Every line of this body prefixed with `> `; the heading above is not.

## Steps to Reproduce
> Numbered and client-agnostic. This is release-notes- and Jira-facing, so NEVER name
> a specific client, their credentials, seed data, or the OE sample DB (no "log in as
> admin / admin", no "from the sample DB", no client / trust names). Describe the
> actor by role ("a logged-in user", "a clinician with access to a patient record")
> and the actions in product terms a reader at any client would recognise. Keep the
> steps generic enough to reproduce on any install — not always possible; if the
> symptom needs particular data, say what *kind* of data, not whose. A version or
> config condition the symptom needs is fine — it holds for every such install, not
> one client (e.g. "On OE v26, where X defaults to ON").
> Every line of this body prefixed with `> `; the heading above is not.
> 1. As a logged-in user, ...
> 2. ...

## Current Outcome
> The wrong behaviour as it stands today — what actually happens at the end of the
> steps. One or two lines, client-agnostic.
> Every line of this body prefixed with `> `; the heading above is not.

## Expected Outcome
> The correct behaviour the steps should produce instead. One or two lines.
> Every line of this body prefixed with `> `; the heading above is not.

## Solution
> The approach taken, named not diffed — the mechanism of the fix and the one
> judgement call that mattered (and the alternative you rejected, if relevant).
> Every line of this body prefixed with `> `; the heading above is not.

## Files changed
> One bullet per changed file — repo-relative path + one sentence on why it changed.
> Mark new files (new) and incidental ones (incidental). The full content of each is
> in files/ at its repo-relative path; this list is just the map.
> - protected/models/Patient.php — added a default scope excluding archived rows.
> - (new) protected/migrations/m260524_120000_patient_archived_idx.php — index that
>   keeps the default scope fast on large tables.

## Test
> Exactly one of — Test added: protected/tests/unit/... (run with
> `vendor/bin/phpunit <path>`); or No test, justification: <one paragraph; acceptable
> for a UI-only change, copy / translation, or a migration with no behavioural
> surface; not "ran out of time" and not "this area has no tests" — add the first
> one>.
> Every line of this body prefixed with `> `; the heading above is not.

## Notes for reviewer
> Very simple bullet points — edge cases to check, clinical-safety invariants touched
> and how you handled them, any stack-specific verification that doesn't belong in the
> release-notes-facing Steps to Reproduce (cache-clear commands, container names), and
> any related occurrence of the same problem found but not fixed here (file:line +
> recommended approach). Skip if there is genuinely nothing to add.
> - <edge case to check>
> - <invariant / verification note>
```

### Jira ticket type — classify, pick exactly one

Every PR.md sets a `Jira ticket type:` label to exactly one value. Choose the best fit:

| Type | Use when |
|---|---|
| **Regression** | Worked in an earlier OE version and broke in a later one. **The default for OE client-reported faults** — most client tickets are regressions. |
| **Bug** | A defect that was never correct (no known prior-working version), or a fault with no earlier baseline to regress from. |
| **New Feature** | Net-new capability that did not exist before. |
| **Improvement** | Enhancement to existing, user-visible behaviour. |
| **Internal Improvement** | Refactor, tech-debt, tooling, or dev-facing change with no user-visible behaviour change. |
| **Story** | A planned unit of requirement work (an agile story). |
| **Epic** | A large body of work spanning several stories. |
| **EyeDraw Spec** | A specification for an EyeDraw doodle / drawing. |

The call you'll make most is **Bug vs Regression**: did a prior OE version behave correctly? If yes → **Regression**; if it never worked → **Bug**. When unsure for a client fault, default to **Regression**. **Improvement vs Internal Improvement** turns on user-visibility: if a clinician would notice the difference it's an Improvement, otherwise Internal Improvement.

The Steps to Reproduce / Current Outcome / Expected Outcome triad fits **Bug** and **Regression**. For the feature and planning types (New Feature, Improvement, Internal Improvement, Story, Epic, EyeDraw Spec) there is often no current outcome to reproduce — drop the triad and let Description + Solution carry the writeup. Match the section shape to the ticket type; do not invent reproduction steps for a feature.

### Multiple commits

The PR may be one commit or several. The **Commit title** label takes one indented message block per commit, in order. Each commit must be self-contained and leave the tree green (tests pass, app boots) — never split a fix from the test that proves it across two commits, never leave a commit that won't build on its own. Split by independent concern, not by file type. The release-notes title is the message of the commit that carries the headline fix. For a single-commit PR, give just one message and skip the numbering ceremony.

## How to raise the PR

The full content of every changed and new file is in `files/`, mirrored at its repo-relative path, so getting the change into the tree is a copy, not a patch apply:

```
# from the PR folder's parent, copy every changed file into the repo
cp -a oe-pr-<slug>/files/. <repo-root>/

# then, per commit in order, stage that commit's files and use its
# "Commit title" from PR.md as the message
git add <files for commit 1>
git commit -m "<commit title 1>"
# ...repeat for any further commits...

git push -u origin <branch>
# title = Jira ticket title; body = the GitHub PR description from PR.md
gh pr create --base <base> --title "<Jira ticket title>" --body-file <pr-description.md>
```

Do not run any of these yourself — they're for the user to copy. The "GitHub PR description" section of PR.md is the PR body verbatim; the user either pastes it into the PR description box or saves it to a file for `--body-file`. The Jira ticket title, Jira ticket type, and Affects version labels are for the Jira ticket, not for `gh` — the user transcribes them into Jira.

## OE field rules (apply while writing PR.md)

These replace the "go survey the tree" steps a generic PR flow would have — they're judgements about the change you're *already* writing up, not a hunt for changes:

- **Jira ticket type, exactly one.** Classify the change as Bug / New Feature / Improvement / Internal Improvement / Story / Epic / Regression / EyeDraw Spec (table above). For an OE client-reported fault the answer is most often **Regression** — get this right, it drives how the ticket is triaged.
- **Affects version, recorded verbatim.** The version the client is experiencing the problem on — where the symptom manifests, not where the fix lands. Distinct from Fix version. Pick the version the reporter is actually running; if a range, name the earliest confirmed. Write `v25.4.1`, never `25`.
- **Fix version, recorded verbatim.** The version the issue was raised against — from `package.json`, `protected/config/local/common.php` (`'version' => …`), `git describe --tags`, or the user. Write `v26.0.0-rc3`, never `26`.
- **Which OE repo.** `openeyes/openeyes` (PHP / Yii core) vs a satellite (`openeyes/oe-frontend`, …). The base branch and template differ; state both in the Fix version field.
- **Migrations are always `core`** — never list a schema migration as "supporting"; it's load-bearing for the reviewer.
- **`local/common.php` edits are almost never the real change.** Module switches belong in `<module>/config/common.php`; `local/common.php` is just the on-switch. If the change is there, double-check the module's own `config/common.php` carries the real config.

## Keep it client-agnostic (applies across every field)

The PR.md is read by reviewers and copied into customer-facing release notes, so strip the original reporter's fingerprints from every field, not just the title:

- **No client-specific details.** No client / trust names, no instance hostnames, no real patient or user data, no ticket numbers, no "as Foo Clinic reported".
- **Generic steps where possible.** Write Steps to Reproduce so any install can follow them. It isn't always possible — when the symptom genuinely depends on a client's data or config, describe the *kind* of data or the config condition, not the client.
- **The template is a default, not a cage.** When a fault can't be reduced to clean Steps / Current / Expected (intermittent, data-dependent, environment-specific), say what you can and stop — don't fabricate reproduction steps to fill the shape.

## OE gotchas worth catching before you finalise the folder

- **Clinical-safety invariants** — if the change touches persistence, calculations, units, or display of clinical values without an explicit ask, **stop and flag it in reviewer notes**. Single most common reason an OE PR gets rejected. See [[oe_coding_standards]].
- **Audit writes** — any new clinical CRUD path needs an audit; don't bypass `AuditService`.
- **`core/common.php`** — never edited from a module install. Module config lives in the module's own `config/common.php`; `local/common.php` is the on-switch only.
- **`voiceControl` / `aiSearch`** — stay independent. No runtime dependency between them.
- **`TestHelper` module** — never enabled in `OE_MODE=live`. Don't loosen that check.
- **`set_frontend_passwords.sh`** — not for sample-DB demos (they ship `admin` / `admin`). Don't put it in the reproduction steps.

## When to invoke this skill

| Trigger | Yes / No |
|---|---|
| "Create an OE PR for this" | **yes** |
| "Write up this OpenEyes change for review" | **yes** |
| "Prep this OE bugfix for release" | **yes** |
| "Create a PR" (no OE context) | no — use [[create-pr]] |
| "Commit this OE change" | no — this skill doesn't commit |

`disable-model-invocation: true` — Claude will not auto-load it. Invoke by name.

## What this skill is **not**

- **Not a change-finder.** It does not scan, survey, `git status`, or diff the working tree to discover what to raise. The caller supplies the change; the skill only formats and places it.
- **Not a patch generator.** No `patches/`, no `git diff`, no `git apply`. The deliverable is the changed files in `files/` plus the PR.md form.
- Not a substitute for [[oe_coding_standards]] — suggest that skill *before* the code is written, not at PR time.
- Not a commit / push tool. The boundary is the folder; the human commits and pushes.
- Not for non-OE repos — use [[create-pr]].
- Not for multi-*issue* branches. Multiple commits for **one** logical change/issue: yes (that's the commit comments). Two unrelated tickets on one branch: split them — the release-notes title can only describe one change.
