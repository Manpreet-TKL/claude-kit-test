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
far side branches off its current base, applies `changes.patch` with `git apply --3way`,
and commits it itself>

Commit title:
(the commit message(s) the user passes to `git commit -m` on the far side - also echoed in
each patch header's `Subject:` line as documentation, but the header never becomes the
commit. One commit near-always; more only when a split is *very* beneficial (see *Multiple
commits*). Every title is prefixed `[OE-XXXXX] - ` with the key left as literal X's - the
user types the real key into the command at apply time, and that commit title is what
auto-updates the ticket. The whole title, prefix included, is <= 72 chars, so the text
after `- ` gets <= 59; aim <= 50 total. The headline-fix commit reuses the Jira title,
trimmed to fit. See *Commit titles* below.)

    [OE-XXXXX] - <exact commit message, <= 59 chars>

## Apply & push

(not a paste target - the far-side commands, written for the user's real workflow: the
PR folder is copied to C:/Temp/pullrequests on a Windows machine and applied from Git
Bash inside the checkout. The patch file is never edited; the OE-XXXXX -> real-key
substitution happens only in the commands (branch name and commit message), noted in a
comment line at the top of the block. Each command gets its own line, never squashed
into one. Branches are normally called fix/OE-XXXXX for bugfixes or feature/OE-XXXXX
for features/improvements; write commands with a sample key, e.g. fix/OE-12345, for
the user to replace with the real one - never bake a real key. See *Apply & push* below.)

    # replace OE-12345 with the real Jira key in the commands below - the patch file needs no editing
    # Go to repo and "git checkout master && git reset --hard && git clean -f && git pull"
    # Below example is for develop as a base branch
    git checkout develop
    git checkout -b fix/OE-12345
    git apply --3way "C:/Temp/pullrequests/<folder>/changes.patch"
    git commit -m "[OE-12345] - <commit title>"
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

- **The user raises the ticket, not the skill.** The title is recorded in `PR.md` and the
  patch header with the key left as literal `OE-XXXXX` X's (still 13 chars, so the budget is
  unchanged) - once the ticket exists the user types the real key into the far-side
  `git commit -m` command; the patch file itself is never edited (see *Apply & push*).
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

Structurally a multi-commit PR is one numbered patch file per commit - `changes-1.patch`,
`changes-2.patch`, ... - each applied and committed in order by its own `git apply --3way`
+ `git commit -m` pair in the Apply & push block. List each title in the Commit title
block and say which files/hunks belong to each file.

## Building the patch (how the skill assembles the folder)

The deliverable is `changes.patch` (one numbered file per commit when split), not a
clone - tiny to copy away, never pinned to a stale base (the far side applies it onto
whatever the base is *now*), and **identity-free**: nothing in the file names an author,
so the far-side commit is indistinguishable from a change the user made and committed
locally. Each file is a plain `git diff` under a short documentation header:

    From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001
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
- **Headers are documentation only** - `git apply` ignores everything before the first
  `diff --git`. **Never write a `From:` line or any name/email**: an author baked into
  the patch would override the applier's own identity, which is exactly what this flow
  avoids (and why `git am` is never used - it refuses to run without one). `Date:` from
  `date -R`. `Subject:` is `[PATCH] [OE-XXXXX] - <title>` on ONE line, key left as
  literal X's - a real Jira key is never baked in. The all-zero sha on the `From ` magic
  line is inert.
- **Diff body** (the skill never commits, so never `git format-patch`): one unified
  `git diff` against the base from a checkout that has the change (`git -C <wc> diff <base>`,
  fetching the base ref first if absent), pasted under the `---` line. Keep the `index ...`
  lines - `git apply --3way` needs those blob ids for its three-way fallback. New files show
  `new file`, deletions `deleted file`.
- **Slicing a multi-commit patch without committing:** from a worktree at the base, build
  slice 1, `git add -A`, `git diff --cached > slice1`; then for each further slice: build it,
  `git diff > sliceN` (worktree vs index = that slice alone), `git add -A`. Each slice
  becomes the diff body of its own numbered patch file, in apply order.
- The headers are ignored by `git apply` (everything before the first `diff --git`), so
  `git apply --check changes.patch` in the target checkout is the cheap validity test - run
  it before delivering, and leave the checkout clean.

## Apply & push (what the user does on the far side - never the skill)

The user's workflow, and the exact shape every PR.md block takes: the PR folder is copied
to `C:/Temp/pullrequests` on a Windows machine and applied from **Git Bash** inside the
checkout - plain commands after a `cd`, no `git -C`, no sed pipe, one action per line.
From a clean checkout:

1. Replace `OE-12345` with the real Jira key **in the commands only** (branch name and
   commit message) - the patch file is never edited.
2. `cd <checkout>`, `git checkout <base>`, `git checkout -b fix/OE-12345` - one command
   per line, never squashed into a `git switch -c <branch> <base>` one-liner. Branches
   are normally called `fix/OE-XXXXX` (bugfixes) or `feature/OE-XXXXX` (new
   features/improvements), with the real Jira key. Branching after an explicit
   `git checkout <base>` pins the start point rather than trusting wherever HEAD is.
3. `git apply --3way "C:/Temp/pullrequests/<folder>/changes.patch"` - applies the diff to
   the working tree AND the index (`--3way` implies `--index`), so the change lands
   staged and ready to commit. Quote the path and use forward slashes (Git Bash mangles
   backslash paths). A moved-on base degrades to ordinary merge-conflict markers; fix
   the files, `git add` them, and carry on - there is no `am` state to abort.
4. `git commit -m "[OE-12345] - <commit title>"` - the commit is created here, on the
   user's machine, with the checkout's own `user.name`/`user.email`, identical to any
   local edit. On a multi-commit PR, repeat the apply + commit pair per numbered patch
   file, in order.
5. `git log --oneline <base>..HEAD` - the subject(s) must read `[OE-12345] - ...`.
6. `git push -u origin fix/OE-12345`, raise the PR, then move the folder into
   `~/pullrequests/pushed/` (back on the machine where the folder was authored).

**`git am` is never used.** It cannot create a commit without an author baked into the
patch (`fatal: empty ident name`), and a baked author is exactly what this flow exists to
avoid: nothing in the folder may carry an identity - or anything else that would make the
result differ from the user modifying the code locally and pushing it themselves.

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
