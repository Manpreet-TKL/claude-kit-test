# PayloadProcessor — runtime settings & the "continuous" mode

Notes from scanning `~/PayloadProcessor` (master). Covers every knob that
controls how the processor runs, with special attention to the question:
*is there a way to make it not run continuously?*

## TL;DR

* **Yes — `PROCESSOR_SHUTDOWN_AFTER` (env) → `-sa` / `--shutdownAfterMinutes` (CLI) is the "don't run continuously" switch.**
  * Default is `0` / unset, which makes the engine run **forever** as a service.
  * Set it to a positive number of **minutes** and the engine runs for that long, then shuts down cleanly and the process exits.
* This is the only built-in way to stop it being continuous. There is **no flag
  that keeps the process alive but periodically drops the DB transaction** — that
  is exactly what the code change in the companion PR adds at the root-cause level.
* Running with `PROCESSOR_SHUTDOWN_AFTER>0` + a Docker `restart: always` policy is
  a legitimate *operational mitigation* for the `innodb_history_list_length`
  growth (each restart releases the long-held transaction), but it trades the
  problem for restart churn and small downtime windows. The PR removes the need
  for it.

## How "continuous vs not" actually works in code

`DicomEngine.main` runs:

```java
while (runAsService || System.currentTimeMillis() < shutdownMsClock) {
    ... requestQueueExecutor.execute(); ...
}
```

* `runAsService` is set to `true` **only when no `-sa` argument is supplied**
  (`DicomEngine.java:140-144`). With `-sa N`, `runAsService` stays `false` and the
  loop ends once `shutdownMsClock` (now + N minutes) passes.
* On exit the engine calls `requestQueueExecutor.shutDown()` →
  `RequestQueueLocker.unlock()`, which commits/closes the queue-lock transaction.
  In continuous mode that transaction is held open for the whole process
  lifetime — the source of the `innodb_history_list_length` problem.

In the Docker entrypoint (`.docker_build/init.sh:68`):

```sh
[ ${PROCESSOR_SHUTDOWN_AFTER} -gt 0 ] && switches="${switches} -sa ${PROCESSOR_SHUTDOWN_AFTER}" || :
```

So `PROCESSOR_SHUTDOWN_AFTER=0` (the Dockerfile default, line 82) ⇒ no `-sa` ⇒
`runAsService=true` ⇒ continuous.

## Command-line arguments (`DicomEngine`)

| Flag | Long form | Meaning | Default |
|------|-----------|---------|---------|
| `-sf` | `--scriptFileLocation` | Directory of JS routine scripts | `src/main/resources/routineLibrary/` (container passes `/routineLibrary/`) |
| `-rq` | `--requestQueue` | `request_queue` row this processor serves | `dicom_queue` |
| `-sa` | `--shutdownAfterMinutes` | Run for N **minutes** then shut down. **Omit ⇒ run forever as a service.** | unset ⇒ service |
| `-sy` | `--synchronizeRoutine` | Minutes between syncing the on-disk routine library into `routine_library` | `0` |
| `-rd` | `--retryDatabaseConnectionForMinutes` | Retry the DB connection for N minutes at startup before giving up | `0` |

## Environment variables (Docker)

### Lifecycle / queue
| Env | Maps to | Meaning | Default |
|-----|---------|---------|---------|
| `PROCESSOR_QUEUE_NAME` | `-rq` | Queue to process | `dicom_queue` |
| `PROCESSOR_SHUTDOWN_AFTER` | `-sa` (only if `> 0`) | Minutes to run before exiting; `0` ⇒ run continuously | `0` |
| `SYNCHRONIZE_ROUTINE_DELAY` | `-sy` | Routine-library sync delay (minutes) | `99999` (effectively never) |
| `RETRY_DATABASE_CONNECTION` | *intended* `-rd` | Startup DB-connect retry window (minutes) | `2` |

### Database (`DatabaseConfiguration` + `hibernate.cfg.xml`)
| Env | Meaning | Default |
|-----|---------|---------|
| `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_NAME` | JDBC URL parts | `db` / `3306` / `openeyes` |
| `DATABASE_USER` / `DATABASE_PASS` | DB credentials (also support Docker secrets) | `openeyes` / `openeyes` |
| `POOL_SIZE` | HikariCP `maximumPoolSize` | `20` (from cfg) |
| `TZ` | JDBC + container timezone | `Europe/London` |

Hibernate connection defaults (`hibernate.cfg.xml`): HikariCP pool, `autocommit=false`,
`hibernate.connection.isolation=2` (READ COMMITTED), `hbm2ddl.auto=validate`,
pool min idle 10 / max 20 / idle timeout 300s.

### OpenEyes REST API (`ApiConfiguration`, README)
| Env | Meaning | Default |
|-----|---------|---------|
| `API_HOST` / `API_PORT` | OpenEyes web service host/port | `host.docker.internal` / `80` |
| `API_USER` / `API_PASSWORD` | API account (needs *API Access* RBAC role; supports Docker secrets) | `api` / — |
| `API_DO_HTTPS` | Use HTTPS for API calls | `FALSE` |

### Routine defaults (used by some scripts)
`DEFAULT_SUBSPECIALTY` (`Eye Casualty`), `DEFAULT_SERVICE` (`Eye Casualty Service`),
`DEFAULT_FIRM_NAME` (`Eye Casualty Service`), `HOSPITAL_NUMBER_CONSTRUCT_REGEX` (optional),
`DOCKER_CONTAINER` (`TRUE`).

### Startup host wait (`init.sh`, `docker-compose-wait`)
`WAIT_HOSTS` (the DB host is always added), `WAIT_HOSTS_TIMEOUT` (`1500`),
`WAIT_SLEEP_INTERVAL` (`2`), `WAIT_BEFORE_HOSTS`, `WAIT_AFTER_HOSTS`.

## DB-driven tuning (not env vars — columns on the `request_queue` row)

These control how hard the poll loop spins and therefore how "busy" the held
connection is. Read fresh from the DB each iteration:

* `maximum_active_threads` — max concurrent `RequestWorker` threads (one per request).
* `busy_yield_ms` — sleep after an iteration that found work.
* `idle_yield_ms` — sleep after an idle iteration (also when the routine-library sync runs).

## Pre-existing bugs spotted while scanning (NOT changed by the PR)

1. **`init.sh:65`** builds switches as
   `... -rq ${PROCESSOR_QUEUE_NAME} -sy ${SYNCHRONIZE_ROUTINE_DELAY} -rq ${RETRY_DATABASE_CONNECTION}`
   — it passes `RETRY_DATABASE_CONNECTION` under a **second `-rq`** instead of `-rd`.
   Commons-CLI keeps the first value, so the queue name still works, but `-rd`
   (DB-connection retry) is never actually passed to the engine.
2. **`DicomEngine.java:162`** computes the retry clock with `System.currentTimeMillis() * 60 * 1000 * RETRY_DATABASE_CONNECTION_FOR_MINUTES`
   (multiplication, should be `+`). Combined with (1) the startup DB-retry feature
   is effectively inert.
3. **README** describes `PROCESSOR_SHUTDOWN_AFTER` as *seconds*; the code treats it
   as **minutes** (`SHUTDOWN_AFTER_MINUTES`).

These are noted for awareness only — flag separately if you want them fixed.
