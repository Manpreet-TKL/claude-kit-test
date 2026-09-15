# OpenEyes knowledge tree

A consolidated, verified map of the OpenEyes codebase (~14.6k files), built to feed
the `c-oe-code` / `c-oe-ui` skills. Every claim here was checked against the working
checkout (file counts, `grep`, `composer.json` PSR-4 map, `index.php`, `OEConfig`,
`AssetManager`) in June 2026. Where a fact depends on a built/deployed instance
(nxblu CSS, eyedraw, special modules), that is called out.

Licence: AGPL-3.0-only. Domain: ophthalmology EHR — event-based clinical record.

---

## 1. Three frameworks, one repo

`index.php` (verified **30 lines**) is a pure router:

- path starts `/xapi` or `/l/` → `index_laravel.php` → **Laravel 12** in `oe-laravel/`
  - `/xapi` = the live API prefix (routes in `oe-laravel/routes/api.php`,
    controllers `oe-laravel/app/Http/Controllers/Xapi/`).
  - `/l/` = a **reserved** web prefix; nothing registered on it yet.
- everything else → `index_yii.php` → **Yii 1.1** in `protected/` (the legacy bulk).

Three PHP codebases, one repo, one root `vendor/`:

| Tree | Framework | Namespace | Role |
|---|---|---|---|
| `protected/` | Yii 1.1 | global + `OE\<dir>\` | the app: clinical modules, models, controllers, the replatform glue |
| `oe-laravel/` | Laravel 12 | `OELaravel\` = `oe-laravel/app` | growth area; new HTTP APIs (ADR-12) |
| `oe-shared/` | framework-agnostic | `OEShared\` = `oe-shared/app` | cross-framework code: `Contracts/ DTOs/ Repositories/ Services/ Enums/ Jobs/ Modules/ Exceptions/` |

- **`oe-shared/` vs root `shared/`** — different things. `oe-shared/` is shared PHP.
  Root `shared/` is just static AssetManager media (`shared/img/ajax-loader.gif`).
- **DI** — both frameworks resolve the same `OEShared\Contracts\…`. Yii uses a
  bespoke PSR-11 `YiiContainer` (the `container` component, bound in
  `config/core/common.php`); Laravel uses the native Illuminate container. An
  `oe_app()` helper returns whichever app is live.
- **Rule of thumb** — new cross-framework code → `oe-shared/`; new HTTP API →
  `oe-laravel/`; refactor Yii **in place**, don't mass-rewrite. Don't add rewrite
  rules to `index.php`.

---

## 2. The `protected/` tree — era key

The fastest way to date code is the **namespace**.

- **Legacy Yii 1.1** = global namespace, `C*`/`Base*` base classes. Dirs:
  `components/ controllers/ models/ widgets/ behaviors/ commands/ migrations/
  extensions/ views/ config/ modules/ cli_commands/`.
- **Replatform** = PSR-4 `OE\<dir>\`, mapped 1:1 in `composer.json`. Dirs:
  `repositories/ dto/ services/ contracts/ casters/ concerns/ enums/ exceptions/
  factories/ forms/ helpers/ listeners/ resources/ seeders/ validators/`.

The replatform's framework-agnostic interfaces/DTOs mostly live in `oe-shared/`;
`protected/`'s `OE\…` dirs hold the **Yii-side glue** — repositories wrapping
ActiveRecord (`PatientRepository extends BaseActiveRecordRepository implements
PatientRepositoryContract`), DTO mappers (`dto/mappers/PatientMapper`), Yii service
impls (`AuditService implements AuditServiceContract`), casters, typed enums/exceptions.

Full verified subdir list (37): `assets behaviors casters cli_commands commands
components concerns config contracts controllers data dto enums exceptions
extensions factories forms helpers javamodules listeners migrations models modules
quarantined_placeholder_files repositories resources runtime scripts seeders
services tests validators vendors views widgets` (+ `docs`).

Gotcha: `composer.json` maps `OE\SystemEvents\` → `protected/system_events`, but
that dir doesn't exist here — system-event classes resolve from the `OESysEvent`
module / `oe-shared`.

Support dirs: `javamodules/` (compiled Java IOLMaster importer, run only by the
file_watcher daemon), `data/` (seed xlsx/csv), `scripts/` (host shell wrappers),
`quarantined_placeholder_files/` (ClamAV substitute media), `tests/` (PHPUnit/Codeception).

---

## 3. Config assembly

`OEConfig::getMergedConfig($env)` is the **only** assembler.

Load order (later wins):
```
core/common.php → core/<env>.php → core/admin.php
  → [for each active module] config/common.php → config/<env>.php   (recursing sub-modules;
                                                                      Oph* also import models.*)
  → local/common.php → local/<env>.php → local/admin.php
