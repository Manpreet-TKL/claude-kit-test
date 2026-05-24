---
name: oe_components
description: Runtime components inside an OpenEyes deployment — the containers (web, oe-manager, db, redis, master, traefik) and what runs inside them (Apache, PHP-FPM, Puppeteer, TCPDF, Horizon, ClamAV, TinyMCE asset bundle). Invoke explicitly when reasoning about what's running on a host or debugging an integration between services. Volatile detail (current tags, ports, named volumes) lives in subs/.
disable-model-invocation: true
---

# OpenEyes runtime components

OpenEyes is a multi-container stack. `oeimagebuilder` builds the images, `oe-deploy` assembles and runs them. This skill is about **what's actually executing inside the running containers** and how they communicate.

## The container set

```
                       ┌──────────────────────────────┐
                       │ traefik (HTTP reverse proxy) │
                       │   :80 → /openmrs, /, …       │
                       └───────────────┬──────────────┘
                                       │
        ┌──────────────┐               │            ┌─────────────────┐
        │  oe-manager  │◄──────────────┼───────────►│      web        │
        │  (sidecar)   │               │            │  (Apache+PHP)   │
        └──────┬───────┘               │            └────┬────────────┘
               │                       │                 │
               │                       │                 │
        ┌──────▼───────┐        ┌──────▼──────┐    ┌─────▼─────────┐
        │   master     │        │    redis    │    │      db       │
        │  (cron jobs) │        │ (queue+cache)│   │   (MariaDB)   │
        └──────────────┘        └─────────────┘    └───────────────┘
```

| Container       | Image                                 | What it runs |
|---              |---                                    |---           |
| `web`           | `toukanlabsdocker/oe-web-live:<tag>`  | Apache 2.4 (mpm-event) + PHP-FPM 8.4. Serves all HTTP. |
| `oe-manager`    | `toukanlabsdocker/oe-manager:<tag>`   | Same Apache+PHP as `web` (built `FROM oe-web-live`); used for admin/manager UIs and offloaded ops. Tag must match `web`. |
| `master`        | `toukanlabsdocker/oe-master:<tag>`    | Cron container — runs the scheduled `yiic` commands (worklists, correspondence email, cleanup, …). |
| `db`            | `mariadb:<pinned>`                    | MariaDB 11.x. Named volume `db_data`; `my.cnf` bind-mounted. |
| `redis`         | `redis:<pinned>`                      | Queue backend + APCu-augment cache. |
| `traefik`       | `traefik:<pinned>`                    | HTTP reverse proxy. **HTTP-only on monkey**, PathPrefix routing — no DNS, no TLS. |
| `notes` (notes recipe only) | `toukanlabsdocker/notes:<tag>` | The ToukanNotes app. |
| `bridgelink`    | `nextgenhealthcare/bridgelink:<patch>` | Mirth-fork integration engine. **Pin a patch (`4.6.1`), not `4.6`** — bare `4.6` doesn't exist. |

For per-host tags, image-pull pitfalls, and the deployment-time `SERVICES`/`MODS` recipes, see the `oe-deploy` skill.

## Inside the web container

| Component              | Purpose | Source |
|---                     |---      |---     |
| Apache 2.4 (mpm-event) | HTTP server. `index.php` is the only entry. | `oeimagebuilder` base layer |
| PHP-FPM 8.4            | Request handler. OPcache `validate_timestamps=0` in prod. | base layer |
| APCu                   | Config cache (`oe_merged_config_*`) and Yii cache when present. | base layer |
| HTMLPurifier           | Pre-Yii bootstrap (workaround for OE-13296 class-loader clash). | composer |
| TCPDF / FPDF / FPDI    | PDF generation (letters, CVI certs). | composer |
| Puppeteer (puphpeteer) | HTML-to-PDF letter rendering via `DocumentRenderServicePuppeteer`. Headless Chromium ships in the image. | composer + image |
| TinyMCE                | Letter-body editor. Config in `params.tinymce_default_options`. | npm/Vite asset |
| Eyedraw                | SVG eye-anatomy drawing. JS lib + Yii module under `protected/modules/eyedraw/`. | repo |
| ClamAV (`xenolope/quahog`) | Optional virus-scanning of uploads when `OE_ENABLE_VIRUS_SCANNING=true`. | composer + clamd sidecar |
| SAML / OAuth2 / OIDC   | `onelogin/php-saml`, `league/oauth2-client`, `jumbojett/openid-connect-php`. Config in `params.SAML_settings` / `params.OIDC_settings`. | composer |
| Vite-built assets      | TypeScript + Tailwind for the modern UI under `shared/` and module `assets/`. | image stage 4 |

## Queues and async work

- `asyncJobDispatcher` resolves to `database` queue (table) when `QUEUE_CONNECTION` is unset, or `redis` when `QUEUE_CONNECTION=redis`.
- **Laravel Horizon** runs against the Redis queue when enabled. It is a Laravel-sidecar concern (`./oe-laravel/artisan horizon`).
- Yii-native batch jobs run in the `master` container via cron (see `subs/cron.md`).
- `event_export_location` is a bind-mount path for outbound NOD / analytics deliveries.

## Storage

- **MariaDB data**: named volume `db_data`. Survives container restart.
- **Letter PDFs / event images / DICOM**: `event_images/`, `protected/files/`, `DicomFiles` — bind-mounted to the host so they survive image upgrades.
- **`FileStorage` module**: pluggable backend (local FS, S3) used by document/letter modules.
- **`cachebuster.txt`**: in `protected/config/`, not git-tracked. Asset-URL cache key. Regenerated by deploy script.
- **`OE_COOKIE_VALIDATION_KEY`**: env var or `/run/secrets/OE_COOKIE_VALIDATION_KEY`. Required.
- **DB credentials**: three sources in order — `/etc/openeyes/db.conf` (pre-docker INI), `DATABASE_*` env, `/run/secrets/DATABASE_*`. Same dance for `$db_test`.

## Routing on the monkey demo box (per memory)

monkey runs Traefik HTTP-only on `:80` with PathPrefix routing:

- `/` → OE web container
- `/openmrs/spa` → SPA (strip prefix)
- `/openmrs` → OpenMRS backend

No DNS, no TLS. OpenMRS first-boot is genuinely ~73 min on first WAR deploy on monkey — don't quote "5–10 min". Legacy OpenMRS UI lives at `/openmrs/login.htm`; bare `/openmrs/` returns `{}` from the REST root.

## Traefik < 3.6 daemon-API fix (per memory)

Traefik versions before v3.6 need the Docker daemon's `min-api-version` lowered to `1.24` in `/etc/docker/daemon.json`. The deploy PR's `minApiFix()` does this. **Don't swap the Traefik tag**, don't add a socket proxy.

## Where the volatile detail lives

- `subs/cron.md` — current scheduled `yiic` commands (worklists, correspondence email, …) running in the `master` container.
- `subs/env-vars.md` — environment variables OE expects (`OE_MODE`, `OE_FORCE_YIILITE`, `QUEUE_CONNECTION`, `LOG_TO_BROWSER`, `OE_ENABLE_VIRUS_SCANNING`, `DATABASE_*`, etc.).
