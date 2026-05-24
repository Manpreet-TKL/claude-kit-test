# OEImageBuilder — the 5-stage oe-web-live build (volatile)

`oe-web-live` is built as a multi-stage Dockerfile so that the final image carries only the runtime artifacts, not the toolchains used to produce them.

## The stages

| # | Stage     | FROM                  | What it does                                       | What it exports |
|---|---        |---                    |---                                                 |---              |
| 1 | `git`     | `alpine/git`          | Clones OpenEyes + each module in `MODULES`         | `/src` |
| 2 | `composer`| `composer:2`          | `composer install --no-dev --optimize-autoloader`  | `/src/vendor` |
| 3 | `npm`     | `node:22-alpine`      | `npm ci` in the asset workspace                    | `/src/node_modules` |
| 4 | `vite`    | `node:22-alpine`      | `npm run build` → compiled assets                  | `/src/protected/assets/dist` |
| 5 | `final`   | `oe-web-base:${OS}`   | `COPY --from=…` of just the needed paths           | the actual image |

The final stage **does not contain** git, composer, npm, node, or the build caches. That's the point.

## Cache implications

- `git` stage uses `--depth 1` keyed on `OE_VERSION` or `BUILD_BRANCH`. Changing either invalidates from stage 1.
- `composer` stage caches on `composer.json` + `composer.lock`. Editing a non-dependency file in `src/` does **not** bust composer.
- `npm` stage caches on `package-lock.json`. Same logic.
- `vite` stage rebuilds whenever any frontend source changes.
- `final` stage rebuilds whenever any earlier stage's exports change, or `oe-web-base` is repulled.

## Common rebuild mistakes

- **Editing PHP and seeing the old code in the image** — you probably didn't bust stage 1. Bump `OE_VERSION` (or use `BUILD_BRANCH=…`) so the git clone re-runs.
- **`npm install` instead of `npm ci`** — don't. CI mode is required so the lockfile is authoritative and the build is reproducible.
- **Skipping the vite stage with `BUILD_ASSETS=false`** — there is no such flag. If assets aren't being built, look at why stage 4 is failing, don't add a bypass.

## Final-stage layout (current)

```
/var/www/openeyes/             # WROOT
├── protected/                 # OpenEyes app code (from stage 1)
│   ├── modules/               # built-in + clinical modules
│   └── assets/dist/           # compiled assets (from stage 4)
├── vendor/                    # composer deps (from stage 2)
└── /etc/apache2/sites-enabled/openeyes.conf
```

`node_modules` are intentionally **not** copied into the final image.
