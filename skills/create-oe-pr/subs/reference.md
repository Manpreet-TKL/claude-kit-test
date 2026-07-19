# create-oe-pr - the PR.md form, field rules, and gotchas

## PR.md template (verbatim shape)

Two `#` sections - **`# JIRA`** and **`# GITHUB`** - each a set of copy-paste blocks. Text above a `##`/`###` heading is plain `label: value` metadata; under a heading the heading stays OUT of the blockquote and each body is one `> `-quoted block. The GitHub blocks carry the PR prose ONLY - never the live template's tickboxes, emoji headings or Do-No-Harm reminder (the user fills those in by hand after raising).

```
# JIRA

Ticket name:
<release-notes-style title - doubles as the customer-facing release-notes entry and
the GitHub PR title. Generic, outcome-shaped, imperative, under 70 chars, no trailing
punctuation, no client names, no ticket numbers.
  Good: Fix archived patients reappearing in the default worklist after refresh
  Bad:  Fix bug Foo Clinic reported in ticket #1421>

## Description box

Paste everything below into the Jira ticket's description field.

Jira ticket type:
<exactly one of: Bug | New Feature | Improvement | Internal Improvement | Story |
Epic | Regression | EyeDraw Spec - see the table below>

Affects version:
<the version the client is experiencing the problem on, verbatim - e.g. v25.4.1.
Where the symptom manifests, not where the fix lands. If a range, the earliest
confirmed. Blank only for types with no affected install.>

Fix version:
Raised in <version, verbatim - e.g. v26.0.0-rc3>. Repo <openeyes/openeyes or a
satellite>. Target <branch - e.g. release/26.0.x>. Back-port? list both.

### Description
> What the change does and why, plain language, client-agnostic. Lead with the
> user-visible behaviour and the problem it fixes. Always present. Reused verbatim
> as the GitHub Summary.

### Steps to Reproduce
> A generic, **frontend-only** click-path any user can follow without knowing what the
> page does - numbered, **one sentence per step**, each naming the exact control by its
> on-screen label (quoted) and where it sits. Client-agnostic (actor by role, data by
> *kind*, never creds/seed/sample-DB). Start at login if a session is needed; end on an
> observable check. Rules, worked example and special cases live in the **`c-oe-repro`**
> skill - run it if the steps aren't already in this conversation.
> 1. Log in as an administrator (a user with full access).

### Current Outcome
> What actually happens at the end of the steps. One or two lines.

### Expected Outcome
> What should happen instead. One or two lines.

# GITHUB

Apply onto:
<the base branch the patch was cut from + its sha, e.g. release/26.0.x @ a1b2c3d - the
far side branches off its current base and applies `changes.patch` with
`git am -3 --keep-non-patch`>

Commit title:
(the commit message(s) exactly as baked into `changes.patch` mbox Subject lines - listed
here so they can be read without opening the patch. One commit near-always; more entries
only when a split is *very* beneficial (see *Multiple commits*). Every subject is prefixed
`[OE-XXXXX] - ` with the key left as literal X's - the user substitutes the real key at
apply time, and that subject is what auto-updates the ticket. The whole subject line,
prefix included, is <= 72 chars, so the text after `- ` gets <= 59; aim <= 50 total. The
headline-fix commit reuses the Jira title, trimmed to fit. See *Commit titles* below.)

    [OE-XXXXX] - <exact commit message, <= 59 chars>

## Apply & push

(not a paste target - the far-side commands, written for the user's real workflow: the
PR folder is copied to C:/Temp/pullrequests on a Windows machine and applied from Git
Bash inside the checkout. The OE-XXXXX -> real-key substitution is done in VSCode
find/replace directly in changes.patch - never suggest sed - and gets its own comment
line at the top of the block; the checkout commands each get their own line too, never
squashed into one. Branches are normally called fix/OE-XXXXX for bugfixes or
feature/OE-XXXXX for features/improvements; write commands with a sample key, e.g.
fix/OE-12345, for the user to replace with the real one - never bake a real key.
See *Apply & push* below.)

    # in VSCode: find/replace OE-XXXXX -> OE-12345 in C:/Temp/pullrequests/<folder>/changes.patch
    # Go to repo and "git checkout master && git reset --hard && git clean -f && git pull"
    # Below example is for develop as a base branch
    git checkout develop
    git checkout -b fix/OE-12345
    git am -3 --keep-non-patch "C:/Temp/pullrequests/<folder>/changes.patch"
    git log --oneline <base>..HEAD
    git push -u origin HEAD

## PR body

Paste each block into the matching section of the live OE PR template.

### Summary
> Same prose as the Jira Description above - what the change does and why, client-agnostic.

### Scope of Changes

#### Solution
> The approach, named not diffed - the mechanism and the one judgement call that
> mattered (and the rejected alternative, if relevant).

#### Files changed
> One bullet per file: repo-relative path + one sentence on why. Mark (new) and
> (incidental). The change to each path lives in `changes.patch` - this list is the map.
> - protected/models/Patient.php - added a default scope excluding archived rows.

#### Test
> Exactly one of - Test added: <path> (run with `vendor/bin/phpunit <path>`); or
> No test, justification: <paragraph - OK for UI-only/copy/migration with no
> behavioural surface; not "ran out of time", not "this area has no tests">. Note per
> change what covers it.

### Notes for Reviewers
> Simple bullets: edge cases, clinical-safety invariants touched and how handled,
> stack-specific verification that doesn't belong in Steps (cache clears, container
> names), related-but-unfixed occurrences (file:line + recommended approach).
> Skip if genuinely nothing to add.
```

