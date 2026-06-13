---
name: jiramcp
description: Fast Jira + Confluence MCP connection check — pings both via the mcp-atlassian tools using minimal tokens, fails fast with remediation if either is unavailable, then loads context on the OE, TKLS and OPD projects. Run this before any Jira/Confluence work.
disable-model-invocation: true
---

# Jira + Confluence MCP preflight

Confirm the Atlassian MCP server is connected, fail fast if it isn't, then load the project context that downstream skills (e.g. `devopstickets`) rely on. Everything goes through the `mcp__atlassian__*` MCP tools — never the JIRA/Confluence REST API, never `curl` an Atlassian endpoint, never read `~/claude-kit/generated/.atlassian.env`.

## Check — fail fast (run both pings in ONE message, in parallel)

1. **Tools present?** If the `mcp__atlassian__*` tools are not in your toolset, the server didn't connect at startup. Run the remediation block, tell the user to **restart Claude Code** (MCP tools bind at startup), and stop.
2. **Jira ping:** `mcp__atlassian__jira_search` with `{ "jql": "ORDER BY created DESC", "limit": 1, "fields": "key" }`.
3. **Confluence ping:** `mcp__atlassian__confluence_search` with `{ "query": "type=page", "limit": 1 }`.

Interpret each call independently:
- **Returns a result (even an empty list) with no error** → that side is healthy.
- **Permission denied** → the `mcp__atlassian` allow rule is missing from settings. Tell the user to re-run `~/claude-kit/install.sh -p <tier> -y` (or add `mcp__atlassian` to `permissions.allow`) and stop.
- **Connection error / "not connected" / timeout** → run the remediation block, tell the user to restart, and stop.

**Fail fast:** if either ping fails, stop here — do not continue and do not fall back to REST. Only when BOTH succeed, print a one-line `Jira ✔  Confluence ✔` and the project context below, then hand back / proceed to whatever the user asked for.

Remediation (shell/CLI only — none of this touches the Atlassian REST API):

```bash
docker info >/dev/null 2>&1 || echo "Docker daemon is not running — start Docker."
docker image inspect ghcr.io/sooperset/mcp-atlassian:latest >/dev/null 2>&1 \
  || docker pull ghcr.io/sooperset/mcp-atlassian:latest        # pull the image if absent
claude mcp get atlassian >/dev/null 2>&1 \
  || (cd ~/claude-kit && ./install.sh -j -c -p trusted -y)     # register the server if absent
claude mcp list                                                # expect: atlassian … ✔ Connected
```

The stdio container is launched by Claude Code itself on (re)start — you cannot `docker run` it into this session out of band. Once the image is present and the server is registered, a restart brings the tools online.

## Project context (the token's visible scope)

Site: `https://openeyes.atlassian.net` · Jira ticket links: `https://openeyes.atlassian.net/browse/<KEY>` · Confluence: `https://openeyes.atlassian.net/wiki/spaces/OPD/...`

The mcp-atlassian token is scoped to two Jira projects (`JIRA_PROJECTS_FILTER=TKLS,OE`) and one Confluence space (`OPD`):

- **OE — OpenEyes Development** (Jira, software project). The development project for OpenEyes itself: an open-source ophthalmology EMR (PHP/Yii 1.1, with a Laravel re-platform underway). Product features, bugs, and engineering work live here.
- **TKLS — ToukanLabs Services** (Jira, service-desk project). The customer support / DevOps desk: client-raised support tickets, incidents, and service requests for OpenEyes deployments. This is the project the `devopstickets` triage skill works against.
- **OPD — OpenEyes product documentation** (Confluence space, key `OPD`). Developer and product docs: release notes, the release timeline & supported-version policy, the developer checklist, the XAPI framework, the Laravel re-platform overview, testing (PHPUnit), and per-event admin guides (e.g. Biometry). Search it with `mcp__atlassian__confluence_search` when a ticket needs a documented answer or known fix.
