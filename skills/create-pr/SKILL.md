---
name: create-pr
description: Prepare a pull request for one isolated change. Audits the working tree, isolates the change being shipped (separating it from unrelated edits), and writes a `pr-<slug>.md` artifact covering problem → fix → file-by-file changes → how to raise the PR. Stops at staging; never commits, never pushes. Invoke explicitly when the user says "create a PR", "write up this PR", "prep this for review", or hands you a branch they want to ship. Does NOT trigger on plain "commit this" or mid-feature work-in-progress saves.
disable-model-invocation: true
---

# Create-PR playbook

A PR is a contract with the reviewer: *one change, clearly motivated, easy to verify*. This skill enforces a five-step shape: **survey → isolate → describe → stage → hand off**.

The hard rule: **never `git commit`, never `git push`, never `--no-verify`.** Output a `.md` artifact and a staged diff; the human raises the PR.

## 1. Survey the working tree

Run, in parallel:

```bash
git status
git diff --stat
git diff
git log --oneline -10
git branch --show-current
git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "no upstream"
```

You need to know:

- **Branch:** is the user on a feature branch or on `main` / `master` / `develop`?
- **Base:** what does this branch diverge from? Use `git merge-base HEAD <base>` if ambiguous.
- **Working-tree state:** uncommitted edits, untracked files, staged-but-uncommitted things.
- **Already-committed changes** on this branch since the base.

If the branch is `main` / `master` / `develop`, **stop and tell the user** — they need to create a feature branch first. Do not silently create one for them.

## 2. Isolate the change

Most working trees are noisy. Before writing anything, separate **the change being shipped** from everything else.

Categorise every changed file into one of:

| Bucket             | What it means                                                       | What happens |
|---                 |---                                                                  |---           |
| `core`             | Files that implement the change being shipped.                      | Goes in the PR. |
| `incidental`       | Generated files, lockfile bumps, formatting tied to the core edits. | Goes in the PR, called out as incidental in the writeup. |
| `unrelated`        | Edits from another task, half-finished work, debug prints.          | **Excluded.** Tell the user and leave them in the working tree. |
| `accidental`       | Files the user clearly didn't mean to touch (whitespace-only churn, IDE config). | **Excluded.** Suggest `git restore <path>` after confirming with the user. |

Show the user this triage as a single message and **ask for confirmation** before staging. The cost of bundling an unrelated edit into the PR is a confused reviewer; the cost of asking is one click.

If the change is genuinely *not* isolatable (e.g. two interleaved refactors), say so plainly and recommend splitting the work across two branches rather than one fat PR.

## 3. Describe — write the `pr-<slug>.md` artifact

Write a single file at the repo root: `pr-<slug>.md`, where `<slug>` is a 3–5 word kebab-case summary derived from the change (e.g. `pr-fix-archive-button-race.md`). If the user has a ticket reference, prefer that: `pr-ENG-1421-archive-race.md`.

Structure:

```markdown
# <Title> — short, imperative, under 70 chars

## Problem

What was wrong / what's missing? 2–4 sentences. Lead with the user-visible symptom or the
concrete gap, not the implementation detail. If there's a ticket / issue / incident link,
put it here.

## Fix

What this PR does, in plain language. 2–4 sentences. Name the approach, not the diff.
Mention the *one* judgement call that mattered — why this approach over the obvious alternative.

## Changes

File-by-file. One bullet per file, with the why (not just the what):

- `path/to/file.ext` — <what changed, and why this change>
- `path/to/other.ext` — <what changed, and why this change>
- (incidental) `package-lock.json` — regenerated alongside the dependency bump.

If a file's diff is large, summarise the **shape** of the edit ("extracted the retry loop into
`withRetry()`; call sites updated"). Don't paste hunks.

## How to verify

A reviewer should be able to run something concrete. One of:

- A test name and the command to run it.
- A manual click-through ("log in → click Archive → row disappears from default list").
- A `curl` invocation and the expected response.

If there's no way to verify, **say so** and justify why ("doc-only change, see rendered preview").

## How to raise the PR

Plain `git` / `gh` commands the user will run. Example:

    git commit -m "<title from above>"
    git push -u origin <branch>
    gh pr create --base <base> --title "<title>" --body-file pr-<slug>.md

Do not run these yourself. They go in the artifact so the user can copy-paste.

## Notes for the reviewer

Anything that would save the reviewer a question: known limitations, follow-up work
explicitly deferred, areas you'd like extra eyes on. Skip the section if there's nothing.
```

Keep the whole file under ~80 lines unless the change really needs more. A long writeup for a small change is a red flag — usually it means the change isn't as isolated as you thought.

## 4. Stage — don't commit

```bash
git add <core files...>
git add <incidental files...>
git add pr-<slug>.md
git diff --staged --stat
git diff --staged
```

Then **stop.** Show the user:

- The staged file list (`git diff --staged --stat`).
- A pointer to `pr-<slug>.md`.
- The exact commands from the artifact's "How to raise the PR" section, ready to copy.

Never run `git commit`. Never run `git push`. Never use `--no-verify`. If the user explicitly asks you to commit, follow your standing instructions on that — this skill does not override them.

## 5. Hand off

End with one line of the form:

> Staged on `<branch>` (base `<base>`): N files + `pr-<slug>.md`. Run the three commands at the bottom of the artifact to raise the PR.

That's it.

## When to invoke this skill

| Trigger | Yes / No |
|---|---|
| "Create a PR for this change" | **yes** |
| "Write up this PR" | **yes** |
| "Help me prep this for review" | **yes** |
| "Commit this" | no — this skill doesn't commit |
| "What's the diff?" | no — just run `git diff` |
| "Working on feature X" (mid-flow) | no — this is for shipping, not in-progress saves |

The skill is `disable-model-invocation: true` — Claude will not auto-load it. Invoke by name when you genuinely want a PR artifact produced.

## What this skill is **not**

- Not a substitute for the user reading their own diff. The artifact is a reviewer's aid, not a green light to skip review.
- Not a commit / push tool. The handoff stops at `git add`. That boundary is deliberate.
- Not for OpenEyes PRs — those have a different shape (release-notes title, repro steps, OE version, coding-standards link). Use [[create-oe-pr]] instead.
- Not for multi-change branches. If the branch contains two unrelated changes, the right move is to split the branch, not to write one PR that does both.
