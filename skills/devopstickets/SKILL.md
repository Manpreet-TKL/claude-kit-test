---
name: devopstickets
description: JIRA DevOps triage menu (TKLS service desk)
disable-model-invocation: true
---

# DevOps JIRA triage (TKLS)

**Run `/jiramcp` first.** It makes the Atlassian MCP tools available (touching the kit's startup-gate flag and advising the `/mcp` reconnect if needed) and loads the OE / TKLS / OPD project context this skill relies on. All JIRA/Confluence access here goes through the `mcp__atlassian__*` MCP tools only - never the REST API, never `curl` an Atlassian endpoint. If any `mcp__atlassian__*` call below fails with a permission or connection error, stop and tell the user to run `/jiramcp` - do **not** fall back to REST.

## Step 1 - Present the menu, then wait

If invoked with `$ARGUMENTS`, parse them and skip the prompt: first token = option#, optional second token = filter#. A bare `TKLS-1234`-style key means option 4 for that ticket. For option 6 the second token is the search keyword (quote a multi-word phrase) and an optional trailing number is the filter#. Otherwise print exactly:

```
Filters (TKLS):
1.) DevOps All Open (saved filter 19720)
2.) DevOps - all time
3.) Systems - all time
4.) DevOps-assigned - all time

Options:
1.) Find top 10 easy to close tickets
2.) Mine 10 tickets for KB notes (reads full comment threads) -> file in $HOME
3.) Output suggested replies for 10 tickets
4.) Summarise one ticket: numbered history + suggested next steps
5.) Hunt SQL-query fixes (with proof the SQL worked) -> file in $HOME
6.) Hunt a keyword across tickets: summarise each fix, then cluster & count the unique fixes -> file in $HOME
```

Then: "Reply with `<option#>` and optionally `<filter#>`. For option 4 give the ticket key; for option 6 give the keyword." Filter default is **1**, except options **2, 5 and 6 default to filter 2** (the all-time DevOps scope, which includes the resolved tickets those options mine).

Filter table - each filter is a raw JQL **where-clause** (no `ORDER BY`); options append their own `ORDER BY`. Appending `ORDER BY` to `filter = 19720` overrides that saved filter's own sort.

| # | Name | What it covers | JQL |
|---|------|----------------|-----|
| 1 | DevOps All Open | the saved "DevOps All Open" filter (open work only) | `filter = 19720` |
| 2 | DevOps - all time | every DevOps ticket ever: Systems/Support assigned to the devops group, plus unassigned Systems | `project = TKLS AND (issuetype in (Systems, Support) AND assignee in membersOf("devops") OR (issuetype = Systems AND assignee is EMPTY))` |
| 3 | Systems - all time | all Systems requests, any status | `project = TKLS AND issuetype = Systems` |
| 4 | DevOps-assigned - all time | anything ever assigned to the devops group | `project = TKLS AND assignee in membersOf("devops")` |

## Step 2 - Dispatch (load detail on demand)

Once the option is known, **read the matching sub-file from this skill's directory with the Read tool and follow it exactly.** Each holds the full workflow and is loaded only when its option runs - do not pre-read them:

- Option 1 -> `subs/option1.md`
- Option 2 -> `subs/option2.md`
- Option 3 -> `subs/option3.md`
- Option 4 -> `subs/option4.md`
- Option 5 -> `subs/option5.md`
- Option 6 -> `subs/option6.md`

Options 1, 2, 3, 5 and 6 fetch ticket lists, and 2/3/5/6 read full comment threads - those subs begin by telling you to also read `subs/shared.md` (the light-list fetch + per-ticket deep-dive engine). Read `subs/shared.md` only when the chosen option calls for it. Option 4 is self-contained. `<filter JQL>` in any sub = the JQL where-clause of the chosen filter from the table above.
