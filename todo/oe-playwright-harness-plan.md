# OpenEyes Playwright Operator/Agent Harness — Plan

> Status: plan **approved** (2026-06-25). **Stack TBD** and **target environment TBD** —
> the user will supply both before any build; nothing has been built yet. This document
> is the standalone copy of the approved plan.
>
> Purpose of the new repo: **mimic end users** — real, multi-step UI journeys through
> the app. This is deliberately different from the existing suite at
> `/home/toukan/OpenEyes/playwright/`, which focuses on verifying the **data/correctness
> of individual pages** (seed via the backend TestHelper API, then assert page contents).
> "Learnings from the existing suite" is at the end.

## Context

We want a dockerised, FOSS Playwright harness that runs **side-by-side** with an
OpenEyes deployment and drives the app's frontend **in Chrome only**, mimicking a
real end user. It is an *operator/agent toolkit*, not the CI regression suite — it
provisions the app from CSVs, records training videos, finds errors and slow pages,
generates sample data, and exposes each scenario as a tool Claude can run and then
document.

The harness is **independent** of `/home/toukan/OpenEyes/playwright/` — its own
repo/dir, own `package.json`, own POMs and selectors, importing nothing from that
folder. That removes coupling to its tsconfig alias and pinned Playwright version, and
keeps the harness runnable against *any* instance/version.

### Locked design decisions

| Area | Decision |
|---|---|
| State/setup & bulk data | **UI-only, fully self-contained.** No TestHelper API, no seeders. Preconditions and bulk creation are reusable UI flows. |
| Browser | **CDP to a lightweight Chromium sidecar.** Harness = Node only; a small `oe-chromium` container holds the browser; connect over CDP. |
| Load testing | **Playwright browser contexts only.** N contexts in the sidecar browser, capped; document the `workers:1` DB-deadlock ceiling. |
| Scope/phasing | **Scaffold + core primitives + a few worked examples first**, then extend across all four capability areas. |
| Licensing/stack | FOSS only: Playwright (Apache-2.0), Node, `papaparse`. |

**The target environment is supplied by the user** and is entirely env-driven — the
harness pins nothing to a specific deployment. The Docker network name, base URL,
session-cookie name, and credentials all come from `.env`, so the same image runs
against any OpenEyes instance. The values in `.env.example` are placeholders only.

---

## Architecture

```
                 docker network (external: ${OE_NETWORK})
   ┌─────────────┐        CDP ws          ┌──────────────────┐      HTTP       ┌─────────┐
   │ oe-harness  │ ─────────────────────▶ │   oe-chromium    │ ──────────────▶ │  OE app │
   │ (Node only) │  ws://oe-chromium:3000 │ (Playwright srv) │  ${BASE_URL}    │         │
   └─────────────┘                        └──────────────────┘                 └─────────┘
        │ writes
        ▼
   ./artifacts   (ONE shared volume — subfolders: videos/ screenshots/ traces/ reports/ docs/ state/)
```

- `oe-harness`: built from a slim Node image (no browser). Runs the CLI/test runner,
  connects to the sidecar via `chromium.connect()` / `connectOverCDP()`. Low memory.
- `oe-chromium`: **dedicated** Playwright browser server (NOT the app's browserless
  `chrome`, to avoid contending with PDF rendering). Same pinned Playwright version as
  the harness so `chromium.connect()` works with full feature parity (video/trace).
  `shm_size` sized for the number of concurrent contexts (load mode).
- Both join the user-supplied app network (`OE_NETWORK`) as `external`, so the harness
  resolves the app by its in-network service name. The app URL (`BASE_URL`) and any host
  header are env-driven; nothing is pinned to a specific deployment.
- **One shared volume** (`./artifacts`) mounted into *both* containers at the *same path*,
  so the video/trace files the chromium sidecar writes server-side land where the harness
  can read them. Every artifact kind lives in a subfolder of this single volume (see below).

### docker-compose.harness.yml (shape)

