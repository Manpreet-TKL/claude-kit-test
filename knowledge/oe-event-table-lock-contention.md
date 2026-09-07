# `event` table lock contention and deadlocks in OpenEyes (2026-08/09, analysis)

Read before diagnosing any deadlock, lock wait or MDL pile-up on the `event`
table, and before "fixing" it by upgrading a branch. Traced on
`release/10.0.x` (`408456b5ba`) and compared against `develop` (`9ae0fe1bc4`).
Line numbers are `release/10.0.x` unless stated.

Evidence base: a `SHOW ENGINE INNODB STATUS` dump (2026-08-19 deadlock), two
`SHOW FULL PROCESSLIST` captures (2026-09-04 14:12 and 15:35-15:43), production
DDL for `unique_codes`, and sizing queries run against the live database on
2026-09-04. The database is **Amazon RDS MariaDB**, which constrains the
diagnostics (see "Diagnosing MDL, and on RDS specifically").

## Summary: two independent problems

| | Problem 1 | Problem 2 |
|---|---|---|
| Symptom | InnoDB deadlock, one transaction rolled back | site-wide freeze of ~30s, then drains |
| Mechanism | version snapshot takes S, save upgrades to X | `LOCK TABLES` queues behind an idle transaction's MDL |
| Trigger | two writers on one `event` row | any cataract op note or CVI save |
| Blast radius | one save | every statement on `event`, `user`, `pathway_step` |
| Fix | isolation level or snapshot ordering | delete the `LOCK TABLES` |

Problem 2 is the one that takes the site down. Problem 1 is the one that shows up
in the deadlock report.

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

Under REPEATABLE READ (the MariaDB default), InnoDB sets **shared next-key locks
on the source rows of an `INSERT ... SELECT`**. The next statement in the same
transaction takes X on that same row. That is an S-to-X upgrade, and two
sessions doing it against one row deadlock deterministically.

OE never asks for an S lock on `event` anywhere. If a deadlock report shows
`lock mode S locks rec but not gap` on `openeyes.event` PRIMARY, it is this
snapshot and nothing else.

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

Production estates run more than one writer against `event`. The statement text
identifies which:

| Signal | Yii web app | External Java/Hibernate service |
|---|---|---|
| Identifiers | backtick-quoted | unquoted |
| Column order | Yii/table order | strictly alphabetical |
| Timestamps | `'2026-08-19 10:23:42'` | `'2026-08-19 10:28:00.0'` (`java.sql.Timestamp`) |
| Column set | full current schema, incl. `institution_id`, `step_id`, `service_firm_id` | legacy subset only |
| User column | real `last_modified_user_id` | often `1` |
| Snapshot first | yes (takes S then X) | no (takes X directly) |

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
registered listener. The event row's X lock is held for all of it.

One save writes the row **twice**: `saveEvent()` (`:1899`) does
`$this->event->withVersion()->save()`, then `updateEventInfo()` (`:1850`) does
`$this->event->noVersion()->save()`. A single event save is therefore S + X + X
on that row plus a full `event_version` row.

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
route, but on an update the mapping already exists so the lock is skipped. It is
a first-save cost. The other caller, `BaseController::getUniqueCodeForUser()`
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

So the hold time is one SELECT plus one INSERT. **The lock is cheap to hold and
expensive to acquire** - which is why the measured query cost below cannot
explain the observed 29-second waits.

### Why the SELECT degrades linearly (measured 2026-09-04)

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

The free pool is **one contiguous block** at the top of the id range, which is
what makes fix 3 below correct: scanning downward finds a free code on the first
row.

Nothing in this code changed. In 2016 the table held a few thousand rows and the
scan was invisible; it has grown by one row per code issued for nine years, so
the cost has been climbing linearly ever since. That is the answer to "why now".

