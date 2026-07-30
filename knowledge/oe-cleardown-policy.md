# OpenEyes cleardown: what to keep and what to clear (2026-07)

Design knowledge from building and then multi-versioning `cleardown` - the yiic
command (`CleardownCommand.php` + one `cleardown.config.<version>.php` per OE
version) that turns a populated SAMPLE OpenEyes database into a bootable SEED.
Read before changing any keep/clear decision. The harness, version detection and
verification side is in `knowledge/oe-cleardown-versions.md`.

Three profiles are served by one policy:

| Profile | Flags | Result |
|---|---|---|
| Blank seed | none | critical system data only, no patients, no client config |
| Keep-config | `--keepConfig=1` | client's admin-page config kept, fake patients stripped, users and orgs kept |
| Trainer template | `--keepConfig=1 --clearUsers=1` | same config, re-owned to admin, sample accounts gone |

## 1. The keep/clear asymmetry is the whole design

A wrong **clear** is recoverable - re-run from the pristine sample. A wrong
**keep** silently ships sample patient data into a "blank" seed and nobody
notices until it is in production. The two failure modes are not symmetric, so
the rules are not either:

- **Keep is only ever explicit** - an allow-list entry (`keepSystem` /
  `keepReference`) or a structural fact (it is a view; it is an identity table
  with a row-rule). Nothing is kept because of a naming prefix.
- **Prefixes can only push toward clear** (`oph*`, `et_*`, `*_version`, `audit*`).
- **Anything unmatched aborts.** Not "assume clear" (would silently drop a new
  national lookup), not "assume keep" (would leak). Stop and make a human
  classify it.

When in doubt the safe default is *abort*, then *clear*, never *keep*. This one
principle resolves almost every "what should this table do" question, and every
guard below is an application of it.

## 2. Default-deny on a flat list is a maintenance trap; default-deny on rules is not

The predecessor listed every one of ~2275 tables in `protected`/`cleardown` and
aborted if a table appeared in neither. Every release broke it. The fix was not
to drop the abort - the abort is the safety property worth keeping - it was to
make the **bulk** classify by rule so ~1800 tables need zero per-release work and
only a genuinely novel *no-prefix, non-clinical* table reaches the abort.
First match wins:

| Tier | Rule | Code |
|---|---|---|
| 0 | is a view | `W` |
| 1 | `rowRules` (identity tables needing row surgery) | `I` |
| 2 | `keepSystem` | `S` |
| 3 | `keepReference` | `R` |
| 4 | ephemeral name (session / log / cache / queue) | `E` |
| 5 | `*_version` | `V` |
| 6 | `adminConfig` | `A` |
| 7 | `oph*` / `et_*` name | `P` |
| 8 | `clearData` map, verbatim | as mapped |
| 9 | FK lineage down from patient/episode/event | `P` |
| 10 | nothing matched | `?` -> **hard abort** |

Honest cost: a few lines of config per release, not zero. Tiers 0, 4, 5, 7 and 9
are pure-auto and carry the bulk of the schema; only a genuinely novel
no-prefix, non-clinical table reaches tier 10.

| Code | Name | End-state |
|---|---|---|
| `S` | System | structural substrate, **kept whole** (lookups, RBAC, settings schema, migrations) |
| `R` | Reference | national ontology, **kept whole** (dm+d, ICD/SNOMED, OPCS, country, language, national institutions) |
| `I` | Identity | row-level: keep seed/system rows, **neutralise and prune** the rest (user, contact, person, address, institution, site, firm) |
| `P` | Patient | patient/clinical data, **cleared** |
| `C` | Config | client/admin-page config under an ordinary name, **cleared**, kept by `--keepConfig` |
| `A` | AdminCfg | admin-page config carrying an `oph*` / `et_*` name, **cleared**, kept by `--keepConfig` |
| `V` | Version | `*_version` history, **cleared** (auto) |
| `E` | Ephemeral | audit / log / session, **cleared** (auto) |
| `W` | vieW | database view, **never touched** (auto) |
| `?` | unknown | matched no rule -> **hard abort** until classified |

`audit` rows are cleared **by design** - this is a maintenance command, not app
code, and the audit trail of a sample database is sample data. Do not "fix" that.

## 3. Derive structure live from `information_schema`, hard-code only policy

FK edges, nullability, the user-FK column set, contact referrers, kept-user ids
(by username), the firm with a subspecialty - all resolved live each run. Only
*policy* is hard-coded: which usernames are system users, which institutions are
national, the floor ids 1/1. That is why the engine survives schema changes.
Hard-coding the graph would rot exactly the way the flat list did.

Any live FK walk must join **both** constraint ends to
`information_schema.TABLES` (`BASE TABLE`): the sample schema carries orphaned
constraints (to a non-existent `archive_allergy`) and an unfiltered walk fatals.

## 4. OE's own config exporter is the authority on "admin config" - keys are half of it

`export_config_v1000.php` (25010 lines) is the definition OE itself uses to
export a site's admin configuration. Read naively it yields 246 `table_name`
entries. That count is wrong in the dangerous direction: **a table's scoping
children are not `table_name` entries, they are `LEFT JOIN`ed into the parent's
`export_query`.** Line 5377 exports `letter_macros` and joins
`ophcocorrespondence_letter_macro_firm`, `_site`, `_institution` and
`_subspecialty` - none of which appears as a key anywhere. Take the keys only and
`--keepConfig` keeps every letter macro while silently discarding which firm,
site, institution and subspecialty each belongs to: 1926 rows on a v10 sample,
and config that looks intact until someone opens the macro list.

The authority is every table the exporter **touches** - keys plus join targets -
which is 228 tables, identical on all four versions: 165 `oph*`/`et_*` tables the
entries are keyed on plus a further 63 reached only through an `export_query`
join. `rescueKeptDependencies()` does not save you here by design: it keeps NOT
NULL FK *parents* of kept tables, and scoping rows are *children*.

One deliberate exclusion from that 228:
`ophtroperationbooking_operation_session`, whose admin tab is called "Sessions"
but whose rows are dated theatre slots a seed must not carry. Being in the
exporter is a strong signal, not a rule.

The forward mechanism for the next release is `report --verbose=1`, which lists
the **candidates**: tables tier 7 tags `P` that are nevertheless lookup-shaped (no
descent from patient/episode/event, no patient-shaped id column). 241 on v10.
Each is cleared by `--keepConfig` today; check the admin pages and promote the
ones a client actually configures.

