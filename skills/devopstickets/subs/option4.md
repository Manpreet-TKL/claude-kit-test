# Option 4 — One ticket: numbered history + next steps

Self-contained — no shared engine, no fan-out.

1. If no ticket key was given, ask for it (e.g. `TKLS-1234`).
2. `mcp__atlassian__jira_get_issue` with `issue_key: <KEY>`, `fields: "summary,description,status,priority,assignee,reporter,created,updated,comment"`, `comment_limit: 100`, `expand: "changelog"`.
3. Output a single **numbered, chronological** list of what has happened: creation (who/when), each status transition and assignee change (from the changelog), and each comment (author + gist + date).
4. Then a numbered **Suggested next steps** list, grounded in the current status and the latest activity.