`ix_unique_codes_active_id (active, id)` was added on 2026-09-04. `EXPLAIN` after
it: `ref` on the new index, `key_len 4`, `rows 95746`, `Extra: Using index`
(covering), and `eq_ref` on `unique_code_mapping_unique_code_id_unique` with
`Using where; Using index; Not exists`. Genuinely better plan, but still 203,777
index entries plus 203,777 probes. **The index reduces cost; it does not change
the shape.** At ~0.4s it was never the thing causing 29-second stalls.

### It also commits the event transaction

`beginInternalTransaction()` (`OEDbConnection.php:35`) returns a real
`beginTransaction()` when nothing is active, and an `OETransactionStub` otherwise.
On a web request `actionCreate` gets a real `BEGIN` at `:1004`.

In MariaDB **both** `LOCK TABLES` and `UNLOCK TABLES` implicitly commit the open
transaction. Yii is not told:

| Line | Intended | Actual |
|---|---|---|
| 1004 | `BEGIN` | real `BEGIN` |
| 1008-1020 | event INSERT, version row, elements, attachments, `updateEventStep()` | in the transaction |
| 1023 -> `BaseController.php:415` | take a table lock | **implicit COMMIT of all of the above** |
| 425-426 | mapping INSERT, `UNLOCK TABLES` | second implicit commit |
| 1025 | `$transaction->rollback()` undoes the event | `ROLLBACK` with nothing open, silent no-op |
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

The OE team knows -
`protected/modules/OphCoCvi/tests/unit/controllers/DefaultControllerComplexAttrClinicalInfoTest.php:42`
stubs the model out with the comment "The UniqueCodeMapping model interferes with
transactions through the use of mysql LOCKing, which subsequently causes problems
with our transaction wrapper."

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
  the event saves with no unique code and no error anywhere.
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

`first_free` is the depth of the scan.

## The lock storms: one op-note save, sixty seconds of freeze

Established from `newmedica_processlist_1542_04092026.txt`, 2026-09-04, and
confirmed against the `event` table on 2026-09-04. This supersedes the earlier
guess that a backup or `FLUSH TABLES` was responsible - **there was no DDL and no
backup activity anywhere in the capture. The application is the cause.**

Poll coverage is not continuous: isolated samples at 15:17:14, 15:35:11-12 and
15:36:51 (all quiet, no MDL waits), then dense one-per-second polling from
15:42:45 to 15:43:37. The freeze was already ~9 seconds old when dense polling
started, so its onset is reconstructed from the `TIME` column, not observed.

| Observation | Value |
|---|---|
| Sessions that issued `LOCK TABLES` | **one**, thread 32276260 |
| Its two statements | 15:42:36-15:43:05 (28s+), then 15:43:06-15:43:35 (29s) |
| Trigger | `event` 11510755, `OphTrOperationnote`, `created_date` 15:42:35 |
| Distinct sessions blocked | 26 |
| Rows waiting on MDL | 538 of 691 (78%) |
| Oldest waiter throughout | the `LOCK TABLES` session |
| Tables blocked | `event` and `user`, **nothing else** |
| DDL / backup in the file | none |

Two findings from this capture are decisive.

**The trigger is confirmed, to the second.** The op note's `event` row was
inserted at 15:42:35 (`saveEvent()`, `:1008`); the `LOCK TABLES` began waiting at
15:42:36 (`afterCreateElements()`, `:1023`). The one-second gap is the element
saves in between. Only two op notes exist in the whole 15:40-15:46 window and the
second one matches exactly.

**The blocked set is exactly the FK parent set.** All 538 MDL-waiting rows are one
of four statements, and every one targets `event` or `user`:

| Blocked statement | Rows |
|---|---|
| `UPDATE event` | 288 |
| `INSERT INTO event` | 155 |
| `LOCK TABLES unique_codes ...` | 51 |
| `UPDATE user` | 44 |

