# Node 24.16.0 broke puppeteer's Chrome unzip silently (resolved 24.17.0)

Archived 2026-08-19 - the regression is fixed upstream (24.17.0+ ships the revert; 24.19.0
current) and Web-Live's dockerfile is back on the floating `NODE_MAJOR_VERSION="24"`. Kept
for the pattern: a floating base tag can break a build with no change on our side.

Node.js v24.16.0 (nodejs/node#63487, from the #62557 backport) made puppeteer's postinstall
Chrome unzip die silently: download completes, extraction starts, process exits 0 with a
partial folder and the zip left behind - looks exactly like "puppeteer can't find the
chromium binary". Floating `node:24-*` tags rolled to 24.16.0 around 2026-06-10, breaking
previously-working Web-Live builds; Web-Live was pinned to 24.15.0 until the revert shipped.
The partial cache folder also poisons `npx puppeteer browsers install` retries ("browser
folder exists but the executable is missing") - `rm -rf` the cache dir before retrying.
Web-Dev PROD_DEBUG=TRUE builds re-install puppeteer with the image's own node - same
exposure. OE's `.puppeteerrc.cjs` puts the cache at `protected/runtime/.cache/puppeteer`
and two puppeteers install browsers (root puppeteer and @zoon/puphpeteer's nested one) -
four binaries (chrome + headless-shell, two versions) in the final image is normal.

**If a puppeteer/Chrome build breaks with no diff on our side:** check the base image's
node version first, pin to the last known-good patch, and watch the extractor
(`@puppeteer/browsers` >= 3.0.4 dropped extract-zip, which was the vulnerable path).
