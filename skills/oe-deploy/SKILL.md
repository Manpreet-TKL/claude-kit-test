---
name: oe-deploy
description: oe-deploy template repo — compose generator + provisioning
disable-model-invocation: true
---

# oe-deploy

When loaded as context with no task, reply only `Context loaded.`

A **template, not a source of truth**: every instance is a `mv oe-deploy <env>` on the target host — **never `cp`** — with its own `.env`, `.oedeploy`, and generated `docker-compose.yml`. Manpreet's hosts already have docker login, GPG, host-setup — don't re-check or re-run those. OE sample DBs ship `admin/admin` — never run `set_frontend_passwords.sh` on demo boxes. Detail: `subs/recipes.md`, `subs/build-gates.md`, `subs/first-run.md`.

## Pantry + recipe + chef

`templates/*.yml` (pantry: one compose fragment per service) + `SERVICES=…` / `MODS=…` in `.env` (recipe) + `build.sh` (chef: assembles fragments + env into the compose). A new app (e.g. `openers`) is a new recipe, not new pantry items. Current recipes: openeyes = `db web`; notes = `db notes` + `tfk_only`; openers = `db web` + `tfk` — live detail in `subs/recipes.md`. `.oedeploy` holds per-instance metadata (at minimum `appName`); the gates use it to pick templates and messaging.

## Template patterns (use, don't invent)

Named volume for data + bind mounts for logs/config; `${VAR:-default}` optional, `${VAR:?msg}` required; literal `$VAR` (no braces) when interpolation must survive into the rendered file; YAML anchors (`<<: *web`) for shared blocks — extend, don't copy-paste.

## Build gates (abridged)

`build.sh` refuses unless: disk ≤ 94% on `/`; `.oedeploy` exists, non-empty; no loose key files; `.env` keys match `.env.example`; pinned MariaDB matches the data volume; `TZ` set; `DOMAIN_NAMES` backtick-quoted. Disruptive gates require a typed literal `yes` — `y`, `YES`, `echo y |` all fail. Remedies: `subs/build-gates.md`.

## First run on a fresh host

```
mv oe-deploy <env> && cd <env>
$EDITOR .oedeploy        # set appName
./env-setup.sh -y -ndp   # write .env, no docker pull, no prompts
$EDITOR .env             # pin tags, DOMAIN_NAMES, TZ
cp templates/my.cnf.sample my.cnf
rm seed_*.csv            # if not seeding from CSV
./db-setup.sh
echo yes | ./build.sh
```

Seeding fallback when the in-container `oemig` alias isn't on PATH: `bash -c` (not `sh -l -c`) with the absolute migrator path — full incantation in `subs/first-run.md`. Images come from `OEImageBuilder` / `notes-test`; switch skills for image work.
