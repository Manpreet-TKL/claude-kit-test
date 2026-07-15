# CLI, jobs, migrations, factories, seeders

Orientation only - *where* the entrypoints live and how the two frameworks relate.
How to *write* a console command -> `c-yiic-command-style`; the rules ->
`c-oe-coding-standards`; runtime/cron schedule -> `c-oe-components`.

## The two CLIs

- **`./protected/yiic <cmd>`** - Yii console. Boots through the **same** merged
  config as web (`config/console.php` -> `OEConfig::getMergedConfig('console')`), so
  module `config/common.php` + `local/` layering applies to CLI too.
- **`./oe-laravel/artisan`** - standard Laravel 12 (Horizon, queues, Tinker). Deps
  are in the **root** `composer.json` (`laravel/horizon`, `laravel/tinker`);
  `oe-laravel/composer.json` is a stub that only sets the namespace.

## `commands/` vs `cli_commands/` (don't conflate)

- `protected/commands/` - ~58 `CConsoleCommand` classes, run `./yiic
  <lowercased-name-minus-Command>` (e.g. `ResetUserLockCommand` -> `yiic
  resetuserlock`). The console bootstrap also scans every
  `modules/<X>/commands/*Command.php` and registers them (e.g.
  `OphTrOperationbooking/commands/GenerateSessionsCommand` -> `yiic generatesessions`).
- `protected/cli_commands/` - **not** a yiic dir. Holds only `file_watcher/`: a
  standalone DICOM-import daemon that connects to MySQL **directly via mysqli**
  (bypassing Yii), loops `while(true)`, and shells out to the Java importer in
  `protected/javamodules/IOLMasterImport/`. Run directly with `php
  runFileWatcher.php` / `php runQueueProcessor.php`.

## The job-dispatch bridge (one contract, two front-ends)

Job classes are cross-framework, in `oe-shared/app/.../Jobs` (base
`AsyncBaseJob`, `tries()=3`, `backoff()=[60,300,900]`). One contract
`OEShared\Contracts\Jobs\JobDispatcher`, two implementations:

- **Yii** `protected/components/JobDispatcher.php` -> `AsyncJobDispatcher`
  (also the `asyncJobDispatcher` component) / `SyncJobDispatcher`. The async path's
  `DatabaseQueueDriver` writes a **Laravel-format queue payload** into the `jobs`
  table (`"job" => "Illuminate\Queue\CallQueuedHandler@call"`, `command =>
  serialize($job)`).
- **Laravel** `oe-laravel/app/Components/JobDispatcher.php` -> Illuminate `Bus`.

So a Yii-side async job is queued by writing a Laravel-compatible row that a
Laravel `queue:work` worker / Horizon then executes. Same job class, two
front-ends, one `jobs` table (default connection `database`; Horizon uses `redis`).

## Migrations - "oemig" (how OE migrations actually run)

Three layers, top to bottom; `oe-migrate.sh` is the single funnel everything
routes through.

- **`protected/scripts/oe-migrate.sh`** - the canonical entry (deploys, CI,
  humans). Runs `yiic migrate --all --interactive=0`, then `oe-laravel/artisan
  migrate --force`, tees both into `protected/runtime/migrate.log`, then greps
  that log for error/exception/warning patterns and prompts Continue/Exit on a
  hit (exits 1 when `DEBIAN_FRONTEND=noninteractive`). Flags: `-q|--quiet` (log
  only), `--connectionID <id>`, `--ignore-warnings`. Callers: `oe-fix.sh`
  (unless `--no-migrate` / `OE_NO_DB=true`) and, at web-container startup,
  `/init_scripts/92-run-migrations-if-requested.sh` - only when
  `OE_FORCE_MIGRATE=TRUE`, followed by `yiic eyedrawconfigload`; not for
  multi-node prod (run on oe-manager instead).
- **`OEMigrateCommand`** (`protected/commands/`) - what `yiic migrate` is:
  `config/core/console.php`'s commandMap remaps `migrate` to it (extends stock
  Yii `MigrateCommand`) with `migrationPath=application.migrations`,
  `migrationTable=tbl_migration`, `connectionID=db`. Two OE additions:
  - `--all` - ignores `migrationPath`; collects new migrations from core
    `protected/migrations/` (~738) plus every **active** module's `migrations/`
    dir (keys of `Yii::app()->modules` - a disabled module's migrations are
    invisible), sorts the union by filename timestamp and runs it as one
    interleaved chronological pass, swapping `migrationPath` per migration.
    Cross-module FK deps are why per-module ordering isn't enough.
  - `--testdata` - calls `setTestData(true)` on `OEMigration` instances
    (`OEMigration` extends `CDbMigration` with CSV seed loading from
    `migrations/data/<Class>/` and helpers like `insertOEEventType()`).

  One shared history table `tbl_migration`; version = bare class name, no module
  prefix, so a row doesn't tell you which module it came from. `yiic migrate
  create <name>` emits an `OEMigration` subclass whose `safeDown()` returns
  false - OE migrations are up-only by default.
- **Laravel:** `oe-laravel/database/migrations/` - only the `jobs`/`failed_jobs`
  tables; the wrapper runs them via `artisan migrate --force`.

Gotchas and adjacent commands:

- `--migrationPath` takes a Yii path ALIAS (`application.modules.X.migrations`);
  a filesystem path fails with "The migration directory does not exist".
- `yiic oemigrate` = the same class via the commands-dir scan (no commandMap
  config; the class defaults happen to match). `yiic migratemodules`
  (`MigrateModulesCommand`) is the older per-module loop - shells `yiic
  oemigrate --migrationPath=application.modules.<X>.migrations` per active
  module, aborting on first failure; `migrate --all` is what the wrapper uses.
- `deploy` module special case: run from `protected/modules/deploy/yiic`, the
  commandMap swaps to stock `MigrateCommand` with table `tbl_migration_deploy`.

## Factories & seeders

- **Factories** (test/dev data): Yii `protected/factories/` (`ModelFactory` +
  ~165 in `factories/models/`, e.g. `PatientFactory`) and module `factories/`;
  Laravel `oe-laravel/database/factories/` (Eloquent, `OELaravel\Database\Factories`).
  Separate systems.
- **Seeders** (scenario builders): Yii-only `protected/seeders/` (`BaseSeeder`,
  `SeederBuilder`, `seeders/*Seeder.php`), driven by `./yiic seeder
  --event_type=... --seeder_class=...` to build whole clinical events for demo/test.
  No Laravel seeders exist.
