---
name: oe_coding_standards
description: OpenEyes coding rules — clinical-safety invariants, AR base-class choice (BaseActiveRecord / Versioned / VersionedSoftDelete / BaseEventTypeElement / BaseEsignElement), OE*Validator catalogue, audit non-negotiable, soft-delete default, voiceControl independence from aiSearch, never edit core/common.php from a module install, three-layer PHPStan/PHPCS/Rector configs (yii/laravel/shared), TestHelper never in prod, OEFuzzyDate. Invoke explicitly before writing or reviewing OpenEyes code. Volatile detail (current validator list, lint baseline state) lives in subs/.
disable-model-invocation: true
---

# OpenEyes coding standards

A short list of non-negotiables, then the conventions.

## Clinical-safety invariants (non-negotiable)

1. **Never change persistence, calculations, units, or display of clinical values** (visual acuity, IOP, dose, eye laterality, drug name/strength, refraction, …) without an explicit ask. A "tidy-up" PR that silently changes a unit conversion is a patient-safety incident.
2. **Never bypass `audit` writes.** `AuditService` runs on every clinical CRUD. If you're tempted to skip it because "it's just a script", stop — write through the model layer.
3. **Soft-delete is the default for clinical data.** Don't `DELETE` from clinical tables; flag `deleted = 1` via `BaseActiveRecordVersionedSoftDelete`.
4. **`TestHelper` module is never enabled in production.** Its routes seed/wipe data for Cypress. The module checks `OE_MODE !== 'live'` — don't loosen that check.
5. **Never edit `core/common.php` from a module install.** A module advertises itself in its **own** `config/common.php`; `local/common.php` is the on-switch. Editing `core/common.php` poisons the canonical config for every deployment.
6. **`voiceControl` must stay independent of `aiSearch`.** No runtime dependency, no shared service-container key, no cross-import. They are separate modules.

## ActiveRecord base classes — pick the right one

| Base | When |
|---|---|
| `BaseActiveRecord` | Plain lookup tables; nothing clinical, no history needed. Still gets audit defaults and created/last-modified user tracking. |
| `BaseActiveRecordVersioned` | Anything that needs history. Writes to `<table>_version` on every save. |
| `BaseActiveRecordVersionedSoftDelete` | **The default for clinical entities.** Versioning + soft-delete. |
| `BaseElement` / `BaseEventTypeElement` / `BaseMedicationElement` | Element-type models. Pick `BaseEventTypeElement` for ordinary clinical elements; `BaseMedicationElement` for medication-bearing ones. |
| `BaseEsignElement` (+ `BaseSignature`) | Elements that require signature (esign / PIN). |
| `BaseEventTemplate` / `EventTemplate` / `EventTemplateUser` | User-saved event drafts as templates. |
| `BaseReport` | Reports. |
| `BaseSetting` | Settings storage (backed by `settingCache`). |
| `BaseTree` (+ `TreeBehavior`, `BuildTreeCommand`) | Hierarchical lookups. |

When in doubt for a clinical model → `BaseActiveRecordVersionedSoftDelete`. After adding the migration, run `GenerateVersionMigrationCommand` and verify with `VerifyVersionTablesCommand`.

## Validators

OE-specific validators live in `protected/components/OE*Validator*` and `protected/validators/`. **Prefer them over hand-rolling.** Current catalogue is in `subs/validators.md`.

Dates: use `OEFuzzyDate`. `YYYY`, `YYYY-MM`, and `YYYY-MM-DD` are all valid (approximate DOB, referral dates, etc.). Pair with `OEFuzzyDateValidator` / `OEFuzzyDateRange`.

## Cross-module reads

- Cross-module: `Yii::app()->moduleAPI->get('<Module>')` → `<Module>_API` extending `BaseAPI`.
- Core (non-module) data: `CoreAPI`.
- **Never reach into another module's models directly.** Reviewers should reject PRs that import `Element_OphCiExamination_*` from outside OphCiExamination — the right move is to extend `OphCiExamination_API`.

## Static analysis & lint

Three layers, three configs each. **Run the config for the layer you touched** — running PHPStan with the Yii config against Laravel code will explode.

| Layer | PHPStan | PHPCS | Rector |
|---|---|---|---|
| Yii (`protected/`)      | `phpstan.yii.neon`     | `phpcs.yii.xml`     | `rector.yii.php` |
| Laravel (`oe-laravel/`) | `phpstan.laravel.neon` | `phpcs.laravel.xml` | `rector.laravel.php` |
| Shared (`oe-shared/`)   | `phpstan.shared.neon`  | `phpcs.shared.xml`  | `rector.shared.php` |

`phpstan-yii-baseline.neon` holds long-standing Yii errors ignored until incrementally fixed. **Don't add new baseline entries to dodge a new error you just introduced** — fix it.

## Testing

- Base classes in `protected/tests/`: `OEDbTestCase` → `ActiveRecordTestCase` → `ModelTestCase`. `RestTestCase` for API tests.
- Traits in `protected/tests/test-traits/`: `WithTransactions` (per-test rollback — **incompatible with fixtures**), `WithFaker`, plus per-feature support traits.
- Modules with a `DefaultController` must declare `@runTestsInSeparateProcesses` + `@preserveGlobalState disabled` — otherwise PHP loads the wrong class (controllers aren't namespaced).
- Configs: `phpunit.xml`, `phpunit_ci.xml`, `phpunit_nonstop.xml`, `nocoverage.xml`. `protected/tests/docker-compose.yml` for local DB.
- **Cypress** (`cypress.config.js`) and **Playwright** (`playwright.config.ts`, `playwright.all.config.ts`) for browser E2E. Tests under `protected/tests/feature/` (some) and `playwright/tests/`.

## Migrations

- Core migrations in `protected/migrations/`; module migrations in `protected/modules/<Mod>/migrations/`.
- New core migration: `<unix-timestamp>_<snake_name>.php` extending `OEMigration` (or `CDbMigration` for trivial schema-only changes).
- Run with `./protected/yiic OEMigrate` (core) and `MigrateModulesCommand` (modules).
- After a schema change touching versioned tables: `GenerateVersionMigrationCommand`, then `VerifyVersionTablesCommand`. Across the lot: `VerifyForeignKeysCommand`.

## Config edits & APCu

- Module advertises in its **own** `config/common.php`. `local/common.php` is the on-switch only.
- After a config edit you can't see take effect: clear APCu (`apc_clear.php` from repo root, or restart php-fpm).

## House-style skills

For shell, command-line tools, notes, and module scaffolding, switch to the relevant house-style skill:

- `bash-style` — bash scripts (50-char banners, abort()+trap, `[OK]` echoes, camelCase functions).
- `yiic-command-style` — Yii CLI commands.
- `note-style` — design-note documents at the repo root.
- `create-oe-module` — scaffolding a new OpenEyes module.

## Where the volatile detail lives

- `subs/validators.md` — current `OE*Validator` catalogue.
- `subs/disruptive-ops.md` — disruptive-op confirmation rules (literal `yes`), `set_frontend_passwords.sh` caveat for demo DBs, secrets-naming.
