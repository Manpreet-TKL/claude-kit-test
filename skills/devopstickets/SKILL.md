---
name: devopstickets
description: Interactive JIRA DevOps triage menu for the TKLS service desk — pick a saved filter, then run one of 4 workflows (easiest-to-close, KB-note candidates, suggested replies, single-ticket summary). MCP only, never the REST API.
argument-hint: "[option#] [filter#] | <TICKET-KEY>"
disable-model-invocation: true
---

# DevOps JIRA triage (TKLS)

**Run `/jiramcp` first.** It verifies the Jira + Confluence MCP connection and loads the OE / TKLS / OPD project context this skill relies on. All JIRA/Confluence access here goes through the `mcp__atlassian__*` MCP tools only — never the REST API, never `curl` an Atlassian endpoint. If any `mcp__atlassian__*` call below fails with a permission or connection error, stop and tell the user to run `/jiramcp` — do **not** fall back to REST.

## Step 1 — Present the menu, then wait

If invoked with `$ARGUMENTS`, parse them and skip the prompt: first token = option#, optional second token = filter#. A bare `TKLS-1234`-style key means option 4 for that ticket. Otherwise print exactly:

```
Filters:
1.) DevOps All Open = 19720

Options:
1.) Find top 10 easy to close tickets
2.) Find tickets to create notes on and output notes to file in $HOME
3.) Output suggested replies for 10 tickets
4.) Summarise one ticket: numbered history + suggested next steps
```

Then: "Reply with `<option#>` and optionally `<filter#>` (filter defaults to 1). For option 4 give the ticket key."

Filter table (JQL for a chosen filter is `filter = <id>`):

| # | Name | filter id |
|---|------|-----------|
| 1 | DevOps All Open | 19720 |

## Shared — fetching tickets (MCP, paginated)

Use `mcp__atlassian__jira_search`:
- `jql`: `filter = <id> <ORDER BY …>`
- `fields`: `summary,description,status,priority,issuetype,assignee,updated,comment`
- `limit`: 50 (the max)
- Paginate until all issues are retrieved: pass the previous response's `page_token` if present, else increment `start_at` by 50. Record the `total` from the first response.

Collect per ticket: key, summary, description, status, priority, issuetype, assignee, comment bodies.

---

## Option 1 — Top 10 easiest to close

**Fetch:** all tickets, `jql = filter = <id> ORDER BY priority ASC, updated ASC`.

**Fan out:** divide the full list into batches of **20**. Spawn one subagent per batch with the Agent tool (`subagent_type: general-purpose`, `model: haiku`), **all in a single message** so they run in parallel. Each agent gets this prompt (`[BATCH]` = that batch's ticket data):

> You are a ToukanLabs support engineer triaging OpenEyes (PHP/Yii 1.1 ophthalmology EMR) support tickets. For each ticket below, assess how easy it is to close with minimal effort. Consider: **Already fixed** (bug fixed in a newer OE version — client needs to upgrade); **Client action needed** (simple config change, DB fix, restart); **Simple answer** (known fact / quick explanation); **DB fix** (a single SQL query resolves it); **Config/admin** (UI setting or config); **Needs more info** (cannot reproduce / needs client clarification); **Complex bug** (code change, investigation, or PR). Score each ticket 1–10 (1 = trivially easy, 10 = very complex/blocked). Return ONLY a JSON array (no other text), one object per ticket: `[{ "key": "TKLS-XXXX", "summary": "...", "score": 3, "effort": "XS", "reason": "one sentence", "action": "specific thing to do to close it" }]`. Effort scale: XS = 15 min, S = 30 min, M = 1–2 hr, L = half day, XL = multi-day. \n\n[BATCH]

**Merge & rank:** collect all JSON arrays, merge, sort by `score` ascending, take the top 10. Display:

| Rank | Ticket | Effort | Score | Why it's easy | Action to close |
|------|--------|--------|-------|---------------|-----------------|
| 1 | [TKLS-XXXX](https://openeyes.atlassian.net/browse/TKLS-XXXX) Summary | XS | 2 | … | … |

End with a one-line summary: total tickets assessed, and how many agents were used.

---

## Option 2 — Tickets that should have a KB note → file in $HOME

Surface tickets whose resolution is a reusable knowledge-base note (recurring issue, known fix, config/DB gotcha, FAQ answer) and draft each note in TKL note style (see the `note-style` skill), then write them to a file in `$HOME`.

**Fetch:** `jql = filter = <id> ORDER BY updated DESC`.

**Fan out:** batches of **20**, parallel haiku agents (as in Option 1). Each agent returns ONLY a JSON array of the note-worthy tickets in its batch — skip one-offs, needs-more-info, and unresolved complex bugs:

```json
[{ "key": "TKLS-XXXX",
   "category": "OpenEyes",          // concrete tool: OpenEyes / MySQL / SSH / Docker …
   "title": "<Category> - <Subject>",
   "note": "1–3 line intro (when/why you'd land here)\n1.) imperative step\n2.) imperative step",
   "source": "TKLS-XXXX" }]
```

**Write the file:**
1. Run `date +%F` to get today's date.
2. With the Write tool, write all notes to `"$HOME/devops-notes-<date>.txt"`. Plain text, note-style format (`<Category> - <Subject>` heading, `1.)` steps, no fluff, grep-discoverable). Separate notes with a line of dashes; end each with `Source: https://openeyes.atlassian.net/browse/<KEY>`.
3. In chat, print the file path and a one-line index (`KEY → title`) of what was written.

---

## Option 3 — Suggested replies for 10 tickets

Draft a client-ready reply for the 10 tickets most in need of one. **Do NOT post anything.**

**Fetch:** `jql = filter = <id> ORDER BY updated ASC` (most stale first). Take the first 10, preferring tickets whose latest comment is from the reporter (i.e. awaiting our response).

**Fan out:** split the 10 into 2 batches of 5, parallel haiku agents. Each returns JSON:

```json
[{ "key": "TKLS-XXXX",
   "summary": "...",
   "reply": "polite, specific reply to the reporter, grounded in the description + latest comments — ask for missing info, give the known fix, or set expectations",
   "confidence": "high|med|low" }]
```

**Present** each as: ticket link + one-line context + the suggested reply in a quoted block + confidence. Then offer: "Say `post N` to add reply N as a comment via `mcp__atlassian__jira_add_comment`." Only post on explicit instruction — TKLS is a Service Desk project, so when posting set `public: true` for a customer-visible reply (or `false` for an internal note) and pass the reply as `body`.

---

## Option 4 — One ticket: numbered history + next steps

1. If no ticket key was given, ask for it (e.g. `TKLS-1234`).
2. `mcp__atlassian__jira_get_issue` with `issue_key: <KEY>`, `fields: "summary,description,status,priority,assignee,reporter,created,updated,comment"`, `comment_limit: 100`, `expand: "changelog"`.
3. Output a single **numbered, chronological** list of what has happened: creation (who/when), each status transition and assignee change (from the changelog), and each comment (author + gist + date).
4. Then a numbered **Suggested next steps** list, grounded in the current status and the latest activity.

One ticket — do it directly, no fan-out.
