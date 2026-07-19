---
name: jiramcp
description: Jira + Confluence MCP context + gate enable
disable-model-invocation: false
---

# Jira + Confluence MCP - context + gate enable

Load how the kit's Atlassian MCP works, make its tools available (enabling the startup gate if needed), and load the project context that downstream skills (e.g. `devopstickets`) rely on. Everything goes through the `mcp__atlassian__*` MCP tools - never the JIRA/Confluence REST API, never `curl` an Atlassian endpoint, never read `~/claude-kit/generated/.atlassian.env`.

## Check - tools present, or touch the gate

1. **Tools present?** If the `mcp__atlassian__*` tools are in your toolset, print a one-line `Jira OK  Confluence OK` and the project context below, then hand back / proceed to whatever the user asked for.
2. **Tools absent?** Run `touch ~/claude-kit/generated/mcp-on/atlassian` - the **only** shell command this skill runs - then reply with exactly this one line and nothing else (no explanation of the gate, no advice dump) and stop: `atlassian MCP ungated - reconnect: /mcp -> atlassian -> reconnect`. Once the user has reconnected, continue with the task.

Beyond that one `touch`, take no other action: no docker commands, no `install.sh` runs, and never a fallback to the REST API - when a call fails, stop and relay the matching advice below; the user runs the fix.

- **Permission denied** -> the `mcp__atlassian` allow rule is missing for this tier - advise `~/claude-kit/install.sh -p <tier> -y` (or adding `mcp__atlassian` to `permissions.allow`).
- **401 / auth errors** -> bad token or wrong URL in `generated/.atlassian.env` - advise fixing it and re-running `~/claude-kit/install.sh --with-atlassian -y` (scoped API tokens don't work here - see `docs/atlassian.md`).
- **Reconnect still fails** -> advise restarting Claude Code, touching the flag, and reconnecting in `/mcp` (or touching the flag before launch). The stdio container is launched by Claude Code itself - only the `/mcp` reconnect (or a restart) spawns it.

## Project context (the token's visible scope)

Site: `https://openeyes.atlassian.net`, Jira ticket links: `https://openeyes.atlassian.net/browse/<KEY>`, Confluence: `https://openeyes.atlassian.net/wiki/spaces/OPD/...`

The mcp-atlassian token is scoped to two Jira projects (`JIRA_PROJECTS_FILTER=TKLS,OE`) and one Confluence space (`OPD`):

- **OE - OpenEyes Development** (Jira, software project). The development project for OpenEyes itself: an open-source ophthalmology EMR (PHP/Yii 1.1, with a Laravel re-platform underway). Product features, bugs, and engineering work live here.
- **TKLS - ToukanLabs Services** (Jira, service-desk project). The customer support / DevOps desk: client-raised support tickets, incidents, and service requests for OpenEyes deployments. This is the project the `devopstickets` triage skill works against.
- **OPD - OpenEyes product documentation** (Confluence space, key `OPD`). Developer and product docs: release notes, the release timeline & supported-version policy, the developer checklist, the XAPI framework, the Laravel re-platform overview, testing (PHPUnit), and per-event admin guides (e.g. Biometry). Search it with `mcp__atlassian__confluence_search` when a ticket needs a documented answer or known fix.
