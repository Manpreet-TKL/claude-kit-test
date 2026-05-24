# oe-deploy — first-run on a fresh host (volatile)

This is the **current** sequence. Steps move when env-setup flags change or a new gate is added. If something in here disagrees with `env-setup.sh --help` or `build.sh --help`, the script is the source of truth — update this file.

## Prerequisites (Manpreet's hosts already have these)

- Docker installed and `docker login` done against `toukanlabsdocker`.
- GPG keys for any encrypted env material.
- `host-setup.sh` previously run (firewall, dirs, timezone).

Don't re-run any of the above on a Manpreet-provisioned host.

## The sequence

```bash
# 1. Rename the checkout (NEVER cp)
mv oe-deploy <env>
cd <env>

# 2. Set the appName so gates pick the right templates
$EDITOR .oedeploy        # set: appName=openeyes | notes | openers

# 3. Generate .env from template, non-interactively, no pull
./env-setup.sh -y -ndp
#                ^^  -y     : assume yes to non-destructive prompts
#                    -ndp   : no docker pull (you pull explicitly later)

# 4. Pin image tags + set the boring required vars
$EDITOR .env
#   OE_WEB_TAG=v26.0.0-rc3        # lowercase rc, see SKILL.md
#   MASTER_TAG=v26.0.0-rc3
#   BL_TAG=4.6.1                  # bare 4.6 doesn't exist
#   NOTES_TAG=…                   # if notes
#   DOMAIN_NAMES=`example.tfk.io,example2.tfk.io`   # backticks!
#   TZ=Europe/London

# 5. Pick a my.cnf variant (don't edit in place)
cp templates/my.cnf.sample my.cnf

# 6. Drop seed CSVs you don't want
rm seed_*.csv      # safe if you're not seeding from CSV

# 7. DB setup
./db-setup.sh

# 8. Assemble compose + bring everything up
echo yes | ./build.sh
```

After step 8, `docker compose ps` should show every service `Up (healthy)` within a few minutes — **except** OpenMRS, which legitimately takes ~73 min on its first WAR deploy on a monkey-spec host. Don't kill it.

## Seeding fallback (when `oemig` alias isn't on PATH)

Inside the web container, `oemig` is a shell alias. Aliases don't survive `docker compose exec sh -c …` — and `sh -l -c …` doesn't expand them reliably either. Use `bash -c` and call the absolute path:

```bash
docker compose exec web bash -c \
  '/var/www/openeyes/protected/yiic migrate --interactive=0'
```

Don't try to make `oemig` work over `exec`. The alias is a developer convenience inside an interactive shell, not an API.

## Where to look when something's wrong

- `./build.sh` printed a gate failure — see `subs/build-gates.md`.
- Compose came up but a service is unhealthy — `docker compose logs <svc>`.
- Bridgelink "manifest unknown" — you pinned `4.6` instead of a patch like `4.6.1`.
- Traefik 502s on a fresh box — old Docker daemon API version. PR's `minApiFix()` patches `/etc/docker/daemon.json` to `min-api-version: 1.24`. Don't downgrade Traefik.
- OE returns `{}` from `/openmrs/` — that's the REST root. Legacy UI is `/openmrs/login.htm`.
