---
name: oe-iolmaster-import
description: IOLMasterImport — PHP+Java DICOM biometry importer for OpenEyes
disable-model-invocation: true
---

# oe-iolmaster-import

When loaded as context with no task, reply only `Context loaded.`

`~/IOLMasterImport` (remote `git@github.com:openeyes/IOLMasterImport.git`, branch
`master`, release line `release/26.0.x`) is a **hybrid PHP + Java** service that
watches a folder for ophthalmic-device DICOM files (Zeiss IOLMaster 500/700
biometry, HFA visual fields, Kowa), parses them, and imports the measurements +
IOL calculations into the `OphInBiometry` schema of the `~/openeyes` app. It runs
as **one Docker container** alongside the OpenEyes stack and shares its DB.

## Data flow

```
device → INCOMING_FOLDER (/incoming)
   → runFileWatcher.php (loop)        inserts dicom_files + dicom_file_queue (status 'new')
   → runQueueProcessor.php            pulls 'new' rows, exec's the importer per file
   → java … OE_IOLMasterImport -d -f <file>   parse DICOM, resolve patient, write rows
   → OpenEyes DB: event, ophinbiometry_imported_events, et_ophinbiometry_*, dicom_import_log
```

Two connection paths to the **same OpenEyes DB**: PHP via `mysqli`
(`connectDatabase.php`), Java via Hibernate/JDBC (`DatabaseFunctions.java`). PHP
owns the queue tables; Java owns all clinical writes.

## Runnable components (kept separate)

The service is **several distinct processes**, not one. Full per-component run
detail (start command, trigger, hand-off) is in `subs/components.md`:

1. **PHP file watcher** — `cli_commands/runFileWatcher.php`. The foreground
   process (last line of `init.sh`); polls the folder, queues new files,
   backgrounds the queue processor.
2. **PHP queue processor** — `cli_commands/runQueueProcessor.php` +
   `queueProcessorClass.php`. PID-locked; drains `dicom_file_queue`, exec's the
   Java importer once per file, sets success/failed.
3. **Java importer** — `OE_IOLMasterImport.jar`
   (`src/uk/org/openeyes/OE_IOLMasterImport.java`). One JVM per file; parses and
   writes to the OpenEyes DB. **This is the only component that does clinical
   writes.**
4. **FHIR/PAS client (optional, experimental)** — `APIUtils.java`. In-process
   patient lookup, only when `FHIR_API_ENABLE` is set and the local lookup fails.
5. **In-container cron** — `.cron/IOLMaster`. Runs the queue processor every 5
   min as a safety net.
6. **Startup gates** — `/wait` (host readiness) + `tini` (PID 1), wired by
   `init.sh`.

## Build / run / deploy — at a glance

Ant build (`compile.sh` → `OE_IOLMasterImport.jar`, JDK 8, vendored `lib/`),
two-stage Dockerfile (temurin-8 builder → ubuntu:noble + php8.3 runtime),
`init.sh` entrypoint launches the watcher. Full detail + the env-var table in
`subs/build-deploy.md`. The only required config is the four `DATABASE_*` vars.

## OpenEyes integration

DICOM is dispatched by **SOP Class UID** (overridable by device-model tag) to a
per-device parser; patient is matched on padded hospital number + DOB + gender.
Writes land in `event`, `ophinbiometry_imported_events`,
`et_ophinbiometry_{measurement,selection,calculation,iol_ref_values}`, plus
auto-created reference data and a `dicom_import_log` audit row. Formats, parser
table, patient resolution and the full table list are in `subs/formats-db.md`.
There is **no web UI in this repo** — admin/log-viewer screens live in the
OpenEyes `OphInBiometry` module.

## Subs

- `subs/components.md` — every runnable component in detail (how each starts, what triggers it, hand-offs).
- `subs/build-deploy.md` — Ant build, Dockerfile, `init.sh` step-by-step, secrets, full env-var table, INI override, image-build trigger.
- `subs/formats-db.md` — DICOM SOP-UID dispatch, per-device parser table, patient resolution, directory naming, OpenEyes tables written.
- `subs/gotchas.md` — known bugs and dead code in the actual source (cite before trusting any of it).

## Key anchors

Dispatch `DICOMParser.java:191-227`; SOP map `DICOMTools.java:26-29`; patient
match `DatabaseFunctions.java:418-473`; measurement write
`BiometryFunctions.java:183-265`; watcher loop `runFileWatcher.php:27-77`; queue
exec `queueProcessorClass.php:16-63`; importer command build
`fileWatcherConfig.php:16-31`; entrypoint launch `init.sh:123`.
