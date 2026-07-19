---
name: project_oe_playwright_enduser_harness
description: New standalone Playwright repo mimics end-user journeys (UI-only); distinct from OpenEyes/playwright which verifies page data
metadata: 
  node_type: memory
  type: project
  originSessionId: be2c5a1c-8e77-4791-9f84-334ff554bf0e
---

Manpreet is building a NEW, standalone, dockerised FOSS Playwright harness for
OpenEyes whose purpose is to **mimic end users** - multi-step real UI journeys
(login -> search -> create patient -> create examination -> ...) for: CSV-driven admin
runbooks, training-video recording, error sweeps, slow-page finding, sample-data
generation, load, and as Claude-callable tools that auto-generate docs.

**It is independent of `/home/toukan/OpenEyes/playwright/`** - own repo/dir, own
`package.json`, own POMs/selectors, importing nothing from it. That existing suite
focuses on **page/data correctness** (seeds state fast via the backend TestHelper API,
loads one page, asserts element values) - borrow its conventions (config defaults,
`getByTestAttr`, POM style, `domHasStoppedChanging`/`waitForNextPaint`, form components,
fixture composition) but diverge: UI-only login, no TestHelper/seeders, journeys span
many pages, add run-modes + error/perf collectors + StepLog schema.

Locked decisions (asked 2026-06-25, **plan approved 2026-06-25**): **UI-only / fully
self-contained** (no TestHelper API); **CDP to a lightweight Chromium sidecar** (harness
container = Node only); **load via Playwright browser contexts only** (respect the suite's
`workers:1` DB-deadlock ceiling); build **scaffold + core spine + a few worked examples
first**, then extend. Later refinements: **don't pin to any environment - user supplies it**
(docker network name, `BASE_URL`, session-cookie name, creds all via `.env`); **one shared
`artifacts/` volume** with subfolders (videos/screenshots/traces/reports/docs/state);
**runtime version gate** - detect OE version from the About-panel markup `#js-openeyes-info`
(`Version: {oe_version}`, present pre-auth on `/site/login`; source of truth is
`params['oe_version']` in `protected/config/core/common.php`) and **abort early with exit
code 3** if unsupported (allow-list in `selectors/supported.ts`; `OE_VERSION_ENFORCE` toggles
dev/UNRELEASED); **well-documented** (`README.md` how-to-use + `docs/ARCHITECTURE.md`
how-it-was-built, plus auto-docs from StepLogs). **Stack/tooling still TBD AND target
environment still TBD - user will supply both before any build.**

**Why:** keeps the harness runnable against any instance/version and avoids coupling
to the regression suite's tsconfig alias + pinned Playwright version.

**How to apply:** approved plan doc lives at `/home/toukan/oe-playwright-harness-plan.md`
(full detail: architecture, selector-map + version-gate strategy, run modes, the four
capabilities, docker-compose sidecar shape, single-volume artifact layout, documentation
deliverables); the plan-mode copy is `/home/toukan/.claude/plans/can-you-make-a-valiant-truffle.md`.
**No default environment** - wait for the user to hand over BOTH the chosen stack AND the
target environment before building. Related: [[oe-deploy-conventions]]
(sample instances seed `admin`/`admin`), [[monkey-environment]].