`event` and `user` are precisely the foreign-key parents of
`unique_codes_mapping` (`event_id` -> `event`; `user_id`, `created_user_id`,
`last_modified_user_id` -> `user`). Not one statement against any other table was
blocked. A backup, a `FLUSH TABLES` or a schema-wide operation would have blocked
unrelated tables too. Nothing else produces this exact set, which promotes the
FK-induced MDL expansion from inference to strong evidence.

The chain:

1. Something holds an open write transaction that has touched `event`, so it
   holds a shared-write MDL on that table. At 15:42:36 no visible session was old
   enough to be it (the earliest `Statistics` wait started 15:42:50), so for this
   wave the holder was `COMMAND = Sleep` and hidden by the capture's
   `COMMAND <> 'Sleep'` filter.
2. A clinician saves a cataract op note. OE inserts the `event` row, then reaches
   `createNewUniqueCodeMapping()` and issues `LOCK TABLES`.
3. That table lock needs a strong MDL covering `unique_codes_mapping` and its FK
   parents, `event` included. It cannot get `event`, so it parks.
4. **MDL is a fair FIFO queue.** Every later `INSERT INTO event`, `UPDATE event`
   and `UPDATE user` queues behind the parked `LOCK TABLES`, although none of them
   conflict with each other. 26 sessions piled up.
5. The wait ends ~29s later having written nothing, and the request
   **immediately issues `LOCK TABLES` a second time**, freezing the site for
   another 29s. Only that second grant writes the mapping row, at 15:43:35. The
   queue drained at 15:43:36.

The holder need not be idle. A Java worker sitting in state `Statistics` for 28s
on `select requestrou0_.routine_lock ... where requestrou0_.routine_lock='508947'
for update` (a single-row application mutex, always the same row) holds the
`event` MDL just as effectively if its transaction already wrote to `event`. Those
sessions are visible in the capture and alternate between that mutex and
`UPDATE event`, which is the shape of a transaction spanning both.

### One request, both locks, and only the second one wrote anything

Thread ids increment monotonically and new connections at 15:43:06 were being
issued ids around 32277xxx, so 32276260 cannot be a reused id: it is the same
connection, therefore the same PHP request, taking the lock twice. So **one op
note save is responsible for the whole ~60 second outage**, not two events.

The mapping rows confirm it and add a free control (2026-09-04):

    SELECT id, event_id, unique_code_id, created_date FROM unique_codes_mapping WHERE event_id IN (11510743, 11510755);

| mapping id | event_id | unique_code_id | created_date | event created | elapsed |
|---|---|---|---|---|---|
| 209849 | 11510743 | 203773 | 15:41:43 | 15:41:41 | **2s** |
| 209850 | 11510755 | 203774 | 15:43:35 | 15:42:35 | **60s** |

**The control.** Event 11510743 is the same event type, the same code path and the
same two tables, 54 seconds earlier, and it finished in two seconds. That is
production evidence, not an argument from `EXPLAIN`, that neither the anti-join
nor `LOCK TABLES` itself is slow. The entire 60 seconds is MDL wait.

**The first 29 seconds produced nothing.** `created_date` is stamped in PHP by
`BaseActiveRecord::save()` at the moment `save()` is entered, which is after the
lock is granted. 15:43:35 is the end of the *second* wait (15:43:06 + 29s), not
the first (15:42:36 + 29s = 15:43:05). No row carries a 15:43:05 timestamp, so the
first freeze bought the request nothing at all.

**The unique-index collision theory is refuted.** Only one row exists for the
event, so the second pass was not an insert that could never succeed - the
`findAllByAttributes` guard was correct to retry, there genuinely was no row.

**Consecutive ids.** 209849 and 209850 are adjacent, so no other event anywhere in
the estate obtained a code between 15:41:43 and 15:43:35. 32276260 was the sole
lock-taker for the whole window.

