# OpenEyes cleardown: establishing versions and verifying them (2026-07)

The harness half of the cleardown work - how to know which OE version a database
is, how to rebuild each version, and how to verify a seed without fooling
yourself. The keep/clear policy itself is in
`knowledge/oe-cleardown-policy.md`. Most of this generalises to any
multi-version OE job, not just cleardown.

Supported set: `release/10.0.x` (v10), `release/11.0.x` (v11),
`release/26.0.x` (v26.0), `develop` (v26.1, unreleased). One config file per
version, auto-selected. New tables per version are guaranteed; deprecations are
rare. Everything below was measured against those four branches rebuilt from their
own sample dumps, on MariaDB 11.8 and PHP 8.4 - both versions matter, and section 3
says why.

## 1. Establish a version by rebuilding it; never by inspecting the database in front of you

Considerable time went into forensically deducing an OE version from a populated
database's table set and `tbl_migration` contents. Wrong instrument, and it
misleads in both directions:

- `protected/version.txt` is `3.0` on **all four** branches - it identifies
  nothing. `OE_VERSION` is unset in dev images (it *is* set in oe-deploy prod
  images, which is what makes a command self-configuring there).
- `m26*`-dated migrations are **not** evidence of a 26.x branch. v10 still
  receives dated migrations, so `release/10.0.x` legitimately carries names like
  `m260313_125620`.
- Migration timestamps are **not** branch-ordered, so "highest `apply_time`" is
  not a version. Any migration-based probe must be pure *set membership* against a
  sentinel that is a floor for its version.
- **Module repos carry their own migrations.** A sentinel derived from the core
  repo's history alone is computed from an incomplete set - the three "obvious"
  sentinels picked that way existed in **no** repo in the checkout.

The only source of truth: check the sample module out to the branch
(`oec <branch>` = `/oe-checkout.sh`, which moves core and all ~42 module repos)
and rebuild (`oe-reset.sh`, which imports `$MODULEROOT/sample/sql/` from whatever
branch the sample module is on and runs migrations itself). Each version is an
independent, self-contained rebuild - no ascending-order constraint. Both `oec`
and `oemig` are aliases in `/etc/profile.d`, so they need a **login** shell:
`docker exec -i <web> bash -lc '...'`.

This also cost a wrong conclusion in the other direction. The v10 config was
declared "incomplete - 27 unclassified, 118-table census gap" on the evidence of
whatever database happened to be loaded. Against a genuine `oec release/10.0.x`
rebuild (2218 base tables) the same config reports **0 unclassified, 0 census
drift** and needed two already-auto-classified tables added. The 27 belonged to a
newer schema someone had restored into that instance. **Never characterise a
config against a database of unverified provenance.**

### Identifying a dump you were handed: compare it to the artifacts, do not restore it

No contradiction with the rule above - the *comparator* still comes from a rebuild.
Once `<v>.schema.tsv` and `<v>.migrations.txt` exist for every version, the version
of an arbitrary dump is three ~1s host passes over the file, with no database
touched and nothing overwritten:

| Probe | Measured on a 252 MB template dump | Verdict |
|---|---|---|
| `^CREATE TABLE ` names vs `cut -f1 <v>.schema.tsv` | 2218 tables, 0 either direction vs v10 | exact |
| `(table, column)` pairs vs `cut -f1,2 <v>.schema.tsv` | 23150 pairs, 0 either direction vs v10 | exact |
| the dump's own `tbl_migration` vs each version's sentinel | only v10's sentinel present | v10 |

Order matters. The table set narrows it; the **column** set is the one that decides,
because the command's surgery SQL names columns, not tables; the sentinel check
predicts what the resolver will pick unaided, which is the thing you are about to
rely on.

Two things this catches that a table-set check alone cannot:

- The dump was **3 migrations behind** the branch tip and still schema-identical,
  because none of the three creates a table. "Fewer migrations" is not "different
  schema" - and conversely, a create-table migration is the only kind a census diff
  can see, which is exactly why sentinels are chosen from that kind (section 2).
- Views are outside all three probes (the command classifies them `W` and skips
  them), and one of those three missing migrations rebuilt a view. Counting
  `^CREATE TABLE ` matched the base-table census exactly, so view placeholders did
  not inflate it, but "schema-identical" here means base tables and their columns.

