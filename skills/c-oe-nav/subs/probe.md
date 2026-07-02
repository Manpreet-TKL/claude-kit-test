# Live browser probe — verify the UI without burning main context

When the atlas (`subs/paths.md`) and the fix branch's view code don't settle a label, a gesture, or an outcome — or the user wants proof — walk the real UI. **Run the walk in a cheap subagent**; only distilled steps come back to the main session (~2–5k tokens instead of 30–100k).

## When to probe

- A label/control the atlas marks unverified or doesn't cover (in-form fields, icon-row buttons, dialogs behind gestures like print/upload/search).
- The running version differs from the atlas stamp and the flow matters.
- The user asks for proof a repro actually reproduces (pair with a server-side check).

## Target discovery

`docker ps` → web container `<stack>-web-1`; image tag = running OE version (e.g. `oe-web-live:11.0.18`); network `<stack>_backend`; in-network the app answers at `http://web`. Sample creds `admin`/`admin`, institution 1, site 1. **Sample boxes only — never point the probe at a clinical instance.**

## The driver

`scripts/journey.mjs` (this skill) — self-contained Playwright script: logs in (hidden institution/site inputs), runs a JSON action list, prints a compact text dump after each step (URL, headings, error banners, visible buttons/fields/links with selectors; popup-scoped when a dialog is open). Read-only by design: it refuses delete-like clicks and dismisses native confirms unless `OE_ALLOW_WRITE=1`. Action schema and env vars are documented in the script header. Selectors are Playwright selectors — CSS or `text="Exact label"`.

Run it in the official Playwright container joined to the app network (nothing installed on the host):

```bash
docker run --rm -i --network snail_backend \
  -v /home/toukan/claude-kit/skills/c-oe-nav/scripts:/probe:ro \
  -e BASE_URL=http://web -e PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
  mcr.microsoft.com/playwright:v1.55.0-noble \
  bash -c 'mkdir -p /j && cp /probe/journey.mjs /j && cd /j \
    && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm -s i --no-save playwright@1.55.0 \
    && node journey.mjs -' <<'EOF'
[
  {"goto": "/patient/summary/17891"},
  {"click": "#add-event"}
]
EOF
```

- Swap `snail_backend` for the target stack's network. Creds/institution/site override via `-e OE_USERNAME/OE_PASSWORD/OE_INSTITUTION_ID/OE_SITE_ID`.
- Fast path when `~/oe-frontend-tests` exists (skips the ~15s npm install): add `-v /home/toukan/oe-frontend-tests/node_modules:/node_modules:ro` and run `node /probe/journey.mjs -` directly (mount at `/node_modules` — module resolution walks up from `/probe`; mounting inside the read-only `/probe` fails).
- Screenshots only when a text dump is ambiguous: mount a writable dir (`-v <scratch>:/shots`) and append `--shot /shots`. Text first — screenshots cost subagent tokens.
- Files for `upload` actions must be mounted into the container too.
- Exit codes: 0 ok · 2 step failed (dump shows the state at failure — pick the right label from it) · 3 login/infra.

## Subagent prompt template

Launch with the Agent tool, **model `haiku`** when the journey is known (walk + transcribe), `sonnet` only when the flow itself must be figured out. Paste the relevant atlas lines in — the subagent does not load skills:

```
You are probing a running OpenEyes sample instance to capture EXACT frontend
labels and steps. This box is disposable sample data (login admin/admin).

Goal: <what to walk and what to bring back, e.g. "open the Document event
create form and report the exact labels of the sub-type, upload mode and
file fields, and what the on-screen error says when Save is clicked empty">.

Known navigation (trust this, do not rediscover):
<paste the relevant lines from subs/paths.md / subs/examination.md>

Tool: run the docker command below with Bash; the heredoc JSON is the action
list. Schema: array of single-key objects — goto/click/fill/select/upload/
press/wait/read; selectors are Playwright CSS or text="Exact label". After
each step the driver dumps what is visible. Refine the action list between
runs; max 4 runs. Never wait for network-idle. Read-only: do not click
Save/Delete or upload unless the goal explicitly says so.

<the docker run command, network + env adjusted>

Return ONLY:
1. Numbered user steps with exact quoted UI labels (as a human would follow).
2. The evidence lines from the dumps that show each label (quoted).
3. The OE version line the driver printed.
4. Anything that blocked you.
No transcripts, no screenshots unless asked.
```

## Policies

- Write actions (Save/upload/delete) only on sample boxes, only when the repro demands it, and say so in the result. `OE_ALLOW_WRITE=1` is the explicit switch.
- Stamp what you verified: "labels verified on v11.0.18" — and note when that differs from the PR's Affects version.
- Pair the UI walk with the server-side observation the PR needs (e.g. `docker exec <stack>-web-1 ls -1 /tmp/OE??????` before/after) — the pairing is what makes Steps to Reproduce provable.
- Sample ids (patient 17891, admin/admin, episode ids) never appear in PR text — PRs stay client-agnostic.
- Desktop alternative: Claude in Chrome (extension ≥1.0.36 + `claude --chrome`, same-desktop only — not from this headless box) can walk the flow in a real logged-in browser and record a GIF as ticket evidence. Use it for watch-and-verify, not at volume.
