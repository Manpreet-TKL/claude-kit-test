# Plan: TKLS Jira estate - record it, extend visibility, split work types

Status: proposed 2026-08-11, nothing executed. All Jira/TLI changes are applied by
Manpreet in the UI; Claude supplies paste-ready JQL and click-path steps, records the
outcomes in the kit, and never curls Atlassian or commits.

## Context

Dashboard 11651 (DevOps Current) was dumped, analysed and improved this session; the
agreed changes (statusCategory base, filter-on-filter derivatives, 22220 window, OE
gadget) are recorded in `~/claude-kit/knowledge/jira-devops-dashboard.md`. This plan
widens that work: record the whole current setup in the kit, design visibility for
tickets waiting on development, improve the support dashboard (11653), separate
incidents from service requests, and move non-product internal work off
openeyes.atlassian.net to a new project on toukanlabs.atlassian.net.

Kit sweep findings: nothing is recorded anywhere for 11653, request types, the support
process, or incident handling - all new ground. Knowledge-file conventions are
inventoried (dated H1, orientation paragraph, inline fact dating, design-decisions
section, tables). One stray: `~/claude-kit/docs/atlassian.md:101` has a stale example
`JIRA_URL` pointing at toukanlabs.atlassian.net (TKLS actually lives on openeyes) -
worth a one-line fix when the kit is next touched.

## Decisions taken (Manpreet, 2026-08-11)

1. Dev-wait view: TKLS tickets needing development are CLONED and LINKED to an OE
   ticket. Wanted widgets: (a) all TKLS tickets with a dev ticket attached, grouped by
   client; (b) TKLS tickets still open but the linked OE ticket's code is merged (OE
   uses GitHub-for-Jira dev info). Several widgets acceptable.
2. Incident vs service request split: request types only (reorganise JSM request types,
   query the "Request Type" field). Accepted limitation: Systems tickets carry no
   request type by default.
3. Existing internal Systems tickets: cut-over - re-raise open ones in the new internal
   project by hand, close TKLS copies with a link comment. No CSV migration.

## Phase 0 - Discovery (user-assisted, read-only)

1. Claude touches `~/claude-kit/generated/mcp-on/atlassian`; Manpreet reconnects
   atlassian in /mcp.
