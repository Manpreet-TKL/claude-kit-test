---
name: oe-deploy
description: oe-deploy template repo — a "pantry + recipe + chef" generator that assembles a docker-compose.yml from SERVICES+MODS lists and templates/, then provisions an OpenEyes/notes/openers instance. Invoke explicitly for deployment work on any host. Volatile detail (per-app recipes, current build gates, first-run order) lives in subs/.
disable-model-invocation: true
---

# oe-deploy — contributor contract

oe-deploy is **a template, not a source of truth**. Every customer instance is a `mv oe-deploy <env>` of this repo on the target host, with its own `.env`, its own `.oedeploy`, and its own generated `docker-compose.yml`.

> **Never `cp` to a sibling directory.** Always `mv oe-deploy <env>`. The repo is designed for one rename per instance.

> **Manpreet's hosts already have**: docker login, GPG keys, host-setup, oe-deploy itself. Don't re-check, don't re-run those.

> **OE sample DBs ship with `admin/admin`.** On demo boxes, do NOT run `set_frontend_passwords.sh`.

## The three-part mental model

| Part        | What it is                                                | Where it lives |
|---          |---                                                        |---             |
| **Pantry**  | A library of compose service fragments (one per service). | `templates/*.yml` |
| **Recipe**  | A per-instance list of which fragments to include.        | `SERVICES=…` and `MODS=…` in `.env` |
| **Chef**    | The script that assembles fragments + env into a compose. | `build.sh` |

A new app (e.g. `openers`) is **a new recipe**, not new pantry items.

## Per-app recipes (current)

| App        | `SERVICES`                | `MODS`            | Notes |
|---         |---                        |---                |---    |
| openeyes   | `db web`                  | _(none)_          | base ref-app |
| notes      | `db notes`                | `tfk_only`        | TFK-only access band |
| openers    | `db web`                  | `tfk`             | TFK-internal OpenEyes variant |

Full live detail in `subs/recipes.md` — it changes when a new app or mod is added.

## `.oedeploy` (per-instance metadata)

Each instance carries a `.oedeploy` file containing at minimum `appName` (`openeyes` | `notes` | `openers`). The build gates use this to pick the right templates and the right disruptive-op messaging.

## Template patterns to use, not invent

- **Named-volume + bind**: data lives in a docker named volume; logs/config bind-mount to the host.
- **`${VAR:-default}`**: optional with a sensible fallback.
- **`${VAR:?msg}`**: required; build fails clearly if unset.
- **`$VAR` literal** (no curly braces) for compose-internal interpolation that must survive into the rendered file.
- **YAML anchors `<<: *web`** for shared service blocks. Don't copy-paste; extend.

## The build gates (1–7, abridged)

`build.sh` refuses to proceed unless:

1. Disk ≤ 94% on `/`.
2. `.oedeploy` exists and is non-empty.
3. No "key files" sit loose on disk (must be in volumes/secrets).
4. `.env` keys match `.env.example` (no orphans, no missing required).
5. Pinned MariaDB version matches what the running data volume expects.
6. `TZ` is set.
7. `DOMAIN_NAMES` is backtick-quoted in `.env` (compose interpolation will otherwise eat the commas).

Disruptive gates (e.g. data wipe) require typing literal `yes`. `y`, `YES`, and `echo y |` all fail.

Full current list, plus what to do when each one trips, in `subs/build-gates.md`.

## First-run order on a fresh host

Cheat-sheet — full sequence with all flags is in `subs/first-run.md`:

```
mv oe-deploy <env>
cd <env>
$EDITOR .oedeploy       # set appName
./env-setup.sh -y -ndp  # write .env, no docker pull, no prompts
$EDITOR .env            # pin tags, set DOMAIN_NAMES, TZ
cp templates/my.cnf.sample my.cnf   # pick a my.cnf variant
rm seed_*.csv            # if not seeding from CSV
./db-setup.sh
echo yes | ./build.sh
```

## Seeding fallback

When the in-container `oemig` alias isn't on PATH, **use `bash -c` not `sh -l -c`**, and call the absolute migrator path. The full incantation is in `subs/first-run.md`.

## Where this fits

This repo only builds and runs containers. The images themselves come from `OEImageBuilder` (and `notes-test`). Switch to those skills for image work.