`depends_on` in the exporter is **section** names (`'institutions'`,
`'disorders'`), not table names, and resolves back to entries already keyed. Keys
plus `LEFT JOIN` targets is the complete set - checked once so it stops being an
open question.

### OE ships its own cleardown too, and it is a second oracle

`modules/sample/sql/cleardown/` holds `run_cleardown.sh` plus 13 `base_scripts`
(always run) and 3 `additional_scripts` (opt-in behind `--delete-meds-data`,
`--delete-pds-data`, `--delete-admin-config`). It is a DELETE-list design, so it
is **not** authoritative about keeps: anything it fails to name simply survives,
including every table added since it was written. But it is an independent
statement of intent from the people who ship the schema, and reading it the two
useful ways costs nothing:

- **LEAK?** a table its base scripts always delete that the policy **keeps**.
  This is how the `request*` family was caught - `80-delete-patients.sql`
  deletes all five unscoped, immediately before `DELETE FROM patient`.
- **GAP?** a table only `admin-config.sql` deletes - i.e. configuration it
  otherwise preserves - that `--keepConfig` does **not** keep. Each one is
  client admin-page configuration that the keep-config scenario would destroy.

Read the *statements*, not the table names. Many of those DELETEs are scoped
(`WHERE institution_id <> 1`, `WHERE userid IN (SELECT id FROM tmp_users)`), and
a name-only extraction reports them as whole-table clears and manufactures
conflicts that are not there.

## 5. An `oph*`/`et_*` name means "clinical module", not "clinical data"

Tier 7 was clearing 165 tables OE's own exporter calls configuration. Hence
category `A` (adminConfig): an explicit list consulted **before** the name rule,
cleared by default and kept by `--keepConfig` exactly like `C`. Explicit list,
not a smarter pattern - the prefixes cannot distinguish
`ophciexamination_advice_leaflet` from `et_ophciexamination_visualacuity`, and a
pattern that tries will eventually keep an element table.

Because the list is a keep it is mechanically guarded, not trusted.
`assertAdminConfigSafe()` runs before any statement and aborts (exit 8) if a
listed table descends from patient/episode/event, has an FK to
`contact`/`person`/`address`, or carries a
`patient_id`/`episode_id`/`event_id`/`element_id` column. Proven by injection:
adding `et_ophciexamination_visualacuity` to the list produced
`refusing to run: - et_ophciexamination_visualacuity - descends from patient/episode/event`.

Two scope notes on that guard:

- **The `contact`/`person`/`address` test is `adminConfig`-only.** `gp`,
  `practice`, `commissioning_body` and `contact_location` legitimately reference
  professional contacts, and the contact surgery already keeps exactly the contacts
  a surviving table points at, so applying the test to every kept table would abort
  on correct policy.
- **A table that trips the guard is not necessarily misfiled - it may be mixed.**
  Part configuration, part clinical, the way `contact` is (section 9). Mixed tables
  belong in `rowRules` for row-level surgery, never in a whole-table keep, and the
  abort message says so rather than guessing a category.

## 6. Fixing the name tier does not fix the same bug under ordinary names

`A` works at tier 6, so it closed the exporter gap only for module-prefixed
tables. Cross-checking **all** 383 in-census exporter-touched tables against the
policy found 16 more losses decided at tier 8: `patient_identifier_type` (plus
`_display_order`, `_identifier_code_assignment`), `patient_shortcode` (169 rows),
eight `patientticketing_*` and four `visual_field_test_*` - admin tabs "Patient
Identifier Types", "Patient Shortcodes", "Queue Sets", "Visual Field Test
Presets", all tagged `P` because their names read clinical. A `patient*` prefix is
no better a discriminator than an `oph*` one.

The remedy for these is `'C'` in `clearData`, **not** an `adminConfig` entry: `A`
exists only to preempt the name rule, so using it for a table the name rule never
touches adds a second place to look for the same decision. Three
exporter-touched tables stay `P` deliberately - `attachment_data` (the blob behind
`event_attachment_item`), `dicom_files`, `patient`. Being exported is not itself a
reason to keep; the test is exported **and** no patient-shaped column **and** no
FK path down from `patient`.

## 7. Guard the widest keep list first - `keepSystem`, not `adminConfig`

The guard was built for `adminConfig` because that list overrides the name rule.
Wrong priority: `adminConfig` is kept only under `--keepConfig`, while
`keepSystem` is kept in **every** profile, so a misfiled table there leaks into
the blank seed - the one artefact that is supposed to contain no patient data at
all. `assertKeepsSafe()` applies three tests to every whole-table keep and found
six offenders, all now `'P'` in `clearData`: `cat_prom5_event_result` and
`cat_prom5_answer_results` (one PROM score, then one answer, per event),
`field_report` and `field_error_report` (Humphrey import staging; `field_report`
also carries `first_name`, `last_name`, `dob` as plain columns),
`referral_episode_assignment` and `signature_request_archive`.

Two mechanisms hid them, both worth testing for directly:

1. **An undeclared FK.** `cat_prom5_event_result.event_id` has no constraint, so
   the lineage tier cannot walk it. The cheap net is a naming-convention scan: a
   kept table with an `<x>_id` column, no declared FK on it, and `x` a table this
   profile clears. That scan found all six and nothing else on v10 - but it stays
   a `report` warning, never an abort, because a name is evidence and a false
   abort is worse than a false alarm.
2. **A wrongly kept parent whitewashing its child.** The "a declared FK into
   `keepSystem`/`keepReference` proves a definition reference" exception (below) is
   only as sound as those lists: `cat_prom5_answer_results.element_id` looked safe
   purely because its parent `cat_prom5_event_result` was itself wrongly in
   `keepSystem`. Retag the parent and the child fails the same test. Any exception
   that trusts a keep list inherits that list's errors.

The declared-FK test: a kept table with a **NOT NULL** FK to a table this profile
clears (and that the rescue did not save) cannot survive - abort. **Nullable** is
a warning, since `heal` nulls it. v10/v11/v26.0 each carry the same two, both `A`
config tables pointing at config the exporter does not claim
(`ophciexamination_qualitative_scale`, `ophgeneric_assessment_specialty_field`),
which is config loss, not corruption.

## 8. "Has a patient-shaped column" needs one exception, and only one

