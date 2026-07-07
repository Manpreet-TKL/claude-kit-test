---
name: traefik-min-api-fix
description: "Traefik < v3.6 talks to the Docker socket at API v1.24 by default; modern daemons reject that - fix by lowering the daemon's `min-api-version` floor, not by swapping Traefik/proxying."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4fa032d4-fe44-4ce5-b660-811da2ca7318
---

When wiring Traefik into an oe-deploy stack (`SERVICES=...tfk...`) and the docker provider logs `Error response from daemon: client version 1.24 is too old. Minimum supported API version is 1.40`: **do not** try to fix it by upgrading Traefik to a newer tag, by setting `DOCKER_API_VERSION` in the container env, or by introducing a docker-socket-proxy. The team has converged on a different fix.

**Fix:** lower the Docker daemon's accepted API floor to 1.24 by writing `{"min-api-version":"1.24"}` into `/etc/docker/daemon.json` and restarting `docker`. There's a `minApiFix()` helper in an open PR (gated on `TFK_TAG < v3.6`) that does this automatically - call/run that, don't reinvent it.

**Why:** Traefik's docker client through v3.5.x defaults to the legacy Docker SDK version 1.24 and does not honour `DOCKER_API_VERSION` in env. Daemons hardened with a higher `min-api-version` reject the ping. v3.6+ negotiates properly; until then the daemon floor is the chosen workaround. Sticking to upstream Traefik tags also means we don't fork on per-host quirks.

**How to apply:** Whenever you add `tfk` to `SERVICES` on a host with a hardened daemon, run the PR's `minApiFix` (or apply the same JSON merge + `systemctl restart docker` by hand) **before** expecting Traefik to discover containers. Watch for it as a regression if you later bump the daemon's hardening config. Drop the floor once `TFK_TAG` moves to `v3.6+`. Related: [[oe-monkey-traefik-http-only]].
