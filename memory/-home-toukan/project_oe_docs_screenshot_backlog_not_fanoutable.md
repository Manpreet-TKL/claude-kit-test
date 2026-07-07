---
name: project_oe_docs_screenshot_backlog_not_fanoutable
description: "OeDocumentation screenshot backlog can't be cleared by a parallel agent fan-out; capture.cjs is direct-URI only and the residual is gated on serial writes, bugs, and unpopulated modules. Canonical backlog now lives IN-MODULE at docs/help/screenshot-backlog.md."
metadata: 
  node_type: memory
  type: project
  originSessionId: 4b3560d9-aca1-4a90-b53d-e1db4636444c
---

The OeDocumentation Phase-6 screenshot backlog is **not** a parallel-fan-out job (a 20-Haiku-agent
attempt was the wrong tool - proven empirically 2026-07-05). `resources/capture.cjs` logs in once
and does direct-URI GET + optional `selector=` clip only - **no click navigation, no form fill, no
DB writes**. The click/journey driver `journey.mjs` that the plan's S4 step assumed is a scratchpad
tool that gets **wiped** (like the scratchpad + chrome cache) and no longer exists.

**Canonical backlog (2026-07-05, post deprecated re-org): the in-module page
`docs/help/screenshot-backlog.md`** - 62 of 456 markers missing (394 captured, container/host
in sync), each with its `needs=`/`nav=`/`selector=` regeneration recipe inlined.
Not-installed event types moved to `docs/deprecated/` and their 31 impossible markers were
removed from the manifest entirely. `~/oe-docs-shot-backlog.md` is a stale external duplicate.

Why the residual can't be bulk-captured (buckets in that page): B=6 op-note shots 500'd by
**BUG-042** (Element_OpNote view suppression); C=14 placeholder-uri shots
(`/.../default/view/{event_id}`) where the module is installed but has **zero sample events
DB-wide**; D=6 populated-module shots whose element-clip `selector=` isn't in the rendered view
(per-shot manual framing); E=1 event-create (UI journey + DB write, serial only); F=32 no direct
route (click-journeys / dynamic ids); G=3 real-id-still-errors (sso-login, admission-form,
whiteboard). The old 105 count included special-module shots (moved out with their docs) and 4
help/* syntax-example false positives; the old 93 included the 31 now-deleted deprecated markers.

Cheap read-only wins are already banked - clean bare-uri shots are all captured. Copy captured
shots to host with a selective `docker cp` OUT of the container's `docs/screenshots` (NOT
`copyin.sh out`); the user pushes the whole module from the host.
See [[project_oe_eventimage_docman_render_testing]] and [[project_oe_document_pdf_probe_recipe]].
