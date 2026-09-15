# Optimizing an OpenEyes query from start to finish

This is the entry point to the OpenEyes query-efficiency series. Use
[EXPLAIN and index access](oe-query-explain.md) to interpret plans,
[date handling](oe-query-patterns-sorting-and-date-predicates.md) for temporal
predicates, and [query and relational design](oe-query-design.md) for indexes,
sorting, N+1 and latest-record queries.

The aim is to return the correct result with less total work under realistic
load. A query can be quick once and still be expensive when every request runs
it. Start with evidence, change one cause at a time, and compare the same work.

## 1. Capture the query and the request that needs it

Record the page/action, complete SQL, bound values and types, frequency, result
size, MariaDB version and relevant table/index definitions. Keep captured SQL
and client data in restricted machine-local storage outside repositories.
Examples in this series use parameters or synthetic constants.

Run database clients and log tools in the database or diagnostic container.
The following SQL assumes an authenticated MariaDB session; no credentials
belong in command arguments or documentation.

| Capture method | Best use | What it misses |
|---|---|---|
| Slow query log | Completed statements exceeding a threshold | Frequent fast statements below the threshold |
| Yii debug toolbar | Query count and SQL for one application request | Other requests and background jobs |
| SHOW FULL PROCESSLIST | What is running or waiting now | Statements completed between observations |
| Performance Schema | Aggregate cost by normalized query pattern | Disabled instruments, exhausted history/digest capacity |

### Slow query log

First inspect the active settings:

```sql
SHOW GLOBAL VARIABLES WHERE Variable_name IN ('slow_query_log', 'slow_query_log_file', 'long_query_time', 'log_output', 'log_slow_query', 'log_slow_query_file', 'log_slow_query_time', 'log_slow_filter', 'log_slow_rate_limit', 'min_examined_row_limit', 'log_slow_min_examined_row_limit');
```

If logging is unavailable, arrange a bounded capture with the database operator.
An example server configuration for file logging is:

```ini
[mariadb]
slow_query_log=ON
log_output=FILE
long_query_time=0.2
```

