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

## Migrations - three locations, two runners

- **Core Yii:** `protected/migrations/` (~738), base `CDbMigration`; OE ones extend
  `OEMigration` (adds CSV seed-data loading from `migrations/data/<Class>/`). Run
  `./yiic migrate` -> `OEMigrateCommand`, table `tbl_migration`.
- **Module Yii:** `modules/<Name>/migrations/`. Run `./yiic migratemodules` ->
  `MigrateModulesCommand`. (The `deploy` module is a special case: table
  `tbl_migration_deploy`.)
- **Laravel:** `oe-laravel/database/migrations/` - only the `jobs`/`failed_jobs`
  table migrations. Run `php oe-laravel/artisan migrate`.

## Factories & seeders

- **Factories** (test/dev data): Yii `protected/factories/` (`ModelFactory` +
  ~165 in `factories/models/`, e.g. `PatientFactory`) and module `factories/`;
  Laravel `oe-laravel/database/factories/` (Eloquent, `OELaravel\Database\Factories`).
  Separate systems.
- **Seeders** (scenario builders): Yii-only `protected/seeders/` (`BaseSeeder`,
  `SeederBuilder`, `seeders/*Seeder.php`), driven by `./yiic seeder
  --event_type=... --seeder_class=...` to build whole clinical events for demo/test.
  No Laravel seeders exist.
