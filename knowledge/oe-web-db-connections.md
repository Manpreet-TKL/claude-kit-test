# How the OpenEyes web container connects to the database

Read before sizing `max_connections`, before proposing a connection pooler, and
before diagnosing "too many connections" / `Aborted_clients` on an OE stack.

Verified 2026-08-19 on the local `snail` stack: `toukanlabsdocker/oe-web-dev:php8.4-noble`
(web), `oe-manager:26.0.6`, MariaDB `11.8.8`. Image-level facts traced in
`~/OEImageBuilder/Web-Base`; server settings in `~/oe-deploy/my.cnf.d/`.

## Headline: there is no pool

OpenEyes opens **one PDO connection per PHP process per request**, and drops it
when the request ends. Nothing is pooled, nothing is kept warm, nothing is shared
between requests. Every page view is a fresh TCP connect, auth handshake and
`SET NAMES`.

Measured (read `SHOW GLOBAL STATUS LIKE 'Connections'` either side, then subtract
1 for the probe query itself):

| Request | New DB connections |
|---|---|
| 10 x `/site/login` (Yii) | 10 |
| 5 x `/xapi/events/1` (Laravel, 401) | 5 |
| 10 x static asset under `/assets/` | 0 |
| 20 x `/site/login` fired concurrently | `Threads_connected` back to baseline immediately after |

## 1. The SAPI is mod_php under prefork, not PHP-FPM

`Web-Base/dockerfile:201` installs `libapache2-mod-php${PHP_VERSION}` and there is
no FPM package, pool directory or `proxy_fcgi` anywhere. `mods-enabled` in both a
running `web` and a running `oe-manager` container is `mpm_prefork` + `php8.4`.
Every image inherits this from `Web-Base` (`Web-Dev`, `Web-Live`, `Manager`).

Consequences that matter for connections:

- one Apache child serves one PHP request at a time, so a child holds at most one
  application DB connection at any instant;
- there is no FPM pool and no `pm.max_children`; the concurrency ceiling is
  Apache's `MaxRequestWorkers`;
- `MaxConnectionsPerChild=0` means children are never recycled, but that does not
  leak connections, because PHP tears the connection down at *request* shutdown,
  not process exit.

Tuning comes from env vars consumed by `apache_configs/include_all/mpm_prefork.conf`
(`PassEnv` + `${...}` substitution), defaulted in `Web-Base/dockerfile:64-68` and
re-stated in `~/oe-deploy/templates/openeyes.env:187-191`:

| Var | Default |
|---|---|
| `OE_APACHE_START_SERVERS` | 5 |
| `OE_APACHE_MIN_SPARE_SERVERS` | 5 |
| `OE_APACHE_MAX_SPARE_SERVERS` | 10 |
| `OE_APACHE_MAX_REQUEST_WORKERS` | 150 |
| `OE_APACHE_MAX_CONNECTIONS_PER_CHILD` | 0 |

## 2. Which framework handles the request

`index.php` is a 30-line router: paths starting `/xapi` or `/l/` go to
`index_laravel.php`, everything else to `index_yii.php`. A request boots one
framework, not both, and Yii does not bootstrap the Laravel container in-request
(no `bootstrap/app.php` reference anywhere in `protected/`). Either path costs
exactly one connection.

## 3. The Yii connection

Component `db` is `OEDbConnection extends CDbConnection`, configured in
`protected/config/core/common.php:352-361`:

    'db' => array(
        'class' => OEDbConnection::class,
        'emulatePrepare' => true,
        'connectionString' => "mysql:host={$db['host']};port={$db['port']};dbname={$db['dbname']}",
        'charset' => $db['charset'],
        'schemaCachingDuration' => 300,
        'attributes' => [],
    ),

- **`attributes => []` is the whole story on pooling.** Yii's `persistent` maps to
  `PDO::ATTR_PERSISTENT` (`CDbConnection.php:726,736`) and is never set, so PHP
  persistent links are not used. `php -i` in the container confirms
  `Active Persistent Links => 0`.
- `autoConnect=true` (`:200`) and `init()` calls `setActive(true)` (`:321`), but
  Yii application components are created lazily, so the socket is opened the first
  time anything asks for `Yii::app()->db`.
- In practice that is the **session**. The `session` component is
  `OESession extends CDbHttpSession` with `connectionID => 'db'` and
  `sessionTableName => 'user_session'` (`core/common.php:532-540`), so session
  reads and writes ride the *same* connection rather than opening a second one.
- On open, `initConnection()` (`CDbConnection.php:459`) sets
  `ATTR_ERRMODE=EXCEPTION`, `ATTR_EMULATE_PREPARES=true`, then runs
  `SET NAMES 'utf8mb4'`; `OEDbConnection::initConnection()` adds
  `ATTR_STRINGIFY_FETCHES=true`.
- `schemaCachingDuration => 300` plus the APCu `cache` component keeps schema
  round-trips off the connection. See `oe-schema-cache.md`.
