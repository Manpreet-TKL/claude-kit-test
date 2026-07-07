---
name: Don't bundle local/common.php template inside an OE module
description: When installing an OE module, patch the in-container local/common.php directly; don't keep a host-side template copy inside the module dir.
type: feedback
originSessionId: 3edf3f74-8cd5-4d68-9e64-24d0878d1895
---
When installing an OE module that needs to be enabled via `local/common.php`, patch the in-container file (`/var/www/openeyes/protected/config/local/common.php`) **directly** — do not maintain a host-side template (e.g. `<module>/local_common.template.php` or `/tmp/lion-local-common.php`) that gets `docker cp`'d in.

**Why:** User pushed back when I created `/tmp/lion-local-common.php` as a staging template for the voiceControl install. The aiSearch module's `local_common.template.php` pattern is not the preferred shape here — the module advertises itself in its own `<module>/config/common.php`; `local/common.php` is just an on-switch and its source of truth lives at the container path.

**How to apply:**
- For module enablement, run an in-place edit inside the container (e.g. `docker exec <web> sed -i ...` or a PHP transform) against `/var/www/openeyes/protected/config/local/common.php`.
- The edit should add `'modules' => array('<Name>')` (or extend the existing array if other modules are already enabled), idempotently, with `<Name>:BEGIN`/`END` markers if you expect other modules to co-exist.
- Don't create or version-control a host-side copy of `local/common.php`. If you need to inspect the current state, `docker exec <web> cat ...` is the source of truth.
