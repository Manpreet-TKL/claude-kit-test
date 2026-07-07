---
name: monkey-remote-chrome
description: monkey renders PDFs/images via plain HTTP to a browserless chrome container (no node/puppeteer in app containers); compose commands must use -f docker-compose.yml; docman_user fixed 2026-06-09
metadata: 
  node_type: memory
  type: project
  originSessionId: c5aa4d89-91f1-4e31-ac53-065c8c9fb6f1
---

Since 2026-06-09 monkey's OpenEyes renders PDFs/lightning images with **zero node or chrome in the app containers**: a rewritten `DocumentRenderServicePuppeteer.php` (bind-mounted read-only from `/home/toukan/monkey/patches/`) curls browserless's `/function` API on the `chrome` service (ghcr.io/browserless/chromium:v2.33.0, token in docker-compose.yml, cpus 2 / mem 3g ring-fence). The puppeteer node packages and bundled Chrome were deleted from both running containers' writable layers. Full docs: `/home/toukan/monkey/remote-chrome.md`. Since 2026-06-10 the patch is the **unified dual-mode class**, byte-identical to `~/pullrequests/oe-pr-remote-puppeteer-browser/files/.../DocumentRenderServicePuppeteer.php`: upstream local launch() when `PUPPETEER_BROWSER_WS_ENDPOINT` is unset, remote HTTP when set, actionable exception when neither browser exists. Companion: `~/pullrequests/oeimagebuilder-pr-chromeless-web/` (PUPPETEER_SKIP_DOWNLOAD chrome-less images + docs/REMOTE_BROWSER_K8S.md).

**Why:** Constraints that shape any change here: (1) always `docker compose -f docker-compose.yml ...` - the pre-existing override.yml is a dev-image swap that would drop the patch mount; (2) the in-container deletions revert on container *recreate* (restart preserves them) - re-delete if the tripwire is wanted; (3) editing the host patch with inode-replacing tools doesn't propagate - restart web/oe-manager after edits; (4) the class has a local fallback but monkey's containers can't use it (node packages deleted): chrome down => prints fail loudly; (5) oe-manager's Apache is `Require local`, so its `PUPPETEER_BASE_URL` is `http://web/`.

**How to apply:** On any image tag bump, re-diff the patch against the new image's file. For print tests use event 3687000 (3686997 has no ElementLetter row and 500s in `getRecipients()` - pre-existing data quirk, not a regression). `docman_user` was fixed 2026-06-09 (see [[oe-v26-resetuserlock-null-institution]]) and the lightning-image chain works end-to-end. Related: [[oe-monkey-traefik-http-only]].
