# PayloadProcessor

## 1. How the container works

PayloadProcessor is a Java service that pulls "routines" off a queue stored in the OpenEyes MySQL/MariaDB database, runs them, and reports the results back via the OpenEyes API. A routine is a small JavaScript script (loaded from `routine_library`) that processes a payload — typically a medical device file such as DICOM, OCT, or XML — and produces attachments / patient data in OpenEyes.

### Entry point and main loop

- `DicomEngine.main()` — `src/main/java/com/abehrdigital/payloadprocessor/DicomEngine.java:34`
  - Loads Tesseract OCR native libs.
  - Calls `init()` to bootstrap Hibernate / HikariCP / configuration.
  - Builds a `RoutineLibrarySynchronizer` to pull JS routines from `routine_library` into the in-memory script cache.
  - Constructs a `RequestQueueExecutor` for the configured queue and enters a stability-recovery loop that calls `executor.execute()` until shutdown.
- `RequestQueueExecutor.execute()` — `src/main/java/com/abehrdigital/payloadprocessor/RequestQueueExecutor.java:52`
  - Acquires a queue-level lock (up to 20 attempts, 5s apart — see `RequestQueueLocker.java:85`).
  - Polls `request_routine` for runnable rows.
  - For each row, spawns a `RequestWorker` thread up to `maximum_active_threads`.
  - Sleeps `busyYieldMs` between cycles when work is found, `idleYieldMs` when the queue is empty (both read from the `request_queue` row).

### Database access

- Hibernate ORM with HikariCP (`src/main/resources/hibernate.cfg.xml`); pool min 10 / max 20, 300s idle timeout.
- `RequestRoutine` entity uses optimistic locking (`DIRTY` strategy) — `models/RequestRoutine.java:22`.

### Configuration

Environment variables (set in `Dockerfile` / `docker-compose.yml`, defaults in `init.sh`):

| Variable | Purpose |
|---|---|
| `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_NAME` | OpenEyes DB connection |
| `DATABASE_USER` / `DATABASE_PASS` | DB creds (Docker secret supported at `/run/secrets/DATABASE_PASS`) |
| `API_HOST` / `API_PORT` / `API_USER` / `API_PASSWORD` / `API_DO_HTTPS` | OpenEyes REST API endpoint and creds |
| `PROCESSOR_QUEUE_NAME` | Which queue this container processes (e.g. `dicom_queue`) |
| `PROCESSOR_SHUTDOWN_AFTER` | Seconds before auto-shutdown (`0` = run forever) |
| `SYNCHRONIZE_ROUTINE_DELAY` | Minutes between routine library re-syncs |
| `RETRY_DATABASE_CONNECTION` | Minutes to retry DB on startup |
| `DEFAULT_SUBSPECIALTY` / `DEFAULT_SERVICE` / `DEFAULT_FIRM_NAME` | Fallbacks when payload doesn't carry them |
| `HOSPITAL_NUMBER_CONSTRUCT_REGEX` | Regex used to extract hospital number from filenames |
| `TZ` | Container timezone (default `Europe/London`) |

Per-queue runtime tuning lives in the `request_queue` table (`models/RequestQueue.java:19`): `maximum_active_threads`, `busy_yield_ms`, `idle_yield_ms`, plus operational counters (`total_execute_count`, `last_poll_date`, etc.).

### Polling query

`RequestRoutine.java:25-37` — named query `routinesWithRequestQueueRestrictionForProcessing`, dispatched from `RequestRoutineDao.getRoutinesForQueueProcessing()` at `dao/RequestRoutineDao.java:69`:

```sql
SELECT * FROM request_routine rr
WHERE rr.execute_request_queue = :request_queue
  AND rr.status IN (:new_status, :retry_status)
  AND IFNULL(rr.next_try_date_time, SYSDATE()) <= SYSDATE()
  AND NOT EXISTS (
        SELECT * FROM request_routine subrr
        WHERE subrr.request_id = rr.request_id
          AND subrr.execute_sequence < rr.execute_sequence
          AND subrr.status NOT IN (:complete_status, :void_status)
      )
ORDER BY rr.id
```