Section shape by type: the Steps/Current/Expected triad fits Bug and Regression; drop it for feature/planning types. Skip lighter sections when the change is self-evident; never pad; if a fault can't be reduced to clean steps (intermittent, data-dependent), say what you can - don't fabricate.

## Steps to Reproduce - owned by `c-oe-repro`

The rules, the worked example, and the special cases (performance/refactor tickets with no repro, client-data-dependent faults, intermittent alerts) now live in the **`c-oe-repro`** skill. If the Steps to Reproduce aren't already in this conversation, run `c-oe-repro` to produce them before assembling the folder, then paste its blockquote into the `## Steps to Reproduce` block. Essentials it enforces: frontend-only, followable blind by someone who has never used the page, client-agnostic (no creds/seed/hospital numbers), plain language (no code), ends on an observable check. Drop the section entirely for types with no user-observable behaviour (performance/internal refactor).

## Jira ticket type - pick exactly one

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

Bug vs Regression: did a prior version behave correctly? Yes -> Regression. Unsure on a client fault -> Regression. Improvement vs Internal: would a clinician notice?

## Commit titles - the `[OE-XXXXX]` prefix and the length cap

Every OE commit subject is prefixed with its Jira key in the form `[OE-XXXXX] - `, e.g.
`[OE-18227] - Clean up temp files created per page in createPdfPreviewImages`. The prefix
is a fixed **13 characters** (`[` + `OE-` + a 5-digit key + `]` + ` - `).

- **The user raises the ticket, not the skill.** The message is baked into `changes.patch`
  with the key left as literal `OE-XXXXX` X's (still 13 chars, so the budget is unchanged) -
  once the ticket exists the user find/replaces the real key into the patch file and
  `git am` creates the commit as them (see *Apply & push*).
- **The whole subject line, prefix included, must fit <= 72 chars** - git's subject wrap and
  where GitHub truncates the commit title. So the text after `- ` gets at most **59 chars**;
  aim for <= 50 total where you can.
- The headline-fix commit reuses the Jira ticket title **trimmed to fit** this budget - the
  Jira title itself can stay fuller (up to ~70 chars for release notes); the commit message
  is the shortened form that survives the prefix + 72-char cap. If trimming loses meaning,
  reword rather than truncate mid-word.
- Every commit in a multi-commit PR carries the same `[OE-XXXXX] - ` prefix and the same cap.

## Multiple commits

**One commit, near-always.** OE PRs are squashed on merge, so a split usually buys nothing
and costs review friction. Split only when it is *very* beneficial - the canonical case is a
bulky mechanical change (a rename, a mass reformat, generated code) that would bury the
behavioural fix if mixed into one commit. Never split by file type, by concern-listing, or
for tidiness: a "command / perf flag / ops parity / test" 4-way split of one logical fix
fails the bar - document the separable concerns in *Solution* instead. Never split a fix
from its proving test; never a commit that won't build alone.

Structurally a multi-commit PR is the SAME deliverable: one `changes.patch` holding N mbox
entries, applied in order by the same single `git am` command. List each subject in the
Commit title block and say which files/hunks belong to each entry.

## Building the patch (how the skill assembles the folder)

The deliverable is a single `changes.patch` in mbox (`git format-patch`) format, not a
clone - tiny to copy away, never pinned to a stale base (the far side applies it onto
whatever the base is *now*), and self-applying: `git am` creates the commit(s) with the
baked-in message(s). One mbox entry per commit, concatenated in the same file:

    From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001
    From: <user.name> <user.email>
    Date: <date -R output>
    Subject: [PATCH] [OE-XXXXX] - <commit title>

    ---
    <unified diff for this commit>

- **Base:** `develop` for anything that isn't a bugfix targeting a release; bugfixes take the
  highest unreleased `release/Y.Z.x` (occasionally an older line for a back-port) -
  `git ls-remote --heads origin 'release/*'`, suggest one, ask when unsure
  (see SKILL.md -> *Base branch*).
  Record it in `PR.md` as `Apply onto: <branch> @ <sha>` (the `git ls-remote` sha). OE repos
  are private, so fetching the base ref relies on the user's configured git auth (askpass / SSH).
- **Headers:** `From:` is the identity the target checkout commits as (`git -C <wc> config
  user.name` / `user.email`) - `git am` takes the commit author from this line, so it must
  be the user's identity, never Claude's. `Date:` from `date -R`. `Subject:` is
  `[PATCH] [OE-XXXXX] - <title>` on ONE line, key left as literal X's - a real Jira key is
  never baked in. The all-zero sha on the `From ` magic line is fine; git ignores it.
