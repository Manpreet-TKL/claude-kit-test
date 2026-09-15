# The Yii schema cache in OpenEyes (2026-08, PR raised)

Read before changing `schemaCachingDuration`, before adding anything that clears
APCu, and before diagnosing "the column I just added is being silently ignored".
Measured against a 2978-base-table OpenEyes database in the local Docker stack.

## What is cached and under which key

`CDbSchema::getTable()` (`vendor/yiisoft/yii/framework/db/schema/CDbSchema.php:72-110`)
is lazy and per table - nothing loads the whole schema at once. Each miss costs
exactly **two** statements, `SHOW FULL COLUMNS FROM <t>` and `SHOW CREATE TABLE <t>`
(verified: 2990 of each for 2990 table loads).

The lookup chain, in order:

1. `$this->_tables[$name]` - an in-process array, so a second `getTable()` in the
   same request never reaches APCu. This is also why measuring the cache needs a
   **fresh `CDbConnection`**, not a second call on the same one.
2. APCu, only when `($duration = $this->_connection->schemaCachingDuration) > 0`.
   A zero or negative duration disables schema caching outright.

The cache key is `'yii:dbschema' . $connectionString . ':' . $username . ':' . $table`,
which `CCache::generateUniqueKey()` (`caching/CCache.php:92-95`) hashes with
`hashKey = true`, so the stored APCu key is:

    md5($appId . 'yii:dbschema' . $dsn . ':' . $user . ':' . $table)

`$appId` is `sprintf('%x', crc32($basePath . $name))`
(`base/CApplication.php:232-238`). Two traps when recomputing it outside the app:
`setBasePath()` **realpath()s** its argument, so the merged config's literal
`/var/www/openeyes/protected/config/..` must be resolved first, and the runtime
`name` is **`OpenEyes Main`**, not the `'OpenEyes'` at `core/common.php:177`.
Getting either wrong yields keys that match nothing, silently.

Two consequences that shape everything else:

- **There is no iterable prefix**, so selective invalidation is impossible. It is
  wipe-everything (`apcu_clear_cache()`) or wipe nothing. Anything proposing to
  expire "just the schema" has to recompute every key from the table list.
- **Yii never negatively caches.** `if ($table !== null) $cache->set(...)`, so a
  table created at runtime (NOD audit's real `tmp_` tables, a database
  `application_log`) can never be masked by a cached absence.

## Measured cost

Per table, end to end in PHP (SQL round trips, `CDbTableSchema` construction and
APCu serialize/unserialize included):

| Working set | Cold (introspect + store) | Warm (APCu read) | Ratio |
|---|---|---|---|
| 12 tables | 0.520 ms/table | 0.026 ms/table | 20x |
| 2978 tables (whole schema) | 0.350 ms/table | 0.021 ms/table | 17x |

A fully warm whole-schema load is **1042 ms cold against 62 ms warm** and occupies
**15.1 MB** of the default `apc.shm_size=64M` - roughly 4x headroom, so the long
TTL does not need a shared-memory increase. The failure mode if it ever did is
fail-safe: APCu evicts and ultimately wipes, which is slower, never stale.

Real page, `/patient/summary/<id>`, with **only** the schema keys expired and every
other cache left warm (mean of 4 paired runs):

| | Wall clock | Statements | Introspection statements |
|---|---|---|---|
| Schema expired | 0.394 s | 417 | 142 |
| Schema cached | 0.347 s | 271 | 0 |

So one expiry costs about **47 ms and 146 extra statements** on that page - 35%
more statements for 13% more wall clock. That page's working set is 107 tables,
0.61 MB of APCu.

**Do not quote the flush-everything number as the schema saving.** A full
`apc_clear.php` makes the same page 1.02 s against 0.35 s, but only 216 of those
~990 extra statements are introspection; the rest come from other cold caches
(merged config, setting metadata). Isolating the schema component needs a probe
that recomputes and deletes just the schema keys.

## The 300-second default is a recurring cost, not a warm-up

APCu TTLs are absolute, not sliding - `set()` is called only on a miss, so an
entry expires 300 s after it was stored no matter how often it is read. Every
table in active use is therefore re-introspected **288 times a day, per
container**. For a 107-table working set that is about 61,600 extra statements
and 13.5 s of wall clock a day; against the whole schema it is 1.7 M statements
and roughly 5 minutes a day.

