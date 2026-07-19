---
name: reference_oe_puppeteer_temporarydirectory_mkdtemp
description: "Relocating Puppeteer's temporaryDirectory in .puppeteerrc.cjs requires pre-creating the dir, else every OE render 500s"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 07be89dc-286d-4f20-a4b0-9874e2333c4c
---

If you set `temporaryDirectory` in OpenEyes `.puppeteerrc.cjs` (e.g. to move the
`puppeteer_dev_chrome_profile-*` user-data dir out of `/tmp` into
`protected/runtime/.cache/puppeteer/tmp`), you MUST create that directory or **every**
PDF/image render dies with `ENOENT: mkdtemp '.../tmp/puppeteer_dev_chrome...'` -> HTTP 500, no
output. Node's `fs.mkdtemp()` (used by Puppeteer for the profile dir) does **not** create
intermediate directories.

**Why:** `cacheDirectory` is created by Puppeteer's browser-fetch, but a `tmp` subdir under it
is never created; `mkdtemp(prefix)` needs `prefix`'s parent to already exist.

**How to apply:** create it in the rc itself (plain JS, evaluated before any browser launch,
created by the rendering user so ownership is right):
```js
const { mkdirSync } = require('fs');
const temporaryDirectory = join(__dirname, 'protected','runtime','.cache','puppeteer','tmp');
mkdirSync(temporaryDirectory, { recursive: true });  // idempotent
```
This bit the reconstructed `oe-pr-tmp-puppeteer-chromium-leak` PR; static checks (`php -l`,
`git apply --check`) all pass because it's a Node runtime failure. See `~/oe-tmpfix-notes.md`.
Related: [[monkey-environment]].
