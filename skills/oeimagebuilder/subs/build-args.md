# OEImageBuilder — build args (volatile)

Versions and defaults move every OE release. Cross-check `Dockerfile` and `build.sh` before quoting any of these.

## Current ARG set

| ARG                 | Default            | Used by         | Notes |
|---                  |---                 |---              |---    |
| `OS_VERSION`        | `noble`            | base            | `noble` (24.04) for v26; `jammy` (22.04) for v25.x and earlier. |
| `PHP_VERSION`       | `8.4`              | base            | v26 needs ≥8.4. v25 needed 8.2. |
| `BASE_IMAGE_NAME`   | `oe-web-base`      | live, dev, mgr  | Override only for fork builds. |
| `BASE_IMAGE_TAG`    | matches family tag | live, dev, mgr  | Pin so a base rebuild doesn't surprise children. |
| `OE_VERSION`        | `v26.0.0-rc3`      | live, dev       | Drives the git checkout. **lowercase rc**. |
| `BUILD_BRANCH`      | (unset)            | live, dev       | When set, builds from this branch instead of `OE_VERSION`. |
| `MODULES`           | core list          | live, dev       | Space-separated module repo names. |
| `WROOT`             | `/var/www/openeyes`| all             | Document root. Don't hardcode elsewhere. |
| `PROD_DEBUG`        | `FALSE`            | dev             | `TRUE` produces `oe-web-debug`, `FALSE` produces `oe-web-dev`. |
| `BUILD_SOURCE`      | `git`              | live, dev       | `git` (default) or `local` — see `subs/local-source.md`. |

## Tag conventions

- `oe-web-base:<os>` — e.g. `noble`, `jammy`. Doesn't carry an OE version because it has no OE.
- `oe-web-live:<oe-version>` — e.g. `v26.0.0-rc3`. **Lowercase `rc`.**
- `oe-web-dev:<oe-version>` and `oe-web-debug:<oe-version>` — same tag scheme as live.
- `oe-manager:<oe-version>` — must equal the `oe-web-live` tag for the same family.

## Adding a new ARG

1. Add to `Dockerfile` with a sensible default.
2. Echo into `/build-info.txt` so the image self-documents.
3. Add to this table.
4. Add to `build.sh` --help.
