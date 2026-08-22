# IOLMasterImport efficiency improvements → separate PRs

> Working plan (mirror of the approved session plan). Source of truth for the
> IOLMasterImport efficiency work: implement each change independently, test in
> the `mcauto` integration test bed, package each as its own `create-oe-pr`
> folder under `~/pullrequests/`, base branch `develop`. Nothing is committed or
> pushed by the assistant — the human pushes.

## Context

Kit `knowledge/iolmaster-import.md` documents resource-efficiency improvements for the
`IOLMasterImport` DICOM-import service. Headline (§4) = replace the polling
file-watcher with an inotify (kernel-notify) backend; §5 = further efficiency
wins. After a clean import works end-to-end, hunt for additional resource
inefficiencies and raise PRs for those too. User reviews/rejects the folders.

### Ground-truth corrections to the notes (verified against source)

1. **Busy-loop is always-on, not conditional.** Dockerfile sets
   `WAIT_SLEEP_INTERVAL=3` (for `/wait`), **not** `QUEUE_SLEEP_INTERVAL`. The
   latter is never set, so `runFileWatcher.php:76`
   `sleep(getenv('QUEUE_SLEEP_INTERVAL') ?? 300)` → `getenv()` returns `false`,
   `false ?? 300` → `false`, `sleep(false)` → `sleep(0)` → tight spin. Every
   iolm container burns a full core right now.