`tbl_migration` in a mysqldump has its `INSERT INTO ... VALUES` header on its own
line with the tuples on following lines, so a one-line regex returns nothing - the
section 9 trap. Extract from the header to the terminating `;`.

## 2. Sentinel migrations: create-table, low end of the delta, verified forward

Sentinels came out of set-differencing four `tbl_migration` snapshots. Two facts
only the empirical route reveals:

- **The sets are not cleanly nested.** 4 migrations exist on `release/26.0.x` and
  not on `develop` - release-branch work not yet forward-merged. A max-`apply_time`
  scheme would have resolved `develop` to v26.0 on those 4 rows alone.
- **Timestamps say nothing about branch order.** The v11 delta contains migrations
  dated `m2412*` through `m2606*`.

So each sentinel is a migration that **creates a table** (independently visible as
a census delta, and never reverted on a release branch), taken from the **low end**
of its version's delta, and confirmed present in every later snapshot. The four
that were derived that way, since re-deriving them costs four rebuilds:

| Version | Branch | Sentinel migration |
|---|---|---|
| v10 | `release/10.0.x` | `m250922_120000_create_sso_config_institution_mapping` |
| v11 | `release/11.0.x` | `m250429_135745_create_event_export_file_drops_table` |
| v26.0 | `release/26.0.x` | `m251020_131341_add_webhooks_subscribers_tables` |
| v26.1 | `develop` | `m260508_140514_create_referral_table` |

Resolution
order in the command: explicit `--configVersion=` (trusted verbatim), then
`OE_VERSION`/`params['oe_version']` when it is a real version, then the sentinel
probe (highest matching version wins by set membership), then **hard abort exit
8** printing the three ways to disambiguate. A silent fallback to the oldest
config is the one outcome that manufactures a wrong keep.

## 3. `oereset --demo` is broken on any branch whose dump was regenerated past a destructive migration

On `release/26.0.x` and `develop`, `oe-reset.sh --demo` aborts before migrations
run:

```
ERROR 1054 (42S22) at line 9: Unknown column 'date_start' in 'INSERT INTO'
```

`protected/migrations/m260312_135924_remove_start_and_end_dates_from_address.php`
drops `address.date_start`/`date_end`, but the demo fixture
`modules/sample/sql/demo/pre-migrate/51-SetupCCGandLA.sql` still inserts into
them. Demo scripts run **pre**-migrate, so the outcome depends entirely on the
vintage of the shipped `sample_db.zip`:

| Branch | Dump vintage vs m260312 | `--demo` |
|---|---|---|
| `release/10.0.x`, `release/11.0.x` | older, columns still present at pre-migrate | works |
| `release/26.0.x`, `develop` | regenerated after, columns already gone | **aborts** |

The abort leaves a half-built database: dump imported, pre-migrate partially
applied, **migrations never run**. It exits 1. Do not confuse it with the benign
`vite: not found` tail, which happens *after* a successful import and only fails
the asset build. Anything captured from the aborted state is worthless, including
a `--writeKnown` census written from it.

Workaround for census work: plain `oe-reset.sh` (no `--demo`) skips the demo
fixtures and still runs migrations, so the table set is correct - only demo
*content* (worklists, booking sessions, CCG/LA fixtures) is missing. The real fix
is a two-line edit to `51-SetupCCGandLA.sql` in the sample module.

### The two-line fix, applied and verified 2026-07-27

Drop the two columns from the insert's column list and the matching `NULL,NULL`
from its `VALUES`, leaving `address_type_id` in place:

```sql
INSERT INTO address (address1,address2,city,postcode,county,country_id,contact_id,address_type_id) VALUES
	 ('12 The street','','Trumpton Town','TR1 1AN','Essex',1,@contact_id,3);
```

On `develop` that took `--demo` all the way through migrate, post-migrate and the
asset build, ending with 2226 migrations, 2284 patients, 6954 events, 29 users -
a fully migrated sample, which is the state every "is this table empty?" question
has to be asked against.

