# oe-deploy — per-app recipes (volatile)

The list of apps and the SERVICES/MODS each needs evolves. Always cross-check `templates/` and `.env.example` before assuming a service still exists or that its variables haven't been renamed.

## Apps and their recipes

| App        | `SERVICES`               | `MODS`            | Image tag var(s) | Notes |
|---         |---                       |---                |---               |---    |
| openeyes   | `db web`                 | _(none)_          | `OE_WEB_TAG`, `MASTER_TAG`, `BL_TAG` | Plain ref-app. Bridgelink is part of the stack. |
| notes      | `db notes`               | `tfk_only`        | `NOTES_TAG`      | TFK-only network band. No OE images. |
| openers    | `db web`                 | `tfk`             | `OE_WEB_TAG`, `MASTER_TAG`, `BL_TAG` | TFK internal OE. |

## What each template does

| Template               | Purpose |
|---                     |---      |
| `templates/db.yml`     | MariaDB service + named volume + my.cnf bind. |
| `templates/web.yml`    | OE web container + Apache. Anchor: `&web`. |
| `templates/notes.yml`  | The Notes app container. |
| `templates/tfk.yml`    | TFK overlay network band (production). |
| `templates/tfk_only.yml` | TFK-only band, no public exposure. |
| `templates/manager.yml`| OE Manager sidecar — present when `OE_MANAGER_TAG` is set. |
| `templates/master.yml` | OE Master cron container. |

## Image tag conventions (current)

- **OE web/manager RC tag casing** — lowercase `rc` suffix only (`v26.0.0-rc3`, not `v26.0.0-RC3`). Docker Hub is case-sensitive and the latter does not resolve.
- **BridgeLink** has no bare `4.6` tag. Pin a patch like `4.6.1` or you'll get a manifest-not-found at compose-time.
- **OpenMRS first boot is slow** — initial WAR deploy can take ~73 min on a monkey-spec host. Don't quote "5–10 min" to users; quote the real number.

## Adding a new app

1. Pick `SERVICES` and `MODS` from existing templates. Resist the urge to add a new template.
2. Add a stanza to `.env.example` documenting any new variables.
3. Add the app to `.oedeploy`'s allowed `appName` values in `build.sh`.
4. Update this table.