- `emulatePrepare => true` means client-side prepares: no server-side prepared
  statement state is left on the connection.

DB credentials resolve in `core/common.php:85-118`: `/etc/openeyes/db.conf` if it
exists, else `DATABASE_*` env, else `/run/secrets/DATABASE_*`.

## 4. The Laravel connection

`oe-laravel/config/database.php` defines a single `mariadb` connection reading the
same `DATABASE_*` env/secrets. Its `options` array carries only an optional
`PDO::MYSQL_ATTR_SSL_CA`; there is no `PDO::ATTR_PERSISTENT`, no read/write split
and no `sticky`. Laravel resolves the connection lazily on first query and closes
it when the process ends, so an HTTP request behaves exactly like the Yii path.

## 5. When a connection terminates

1. **Normal end of request.** `CDbConnection` has no `__destruct` and `close()` is
   `protected`, so the PDO handle is released when PHP frees the object graph at
   request shutdown; PDO's destructor sends `COM_QUIT`. Laravel is the same. This
   is why a burst of concurrent requests leaves `Threads_connected` back at
   baseline the instant it finishes.
2. **Fatal error or killed worker.** The socket dies without `COM_QUIT` and
   MariaDB increments `Aborted_clients`. On the 11-day-old snail stack that
   counter is 1 against 83,857 connections, so clean teardown is the norm.
3. **Server idle timeout.** `wait_timeout = 600` in the shipped `my.cnf`
   (identical in every `~/oe-deploy/my.cnf.d/my.cnf.c*` profile). A web request
   never lives that long; this only ever bites the long-lived CLI processes in
   section 6.
4. **Explicit close.** The only deliberate close in `protected/` is
   `components/ParallelMigration.php:29,51`, which calls `setActive(false)` before
   forking so children do not inherit a live PDO handle.
5. **Transport timeouts.** `connect_timeout 10`, `net_read_timeout 30`,
   `net_write_timeout 60` (server defaults, not set in `my.cnf`).

Transactions do not change any of this. `OEDbConnection::beginTransaction()`
returns an `OETransactionStub` when the `enable_transactions` setting is off, and
otherwise pins the request's single connection; it never opens another.

## 6. The connections that are not per-request

| Source | Where | Lifetime |
|---|---|---|
| Docker healthcheck `curl /healthCheck` | `web` and `oe-manager`, interval 50s | one connection per container per 50s; `HealthCheckController::actionIndex` runs one `SELECT` against `setting_metadata` |
| Container start-up probe | `Web-Base/init_scripts/30-wait-hosts.sh`, `83-test-database-connection.sh`, `92-run-migrations-if-requested.sh` | one `mysql` client connection each, at boot |
| `yiic` cron jobs | web-container crontab (`correspondenceemail` /10 min, `runlinearregression` /5 min, `clearexpiredusersessions`, `closehotlistitems`, `clearexpireddraftsaves`, worklist/session generators) | one connection for the life of the command |
| `artisan queue:work --max-time=60` | web-container crontab, every minute | one connection held up to 60s |
| Horizon | `oe-manager`: `artisan horizon` master + `horizon:supervisor` + `horizon:work` children | long-lived PHP CLI; Laravel holds the PDO for the process lifetime and reconnects after a gone-away. `maxProcesses` 10 in `production`, 3 in `local`; `memory` 128 MB forces recycling, which closes the connection |
| Ad-hoc `new PDO` / `new CDbConnection` | core: `modules/Mirth/controllers/AdminController.php:39`. Locally also the `OeDatabase` / `OeMerge` / `OeDataDictionary` / `OeConfig` admin modules | extra connection *in addition* to the request's `db`, for that request only |
| Extra `CDbConnection` components | e.g. a `db_oestats` declared in `config/local/common.php` | opens only when first touched, closes with the request |

Note that on a full `oe-deploy` stack the `yiic` schedule lives in the `master`
container; on this dev stack the `web` container runs it itself.

## 7. Sizing

Shipped server settings (all `my.cnf.c*` profiles are identical on these keys):

| Setting | Value |
|---|---|
| `max_connections` | 1200 |
| `max_user_connections` | 700 |
| `wait_timeout` | 600 |
| `innodb_lock_wait_timeout` | 30 |
| `skip_name_resolve` | ON |
| `thread_cache_size` | 256 (server default, not set in `my.cnf`) |
| `thread_handling` | `one-thread-per-connection` |

- The binding ceiling is **`max_user_connections = 700`**, not 1200: every
  container authenticates as the same `openeyes` user, so web + `oe-manager` +
  `master` + queue workers all draw on that one budget.
- Worst case per web container is `MaxRequestWorkers` simultaneous PHP requests,
  so 150 connections at the default, plus the healthcheck and any running cron
  job. Two web containers and a manager at defaults can therefore ask for ~450.
- `thread_cache_size` is what makes the no-pool design survivable. On snail,
  83,857 connections over 11.2 days produced only 16 created threads: MariaDB is
  re-using cached threads, so the per-connect cost is a TCP handshake plus auth,
  not a thread spawn. `skip_name_resolve = ON` removes a reverse-DNS lookup from
  the same path.
