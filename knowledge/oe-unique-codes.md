# OpenEyes unique codes: what they are, how the pool works, and why the locking has to go

Read before touching `unique_codes`, `unique_codes_mapping`,
`GenerateUniqueCodeCommand`, `BackfillMissingPucCodesCommand`, or anything that resolves a
six-character code back to an event. Traced on `release/10.0.x` (`408456b5ba`, tag
`v10.0.34`) and compared against `develop` on 2026-08-25. For the deeper `event`-row lock
mechanics (S-to-X upgrade on the version snapshot, `Event::lock()` spin, deadlock
signatures) read `oe-event-table-lock-contention.md` first - this file is the unique-codes
half and does not repeat it.

## 1. What a unique code is

A six-character token drawn at random from a 34-character alphabet: `A-Z` plus the digits
`2-9`. The digits `0` and `1` are excluded (`implode(range('A','Z')) . implode(range(2,9))`
in `GenerateUniqueCodeCommand::run()`), presumably so a printed code cannot be misread as
`O` or `I`. That gives a keyspace of 34^6 = 1,544,804,416.

Codes are **not** generated on demand. They are pre-generated into a pool and handed out
one at a time.

| Table | Role |
|---|---|
| `unique_codes` | the pool. `id`, `code varchar(6) NOT NULL`, `active int(1) unsigned NOT NULL DEFAULT 1`, plus the four audit columns. **No index on `code` at all** - only `PRIMARY` and the two FK indexes on `created_user_id` / `last_modified_user_id`. |
| `unique_codes_mapping` | the allocation. `id`, `event_id` (nullable, FK to `event`), `unique_code_id` (NOT NULL, FK to `unique_codes`), `user_id` (nullable, FK to `user`). `UNIQUE(unique_code_id)` and `UNIQUE(event_id)`. |

A row in `unique_codes` with no matching row in `unique_codes_mapping` is a free code. The
two unique keys on the mapping table mean one code per event and one event per code are
already guaranteed by the database. **The only axis on which duplication is possible is
`unique_codes.code` itself.**

### 1.1 The printed form is not the stored form

`OphTrOperationnote_API::getPatientUniqueCode()` (the `puc` correspondence shortcode, which
is where the name "PUC" comes from - Patient Unique Code) wraps the six characters in check
digits:

    <institution_code><check_digit_1>-<CODE>-<check_digit_2>

`check_digit_1` is generated over `institution_code . code`, `check_digit_2` over
`code . patient->dob`, both salted with `params['portal']['credentials']['client_id']`.
So the printed identifier is patient-specific even though the code is not.

**No consumer validates either check digit.** `PortalExamsCommand` does
`explode('-', $examination['patient']['unique_identifier'])` and takes `$uidArray[1]`, the
middle segment, and everything downstream resolves on that alone. The check digits are
presentation-only. That matters twice over: they do not detect a mistyped code, and they do
not disambiguate a duplicated one (see section 10).

## 2. What the codes are used for, and why they are pre-generated at all

Allocation is narrow. `BaseEventTypeController::updateUniqueCode()` is called from
`afterCreateElements()` and `afterUpdateElements()`, so on every event save, but it only
acts for the event types in the private `$unique_code_elements` list:

| Event type | Element |
|---|---|
| `OphTrOperationnote` | `Element_OphTrOperationnote_Cataract` |
| `OphCoCvi` | `Element_OphCoCvi_EventInfo` |

So: cataract operation notes and CVI events, and nothing else. The code is printed into
correspondence and quoted by external systems as the sole identifier of the record.

Resolution back to an event goes through `UniqueCodes::eventFromUniqueCode($code)`. Its
callers:

| Caller | What it does with the answer |
|---|---|
| `protected/modules/Api/controllers/v1/SignController.php:155` | records a signature against the returned event. Guards `if ($event)`. |
| `protected/modules/OphCiExamination/commands/PortalExamsCommand.php:53` | portal examination import. Logs "Unfound Event" on null and parks the payload in `automatic_examination_event_log` keyed by `unique_code`. |
| `protected/controllers/oeadmin/EventLogController.php:152` | admin lookup. |

Dead code to know about, so it is not mistaken for a live path:

- `BaseController::getUniqueCodeForUser()` - zero callers anywhere in the tree. It would
  allocate a code against a user rather than an event.
- `UniqueCodes::getEpisodeIdFromCode()` - zero callers, and it interpolates `$code`
  straight into the join condition (`"... and uc.code ='$code'"`). Should be deleted, not
  repaired.
- `UniqueCodes::codeForEventId()` interpolates `$id` the same way but **does** have
  callers.

### 2.1 Why they have to exist

