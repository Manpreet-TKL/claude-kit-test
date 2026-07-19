---
name: bolton-cgroup-memory-incident
description: Bolton 2026-07-17 RAM alert root cause - dbbackup page cache + 11G orphaned cgroup charge; writeups at ~/Bolton_docker_cgroup_memory_analysis.md and ~/innodb-buffer-pool-audit.md
metadata: 
  node_type: memory
  type: project
  originSessionId: 18634775-ef5b-4afa-8fcc-0cc15602fdb2
---

Bolton (sys376) high-RAM alerts 2026-07-17: NOT a DB leak. The dbbackup
container (shares oe-db volume, no mem_limit) pushed ~40G/backup of page cache
through docker_limit.slice, swapping the DB nightly; destroying it stranded
~11G charged to the slice with no living owner (slice memory.current minus sum
of child scopes). drop_caches recovered only 1.5G; guarded 512M-step
`memory.reclaim` writes (swappiness= arg rejected by 6.17.0-1019-aws kernel)
or host reboot clear it. `docker compose down` cannot - containers don't own
the charge. Prevention: always-on `mem_limit: ${DB_BACKUP_MEM_LIMIT:-2g}` +
equal memswap_limit in templates/bkp.yml (NOT the opt-in resources overlay);
dump OOM (exit 137) on blob-heavy sites -> raise to 4g. Alert on
swap_used_percent + mem_available_percent, not mem_used_percent (idles 80%+ by
design). Full runbooks: ~/Bolton_docker_cgroup_memory_analysis.md,
~/innodb-buffer-pool-audit.md. See [[bolton-prod-slow-query-analysis]].
