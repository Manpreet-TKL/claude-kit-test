---
name: reference_oe_render_testing_gotchas
description: "Testing OE document/PDF renders on sample containers: yiic eventimage fails silently (docman auth) - drive renders via a direct admin web session; a relocated Puppeteer temporaryDirectory must be mkdir'd in .puppeteerrc.cjs or every render 500s"
metadata:
  type: reference
---

Merged 2026-08-19 from two memories out of the same /tmp-leak PR work (now `~/claude-kit/knowledge/oe-tmp-file-origins.md`).

## yiic eventimage cannot drive renders on sample containers

`createImageForEvent` curls `/{module}/default/createImage/{id}` server-side with **docman**
creds, which fail on sample web containers (e.g. `snail-web-1`): the cookie jar is still
written (a cookie-jar leak still reproduces) but the render never runs, the command does not
check the curl HTTP code and prints "Successfully created EventImages" anyway, and it
**deletes** existing `event_image` rows first - silently wiping preview caches.

**How to apply:** authenticate a direct web session with `admin`/`admin` PLUS
`LoginForm[institution_id]` and `LoginForm[site_id]` (1/1 on the sample; CSRF is
cookie-backed so the hidden token may be empty), then `GET /{module}/default/createImage/{id}`
(or `/PDFprint/{id}`) yourself and diff `/tmp` before/after. `event_image` is a regenerable
cache, not clinical data. Document-leak paths (OphCoDocument imagick/ghostscript/pdf-preview)
need an OphCoDocument event **with a file attachment** - the seeded sample DB has none.

## Puppeteer temporaryDirectory needs pre-creating

Setting `temporaryDirectory` in `.puppeteerrc.cjs` (e.g. moving `puppeteer_dev_chrome_profile-*`
out of `/tmp` into `protected/runtime/.cache/puppeteer/tmp`) without creating the dir makes
**every** PDF/image render die with `ENOENT: mkdtemp ...` -> HTTP 500: `fs.mkdtemp()` does not
create parents, and Puppeteer's browser-fetch creates `cacheDirectory` but never a `tmp` under
it. Create it in the rc itself (evaluated before any launch, by the rendering user):
```js
const { mkdirSync } = require('fs');
const temporaryDirectory = join(__dirname, 'protected','runtime','.cache','puppeteer','tmp');
mkdirSync(temporaryDirectory, { recursive: true });
```
Static checks (`php -l`, `git apply --check`) all pass - it is a Node runtime failure.
Related: [[monkey-environment]].
