# Option 3 - Suggested replies for 10 tickets

First read `subs/shared.md` (Shared A + Shared B). Default filter: **1**.

Draft a client-ready reply for the 10 tickets most in need of one. **Do NOT post anything.**

**Fetch:** the light list (Shared A), `jql = <filter JQL> ORDER BY updated ASC` (most stale first). Take the ~12 stalest and deep-dive them (Shared B) into `/tmp/oetriage/deep/<KEY>.json`; pick the 10 whose latest comment is from the reporter (i.e. awaiting our response).

**Fan out:** 2 batches of 5, parallel haiku agents; each agent reads the saved `/tmp/oetriage/deep/<KEY>.json` files for its batch. Each returns JSON:

```json
[{ "key": "TKLS-XXXX",
   "summary": "...",
   "reply": "polite, specific reply to the reporter, grounded in the description + latest comments - ask for missing info, give the known fix, or set expectations",
   "confidence": "high|med|low" }]
```

**Present** each as: ticket link + one-line context + the suggested reply in a quoted block + confidence. Then offer: "Say `post N` to add reply N as a comment via `mcp__atlassian__jira_add_comment`." Only post on explicit instruction - TKLS is a Service Desk project, so when posting set `public: true` for a customer-visible reply (or `false` for an internal note) and pass the reply as `body`.
