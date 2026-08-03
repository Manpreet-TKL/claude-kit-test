---
name: cleardown-v3-battery-2026-08-02
description: cleardown v3 battery PASSED 2026-08-02; d walk + e smoke PASSED 2026-08-03 after 6 break-fixes (8 S leanings, 2 ensure floors); battery re-run + leanings review pending
metadata: 
  node_type: memory
  type: project
  originSessionId: 7ddcebe5-1588-40bc-a02d-e44660e57b8d
  modified: 2026-08-03T02:51:45.383Z
---

The cleardown v3 five-scenario battery (`~/cleardown/battery-pptest.sh -s`) PASSED on
the migrated pptest dump on 2026-08-02: all six runs (a, b, c, default, d, e) verify
green, logins OK, idempotency 0 fail, pairwise confinement exact; report at
`~/cleardown/artifacts/pptest.battery.txt`. Three fixes were forced by it: a generic
self-FK-safe subtree prune (`pruneResidue`), kept users' login bindings at dropped
institutions now die with them (scenario c crash), and `country` promoted R->S
(NOT NULL `address.country_id` on surgery-kept rows breaks `--bareSystem` otherwise).

Interactive tail DONE 2026-08-03: the d 35-admin-page Chrome walk PASSED, and the e
smoke (patient create -> Examination -> Clinic Outcome -> save -> view) PASSED on
walk 7 after six break-fix rounds. Eight tables were S-promoted via leanings (all
LIKELY, awaiting Manpreet's veto): ophcodocument_sub_types, service,
service_subspecialty_assignment, ophciexamination_clinicoutcome_role,
ophciexamination_clinicoutcome_risk_status, ophciexamination_discharge_status,
ophciexamination_discharge_destination, pathway_step_type. Two ensure floors were
added to the command (pattern of ensurePersonalMailboxes): ensureExaminationWorkflow
(Default workflow + catch-all rule + element set after `--clearWorkflows`/e) and
ensureDefaultPathway (m210715 'Default pathway' row, id 1, after e - the
worklist_definition.pathway_type_id DEFAULT 1 FK dies without it on any event save).
catdiff.pl `%floor_ok` tolerates both floors.

Still open: (1) the consolidated leanings review (now including the eight smoke
promotions); (2) battery re-run - the ledger and command changed since the PASS;
(3) whether to regenerate the pptest seed under scenario d as the new deliverable;
(4) patient_identifier_type_display_order rowRule question (patient search dead on
d/e templates). See [[pptest-seed-run-2026-07-28]].
