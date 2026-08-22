# IOLMasterImport

## 1. How the container works

IOLMasterImport is a hybrid PHP + Java service that imports biometry / visual-field DICOM files produced by ophthalmic devices into OpenEyes. PHP watches an inbound folder and maintains a database-backed queue; Java parses each DICOM file, maps fields to the OpenEyes ophthalmology event schema, and writes measurements directly into the OpenEyes database.

### Components

- **PHP file watcher** — `cli_commands/runFileWatcher.php`. Long-running CLI process started by `init.sh:123`. Detects new files in `INCOMING_FOLDER` and inserts rows into `dicom_file_queue` with status `new`.
- **PHP queue processor** — `cli_commands/runQueueProcessor.php`. Picks up to 10 files at a time from `dicom_file_queue`, marks them `in_progress`, shells out to the Java importer per file, then updates status to `success` / `failed`. Run on demand by the watcher (`exec(... &)`) and on a 5-min cron from `.cron/IOLMaster`.
- **Java importer** — `src/uk/org/openeyes/OE_IOLMasterImport.java` plus `DICOMParser.java` which dispatches on SOP Class UID to a per-device parser. Uses Hibernate for OpenEyes DB writes.
- **Optional FHIR client** — `src/uk/org/openeyes/APIUtils.java`. Patient lookup against an external FHIR endpoint, controlled by `FHIR_API_ENABLE`.

### Data flow

1. Device drops a `.dcm` (or directory tree of them) into `INCOMING_FOLDER`.
2. Watcher `stat()`s the file, inserts a row into `dicom_files` (filename, size, mtime, processor host) and a row into `dicom_file_queue` (filename, status `new`).
3. Watcher launches the queue processor in the background.
4. Queue processor invokes `java -cp ./lib/*:./OE_IOLMasterImport.jar uk.org.openeyes.OE_IOLMasterImport -d -f <file>`.
5. Java parser identifies the device by SOP Class UID, extracts measurements, writes to `et_ophinbiometry_measurement` and links into `ophinbiometry_imported_events`. Optional FHIR lookup resolves the patient by hospital number.
6. Status row is updated to `success` or `failed`; full audit trail in `dicom_file_log`.

### OpenEyes tables touched

- IOLMasterImport-owned: `dicom_files`, `dicom_file_queue`, `dicom_process_status`, `dicom_file_log`, `patient_identifier_type`.
- OpenEyes-owned (written by the Java importer): `et_ophinbiometry_measurement`, `ophinbiometry_imported_events`, plus normal event / episode / patient relations resolved during import.

### Configuration

| Variable | Default | Purpose |
|---|---|---|
| `INCOMING_FOLDER` | `/incoming` | Root directory watched (recursive) |
| `QUEUE_SLEEP_INTERVAL` | `3` (Dockerfile), `300` (intended fallback — broken, see §4) | Watcher loop sleep in seconds |
| `OE_MODE` | `DEV` | `DEV` or `LIVE` |
| `HOSNUM_REGEX` / `HOSNUM_PAD` | empty | Hospital-number normalisation applied during import |
| `PATIENT_IDENTIFIER_TYPE` | empty | Override of which `patient_identifier_type.unique_row_string` to use |
| `FHIR_API_ENABLE` | empty | Toggle FHIR patient lookup |
| `FHIR_API_HOST` / `_PORT` / `_USER` / `_PASSWORD` | `host.docker.internal:7070` / `api` / Docker secret | FHIR endpoint and creds |
| `DATABASE_HOST` / `_PORT` / `_NAME` / `_USER` / `_PASS` | OpenEyes DB | OpenEyes DB connection (Docker secrets supported) |
| `ENABLE_CRON` | `TRUE` | Whether the in-container cron service runs |

Alternative config source: `/etc/openeyes/file_watcher.conf` (INI, loaded by `cli_commands/fileWatcherConfig.php`).

---

## 2. Supported file formats

All inbound files are **DICOM** (`.dcm`). Format selection is by SOP Class UID (DICOM tag `0008,0016`), with an extra device-model override (tag `0008,1090`) to disambiguate IOLMaster generations. Dispatch lives in `src/uk/org/openeyes/DICOMTools.java:14-40`.

