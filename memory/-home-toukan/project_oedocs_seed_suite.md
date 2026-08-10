---
name: project_oedocs_seed_suite
description: "OeDocumentation demo-data seed suite at ~/oe-frontend-tests/tests/seed: 30 specs green + idempotent (2026-08-10), installs 29-token manifest only on all-green; gotchas - SSO OIDC all-required/readonly mapping keys, Yii lowercase redirects, BUG-531 dropdown workaround, debug-bar suppressed at network layer."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7f4b956c-11d9-43af-b3d6-bed06c12a1d5
  modified: 2026-08-10T12:18:53.477Z
---

The OeDocumentation demo-data seed suite lives at `~/oe-frontend-tests/tests/seed/`
(admin.spec.mjs + worklist.spec.mjs + helpers.mjs, driven by `seed.sh` - dockerised
Playwright v1.55.0-noble on the snail_backend network, BASE_URL http://web, recipes CSV from
`~/Temp10/oedocumentation-test/data/demo` mounted RO). As of 2026-08-10: **30/30 specs green
and proven idempotent** (second run probes, skips every write, still passes, ~1.4m); the
29-token manifest installs to the container's `runtime/oedocs_demo_manifest.json` only when
every spec passes (`set -euo pipefail`). Token contract: lower_snake_case ending `_id`, and a
page's `demo_data:` front matter must name a token declared as `- **Token:**` in
`docs/help/demo-data-recipes.md` or `yiic oedocs lint --strict=1` fails.

Gotchas baked into the suite (re-learn nothing):

- **SSO config** (`/admin/editssoconfig`): ALL OIDC attributes are required non-blank
  (provider_url, client_id, client_secret, redirect_url, response_type, implicit_flow,
  scopes, auth_params, encryption_key); the four field-mapping KEY inputs are readonly
  (username/email/first_name/last_name) - fill only the VALUE inputs. Save redirects to
  `/admin/ssoconfig` (a real list page).
- **Yii lowercases controller segments in redirects**: `$this->redirect(['list'])` from
  HistoryMacroController lands on `/OphCiExamination/admin/historyMacro/list` - post-save
  waitForURL patterns must be case-insensitive.
- **Systemic diagnoses set form**: the autocomplete pick is broken (BUG-531,
  `input.siblings('.savedDiagnosis')` vs the template's nested div) - seed via the
  `select.commonly-used-diagnosis` dropdown (populated async from
  `/disorder/getcommonlyuseddiagnoses/type/systemic`), which works.
- **Wait times screen** ships a disabled mustache template row - selectors need
  `:not([disabled])`.
- **Debug toolbar is suppressed at the network layer** for both pipelines: capture.cjs blocks
  `*/debug/*` via CDP Network.setBlockedURLs, and the seed specs route-abort
  `**/debug/*/toolbar*` in beforeEach - so it can never photobomb a screenshot again.
- **Teams**: Team.beforeSave forces memberless teams inactive; a non-Super-Team-Manager only
  sees teams they Own/Manage; the Add Team form is broken for users without the team-role
  permission (BUG-530).
- Worklist seeding must respect the one-unbooked-list-per-day rule - see
  [[reference_oe_unbooked_worklist_first_event_claims]].

Bugs found while seeding go to `/home/toukan/openeyes_unverified_bugs.md` (BUG-530, BUG-531
this run) + `known_issues:` stamps on the affected pages. Backlog state lives in
[[project_oe_docs_screenshot_backlog_not_fanoutable]].
