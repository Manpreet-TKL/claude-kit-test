# Support dashboard 11653 (2026-08, TKLS)

The support team's Jira board, dumped and analysed 2026-08-11; the fixes
suggested below are NOT yet applied. Sibling of jira-devops-dashboard.md
(devops board 11651, plus how to dump any dashboard at all); the ticket flow
and the 2026-08 work-type decisions live in jira-tkls-process.md.

- Dashboard: https://openeyes.atlassian.net/jira/dashboards/11653 -
  "TKLS Support Summary", owner Manpreet, viewable by any logged-in user,
  five named edit users.
- The client dimension is the JSM Organizations field, `customfield_13200` -
  several gadgets already chart by it, which proves grouped-by-client widgets
  are directly buildable.

## Gadget layout (dumped 2026-08-11)

One tall left column (rows 0-16) plus a short right column. A mix of native
gadgets and a Forge report app (moduleKey ends `report-dashboard-item`) whose
charts group by Organizations.

| Pos | Gadget | Filter | Notes |
|-----|--------|--------|-------|
| L0 | Service project report | project TKLS | JSM custom report 549 "Tickets Created by customer" |
| L1 | 2D Filter Statistics | 23321 All tickets - Transition this month | issuetype x status; filter has a hardcoded date window |
| L2 | Filter Results | 21192 TKLS - A-Team Tickets - Daily | 5 rows |
| L3 | Filter counts | 23153 Clinical safety and security assessment | Total only; CSO/safety checkbox radar |
| L4 | Filter Results | 22889 In Progress - Last Updated | 5 rows |
| L5 | Escalated Ticket by Priority | project-scoped | per-row JQL on ESCL-1/2/3 labels, In Progress only |
| L6 | Filter counts | 21651 TKLS - In Progress Tickets | per-priority rows; filter also includes To Do |
| L7 | Filter counts | 20831 Customer Update Due | Total + per-priority rows; overdue-update chase |
| L8 | By Support Team member | 21191 | 2D stats; hardcoded account ids |
| L9 | By PM | 21190 | same |
| L10 | By Dev Team member | 21156 | same |
| L11 | By DevOps Team member | 21189 | same |
| L12 | Triaged (logs reproduced on Stable) | 21486 | labels chart; 40+ segments hand-hidden |
| L13 | Open by Priority | 19722 | Forge report |
| L14 | Open by Client | 19722 | Forge report, Organizations x status |
| L15 | Open by Assignee | 19722 | native stats |
| L16 | Open by Label | 19722 | Forge report |
| R0 | Created vs Resolved | project TKLS | monthly, 365 days, no refresh |
| R1 | Forgotten About (Support) | 19724 | Forge report by Organizations |
| R2 | Support Tickets (7 Days) | 19723 | Forge report by Organizations |

Unlike 11651, most gadgets here already refresh at 15 min; only Created vs
Resolved (R0) and the L1 2D stats do not.

## Filter defects found (2026-08-11; suggested rewrites, not applied)

1. 19722 TKLS-Open-Tickets-Support-Only - the board's base filter - has the
   same latent Closed leak as devops 19720 (`status != Done`) plus a redundant
   `issuetype != Sub-task` next to `issuetype = Support`. Suggested:

   ```
   project = "ToukanLabs Services" AND statusCategory != Done AND issuetype = Support ORDER BY created DESC, updated DESC
   ```

   Derivatives then become `filter = 19722 AND ...` (same base-filter
   architecture agreed for 11651).

2. 19723 Closed-Last-7-Days contradicts itself: `status = Done` but
   `status changed to (Done, Closed)` - a ticket that ends in Closed never
   counts. Suggested:

   ```
   project = "ToukanLabs Services" AND issuetype = Support AND statusCategory = Done AND status CHANGED TO (Done, Closed) AFTER -7d ORDER BY created DESC, updated DESC
   ```

3. The four team filters (21191 support, 21190 PM, 21156 dev, 21189 devops)
   hardcode assignee account ids - staff changes mean editing four filters and
   a leaver silently drops out. 21189 should be
   `assignee IN (membersOf("devops"))`; create groups for the other three
   teams once and use membersOf.

