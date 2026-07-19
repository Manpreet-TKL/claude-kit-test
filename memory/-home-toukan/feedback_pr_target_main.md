---
name: pr-target-main
description: "create-pr (non-OE) diffs cut against the repo's mainline (main on newer repos, master on older) unless Manpreet names another base; OE repos follow create-oe-pr's develop/release rules"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1a93f437-6cb5-4114-be35-1b9094a3eef1
  modified: 2026-07-19T11:50:55.635Z
---

Non-OE PRs (create-pr folders) always target the repo's mainline as the base branch unless Manpreet explicitly names a different one: `main` on newer repos (e.g. oe-deploy), `master` on older ones - check which exists. OE PRs (create-oe-pr) are the exception: openeyes, IOLMasterImport, and PayloadProcessor all have `master` branches, but PR bases follow the create-oe-pr skill (`develop` / `release/Y.Z.x`, or `master` as default for the two satellites).

**Why:** Stated 19/07/2026 while re-cutting a gitsecret-perms PR; local checkouts often sit on long-lived feature branches, but the PR base is the mainline regardless of what the working copy has checked out. Refined the same day: only newer repos have `main`, and OE targeting rules live in the create-oe-pr skill.

**How to apply:** Resolve `origin/main` (or `origin/master` on older repos) for the `Apply onto` line and cut `changes.patch` from a clean throwaway worktree/clone at that ref when the live checkout is busy on another branch. For the three OE repos, follow the create-oe-pr skill's base-branch section instead.
