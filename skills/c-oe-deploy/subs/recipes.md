# oe-deploy - per-app recipes (volatile)

The list of apps and the SERVICES/MODS each needs evolves. Always cross-check `templates/` and the per-app `templates/<app>.env` before assuming a service still exists or that its variables haven't been renamed. Snapshot below taken against the `cat` checkout (appName=openeyes, MASTER_TAG 26.0.0).

## The recipe lives in `.env` (copied from `templates/<appName>.env`)

Four space-separated lists, each mapping to a template path:

| List          | Path it expands to                |
|---            |---                                |
| `SERVICES`    | `templates/<svc>.yml`             |
| `MODS`        | `templates/modules/<mod>.yml`     |
| `HEALTHCHECKS`| `templates/healthchecks/<svc>.yml`|
| `AWSLOGS`     | `templates/awslogs/<svc>.yml`     |

`build.sh` builds a `-f ...` string from all four and runs `docker compose ... config`.

## Apps and their recipes (cross-check before trusting)

| App      | `SERVICES`                       | `MODS` | DB-pass secret file | Notes |
|---       |---                               |---     |---                  |---    |
| openeyes | `db web`                         | _(none)_ | `secrets/DATABASE_PASS` | Plain ref-app. `oe-manager` ships inside `web.yml`. Mirth/BridgeLink is optional (`mc`/`mcbl`), not in the base stack. |
| notes    | `db notes tfk`                   | _(none)_ | `secrets/DB_PASSWORD`   | Uses the real `tfk` service, not the `tfk_only` mod. No OE images. |
| openers  | `db mc-ers ers min tfk-ers cla`  | _(none)_ | `secrets/DB_PASSWORD` (+ `OPENERS_DATABASE_PASS`) | WIP recipe: `mc-ers ers min tfk-ers cla` have **no** matching `templates/*.yml` in this checkout - it will not render as-is. |

## What each template does

Service fragments (`templates/<svc>.yml`):

| Template      | Service(s) / purpose |
|---            |---      |
| `db.yml`      | MariaDB + named data volume + `my.cnf.d` bind. Anchor for the db service. |
| `db2.yml`     | Second MariaDB container (`-db2` in db-setup). |
| `mys.yml`     | MySQL container instead of MariaDB (`-mys`). |
| `web.yml`     | `web` (anchor `&web`, image `toukanlabsdocker/oe-web-live`) **and** `oe-manager` (`<<: *web`, image `toukanlabsdocker/oe-manager`). No separate manager/master template. |
| `mc.yml`      | NextGen Connect (Mirth) container - service name `mc`. |
| `mcbl.yml`    | BridgeLink drop-in for `mc` - `innovarhealthcare/bridgelink:${MIRTH_IMAGE_TAG}`. Set `MIRTH_SSL=false`, `MIRTH_PKRET=true`, `VMOPTIONS=-Xmx512m`. |
| `notes.yml`   | The Notes app container. |
| `iol.yml`     | IOL Master - import DICOM to OE. |
| `pay.yml`     | Payload Processor (image processing). |
| `pen.yml`     | Pentaho data-migration pipelines. |
| `red.yml`     | Redis cache. |
| `rmq.yml`     | RabbitMQ. |
| `rtf.yml`     | RTF document conversion. |
| `sig.yml`     | Signature processor. |
| `ss.yml`      | MS SQL Server container. |
| `tfk.yml`     | Traefik reverse proxy (public frontend). |
| `tfk_only.yml`| Traefik network band only, no public exposure. |
| `whi.yml`     | Whiskers monitoring. |
| `bkp.yml`     | Backup features on oe-manager (local DB only). |
| `portal.yml`  | Optometry portal (Laravel). |
| `du_pay.yml`  | Document-upload payment helper. |
| `aws.yml`     | AWS CLI sidecar for S3 sync. |
| `dev.yml` / `debug.yml` | Dev / xdebug variants of web. |

Mods (`templates/modules/<mod>.yml`) overlay extra env/config onto `web`: `apache`, `cito`, `cocoa`, `csd`, `debug`, `dev`, `hie`, `international`, `mailer`, `optom`, `pfbackup`, `tfk`, `wcrs`, `worklist`.

## mc / BridgeLink ports (host vs container)

Container-side ports in `mc.yml` are fixed: `8443` admin UI, `11112` DICOM, `6661` PAS IN, plus the channel port(s) `MIRTH_PORTS` (default `6660`, range allowed - deployed channels listen on fixed container ports, mostly `6661`/`6662`). To move a **host** port use the host-side variables (pending merge): `MC_ADMIN_PORT`, `MC_DICOM_PORT`, `MC_PAS_PORT`, `MIRTH_HOST_PORTS` (defaults to `${MIRTH_PORTS}`). Never remap `MIRTH_PORTS` itself to dodge a busy host port - that moves the container side the channels are deployed against.

If `MIRTH_PORTS` is a range, `MIRTH_HOST_PORTS` must be a range of **equal length**: docker maps equal-length ranges pairwise in order (first host port -> first container port, and so on), and refuses unequal lengths at container create ("invalid ranges specified for container and host Ports").

## Image tag conventions (current)

- `MASTER_TAG` (e.g. `26.0.0`) is the umbrella - `OE_WEB_TAG`, `OE_MANAGER_TAG`, `OE_RTF_TAG`, `IOL_MASTER_IMPORT_TAG`, `PAYLOAD_IMAGE_TAG`, `SIGNATURE_PROCESSOR_TAG` all default to `${MASTER_TAG}`. There is **no** `BL_TAG`.
- **Mirth / BridgeLink** is `MIRTH_IMAGE_TAG` (default `4.6.1`). There's no bare `4.6` tag - pin a patch.
- **DB** is `DB_IMAGE`/`DB_TAG` (default `mariadb`/`11.8`); **Traefik** is `TFK_TAG` (`v3.6`).
- **RC tag casing** - lowercase `rc` only (`v26.0.0-rc3`, not `-RC3`); Docker Hub is case-sensitive.
- **OpenMRS first boot is slow** - initial WAR deploy can take ~73 min on a monkey-spec host. Quote the real number.

## Adding a new app

1. Pick `SERVICES`/`MODS` from existing templates. Resist adding a new template.
2. Create `templates/<app>.env` documenting all its variables (build.sh diffs `.env` against it).
3. Add the app to the allowed `appName` values / per-app branches in `environment-setup.sh` and `db-setup.sh`.
4. Update this table.