Two things make the edit safe to do in the container rather than in a checkout.
The web repo lives **inside the image** (`/var/www/openeyes` is not a bind mount),
so it touches no git working tree; and `oe-reset.sh` only re-runs `oe-checkout.sh`
when a branch is passed or `modules/sample/sql` is missing, so an unqualified
`oe-reset.sh --demo` will not overwrite it. Pass a branch and the fix is gone.
Keep a `.orig` beside it so the delta is recoverable, and re-apply after any
checkout.

### `--clean-base` cannot work - OE has no migrate-from-clean path

`oe-reset.sh --clean-base` ("Do not import sample data - migrate from clean db
instead") reads like the way to build the database a genuine install has. It is
not, and the last of its three barriers is structural rather than environmental.
Measured on `release/10.0.x`, each one only visible after clearing the one before:

1. **The script cannot reach its own migrate step.** It forces the institution code
   with `SELECT id FROM institution` *before* migrations run, so on an empty
   database that is error 1146 and the abort trap fires. Bypassable by building the
   clean base by hand - drop, create, re-grant the app user with the reset script's
   own grant list, then `yiic migrate --all --interactive=0`.
2. **PHP 8.4 kills the first migration.** The 2013 base consolidation seeds CSV data
   through `OEMigration::initialiseData`, whose `fgetcsv($fh)` raises "the $escape
   parameter must be provided", and Yii 1.x escalates any error inside
   `error_reporting()` into a fatal. Bypassable with `php -d error_reporting=24575`
   (`E_ALL & ~E_DEPRECATED`) - a run-time mask, no repo change.
3. **The historical migrations no longer form a replayable sequence.** The same base
   migration seeds `address` rows with empty `date_start`/`date_end`, which
   MariaDB 11.8 strict mode rejects (1292) - bypassable by relaxing `sql_mode` for
   the migrate. Behind that, `OphTrIntravitrealinjection`'s
   `m131010_074031_allergy_checking` creates a table with an FK to
   **`archive_allergy`**, a name that only came into existence years later when
   `allergy` was renamed. The old migration was edited to the new name, so from
   clean it references a table that does not yet exist. **Not bypassable** without
   patching historical migrations, and there is no reason to think it is the last
   one: 696 core migrations plus module migrations, 13 years, and this path is
   exercised by nobody.

The conclusion is the useful part: **a real OpenEyes install is a shipped base dump
plus forward migrations, never a migrate from zero.** So "what does a genuine
install contain" is answered by importing the base dump *without* the demo fixtures
(plain `oe-reset.sh`), not by `--clean-base` - see the policy file, section 11. Do
not spend a day making from-clean work; it is broken by design decisions taken over
a decade, not by this environment.

## 4. The per-release workflow, and the artifacts that make the next one cheap

Adding a version is: rebuild it, capture its artifacts, classify the delta, verify
the three scenarios. **One ordering constraint, and it is easy to lose an
afternoon to:** run the plain classification report and keep its output *before*
refreshing the census. The census refresh (`report --writeKnown=1`) rewrites the
config's generated census block, and the `NEW / REMOVED since config census`
section of the report **is** the per-version work list. Refresh first and the work
list is gone - the report then agrees with itself and tells you nothing.

Per version, in a login shell, capture these before anything is edited:

| Artifact | How |
|---|---|
| `<v>.branches.txt` | branch of core and of every module repo |
| `<v>.report.txt` | the classification report, **pre**-census-refresh |
| `<v>.schema.tsv` | every column of every `BASE TABLE` |
| `<v>.migrations.txt` | `SELECT version FROM tbl_migration ORDER BY version` |
| `<v>.fkedges.tsv` | FK edges, both ends `BASE TABLE`, with nullability (section 8) |
| `<v>.views.txt` | `TABLES WHERE TABLE_TYPE != 'BASE TABLE'` |

Write them to the bind-backed commands directory so they land on the host with no
copy-out step. The schema query, which is the one worth not re-deriving:

```sql
SELECT t.TABLE_NAME, c.COLUMN_NAME, c.COLUMN_TYPE, c.IS_NULLABLE, c.COLUMN_KEY FROM information_schema.TABLES t JOIN information_schema.COLUMNS c ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_TYPE = 'BASE TABLE' ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION
```

Then: classify the delta (evidence per table, not guesses - see the policy file),
refresh the census, run the static drift gate (section 11), and only then the
scenarios. Base-table counts for the four rebuilds, as a sanity check that a
rebuild actually took: **2218** (v10), **2231** (v11), **2330** (v26.0), **2348**
(v26.1). FK edge counts on the same rebuilds: 4145 / 4303 / 4346 for v11 / v26.0 /
v26.1, 57 views on each.

Three harness scripts carry this, and all are worth rebuilding if lost:

1. **Sample-side scenario suite** - per version: check out the branch, deploy the
   working copy, then for each of the three profiles reset the sample database, run
   the cleardown, run a **mode-matched** verify, drive a real login, and record the
   headline row counts. Finishes with a scenario-2-vs-3 diff and a second blank run
   for idempotence, and prints a per-version completion marker other tooling can
   wait on.
2. **Client-side acceptance** - the same three scenarios against a restored client
   dump, with **no** version flag passed, so the sentinel resolver has to pick the
   config unaided and you find out whether it does. It counts every kept table
   before and after the keep-config run, and *that count is the point*: a table
   empty on a sample database **and** on a real client database is a keep nobody can
   justify, and a kept table whose count drops across the run is a keep that did not
   hold.
3. **Base-vs-blank audit** - the only harness that tests **keeps** rather than
   clears: reset **without** `--demo`, count every table, cleardown, count again,
   diff tagged by category. Chunk the counting 250 tables per `UNION ALL` query.
   Any kept table that loses rows is either explained or a bug. See the policy
   file, section 11, for the v10 result.

`verify` is 7 checks, mode-aware, and refuses with **exit 8** rather than guessing
- the same exit the unresolvable-version and unclassified-table paths use. Treat
exit 8 as "the command declined to act", never as a failure to work around.

## 5. The verification loop, and what "green" is allowed to mean

Reset-to-sample -> `report` -> `cleardown` -> `verify` -> **log in** -> repeat. The
report's zero-unclassified gate and verify's checks are cheap and catch the
DB-shaped problems; the **login** at each stage caught three runtime invariants no
DB assertion would have (see the policy file, section 15). A green `verify` is
necessary and **not sufficient** - two of the three login invariants only ever
appeared as a runtime 500.

Per version the suite runs all three profiles, each with a mode-matched verify and
a real login, then a second blank run to prove idempotence (all-zero deletes,
verify still passes). Two cross-checks that earn their place:

- **Scenario 2 vs 3 headline counts must differ only in `user`/`contact`.** Any
  other config count that drops means config was deleted rather than re-owned.
- **A per-version count difference is not automatically a bug - find the
  migration.** `setting_institution` is 41 on v10 scenario 2 but 1 on v11, which
  looks alarming until you find the v11-only
  `m250714_091256_remove_duplicate_correspondence_setting_overrides`. Resolve every
  cross-version delta to a named migration before treating it as either a bug or a
  non-event.

Headless login must post `LoginForm[institution_id]` and `[site_id]` - they are
JS-populated hidden inputs, blank on a raw GET, and login rejects "Site Id cannot
be blank" without them.

## 6. Driving a long multi-version suite

Four rebuild-and-verify passes take hours, so the harness rules matter more than
usual:

- **Bash reads a running script incrementally.** Editing a `.sh` file while it
  executes changes what the *running* process does next. Never touch the suite
  script or a watcher mid-run.
- **A suite that deploys the working copy at start freezes your edit window.** The
  runner copies the command + config into place per version, so a host edit made
  mid-run silently changes what the *next* version's suite tests. Batch edits to
  between runs and say so out loud.
- **The `Write` tool does not set the execute bit** - a freshly written script
  exits 126. `chmod +x` it or invoke it as `bash <script>`.
- **`until ! pgrep -f 'thing'` never exits** - the waiting shell matches itself,
  because the pattern is an argument of the process running the loop. It spins
  forever and the driver behind it looks hung. Either match a container-side
  process (`docker exec ... pgrep`), bracket a character (`[o]e-reset.sh`), or
  better, **wait on the artifact the job writes** rather than a process name.
  The bracket trick is weaker than it looks: it disguises only the *pattern*, so
  any other plain mention of the name in the same command line re-arms the
  self-match. A waiter written as
  `while pgrep -f 'accept-pptes[t].sh'; do sleep 30; done; echo "=== accept-pptest.sh exited"`
  matches itself on the **echo text** and never fires - and the same goes for a
  closing `tail` of a log named after the job. `while kill -0 <pid>` cannot
  self-match at all and needs no pattern; capture the PID at launch and wait on
  that.
- Wait on the log marker the suite itself prints, not on wall-clock guesses.

## 7. Instrumenting a running suite: seconds-long windows, so use seconds-long probes

Capturing per-version schema facts *while that version is up* looks easy and is
not. PHP boot plus plan building for a `report` run is ~40s; the gaps between a
suite's own DB operations are seconds. Two failures before the working approach:
a `report` fired mid-suite landed inside an `oereset` and got
`CDbException: Access denied for user 'openeyes'@'%'`; the retry was killed by the
next branch checkout after 82 bytes.

What works: two ~1s `information_schema` queries, triggered on the suite's own log
line for that version's verify window (the one point where the database is
guaranteed up and idle), then gate on the suite's completion marker before moving
to the next version.

