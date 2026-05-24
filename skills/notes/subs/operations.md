# notes — dev, build, deploy, gotchas (volatile)

## Local dev (host)

```bash
cd ~/notes-test/src
composer install
npm ci
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan serve
npm run dev   # in another terminal, for HMR
```

Tests:

```bash
cd ~/notes-test/src
php artisan test                       # full suite
php artisan test --filter=NoteSearch   # focused
```

## Build the image

```bash
cd ~/notes-test
./build.sh                # produces toukanlabsdocker/notes:<tag>
./build.sh --push         # only if logged in to Docker Hub
```

The tag comes from `git describe --tags --always`. Don't override unless you mean to.

## Deploy

This repo only produces the image. Deployment is handled by the `oe-deploy` skill. In short:

1. `cd <env>` (the renamed oe-deploy checkout)
2. Edit `.env` to pin the new `NOTES_TAG`.
3. `./build.sh` — gates check disk, env keys, mariadb version, etc.
4. Disruptive operations require typing `yes` literally.

## Things that bite (current)

- **Markdown code-fence rendering** depends on `Note::renderedBody()`. Never `{!! $note->body !!}` directly.
- **Slug collisions on restore** — see the soft-delete contract; trust the model's logic.
- **MariaDB collation drift** — local dev DBs sometimes get re-created with `utf8mb4_unicode_ci`. Search ordering will then differ from prod. `SHOW CREATE TABLE notes\G` to check.
- **`stats_viewer`** is intended to be default-on. If the create-user form ever stops pre-ticking it, it's because the `default_on_create` flag was wiped during a seed.
- **OPcache in prod** — `validate_timestamps=0` means an in-place file edit doesn't take effect until `opcache_reset()` or container restart. This is the expected production behaviour; don't "fix" it.
- **No queue worker** — long-running work blocks the request. If you add something slow, switch the queue driver before deploying, not after.

## Deferred / known-debt

Anything tracked as deferred lives in the repo's `docs/deferred.md` (not here, because the list churns weekly).
