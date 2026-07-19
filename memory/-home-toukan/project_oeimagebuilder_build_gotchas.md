---
name: oeimagebuilder-build-gotchas
description: OEImageBuilder builds - openeyes repos are private (SSH agent socket + --platform linux/amd64) and node 24.16.0 silently breaks puppeteer Chrome extraction (Web-Live pins 24.15.0)
metadata:
  type: project
---

Two standing gotchas for OEImageBuilder live/manager builds (merged 2026-07-19 from two memories).

## openeyes repos are private - SSH builds only

The `openeyes` GitHub org repos (OpenEyes, eyedraw, ...) are **private**: anonymous smart-HTTP gets 401, web/API get 404. Host-side `git ls-remote` still succeeds only because shells inherit `GIT_ASKPASS` pointing at the VS Code server askpass helper - don't mistake that for public access, and never embed a token in `GIT_REPO_BASE` (it's an ARG in the final image stage). Builds must clone over SSH with `--ssh default=<socket>`. No persistent agent exists on this host; ask Manpreet to run `! eval $(ssh-agent -a /tmp/oe-build.agent) && ssh-add` in-session, then build with `--ssh default=/tmp/oe-build.agent`. Also pass `--platform linux/amd64` - leftover arm64-tagged images (alpine, oe-web-base php8.4-noble-arm64) on this amd64 host cause "exec format error" otherwise.

## Node 24.16.0 puppeteer regression

Node.js v24.16.0 has a stream regression (nodejs/node#63487, caused by the #62557 backport) that makes puppeteer's postinstall Chrome unzip die silently: download completes, extraction starts, process exits 0 with a partial folder and the zip left behind - looks exactly like "puppeteer can't find the chromium binary". Node 24.15.0 and 22.x are fine. Floating `node:24-*` tags rolled to 24.16.0 around 2026-06-10, breaking previously-working Web-Live builds with no change on our side. The partial cache folder also poisons `npx puppeteer browsers install` retries ("browser folder exists but the executable is missing") - `rm -rf` the cache dir before retrying.

Web-Live's dockerfile pins `NODE_MAJOR_VERSION="24.15.0"` (staged 2026-06-11). Unpin to "24" once Node 24.17.0 ships the revert (nodejs/node#63834), or once OpenEyes' puppeteer resolves `@puppeteer/browsers` >= 3.0.4 (which dropped extract-zip; OE's `puppeteer ^24.6.0` still resolves 24.43.1 = broken extractor). Watch out: Web-Dev PROD_DEBUG=TRUE builds re-install puppeteer with the image's own node - same bug if that node is 24.16. OE's `.puppeteerrc.cjs` puts the cache at `protected/runtime/.cache/puppeteer` (inside WROOT) and two puppeteers install browsers (root puppeteer -> Chrome 148.x, @zoon/puphpeteer's nested one -> 144.x) - four binaries (chrome + headless-shell, two versions) in the final image is normal.
