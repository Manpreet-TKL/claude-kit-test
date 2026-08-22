# TKLS Jira estate - pending changes (2026-08, none applied yet)

The consolidated action list from the 2026-08 dashboard/process review. All
items are human-applied in the Jira UI (Jira is read-only for agents). The
paste-ready JQL for each item lives in the knowledge/ files:
jira-devops-dashboard.md (11651), jira-support-dashboard.md (11653),
jira-tkls-process.md (flow, decisions, probe results). The original 5-phase
plan is at ~/claude-kit/todo/jira-estate-full-plan.md.

**Devops board 11651**

1. Rebase filter 19720 (DevOps-Open) from `status != Done` to `statusCategory != Done` so a ticket parked in Closed can never linger on the board.
2. Rewrite the four open derivative filters (22086 Forgotten-About, 22087 High-Priority, 22187 Easy-Money, 22053 Ateam) as `filter = 19720 AND ...` so the base scope is defined once and edits propagate.
3. Fix 22220 (Closed-By-Support): add a closure-date window and drop the DURING assignment window, so it actually counts "resolved by devops, closed by support in the last 7 days".
4. Create the new DevOps-Open-OE-Tickets filter (OE project, open, assignee in the devops group) and add its gadget to the board.
5. Enable the 15-minute refresh on the seven gadgets that currently never refresh.

**Support board 11653**

6. Rebase 19722 (the board's base filter) to `statusCategory != Done` and drop the redundant Sub-task clause; point its derivatives at `filter = 19722`.
7. Fix 19723 (Closed-Last-7-Days): it self-contradicts (`status = Done` plus `changed to (Done, Closed)`) so tickets ending in Closed never count.
8. Replace the hardcoded assignee account ids in the four team filters (21191 support, 21190 PM, 21156 dev, 21189 devops) with `membersOf(<group>)` so staff changes don't require filter edits.
9. Move 21486 (Triaged)'s restriction into the filter JQL and clear the 40+ hand-hidden chart segments, so new labels stop appearing by default.
10. Fix 23321 (Transition this month): replace the hardcoded date window (stale since 2026-08-13) with `startOfMonth()`, and either drop the two hardcoded client orgs or rename it as a single-client widget.
11. Fix 21192 (A-Team): enumerate the four label case variants like the devops board does, so ateam/ATEAM/aTeam tickets stop being invisible.
12. Fix the Escalated gadget rows: `statusCategory != Done` instead of In Progress only, and remove the case-duplicate status clause in the Total row.
13. Fix 23153 (Clinical safety) - highest priority of the lot: `statusCategory != Done`, because right now a patient-harm or cyber-incident ticket moved to Closed vanishes from the safety radar.
14. Fix 21651 (In Progress Tickets): either drop To Do from the JQL or rename the filter, and add the missing Total and Trivial rows to its gadget.

**New dev-wait visibility**

15. W1: create "TKLS - Dev Ticket Attached" (`issueLinkType = "is cloned by"`, verified working) and add a by-client Forge report gadget grouped by Organizations.
16. W2: create the OE automation rule (PR merged -> label the linked TKLS ticket `oe-merged`; needs multi-project scope, so Jira admin), plus the "TKLS - Dev Merged Awaiting Release" filter; backfill the label on the existing Available Next Release pile.
17. W3: create "TKLS - Waiting On Development" over the verified statuses (In Development, CR, Available Next Release) as a counts or 2D gadget.

**Incident / service-request split**

18. Add SR-shaped request types to portal 3 mapped to the Support issue type (suggested: Request an upgrade, Request a data extract, Request an access or config change), optionally one mapped to Systems for planned work. Keep "Service Desk" un-renamed so existing JQL keeps working.
19. Create the SR/incident filter pair on top of 19722 (and devops equivalents on 19720) using `"Request Type" IN/NOT IN` - the probing showed Systems tickets carry the "Systems" request type, so EMPTY-based logic is wrong.

**Internal work off the product instance**

20. Create the "ToukanLabs Internal" (TLI) business project on toukanlabs.atlassian.net with the agreed scope rule: would a client or the product/deployments notice - yes stays on openeyes, no goes to TLI.
21. Cut-over: re-raise the open internal Systems tickets in TLI by hand and close the TKLS copies with a URL comment (candidate query: `project = TKLS AND issuetype = Systems AND labels = internal`).

**Next steps**

1. Decide the four open questions before applying: 20831 chasing In Progress only; 23153 counting "assessed by CSO" together with the risk flags; "Ask a question" excluded from the board base; Forgotten-About window 4 days here vs 5 on devops.
2. Apply the changes in the Jira UI, in whatever order - suggested: 13 (clinical safety) first, then the base filters (1, 6) since the derivatives build on them.
3. After applying, run `bash ~/claude-kit/scripts/jira_dashboard_dump.sh -d 11653` and `bash ~/claude-kit/scripts/jira_dashboard_dump.sh -d 11651` so the dumps can be diffed against the intended state and the new filter counts sanity-checked via MCP.
4. Review and commit the kit knowledge updates from the 2026-08 review session.
