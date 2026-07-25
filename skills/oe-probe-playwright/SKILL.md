---
name: oe-probe-playwright
description: Drive a running OpenEyes instance with Playwright when the bundled Puppeteer probe can't run
disable-model-invocation: false
---

# OE probe - Playwright

When loaded as context with no task, reply only `Context loaded.`

Drives a running OpenEyes instance and reports back distilled, quoted labels/steps/state - **run the walk in a cheap subagent**; only the distilled result comes back to the main session. This is the fallback lane: `c-oe-nav`'s in-container Puppeteer probe (`subs/probe.md`, `scripts/journey.mjs`) is the cheaper default for the ~99% of stacks that ship `oe-web-live` (Node/Puppeteer/Chrome already in the image, nothing to install). Reach for this skill instead when:

- The target image has no bundled Puppeteer/Chrome - dev/debug images carry Playwright instead; browserless/remote-chrome stacks have no in-container browser at all.
- A Playwright run is explicitly requested.

**Sample boxes only - never point this at a clinical instance.**

## The driver

`scripts/journey.playwright.mjs`, in `c-oe-nav` at `~/claude-kit/skills/c-oe-nav/scripts/journey.playwright.mjs` (not duplicated here - point at that path). Same action schema, dumps, guardrails and exit codes as the Puppeteer driver; selectors are Playwright's (CSS, `text="Exact label"`, `<sel> >> nth=N`). It imports `playwright`, falling back to `playwright-core`.

Logs in automatically (hidden institution/site inputs) and runs a JSON action list from `OE_ACTIONS` (or piped on stdin as shape 3 below does). Read-only by design: refuses delete-like clicks and dismisses native confirms unless `OE_ALLOW_WRITE=1`. Output is quiet by default - an `oe version:` line, explicit `read`s, any `STEP FAILED` state, and one final snapshot; pass `--verbose` (or `-e OE_VERBOSE=1`) for a full per-step dump while diagnosing an unknown failure point.

Full action schema: `{"goto":"/path"}`, `{"click":"<sel>"}`, `{"fill":["<sel>","<value>"]}`, `{"select":["<sel>","<option value>"]}`, `{"upload":["<sel>","/file/in/container"]}`, `{"press":"Enter"}`, `{"wait":<ms>}`, `{"read":"<sel>"}`, `{"dump":true}`; first action `{"login":false}` skips auto-login.

