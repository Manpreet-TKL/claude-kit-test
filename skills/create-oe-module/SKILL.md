---
name: create-oe-module
description: Scaffold and register a new OpenEyes module under protected/modules/
---

# Creating an OpenEyes module

When loaded as context with no task, reply only `Context loaded.`

OpenEyes modules live under `protected/modules/<Name>/` and are loaded by `OEConfig::getMergedConfig()` (see `protected/config/OEConfig.php`). This skill covers the load-bearing pieces that aren't obvious from looking at one module in isolation: registration, the `oe_special_module` menu gate, APCu invalidation, and the cross-module migration runner.

For naming conventions (`Oph` + two-letter category like `Ci`, `Co`, `Tr`, `In`, `Dr`, `Le`, `Ou`), see CLAUDE.md §6.

---

## 1. Module directory layout

```
protected/modules/<Name>/
├── <Name>Module.php          # required — the module class
├── README.md                 # required — what it is, how to use it, its dependencies
├── docs/                     # module-owned design/format/contract docs (NOT the repo root)
├── config/
│   ├── common.php            # merged into global config (params, components, sub-modules)
│   └── <env>.php             # optional per-environment overrides (main/console/admin/test)
├── controllers/              # routed at /<Name>/<Controller>/<action>
├── models/                   # AR models — `Element_<Name>_<Foo>` for event-type elements
├── components/               # `<Name>_API.php` lives here for cross-module reads (BaseAPI)
├── resources/                # vendored, module-owned static assets (templates, filters, …)
├── views/                    # PHP views per controller
├── widgets/                  # form/display widgets
├── migrations/               # see §6
│   └── data/<migration_name>/NN_<table>.csv   # CSV seed data
├── seeders/                  # BaseSeeder classes (test data, used by Cypress/Playwright)
├── factories/                # Faker factories (`HasFactory` trait)
├── shortcodes/               # only for OphCo letter modules
└── tests/                    # unit/, functional/, feature/
```

**Modules are self-contained.** Everything needed to understand, use, and run a module
lives inside its own directory — never at the repo root. Two non-negotiables for a new
module:

- A **`README.md`** at the module root: what the module is, how to use it (UI + any
  `yiic` command), its runtime dependencies, and its configuration knobs.
- A **`docs/`** folder for any longer design notes, format/contract docs, or rebuild
  procedures. The repo-root `*.md` convention is for *core* analysis notes; a module's
  own docs belong under `protected/modules/<Name>/docs/`, and any vendored assets the
  module relies on belong under `protected/modules/<Name>/resources/` — so the module
  can be dropped into any OpenEyes container as one tree, with nothing to wire up
  elsewhere. (If the module depends on a tool or composer package that may be absent in
  some containers, probe for it and degrade gracefully rather than fataling — say so in
  the README.)

### `<Name>Module.php` — minimum class

**Utility module** (no event types):
```php
<?php
namespace OEModule\MyModule;

class MyModuleModule extends \CWebModule
{
    public $controllerNamespace = 'OEModule\\MyModule\\controllers';
}
```

**Event-type module** (extends `BaseEventTypeModule`):
```php
<?php
namespace OEModule\OphXxFoo;

use BaseEventTypeModule;

class OphXxFooModule extends BaseEventTypeModule
{
    public $controllerNamespace = '\OEModule\OphXxFoo\controllers';

    public function init()
    {
        $this->setImport([
            'OphXxFoo.models.*',
            'OphXxFoo.components.*',
        ]);
        parent::init();
    }
}
```

If you have a sub-module (e.g. an admin pane), declare it in `init()`:
```php
$this->setModules(['OphXxFooAdmin']);
```

### `config/common.php` — typical shape

