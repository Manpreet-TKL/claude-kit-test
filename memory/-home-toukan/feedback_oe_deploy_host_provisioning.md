---
name: oe-deploy host pre-provisioning
description: Manpreet's oe-deploy hosts already have Docker login, GPG keys, and host bootstrap done — don't re-run host-setup.sh or check those.
type: feedback
originSessionId: 596431f6-e7a0-484f-a3d6-6dd01fd7636a
---
On Manpreet's oe-deploy hosts, Docker registry login and GPG keys are pre-provisioned. Don't run `gpg --gen-key`, `docker login`, `docker info | grep Username`, or `host-setup.sh` to verify or set them up.

**Why:** He flagged this as wasted work mid-task — these are done once per host and re-running them risks destroying state (`host-setup.sh` is invasive: installs packages, edits `/etc/ssh`, sets timezone, etc.).

**How to apply:** When bringing up an `oe-deploy` instance, skip `host-setup.sh` if Docker and `mariadb` client are already on the host. Skip docker-login / GPG-key checks entirely. Go straight from `environment-setup.sh` (or its precondition: a non-`oe-deploy`-named working directory) to `db-setup.sh` and `build.sh`.