2. **Single-flight (§5 #5) already implemented** — `runQueueProcessor.php`
   PID-locks via `/tmp/DicomFileQueue.pid` + `isRunning()`. Excluded.
3. **FAM branch is unreachable, not literally dead** (`$dicomConfig['FAM']=='1'`,
   default 0; PHP FAM ext unpackaged on noble). Removal is cleanup (#6).
4. **Pre-filter must key on the DICM magic bytes, not the `.dcm` extension.**
   BridgeLink's File Writer drops extension-less files (live file in
   `~/mcauto/dicom-files/` is `1782104543121.dat`). Use the 128-byte preamble +
   `DICM` at bytes 128–131.

### Reconciliation with `origin/feature/efficiency` (done 2026-06-26)

Stale branch (forked pre-noble, pre-LF-normalization; ±13k churn is cosmetic
line-ending diff). Only two semantic commits, both by Manpreet, never merged:

- `46f00e8` "Small sleep to avoid CPU thrashing" — adds `usleep(50000)` **inside
  the FAM branch** (unreachable). Does **not** fix the real busy-loop at line 76.
  **Superseded by PR-1.**
- `3280a8b` "Persisting mysqli connection" — `connectDatabase.php` switches to a
  `p:`-prefixed **persistent** mysqli connection. Real efficiency win, stranded
  on the stale branch. **Resurrect as a clean PR off `develop`** (this is the
  "DB reconnect per loop" inefficiency-hunt item — use the user's own approach).

Do **not** base any PR on `feature/efficiency`; cherry-pick the idea onto a fresh
`develop`-based branch.

### Decisions (from the user)

- Each change = its own PR folder (granular).
- Base branch = `develop` (verified on origin; currently == `master` @ `371467c`).
- Include FAM removal (#6) and Java parser registry (#7).
- Exclude §5 #5 (done) and §5 #8 (lives in the `openeyes` repo).
- After a working import, investigate further inefficiencies and raise PRs.

## PR inventory — each standalone off `develop`

| PR | Slug | Jira type | Files |
|----|------|-----------|-------|
| 1 | `oe-iol-pr-watcher-busyloop-sleep` | Bug/Regression | `runFileWatcher.php` |
| 2 | `oe-iol-pr-inotify-watch-backend` | Improvement | `runFileWatcher.php`, `Dockerfile`, `init.sh`, `README.md` |
| 3 | `oe-iol-pr-watcher-keyed-file-lookup` | Internal Improvement | `runFileWatcher.php` |
| 4 | `oe-iol-pr-watcher-settle-guard` | Internal Improvement | `runFileWatcher.php` |
| 5 | `oe-iol-pr-watcher-dicm-prefilter` | Internal Improvement | `runFileWatcher.php` |
| 6 | `oe-iol-pr-remove-fam-branch` | Internal Improvement | `runFileWatcher.php` |
| 7 | `oe-iol-pr-parser-registry` | Internal Improvement | `DICOMParser.java`, `DICOMTools.java`, tests |
| 8 | `oe-iol-pr-persistent-db-connection` | Internal Improvement | `connectDatabase.php` (resurrected from `feature/efficiency`) |
| 9+ | other verified inefficiency-hunt wins | TBD | TBD |

### Inter-PR dependencies

None hard — all branch independently off `develop`, each green on its own. Soft:
PR-6 (remove FAM) reads cleaner before PR-2 (inotify); PRs 1–6 all edit
`runFileWatcher.php` and will textually conflict on merge (maintainer merge-order
concern, not correctness).

## Per-change implementation

- **PR-1 (sleep fix):** `runFileWatcher.php:76` `?? 300` → `?: 300` (Elvis).
- **PR-2 (inotify backend):** opt-in `WATCH_BACKEND` env (default `poll`). inotify
  branch: `inotify_init()`, recursive `addWatch()` mirroring `processDir()`'s
  walk, mask `IN_CLOSE_WRITE | IN_MOVED_TO | IN_CREATE`, blocking `inotify_read()`
  loop reusing an extracted `queueFile($path,$pidType,$mysqli,$logger)` helper
  (factored out of `processDir()` 98–109), one initial reconciliation scan, and
  `pcntl_async_signals(true)` + SIGTERM/SIGINT handlers. Dockerfile: build-then-
  purge `php${PHP_VERSION}-dev php-pear` + toolchain, `pecl install inotify`,
  enable in `/etc/php/${PHP_VERSION}/cli/conf.d/`. Keep the 5-min cron safety net.
  Document `WATCH_BACKEND` + network-mount caveat in README/init.sh.
- **PR-3 (keyed lookup):** drop per-cycle `SELECT * FROM dicom_files` + `$allfiles`
  map; `fileEntryExists()` → prepared `SELECT 1 ... WHERE filename=? AND
  filesize=?`. Preserves filename+filesize semantics.
- **PR-4 (settle guard):** skip files with `mtime` within N seconds before
  queueing in `processDir()`. Poll-path only.
- **PR-5 (DICM pre-filter):** require `DICM` at offset 128 before queueing; skip
  non-DICOM. Not extension-based.
- **PR-6 (remove FAM):** delete FAM init/loop/funcs; collapse loop to poll body.
- **PR-7 (parser registry):** `DICOMParser` SOP-UID if/else → `Map` registry;
  update Java unit tests.
- **PR-8 (persistent DB conn):** `connectDatabase.php` → `p:`-prefixed mysqli
  (resurrected from `feature/efficiency` 3280a8b).

## Build & test in mcauto

mcauto already up & seeded (`mcauto-db-1`, `mcauto-web-1` healthy, `mcauto-mc-1`
BridgeLink up, `mcauto-iolm-1` on `:26.0.0`). Sample patient 17885 (Agnes Bray),
id `LOCAL-1-0` / `1007913`. Host x86_64 (native build, no `--platform`, no SSH).

1. `cd ~/IOLMasterImport && docker build -t toukanlabsdocker/iolmasterimport:dev-eff .`
2. Swap only iolm via throwaway `~/mcauto/docker-compose.override.yml` (image
   `:dev-eff`, `pull_policy: never`, `WATCH_BACKEND` under test);
   `docker compose up -d --force-recreate iolm`. Remove override after.
3. Inject: `cd ~/mcauto && bash test-fixtures/edit-dicom.sh test-fixtures/dicom &&
   bash test-fixtures/send-dicom.sh test-fixtures/dicom` (or `cp` into `dicom-files/`).
4. Verify: logs "New file arrived" near-instant under inotify; SQL
   `dicom_file_queue` status `success`, `dicom_import_log` "Selected patient…",
   new `event` + `et_ophinbiometry_*`; `docker stats mcauto-iolm-1` idle CPU ≈ 0%
   vs ~100% baseline. Test both `poll` and `inotify`.

## Post-import inefficiency hunt

DB reconnect per loop → persistent connection (PR-8, above). JVM cold-start per
file (`java -cp …` per DICOM) — likely biggest churn, larger change, scope its own
PR/flag. String-interpolated INSERTs (`createFileEntry:147`) → prepared statement.
5-min cron redundancy once inotify on. Each verified win → its own PR folder.

## Packaging (create-oe-pr)

Per change: `~/pullrequests/oe-iol-pr-<slug>/` with `PR.md` (Jira form per
`create-oe-pr/subs/reference.md`) + fresh clone on a `fix/…`|`feature/…` branch
off `develop`, change applied uncommitted (new files `(new)`). One line per PR
appended to `~/pullrequests.md`. Never commit/push.
