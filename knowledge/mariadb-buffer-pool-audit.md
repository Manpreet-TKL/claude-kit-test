# Auditing the InnoDB buffer pool - and keeping its use minimal

The buffer pool caches whatever queries actually touch. On OpenEyes - point
lookups per patient/event, writes only when a clinician saves - the genuinely
hot working set is small. The guiding rule:

    A table's resident footprint should track query SELECTIVITY, not table size.
    A large table sitting fully resident means something is scanning it.

Well-indexed traffic pulls in only the index path and the rows it needs; full
scans drag every page of the table through the pool. So the census below is
not just a cache report - it is a full-table-scan detector.

## Seeing what is in the pool

Per-table census (top 20):

    SELECT TABLE_NAME, COUNT(*) pages, ROUND(COUNT(*)*16/1024,1) mb, SUM(NUMBER_RECORDS) entries_cached FROM information_schema.INNODB_BUFFER_PAGE WHERE TABLE_NAME IS NOT NULL GROUP BY TABLE_NAME ORDER BY pages DESC LIMIT 20;

Per-index breakdown of one suspect (is it the PK/data or a secondary index?):

    SELECT INDEX_NAME, COUNT(*) pages, ROUND(COUNT(*)*16/1024,1) mb, SUM(IS_OLD='NO') young FROM information_schema.INNODB_BUFFER_PAGE WHERE TABLE_NAME LIKE '%request_routine%' GROUP BY INDEX_NAME ORDER BY pages DESC;

Caveats:

- COST: the query walks every page in the pool under internal locks. On a 20G
  pool (~1.3M pages) it takes seconds and briefly contends. Burst diagnostic -
  run in a quiet moment, not from monitoring.
- `entries_cached` (NUMBER_RECORDS) counts INDEX ENTRIES, not rows - a row
  counts once per cached index, so it overstates. Use it for magnitude only.
- IS_OLD='NO' = young LRU sublist = touched recently and repeatedly. A table
  whose pages are mostly young is being hit constantly, not lingering.
- Pool headroom check first: `SHOW ENGINE INNODB STATUS\G` -> Free buffers +
  Buffer pool hit rate (below ~995/1000 in steady state = actual pressure).

## Reading the census

| Observation | Meaning | Action |
|---|---|---|
| Big table, resident MB ~= table size on disk | Something reads the whole table | Find the scanner (below); index or prune |
| Big table, small resident slice, mostly young | Normal point-lookup traffic | None - healthy |
| Queue/session/log table with large residency | Dead rows being re-scanned forever | Prune + index (worked examples below) |
| Secondary index fully resident, data pages not | Index-only scans - cheap but still scans | Check the digest; often fine |
| `evicted without access > 0` in INNODB STATUS | Scans churning pages through the pool | Find the scanner - it is also wasting IO |

Table size on disk for comparison:

    SELECT table_name, ROUND((data_length+index_length)/1048576,1) mb_on_disk, table_rows FROM information_schema.TABLES WHERE table_schema='openeyes' ORDER BY data_length+index_length DESC LIMIT 20;

## Finding the scanner behind a big resident

Needs performance_schema=ON. The discriminator is rows examined per execution:

    SELECT LEFT(DIGEST_TEXT,90) q, COUNT_STAR execs, ROUND(SUM_ROWS_EXAMINED/COUNT_STAR) rows_per_exec, ROUND(SUM_TIMER_WAIT/1e12,1) total_s FROM performance_schema.events_statements_summary_by_digest WHERE DIGEST_TEXT LIKE '%request_routine%' ORDER BY SUM_ROWS_EXAMINED DESC LIMIT 5;

- rows_per_exec ~= table row count -> full scan; every execution reads the
  whole table (and keeps it resident).
- rows_per_exec small but execs huge -> app-side chattiness (N+1); harmless to
  the pool, fix in the app if at all.
- Also useful: `SELECT * FROM sys.statements_with_full_table_scans ORDER BY no_index_used_count DESC LIMIT 10;`

Then confirm the plan with the real statement:
`ANALYZE FORMAT=JSON <query>\G` - see r_rows vs rows and access_type (details
in ~/oe-deploy/docs/mariadb-query-profiling.md).

## Worked example 1: the poller (index the scan)

Census showed request_routine at 233.5MB / 5.36M cached entries - a queue
table, ~1.96M rows, 98% status COMPLETE. A payload poller ran ~1/sec:

    ... WHERE execute_request_queue = ? AND status IN ('NEW','RETRY') ...

`SHOW INDEX FROM request_routine;` explained why the whole table was resident:
the FK index on execute_request_queue has cardinality 1 (single queue value) -
useless - and status has no index at all. The optimizer full-scanned 1.96M
rows every second, i.e. the entire table was its working set. Fix, online:

    ALTER TABLE request_routine ADD INDEX idx_rr_queue_status (execute_request_queue, status), ALGORITHM=INPLACE, LOCK=NONE;

Benchmarked 4.3s -> 0.7ms per poll; residency collapses to a few index pages.
This one query was 94% of the host's slow-query time and ~2.6 vCPU of load.

## Worked example 2: the session table (prune the dead)

user_session: 139MB / 736K cached entries resident for 121K live rows - of
which 64K were expired (Yii's probabilistic GC was not keeping up). Every
session validation waded through dead rows, keeping them cached.

    DELETE FROM user_session WHERE expire < UNIX_TIMESTAMP();
    OPTIMIZE TABLE user_session;

then recurring GC (daily EVENT or cron) so it never regrows. Same pattern
applies to any append-forever table: request_routine COMPLETE history,
audit-ish tables, queues. Rows that no query wants should not exist, because
scans do not know how to skip them.

## When a big resident is legitimate

- Hot indexes of genuinely busy tables (event, patient, episode) partially
  resident: normal and desirable - that IS the working set.
- A rare heavy report (e.g. a 2.2M-row letters list query that ran twice)
  can leave a large table resident for a while. Check execs in the digest
  table before declaring a fire: 2 executions is an incident, not a workload.
  It will age out of the LRU; only recurring scans hold residency.
- After a restart the pool refills on demand (11.8 commits pages as touched);
  early residency just reflects the morning's traffic.

## Keeping pool use minimal - the loop

1. Census in a quiet moment; compare top tables against mb_on_disk.
2. For each table resident far beyond its query needs: digest -> plan ->
   composite index, or prune dead rows, or both.
3. Re-census after fixes; the reclaimed space becomes headroom for the real
   working set (and lets a smaller pool suffice on shared hosts).
4. Steady-state watch (cheap, no census needed): hit rate in INNODB STATUS,
   `SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';` delta over a week
   (misses going to disk), and evicted-without-access. Re-census only when
   those degrade or a new module ships.

## Related

- ~/oe-deploy/docs/mariadb-query-profiling.md - digests, ANALYZE, slow log
- ~/oe-deploy/docs/mariadb-innodb-status.md - hit rate, LRU, free buffers
- ~/Bolton_prod_slow_analysis.md - the request_routine analysis in full
- ~/Bolton_docker_cgroup_memory_analysis.md - host-level memory accounting
