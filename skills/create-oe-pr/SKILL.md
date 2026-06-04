---
name: create-oe-pr
description: Load the instructions for packaging an already-decided OpenEyes change into a review-ready PR folder. Same writeup shape as [[create-pr]] (problem → fix → changes → handoff) plus the OE-specific fields reviewers expect — release-notes-style title, non-client-specific problem statement, reproduction against a clean OE, the OE version the issue was raised in, and either a unit test or a written justification why none. This skill does NOT scan, survey, or discover changes — the caller already knows what changed; the skill only tells you how to write it up and where to put it. Output is a self-contained folder (changed files + a single .md) and supports multiple commits in one PR. Stops at the folder; never commits, never pushes. Invoke explicitly when the user says "create OE PR", "write up this OE PR", or "prep this OpenEyes change for review". Does NOT trigger for generic non-OE work — use [[create-pr]] for that.
disable-model-invocation: true
---

# Create-OE-PR playbook

This skill is **instructions only**. It does not look at the working tree, it does not run `git status`, it does not go hunting for what changed. The change to write up is whatever the current task already produced or decided — you bring that in; the skill tells you how to package it.

OpenEyes PRs face stricter review than a typical OSS repo: they ship across NHS trusts and private clinics, the title becomes a line in the customer-facing release notes, and the problem statement is read by people with no context for the original reporter. This skill enforces the OE conventions on top of the [[create-pr]] writeup.

Hard rules — same as [[create-pr]]:

- **Never `git commit`, never `git push`, never `--no-verify`.** You produce a folder of files plus one `.md`; the human raises the PR.
- **Suggest the [[oe_coding_standards]] skill** before any OE code is written. If the change predates that suggestion, suggest it now so the user can review the change against those rules before they commit.

## The deliverable: one folder, always

Every invocation produces exactly one folder. Never a loose `.md` at the repo root, never an in-place staged diff — a self-contained folder the user can read, apply, and raise from. Default its location to the user's home (`~/oe-pr-<slug>/`) unless the user names a path. Prefer the ticket ref in the slug if there is one (e.g. `oe-pr-OE-12345-archive-race/`).

```
oe-pr-<slug>/
  PR.md                 # the single writeup — title, problem, repro, fix, changes,
                        #   the commit plan, test, manual verify, OE version,
                        #   how-to-raise, reviewer notes
  files/                # every changed and new file, full content, mirrored at its
                        #   repo-relative path so the user can see exactly where each
                        #   one goes — e.g. files/protected/models/Patient.php
  patches/              # one patch per commit, in commit order, named NN-<slug>.patch
    01-<slug>.patch     #   the user runs `git apply` then commits with the message
    02-<slug>.patch     #   from PR.md's commit plan. Omit only for a brand-new repo
                        #   with no base to diff against.
```

`files/` mirrors the **repo-relative path** of each file, so `PR.md` never has to describe placement in prose for existing files — the path is the placement. For genuinely *new* files, the mirrored path is also where they go; call that out explicitly in PR.md's commit plan anyway, since a reviewer can't tell a new file from a moved one by looking at the folder.

## PR.md structure

This is what reviewers expect — don't omit sections. The **Commit plan** section is what carries multiple commits; everything else describes the PR as a whole.