```bash
db() { docker exec -i <db> sh -c 'mariadb -uroot -p"$(cat /run/secrets/MYSQL_ROOT_PASSWORD)" openeyes -N -B -e "$1"' _ "$1"; }
while ! grep -q 'Verifying' "${log}"; do sleep 10; done          # DB up, nothing resetting
db "${fk_sql}" > "${out}/${v}.fkedges.tsv"
while ! grep -q "SCENARIOS VERIFIED: ${v}" "${log}"; do sleep 10; done   # do not re-fire
```

Anything captured during a reset window is untrustworthy and should be deleted
rather than reconciled.

## 8. Replay the runtime guard offline instead of buying four more live runs

The runtime keep-guard can only see the schema that is live. Rather than four more
full runs, capture four facts per version and replay the guard's logic in a
throwaway script:

| Fact | Source |
|---|---|
| columns per table | `information_schema.COLUMNS` dump (`<v>.schema.tsv`) |
| FK edges, both ends `BASE TABLE`, with nullability | `KEY_COLUMN_USAGE` joined to `COLUMNS` + `TABLES` |
| view list | `TABLES WHERE TABLE_TYPE != 'BASE TABLE'` |
| flattened policy | a `dump-policy.php` that replays `classify()`'s tier order to `table -> code` |