```yaml
services:
  oe-chromium:
    image: oe-harness-chromium          # FROM mcr.microsoft.com/playwright:vX.Y.Z, runs `playwright run-server --port 3000`
    shm_size: "1073741824"              # 1 GB; raise for many load contexts
    mem_limit: "1610612736"             # ~1.5 GB
    networks: [oe_net]
    volumes: [ ./artifacts:/work/artifacts ]   # SAME single volume, SAME path as harness
    profiles: ["harness"]

  oe-harness:
    build: { context: ., dockerfile: Dockerfile }   # slim node, no browser
    mem_limit: "536870912"              # ~512 MB
    environment:
      BASE_URL: "${BASE_URL}"                  # full app URL, user-supplied (e.g. http://<svc>:<port>)
      CDP_WS: "ws://oe-chromium:3000"
      OE_USERNAME: "${OE_USERNAME}"
      OE_PASSWORD: "${OE_PASSWORD}"
      OE_INSTITUTION: "${OE_INSTITUTION:-}"    # name or id to click at login
      OE_SITE: "${OE_SITE:-}"
      OE_SESSION_COOKIE: "${OE_SESSION_COOKIE}" # session cookie name for this deployment
      RUN_MODE: "${RUN_MODE:-errors}"          # errors | slow | load
      APP_VERSION: "${APP_VERSION:-auto}"      # auto = detect at runtime; or pin to override the selector map
      OE_VERSION_ENFORCE: "${OE_VERSION_ENFORCE:-true}"  # abort on unsupported/unknown; set false to allow dev/UNRELEASED
      ARTIFACTS_DIR: "/work/artifacts"
    volumes: [ ./artifacts:/work/artifacts ]   # SAME single volume, SAME path as chromium
    networks: [oe_net]
    profiles: ["harness"]

networks:
  oe_net: { external: true, name: "${OE_NETWORK}" }   # user supplies the app's docker network name
```

Invocation is one line: `docker compose -f docker-compose.harness.yml run --rm oe-harness oeh <cmd>`.

---

## Project layout

```
/home/toukan/oe-harness/                 # standalone; rename freely
├── README.md                            # how to USE it: quickstart, env, every tool, run modes, exit codes
├── docs/
│   ├── ARCHITECTURE.md                  # how it was CONSTRUCTED: the spine, design rationale, trade-offs
│   ├── SELECTORS.md                     # selector-map + version-gating strategy; how to add a release
│   └── WRITING-TOOLS.md                 # the recipe Claude follows to add a tool/flow/runbook
├── package.json                         # @playwright/test, papaparse, yaml, zod
├── tsconfig.json
├── playwright.config.ts                 # projects = run modes; reporter per mode
├── Dockerfile                           # slim node harness
├── Dockerfile.chromium                  # playwright run-server sidecar
├── docker-compose.harness.yml
├── .env.example
├── bin/oeh                              # thin CLI dispatcher (Claude-callable)
├── src/
│   ├── config/
│   │   ├── env.ts                       # parse+validate env once
│   │   └── runModes.ts                  # RunMode enum + per-mode policy
│   ├── browser/connect.ts               # chromium.connect(CDP_WS) → context (testIdAttribute:'data-test')
│   ├── selectors/                       # CENTRAL version-keyed selector map
│   │   ├── types.ts  index.ts  default.ts
│   │   ├── supported.ts                 # supported-version allow-list (the fail-fast gate)
│   │   └── versions/v26.x.ts            # sparse per-release overrides
│   ├── core/
│   │   ├── auth.ts                      # UI login primitive (institution→site→firm)
│   │   ├── version.ts                   # VersionDetector + supported-range gate (fail fast)
│   │   ├── settle.ts                    # domHasStoppedChanging + waitForNextPaint (own impl)
│   │   ├── errors.ts                    # ErrorCollector (console/pageerror/4xx-5xx/PHP+Yii sigs)
│   │   ├── perf.ts                      # PerfCollector (nav timing, FCP, networkidle, settle)
│   │   └── steplog.ts                   # StepLog + Report writers (the doc/agent foundation)
│   ├── pom/                             # thin POMs, all selectors via selectors/index
│   │   ├── LoginPage.ts  PatientSearch.ts  AdminUserForm.ts  ExaminationEvent.ts
│   ├── flows/                           # reusable UI actions (double as preconditions + data gen)
│   │   ├── findOrCreatePatient.ts
│   │   └── createExaminationEvent.ts
│   ├── capabilities/
│   │   ├── runbook/                     # CSV→form engine (engine.ts, config schema, fillers, transforms)
│   │   ├── sweep/                       # error + slow-page sweep over a flow list
│   │   ├── load/                        # N-context load driver
│   │   └── docgen/                      # StepLog/Report → markdown
│   ├── tools/                           # one CLI per capability (JSON in, JSON out, stable exit codes)
│   │   ├── run-runbook.ts  sweep.ts  examination-elements.ts  generate-data.ts  record-demo.ts
│   └── tests/                           # @-tagged example specs (independent, idempotent)
│       ├── smoke/login.spec.ts
│       ├── sweep/popular-pages.spec.ts
│       └── examination/elements-load.spec.ts
├── config/
│   ├── pages.popular.json               # the "most-used flows" list (sweep + load source of truth)
│   └── runbooks/users.runbook.yaml      # example CSV mapping config
└── artifacts/                           # gitignored; ONE volume, subfolders below
    ├── videos/  screenshots/  traces/   # browser artifacts (written by the sidecar)
    ├── reports/                         # *.json — errors / slow / load / StepLog
    ├── docs/                            # auto-generated run docs (docgen output)
    └── state/                           # runbook checkpoints (*.state.jsonl)
```

