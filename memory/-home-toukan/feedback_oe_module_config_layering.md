---
name: OE module config layering — module declares, local enables
description: An OE Yii 1.1 module advertises itself in its own config/common.php (menu entries, CSRF exemptions, params); local/common.php only flips the on-switch by adding the module name to `modules`. The OE codebase is never modified.
type: feedback
originSessionId: 596431f6-e7a0-484f-a3d6-6dd01fd7636a
---
The architectural pattern Manpreet wants for any new OE module:

- **`protected/modules/<Name>/config/common.php`** — the module *advertises* itself. Anything specific to the module belongs here: menu entries (`params.menu_bar_items.<key>`), CSRF route exemptions (`components.request.noCsrfValidationRoutes`), params, custom URL rules, etc. OEConfig auto-discovers and merges this for every active module.
- **`protected/config/local/common.php`** — per-deployment overlay. Should only contain the on-switch: `'modules' => array('<Name>')`. Never duplicate things the module can declare for itself.
- **`protected/config/core/common.php` and the rest of the OE codebase** — never modified by a third-party module. If a fleet-wide change is genuinely needed it goes upstream.

**Why:** Manpreet flagged a setup that put the menu entry and CSRF exemption in `local/common.php` as the wrong layer — those belong with the module that owns them, not with the deployment. Putting them in `local/` couples every deployment to module internals and makes the module non-portable.

**How to apply:** When wiring a new module into OE, default to `<module>/config/common.php` for ANY config the module owns. `local/common.php` is reserved for "this deployment turns module X on" and per-environment value overrides. Touching `core/common.php` from a module install is a code smell — fix it by moving config into the module.
