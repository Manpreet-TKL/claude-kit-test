---
name: keep-temp10-synced
description: "Host checkouts under ~/Temp10 (special-module repos like oedocumentation-test) must be kept in sync with their running container proactively, not only when asked."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7f4b956c-11d9-43af-b3d6-bed06c12a1d5
  modified: 2026-08-09T22:53:46.915Z
---

Whenever work changes a special module's content or generated artifacts (e.g.
OeDocumentation's `docs/`, `data/coverage.json`) inside a container (e.g.
`snail-web-1`), keep the host checkout under `~/Temp10/<module>-test` in sync
automatically - do not wait for an explicit "copy this out" request.

**Why:** the user first had to explicitly ask ("Can you copy out the change to
~/Temp10 when done using the ~/copyin.sh script") after a fix was made and
verified in-container, then said "Always keep ~/Temp10 in sync" - turning a
one-off ask into a standing expectation for every session in this tree.

**How to apply:** after any edit that touches a special module's live
container state, sync before considering the task done:
- Container changed (e.g. a generated file like a regenerated
  `coverage.json`) -> pull it back with `bash ~/Temp10/copyin.sh out -m <Module>`
  (safe merge onto host, preserves host `.git`, does not delete host-only
  files; the script is not executable, so invoke via `bash`).
- Host file edited first -> push it into the container too, preferring a
  per-file `docker cp` for surgical changes over `copyin.sh in -m <Module>`,
  since the `in` direction does a full `rm -rf` of the container path before
  mirroring - more sweeping than one edited file needs.
Since 2026-08-09 the sync tooling lives WITH the checkouts: `~/Temp10/copyin.sh`
and `~/Temp10/local_common.php` (moved from `~/`; the user keeps them all in
one place). Beware `copyin.sh out` regressing host files whose staged versions
are newer than the container's copy - after an `out`, check `git status` for
unexpected unstaged diffs and `git restore` any regression, then `docker cp`
the correct file back into the container.
Applies to any `copyin.sh`-managed special module (VoiceControl, AiSearch,
OeMerge, OeConfig, OeDataDictionary, OeDocumentation, NodAudit, OeStats,
OeDatabase, OeDocBuilder), not just OeDocumentation.
