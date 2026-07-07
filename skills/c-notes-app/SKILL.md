---
name: c-notes-app
description: opennotes repo conventions
disable-model-invocation: true
---

# opennotes (formerly notes-test)

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

The repo and app are now called **opennotes** - `~/opennotes`, GitHub `ToukanLabs/opennotes` (renamed June 2026; a stale `~/notes-test` checkout of the old repo may still exist - don't work in it). The **Docker image and deploy plumbing keep the `notes` name**: image `toukanlabsdocker/notes`, oe-deploy `appName=notes`, `templates/notes.yml`, `NOTES_*` env vars. In-repo branding (README, `APP_NAME`) may still say ToukanNotes in places.

Laravel + Alpine + MariaDB notes app for DevOps teams; the single design goal is **speed** to write, find, and share a note. Read the in-app `/help` (`src/resources/views/help/index.blade.php`) before any UX change - its rules are non-negotiable. Detail: `subs/stack.md` (pinned versions), `subs/schema-and-domain.md`, `subs/operations.md` (dev/build/deploy), and `docs/codebase-tour.md` in the live repo.

## Stable conventions

- No SPA framework - Alpine.js + Blade only.
- Body is plain text in the DB; render only via `Note::renderedBody()` (the one path with ``` rendering AND XSS safety).
- Search = case-insensitive LIKE on `notes.title` + `sections.name`; body intentionally not searched; SQL wildcards in user terms neutralised.
- Slugs auto-generate in `Note::boot('creating')`; the uniqueness check includes soft-deleted rows.
- Resource routes bind on `id`, not slug.
- Authorisation only via `User::can*()` + `NotePolicy` - never query roles/permissions from views or controllers.
- Validation in `Http/Requests/Store*/Update*Request`; controllers take typed requests.
- Forward-only migrations: new columns `nullable()` or defaulted - production has data.
- Tests hit a real MariaDB; SQLite is not a substitute.
- `roles.default_on_create` drives pre-ticked roles on the user-create form (`stats_viewer` is on) - flip the flag, don't hardcode a checkbox.

## Security greps (every PR - zero new lines vs baseline)

```bash
grep -rnE '\b(eval|exec|system|popen|proc_open|passthru|shell_exec|pcntl_exec|assert|unserialize)\s*\(' src/app/
grep -rnE '\{!! ' src/resources/views/
grep -rnE 'whereRaw|DB::raw\(|->raw\(' src/app/
```

Full audit: `docs/security.md` in the live repo.

## Wider stack

This repo only produces the image - no `build.sh`; build with `docker build --target production` (see `subs/operations.md`). Deployment is an oe-deploy instance: the live one is `~/octopus` (`appName=notes`, `machineName=test2`), publishing `toukanlabsdocker/notes:<NOTES_TAG>` on :81 plus Traefik `notes.localhost` - the deploy side is untouched by the opennotes rename. For deployment-repo work, switch to the `c-oe-deploy` skill.
