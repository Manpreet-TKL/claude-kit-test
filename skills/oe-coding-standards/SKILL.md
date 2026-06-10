---
name: oe-coding-standards
description: OpenEyes coding rules and clinical-safety invariants
disable-model-invocation: true
---

# OpenEyes coding standards

When loaded as context with no task, reply only `Context loaded.`

## Clinical-safety invariants (non-negotiable)

1. Never change persistence, calculations, units, or display of clinical values (visual acuity, IOP, dose, laterality, drug name/strength, …) without an explicit ask.
2. Never bypass `audit` writes — `AuditService` runs on every clinical CRUD; write through the model layer even in scripts.
3. Soft-delete is the default for clinical data (`deleted = 1`), never `DELETE`.
4. `TestHelper` module is never enabled in production — don't loosen its `OE_MODE !== 'live'` check.
5. Never edit `core/common.php` from a module install — a module advertises itself in its own `config/common.php`; `local/common.php` is the on-switch.
6. `voiceControl` stays independent of `aiSearch` — no runtime dependency, shared key, or cross-import.

## ActiveRecord base classes

`BaseActiveRecord` (plain lookups) → `BaseActiveRecordVersioned` (history via `<table>_version`) → `BaseActiveRecordVersionedSoftDelete` (**the default for clinical entities**). Elements: `BaseEventTypeElement` (ordinary), `BaseMedicationElement` (medication-bearing), `BaseEsignElement` + `BaseSignature` (signature/PIN). Also `BaseEventTemplate`, `BaseReport`, `BaseSetting`, `BaseTree`. After a versioned-table migration: `GenerateVersionMigrationCommand`, then `VerifyVersionTablesCommand`.

## Conventions

- Validators: prefer `OE*Validator*` (`protected/components/`, `protected/validators/`) over hand-rolling — catalogue in `subs/validators.md`. Dates: `OEFuzzyDate` (`YYYY` / `YYYY-MM` / `YYYY-MM-DD`) with `OEFuzzyDateValidator` / `OEFuzzyDateRange`.
- Cross-module reads: `Yii::app()->moduleAPI->get('<Module>')` → `<Module>_API` extending `BaseAPI`; `CoreAPI` for core data. Never import another module's models directly.
- Lint: three layers × three tools — `phpstan|phpcs|rector` configs suffixed `.yii` / `.laravel` / `.shared`. Run the config for the layer you touched. Never add `phpstan-yii-baseline.neon` entries to dodge an error you just introduced.
- Tests: `OEDbTestCase` → `ActiveRecordTestCase` → `ModelTestCase`; `RestTestCase` for APIs. `WithTransactions` is incompatible with fixtures. Modules with a `DefaultController` need `@runTestsInSeparateProcesses` + `@preserveGlobalState disabled`. Cypress + Playwright for browser E2E.
- Migrations: core in `protected/migrations/`, module in `<Mod>/migrations/`; `<timestamp>_<snake>.php` extending `OEMigration`. Run via `yiic OEMigrate` / `MigrateModulesCommand`; check FKs with `VerifyForeignKeysCommand`.
- Config edit not showing? Clear APCu — `apc_clear.php` from repo root, or restart php-fpm.

Related skills: `bash-style`, `yiic-command-style`, `note-style`, `create-oe-module`. Subs: `subs/validators.md`, `subs/disruptive-ops.md` (literal-`yes` confirms, `set_frontend_passwords.sh` demo caveat, secrets naming).
