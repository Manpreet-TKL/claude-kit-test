# TKLS ticket flow and work-type decisions (2026-08, decisions in flight)

How tickets move between clients, support, devops and development on
openeyes.atlassian.net, and the 2026-08-11 decisions on splitting work types.
Boards: jira-devops-dashboard.md (11651) and jira-support-dashboard.md
(11653). The change plan lives at ~/tkls-jira-estate-plan.md.

## The flow (Manpreet, 2026-08-11)

- Clients raise Support tickets via the JSM portal; the support team triages.
- A ticket routes to devops when support cannot reproduce it on a stable copy
  of OpenEyes (so it is not provably a code issue), when it looks like
  config/infrastructure (e.g. performance), or when it is a routine service
  request (upgrade, data extract).
- A provable code issue gets the TKLS ticket CLONED and LINKED to a new OE
  ticket; the OE ticket carries GitHub-for-Jira dev info (branch/PR started,
  merged). The TKLS ticket then waits in In Development / CR / Available Next
  Release.
- Systems tickets are internal and devops-raised; clients cannot raise them.
  Unassigned Systems fall to devops; unassigned Support stays with support
  (triage is their responsibility).
- With Customer = waiting on the client; auto-closure applies, so nothing
  chases them.
- Issue types seen in the wild: Support, Systems, Sub-task, "Ask a question".
- The client on a Support ticket is the JSM Organizations field
  (`customfield_13200`).
- Label conventions observed on 11653: escalation ESCL-1/2/3; process markers
  create_dev_ticket, raiseDEV, stablereproduce, mirth_logs, upgrade-request,
  internal, oe-deploy. The devops HP/EM/ateam highlight labels are recorded in
  jira-devops-dashboard.md.
- Custom fields carrying process state: "customer update due date" (date -
  when the client is next owed an update) and "clinical safety and security
  assessment" (checkboxes: assessed by CSO / potential patient harm /
  potential cyber security incident).

## Decisions (Manpreet, 2026-08-11)

1. Incidents vs service requests: split by JSM request types ONLY - no new
   issue type, no SR label. (Corrected by probing 2026-08-11: Systems tickets
   DO carry request type 19 "Systems", so the incident side of a split
   catches them via `"Request Type" NOT IN (<SR types>)`, not via EMPTY -
   empty exists only on old pre-portal Support tickets.)
2. Dev-wait visibility wanted as dashboard widgets: (a) all TKLS tickets with
   a dev ticket attached, grouped by client; (b) TKLS tickets still open but
   the linked OE ticket's code is merged. JQL cannot read a linked issue's
   state, so (b) needs an automation rule on OE (PR merged -> update the
   linked TKLS ticket); the exact link type is still to be probed.
3. Internal business work (office VPN, Google Workspace admin, company AWS
   costings) must leave openeyes.atlassian.net: new company-managed business
   project "ToukanLabs Internal" (TLI) on toukanlabs.atlassian.net. Scope
   rule: would a client, or the OpenEyes product / its deployments, notice or
   care? Yes -> openeyes instance (TKLS/OE/CR); no -> TLI. The Systems issue
   type then narrows to product/deployment infrastructure only.
4. Existing internal Systems tickets: cut-over - re-raise the open ones in
   TLI by hand and close the TKLS copy with a URL comment. No CSV migration
   (it loses attachments, change history and comment authorship).
   `project = TKLS AND issuetype = Systems AND labels = internal` is a
   candidate query for finding them.
5. Second-instance limits accepted: no cross-instance JQL, dashboards or
   issue links (pasted URLs only); separate user management and licensing;
   any automation against TLI would need a second API token stored under
   ~/.claude/mcp-env/, never in the kit.

## Probed 2026-08-11 (MCP, read-only)

- Request types on service desk 3 (the TKLS portal) are channel-shaped, not
  work-shaped: 21 "Service Desk" (the portal form; gained a clinical safety
  section 06/05/2026 that escalates to the Apperta clinical safety group),
  22 "Emailed request", 20 "Support" (legacy Trello/Freshdesk logging),
  96 "Ask a question", 19 "Systems" ("for PMs to assign tasks to SYS-admins
  or DBAs"). The incident/SR split therefore means ADDING SR-shaped request
  types, not reorganising existing ones.
- A request type is bound to one issue type (21/22/20 -> Support, 96 -> Ask a
  question, 19 -> Systems): an SR type for Systems-shaped work (e.g. planned
  maintenance) would have to be created against the Systems issue type.
- Clone link confirmed: link type "Cloners"; the TKLS side reads "is cloned
  by", the OE side "clones". `issueLinkType = "is cloned by"` is valid JQL
  and returns the expected dev-attached tickets; JQL cannot restrict which
  project the linked issue is in (a TKLS-cloned-by-TKLS pair also matches).
- Waiting statuses confirmed on TKLS: In Development, CR, Available Next
  Release (all statusCategory In Progress).
- GitHub-for-Jira dev info IS populated on OE (branches + PRs with statuses).
  `development[pullrequests].all > 0` works through the API but
  `development[pullrequests].merged > 0` is rejected (tested twice) -
  merged-detection needs the OE automation rule, not JQL.
