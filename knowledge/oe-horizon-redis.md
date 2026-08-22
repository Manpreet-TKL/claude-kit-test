# Laravel Horizon in OpenEyes v26.1.0+ - how it works, how to configure it, and what devops must know

Verified live on OE 26.0.6 (snail) and by inspection of `toukanlabsdocker/oe-manager:v26.1.0-pre1-meh` on 2026-07-18. Everything here is about the OpenEyes application and images, not oe-deploy specifically; the oe-deploy `red`/`horizon` templates are just one way to supply the environment described below.

## 1. The moving parts

OpenEyes ships a Laravel application at `/var/www/openeyes/oe-laravel` alongside the Yii application. Both share one composer vendor tree at `/var/www/openeyes/vendor` (there is no `oe-laravel/vendor`; `oe-laravel/artisan` requires `../vendor/autoload.php`). The queue stack:

1. `laravel/horizon ^5.43` and `predis/predis ^3.3` are in the main `composer.json`.
2. The images have NO phpredis PHP extension (`php -m` shows no redis), so `REDIS_CLIENT` must be `predis`. Laravel's default is `phpredis` - leaving it unset breaks redis use.
3. Jobs live in `oe-laravel/app/Modules/*/Jobs/` (e.g. `Webhooks/Jobs/SendWebhook.php`, `TrDeviceUsageRecord/Jobs/DeviceUsageReportJob.php`), plus system events dispatched from module observers.
4. The Yii side dispatches into the same Laravel queue through `protected/components/JobDispatcher.php` -> `AsyncJobDispatcher`, which picks `DatabaseQueueDriver` or `RedisQueueDriver` from `QUEUE_CONNECTION` (`protected/config/core/common.php`: `'connection' => getenv('QUEUE_CONNECTION') ?: 'database'`).

## 2. The two consumers

| Consumer | Started by | Runs | Connection |
|---|---|---|---|
| Cron worker | `/init_scripts/95-start-cron.sh` installs `protected/scripts/.cron/reportsqueue` into the crontab when `ENABLE_CRON=TRUE` and `OE_MODE != TEST` | `php oe-laravel/artisan queue:work --max-time=60` every minute (schedule overridable via `CRON_REPORTSQUEUE_SCH`, max time via `REPORTSQUEUE_MAX_TIME`) | Whatever `QUEUE_CONNECTION` says (default `database`) |
| Horizon | `/init_scripts/96-start-horizon.sh` starts supervisord when `ENABLE_HORIZON=TRUE`, which runs `php oe-laravel/artisan horizon` as www-data (autorestart, log `/var/log/supervisor/horizon.log`) | A master + `horizon:supervisor` + auto-scaled `horizon:work redis` workers (observed defaults: `--balance=auto --min-processes=1 --max-processes=10 --memory=128 --timeout=60 --tries=1 --queue=default`) | Always redis - Horizon cannot run on the database driver |

Image defaults (OEImageBuilder): `Manager/dockerfile` bakes `ENV ENABLE_HORIZON="TRUE"`, `Web-Dev/dockerfile` bakes `FALSE`. So out of the box every oe-manager tries to start Horizon and every web container does not. Both images carry the init script, the supervisor config, and the cron template.

Consequence 1: on a deployment with no redis at all, the manager's Horizon crashes at startup with `Predis\Connection\Resource\Exception\StreamInitException: Connection refused [tcp://127.0.0.1:6379]` (4 entries in `oe-laravel/storage/logs/laravel.log` and `/var/log/supervisor/horizon.log`), then supervisord gives up: `horizon FATAL Exited too quickly`. Harmless but noisy at every container start. The image default stays TRUE deliberately (Horizon is rolling out to every OpenEyes instance); oe-deploy counters the noise instead by shipping `ENABLE_HORIZON=FALSE` in the `.env` template, which `templates/web.yml` passes to oe-manager only - flip it to TRUE alongside the `red`/`horizon` recipe entries.

Consequence 2: with `QUEUE_CONNECTION=redis`, the every-minute cron worker consumes the same `default` redis queue as Horizon's workers. Jobs are processed exactly once (redis pops are atomic) but you effectively run one extra worker Horizon does not know about; its jobs bypass Horizon's metrics/tags. Cosmetic today; keep in mind when reading the dashboard.

## 3. Configuration reference

Set on BOTH web and manager (both sides dispatch; the manager processes):

| Variable | Meaning | Note |
|---|---|---|
| `QUEUE_CONNECTION` | `database` (default) or `redis` | Drives Laravel's `config/queue.php` AND the Yii `AsyncJobDispatcher` |
| `REDIS_CLIENT` | Must be `predis` | No phpredis extension in the images |
| `REDIS_HOST` / `REDIS_PORT` / `REDIS_DB` | Server location | Defaults `127.0.0.1` / `6379` / `0` |
| `REDIS_PREFIX` | Key prefix | Laravel default is `<app_name_slug>_database_`; set explicitly (e.g. `openeyes:`) so keys are recognisable |
| `REDIS_PASSWORD` | Auth | See the secret-file split below |
| `REDIS_QUEUE` | Queue name for Yii redis dispatch | Defaults `default` |

Manager only:

