---
name: oeimagebuilder-build-gotchas
description: OEImageBuilder live/manager builds - openeyes repos are private (in-session ssh-agent socket + --ssh default=/tmp/oe-build.agent) and pass --platform linux/amd64 to dodge leftover arm64 base images
metadata:
  type: project
---

The `openeyes` GitHub org repos (OpenEyes, eyedraw, ...) are **private**: anonymous
smart-HTTP gets 401, web/API get 404. Host-side `git ls-remote` still succeeds only because
shells inherit `GIT_ASKPASS` pointing at the VS Code server askpass helper - don't mistake
that for public access, and never embed a token in `GIT_REPO_BASE` (it's an ARG in the final
image stage). Builds must clone over SSH with `--ssh default=<socket>`. No persistent agent
exists on this host; ask Manpreet to run `! eval $(ssh-agent -a /tmp/oe-build.agent) && ssh-add`
in-session, then build with `--ssh default=/tmp/oe-build.agent`. Also pass
`--platform linux/amd64` - leftover arm64-tagged images (alpine, oe-web-base
php8.4-noble-arm64) on this amd64 host cause "exec format error" otherwise.

The Node 24.16.0 puppeteer-unzip regression that forced a 24.15.0 pin is resolved
(24.17.0+; Web-Live back on floating "24") - pattern archived at
`~/claude-kit/knowledge/oeimagebuilder-node-puppeteer-regression.md`.
