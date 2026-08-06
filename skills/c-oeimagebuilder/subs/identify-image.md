# Identifying which image you are in

Four images can be serving OpenEyes, and code sometimes needs to know which. The useful
distinction is usually **frozen or not**: `oe-web-live` and `oe-manager` bake a checkout
at build time and strip `.git`, so nothing about the code or the schema can change
without a redeploy. `oe-web-dev` clones at runtime into a live git tree. The
production-debug image is a third case - frozen code, but deliberately labelled as dev.

`DOCKER_CONTAINER` does **not** answer the question. `Web-Base/dockerfile:50` sets
`DOCKER_CONTAINER="TRUE"`, so every image inherits it, dev included.

## Signal matrix

Verified against locally built `v26.1.0-pre2` images of all four types.

| Signal | oe-web-live | oe-manager | oe-web-dev | prod-debug (`PROD_DEBUG=TRUE`) |
|---|---|---|---|---|
| `/imageinfo.txt` prefix | `oe-web-live. ` | `oe-manager-` | `oe-web-dev. ` | `DEBUG-` |
| `/oe-build-dev.sh` | absent | absent | present | present |
| `/init_scripts/42-clone-source.sh` | absent | absent | present | absent |
| `/dev_init_scripts/` | absent | absent | absent | present |
| `/init_scripts/85-migrate-up.sh` | absent | present | absent | absent |
| `OE_MODE` | `LIVE` | `LIVE` | `DEV` | `DEV` |
| `PROD_DEBUG` | unset | unset | `FALSE` | `TRUE` |
| `OE_VERSION` | set | set | **unset** | set (inherited) |
| `$WROOT/buildinfo.txt` | present | present | absent | present |
| `$WROOT/.git` in the **image** | absent | absent | absent | absent |
| `$WROOT/.git` in a **running** container | absent | absent | **present** | absent |
| `DOCKER_CONTAINER` | `TRUE` | `TRUE` | `TRUE` | `TRUE` |

The `.git` row is the one that catches people: the dev image ships an empty `WROOT` and
clones at container start, so the image and the running container disagree. Test it in a
running container or not at all.

## The recipe

`/imageinfo.txt` is the only marker that separates all four types on its own, and it is
an intentional one - `subs/build-args.md` records the convention that an arg changing
what the image *is* gets appended to that line. It sits at `/`, root-owned 0644, outside
any mount point, so a bind-mounted `$WROOT` cannot mask it and no compose setting can
forge it. `protected/views/site/debuginfo.php` already reads it under mod_php.

```php
$info = @file_get_contents('/imageinfo.txt') ?: '';
$is_frozen = !file_exists('/oe-build-dev.sh')
    && (str_starts_with($info, 'oe-web-live.') || str_starts_with($info, 'oe-manager-'));
```

Match the **prefix**, never the whole string - the line ends with a version and a build
date, and the convention is to keep appending build args to it.

Without starting a container:

```
docker image inspect <image> --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E 'OE_MODE|PROD_DEBUG|OE_VERSION'
docker run --rm --entrypoint /bin/sh <image> -c 'cat /imageinfo.txt; ls /oe-build-dev.sh /dev_init_scripts 2>&1'
```

`--entrypoint /bin/sh` matters: without it the init scripts run and a dev image starts
cloning OpenEyes.

## Gotchas

- **`OE_MODE` is a deployment label, not a statement about frozen code.**
  `Web-Base/dockerfile:79` sets `OE_MODE="LIVE"`, so anything built from base inherits
  `LIVE` unless it overrides - detection by `OE_MODE` alone is fail-live at the image
  layer even though the application code treats anything-but-`live` as dev. In the other
  direction `Web-Dev/dockerfile:41` sets `OE_MODE="DEV"` unconditionally, so a
  production-debug image built from a live tag reports `DEV` despite carrying frozen
  code. For a runtime decision that only needs "is this a production deployment",
  `OE_MODE` is still the right lever and the one the application already uses; for "is
  the code frozen", use the recipe above.
- **Frozen code does not imply a frozen database.** `oe-manager` is `OE_MODE=LIVE` and
  is the container that runs migrations (`Manager/init_scripts/85-migrate-up.sh` at
  boot), against a database other containers share.
- **Do not trust the banner.** `Web-Base/init_scripts/00-banner.sh:25` compares
  `${OE_MODE^^}` against a string with a stray `U+2763 U+FE0F` emoji prefix, so the live
  branch is unreachable and every image banners as `DEVELOPMENT MODE`.
- **`oe-web-dev` has no `OE_VERSION`**, because it has no baked checkout to version. Any
  code that reads `OE_VERSION` for display or API headers gets an empty value there.
