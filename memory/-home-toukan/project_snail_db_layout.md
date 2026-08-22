---
name: snail-db-layout
description: "Since 2026-08-10 snail's `openeyes` DB is the official sample DB; the keeper dataset is parked at `openeyes2`"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7f4b956c-11d9-43af-b3d6-bed06c12a1d5
  modified: 2026-08-10T09:59:34.565Z
---

On the snail stack, `openeyes` was reset to the official sample DB (oe-reset.sh, admin/admin, 2367 tables / 2284 patients) on 2026-08-10 so the screenshot backlog can run against sample data. The previous dataset - a keeper, NOT the sample DB - lives intact in `openeyes2` (2606 tables, 57 views, 3 triggers, 5 routines, 421,849 patients, ~64GB); app-user grants mirrored onto it. Secondary-object DDL backup at snail-db-1:/var/tmp/oe-park. Unit drift vs the corpus manifest on sample data: 2 added (deprecated MEH PAC pre-assessment), 12 element-types re-check-flagged, 0 gone; committed coverage.json left untouched. `oedocs repoint`: 0 markers to re-aim, 10 blocked on demo-data events (see [[project_oe_docs_screenshot_backlog_not_fanoutable]]).
