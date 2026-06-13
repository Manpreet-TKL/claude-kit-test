# Option 6 — Hunt a keyword: cluster the fixes & count unique fixes → file in $HOME

First read `subs/shared.md` (Shared A + Shared B). Default filter: **2 (DevOps — all time)** — widen to 3 or 4 if the keyword spans non-DevOps tickets.

Goal: given a keyword (e.g. `worklist`), find every ticket that mentions it, summarise each ticket's actual fix, then **cluster the fixes and count how many *unique* fixes there are** — so a fix that recurs across many tickets stands out as a candidate to automate (e.g. fold into a `yiic` command). If no keyword was supplied, ask for one.

## 1 — Search (Shared A + keyword net)

Fetch the light list with the keyword ANDed in:
`<filter JQL> AND text ~ "<keyword>" ORDER BY created DESC`
`text ~` matches summary, description and comments. Page until exhausted (Shared A). Let `M` = number of matched tickets.

**Generic-keyword guard (the "unless it's too generic" check).** If `M > 60`, the keyword is too broad to fan out over (dozens of deep-dives + agents for a blurry result). STOP before any deep-dive and report: `M`, the issuetype/status breakdown, and a handful of sample summaries (the common terms in them). Ask the user to **narrow** the keyword (add a qualifier, or quote a multi-word phrase) **or confirm a capped run** over the **60 most recent** matches. Do not fan out until they answer.

## 2 — Deepen EVERY match (no finder step)

The keyword search already selects the tickets, so unlike options 2/5 there is no Haiku finder — just deep-dive them all. `mkdir -p /tmp/oetriage/deep`, then `jira_get_issue` (Shared B shape) each matched key in waves of ≈12, saving each to `/tmp/oetriage/deep/<KEY>.json`.

## 3 — Extract each ticket's fix (multiple agents, parallel Haiku)

Batch the matched keys into groups of **10**; spawn one Haiku agent per batch (`subagent_type: general-purpose`, `model: haiku`, **all in one message** so they run in parallel). Each agent reads ONLY the `/tmp/oetriage/deep/<KEY>.json` files for its batch (local files — no MCP, so it stays token-light) and returns a JSON array, one object per ticket:

> You are a ToukanLabs support engineer. For each OpenEyes (PHP/Yii 1.1 ophthalmology EMR) support-ticket JSON, read the comment thread (where the real resolution lives) and summarise the fix that was actually applied. Return `{ "key": "...", "problem": "one line", "fix": "1–2 lines: what was actually done to resolve it", "fix_signature": "a short normalised lowercase tag for the KIND of fix, e.g. 'reindex-worklist', 'restart-mirth', 'sql-null-institution' — tickets fixed the SAME way MUST share the SAME signature", "automatable": true|false, "confirmed": "the comment quote/event proving it worked", "source": "<KEY>" }`. If the ticket has no concrete, confirmed fix (still open, needs-info, or it points to an attachment/log/SQL not included in this JSON), return `{ "key": "...", "skip": true, "reason": "..." }`. Never invent a fix.

**Completeness gate:** drop skips and any object with an empty `fix` or `confirmed`. Let `K` = kept tickets.

## 4 — Cluster & count unique fixes (main loop)

In the main loop, group the kept objects into clusters of the SAME underlying fix — use `fix_signature` as a strong hint but merge near-duplicates (same root cause + same remedy). The number of clusters = **`unique_fix_count`**. For each cluster record: a short title, a one-line fix summary, the member ticket keys (so `count` = how many), whether it's `automatable`, and — when automatable — a one-line `yiic` sketch of what a command would do (e.g. `yiic fixworklist --patient=<id>` reindexes the orphaned worklist rows). Sort clusters by `count` descending; the high-count automatable ones are the prize.

## 5 — Write the file

1. `date +%F`; sanitise the keyword (lowercase, non-alphanumerics → `-`) for the filename.
2. With the Write tool, write to `"$HOME/devops-keyword-<keyword>-<date>.txt"`:
   - **Header:** keyword, filter used, `M` matched / `K` with a confirmed fix / **`unique_fix_count` unique fixes**, today's date; note each ticket's fix carries a confirmation quote.
   - **Recurring fixes first** — per cluster, count-descending: `## <title>  (×<count>)`, the fix summary, an `Automatable: yes/no` line and the `yiic` sketch when yes, then the member ticket links.
   - **Per-ticket appendix:** `<KEY> — <problem>` / `Fix: …` / `Confirmed: <quote>` / `Source: https://openeyes.atlassian.net/browse/<KEY>`; dashes between entries.
3. In chat, print the file path, the headline `M tickets → unique_fix_count unique fixes`, and a ranked one-line list of clusters with counts and the automatable flag (`×7 reindex-worklist (automatable) … ×3 restart-mirth …`) so the automation candidates are obvious at a glance.
