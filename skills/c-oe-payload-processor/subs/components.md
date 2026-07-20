# PayloadProcessor - runnable components

Responsibilities are deliberately split: **lock** (one process per queue),
**poll/dispatch**, **run** (per request), **execute** (the JS), **sync** (the
registry). They are wired in `DicomEngine.main` (`:44-63`): synchronizer built
first, then the executor with `(queueName, synchronizer, shutdownClock,
runAsService)`.

## DicomEngine - entry point / supervisor

`DicomEngine.java`. Parses CLI args (`:107-156`), loads Tesseract/Leptonica native
libs (`:35-42`), builds the Hibernate `SessionFactory` with DB-connect retry
(`:158-178`), inits API config + JS wrapper scripts, runs an initial
routine-library sync, then the **outer stability-recovery loop + inner execute
loop** (`:66-87`). Catches `Exception|Error`, calls `shutDown()`, re-enters the
loop. Main thread only. **`-sa` absent => `runAsService=true`** (runs forever).

## RequestQueueExecutor - poller / scheduler

`RequestQueueExecutor.java`. The component that **polls** and **dispatches** (it
does not itself run routines). Each cycle:

- Reads per-queue tuning live from the `request_queue` row:
  `maximum_active_threads`, `busy_yield_ms`, `idle_yield_ms` (`:67-95`).
- Runs the poll named-query `routinesWithRequestQueueRestrictionForProcessing`
  (`:57-59` -> `RequestRoutineDao.getRoutinesForQueueProcessing`,
  `RequestRoutineDao.java:69-81`).
- Groups results by `request_id` and spawns **one `RequestWorker` thread per
  distinct request** (`requestIdToThreadSyncMap` ensures at most one in-flight
  worker per request, `:73-86`), capped at `maximum_active_threads`.
- When idle, triggers `routineLibrarySynchronizer.sync()` (`:94`).
- Implements `RequestThreadListener.deQueue` (`:162-169`) - workers call back to
  update the queue's success/fail/active counters (`request_queue` is written
  under `LockMode.UPGRADE_NOWAIT`, `:139-142`; in lease versions this became a
  fenced `UPDATE ... WHERE owner_id = <me>` guarded by the volatile ownership
  flag).

## RequestWorker - routine runner (one thread per request)

`RequestWorker.java` (`Runnable`). Locks the `request` row, then loops:
`getNextRoutineToProcess()` -> `executeRequestRoutine()` (`:40-67`). For each
routine it sets status/`hash_code`, persists a `request_routine_execution` audit
row with the captured log, and increments success/fail counters. On
`OptimisticLockException` it rolls back and leaves the row untouched so it re-runs
later (`:86-91`). Thread named `"request_id=<id> worker thread"`. Each worker owns
its own `ScriptEngineDaoManager` / Hibernate session. `RequestWorkerService` is
the thin facade (transaction control, next-routine lookup, body load via
`RoutineScriptAccessor`).

## RequestQueueLocker - process mutex per queue

`RequestQueueLocker.java`. **This is what makes "one processor per queue" true.**
Two designs exist:

- **Latest versions only** (OE-18206, on master / release/26.0.x - not in older
  releases): a TTL **lease** on the `request_queue_lock` row (`owner_id`,
  `lease_until`, `heartbeat_at`; columns added by an OpenEyes-side migration).
  Fenced native SQL against `UTC_TIMESTAMP(6)`: renew where `owner_id` = me and
  `lease_until` > now, else acquire/steal where owner is NULL or expired;
  release is fenced by owner too. TTL default 30s, env
  `REQUEST_QUEUE_LEASE_SECONDS`.
- **Heartbeat design on top of the lease** (delivered as a fix PR, pending merge
  as of 2026-07 - `~/pullrequests/oe-pay-pr-lease-locking-fixes/`): a daemon
  heartbeat thread exclusively owns the lease Hibernate session; it acquires
  once at startup (retry budget 20x with 5s sleeps), renews every
  max(1s, TTL/3), and releases only in its own finally on shutdown, so the
  lease spans polling cycles. Ownership is published to the polling/worker
  threads as a volatile flag (`isLeaseOwned()`) - they never touch the session.
  A refused renewal drops the flag immediately; an unreachable DB keeps it only
  until the last successful renewal is a full TTL old. The thread restarts
  after `unlock()` (DicomEngine's recovery loop re-enters `execute()` on the
  same executor); an unclean exit lets the lease lapse at TTL for the next
  processor to steal. Before this PR, the lease was acquired and released every
  polling cycle, leaving unowned gaps between cycles.
- **Older versions**: opens its own session and holds
  `SELECT ... FOR UPDATE NOWAIT` (`LockMode.UPGRADE_NOWAIT`) on the row for the
  whole process lifetime; if the row is missing it inserts one; retries up to
  20x with 5s sleeps; `unlock()` commits the held transaction.

## RoutineLibrarySynchronizer - registry syncer

`RoutineLibrarySynchronizer.java`. Lists files in `SCRIPT_FILE_LOCATION` and
inserts a `routine_library` row (name + script `hashCode`) for any file not yet
registered. **Insert-only - never updates an edited script's hash, never removes
a deleted one** (`:25-46`). Throttled by `-sy` minutes. Runs on the main thread at
startup and whenever the queue is idle.

## JavascriptScriptExecutor + GraalVM - executes the JS

`JavascriptScriptExecutor.java`. Uses **GraalVM Polyglot**
(`Context.newBuilder("js").allowAllAccess(true)`, `:40-44`) - **not** Nashorn.
Wraps the routine with `preScript/functions` + script + `postScript/save`, binds
the Java `RoutineScriptService` object under a random 6-char name, and rewrites
bare method calls to `<name>.method(` via `JavascriptRoutineMethodConverter`
(`:30-34,50-56`). stdout/stderr are captured into a buffer returned as the
execution log. A new `Context` is created per routine, on the worker thread.

## Subsystems invoked by routines (not standalone processes)

- **OCR** - `utils/ImageTextExtractor.java` (tess4j `Tesseract`,
  `datapath=/tessdata/`); native `liblept`/`libtesseract` loaded in
  `DicomEngine.main` and symlinked by the Dockerfile.
- **DICOM** - `DicomParser.java` + `Study.java` (dcm4che 5.25): flattens header
  tags to a hex-keyed map, extracts encapsulated docs / pixel data, exposes
  image/PDF blobs.
- **PDF** - `utils/PDFUtils.java` + `PdfTextWithCoordinates*` (PDFBox 2.0.33):
  text-by-coordinate scrape, render-to-image for OCR, thumbnails.
- **OpenEyes REST client** - `utils/BaseApi.java` (Apache HttpClient, Basic auth)
  + `AttachmentDataApi`, `DocumentUploadApi`, `PatientSearchApi`.
- **DataAPI** - `DataAPI.java` + `Query.java` + `XID.java`: a JSON-driven SQL
  generator invoked by `RoutineScriptService.createEvent()`; emits INSERT/UPDATE
  against OpenEyes tables **directly via the worker's Hibernate connection**
  (savepoint per saveset). This - not REST - is how events/episodes are created.
- **Hibernate / HikariCP** - `utils/HibernateUtil.java`,
  `utils/DatabaseConfiguration.java`, `resources/hibernate.cfg.xml`: one global
  `SessionFactory`, HikariCP pool (min 10 / max 20), `hbm2ddl.auto=validate`.
