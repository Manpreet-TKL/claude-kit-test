---
name: cleardown-pptest-campaign
description: "cleardown v3 / pptest seed campaign - battery PASSED 2026-08-02, d walk + e smoke PASSED 2026-08-03 (8 S leanings, 2 ensure floors); v26.1 seed at ~/pptest-seed-v26-1-template-config.sql; open: leanings review, battery re-run, seed-regen decision"
metadata:
  type: project
---

Merged 2026-08-19 from the battery and seed-run memories (same campaign, ~/cleardown/campaign).

**Seed run 2026-07-28:** pptest dump migrated to v26.1.0-pre2 (75s, 125 migrations),
`cleardown --keepConfig=1 --clearUsers=1` with the 130 interim leanings, verify PASSED,
admin/admin login OK. Seed at `~/pptest-seed-v26-1-template-config.sql` (201M);
categorised pre/post diff had ZERO violations (S/R/M/G untouched; only P/Q/E/V, I surgery
and 6 user-pruned C tables changed). Artifacts in `~/cleardown/campaign/artifacts/`; side DB
`pptest` dropped (source dump kept).

**Battery 2026-08-02:** `~/cleardown/campaign/battery-pptest.sh -s` PASSED all six runs (a, b, c,
default, d, e) - verify green, logins OK, idempotency 0 fail, pairwise confinement exact;
report `~/cleardown/campaign/artifacts/pptest.battery.txt`. Fixes it forced: generic self-FK-safe
subtree prune (`pruneResidue`), kept users' login bindings at dropped institutions die
with them (scenario c crash), `country` promoted R->S (NOT NULL `address.country_id`).

**Interactive tail 2026-08-03:** d 35-admin-page Chrome walk PASSED; e smoke (patient
create -> Examination -> Clinic Outcome -> save -> view) PASSED on walk 7 after six
break-fix rounds. Eight tables S-promoted via leanings (all LIKELY, awaiting veto):
ophcodocument_sub_types, service, service_subspecialty_assignment,
ophciexamination_clinicoutcome_role, ophciexamination_clinicoutcome_risk_status,
ophciexamination_discharge_status, ophciexamination_discharge_destination,
pathway_step_type. Two ensure floors added (pattern of ensurePersonalMailboxes):
ensureExaminationWorkflow (Default workflow + catch-all rule + element set after
`--clearWorkflows`/e) and ensureDefaultPathway (m210715 'Default pathway' row id 1 -
`worklist_definition.pathway_type_id` DEFAULT 1 FK dies without it on any event save).
catdiff.pl `%floor_ok` tolerates both.

**Still open:** (1) consolidated leanings review incl. the eight smoke promotions;
(2) battery re-run - ledger and command changed since the PASS; (3) whether to regenerate
the pptest seed under scenario d as the new deliverable; (4)
patient_identifier_type_display_order rowRule (patient search dead on d/e templates).

**Gotchas:** `oe-checkout.sh` hard-aborts when ANY module checkout in the container is
dirty - `git stash push` inside the module unblocks it without reset --hard (the old
sample-module compat stash is gone; the fix is upstream in sample develop 060436f, patch
copy at `~/cleardown/snail-sample-module-stash-cleardown-compat.patch`). `yiic cleardown report`
takes NO profile flags (classification is profile-independent); flags belong to
index/verify only. Related: [[oe-deploy-conventions]].