```php
<?php
return [
    'params' => [
        'menu_bar_items' => [ /* see §5 */ ],
    ],
    'aliases' => [
        // 'OphXxFooAdmin' => 'OEModule.OphXxFoo.modules.OphXxFooAdmin',
    ],
    'modules' => [ /* sub-modules, if any */ ],
    'components' => [
        // optional: register listeners on the event manager,
        // bind contracts in the OEShared container, etc.
        'event' => [
            'observers' => [
                // [ 'system_event' => SomeSystemEvent::class, 'listener' => SomeListener::class ],
            ],
        ],
        'container' => [
            'bindings' => [ /* Contract::class => Impl::class */ ],
            'singletons' => [],
        ],
    ],
];
```

The Yii prefix-based autoload means: any module whose name starts with `Oph` gets its `models.*` path auto-imported by `OEConfig` — you don't have to list it again in `import`. Other modules (`Diagnoses`, `FileStorage`, etc.) need to declare imports themselves if they want models autoloaded.

---

## 2. Registering the module in `core/common.php`

Add the module to the `$modules` array in `protected/config/core/common.php` (around line 1161). Two valid forms:

```php
// Simple (Yii infers class from path — works when the module class is in protected/modules/<Name>/<Name>Module.php and uses no namespace, OR is plain camel-case discoverable):
'OphCoCorrespondence',

// Explicit with class FQCN (required when the module lives under a PSR-4 namespace like OEModule\X):
'OphXxFoo' => ['class' => \OEModule\OphXxFoo\OphXxFooModule::class],
```

Almost every modern module uses the explicit form. Use the simple form only if you're matching the convention of older clinical modules (`Api`, `eyedraw`, `Mirth`, `oldadmin`).

Pattern for dev-only modules — wrap in an env check, like `TestHelper`:
```php
if (strtolower(getenv('OE_MODE')) !== 'live') {
    $modules['TestHelper'] = ['class' => TestHelperModule::class];
}
```

### Docker deployments: `/config/modules.conf`

If the module is deployment-specific, it can be added without touching core by mounting `/config/modules.conf` on the container (see `core/common.php` lines 1222–1242). Format:
```
modules=(MyModule=OEDeployment\MyModule\MyModuleModule OtherModule)
```
This is the right escape hatch for site-local modules — don't edit core/common.php for one trust's bespoke module.

---

## 3. Testing locally with `local/common.php`

`protected/config/local/common.php` is the **last** layer merged, so anything you put there wins. Use it to develop a new module without touching `core/common.php`:

```php
<?php
return [
    'modules' => [
        'MyNewModule',                              // simple form
        // 'OphXxFoo' => ['class' => \OEModule\OphXxFoo\OphXxFooModule::class],
    ],
    'params' => [ /* feature-flag overrides */ ],
];
```

`local/common.php` is **not** in VCS by default — copy from `protected/config/local.sample/` to start. The file ships in some checkouts already (see `protected/config/local/common.php`), and the existing one does menu-bar suppression (see §4); preserve that logic if you edit it.

Once the module is stable, move the registration into `core/common.php` so it ships with the codebase.

---

## 4. `oe_special_module` — making your menu items visible

This is the gotcha that catches new modules: **by default, your `menu_bar_items` will be invisible.**

`protected/config/local/common.php` runs after all module configs and suppresses every menu item it can find — both core menu keys and every key in every module's `params.menu_bar_items` — by injecting an impossible `requires_setting` into them. It only leaves alone modules that have explicitly opted in:

```php
// protected/modules/MyModule/config/common.php
return [
    'params' => [
        'oe_special_module' => true,        // <-- the opt-in
        'menu_bar_items' => [
            'my-thing' => [
                'title'      => 'My Thing',
                'uri'        => '/MyModule/default/index',
                'restricted' => ['OprnInstitutionAdmin'],
            ],
        ],
    ],
];
```

**Use `oe_special_module` only for admin/infrastructure modules** (existing examples: `OeMerge`, `OeConfig`, `OeDataDictionary`, `OeDocumentation`). For clinical modules, the suppression is intentional — clinical entry points appear on the patient summary / pathway, not in the top nav.

The suppression code is in `protected/config/local/common.php` (lines 22–55). It scans both `modules/*/config/common.php` and one level of sub-module configs (`modules/*/modules/*/config/common.php`). When debugging "my menu item doesn't show up," read that file first.

