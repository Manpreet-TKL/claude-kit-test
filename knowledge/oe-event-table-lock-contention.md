# `event` table lock contention and deadlocks in OpenEyes (2026-08, analysis)

Read before diagnosing any deadlock, lock wait or MDL pile-up on the `event`
table, and before "fixing" it by upgrading a branch. Traced on
`release/10.0.x` (`408456b5ba`) and compared against `develop` (`9ae0fe1bc4`).
Line numbers are `release/10.0.x` unless stated.

## The mechanism: the version snapshot takes S, the save then upgrades to X

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

## Recognising it in `SHOW ENGINE INNODB STATUS`

    *** (1) ... UPDATE `event` SET `id`='...', ... WHERE `event`.`id`='...'
        WAITING: index PRIMARY of table `openeyes`.`event` lock_mode X locks rec but not gap waiting
        CONFLICTING WITH: ... trx id <n> lock mode S locks rec but not gap
    *** (2) ... update event set created_date=..., ... where id=<same id>
        WAITING: ... lock_mode X ... CONFLICTING WITH: trx <n> lock mode S

Both transactions hold S on the same PK record and both want X. Whichever
InnoDB rolls back is arbitrary; the pairing is the diagnosis.

## Telling the writers apart by SQL fingerprint

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

## What else is inside the event save transaction

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

## `LOCK TABLES` inside the event transaction (implicit commit)

`afterCreateElements`/`afterUpdateElements` -> `updateUniqueCode()` ->
`BaseController::createNewUniqueCodeMapping()` (`:412`) calls
`UniqueCodeMapping::lock()`, which is
`LOCK TABLES unique_codes READ, ... unique_codes_mapping WRITE ...`
(`protected/models/UniqueCodeMapping.php:92`), then `UNLOCK TABLES`.

In MariaDB **both** `LOCK TABLES` and `UNLOCK TABLES` implicitly commit the open
transaction. For any event type listed in `unique_code_elements` the event-save
transaction is silently committed part-way and the later `$transaction->commit()`
covers nothing. `OE-18038` (`408456b5ba`, tip of `release/10.0.x`, also in
`develop`) removed only the *nested* pair inside `getActiveUnusedUniqueCode()`;
the outer pair in `createNewUniqueCodeMapping()` is still live on both branches.

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

**Upgrading `release/10.0.x` to `develop` does not fix `event` deadlocks.**

## Metadata locks are a different problem

If the stalled sessions say **"Waiting for table metadata lock"** rather than
showing a lock wait, no application change helps. Look for sessions `ACTIVE` for
hours holding a row lock with no running query (idle-in-transaction, typically a
Java connection pool); a large `History list length` corroborates. Any DDL
arriving on `event` queues behind those, and every later statement queues behind
the DDL.

The MDL holder is not in `SHOW ENGINE INNODB STATUS`. Get it with:

    SELECT * FROM performance_schema.metadata_locks WHERE OBJECT_NAME = 'event'\G

    SELECT id, user, host, db, command, time, state, LEFT(info,120) FROM information_schema.processlist WHERE command <> 'Sleep' ORDER BY time DESC LIMIT 20\G

## Adjacent bug seen in the same dumps

`LATEST FOREIGN KEY ERROR` on
`DELETE FROM ophciexamination_postop_complication_entry WHERE element_id = <id>`
because `ophciexamination_postop_complication_entry_complication` still holds a
child row. That is `saveEvent()`'s "delete elements no longer required" loop
(`$curr_element->delete()`) hitting an FK with neither `ON DELETE CASCADE` nor
application-level child cleanup. Unrelated to locking, but it aborts event saves
on its own.

## Fixes, cheapest first

1. `transaction-isolation = READ-COMMITTED` with `binlog_format = ROW`. Under
   READ COMMITTED, InnoDB runs the SELECT side of `INSERT ... SELECT` as a
   consistent read and takes no S locks on the source, so the S-to-X upgrade
   deadlock disappears with zero code change. No gap-lock-dependent logic on
   `event` was found in either branch. Highest value change; confirm the current
   isolation level and binlog format before proposing it.
2. In `BaseActiveRecordVersioned::updateByPk`/`updateAll`/`deleteByPk`/`deleteAll`,
   acquire X before snapshotting (`SELECT ... FOR UPDATE` on the PK first, or
   mutate then snapshot the pre-image) so the transaction never upgrades.
3. Fold `updateEventInfo()`'s `info` write into the single
   `withVersion()->save()` in `saveEvent()`, and save only dirty attributes
   instead of every column including `id`.
4. Get any external writer off concurrent `event` writes, and fix its
   idle-in-transaction pooling - that is what feeds the multi-hour transactions
   and the MDL queue.
5. Cap the `Event::lock()` spin and move the PDF render outside it.

## Not verified

- Server-side `transaction_isolation` and `binlog_format` were inferred from the
  `lock mode S` in the deadlock report, not read from the server.
- The MDL holder in the sample dump was never identified; the diagnostic queries
  above were not run.
- Analysis is from the git branches. Per `project_oe_host_checkout_lags_container`,
  a running container can differ from any host clone - confirm file:line against
  the deployed source before quoting it to a client.
