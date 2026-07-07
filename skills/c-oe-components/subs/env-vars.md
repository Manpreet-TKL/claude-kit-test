# Runtime environment variables (volatile)

What OE reads at boot. Sources vary by deployment (`.env`, compose-file `environment:`, Docker secrets under `/run/secrets/`). The complete current list lives in `protected/config/core/common.php` and `oe-laravel/config/`.

## Mode / behaviour

| Var | Effect |
|---|---|
| `OE_MODE` | `live` enables OPcache + caches + Sentry, disables `YII_DEBUG`. Anything else (`dev`, `test`, ...) = debug mode. **`TestHelper` checks `OE_MODE !== 'live'` before exposing any route.** |
| `OE_FORCE_YIILITE` | `1` forces `yiilite.php` even in debug. |
| `OE_CONFIG_TEST_RUNNING` | `1` bypasses APCu cache for `OEConfig::getMergedConfig`. Set by the test bootstrap. |
| `OE_ENABLE_VIRUS_SCANNING` | `true` turns on ClamAV upload scanning via `xenolope/quahog`. |
| `LOG_TO_BROWSER` | Mirrors logs into the browser dev tools (debug only). |
| `OE_VERSION` | Surfaced in UI / API headers. Populated at image build time from the git ref. |

## Database

| Var | Notes |
|---|---|
| `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USERNAME`, `DATABASE_PASSWORD` | Used after `/etc/openeyes/db.conf` (INI) if no INI is present. |
| `DATABASE_HOST_TEST`, `DATABASE_NAME_TEST`, `DATABASE_USERNAME_TEST`, `DATABASE_PASSWORD_TEST` | Same triad for the `$db_test` connection. |
| `/run/secrets/DATABASE_PASSWORD` (file) | Docker-secret path; takes precedence over `DATABASE_PASSWORD` env when present. |

## Queue / cache

| Var | Effect |
|---|---|
| `QUEUE_CONNECTION` | `redis` selects the Redis queue (requires `redis` container + Horizon); anything else falls back to the `database` queue table. |
| `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` | Standard Laravel-style Redis vars. |

## Security / signing

| Var | Notes |
|---|---|
| `OE_COOKIE_VALIDATION_KEY` | Required. Yii cookie HMAC. Persist across deploys, otherwise everyone's session invalidates. |
| `/run/secrets/OE_COOKIE_VALIDATION_KEY` (file) | Preferred form on swarm/secrets-aware deploys. |

## SSO

`SAML_settings` and `OIDC_settings` are config arrays, not env vars - they live in `local/common.php`. Env vars only seed the references (e.g. IdP cert path).

## Demo / sample DB caveat (per memory)

OE sample DBs ship with `admin` / `admin`. **Don't run `set_frontend_passwords.sh` on demos** - it will lock out the seeded admin credentials people expect.