(2026-07-20: the IFNULL/SYSDATE line has since been rewritten to the sargable
`(rr.next_try_date_time IS NULL OR rr.next_try_date_time <= NOW())` form - see 5.1.)

Status values: `NEW`, `RETRY`, `COMPLETE`, `FAILED`, `VOID`. The `NOT EXISTS` clause enforces in-request ordering (a routine with a lower `execute_sequence` for the same `request_id` must finish before later ones run). `next_try_date_time` provides retry backoff (computed by `utils/RequestRoutineNextTryTimeCalculator.java`).

---

## 2. Admin pages to configure in `/repo/openeyes`

All PayloadProcessor admin lives under the `Api/Request` module:
`/repo/openeyes/protected/modules/Api/modules/Request/modules/RequestAdmin/`

| Page | Route | What it configures | Why PayloadProcessor needs it |
|---|---|---|---|
| **Request Queue** | `/Api/Request/admin/requestQueue/index` | Queue name (e.g. `dicom_queue`), `maximum_active_threads`, `busy_yield_ms`, `idle_yield_ms` | The container polls exactly the queue named in `PROCESSOR_QUEUE_NAME`; this row must exist or it has nothing to read. Thread pool size and yield intervals are read from here every cycle. |
| **Request Type** | `/Api/Request/admin/requestType/index` | Maps a request type (e.g. `DICOM`, `FHIR`) to a `default_routine_name` and `default_request_queue` | Inbound payloads need a request type so the dispatcher knows which routine to enqueue and on which queue. |
| **Routine Library** | `/Api/Request/admin/routineLibrary/index` | The JavaScript routines themselves | The container syncs these into its in-memory cache via `RoutineLibrarySynchronizer` (interval = `SYNCHRONIZE_ROUTINE_DELAY`). Without entries here, routines fail to resolve. |
| **Request** | `/Api/Request/admin/request/index` | Monitoring / search of requests by status | Operational visibility — verifying that the container is processing and locating stuck requests. |
| **Request Routine** | `/Api/Request/admin/requestRoutine/edit?id={id}` (also `getRoutineLogs`, `resetToNew`) | View per-routine logs; reset `FAILED` routines back to `NEW` for retry | Manual recovery path when a routine permanently failed. |
| **Mime Type** | `/Api/Request/admin/mimeType/index` | Allowed MIME types for inbound attachments | Validates the file types the container ingests / writes back. |
| **Attachment Type** | `/Api/Request/admin/attachmentType/index` | Attachment categorisation (e.g. `IMAGE`, `REPORT`) | Routines tag stored attachments using these categories via the OpenEyes API. |
| **Manual Upload** | `/Api/Request/admin/default/manualupload` | Drop a file directly onto the queue | Test harness for verifying the container end-to-end without a real device feed. |

Minimum bring-up checklist: create the queue → create at least one request type pointing at it → ensure routine library has the JS scripts → confirm mime/attachment types match what the routines emit → confirm the `payload_processor` API user (in `protected/config/core/common.php`) has the `API Access` RBAC role.

---

## 3. Making the polling more efficient (least-intrusive first)

The current cycle re-issues `SELECT *` against `request_routine` every `busy_yield_ms` (work present) or `idle_yield_ms` (idle). On a busy database with a large `request_routine` history, that's a lot of pointless I/O. Improvements, ordered from least to most invasive:

### Tier 1 — pure DB / query tweaks (no behaviour change)

