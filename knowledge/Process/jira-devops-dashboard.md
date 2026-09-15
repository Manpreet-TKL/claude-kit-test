# DevOps dashboard 11651 + filter 19720 (2026-08, TKLS)

The DevOps team dashboard in Jira and the saved filter behind it. Intent: show
every open ticket - Support or Systems - that sits with the devops group.

- Dashboard: https://openeyes.atlassian.net/jira/dashboards/11651 -
  "DevOps Current", owner Manpreet, viewable by any logged-in user
- Main filter: 19720 "DevOps-Open" (the same filter the `devopstickets`
  skill uses as its default scope, where it is called "DevOps All Open")
- Siblings: jira-support-dashboard.md (support board 11653),
  jira-tkls-process.md (ticket flow + the 2026-08 work-type decisions)

## Filter 19720 - verified semantics

Actual JQL (dumped 2026-08-11):

```
project = "ToukanLabs Services" AND status != Done AND (issuetype in (Systems, Support) AND assignee IN (membersOf("devops")) OR (issuetype = Systems AND assignee is EMPTY)) ORDER BY created DESC
```

Probed 2026-08-08 with set-difference JQL in both directions; currently
equivalent to the `statusCategory != Done` version: nothing missing, no
resolved tickets leaking in, no non-devops assignees, and unassigned Support
is (deliberately) not included - only unassigned Systems. Latent leak though:
`status != Done` does not exclude the `Closed` status that the closed-side
filters prove exists, so a devops ticket parked in Closed would linger on the
board forever. `statusCategory != Done` is the robust form.

Snapshot 2026-08-08: 116 open tickets - 75 In Progress, 16 With Customer,
19 To Do, 5 On Hold, 1 In Development. Load almost entirely Alex Webb and
Yousuf Ellahi, plus a tail of very old Systems tickets (TKLS-19, 334, 1471,
1622, 2087, 3095) parked with Manpreet. The 75-strong In Progress pile (some
untouched since 2024) is the standing data-quality problem; "With Customer"
is the waiting-on-customer state.

## Inspecting a Jira dashboard at all

mcp-atlassian has NO dashboard endpoints - gadgets and their configs are
invisible to the MCP tools, and per the `jiramcp` skill Claude never curls
Atlassian or reads the credential env file. The human runs the dump instead
(output lands in the conversation via the `!` prefix):

`~/claude-kit/scripts/jira_dashboard_dump.sh -d 11651`

It prints dashboard metadata, the gadget list, each gadget's saved config and
the id/name/JQL of every filter those configs reference.

## Gadget layout (dumped 2026-08-11)

Left column: six two-dimensional filter statistics gadgets (statuses across,
assignees down). Right column: three filter-results lists driven by manual
labels. Only the two top-left gadgets auto-refresh (15 min).

| Pos | Gadget | Filter | Scope |
|-----|--------|--------|-------|
| L0 | DevOps Open Tickets | 19720 DevOps-Open | all open devops work |
| L1 | DevOps Not Updated In 5 Days | 22086 DevOps-Forgotten-About-Tickets | open minus With Customer/In Development/CR/Available Next Release/On Hold, `NOT updated > -5d` |
| L2 | DevOps Closed In The Last 7 Days | 22052 DevOps-Closed-Last-7-Days | `status CHANGED to (Done, Closed) BY membersOf("devops") after startOfDay(-7d)` |
| L3 | DevOps Closed By Support Last 7 Days | 22220 DevOps-Closed-By-Support-Last-7-Days | closed + `assignee WAS IN membersOf("devops") DURING (-7d, now())` + assignee now not devops; no closure-date window |
| L4 | DevOps Closed Since Month Start | 22120 DevOps-Closed-Since-Month-Start | as 22052 but `AFTER startOfMonth()` |
| L5 | DevOps Closed Since Year Start | 22589 DevOps-Closed-Since-Year-Start | as 22052 but `AFTER startOfYear()` |
| R0 | !!!!! DevOps High Priority !!!!! | 22087 DevOps-Open-High-Priority-Tickets | open + `labels IN (HP,hP,Hp,hp)`, 10 rows, key/summary/labels |
| R1 | DevOps Easy Money Right Here | 22187 DevOps-Open-Easy-Money-Tickets | open + `labels IN (EM,eM,Em,em)`, 10 rows |
| R2 | DevOps Open [ ATEAM ] | 22053 DevOps-Open-Ateam-Tickets | open + `labels IN (ateam,ATeam,ATEAM,aTeam)`, 15 rows, key/summary |

Conventions: filters are named `DevOps-<Open|Closed>-<Thing>[-Tickets]`;
priority/queue routing is by hand-applied labels (HP = high priority, EM =
easy money, ateam = A-team), each enumerated in four case variants. All
"open" filters repeat 19720's where-clause verbatim (including its
`status != Done` weakness) rather than referencing it.

## Design decisions (Manpreet, 2026-08-11)

Deliberate choices - do not re-suggest "fixing" these:

- "With Customer" is excluded from the stale radar on purpose: the board
  tracks where devops has not been proactive, not where the client is sitting
  on a reply; With Customer tickets auto-close anyway.
- Unassigned Support is excluded on purpose: triage is the support team's
  responsibility; only unassigned Systems fall to devops.
- The HP labels are belt-and-braces on top of the priority field - a manual
  extra-highlight mechanism, not a workaround to replace with `priority in`.
- No age/oldest-first views wanted.
- 22220's intent: tickets devops resolved and handed back to support, who
  close them once the client confirms - a "resolved by devops, closed by
  support" count.

Agreed changes (2026-08-11): base filter moves to `statusCategory != Done`;
the four open derivative filters become `filter = 19720 AND ...`; 22220 gains
a closure window and drops its DURING assignment window; new
`DevOps-Open-OE-Tickets` filter + gadget for OE-project devops work; refresh
to be enabled on the seven non-refreshing gadgets.

## JQL probing gotchas (learned doing the verification)

- `NOT (assignee in membersOf("x"))` never matches unassigned issues - empty
  fields fail both the positive and the negated clause. Probe unassigned
  slices with an explicit `assignee is EMPTY` conjunct instead.
- Cloud enhanced search returns `total: -1`; to count a filter you paginate
  (limit 50 + `next_page_token`) and add up the pages.
- `filter != 19720` / `filter = 19720` compose fine with other clauses, so
  "in scope but not in filter" and "in filter but out of scope" are each one
  query - cheap way to prove a saved filter's real semantics.
