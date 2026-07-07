# Option 2 - Mine 10 tickets for KB notes (full comment threads) -> file in $HOME

First read `subs/shared.md` (Shared A + Shared B). Default filter: **2 (DevOps - all time)** - the finder agents favour resolved tickets within it.

Produce 10 **accurate** KB notes whose fix is grounded in the ticket's actual resolution - read from the comment thread, not guessed from the summary.

Run the **Shared B engine** with `N = 10`:
- Finder agents pick candidates that look like a *reusable, resolved* issue (recurring problem, known config/DB/Mirth/SSO gotcha, FAQ) - skip one-offs, "needs more info", and still-open complex bugs.
- Writer agent (per ticket, reading `/tmp/oetriage/deep/<KEY>.json`):

> You are a ToukanLabs support engineer. Read this OpenEyes (PHP/Yii 1.1 ophthalmology EMR) support-ticket JSON - especially the comment thread, which holds the real resolution. Write a TKL-style KB note ONLY if the ticket contains a concrete fix that was actually applied. Return a JSON object: `{ "key": "...", "category": "OpenEyes|MySQL|Mirth|SSH|Docker|...", "title": "<Category> - <Subject>", "note": "1-3 line intro (when/why you land here)\n1.) imperative step\n2.) imperative step", "confirmed": "the comment quote/paraphrase showing the fix worked", "source": "<KEY>" }`. If the resolution is NOT actually in this text - e.g. it points to a SQL query, attachment, or log that isn't included here - return `{ "skip": true, "reason": "..." }`. Never invent steps. \n\n[TICKET JSON]

Apply the completeness gate (drop skips and any note whose `confirmed` is empty); loop until 10.

**Write the file:**
1. `date +%F` for today's date.
2. With the Write tool, write all notes to `"$HOME/devops-notes-<date>.txt"`. Plain text, note-style (`<Category> - <Subject>` heading, `1.)` steps, no fluff, grep-discoverable); dashes between notes; end each with a `Confirmed:` line (the proof the fix worked) and `Source: https://openeyes.atlassian.net/browse/<KEY>`. Header: state notes were drawn from full comment threads and each carries a confirmation.
3. In chat, print the file path and a one-line index (`KEY -> title`).
