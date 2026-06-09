---
name: notes-app
description: ToukanNotes (notes-test) repo — Laravel 13 + Alpine + MariaDB notes app whose single design goal is speed of writing/finding/sharing notes. Invoke explicitly when working in ~/notes-test/ or anywhere ToukanNotes context is needed. Volatile detail (pinned versions, schema, current gotchas) lives in subs/.
disable-model-invocation: true
---

# ToukanNotes (notes-test) — contributor contract

A fast, opinionated notes app for DevOps teams. The single design goal is **speed** — to write, find, and share a note. Everything else is a trade-off in service of that goal.

Read the in-app `/help` (`src/resources/views/help/index.blade.php`) before designing any UX change — its 9 strict rules and 10 principles are non-negotiable.

## Where to look first

- `docs/codebase-tour.md` — full annotated tree (in the live repo).
- `subs/stack.md` — pinned versions (PHP, Laravel, MariaDB, …). These move; check it before assuming.
- `subs/schema-and-domain.md` — current domain model, container runtime, conventions.
- `subs/operations.md` — local dev, building images, deploying, things that bite.

## Stable conventions (do not violate without discussion)

- **No SPA framework.** Alpine.js + Blade only. UX target is "fastest possible page load and search response."
- **Body is plain text in the DB.** Render via `Note::renderedBody()` — the only path that guarantees both ` ``` ` → `<pre><code>` rendering AND XSS safety.
- **Search uses case-insensitive LIKE** across `notes.title` and `sections.name`. **Body is not searched** — intentional, the priority is sub-second lookup. SQL wildcards in user terms are neutralised; empty terms return no results.
- **Slugs auto-generate** in `Note::boot('creating')` and the uniqueness check includes soft-deleted rows — restoring must not collide.
- **Resource routes bind on `id`**, not slug, for collision-proof URLs.
- **Authorisation flows through `User::can*()` and `NotePolicy`.** Never query roles/permissions from views or controllers.
- **Validation lives in `Http/Requests/Store*Request` / `Update*Request`.** Controllers take typed requests, not raw `Request`.
- **Forward-only migrations.** New columns must be `nullable()` or have a default — production has data.
- **Tests hit a real MariaDB** (`MATCH … AGAINST`, BLOB, case-insensitive collation). SQLite is not a substitute.
- **Default-on-create roles**: the `roles` table carries a `default_on_create` flag — the user-create form pre-ticks them. `stats_viewer` is default-on. New roles intended for everyone need that flag flipped, not a hardcoded checkbox.

## Security must-do list (run on every PR)

```bash
# All three should produce zero new lines vs. the baseline call-sites.
grep -rnE '\b(eval|exec|system|popen|proc_open|passthru|shell_exec|pcntl_exec|assert|unserialize)\s*\(' src/app/
grep -rnE '\{!! ' src/resources/views/
grep -rnE 'whereRaw|DB::raw\(|->raw\(' src/app/
```

See `docs/security.md` in the live repo for the full audit and what each known site does.

## Where this app sits in the wider stack

This repo only produces the **image** — and note it has **no `build.sh` of its own**; the image is built directly with `docker build --target production` (see `subs/operations.md`).

Actual deployment lives in an `oe-deploy` instance. The live one is `~/octopus` (a `mv oe-deploy octopus` with `appName=notes`, `machineName=test2`): its generated `docker-compose.yml` references the prebuilt `toukanlabsdocker/notes:<NOTES_TAG>` image and publishes it on **:81** (plus Traefik `notes.localhost`). The oe-deploy repo assembles `templates/notes.yml` + `templates/db.yml` + `templates/tfk_only.yml` via *its* `build.sh`. For deployment-repo work, switch to the `oe-deploy` skill; for the concrete rebuild-and-redeploy commands, see `subs/operations.md`.