| Device | SOP Class UID | Parser | Extracts |
|---|---|---|---|
| Zeiss IOLMaster 500 | `1.2.840.10008.5.1.4.1.1.7.4` | `src/uk/org/openeyes/DICOMIOLMaster500.java` | Axial length, K1/K2 + axes, ACD, white-to-white, IOL formula results, SNR |
| Zeiss IOLMaster 700 | `1.2.840.10008.5.1.4.1.1.104.1` | `src/uk/org/openeyes/DICOMIOLMaster700.java` | IOLMaster 500 fields plus extended swept-source measurements |
| Humphrey Visual Field (HFA) | `1.2.840.10008.5.1.4.1.1.77.1.5.1` | `src/uk/org/openeyes/DICOMHFAVF.java` | Visual-field test data; extracts the embedded PDF report |
| KOWA biometry | `1.2.840.10008.5.1.4.1.1.77.1.5.1` (model-disambiguated) | `src/uk/org/openeyes/DICOMKOWA.java` | KOWA-encoded biometry measurements |

Anything else read off the directory is queued, attempted, and rejected by the Java parser (status `failed`); there is no pre-filter on extension or content.

---

## 3. OpenEyes admin pages

Configuration that affects IOLMasterImport lives in the **OphInBiometry** module: `/repo/openeyes/protected/modules/OphInBiometry/`.

| Page | Route | Purpose | Why IOLMasterImport needs it |
|---|---|---|---|
| **Biometry admin** | `/admin/biometry` | OphInBiometry module landing page; redirects to the DICOM log viewer | Operational entry point. |
| **DICOM log viewer — list** | `/admin/dicomlogviewer/list` | Lists every file the importer has seen, with status (`new` / `in_progress` / `success` / `failed`) | The only place clinicians/admins can confirm an import landed and inspect failures. |
| **DICOM log viewer — detail** | `/admin/dicomlogviewer/index` | Per-file log of every line the Java importer wrote | Forensic view when an import fails or maps the wrong patient. |
| **OphInBiometry module config** | `/biometry/admin` | Default lens types, IOL formulas, surgeon defaults, institution-specific biometry rules | Java importer reads these on insert to pick the right defaults when a field isn't in the DICOM file. |

OpenEyes-side prerequisites that aren't admin pages but must be set up:

- A `patient_identifier_type` row whose `unique_row_string` matches `PATIENT_IDENTIFIER_TYPE` (or matches the directory naming convention `local-N-M` / `global-N-M` that `processDir()` parses at line 88).
- The `dicom_process_status` table seeded with the `new`, `in_progress`, `success`, `failed` rows.

There is **no** Request Queue / Request Type / Routine Library configuration here — IOLMasterImport does not use the PayloadProcessor architecture.

---

## 4. Replacing the file watcher with inotify (the priority change)

### Why it currently burns a core

`cli_commands/runFileWatcher.php:27-77` is a `while(true)` loop that, on every iteration, opens a DB connection, runs `SELECT * FROM dicom_files`, recursively `readdir()`s the entire `INCOMING_FOLDER` tree, `stat()`s every file, and then sleeps. The intended sleep is 5 minutes:

```php
sleep(getenv('QUEUE_SLEEP_INTERVAL') ?? 300);
//             runFileWatcher.php:76
```

There are two compounding bugs:

