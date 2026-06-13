# Shared fetch + deep-dive engine

Used by options 1, 2, 3 and 5. `<filter JQL>` = the JQL where-clause for the chosen filter (see the filter table in `SKILL.md`).

## Shared A — fetch the ticket LIST (light; works around the payload cap)

`mcp__atlassian__jira_search`:
- `jql`: `<filter JQL> <ORDER BY …>`
- `fields`: `summary,status,priority,issuetype,assignee,updated` — **light fields only. Do NOT request `comment` in a bulk search.** A 50-issue page with comments is ~0.5 MB and even descriptions push ~77 KB; both exceed the MCP inline token cap, so the result silently auto-saves to a file under `…/tool-results/` and you get a path back instead of data.
- `limit`: 50; paginate with `page_token` (carried on the response) until there is none. `total` is `-1` on this Cloud instance (approximate count disabled) — don't trust it; page until exhausted.
- If a page still overflows to a file, read it back with `jq`, projecting only the light fields (truncate any long string) so it fits.

This light list is enough to enumerate and to pick candidates. **Option 1 may additionally request `description`** to judge effort — expect that page to overflow to a file; `jq`-truncate `description` to ~500 chars. **Options 2, 3 and 5 do not pull text in bulk** — they read it per-ticket via Shared B.

## Shared B — deep-dive ONE ticket (the way around the limit to read solutions)

Resolutions live in the comments, and a bulk search with comments overflows — so read solutions **one ticket at a time**, which fits inline:

`mcp__atlassian__jira_get_issue` with `issue_key: <KEY>`, `fields: "summary,description,status,resolution,assignee,reporter,created,updated,comment"`, `comment_limit: 50` (Option 4 also `expand: "changelog"`).

**Find → deepen → write engine** (used by options 2 and 5; target count `N = 10`):

1. **Find (cheap, Haiku).** From the Shared-A light list, spawn parallel haiku finder agents over batches of **20** (`subagent_type: general-purpose`, `model: haiku`, all in one message). Each picks the candidates most likely to carry a *documented, confirmed* resolution — prefer `statusCategory = Done`/resolved and tickets with real back-and-forth — and returns ONLY a JSON array of `{ "key": "...", "reason": "one line" }`, best-first. Merge into one ranked candidate queue.
2. **Deepen (main loop).** `mkdir -p /tmp/oetriage/deep`. Walk the queue and `jira_get_issue` (above) each candidate, saving the returned JSON to `/tmp/oetriage/deep/<KEY>.json`. Fetch in small waves (≈12 at a time) so you only pull what you need to hit `N`.
3. **Write (cheap, Haiku).** One haiku agent per fetched ticket reads **only** its `/tmp/oetriage/deep/<KEY>.json` (a local file — no MCP, so the agent stays token-light) and returns the note / SQL-extract, OR `{ "skip": true, "reason": "..." }`.
4. **Completeness gate.** REJECT any result that refers to content **not actually present** in the fetched ticket — a SQL query, attachment, log, or screenshot it tells you to "see" but that isn't in the comments/description. Drop skips and incompletes. If you have fewer than `N`, pull the next wave from the candidate queue and repeat. Stop at `N` complete results or an exhausted queue (then say how many you got).
