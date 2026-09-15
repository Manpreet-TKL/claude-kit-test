# `event` table lock contention and deadlocks in OpenEyes (2026-08/09, analysis)

Read before diagnosing any deadlock, lock wait or MDL pile-up on the `event`
table, and before "fixing" it by upgrading a branch. Traced on
`release/10.0.x` (`408456b5ba`) and compared against `develop` (`9ae0fe1bc4`).
Line numbers are `release/10.0.x` unless stated.

Evidence was re-audited on 2026-09-08 by reading all four supplied processlist
files before comparing with this note. The audited windows are 2026-09-04
15:35-15:43 and 2026-09-08 09:31, 14:26-14:28 and 14:43-14:45. The unique-code
path was also checked in the local OpenEyes checkout at
`ad2324084788608246a8250e817198c2f26a4fd6`; that is not deployment verification.

Earlier evidence retained below includes the 2026-08-19 deadlock dump, an
additional 2026-09-04 14:12 capture, a 46-record RDS deadlock corpus covering
2026-09-07 09:00 to 2026-09-08 09:00, and production DDL/sizing measurements from
2026-09-04. Those separate artefacts were not re-audited with the four files;
their reported measurements must not be presented as new verification.

Operator-supplied SQL results on 2026-09-08 confirm **MariaDB 10.6.25-log,
Performance Schema ON, and metadata-lock instrumentation enabled and timed**.
The owner/waiter capture therefore needs no instrumentation change or reboot.
No owner/waiter results have yet been supplied. The original holder is unknown;
the earlier assertion of two proven freeze modes is withdrawn.

## Summary: two different locking mechanisms

| | Problem 1 | Problem 2 |
|---|---|---|
| Symptom | InnoDB deadlock, one transaction rolled back | bursts of metadata waits affecting many writes |
| Mechanism | version snapshot can take S, save upgrades to X | strong table-lock request can make later metadata requests queue |
| Trigger | overlapping writers on one row; historical corpus mostly `user` | unique-code allocation for a configured event without a mapping |
| Observed impact | transactions in the deadlock report | `event`/`user` writes, allocation locks, and a mapping INSERT |
| Next step | verify transaction history and preserve audit semantics in any fix | capture the original holder; replace table-wide allocation locking safely |

Problem 2 best explains the widespread write stalls in the four processlists.
They do not establish that all database activity stopped, or prove Problem 1
from an `Updating` state alone. A row-lock delay can also feed an MDL queue.

## Problem 1: the version snapshot takes S, the save then upgrades to X

`Event extends BaseActiveRecordVersioned`, so every save on an existing row runs
`protected/models/BaseActiveRecordVersioned.php:271` (`updateByPk`):

    $transaction = $this->dbConnection->beginInternalTransaction();
    $criteria = $this->commandBuilder->createPkCriteria($this->tableName(), $pk, ...);
    $this->versionToTableManyToMany($criteria);
    $this->versionToTable($criteria);      // INSERT INTO event_version ... SELECT ... FROM event WHERE event.id = ?
    $result = parent::updateByPk(...);     // UPDATE event SET ... WHERE event.id = ?
    $transaction->commit();

`versionToTable()` (`:399`) calls `OECommandBuilder::createInsertFromTableCommand()`
(`protected/components/OECommandBuilder.php:21`), which emits:

    INSERT INTO event_version (`id`,`episode_id`,...,`version_date`,`version_id`) SELECT event.*, '<now>', NULL FROM event WHERE event.id = :id

Under REPEATABLE READ (the MariaDB default), InnoDB can take **shared locks
on the source rows of an `INSERT ... SELECT`**. The next statement in the same
transaction takes X on that same row. If two sessions both acquire S before
either upgrades, the S-to-X upgrades can deadlock. Two overlapping saves do not
necessarily follow that interleaving.

The snapshot is a candidate source of an S lock on `event`, not the only
possible source. Foreign-key checks can also acquire shared record locks;
attribute a lock to a statement using transaction history and the full report.

The same pattern applies to `updateAll`, `deleteByPk` and `deleteAll` on any
versioned model - all four snapshot before mutating.

