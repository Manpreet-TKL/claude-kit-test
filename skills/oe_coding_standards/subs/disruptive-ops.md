# Disruptive operations — confirmation & secrets (volatile)

## Confirmation literal

Any operation that destroys data, overwrites a host, or restarts production must require the **literal string `yes`** to proceed. **Not `y`, not `Y`, not `YES`.** Anything other than `yes` aborts.

The pattern for bash (see `bash-style` skill for the full house style):

```bash
read -r -p "Type 'yes' to proceed: " ans
[[ "$ans" == "yes" ]] || abort "aborted"
```

## Sample-DB / demo caveats

- **OE sample DBs ship with `admin` / `admin`.** Don't run `set_frontend_passwords.sh` on a demo box — it locks out the seeded credentials people expect.
- Demo containers may share secrets across hosts; rotating one without the others will lock the cluster out of its own DB.

## Secrets

- Yii cookie HMAC: `OE_COOKIE_VALIDATION_KEY`. Env var, or `/run/secrets/OE_COOKIE_VALIDATION_KEY` on swarm/secrets-aware deploys. **Persist across deploys** — rotating it invalidates every session.
- DB credentials: three sources in order — `/etc/openeyes/db.conf` (INI), `DATABASE_*` env, `/run/secrets/DATABASE_*`. Same for `$db_test`.
- SSO blobs (`SAML_settings`, `OIDC_settings`) live in `local/common.php` — not env vars.
- **Never commit secrets to the repo.** The `local/` directory is gitignored on purpose. Pre-commit hooks should reject env files; if one slips through, rotate immediately.

## Tag casing (per memory)

- `OE_WEB_TAG` and `MASTER_TAG` must use **lowercase `rc`** (`v26.0.0-rc3`). Docker Hub is case-sensitive — `RC3` will 404.
- BridgeLink: no bare `4.6` — pin a patch like `4.6.1`.

## Deploy templates (per memory)

- `oe-deploy` is a template. **`mv oe-deploy <env>`, never `cp`.** The repo isn't a source-of-truth checkout.
- On Manpreet's hosts, Docker login / GPG / host-setup are already done — don't re-check or re-run.

## Traefik daemon fix (per memory)

Traefik < v3.6 needs `min-api-version: 1.24` in `/etc/docker/daemon.json`. The deploy PR's `minApiFix()` does it. **Don't swap the Traefik tag**, don't add a socket proxy.
