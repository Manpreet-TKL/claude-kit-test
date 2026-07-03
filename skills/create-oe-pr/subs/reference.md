# create-oe-pr — the PR.md form, field rules, and gotchas

## PR.md template (verbatim shape)

Everything above the GitHub PR description is plain `label: value` metadata. The GitHub PR description is the only markdown field: `##` headings stay OUT of the blockquotes; each section body is one `> `-quoted block.

```
Jira ticket title:
<release-notes-style title — doubles as the customer-facing release-notes entry and
the GitHub PR title. Generic, outcome-shaped, imperative, under 70 chars, no trailing
punctuation, no client names, no ticket numbers.
  Good: Fix archived patients reappearing in the default worklist after refresh
  Bad:  Fix bug Foo Clinic reported in ticket #1421>

Jira ticket type:
<exactly one of: Bug | New Feature | Improvement | Internal Improvement | Story |
Epic | Regression | EyeDraw Spec — see the table below>

Affects version:
<the version the client is experiencing the problem on, verbatim — e.g. v25.4.1.
Where the symptom manifests, not where the fix lands. If a range, the earliest
confirmed. Blank only for types with no affected install.>

Fix version:
Raised in <version, verbatim — e.g. v26.0.0-rc3>. Repo <openeyes/openeyes or a
satellite>. Target <branch — e.g. release/26.0.x>. Back-port? list both.

Commit title:
(verbatim `git commit -m` message, on its own indented line; one block per commit,
in order; the headline-fix commit reuses the Jira title)

    <exact commit message>

GitHub PR description:

## Description
> What the change does and why, plain language, client-agnostic. Lead with the
> user-visible behaviour and the problem it fixes. Always present.

## Steps to Reproduce
> A generic, **frontend-only** click-path any user can follow without knowing what the
> page does — numbered, **one sentence per step**, each naming the exact control by its
> on-screen label (quoted) and where it sits. Client-agnostic (actor by role, data by
> *kind*, never creds/seed/sample-DB). Start at login if a session is needed; end on an
> observable check. Rules, worked example and special cases live in the **`c-oe-repro`**
> skill — run it if the steps aren't already in this conversation.
> 1. Log in as an administrator (a user with full access).

## Current Outcome
> What actually happens at the end of the steps. One or two lines.

## Expected Outcome
> What should happen instead. One or two lines.

## Solution
> The approach, named not diffed — the mechanism and the one judgement call that
> mattered (and the rejected alternative, if relevant).

## Files changed
> One bullet per file: repo-relative path + one sentence on why. Mark (new) and
> (incidental). The applied change lives in the clone at the same path — this list
> is the map.
> - protected/models/Patient.php — added a default scope excluding archived rows.

## Test
> Exactly one of — Test added: <path> (run with `vendor/bin/phpunit <path>`); or
> No test, justification: <paragraph — OK for UI-only/copy/migration with no
> behavioural surface; not "ran out of time", not "this area has no tests">.

## Notes for reviewer
> Simple bullets: edge cases, clinical-safety invariants touched and how handled,
> stack-specific verification that doesn't belong in Steps (cache clears, container
> names), related-but-unfixed occurrences (file:line + recommended approach).
> Skip if genuinely nothing to add.
```

Section shape by type: the Steps/Current/Expected triad fits Bug and Regression; drop it for feature/planning types. Skip lighter sections when the change is self-evident; never pad; if a fault can't be reduced to clean steps (intermittent, data-dependent), say what you can — don't fabricate.

## Steps to Reproduce — owned by `c-oe-repro`

The rules, the worked example, and the special cases (performance/refactor tickets with no repro, client-data-dependent faults, intermittent alerts) now live in the **`c-oe-repro`** skill. If the Steps to Reproduce aren't already in this conversation, run `c-oe-repro` to produce them before assembling the folder, then paste its blockquote into the `## Steps to Reproduce` block. Essentials it enforces: frontend-only, followable blind by someone who has never used the page, client-agnostic (no creds/seed/hospital numbers), plain language (no code), ends on an observable check. Drop the section entirely for types with no user-observable behaviour (performance/internal refactor).

## Jira ticket type — pick exactly one

| Type | Use when |
|---|---|
| **Regression** | Worked in an earlier OE version, broke later. **Default for client-reported faults.** |
| **Bug** | Never correct, or no prior-working baseline. |
| **New Feature** | Net-new capability. |
| **Improvement** | Enhancement to existing user-visible behaviour. |
| **Internal Improvement** | Refactor/tooling/tech-debt, no user-visible change. |
| **Story** | A planned unit of requirement work. |
| **Epic** | Large body of work spanning stories. |
| **EyeDraw Spec** | Specification for an EyeDraw doodle. |

Bug vs Regression: did a prior version behave correctly? Yes → Regression. Unsure on a client fault → Regression. Improvement vs Internal: would a clinician notice?

## Multiple commits

One indented message block per commit, in order. Each commit self-contained and green (tests pass, app boots) — never split a fix from its proving test, never a commit that won't build alone. Split by independent concern, not file type. Single commit → one message, no numbering ceremony.

## Building the clone (how the skill assembles the folder)

- **Source:** clone from the repo's `origin` URL — read it from the caller's working copy
  (`git -C <working-copy> remote get-url origin`) — so the clone's `origin` is the real
  remote and your push just works. Full clone, not shallow. OE repos are private,
  so this relies on the user's configured git auth (askpass / SSH).
- **Base branch:** resolve the nearest `release/<major>.<minor>.x` from the Fix version —
  `git ls-remote --heads origin 'release/*'`, match `release/<maj>.<min>.x`, else nearest +
  say which, else list candidates and let the user pick (see SKILL.md → *Base branch*).
  Check that release branch out, then `git checkout -b <branch>` off it.
- **Apply:** write the final content of every changed and new file into the clone's working
  tree at its repo-relative path — content, not patches — and **delete every file the change
  removes** so the working tree reflects additions, edits, and deletions. Nothing else in the tree.
- **Leave it uncommitted.** Never `git commit` / `git push` / `--no-verify` — you push it
  yourself. `.git` stays and `origin` is the real remote, so the clone is ready to push as-is.

## Jira fields vs the GitHub PR

The Jira ticket title / type / Affects version / Fix version fields are for the Jira ticket —
they feed the release notes and are transcribed there by the user. Only the **GitHub PR
description** section becomes the PR body.

## OE field rules

- **Fix version sources:** `package.json`, `protected/config/local/common.php` (`'version' => …`), `git describe --tags`, or the user. Always verbatim (`v26.0.0-rc3`, never `26`).
- **Which repo:** `openeyes/openeyes` (PHP/Yii core), `openeyes/IOLMasterImport`, or `openeyes/PayloadProcessor` — only `openeyes` cuts `release/*.x`; state the repo and target branch in Fix version.
- **Migrations are always core** — never "supporting"; load-bearing for the reviewer.
- **`local/common.php` edits are almost never the real change** — module switches belong in `<module>/config/common.php`.

## Gotchas to catch before finalising

- **Clinical-safety invariants** — change touches persistence/calculations/units/display of clinical values without an explicit ask → stop and flag in reviewer notes. The most common OE PR rejection. See `c-oe-coding-standards`.
- **Audit writes** — new clinical CRUD paths need an audit; don't bypass `AuditService`.
- **`core/common.php`** — never edited from a module install.
- **`voiceControl` / `aiSearch`** — stay independent; no runtime dependency between them.
- **`TestHelper`** — never enabled in `OE_MODE=live`; don't loosen the check.
- **`set_frontend_passwords.sh`** — not for sample-DB demos (`admin`/`admin`); keep it out of repro steps.