`id` appears in the `SET` clause because Yii's `updateByPk($pk,
$this->getAttributes())` writes every column including the PK.

### Recognising it in `SHOW ENGINE INNODB STATUS`

    *** (1) ... UPDATE `event` SET `id`='...', ... WHERE `event`.`id`='...'
        WAITING: index PRIMARY of table `openeyes`.`event` lock_mode X locks rec but not gap waiting
        CONFLICTING WITH: ... trx id <n> lock mode S locks rec but not gap
    *** (2) ... update event set created_date=..., ... where id=<same id>
        WAITING: ... lock_mode X ... CONFLICTING WITH: trx <n> lock mode S

Both transactions hold S on the same PK record and both want X. Whichever
InnoDB rolls back is arbitrary; the pairing is the diagnosis.

### Telling the writers apart by SQL fingerprint

Production estates run more than one writer against `event`. These SQL
fingerprints suggest a client family, but do not prove client identity or its
earlier transaction statements:

| Signal | Yii web app | External Java/Hibernate service |
|---|---|---|
| Identifiers | backtick-quoted | unquoted |
| Column order | Yii/table order | strictly alphabetical |
| Timestamps | `'2026-08-19 10:23:42'` | `'2026-08-19 10:28:00.0'` (`java.sql.Timestamp`) |
| Column set | full current schema, incl. `institution_id`, `step_id`, `service_firm_id` | legacy subset only |
| User column | real `last_modified_user_id` | often `1` |
| Snapshot first | versioned update path snapshots before mutation | not established by the current UPDATE text |

Other Hibernate tells in the same dump: the `<table>0_` alias convention, e.g.
`select requestrou0_.routine_lock from request_routine_lock requestrou0_ ... for update`.
`request_routine` and `request_routine_lock` are OE tables (`Api/Request` module,
`OphGeneric` migration `m200204_132129`) but the consumer is external.

A statement of the shape
`UPDATE event ev SET ev.service_firm_id = (SELECT ep.firm_id FROM episode ep WHERE ep.id = ev.episode_id) WHERE ev.id = <id>`
exists **nowhere** in the PHP repo - the two migrations touching `service_firm_id`
(`m240604_102447`, `m251002_112405`) use a JOIN form with no per-id WHERE. It is
external. Watch for that writer blanking `episode_id` on rows the web app is
concurrently populating.

A third writer is in-repo:
`protected/modules/PASAPI/resources/PatientAppointment.php:172` runs
`\Event::model()->updateAll(['worklist_patient_id' => null], 'worklist_patient_id = :wp', ...)`,
which routes through `BaseActiveRecordVersioned::updateAll` and so snapshots a
whole range before updating it. `event.worklist_patient_id` is indexed
(`m220916_160353`), so it is a range not a scan, but it is still S-then-X.

### What else is inside the event save transaction

`BaseEventTypeController::actionCreate` (`:983`) and `actionUpdate` (`:1229`)
open one `$db->beginInternalTransaction()` and hold it across element saves and
deletes, `EventAttachmentHandler::saveAttachmentsFromRequest`, `updateEventStep()`,
`afterCreate/UpdateElements`, audit writes, and
`Yii::app()->event->dispatch('event_created'|'event_updated')` with every
registered listener. The intended transaction spans all of it; the allocation
path's implicit commit, described below, can release transactional locks early.

One save writes the row **twice**: `saveEvent()` (`:1899`) does
`$this->event->withVersion()->save()`, then `updateEventInfo()` (`:1850`) does
`$this->event->noVersion()->save()`. A single event save is therefore S + X + X
on that row plus a full `event_version` row.

### The biggest single source of deadlocks is `user`, not `event`

Historical analysis reports a 46-dump corpus captured on 2026-09-08 after
`innodb_print_all_deadlocks` was enabled, covering 2026-09-07 09:00 to
2026-09-08 09:00. The counts and record interpretations in this subsection are
retained from that analysis, not independently verified by the processlist audit.

| Table, by lock lines | Count |
|---|---|
| `user` | 190 |
| `ophciexamination_intraocularpressure_value` | 30 |
| `event` | 24 |
| `pathway_step` | 14 |
| `patientticketing_ticket`, `episode` | 12 each |
| `plans_problems`, `ophdrpgdpsd_assignment_meds`, `mview_datapoint_node` | 6 each |

**30 of the 46 records are two transactions updating the same `user` row.**
`event` is third. The title of this note is historical: the deadlock problem is
mostly not an `event` problem.

The writer is `BaseEventTypeController::setContext()` (and the identical copy in
`PatientEventController`), reached from `OphCiExamination` `actionStep`, so it
fires on every examination workflow step advance:

```php
$user->changeFirm($context->id);
if ($user->isModelDirty() && !$user->save(false)) {
```

`changeFirm()` sets only `last_firm_id`, but `save(false)` is a full versioned
save of all 24 columns.

**Correction: the dirty check is not the bug.** 24 of the 46 records show both
transactions writing the *same* `last_firm_id`, which looks like a wasted no-op
write. It is not. Field 14 of the 26-field `openeyes`.`user` PHYSICAL RECORD in
each dump is the pre-image of `last_firm_id`:

| Of the 24 same-value records | Count |
|---|---|
| pre-image equals the written value (a true no-op) | 1 |
| pre-image differs, both racers moving the user to the same new firm | 23 |

Exactly **one** of 46 is a write that changes nothing. `isModelDirty()` is
behaving correctly, and fixing it would remove one deadlock. Do not chase it.

What the records actually show, worked from record 1: one user id, both
transactions from the same application IP, `last_modified_date` 8 seconds apart,
pre-image firm 595, one transaction writing 608 and the other 609. Both hold
`lock mode S locks rec but not gap` on the same PK record and both wait for
`lock_mode X locks rec but not gap` on it. Symmetric S-to-X upgrade, both sides
in the cycle. Across the corpus, 80 records show a transaction waiting for X on
a record it already holds S on, and no `_version` table appears in any lock line,
which is consistent: the S is taken on the source row by the snapshot's SELECT
side, not on the destination.

The historical interpretation is a version-snapshot S-to-X pattern driven by
concurrent requests for one signed-in clinician. Proposals 6 and 7 target that
pattern; proposal 8 needs audit-preserving implementation and does not by itself
remove the upgrade. These are proposed changes, not measured fixes.

## Problem 2: the unique-code path

Call chain:

    actionCreate()                       BaseEventTypeController.php:1004  <- transaction opens
      saveEvent()                        :1008   event INSERT + version row + every element INSERT
      updateEventStep()                  :1020
      afterCreateElements()              :1023
        updateUniqueCode()               :2854
          createNewUniqueCodeMapping()   :2877
            UniqueCodeMapping::lock()    BaseController.php:415  <- LOCK TABLES

`afterUpdateElements()` (`:2842`, from `actionUpdate()` `:1247`) takes the same
route. If the mapping already exists the lock is skipped; an update with a
missing mapping can still allocate. The other caller, `BaseController::getUniqueCodeForUser()`
(`:401`), has no callers anywhere in the repo - dead code.

Trigger scope is narrow, hard-coded at `BaseEventTypeController.php:71`:

| Event | Element |
|---|---|
| `OphTrOperationnote` | `Element_OphTrOperationnote_Cataract` |
| `OphCoCvi` | `Element_OphCoCvi_EventInfo` |

`OphTrOperationnote/controllers/DefaultController.php:355` calls
`parent::afterCreateElements()`, so cataract op notes do reach it. Narrow, but it
fires hardest exactly when a cataract list is running.

### The statement it emits

`UniqueCodeMapping::lock()` builds its own SQL from model aliases.
`UniqueCodes::defaultScope()` sets only an `order`, so its alias is Yii's default
`t`; `UniqueCodeMapping::defaultScope()` sets `alias => unique_codes_mappingtable`.
Four lock names, two tables, all on `Yii::app()->db` - the same single connection
the controller's transaction is on:

    LOCK TABLES `unique_codes` READ, `unique_codes` AS `t` READ, `unique_codes_mapping` WRITE, `unique_codes_mapping` AS `unique_codes_mappingtable` READ

### What runs between lock and unlock

`BaseController.php:415-426`, no `try/finally`:

| Line | Code | SQL on the wire |
|---|---|---|
| 416 | `getActiveUnusedUniqueCode()` (`:436`) | 1 SELECT, the anti-join |
| 417-423 | assign `event_id` / `user_id` | none |
| 424 | `isNewRecord = true` | none |
| 425 | `save()` | 1 INSERT |
| 426 | `unlock()` | `UNLOCK TABLES` |

    SELECT unique_codes.id FROM unique_codes LEFT JOIN unique_codes_mapping ON unique_code_id=unique_codes.id WHERE unique_codes_mapping.id IS NULL AND active = 1 LIMIT 1

Nothing else fires. Each hook was checked, not assumed:

1. `rules()` is only `safe` + `required`, so validation issues no queries.
2. `beforeValidate()` is HTML purification, in PHP.
3. `afterValidate()` walks `HAS_MANY`/`HAS_ONE`; all four relations are
   `BELONGS_TO`, so it does nothing.
4. `afterSave()` walks `HAS_MANY`/`MANY_MANY`/`HAS_ONE`; same, nothing.
5. `getChangeUserId()` (`BaseActiveRecord.php:337`) reads `Yii::app()->user`, no
   query. `getChangeUser()`, which would hit the `user` table, is not on this path.
6. The model extends `BaseActiveRecord`, not `BaseActiveRecordVersioned`, so there
   is no version snapshot. The migration used `createOETable(..., true)` so a
   `unique_codes_mapping_version` table exists, but nothing at runtime writes it.
7. The `LookupTable` behavior contributes named scopes only, no save hooks.

The critical section includes the SELECT, model processing and INSERT. Their
execution and any further waits all extend lock retention. The historical
single-query measurement below does not establish the hold time under incident
load; the captures filter out states in which that work could be running.

### Historical SELECT sizing (reported 2026-09-04)

The following measurements and index change are retained from the earlier
investigation; neither the live plan nor these counts was rechecked in this audit.

`unique_codes` is `id` PK, `code varchar(6)`, `active int(1)`, plus the audit
columns from `createOETable`. Original indexes: `PRIMARY`, two FK indexes on the
user columns, and `unique_codes_code_IDX` on `code`. **No index on `active`.**
`AUTO_INCREMENT` was `205020`, and `GenerateUniqueCodeCommand.php:25` tops the
pool up to 1500 free codes daily and never prunes consumed ones.

Consumed codes are therefore the low-id prefix, and the query walks it in `id`
order probing `unique_code_mapping_unique_code_id_unique` once per row until it
finds a miss. Measured on production:

| Metric | Value |
|---|---|
| Free codes | 1242 |
| `first_free` | 203778 |
| `last_free` | 205019 |
| Rows skipped per call | 203,777 |
| Query time | 0.41 sec |

At that measurement the reported free pool was one contiguous block at the top
of the id range. That supports evaluating descending selection in proposal 3,
not assuming today's distribution or guaranteeing a first-row hit.

With an ascending scan through consumed codes, pool growth increases work.
That is a plausible contributor to longer allocation critical sections, not a
proven explanation of incident onset. The actual plan and free-code distribution
must be measured again before attributing the stalls to this scan.

`ix_unique_codes_active_id (active, id)` was added on 2026-09-04. `EXPLAIN` after
it: `ref` on the new index, `key_len 4`, `rows 95746`, `Extra: Using index`
(covering), and `eq_ref` on `unique_code_mapping_unique_code_id_unique` with
`Using where; Using index; Not exists`. Genuinely better plan, but still 203,777
index entries plus 203,777 probes. **The index reduces cost; it does not change
the shape.** A historical ~0.4s measurement cannot rule out scan/INSERT time or
waiting inside the critical section contributing to a later queue.

### It also commits the event transaction

`beginInternalTransaction()` (`OEDbConnection.php:35`) returns a real
`beginTransaction()` when nothing is active, and an `OETransactionStub` otherwise.
On a web request `actionCreate` gets a real `BEGIN` at `:1004`.

In MariaDB `LOCK TABLES` implicitly commits an active transaction. `UNLOCK
TABLES` can also commit when releasing locks acquired by `LOCK TABLES`; it is
not an unconditional commit for every use of `UNLOCK TABLES`. The key hazard is
the premature commit at lock acquisition. See the
[implicit-commit rules](https://mariadb.com/docs/server/reference/sql-statements/transactions/sql-statements-that-cause-an-implicit-commit).
The earlier branch trace describes the intended/actual boundary below; exact
wrapper behaviour after the server commit requires deployed-code verification:

| Line | Intended | Actual |
|---|---|---|
| 1004 | `BEGIN` | real `BEGIN` |
| 1008-1020 | event INSERT, version row, elements, attachments, `updateEventStep()` | in the transaction |
| 1023 -> `BaseController.php:415` | take a table lock | **implicit COMMIT of all of the above** |
| 425-426 | mapping INSERT, `UNLOCK TABLES` | outside the original event transaction; commit behaviour depends on engine/session state |
| 1025 | `$transaction->rollback()` undoes the event | cannot undo work committed by `LOCK TABLES`; wrapper outcome may vary |
| 1029-1035 | `logActivity`, `audit`, `dispatch` in transaction | autocommit |
| 1037 | `$transaction->commit()` commits the event | commits nothing |

Two consequences beyond the locking:

1. **The rollback at `:1025` cannot undo the event.** `afterCreateElements()`
   takes the lock and *then* the code checks its return for errors. On error the
   controller believes it rolled back and returns, but the event, its version row
   and all its elements are already permanently committed. Same at `:1268`.
2. **Every later `beginInternalTransaction()` in the request returns a stub**,
   because `getCurrentTransaction()` still hands back the Yii object although the
   DB has no transaction. Anything nested after this point silently autocommits.

`protected/modules/OphCoCvi/tests/unit/controllers/DefaultControllerComplexAttrClinicalInfoTest.php:42`
stubs the model because its table locking interferes with the transaction wrapper.

`OE-18038` (`408456b5ba`, tip of `release/10.0.x`, also in `develop`) removed only
the *nested* pair inside `getActiveUnusedUniqueCode()`; the outer pair in
`createNewUniqueCodeMapping()` is still live on both branches.

### Smaller defects on the same path

- `$newUniqueCode = UniqueCodeMapping::model();` (`BaseController.php:414`)
  mutates and saves Yii's shared static singleton instead of a new instance. It
  works only because `isNewRecord` is forced true at `:424`; any later
  `UniqueCodeMapping::model()` in the request carries these attribute values.
- No `try/finally` around the lock, so an uncaught exception skips `unlock()`.
  Connections are not persistent (no `'persistent'` in
  `protected/config/core/common.php`), so the lock drops at request end - but the
  transaction stays committed.
- **Failures are silent.** `BaseActiveRecord::save()` (`:354`) catches
  `CDbException` and returns `false` rather than throwing, and `updateUniqueCode()`
  ignores the return value. If the pool is exhausted (`getActiveUnusedUniqueCode()`
  returns `null`, failing the `required` rule) or the INSERT hits the unique index,
  the caller can report success without a unique code. Caught database errors
  are logged through `OELog` subject to logging configuration; validation
  failures return false without a database exception. The captures do not prove
  either failure occurred.
- `code` carries `KEY`, not `UNIQUE`, and `GenerateUniqueCodeCommand::insert()`
  (`:122`) swallows every exception silently with no collision check. The alphabet
  is A-Z plus 2-9, 6 characters, so 34^6 = 1,544,804,416 codes. Drawing 205,020 of
  them at random gives an expected ~13.6 duplicate pairs and a ~100% chance of at
  least one. These codes go into patient letters and
  `DicomLogViewerController.php:176` joins on them for signature import.
  Check: `SELECT code, COUNT(*) n FROM unique_codes GROUP BY code HAVING n > 1;`

### develop

`UniqueCodeMapping.php`, `createNewUniqueCodeMapping()` and
`getActiveUnusedUniqueCode()` are byte-identical on `develop` apart from one space
in a cast. Upgrading changes nothing here.

### Sizing it on a live database

    SELECT COUNT(*) free, MIN(c.id) first_free, MAX(c.id) last_free FROM unique_codes c LEFT JOIN unique_codes_mapping m ON m.unique_code_id = c.id WHERE m.id IS NULL AND c.active = 1;

    EXPLAIN SELECT unique_codes.id FROM unique_codes LEFT JOIN unique_codes_mapping ON unique_code_id=unique_codes.id WHERE unique_codes_mapping.id IS NULL AND active = 1 LIMIT 1;

`first_free` is a candidate id, not an exact count of rows examined: gaps,
inactive rows and the access plan matter. Measure the plan and examined rows.

## Re-audited metadata-lock captures (2026-09-08)

Capture labels below use filename time/date suffixes only. Raw files and
customer-identifying exports must stay outside the repository.

| Capture label | Internal timestamp range | Result sets including empty sets | MDL rows / all rows | Peak concurrent MDL waiters | Maximum displayed MDL TIME |
|---|---|---:|---:|---:|---:|
| 1414_08092026 | 2026-09-08 09:31:20 | 1 | 18 / 20 | 18 | 22s |
| 1426_08092026 | 2026-09-08 14:26:01-14:28:30 | 54 | 262 / 343 | 12 | 22s |
| 1443_08092026 | 2026-09-08 14:43:16-14:45:43 | 163 | 193 / 496 | 13 | 15s |
| 1542_04092026 | 2026-09-04 15:35:11-15:43:37, with gaps | 56 | 538 / 694 | 16 | 29s |

Count rows by result-set boundary, not by timestamp: multiple polls can share
one second. These are 1,553 row observations, including 1,011 MDL observations,
not that many distinct executions. Do not sum repeated `TIME` values or equate
processlist age with slow-log `Lock_time`, transaction age or request duration.

The file labelled 1414 contains a 09:31 snapshot. The 4 September file does not
contain the previously cited 15:17:14 or 15:36:51 samples. Its dense sequence
starts at 15:42:45, with the allocation lock already showing TIME 9.

### What the observations support

The exact unique-code `LOCK TABLES` appears during every captured burst. Later
event/user writes accumulate while it waits and drain around its disappearance.
In the two afternoon captures, 81 of 82 snapshots with MDL waiters contain that
statement; the exception is a final draining snapshot.

| Capture | Direct observation |
|---|---|
| 09:31 | Two allocation-lock connections and 16 other MDL waiters; a separate routine-lock SELECT shows TIME 48 in `Statistics`. |
| 14:26 | One connection progresses from allocation-lock waits to a mapping INSERT that waits up to 9s. Another progresses from an event INSERT to allocation-lock waits. |
| 14:43 | Exactly one connection executes `LOCK TABLES` in the entire file. It is visible from 14:44:31 through 14:45:00, with a timer reset at 14:44:45. Residual MDL waiters clear by 14:45:02. |
| 4 September | One allocation-lock connection reaches TIME 28, then appears with a reset timer and reaches TIME 29. Residual MDL waiters clear by 15:43:36. |

At 14:44:43 there is **one**, not two, `LOCK TABLES` row, among 13 MDL
waiters. The event/user statements are not evidence that all reads or every
table on the instance were blocked.

The 4 September statement counts are:

| MDL-waiting statement family | Observations |
|---|---:|
| UPDATE event | 288 |
| INSERT INTO event | 155 |
| LOCK TABLES unique_codes ... | 51 |
| UPDATE user | 44 |

The target of a statement is not necessarily its requested metadata-lock object.
In particular, the 51 `LOCK TABLES` rows target the code tables, not `event`
or `user`.

### Why code-table locking can block parent-table writes

The local migrations define `unique_codes_mapping.event_id -> event.id` and
`unique_codes_mapping.user_id -> user.id`; audit columns add further user
references. Confirm the deployed foreign keys rather than assuming checkout
DDL is production DDL.

MariaDB 10.6.25's `prepare_fk_prelocking_list()` examines incoming foreign
keys when preparing parent-table writes. Its
`get_parent_foreign_key_list()` implementation enumerates foreign keys in
which the current table is referenced. Thus a write to `event` or `user`
can also request metadata access to the referencing
`unique_codes_mapping` table. See the version-pinned
[SQL prelocking code](https://github.com/MariaDB/server/blob/mariadb-10.6.25/sql/sql_base.cc)
and [InnoDB foreign-key enumeration](https://github.com/MariaDB/server/blob/mariadb-10.6.25/storage/innobase/handler/ha_innodb.cc).

That supports this candidate chain:

1. An existing connection retains a conflicting metadata lock.
2. Allocation requests the strong code-table lock and waits.
3. Later event/user writes need metadata access, potentially to the mapping
   table through foreign-key prelocking, and queue behind the strong request.
4. Releasing the incompatible lock allows work to resume.

MDL scheduling includes lock-mode priority and fairness within priorities; it
is not an unconditional FIFO. A pending strong request can block later weaker
requests even before it is granted. See
[MariaDB 10.6.25 scheduling](https://github.com/MariaDB/server/blob/mariadb-10.6.25/sql/mdl.cc).
This refines the earlier assumption that locking the mapping table must acquire
strong metadata locks on all its parents. The actual incident objects, modes
and owners still require a live lock inventory.

### What the captures do not prove

| Earlier interpretation | Correction |
|---|---|
| The original owner must be a sleeping Java worker | All captures exclude `Sleep`; most exclude `Sending data`. An idle transaction, running statement or another allocator can be hidden. No owner's client family is established. |
| Afternoon freezes exclude Java involvement | The 14:43 capture contains unquoted alphabetical-column event UPDATEs matching the earlier Hibernate-style signature. The absence of a long routine-lock SELECT cannot exclude that client family. |
| One connection id proves one PHP request and two allocator calls | A connection id is not a request id. Timer resets identify timing phases, not request boundaries or an exact call count. |
| The first lock was granted and its INSERT failed | No statement-completion/error history was captured. Timer resets and later mapping timestamps do not prove a grant, failed save, retry, or rule out errors/collisions/timeouts. |
| Two allocations alone can freeze the instance indefinitely | Visible transitions support contention involving allocation, but do not establish the full held/requested lock graph or an indefinite cycle. |
| `Updating` proves a row-lock wait or deadlock | It means searching for/updating rows; row locks require InnoDB wait evidence. `Statistics` alone likewise does not prove a mutex wait. |
| No DDL/backup can be responsible | No such statement is captured. The filtered samples do not categorically exclude earlier or hidden operations, although the allocation path is the strongest explanation of these bursts. |

MariaDB documents the [thread-state meanings](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/buffers-caches-and-threads/thread-states/general-thread-states).
The 166 repeated hotlist SELECT observations in the 14:43 file all show TIME 0;
they query `user_hotlist_item`, `patient` and `contact`, not a worklist.
They are not evidence of the dominant instance-wide workload because the
capture is filtered and samples in-flight statements.

Historical event/mapping timestamp comparisons reported an approximately
60-second interval for an affected allocation and two seconds for another.
Those separate row queries were not re-audited. Neither timestamp spacing nor
adjacent mapping ids establishes that every second was MDL wait, identifies a
failed attempt, or excludes other concurrent allocation attempts.

A long transaction spanning an event write and a routine mutex remains a
plausible contributor. Temporal coincidence is not a lock-ownership proof.
Capture both MDL and InnoDB waits before asserting a cross-layer cycle; neither
an InnoDB-only report nor processlist state alone resolves that graph.

## Diagnosing MDL, and on RDS specifically

MariaDB has `performance_schema.metadata_locks` from 10.5.2. The previous
claim that it is unavailable on every MariaDB version was incorrect. It exposes
requested and held locks, including owners, modes and status; see the
[MariaDB table documentation](https://mariadb.com/docs/server/reference/system-tables/performance-schema/performance-schema-tables/performance-schema-metadata_locks-table).
Installing `metadata_lock_info` is not needed for the confirmed instance.

A connection waiting on MDL can hold other locks and block other work. Do not
automatically kill the oldest waiter or identify the oldest idle transaction
as the blocker. Match the object and incompatible lock modes, including pending
request priority. An owner need not have modified rows or appear in INNODB_TRX.

### Confirmed operator preflight, 2026-09-08

These are operator-supplied SQL results, not settings changed by this review.

| Check | Confirmed result |
|---|---|
| VERSION() | 10.6.25-MariaDB-log |
| @@GLOBAL.performance_schema | 1 |
| wait/lock/metadata/sql/mdl | ENABLED YES, TIMED YES |
| global_instrumentation / thread_instrumentation | YES / YES |
| events_statements_current / statements_digest | YES / YES |
| events_waits_current | YES |
| events_statements_history / history_long | NO / NO |
| performance_schema_events_statements_history_size | 10 |
| Disabled statement/% instruments | None |
| Stage, transaction and wait-history consumers | NO |

**No reboot, parameter-group change or MDL-enabling UPDATE is needed.**
The disabled Performance Schema transaction consumers do not prevent reading
`information_schema.INNODB_TRX`. History size 10 is capacity, not evidence
that statement-history collection is active. Per-thread flags and complete
cross-session visibility remain to be checked.

For another instance, re-run preflight rather than copying this dated state:

```sql
SELECT VERSION(), @@GLOBAL.performance_schema;
SELECT NAME,ENABLED,TIMED FROM performance_schema.setup_instruments WHERE NAME='wait/lock/metadata/sql/mdl';
SELECT * FROM performance_schema.setup_consumers;
SHOW GLOBAL VARIABLES LIKE 'performance_schema_events_statements_history_size';
SELECT NAME,ENABLED,TIMED FROM performance_schema.setup_instruments WHERE NAME LIKE 'statement/%' AND ENABLED='NO';
```

Enabling Performance Schema itself requires a restart if it is off; switching
Database Insights on does not remove that requirement. See
[AWS configuration guidance](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.EnableMySQL.html).
Do not schedule a reboot for the already-enabled instance.

### Core capture: read-only and bounded

Use an approved monitoring account with access to these diagnostic tables and
visibility of other connections; full processlist visibility requires PROCESS.
First check that foreground application threads are instrumented and that lock
records are not being dropped:

```sql
SELECT THREAD_ID,PROCESSLIST_ID,INSTRUMENTED,HISTORY FROM performance_schema.threads WHERE TYPE='FOREGROUND';
SHOW GLOBAL STATUS LIKE 'Performance_schema_metadata_lock_lost';
```

From one external persistent connection with autocommit enabled, save these
results together about once per second for a five-to-ten-minute incident window:

```sql
SELECT UTC_TIMESTAMP(6) AS captured_at,m.*,t.PROCESSLIST_ID FROM performance_schema.metadata_locks m LEFT JOIN performance_schema.threads t ON t.THREAD_ID=m.OWNER_THREAD_ID;
SELECT UTC_TIMESTAMP(6) AS captured_at,t.* FROM performance_schema.threads t WHERE t.TYPE='FOREGROUND';
SELECT UTC_TIMESTAMP(6) AS captured_at,x.* FROM information_schema.INNODB_TRX x;
SELECT UTC_TIMESTAMP(6) AS captured_at,s.* FROM performance_schema.events_statements_current s;
```

The thread inventory includes processlist fields without excluding sleeping or
`Sending data` sessions. Preserve all lock objects and statuses, not just the
four suspected tables or PENDING rows. LEFT JOIN preserves lock rows when their
owner cannot be mapped. The snapshots are not atomic, so timestamp each set and
keep consecutive samples. Do not discard MDL owners absent from INNODB_TRX.

For a one-off unfiltered processlist with MariaDB QUERY_ID and full INFO:

```sql
SELECT UTC_TIMESTAMP(6) AS captured_at,p.* FROM information_schema.PROCESSLIST p;
```

For repeated polling, prefer the thread inventory above: MariaDB notes that
[querying PROCESSLIST can introduce locking](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/show/show-processlist).
Do not truncate statement text before preserving the secured raw capture.

When contention appears, also collect the InnoDB row-lock relationships and
recheck the lost-lock counter:

```sql
SELECT UTC_TIMESTAMP(6) AS captured_at,w.* FROM information_schema.INNODB_LOCK_WAITS w;
SELECT UTC_TIMESTAMP(6) AS captured_at,l.* FROM information_schema.INNODB_LOCKS l;
SHOW GLOBAL STATUS LIKE 'Performance_schema_metadata_lock_lost';
```

Start with one sample to measure duration/output volume. Do not overlap polls.
Monitor CPU, free memory and application latency, and stop or reduce frequency
if collection adds material overhead. This is not a zero-overhead guarantee.

The current-statement table is already enabled. MariaDB 10.6.25 can retain the
last completed top-level statement for an idle thread, so it can help even
without history; see the
[version-pinned implementation](https://github.com/MariaDB/server/blob/mariadb-10.6.25/storage/perfschema/table_events_statements.cc#L592-L620).
Compare its EVENT_ID with the lock's OWNER_EVENT_ID; a thread's latest SQL is
not necessarily the statement that acquired the lock.

### Optional short statement history: human-executed change only

This is useful if the current statement has replaced the lock-acquiring SQL.
The supplied settings satisfy the consumer/instrument prerequisites, but target
threads must also have INSTRUMENTED=YES and HISTORY=YES. Do not blindly change
all thread flags if the check above finds exclusions.

If approved for a short capture window, the only additional consumer change is:

```sql
UPDATE performance_schema.setup_consumers SET ENABLED='YES' WHERE NAME='events_statements_history';
SELECT NAME,ENABLED FROM performance_schema.setup_consumers WHERE NAME='events_statements_history';
```

This records future completed statements for every eligible thread, not only
threads selected by a later query. It cannot recover old statements. The
ten-entry per-thread ring is short-lived; export promptly when contention
appears, preferably retrieving only the involved OWNER_THREAD_ID values.

Retain THREAD_ID, EVENT_ID, END_EVENT_ID, EVENT_NAME, TIMER_WAIT, MYSQL_ERRNO,
RETURNED_SQLSTATE, ROWS_EXAMINED, DIGEST_TEXT and, in the secured raw capture,
SQL_TEXT. Match OWNER_EVENT_ID where possible. See
[statement-history fields](https://mariadb.com/docs/server/reference/system-tables/performance-schema/performance-schema-tables/performance-schema-events_statements_history-table).

Restore the confirmed original history-consumer state after the window:

```sql
UPDATE performance_schema.setup_consumers SET ENABLED='NO' WHERE NAME='events_statements_history';
```

Do not disable the MDL instrument, current statements or waits: they were
already enabled. Do not enable all instruments, history_long, stage histories
or transaction consumers for this capture. Runtime settings should be rechecked
after a restart/failover rather than assumed persistent.

### Which other monitoring is worth using?

| Facility | Value and limitation for this incident |
|---|---|
| Existing Database Insights monitoring | Correlates incident time, DB load, waits and affected SQL; does not replace the captured owner/request graph. |
| Advanced mode upgrade only for blocker trees | Not recommended for this MariaDB investigation. AWS documents lock-tree analysis for RDS/Aurora PostgreSQL, not MariaDB. |
| Slow query log | Supplementary evidence of completed slow statements; can miss a fast statement followed by a long idle transaction. Lock_time is not a complete ownership or end-to-end waiting record. |
| innodb_print_all_deadlocks | Useful for a separate confirmed row-deadlock investigation; does not log every MDL wait or prove an MDL cycle. |
| General log / broad instrumentation | Not the first choice: increases overhead and sensitive SQL collection without replacing a live lock inventory. |

See [AWS lock-analysis support](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Database-Insights-Lock-Analysis.html).
Do not change global timeouts, isolation, log settings or kill sessions as part
of this capture. Any mitigation needs an identified target, application-error
handling review and separate operator approval.

Raw SQL, hosts and identifiers can contain patient/staff/client data. Export
to an approved restricted location outside the repository with bounded
retention. Keep only sanitized conclusions here. If the original owner is
idle while application code waits elsewhere, correlate its connection id with
request/job id, transaction boundaries and external-call timings; database
instrumentation cannot explain the external delay on its own.

## `Event::lock()` spins forever

`protected/models/Event.php:842` is `SELECT GET_LOCK(?, 1)` inside
`while (!$cmd->queryScalar(...)) ;` - no attempt cap, no backoff.
`BaseEventTypeController::setPDFprintData()` (`:2471`) holds it across the whole
Puppeteer render; `OphCoCvi_Manager:679` and
`OphCoTherapyapplication_Processor:187,357` also use it. A slow or dead holder
pins one PHP worker and one DB connection per waiter indefinitely. Advisory, so
it never appears in an InnoDB deadlock report, but it lives in the same blast
radius.

## Historical branch comparison: pinned commits above

| Item | release/10.0.x | develop |
|---|---|---|
| `createInsertFromTableCommand` (`INSERT...SELECT` on `event`) | `OECommandBuilder.php:21` | byte-identical, file absent from the diff |
| `versionToTable()` before `parent::updateByPk()` | `BaseActiveRecordVersioned.php:271` | same order, only wrapped in `runInVersionedTransaction()` (OE-18188 cast-error handling) |
| `Event::lock()` uncapped `GET_LOCK` spin | `Event.php:842` | `Event.php:861`, identical |
| PDF render inside `event->lock()` | `BETC:2471-2483` | `BETC:2547-2559`, identical |
| Single `beginInternalTransaction` in actionCreate/Update | yes | yes |
| Double save (`withVersion` + `noVersion` info write) | yes | `BETC:1983/2016` + `:1927`, same |
| `UniqueCodeMapping::lock()` LOCK TABLES inside event txn | `BETC:2877` | `BETC:2961`, same |
| PASAPI `Event::updateAll(worklist_patient_id => null)` | yes | yes |

Two `develop`-only changes, neither of which helps:

1. `OE-16889` reworked `OEDbConnection` to return an `OEDbTransaction` and
   dispatch `TransactionStarted/Committed/RolledBackSystemEvent` (the `Webhooks`
   module listens), and moved `enable_transactions` from `params` to
   `SettingMetadata`. Lock behaviour unchanged; it adds a listener dispatch per
   transaction start.
2. `actionCreate` moved `EventDraft::removeDraftForEvent()` out of the
   transaction, commented: "Deleting the autosave draft inside the save
   transaction can race a concurrent autosave and roll the whole creation back
   (MariaDB 11.8 snapshot isolation, error 1020). We clean up post-commit."
   That is the only concurrency-motivated change on this path, and it is about
   `event_draft`, not `event`.

At those compared commits, the upgrade does not remove these locking paths.
This is not a claim about later branch tips or the currently deployed code.

## Adjacent bug seen in the same dumps

`LATEST FOREIGN KEY ERROR` on
`DELETE FROM ophciexamination_postop_complication_entry WHERE element_id = <id>`
because `ophciexamination_postop_complication_entry_complication` still holds a
child row. That is `saveEvent()`'s "delete elements no longer required" loop
(`$curr_element->delete()`) hitting an FK with neither `ON DELETE CASCADE` nor
application-level child cleanup. Unrelated to locking, but it aborts event saves
on its own.

## Fixes, in priority order

1. **Replace table-wide unique-code allocation locking with a transaction-safe
   allocation design.** Do not merely delete LOCK/UNLOCK or call retries
   "lock-free". Preserve the unique constraints on code allocation and event
   mapping; handle duplicate candidates, exhaustion, validation and database
   errors explicitly. Bound retries, account for REPEATABLE READ visibility,
   and retry the complete transaction where an error has rolled it back.
   Preserve event/mapping atomicity and test concurrent saves and rollback.
   Until replaced, guarantee unlock cleanup without concealing the existing
   implicit-commit hazard.
2. **Identify and shorten the original blocking transaction using the capture
   above.** A transaction spanning event work and a routine mutex is a candidate,
   not an identified owner. Check integration workers, web requests and earlier
   allocators without presupposing the client family or a two-mode split.
3. Evaluate `ORDER BY unique_codes.id DESC` against a fresh plan and current
   free-code distribution. Historical measurements suggest it could shorten
   selection, but do not guarantee a first-row hit or permanent constant cost.
   Confirm that allocation order has no application meaning before changing it.
4. Verify the historically reported `ix_unique_codes_active_id (active, id)`
   deployment and measure its effect. Faster work inside a held critical section
   can help, but an index does not remove table-wide lock contention.
5. Check for duplicate `unique_codes.code` values before designing a uniqueness
   migration and generator retry. Probability estimates are not a live duplicate
   count; any cleanup must preserve existing clinical references.
6. For the separately evidenced S-to-X deadlock pattern, evaluate READ COMMITTED
   and the binlog format only after reading the actual settings and testing the
   application's transaction semantics. It can change snapshot source locking;
   it is not an MDL fix or a guarantee against other deadlocks. The historical
   corpus supports investigation, not a claim that an unperformed change already
   reduced the deadlock count.
7. Evaluate deterministic exclusive locking before version snapshots in
   `BaseActiveRecordVersioned::updateByPk`/`updateAll`/`deleteByPk`/`deleteAll`.
   Preserve the correct pre-image and audit/version rows; do not move mutation
   before an ordinary snapshot and assume it still captures the old values.
   Test multi-row ordering and deadlock retry as well as the single-row case.
8. Evaluate consolidating the event info write and limiting modified columns
   while retaining validation, audit and versioning. Do not assume substituting
   `saveAttributes(['last_firm_id'])` preserves hooks or makes a full version
   snapshot smaller. A narrower UPDATE alone does not remove S-to-X upgrades.
9. Cap the `Event::lock()` spin and move the PDF render outside it.

## Still unverified

1. Original MDL owner, object/mode graph, lock-retention cause and any row-lock
   dependency. The supplied preflight confirms instrumentation, not ownership.
2. Actual transaction isolation, binlog format, session timeout overrides,
   deployed foreign keys and current code-pool query plan. An S lock alone does
   not uniquely establish server settings.
3. Statement completions/errors and application request boundaries behind timer
   resets. No first failed INSERT or particular retry mechanism is proven.
4. Whether any original owner was an integration worker, idle web transaction,
   active SELECT, previous allocator or another operation hidden by filtering.
5. The earlier deadlock corpus, sizing benchmarks and index-deployment report
   were not revalidated by this four-file audit. They remain historical evidence.
6. The deployed application code. Earlier local checks reported identical
   `BaseActiveRecord.php` bytes (md5 `aecc897aae502b697039398af44a7466`) across
   a host checkout and two containers, plus matching `setContext()` text. Those
   containers were not the client deployment. Source-level findings here need
   deployment confirmation before claiming the exact production implementation.
