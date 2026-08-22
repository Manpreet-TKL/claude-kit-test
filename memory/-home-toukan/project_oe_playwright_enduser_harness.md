---
name: project_oe_playwright_enduser_harness
description: Planned standalone Playwright harness that mimics OE end-user journeys (UI-only, CDP chromium sidecar); plan approved 2026-06-25 but NOT started - stack and target env both still to be supplied by Manpreet
metadata:
  type: project
---

Manpreet wants a NEW, standalone, dockerised FOSS Playwright harness for OpenEyes that
**mimics end users** - multi-step UI journeys (login -> search -> create patient -> create
examination -> ...) for CSV-driven admin runbooks, training-video recording, error sweeps,
slow-page finding, sample-data generation, load, and Claude-callable doc generation. It is
**independent of `/home/toukan/OpenEyes/playwright/`** (that suite verifies page/data
correctness via the backend TestHelper API) - borrow its conventions (config defaults,
`getByTestAttr`, POM style, `domHasStoppedChanging`, fixture composition), import nothing.

Locked decisions (plan approved 2026-06-25): UI-only / no TestHelper; CDP to a lightweight
Chromium sidecar (harness container = Node only); load via Playwright browser contexts only
(`workers:1` DB-deadlock ceiling); scaffold + core spine + a few worked examples first; no
pinned environment (docker network, `BASE_URL`, cookie name, creds via `.env`); one shared
`artifacts/` volume; runtime version gate from `#js-openeyes-info` on `/site/login`
(`params['oe_version']`), exit code 3 if unsupported; README + `docs/ARCHITECTURE.md` +
auto-docs from StepLogs.

**Status 2026-08-19: not started - no repo exists.** Full plan at
`~/claude-kit/todo/oe-playwright-harness-plan.md`.
Do not build until Manpreet supplies BOTH the stack AND the target environment.
Related: [[project-oe-frontend-tests-repo]] (the existing, different suite),
[[oe-deploy-conventions]] (sample instances seed `admin`/`admin`).