Special modules share a consistent landing-page UI (canonical ribbon, full page width, hidden patient/hotlist panel, cache-busted module CSS) — see `subs/special-module-ui.md` for the recipe, and the `oe-ui` skill for the core CSS mechanics behind it.

---

## 5. Menu bar item shape

Used in core (`core/common.php` lines ~628–714) and inside any module's `params.menu_bar_items`:

```php
'menu_bar_items' => [
    '<unique_key>' => [
        'title'            => 'Visible label',
        'alt_title'        => 'Toggle label',                  // optional, for toggleable items
        'uri'              => '/Controller/action',            // or 'Module/controller/action'
        'position'         => 99,                              // optional, higher = further right
        'restricted'       => ['OprnFoo', 'TaskBar'],          // RBAC: any-of these auth items
        'requires_setting' => ['setting_key' => 'feature_x',   // optional setting gate
                               'required_value' => 'on'],
    ],
],
```

`restricted` entries map to `authitem` rows (RBAC). If the user has any of the listed `Oprn*`/`Task*`/role names, the item shows. If the module is gated by a new permission, add the `authitem` row in a module migration:

```php
$this->insert('authitem', [
    'name' => 'OprnMyModuleAccess', 'type' => 0, 'bizrule' => null,
]);
$this->insert('authitemchild', [
    'parent' => 'TaskMyModule', 'child' => 'OprnMyModuleAccess',
]);
```

---

## 6. Migrations — core vs module ordering

OpenEyes has a custom `OEMigrateCommand` (`protected/commands/OEMigrateCommand.php`) that interleaves core migrations and every module's migrations into a single chronologically-sorted run.

### Where they live
- **Core**: `protected/migrations/m<YYMMDD>_<HHMMSS>_*.php`
- **Module**: `protected/modules/<Name>/migrations/m<YYMMDD>_<HHMMSS>_*.php`

Every migration filename starts with a Yii timestamp prefix `mYYMMDD_HHMMSS_` (e.g. `m130913_000006_consolidation_for_ophciphasing`).

### How the runner orders them

`OEMigrateCommand::getMigrationPaths()` builds the path list as:

```
[ protected/migrations,
  protected/modules/<module1>/migrations,
  protected/modules/<module2>/migrations,
  ... (one per active module, in the order they appear in $modules) ]
```

`getNewMigrations()` collects pending migrations from every path, then **sorts the combined list alphabetically by filename** (`usort` on `migration` field). Because the prefix is `m<YYMMDD>_<HHMMSS>`, alphabetic == chronological. So:

> All pending migrations across core and every module run in a single timestamp-sorted sequence. A module migration from 2018 will run before a core migration from 2020.

This is what `yiic migrate --all` does. Without `--all` it falls through to the parent `MigrateCommand` and runs migrations from a single `migrationPath` only (legacy behaviour).

### Practical consequences
- **One `tbl_migration` table tracks them all.** Core and module migrations share the same applied-migrations log.
- **Timestamp your new migration accurately.** If you backdate it before an existing core migration that creates a table you depend on, the runner will try to run your migration first and fail.
- **Cross-module foreign keys are fragile.** If your module's migration references a table from another module, your timestamp must be later than the other module's table-creation migration.
- **Module disable doesn't roll back migrations.** Removing a module from `$modules` makes its migrations vanish from the `--all` discovery pass, but the applied rows stay in `tbl_migration`. To truly back out, run `yiic migrate down` against that path first.

### Base class

Module migrations should extend `OEMigration` (not `CDbMigration` directly) so you get helpers like `insertOEEventType()`, `insertOEElementType()`, and CSV-driven `initialiseData()`:

```php
class m260518_120000_create_my_module_tables extends OEMigration
{
    public function up()
    {
        $event_type_id = $this->insertOEEventType('My Event', 'OphXxFoo', 'Xx');
        $this->insertOEElementType([
            ['name' => 'My Element', 'class_name' => 'Element_OphXxFoo_MyElement', ...],
        ], $event_type_id);
        // ... createTable calls ...
    }
}
```

