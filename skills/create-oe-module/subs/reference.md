# create-oe-module - skeletons and snippets

## Directory layout

```
protected/modules/<Name>/
├── <Name>Module.php          # required - the module class
├── config/
│   ├── common.php            # merged into global config (params, components, sub-modules)
│   └── <env>.php             # optional per-environment overrides (main/console/admin/test)
├── controllers/              # routed at /<Name>/<Controller>/<action>
├── models/                   # AR models - `Element_<Name>_<Foo>` for event-type elements
├── components/               # `<Name>_API.php` for cross-module reads (BaseAPI)
├── views/, widgets/
├── migrations/
│   └── data/<migration_name>/NN_<table>.csv   # CSV seed data
├── seeders/                  # BaseSeeder classes (Cypress/Playwright test data)
├── factories/                # Faker factories (HasFactory trait)
├── shortcodes/               # only for OphCo letter modules
└── tests/                    # unit/, functional/, feature/
```

## Module class skeletons

Utility module (no event types):

```php
<?php
namespace OEModule\MyModule;

class MyModuleModule extends \CWebModule
{
    public $controllerNamespace = 'OEModule\\MyModule\\controllers';
}
```

Event-type module:

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

Sub-modules (e.g. an admin pane): `$this->setModules(['OphXxFooAdmin']);` in `init()`.

## config/common.php shape

```php
<?php
return [
    'params' => [
        'menu_bar_items' => [ /* see below */ ],
    ],
    'aliases' => [
        // 'OphXxFooAdmin' => 'OEModule.OphXxFoo.modules.OphXxFooAdmin',
    ],
    'modules' => [ /* sub-modules */ ],
    'components' => [
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

## Registration forms (`$modules` in core/common.php, ~line 1161)

```php
// Simple - only when matching older modules (Api, eyedraw, Mirth, oldadmin):
'OphCoCorrespondence',

// Explicit FQCN - what every modern module uses:
'OphXxFoo' => ['class' => \OEModule\OphXxFoo\OphXxFooModule::class],

// Dev-only modules - env-gate like TestHelper:
if (strtolower(getenv('OE_MODE')) !== 'live') {
    $modules['TestHelper'] = ['class' => TestHelperModule::class];
}
```

Docker escape hatch for site-local modules - mount `/config/modules.conf` (handled in core/common.php lines 1222-1242):

```
modules=(MyModule=OEDeployment\MyModule\MyModuleModule OtherModule)
```

`local/common.php` is not in VCS by default - copy from `protected/config/local.sample/`. The shipped one does the menu-bar suppression (lines 22-55); preserve that logic if you edit it.

## oe_special_module + menu items

```php
// protected/modules/MyModule/config/common.php
return [
    'params' => [
        'oe_special_module' => true,        // the opt-in - admin/infra modules only
        'menu_bar_items' => [
            'my-thing' => [
                'title'            => 'My Thing',
                'alt_title'        => 'Toggle label',                // optional
                'uri'              => '/MyModule/default/index',
                'position'         => 99,                            // higher = further right
                'restricted'       => ['OprnInstitutionAdmin'],      // RBAC: any-of
                'requires_setting' => ['setting_key' => 'feature_x',
                                       'required_value' => 'on'],    // optional gate
            ],
        ],
    ],
];
```

New permission rows go in a module migration:

```php
$this->insert('authitem', ['name' => 'OprnMyModuleAccess', 'type' => 0, 'bizrule' => null]);
$this->insert('authitemchild', ['parent' => 'TaskMyModule', 'child' => 'OprnMyModuleAccess']);
```

## Migration runner detail

`OEMigrateCommand::getMigrationPaths()` = `protected/migrations` + one path per active module (in `$modules` order); `getNewMigrations()` sorts the combined pending list alphabetically by filename - `m<YYMMDD>_<HHMMSS>` prefix makes alphabetic == chronological. `yiic migrate --all` runs that single interleaved sequence; without `--all` it's legacy single-path. One shared `tbl_migration`. To truly back a module out, `yiic migrate down` against its path before removing it from `$modules`.

Migration base-class example:

```php
class m260518_120000_create_my_module_tables extends OEMigration
{
    public function up()
    {
        $event_type_id = $this->insertOEEventType('My Event', 'OphXxFoo', 'Xx');
        $this->insertOEElementType([
            ['name' => 'My Element', 'class_name' => 'Element_OphXxFoo_MyElement', /* ... */],
        ], $event_type_id);
        // ... createTable calls ...
    }
}
```

CSV seed data: `migrations/data/<migration_class_name>/NN_<table>.csv`, loaded by `initialiseData()`.

## APCu - three ways to clear

1. `curl http://localhost/apc_clear.php` - returns `✅ success`; 403 for non-loopback.
2. `sudo systemctl restart php8.4-fpm` - clears the whole APCu opcode + user cache (also catches the `yiilite.php` cache).
3. `OE_CONFIG_TEST_RUNNING=1` - bypass entirely (what PHPUnit sets); re-merges every request.

Cache key: `oe_merged_config_<environment>` per env (`main`/`console`/`admin`/`test`), set in `protected/config/OEConfig.php` (~lines 46-47, 111).

## End-to-end checklist for OphXxFoo

1. `mkdir -p protected/modules/OphXxFoo/{config,controllers,models,migrations,views,components}`
2. Write `OphXxFooModule.php` (event-type -> `BaseEventTypeModule`; otherwise `CWebModule`).
3. Write `config/common.php`.
4. Add the explicit-class entry to `$modules` in `core/common.php` (or `local/common.php` for testing).
5. Top-nav entry? `params.menu_bar_items` AND `params.oe_special_module = true` - admin/infra tools only; clinical modules don't.
6. Timestamped migration: tables + `event_type`/`element_type` rows + `authitem` permissions.
7. Clear APCu: `curl http://localhost/apc_clear.php`.
8. `./protected/yiic migrate --all`.
9. `<Name>_API.php` in `components/` if other modules read from yours.
10. PHPStan/PHPCS against the **yii** configs.
