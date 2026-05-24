---
name: create-oe-pr
description: Prepare a pull request against an OpenEyes repo. Same shape as [[create-pr]] (problem → fix → changes → handoff) but adds OE-specific fields the reviewers expect — release-notes-style title, non-client-specific problem statement, reproduction steps against a clean OE, OE version the issue was raised in, and either a unit test or a written justification why none. Stops at staging; never commits, never pushes. Invoke explicitly when the user says "create OE PR", "write up this OE PR", or "prep this OpenEyes change for review". Does NOT trigger for generic non-OE work — use [[create-pr]] for that.
disable-model-invocation: true
---

# Create-OE-PR playbook

OpenEyes PRs face stricter review than a typical OSS repo: they're shipped across NHS trusts and private clinics, the title becomes a line in the customer-facing release notes, and the problem statement is read by people without context for the original reporter. This skill enforces the OE conventions on top of the [[create-pr]] base.

Hard rules — same as [[create-pr]]:

- **Never `git commit`, never `git push`, never `--no-verify`.** Output a `.md` artifact and a staged diff; the human raises the PR.
- **Suggest the [[oe_coding_standards]] skill** before writing any code in this skill's flow. If the change predates the suggestion, suggest it now and let the user review the diff against those rules before staging.

## 1. Survey the working tree

Same as [[create-pr]] step 1. Additionally identify:

- **Which OE repo:** `openeyes/openeyes` (PHP / Yii core) or one of the satellites (`openeyes/oe-frontend`, etc.). The PR template differs.
- **The OE version the issue was raised against.** Look in `package.json`, `protected/config/local/common.php` (`'version' => …`), or ask the user. Record it verbatim — e.g. `v26.0.0-rc3`, not `26`.
- **Whether the change touches clinical persistence / calculations / units / display.** If yes, surface clinical-safety invariants from [[oe_coding_standards]] before staging — the reviewer will block on this.

## 2. Isolate the change

Same triage as [[create-pr]] step 2 (`core` / `incidental` / `unrelated` / `accidental`). Two OE-specific calls:

- **Migrations.** Schema migrations are *always* `core` even if the user calls them "supporting" — they're load-bearing for the reviewer.
- **`local/common.php` edits.** These are *almost never* `core`. Module switches belong in `<module>/config/common.php`; if the diff touches `local/common.php`, double-check that the module's own `config/common.php` carries the real config and `local/common.php` is just the on-switch. See [[oe_coding_standards]].

## 3. Describe — write the `pr-<slug>.md` artifact

Write a single file at the repo root: `pr-<slug>.md`. Prefer the ticket ref if there is one (e.g. `pr-OE-12345-archive-race.md`).