`ophtrconsent_type_assessment` (50 rows) has `element_id`, which trips a naive
guard. Its `element_id` carries a declared FK to `element_type`, a definition
table in `keepSystem`, so those rows map a consent form type to the elements it is
built from - configuration, not a patient's consent. So the guard allows a
patient-shaped column **only** when a declared FK points into
`keepSystem`/`keepReference`. The converse is not symmetrical: no declared FK
proves nothing, because OE has plenty of undeclared ones, so an unconstrained
`patient_id` still counts. The exception must be positively proven; the default is
suspicion.

The shaped-column set is worth keeping wide - identity columns as well as FKs:
`patient_id`, `episode_id`, `event_id`, `element_id`, `first_name`, `last_name`,
`dob`, `date_of_birth`, `nhs_num`, `hos_num`. The plain-name columns are in that
list because of how the worst offender arrived: `field_report` holds an
unconstrained `patient_id` **varchar** plus a name and a date of birth, so a
client with Humphrey field imports would have shipped real identities into a
"blank" seed. Measured across all four rebuilt schemas, no kept table matches a
name or dob column in either profile, so the wider net costs nothing today and
covers the case where the id column is the one that is missing.

### The blind spot: key/value tables carry identifiers in rows, not columns

Shape detection is a *column* test, so a table declared `(id, name, value)` is
invisible to it - and if its reference to the patient is soft, the FK-lineage
tier cannot see it either. `request_details` is exactly that table: of the 41
distinct `name` keys a DICOM import writes, `patientId` and `hosNum` appear on
every request and `date_of_birth`, `gender`, `extractedHospitalNumber`,
`operators_name` and `station_name` on most of them. The values sit in a `text`
column, and there is no FK to `patient` anywhere. It sat in `keepSystem` and shipped 5036 rows of DICOM-import
identifiers into a supposedly blank seed, next to `request` (134),
`request_routine` (1365), `request_routine_execution` (1391) and
`request_routine_lock` (124). One sampled row: `hosNum 1009797`,
`date_of_birth 19670816`, `gender F`, `patientId 19766`.

So a whole-table keep needs a third question after "does it descend from
patient" and "does it carry a patient-shaped column": **is it key/value
shaped?** The test is cheap - two or three payload columns, one named
`name`/`key`/`attribute` and one `value`/`data`/`payload`, usually `text`. If it
is, the schema tells you nothing and the only honest answer is
`SELECT name, COUNT(*) FROM t GROUP BY name` on real data. The queue plumbing
and its catalogue (`request_queue`, `request_queue_lock`, `request_type`,
`routine_library`) are genuine substrate and stay `S`; the payloads are `E`.

### The same blind spot again: polymorphic reference pairs

`pas_assignment` is `(internal_id, internal_type, external_id, external_type)` with
no declared FK on any of them. `internal_type` names a *class* - so one row is
`Patient.id` paired with the hospital's PAS number, and the next could be something
else entirely. The lineage tier sees no FK; the guard sees no patient-shaped column
name (`internal_id` matches nothing); and it is not key/value shaped either, so the
third question misses it too. It sat in `keepSystem` on all four versions, as did
`pasapi_assignment` with the same shape under different column names
(`resource_id`/`resource_type`).

The **fourth question** is therefore: does the table pair a varchar `*_type` column
with an int `*_id` column, neither carrying an FK? If so the `_type` values are the
only thing that says what the `_id`s point at, and only real data answers it:
`SELECT internal_type, COUNT(*) FROM t GROUP BY internal_type`. Both are `P`.

Two neighbours fell out of the same read. `import` (not `import_log` - that
auto-clears on the name rule) is the log's child through an undeclared
`parent_log_id` and carries a 4096-char `message`, so keeping it left dangling
parents and free text: `E`. `pasapi_xpath_remap` is institution-scoped client
configuration miscast as substrate: `C`, and its NOT NULL child
`pasapi_remap_value` had to follow, which the keep guard would have insisted on
anyway. `findings_subspec_assignment`, from the same shortlist, is two lookups
joined and correctly stays `S` - OE's own cleardown deleting a table is a lead, not
a verdict (section 4).

## 9. Some tables are mixed - then the ROW is the unit of policy, not the table

Two tables are shipped substrate, client config **and** patient data at once, so
no whole-table verdict is correct:

- **`contact`** - carries patient PII, clinician records and organisational
  contacts. Handled by `surgeryContacts($survivors)`, which runs AFTER the clear
  and keeps a contact if any surviving row still references it
  (`referrersOf('contact', $survivors)`).
- **`protected_file`** - the blob table behind eyedraw templates (shipped),
  letter-macro attachments / therapy file collections / advice-leaflet PDFs
  (config), and patient imaging, freehand drawings, signatures and correspondence
  blobs (patient data). 24 tables declare 25 FKs into it. OE's own cleardown
  reaches the same "not a whole-table keep" conclusion by a blunter route:
  `40-delete-other-local-data.sql` ends with `DELETE FROM protected_file WHERE
  id NOT IN (SELECT signature_file_id FROM user);`, keeping user signatures and
  nothing else - correct for a blank seed, and wrong under `--keepConfig`.

The survivor-keyed prune is the general answer, and it resolves every class by
construction without needing to know which class a row is in: keep the rows a
surviving row still points at, clear the rest. Shipped assets survive because
`drawing_templates` (`S`, NOT NULL FK) survives in every profile; a user's own
freehand templates survive for the same reason, being rows of that same kept
table; config assets survive only under `--keepConfig`, when their referrer does;
patient files go, because only cleared tables point at them.

Measured against a real 252 MB client template-config dump, 389
`protected_file` rows:

| Name shape | Kept | Referenced only by cleared rows | Referenced by nothing |
|---|---|---|---|
| eyedraw template `.png` | 8 | 0 | 145 |
| `N_blob.pdf` / `.png` sample correspondence | 0 | 138 | 0 |
| `OCT_[RL]_*.JPG` patient imaging | 0 | 0 | 66 |
| `event_N.pdf` | 0 | 5 | 7 |
| `user_signature_N` | 1 (admin) | 2 (deleted users) | 0 |
| other | 0 | 1 | 16 |

So a whole-table keep ships 66 patient OCT images that **no row in the database
even references**, plus 138 correspondence blobs. Two things follow:

- **The id FK is the only usable discriminator.** `Blepharospasm.png` exists 153
  times in that dump; nothing name-based can separate the live template from the
  debris.