---

## Core primitives (the reusable spine — built first)

These are version-proofing and reuse leverage; capabilities are thin layers on top.

### 1. Central selector map (`src/selectors/`)
A single version-keyed map so a release that renames a selector = one sparse edit in
`versions/vN.x.ts`. Prefer the `data-test` hooks that already exist. Known-good anchors
discovered during exploration (UI-only paths):

- **Login** (`/site/login`, form `#loginform`): `data-test` =
  `login-username-input`, `login-password-input`, `login-button`,
  `login-institution-selection`, `login-site-selection`, `institution-id-input`,
  `site-id-input`; clickable institution/site rows `.js-institution`/`.js-site` carry
  `data-id`. **Version readout:** `#js-openeyes-info` holds `Version: {oe_version}`
  (present in the DOM **pre-auth**, hidden until `#js-openeyes-btn` is clicked — but
  readable via `textContent()` without clicking). Creds come from env (sample
  instances seed `admin`/`admin`).
- **Admin user create** (`/admin/addUser` → `editUser`, form `#adminform`):
  `#User_first_name`, `#User_last_name`, `#User_email`, `#User_title`,
  `#Contact_qualifications`, roles via **custom** multiselect `User[roles]`
  (a `-- Add --` picker, **not** native `<select multiple>`), auth row by `name=`:
  `UserAuthentication[0][username]`, `[password]`, `[password_repeat]`,
  `[institution_authentication_id]` (must select a LOCAL inst-auth to enable the
  password fields), `[active]`; save `#et_save` (`data-test="et_save"`); error block
  `.errorMessage` / the `_form_errors` partial.
- **Examination** (`OphCiExamination`): element manager opens via `#js-manage-elements-btn`;
  each element button `id="manage-elements-{kebab-name}"`; clicking fires AJAX
  `/OphCiExamination/Default/ElementForm*` — await that response, then assert the
  `{name}-element-section` appears. Create form id `clinical-create`.

`resolve(page, group, key)` deep-merges `default` + `versions[<active version>]` and
dispatches by kind (`testId`→`getByTestId`, `id`→`#id`, `name`→`[name="..."]`, `css`).
The active version comes from the **version gate** (below) so the right overrides load
automatically; `APP_VERSION` env pins/overrides it when needed.

