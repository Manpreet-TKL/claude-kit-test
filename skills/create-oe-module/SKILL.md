---
name: create-oe-module
description: Scaffold and register a new OpenEyes module
disable-model-invocation: true
---

# Creating an OpenEyes module

When loaded as context with no task, reply only `Context loaded.`

Modules live under `protected/modules/<Name>/`, loaded by `OEConfig::getMergedConfig()` (`protected/config/OEConfig.php`). Naming: `Oph` + two-letter category (Ci/Co/Tr/In/Dr/Le/Ou). **Skeletons, config shapes, migration samples, and the end-to-end checklist are in `subs/reference.md`** — read it before scaffolding.

## Load-bearing facts

- `<Name>Module.php` is required: event-type modules extend `BaseEventTypeModule`, utility modules `\CWebModule`; namespace `OEModule\<Name>`, set `$controllerNamespace`; sub-modules via `setModules()` in `init()`.
- A module advertises itself in its **own** `config/common.php` (params, aliases, event observers, container bindings). `Oph*` modules get `models.*` auto-imported; other modules declare imports themselves.
- Register in `$modules` in `protected/config/core/common.php` — modern modules use the explicit FQCN form. For development, register in `local/common.php` instead (last layer merged, wins); move to core when stable. Deployment-specific modules go via the mounted `/config/modules.conf` — never edit core for one trust's bespoke module.
- **Menu items are invisible by default**: `local/common.php` suppresses every `menu_bar_items` entry unless the module sets `params.oe_special_module = true`. Opt in only for admin/infra modules (OeMerge, OeConfig, …) — for clinical modules the suppression is intentional; their entry points are the patient summary/pathway. `restricted` entries map to `authitem` RBAC rows; add new ones in a module migration.
- Migrations: `m<YYMMDD>_<HHMMSS>_*.php` extending `OEMigration` (helpers `insertOEEventType`, `insertOEElementType`, CSV-driven `initialiseData()`). `yiic migrate --all` interleaves core + all module migrations into one timestamp-sorted run sharing one `tbl_migration` — timestamp yours later than any table it depends on; disabling a module doesn't roll its applied rows back.
- Config is APCu-cached as `oe_merged_config_<env>`. After any config edit: `curl http://localhost/apc_clear.php` (localhost-only), restart php-fpm, or `OE_CONFIG_TEST_RUNNING=1` to bypass.
- Cross-module reads: ship `components/<Name>_API.php extends BaseAPI`; consumers use `Yii::app()->moduleAPI->get('<Name>')` — never reach into another module's models. Framework-agnostic contracts: interface in `oe-shared/`, bound in `components.container.bindings`.
- New module code lints against the **yii** configs (`phpstan.yii.neon`, `phpcs.yii.xml`, `rector.yii.php`).
