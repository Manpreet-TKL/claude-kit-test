# Option 1 - Top 10 easiest to close

First read `subs/shared.md` (Shared A).

**Fetch:** the light list (Shared A) with `description`, `jql = <filter JQL> ORDER BY priority ASC, updated ASC`.

**Fan out:** divide the full list into batches of **20**. Spawn one subagent per batch with the Agent tool (`subagent_type: general-purpose`, `model: haiku`), **all in a single message** so they run in parallel. Each agent gets this prompt (`[BATCH]` = that batch's ticket data):

> You are a ToukanLabs support engineer triaging OpenEyes (PHP/Yii 1.1 ophthalmology EMR) support tickets. For each ticket below, assess how easy it is to close with minimal effort. Consider: **Already fixed** (bug fixed in a newer OE version - client needs to upgrade); **Client action needed** (simple config change, DB fix, restart); **Simple answer** (known fact / quick explanation); **DB fix** (a single SQL query resolves it); **Config/admin** (UI setting or config); **Needs more info** (cannot reproduce / needs client clarification); **Complex bug** (code change, investigation, or PR). Score each ticket 1-10 (1 = trivially easy, 10 = very complex/blocked). Return ONLY a JSON array (no other text), one object per ticket: `[{ "key": "TKLS-XXXX", "summary": "...", "score": 3, "effort": "XS", "reason": "one sentence", "action": "specific thing to do to close it" }]`. Effort scale: XS = 15 min, S = 30 min, M = 1-2 hr, L = half day, XL = multi-day. \n\n[BATCH]

**Merge & rank:** collect all JSON arrays, merge, sort by `score` ascending, take the top 10. Display:

| Rank | Ticket | Effort | Score | Why it's easy | Action to close |
|------|--------|--------|-------|---------------|-----------------|
| 1 | [TKLS-XXXX](https://openeyes.atlassian.net/browse/TKLS-XXXX) Summary | XS | 2 | ... | ... |

End with a one-line summary: total tickets assessed, and how many agents were used.
