# The 3-stage oe-web-live build

Multi-stage so the final image carries no git or composer toolchain. It does **not** mean a slim payload: the final stage copies the **entire WROOT** from the deps stage, `node_modules` and puppeteer's bundled Chrome (~600 MB) included - in-container PDF rendering depends on them.

The build was 5 stages historically (git -> composer -> npm -> vite -> final); checkout, composer and npm were merged into a single `deps` stage, which is why they now all run on the OE base image rather than on `alpine` / `chialab/php` / `node`.

## The stages (as in `Web-Live/dockerfile`)

| # | Stage | FROM | What it actually runs |
|---|---|---|---|
| 1 | `deps` | `${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}` (default `oe-web-base:php8.4-noble`) | apt-gets `git`/`bzip2`/`unzip`, `ssh-keyscan github.com`, then `oe-checkout.sh` over `--mount=type=ssh`: clones openeyes at `BUILD_BRANCH` (mandatory), each `MODULES` entry + always `eyedraw` into `protected/modules/` (falling back to `DEFAULT_BRANCH`), inits submodules, strips `.git`, writes `$WROOT/buildinfo.txt` and `/config/modules.conf`. Writes `protected/config/cachebuster.txt` from `CACHEBUSTER` (or a timestamp). **Deletes `*openeyes-live.ini` from both the cli and apache2 `conf.d`** - the live php hardening blocks composer. Installs composer (pinned by `COMPOSER_VERSION` when set), then `composer update --no-dev --optimize-autoloader --prefer-stable` - **update, not install**: deps re-resolve at build time within composer.json constraints. Then `npm install --omit=dev --no-save` - **install, not ci**, so package-lock is not authoritative either - followed by an explicit puppeteer re-fetch (`rm -rf` the cache's `chrome`/`chrome-headless-shell`, then `node node_modules/puppeteer/install.mjs`) so both amd64 and arm64 get a real download. |
| 2 | `vite` | `node:alpine` | `COPY --from=deps ${WROOT}`, `NODE_ENV=development`, `mkdir -p ${WROOT}/assets`. Conditional: only if `package.json` has a `vite-build-only` script - `npm install --no-save && npm run vite-build-only`. No-op on branches without it, and both lines end `|| :` so a missing script never fails the build. |
| 3 | final | `${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}` | `COPY --from=deps --chown=www-data:www-data ${WROOT}` (everything), `COPY --from=vite ... ${WROOT}/assets` over it, `COPY --from=deps /config/modules.conf`; `php oe-laravel/artisan optimize` if present; bakes the runtime ENVs (incl. its own `OE_MODE="LIVE"`, `NODE_ENV=production`, `APP_ENV=production`), init scripts, profile.d, apache configs, local scripts, runs `55-create-folders.sh`, writes `/imageinfo.txt`, and sets a `HEALTHCHECK` that greps `OK` out of `/healthCheck`. |

The tree accretes across stages: source -> +vendor -> +node_modules/Chrome -> +built assets.

Stage 1's puppeteer install honours the repo's `.puppeteerrc.cjs`, so the Chrome cache lands in `$WROOT/protected/runtime/.cache/puppeteer` and any directory the rc creates on load exists at build time; stage 3's `COPY --chown=www-data:www-data` then ships the whole tree - cache included - owned by www-data. Live containers therefore never hit the dev-image trap of a root task creating `.cache` intermediates first (Web-Dev clones source at runtime, where whichever user runs node first sets the ownership).

## Cache behaviour

- `CACHEBUSTER` is an ARG of the **deps stage**, so changing it re-runs checkout, composer, npm and everything downstream. That is the only supported way to force a fresh checkout of the same branch (`--no-cache` works too, at the cost of the apt layers).
- Because deps uses `update`/`install` rather than lockfile-exact commands, a rebuild can ship different dependency versions - but only if the cache is busted; with a full cache hit nothing re-resolves.
- `--ssh default` is needed for the deps stage (and Manager's sample clone); without an SSH agent the build dies at checkout.

## Manager is not multi-stage

`Manager/dockerfile` is a single stage `FROM ${BASEIMAGE}:${OE_VERSION}` that clones the `sample` repo (at `BUILD_BRANCH`, default `OE_VERSION`, fallback master) and adds cron/maintenance wiring. It inherits everything else - including node_modules and Chrome - from the live image.