Env vars: `BASE_URL` (default `http://localhost`, or the app's hostname on its docker network for sidecar shapes), `OE_USERNAME`/`OE_PASSWORD`/`OE_PASSWORD_FILE`, `OE_INSTITUTION_ID`/`OE_SITE_ID` (default 1/1), `OE_SETTLE_MS` (700), `OE_ALLOW_WRITE=1`, `OE_VERBOSE=1`, `OE_CDP_URL` (connect to an existing browser over CDP instead of launching one), `OE_CHROME` (launch a specific Chrome binary). Exit codes: 0 ok, 2 step failed (the dump shows the state at failure), 3 login/infra.

## Three shapes, by what the target has

### 1. Image ships Playwright (dev/debug images)

Exec straight in, exactly like the Puppeteer lane:

```bash
docker exec -i -e OE_ACTIONS='[{"goto":"/patient/summary/17891"},{"click":"#add-event"}]' -w /var/www/openeyes <stack>-web-1 node --input-type=module - < ~/claude-kit/skills/c-oe-nav/scripts/journey.playwright.mjs
```

Check the browser first: `docker exec <ctr> node -e "console.log(require('playwright').chromium.executablePath())"` - if that binary doesn't exist, point `OE_CHROME` at one that does (e.g. a Puppeteer cache Chrome under `protected/runtime/.cache/puppeteer/chrome/...`).

### 2. Existing browser service, no driver in the image (browserless / remote-chrome stacks)

Don't launch - connect: set `OE_CDP_URL` to the chrome service's CDP endpoint (browserless: `ws://chrome:3000`) and run the driver wherever Playwright is available (shape 1 if the image has it, shape 3's sidecar otherwise - the sidecar then needs no browsers of its own). **Installing into the running container happens only on the user's explicit request**, and then the light way: `cd /tmp && npm i --no-save playwright-core` (small, no browser download, reverts on container recreate) and run with `OE_CDP_URL` or `OE_CHROME` - never `playwright install` browser downloads into a container, and sample boxes only.

### 3. Nothing available - throwaway sidecar container

Zero-touch: the official Playwright container joined to the app network (the app answers at `http://web` there, so `BASE_URL` is set explicitly):

```bash
docker run --rm -i --network <app_network> \
  -v /home/toukan/claude-kit/skills/c-oe-nav/scripts:/probe:ro \
  -e BASE_URL=http://web -e PLAYWRIGHT_BROWSERS_PATH=/ms-playwright \
  mcr.microsoft.com/playwright:v1.55.0-noble \
  bash -c 'mkdir -p /j && cp /probe/journey.playwright.mjs /j && cd /j \
    && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm -s i --no-save playwright@1.55.0 \
    && node journey.playwright.mjs -' <<'EOF'
[
  {"goto": "/patient/summary/17891"},
  {"click": "#add-event"}
]
EOF
```

- Network name: `docker inspect <stack>-web-1 --format '{{range $k,$_ := .NetworkSettings.Networks}}{{$k}}{{end}}'`. Creds/institution/site via `-e OE_USERNAME/OE_PASSWORD/OE_INSTITUTION_ID/OE_SITE_ID`.
- Fast path when `~/oe-frontend-tests` exists (skips the ~15s npm install): add `-v /home/toukan/oe-frontend-tests/node_modules:/node_modules:ro` and run `node /probe/journey.playwright.mjs -` directly (mount at `/node_modules` - module resolution walks up from `/probe`; mounting inside the read-only `/probe` fails).
- Screenshots: mount a writable dir (`-v <scratch>:/shots`) and append `--shot /shots`. Files for `upload` actions must be mounted in too.

## Subagent prompt template

Launch with the Agent tool, **model `haiku`** when the journey is known (walk + transcribe), `sonnet` only when the flow itself must be figured out. Paste in the exact `docker exec`/`docker run` command for the target's shape (above) and any known navigation (from `c-oe-nav`'s `subs/paths.md`/`subs/examination.md` if that skill is also loaded, otherwise describe the goal plainly) - the subagent does not load skills:

```
You are probing a running OpenEyes sample instance via Playwright to capture EXACT
frontend labels and steps. This box is disposable sample data (login admin/admin).

Goal: <what to walk and what to bring back>.

Tool: run the command below with Bash. Put the action list in OE_ACTIONS (or on
stdin, per the shape below): an array of single-key objects - goto/click/press/
wait/read take one string; fill/select/upload take ["<sel>","<value or
/file/in/container>"]; selectors are CSS, text="Exact label", or "<sel> >> nth=N".
JSON endpoints: goto the URL then read "body". Quiet by default - it prints the
oe-version line, your explicit reads, any STEP FAILED state, and a final snapshot;
add a {"dump":true} action wherever you need the visible buttons/fields/links at
that point. Refine between runs; max 4 runs. Never wait for network-idle.
Read-only: do not click Save/Delete or upload unless the goal explicitly says so.

<the exact command for the target's shape, container/network/env filled in>

Return ONLY:
1. Numbered user steps with exact quoted UI labels (as a human would follow).
2. The evidence lines from the dumps that show each label (quoted).
3. The OE version line the driver printed.
4. Anything that blocked you.
No transcripts, no screenshots unless asked.
```

## Policies

- Write actions (Save/upload/delete) only on sample boxes, only when the goal demands it, and say so in the result. `OE_ALLOW_WRITE=1` is the explicit switch.
- Stamp what you verified: "labels verified on v11.0.18" - and note when that differs from the PR's Affects version.
- Sample ids, creds, and box/network names never appear in PR text - PRs stay client-agnostic.