```
- The active-module list is pre-scanned from the `modules` key in **core + local
  only** (so a module can't add itself to the scan from inside its own config).
- Cache: APCu key `oe_merged_config_<env>`. `OE_CONFIG_TEST_RUNNING=1` bypasses the
  cache **read** but still re-stores.
- Clearing: `curl http://localhost/apc_clear.php` — a **localhost-only HTTP**
  endpoint. Running `php apc_clear.php` from the CLI won't clear the web SAPI's APCu.

---

## 4. Modules & the module API

- Layout: `protected/modules/<Name>/` — each self-contained (`models/ controllers/
  views/ widgets/ components/ config/ migrations/ assets/`), and may carry both eras
  (e.g. `Referral/` has legacy `models/` + replatform `dto/ repositories/ factories/
  seeders/`).
- A module advertises itself in its **own** `config/common.php` (components, params,
  menus, nested `modules`). `local/common.php` / Docker `modules.conf` is just the
  on-switch. Never edit `core/common.php`'s `$modules` from a module install.
- Cross-module reads: `Yii::app()->moduleAPI->get('<Module>')` → `<Module>_API
  extends BaseAPI`. Never reach into another module's models.
- **`CoreAPI`** serves core/non-module patient data. It is a **sibling** of
  `BaseAPI` (uses the `InteractsWithApp` trait), instantiated via `new CoreAPI()`,
  **not** resolved through `moduleAPI`.
- `moduleAPI` component registered at `config/core/common.php` (the `moduleAPI` key).

### Clinical-event prefixes (verified present in core)

