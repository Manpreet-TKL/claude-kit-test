# Tooling & static analysis

Three codespaces (`yii`, `laravel`, `shared`) × three tools (phpcs, phpstan, rector), each with a
config suffixed `.yii` / `.laravel` / `.shared`. Run the config for the layer you touched. Drive
everything through composer scripts — list them with `composer run-script --list`.

## phpcs

Base style is PSR-12 (`phpcs.xml`). Check/auto-fix changed files before committing; target files after `--`.

```bash
composer cs:yii:full -- protected/path/File.php -v   # check (PSR-12 + Yii exceptions)
composer cbf:yii -- protected/path/File.php -v        # autofix (phpcbf)
```

- PRs run only `phpcs` (no autofix), so web-UI edits can fail CI.
- To reproduce a CI failure, run against the **full** changed-file list (from the Action output), not one file; `-v` surfaces issues hidden on single files.
- Laravel and Shared configs must stay mutually consistent.

## Pre-commit hooks

Configure the project's hook path so phpcbf → phpcs → rector run on changed files at commit (v26.0+).
The ToukanLabs dev environment sets this up automatically.

```bash
git config core.hooksPath ./githooks
```

## PHPStan

There is **no** pre-commit PHPStan for Yii (legacy noise, kept fast), so run it manually before pushing:

```bash
composer stan:branch                 # vs develop (default)
composer stan:branch release/26.0.x  # vs another target branch
```

- Levels: Yii `phpstan.yii.neon` level 3 (baseline `phpstan-yii-baseline.neon`); Laravel `phpstan.laravel.neon` level 5 (Larastan); Shared `phpstan.shared.neon` level 5 (no Larastan).
- **Never add baseline entries to dodge an error you just introduced.** The baseline is for pre-existing legacy noise only; the goal is to raise Laravel/Shared levels over time.

## Rector

Write code compatible with the target PHP version (**8.4** as of v26.0); Rector enforces this in
pre-commit and CI. Run with `composer rector`.

## APCu

Config (module registration, params) is cached in APCu. If an edit isn't taking effect, clear it:
run `apc_clear.php` from the repo root, or restart php-fpm.

## Migrations

`<timestamp>_<snake_name>.php` extending `OEMigration`; core migrations in `protected/migrations/`,
module migrations in `<Module>/migrations/` (CSV seed data under `migrations/data/<name>/NN_<table>.csv`).

```bash
yiic OEMigrate            # core + run
# MigrateModulesCommand   # module migrations
# VerifyForeignKeysCommand to check FKs
```

- After a versioned-table migration: `GenerateVersionMigrationCommand`, then `VerifyVersionTablesCommand`.
- Core and module migrations interleave when run with `yiic migrate --all` (see `create-oe-module`).

---
Sources: Code Style & Static Analysis (3399909380), Coding Standards (1570668569).
