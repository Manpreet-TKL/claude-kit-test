---
name: oe-web-lowercase-rc
description: "toukanlabsdocker/oe-web-live and oe-manager publish RC tags in lowercase (e.g. v26.0.0-rc3, not -RC3); Docker Hub tags are case-sensitive so the uppercase form 404s."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4fa032d4-fe44-4ce5-b660-811da2ca7318
---

When pinning an OE release-candidate tag in `.env` (`OE_WEB_TAG` / `MASTER_TAG`), use the **lowercase** suffix: `v26.0.0-rc3`, not `v26.0.0-RC3`.

**Why:** Docker Hub tags are case-sensitive. `toukanlabsdocker/oe-web-live:v26.0.0-RC3` returns `manifest unknown`; the lowercase `v26.0.0-rc3` resolves. Both `oe-web-live` and `oe-manager` follow the same lowercase convention. The user may write/say "RC3" in conversation - convert to `rc3` when writing into config.

**How to apply:** Any time you set `MASTER_TAG`, `OE_WEB_TAG`, `OE_MANAGER_TAG`, or any other tag from `toukanlabsdocker/*` in oe-deploy `.env` / templates, lowercase the `rc` suffix. After pinning, sanity-check with `docker manifest inspect <image>:<tag>` before running `build.sh` to avoid a full-stack pull abort partway through.

Related: BridgeLink (`innovarhealthcare/bridgelink`) does **not** publish a bare-minor tag like `4.6` - only patch tags (`4.6.0`, `4.6.1`). Pin a patch, not a minor.