The lock was granted at ~15:43:05 and the `save()` failed - see the next section
for the proof and the two remaining candidates. `BaseActiveRecord::save()` catches
`CDbException`, logs a `uniqid()`-tagged message through `OELog::log()` and returns
false, so a failed write is silent to the caller. `updateUniqueCode()` is called
from both `afterCreateElements()` and `afterUpdateElements()`, so a
create-then-update request enters it twice, and on the second entry the guard
finds nothing precisely because the first save failed.

The OE application log for 2026-09-04 around 15:43:05 would name the failing
statement, but only if `params['log_events']` is on.

### The first lock was granted, and the save failed silently

`SHOW VARIABLES LIKE 'lock_wait_timeout'` on the production instance returns
**86400**, the RDS default. Nothing on this path times out at 30 seconds, so the
first `LOCK TABLES` was **granted**, not aborted. That closes the timeline to the
second:

| Time | Event |
|---|---|
| 15:42:35 | `event` 11510755 inserted (`saveEvent()`) |
| 15:42:36 | `LOCK TABLES` #1 issued, parks on the `event` MDL |
| 15:43:05 | granted, 29s later |
| 15:43:05-06 | the 0.4s picker SELECT runs, `save()` **fails**, `UNLOCK TABLES` |
| 15:43:06 | `LOCK TABLES` #2 issued, parks again |
| 15:43:35 | granted, 29s later; `save()` succeeds, mapping 209850 written |
| 15:43:36 | `UNLOCK TABLES`, the 26-session queue drains |

The one-second gap between the first grant and the re-issue is exactly the picker
SELECT plus a failed insert. Two candidates remain for the failure, and they are
distinguishable:

1. **An InnoDB error swallowed by `save()`.** The `INSERT INTO
   unique_codes_mapping` takes shared row locks on its FK parents, `event` and
   `user`, and 15:43:05-06 is precisely when 26 queued sessions were released in a
   thundering herd onto those two tables. A deadlock (1213) returns instantly;
   `BaseActiveRecord::save()` catches the `CDbException`, logs through `OELog` and
   returns false.
2. **Validation.** `rules()` makes `unique_code_id` required, so if
   `getActiveUnusedUniqueCode()` returned NULL, `save()` returns false with no
   exception and no log line at all.

Check with `SHOW GLOBAL STATUS LIKE 'Innodb_deadlocks';` for a baseline, and set
`innodb_print_all_deadlocks = 1` in the parameter group (dynamic, no reboot) so
every deadlock reaches the RDS error log instead of only the most recent one being
visible in `SHOW ENGINE INNODB STATUS`.

### The holder: a Java worker holding `event` across an application mutex

Two Java sessions in the capture make the mechanism explicit. Both alternate
between one `UPDATE event` and one `select requestrou0_.routine_lock ... where
requestrou0_.routine_lock='508947' for update` - a **single-row global mutex** the
whole worker fleet funnels through.

| Thread | 15:42:44-15:43:07 | 15:43:07 onward |
|---|---|---|
| 32234634 | `UPDATE event`, blocked on MDL | holds nothing visible; **waits 28s+ on the mutex row** |
| 32244468 | waits 15s on the mutex row | holds the mutex row; its `UPDATE event` blocked on MDL |

32244468's mutex wait ended at the same instant `LOCK TABLES` #1 was granted
(~15:43:05), so the transaction that released the `event` MDL is the same one that
released the mutex row. The MDL holder is a worker in this cycle. It is not
visible directly because every capture filters `COMMAND <> 'Sleep'`.

From 15:43:08 there is a **circular wait that InnoDB cannot detect**:

1. OE's `LOCK TABLES` waits for a strong MDL on `event`.
2. 32234634 has just written to `event` and waits on the mutex row.
3. 32244468 holds the mutex row and its own `UPDATE event` is queued behind OE's
   `LOCK TABLES` in the MDL FIFO.

MariaDB's deadlock detector covers InnoDB row locks only. A cycle that runs
through a metadata lock is invisible to it, never rolled back, and unwinds only
when a client gives up or a timeout fires - and `lock_wait_timeout` is 86400.