1. **Composite index on the filter predicates.** Add `INDEX (execute_request_queue, status, next_try_date_time, id)`. Today the planner most likely filters on `execute_request_queue` alone and rescans for `status` and the `IFNULL(...) <= SYSDATE()` check. A covering index lets the polling query be served from the index alone (especially combined with #2). Pure schema migration; no Java change.
2. **Replace `SELECT *` with the columns the dispatcher actually uses.** The dispatcher only needs `id`, `request_id`, `execute_sequence`, `status`, and `next_try_date_time` to decide what to run; the heavy fields (payload blob/large text) are already lazy on the entity, but `SELECT *` materialises everything mapped non-lazily and prevents the index above from being covering. Change `routinesWithRequestQueueRestrictionForProcessing` in `models/RequestRoutine.java:25` to an explicit projection (or a constructor-result `RequestRoutineSummary`). The full entity can be loaded by id when a worker actually claims the routine.
3. **Add `LIMIT` to the polling query.** The executor can dispatch at most `maximum_active_threads − active_count` routines per cycle. There is no reason to fetch more rows than that. Pass the available slot count as a parameter to `getRoutinesForQueueProcessing()` and append `LIMIT :batch_size`. This bounds memory and makes large backlogs cheap to poll.

### Tier 2 — small Java changes

4. **Cheap pre-check before the heavy query.** Before issuing the main query, run `SELECT 1 FROM request_routine WHERE execute_request_queue = ? AND status IN ('NEW','RETRY') AND IFNULL(next_try_date_time, SYSDATE()) <= SYSDATE() LIMIT 1`. With the index from #1 it's an index-only single-row probe. Skip the full poll (and the `NOT EXISTS` correlated subquery) on idle cycles.
5. **Cache `RequestQueue` config across cycles.** `busy_yield_ms`, `idle_yield_ms`, and `maximum_active_threads` are looked up every loop. Reload them on a fixed interval (e.g. every 30s or every N polls) instead — same effect, far fewer round-trips. Counters that the executor writes back stay write-through.
6. **Adaptive idle backoff.** When N consecutive polls return zero rows, multiply `idle_yield_ms` (capped at, say, 5×). Reset on the first hit. Keeps fast response when work arrives but stops hammering the DB during quiet periods. Fits inside `RequestQueueExecutor.execute()` without any schema changes.

### Tier 3 — more invasive, mention only if the above isn't enough

7. **Push the `NOT EXISTS` ordering check into a generated column or status flag** (`is_eligible TINYINT`) maintained by triggers / application code on insert and on each routine completion. The polling query then becomes a flat range scan on the index. This is a real schema and write-path change — only worth doing if profiling shows the correlated subquery dominates.
8. **Database notifications instead of polling** (e.g. a separate "wake-up" channel via a small inserted-row trigger that updates a heartbeat row, or moving the queue to something with native notify like Postgres `LISTEN`/`NOTIFY` or a real broker). High value but a rewrite of the dispatch loop.

Recommendation: apply tiers 1–2 together as a single non-breaking change. Items 1, 2, and 3 alone typically take this kind of poll from "scan-the-table" to "index probe + tiny result set" and require no migration of existing rows.

---

## 4. 2026-07-20 update - poll indexes applied + lease locking (OE-18206) review

### 4.1 Poll index fix (shipped in the performance_indexes_rollup migration)

Two indexes replace the Tier 1 #1 suggestion above (validated with ANALYZE FORMAT=JSON
on the test instance, MariaDB 11.8, request_routine at 139k rows):

```sql
ALTER TABLE request_routine ADD INDEX idx_request_routine_queue_status_next_try (execute_request_queue,status,next_try_date_time), ADD INDEX idx_request_routine_request_sequence_status (request_id,execute_sequence,status);
```

| Metric (one poll) | Before | After |
|---|---|---|
| Outer access | full clustered scan, 139k rows, 820 pages | range on new index, 6.4k rows, ICP on next_try |
| NOT EXISTS probes | ref on request_id + row lookups, 133,030 pages | covering index (`Using index`), 12,876 pages |
| Total pages accessed | ~133,850 | ~25,700 |
| Total time | 64-95 ms | ~20 ms |

The second index is what stops the whole table entering the buffer pool: the ordering
probe no longer touches row data of historic COMPLETE routines. Residual cost scales
with the NEW+RETRY count, not table size.

Corrections to section 3 above:
- A covering outer index / trailing `id` is pointless while the query is `SELECT *`
  (row lookups happen regardless); 3 columns is the right size.
- The `IFNULL(next_try_date_time, SYSDATE()) <= SYSDATE()` predicate is non-sargable
  and stays non-sargable even rewritten as `IS NULL OR <= SYSDATE()` because SYSDATE()
  is not a query constant. A future Java rewrite must use NOW():
  `(rr.next_try_date_time IS NULL OR rr.next_try_date_time <= NOW())` - then the new
  index serves it as pure ranges. (Done later the same day - see 5.1.) Tier 1 #2
  (projection) and #3 (LIMIT) still apply.