### 2. Version gate (`src/core/version.ts`) — fail fast on unsupported OE
The harness must refuse to run blind against a version it has no selectors for. The
version's source of truth is `params['oe_version']`, defined in
`protected/config/core/common.php` (`getenv('OE_VERSION') ?: 'UNRELEASED'`, seeded from
`protected/version.txt`). OpenEyes exposes **no** version HTTP header, meta tag, or
unauthenticated endpoint — but that same `oe_version` is printed into the About-panel
markup that ships on every page (incl. `/site/login`, pre-auth):

- Hidden container `#js-openeyes-info` holds `<p>Version: {oe_version}</p>` (from
  `protected/views/base/_brand.php`). It's `display:none` until the logo
  (`#js-openeyes-btn`) is clicked, but Playwright `locator.textContent()` reads it
  regardless of visibility — so we extract it **without** clicking.
- Format = the `oe_version` value: e.g. `3.0` or `26.0.0`; debug builds add a
  ` (branch - dev)` suffix; when unset it's the literal `UNRELEASED`.

`detectVersion(page)`: load `/site/login`, read `#js-openeyes-info` textContent, regex
`/Version:\s*([^\s<]+)/`; **fallbacks** (a) click `#js-openeyes-btn` then re-read, (b)
post-auth GET `/site/debuginfo` (`OpenEyes Version: …`). Normalise (strip the
` (… - dev)` suffix; keep `isDev` / `isUnreleased` flags).

`assertSupported(version)` checks it against `selectors/supported.ts` (the allow-list of
versions the map covers):
- **supported** → continue; record the resolved version in every StepLog/Report
  `environment` block.
- **unsupported released version** → **abort immediately** (`OE 27.x not supported
  (known: 26.x); update selectors/supported.ts`) with **exit code 3**, before any
  scenario runs.
- **dev / UNRELEASED** → can't be matched; **abort** under the default
  `OE_VERSION_ENFORCE=true`, or warn-and-continue when set `false` (for dev boxes).

The gate runs once, up front, in the shared fixture / CLI bootstrap — every tool
inherits it, so an unsupported target fails in seconds, not mid-run.

### 3. UI login primitive (`src/core/auth.ts`)
OE login is multi-step: fill username/password → click institution (sets
`institution-id-input`) → click site (sets `site-id-input`) → submit → handle
post-login firm context. Single robust fixture; the #1 flakiness source.

### 4. Settle/perf/error collectors (`settle.ts`, `perf.ts`, `errors.ts`)
- `settle`: own implementation of "DOM stopped changing" (MutationObserver quiet
  period) + double-rAF paint wait. Used by slow mode and to de-flake every action.
- `perf`: `performance.getEntriesByType('navigation')` (TTFB, DOMContentLoaded,
  load), `first-contentful-paint`, time-to-networkidle, and settle time. Report
  median + p95 over N iterations.
- `errors`: `page.on('console'|'pageerror'|'response'|'requestfailed')` + scan
  `page.content()` for PHP/Yii signatures (`Fatal error`, `CException`, `CDbException`,
  Yii exception page markers — tunable list).

### 5. StepLog + Report schema (`src/core/steplog.ts`) — the agent/doc foundation
Designed *first* so CLI exit codes, auto-docs, and video narration all hang off it.

```jsonc
// StepLog (per scenario run)
{ "schemaVersion":"1.0", "tool":"examination-elements", "title":"...", "status":"passed|failed|partial",
  "environment":{ "baseURL":"...", "oeVersion":"26.0.0", "browser":"chromium", "viewport":"1280x737" },
  "context":{ ... },                         // ids/inputs the run depended on
  "steps":[ { "index":1, "name":"...", "narration":"plain-English sentence (also drives video overlay)",
              "action":"navigate|click|fill|assert|waitResponse", "target":{"kind":"testId","value":"..."},
              "expected":"...", "status":"passed", "durationMs":842,
              "network":[{"url":"...","method":"GET","status":200,"ms":230}],
              "observations":{"console":[],"httpErrors":[],"phpSignatures":[]},
              "artifacts":[{"type":"screenshot","path":"artifacts/screenshots/.../step-01.png"}] } ],
  "metrics":{ ... } }
```

