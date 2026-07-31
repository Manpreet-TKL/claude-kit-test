---
name: c-pr-explainer
description: Turn a finished PR folder into a plain-language explainer .md for non-programmers
disable-model-invocation: false
---

# PR explainer

When loaded as context with no task, reply only `Context loaded.`

Turns a finished PR folder (`~/pullrequests/<folder>/` with `PR.md` +
`changes.patch`) into a standalone plain-language explainer for a reader with
**no knowledge of the codebase or the implementation language** - a manager,
clinician, or reviewer-from-afar who wants to understand what changed, why it
is safe, and what was considered. Model example (structure and register):
`~/oe-pr-eventmeduse-memoize-chain-explainer.md`.

## The deliverable

One file: `/home/toukan/<pr-folder-name>-explainer.md` - under the home
directory, never inside a repo working tree and never inside the PR folder.
Title line: `# <slug> PR: plain-language explainer`, where `<slug>` is the
folder name minus its repo prefix (`oe-pr-`, `oe-iol-pr-`, ...).

## The golden rule: verify, then write

Every factual claim - which screens use the code, who calls the changed
routine, what the old and new behaviour is - is re-checked against the patch
and a **fresh** grep/run on the current tree before it is written down, never
recalled from memory. The preamble states the verification basis explicitly
(what was re-run, against which branch @ sha). If a claim cannot be cheaply
verified, it is either dropped or written as an open question in the caveats -
never asserted.

## Voice

- Plain words; every mechanism gets one concrete analogy (sticky notes, paper
  trail, proofreader). No jargon a lay reader could not follow; any term of
  art used is explained on first use.
- Honest, not promotional: caveats get their own section and real content;
  equivalence claims ("no question is answered differently") appear only when
  actually proven above.
- Choices as numbered lists, comparisons as tables (house rules); ASCII only;
  commands on one line; no Claude mentions; no test-environment names;
  client-agnostic (actors by role, data by kind).

## Section blueprint

Fixed core, in this order - keep every section, scale depth to the PR's
weight (a one-file bugfix earns a shorter file than a campaign headliner):

1. Preamble (no heading): which folder + commit title it covers, the intended
   reader, the verification basis.
2. `## What the page is doing, in plain words` - the domain story: what the
   user sees and does, how the mechanism behind it works, and the problem -
   told so the change follows naturally from it.
3. `## What the change actually does - N small ideas` - numbered ideas, one
   plain paragraph each; end with what does NOT change.
4. `## Reading the code itself - a glossary for non-programmers` - every
   symbol/keyword the reader will meet in the quoted code, in order of first
   appearance, one line each (include removed-line symbols when the diff is
   quoted); then quote the heart of the patch - a few lines, never the whole
   diff - and translate it into words.
5. `## Blast radius` - files changed; an exhaustive consumer/caller sweep
   presented as a table (thing changed -> every caller -> screen it serves),
   stated as repo-wide grep, not a sample; classify read vs write paths.
6. `## Why this cannot affect other features` - bullets arguing from
   mechanism, not assertion: what the change is structurally unable to do,
   equivalence of preserved behaviour, lifetime/visibility of any state,
   exhaustiveness of the sweep, evidence it was exercised.
7. `## Honest caveats` - numbered; carries the PR.md reviewer notes plus
   anything else a reviewer deserves to know. Never padded and never empty -
   if there is truly nothing, say why the confidence is earned.
8. `## Alternatives considered` - numbered options with trade-offs narrated,
   then a comparison table; honest about options that shipped as sibling PRs
   or remain as follow-ups.

Optional extras after the core, chosen by PR type - each must be hands-on (a
runnable command, query, or observable check), never filler: perf PR ->
high-concurrency considerations + a find-the-worst-affected-data query; UI
bugfix -> a seeing-it-for-yourself before/after and/or a self-contained
snippet demoing old vs new behaviour; migration/data PR -> rollback story and
row-count sanity checks.

## Process

1. Read `PR.md` and `changes.patch` in full; read the touched files as they
   stand on the current tree.
2. Verify: fresh greps for every consumer/caller table row; re-run any cheap
   simulation of old vs new behaviour (in a container); note the ref + sha.
3. Write the file; check it renders as plain ASCII markdown.
4. Report the path; the explainer is a home-directory document - do not add
   it to the PR folder, the pullrequests index, or any repo.
