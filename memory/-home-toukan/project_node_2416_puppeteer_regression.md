---
name: node-2416-puppeteer-regression
description: Node 24.16.0 silently breaks puppeteer Chrome extraction; OEImageBuilder live builds pin node 24.15.0
metadata: 
  node_type: memory
  type: project
  originSessionId: b121674c-328b-40bb-a7b1-c471f12b2219
---

Node.js v24.16.0 has a stream regression (nodejs/node#63487, caused by #62557 backport) that makes puppeteer's postinstall Chrome unzip die silently: download completes, extraction starts, process exits 0 with a partial folder and the zip left behind. Looks exactly like "puppeteer silently failing to find the chromium binary". Node 24.15.0 and 22.x are fine.

**Why:** floating `node:24-*` tags rolled to 24.16.0 around 2026-06-10, breaking previously-working OEImageBuilder Web-Live builds with no change on our side. The partial cache folder also poisons `npx puppeteer browsers install` retries ("browser folder exists but the executable is missing") — `rm -rf` the cache dir before retrying.

**How to apply:** Web-Live dockerfile pins `NODE_MAJOR_VERSION="24.15.0"` (diagnosed + staged 2026-06-11). Unpin to "24" once Node 24.17.0 ships the revert (nodejs/node#63834), or once OpenEyes' puppeteer resolves `@puppeteer/browsers` >= 3.0.4 (which dropped extract-zip; OE's `puppeteer ^24.6.0` still resolves 24.43.1 = broken extractor). Watch out: Web-Dev PROD_DEBUG=TRUE builds re-install puppeteer with the image's own node — same bug applies if that node is 24.16. OE's `.puppeteerrc.cjs` puts the cache at `protected/runtime/.cache/puppeteer` (inside WROOT) and two puppeteers install browsers (root puppeteer -> Chrome 148.x, @zoon/puphpeteer's nested one -> 144.x); four binaries (chrome + headless-shell, two versions) in the final image is normal. Related: [[openeyes-repos-private-ssh-build]]
