# Live probe — verify the UI without burning main context

When the atlas (`subs/paths.md`) and the fix branch's view code don't settle a label, a gesture, or an outcome — or the user wants proof — drive the real instance. **Run the walk in a cheap subagent**; only distilled steps come back to the main session (~2–5k tokens instead of 30–100k).

The probe runs **inside the web container itself** via `docker exec` — the standard `oe-web-live` image (≈99% of deployments) already ships Node, Puppeteer and Chrome (docman renders lightning previews with them). One driver covers everything: UI gestures, JS-rendered labels, and firing endpoints for proof. Nothing is installed, nothing is written to the image, no second container. For the rare image without the bundled browser (dev/debug images carry Playwright; browserless/remote-chrome stacks like monkey have no in-container browser) — or when a Playwright run is explicitly requested — use the fallback: `subs/probe-playwright.md`.

## When to probe

- A label/control the atlas marks unverified or doesn't cover (in-form fields, icon-row buttons, dialogs behind gestures like print/upload/search).
- The running version differs from the atlas stamp and the flow matters.
- The user asks for proof a repro actually reproduces (pair a gesture or endpoint with a server-side check).

## Target discovery

`docker ps` → web container `<stack>-web-1`; image tag = running OE version (e.g. `oe-web-live:11.0.18`). Inside the container the app answers at `http://localhost`. Sample creds `admin`/`admin`, institution 1, site 1. **Sample boxes only — never point the probe at a clinical instance.**

Most journeys need a **real patient/episode/context id** to drive — but **don't reach for the DB first**: the atlas already records sample patient 17891, its Add-Event ctx/ep pairs and all event_type_ids, and a stale pair fails fast (HTTP 400 "Episode/Context mismatch"), so try the recorded ids and hit the DB only on a 400, for a data-shaped patient pick ("a patient with …"), or for before/after DB-state proof. When you do need it, get access from the **`c-dblogin`** skill — load it first rather than fumbling the login: the client is **`mariadb`**, not `mysql`, and root reads a password *file* (`$MYSQL_ROOT_PASSWORD_FILE` / `/run/secrets/…`), not an env var. One-shot form: `docker exec <stack>-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -N openeyes -e "<SQL>"'`. Cheapest picks — a patient `SELECT id FROM patient WHERE deleted=0 LIMIT 1`; its Add-Event pair `SELECT id, firm_id FROM episode WHERE patient_id=<pid> AND deleted=0` (`firm_id`=`context_id`, `id`=`episode_id`); an event type `SELECT id FROM event_type WHERE class_name='<Module>'`.

## The driver

`scripts/journey.mjs` (this skill) — a Puppeteer script: logs in (hidden institution/site inputs) and runs a JSON action list. **Output is quiet by default** — the `oe version:` line, explicit `read`s, any `STEP FAILED` state, and one final snapshot of where you landed; nothing per step. Pass `--verbose` (or `-e OE_VERBOSE=1`) to dump a compact structural view after *every* step (URL, headings, error banners, visible buttons/fields/links with selectors; popup-scoped when a dialog is open); see *Taming the dump*. Read-only by design: it refuses delete-like clicks and dismisses native confirms unless `OE_ALLOW_WRITE=1`. Selectors: CSS, `text="Exact label"`, or `<sel> >> nth=N`. Full action schema (no need to read the script header): `{"goto":"/path"}` · `{"click":"<sel>"}` · `{"fill":["<sel>","<value>"]}` · `{"select":["<sel>","<option value>"]}` · `{"upload":["<sel>","/file/in/container"]}` (works on `display:none` inputs) · `{"press":"Enter"}` · `{"wait":<ms>}` · `{"read":"<sel>"}` · `{"dump":true}` · first action `{"login":false}` skips login. Env-var overrides are in the invocation bullets below.

Pipe the script in on stdin (nothing lands in the image) with the action list in `OE_ACTIONS`:

```bash
docker exec -i -e OE_ACTIONS='[{"goto":"/patient/summary/17891"},{"click":"#add-event"}]' \
  -w /var/www/openeyes snail-web-1 node --input-type=module - < scripts/journey.mjs
```

- `-w /var/www/openeyes` so Puppeteer resolves from the app's `node_modules` and `.puppeteerrc.cjs` finds the bundled Chrome; `--input-type=module` because the ESM script arrives on stdin.
- Swap `snail-web-1` for the target container. Creds/institution/site override via `-e OE_USERNAME/OE_PASSWORD/OE_INSTITUTION_ID/OE_SITE_ID`; `BASE_URL` defaults to `http://localhost`.
- Screenshots only when a text dump is ambiguous: append `--shot /tmp/oeshots` and `docker cp` them out. Text first — screenshots cost subagent tokens.
- `upload` files must be inside the container: `docker cp <file> snail-web-1:/tmp/x.pdf` first, reference `/tmp/x.pdf`, remove it after — or generate a test PDF in-container with `gs` (ships in web-live; one-liner in the Document create form section of `subs/paths.md`).
- Exit codes: 0 ok · 2 step failed (the dump shows the state at failure — pick the right label from it) · 3 login/infra.

## Taming the dump — token discipline

The full per-step dump repeats the whole page's chrome every step, so **the driver is quiet by default** — you get the `oe version:` line, explicit `read`s, any `STEP FAILED` state, and a single final snapshot of where you landed; nothing per step. That already handles the common case. The rest is when you need *more* or *less*:

- **Need a mid-journey structural view?** Insert a `{"dump":true}` action at that point — it prints the full buttons/fields/links snapshot even while quiet. A trailing `{"read":…}` counts as your output, so endpoint-proof runs (`goto` an endpoint, then `read "body"`) come back as just the JSON.
- **Need to watch every step** (debugging a flow that fails at an unknown point)? Add `--verbose` (or `-e OE_VERBOSE=1`) to restore a full dump after every step — a 3-step walk is ~3× the output, longer walks more, so reach for it only while diagnosing.
- **Scope `read`s.** `{"read":"body"}` prints up to 2 000 chars; for a form, read a tight selector (`{"read":"#Element_..._event_sub_type"}`) rather than the whole page.
- **Under `--verbose`, grep to what you need:** `… < scripts/journey.mjs --verbose 2>&1 | grep -iE '^url:|^### step|headings:|STEP FAILED|error|view/|required'`. One open Add Event dialog alone dumps ~20 event-type links; the hidden re-auth form `#js-login` and the global nav buttons/links recur on every page — ignore them.

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
OE_ACTIONS: an array of single-key objects — goto/click/press/wait/read take one
string; fill/select/upload take ["<sel>","<value or /file/in/container>"];
selectors are CSS, text="Exact label", or "<sel> >> nth=N".
JSON endpoints: goto the URL then read "body". The driver is quiet by default —
it prints the oe-version line, your explicit reads, any STEP FAILED state, and a
final snapshot of where you land; add a {"dump":true} action wherever you need the
visible buttons/fields/links at that point. Refine OE_ACTIONS between runs; max 4
runs. Never wait for network-idle. Read-only: do not click Save/Delete or upload
unless the goal explicitly says so.

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