The code is the handle an outside system holds. A cataract operation note is signed back
through the API and a portal examination is imported against the operation note weeks
later; in both cases the only thing the far end quotes is those six characters. It cannot
be the event id, because the event id is an internal auto-increment that leaks record
counts and is trivially enumerable, and it cannot be anything patient-identifying, because
the identifier travels on paper. So it has to be a short, opaque, per-event token, and it
has to exist for every cataract operation note and CVI or that record is simply
unreachable from outside. An event saved without one is not degraded, it is invisible.

### 2.2 Why they are pre-generated, and why that reasoning does not hold

Nothing in the tree explains the pool. The originating commit (`cdcceb1e66`, "Unique Codes
integrated with events") has an empty body, there is no ADR, and there is no comment. Two
rationales are inferable, and neither survives:

1. *Vet the codes for uniqueness in advance, so a save never has to deal with a collision.*
   The pool does not do this. There is no unique index on `unique_codes.code` and the
   generator's insert sat inside `try { } catch (Exception $e) { }` with an empty catch, so
   a colliding code is stored, not rejected. The pool is a bag of possibly-duplicate codes.
2. *Keep the cost of generating and retrying out of the request.* Real, but the cost being
   avoided is one insert with a ~1-in-6,000 retry rate (section 9). What the pool
   substitutes for it is a table lock, a weekly cron, a whole-pool scan and an entire
   failure mode where the event gets no code at all.

That is the case for section 11: the pool buys nothing it was meant to buy and costs
everything in sections 6 to 8.

## 3. The flow, end to end

    generateuniquecodes.sh (cron)                   supply
      -> yiic generateuniquecode [limit=1500]
      -> count free codes (anti-join)
      -> generate random codes until free count = limit
      -> INSERT INTO unique_codes

    unique_codes                                    the pool
      free = no row in unique_codes_mapping

    clinician saves a cataract op note or a CVI      demand
      -> BaseEventTypeController::afterCreateElements() / afterUpdateElements()
      -> updateUniqueCode()            (only for the two elements in section 2)
      -> BaseController::createNewUniqueCodeMapping($event->id, null)
      -> UniqueCodeMapping::lock()     LOCK TABLES ... WRITE   <-- implicit commit, section 6.1
      -> getActiveUnusedUniqueCode()   anti-join, LIMIT 1      <-- whole-pool scan, section 7
      -> save()                        INSERT unique_codes_mapping
      -> UniqueCodeMapping::unlock()   UNLOCK TABLES           <-- implicit commit again

    correspondence [puc] shortcode                  consumption
      -> OphTrOperationnote_API::getPatientUniqueCode()
      -> <institution_code><cd1>-<CODE>-<cd2> onto paper

    external system quotes the code back
      -> SignController / PortalExamsCommand / EventLogController
      -> UniqueCodes::eventFromUniqueCode($code) -> event

    backfillmissingpuccodes (cron, site-local, not in the repo)   repair
      -> find events of those two types with no mapping row
      -> allocate a free code to each

Three commands, three different jobs. They are routinely confused:

| Command | Side | What it does | Where it lives |
|---|---|---|---|
| `generateuniquecode` | supply | tops the **pool** up to N free codes. Never touches an event. | in the repo, `protected/commands/GenerateUniqueCodeCommand.php` |
| the save path | demand | allocates one pool code to one event, at save time | `BaseController::createNewUniqueCodeMapping()` |
| `backfillmissingpuccodes` | repair | allocates pool codes to events that were saved while the pool was empty | **not in the repo** - see section 4 |

The dependency runs one way: the backfill can only hand out codes the generator has already
put in the pool. Running the backfill against an empty pool does nothing except scan the
pool very hard (section 8).

The cron wrapper is `protected/scripts/cronrunner.sh`, which does `eval $@` and appends
everything to one log. The `eval` re-splits its argument, so quoting in the crontab line
matters and a single-quoted SQL string is not passed through opaquely.

## 4. Nothing in the codebase repairs an event that missed its code

Item checked on `develop` on 2026-08-25, and on every other branch:

    git grep -n 'unique_codes_mapping\|UniqueCodeMapping' origin/develop -- 'protected/**/*.php'
    git log --all --oneline -S'unique_codes_mapping' -- 'protected/migrations/*'

There is exactly one writer of `unique_codes_mapping` on `develop`:
`BaseController::createNewUniqueCodeMapping()`, reached from
`BaseEventTypeController` (line 2961) and from the dead `getUniqueCodeForUser()`. The only
unique-code command in the tree is `GenerateUniqueCodeCommand`, which is the supply side and
never looks at an event. No migration inserts a mapping. There is no admin screen, no
maintenance action and no repair route.

**One in-application repair path does exist and is easy to miss:** `updateUniqueCode()` runs
from `afterUpdateElements()` as well as `afterCreateElements()`, so opening an existing
cataract operation note and saving it will allocate a code if the event has none. That is
real but it is not a mass-repair route - it needs a human to open every affected event, and
it rewrites the event's last-modified stamp and creates a version row while doing it.

Hence `BackfillMissingPucCodesCommand`. The version deployed on the live instance was
written site-side and exists in no branch. Section 12 packages a version for the repo.

## 5. `release/10.0.x` vs `develop`: the unique-code path is identical, so there is nothing to back-port

Checked on 2026-08-24. Every file in the unique-code path is byte-identical on the two
lines:

    git diff origin/release/10.0.x origin/develop -- protected/commands/GenerateUniqueCodeCommand.php protected/models/UniqueCodeMapping.php protected/models/UniqueCodes.php protected/scripts/.cron/generateuniquecodes protected/scripts/generateuniquecodes.sh

`BaseController::createNewUniqueCodeMapping()` and
`BaseEventTypeController::updateUniqueCode()` differ only in line numbers.

`OE-18038` ("remove nested locks for unique code mapping", `408456b5ba`, the tip of
`release/10.0.x`) is present on both lines, and it is easy to over-read: it removed the
**nested** `lock()`/`unlock()` pair inside `getActiveUnusedUniqueCode()` only. The outer
pair in `createNewUniqueCodeMapping()` survived on both branches. If someone says "this is
already fixed on develop", that commit is what they are thinking of, and it is not a fix
for either fault above.

Practical consequence: base the work on `release/10.0.x` and let the standard merge
forward (`release/10.0.x` -> `release/11.0.x` -> `release/26.0.x` -> `develop`) carry it.
One PR per logical change reaches every line.

### 5.1 Two develop-only differences that post-date the base, neither of them a fix

`OE-18351` ("Refactor event handling and transaction management in
BaseEventTypeController", `295f56e644`, 2026-08-11) is on `develop` only - not on
`release/11.0.x`, not on `release/26.0.x`, not on `master`. It moves the post-commit work
(`afterCreateEvent()`, the redirects) out of the try block, widens `catch (Exception)` to
`catch (Throwable)`, and carries this comment:

> rolling back a committed transaction throws, and that exception would replace whatever
> actually went wrong here

That is the same class of bug as 6.1, recognised and guarded for the code the author knew
ran after the commit. `LOCK TABLES` produces a second implicit commit *inside* the
transaction, which the refactor does not address: on `develop`, `afterCreateElements()` is
still called from inside the event transaction and still reaches `updateUniqueCode()`. It
does not overlap with the change in 6.4 either, which lives in `BaseController`.

The two lines also pin different framework versions - `release/10.0.x` has
`yiisoft/yii: 1.1.31`, `develop` has `dev-master#a2d4af95` (which reports itself as
`1.1.33-dev`). Worth checking, because it decides the behaviour described in 6.1: both
carry the same `inTransaction()` guard in `CDbTransaction`, so there is no per-line
difference to account for.

## 6. Why the locking has to change

`UniqueCodeMapping::lock()` issued:

    LOCK TABLES `unique_codes` READ, `unique_codes` AS `<alias>` READ, `unique_codes_mapping` WRITE, `unique_codes_mapping` AS `<alias>` READ

around the allocating `save()`, then `UNLOCK TABLES`. Three separate problems, in
descending order of severity.

### 6.1 It commits the event transaction part-way through the save

In MariaDB and MySQL both `LOCK TABLES` and `UNLOCK TABLES` cause an **implicit commit**.
Verified directly rather than assumed:

| Sequence | Rows surviving the `ROLLBACK` |
|---|---|
| `BEGIN; INSERT ...; ROLLBACK;` | 0 |
| `BEGIN; INSERT ...; LOCK TABLES ...; UNLOCK TABLES; ROLLBACK;` | 1 |

The call chain is `actionCreate()` -> `beginInternalTransaction()` -> `saveEvent()` ->
`afterCreateElements()` -> `updateUniqueCode()` -> `createNewUniqueCodeMapping()` ->
`lock()`. So for the two event types that take codes, the event row and its elements are
committed at the moment the lock is taken, and the `commit()` at the end of `actionCreate`
covers nothing. A failure after that point cannot be rolled back and leaves a partially
written event. This is a correctness bug, not a performance one, and it is the reason the
lock has to go rather than merely be narrowed.

**What the rollback then does is nothing at all, silently.** `CDbTransaction::rollback()`
is guarded:

    if($this->_active && $this->_connection->getActive())
    {
        if($this->_connection->getPdoInstance()->inTransaction())
            $this->_connection->getPdoInstance()->rollBack();
        $this->_active=false;
    }

Probed through PDO against MariaDB: after a mid-transaction `LOCK TABLES` /
`UNLOCK TABLES`, `PDO::inTransaction()` reports **false** and the inserted row survives. So
the guard skips the driver call, sets `_active = false`, and returns normally. There is no
exception and no log line. `$transaction->rollback()` is a **silent no-op**, and the
`if (!empty($errors)) { $transaction->rollback(); return; }` branch in
`BaseEventTypeController::actionCreate()` leaves the half-written event committed while
reporting the errors as though it had undone the work. Same guard in `1.1.31` and
`1.1.33-dev`, so this is identical on both lines.

### 6.2 It is an instance-wide mutex on the save path

`LOCK TABLES ... WRITE` is a table-level lock. Every concurrent cataract operation note or
CVI save serialises on it, each waiting a full round trip of lock, select, insert, unlock.
`LOCK TABLES` also has to acquire metadata locks on the named tables, so a single
long-running statement touching `unique_codes` stalls the `LOCK TABLES` statement and
every request queued behind it. That is a convoy on a path a clinician is sitting in front
of.

The duration of that hold is not constant. It contains the free-code selection, which is a
whole-pool anti-join (section 7), so it grows with the pool and it is worst exactly when
the pool has no free codes left: the scan then reads every row before returning nothing.
Measured on a warm, fully-allocated 251,500-row pool, that select is **317.56 ms**. An
empty pool therefore turns every cataract and CVI save into a third of a second of
exclusive, instance-wide hold on both tables, for no result.

### 6.3 It stretches how long an `event` row stays pinned

`unique_codes_mapping.event_id` is a foreign key to `event`, so inserting the mapping row
takes a shared lock on the parent `event` row for the rest of the transaction. `event` is
already the highest-contention table in the schema - see
`oe-event-table-lock-contention.md` for the S-to-X upgrade that the version snapshot
performs on the same row, and for the fact that one save writes the row twice. Wrapping
the mapping insert in a table lock adds the table-lock wait to the time that row is held,
on top of everything else. On an instance where `event` is already producing lock waits,
this is a multiplier, and it is entirely avoidable.

### 6.4 What replaces it

`unique_codes_mapping` already declares `UNIQUE(unique_code_id)`. That constraint, not the
table lock, is what actually guarantees one code per mapping - the lock was belt over
braces. So: select a free code, insert it, and if the database rejects the row because
another request took it first, take the next free code. Bounded retries (five is plenty;
five consecutive losses means the pool is draining faster than it fills, and the right
answer is a log line, not an unbounded retry inside a save).

**Yii gotcha that decides how the retry is written:** `BaseActiveRecord::save()` catches
`CDbException`, logs it, calls `addError('database', ...)` and **returns false**. It never
rethrows. A duplicate-key rejection therefore surfaces as `save() === false`, not as an
exception - a `catch (CDbException $e)` around `$model->save()` is dead code in this
codebase. React to the false return.

Verified against the database: a second insert of the same `unique_code_id` gives
`ERROR 1062 (23000): Duplicate entry '2' for key 'u_code'`. The retry path is real.

## 7. Finding a free code without scanning the pool

The shipped selector was the anti-join again, ordered and limited:

    SELECT unique_codes.id FROM unique_codes LEFT JOIN unique_codes_mapping ON unique_code_id=unique_codes.id WHERE unique_codes_mapping.id is null AND active = 1 ORDER BY unique_codes.id LIMIT 1

`EXPLAIN` on a real 1500-row pool: `type=ALL` over `unique_codes` with `eq_ref ... Not
exists` probing the mapping table. Cost grows with the size of the pool, and the pool only
grows.

Codes are handed out in ascending `id`, so everything below the highest allocated id is
normally taken. Starting just past that watermark answers the normal case with an index
lookup and a short PK range seek:

    SELECT unique_codes.id FROM unique_codes WHERE unique_codes.id > (SELECT COALESCE(MAX(unique_code_id), 0) FROM unique_codes_mapping) AND active = 1 ORDER BY unique_codes.id LIMIT 1

`EXPLAIN`: `type=range` on `PRIMARY`, with the subquery answered by the min/max optimiser
straight from the unique index. Keep the anti-join as a fallback for when that returns
nothing, so a gap left further down the pool (a withdrawn mapping, a code deactivated then
reactivated) is still found and nothing is stranded. Verified: with ids 2 and 5 free and 5
above the watermark, the fast path returns 5; once the tail is exhausted the fallback
returns 2.

Measured on the same 251,500-row fully-allocated pool:

| Statement | Time |
|---|---|
| anti-join select (`type=ALL`, 251,076 rows examined) | 317.56 ms |
| the backfill's `INSERT IGNORE ... SELECT` over the same anti-join | 378.62 ms |
| watermark select | 0.476 ms |

Three orders of magnitude, and the two slow ones are the two that run under a lock.

## 8. What is actually causing the lock storms

Four mechanisms stack. Ranked by how much lock time each one is responsible for.

### 8.1 The save path holds a table-level lock over both tables

Section 6.2. Every cataract and CVI save takes an instance-wide mutex, and the hold
contains a scan whose cost is proportional to the pool. This is the base layer and nothing
else can be fixed around it: while it is in place, any other query that wants either table
queues behind clinicians, and clinicians queue behind each other.

### 8.2 The backfill's `INSERT ... SELECT` shared-locks the whole pool, even when it inserts nothing

This is the one that is not obvious from reading the SQL. The site-local backfill allocates
with a single statement:

    INSERT IGNORE INTO unique_codes_mapping (...) SELECT :event_id, uc.id, ... FROM unique_codes uc LEFT JOIN unique_codes_mapping used ON used.unique_code_id = uc.id WHERE uc.active = 1 AND used.id IS NULL ... ORDER BY uc.id LIMIT 1

Under `REPEATABLE READ`, `INSERT ... SELECT` does **not** do a lock-free consistent read of
its source. It takes **shared next-key locks on every row it reads from `unique_codes`**,
and it does so even when it inserts zero rows. Proved with two sessions on a scratch
database:

| Isolation level | Session A: `INSERT IGNORE ... SELECT` (0 rows inserted) | Session B: `UPDATE unique_codes SET active = 1 WHERE id = 1` |
|---|---|---|
| `REPEATABLE READ` | holds its transaction open | blocks until `ERROR 1205 Lock wait timeout exceeded` |
| `READ COMMITTED` | same | returns immediately |

Consequences on a dry pool, with the deployed defaults (`--limit=50`, `max_retries=3`):

- Per event, attempts 1 to 3 are bounded by the frontier (`uc.id > :min_code_id`) and cheap,
  but attempt 4 drops the bound and scans the whole pool: 378.62 ms of shared locks over
  every row in `unique_codes`.
- 50 events per run means up to 50 whole-pool scans, roughly **19 seconds of near-continuous
  shared-lock coverage of the entire pool, every ten minutes**.
- The frontier-bounded attempts are not free either. A range scan that runs off the end of
  the index takes a next-key lock on the supremum gap, which is precisely where
  `generateuniquecode` inserts new codes. So the backfill can block the top-up that would
  end the whole problem. That one follows from the locking rules rather than from a direct
  measurement here - worth confirming on the instance if it is being relied on.
- The candidate query is itself a heavy read of `event`: it filters by `event_type_id`,
  joins `et_ophtroperationnote_cataract`, anti-joins `unique_codes_mapping` and then sorts
  by `e.created_date`, which is a filesort over every cataract event on the instance. Every
  ten minutes, against the highest-contention table in the schema.

The fix is structural, not a tuning knob: read and insert as **separate statements**, so
the read is a plain consistent read taking no locks at all; cap the expensive
below-frontier scan at one per run rather than one per event; and advance the frontier as
codes are allocated so a retry never re-reads what it just consumed. Setting the session to
`READ COMMITTED` fixes the locking too, but only for as long as nobody changes the
statement back.

### 8.3 The pool is allowed to run dry, which makes 8.1 and 8.2 as expensive as they can be

`generateuniquecodes.sh` calls `php $WROOT/protected/yiic generateuniquecode` with **no
argument**, so the target is always the default: 1500 *free* codes, regardless of how many
the instance gets through. The shipped schedule is
`${CRON_GENERTAEUNIQUECODES_SCH:-55 5 * * 0}`, weekly. (Note the `GENERTAE` typo - it is
in the shipped variable name; do not "fix" it or instances overriding it break.)

An empty pool does not block the save. `createNewUniqueCodeMapping()` returns an unsaved
model and the event is written without a code, which is worse than blocking: the record
looks fine and is simply invisible to whatever consumes the code afterwards. It is also
what creates work for the backfill, which is what causes 8.2.

The generator's own counting fault - the loop ran `$this->limit - $unusedCount` times and
counted every *attempt*, because `insert()` swallowed everything in an empty catch - is a
real defect and it silently under-fills, but it is not what empties the pool at these
sizes. With 250,000 codes stored, a fresh random code collides with probability
250,000 / 1,544,804,416 = 1 in 6,181, so a 1500-code top-up expects **0.24** wasted
attempts. The schedule and the fixed 1500 target are the availability fault; the counting
fault matters because (a) it hides a shortfall from any other cause, including a lock-wait
timeout on `unique_codes` while the save path holds the table lock, and (b) it becomes the
dominant fault the moment a unique index on `code` starts rejecting rows (section 9).

### 8.4 The live cron piles six jobs onto the same minute

The instance's crontab, with the relevant entries and what each one touches:

| Schedule | Job | Touches |
|---|---|---|
| `55 5 * * *` | `generateuniquecodes.sh` | `unique_codes` (insert), `unique_codes_mapping` (anti-join count) |
| `*/10 * * * *` | `backfillmissingpuccodes --min-age-minutes=1 --exclude-user-id=6736` | `event`, `et_ophtroperationnote_cataract`, `unique_codes`, `unique_codes_mapping` |
| `*/10 * * * *` | `correspondenceemail` | `event` and correspondence tables |
| `*/10 * * * *` | raw `mysql -u root` `UPDATE ophinbiometry_imported_events oie JOIN event ev JOIN episode ep SET ev.episode_id=ep.id` | **writes `event` directly** |
| `*/5 * * * *` | `runlinearregression` | measurement tables |
| `*/12 * * * *` | `generatedocumentevent` | `event` |
| `0 * * * *` | `portalexams.sh` | **`eventFromUniqueCode()`** - reads `unique_codes` + `unique_codes_mapping`, writes events |
| `5 * * * *` | raw `mysql -u root` `UPDATE et_ophcomessaging_message ... SET m.deleted = 1, e.deleted = 1 WHERE ... m.message_text LIKE '%...%'` | **writes `event` directly**, matched by an unindexable `LIKE` |

Alignment: `*/10`, `*/5` and `*/12` all coincide at **:00 of every hour**, where
`portalexams` joins them. That is six jobs starting together, of which four touch `event`
and two touch the unique-code tables. Every other `:x0` minute still starts four.

Specific collisions that matter:

1. **`portalexams` at `:00` is the unique-code consumer**, and it starts on the same minute
   as a backfill run that may be shared-locking the whole pool for the next 19 seconds.
   The import's `eventFromUniqueCode()` lookups queue behind it.
2. **The backfill runs with `--min-age-minutes=1`.** The intent is obvious (repair quickly),
   but one minute is inside the window where the web save has already implicitly committed
   the event (6.1) and has not yet inserted the mapping. The backfill does not corrupt
   anything there - it blocks on the web session's table lock and then loses the unique key
   on `event_id`, reporting "already mapped" - but it means the backfill and live saves are
   contending for the same two tables by design. Five minutes or more costs nothing.
3. **Two raw `mysql -u root` crons write `event` outside the application.** No version rows,
   no audit, `last_modified_user_id` hard-coded to 1. That is the same fingerprint as the
   unexplained external `event` writer recorded in `oe-event-table-lock-contention.md`;
   they are not the same statement (that one sets `service_firm_id` per id, this one sets
   `episode_id` in bulk and *joins* on `service_firm_id`), but this is a fourth writer of
   that table and it is exactly the interaction that file warns about - a non-application
   writer moving `episode_id` on rows the web app is concurrently populating. The messaging
   one is worse per run: a `LIKE '%...%'` on `message_text` cannot use an index, so it scans
   `et_ophcomessaging_message` and then takes exclusive locks on the matching `event` rows,
   hourly, with no time bound and no `LIMIT`.

Three smaller things in the same crontab, none of them lock-related but all worth knowing:

- `generateuniquecodes` is scheduled **daily** here (`55 5 * * *`), not weekly. Someone has
  already overridden `CRON_GENERTAEUNIQUECODES_SCH`. That is a mitigation, and it caps the
  instance at 1500 codes per day before the pool is dry until the next morning.
- `[ ! -z /docman ]` and `[ ! -z england ]` are tests on non-empty literal strings, so they
  are always true and the `|| echo disabled` branches can never fire. Templating artifacts.
- `cronrunner.sh` runs `eval $@`, and the biometry line's `-e UPDATE ...` argument is not
  quoted as supplied. If that is faithful to the box, `mysql` receives `-e UPDATE` and
  treats the next word as the database name, so the job errors every ten minutes rather
  than running; if the quoting is intact on the box, it is an unbounded bulk `UPDATE` of
  `event`. Worth checking which, because the two readings have opposite implications.
  Separately, `-p$(cat /run/secrets/...)` puts the root password in the process argument
  list where `ps` can read it; `MYSQL_PWD` or a defaults-file avoids that.

### 8.5 What to change, in order

1. **Remove the table lock from the save path** (PR `oe-pr-unique-code-pool-availability`).
   Nothing else matters as much: while an instance-wide mutex sits on the clinician's save
   path, every other change is tuning around it.
2. **Replace the backfill's `INSERT ... SELECT`** (PR `oe-pr-unique-code-backfill`), which
   removes the shared-lock scans entirely rather than mitigating them.
3. **De-align the crons.** Offset the three `*/10` jobs by two or three minutes from each
   other and move the backfill off the hour, so it does not start alongside `portalexams`.
   This costs nothing and is the only item here that does not need a release.
4. **Raise `--min-age-minutes` to 5 or more**, its default.
5. **Size the top-up to actual consumption.** The 1500 default is a guess; count what the
   instance really issues per day:
   `SELECT DATE(created_date) d, COUNT(*) FROM unique_codes_mapping WHERE created_date > DATE_SUB(NOW(), INTERVAL 30 DAY) GROUP BY d ORDER BY d;`
   and pass a limit with headroom. Once the pool reliably has free codes, the backfill has
   almost nothing to do and can drop to nightly or be retired.
6. **Get the two raw `mysql` crons off `event`**, or at minimum bound them with a date or id
   predicate and a `LIMIT` so each run touches a known number of rows.

## 9. Duplicate codes: where they come from, and why they stop

`unique_codes.code` has no index, so nothing stops the same code being stored twice.
Because codes are drawn at random, the birthday bound applies over the total number of
codes ever generated on the instance, not over the pool size - allocated codes are never
deleted, so that total only grows:

| Codes generated | P(at least one duplicate) | Expected duplicate pairs |
|---|---|---|
| 1,500 | 0.07% | 0.001 |
| 50,000 | 55.5% | 0.8 |
| 100,000 | 96.1% | 3.2 |
| 250,000 | ~100% | 20.2 |

(`p = 1 - exp(-n^2 / 2N)` and `E = n^2 / 2N` over `N = 34^6 = 1,544,804,416`.) A long-lived
instance is not at risk of duplicates, it already has them, and it has roughly one for every
110,000 codes squared over the keyspace. **An instance that has issued 250,000 codes should
expect about twenty duplicated codes.** That is the number to go looking for, not zero.

The consequence is clinical, not cosmetic. `eventFromUniqueCode()` used `queryRow()` with
no ordering, so a duplicated code resolved to whichever row the database happened to
return, and `SignController::actionAdd` then wrote a signature onto that event. The same
lookup feeds the portal examination import. And per section 1.1, the check digits printed
around the code are never validated, so nothing downstream can notice.

### 9.1 Will it just happen again

No, and this is the part that makes the repair worth doing once. Two changes together make
recurrence impossible rather than unlikely:

1. **`CREATE UNIQUE INDEX unique_codes_code_IDX USING BTREE ON unique_codes (code);`** - the
   database refuses to store a second copy. This is the whole defence. It does not reduce
   the collision *rate*, it converts a collision from a stored duplicate into a rejected
   insert.
2. **The generator counts rows the database accepted, not attempts made** - it batches with
   `INSERT IGNORE`, adds `ROW_COUNT()`, and keeps going until the pool really holds the
   requested number. Without this, the index turns silent duplication into silent
   under-filling: rejected rows would still be counted as created and the pool would quietly
   run short, which is a worse failure than the one being fixed.

**Ordering matters between the two.** The counting fix has to land first. Verified:
post-index, a three-row `INSERT IGNORE` with one collision reports `ROW_COUNT() = 2`, which
is what lets the corrected loop top up to the real target. Also verified, as the direct
reproduction of the bug: without the unique index, `INSERT IGNORE` of four rows that
duplicate existing codes inserts all four.

Cost of the retry loop, so nobody worries about it: at 250,000 codes stored a collision is
1 in 6,181 and a 1500-code batch expects 0.24 rejections; at 10 million stored it is 1 in
154 and a batch expects 10. `INSERT IGNORE` absorbs both without noticing. The rejection
rate grows linearly with the number of codes ever generated, so the loop only becomes
interesting at a scale (tens of millions of cataract operations on one instance) that will
not happen. A unique index makes the design self-correcting; it was never self-correcting
before.

The runtime half is worth keeping even so: `eventFromUniqueCode()` selects with `LIMIT 2`
and returns null when it gets two rows, logging the code. Every caller already handles a
null. Once the unique index exists that branch is unreachable by construction, which is the
point - it covers the window where the repair below has stopped for a human decision.

## 10. Duplicates that have already been issued

The unique index cannot be created over a column that still holds duplicates, so the repair
comes first, and it is not all one job. Find them and classify:

    SELECT uc.code, COUNT(*) rows_held, SUM(ucm.id IS NOT NULL) issued FROM unique_codes uc LEFT JOIN unique_codes_mapping ucm ON ucm.unique_code_id = uc.id GROUP BY uc.code HAVING rows_held > 1 ORDER BY issued DESC, rows_held DESC;

Three cases, and only the third needs a person:

| `issued` | What it means | What to do |
|---|---|---|
| 0 | the code sits in the pool two or more times and has never reached a record | delete all but the lowest id. No clinical impact. |
| 1 | one copy is allocated to an event, the spares are free | keep the allocated row, delete the spares. No clinical impact - the issued code is untouched. |
| 2 or more | the same six characters identify two or more different events | **stop.** This is a decision, not a data fix. |

For the third case, in order:

1. **Do not delete either mapping.** Deleting a mapping strands its event with no code *and*
   frees the code to be handed out a third time. It makes the problem worse in both
   directions.
2. **Find out whether the ambiguity has actually been exercised.** The portal import
   records what it was sent:
   `SELECT unique_code, event_id, examination_date, import_success FROM automatic_examination_event_log WHERE unique_code = '<CODE>';`
   Signatures recorded through `SignController` are the other route. If exactly one of the
   colliding events has external traffic against it, that event keeps the code and the
   question is closed.
3. **Re-code the other event(s).** In one transaction, insert a new mapping row for the
   event against a fresh free code and delete the old one - or delete the old mapping and
   run the backfill for that single event id, which is what `--event-id=` is for. Re-coding
   is only safe once step 2 has established that nothing external is holding the old code
   *for that event*.
4. **Treat the paper trail as a separate, clinical piece of work.** Anything already printed
   with the re-coded event's old code has to be reprinted, and anything already imported
   against the wrong event has to be reviewed. Produce the list - patient, event date, event
   type, code - and hand it to whoever owns clinical safety on the instance. Nobody looking
   only at these two tables can tell which event a given piece of external data was *meant*
   for.
5. **Never re-point a mapping at a different event to tidy the data up.** That silently
   re-attributes whatever the external systems have already written.

The repair migration in `oe-pr-unique-code-duplicate-prevention` implements exactly cases 0
and 1 automatically and **refuses to run** on case 2, naming the rows. An upgrade stopping
with a clear message is the correct behaviour here: the alternative is a migration choosing,
on a clinician's behalf, which patient's record a code belongs to.

## 11. How this should be handled instead

The pool is the root cause of sections 6, 7 and 8 and, per section 2.2, it buys nothing.
Four options, in the order they are worth doing:

1. **Generate the code on the fly, and let the unique index arbitrate.** At save time,
   generate six random characters, insert into `unique_codes`, insert the mapping, both
   inside the event's own transaction; on a duplicate-key rejection generate another and
   retry. With the unique index from section 9, correctness is enforced by the database at
   the moment of use rather than by a batch job hours earlier. At realistic pool sizes
   99.98% of saves take one attempt. What disappears: the cron, the pool, the anti-join, the
   table lock, the empty-pool failure mode where an event gets no code, and the backfill
   command with it. This is strictly better than the current design on every axis, and it is
   a smaller change than it sounds - two inserts and a retry loop replacing a select under a
   lock.
2. **Keep the pool but make allocation a claim, not a scan.** If pre-generation must stay -
   the only real argument is pre-printing codes before the event exists, which nothing in
   the tree does - allocate with a single-statement claim against a free row rather than a
   select-then-insert, and keep the watermark from section 7 so the claim is an index seek.
   This is a smaller change than (1) but keeps the cron, the dry-pool failure mode and the
   backfill.
3. **Widen the code.** The real weakness is that a value which must stay unique for the life
   of an instance was given a 34^6 keyspace. Eight characters gives 1.8 x 10^12, at which
   250,000 codes carry a 1-in-58,000 chance of *any* collision and the whole subject
   evaporates. Blocked by `code varchar(6)`, by every document already printed, and by any
   external system parsing the three-part format, so it is a coordinated change - worth
   putting on the table the next time that format is opening anyway.
4. **Do not derive the code from the event id.** An HMAC of the event id truncated to six
   base-34 characters removes the table entirely, and is tempting for that reason. It is
   worse: truncation reintroduces exactly the same birthday bound with no unique index left
   to catch it, so collisions become undetectable instead of merely likely. Only viable in
   combination with (3), and even then (1) is simpler.

Recommendation: (1) now, and (3) whenever the identifier format is next revisited.

## 12. Related work

Three PRs against `release/10.0.x @ 408456b5ba`, split because the duplicate work can stop
an upgrade for a human decision and must not hold up the availability fix:

| Folder | Change |
|---|---|
| `oe-pr-unique-code-pool-availability` | lock removal, watermark allocation with retry, batched generator counting real insertions, hourly cron |
| `oe-pr-unique-code-duplicate-prevention` | repair-then-index migration, ambiguity refusal in `eventFromUniqueCode()` |
| `oe-pr-unique-code-backfill` | brings the site-local backfill into the repo: separate read and insert so nothing shared-locks the pool, one below-frontier scan per run, an advancing frontier, allocation through the model layer for audit columns, and `--type=cvi` so CVI events are repaired as well as cataract operation notes |

All three are scoped into a single **v10.0.35** cut from `release/10.0.x`, and they apply
in the order above: the first stops new events being left codeless, the second makes the
pool incapable of holding a duplicate (and can stop for a human decision while doing it),
the third repairs what the first two arrive too late for and can only hand out codes the
pool already holds. Upgrade impact, pre-upgrade audit and test plan for that release, from
v10.0.32 upwards: `/home/toukan/oe-v10-0-35-unique-codes-upgrade-impact.md`, with the index
and lock-baseline analysis in `/home/toukan/newmedica-index-change-analysis.md`.