4. 21486 (Triaged) restricts to two labels by hand-hiding 40+ chart segments
   in the gadget; every new project label appears until someone removes it.
   Put the restriction in the filter instead:

   ```
   project = TKLS AND issuetype = Support AND status IN ("In Progress", "With Customer", "To Do") AND labels IN (stablereproduce, mirth_logs)
   ```

   then clear the segment list.

5. 23321 hardcodes a literal one-month date window (stale from 2026-08-13)
   and two client organizations. Use `status CHANGED AFTER startOfMonth()`
   (or a rolling `-30d`); keep the org clause only if it is deliberately a
   single-client review widget, and then say so in the name.

6. 21192 A-Team uses single-case `labels = ATeam` while the devops board
   enumerates four case variants - ateam/ATEAM/aTeam tickets are invisible.
   Rebased equivalent:

   ```
   filter = 19722 AND labels IN (ateam, ATeam, ATEAM, aTeam) AND status != "With Customer" ORDER BY priority ASC, created DESC
   ```

7. The Escalated gadget counts only `status = "In Progress"` - an
   ESCL-labelled ticket parked in To Do or With Customer leaves the escalation
   radar while still escalated. Suggested per-row JQL:
   `issuetype = Support AND statusCategory != Done AND labels = ESCL-1` (etc);
   the Total row also carries a `status in ("In Progress", "In progress")`
   case-duplicate.

8. 23153 Clinical safety and security assessment has the Closed leak in the
   worst possible place: `status != Done` on the patient-harm / cyber-incident
   radar, so a flagged ticket parked in Closed vanishes from the safety count.
   Suggested:

   ```
   project = TKLS AND "clinical safety and security assessment[checkboxes]" IN ("This issue has been assessed by our CSO", "This issue has the potential to cause patient harm", "This is a potential Cyber Security Incident") AND statusCategory != Done ORDER BY created DESC
   ```

9. 21651 is named "In Progress Tickets" but its JQL includes To Do; and its
   count gadget has neither a Total nor a Trivial row, so Trivial-priority
   tickets are invisible in it. Either align the JQL to the name or rename
   (e.g. "TKLS - Active Tickets") and add Total/Trivial rows.

## Dump gotchas (learned here)

- Filter-count gadgets (servicedesk dashboard-items plugin) store their filter
  as `{"type":"filter","id":N}` under the `projectFilterDetails` item
  property - the dump script's grep missed these until fixed and re-run
  2026-08-11; all referenced filters now dump.
- Forge report gadgets keep config in the `report` item property; the filter
  sits at `dataSource.filterId`; `segmentCustomizations` entries with
  `removed:true` hide chart segments one by one. Restrictions belong in the
  filter JQL, not the segment list, because every new field value appears by
  default.

## Late-dumped filters (2026-08-11, after the script fix)

```
20831 TKLS - Customer Update Due: project = TKLS AND "customer update due date[date]" <= -1m AND status = "In Progress" ORDER BY created DESC
21651 TKLS - In Progress Tickets: project = TKLS AND status IN ("In Progress", "To Do") AND type = Support ORDER BY created DESC
23153 Clinical safety...: project = TKLS AND "clinical safety and security assessment[checkboxes]" IN ("This issue has been assessed by our CSO", "This issue has the potential to cause patient harm", "This is a potential Cyber Security Incident") AND status != Done ORDER BY created DESC
```

20831 reveals a "customer update due date" date field (update cadence owed to
the client; `<= -1m` = due date already passed); 23153 reveals a
"clinical safety and security assessment" checkbox field set by the CSO
process - the portal's "Service Desk" request form gained that section on
06/05/2026 (escalates to the Apperta clinical safety group), and 23153 is
the dashboard's radar for it.

## Open questions

- "Ask a question" issue type appears in 23321 but 19722 excludes it from the
  whole board - deliberate?
- Forgotten-About window is 4 days here vs 5 days on the devops board -
  deliberate?
- 20831 only looks at In Progress - a To Do ticket with an overdue customer
  update is invisible; deliberate?
- 23153 counts "assessed by CSO" together with the two risk flags in one
  Total - the number cannot distinguish assessed-and-fine from
  potential-harm; deliberate?