`Report` is a shared envelope for sweep/runbook/load: `{ ok, summary, results[], artifacts[] }`.

---

## Run modes (cross-cutting, no test duplication)

`RUN_MODE` env → Playwright projects + a `runMode` fixture + reporter selection.
One scenario body serves all three:

- **errors**: attach `ErrorCollector`; functional asserts run; error reporter →
  `artifacts/reports/errors.json`. Timing ignored.
- **slow**: wrap each navigation/action with `perf` + `settle`; console/HTTP errors
  downgraded to warnings; slow reporter ranks slowest pages → `artifacts/reports/slow.json`.
- **load**: `capabilities/load` loops the scenario across N `browser.newContext()` in
  the sidecar browser, capped; per-iteration timing → `artifacts/reports/load.json`.

No `if(mode)` in spec files — all branching lives in the fixture/config/reporters.

---

## Capabilities (thin layers; all four in scope, examples first)

### A. Error + slow-page sweep (`capabilities/sweep`)
Walks `config/pages.popular.json`. A flow is `static` (URL) or `dynamic` (needs a
precondition built via a UI `flow`, e.g. `findOrCreatePatient` then open summary, or
create an examination). Same list feeds errors mode, slow mode, and load. Output:
`Report` JSON, slowest-first / errors grouped.

### B. CSV admin runbook + sample-data gen (`capabilities/runbook`)
Generic engine: stream a CSV (`papaparse`) + a YAML mapping config, fill/submit one
admin form per row, capture per-row validation errors, idempotent (UI search probe),
**resumable** (checkpoint `artifacts/state/<run>.state.jsonl`). This *is* the UI-only bulk
data path (1000 users, patients, etc.) — note it is slow and resumable by design.

```yaml
# config/runbooks/users.runbook.yaml (shape)
name: admin-users
login: true
idempotency: { probe_url: "/admin/users?search={email}", exists_selector: "tr:has-text('{email}')" }
ui:
  page_url: "/admin/addUser"
  ready_selector: "#et_save"
  fields:
    - { col: first_name, selector: "#User_first_name", type: text }
    - { col: last_name,  selector: "#User_last_name",  type: text }
    - { col: email,      selector: "#User_email",      type: text }
    - { col: roles,      group: adminUser, key: roles, type: oe-multiselect, transform: splitPipe }
    - { col: username,   selector: "[name='UserAuthentication[0][username]']", type: text }
    - { col: password,   selector: "[name='UserAuthentication[0][password]']", type: text }
    - { col: password,   selector: "[name='UserAuthentication[0][password_repeat]']", type: text }
  submit: { selector: "#et_save", wait: { kind: domQuiet } }
  success: { selector: ".alert-box.success, [data-test='flash-success']", visible: true }
  error_capture: { selector: ".errorMessage, #_form_errors" }
```

Field types include `oe-multiselect` (handles the custom `-- Add --` role widget) and
plain `text`/`select`/`checkbox`. A "create a user with permission X then verify they
*cannot* reach feature Y" test = a runbook row + a follow-on assertion spec — easy for
Claude to copy and tweak.

### C. Claude tools + auto-docs (`tools/`, `capabilities/docgen`)
Every tool: `oeh <tool> --json '{...}'`, single JSON object on stdout, logs on stderr,
**stable exit codes**: `0` ok · `1` capability found problems (app bug/threshold) ·
`2` bad args · `3` infra/login failure. Worked example tool **`examination-elements`**:
login → `findOrCreatePatient` (UI) → open patient → create OphCiExamination event →
open element manager → for each `manage-elements-{kebab}`: click, await `ElementForm`
AJAX, assert `{name}-element-section` visible, screenshot, record timing + errors →
emit StepLog. `capabilities/docgen` maps StepLog → markdown (title→H1, each step→H3 +
narration + screenshot + status), so Claude either emits docs directly or reads the
StepLog and writes richer prose.

