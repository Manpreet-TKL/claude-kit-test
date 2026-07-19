---
name: oe-deploy-conventions
description: oe-deploy workflow - mv (never cp) the template, hosts pre-provisioned, sample DB is admin/admin, lowercase rc image tags
metadata:
  type: feedback
---

Conventions for bringing up Manpreet's oe-deploy instances (merged 2026-07-19 from four correction memories):

- **Rename, don't copy.** `environment-setup.sh` wants a non-`oe-deploy`-named dir: `mv oe-deploy <env>`. The repo is designed as a template - keeping a pristine copy has no value; a `cp -a` attempt was flagged as wrong. Docs should say "rename", not "clone into a new directory".
- **Hosts are pre-provisioned.** Docker registry login, GPG keys, and host bootstrap are done once per host. Never run `host-setup.sh` (invasive: installs packages, edits /etc/ssh, sets timezone), `gpg --gen-key`, `docker login`, or docker-login/GPG verification checks. Go straight from `environment-setup.sh` to `db-setup.sh` and `build.sh`. `host-setup.sh` also overwrites `~/.bash_aliases` and `~/.screenrc` - re-run `~/claude-kit/scripts/screen5_install.sh` after it ([[screen5-term-prompt-gotchas]]).
- **Sample DBs ship admin/admin.** Anything seeded via `oe-reset.sh -nm` + `oe-migrate.sh` logs in with username `admin`, password `admin`. Don't run `set_frontend_passwords.sh` on a demo (it clobbered the working admin password and partially failed on docman) and don't read the OE_ADMIN_PASSWORD secret; reset passwords only on explicit ask. Rows it cannot reset anyway: [[oe-v26-resetuserlock-null-institution]].
- **Lowercase rc tags.** `toukanlabsdocker/oe-web-live` and `oe-manager` publish `v26.0.0-rc3`, never `-RC3` - Docker Hub tags are case-sensitive and the uppercase form returns `manifest unknown`. Convert spoken "RC3" to `rc3` when writing `MASTER_TAG`/`OE_WEB_TAG`/`OE_MANAGER_TAG`, and sanity-check with `docker manifest inspect <image>:<tag>` before `build.sh` to avoid a mid-pull abort. BridgeLink (`innovarhealthcare/bridgelink`) publishes no bare-minor tag like `4.6` - pin a patch (`4.6.1`).

**Why:** every bullet was flagged-wrong feedback mid-task (template cp, re-provisioning checks, demo password reset, -RC3 404).

**How to apply:** the bullets are the checklist; follow them whenever an oe-deploy instance is set up or retagged.
