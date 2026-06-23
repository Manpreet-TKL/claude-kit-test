---
name: c-oe-code
description: OpenEyes codebase shape — frameworks, modules, config
disable-model-invocation: true
---

# OpenEyes codebase shape

When loaded as context with no task, reply only `Context loaded.`

OpenEyes is event-based: every clinical interaction (examination, surgery, injection, letter, prescription, CVI, …) is an event on an episode on a patient. Licence AGPL-3.0-only. Clinical safety: never change persistence, calculations, units, or display of clinical values without an explicit ask; never bypass `audit` writes — see `c-oe-coding-standards`.

## Three frameworks, one repo

`index.php` is a 30-line router: `/xapi` + `/l/` → Laravel (`index_laravel.php` → `oe-laravel/`), everything else → Yii 1.1 (`index_yii.php` → `protected/`, the legacy bulk). Don't bolt rewrite rules onto it. `oe-shared/` is the home for cross-framework code (contracts, DTOs, repositories) — new code both frameworks need goes there, not `protected/` or `oe-laravel/`. Both share one `vendor/` and resolve the same OEShared contracts through their DI containers. Laravel is the growth area (ADR-12): prefer it for greenfield HTTP APIs; refactor Yii in place rather than mass-rewriting. CLI: `./protected/yiic` (see `c-yiic-command-style`) and `./oe-laravel/artisan` (Horizon, queues, Tinker).

## Config

`OEConfig::getMergedConfig($env)` is the **only** assembler. Load order (later wins): `core/common.php` → `core/<env>.php` → each module's `config/common.php` + `config/<env>.php` → `local/common.php` → `local/<env>.php`. Cached in APCu as `oe_merged_config_<env>`; bypass with `OE_CONFIG_TEST_RUNNING=1`; if an edit doesn't show up, run `apc_clear.php`.

## Modules

`protected/modules/<Name>/`. A module advertises itself in its **own** `config/common.php`; `local/common.php` is only the on-switch; never edit `core/common.php` from a module install. `Oph*` modules auto-import `models.*`. Cross-module reads via `Yii::app()->moduleAPI->get('<Module>')` → `<Module>_API` extending `BaseAPI` (`CoreAPI` for non-module data) — never reach into another module's models. Prefixes: `OphCi` clinical investigation, `OphCo` communication/document, `OphTr` treatment, `OphIn` investigation result, `OphDr` drug, `OphLe` letter, `OphOu` outcome. Scaffolding → `create-oe-module` skill.

## Orientation

1. `/xapi/*` or `/l/*` → `oe-laravel/`. 2. Clinical event/element → `protected/modules/Oph*/`. 3. Cross-cutting for both frameworks → `oe-shared/`. 4. Otherwise core Yii in `protected/`.

Root-level `*.md` design notes are the accepted home for analysis docs — keep new ones there, not under `protected/`. DB schema → `c-oe-db-schema`; container runtime → `c-oe-components`; rules → `c-oe-coding-standards`.

Subs: `subs/clinical-modules.md` (~49-module catalogue), `subs/examination-elements.md` (~59 OphCiExamination element types), `subs/explore.md` (goal-keyed jump table).