- **Orphan-heavy asset tables are normal, not corruption.** Those 153 are the same
  8-file set re-uploaded once per upgrade run - 19 generations, ids in exact
  strides of 8 - of which only the newest 8 are referenced. Expect an asset table
  to be mostly dead rows and do not read that as a broken dump.

Shipped as a `rowRules` group `'file'` -> `surgeryProtectedFiles($survivors)`, built
on the `surgeryContacts()` model: one `SELECT DISTINCT <childCol>` per referring
edge, then `DELETE FROM protected_file WHERE id NOT IN (...)`. It runs after the
contact surgery, so post-surgery rows are what "still points at it" reads, and it is
skipped under `--keepPatients` alone - "keep the patient data" must not let the
command decide that a client's unreferenced blobs are debris. `verify` gained a
check for the invariant stated the other way round: no surviving file that nothing
references. The dangling-FK check cannot see that, because an orphaned blob is the
opposite shape to a dangling FK - it is the parent that is unwanted, not the child
that is missing.

Measured on a blank v10 seed: **299 -> 8** (`deleted 291 protected file(s), kept 8`),
those 8 being the `drawing_templates` eyedraw templates and nothing else. Before the
prune that "blank" seed shipped 138 sample correspondence PDFs and 144 dead eyedraw
generations.

`--keepConfig` keeps the same 8 on the sample DB, and that is the flag working, not
being ignored: the config-side referrers (`macro_init_associated_content`,
`ophcodocument_sub_types`, `ophcotherapya_filecoll` / `_filecoll_assignment` /
`_email_attachment`) are all empty in the sample and in the client dump, so no config
blob exists to keep. Do not read equal counts as evidence the prune is
profile-blind - check whether the referrer has rows first.

## 10. Finding the next mixed table

The structural shortlist is: kept in every profile **and** authored (has audit
columns) **and** pointed at by rows of clinical tables. On v11 that is 41 of the
196 always-kept tables. Most are plainly lookups and dismissable at a glance
(`eye` with 94 clinical children, `disorder`, `event_type`, `proc`, `medication*`,
`country`, `language`, `subspecialty`, `ethnic_group`, `gender`). The
non-lookup-shaped members are where to look: `protected_file` (confirmed),
`request` (confirmed - key/value payload, section 8), `pedigree` (`inheritance_id`, `consanguinity`, `gene_id`,
`base_change`, `disorder_id`, `genomic_coordinate` - per-family genetics),
`cat_prom5_answers` / `eur_answers`, `checklist_section_type_form`, `proc_set`,
`media_type`, `measurement_type`, `anaesthetist`, `complication`,
`event_subtype`.

Two row-level tells, cheap to compute:

- **The migration-insert sentinel.** Rows a migration inserted carry
  `created_user_id = 1` and `created_date = '1901-01-01 00:00:00'`. Rows outside
  that shape, authored by a real account, are client configuration and are never
  `S`/`R`.
- **The install window.** `MIN/MAX(apply_time)` from `tbl_migration` bounds the
  seed. Authored inside the window by a system user is shipped substrate;
  authored after it by a non-system user is client config.

## 11. "Critical system data" is the shipped base dump, not a migrate-from-clean database

Whether a lookup table is shipped substrate or sample content is not a judgement
call - but pick the right instrument. The obvious one, a **migrate-from-clean**
database (nothing in it but what migrations put there), does not exist: OE cannot
be built that way at all, and the reason is structural, not environmental (see the
versions file, section 3). A real install starts from the **shipped base dump**,
which is why nobody has noticed.

So the definition is: the shipped base dump imported **without** the demo
fixtures. That is what a genuine install has. Diff its populated tables against
the blank seed and "does the app need these rows" is answered by measurement
rather than argument, and the demo fixtures - worklists, booking sessions, CCG/LA
data - are excluded from the comparison by construction instead of by policy.

A migration-insert grep gets you an ordering of the work (83 of 179 residual
candidates seeded, 2171 rows) but never a verdict, because a table can be seeded
by a migration a later branch reverted, and a table with no insert can still be
required.

