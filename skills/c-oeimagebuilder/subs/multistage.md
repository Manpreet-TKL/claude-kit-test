# The 5-stage oe-web-live build

Multi-stage so the final image carries no git, composer or build-node toolchain. It does **not** mean a slim payload: the final stage copies the **entire WROOT** from the npm stage, `node_modules` and puppeteer's bundled Chrome (~600 MB) included - in-container PDF rendering depends on them.

## The stages (as in `Web-Live/dockerfile`)

| # | Stage | FROM | What it actually runs |
|---|---|---|---|
| 1 | `git` | `alpine` (+ bash, git, openssh) | `oe-checkout.sh` over `--mount=type=ssh`: clones openeyes at `BUILD_BRANCH` (mandatory), each `MODULES` entry + always `eyedraw` into `protected/modules/` (falling back to `DEFAULT_BRANCH`), inits submodules, strips `.git`, writes `$WROOT/buildinfo.txt` (debug info panel) and `/config/modules.conf`. Then writes `protected/config/cachebuster.txt` from `CACHEBUSTER` (or a timestamp). |
| 2 | `composer` | `chialab/php:${PHP_VERSION}` | `composer update --no-dev --optimize-autoloader --prefer-stable` - **update, not install**: deps re-resolve at build time within composer.json constraints; two builds of the same branch can differ. |
| 3 | `npm` | `node:${NODE_MAJOR_VERSION}-${NODE_DEBIAN_VERSION}` | `npm install --omit=dev --no-save` - **install, not ci**, so package-lock is not authoritative either. Puppeteer's postinstall downloads Chrome-for-Testing (~600 MB) into the web root here. |
| 4 | `vite` | `node:alpine` | Conditional: only if `package.json` has a `vite-build-only` script - `npm install --no-save && npm run vite-build-only`. No-op on branches without it. |
| 5 | final | `${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}` (default `oe-web-base:php8.4-noble`) | `COPY --from=npm ${WROOT}` (everything, chowned www-data), `COPY --from=vite ${WROOT}/assets` over it, `COPY --from=git /config/modules.conf`; bakes the runtime ENVs, init scripts, `/imageinfo.txt`. |

Each stage `COPY --from`s the previous one's whole WROOT, so the tree accretes: source -> +vendor -> +node_modules/Chrome -> +built assets.

## Cache behaviour

- `CACHEBUSTER` is an ARG of the **git stage**, so changing it re-runs checkout, composer, npm, vite - the works. That is the only supported way to force a fresh checkout of the same branch (`--no-cache` works too, at the cost of the apt layers).
- Because stages 2-3 use `update`/`install` rather than lockfile-exact commands, a cache hit on the git stage can still ship different dependency versions on a rebuild only if the cache is busted - with a full cache hit, nothing re-resolves.
- `--ssh default` is needed for stage 1 (and Manager's sample clone); without an SSH agent the build dies at checkout.

## Manager is not multi-stage

`Manager/dockerfile` is a single stage `FROM ${BASEIMAGE}:${OE_VERSION}` that clones the `sample` repo (at `BUILD_BRANCH`, default `OE_VERSION`, fallback master) and adds cron/maintenance wiring. It inherits everything else - including node_modules and Chrome - from the live image.