CSV seed data goes in `migrations/data/<migration_class_name>/NN_<table>.csv` and is loaded by `initialiseData()`.

---

## 7. APCu — your module isn't appearing, here's why

`OEConfig::getMergedConfig($environment)` caches the assembled config in APCu under the key `oe_merged_config_<environment>` (see `protected/config/OEConfig.php` lines 46–47 and 111). The cache is **per-environment** (`main`, `console`, `admin`, `test`) and persists across requests.

So when you edit a config file (`core/common.php`, `local/common.php`, or any module `config/common.php`) and nothing changes in the browser — APCu is serving you stale config.

### Three ways to clear it

1. **Hit `apc_clear.php`** in a browser from localhost only:
   ```
   curl http://localhost/apc_clear.php
   ```
   Returns `✅ success`. Blocked for non-loopback requesters (returns 403).

2. **Restart PHP-FPM** (clears the whole APCu opcode + user cache):
   ```
   sudo systemctl restart php8.4-fpm   # or whatever your fpm pool is called
   ```

3. **Bypass APCu entirely** by setting an env var on the request:
   ```
   OE_CONFIG_TEST_RUNNING=1
   ```
   This is what the test suite uses (PHPUnit sets it in `phpunit*.xml`). Useful in development if you're iterating on config — set it in your `.env` or fpm pool config and you'll never hit cached config again at the cost of re-merging on every request.

`yiilite.php` (the bytecode-optimised Yii bundle used in production when `OE_FORCE_YIILITE=true` or non-debug+APCu) is also cached — see `index_yii.php`. A full FPM restart catches both.

---

## 8. Don't forget

- **Module API**: if other modules need to read from yours, add `protected/modules/<Name>/components/<Name>_API.php extends BaseAPI`. Consumers resolve it via `Yii::app()->moduleAPI->get('<Name>')`. Never reach into another module's models directly.
- **OEShared bindings**: if your module exposes a framework-agnostic contract, put the interface in `oe-shared/app/Modules/<Name>/Contracts/` and bind the Yii impl in your module's `config/common.php` `components.container.bindings` block (Laravel binds the same contract on its side).
- **Static analysis**: your new module is under `protected/` so it's covered by `phpstan.yii.neon` / `phpcs.yii.xml` / `rector.yii.php` — not the Laravel or shared configs.
- **OEMigrate after registration**: after adding the module to `$modules` and clearing APCu, run `./protected/yiic migrate --all` to apply its migrations.

---

## End-to-end checklist for a new module `OphXxFoo`

1. `mkdir -p protected/modules/OphXxFoo/{config,controllers,models,migrations,views,components,docs}`
2. Write `OphXxFooModule.php` (event-type → `BaseEventTypeModule`; otherwise `CWebModule`).
3. Write a `README.md` at the module root (what it is, usage, dependencies, config) and put any longer design/format docs under `docs/`. Keep the module self-contained — its docs and any vendored assets live inside the module, not at the repo root.
4. Write `config/common.php` (params, components, sub-modules as needed).
5. Add the explicit-class entry to `$modules` in `protected/config/core/common.php` (or `local/common.php` for testing).
6. If you need a top-nav entry: add `params.menu_bar_items` AND set `params.oe_special_module = true` — but only if this is an admin/infra tool. Clinical modules don't. Build the landing page per `subs/special-module-ui.md`.
7. Write a timestamped migration in `protected/modules/OphXxFoo/migrations/` that creates tables, inserts the `event_type` and `element_type` rows (event-type modules), and any `authitem` permissions.
8. Clear APCu: `curl http://localhost/apc_clear.php`.
9. Run `./protected/yiic migrate --all`.
10. Add a `<Name>_API.php` in `components/` if other modules need to read from yours.
11. PHPStan/PHPCS the new files against the **yii** configs (`phpstan.yii.neon`, `phpcs.yii.xml`).
