---
name: pptest-seed-run-2026-07-28
description: "pptest v26.1 seed produced with interim leanings; artifact locations, snail stash breadcrumb, oe-checkout dirty-module gotcha"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7ddcebe5-1588-40bc-a02d-e44660e57b8d
  modified: 2026-08-03T14:15:59.453Z
---

The pptest cleardown ran clean on 2026-07-28: dump migrated to v26.1.0-pre2 (75s,
125 migrations), cleardown --keepConfig=1 --clearUsers=1 with the 130 interim
leanings, verify PASSED, admin/admin login OK. Seed at
`/home/toukan/pptest-seed-v26-1-template-config.sql` (201M). Categorised pre/post
diff had ZERO violations (S/R/M/G untouched; only P/Q/E/V, I surgery and 6
user-pruned C tables changed). Artifacts: pre/post count snapshots + cleardown log
in `/home/toukan/cleardown/artifacts/`. Side DB `pptest` dropped (source dump kept).

Breadcrumbs and gotchas:

- `oe-checkout.sh` hard-aborts when ANY module checkout in the container is dirty.
  A `git stash push` inside the module unblocks it without reset --hard. The
  "cleardown-campaign: 51-SetupCCGandLA address-columns compat patch" stash that
  lived on the sample module in snail-web-1 is GONE (2026-08-03: web container
  recreated; the fix is now upstream in sample develop, commit 060436f "fix risk
  institutions + ccg demo script", so no stash or patch is needed anymore; patch
  copy kept at /home/toukan/snail-sample-module-stash-cleardown-compat.patch).
- `yiic cleardown report` takes NO profile flags (classification is
  profile-independent; it prints all three profiles' reference checks). Flags
  belong to index/verify only.

Related: [[oe-deploy-conventions]]
