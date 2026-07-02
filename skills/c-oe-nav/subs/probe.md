# Live probe — verify the UI without burning main context

When the atlas (`subs/paths.md`) and the fix branch's view code don't settle a label, a gesture, or an outcome — or the user wants proof — drive the real instance. **Run the walk in a cheap subagent**; only distilled steps come back to the main session (~2–5k tokens instead of 30–100k).

The probe runs **inside the web container itself** via `docker exec` — the standard `oe-web-live` image (≈99% of deployments) already ships Node, Puppeteer and Chrome (docman renders lightning previews with them). One driver covers everything: UI gestures, JS-rendered labels, and firing endpoints for proof. Nothing is installed, nothing is written to the image, no second container. For the rare image without the bundled browser (dev/debug images carry Playwright; browserless/remote-chrome stacks like monkey have no in-container browser) — or when a Playwright run is explicitly requested — use the fallback: `subs/probe-playwright.md`.

## When to probe

- A label/control the atlas marks unverified or doesn't cover (in-form fields, icon-row buttons, dialogs behind gestures like print/upload/search).
- The running version differs from the atlas stamp and the flow matters.
- The user asks for proof a repro actually reproduces (pair a gesture or endpoint with a server-side check).

## Target discovery

`docker ps` → web container `<stack>-web-1`; image tag = running OE version (e.g. `oe-web-live:11.0.18`). Inside the container the app answers at `http://localhost`. Sample creds `admin`/`admin`, institution 1, site 1. **Sample boxes only — never point the probe at a clinical instance.**

## The driver

`scripts/journey.mjs` (this skill) — a Puppeteer script: logs in (hidden institution/site inputs), runs a JSON action list, prints a compact text dump after each step (URL, headings, error banners, visible buttons/fields/links with selectors; popup-scoped when a dialog is open). Read-only by design: it refuses delete-like clicks and dismisses native confirms unless `OE_ALLOW_WRITE=1`. Action schema and env vars are in the script header. Selectors: CSS, `text="Exact label"`, or `<sel> >> nth=N`.

Pipe the script in on stdin (nothing lands in the image) with the action list in `OE_ACTIONS`:

```bash
docker exec -i -e OE_ACTIONS='[{"goto":"/patient/summary/17891"},{"click":"#add-event"}]' \
  -w /var/www/openeyes snail-web-1 node --input-type=module - < scripts/journey.mjs
```

- `-w /var/www/openeyes` so Puppeteer resolves from the app's `node_modules` and `.puppeteerrc.cjs` finds the bundled Chrome; `--input-type=module` because the ESM script arrives on stdin.
- Swap `snail-web-1` for the target container. Creds/institution/site override via `-e OE_USERNAME/OE_PASSWORD/OE_INSTITUTION_ID/OE_SITE_ID`; `BASE_URL` defaults to `http://localhost`.
- Screenshots only when a text dump is ambiguous: append `--shot /tmp/oeshots` and `docker cp` them out. Text first — screenshots cost subagent tokens.
- `upload` files must be inside the container: `docker cp <file> snail-web-1:/tmp/x.pdf` first, reference `/tmp/x.pdf`, remove it after.
- Exit codes: 0 ok · 2 step failed (the dump shows the state at failure — pick the right label from it) · 3 login/infra.

## Endpoints and proof — same driver, no other HTTP tool

- The driver is a logged-in browser: `{"goto":"/eventImage/getImageInfo?event_id=123"}` fires an endpoint with the session, and a following `{"read":"body"}` prints the JSON response.
- Real POSTs fire the way the app makes them — goto the page whose JS sends them (an event's print view POSTs `/eventImage/generateImage/<id>` on load).
- Observe the server-side effect with a plain `docker exec` before and after the journey, e.g. `docker exec <stack>-web-1 sh -c 'ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l'` — the pairing is what makes Steps to Reproduce provable.

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

Tool: run the command below with Bash. It execs into the web container and runs
the bundled Puppeteer/Chrome — nothing is installed. Put the action list in
OE_ACTIONS: an array of single-key objects — goto/click/fill/select/upload/
press/wait/read; selectors are CSS, text="Exact label", or "<sel> >> nth=N".
JSON endpoints: goto the URL then read "body". After each step the driver
dumps what is visible. Refine OE_ACTIONS between runs; max 4 runs. Never wait
for network-idle. Read-only: do not click Save/Delete or upload unless the
goal explicitly says so.

<the docker exec command from The driver, container + env adjusted>

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
- Sample ids (patient 17891, admin/admin, episode ids) never appear in PR text — PRs stay client-agnostic.
- Desktop alternative: Claude in Chrome (extension ≥1.0.36 + `claude --chrome`, same-desktop only — not from this headless box) can walk the flow in a real logged-in browser and record a GIF as ticket evidence. Use it for watch-and-verify, not at volume.
