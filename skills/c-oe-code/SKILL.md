---
name: c-oe-code
description: OpenEyes codebase shape — frameworks, modules, config
disable-model-invocation: true
---

# OpenEyes codebase shape

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself — it just loads knowledge; act only on instructions given in the conversation.

OpenEyes is event-based: every clinical interaction (examination, surgery, injection, letter, prescription, CVI, …) is an event on an episode on a patient. Licence AGPL-3.0-only. Clinical safety: never change persistence, calculations, units, or display of clinical values without an explicit ask; never bypass `audit` writes — see `c-oe-coding-standards`.

## Three frameworks, one repo

`index.php` is a 30-line router: a path starting `/xapi` or `/l/` → Laravel (`index_laravel.php` → `oe-laravel/`, namespace `OELaravel\` = `oe-laravel/app`), everything else → Yii 1.1 (`index_yii.php` → `protected/`, the legacy bulk). `/xapi` carries the live API routes; `/l/` is a **reserved** web prefix with nothing registered on it yet. Don't bolt rewrite rules onto the router. `oe-shared/` (namespace `OEShared\` = `oe-shared/app`: `Contracts/ DTOs/ Repositories/ Services/ Enums/ Jobs/`) is the home for cross-framework code — new code both frameworks need goes there, not `protected/` or `oe-laravel/`. (Don't confuse it with root `shared/`, which is just static AssetManager images.) Both frameworks share one root `vendor/` and resolve the same `OEShared\Contracts\…` through their DI containers — Yii via a bespoke PSR-11 `YiiContainer` (the `container` component in `config/core/common.php`), Laravel via the native Illuminate container. Laravel is the growth area (ADR-12): prefer it for greenfield HTTP APIs; refactor Yii in place rather than mass-rewriting. CLI: `./protected/yiic` (see `c-yiic-command-style`) and `./oe-laravel/artisan` (Horizon, queues, Tinker) — see `subs/cli-jobs.md`.

## The `protected/` tree (legacy vs replatform)

Date code by **namespace**. Global namespace + `C*`/`Base*` base classes = legacy Yii 1.1 (`components/ controllers/ models/ widgets/ behaviors/ commands/ migrations/ extensions/ views/`). PSR-4 `OE\<dir>\` (mapped 1:1 in `composer.json`) = the replatform layer (`repositories/ dto/ services/ contracts/ casters/ concerns/ enums/ exceptions/ factories/ forms/ helpers/ listeners/ resources/ seeders/ validators/`); its framework-agnostic interfaces/DTOs mostly live in `oe-shared/`, while `protected/` holds the Yii-side glue (AR-wrapping repositories, DTO mappers, Yii service impls). A single module dir can carry both eras. Full per-dir map → `subs/protected-tree.md`.

## Config

`OEConfig::getMergedConfig($env)` is the **only** assembler. Load order (later wins): `core/common.php` → `core/<env>.php` → `core/admin.php` → each active module's `config/common.php` + `config/<env>.php` (recursing sub-modules; `Oph*` modules also auto-import `models.*`) → `local/common.php` → `local/<env>.php` → `local/admin.php`. The active-module list is pre-scanned from the `modules` key in core + local only. Cached in APCu as `oe_merged_config_<env>`; `OE_CONFIG_TEST_RUNNING=1` bypasses the cache **read** but still re-stores; if an edit doesn't show up, `curl http://localhost/apc_clear.php` (a localhost-only HTTP endpoint — running `php apc_clear.php` from the CLI won't clear the web SAPI's cache).

## Modules

`protected/modules/<Name>/`. A module advertises itself in its **own** `config/common.php` (components/params/menus + nested `modules`); `local/common.php` (or Docker `modules.conf`) is only the on-switch; never edit `core/common.php`'s `$modules` list from a module install. `Oph*` modules auto-import `models.*`. Cross-module reads via `Yii::app()->moduleAPI->get('<Module>')` → `<Module>_API extends BaseAPI` — never reach into another module's models. (`CoreAPI` serves core/non-module patient data; it is a *sibling* of `BaseAPI`, instantiated directly via `new CoreAPI()`, **not** resolved through `moduleAPI`.) Domain events: the `event` component (`OEModule\OESysEvent\components\Manager`, a `Dispatcher`) fans `*SystemEvent`s out to listeners; subscribe via `event.observers` entries in a module's `config/common.php`, app-level listeners live in `protected/listeners/`. Clinical-event prefixes present in core: `OphCi` clinical investigation, `OphCo` communication/document/**letters** (`OphCoCorrespondence`), `OphTr` treatment, `OphIn` investigation result, `OphDr` drug, `OphOu` outcome, plus `OphGeneric` (catch-all). (`OphLe`/`OphLeEpatientletter` is external — not in a base checkout; core letters are `OphCoCorrespondence`.) Census → `subs/clinical-modules.md`; event/element model → `subs/event-element-model.md`; scaffolding → `create-oe-module`.

## Orientation

1. `/xapi/*` or `/l/*` → `oe-laravel/`. 2. Clinical event/element → `protected/modules/Oph*/`. 3. Cross-cutting for both frameworks → `oe-shared/`. 4. Otherwise core Yii in `protected/`.

Root-level `*.md` design notes are the accepted home for analysis docs — keep new ones there, not under `protected/`. DB schema → `c-oe-db-schema`; container runtime → `c-oe-components`; rules → `c-oe-coding-standards`.

Subs: `subs/protected-tree.md` (per-dir map + era key), `subs/event-element-model.md` (Patient→Episode→Event→Element spine, base classes, view triad, `et_` naming), `subs/cli-jobs.md` (yiic/artisan, the job-dispatch bridge, migrations/factories/seeders), `subs/clinical-modules.md` (module catalogue), `subs/examination-elements.md` (OphCiExamination element types), `subs/explore.md` (goal-keyed jump table), `subs/code-history.md` (git archaeology + release mapping — when code was introduced/deprecated and in which version: pickaxe `-S`/`-G`, creation migrations, `tag --contains`).