The threshold is an example, not a universal setting. Check filters, row limits,
sampling and log rotation. Capture a representative workload, then restore the
previous configuration if it was temporary. Global threshold changes do not
necessarily update existing pooled sessions; verify the application's session
setting. MariaDB 10.11 introduced `log_slow_query*` names for several older
settings. [Slow-log configuration](https://mariadb.com/docs/server/server-management/server-monitoring-logs/slow-query-log/slow-query-log-overview)
describes aliases and scope.

Read query time, lock time, rows examined and rows sent. Many rows examined for
few rows returned is a lead, not proof: a correct aggregate can need many input
rows. Log time is not CPU time.

To group similar statements in a captured file, run these inside a diagnostic
container where the private log is mounted at the example path:

```bash
mariadb-dumpslow -s t -t 20 /capture/slow.log
mariadb-dumpslow -s c -t 20 /capture/slow.log
```

The first ranks grouped query time; the second ranks count. The default
normalization replaces ordinary string and number literals.
[mariadb-dumpslow](https://mariadb.com/docs/server/clients-and-utilities/logging-tools/mariadb-dumpslow)
documents the grouping and sort options. Keep one representative full statement
privately: the normalized pattern cannot be executed or reveal value skew by
itself. A slow-log count counts logged executions, not all executions.

### Yii debug toolbar

OpenEyes configures the toolbar in `protected/config/core/main.php`. It requires
`YII_DEBUG` and a nonempty `YII_DEBUG_BAR_IPS`. The same configuration enables
database profiling and parameter logging. `index_yii.php` controls the default
debug flag from deployment mode.

1. Use a controlled development deployment with debug mode enabled and the
   developer's address allowed by `YII_DEBUG_BAR_IPS`.
2. Open the target screen and perform one reproducible action.
3. Open the toolbar's database panel and inspect total query count, cumulative
   database time, individual SQL and repeated shapes.
4. Repeat with a longer list or more relations. A query count that grows with
   each displayed row suggests N+1.
5. Follow the SQL back to the model/controller and the relation accessed by the
   rendering code. Retest the same action after the change.

The toolbar exposes SQL parameters and configuration, so keep its access
restricted. Its timings include profiling overhead and describe that request.

For the closed hotlist, start at `UserHotlistItem::getHotlistItems()`. Its
`with('patient', 'patient.contact')` call intentionally preloads relations.
The [date example](oe-query-patterns-sorting-and-date-predicates.md) retains the
complete SELECT this produces.

### SHOW FULL PROCESSLIST

```sql
SHOW FULL PROCESSLIST;
```

`FULL` avoids the ordinary 100-character statement display limit. To focus on
active statement text while excluding this observer connection:

```sql
SELECT ID, NOW(6) AS observed_at, DB, TIME, STATE, INFO FROM information_schema.PROCESSLIST WHERE ID <> CONNECTION_ID() AND COMMAND <> 'Sleep' AND INFO IS NOT NULL ORDER BY TIME DESC;
```

Keep `Sending data` visible: that state can include row reading and processing,
not just network transmission. `Creating sort index` is transient internal
work, not permanent schema-index creation. Neither state identifies the missing
index by itself. See [MariaDB thread states](https://mariadb.com/docs/server/ha-and-performance/optimization-and-tuning/buffers-caches-and-threads/thread-states/general-thread-states).

A snapshot is not an execution counter. Ten observations of one long statement
are not ten executions. Polling favours long statements and misses short ones.
TIME is an elapsed-age field, not measured time spent in the displayed sorting
stage or a prediction of remaining time. Without PROCESS visibility, an account
may only see its own threads. Information-schema polling also has overhead;
Performance Schema threads can be preferable when available.
[SHOW PROCESSLIST](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/show/show-processlist)
documents visibility and polling considerations.

### Performance Schema: count patterns, not literal variants

Check availability and instrumentation first:

```sql
SHOW VARIABLES LIKE 'performance_schema';
SELECT NAME, ENABLED FROM performance_schema.setup_consumers WHERE NAME LIKE '%statements%';
SELECT NAME, ENABLED, TIMED FROM performance_schema.setup_instruments WHERE NAME LIKE 'statement/sql/%';
```

An empty result set is not proof of no query activity. Performance Schema may
be off, instrumentation/timing may be disabled, or collection may have just
started. Enabling the server facility can require a restart; arrange collection
with the operator rather than treating it as a harmless query switch.

A normalized digest groups statements with different literal values. Start with
total statement time:

```sql
SELECT SCHEMA_NAME, DIGEST, DIGEST_TEXT, COUNT_STAR, ROUND(SUM_TIMER_WAIT / 1000000000000, 3) AS total_seconds, ROUND(AVG_TIMER_WAIT / 1000000000, 3) AS average_ms FROM performance_schema.events_statements_summary_by_digest WHERE SCHEMA_NAME = DATABASE() ORDER BY SUM_TIMER_WAIT DESC LIMIT 20;
```

Select the application database first. Then examine work counters:

```sql
SELECT DIGEST, COUNT_STAR, SUM_ROWS_EXAMINED, SUM_ROWS_SENT, SUM_SORT_ROWS, SUM_SORT_MERGE_PASSES, SUM_CREATED_TMP_TABLES, SUM_CREATED_TMP_DISK_TABLES FROM performance_schema.events_statements_summary_by_digest WHERE SCHEMA_NAME = DATABASE() ORDER BY SUM_ROWS_EXAMINED DESC LIMIT 20;
```

Timer units are picoseconds. These are accumulated counters, not automatically
a five-minute window. Take start/end snapshots, match by schema and digest, and
subtract counters. Divide delta time by delta count for the window's average;
do not subtract averages. Discard intervals spanning a restart or reset.
Snapshot all relevant digests before ranking the deltas.

Digest capacity and statement-text length are bounded. Check the NULL-digest
overflow bucket; truncated shapes and overflow weaken attribution. A digest is
not a security scrubber: identifiers and schema names can remain.
[Digest summary columns and limits](https://mariadb.com/docs/server/reference/sql-statements/administrative-sql-statements/system-tables/performance-schema/performance-schema-tables/performance-schema-events_statements_summary_by_digest-table)
define the available aggregates.

Where enabled, [events_statements_history_long](https://mariadb.com/docs/server/reference/system-tables/performance-schema/performance-schema-tables/performance-schema-events_statements_history_long-table)
can supply recent completed statement examples and per-execution counters;
it is a finite ring, not a
durable log. Stage history can add observed sort stages but needs separate
instrumentation. Do not enable every history consumer indefinitely just to
answer one question.

## 2. Choose the pattern with the greatest impact

| Evidence | Priority and likely resource |
|---|---|
| Requests waiting on a lock | Investigate blocker and transaction lifetime; an index change may not address the wait |
| High total time and execution count | High aggregate cost, even if each call is fast |
| Many examined rows for a small result | CPU, logical page reads and possible cache churn |
| Large disk temporary work or sort merge passes | Storage traffic and elapsed time |
| Many near-identical statements in one request | N+1, repeated planning/execution and round trips |
| Huge returned rows/bytes | Network, serialization and PHP hydration/memory |
| Rare tiny filesort | Usually lower priority than the above |

`count * average duration` estimates cumulative statement time over a window,
not CPU usage or wall time when executions overlap. Use application latency
and concurrency alongside server metrics.

For the hotlist, many date-literal variants belong to one pattern. Keep its
count and total work, and test representative small and large creator
histories. One example with a few rows can hide a problem for a busy user.

## 3. Read the plan and inspect the schema

1. Run EXPLAIN for the exact statement and representative values.
2. Locate the first large scan or broad lookup and any repeatedly executed work.
3. Compare `possible_keys`, `key`, `key_len` and JSON `used_key_parts` with the
   real index definitions.
4. Check each filtering and join column's type, collation and NULL semantics.
5. Inspect sorting, grouping, materialization and row multiplication separately.
6. Use controlled `ANALYZE FORMAT=JSON` execution to compare estimated and actual
   work where the read query is safe to run.

The [EXPLAIN guide](oe-query-explain.md) explains every standard access type and
the Extra messages. **Multiplying the rows column does not predict
milliseconds.** It can only suggest fanout under restricted assumptions.

## 4. Change the cause

| Cause | Candidate change | Check |
|---|---|---|
| Hotlist date tested after broad lookup | Bare-column bounds in PHP | Date, NULL and timezone semantics preserved |
| Missing creator/status/date access path | Reviewed composite-index migration | Existing overlap, build impact and write cost |
| Repeated patient/contact lazy loads | Eager loading or batch fetching | Same visible data without relation fanout |
| Global latest-risk work for one patient | Restrict candidates before latest-row work | Tie, deletion and correction behaviour preserved |
| Huge result only partly displayed | Select needed fields and paginate | Stable order and required hydration keys |

Rewriting SQL is often how a rule is applied: make a condition searchable, filter
earlier, stop generating duplicates or avoid per-row database trips. Some
queries still need a different algorithm or a maintained read model. Adding
indexes cannot repair every relational access pattern.
[Query design](oe-query-design.md) develops these examples.

## 5. Validate correctness, cost and the application request

Compare before/after on equivalent data and parameter distributions. Preserve
row identities, values, NULLs, duplicates and promised ordering. With timestamp
ties, verify the ordering contract rather than assuming an unspecified tie order.

Measure actual rows and loops, statement time, page accesses/reads where
available, sort/temp work, rows and bytes returned, and application query count.
Include high-history users, empty results and boundary dates. Check the
rendered screen too: fewer SQL columns must not create missing attributes or
new lazy loads.

Repeat enough to distinguish a warm-cache improvement from noise. Do not flush
a shared database's caches for a comparison. An isolated workload can explore
cold-cache behaviour; representative concurrency tests reveal costs hidden by
a single request.

After an index change, inspect its size and write overhead as well as SELECT
performance. If estimates remain poor, investigate statistics and skew before
forcing an index. Review execution plans on the supported MariaDB versions.

## Why a fast query can still harm the database

The [InnoDB buffer pool](https://mariadb.com/docs/server/server-usage/storage-engines/innodb/innodb-buffer-pool)
caches table and index pages. A broad scan can touch many cached pages quickly,
consume CPU, and introduce pages that compete with useful data.
Later misses can cause physical reads and IOPS. It does not follow that all
pages resident for that table are wasted or owned by one query.

Sort and join buffers are separate working memory; temporary disk tables/files
add storage work. A busy deployment can multiply these costs across concurrent
statements. A quick warm run proves neither low memory pressure nor low cold
I/O. Compare logical page activity and physical read deltas, then correlate
with host/container resource measurements and workload frequency.

Use [ANALYZE's engine counters](oe-query-explain.md#rows-multiplied-together-do-not-give-milliseconds)
where available. Avoid treating an expensive full buffer-page inventory as a
continuous query monitor; see [buffer-pool analysis](mariadb-buffer-pool-audit.md).
