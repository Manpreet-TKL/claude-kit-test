---
name: monkey-environment
description: monkey oe-deploy stack - browserless remote-chrome rendering (compose -f only, deletions revert on recreate), HTTP-only Traefik PathPrefix routing on :80, OpenMRS first boot ~73 min
metadata:
  type: project
---

The `monkey` instance's three defining quirks (merged 2026-07-19 from three memories).

## Remote chrome rendering (since 2026-06-09)

OpenEyes renders PDFs/lightning images with **zero node or chrome in the app containers**: a rewritten `DocumentRenderServicePuppeteer.php` (bind-mounted read-only from `/home/toukan/monkey/patches/`) curls browserless's `/function` API on the `chrome` service (ghcr.io/browserless/chromium:v2.33.0, token in docker-compose.yml, cpus 2 / mem 3g ring-fence). The puppeteer node packages and bundled Chrome were deleted from both running containers' writable layers. Full docs: `/home/toukan/monkey/remote-chrome.md`. Since 2026-06-10 the patch is the **unified dual-mode class**, byte-identical to `~/pullrequests/oe-pr-remote-puppeteer-browser/files/.../DocumentRenderServicePuppeteer.php`: upstream local launch() when `PUPPETEER_BROWSER_WS_ENDPOINT` is unset, remote HTTP when set, actionable exception when neither browser exists. Companion: `~/pullrequests/oeimagebuilder-pr-chromeless-web/` (PUPPETEER_SKIP_DOWNLOAD chrome-less images + docs/REMOTE_BROWSER_K8S.md).

Constraints that shape any change here:

1. Always `docker compose -f docker-compose.yml ...` - the pre-existing override.yml is a dev-image swap that would drop the patch mount.
2. The in-container deletions revert on container *recreate* (restart preserves them) - re-delete if the tripwire is wanted.
3. Editing the host patch with inode-replacing tools doesn't propagate - restart web/oe-manager after edits.
4. The class has a local fallback but monkey's containers can't use it (node packages deleted): chrome down means prints fail loudly.
5. oe-manager's Apache is `Require local`, so its `PUPPETEER_BASE_URL` is `http://web/`.

On any image tag bump, re-diff the patch against the new image's file. For print tests use event 3687000 (3686997 has no ElementLetter row and 500s in `getRecipients()` - pre-existing data quirk, not a regression). `docman_user` was fixed 2026-06-09 ([[oe-v26-resetuserlock-null-institution]]) and the lightning-image chain works end-to-end.

## Traefik: HTTP-only PathPrefix routing on :80

`templates/tfk.yml` runs Traefik stripped down: a single `web` entrypoint on `:80`, no `websecure`, no cert resolver, no Host rules; `traefik-files/traefik.yml` is the HTTP-only override (no `redirections.entryPoint` block, no `file` provider, dashboard insecure on `:8081`). Routers (Docker-provider labels in the respective service yaml):

- `oe` - PathPrefix `/` priority 1 -> `web:80` (label in `templates/tfk.yml`).
- `omrs-spa` - PathPrefix `/openmrs/spa` -> `omrs-frontend:80` via `omrs-spa-strip` StripPrefix middleware (label in `templates/omrs.yml`).
- `omrs-api` - PathPrefix `/openmrs` -> `omrs-backend:8080` (label in `templates/omrs.yml`).

Purpose: reach the stack from a laptop via the host's IP with no DNS or TLS - OE at `/`, the O3 SPA at `/openmrs/spa/home`, legacy OpenMRS UI at `/openmrs/login.htm`, one `http://HOST/...` origin so the SPA's same-origin API calls work. `DOMAIN_NAMES` in `.env` stays `` `oe.localhost` `` purely to satisfy `build.sh`'s backtick check - no router uses it. Don't reintroduce the upstream `tfk.yml` (bakes in `tls=true`, `hsts@file`, a `Host(${DOMAIN_NAMES})` rule). The `:81` (OE) and `:82` (OMRS backend) host-port publishes are kept as fallbacks; BridgeLink still owns `:8443`. Hardened-daemon prerequisite: [[traefik-min-api-fix]].

## OpenMRS first boot is slow

OpenMRS 3 ref-app backend first boot took **~73 minutes** (`Server startup in [4413944] ms`) - the WAR expands lazily, then Liquibase runs hundreds of changesets against the empty `openmrs` schema while the shared MariaDB also serves OE's own migrations. Don't quote "5-10 minutes"; don't busy-poll. Tail `docker logs -f monkey-omrs-backend-1` for `Deployment of web application archive [...openmrs.war] has finished` then `Starting ProtocolHandler ["http-nio-8080"]`. Subsequent restarts (WAR already expanded on the data volume) come up in seconds. Bare `/openmrs/` returns `{}` from the REST root - the legacy UI lives at `/openmrs/login.htm`.
