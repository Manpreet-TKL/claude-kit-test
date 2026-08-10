# DevOps dashboard 11651 + filter 19720 (2026-08, TKLS)

The DevOps team dashboard in Jira and the saved filter behind it. Intent: show
every open ticket - Support or Systems - that sits with the devops group.

- Dashboard: https://openeyes.atlassian.net/jira/dashboards/11651
- Backing filter: 19720 "DevOps All Open" (the same filter the `devopstickets`
  skill uses as its default scope)

## Filter 19720 - verified semantics

Probed 2026-08-08 with set-difference JQL in both directions; the filter is
exactly equivalent to:

```
project = TKLS AND statusCategory != Done AND (issuetype in (Systems, Support) AND assignee in membersOf("devops") OR issuetype = Systems AND assignee is EMPTY)
```

Nothing missing and nothing extra: no open devops-assigned Support/Systems
ticket falls outside it, no resolved tickets leak in, no non-devops assignees,
and unassigned Support is (deliberately) not included - only unassigned Systems.

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
the id/name/JQL of every filter those configs reference. As of 2026-08-08 the
gadget layout of 11651 had not yet been dumped - fold the results in here when
it has been run.

## JQL probing gotchas (learned doing the verification)

- `NOT (assignee in membersOf("x"))` never matches unassigned issues - empty
  fields fail both the positive and the negated clause. Probe unassigned
  slices with an explicit `assignee is EMPTY` conjunct instead.
- Cloud enhanced search returns `total: -1`; to count a filter you paginate
  (limit 50 + `next_page_token`) and add up the pages.
- `filter != 19720` / `filter = 19720` compose fine with other clauses, so
  "in scope but not in filter" and "in filter but out of scope" are each one
  query - cheap way to prove a saved filter's real semantics.