This is the direct evidence behind fix 2. Any Java transaction that touches
`event` and then waits on `routine_lock='508947'` converts a worker-side queue
into an estate-wide `event` freeze the moment one op note is saved.

## Diagnosing MDL, and on RDS specifically

If the stalled sessions say **"Waiting for table metadata lock"** rather than
showing a row-lock wait, no amount of index tuning helps. The holder is not in
`SHOW ENGINE INNODB STATUS`, and it is almost never the oldest *waiter*:
everything showing "Waiting for table metadata lock" is a victim.

MariaDB has no `performance_schema.metadata_locks` at any version - that table is
MySQL 5.7+. MariaDB's only MDL introspection is the `metadata_lock_info` plugin
(`INSTALL SONAME 'metadata_lock_info';`), which needs privileges **Amazon RDS does
not grant**, so on RDS there is no direct view of who holds an MDL. Identify the
holder indirectly instead - works on any deployment and is enough:

    USE information_schema;

    SELECT t.trx_mysql_thread_id id, t.trx_started, t.trx_state, t.trx_rows_modified, p.command, p.time, p.user FROM innodb_trx t JOIN processlist p ON p.id=t.trx_mysql_thread_id ORDER BY 2;

The holder is the row with `command = Sleep`, `trx_state = RUNNING`,
`trx_rows_modified > 0`, `trx_query = NULL` and a `trx_started` older than the
oldest waiter: idle in an open write transaction.

On RDS the retrospective route beats polling. Enable the slow query log in the
parameter group (`slow_query_log=1`, `long_query_time=5`, `log_output=TABLE`) and
read `mysql.slow_log` by SQL; rotate with `CALL mysql.rds_rotate_slow_log();`.
Slow-log `Lock_time` is table-lock and MDL wait time, **not** row-lock wait, so
every stalled `LOCK TABLES` and everything queued behind it records itself with a
timestamp and no need to catch the storm live. Kill a live holder with
`CALL mysql.rds_kill(<thread_id>);` - plain `KILL` needs privileges the RDS
master user does not have.

Two RDS parameter-group stopgaps, neither a fix, both capping blast radius:

1. `idle_write_transaction_timeout` (check
   `SHOW VARIABLES LIKE 'idle%transaction_timeout';` first, it is version
   dependent) set to ~10. Kills sessions idling with an open write transaction,
   which is exactly the failure mode. Check what it would have hit before
   enabling.
2. `lock_wait_timeout`, default 86400, set to 30-60. The parked `LOCK TABLES`
   gives up instead of holding the queue open. Trade-off: the op-note save throws
   a visible error instead of hanging, and there is no `try/finally` to clean up.

Other RDS angles: Performance Insights has the window already recorded if it is
on (expect connection-count and table-lock shapes, MariaDB does not instrument
MDL waits by name); and if RDS Proxy is in use, `LOCK TABLES` forces session
pinning, so check `DatabaseConnectionsCurrentlySessionPinned`.

## `Event::lock()` spins forever

`protected/models/Event.php:842` is `SELECT GET_LOCK(?, 1)` inside
`while (!$cmd->queryScalar(...)) ;` - no attempt cap, no backoff.
`BaseEventTypeController::setPDFprintData()` (`:2471`) holds it across the whole
Puppeteer render; `OphCoCvi_Manager:679` and
`OphCoTherapyapplication_Processor:187,357` also use it. A slow or dead holder
pins one PHP worker and one DB connection per waiter indefinitely. Advisory, so
it never appears in an InnoDB deadlock report, but it lives in the same blast
radius.

## `release/10.0.x` vs `develop`: nothing relevant has changed

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

**Upgrading `release/10.0.x` to `develop` does not fix `event` deadlocks or the
lock storms.**

## Adjacent bug seen in the same dumps