2. Manpreet runs (via `!`): `bash ~/claude-kit/scripts/jira_dashboard_dump.sh -d 11653`
3. MCP probes (read-only, paginated counts - `total` is -1 on Cloud):
   - Request Type values in use on TKLS (`"Request Type" is not EMPTY` samples); do
     Systems tickets ever carry one.
   - Link type used between TKLS and its OE clone (sample In Development tickets,
     inspect issuelinks: "clones"/"is cloned by"/"relates to").
   - How the client is recorded on TKLS tickets (JSM Organizations field vs custom
     field vs reporter) - determines what "grouped by client" can use.
   - Status usage: counts for In Development / CR / Available Next Release; overlap
     with has-OE-link.
   - OE side: is `development[pullrequests].merged > 0` populated (GitHub for Jira).
   - Support-team group name (expected in 11653's filters).

## Phase 1 - Support dashboard 11653 suggestions

Same method as 11651. From the dump + probes, deliver a numbered suggestion list with
paste-ready JQL: a Support-Open base filter with `filter = N` derivatives,
`statusCategory != Done` robustness, filter sharing vs dashboard visibility, refresh,
row caps/columns, unassigned-Support triage queue visibility (triage is support's
responsibility), and a With Customer chase view (support owns client chasing;
suggest, Manpreet decides). Manpreet applies chosen changes in the Jira UI.

## Phase 2 - Dev-wait widgets

Design from discovery results; deliver as numbered suggestions with JQL and admin
steps. Expected shape (link type placeholder until probed):

- W1 "TKLS with dev ticket attached, by client": filter
  `project = "ToukanLabs Services" AND statusCategory != Done AND issueLinkType = "<clone link type>"`,
  grouped by the client field found in discovery (2D stats gadget if it supports that
  field; else one-dimensional stats / per-client filters).
- W2 "Open TKLS, code merged": JQL cannot read a linked issue's state, so recommend an
  automation rule on OE (trigger: PR merged, or OE status -> merged-ish) that updates
  the linked TKLS ticket (transition to Available Next Release or add a `merged`
  label); widget then filters on that. Interim OE-side widget:
  `project = OE AND statusCategory != Done AND development[pullrequests].merged > 0`
  as a list, if dev info is populated.
- W3 waiting-status counts: `filter = 19720 AND status IN ("In Development", CR, "Available Next Release")`
  plus the support-side equivalent, as stats gadgets.
- Placement suggestion: new row on 11653 or a small "Development Wait" dashboard.

## Phase 3 - Incident vs service split (request types)

- Propose a request-type taxonomy from the discovered inventory: incident-shaped
  ("Report a problem") vs service-shaped (upgrade, data extract, access/config...).
- Derivative filters (name-based - note renames silently break them):
  `DevOps-Open-Incidents: filter = 19720 AND ("Request Type" in (<incident types>) OR "Request Type" is EMPTY)`
  `DevOps-Open-Service-Requests: filter = 19720 AND "Request Type" in (<service types>)`
  Empty request type (all Systems tickets) defaults to the incident side; agents can
  set a request type manually on the issue view where wanted.
- Gadget split suggestions for 11651 (and the 11653 equivalent). Manpreet applies.

## Phase 4 - Internal project on toukanlabs.atlassian.net

Deliver as a numbered proposal (separate instance - nothing executable from here):

- Company-managed business (work-management) project "ToukanLabs Internal", key TLI;
  Free tier covers it if the instance stays <= 10 users. JSM is overkill internally.
- Scope rule: "Would a client, or the OpenEyes product/its deployments, notice or
  care? Yes -> openeyes.atlassian.net (TKLS/OE/CR). No -> TLI." Examples: client-site
  VPN = TKLS Systems; office VPN / Google Workspace / company AWS costings = TLI.
- Components with default assignees for routing: IT & Access, SaaS Admin, Cloud &
  Costs, Procurement & Licensing, Other. Anyone raises; company-IT hat triages.
- Systems issue type narrows to product/deployment infrastructure only: update its
  description text; future misfiled internal tickets get closed with a "raise in
  TLI: <url>" comment (no cross-instance links - pasted smart-link URLs only).
- Cut-over: identify open internal Systems tickets (the old parked tail TKLS-19, 334,
  1471, 1622, 2087, 3095 are candidates to review), re-raise in TLI, close TKLS copy
  with the URL comment.
- Hard limits stated up front: no cross-instance JQL or dashboards (11651 can never
  show TLI - that is the point); separate user management/licensing; any future
  automation/tooling needs a second API token stored under `~/.claude/mcp-env/`,
  never in the kit.

## Phase 5 - Record knowledge in the kit

Follow the inventoried knowledge-file conventions (dated H1, orientation paragraph,
inline fact dating, design-decisions "do not re-suggest" section, tables, ASCII).

- NEW `~/claude-kit/knowledge/jira-tkls-process.md`: ticket flow (client -> support
  triage -> devops routing criteria: not reproducible on stable copy, config/infra,
  routine service request; provable code issue -> clone+link to OE), Systems vs
  Support semantics, waiting statuses, request-type split, TLI scope rule and
  cut-over, second-instance limits.
- NEW `~/claude-kit/knowledge/jira-support-dashboard.md`: 11653 layout, filters,
  suggestion outcomes (mirror of the 11651 file).
- UPDATE `~/claude-kit/knowledge/jira-devops-dashboard.md`: cross-reference siblings;
  extend the agreed-changes note (request-type filters, dev-wait widgets).
- No client names in the kit (public remote): "grouped by client" mechanics are
  described, client org values are not enumerated.
- Offer (approval-gated, per kit rule): one-line notes in `skills/jiramcp/SKILL.md`
  (TLI is on a second instance the MCP cannot reach) and `skills/devopstickets/`
  (request-type awareness), plus the `docs/atlassian.md:101` stale-example fix.

## Verification

- After Manpreet applies Jira changes: re-run the dump for 11653 (and 11651 if
  touched) via `!`; diff against the suggested config.
- MCP paginated count probes on every new filter JQL - sanity-check counts against
  each other (e.g. dev-attached >= In Development count, incidents + SRs = open).
- Knowledge files: conventions check, `git -C ~/claude-kit status` shows only the
  intended files; Manpreet commits (never Claude).

## Constraints

- Claude never curls Atlassian or reads the credential env; dumps are human-run
  via `!`.
- All Jira/TLI config changes are human-in-UI (MCP has no dashboard/filter/request-
  type write endpoints); Claude supplies paste-ready JQL and click-path steps.
- No commits, no pushes, no secrets or client identifiers in the kit.
