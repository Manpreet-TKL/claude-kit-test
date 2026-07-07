---
name: project-atlassian-scoped-token-gateway
description: Scoped Atlassian API tokens 401 on the site URL; mcp-atlassian needs a classic unscoped token. OpenEyes Jira cloudId recorded.
metadata: 
  node_type: memory
  type: project
  originSessionId: a1182574-cdb1-4438-8c33-2b4edc98ee62
---

Manpreet's Atlassian API tokens (for claude-kit's Jira wiring) are **scoped** tokens. Scoped tokens are rejected with a plain `401 "Client must be authenticated"` at the site URL (`https://<site>.atlassian.net/rest/api/3/...`) and only authenticate through the API gateway: `https://api.atlassian.com/ex/jira/<cloudId>/rest/api/3/...` (basic auth `email:token`). On the gateway, a missing scope returns `{"code":401,"message":"Unauthorized; scope does not match"}` (token valid, scope wrong) - distinct from a bad credential.

- Get cloudId (unauthenticated): `GET https://<site>.atlassian.net/_edge/tenant_info` -> `.cloudId`.
- OpenEyes (`openeyes.atlassian.net`) cloudId = `2bab103a-8c84-4d7f-b23a-c82dd29201cf`.
- Project "ToukanLabs Services" (TKLS) lives on **openeyes.atlassian.net**, not toukanlabs.atlassian.net.

**Why it matters:** the `mcp-atlassian` Docker server ([[project_cat_database_ssl_ca_empty]] unrelated) authenticates against the *site URL* with basic auth - the exact path scoped tokens refuse - so a scoped token makes the MCP server fail to connect (no container, no tools). Fix: create a **classic (unscoped)** API token ("Create API token", not "Create API token with scopes") for the kit, or switch mcp-atlassian to OAuth.

**How to apply:** when a Jira REST/MCP call 401s but the token shows "accessed" in id.atlassian.com, suspect a scoped token; test via the gateway URL before assuming the token is revoked. For claude-kit, recommend a classic token.
