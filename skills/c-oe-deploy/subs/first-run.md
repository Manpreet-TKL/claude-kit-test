# oe-deploy - first-run on a fresh host (volatile)

This is the **current** sequence, read from `environment-setup.sh`, `db-setup.sh`, `build.sh`. Steps move when flags change or a gate is added. If something here disagrees with a script, the script wins - update this file.

## Prerequisites (Manpreet's hosts already have these)

- Docker installed and `docker login` done against `toukanlabsdocker` (`environment-setup.sh` aborts if `docker info` shows no Username).
- GPG keys imported (needed for `-ndp` offline password generation and for git-secret on client boxes).
- `host-setup.sh` previously run (firewall, dirs, timezone, mariadb client).

Don't re-run any of the above on a Manpreet-provisioned host.

## The sequence

```bash
# 1. Rename the checkout (NEVER cp). The dir name becomes the environment/COMPOSE_PROJECT name.
mv oe-deploy <env>          # scripts abort if the dir is still called "oe-deploy"
cd <env>

# 2. Set per-instance metadata. Every var in .oedeploy must be non-empty.
$EDITOR .oedeploy           # appName=openeyes|notes|openers ; pushToGit='' on demo boxes

# 3. Generate secrets + keeper.csv and copy templates/<appName>.env -> .env
bash environment-setup.sh -y       # -y = non-interactive, auto-generate passwords
#                         -ndp     # offline: gpg-random passwords instead of dinopass.com
#                         -nm      # skip Mirth passwords ; -o = overwrite existing [DANGEROUS]
#   Flags are -y -o -ndp -tfk -nm. -ndp means no-dinopass/offline, NOT "no docker pull".

# 4. Tweak .env. The template ships working defaults (MASTER_TAG drives OE tags,
#    DB_TAG=11.8, TZ=Europe/London, DOMAIN_NAMES=`oe.localhost`, WEB_PORT=81).
$EDITOR .env
#   OE_WEB_TAG / MASTER_TAG   # lowercase rc only, e.g. v26.0.0-rc3
#   MIRTH_IMAGE_TAG=4.6.1     # if running mc/mcbl; no bare 4.6
#   DOMAIN_NAMES=`a.tfk.io`   # backticks, only matters when SERVICES has tfk
#   TZ=Europe/London          # must equal the host timezone

# 5. Pick a my.cnf for the host spec (build.sh needs my.cnf.d/my.cnf when SERVICES has db)
cp my.cnf.d/my.cnf.c4m16 my.cnf.d/my.cnf   # variants: c2m4 | c4m16 | c8m32

# 6. Create databases + users (spins a temp 'tempdb' container, then removes it)
bash db-setup.sh            # default: OpenEyes + Mirth + backup user
#   -o -nb   OpenEyes only        -na   Notes app        -ers  Openers
#   -f reset pw's   -ra incl root   -r root only

# 7. Render docker-compose.yml, pull, and bring up
bash build.sh              # -np no pull, -n no up, -d dry-run diff, -y skip prod prompt
```

No `echo yes |` is needed on a fresh host - `build.sh` only prompts on a prod machine with running containers (and `-y` skips that). On demo/sample boxes **do not** run `scripts/set_frontend_passwords.sh` - the sample DB ships `admin/admin`.

After step 7, `docker compose ps` should show services `Up (healthy)` within a few minutes - **except** OpenMRS, which legitimately takes ~73 min on its first WAR deploy on a monkey-spec host. Don't kill it.

## Re-running db-setup.sh / stale `oe-db` volume

`db-setup.sh` is safe to re-run: it detects databases/users that already exist and exits with "All selected databases and users are already set up".

What breaks re-runs is a **leftover data volume with a different root password**: the temp `tempdb` container mounts the instance's `<env>_oe-db` volume (`<env>_oe-db2` with `-db2`), so if that volume pre-dates the current `secrets/MYSQL_ROOT_PASSWORD` every query gets `Access denied`. On `feature/test_env_setup_script` (pending merge) the script warns about the pre-existing volume up front and exits within seconds of the first `Access denied`; older checkouts poll forever with no error. Remedies either way:

- `bash db-setup.sh -r` - resets root to the current secret. Spins the temp container on the SAME volume with `--skip-grant-tables`, so it needs no old password. `DATABASE_HOST=db` is normalised to `localhost` inside the script, so the "local docker containers only" refusal only bites genuinely remote DBs (RDS), not containerised ones.
- `docker volume rm <env>_oe-db` - completely fresh database.

### mariadb 11+ images have no `mysql*` binaries

`mariadb:11.x` ships only `mariadb`, `mariadb-dump`, `mariadbd-safe`, ... - no `mysql`, no `mysqld_safe` (`mysql:8` images are the mirror case). Two traps with `docker exec` into a db container:

