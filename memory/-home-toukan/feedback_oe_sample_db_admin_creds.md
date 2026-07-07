---
name: OE sample DB ships with admin/admin
description: OpenEyes seeded/sample databases ship with username `admin` and password `admin` — do not reset frontend passwords on a demo box.
type: feedback
originSessionId: 596431f6-e7a0-484f-a3d6-6dd01fd7636a
---
OpenEyes' sample/seeded databases (anything created via `oe-reset.sh -nm` + `oe-migrate.sh`) ship with a known working login: **username `admin`, password `admin`**.

**Why:** Manpreet flagged a `set_frontend_passwords.sh` run as wrong — the script clobbered the admin password (and partially failed on docman), making demo logins harder, not easier. The seeded `admin/admin` was already correct.

**How to apply:** When you need to authenticate to a demo OE for testing (curl, browser walkthrough), use `admin`/`admin` directly. Don't run `bash scripts/set_frontend_passwords.sh` and don't try to read the OE_ADMIN_PASSWORD secret. Only reset passwords if the user explicitly asks.
