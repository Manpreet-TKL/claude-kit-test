---
name: project-oe-frontend-tests-repo
description: "~/oe-frontend-tests (ex oe-sitemap) - end-user FRONTEND Playwright suite: admin + app projects, the OeDocumentation demo-data seed suite (tests/seed, idempotent, 29-token manifest), two docker images; OE gotchas - no networkidle, JS row-click lists, SSO all-required, Yii lowercase redirects, BUG-531 dropdown"
metadata:
  type: project
---

Merged 2026-08-19 from the repo-purpose and seed-suite memories (same repo).

## Purpose and layout

`/home/toukan/oe-frontend-tests` (renamed from `oe-sitemap` 2026-06-25) tests OpenEyes
end-user scenarios through the frontend with Playwright. The page-discovery crawler
(`src/areas`, `tools/*.mjs`) was a one-off seed and is now an authoring tool (62 areas /
390 pages; `docs/sitemap/TREE.md`). Sample-data marker typed into forms: `oe-frontend-test`.

Projects (all depend on the `setup` login): `admin` (`tests/admin/`, ~267-page
reachability+archetype spec + 33 deep section specs), `app` (`tests/app/`, 80-page
reachability from `tests/fixtures/app-pages.json` + read-only gesture specs directories,
trials, patient-record), and `seed` (below). Dockerised from one multi-stage Dockerfile:
`oe-frontend-tests:run` (slim) and `:author` (full toolchain); compose services
`tests`/`author`/`report` on the external `snail_backend` net; password via Docker secret
`OE_PASSWORD_FILE` (sample=`admin`); `PAGES_CSV` overrides the page list; artifacts land
host-owned in `artifacts/` via `HOST_UID`/`HOST_GID`; dev loop `test.sh`, seed loop
`seed.sh` (repo root).

## OE Playwright gotchas

- `networkidle` never settles (OE long-polls) - navigate on `domcontentloaded` + `load` +
  a short `waitForTimeout`; never `waitForLoadState('networkidle')`.
- List rows open records via a JS row-click, not `<a href>` (practices, GPs, CVI, genetics,
  reports; only `/OETrial` has real anchors) - click the first
  `table.standard tbody tr:has(td)` and read where it lands. Patient summary event links:
  the first is in a collapsed panel - filter `:visible`.
- Debug toolbar suppressed at the network layer: capture.cjs blocks `*/debug/*` via CDP,
  seed specs route-abort `**/debug/*/toolbar*` in beforeEach.

## OeDocumentation demo-data seed suite (`tests/seed/`)

admin/checklist/consent/events/users/worklist specs + helpers.mjs, driven by `seed.sh`
(Playwright v1.55.0-noble on snail_backend, BASE_URL http://web, recipes CSV from
`~/Temp10/oedocumentation-test/data/demo` mounted RO). 2026-08-10: 30/30 green and proven
idempotent (second run probes, skips every write, ~1.4m); the 29-token manifest installs to
the container's `runtime/oedocs_demo_manifest.json` only when every spec passes. Token
contract: lower_snake_case ending `_id`; a page's `demo_data:` front matter must name a
token declared as `- **Token:**` in `docs/help/demo-data-recipes.md` or
`yiic oedocs lint --strict=1` fails. Baked-in gotchas (re-learn nothing):

- SSO config (`/admin/editssoconfig`): ALL OIDC attributes required non-blank; the four
  field-mapping KEY inputs are readonly - fill only VALUE inputs; save lands on `/admin/ssoconfig`.
- Yii lowercases controller segments in redirects (`/OphCiExamination/admin/historyMacro/list`)
  - post-save waitForURL must be case-insensitive.
- Systemic diagnoses set form: autocomplete pick broken (BUG-531) - seed via
  `select.commonly-used-diagnosis` (async from `/disorder/getcommonlyuseddiagnoses/type/systemic`).
- Wait times screen ships a disabled mustache template row - selectors need `:not([disabled])`.
- Teams: memberless teams forced inactive; non-Super-Team-Manager sees only Own/Manage teams;
  Add Team form broken without the team-role permission (BUG-530).
- Worklist seeding respects one-unbooked-list-per-day - [[reference_oe_unbooked_worklist_first_event_claims]].

Bugs found while seeding go to `/home/toukan/openeyes_unverified_bugs.md` + `known_issues:`
stamps on the pages. Backlog state: [[project_oe_docs_screenshot_backlog_not_fanoutable]].
Related: [[project_oe_playwright_enduser_harness]].
