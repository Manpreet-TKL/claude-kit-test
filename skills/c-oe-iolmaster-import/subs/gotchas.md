# IOLMasterImport — known issues & dead code

Found in the actual source. Cite/verify a line before relying on it — some of
this is stale or inert.

## Live bugs

- **Watcher CPU-spin / wrong default sleep.** `runFileWatcher.php:76` —
  `sleep(getenv('QUEUE_SLEEP_INTERVAL') ?? 300)`. `getenv()` returns `false` (not
  `null`) when unset, and `false ?? 300` is `false`, so `sleep(false)` ≈
  `sleep(0)` → the loop busy-spins a core. `QUEUE_SLEEP_INTERVAL` is **not** set
  in the Dockerfile, so this is the default behaviour. Intended guard is
  `getenv(...) ?: 300`.
- **Java `OE_MODE` check is always false.** `DatabaseFunctions.java:238` uses
  `System.getenv("OE_MODE").toLowerCase() == "dev"` — Java `==` is reference
  equality on Strings, so Hibernate `show_sql`/`hbm2ddl` are never enabled
  regardless of `OE_MODE`, and it NPEs if `OE_MODE` is unset.
- **`getenv('$CLI_ROOT')` literal.** `fileWatcherConfig.php:27` passes the literal
  string `$CLI_ROOT` (with the `$`) to `getenv`, which returns `false`, so it
  always falls back to `/cli_commands`. Harmless because the fallback is correct.

## Dead / inert code

- **FAM (inotify) branch** in `runFileWatcher.php` (lines 8-53, 116-202) is gated
  on `$dicomConfig['FAM']` (default 0, never set in Docker); php-fam isn't
  installed. The folder is polled, not inotify-watched. (A migration to inotify
  was the priority item in the original notes.)
- **Legacy `dicom-file-watcher` service** — `queueProcessorClass.php:37-51`
  `checkFileWatcher()` `sudo service dicom-file-watcher start` only runs outside
  Docker; that service doesn't exist in this image (pre-Docker artefact).
- **`DICOMHFAVF.java`** writes to hard-coded Windows paths
  (`d:\\work\\wombex\\...`) and its SOP UID is commented out in the dispatch map,
  so it's unreachable.
- **`persistence.xml`** declares an EclipseLink PU pointing at `openeyes_qa` and
  references classes that don't exist in `models/`; the runtime uses Hibernate,
  not this PU.
- **`src/resources/hibernate.cfg.xml`** hard-codes `db:3306`/deprecated driver
  with `hbm2ddl.auto=validate`; only used if `-c …hibernate.cfg.xml` is passed,
  which PHP never does.
- Committed dev scratch: `run_test_with_live_data.php`,
  `test_large_file_structure.php`, `testrun.txt`, `queuePid` — hard-coded paths,
  stale classpaths.

## Other rough edges

- **Unprepared/concatenated SQL** throughout the PHP (`createFileEntry`, logger)
  and some Java (`processImportedEvent` builds raw SQL with DICOM-sourced study
  IDs). DICOM-sourced but unsanitised.
- **Schema drift:** `cli_commands/file_watcher.sql` lacks the `pid_type_id` and
  `filedate` columns the code inserts and never defines `dicom_files` /
  `dicom_file_log`. The real schema comes from the OpenEyes module.
- **Default DB port `3333`** (Dockerfile) mismatches `hibernate.cfg.xml`'s 3306
  and is unusual.
- **`FHIR_API_PI_UNIQUE_ROW_STR`** (Dockerfile default `LOCAL-1-0`) is declared but
  read by no code — orphan env. FHIR feature is "experimental (untested)" per the
  README.
- **`calculateHaigisLH`** carries a `TODO this is still myopic...` — the hyperopic
  Haigis-L path reuses the myopic formula (`BiometryFunctions.java:996`).
- **`DICOMKOWA extends DICOMParser`** while the other parsers extend
  `IOLMasterAbstract` — inconsistent inheritance.