The run itself is four steps and worth scripting per release: `oe-reset.sh`
**without** `--demo`, row counts to a TSV, `cleardown --yes=1`, row counts
again, then diff the two tagged with each table's category. Count in chunks -
250 tables per `UNION ALL SELECT 't', COUNT(*) FROM t` query - or the statement
gets too long to run. On v10 that gave 1942656 rows -> 1703380: 804 tables
emptied (509 auto-ruled, 189 `A`, 77 `C`, 29 `P`) and 12 reduced, and of
everything kept only **two** `S` tables lost rows, both explained -
`authassignment` 141 -> 39 (user-scoped, the deleted sample users' role rows)
and `document_recipient_output_type` 11 -> 10 (one institution-scoped row
cascaded with its institution). Nothing kept lost a row it needed. That is the
clean bill of health the `S`/`R` lists needed, and it is the one measurement
that tests keeps rather than clears.

## 12. A "keep the data" profile has to keep the data's substrate too

- **Config lives in `oph*`-named lookup tables that the clinical clear treats as
  patient data.** `ophciexamination_areaofcare_type`,
  `ophcocorrespondence_letter_macro`, `ophciexamination_advice_leaflet`,
  `ophgeneric_assessment_specialty` and `patient_identifier_type` are
  *configuration* lookups, but they are `oph*`-prefixed (tier 7 -> `P`) or tagged
  `P` outright, so the blank clear empties them. The `C`-tagged *assignment* tables
  that reference them - `areaofcare_institution_assignment`,
  `macro_init_associated_content`, `worklist_definition` and the rest - do so by
  **NOT NULL** FK. Keep the children, clear the parents, and the kept config
  dangles, and `heal` cannot null a NOT NULL column.
- **The fix is the FK-closure of keep with the lineage predicate as the guard.**
  Under `--keepConfig`, after keeping the `C` tables, also keep every NOT NULL
  FK-parent they transitively depend on, **unless** that parent is in
  `lineageTables()`. The guard is exactly right: a config lookup is referenced
  **by** clinical data, it does not descend **from** it, so it is absent from the
  lineage set and safe to rescue; an `et_*` element table **is** in the set and is
  never resurrected. The closure can only pull non-patient substrate back into
  keep.
- **A keep profile breaks the wipe-and-reseed shortcuts.** With `mailbox` kept
  (`C`), the personal mailboxes of *deleted* sample users survive, named after
  them - a textbook leak; drop personal mailboxes with no `mailbox_user` and no
  `mailbox_team` after the user delete. And the survivor user-FK repoint ("set
  every non-kept `user_id` to admin") is wrong for kept user-scoped config
  (`user_firm`, `mailbox_user`): it piles every sample user's rows onto admin and
  can collide on a unique key. The kept-config path must **prune** ownership rows
  (`user_id`/`userid`) by row and repoint only audit *stamps*
  (`created_user_id`/`last_modified_user_id`).

## 13. A keep flag keeps the whole noun; carve-outs are explicit negative flags

The first cut had `--keepConfig` keep the `C` tables but still prune the sample
users, with org-keeping behind a separate `--keepOrgs`. That is incoherent:
**users and orgs *are* configuration**, so "keep the config" cannot silently
delete the configured users. `--keepConfig` now keeps `C` tables + users + orgs,
`--keepOrgs` was deleted rather than carried as a redundant second way to say the
same thing, and wanting the users gone *under* a keep-config is an opt-in
`--clearUsers`, mirroring the established `--clearOntology`. The polarity matches
the asymmetry: the safe default is to keep, and removing more is what you have to
ask for.

**"Keep the config a user made" is not "keep the user."** When `--clearUsers`
removes an account, the config it authored must survive **reassigned to admin
(id 1)**. That falls out of the mechanism above for free: authorship lives in
`created_user_id`/`last_modified_user_id` (repointed), while rows keyed *by* a
user (`user_firm`, `user_site`, `setting_user`, mailbox membership) are the
account itself and go with it. The regression test: the headline config tables
(letter macros, worklist definitions, advice leaflets, identifier types) keep an
**identical row count** across `--keepConfig` and `--keepConfig --clearUsers`;
only the owner column changes. A count that drops means config was deleted rather
than re-owned.

**The gate is three independent booleans, not one.** Bundling user/org/contact
surgery under a single `if` is what blocked this ask for a while. The triggers
differ: user surgery when users are not kept; org surgery only in a true blank
seed; contact surgery whenever patients are cleared, so patient PII in
`contact`/`person`/`address` never lingers in a kept-config seed even when every
user is kept.

## 14. Order of operations under all-RESTRICT FKs

`user` is self-referencing and RESTRICT-referenced by ~1100 columns; `contact` by
~16; institution/site/firm form an all-RESTRICT login chain. You cannot just
`DELETE FROM user`. The working order:

1. Clear all clinical/version/ephemeral tables first (removes the rows holding
   sample user/contact ids that would RESTRICT-block the deletes).
2. Re-point surviving user-FKs to admin (id 1) - re-point, not NULL, because most
   are NOT NULL, and it also erases *which* sample clinician touched a kept row.
3. Delete user-chain children, then users.
4. Institutions/sites/firms: neutralise survivors in place, repoint the kept firm
   onto institution 1 **before** deleting institutions (else its
   `institution_id` dangles when its original institution goes), then delete the
   rest child-first.
5. Row surgery on mixed tables (`contact`, and the same shape for
   `protected_file`) runs **after** the clear, so "referenced by a survivor" is
   evaluated against what actually survived.
6. Re-create personal mailboxes **after** the emptiness assertion - they
   re-populate a clear-target table, so doing it before fails the assertion.

## 15. Login is a deep invariant - three separate things must hold

"Make sure it still logs in" is three requirements, each found by actually logging
in rather than trusting that the database looked empty and clean:

1. **institution id 1 + site id 1 must exist.** Solved by a floor: never delete
   them, neutralise in place.
2. **At least one active firm in the login institution.**
   `UserIdentity::setSessionDataForUser` -> `User::getFirmsForCurrentInstitution()`
   throws "User has no firm rights and cannot use the system" on zero. The first
   design deleted all firms and login 500'd. Keep one firm, repoint it onto
   institution 1, neutralise it. `admin` has `global_firm_rights`, so one active
   firm suffices.
3. **A personal mailbox per user.** Login *succeeded* (302) but the home dashboard
   500'd: `OphCoMessaging`'s inbox builds `... IN ({ids})` and zero mailboxes
   gives `IN ()`, a SQL syntax error. OE auto-creates one personal mailbox per
   user via a `UserSavedSystemEvent` listener that does **not** re-fire on login,
   so a cleared seed never gets one back. Re-create one per kept user in SQL,
   mirroring `createPersonalMailboxIfDoesNotExist`.

The meta-lesson: a "blank" seed is not the empty intersection of tables, it is
whatever a **fresh install** produces - one institution, one site, one firm, a
personal mailbox per user. Reproduce that shape rather than stripping to bare
minimum. Every over-clear here surfaced only as a runtime 500, never as a failed
DB assertion.

## 16. Assertions must not outrun the policy or the running app

- **Do not assert emptiness on tables a live app keeps writing.** `assertEmpty`
  asserted every clear target was empty and started false-failing on
  `user_session`, because the command runs against a **live** instance: between
  the clear and the assertion (~30s) the web app writes fresh
  `user_session`/`*_log`/`audit` rows for any login, tab or healthcheck. Seeding
  `user_session` to 1800 rows and running gave 2 - the app re-populated it during
  the run. Scope the assertion to what its emptiness guarantees: the
  patient/clinical/config/version (`P`/`C`/`V`) leak surface. Ephemeral `E` tables
  are excluded on two grounds - they are `TRUNCATE`d with `FK_CHECKS=0` so cannot
  partially fail, and a non-zero count there is fresh runtime state.
  Generalisable: a "did the destructive step take?" assertion must cover only
  state the app will not re-create on its own.
- **Adding a keep category breaks the emptiness assertions that predate it.**
  `actionVerify` asserts every `et_*` table is empty, which held while every
  `et_*` table was an event element. `et_ophciexamination_investigation_codes` is a
  lookup with no `event_id`, so the first `--keepConfig` run after the `A` list
  landed failed on it. Under `--keepConfig` the blank assertion now skips
  `adminConfig` members. Walk any new keep category through `verify`'s assertions
  in the same pass, or verify starts contradicting policy.

## 17. Verifying a kept-data result needs a mode-aware, FK-correct verify

- **Composite FKs defeat a per-column dangling scan.** `KEY_COLUMN_USAGE` lists
  each FK column as its own row, so a naive scan checks columns independently. A
  composite FK like
  `patient_identifier_type (institution_id, site_id) -> site(institution_id, id)`
  then gets tested as "`institution_id` alone must exist in
  `site.institution_id`" - a false positive, because InnoDB enforces **MATCH
  SIMPLE**: the constraint is checked only when *every* component is non-NULL and
  is satisfied by a full-tuple match. Worse, one column can sit in two FKs at once
  (`institution_id` -> `institution.id` **and** -> `site.institution_id` as half a
  composite). Group edges by `CONSTRAINT_NAME` and check the whole tuple.
- **A kept child dangling to a *kept* parent is the source's problem.** If the
  cleardown kept both ends byte-for-byte, the dangle was already in the restored
  dump - `mysqldump` restores with `FOREIGN_KEY_CHECKS=0`, so a populated database
  can carry orphans InnoDB would now reject. Ask whether *you* emptied the parent
  (your bug) or it was always short (their data); `ALTER TABLE ... FORCE`
  re-validates with checks on and tells you which.
- **A green default-seed verify lies about a keep-mode result.** The
  org-fingerprint leak scan assumes the neutralised "Default Institution" /
  "Default Site"; under `--keepConfig` the configured names are kept on purpose.
  Verify must take the same mode flags the cleardown ran with
  (`verify --keepConfig=1 [--clearUsers=1]`) and skip the checks the mode
  deliberately invalidates, or it cries wolf and trains the operator to ignore it.
  Blank-clinical, dangling and login-substrate checks stay live in every mode; the
  fingerprint scan is skipped whenever orgs are kept; the only-system-users check
  is skipped only when users are kept too.

## 18. A heuristic hint may order the work, never conclude it

`report` annotates each unclassified table with a guess. For
`unused_fields_et_ophtroperationbooking_operation` (388 rows) it said "no audit
cols -> likely a national lookup: add to keepSystem (S) or keepReference (R)" -
i.e. it pointed straight at a whole-table keep. The creating migration settled it
in one look: `m260615_134252_archive_booking_unused_fields` copies five columns out
of `et_ophtroperationbooking_operation` keyed by `operation_id` and drops them, so
every row belongs to one patient's operation. Absent audit columns is a real
signal for shipped lookups and a worthless one for an archive table, which never
had them. For any table a hint pushes toward `S` or `R`, read the
`createTable`/`createOETable` migration before agreeing.

## 19. Baseline established 2026-07 (snapshot for delta work)

Artifacts (`<version>.schema.tsv`, `.migrations.txt`, `.fkedges.tsv`,
`.views.txt`, `.report.txt`, `.scenarios.txt`) live in `~/cleardown/artifacts`;
they make the next version's delta a short job instead of a re-derivation.

| | v10 (`release/10.0.x`) | v11 (`release/11.0.x`) | v26.0 (`release/26.0.x`) | v26.1 (`develop`) |
|---|---|---|---|---|
| base tables | 2218 | 2231 | 2330 | 2348 |
| `tbl_migration` rows | 2090 | 2110 | 2190 | 2226 |
| explicit policy entries | 609 | 614 | 638 | 644 |
| keeps, blank profile | 183 | 183 | 184 | 183 |
| keeps, `--keepConfig` | 534 | 538 | 558 | 563 |
| clear targets, `--keepConfig` | 1674 | 1683 | 1762 | 1775 |
| `protected_file` pruned to | 299 -> 8 | 301 -> 9 | 299 -> 8 | 299 -> 8 |
| rescued by FK closure | 2 | 2 | 3 | 3, but see below |
| guard aborts | 0 | 0 | 0 | 0 |
| guard warnings | 2 | 2 | 2 | 2 |

The v26.1 rescue count is the one cell not measured on a sample rebuild. It is `3`,
read off a **client** database (the pptest dump migrated 10.0.x -> develop), because the
chain's grep never captured the `Kept for config FK integrity (N` line. The count is
driven by schema and policy rather than by rows, and that schema was proved identical
to the v26.1 rebuild census - 2348 tables and 24430 (table, column) pairs, zero
difference in either direction - so `3` is very likely also the sample figure. It is
*not* the same measurement though: identical columns do not prove identical FK
constraint sets, and a migrated-up schema is exactly where a constraint can differ from
a freshly built one. Treat it as a prediction until a v26.1 sample rebuild prints the
line.

Views are 57 on v11, v26.0 and the v10 acceptance dump. Identity surgery is 10 tables
on every version. The two warnings are the same three-version-stable pair from
section 7.

v10 has no live `fkedges.tsv` (the capture pass post-dates its rebuild), so
`v10.fkedges.derived.tsv` was parsed out of a v10 dump's DDL instead, by
`fkedges_from_dump.pl`. Treat a derived artifact as a probe, not a capture, and
validate it before use: every one of the 4156 edges it shares with the live v11
capture agrees on nullability, and its 16 duplicate `(child, col, parent)` triples
match v11's 16 exactly, so the duplicates are a schema feature (two constraints over
one column) rather than a parser artifact. Column nullability must be read from the
column definition in the same `CREATE TABLE` block - and in Perl,
`$null{$1} = ($line =~ /NOT NULL/) ? ...` silently fills the wrong key, because the
right-hand match runs first and resets `$1`.

Every cell above is measured, all four versions on one build: sixteen verifies passed,
zero failed, twelve logins OK, `UNCLASSIFIED`/`NEW`/`REMOVED` all zero on every
version, and each idempotence re-run deleted nothing while keeping the same file
survivors. Read a keep count off `--dryRun=1` (with and without `--keepConfig=1`) after
the version's suite runs; never derive one. Two earlier attempts to derive were wrong
by five and by one.

Derivation is banned; a *prediction* stated before the measurement is how you find out
whether the model is right. Taking six tables out of `keepSystem` should drop the blank
keep by exactly six and the `--keepConfig` keep by exactly four, since two of the six
come back as `C`, which that profile keeps. v10 measured 189 -> 183 and 538 -> 534:
both exact, so the accounting is closed and nothing is left to chase. The same
subtraction against v26.0's older figure appeared to be off by one - which was the
figure's fault, not a mechanism, as the next paragraph shows.

The `<v>.report.txt` artifacts are **not** a comparator for a keep count either. They
were captured in the per-version rebuild pass, before later policy work, so v26.0's
says `Keep: 202` against a measured 184 - a difference that spans several changes and
tempts exactly the arithmetic the previous paragraph forbids. Two rules follow: a keep
count is only comparable to another count taken under the *same* policy, and a delta
is only explainable if you can name the mechanism. When 184 did not differ from an
older figure by the six retagged tables, the one mechanism that could have explained
it - a retagged table forcing an FK-closure rescue that is no longer needed - was
checked in `<v>.fkedges.tsv` and ruled out: the six have no NOT NULL FK out except to
`user` (which identity surgery always leaves standing) and to each other. Rescued
tables: `ophtroperationbooking_admission_letter_warning_rule_type` and
`ophtroperationbooking_operation_sequence_interval` on v10/v11, plus
`ophciexamination_allergy_category` (the lookup behind the kept allergy config) on
v26.0.

## 20. OpenEyes already ships a cleardown - read it before inventing categories

`protected/modules/sample/sql/cleardown/` in the sample module is a working
cleardown that predates this one: `run_cleardown.sh` plus `base_scripts/*.sql`
(patients, events, users, contacts, extra sites and institutions, audit) and
`additional_scripts/admin-config.sql` (only run under `--delete-admin-config`).
It names 550 tables. That is upstream stating, in SQL, which tables hold nothing a
blank install needs - the single strongest external evidence available for the
`P`/`C` boundary, and it is free.

It went unread for weeks because the sample module reads as "the demo fixtures".
The generalisation is the useful part: **before classifying anything, look for a
peer implementation that already made the same judgement.** In this codebase the
peers are that script set, `export_config_v1000.php` (section 4), and the model
layer. Cross-referencing the first two against each other is also how you find the
gaps in both - 180 tables appear in both, 28 only in `admin-config.sql`, 211 only
in `export_config`, so neither list is a superset and neither is complete.

Against the v26.1 policy the comparison found six genuine disagreements:
`findings_subspec_assignment`, `measurement_type` and `media_type` are unconditionally
emptied by `40-delete-other-local-data.sql` but held as `S`; `drawing_templates`,
`event_subtype` and `event_subtype_element_entries` are in `admin-config.sql` but
held as `S`. It also put 237 otherwise-unclassified tables on evidenced ground,
148 of them from `30-delete_events_and_eps_data.sql` alone.

### The `WHERE` clause is the whole signal

Do not extract table names and stop. An unconditional `DELETE FROM t` or
`TRUNCATE t` is upstream saying *the table is not needed*; a `DELETE FROM t WHERE
... IN (deleted users)` is **row surgery** and is entirely consistent with keeping
the table. Grepping for table names alone conflated the two and produced eight
accusations against the `S` list; parsing statement-by-statement and recording
`DELETE_ALL`/`TRUNCATE`/`DROP` separately from `DELETE_WHERE` cut that to three
real ones and reclassified the rest - `authassignment` among them, which section 19
had already explained as user-scoped. Strip SQL comments first, or a commented-out
`DELETE` is read as upstream policy. The parser is
`~/cleardown-audit/scripts/sweep-oe-cleardown.pl`.

## 21. A missing migration insert is not evidence of anything

Section 11 says a migration-insert grep orders the work but never gives a verdict.
The measurement is now in: **45 of the 119 `S` tables have no migration insert at
all** - 38% - and they include `eye`, the canonical example of a system lookup, plus
`episode_status` and `country` (248 rows, `R`). Their rows come from the shipped base
dump, because OE's baseline predates the 2013 consolidation migration and migrations
only carry deltas from there.

So the rule is one-directional, and worth stating that way in any brief given to a
subagent or a human:

- **A literal-row migration insert is positive evidence for keeping** - somebody
  shipped those rows to every instance on purpose.
- **The absence of a migration insert is evidence of nothing.** It does not
  distinguish "sample content" from "substrate so old it predates the migration
  history". Anything that treats a bare `inserted_by = -` as a reason to clear will
  clear `eye`.
- `INSERT ... SELECT` and PHP loops over live rows are **backfills**, not shipped
  data: they push toward clear, whatever their row count in a sample database.

The asymmetry mirrors section 1: the signal that argues for the recoverable action
(clear) has to meet a higher bar than the one arguing for the unrecoverable one.

## 22. Upstream's cleardown names only a third of the tables it empties

Section 20 said to read OE's own `protected/modules/sample/sql/cleardown/` scripts
before inventing categories. That was right and badly under-counted: a
statement-by-statement parse found 550 tables, and the real figure is 1847.

Four of the base scripts build their table names at run time from
`information_schema`, so nothing textual connects the call to the tables it hits:

| Procedure | Script | Pattern | What it issues | Tables |
|---|---|---|---|---|
| `CLEAN_ETDATA('x')` | `30-delete_events_and_eps_data` | `et_x%` | `DELETE FROM <t>`, unqualified | 440 |
| `CLEAN_VERSIONS()` | `20-delete_version_tables` | `%_version` | `DELETE FROM <t>`, unqualified | 1072 |
| `droparchive()` | `10-drop_archive_tables` | `archive_%` | `DROP TABLE <t>` | 12 |
| `CLEAN_INSTITUTION_TABLES()` | `100-delete-data-for-extra-institutions` | `%_institution` | `DELETE .. WHERE institution_id<>1` | 26 |

`30-delete_events_and_eps_data.sql` calls `CLEAN_ETDATA` for 25 module prefixes.
Every `et_*` table in those 25 families is emptied whole by an always-run script,
which is upstream stating plainly that none of them holds anything a blank install
needs. Expanding the four patterns against the census took the evidence base from
23% of the schema to 78% and moved v10's mechanically-certain share by five points.

Two consequences that are not obvious:

1. **`et_` is no longer just a name heuristic for those 25 families.** It stops
   being "the prefix suggests clinical data" (which section 18 forbids concluding
   from) and becomes "an always-run upstream script deletes this table by pattern",
   which is evidence about behaviour. The distinction matters: the evidence covers
   exactly the prefixes actually passed to `CLEAN_ETDATA`, not every `et_*` table.
   `et_ophciexamination_drgrading_gradeability_options` is swept as collateral and
   is genuinely a lookup, so the sweep is a strong signal and still not a proof.
2. **`%_institution` scoping is not identity surgery.** It prunes to institution 1,
   which `keepInstitutionIds` already handles, and says nothing about whether the
   table holds config or clinical data. Reading it as category `I` puts a
   row-surgery verdict on several hundred admin scoping join tables.

Grep any SQL corpus for `PREPARE`, `information_schema`, `CONCAT(... TABLE_NAME` and
`GROUP_CONCAT` before believing a table-name extraction is complete.

## 23. `gp` and `practice` are cleared by an always-run script, not admin config

`additional_scripts/admin-config.sql` contains `DELETE FROM practice;` and
`DELETE FROM gp;` - both **commented out**. The live statements are unqualified
`DELETE FROM gp;` / `DELETE FROM practice;` in `120-delete-contacts.sql`, which runs
every time.

So upstream clears them unconditionally, and filing either as `C` would keep 184
named real GPs and their practices under `--keepConfig`. Any extraction from these
scripts has to strip `--` and `/* */` comments before matching, or it inherits
whichever side of the contradiction it happened to read first.

## 24. The two provenance axes miss three row-origin classes

The config re-split classifies a keep candidate on two programmatic axes - is it
migration-fed, and does an admin screen edit it - with only the canon-vs-suggestion
call left to judgement. Running 282 candidates through source-reading agents
surfaced three recurring shapes that sit outside both axes, each misfiled by the
scanners in a predictable direction:

1. **The settings key/value split.** OE ships a settings *metadata* table (the
   keys, migration-seeded, `S`) next to a separate *values* table that the admin
   screen actually writes. A reference scan sees the screen touching both and
   calls the key table admin-editable; only the write path settles it - the
   screen INSERTs into the values table and merely SELECTs the keys.
   `ophcocorrespondence_letter_settings`, `ophtroperationbooking_whiteboard_settings`
   and `ophcocorrespondence_internal_referral_settings` are the metadata half of
   such pairs. Before calling any `*_settings` table editable, find the statement
   that writes it.
2. **Runtime-generated registries.** `audit_model`, `audit_module` and
   `audit_type` look like seeded lookups but are populated on demand by
   application code as audit rows are written - neither migration-fed nor
   admin-typed, so both axes read 0/0 and the "neither" bucket miscasts them as
   thin-evidence config. They are self-regenerating runtime state, the same
   provenance class as the audit rows they describe.
3. **Post-migration loader commands.** `eyedraw_tag` is fed by
   `EyedrawConfigLoadCommand`, which `oe-fix.sh` runs after every migrate - shipped
   content that never appears in a migration insert or data CSV, so a
   "migration-fed" grep scores it unfed and the mechanical lean drifts toward
   client-typed. Check the yiic commands the install/upgrade wrappers invoke
   before concluding a populated keep candidate has no shipped seed.

The common fix is the same in all three: read the actual write path, never count
references. A reference is where to look (sections 18, 21), and the statement
that performs the write is the only thing that says who owns the rows.

## 25. Seed drift, not miscategorisation, is the dominant failure of keeps

The adversarial re-verify of every keep (464 S/R/M/G tables, one slice each) found
50 leaks, and 35 of them were the same shape: the shade was right about WHO ships
the rows, but the sample had accreted client- or demo-typed rows on top of the
shipped seed, so the whole-table keep leaks and only row surgery is safe (category
I). Editable lookups (G, then M) are the natural accretors - letter macros, letter
strings, workflows, element sets, instruments, lens types - but supposedly
non-editable S tables fell the same way when the production CSV ships a stub and
the demo CSV supplies the rest: `subspecialty` ships 1 production row and holds 17,
16 of them testdata. Corollary: a table being the canonical example of a category
("subspecialty is S") is not evidence about its ROWS.

Three second-order lessons from the same pass:

1. A MUST-KEEP row inside a clearable shade is a profile clash: `ophciexamination_risk`
   is genuinely G (editable suggested defaults), but code dereferences the literal
   `Anticoagulants` row unguarded, so `--clearSuggested` would 500 the risks screen.
   Whole-profile safety has to be checked per row, not per shade - these go to the
   human, never silently promoted to S.
2. Empty ontology-family staging tables (`f_ampp_*`, `f_vmpp_*`) are not ontology
   payload: the dm+d importer creates them from the XSD and then skips their XML.
   An asserted family keep on an empty table is a bet, and the re-verify shows the
   bet wrong - they are import scaffolding (E), kept only by the family assertion.
3. GNU split with a rename loop is a cascade hazard: `split -d` suffixes 00.. then
   `mv` into 1-based names overwrites unprocessed zero-padded sources. Use
   `split -d --numeric-suffixes=1 --additional-suffix=.txt` and no rename loop.

## 26. A default tier must never outrank structural machinery

merge.pl's fallback for tables no source speaks to filed empty tables as
'P LIKELY default-empty'. `person` is empty in the sample AND carries a rowRules
entry - the structural marker that the table needs row surgery, the strongest
signal in the whole pipeline - and the default silently overruled it, turning a
surgery table into a plain clear. The fix orders the tiers: a table with a
rowRule is never defaulted, it routes to human review (tier A, UNSURE). The
general shape: an escape hatch that downgrades certainty ("empty, so clearing is
a no-op") must check for stronger machinery first, because "no source speaks to
it" and "a rowRule speaks to it" can both be true, and the cheap default wins
silently unless the precedence is explicit.

## 27. Widening a guard to a broader union resurrects the false positives the old scoping existed to avoid

When the retired `adminConfig` (A) list dissolved into M/G/C, `assertConfigKeepsSafe`
was re-pointed at the M+G+C union - and the first live run aborted on two false
positives, both pre-solved by scoping the old code had and the rework dropped:

1. `commissioning_body` (C) tripped the FK-to-contact prong. That prong had only
   ever applied to the A list precisely because C tables (`gp`, `practice`,
   `commissioning_body`) legitimately reference professional contacts, and the
   survivor-keyed contact surgery keeps exactly the contacts surviving tables
   still point at. The doctrine was even written down next to the old check. Fix:
   the contact/person/address prong fires only for migration-seeded keeps (M, G),
   where a shipped seed referencing instance identities is always wrong; C is
   exempt by design.
2. `ophtrconsent_type_assessment` (M) tripped the patient-shaped-column prong on
   `element_id` - because the resplit moved its FK target `element_type` from S
   to M, and the definition-reference exemption still only recognised
   keepSystem+keepReference. A category move silently invalidated an exemption
   keyed on category membership. Fix: a declared FK into S, R or M proves a
   definition reference (all three are kept by every profile); G stays excluded
   because `--clearSuggested` clears it, so an FK there proves nothing.

Two tells to check when re-pointing any guard at a wider set: (a) the old code's
narrower scoping usually had a written rationale - read it before assuming the
wider application is safe; (b) any exemption list keyed on category membership
must be re-derived after a re-categorisation, not carried forward. And run the
guard against a live schema before shipping: both bugs were invisible to php -l
and the round-trip check, and cost one smoke test to find.
