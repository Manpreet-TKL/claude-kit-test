# notes — pinned stack (volatile)

These versions move. Re-check against `src/composer.json`, `src/package.json`, `Dockerfile`, and `oe-deploy/templates/notes.yml` before assuming.

| Layer        | Version                | Notes |
|---           |---                     |---    |
| OS (host)    | Ubuntu 24.04 noble     | matches `oe-web-base:noble` |
| OS (image)   | Ubuntu 24.04 noble     | base image for the notes container |
| PHP          | 8.5                    | Composer plays nicely with 8.5; CI runs on 8.5 |
| Laravel      | 13.x                   | calendar-versioned |
| HTTP server  | Apache 2.4 (mpm-event) | not nginx; `.htaccess` is honoured |
| DB           | MariaDB 11.8           | InnoDB; `utf8mb4_general_ci`; case-insensitive LIKE |
| Cache/queue  | none                   | sync queue; APCu only as opcode cache, not data |
| JS runtime   | Node 22 LTS            | only at build time, for Vite |
| Frontend     | Alpine.js 3, Tailwind 3, Blade | no React/Vue/SPA |
| Build tool   | Vite 5                 | `npm run build` produces `public/build/` |
| Containers   | docker compose         | image is `toukanlabsdocker/notes:<tag>` |

## Container runtime

- `php artisan` is invoked through the image's entrypoint, not via `sh -l -c`.
- OPcache: `validate_timestamps=0` in prod, `=1` in dev. Production deploys must restart php-fpm or hit `opcache_reset()`.
- Sessions are file-based and live in a named volume so a container restart preserves logins.