`OphCi` clinical investigation (3: Examination, Phasing, DidNotAttend) · `OphCo`
communication/document/**letters** (7, incl. `OphCoCorrespondence`) · `OphTr`
treatment/surgery (6) · `OphIn` investigation result (6) · `OphDr` drug (2) ·
`OphOu` outcome (1) · `OphGeneric` catch-all.

**No `OphLe*` dir exists in core** — `OphLeEpatientletter` is external; core letters
are `OphCoCorrespondence`. Other external/site-specific modules absent from a base
checkout: `eyedraw`, `mehstaffdb`, `OphInMehPac`.

### Domain events

The `event` component is `OEModule\OESysEvent\components\Manager` (implements
`Dispatcher`). It fans `*SystemEvent` objects out to listeners. Two subscription
routes:
- Module-scoped: `event.observers` `['system_event'=>…, 'listener'=>…]` entries in a
  module's `config/common.php`.
- App-level: 5 invokable listeners in `protected/listeners/` (`OE\listeners\…`),
  e.g. `RemoveDraftEventAfterSoftDelete`, `UpdatePatientMedicationLinksAfterEventSave`.

`EventSupport` is a **separate** utility module — NOT the dispatcher.

---

## 5. The event/element domain model

Spine: **`Patient → Episode → Event → EventType → ElementType → Element`**.

- `Patient` HAS_MANY `Episode`; `Episode` BELONGS_TO `Patient`, HAS_MANY `Event`
  ordered by `event_date`.
- `Event` BELONGS_TO `Episode` + `EventType`, and has **no element columns** — it
  discovers elements at runtime: walk `eventType->getAllElementTypes()`, load each
  `ElementType.class_name`, `findAll('event_id = ?')`. `Event::getElements()`.
- `EventType` (`event_type` table): one row ≈ one module; `class_name` = module
  folder; HAS_MANY `ElementType`; `getApi()` resolves the module API.
- `ElementType` (`element_type`): one row ≈ one element model; holds `class_name`,
  `display_order`, `default`, `required`, `element_group_id`; `getInstance()` =
  `new $this->class_name()`. (Dummy `id=0` row filtered — MariaDB NULL-unique hack.)
- **`element_type` rows are created by migrations/seeders, not module config.** New
  event = `EventType::getDefaultElements()` (`default=1`, by `display_order`);
  existing event = `Event::getElements()`.

### Base-class chain

`CActiveRecord → BaseActiveRecord → BaseActiveRecordVersioned → BaseElement →
BaseEventTypeElement`. (`BaseActiveRecordVersioned` = audited + soft-deleted; a
`*_version` shadow table; `deleted=0` default scope.) Elements extend
`BaseEventTypeElement` **directly or via a module-local base** (OphTrOperationnote:
`Element_OpNote`, `Element_OnDemand`, `Element_OnDemandEye`).

### `et_` table naming

`tableName()` = `et_` + lowercased module + `_` + element:
`Element_OphCiExamination_VisualAcuity` → `et_ophciexamination_visualacuity`.

### The two render triads (UI)

1. **Legacy prefix triad** in `modules/<M>/views/default/`:
   `form_<Class>.php` / `view_<Class>.php` / `print_<Class>.php`. Verified file
   counts for OphCiExamination: **86 form_, 69 view_, 8 print_**. Resolved by
   `BaseEventTypeElement::getForm_View()/getView_view()/getPrint_view()`; print falls
   back to view (so print_ is sparse).
2. **Widget triad**: `modules/<M>/widgets/views/<Name>_event_edit.php` / `_event_view.php`
   / `_event_print.php`, backed by `BaseEventElementWidget`. Verified **72
   `_event_edit`** in OphCiExamination.

Both wrapped by `//patient/element_container_{form,view,print}.php`.

> The suffix `_form.php`/`_view.php` (leading underscore) files are unrelated **Gii
> CRUD admin** scaffolding under `…Admin/views/` — not element views.

Soft-delete only for clinical data; never bypass `audit`; never change persistence /
calculations / units / display of clinical values without an explicit ask.

---

## 6. CLI, jobs, migrations, factories, seeders

### Two CLIs
- `./protected/yiic <cmd>` — Yii console, boots the **same** merged config as web
  (`config/console.php`).
- `./oe-laravel/artisan` — Laravel (Horizon, queues, Tinker). Horizon/Tinker deps
  are in the **root** composer.json; `oe-laravel/composer.json` is a namespace stub.

### `commands/` vs `cli_commands/`
- `protected/commands/` — ~58 `CConsoleCommand`, run `./yiic <name>`. The bootstrap
  also registers `modules/<X>/commands/*Command.php`.
- `protected/cli_commands/` — **not** yiic. Only `file_watcher/`: a standalone DICOM
  importer daemon, **raw mysqli** (no Yii), `while(true)`, shells out to the Java
  importer in `protected/javamodules/IOLMasterImport/` (`OE_IOLMasterImport.jar`).
  Run `php runFileWatcher.php`. Feeds `OphInBiometry`.

### Job-dispatch bridge (one contract, two front-ends)
Job classes in `oe-shared/app/.../Jobs` (base `AsyncBaseJob`, `tries()=3`,
`backoff()=[60,300,900]`). One contract `OEShared\Contracts\Jobs\JobDispatcher`:
- Yii `protected/components/JobDispatcher.php` (`AsyncJobDispatcher` /
  `SyncJobDispatcher`) — async path writes a **Laravel-format** payload
  (`Illuminate\Queue\CallQueuedHandler@call`, `command => serialize($job)`) into the
  `jobs` table.
- Laravel `oe-laravel/app/Components/JobDispatcher.php` — Illuminate `Bus`.
A Laravel `queue:work` / Horizon worker executes either way. One `jobs` table
(default `database` connection; Horizon on `redis`).

### Migrations — 3 locations, 2 runners
- Core Yii: `protected/migrations/` (~738), `OEMigration` (CSV from `migrations/data/`),
  `./yiic migrate`, table `tbl_migration`.
- Module Yii: `modules/<M>/migrations/`, `./yiic migratemodules`. (`deploy` module →
  `tbl_migration_deploy`.)
- Laravel: `oe-laravel/database/migrations/` — only the `jobs`/`failed_jobs` tables,
  `artisan migrate`.

### Factories & seeders
- Factories: Yii `protected/factories/` (`ModelFactory` + ~165 in `factories/models/`)
  and Laravel `oe-laravel/database/factories/` — separate systems.
- Seeders: **Yii-only** `protected/seeders/` (`BaseSeeder`, `SeederBuilder`), driven
  by `./yiic seeder` to build whole clinical events. No Laravel seeders.

---

## 7. Frontend — modern build

- Root build: `package.json` + `vite.config.js`, **Vue 3.5 + Vite 7, NO Tailwind**.
- Entry: `protected/assets/js/vue/main.js` (one app that hydrates mount points).
- Components: `.vue` SFCs in **module** `assets/` dirs (Diagnoses, Referral, …),
  not the root.
- Output: `protected/assets/vue/dist/` + `assets/vue/.vite/manifest.json`.
- **Cache-bust seam**: `AssetManager::urlForManifestFile()` (line ~302) reads
  `getManifest()` (~309) → resolves the content-hashed filename. So Vue assets are
  busted by **content hash, no `?v=`**.
- **Tailwind v4 (config-less) is `oe-laravel`-ONLY** (its own package.json/Vite).
  Never put Tailwind classes in Yii views or root Vue SFCs.

### Legacy asset pipeline (still the majority)
- `Yii::app()->assetManager->publish(<dir>)` → `/assets/<hash>/…` (symlink under
  `YII_DEBUG`, copy in prod), then `clientScript->registerCssFile($url . '?v=' .
  filemtime(...))` (~256) / `registerScriptFile` (~290).
- nginx serves `/assets/...` `Cache-Control: max-age=31536000` — **always** append
  `?v=<filemtime>` or browsers cache stale for a year.
- **Two regimes coexist**: legacy `?v=filemtime` vs modern Vite manifest hash. Don't
  cross them.

### JS toolkit (`OpenEyes.UI.*`)
Hand-rolled jQuery-era namespace (source `protected/assets/js/src/`,
`assets/js/openeyes/`). `js-` class prefix = **behaviour hook, never style hook**.
Key widgets: `AdderDialog` (the "+ Add" picker, the most common clinical
interaction), `ElementController`(+`.MultiRow`) (wires element fields to AdderDialogs
via `data-adder-*`/`data-ec-*`), `CollapseData`, `NavBtnPopup`/HotList, `Dialog.*`,
`Tooltip`, `EpisodeSidebar`, `Search`. Instantiated in an inline `<script>` at the
end of a view.
- **EyeDraw** is a PHP **widget** (`application.modules.eyedraw.OEEyeDrawWidget`),
  JS runtime `protected/assets/js/eyedraw/EyeDrawManager.js`; `eyedraw` module is
  external. Serialises a canvas doodle to a hidden input.
- **TinyMCE** via `registerCoreScript('tinymce')`; output in `.user-tinymce-content`
  (letters, HTML settings).

---

## 8. UI / page chrome (Yii side)

- **CSS lives in `protected/assets/nxblu/dist/css/style_openeyes.css`** — minified
  one-liner; grep with `-o`. `nxblu/` is a **git submodule** (`git@github.com:openeyes/nxblu`),
  uninitialised in a bare checkout — `dist/css` only exists on a built/deployed
  instance. Verified values were read off a deployed instance.
- **Theming**: CSS variables (`--bg-title`, `--txt-light`, `--bg-main`, …) keyed off
  a `theme-<dark|light>` class on `<html>`. Two-stage: `main.php` emits server-side
  preference as `data-theme` (from `SettingMetadata::getSetting('display_theme')`),
  then client JS adds the `theme-<light|dark>` class the CSS targets. Write CSS
  against `.theme-dark`/`.theme-light`, not `[data-theme]`.
- **Chassis**: `body.open-eyes.oe-grid` CSS grid, named areas. `main.php` owns the
  chrome (brand/header/footer/hotlist); the action's view supplies the
  `.oe-full-header` (ribbon, `grid-area: pageheader`) + `.oe-full-content`
  (`grid-area: main`) markup, injected at `echo $content`.
- **Ribbon** `.oe-full-header`: dark `var(--bg-title)`, `justify-content:flex-start`;
  title `.title.wordcaps`; buttons auto `height:38px; padding:0 16px`.
- **Flex gotcha**: `.flex-layout` = space-between + center — with 3 children it
  centers the middle. `.flex-left` = flex-start.
- **Width cap**: ≥1890px core caps the content selectors to `width:1440px`; pinned
  hotlist takes `calc(100vw - 1440px)`. Add `use-full-screen` to span fully.
- **Hotlist**: render chain `_header.php → _form.php → _menu_option_hotlist.php`
  (`li.js-hotlist-panel-wrapper`, `data-fixable="<?= $this->fixedHotlist ?>"`) →
  `//base/_hotlist`. `BaseController::$fixedHotlist=true` default; `NavBtnPopup`
  auto-pins on wide windows. Hide via CSS on `.oe-hotlist-panel,
  .js-hotlist-panel-wrapper`.
- **Clinical element views** are the part clinicians use — see §5 render triads +
  the JS toolkit §7.
- **Exemplar landing-page modules** (special/admin, deployment add-ons, not core):
  `OeDataDictionary`, `OeConfig`, `NodAudit`, `OeDatabase`.

---

## Verification notes

- `index.php` = 30 lines; `OphCiExamination/views/default/` = 86 `form_`, 69 `view_`,
  8 `print_`; widgets/views = 72 `_event_edit`.
- No `OphLe*` dir; `.gitignore` whitelists core modules under `protected/modules/*`.
- `nxblu` is an uninitialised submodule; `nxblu/dist` absent in bare checkout.
- `protected/` 37-subdir list captured; `Referral` carries the full replatform stack.
- `AssetManager.php`: `registerCssFile` ~256, `registerScriptFile` ~290,
  `urlForManifestFile` ~302, `getManifest` ~309.
- `OEConfig.php`: APCu gate ~46, `admin.php` layer ~64–65, `apcu_store` ~111.
- `moduleAPI` registered in `config/core/common.php`.
- `OE\…` PSR-4 dirs mapped 1:1 in `composer.json`.

Anthropic-only: this tree was built entirely with Claude Code's own tools — no
third-party indexing/embedding service.
