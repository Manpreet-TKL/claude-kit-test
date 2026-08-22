---
name: project_oe_docs_screenshot_backlog_not_fanoutable
description: "OeDocumentation screenshot backlog can't be cleared by a parallel agent fan-out; capture.cjs is direct-URI only and the residual is gated on serial writes, bugs, and unpopulated modules. Canonical backlog now lives IN-MODULE at docs/help/screenshot-backlog.md."
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b3560d9-aca1-4a90-b53d-e1db4636444c
  modified: 2026-08-10T12:18:24.126Z
---

The OeDocumentation Phase-6 screenshot backlog is **not** a parallel-fan-out job (a 20-Haiku-agent
attempt was the wrong tool - proven empirically 2026-07-05). `resources/capture.cjs` logs in once
and does direct-URI GET + optional `selector=` clip only - **no click navigation, no form fill, no
DB writes**. The click/journey driver `journey.mjs` that the plan's S4 step assumed is a scratchpad
tool that gets **wiped** (like the scratchpad + chrome cache) and no longer exists.

**Canonical backlog (refreshed 2026-08-10): the in-module page
`docs/help/screenshot-backlog.md`** - 56 of 710 markers missing (654 captured, container/host
in sync, page reconciles entry-for-entry with `yiic oedocs shots --section=all --missing=1`),
each with its `needs=`/`nav=`/`selector=` regeneration recipe inlined.
The Jul-2026 `~/oe-docs-shot-backlog.md` duplicate has been deleted; the
separate hardcoded-id marker inventory now lives at kit
`knowledge/oe-docs-shot-id-inventory.md`.

Why the residual can't be bulk-captured (buckets in that page): 13 auto = `review/` skeletons
whose routes answer HTTP 500/400 even logged in (app-blocked, not capture-blocked); B=6 op-note
element shots needing a procedure-specific note (Biometry never capturable, BUG-043); C=20
no-sample-data (8 op-checklists blocked by the missing `secondary_diagnosis` table, 5 Visual
Fields with no create path, 7 seedable-but-serial); D=1 selector absent in view; F=26 click-
journey/gated routes; G=3 real-id-still-errors. The seedable ADMIN screens were cleared
2026-08-10 by the Playwright seed suite in `~/oe-frontend-tests/tests/seed` (see
[[project-oe-frontend-tests-repo]]) - 16 shots captured in one pass once the data existed.

Cheap read-only wins are already banked - clean bare-uri shots are all captured. Copy captured
shots to host with a selective `docker cp` OUT of the container's `docs/screenshots` (NOT
`copyin.sh out`); the user pushes the whole module from the host.
See [[reference_oe_render_testing_gotchas]] and [[oe-document-pdf-probe-recipe]].
