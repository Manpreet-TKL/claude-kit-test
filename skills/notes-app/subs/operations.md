# notes — dev, build, deploy, gotchas (volatile)

## Local dev (host)

```bash
cd ~/opennotes/src
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
cd ~/opennotes/src
php artisan test                       # full suite
php artisan test --filter=NoteSearch   # focused
```

## Build the image

There is **no `build.sh` in `~/opennotes`** (the old docs were wrong). Build the multi-stage `docker/Dockerfile` directly — the `production` target bakes `composer install` + `npm run build` (compiled `public/build/` assets) into a self-contained image:

```bash
cd ~/opennotes
docker build --target production \
  --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
  -f docker/Dockerfile \
  -t toukanlabsdocker/notes:"$(cat VERSION)" .
# push only if logged in to Docker Hub:
docker push toukanlabsdocker/notes:"$(cat VERSION)"
```

The tag comes from the **`VERSION` file** (currently `1.0.0`), *not* `git describe`. There is also a `development` target. The buildkit `SecretsUsedInArgOrEnv` lines at the end are pre-existing lint advisories, not build failures — check the exit code, not those.

## Deploy (redeploy to the `~/octopus` instance)

`~/octopus` is the live oe-deploy instance (`appName=notes`). Its generated `docker-compose.yml` references the prebuilt image (no build context) and runs `db` (mariadb:11.8) + `notes` on **:81**. Redeploy = rebuild the image (above), then recreate the container from the same tag:

```bash
# safety: keep a rollback image before overwriting the tag
docker tag toukanlabsdocker/notes:"$(cat ~/opennotes/VERSION)" \
           toukanlabsdocker/notes:"$(cat ~/opennotes/VERSION)"-pre-redeploy-$(date +%Y%m%d)

# hot-swap just notes (db already up):
docker compose --project-directory ~/octopus -p octopus -f ~/octopus/docker-compose.yml \
  up -d --force-recreate --no-deps notes

# or bring up the whole stack from cold (db + notes):
docker compose --project-directory ~/octopus -p octopus -f ~/octopus/docker-compose.yml up -d
```

Notes on behaviour, verified:

- The compose does **not** mount `src/` — the image is self-contained, so source edits require a rebuild + recreate, never a live reload. (Combined with prod OPcache `validate_timestamps=0`, an edit inside the running container does nothing until restart anyway.)
- The notes entrypoint **waits for db** (`40-wait-for-db-host.sh`, timeout 9999s), so start ordering is safe even though the compose has no `depends_on`.
- `RUN_MIGRATIONS=true` runs migrations on boot; `RUN_SEEDERS=auto` seeds **only if the users table is empty** — existing data in the `octopus_oe-db` volume is preserved across redeploys.
- Verify after: `docker inspect -f '{{.State.Health.Status}}' octopus-notes-1` → `healthy`, then `curl -s -o /dev/null -w '%{http_code}' http://localhost:81/` → `302` (redirects to `/login`).

Running `oe-deploy`'s own `build.sh` (gates on disk/env/mariadb version, `yes`-gated disruptive ops) is only needed when the *compose itself* must be regenerated — e.g. after changing `SERVICES`/`MODS`/tags in `~/octopus/.env` — or to cold-start the whole stack when it's been `compose down`'d. A plain hot-swap redeploy does not need it.

When you *do* deploy via `build.sh` with a **locally-built, unpushed** image, two things bite (both verified 2026-06-10):

- **Always pass `-np` (no-pull).** A plain `build.sh` runs `docker-compose pull` (step 6 of the script) and replaces your fresh local `toukanlabsdocker/notes:1.0.0` with the **stale registry `1.0.0`** before bringing it up. `-np` keeps the local image. The `yes` confirmation reads from stdin (lowercased), so `printf 'yes\n' | bash build.sh -np` works; only `-n`/`-d` skip the prompt. Run it from `~/octopus` (the script uses relative paths).
- **The trailing `failed to resolve digest … denied/unauthorized` + an empty `old-files/image-hashes-*.txt` are harmless.** `saveImageHashes` can't resolve a *registry* digest for an unpushed local image; the `| jq` swallows the error so the deploy still completes (`*** DONE ***`, exit 0). If you want the registry digest recorded (and other hosts to get the build), `docker push toukanlabsdocker/notes:1.0.0` first.
- `build.sh -d` (dry-run) currently aborts on a `printf "--…": invalid option` bug in `showDryRunDiff` — but only **after** every gate has run and printed `[OK]`, so it still works as a gate validator. (Upstream `oe-deploy` bug, not a per-instance fix.)

## Things that bite (current)

- **Markdown code-fence rendering** depends on `Note::renderedBody()`. Never `{!! $note->body !!}` directly.
- **Slug collisions on restore** — see the soft-delete contract; trust the model's logic.
- **MariaDB collation drift** — local dev DBs sometimes get re-created with `utf8mb4_unicode_ci`. Search ordering will then differ from prod. `SHOW CREATE TABLE notes\G` to check.
- **`stats_viewer`** is intended to be default-on. If the create-user form ever stops pre-ticking it, it's because the `default_on_create` flag was wiped during a seed.
- **OPcache in prod** — `validate_timestamps=0` means an in-place file edit doesn't take effect until `opcache_reset()` or container restart. This is the expected production behaviour; don't "fix" it.
- **No queue worker** — long-running work blocks the request. If you add something slow, switch the queue driver before deploying, not after.
- **`.gitignore` is anchored to the repo root, but the Laravel app lives under `src/`.** Root rules (`/vendor`, `/storage/*`, `/public/build`, …) anchor to `/` and never match the nested `src/vendor`, `src/storage/...`. Without a **`src/.gitignore`** (same Laravel ignores, re-anchored to `src/`), ~9.5k `vendor/` files plus compiled views, logs and temp leak into `git status`. Keep `composer.lock` committed; `public/build` is already tracked (don't add it to the ignore or you get a tracked-but-ignored mess). Unanchored root entries (`.env*`, `auth.json`, `*.log`) already match at any depth — only the leading-slash ones miss.
- **Reverb/Echo guard in `resources/js/bootstrap.js`.** Only wire laravel-echo when `import.meta.env.VITE_REVERB_APP_KEY` is truthy — pusher-js throws **synchronously** on a null/undefined key, which kills Alpine on every page (symptom: the persistent navbar search silently stops working). The production `npm run build` stage bakes no `VITE_REVERB_*`, so the key is `undefined` there and the guard is mandatory. `FEATURE_REVERB` defaults `false`.

## Deferred / known-debt

Anything tracked as deferred lives in the repo's `docs/deferred.md` (not here, because the list churns weekly).