1. **The Dockerfile sets `QUEUE_SLEEP_INTERVAL=3`** (it was meant for the `runQueueProcessor` cron, not the watcher) — so the watcher iterates every 3 seconds.
2. **The fallback is wrong**: `getenv()` returns `false` for an unset variable, not `null`, and `false ?? 300` evaluates to `false`. `sleep(false)` casts to `0` and returns immediately. So if `QUEUE_SLEEP_INTERVAL` is ever unset (or removed thinking it'll fall back to 5min), the loop spins as tight as the kernel will let it — that's the full core.

Even fixed, polling is wasteful: `SELECT *` on `dicom_files` plus a full `readdir` recursion every few seconds, on every container, regardless of whether anything new arrived.

### Strategy: swap the loop body, keep everything else

The good news is that the work the watcher does **per detected file** is well factored — `createFileEntry()`, `fileEntryExists()`, the queue-insert SQL, and the `processDir()` recursion logic all stay intact. We only replace the *trigger mechanism* (poll → kernel notify). The change is contained to the body of `while (true) { ... }` plus a small init block.

### Step-by-step migration

**1. Add the PHP inotify extension to the image.**

`Dockerfile` — add to the existing PHP install layer:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
        php8.3-dev php-pear \
    && pecl install inotify \
    && echo "extension=inotify.so" > /etc/php/8.3/cli/conf.d/20-inotify.ini \
    && apt-get purge -y php8.3-dev php-pear && apt-get autoremove -y
```

(If the base image is one of the official `php:*-cli` images, the recipe is `pecl install inotify && docker-php-ext-enable inotify`.)

Verify with `php -m | grep inotify` during the image build.

**2. Introduce a `WATCH_BACKEND` env var.**

Default it to `poll` so existing deployments are byte-identical until they opt in. Read it once at the top of `runFileWatcher.php`:

```php
$backend = getenv('WATCH_BACKEND') ?: 'poll';   // 'poll' | 'inotify'
```

This makes the rollout per-site reversible without redeploying the image.

**3. Add an `inotify` branch alongside the existing `FAM` / poll branches.**

The file already has the right shape: `if ($dicomConfig['FAM']) { ... } else { /* poll */ }`. Add a third branch. Touch only:

- The init block at lines 7–25 (add inotify init).
- The loop body at lines 27–77 (add the inotify branch).
- Leave `processDir()`, `fileEntryExists()`, `createFileEntry()`, `checkExistingFiles()` unchanged.

**4. Initial reconciliation scan.**

Race-free startup: before adding any watch, run the existing recursive scan once to catch files that arrived while the watcher was down. This is exactly the body that's already in lines 55–64 — extract it into a function `performReconciliationScan()` and call it once at startup. No new logic required.

**5. Set up watches.**

Open the inotify fd, walk `INCOMING_FOLDER` recursively (mirror the same recursion `processDir()` already does), and add one watch per directory:

```php
$fd  = inotify_init();
$wds = [];                    // wd → absolute directory path
$mask = IN_CLOSE_WRITE        // file writer closed it (preferred over IN_CREATE — survives partial copies)
      | IN_MOVED_TO           // atomically renamed into the dir (rsync / .tmp → .dcm)
      | IN_CREATE             // needed only to detect new subdirs to watch
      | IN_ONLYDIR_SAFE;      // pseudo-mask: see addWatch helper below

function addWatch($fd, $dir, &$wds, $mask) {
    $wd = inotify_add_watch($fd, $dir, $mask);
    $wds[$wd] = $dir;
    foreach (new DirectoryIterator($dir) as $e) {
        if ($e->isDir() && !$e->isDot()) addWatch($fd, $e->getPathname(), $wds, $mask);
    }
}
addWatch($fd, $dicomConfig['biometry']['inputFolder'], $wds, $mask);
```

Use `IN_CLOSE_WRITE` rather than `IN_CREATE` for the file-arrival signal — it fires only when the writing process closes the fd, so partially-copied files aren't queued. `IN_MOVED_TO` covers DICOM senders that write to `*.tmp` then rename. `IN_CREATE` is used only on directories so we can attach watches to newly created subdirs.

**6. Replace the loop body with a blocking read.**

```php
while (true) {
    $events = inotify_read($fd);            // blocks — zero CPU until something happens
    if ($events === false) break;

    $newfile = false;
    $mysqli  = connectDatabase();
    $logger  = new eventLogger($mysqli);

    foreach ($events as $ev) {
        $dir  = $wds[$ev['wd']] ?? null;
        if ($dir === null) continue;
        $path = $dir . '/' . $ev['name'];

        if ($ev['mask'] & IN_ISDIR) {
            if ($ev['mask'] & (IN_CREATE | IN_MOVED_TO)) {
                addWatch($fd, $path, $wds, $mask);   // pick up new subdirs
            }
            continue;
        }

        if (!is_file($path)) continue;
        $filedata = stat($path);
        if (fileEntryExists($path, $filedata, $mysqli)) continue;

        // Re-derive pidType from the parent dir name, exactly like processDir() lines 88-92
        $pidType = preg_match('/^(local|global)-(\d+)-(\d+)$/i', basename($dir))
                 ? basename($dir) : ($dicomConfig['patientidentifiertype'] ?? null);

        createFileEntry($path, $filedata, $mysqli);
        // …reuse the prepared-statement INSERT from runFileWatcher.php:101-108 verbatim…
        $logger->addLogEntry($path, 'new', basename($_SERVER['SCRIPT_FILENAME']));
        $newfile = true;
    }

    // Coalesce bursts: drain anything else that arrived while we were inserting.
    while (inotify_queue_len($fd) > 0) {
        // re-enter the foreach by reading again non-blocking-ish via stream_select($fd, …, 0)
    }

    if ($newfile) {
        exec('cd '.$dicomConfig['general']['PHPdir'].' && /usr/bin/php runQueueProcessor.php 2>&1 &');
    }
    $mysqli->close();
}
```

Net effect: process is asleep in the kernel until a real event arrives. No `sleep()`, no poll, no recurring `SELECT * FROM dicom_files`. CPU at idle drops to ~0%.

**7. Signal handling for clean shutdown.**

`inotify_read()` is a blocking syscall, so the container won't react to `SIGTERM` quickly without help:

```php
pcntl_async_signals(true);
pcntl_signal(SIGTERM, function () use (&$fd) { @fclose($fd); exit(0); });
pcntl_signal(SIGINT,  function () use (&$fd) { @fclose($fd); exit(0); });
```

Closing the fd makes `inotify_read()` return `false` and the loop exits cleanly.

**8. Bump the watch limit if needed.**

Each watched directory consumes one entry from `/proc/sys/fs/inotify/max_user_watches` (default 8192 on most kernels, plenty for this use case but worth confirming on hosts with many years of historical sub-folders). Document in the deployment notes; no code change.

### Things to verify before flipping `WATCH_BACKEND=inotify`

- **Is `INCOMING_FOLDER` a network mount?** inotify only sees writes that happen on the *local* kernel. If the device drops files via SMB / NFS from another host, the local kernel never sees the write and inotify will be silent. Two sane options: (a) keep `poll` for those sites, or (b) run inotify on the share's host and forward via a small relay. This is the single biggest gotcha.
- **Atomic-rename check.** Confirm the device / sender writes to a temp name and renames — `IN_MOVED_TO` will catch it. If it streams directly, `IN_CLOSE_WRITE` will catch it. If it does neither (very rare), fall back to `IN_CREATE` plus a small "settle" delay.
- **Test with the existing `.cron/IOLMaster` job still running** — the 5-minute cron is a cheap safety net that will reconcile anything inotify missed (e.g. during a watcher restart). Keep it.

### Files to change

- `cli_commands/runFileWatcher.php` — add inotify branch (lines 7–25 init, lines 27–77 loop body). Roughly +60 / −0 lines; no existing behaviour removed.
- `Dockerfile` — install + enable the inotify extension. ~3 lines.
- `init.sh` / docker-compose — document and surface `WATCH_BACKEND`.
- No DB migration. No Java change. No OpenEyes change.

---

## 5. Other future improvements

These are out of scope for the inotify swap but worth queuing.

1. **Fix the `getenv() ?? 300` fallback bug.** Use `getenv('QUEUE_SLEEP_INTERVAL') ?: 300` (Elvis operator) so an unset env var actually falls back to 300s. Trivial, self-contained, immediate CPU win on existing poll-mode deployments.
2. **Stop `SELECT * FROM dicom_files` on every cycle.** The poll branch builds an in-memory map of every file ever seen. As `dicom_files` grows, so does this map. Replace with a per-file `SELECT 1 FROM dicom_files WHERE filename = ? AND filesize = ?` keyed lookup — or, better, a `UNIQUE(filename, filesize)` index plus `INSERT IGNORE` and trust the unique constraint.
3. **Use `IN_CLOSE_WRITE` semantics in the existing poll path.** Right now `is_file() + stat()` will pick up a file mid-copy and may queue it before the writer finishes — `runQueueProcessor` then fails parsing. A "modified within last N seconds" guard would close the gap until inotify ships.
4. **Pre-filter by extension.** `processDir()` queues every file regardless of type, then the Java parser rejects non-DICOM. Skipping files whose extension isn't `.dcm` (or whose first 132 bytes don't end in `DICM`) avoids round-trips through the queue and the JVM.
5. **Single-flight the queue processor launch.** `exec('runQueueProcessor.php &')` can fire multiple concurrent processors during a burst of files. A pidfile / `flock` would prevent overlap and the wasted DB churn that follows.
6. **Decommission the dead FAM branch** (`runFileWatcher.php:12-19, 32-53, 133-203`). The PHP FAM extension hasn't been packaged for Debian since PHP 5; the code is unreachable in any current build. Removing it shrinks the surface area before adding the inotify branch.
7. **Promote per-device parser detection to a registry.** `DICOMParser.java`'s if/else chain on SOP Class UID makes adding a new device (e.g. Pentacam, Atlas topographer) require touching the dispatcher. A `Map<String, BiometryParser>` populated at startup would let new parsers self-register.
8. **Surface failures into the OpenEyes admin UI.** The DICOM log viewer shows `failed`, but the actual exception lives in container stdout / `dicom_file_log`. A "view error" link on the list page would save a lot of `kubectl logs` round-trips.