```markdown
# <release-notes title>

The title doubles as a customer-facing release-notes entry. Generic, outcome-shaped,
imperative mood, under 70 chars, no trailing punctuation. No client names, no internal
jargon, no ticket numbers in the title itself.

  Good: "Fix archived patients reappearing in the default worklist after refresh"
  Bad:  "Fix bug Foo Clinic reported in ticket #1421"

## Problem

State it in **generic, non-client-specific** terms — a reader at a different trust should
recognise the symptom. Lead with user-visible behavior, not implementation. If there's a
ticket / incident link, put it on its own line at the end of the section.

  Good: "When a patient is archived from the worklist, the row reappears on the next page
         refresh until the user logs out. Affects clinics with >100 active patients."
  Bad:  "Foo Clinic reported that patient X is broken."

## Reproduction

Numbered, against a **clean OE** (sample DB, default seeds, `admin` / `admin`). A reviewer
on a fresh stack should land on the same symptom. If the bug needs config / module-state /
data not in the sample DB, say so and include the setup commands (`yiic`, SQL, etc.).

  1. Log in as `admin` / `admin`.
  2. Go to /worklist.
  3. Click "Archive" on any patient row.
  4. Refresh the page.
  5. Observed: archived patient still in default list.
     Expected: archived patient hidden; visible under `?showArchived=1`.

## Fix

What the change does, in plain language. Name the approach, not the diff. Mention the one
judgement call that mattered (and, if relevant, the approach you rejected and why).

## Changes

File-by-file, grouped by layer — model / migration / controller / view / module config /
test. Each bullet says *what* and *why*. Mark new files as (new) and incidental files as
(incidental).

  - `protected/models/Patient.php` — added `scopes()['default']` excluding archived rows.
    Root-cause fix; the controller filter (now removed) missed the AJAX paginator.
  - (new) `protected/migrations/m260524_120000_patient_archived_idx.php` — composite index
    on `(deleted, archived)` to keep the default scope fast on large tables.

## Commit plan

The PR may be one commit or several. List them **in order**. Each commit must be
self-contained and leave the tree green (tests pass, app boots) — never split a fix from
the test that proves it across two commits, and never leave a commit that won't build on
its own. Split by independent concern, not by file type.

For each commit give: the exact commit message (the release-notes title is the message of
the commit that carries the headline fix), the files it includes, and an apply command.

  ### Commit 1 — <message, imperative, matches the PR title for the headline fix>

    Files:
      - protected/models/Patient.php
      - protected/tests/unit/models/PatientArchivedScopeTest.php   (new)

    Apply & commit:
      git apply oe-pr-<slug>/patches/01-<slug>.patch
      git add protected/models/Patient.php \
              protected/tests/unit/models/PatientArchivedScopeTest.php
      git commit -m "Fix archived patients reappearing in the default worklist after refresh"

  ### Commit 2 — <message>

    Files:
      - (new) protected/migrations/m260524_120000_patient_archived_idx.php
          New file → goes at protected/migrations/ (mirrored in files/).

    Apply & commit:
      git apply oe-pr-<slug>/patches/02-<slug>.patch
      git add protected/migrations/m260524_120000_patient_archived_idx.php
      git commit -m "Add composite index for the default patient scope"

For a single-commit PR, give one block and skip the numbering ceremony.

## Test

Either a unit / functional test, or a justification. Pick exactly one:

  **Test added:** `protected/tests/unit/models/PatientArchivedScopeTest.php`. Run with:

      vendor/bin/phpunit protected/tests/unit/models/PatientArchivedScopeTest.php

  **No test, justification:** <one paragraph>. Acceptable: UI-only change with no model
  logic; copy / translation change; migration with no behavioural surface not already
  covered. Unacceptable: "ran out of time"; "this area has no tests" (add the first one).

## How to verify manually

Walk-through against a clean OE. This is what QA follows.

  1. Log in as `admin` / `admin`.
  2. … land on the symptom from Reproduction, apply the change, confirm it's gone.

## OE version

Issue raised in: **<version>** (verbatim — e.g. `v26.0.0-rc3`, `v25.4.1`).
Fix targeted at: **<branch>** (e.g. `master`, `release/26.0.x`).
Back-port? List both: targeted at `master`, cherry-pick to `release/25.4`.

## How to raise the PR

After running the per-commit apply & commit blocks above, in order:

    git push -u origin <branch>
    gh pr create --base <base> --title "<title>" --body-file oe-pr-<slug>/PR.md

Do not run any of these yourself — they're for the user to copy.

## Notes for the reviewer

Anything that saves the reviewer a question. If the change touches a clinical invariant
from [[oe_coding_standards]], say so and how you handled it (audit writes kept, soft-delete
preserved, transaction boundaries respected). Also call out any *related occurrences of the
same problem you found but did not fix here*, with file:line and a recommended approach, so
they can be tracked. Skip the section only if there is genuinely nothing to add.
```

## OE field rules (apply while writing PR.md)

These replace the "go survey the tree" steps a generic PR flow would have — they're judgements about the change you're *already* writing up, not a hunt for changes:

- **OE version, recorded verbatim.** The version the issue was raised against — from `package.json`, `protected/config/local/common.php` (`'version' => …`), `git describe --tags`, or the user. Write `v26.0.0-rc3`, never `26`.
- **Which OE repo.** `openeyes/openeyes` (PHP / Yii core) vs a satellite (`openeyes/oe-frontend`, …). The base branch and template differ; state both in the OE version section.
- **Migrations are always `core`** — never list a schema migration as "supporting"; it's load-bearing for the reviewer.
- **`local/common.php` edits are almost never the real change.** Module switches belong in `<module>/config/common.php`; `local/common.php` is just the on-switch. If the change is there, double-check the module's own `config/common.php` carries the real config.

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
- Not a substitute for [[oe_coding_standards]] — suggest that skill *before* the code is written, not at PR time.
- Not a commit / push tool. The boundary is the folder; the human commits and pushes.
- Not for non-OE repos — use [[create-pr]].
- Not for multi-*issue* branches. Multiple commits for **one** logical change/issue: yes (that's the commit plan). Two unrelated tickets on one branch: split them — the release-notes title can only describe one change.
