---
name: c-oe-deploy
description: oe-deploy template - compose gen + provisioning
disable-model-invocation: false
---

# oe-deploy

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

A **template, not a source of truth**: every instance is a `mv oe-deploy <env>` on the target host - **never `cp`** - with its own `.env`, `.oedeploy`, and generated `docker-compose.yml`. Upstream is a private repo **`oed`** - it holds the docs, the extra templates, and the advanced devops maintenance scripts; this `oe-deploy` is the trimmed template for deploying production-ready OpenEyes plus a little diagnostics. **Changes/PRs go to `oe-deploy` when they need to reach a working deployment** (setup/build scripts, compose templates, env scripts); `oed` only for docs and advanced maintenance tooling - **ask when unsure which repo a change targets.** **Sensitive values (DB passwords, API keys, GPG passphrases, ...) always go in Docker secrets** - the per-instance secret files keyed off `.oedeploy`/`keeper.csv` - **never in `.env` / environment variables.** Manpreet's hosts already have docker login, GPG, host-setup - don't re-check or re-run those. OE sample DBs ship `admin/admin` - never run `set_frontend_passwords.sh` on demo boxes. Detail: `subs/versions.md`, `subs/recipes.md`, `subs/build-gates.md`, `subs/first-run.md`; `.bash_aliases` house rules: `subs/aliases.md`.

## Pantry + recipe + chef

Pantry: `templates/*.yml` (one compose fragment per service), with mods in `templates/modules/`, and `templates/healthchecks/` + `templates/awslogs/`. Recipe: four space-separated lists in `.env` - `SERVICES` -> `templates/<svc>.yml`, `MODS` -> `templates/modules/<mod>.yml`, `HEALTHCHECKS` -> `templates/healthchecks/<hc>.yml`, `AWSLOGS` -> `templates/awslogs/<svc>.yml`. Chef: `build.sh` runs `docker compose -f ... config` over the lot into `docker-compose.yml`. A new app is a new recipe - its own `templates/<app>.env` - not new pantry items. Current recipes (cross-check the per-app `.env`): openeyes = `db web`; notes = `db notes tfk`; openers = `db mc-ers ers min tfk-ers cla` - live detail in `subs/recipes.md`. `MASTER_TAG` (e.g. `26.0.0`) is the umbrella image tag; `OE_WEB_TAG`/`OE_MANAGER_TAG`/`OE_RTF_TAG`/`PAYLOAD_IMAGE_TAG`/... default to it. `.oedeploy` holds per-instance metadata (at minimum `appName`, every var must be non-empty); the scripts source it to pick the `.env` template, secret filenames, and keeper entries.

## Template patterns (use, don't invent)

Named volume for data + bind mounts for logs/config; `${VAR:-default}` optional, `${VAR:?msg}` required; literal `$VAR` (no braces) when interpolation must survive into the rendered file; YAML anchors (`<<: *web`) for shared blocks - extend, don't copy-paste.

## Dev mod (oe-web-dev) gotchas

The `dev` mod swaps `web` to `oe-web-dev`, which clones openeyes at first boot (dev-only init 42, skipped once `protected/modules/eyedraw/.git/HEAD` exists; needs `BUILD_BRANCH` plus the `SSH_PRIVATE_KEY` secret). **Never mount a volume inside `/var/www/openeyes`** - compose pre-creates the mount dir before init 42, git refuses to clone into the non-empty tree, and the container never comes up. The exception-handler volume's designed target is top-level `/OEExceptionHandlerLogs`: init 52 (in web AND manager images) symlinks it into `protected/runtime/` after the clone, so host-side logs work on live, dev, and manager alike - an in-tree target is exactly the clone-breaking bug (an existing dev host may carry the old workaround of stripping the mount from its rendered `docker-compose.yml`). `YII_DEBUG_BAR_IPS: ${YII_DEBUG_BAR_IPS:-'*'}` (the `debug.yml` pattern) turns on the Yii debug bar; openeyes reads it in `protected/config/core/main.php` only when `YII_DEBUG` is on (quotes stripped, comma-separated IPs or `*`), so it is inert on live images. `web.yml`'s `OE_EXCEPTION_HANDLER_FORCE_ENABLED` / `OE_EXCEPTION_HANDLER_LOG_PATH` **environment entries** have no consumer anywhere - dead config (the same-named variable still works as the mount-target override).

## Build gates (abridged)

`build.sh` refuses unless: disk <= 94% on `/`; every `.oedeploy` var is non-empty; no loose key files (keeper.csv, private.key, public-key.gpg, `~/.ssh/<client>{,.pub}`); `.env` exists; `my.cnf.d/my.cnf` present when `SERVICES` has `db`; `.env` keys match `templates/<appName>.env`; host mariadb client >= `DB_TAG` (and >= 10.6 for OE >= 7.0.0); `TZ` valid and equal to the host timezone; `DOMAIN_NAMES` all backtick-quoted (only checked when `SERVICES` has `tfk`). There is no `--force` and no typed-`yes` gate - the one interactive prompt is prod-with-running-containers, bypassed by `-y`. Remedies: `subs/build-gates.md`.

## First run on a fresh host

```
mv oe-deploy <env> && cd <env>             # NEVER cp; never leave it named oe-deploy
$EDITOR .oedeploy                          # set appName=openeyes|notes|openers (no blank vars)
bash environment-setup.sh -y               # gen secrets + keeper.csv, copy templates/<app>.env -> .env
#                         -ndp             # add if no dinopass.com access (offline gpg passwords)
$EDITOR .env                               # tweak tags/DOMAIN_NAMES/TZ (template ships sane defaults)
cp my.cnf.d/my.cnf.c4m16 my.cnf.d/my.cnf   # pick c2m4|c4m16|c8m32 by host spec
bash db-setup.sh                           # temp db container creates dbs+users, then tears down
bash build.sh                              # renders docker-compose.yml, pulls, ups

# Demo/sample OE only - load the bundled sample DB (admin/admin + sample patients).
# oe-manager does NOT auto-load it; its startup only migrates. Run AFTER build.sh:
docker compose stop oe-manager             # stop it first so it can't race the reset
docker compose run --rm --entrypoint /bin/bash oe-manager -c \
  '/init_scripts/55-create-folders.sh && \
   /var/www/openeyes/protected/scripts/oe-reset.sh -nm && \
   /var/www/openeyes/protected/scripts/oe-migrate.sh'   # drops DB, loads sample_db.zip, migrates
docker compose up -d oe-manager            # comes back healthy; its migrate-up is now a no-op
```

`environment-setup.sh` aborts unless docker is logged in. Real script name is `environment-setup.sh` (flags: `-y -o -ndp -tfk -nm`); `-ndp` is offline/no-dinopass, **not** "no pull". **oe-manager builds the OE schema from migrations only - it never auto-loads the sample DB.** A demo box therefore needs the `oe-reset.sh -nm && oe-migrate.sh` step above; skip it and you get an empty (or, if a prior run was interrupted, a half-built crash-looping) schema. The tell-tale is `oe-manager` stuck `Restarting` with `Table 'openeyes.eyedraw_doodle' doesn't exist` - the same reset fixes it. The 242 MiB `sample_db.zip` is bundled inside the **oe-manager** image (not web), so this works offline. Full recipe, symptoms, and `oe-reset.sh` flags: `subs/first-run.md`. Images come from `OEImageBuilder` / `notes-test`; switch skills for image work.
