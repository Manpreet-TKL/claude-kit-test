# Portainer Deployment

This document explains how the `feature/portainer` branch deploys Portainer + Traefik via Docker Swarm using the existing `oe-deploy` tooling. It walks through every script, file and command that gets run, in the order they get run, so an operator can follow along end-to-end.

## What you end up with

A single host running:

- **Docker Swarm** (single-node manager). Portainer needs swarm because it is deployed as a `docker stack`.
- **Traefik** stack (`portainer_tfk.yml`) terminating TLS on `:443`, redirecting `:80 → :443`, exposing a dashboard at `https://traefik.<PORTAINER_DOMAINNAME>` behind basic-auth.
- **Portainer** stack (`portainer.yml`) consisting of:
  - `portainer/portainer-ce` UI (replicated, manager-pinned), reachable at `https://portainer.<PORTAINER_DOMAINNAME>`.
  - `portainer/agent` (global, one per node) so Portainer can manage the swarm.
  - `nginx` "template" service serving `portainer/templates/templates.json` to the Portainer UI as the App Templates catalog.
- A small set of swarm secrets and bind-mount volumes for Portainer data and the templates JSON.

## Deployable inputs in this repo

| Path | Purpose |
| --- | --- |
| `.oedeploy` | `appName=portainer` is the trigger for everything below. |
| `templates/portainer.yml` | Stack definition for `portainer`, `agent`, `template` services. |
| `templates/portainer_tfk.yml` | Stack definition for `traefik`. Owns the external `proxy` overlay network. |
| `templates/openeyes.env` | Source `.env`. Portainer reuses the `openeyes.env` template (see `copy_env_file()` in `environment-setup.sh`). The portainer-specific block is at the bottom (`PORTAINER_*`, `PORTAINER_TEMPLATES`, `PORTAINER_DATA`, `PORTAINER_EMAIL_CONTACT`). |
| `portainer/templates/templates.json` | Bind-mounted into the `template` nginx container; Portainer reads it for App Templates. |
| `portainer/data/` | Bind-mounted into the `portainer` container as `/data` for its embedded DB. |
| `secrets/PORTAINER_ADMIN_PASSWORD` | Initial admin password loaded via `--admin-password-file` on first start. |
| `secrets/TRAEFIK_DASHBOARD_USERS` | htpasswd file for the Traefik dashboard. |
| `secrets/DATABASE_PASS` | Declared as a swarm secret on the traefik service (kept for compatibility with the shared template; not consumed by traefik command flags). |
| `secrets/sodium_crypto_key` | Promoted to the `SODIUM_CRYPTO_KEY` docker secret in `build.sh`. |

## End-to-end flow

The three deploy scripts each detect `appName=portainer` and switch their behaviour. The operator does not need to pass `-p` flags by hand — setting `appName=portainer` in `.oedeploy` is enough.

### 1. `.oedeploy`

Set `appName='portainer'`. This is the single switch that drives portainer-aware behaviour in the rest of the scripts.

### 2. `bash host-setup.sh`

Standard host bootstrap, plus:

- **Swarm detection.** After sourcing `.oedeploy`, the script forces `swarm=1` when `appName=portainer`. The same flag can be set by hand with `-s` / `--swarm`.
- **Swarm enablement.** `enableSwarmMode()` runs after the docker install/update step and is idempotent: it inspects `docker info --format '{{.Swarm.LocalNodeState}}'` and only calls `docker swarm init` if the node is not already active. This means re-running `host-setup.sh` (with or without `-ndu`) on a portainer host always converges on swarm being on.
- **Re-entry.** Running `host-setup.sh -ndu` on a portainer host is the supported way to ensure swarm is on without restarting docker.

After this step the host is in swarm mode with a single manager.

### 3. `bash environment-setup.sh`

After sourcing `.oedeploy` the script auto-promotes itself into portainer mode when `appName=portainer` (equivalent to passing `-p`). That triggers the `PORTAINER SETUP` block which:

1. Generates `secrets/sodium_crypto_key` (32-byte hex). Used by the `SODIUM_CRYPTO_KEY` docker secret created later by `build.sh`.
2. Asks for / detects the host IP (used in Keeper subfolder name only).
3. Generates `secrets/PORTAINER_ADMIN_PASSWORD` — consumed by Portainer on first launch via `--admin-password-file '/run/secrets/PORTAINER_ADMIN_PASSWORD'`.
4. Generates `secrets/TRAEFIK_DASHBOARD_USERS` (`htpasswd -nbB admin <pw>`, fallback to `openssl passwd -apr1`) — referenced from the traefik dashboard middleware via `usersfile:/run/secrets/TRAEFIK_DASHBOARD_USERS`.
5. Generates `secrets/DATABASE_PASS` — declared as a swarm secret on traefik (kept for parity with the shared template).
6. Writes the four passwords above into `${keeperFileNameOE}` under a `… - PORTAINER` subfolder for export to Keeper.
7. Copies `templates/openeyes.env` to `./.env` (portainer reuses the openeyes env template).
8. Creates `portainer/templates/` and `portainer/data/` if they do not exist, and verifies `templates/portainer.yml` and `templates/portainer_tfk.yml` exist.
9. Optionally `git secret`-encrypts and pushes secrets/.env to a `portainer/<client>` branch when `pushToGit=true`.

After this step the operator must hand-edit `.env` and fill in at minimum:

- `PORTAINER_DOMAINNAME` — the apex domain. Hostnames `portainer.<domain>` and `traefik.<domain>` must already resolve to this host so Let's Encrypt HTTP-01 can succeed.
- `PORTAINER_EMAIL_CONTACT` — Let's Encrypt registration email.
- `SERVICES=portainer` (or include `portainer` in the list) so the build-time check in `build.sh` passes.
- `PORTAINER_TEMPLATES` / `PORTAINER_DATA` — defaults to `${PWD}/portainer/templates` / `${PWD}/portainer/data`. Override only if you want to bind elsewhere.
- `TFK_TAG`, `PORTAINER_TAG`, `PORTAINER_AGENT_TAG`, `PORTAINER_TEMPLATES_TAG` — pinned image tags.

### 4. `bash build.sh -p` (the `-p` here is intentional)

`build.sh` still requires `-p` because `portainer` mode in build does extra work beyond just composing a yml. The check at the top fails if `-p` is set but `SERVICES` does not contain `portainer`, and vice-versa, so the two stay aligned.

The portainer code path runs:

1. **`portainerQuestions()`** — asks for paths to `ssh_deploy_key` (default `~/.ssh/id_rsa`) and `authorized_keys` (default `~/.ssh/authorized_keys`), then creates three docker swarm secrets if missing:
   - `ssh_deploy_key`
   - `ssh_authorized_keys`
   - `SODIUM_CRYPTO_KEY` (sourced from `secrets/sodium_crypto_key` written in step 3).

   These are docker-swarm-level secrets (created via `docker secret create`), not the file-based secrets under `secrets/`. They are intended for stacks deployed *through* Portainer (e.g. an OpenEyes stack template) rather than for portainer itself.

2. **`portainerUp()`** — deploys the two stacks. Both go through `docker compose … config | sed … | docker stack deploy -c -`:

   ```bash
   docker compose -f templates/portainer_tfk.yml --env-file .env config \
       | sed -E '/^name: /d; s/^( *published: )"([0-9]+)"/\1\2/' \
       | docker stack deploy -c - --detach --with-registry-auth traefik

   docker compose -f templates/portainer.yml --env-file .env config \
       | sed -E '/^name: /d; s/^( *published: )"([0-9]+)"/\1\2/' \
       | docker stack deploy -c - --detach --with-registry-auth portainer
   ```

   The `sed` strips `name:` (rejected by `docker stack deploy`) and unquotes published port numbers (compose v2 quotes them, swarm rejects strings).

3. The normal `composeUp()` path is **skipped** when `portainer=1`, and so is the Confluence post.

