# Option 5 — Hunt SQL-query fixes (with proof the SQL worked) → file in $HOME

First read `subs/shared.md` (Shared A + Shared B). Default filter: **2 (DevOps — all time)**.

Find tickets resolved by a **SQL query that is present in the ticket and confirmed to have worked**.

**Narrow before deep-diving.** AND the chosen filter with a SQL-keyword text net so you fetch far fewer tickets:
`<filter JQL> AND (text ~ "UPDATE" OR text ~ "SELECT" OR text ~ "DELETE" OR text ~ "ALTER" OR text ~ "WHERE")`
`text ~` matches prose too ("please update…"), so treat it only as a coarse net — the per-ticket gate decides truth.

Run the **Shared B engine** with `N = 10`. Writer agent (per ticket, reading `/tmp/oetriage/deep/<KEY>.json`):

> You are a ToukanLabs DBA reviewing an OpenEyes support-ticket JSON. Extract a fix ONLY if the comments/description contain an ACTUAL SQL statement (SELECT/UPDATE/DELETE/INSERT/ALTER…) that was run to resolve the issue, AND explicit confirmation it worked (e.g. "applied", "ran successfully", "confirmed", "fixed", client sign-off, or the ticket moved to Done right after it). Return JSON: `{ "key": "...", "problem": "one line", "sql": "the verbatim SQL", "db": "OE|CERA|... if stated", "confirmation": "the quote/event proving it worked", "source": "<KEY>" }`. If there is no real SQL, or no confirmation it worked, return `{ "skip": true, "reason": "..." }`. NEVER fabricate or "reconstruct" SQL — copy it verbatim or skip. \n\n[TICKET JSON]

Completeness gate: drop any result with empty `sql` or empty `confirmation`; loop until 10 (or report fewer).

**Write the file:**
1. `date +%F` for today's date.
2. With the Write tool, write to `"$HOME/devops-sql-fixes-<date>.txt"`. Per entry: a `<KEY> — <problem>` heading, the SQL in a fenced ```sql block (verbatim), then `DB:`, `Confirmed: <quote>`, and `Source: https://openeyes.atlassian.net/browse/<KEY>`; dashes between entries. Header: note every entry's SQL is copied verbatim from the ticket and carries proof it worked.
3. In chat, print the file path and a one-line index (`KEY → problem`).
