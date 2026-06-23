# IOLMasterImport — runnable components

Each component is a distinct process or in-process module. They hand off via the
DB queue (`dicom_file_queue`) and `exec()`, not via shared memory.

## 1. PHP file watcher — `cli_commands/runFileWatcher.php`

- **Started by:** the container entrypoint, the last line of `init.sh:123`:
  `cd $CLI_ROOT && php runFileWatcher.php`. This is the **long-lived foreground
  process** that keeps the container alive (under `tini`).
- **Trigger:** infinite `while(true)` loop (`runFileWatcher.php:27`), one pass per
  `QUEUE_SLEEP_INTERVAL` seconds (`sleep()` at line 76; default *intended* 300 —
  see gotchas).
- **Inputs:** the watched folder (`INCOMING_FOLDER`, default `/incoming`) and the
  `dicom_files` table (its "already seen" set, reloaded each pass).
- **Does:** `processDir()` recurses the folder; for each file not already in
  `dicom_files` (matched by name+size) it inserts a `dicom_files` row and a
  `dicom_file_queue` row with `status='new'`. Sub-folder names matching
  `^(local|global)-(\d+)-(\d+)$` (case-insensitive, line 88) are captured and
  stored in `dicom_file_queue.pid_type_id` (sub-select against
  `patient_identifier_type.unique_row_string`).
- **Hand-off:** if any new file was seen this pass, it backgrounds the queue
  processor: `exec('cd '.PHPdir.' && /usr/bin/php runQueueProcessor.php 2>&1 &')`
  (line 70).
- **Dead path:** the `fam_*` (inotify via PECL `fam`) branch is gated on
  `$dicomConfig['FAM']`, which defaults to 0 and is never set in Docker — dead.

## 2. PHP queue processor — `runQueueProcessor.php` + `queueProcessorClass.php`

- **Started by:** (a) the watcher's in-loop `exec(... &)` on new files, **and**
  (b) cron every 5 min (`.cron/IOLMaster`).
- **Mutual exclusion:** PID lock at `/tmp/DicomFileQueue.pid`
  (`runQueueProcessor.php:9`); if the recorded PID still runs (`ps -p`), it prints
  "Process still running! Exiting." and dies. `checkFileWatcher()` is a no-op in
  Docker (`DOCKER_CONTAINER=="true"` early-returns).
- **Work loop:** `queueProcessor::checkEntries()`
  (`queueProcessorClass.php:16`) selects up to 10 `dicom_file_queue` rows with
  `status='new'` (`ORDER BY id DESC`). Per row: set `in_progress`, resolve
  `pid_type_id` → `unique_row_string`, substitute it into the importer command via
  `preg_replace('/(local|global)-\d+-\d+/i', $pit, $cmd)` (line 39), then
  `exec($cmd.' '.$filename, $results, $exitcode)` (line 42). Exit 0 → `success`,
  nonzero → `failed`. Recurses until no `new` rows remain.

## 3. Java importer — `OE_IOLMasterImport.jar`

- **Entry:** `src/uk/org/openeyes/OE_IOLMasterImport.java` (`main`, lines 59-166).
- **Started by:** the queue processor's `exec`. The command is assembled in
  `fileWatcherConfig.php:16-31`:
  ```
  cd $APPROOT && java -cp ./lib/*:./OE_IOLMasterImport.jar \
    uk.org.openeyes.OE_IOLMasterImport [-r ..][-p ..][-a ..][-t ..][-i ..] -d -f <file>
  ```
  `-d` (debug) and `-f <file>` are always present; the others are added only when
  their env var is set. **PHP never passes `-c`**, so Hibernate is configured from
  env vars, not from a config file.
- **Trigger:** one JVM invocation **per file**.
- **Flow:** parse CLI (commons-cli) → `DICOMParser.initParser()` opens a Hibernate
  session → upsert `dicom_files` log row → `parseDicomFile()` reads the dataset
  (dcm4che) and dispatches to a device parser by SOP Class UID →
  `processParsedData()` resolves the patient and writes the Biometry event. On any
  exception: prints `Error:`, marks the log `failed`, `System.exit(1)`.
- **Exit codes:** 1 generic, 2 file-open fail, 3 read fail, 4 patient-not-found,
  5 DB-connect fail.
- **This is the only component that writes clinical data.**

## 4. FHIR / PAS client (optional, experimental) — `APIUtils.java`

- **Started by:** invoked in-process by `DICOMParser.processParsedData()`
  (lines 380-407), **only if** `-a <config>` was passed (`FHIR_API_ENABLE` set)
  **and** the local patient lookup failed.
- **Does:** HTTP GET `http://{FHIR_API_HOST}:{FHIR_API_PORT}/api/Patient?...&identifier=<hosNum>&patient_identifier_type=<pit>`
  with basic auth; on HTTP 200, `Thread.sleep(10000)` then retries `searchPatient`
  (the PAS is expected to have pulled the patient in). README/Dockerfile call this
  "experimental (untested)".

## 5. In-container cron — `.cron/IOLMaster` → `/etc/cron.d/IOLMaster`

- One line: `*/5 * * * * root . /env.sh … ; cd $CLI_ROOT && php runQueueProcessor.php`.
- Enabled by `init.sh:115` (`service cron start`) unless `ENABLE_CRON` upper-cased
  equals `FALSE`. `/env.sh` (written by `init.sh:107-112`) re-exports the
  container env into cron's shell. It is a **safety net** that drains the queue
  even if the watcher's background `exec` is missed.

## 6. Startup gates

- **`/wait`** — the static [`docker-compose-wait`](https://github.com/ufoscout/docker-compose-wait)
  binary committed at repo root. `init.sh:69` always appends
  `DATABASE_HOST:DATABASE_PORT` to `WAIT_HOSTS`, then runs `/wait` to block until
  the DB (and any extra `WAIT_HOSTS`, e.g. the web container) is reachable. After
  that, `init.sh:84-104` additionally polls `mysql … USE <db>` up to 200×2s to
  wait for the **schema** itself (created by the OpenEyes web container on first
  boot).
- **`tini`** — `ENTRYPOINT ["/tini", "--", "/init.sh"]` (PID-1 init / zombie
  reaper).