These are a **floor**. Web and database were containers on one host here, where a
round trip measured 0.043 ms, so 214 round trips cost 9 ms. A deployment with a
remote database pays real latency on all of them: at 0.5 ms RTT the same 107
tables cost about 107 ms per expiry rather than 9 ms.

## Invalidation, and the gap that has no hook

- `apc_clear.php` sits in the web root and is **loopback gated**
  (`REMOTE_ADDR` in `127.0.0.1`, `::1`). Call it as `http://127.0.0.1/...`, never
  `localhost` - `getent hosts localhost` resolves `::1` first, and the SSL vhost
  both redirects to HTTPS and denies anything that is not literally `127.0.0.1`,
  so the `::1` branch is unreachable on a live container even though the PHP
  allows it.
- `oe-fix.sh:280` is the only thing in the tree that calls it today.
- **CLI can never flush the web cache.** `apc.enable_cli=1` is set, but each CLI
  process gets its own APCu segment, so every `yiic` run starts cold and nothing
  it does reaches the web SAPI's segment. This is why an APCu flush has to be an
  HTTP call to the local web server rather than a PHP function call.

**Runbook line.** After a migration or hand-applied DDL that did not come with a
redeploy, **restart the web containers or pods**, or `curl` `apc_clear.php` inside
each one. The normal deploy path is already safe - new image, manager migrates,
web containers are recreated and come up with an empty APCu - but three cases are
not covered by any hook: a migration run from a **separate manager container**
(loopback there has no web SAPI), a **multi-replica** deployment (N independent
segments), and **DDL applied straight to the database**. Cross-container
invalidation would need network reach into every replica plus an auth story, and
opening up a deliberately loopback-only endpoint is a bigger regression than the
staleness it removes.

The staleness matters because Yii AR filters attributes against the cached column
list, so a newly added column is silently dropped from INSERT and UPDATE rather
than erroring - a data-loss shape, not a visible failure. Precisely:
`CActiveRecord::setAttributes($values, false)` filters against `attributeNames()`,
which is the cached column list, and a key that is not in it is skipped with no
error and no `onUnsafeAttribute()` call. Demonstrated end to end: with a column
added out of band, an insert supplying it stored `NULL`; after an APCu flush the
same insert persisted the value. Note that direct assignment (`$model->newcol = x`)
does **not** share this shape - it reaches `CComponent::__set` and throws, so the
silent case is specifically mass assignment.

## Reproducing the measurement

General and slow logs to tables, so both are queryable (`long_query_time=0` makes
the slow log record every statement with its `query_time`). Note MariaDB logs
`SHOW FULL COLUMNS` to the slow log but **not** `SHOW CREATE TABLE`, so double the
introspection database time it reports.

    docker exec test-db-1 sh -c 'p=$(cat "$MYSQL_ROOT_PASSWORD_FILE"); mariadb -uroot -p"$p" -e "SET GLOBAL general_log=OFF; SET GLOBAL log_output=\"TABLE\"; TRUNCATE mysql.general_log; TRUNCATE mysql.slow_log; SET GLOBAL long_query_time=0; SET GLOBAL general_log=ON; SET GLOBAL slow_query_log=ON;"'

Count introspection for one request with
`SELECT COUNT(*) FROM mysql.general_log WHERE argument LIKE 'SHOW FULL COLUMNS%'`,
and restore the server afterwards (`general_log=OFF`, `log_output=FILE`,
`long_query_time=3`, both log tables truncated).

Driving a real clinical page needs a session. The login form wants
`YII_CSRF_TOKEN`, `LoginForm[institution_id]`, `LoginForm[site_id]`,
`LoginForm[username]`, `LoginForm[password]`; tokens are **masked**
(`CHttpRequest::validateCsrfToken` unmasks both sides), and the form input carries
`value=` *before* `name=`, which defeats the obvious `name="..."[^>]*value="\K`
regex. Extract with `grep -oE '<input[^>]*YII_CSRF_TOKEN[^>]*>'` then pull `value`
from that match.

To time the schema cache specifically, a throwaway loopback-gated script in the
web root can recompute the keys from `information_schema` plus the `$appId` above
and `apcu_delete()` only those - verify it by checking that
`apcu_cache_info(true)['num_entries']` drops by the number of tables the page
uses, and delete the script afterwards. Do not leave an APCu status or clear
endpoint in the tree; it discloses key names and cache contents.
