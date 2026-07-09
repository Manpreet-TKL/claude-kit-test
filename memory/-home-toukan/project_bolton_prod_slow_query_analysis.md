---
name: bolton-prod-slow-query-analysis
description: Bolton prod (OE v26.0.6) slow-log analysis done 2026-07-08; report + ready DDL at ~/Bolton_prod_slow_analysis.md
metadata: 
  node_type: memory
  type: project
  originSessionId: d80dee4e-1d2a-41f7-8c20-b38046111ac2
---

Analysed ~/Bolton_prod_slow.log (33.7h, 2026-07-07/08) on 2026-07-08. Report with ready-to-run DDL: `~/Bolton_prod_slow_analysis.md`; distinct queries file: `~/Bolton_prod_slow_unique_queries.log`.

Key facts: 94% of slow time = Mirth Database Reader polling `request_routine` ('dicom_queue') every 2s full-scanning 2M rows - fix is `ADD INDEX (execute_request_queue, status)` (benchmarked 4.3s -> 0.7ms at prod cardinality). PatientTicketing VC queries need `patientticketing_ticketqueue_assignment (ticket_id, created_date, id)` + queue-driven rewrite of DefaultController.php:117 (window-function rewrite is 5x WORSE - benchmarked). Other missing prod indexes: contact.pas_id, user_session.expire, event(event_type_id, created_date), pasapi_assignment.internal_type, version-table `id` indexes (only 27/1066 have one). Nightly ETL (client_user@10.28.x.x) full-dumps whole tables incl. 1.6GB letters x2. v26.0.6 tag already contains idx_pta_*/worklist/letter perf indexes; snail carries an out-of-band user_session_expire index found in no migration.