- `DATABASE_SSL_ENABLED=true` adds a full TLS handshake to *every* request,
  because there is no connection to amortise it over. Budget for that before
  enabling it.

## 8. Reading the processlist: why you see `Sleep` and never see zero

`Sleep` is not a leak. It means "connected, no statement executing". OE holds its
one connection for the whole request but spends most of that request in PHP, not
in SQL, so at any instant most in-flight requests show `Sleep`. Measured with 8
concurrent request loops against `/site/login`, sampled once a second:

| COMMAND | count per sample | TIME |
|---|---|---|
| `Sleep` | 2 - 7 | always 0 |
| `Query` | 1 - 2 | always 0 |
| `Connect` / `Statistics` / `Killed` | 0 - 1 | always 0 |

**`TIME` is the discriminator, not `COMMAND`.** Those sleepers are a different set
of connections every second, not the same ones lingering. A second sampler run
once a second across the same window captured **104 `Sleep` rows carrying 104
distinct connection IDs** (84,085 to 86,669) - not one connection was seen twice.
The 25s load burned 2,820 connections (`Connections` 83,857 -> 86,677) and created
**zero** new threads (`Threads_created` stayed at 16, absorbed by the thread
cache). Across the 90s of idle sampling either side of the load, that same query
returned **no rows at all**: with nothing being served, application connections
really are zero.

So:

- request-driven connections churn at `TIME` 0-2 and the `ID`s always move;
- a connection that is genuinely being held sits at a rising `TIME` and a fixed
  `ID`, climbing toward `wait_timeout` (600s).

Four reasons the number you are looking at never reads zero:

1. **Your own session counts.** `Threads_connected` and `SHOW PROCESSLIST` include
   the connection asking the question, so the floor is 1 by construction (higher
   if a monitoring agent holds its own). Filter with `WHERE HOST NOT LIKE 'localhost%'`
   to see only application connections.
2. **Healthchecks land constantly.** `db` is probed every 30s and `web` /
   `oe-manager` every 50s, so a sampling loop nearly always catches a connection
   mid-handshake - it shows up as `unauthenticated user` / `Connect`.
3. **The genuinely long-lived connections in section 6**, above all **BridgeLink**.
   `templates/mc.yml:11-18` points a JDBC pool at the *same* MariaDB server
   (`jdbc:mysql://db:3306/mirthdb`, user `mirthconnect`) with
   `DATABASE_MAX_CONNECTIONS: 150` and `MP_DATABASE_MAX__CONNECTIONS: 150`. Java
   pools pre-open connections and hold them idle by design, so on any stack with
   `mc` there is a permanent floor of `Sleep` rows with climbing `TIME` that has
   nothing to do with the web container. Horizon workers on `oe-manager` behave
   the same way once a job has touched the DB, until the 128 MB memory limit
   recycles the process. Group by `USER` and `DB` and they separate instantly.
4. **`Threads_cached` is not connections.** Parked OS threads waiting to be
   re-used; they never appear in the processlist and never count against
   `max_connections`. Snail idles at `Threads_cached 10`, `Threads_connected 1`.

The grouping query that separates all of this in one shot:

    docker exec -i snail-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -e "SELECT USER, SUBSTRING_INDEX(HOST,\":\",1) AS client, DB, COMMAND, COUNT(*) n, MIN(TIME) min_s, MAX(TIME) max_s FROM information_schema.PROCESSLIST GROUP BY USER, client, DB, COMMAND ORDER BY n DESC"'

## 9. How to observe it

    docker exec -i snail-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -N -e "SHOW GLOBAL STATUS WHERE Variable_name IN (\"Threads_connected\",\"Threads_running\",\"Threads_created\",\"Max_used_connections\",\"Aborted_clients\",\"Aborted_connects\",\"Connections\")"'

    docker exec -i snail-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -e "SELECT USER,HOST,DB,COMMAND,TIME,STATE FROM information_schema.PROCESSLIST ORDER BY TIME DESC"'

    bash ~/oe-deploy/monitoring/count_apache_workers.sh

To measure per-request cost, read `Connections` before and after and subtract one
per probe query. `Threads_connected` on an idle stack sits at the number of
monitoring sessions only, which is the quickest proof that nothing persists.

## 10. What this rules out, and what it enables

- No pooling, no persistent links, no reconnect-on-idle inside a request. Any
  "connection leak" theory has to explain how a connection outlives PHP request
  shutdown; the usual real answer is a long-lived CLI process from section 6.
- A pooler (ProxySQL, MaxScale) would be an external addition; nothing in the app
  expects or configures one. `emulatePrepare => true` means no server-side
  prepared statements, which is precisely what makes transaction-level pooling
  viable if it is ever wanted.
- Reducing per-request connection count is not a lever: it is already one. The
  levers are `MaxRequestWorkers` (how many can exist at once) and request
  duration (how long each is held).