OpenEyes PR structure (this is what reviewers expect — don't omit sections):

```markdown
# <release-notes title>

The title doubles as a customer-facing release-notes entry. Make it generic and outcome-shaped.

  Good: "Fix archived patients reappearing in the default worklist after refresh"
  Bad:  "Fix bug Foo Clinic reported in ticket #1421"
  Bad:  "tweak"

No client names. No internal jargon. Imperative mood, under 70 chars, no trailing punctuation.

## Problem

State the problem in **generic, non-client-specific** terms. A reader at a different trust
should be able to recognise the symptom. Lead with the user-visible behavior, not the
implementation detail.

  Good: "When a patient is archived from the worklist, the row reappears on the next page
         refresh until the user logs out. Affects clinics with >100 active patients."
  Bad:  "Foo Clinic reported that patient X is broken."

If there's a ticket / incident link, put it on its own line at the end of the section.

## Reproduction

Numbered, against a **clean OE** (sample DB, default seeds, `admin` / `admin`). A reviewer
running through these steps on a fresh stack should land on the same symptom.

  1. Log in as `admin` / `admin`.
  2. Go to /worklist.
  3. Click "Archive" on any patient row.
  4. Refresh the page.
  5. Observed: archived patient still in default list.
     Expected: archived patient hidden from default list; visible under `?showArchived=1`.

If the bug requires specific config / module-state / data not present in the sample DB,
say so and include the setup commands (`yiic` invocations, SQL, etc.).

## Fix

What the change does, in plain language. Name the approach, not the diff. Mention the one
judgement call that mattered.

## Changes

File-by-file. Group by layer — model / migration / controller / view / module config / test.
Each bullet says *what* and *why*.

  - `protected/models/Patient.php` — added `scopes()['default']` excluding archived rows.
    Reviewers: this is the root-cause fix; the controller-level filter (now removed) was
    incomplete because it didn't apply to the AJAX paginator.
  - `protected/migrations/m260524_120000_patient_archived_idx.php` — composite index on
    `(deleted, archived)` to keep the default scope fast on large tables.
  - (incidental) `composer.lock` — bumped alongside the dependency change above.

## Test

Either a unit / functional test, or a justification. Pick exactly one:

  **Test added:** `tests/unit/models/PatientArchivedScopeTest.php`. Run with:

      vendor/bin/phpunit tests/unit/models/PatientArchivedScopeTest.php

  **No test, justification:** <one paragraph>. Acceptable reasons include: UI-only change
  with no model logic; copy / translation change; migration with no behavioural surface
  that isn't already covered. Unacceptable reasons: "ran out of time", "the codebase
  doesn't have tests for this area" (add the first one).

## How to verify manually

Walk-through against a clean OE. This is what QA will follow.

  1. Log in as `admin` / `admin`.
  2. Go to /worklist.
  3. Click "Archive" on any patient row.
  4. Refresh the page.
  5. Verify the archived patient is hidden from the default list.
  6. Visit `?showArchived=1` and verify the patient reappears.

## OE version

Issue raised in: **<version>** (e.g. `v26.0.0-rc3`, `v25.4.1`).
Fix targeted at: **<branch>** (e.g. `master`, `release/26.0`).

If you're back-porting, list both: targeted at `master`, will need cherry-pick to `release/25.4`.

## How to raise the PR

    git commit -m "<title from above>"
    git push -u origin <branch>
    gh pr create --base <base> --title "<title>" --body-file pr-<slug>.md

Do not run these yourself. They go in the artifact for the user to copy.

## Notes for the reviewer

Anything that would save the reviewer a question. Mention if the change touches a clinical
invariant from [[oe_coding_standards]] and how you handled it (audit writes, soft-delete
preserved, unit kept, etc.). Skip if nothing to add.
```

## 4. Stage — don't commit

Same as [[create-pr]] step 4. Stage the core + incidental files + the `pr-<slug>.md`, show `git diff --staged --stat`, then stop. Never `git commit`, never `git push`.

## 5. Hand off

End with:

> Staged on `<branch>` (base `<base>`, OE `<version>`): N files + `pr-<slug>.md`. Run the three commands at the bottom of the artifact to raise the PR.

## OE-specific gotchas worth catching before staging

- **Clinical-safety invariants** — if the diff touches persistence, calculations, units, or display of clinical values without an explicit ask, **stop and flag it**. This is the single most common reason an OE PR gets rejected. Refer to [[oe_coding_standards]].
- **Audit writes** — any new clinical CRUD path needs an audit. Don't bypass `AuditService`.
- **`core/common.php`** — never edited from a module install. Module config lives in the module's own `config/common.php`; `local/common.php` is the on-switch only.
- **`voiceControl` / `aiSearch`** — these two modules stay independent. No runtime dependency between them.
- **`TestHelper` module** — never enabled in `OE_MODE=live`. Don't loosen that check.
- **`set_frontend_passwords.sh`** — not for sample-DB demos (they ship `admin` / `admin`). Don't recommend it in the reproduction steps.

## When to invoke this skill

| Trigger | Yes / No |
|---|---|
| "Create an OE PR for this" | **yes** |
| "Write up this OpenEyes change for review" | **yes** |
| "Prep this OE bugfix for release" | **yes** |
| "Create a PR" (no OE context) | no — use [[create-pr]] |
| "Commit this OE change" | no — this skill doesn't commit |

The skill is `disable-model-invocation: true` — Claude will not auto-load it. Invoke by name.

## What this skill is **not**

- Not a substitute for [[oe_coding_standards]] — suggest that skill *before* the code is written, not at PR time.
- Not a commit / push tool. Boundary stops at `git add`.
- Not for non-OE repos — use the generic [[create-pr]] instead.
- Not for multi-issue branches. If the branch fixes two unrelated tickets, split it; the release-notes title can only describe one change.