After this step:

- The `traefik` stack exists with the `proxy` overlay network attached and is bound to `:80`, `:443`, plus the auxiliary entrypoints listed in `portainer_tfk.yml` (`:8080`, `:8443`, `:2575`, `:11111-:11115`, etc.).
- The `portainer` stack exists. The agent runs globally; portainer talks to it via `tasks.agent:9001` over the `private` overlay network and is published only through Traefik (no host port).
- DNS for `portainer.<PORTAINER_DOMAINNAME>` and `traefik.<PORTAINER_DOMAINNAME>` should resolve to this host so the certificate resolver can issue.

## Stack details that are easy to miss

- **Networks.** `portainer_tfk.yml` is the *owner* of the `proxy` overlay network (`driver: overlay, attachable: true, name: proxy`). `portainer.yml` declares `proxy` as `external: true`. Therefore the traefik stack must be deployed first — which is exactly the order in `portainerUp()`.
- **Placement.** Both `portainer` and `traefik` are pinned to `node.role == manager`. `agent` is `mode: global`, so on a single-node setup all three end up on the same host.
- **Templates volume.** `portainer-templates` is a local bind volume pointing at `${PORTAINER_TEMPLATES:-/home/toukan/OE-Deploy/portainer/templates}`. Edit `portainer/templates/templates.json` on the host and restart the `template` service to refresh the App Templates catalog seen in the UI. The `portainer` service is started with `--templates http://template/templates.json` which resolves over the `private` network to the nginx container.
- **Admin password.** `--admin-password-file '/run/secrets/PORTAINER_ADMIN_PASSWORD'` only seeds the *initial* password. After first login the password lives in `portainer/data/portainer.db`, so changing the secret later has no effect — you must rotate inside the UI.
- **Traefik dashboard.** `traefik.http.middlewares.auth.basicauth.usersfile` reads from `/run/secrets/TRAEFIK_DASHBOARD_USERS`, which is the htpasswd file generated by `environment-setup.sh`. The Keeper export records the plaintext password used to build that file.
- **DATABASE_PASS.** Listed as a swarm secret on traefik but not consumed by any of its command flags. It exists so the same template structure can be reused; do not remove it without also removing the secret reference and the file generation in `environment-setup.sh`.

## Day-2 operations

- **Re-deploy after editing yml or .env**: rerun `bash build.sh -p`. `docker stack deploy` is converging, so it will only update the services that changed.
- **Tear down**: `docker stack rm portainer && docker stack rm traefik`. The bind volumes under `portainer/data/` and `portainer/templates/` survive.
- **Leave swarm**: `docker swarm leave --force`. Only do this if you also intend to re-run `host-setup.sh` to recreate the swarm.
- **Inspect**: `docker stack ps portainer` / `docker stack ps traefik`, `docker service logs portainer_portainer`, `docker service logs traefik_traefik`.
- **Rotate Portainer admin password**: do it from inside the UI. The file under `secrets/PORTAINER_ADMIN_PASSWORD` is only consulted on first start.
- **Rotate Traefik dashboard password**: regenerate `secrets/TRAEFIK_DASHBOARD_USERS` (`htpasswd -nbB admin <new>`), then `docker service update --secret-rm TRAEFIK_DASHBOARD_USERS --secret-add source=TRAEFIK_DASHBOARD_USERS traefik_traefik` (or simpler: `docker stack rm traefik && build.sh -p`).

## What `appName=portainer` does *not* do

- It does not deploy any application stacks (OpenEyes, openers, notes, …). Portainer is the management plane only; application stacks are added later either by importing them as Portainer stacks/templates or by SSH'ing in and running `docker stack deploy` directly.
- It does not configure DNS or certificates. Both depend on `PORTAINER_DOMAINNAME` resolving to this host before `portainerUp()` runs.
- It does not back up `portainer/data/`. That directory holds Portainer's embedded SQLite-equivalent DB and should be included in any host-level backup if the deployment is non-throwaway.