| Variable | Meaning |
|---|---|
| `ENABLE_HORIZON` | `TRUE` starts supervisord + Horizon. Keep it off on web - a second Horizon daemon there would double the worker fleet |
| `HORIZON_NAME` | `config/horizon.php` 'name' |
| `HORIZON_PATH` | Dashboard path, default `l/horizon` |
| `CRON_REPORTSQUEUE_SCH` / `REPORTSQUEUE_MAX_TIME` | Cron worker schedule / max-time |

Password handling is split and this matters:

1. Laravel (`oe-laravel/config/database.php`) reads the FILE `/run/secrets/REDIS_PASSWORD` if it exists, else the env var. Docker secrets work. Verified working with a password containing a space and `$`.
2. The Yii `RedisQueueDriver` (`protected/components/RedisQueueDriver.php`) in 26.0.x and the v26.1.0-pre1 images reads ONLY `getenv('REDIS_PASSWORD')`. With the password delivered as a Docker secret and no env var, every Yii-side redis dispatch fails with `Predis\Response\ServerException: NOAUTH Authentication required.` (reproduced on snail, 26.0.6). Fixed on develop by OE-18162 (openeyes/openeyes #12187, merged 2026-06-30): `config/core/common.php` now reads `/run/secrets/REDIS_PASSWORD` first (env fallback) into `params['redis_password']` and the driver uses that param. Until an image containing that commit ships, Yii-side redis dispatch on 26.x needs the env var.

## 4. Telling the queue errors apart in manager logs

| Error in the log | What it actually means |
|---|---|
| `SQLSTATE[HY000] [2002] Connection refused` through `Illuminate\Queue\DatabaseQueue->pop()` | The cron `queue:work` on the DATABASE driver could not reach MySQL - the DB was down/restarting at that minute. Nothing to do with redis; appears once per cron tick while the DB is unreachable |
| `Connection refused [tcp://127.0.0.1:6379]` (`Predis ... StreamInitException`, code 111), 4x at container start then `FATAL` in `supervisorctl status` | Horizon enabled (image default) but no redis configured - the stock no-redis deployment signature |
| `php_network_getaddresses: getaddrinfo for redis failed ... [tcp://redis:6379]` or `Connection refused [tcp://redis:6379]`, repeating ~2/second | Redis WAS configured and is now down/unreachable - running Horizon master/supervisor retry in a tight loop and flood `storage/logs/laravel.log`; the cron worker adds one burst per minute |
| `NOAUTH Authentication required.` (`Predis\Response\ServerException`) | Client connected without a password - in OE almost always the Yii `RedisQueueDriver` env-only password bug above |

Log locations inside the manager container: `oe-laravel/storage/logs/laravel.log` (container filesystem - grows unbounded until the container is recreated), `/var/log/supervisor/horizon.log`, `/var/log/cron`.

## 5. How redis uses memory, and deployment concerns

1. Queue + Horizon metadata are small (KBs to a few MBs) unless jobs backlog. Memory grows with backlog length x payload size; Horizon also keeps recent-job/metrics keys with TTLs.
2. `maxmemory` defaults to 0 = unlimited. In a container that means redis grows until the cgroup `mem_limit` and the kernel OOM-kills it (exit 137, restart loop, queue outage). ALWAYS set `--maxmemory` below the container limit.
3. `maxmemory-policy` must be `noeviction` for a queue store. Any LRU/LFU policy silently deletes keys under pressure - i.e. throws away jobs. With `noeviction`, writes fail loudly (`OOM command not allowed when used memory > 'maxmemory'`) and the error surfaces in the app logs instead of jobs vanishing.
4. RDB snapshots (on by default in the official image: `save 3600 1 300 100 60 10000`) fork the process; copy-on-write can briefly double resident memory under write load. Budget roughly `maxmemory <= 50%` of `mem_limit` - hence oe-deploy's 256mb maxmemory inside a 512m limit with 256m reservation (`templates/resources/red.yml`).
5. Snapshots land in `/data` (the `redis-data` volume), so a restart keeps queued jobs up to the last save point. If losing up to a few minutes of queued jobs on crash is unacceptable, enable AOF (`--appendonly yes`) and budget extra disk + rewrite-fork memory.
6. Kernel tuning redis warns about at startup: `vm.overcommit_memory=1` (otherwise background saves can fail under pressure) and transparent hugepages off. Host-level, optional for the small OE workload, but they explain the startup warnings.
7. Auth: `requirepass` is fed from the Docker secret via in-container `$(cat /run/secrets/REDIS_PASSWORD)`. The substitution MUST be double-quoted - unquoted it word-splits, and a password containing whitespace crash-loops redis with `FATAL CONFIG FILE ERROR ... wrong number of arguments` (reproduced; fixed on the oe-deploy branch).
8. Pin the image tag (`redis:8.8`, not `latest`) and give the container a healthcheck that authenticates - an unauthenticated `redis-cli ping` only proves the port is open, not that the password in the secret matches (`NOAUTH` still returns a TCP response).
9. Monitoring: `php oe-laravel/artisan horizon:status`, `supervisorctl status horizon`, the dashboard at `/l/horizon` (subject to Horizon's auth gate), and `redis-cli INFO memory` (`used_memory_human` vs `maxmemory_human`).