- If a LIMIT is ever added, beware the optimizer flipping back to a PRIMARY-ordered
  scan (pathological here since NEW rows sit at high ids); pair LIMIT with FORCE INDEX.
- Backlog observation: on test, 6.4k NEW rows are permanently blocked behind FAILED
  predecessors (FAILED is not COMPLETE/VOID, so the NOT EXISTS never clears). The poll
  working set grows monotonically; needs housekeeping (void/abandon descendants of
  FAILED requests, and/or archive COMPLETE rows).

### 4.2 Lease-based queue locking (OE-18206) assessment

What changed: `RequestQueueLocker` no longer holds `SELECT ... FOR UPDATE NOWAIT` in a
never-committed transaction (the undo-purge/history-length blocker). It now runs short
committed transactions against new `request_queue_lock` columns (owner_id, lease_until,
heartbeat_at, updated_at), TTL 30s (env `REQUEST_QUEUE_LEASE_SECONDS`), all times from
DB `UTC_TIMESTAMP(6)` (no app clock skew). Aggregate `request_queue` writes are fenced
with `EXISTS (... owner_id = me AND lease_until > now)`.

New-column performance: no issue and no further indexes needed. Every lease statement
filters on the PK (`request_queue`) of a table with one row per queue. The migration's
own two indexes (lease_until, owner_id) are never used by any query shape but are
harmless.

Problems found (in severity order; plain-English version with risk levels in 5.4):

1. **Migration missing from develop** (hit live on test): the OpenEyes migration
   `m260701_120000_add_lease_columns_to_request_queue_lock.php` is on `master` and
   `release/26.0.x` only. `payloadprocessor:develop` validates the schema at startup
   (hbm2ddl validate) and crash-loops with "missing column [heartbeat_at]". Fixed on
   the test DB by applying the migration DDL manually (the migration is defensive, so
   it will no-op later). (2026-07-20: per repo process this is normal - release
   branches get merged into develop regularly, so the migration arrives with the next
   routine merge; no cherry-pick needed. Full path:
   protected/modules/Api/migrations/m260701_120000_add_lease_columns_to_request_queue_lock.php.)
2. **Per-cycle release weakens the single-processor guarantee**:
   `RequestQueueExecutor.execute()` releases the lease in `finally` every cycle and
   re-acquires next cycle. Between cycles the queue is unowned, and worker threads
   outlive the cycle. A second processor on the same queue (the misconfiguration the
   lock exists to prevent) can interleave cycles and double-execute routines - and if
   it acquires the lease mid-gap, the first processor stalls in 20x5s retries while
   its in-flight workers keep running alongside the thief's. Nothing else serializes
   workers: `RequestWorkerService.getRequestWithLock()` does a plain `get` (the
   pessimistic lock is vestigial) and there is no `@Version` on Request/RequestRoutine.
   Remedy: hold + renew per cycle, release only in `shutDown()`; restore per-request
   `UPGRADE_NOWAIT` as defence in depth.
3. **Locker Session is not thread-safe but is now shared across threads**: the main
   thread uses it in lock/renew (`execute():53`), `isLeaseOwned` (`:83`) and `unlock`
   (`:110`) while worker threads reach the same Session via
   `deQueue -> saveWithLock -> hasActiveLeaseOwnership -> isLeaseOwned` - no common
   monitor. `startTransactionIfNeeded()` can adopt and commit the other thread's
   in-flight lease transaction mid-acquire. Remedy: confine the Session to a single
   thread; the worker-side ownership pre-check is advisory anyway (the fenced UPDATEs
   already guard), so it can read a volatile flag instead. (2026-07-20: master carries
   an extra commit bf8552d "#164 ensure lease locking behaviour on queues are
   synchronised" - lock/unlock/isLeaseOwned are synchronized there, which stops the
   transaction interleaving; develop gets it with the next release merge. The Session
   still crosses threads, and the retry sleeps now run inside the synchronized
   acquire, so a finishing worker can block on the locker monitor for up to 20x5s
   while acquisition is being retried - the heartbeat-thread remedy fixes both.)