### D. Training video recording (`tools/record-demo`)
Playwright `video`/`trace` on, `slowMo`, a fixed narration banner injected via
`addInitScript` (text from the StepLog `narration` field), and a `highlight(locator)`
helper that outlines the target before each action. Clean runs use UI-built data.
Output `artifacts/videos/{tool}/{run}/`. (Video files are written by the sidecar browser
server → the single shared `artifacts` volume; see Risks.)

---

## Documentation (first-class deliverable)

Two distinct streams, both required:

1. **Hand-written, shipped with the repo** — how to *use* it and how it was *built*:
   - `README.md` — quickstart (bring up the two containers, set `.env`, run a tool), the
     full env-var table, every `oeh` sub-command with example JSON in/out, the run modes,
     the stable exit codes, and the artifact layout.
   - `docs/ARCHITECTURE.md` — how the harness is constructed and *why*: the core spine
     (connect → version gate → auth → collectors → StepLog), the run-mode mechanism, the
     version-keyed selector map, the CDP-sidecar topology and single-volume artifact
     design, and the key trade-offs (UI-only bulk is slow; `workers:1` load ceiling).
   - `docs/SELECTORS.md` — the selector-map + version-gating strategy and the exact steps
     to add support for a new OE release.
   - `docs/WRITING-TOOLS.md` — the recipe Claude follows to add a flow / tool / runbook
     (copy an example, wire selectors, emit a StepLog).
2. **Auto-generated from runs** (`capabilities/docgen`) — every StepLog → readable
   markdown under `artifacts/docs/`, so a run *documents itself* (and Claude can enrich
   it). This satisfies "Claude creates documentation from what the tests do."

Docs are written/updated alongside the code in Phase 1 — not deferred.

---

## Phasing

**Phase 1 — Structure + examples (the deliverable to start):**
1. Repo scaffold, `package.json`, `tsconfig`, `playwright.config.ts` (mode projects),
   Dockerfiles, `docker-compose.harness.yml`, `.env.example`, `bin/oeh`, and the
   `README.md` + `docs/` skeleton.
2. Core spine: `browser/connect`, `selectors` (default + `v26.x` + `supported`),
   `core/version` (the fail-fast gate), `core/auth`, `settle`, `errors`, `perf`,
   `steplog`, `runModes`.
3. Three worked examples proving the spine end-to-end:
   - `tests/smoke/login.spec.ts` (auth primitive).
   - `tools/sweep` over a 5–6 page `pages.popular.json` in **errors** and **slow** modes.
   - `tools/examination-elements` → StepLog → `docgen` markdown.
4. One `users.runbook.yaml` + `tools/run-runbook` creating a few users from a sample CSV.

**Phase 2+ — Extend:** more runbooks (patients, settings), richer popular-flow list,
load mode hardening, video polish, more Claude tools, new entries in
`selectors/supported.ts` + `versions/` as releases land, and a `selftest` that validates
the selector map (and the detected version) against the live instance before big runs.

---

## Verification

1. `docker compose -f docker-compose.harness.yml --profile harness up -d oe-chromium`
   then `... run --rm oe-harness oeh smoke` → the version gate detects and logs the OE
   version; login succeeds against `$BASE_URL` with env creds; trace/screenshot land in
   `./artifacts`.
2. **Version gate:** against a supported instance, `oeh smoke` prints the detected version
   and proceeds; set `APP_VERSION` to an unsupported value (or point at an unknown build)
   → it aborts in seconds with a clear message and **exit code 3**, before any scenario runs.
3. `RUN_MODE=errors oeh sweep --config config/pages.popular.json` →
   `artifacts/reports/errors.json` lists zero/known errors; flip `RUN_MODE=slow` →
   `artifacts/reports/slow.json` ranks pages by settle time. Same spec body, different reports.
4. `oeh examination-elements --json '{}'` → exit 0, StepLog written (with `oeVersion` in
   `environment`); run `oeh docgen <steplog>` → readable markdown under `artifacts/docs/`
   with per-element screenshots.
