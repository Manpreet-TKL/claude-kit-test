---
name: openeyes-repos-private-ssh-build
description: "openeyes GitHub org repos are private; docker builds need an ssh-agent socket, host git only works via VS Code askpass"
metadata: 
  node_type: memory
  type: project
  originSessionId: b121674c-328b-40bb-a7b1-c471f12b2219
---

The `openeyes` GitHub org repos (OpenEyes, eyedraw, ...) are **private**: anonymous smart-HTTP gets 401, web/API get 404. Host-side `git ls-remote` still succeeds because shells inherit `GIT_ASKPASS` pointing at the VS Code server askpass helper — do not mistake that for public access, and never embed a token in `GIT_REPO_BASE` (it's an ARG in the final image stage).

**How to apply:** OEImageBuilder live/manager builds must clone over SSH with `--ssh default=<socket>`. No persistent agent exists on this host; ask Manpreet to run `! eval $(ssh-agent -a /tmp/oe-build.agent) && ssh-add` in-session, then build with `--ssh default=/tmp/oe-build.agent`. Also pass `--platform linux/amd64` — leftover arm64-tagged images (alpine, oe-web-base php8.4-noble-arm64) on this amd64 host cause "exec format error" otherwise. Related: [[node-2416-puppeteer-regression]]
