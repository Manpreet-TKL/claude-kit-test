# Bolton production performance work (2026-07, closed)

Two completed investigations on Bolton (sys376). Archived from auto-memory
2026-07-19; the full runbooks live outside the kit and remain the working
references.

## Slow-query analysis (2026-07-08)

Analysed `~/Bolton_prod_slow.log` (33.7h of 2026-07-07/08, OE v26.0.6). Report
with ready-to-run DDL: `~/Bolton_prod_slow_analysis.md`; distinct queries:
`~/Bolton_prod_slow_unique_queries.log`.

- 94% of slow time = Mirth Database Reader polling `request_routine`
  ('dicom_queue') every 2s, full-scanning 2M rows. Fix: `ADD INDEX
  (execute_request_queue, status)` - benchmarked 4.3s -> 0.7ms at prod
  cardinality.
- PatientTicketing VC queries need `patientticketing_ticketqueue_assignment
  (ticket_id, created_date, id)` plus a queue-driven rewrite of
  DefaultController.php:117 (the window-function rewrite is 5x WORSE -
  benchmarked).
- Other missing prod indexes: `contact.pas_id`, `user_session.expire`,
  `event(event_type_id, created_date)`, `pasapi_assignment.internal_type`,
  version-table `id` indexes (only 27/1066 have one).
- Nightly ETL (client_user@10.28.x.x) full-dumps whole tables including the
  1.6GB letters table twice.
- The v26.0.6 tag already contains the idx_pta_*/worklist/letter perf indexes;
  snail carries an out-of-band `user_session_expire` index found in no
  migration.

## Cgroup memory incident (2026-07-17)

High-RAM alerts were NOT a DB leak. The dbbackup container (shares the oe-db
volume, no mem_limit) pushed ~40G per backup of page cache through
docker_limit.slice, swapping the DB nightly; destroying the container stranded
~11G still charged to the slice with no living owner (slice memory.current
minus the sum of child scopes). `drop_caches` recovered only 1.5G; guarded
512M-step `memory.reclaim` writes clear it (the `swappiness=` argument is
rejected by the 6.17.0-1019-aws kernel), or a host reboot. `docker compose
down` cannot - containers don't own the charge.

Prevention: always-on `mem_limit: ${DB_BACKUP_MEM_LIMIT:-2g}` + equal
`memswap_limit` in `templates/bkp.yml` (NOT the opt-in resources overlay); a
dump OOM (exit 137) on blob-heavy sites means raise it to 4g. Alert on
`swap_used_percent` + `mem_available_percent`, not `mem_used_percent` (idles
80%+ by design). Runbooks: `~/Bolton_docker_cgroup_memory_analysis.md`,
`~/innodb-buffer-pool-audit.md`.
