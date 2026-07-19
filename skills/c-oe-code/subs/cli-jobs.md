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

Redis mode + consumers (verified 26.0.6 / v26.1.0-pre1):

- Driver pick: `asyncJobDispatcher`'s `connection` is `getenv('QUEUE_CONNECTION')
  ?: 'database'` (`config/core/common.php`). `redis` swaps in `RedisQueueDriver`,
  which rpushes the same Laravel payload to `<REDIS_PREFIX>queues:<REDIS_QUEUE
  |default>` and back-fills Horizon's metadata keys so Yii-dispatched jobs show
  in the dashboard. No phpredis extension in the images - `REDIS_CLIENT=predis`.
- Password gotcha (26.0.x / v26.1.0-pre1 images only): `RedisQueueDriver::getRedis()`
  there auths from `getenv('REDIS_PASSWORD')` ONLY - it does not read the
  `/run/secrets/REDIS_PASSWORD` file the way `oe-laravel/config/database.php`
  does (secret-file first, env fallback). Password delivered as a Docker secret
  only -> every Yii-side redis dispatch throws `Predis\Response\ServerException:
  NOAUTH Authentication required.` while Horizon itself runs fine. Fixed on
  develop by OE-18162 (#12187, 2026-06-30): `config/core/common.php` reads the
  secret file into `params['redis_password']`, which the driver now uses.
- Consumers: the manager cron runs `queue:work --max-time=60` every minute
  (`protected/scripts/.cron/reportsqueue`; schedule `CRON_REPORTSQUEUE_SCH`) on
  whatever connection is default. Horizon is redis-only, gated by
  `ENABLE_HORIZON` in `/init_scripts/96-start-horizon.sh` - baked `TRUE` in the
  oe-manager image, `FALSE` in web, so a no-redis deployment's manager crash-loops
  Horizon 4x at start (`Connection refused [tcp://127.0.0.1:6379]`) into
  supervisord FATAL. With redis on, cron worker and Horizon both consume
  `default` - cron-run jobs bypass Horizon's metrics. Dashboard: `/l/horizon`
  (`HORIZON_PATH`), on the reserved `/l/` Laravel prefix.

## docmandelivery - v26 correspondence delivery (verified v26.1.0-pre2)

`yiic docmandelivery` (`protected/commands/DocManDeliveryCommand.php`) is the
single delivery command for **Docman + Electronic + Internalreferral** outputs -
there is no ElectronicDeliveryCommand. Selection logic:

- **Institution gate** (:62-80): `active = 1` AND at least one
  `correspondence_delivery_configuration` row. Per-institution flags
  with_docman / with_electronic / with_internal_referral come from the config
  rows' `output_type` (:101-108).
- **Row selection** (:125-179): `document_output` joined through
  document_target -> document_instance -> event ->
  et_ophcocorrespondence_letter, filtered `event.deleted = 0`,
  `event.delete_pending = 0`, `et_ophcocorrespondence_letter.draft = 0`.
- **Status**: `output_status = 'PENDING'` always, plus `'PRINTED'` ONLY when
  the institution has an Electronic config row - and that status OR-group
  applies across ALL output types selected for that institution.
- **'Print' never flows through it**: migration m241002_025325 converted
  config 'Print' rows to 'Electronic'; the cdc `output_type` enum is now
  `enum('Docman','Internalreferral','Print','Electronic')` but only the three
  non-Print values are acted on.
- **FAILED is never retried** by the cron path; `actionGenerateOne` ignores
  status entirely. Status writes at :329-343.
- `document_output.output_type` values: Print, Email, Email (Delayed),
  Internalreferral, Docman, Electronic; statuses DRAFT / SENDING / PENDING /
  PENDING_RETRY / FAILED / COMPLETE / PRINTED
  (`protected/models/DocumentOutput.php:48-61`; institution relations
  `protected/models/Institution.php:124-142`).
- `InternalReferralDeliveryCommand` (:139-150) overlaps for internal referrals
  but is simpler - no institution gate.
- Ops side: oe-deploy's manager cron runs it (`CRON_DOCMANDELIVERY_SCH`,
  default 21:00); the `oedocman` alias in oe-deploy `.bash_aliases` previews
  exactly what a run would pick up.

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
