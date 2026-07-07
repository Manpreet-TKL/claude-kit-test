---
name: project-oe-frontend-tests-repo-purpose
description: The oe-frontend-tests repo (formerly oe-sitemap) is an end-user frontend Playwright test suite; dockerised with two images.
metadata: 
  node_type: memory
  type: project
  originSessionId: be2c5a1c-8e77-4791-9f84-334ff554bf0e
---

The `/home/toukan/oe-frontend-tests` repo (renamed from `oe-sitemap` on
2026-06-25 — the old name misled, it was never a sitemap tool) is for **testing
OpenEyes end-user scenarios through the app's frontend** with Playwright. The
page-discovery crawler (`src/areas`, `tools/probe.mjs`, `tools/build-index.mjs`)
was a one-off seed and is now just an authoring tool. The sample-data marker
typed into forms is `oe-frontend-test`.

Current tests, two Playwright projects (both depend on the `setup` login):
- `admin` (`tests/admin/`) — baseline reachability+archetype spec
  (`admin-pages.spec.mjs`, ~267 pages) plus 33 deep section specs; ~417 pass,
  3 `test.fixme`.
- `app` (`tests/app/`, added 2026-06-25) — whole-app coverage of the **non-admin**
  pages: `app-reachability.spec.mjs` = one reachability test per discovered page
  (80, from `tests/fixtures/app-pages.json`), plus gesture specs `directories`
  (practices/GPs), `trials`, `patient-record`. All read-only.

All gestures (search, open Add forms, fill fields, open records) never persist;
the sample-data marker typed into forms is `oe-frontend-test`.

Two OE-specific Playwright gotchas (both bit during this work):
- **`networkidle` never settles** — OE long-polls (notifications/worklist). Navigate
  on `domcontentloaded` + `load` + a short `waitForTimeout`, like the crawler's
  `gotoSettle` / admin `gotoAdmin`. Never `waitForLoadState('networkidle')`.
- **List rows open records via a JS row-click, not an `<a href>`** (practices `/practice/index`,
  GPs `/gp/index`, CVI, genetics, reports…). `table tbody tr a[href]` is empty; only
  `/OETrial` has real row anchors. To drill into a detail page, click the first
  `table.standard tbody tr:has(td)` and read where it navigates. Also: a patient summary
  carries ~146 `/default/view/` event links but the first is hidden in a collapsed panel —
  filter `:visible`.

Sitemap now spans 62 areas / 390 pages (was 37/334). New crawlers
`src/areas/top-level.mjs` (24 menu destinations, click-through row discovery) and
`src/areas/patient-record.mjs` (deep read-only walk of patient 17891, ≤3 views per
event module). New author tools: `tools/build-pages-fixture.mjs` →
`tests/fixtures/app-pages.json` (non-admin reachable pages, dedup by URL), and
`tools/build-tree.mjs` → `docs/sitemap/TREE.md` (page tree at family → area →
distinct-route depth).

Dockerised (two images from one multi-stage `Dockerfile`):
`oe-frontend-tests:run` (slim, just runs the suite) and `:author` (full
toolchain). `docker-compose.yml` has `tests`/`author`/`report` services on the
external `snail_backend` net. Password via Docker secret `OE_PASSWORD_FILE`
(`secrets/oe_password.txt`, sample=`admin`); `PAGES_CSV` replaces the page list
(loader `tests/fixtures/pages.mjs`); artifacts (report + traces + videos) land
host-owned in `artifacts/` via `HOST_UID`/`HOST_GID`. Dev loop (`test.sh`,
official image + bind mount) is unchanged. Related: [[project-oe-playwright-enduser-harness]].