`LATEST FOREIGN KEY ERROR` on
`DELETE FROM ophciexamination_postop_complication_entry WHERE element_id = <id>`
because `ophciexamination_postop_complication_entry_complication` still holds a
child row. That is `saveEvent()`'s "delete elements no longer required" loop
(`$curr_element->delete()`) hitting an FK with neither `ON DELETE CASCADE` nor
application-level child cleanup. Unrelated to locking, but it aborts event saves
on its own.

## Fixes, in priority order

1. **Drop `LOCK TABLES` from `UniqueCodeMapping::lock()`/`unlock()`.** The unique
   index on `unique_code_id` already enforces one mapping per code, so
   insert-and-retry-on-duplicate is correct and lock-free. This removes the MDL
   convoy, un-breaks the event save transaction (`LOCK TABLES` is what commits it
   part-way), and makes the rollback at `:1025` mean something again. Three bugs,
   one change. Highest value by a wide margin.
2. **Stop the external Java service holding a transaction open across the
   `request_routine_lock` mutex.** Without a holder there is nothing for step 3 of
   the chain to queue behind. Fixes the same storm from the other end, and also
   removes the multi-hour idle transactions feeding `History list length`.
3. Add `ORDER BY unique_codes.id DESC` to the query at `BaseController.php:436`.
   Free codes are one contiguous block at the top of the id range, so scanning
   downward finds one on the first row. Cost drops from "every code ever issued"
   to "codes consumed since the last top-up", permanently. The codes are random,
   so issuing the newest rather than the oldest changes nothing that matters. One
   clause, no migration. A cost reduction, not a fix for the storms.
4. `ix_unique_codes_active_id (active, id)` - **applied 2026-09-04.** Keep it;
   pair it with 3. Alone it improves the plan but not the shape.
5. Add `UNIQUE` on `unique_codes.code` and a retry in the generator, after
   cleaning up the duplicates that are near-certainly already there.
6. `transaction-isolation = READ-COMMITTED` with `binlog_format = ROW`. Under
   READ COMMITTED, InnoDB runs the SELECT side of `INSERT ... SELECT` as a
   consistent read and takes no S locks on the source, so the S-to-X upgrade
   deadlock disappears with zero code change. No gap-lock-dependent logic on
   `event` was found in either branch. Confirm the current isolation level and
   binlog format before proposing it.
7. In `BaseActiveRecordVersioned::updateByPk`/`updateAll`/`deleteByPk`/`deleteAll`,
   acquire X before snapshotting (`SELECT ... FOR UPDATE` on the PK first, or
   mutate then snapshot the pre-image) so the transaction never upgrades.
8. Fold `updateEventInfo()`'s `info` write into the single
   `withVersion()->save()` in `saveEvent()`, and save only dirty attributes
   instead of every column including `id`.
9. Cap the `Event::lock()` spin and move the PDF render outside it.

## Not verified

- Server-side `transaction_isolation` and `binlog_format` were inferred from the
  `lock mode S` in the deadlock report, not read from the server.
- The MDL holder is identified by class but not by session id. Its release
  coincides exactly with the release of the `routine_lock='508947'` mutex row, so
  it is a Java worker in that cycle, but the `COMMAND <> 'Sleep'` filter on every
  capture hid the row itself. The `innodb_trx` join above names it next time.
- The FK-induced expansion of the `LOCK TABLES` MDL set is strongly evidenced (the
  blocked set is exactly `event` + `user`, with no other table touched in 538
  rows) but has not been read from a lock table or reproduced in isolation. The
  container experiment settles it.
- Why the first `LOCK TABLES` grant wrote no row is unresolved. A unique-index
  collision and a lock timeout are both ruled out; an InnoDB error swallowed by
  `save()` and a `unique_code_id` validation failure both remain.
  `Innodb_deadlocks` plus `innodb_print_all_deadlocks` separate them.
- Analysis is from the git branches. Per `project_oe_host_checkout_lags_container`,
  a running container can differ from any host clone - confirm file:line against
  the deployed source before quoting it to a client.
