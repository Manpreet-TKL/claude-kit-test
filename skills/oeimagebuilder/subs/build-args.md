# Build args — per image

ARG names, defaults and meaning, as declared in each `dockerfile`. Defaults move with the repo; when in doubt, `grep '^ARG' <folder>/dockerfile` is the source of truth.

## Web-Live (`oe-web-live`)

| ARG | Default | Meaning |
|---|---|---|
| `BUILD_BRANCH` | *(none — mandatory)* | OE branch/tag to clone; `oe-checkout.sh` aborts without it |
| `DEFAULT_BRANCH` | `master` | Fallback when a module repo lacks `BUILD_BRANCH` |
| `GIT_REPO_BASE` | `git@github.com:openeyes` | Org/base for all clones (point at a fork to build from one) |
| `MODULES` | `""` | Extra module repos to clone into `protected/modules/` — comma **or** space separated; `eyedraw` is always added |
| `OE_VERSION` | *(none)* | Display/version string only — baked into ENV + `/imageinfo.txt`; does **not** drive the checkout (that's `BUILD_BRANCH`) |
| `PHP_VERSION` | `8.4` | Picks the composer-stage image and the base-image tag |
| `OS_VERSION` | `noble` | Half of the base-image tag |
| `BASE_IMAGE_NAME` | `toukanlabsdocker/oe-web-base` | Final-stage base |
| `BASE_IMAGE_TAG` | `php${PHP_VERSION}-${OS_VERSION}` | Final-stage base tag |
| `NODE_MAJOR_VERSION` | `24` | npm-stage node image major |
| `NODE_DEBIAN_VERSION` | `trixie` | npm-stage node image debian flavour |
| `CACHEBUSTER` | *(unset → build timestamp)* | Busts cache from the git stage onward; the value lands in `protected/config/cachebuster.txt` so all instances of one image share an asset cache key |
| `WROOT` | `/var/www/openeyes` | Document root, threaded through every stage |

## Web-Dev (`oe-web-dev` / debug)

| ARG | Default | Meaning |
|---|---|---|
| `BASE_IMAGE_NAME` | `toukanlabsdocker/oe-web-base` | Set to `toukanlabsdocker/oe-web-live` for a debug build |
| `BASE_IMAGE_TAG` | `latest` | Base tag; for debug builds, the live tag being debugged |
| `PROD_DEBUG` | `FALSE` | `TRUE` = production debug image (code from the live base, oe-fix + puppeteer re-install run); `FALSE` = dev image (no code — mounted from host) |
| `BUILD_BRANCH` | `develop` | Recorded in imageinfo for debug builds |
| `CYPRESS_VERSION` | `12.17.4` | **Pinned** — last version the currents.dev mirror serves for linux-arm64; do not bump without re-checking arm64 availability (see the dockerfile comment) |
| `PLAYWRIGHT_VERSION` | `1.55.0` | Skipped automatically when the base's node is < 18 |
| `COMPOSER_VERSION` | *(unset → latest)* | Pin the composer install if needed |
| `CACHEBUSTER` | `202207151548` | Cache bust |
| `WROOT` | `/var/www/openeyes` | Document root |

## Web-Base (`oe-web-base`)

| ARG | Default | Meaning |
|---|---|---|
| `OS_IMAGE` | `ubuntu` | Base OS image |
| `OS_VERSION` | `jammy` | OS tag (CI builds newer; the dockerfile default lags) |
| `PHP_VERSION` | `8.3` | PHP to install (CI builds newer; ditto) |
| `BUILD_NODE_MAJOR_VERSION` | `20` | Node major installed in the image |
| `TIMEZONE` | `Europe/London` | System TZ |
| `BUILD_WROOT` | `/var/www/openeyes` | Document root |
| `APT_ONDREJ_PHP_KEY` / `APT_ONDREJ_APACHE_KEY` / `APT_OLD_NODE_KEY` / `APT_NODE_KEY` | *(pinned ids)* | APT signing keys — only change when a repo rotates keys |

Result is tagged `php<ver>-<os>`, e.g. `php8.4-noble` — never with an OE version.

## Manager (`oe-manager`)

| ARG | Default | Meaning |
|---|---|---|
| `BASEIMAGE` | `toukanlabsdocker/oe-web-live` | The live image to extend |
| `OE_VERSION` | *(none — effectively mandatory)* | The live tag to build `FROM`; pair the manager tag with it |
| `BUILD_BRANCH` | `${OE_VERSION}` | Branch of the `sample` repo to clone (falls back to master if absent) |
| `GIT_REPO_BASE` | `openeyes` | GitHub org for the sample clone |

## Aws-Cli

`OS_IMAGE` (`ubuntu`), `OS_VERSION` (`jammy`), `TIMEZONE` (`Europe/London`). Standalone utility image.

## Adding a new ARG — checklist

1. Declare it at the top of the dockerfile with its default, **and re-declare it after every `FROM` whose stage uses it** (multistage scoping — an ARG silently evaluates empty in stages that don't re-declare it).
2. If runtime code needs it, echo it into an `ENV` in the stage(s) where it matters.
3. Add a row to the image's **`README_template.md`** build-args table (never `README.md` — CI regenerates that).
4. If the arg changes what the image *is* (contents, capability), record it in the `/imageinfo.txt` line so a built image is identifiable, e.g. `${MYARG:+ MYARG=${MYARG}.}`.