**The validation contract is the whole point.** The replay must first reproduce a
measurement taken live from the real command on one version. If it does not, the
replay is wrong, not the command. Write that contract into the script's docstring
so the next reader cannot skip it. Once it holds, the replay answers "would this
version abort, and on what" for every version in milliseconds, including versions
whose schema is not currently checked out.

## 9. Trust a probe only after proving it can return a positive

Two instances of the same failure, and it is the nastiest class of bug in this kind
of work, because **a null-returning probe reads exactly like evidence**:

- An evidence field's `created_by_migration` searched for `createTable('<name>'` on
  one line and returned `null` for every table - which reads as "no migration
  creates this", a fact a classifier will happily reason from. OE actually uses
  `createOETable(` with the table name on the **following** line, and generates the
  `_version` twin implicitly with no migration of its own.
- A `mysqldump` parser matched `INSERT INTO \`t\` VALUES <tuples>` on one line and
  reported zero references into a table from every referrer. This dump puts the
  `INSERT INTO ... VALUES` header on its own line with tuples on the lines after,
  so every count came back 0 - indistinguishable from "nothing references it",
  which was the exact question being asked. Fixed with a tuple tokenizer whose
  quote/escape/depth state survives across lines.

- A completion monitor read a *previous* run's log (`/tmp/scen4.<v>.log`) for the
  "finished" marker while counting the *current* run's artifacts file, so it
  announced `v26.0 suite FINISHED - 0 verify passed, 0 failed, 0 logins OK` while
  that suite was still in its branch checkout. Both halves were true of the file
  they came from; the pairing was the lie. Key every input of a probe to the same
  run, and note that a suite truncates its artifacts file at start - which is
  exactly what a stale trigger reads as "finished, and it found nothing". Prefer a
  trigger the current run *writes*: a monitor keyed on the chain's own summary file
  cannot fire before the version it reports on has exited.

Rule: verify every new probe against a case you have independently confirmed by
hand, and prefer a probe that can be checked against a known non-zero count,
*before* letting it inform a decision. When a sweep returns all-zero, suspect the
sweep first - whether it reports that as silence or as success.