5. `oeh run-runbook --config config/runbooks/users.runbook.yaml --csv sample.csv --limit 3`
   → 3 users visible at `/admin/users`; re-run → all 3 **skipped** (idempotency); kill
   mid-run and re-run → **resumes** from the `artifacts/state/` checkpoint.
6. `RUN_MODE=load oeh sweep --vus 3` → `artifacts/reports/load.json` with per-iteration
   timings; confirm low memory on `oe-harness` (browser load sits in `oe-chromium`).
7. **Docs:** `README.md` quickstart reproduces step 1 verbatim; `docs/ARCHITECTURE.md`
   matches the shipped spine.

---

## Risks / notes

- **`workers:1` / DB deadlocks.** OE's own suite runs single-worker because parallel
  browsers deadlock the DB. Load mode must cap concurrency and lean on read/GET-heavy
  journeys; write-heavy concurrency will deadlock. Document the ceiling; don't promise
  high VUs.
- **UI-only bulk is slow.** 1000 users via forms is minutes→hours; mitigated by
  streaming + resumable checkpoints, not by speed. This is the accepted trade for full
  independence.
- **CDP video artifacts.** With `chromium.connect()` to the sidecar, video/trace are
  written server-side — the single shared `artifacts` volume (same mount path in both
  containers) makes them reachable. Verify path mapping early (Phase 1 smoke).
- **Version parity.** Pin the *same* Playwright version in both Dockerfiles so
  `chromium.connect()` negotiates cleanly. `connectOverCDP` to a raw chromium is the
  fallback if we drop the Playwright-server sidecar.
- **Selector drift is inevitable** at this cadence — the central map is the mitigation;
  a `selftest` (Phase 2) should fail fast when a hook disappears.
- **Version detection is best-effort, UI-sourced.** OE exposes no version header/endpoint;
  the gate parses the About-panel markup, which reads `UNRELEASED` or a `… - dev` suffix on
  non-release builds. Policy: enforce on released versions, env-toggle for dev. If the
  markup hook (`#js-openeyes-info`) ever moves, it lives in the selector map like any other.
- **Clinical safety.** Never run write-heavy/load tools against a live clinical DB —
  sample/throwaway instances only; tag generated data for cleanup.
- **Secrets.** Creds, session-cookie name, any tokens come from env only, never the repo.

## Open items (non-blocking)

- **Stack/tooling: TBD** — user will specify (language/runner choices may revise the
  TypeScript+Playwright assumptions above).
- **Target environment: TBD** — user will supply the docker network name, `BASE_URL`,
  session-cookie name, and creds (via `.env`); nothing is pinned to a deployment.
