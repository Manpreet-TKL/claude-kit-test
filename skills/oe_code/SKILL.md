---
name: oe_code
description: OpenEyes codebase — Yii 1.1 owns the bulk under protected/; Laravel 12 sidecar in oe-laravel/ owns only /xapi/* and /l/*; oe-shared/ holds framework-agnostic logic. Invoke explicitly for any work in ~/openeyes/ source. Volatile detail (clinical module catalogue, validator list) lives in subs/.
disable-model-invocation: true
---

# OpenEyes codebase shape

OpenEyes is event-based: every clinical interaction (examination, surgery, injection, laser, imaging investigation, letter, prescription, CVI certification, virtual clinic) is an "event" attached to an episode attached to a patient. Licence: **AGPL-3.0-only**.

> Clinical safety: never change persistence, calculations, units, or display of clinical values without an explicit ask. Never bypass `audit` writes. See `oe_coding_standards`.

## Three frameworks, one repo

```
/var/www/openeyes/
├── index.php             ← 30-line router: /xapi + /l/ → Laravel, else → Yii
├── index_yii.php
├── index_laravel.php
├── protected/            ← Yii 1.1 application root (the legacy bulk)
├── oe-laravel/           ← Laravel 12 sidecar
├── oe-shared/            ← Framework-agnostic shared logic
└── vendor/               ← Composer deps, shared by both frameworks
```

- **Yii owns everything except** `/xapi/*` and `/l/*`. There is no rewrite logic beyond `index.php`'s prefix check — don't bolt rewrite rules onto it.
- **Laravel is the growth area** for new HTTP APIs. ADR-12 makes Laravel the long-term replatform target. Prefer Laravel for greenfield; refactor Yii in place rather than mass-rewriting.
- **`oe-shared/`** is the home for cross-framework code. Contracts, DTOs, repositories, system-event abstractions all live here. New code that both frameworks need goes here, **not** in `protected/` and **not** in `oe-laravel/`.

Both frameworks share the same `vendor/` and resolve the same OEShared contracts through their respective DI containers.

## Entry points

- **Web (Yii)**: `index.php` → `index_yii.php` → `Yii::createWebApplication($config)->run()`. Config from `OEConfig::getMergedConfig('main')`.
- **Web (Laravel)**: `index.php` → `index_laravel.php` → `oe-laravel/bootstrap/app.php` → `->handleRequest(Request::capture())`. Sub-folder bootstrap is intentional; see `oe-laravel/README.md`.
- **CLI (Yii)**: `./protected/yiic <command> [args]`. Command class in `protected/commands/<Name>Command.php`. See `yiic-command-style` skill for the house style.
- **CLI (Laravel)**: `./oe-laravel/artisan <command>`. Used for Horizon, queue workers, Tinker.

## Configuration architecture

`OEConfig::getMergedConfig($environment)` is the **only** function that assembles config. Called from `main.php`, `console.php`, `admin.php`, `test.php`.

Load order (later overrides earlier):

1. `core/common.php`
2. `core/<environment>.php`
3. For each module listed so far: module's `config/common.php` then `config/<environment>.php`, recursively
4. `local/common.php`
5. `local/<environment>.php`

After first merge in a process, result is cached in **APCu** under `oe_merged_config_<env>`. Set `OE_CONFIG_TEST_RUNNING=1` to bypass. **If a config edit doesn't show up**, run `apc_clear.php` from the repo root.

## Module system

```
protected/modules/<Name>/
├── <Name>Module.php          # required; sets controllerMap/params
├── config/common.php         # merged into global config
├── controllers/, models/, components/, views/, widgets/
├── shortcodes/               # OphCo modules: letter shortcode handlers
├── migrations/, seeders/, factories/, tests/
├── dto/, enums/, contracts/, listeners/, exceptions/
```

Rules:

- A module advertises itself in its **own** `config/common.php`. `local/common.php` is **only** the on-switch.
- **Never edit `core/common.php` from a module install** — it is shared canonical config.
- Modules with names starting `Oph` auto-import their `models.*` path; don't repeat the `import`.
- Cross-module reads go through `Yii::app()->moduleAPI->get('<Module>')` → the module's `<Module>_API` class extending `BaseAPI`. **Never reach into another module's models directly.** `CoreAPI` plays the same role for non-module data.
- Need to scaffold a new module? Switch to the `create-oe-module` skill.

### Naming convention (Oph + two-letter category)

| Prefix | Category |
|---|---|
| `OphCi` | Clinical Investigation / encounter (examination, phasing, DNA) |
| `OphCo` | Communication / correspondence / document (letter, CVI, messaging, request form, doc, therapy app, checklist) |
| `OphTr` | Treatment (operation booking, op note, consent, laser, intravitreal injection) |
| `OphIn` | Investigation result (biometry, visual fields, lab results, genetic results, MEH PAC) |
| `OphDr` | Drug (prescription, PGD/PSD) |
| `OphLe` | Letter (e-patient letter) |
| `OphOu` | Outcome / patient-reported (CatProm5) |

## Repo layout (top level)

```
protected/        Yii app root (models/, modules/, controllers/, components/, services/,
                  repositories/, views/, widgets/, helpers/, enums/, dto/, contracts/,
                  factories/, listeners/, validators/, migrations/, commands/, tests/, config/)
oe-laravel/       Laravel 12 sidecar (app/, routes/, config/, database/, public/,
                  resources/, storage/, stubs/, tests/)
oe-shared/        Framework-agnostic (app/Contracts, app/DTOs, app/Repositories,
                  app/Services, app/Modules; helpers.php exposes oe_app())
shared/           JS/TS/CSS assets bundled by Vite
docs/             ADRs (architecture decision records)
playwright/       Playwright E2E tests; cypress.config.js for Cypress
phpstan.*.neon    Per-layer linting; see oe_coding_standards
apc_clear.php     Clear APCu config cache
```

Root-level `*.md` design notes (`PATIENT_SUMMARY_PERF_CHANGES.md`, `WORKLIST_PERF_ANALYSIS.md`, `CONTAINER_COMPONENTS.md`, …) are the accepted home for analysis docs. **Keep new design docs at the root**, not under `protected/`.

## Quick orientation when starting a task

1. Path under `/xapi/*` or `/l/*`? → `oe-laravel/`.
2. Clinical event / element? → a module under `protected/modules/Oph*/`.
3. Cross-cutting service both Yii and Laravel need? → `oe-shared/`.
4. Otherwise → core Yii in `protected/`.

For DB schema / domain model, switch to `oe_db_schema`. For container runtime (Apache / Horizon / Puppeteer / queues), switch to `oe_components`. For coding-standards rules, switch to `oe_coding_standards`.

## Where the volatile detail lives

- `subs/clinical-modules.md` — the current ~49-module catalogue, one line per module.
- `subs/examination-elements.md` — the ~59 `OphCiExamination` element types.
- `subs/explore.md` — "useful entry points when exploring" goal-keyed jump table.