## 10. When two copies of a command disagree, decide by content

The deployed copy and the working copy diverged, and mtimes pointed one way while
content pointed the other. The host copy was newer by mtime but smaller, and its
function set was a **strict subset** - zero functions existed only there, while the
deployed copy added whole documented features. All four host files also shared an
identical to-the-second mtime, which reads as a batch copy or extract rather than
authorship. Decide by function-set containment and by which copy matches the
documented end-state, never by timestamps, and confirm the baseline with the human
before building on it.

## 11. A static drift gate cannot see the dynamic tiers - say so in the severity

`policyDiff` compares the four config files with no database, so it cannot walk the
FK-lineage tier. Every `patient_*`/`event_*` table therefore looks "uncovered" to
it: 205 errors across four files, all false, on configs `report` classifies with
zero unknowns. As an error that made the gate unusable on its first run. It is now
a warning named "not statically covered", and the three checks that **are** fully
static - category conflict, missing policy, intra-file duplicate - stay errors. A
gate that fires on what it cannot determine trains you to ignore it, which costs
you the findings it can prove.

Findings the gate does own, given four near-identical files whose drift is
otherwise silent (an entry for a table absent from the live schema is structurally
inert - no SQL error, no wrong result, and no warning either):

| Finding | Condition | Severity |
|---|---|---|
| category conflict | table categorised differently in two files | error |
| missing policy | policy in A, absent in B, table in **both** censuses | error |
| intra-file duplicate | one table in two lists in one file | error |
| not statically covered | no policy entry and no static rule would catch it | warning |
| version-scoped | absent from B's policy **and** B's census | count only |
| orphaned entry | in a policy, in no census | warning |

The state that gate should be in once four files are genuinely aligned: **0 errors,
0 orphaned entries, and a small version-scoped count** - 9 across these four, being
the referral and RTT tables `develop` replaced. Any orphaned entry is a name that
has changed under you, and a version-scoped count that grows without a named
migration behind it is drift wearing the expected label.

## 12. Container and authoring traps

- **`/extra_commands` is a named volume that is bind-backed.**
  `docker volume inspect <instance>_commands` shows
  `driver_opts: device=~/<instance>/commands, o=bind`, so that host directory *is*
  the volume: host edits are visible in the container immediately and `docker cp`
  is needed in neither direction.
- **`php` is not on the host** - lint through the container:
  `docker exec -i <web> php -l < ~/cleardown/CleardownCommand.php`.
- **`docker exec -i` inside a `while read` loop eats the loop's input.** The `-i`
  says "attach stdin", and the loop's stdin is the list being read, so the first
  call swallows the remainder and the loop ends after one iteration. A per-table
  census batching 150 tables per query stopped at exactly 150 rows of 411 and
  reported `counted: 150 of 411` on a schema where all 411 were present - the
  truncation landed mid-list, so the tail of the policy (every `adminConfig`
  entry) was silently never counted, and the "lost rows" comparison built from it
  returned an empty list that read as a pass. Redirect every such call:
  `docker exec -i ... </dev/null`. Two-line proof, worth running once on any host
  you doubt: `while read -r x; do echo "$x"; docker exec -i <c> true; done < <(printf 'a\nb\nc\n')`
  prints only `a`, and the same loop with `</dev/null` prints all three. `ssh`
  without `-n` and `mysql` reading a script have the identical shape.
- **`oph*`/`et_*` in a PHP docblock closes the comment.** The literal `*/` inside
  `et_*/` ends the docblock early and produces a parse error ~80 lines later. Space
  it (`oph* / et_*`) in comments.
- **Flexible heredocs need at least 8-space indentation on every line**, including
  interpolated placeholders. A token at column 0 triggers "Invalid body
  indentation level". Put a `%TOKEN%` at the right indent and `str_replace` it
  after the heredoc.
- **`init()` is a reserved public method on `CConsoleCommand`.** Naming a private
  helper `init()` gives a silent EXIT=255 ("Access level must be public"). Use
  `bootstrap()`.
- **A `--writeKnown`-style census writer must rewrite the *selected* config file**,
  not a hardcoded filename, and log the `basename()` so the operator sees which of
  four files was rewritten.