- Directory/CLI name (`oe-harness` / `oeh`) — rename to taste.
- Licence for the new repo (AGPL-3.0 to match OE, or MIT since it's a separate tool).
- Whether to also add a few `data-test` hooks upstream on target pages that lack them.
- Initial contents of `selectors/supported.ts` — confirm the exact OE version(s) the first
  build must support (the running target's version will seed it).

---

## Learnings from the existing suite (`/home/toukan/OpenEyes/playwright/`)

Studied the existing suite to extract conventions. **Core distinction:** that suite
verifies **page/data correctness** — it seeds state fast via the backend TestHelper API
(`/TestHelper/Default/createPatient`, `runSeeder`, `createEvent`, `getEventCreationUrl`),
loads **one** page, and asserts element-level values/classes (e.g.
`patient-header.spec.ts`, `botox-management-admin.spec.ts` — login, `runSeeder(...)`,
go straight to the admin page, assert rows). Our repo instead exercises **multi-step
end-user journeys** (login → search → create patient → create exam → …) built entirely
through the **UI**, watching for errors, slow pages, and producing demos/runbooks.

### Borrow (copy/adapt — these are proven and version-agnostic)

- **Config defaults** (`playwright/playwright.common.ts`): `workers:1` + `fullyParallel:false`
  (the DB-deadlock guard — keep it; it bounds our load mode), long `timeout: 360s`,
  `expect.timeout 5000`, `actionTimeout 10000`, `navigationTimeout 15000`,
  `testIdAttribute:'data-test'`, `trace/screenshot/video: 'on'`, `locale en-GB`,
  `timezoneId Europe/London`. CI `retries:3`.
- **tsconfig**: path-alias pattern (`@plw-support/*` → ours e.g. `@harness/*`) and
  `verbatimModuleSyntax: true`, `target es2022`.
- **Selector helper** `getByTestAttr(base, testId[, css, strategy])` (`helpers/selectors.ts`)
  — supports nested chains and a `Page | Locator` base. This is the mechanism our central
  selector map should dispatch through. `getById` for `#id`.
- **POM conventions**: class takes `Page` (or `Page | Locator` for nested components);
  `readonly` Locators built in the constructor; **action-named** async methods;
  **no assertions inside POMs** (return `Promise<T>`, assert in the test); compose child
  POMs in the constructor; a base `Element` class with `static DEFAULT_TEST_SELECTORS`
  and optional `testIdOverrides`.
- **Form components** (`pom/components/form/InputText.ts` etc.): wrapper + `fill()` /
  `type()` (pressSequentially) / `setValue()` (evaluate + dispatch `input`) variants —
  directly reusable for the CSV runbook field-fillers.
- **Settle/timing helpers** (`helpers/utils.ts`): `domHasStoppedChanging` (MutationObserver
  quiet period), `waitForNextPaint` (double rAF), `expectElementCount` (poll), plus
  `toKebabCase` / `toElementSectionTestId` (encode OE's `manage-elements-{kebab}` and
  `{name}-element-section` naming) and `getElementInfo`. Reimplement these in-repo
  (we're standalone) — they're the backbone of slow-mode timing and the examination tool.
- **Element-add network sync** (`pom/components/ElementManager.ts`): the
  `Promise.all([waitForResponse(/OphCiExamination/Default/ElementForm/ GET), click])`
  + assert `{name}-element-section` visible + idempotent "skip if `.added`" pattern is
  exactly the `examination-elements` tool's inner loop.
- **DateTimeHelper** (PHP-style format tokens) and the `fixture.extend().extend()`
  composition pattern (`fixtures/system/all.ts`) — our `runMode`/`auth`/observer fixtures
  layer the same way.

### Diverge (deliberately do differently)

- **Login via UI, not API.** The existing `auth.ts` calls `/TestHelper/Default/login`
  then syncs cookies into the browser context. We drive the real `LoginPage`
  (institution → site → firm → submit) so login bugs surface and the journey is genuine.
- **No TestHelper/seeder fixtures.** Drop `createPatient`/`runSeeder`/`createEvent`/
  `getEventCreationUrl`/`addElementsToDraftExamination`. Build preconditions as reusable
  **UI flows** (`flows/findOrCreatePatient`, `createExaminationEvent`) that double as the
  bulk data-gen path. (Keep the `sendFormRequest`/`toUrlEncoded` transport only if we
  ever need a non-UI shortcut — not in the UI-only baseline.)
- **Journeys span many pages**, not one page in isolation — the unit of work is a flow.
- **Add what the existing suite lacks**: run-modes (errors/slow/load), an `ErrorCollector`
  (console/pageerror/4xx-5xx + PHP/Yii signature scan), a `PerfCollector`, the
  StepLog/Report schema, the version gate, CSV runbook engine, and doc/video generation.
- **Annotations carry perf/error metadata** (`testInfo.annotations` of type `perf`/`error`)
  rather than the existing `type:'seed'` seeding notes.

### Reference files (read-only, for patterns)
`playwright/playwright.common.ts`; `support/helpers/{selectors,utils,dateTime}.ts`;
`support/pom/pages/LoginPage.ts`; `support/pom/components/{ElementManager,Element}.ts`;
`support/pom/components/form/InputText.ts`; `support/pom/patient/PatientHeader.ts`;
`support/fixtures/system/{all,auth,utils}.ts`; evidence specs
`tests/e2e/patient/patient-header.spec.ts`, `tests/e2e/admin/botox-management-admin.spec.ts`.
