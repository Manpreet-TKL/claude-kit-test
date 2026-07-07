---
name: c-oeimagebuilder
description: OEImageBuilder repo - builds the OE container images
disable-model-invocation: true
---

# OEImageBuilder

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

Builds every image `oe-deploy` runs; it runs nothing itself. There is **no build script** - each top-level folder (`Web-Base/`, `Web-Live/`, `Web-Dev/`, `Manager/`, `Aws-Cli/`) holds a `dockerfile`, built with a plain `docker build` from inside that folder. Detail: `subs/build-args.md` (per-image ARGs), `subs/multistage.md` (the 5-stage live build), `docs/ARM_BUILDS.md` in the repo. Root `docker-compose.yml` is a local test stack, not a deployment artifact.

## Hierarchy

```
oe-web-base ──┬──> oe-web-live ──> oe-manager
              └──> oe-web-dev   (dual personality: dev | debug)
```

- `oe-web-base` - Ubuntu + PHP + Apache + node + Chrome's system libs. Tagged `php<ver>-<os>` (e.g. `php8.4-noble`), never an OE version.
- `oe-web-live` - adds OpenEyes via 5 stages (git -> composer -> npm -> vite -> final). The final image **does** carry `node_modules` incl. puppeteer's Chrome (~600 MB) - that's how in-container PDF rendering works.
- `oe-web-dev` - dev tooling on a switchable base: `PROD_DEBUG=FALSE` from base = dev image (code mounted from host); `PROD_DEBUG=TRUE` from a live tag = production debug image (`debug-<tag>`).
- `oe-manager` - `FROM oe-web-live:${OE_VERSION}` + sample-DB repo + cron/maintenance. **Tag must match oe-web-live** - they deploy as a pair or schemas/migrations mismatch.
- `aws-cli` - standalone cron-runner utility.

## Building

```bash
eval `ssh-agent -s`        # live/manager clone OE repos over SSH
cd Web-Live
docker build -t toukanlabsdocker/oe-web-live:v26.0.0-rc3 \
  --build-arg BUILD_BRANCH=v26.0.0-rc3 --ssh default --progress=plain --no-cache .
```

`BUILD_BRANCH` is mandatory for Web-Live (`oe-checkout.sh` aborts without it); per-module checkouts fall back to `DEFAULT_BRANCH` (master). CI builds/pushes **base, dev, aws-cli** only (amd64+arm64); live/manager are built and pushed by hand.

## Stable rules

- Init scripts run in numeric prefix order (`00-banner.sh` ... `100-start-apache.sh`): tini -> `/init.sh` -> `/init_scripts/`; child images add/override by same filename (`Web-Dev` also has `init_scripts_dev_only/`).
- ARGs are the build knobs, ENVs the runtime contract; re-declare an ARG after every `FROM` whose stage uses it.
- `MODULES` is comma OR space separated; `eyedraw` is always added.
- `WROOT` (default `/var/www/openeyes`) is the document root - don't hardcode the path.
- READMEs are generated: edit `README_template.md` only; CI regenerates and commits `README.md`.
- Every image writes `/imageinfo.txt`; the live checkout also writes `$WROOT/buildinfo.txt` (debug info panel).
- Docker Hub tags are case-sensitive - lowercase `rc` always: `v26.0.0-RC3` pushes a wrong tag and manifest-not-founds on pull.

Deployment work -> `oe-deploy` skill.
