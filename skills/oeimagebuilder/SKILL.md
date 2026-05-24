---
name: oeimagebuilder
description: OEImageBuilder repo — builds the toukanlabsdocker/{oe-web-base, oe-web-live, oe-web-dev, oe-manager} images that oe-deploy then runs. Invoke explicitly for image work. Volatile detail (build args, multi-stage layout, local-source variant) lives in subs/.
disable-model-invocation: true
---

# OEImageBuilder — contributor contract

This repo produces every OpenEyes container image consumed by `oe-deploy`. It does **not** run anything — it builds and (optionally) pushes.

## Image hierarchy

```
oe-web-base  ──┬──> oe-web-live  ──> oe-manager
               │
               └──> oe-web-dev   (dual personality: oe-web-dev | oe-web-debug)
```

- **`oe-web-base`** — OS, PHP, system libs, Apache. The slow-changing layer.
- **`oe-web-live`** — adds OpenEyes itself via a 5-stage build (git → composer → npm → vite → final). Production-shaped.
- **`oe-web-dev`** — `oe-web-base` + dev tooling. Switches personality on `PROD_DEBUG=TRUE/FALSE`.
- **`oe-manager`** — `FROM oe-web-live` + manager-specific bits. **Its tag must match `oe-web-live`** at build time, otherwise oe-deploy's gate refuses to come up.

## Build philosophy (stable rules)

- **Init scripts run in numeric prefix order.** `10_apache.sh`, `20_php.sh`, `30_openeyes.sh`, etc. Child images override parent scripts by **same filename**, not by addition.
- **Build args are the only configuration.** No `ENV` writes inside the Dockerfile that aren't echoing an `ARG`. If you need a new knob, plumb a new `ARG` through — see `subs/build-args.md`.
- **Modules are space-separated in `MODULES=`.** The init script clones each into `protected/modules/` at build time. Adding a module = changing the build arg, not editing the Dockerfile.
- **WROOT is the document root.** Default `/var/www/openeyes`. Don't hardcode the path elsewhere.

## When the tag doesn't match (and why)

`oe-manager` and `oe-web-live` are deployed as a pair. If you bump one to `v26.0.0-rc4` and the other stays on `v26.0.0-rc3`, schemas/migrations will mismatch. **Build them together.** `build.sh` in this repo accepts a single `--tag` for the family for exactly this reason.

## Tag casing — Docker Hub is case-sensitive

`v26.0.0-rc3` ≠ `v26.0.0-RC3`. Always use lowercase `rc`. This bites in two places:

1. Pushing — `docker push toukanlabsdocker/oe-web-live:v26.0.0-RC3` succeeds and creates the wrong tag.
2. Pulling from `oe-deploy` — `OE_WEB_TAG=v26.0.0-RC3` will manifest-not-found in production.

## Where the detail lives

- `subs/build-args.md` — current `ARG` names, defaults, what they do. Versions move.
- `subs/multistage.md` — the 5-stage `oe-web-live` build, why each stage exists, cache implications.
- `subs/local-source.md` — building from a local OpenEyes checkout (offline / WIP branches).

## Where this fits

You build images here. They get **pulled** by `oe-deploy` on the target host (or pushed from here, then pulled there). For deployment work, switch to the `oe-deploy` skill.
