---
name: c-oe-payload-processor
description: PayloadProcessor - JS device-routine queue runner
disable-model-invocation: false
---

# oe-payload-processor

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

`~/PayloadProcessor` (remote `git@github.com:openeyes/PayloadProcessor.git`,
branch `master`) is a long-running **Java** daemon that pulls "routines" (small
**JavaScript** scripts) off a queue stored in the `~/openeyes` MySQL/MariaDB DB,
runs each routine on a GraalVM JS engine to process a device payload
(DICOM/OCT/XML/PDF/image), and writes results back to OpenEyes - **both** via its
REST API and via direct SQL on the shared DB. Maven artifact
`com.abehrdigital:PayloadProcessor`, main class `DicomEngine`.

**One container serves exactly one named queue.** To process N queues, run N
containers; a DB lock (a TTL lease in the latest versions, a held row-lock
before) guarantees one live processor per queue name.

## Request / routine lifecycle

```
external system creates a `request` (+ payload in attachment_data) and
`request_routine` rows (status NEW, an execute_request_queue, routine_name, execute_sequence)
   -> DicomEngine.main           acquires per-queue lock, loops
   -> RequestQueueExecutor       polls request_routine for this queue, spawns one worker per request_id
   -> RequestWorker (thread)     locks the request, runs its routines in execute_sequence order
   -> JavascriptScriptExecutor   wraps + evals the JS routine on GraalVM, binds RoutineScriptService
   -> routine reads payload, transforms, writes back via REST (attachmentData/document/patient)
                                 and/or direct SQL (DataAPI event engine)
   -> routine row -> COMPLETE (or RETRY w/ backoff, or FAILED); a request_routine_execution audit row is saved
```

## Runnable components (kept separate)

These are distinct responsibilities - **poll vs run vs sync vs lock**. Full detail
in `subs/components.md`:

1. **`DicomEngine`** - entry point / supervisor. Parses CLI, loads native OCR
   libs, builds the Hibernate `SessionFactory`, runs the outer recovery + inner
   execute loop. Main thread only.
2. **`RequestQueueExecutor`** - the **poller / scheduler**. Holds the queue lock,
   runs the poll query, and dispatches **one `RequestWorker` thread per
   `request_id`** up to `maximum_active_threads`. Triggers routine-library sync
   when idle.
3. **`RequestWorker`** - the **routine runner** (one thread per request). Loops:
   fetch this request's next eligible routine -> execute it -> set status.
4. **`RequestQueueLocker`** - the **process mutex**. Latest versions only
   (OE-18206, master / release/26.0.x): a TTL lease on the `request_queue_lock`
   row (`owner_id`/`lease_until`, default 30s via `REQUEST_QUEUE_LEASE_SECONDS`),
   renewed by a heartbeat thread at TTL/3. Older versions instead hold
   `SELECT ... FOR UPDATE NOWAIT` on that row for the process lifetime. Either
   way -> only one processor per queue.
5. **`RoutineLibrarySynchronizer`** - the **registry syncer**. Inserts a
   `routine_library` row for any on-disk script file not yet registered
   (insert-only; never updates/deletes).
6. **`JavascriptScriptExecutor` + GraalVM** - **executes** the JS (Polyglot,
   `allowAllAccess(true)`, *not* Nashorn), binding `RoutineScriptService` as the
   Java API the routine calls.
7. **Subsystems used by routines** - OCR (tess4j/Tesseract), DICOM (dcm4che), PDF
   (PDFBox), the OpenEyes REST client (`BaseApi` + subclasses), the `DataAPI`
   JSON->SQL event engine, and the Hibernate/HikariCP layer.

## Build / run / deploy - at a glance

Maven (`mvn package`) -> **appassembler** launch scripts at
`target/appassembler/bin/dicomEngine` (**not** a fat jar), Java 21. Two-stage
Dockerfile (maven-temurin-21) baking the routine library into `/routineLibrary`
and `eng.traineddata` into `/tessdata`; `.docker_build/init.sh` waits for hosts
then launches the binary. `docker-compose.yml` = local build; `docker-compose-full.yml`
= full demo stack (processor + web + mariadb). Full detail + env table + CLI args
in `subs/build-deploy.md`.

## Queue, routines & integration

The poll query enforces **strict in-order execution per request** via a
`NOT EXISTS` on lower `execute_sequence` rows; statuses are
`NEW/RETRY/COMPLETE/FAILED/VOID`; retries back off then give up at try >=20. See
`subs/queue-and-routines.md` for the query, status model, locking, the JS routine
model, the methods routines can call, and the bundled SEED routines. OpenEyes
integration (REST endpoints, DB tables, the `payload_processor` API user, admin
pages that live in the OpenEyes repo) and known issues are in
`subs/integration-and-gotchas.md`.

## Key anchors

Entry `DicomEngine.java:59-88`; poll/dispatch `RequestQueueExecutor.java:57-95`;
worker run loop `RequestWorker.java:40-67`; process lock
`RequestQueueLocker.java` (layout differs per version - see subs/components.md);
JS exec `JavascriptScriptExecutor.java:40-61`;
poll query `models/RequestRoutine.java:25-37`; retry backoff
`utils/RequestRoutineNextTryTimeCalculator.java`; container launch
`.docker_build/init.sh:65,77`.
