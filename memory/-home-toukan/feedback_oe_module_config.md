---
name: oe-module-config
description: OE module config - the module declares itself in <module>/config/common.php; local/common.php is only the on-switch, patched in-container directly
metadata:
  type: feedback
---

Config layering for any new OE Yii 1.1 module (merged 2026-07-19 from two correction memories):

- `protected/modules/<Name>/config/common.php` - the module **advertises itself**: menu entries (`params.menu_bar_items.<key>`), CSRF route exemptions (`components.request.noCsrfValidationRoutes`), params, custom URL rules. OEConfig auto-discovers and merges this for every active module.
- `protected/config/local/common.php` - per-deployment overlay: **only** the on-switch `'modules' => array('<Name>')` plus per-environment value overrides. Never duplicate what the module can declare for itself.
- `protected/config/core/common.php` and the rest of the OE codebase - never modified by a module install; a genuinely fleet-wide change goes upstream.
- Patch `local/common.php` **in-container, in place** (`docker exec <web> sed -i ...` or a PHP transform against `/var/www/openeyes/protected/config/local/common.php`; idempotent, `<Name>:BEGIN`/`END` markers if other modules co-exist). Never keep a host-side template copy inside the module (no `local_common.template.php`, no `/tmp` staging file) - the container path is the source of truth; inspect it with `docker exec <web> cat`.

**Why:** Manpreet flagged both a menu-entry/CSRF block placed in `local/` (wrong layer - couples every deployment to module internals, makes the module non-portable) and a host-side local-common template (aiSearch's template pattern is not the preferred shape).

**How to apply:** default any module-owned config to `<module>/config/common.php`; treat a `core/common.php` edit from a module install as a code smell; enable via an in-place container edit.