- **Diff body** (the skill never commits, so never `git format-patch`): one unified
  `git diff` against the base from a checkout that has the change (`git -C <wc> diff <base>`,
  fetching the base ref first if absent), pasted under the `---` line. Keep the `index ...`
  lines - `git am -3` needs those blob ids for its three-way fallback. New files show
  `new file`, deletions `deleted file`.
- **Slicing a multi-commit patch without committing:** from a worktree at the base, build
  slice 1, `git add -A`, `git diff --cached > slice1`; then for each further slice: build it,
  `git diff > sliceN` (worktree vs index = that slice alone), `git add -A`. Each slice
  becomes the diff body of its own mbox entry, in apply order.
- The headers are ignored by `git apply` (everything before the first `diff --git`), so
  `git apply --check changes.patch` in the target checkout is the cheap validity test - run
  it before delivering, and leave the checkout clean.

## Apply & push (what the user does on the far side - never the skill)

The user's workflow, and the exact shape every PR.md block takes: the PR folder is copied
to `C:/Temp/pullrequests` on a Windows machine and applied from **Git Bash** inside the
checkout - plain commands after a `cd`, no `git -C`, no sed pipe, one action per line.
From a clean checkout:

1. In VSCode, find/replace `OE-XXXXX` with the real Jira key (e.g. `OE-12345`) in
   `C:/Temp/pullrequests/<folder>/changes.patch` - written as a `#` comment line at the
   top of the command block, never as a sed pipe.
2. `cd <checkout>`, `git checkout <base>`, `git checkout -b fix/OE-12345` - one command
   per line, never squashed into a `git switch -c <branch> <base>` one-liner. Branches
   are normally called `fix/OE-XXXXX` (bugfixes) or `feature/OE-XXXXX` (new
   features/improvements), with the real Jira key. Branching after an explicit
   `git checkout <base>` pins the start point rather than trusting wherever HEAD is.
3. `git am -3 --keep-non-patch "C:/Temp/pullrequests/<folder>/changes.patch"` - applies
   the diff AND creates the commit(s), one per mbox entry, authored as the user. Quote
   the path and use forward slashes (Git Bash mangles backslash paths). `-3` degrades a
   moved-on base to ordinary merge-conflict markers; on conflict fix the files, `git add`
   them, `git am --continue` - or `git am --abort` to return to the pristine branch tip.
   An editor that saved the patch with CRLF line endings is harmless - `git am` strips
   the CRs by default.
4. `git log --oneline <base>..HEAD` - the subject(s) must read `[OE-12345] - ...`.
5. `git push -u origin fix/OE-12345`, raise the PR, then move the folder into
   `~/pullrequests/pushed/` (back on the machine where the folder was authored).

**`--keep-non-patch` is load-bearing.** Plain `git am` strips *every* leading `[...]` group
from the subject, so `[PATCH] [OE-12345] - Fix ...` would land as `- Fix ...`;
`--keep-non-patch` (`-b`) strips only the `[PATCH]` marker and keeps the Jira prefix intact.

No-commit fallback: `git apply --3way changes.patch` ignores the mail headers and applies
the diff without committing - useful for inspecting the change in the working tree.

## Jira section vs GitHub section

The two `#` sections are the two paste targets. **`# JIRA`**: `Ticket name` goes in the Jira
ticket's name/summary field; everything in the `## Description box` (type / Affects version /
Fix version + Description + Steps + Current + Expected) pastes into the ticket's description
field. **`# GITHUB`**: each `##`/`###` block pastes into the matching section of the live OE
PR template. The Description is reused verbatim as the Summary. The template's tickboxes, emoji
headings and Do-No-Harm reminder are filled in by hand after raising - the skill never
reproduces that chrome.

## OE field rules

- **Fix version sources:** `package.json`, `protected/config/local/common.php` (`'version' => ...`), `git describe --tags`, or the user. Always verbatim (`v26.0.0-rc3`, never `26`).
- **Which repo:** `openeyes/openeyes` (PHP/Yii core), `openeyes/IOLMasterImport`, or `openeyes/PayloadProcessor` - only `openeyes` cuts `release/*.x`; state the repo and target branch in Fix version.
- **Migrations are always core** - never "supporting"; load-bearing for the reviewer.
- **`local/common.php` edits are almost never the real change** - module switches belong in `<module>/config/common.php`.

## Gotchas to catch before finalising

- **Clinical-safety invariants** - change touches persistence/calculations/units/display of clinical values without an explicit ask -> stop and flag in reviewer notes. The most common OE PR rejection. See `c-oe-coding-standards`.
- **Audit writes** - new clinical CRUD paths need an audit; don't bypass `AuditService`.
- **`core/common.php`** - never edited from a module install.
- **`voiceControl` / `aiSearch`** - stay independent; no runtime dependency between them.
- **`TestHelper`** - never enabled in `OE_MODE=live`; don't loosen the check.
- **`set_frontend_passwords.sh`** - not for sample-DB demos (`admin`/`admin`); keep it out of repro steps.
