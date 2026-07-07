# Code history & release mapping - when code landed, when it died, and in which version

How to date a piece of code: the release/branch topology, then `git` archaeology to
find the commit that **introduced** or **dropped** something, then map that commit back
to a **released version**. Generic - works for any symbol, column, file, or call site.
Run it from an up-to-date clone (`git fetch --all --tags` first); `--contains` and
pickaxe only see refs you've actually fetched, so a shallow or partial checkout
under-reports. Repo: `git@github.com:OpenEyes/openeyes.git`.

## The release topology (what a "version" maps to in git)

- **`develop`** - the integration branch and `origin/HEAD`; the canonical "current
  truth". Ask "when was X introduced?" from here unless you specifically want a release
  line's view.
- **`master`** - tracks released code.
- **`release/<maj>.<min>.x`** - one long-lived branch per minor line (e.g.
  `release/26.0.x`, `release/11.0.x`). Fixes flow between `develop` and the active
  release branch (cherry-pick either way); a PR's *Fix version* is which of these it
  targets, its *Affects version* is the earliest **release tag** that already contains
  the offending commit (see mapping below) - this is how you justify those two fields in
  `create-oe-pr`.
- **Tags = versions, but the naming is inconsistent.** You will see `v26.0.0`,
  `v26.0.1`..., RC/pre/alpha suffixes with *mixed casing* (`v26.0.0-RC1`, `v26.0.0-RC2`,
  `v26.0.0-rc3`, both `26.0.0-rc3` and `v26.0.0-rc3`), `v26.1.0-pre1`, `12.0.0-alpha1`.
  The `v` is optional and the `rc` casing varies, so always **filter to release-shaped
  tags case-insensitively and `sort -V`**, never trust raw tag order. (Docker image tags
  lowercase the `rc` - that's a deploy concern, see `c-oe-deploy`.)
- **Commit subjects carry the Jira ref** (`OE-15491 - API endpoints for ...`). Once you
  have the commit you have the ticket - and vice-versa: `git log --grep='OE-15491'`.
- `git describe --tags` tells you where a checkout sits relative to the nearest tag.

## Find when code was INTRODUCED (the earliest occurrence)

- **By content (pickaxe), the workhorse.** `-S` matches commits that change the *number
  of occurrences* of a literal; `--reverse ... | head -1` gives the oldest = the birth:
  ```
  git log --reverse --oneline -S'getFileContents' -- protected/.../AttachmentDisplayController.php | head -1
  git show -s --format='%h %ad %an  %s' --date=short <commit>      # confirm date/ticket
  ```
  Use `-G'<regex>'` instead of `-S` when you want any diff line matching a pattern (catches
  edits/moves that `-S` misses, since a pure move leaves the count unchanged).
- **By file creation:** `git log --diff-filter=A --follow --format='%h %ad %s' --date=short -- <path>`
  (`--follow`/`-M` so a rename doesn't truncate the history).
- **Schema (columns/tables) - the introduction point is the migration, not the model.**
  `grep -rn '<column>' protected/**/migrations/ protected/modules/*/migrations/` finds the
  **creation migration** (e.g. `m181219_152028_init_api_migration.php` created the
  `thumbnail_*_blob` columns as `MEDIUMBLOB NULL`); its `mYYMMDD_...` stamp dates the schema.
- **Line / function granularity:** `git blame -L 80,99 -- <file>` for specific lines;
  `git log -L :<funcName>:<file>` to replay a single function's whole history.

## Find when code was DEPRECATED / DROPPED ("deprecated != deleted")

Two different questions - answer the one you actually mean:

- **The declaration/bytes were removed.** The same pickaxe finds the *removal* too: `git
  log --oneline -S'<literal>' -- <path>` lists add **and** remove; the newest is usually
  the removal - confirm with `git show <commit>` (distinguish a real delete from a move).
  Whole-file deletion: `git log --diff-filter=D --format='%h %ad %s' --date=short -- <path>`.
- **The code still exists but nothing uses it any more** (the common, sneaky case - dead
  columns, ignored params, orphan endpoints). The declaration won't show a removal, so
  **pickaxe the consumer / call site, not the declaration.** The thumbnail columns were
  never deleted; the *read path* was rerouted - found by pickaxing the new reader and the
  old param against the serving controller:
  ```
  git log -S'getFileContents' -- protected/.../AttachmentDisplayController.php   # -> 49ffa052ff, OE-15491, 2024-05-03
  ```
  which showed the commit where `getFileContents()` replaced the old `?attachment=<col>`
  read, i.e. the moment the columns went read-dead.
- **Then prove the *current* state with grep, not git.** Pickaxe finds the *event*; a
  tree-wide grep proves nothing live still touches it today. Search every remaining
  writer/reader and exclude noise (labels, factories, migrations, tests):
  ```
  grep -rnE 'thumbnail_(small|medium|large)_blob' protected --include=*.php \
    | grep -viE "migrations/|/tests/|@property|attributeLabels|'safe'"
  ```
  If that returns only declarations and the dump command clearing them -> confirmed dead.

## Map a commit back to a RELEASE (close the loop)

- **Earliest released version containing it** - filter the noise out (`--contains` returns
  feature/UAT/test tags like `OE-16629-...`, `cera-trials-uat-1`, `*-test` alongside real
  releases):
  ```
  git tag --contains <commit> | grep -iE '^v?[0-9]+\.[0-9]+\.[0-9]+' | sort -V | head -1
  ```
  (`49ffa052ff` -> first release tag `v26.0.0-rc3`, so the reroute shipped on the v26.0
  line.)
- **Which lines carry it:** `git branch -r --contains <commit>` (develop / master /
  release/*). **Caveat:** only as complete as your fetched refs - `git fetch --all --tags`
  first or it silently under-reports.
- `git describe --contains <commit>` names the first tag *after* a commit.

## Worked example (the pattern end to end)

`thumbnail_*_blob` columns: **introduced** 2018-12-19 by creation migration
`m181219_152028_init_api_migration.php` (grep + migration stamp); **read-deprecated**
2024-05-03 by `49ffa052ff` / OE-15491 (pickaxe the consumer controller), which `git tag
--contains` places in `v26.0.0`; **confirmed dead today** by a tree-wide grep showing no
live writer or reader. Three tools, one per question: grep/migration for birth, pickaxe
the call site for death, `tag --contains` for the version.

## Gotchas

- `-S` counts occurrences (misses pure moves); `-G` matches any diff line (use for "last
  modified"). Renames need `--follow` / `-M` or history stops at the rename.
- Run introduction searches from `develop` (or add `--all`) - a PR/feature branch's
  ancestry may not contain the real first occurrence.
- Tag naming is genuinely inconsistent (casing, optional `v`, `-rc`/`-RC`/`-pre`/`-alpha`):
  always `sort -V` and match case-insensitively; never eyeball tag order.