- Resolve the client name **inside** the container: `docker exec <db> bash -c '$(command -v mysql || command -v mariadb) ...'` (single quotes - a host-evaluated `$(command -v mysql)` picks the host's client name, which the image may not have).
- A hardcoded `mysqld_safe` entrypoint dies with "executable file not found"; probe first: `docker run --rm --entrypoint sh <image> -c 'command -v mariadbd-safe || command -v mysqld_safe'`.

## Loading the sample DB / fixing the oe-manager crash loop

**oe-manager never loads the sample DB on its own.** Its startup only runs migrations (`85-migrate-up.sh` builds the schema from scratch via the `m130913_000000_consolidation` migration, then `93-import-eyedraw-config.sh` populates eyedraw). A fresh empty DB therefore migrates to an *empty* schema (no patients, and a login you may not have). A **demo** wants the bundled sample DB (admin/admin + sample patients), so run the reset below after `build.sh`.

It's also the fix for the classic crash loop: oe-manager stuck `Restarting (1)` while web is `health: starting`, log ending in:

```
85-migrate-up.sh ... CREATE TABLE `address` ... Table 'address' already exists   # consolidation can't run on a dirty DB
93-import-eyedraw-config.sh ... Table 'openeyes.eyedraw_doodle' doesn't exist   # -> STARTUP ABORTED, exit 1
```

That means a prior run left a **half-built** schema; consolidation won't re-run over existing tables, so `eyedraw_doodle` is never created and the container dies and retries forever. The reset wipes the DB and rebuilds it from the bundled sample.

```bash
docker compose stop oe-manager             # CRUCIAL: stop the crash loop first, or it races the reset on the DB
docker compose run --rm --entrypoint /bin/bash oe-manager -c \
  '/init_scripts/55-create-folders.sh && \
   /var/www/openeyes/protected/scripts/oe-reset.sh -nm && \
   /var/www/openeyes/protected/scripts/oe-migrate.sh'
docker compose up -d oe-manager            # migrate-up is now a no-op; oe-manager stays healthy
```

- The README (Tutorial 5) writes this as `docker-compose run -d ... && docker exec ... && docker stop`. On compose v2 a **detached** `/bin/bash` with no TTY exits immediately, so the `exec` misses it - pass the work to `bash -c` inline instead (above). `docker-compose` and `docker compose` both work on Manpreet's hosts.
- `oe-reset.sh -nm`: drop the DB + protected files, extract & import `protected/modules/sample/sql/sample_db.zip` (~242 MiB, **bundled in the oe-manager image - not web - so no git/network fetch**), `-nm` skips the auto-migrate so `oe-migrate.sh` runs the migration delta explicitly. **WARNING: destroys the current DB.** Other flags: `-nb` no banner, `--no-clean`, `--cleanbase`, `-r <restorefile>`.
- Watch it: `tail -f` the run, or `docker exec <env>-db-1 sh -c 'mariadb -uroot -p"$(cat /run/secrets/MYSQL_ROOT_PASSWORD)" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\"openeyes\""'` - count climbs ~145 (broken) -> ~1400 (sample imported) -> ~2300 (after migrate). The OE DB password secret is `DATABASE_PASS` (not `...PASSWORD`); root is `MYSQL_ROOT_PASSWORD`.
- **The reset exits non-zero (`exit 1`, "ABORTED DUE TO ERROR") and that's EXPECTED - do not redo it.** `oe-migrate.sh` migrates first (`yiic migrate --all`, then `artisan migrate`) and only *then* tries an `npm/vite build`, which dies `vite: not found` (code 127) because the **oe-manager image has no node toolchain**. The schema is already complete by then and the **web** image ships prebuilt assets, so OE works regardless. Confirm success by the DB, not the exit code: `eyedraw_doodle` exists with rows, `tbl_migration` maxes at the latest `m26...` version, `user`/`patient` are populated.
- Verify the instance: `docker compose ps` -> web `(healthy)`, oe-manager `Up` with **restarts=0** (it now clears `93-import-eyedraw-config.sh` instead of crash-looping); `curl -s -o /dev/null -w '%{http_code}' http://localhost:<WEB_PORT>/` -> `200`, page title `OpenEyes`.
- Sample login is `admin`/`admin`; **do not** run `scripts/set_frontend_passwords.sh` on a demo box.

### Migrate-only fallback (when `oemig` alias isn't on PATH)

To run migrations without a full reset (e.g. after pulling a newer image), the in-container `oemig` is a shell alias; aliases don't survive `exec sh -c ...`, and `sh -l -c` doesn't expand them reliably. Use `bash -c` with the absolute path:

```bash
docker compose exec web bash -c \
  '/var/www/openeyes/protected/yiic migrate --interactive=0'
```

## Where to look when something's wrong

- `build.sh` printed a gate failure -> `subs/build-gates.md`.
- A service is unhealthy -> `docker compose logs <svc>`.
- BridgeLink/Mirth "manifest unknown" -> you pinned a tag that doesn't exist; use `MIRTH_IMAGE_TAG=4.6.1`.
- Traefik 502s on a fresh box -> old Docker daemon API version; lower `min-api-version` to `1.24` in `/etc/docker/daemon.json` (don't downgrade Traefik).
- OE returns `{}` from `/openmrs/` -> that's the REST root; legacy UI is `/openmrs/login.htm`.
