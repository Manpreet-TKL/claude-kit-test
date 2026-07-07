# Fallback probe - Playwright

Load this **only** when the standard in-container Puppeteer lane (`subs/probe.md`) can't run - the image has no bundled Puppeteer/Chrome - or the user explicitly asks for a Playwright run. Driver: `scripts/journey.playwright.mjs` - same action schema, dumps, guardrails and exit codes as the Puppeteer driver; selectors are Playwright's (CSS, `text="Exact label"`, `>> nth=N` native). Extra env: `OE_ACTIONS` (action list when the script is piped on stdin), `OE_CDP_URL` (connect to an existing browser over CDP instead of launching), `OE_CHROME` (launch a specific Chrome binary). It imports `playwright`, falling back to `playwright-core`.

Three shapes, by what the target has:

## 1. Image ships Playwright (dev/debug images)

Exec straight in, exactly like the Puppeteer lane:

```bash
docker exec -i -e OE_ACTIONS='[{"goto":"/patient/summary/17891"},{"click":"#add-event"}]' \
  -w /var/www/openeyes <stack>-web-1 node --input-type=module - < scripts/journey.playwright.mjs
```

`BASE_URL` defaults to `http://localhost`. Check the browser first: `docker exec <ctr> node -e "console.log(require('playwright').chromium.executablePath())"` - if that binary doesn't exist, point `OE_CHROME` at one that does (e.g. a Puppeteer cache Chrome under `protected/runtime/.cache/puppeteer/chrome/...`).

## 2. Existing browser service, no driver in the image (browserless / remote-chrome stacks)

Don't launch - connect: set `OE_CDP_URL` to the chrome service's CDP endpoint (browserless: `ws://chrome:3000`) and run the driver wherever Playwright is available (shape 1 if the image has it, shape 3's sidecar otherwise - the sidecar then needs no browsers of its own). **Installing into the running container happens only on the user's explicit request**, and then the light way: `cd /tmp && npm i --no-save playwright-core` (small, no browser download, reverts on container recreate) and run with `OE_CDP_URL` or `OE_CHROME` - never `playwright install` browser downloads into a container, and sample boxes only.

## 3. Nothing available - throwaway sidecar container

Zero-touch: the official Playwright container joined to the app network (the app answers at `http://web` there, so `BASE_URL` is set explicitly):

```bash
docker run --rm -i --network snail_backend \
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

Everything else - when to probe, endpoints-for-proof, the subagent template, and the policies - is in `subs/probe.md`; only the run command and driver file differ.