4. **Renewal cadence coupled to cycle length**: the lease renews once per poll cycle,
   and `busy_yield_ms` / `idle_yield_ms` are DB-editable at runtime. Setting either
   >= TTL makes the lease self-expire mid-sleep (mostly moot today because of the
   per-cycle release, but becomes the critical liveness bug once fix #2 lands).
   Remedy: dedicated heartbeat thread at ~TTL/3 owning the locker Session (fixes #3
   at the same time) + warn when yields approach the TTL.
5. **Minor**: a worker `deQueue` landing in the unlock->relock gap fails the fenced
   update and silently drops success/fail counter increments (log-only drift).

### 4.3 Two processors on two separate queues

Running one processor per queue (e.g. dicom_queue + a second queue) is the supported
topology and nothing above changes:

- Locking: each queue has its own `request_queue_lock` row (PK = queue name); the two
  leases never touch each other's row. Problems #2/#3/#4 above concern two processors
  on the SAME queue (or a processor racing itself); cross-queue there is no contention.
- Poll cost: the outer index leads with `execute_request_queue`, so each processor's
  range scan covers only its own queue's NEW/RETRY entries; two pollers do not multiply
  each other's work. (Before the index this was worse than it looked: every poller
  full-scanned the whole table including the other queue's rows.)
- The NOT EXISTS ordering probe is deliberately queue-agnostic (same request_id across
  queues serializes by execute_sequence); the covering index serves it regardless of
  which queue polls.
- One pre-existing cross-queue touch point: `request_routine_lock` rows used by
  `synchronizedJavaSubroutine` are `FOR UPDATE NOWAIT` and shared by name across all
  processors - two queues running routines that use the same synchronized subroutine
  name can still block each other briefly. Unchanged by OE-18206.

Verified working on test after the DDL fix: container up, no schema errors, lease row
heartbeating every ~1s cycle, fenced owner_id populated. (Separate pre-existing test
issue: routines fail with HTTP 403 from the OpenEyes REST API - check the
payload_processor API user / API Access RBAC role.)

---

## 5. 2026-07-20 follow-up - NOW() rewrite delivered, housekeeping command, admin search page

### 5.1 Sargable poll predicate (the "future Java rewrite" from 4.1 - now done)

Both named queries in `models/RequestRoutine.java` now read
`AND (rr.next_try_date_time IS NULL OR rr.next_try_date_time <= NOW())` in place of
`AND IFNULL (rr.next_try_date_time, SYSDATE()) <= SYSDATE()`. Packaged as PR folder
`~/pullrequests/oe-pay-pr-poll-query-sargable/` (base `master` @ 900764d; the file is
byte-identical on master and develop, so the patch applies to either). `mvn compile`
clean in a dockerised Maven / Temurin 21 container.

Verification on the test DB (dicom_queue: 6,563 NEW/RETRY of 139k rows, 6,374 with
NULL next_try_date_time, 189 in future-dated backoff):

- Equivalence: old XOR new predicate across the entire request_routine table = 0
  disagreements; same over literal NULL/past/boundary/future dates; the full poll
  query returns identical row sets (predicate stage 6,374 rows, matching MD5 of the
  ordered id list).
- Sargability: ANALYZE FORMAT=JSON on idx_request_routine_queue_status_next_try shows
  key_length 280 = all three key parts used (next_try_date_time is now a range
  component); examined rows drop 6,563 -> 6,374 - the 189 backoff rows are excluded
  inside the index and never reach the NOT EXISTS probe. The IFNULL form can use at
  most the (queue, status) prefix.
- NOW() appears as `<cache>(current_timestamp())` in the plan: evaluated once per
  statement and replication-safe; SYSDATE() is neither.
- Timings on this dataset: old form 19.7ms, new 18.2-18.3ms. The delta is small
  because only 189 rows are in backoff and the NOT EXISTS block dominates (~12ms of
  ~18ms); the structural win is that poll cost stops scaling with backoff depth, so
  it grows with RETRY volume under load.
- Optimizer note: with all rollup indexes present the planner actually prefers
  idx_request_routine_status_request_id (global status range, 6,563 rows, 18.3ms)
  over the queue-led index (18.2ms when forced) - near-tied costs on a single-queue
  dataset where status IN (NEW,RETRY) is as selective as the queue prefix. Both plans
  are fine; on multi-queue installs the queue-led index wins naturally.

Deliberately out of scope for this PR: projection instead of SELECT * (Tier 1 #2) and
LIMIT (Tier 1 #3) - both remain open, with the LIMIT/FORCE INDEX caveat from 4.1.

### 5.2 Housekeeping command (remedy for 4.1's backlog observation)

New OpenEyes yiic command `PruneApiRequestsCommand` (PR folder
`~/pullrequests/oe-pr-prune-api-requests/`, base develop @ a49d028040). Three
independent actions, all dry-run unless `--execute=1` (exactly `1`):

- `abandonblocked` (default 365d): sets NEW/RETRY routines stuck behind a FAILED
  routine of the same request to VOID - directly shrinks the monotonically growing
  poll working set from 4.1. Test: 4,806 routines caught at a 30-day threshold
  (0 at 365d - test data is recent).
- `executionlogs` (default 180d): deletes request_routine_execution rows of
  COMPLETE/VOID routines. The bulk of reclaimable volume: 149,989 rows at 30 days
  on test.
- `requests` (default 730d): deletes whole requests plus child rows, guarded - skips
  any request with a pending routine (including the processor-side PAUSE status,
  absent from RequestRoutineStatus) or a payload that is event-attached, drafted, an
  event image, or a protected file; per-batch in-transaction FOR UPDATE recheck
  before deleting. Test: only 2 of 12,930 old requests deletable - most payloads are
  event-attached, so real space recovery comes from executionlogs + abandonblocked,
  not request deletion.

### 5.3 Request admin search page (the monitoring page from section 2)

Two-part fix for the Request admin search page slowing down with table growth:

- Rollup-migration indexes (shipped alongside the poll indexes): request
  (last_modified_date); request_routine (status,request_id); request_routine
  (try_count,request_id); request_details (name). Measured query times: default
  listing 2.30 -> 0.04ms; status filter 81.2 -> 45.5ms; try-count filter
  20.6 -> 6.3ms; extra-filter chain 115.3 -> 20.5ms; distinct detail names
  196.8 -> 0.13ms.
- Page query fix (PR folder `~/pullrequests/oe-pr-api-request-admin-search-performance/`,
  base develop @ a49d028040): eager-loads routines/details/attachments with the page
  query (previously ~10 follow-up queries per row), selects LENGTH(blob_data) instead
  of the blob so payload bytes never leave the database, and computes each row's
  payload size/count as one aggregate query. Rendered output verified identical
  row-for-row against the old page.

Delivery: all three changes are identity-free PR folders under `~/pullrequests/`
(indexed in `~/pullrequests.md`); the performance_indexes_rollup migration ships
separately.

### 5.4 New lease locking - concerns in plain English (handover)

Section 4.2 has the full technical detail; this is the short version for whoever
picks this up. "Risk" is how much damage the problem can do if nothing is done.

| # | Concern | Risk | Suggested fix |
|---|---------|------|---------------|
| 1 | The database change that adds the new lock columns is on the release branch but has not reached the develop branch yet. Anything built from develop refuses to start until it arrives: it checks the database shape on startup, finds a column missing, and restarts forever. The test database was fixed by hand. | Low - release branches are merged into develop regularly, so this fixes itself with the next routine merge. | None needed - wait for the next release-into-develop merge. |
| 2 | The processor now gives up its queue lock at the end of every polling cycle and takes it again at the start of the next one. In that gap nobody owns the queue, so if a second processor is accidentally pointed at the same queue, both can run at the same time and the same job can be executed twice. Preventing exactly that was the whole point of the lock, and the old design did prevent it. | High - duplicate processing and duplicate data, though it needs the misconfiguration of two processors on one queue. | Keep the lock for the life of the process, refresh it each cycle, and release it only on shutdown. Also restore the old per-request lock as a backstop. |
| 3 | The database connection used for the lock bookkeeping is shared between the main thread and the worker threads, but it is not safe to share. Two threads using it at the same moment can accidentally commit each other's half-finished work. This can happen inside one normally-configured processor and would show up as rare, random, hard-to-reproduce faults. A later fix on master (#164) already serializes the calls, which stops the worst of this - but the connection still moves between threads, and that fix means a finishing worker can now be blocked for over a minute while the lock is being retried. | Medium on develop today; Low on master after #164, though the worker-blocking side effect remains. | Let only one thread use that connection; the workers only need a simple yes/no flag, not the connection itself. |
| 4 | The lock expires after 30 seconds and is only refreshed once per polling cycle. The cycle sleep times can be changed in the database while the service is running; if someone sets one to 30 seconds or more, the lock quietly expires while the processor sleeps. Today this barely matters (the lock is dropped every cycle anyway, see #2), but it becomes the serious bug the moment #2 is fixed. | Low today, High once #2's fix lands - the two must be fixed together. | Refresh the lock from its own small timer thread (roughly every 10 seconds), and log a warning when sleep settings get close to 30 seconds. |
| 5 | If a worker finishes a job at the exact moment the lock is released between cycles, its success/failure counters are not updated. The job itself completes fine; only the statistics drift, and the miss is logged. | Low - cosmetic counter drift only. | Optional: update the counters without the ownership check, or accept the drift. |

None of this affects the supported setup of one processor per queue across different
queues (see 4.3): #2 needs two processors on the SAME queue, and #1, #3, #4, #5 are
about a single processor's own behaviour.

Fixed and raised as a PR folder:
`~/pullrequests/oe-pay-pr-lease-locking-fixes/` (fixes #2-#5 against
PayloadProcessor master; #1 resolves itself via the routine release-into-develop
merge, so it is not in the PR). Implementation and verification in 5.5.

### 5.5 Lease locking fixes - implemented and verified live

The concerns #2-#5 from 5.4 are fixed in three files (patch in the PR folder,
changes also staged in `~/PayloadProcessor` on develop):

1. `RequestQueueLocker.java` - rewritten around a dedicated heartbeat thread that
   exclusively owns the lease Hibernate session (fixes #3). It acquires the lease
   once at startup with the existing 20 x 5s retry budget, renews every
   max(1s, TTL/3) (fixes #4), and releases only in its own finally, fenced by
   owner id. Ownership is published as a volatile flag; a refused renewal drops
   the flag immediately, an unreachable database keeps it up only until the last
   successful renewal is a full TTL old. Public API and exception contract are
   unchanged; the thread restarts after unlock() because DicomEngine's recovery
   loop re-enters execute() on the same executor. Daemon thread, so an unclean
   exit falls back to TTL expiry.
2. `RequestQueueExecutor.java` - the per-cycle release in execute()'s finally is
   removed; the lease now spans cycles and shutDown() is the single release
   point (fixes #2, and with it the counter-drift window #5 - the fenced counter
   update is kept, so a genuine ownership loss still skips the write).
3. `RequestWorkerService.java` - getRequestWithLock() restored to
   LockMode.UPGRADE_NOWAIT (the exact pre-OE-15491 form) as defence in depth.

Judgement calls: the #164 synchronized keywords are superseded (session no longer
crosses threads, so the worker monitor-blocking is gone too); the yield-vs-TTL
warning from 5.4 #4 was dropped as moot (renewal no longer depends on cycle
sleeps).

Verified live on the test stack (image built from the develop clone, run against
the populated database):

- Single processor: acquires at startup, `request_queue_lock.heartbeat_at` and
  `lease_until` advance every 10s (TTL 30).
- Contention: a second processor on the same queue sat in its retry loop for 25s+
  without taking the lease while the first renewed.
- Takeover: after `docker kill` of the holder, its lease expired at TTL and the
  second processor acquired ~1.2s later (expiry 14:37:07.72, steal 14:37:08.97),
  then resumed the 10s cadence. The same steal-on-expiry was observed against the
  stale lease a stopped container left behind.
- `mvn compile` passes on both develop and master 900764d;
  `git apply --check --3way` of the patch passes on pristine master.
- Stack restored afterwards: the original develop container reacquired the queue.
