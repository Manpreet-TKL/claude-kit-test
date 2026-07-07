---
name: oe-monkey-traefik-http-only
description: "On the monkey oe-deploy stack, Traefik runs HTTP-only on :80 with PathPrefix routing (no DNS, no TLS). OE owns `/`, OpenMRS SPA owns `/openmrs/spa/*`, OpenMRS backend owns `/openmrs/*`."
metadata: 
  node_type: memory
  type: project
  originSessionId: 4fa032d4-fe44-4ce5-b660-811da2ca7318
---

The `monkey` instance runs Traefik (`templates/tfk.yml`) in a stripped-down config: a single `web` entrypoint on `:80`, no `websecure`, no cert resolver, no Host rules. Routing is purely by `PathPrefix`. `traefik-files/traefik.yml` is the HTTP-only override - no `redirections.entryPoint` block, no `file` provider, dashboard exposed insecurely on `:8081`.

Routers (Docker-provider, labels in the respective service yaml):
- `oe` - `PathPrefix(`/`)` priority 1 -> `web:80` (label lives in `templates/tfk.yml`).
- `omrs-spa` - `PathPrefix(`/openmrs/spa`)` -> `omrs-frontend:80` via `omrs-spa-strip` (StripPrefix `/openmrs/spa`) middleware (label in `templates/omrs.yml`).
- `omrs-api` - `PathPrefix(`/openmrs`)` -> `omrs-backend:8080` (label in `templates/omrs.yml`).

**Why:** the user wants to reach the stack from a laptop via the host's IP without setting up DNS or a TLS cert. PathPrefix on a single HTTP entrypoint serves OE at `/`, the O3 SPA at `/openmrs/spa/home`, and the legacy OpenMRS UI at `/openmrs/login.htm`, all on the same `http://HOST/...` origin so the SPA's same-origin API calls work. `DOMAIN_NAMES` in `.env` is left as `` `oe.localhost` `` purely to satisfy `build.sh`'s backtick check - it isn't used by any router.

**How to apply:** When working on `monkey`, treat `:80` as the unified entrypoint and don't reintroduce the upstream `tfk.yml` (which bakes in `tls=true`, the `hsts@file` middleware, and a `Host(${DOMAIN_NAMES})` rule for OE). The `:81` (OE) and `:82` (OMRS backend) host-port publishes are kept as fallbacks; once the user is happy with Traefik they can be removed. BridgeLink still has its own `:8443`. Related: [[traefik-min-api-fix]], [[openmrs-first-boot-long]].
