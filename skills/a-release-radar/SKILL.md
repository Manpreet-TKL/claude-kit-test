---
name: a-release-radar
description: Track relevant upstream releases in continuous, sourced product sections in radar/
disable-model-invocation: false
---

# Release radar

When loaded as context with no task, reply only `Context loaded.`

Maintain `~/claude-kit/radar/release-radar.md` as a decision aid for OpenEyes
deployment and daily tooling. Read `subs/sources.md` for products, floors, official
sources and relevance tests. Read `skills/c-oe-deploy/subs/versions.md` when an
upgrade comparison depends on deployed versions.

## Procedure

1. Get today's local date with `date +%F`. Read `Last attempted` in the live file.
   Unless the invocation says `force`, stop without web calls or writes if that date
   is less than one calendar month ago. Say when it was attempted and how to force.
   A missing date never gates a run.
2. For every product, start at its `Verified through` watermark, or its initial
   floor if none exists. Enumerate dated releases through today from the official
   discovery source. Open the direct release note, migration guide or announcement
   for each candidate. Use another official index or search only to recover a
   missing page; cite the final direct source. Do not infer a feature or date from
   a version list, search snippet, undated page or another vendor's summary.
3. Check the product brief. Prefer upgrade breaks, removals, support deadlines,
   cost and concrete workflow improvements. Keep up to about ten highest-value
   entries per product, with no filler. A selected entry needs an announcement or
   release date, affected version if applicable, what changed, why it matters to
   OpenEyes or the stated workflow, and a direct official link. Say `Possible` or
   `Test` when the operational effect is an inference; never claim a speedup
   without a benchmark. Group related changes in one entry only when their
   upgrade action is the same. The requested one-time historical Compose
   inventory may use its review date if the capability predates the floor;
   label it `Historical`, not a new release.
4. For AWS and GCP, verify each feature in London (`eu-west-2` and
   `europe-west2`). If an important feature is announced but London availability
   cannot be confirmed from official regional documentation, keep it in a
   clearly marked `London unverified` line, with the check still pending. Do not
   present global availability as proof of London availability.
5. Update the existing product section in place. Put newer entries above older
   entries within that section; do not repeat an unchanged entry. Preserve its
   relevant older entries, combine duplicates, and remove an item only when it
   is disproved, superseded or archived. Count verified selected entries and
   pending checks in the section. Record `Checked on` and the exact interval
   examined. Advance `Verified through` only when the official dated source
   series covers the whole interval; otherwise leave it unchanged and explain
   the source gap. An empty interval is valid if checked completely. Source
   failures for one product never stop others. Recalculate the top-level
   selected-entry and pending-check totals from the product counts.
6. Set top-level `Last attempted` to today. When the live file exceeds about 600
   lines, move the oldest complete calendar months whose month-end is more than
   six months old into `radar/release-radar-YYYY.md`, preserving entries and
   source links under the same product headings. Never split a month or archive
   an unresolved pending check or active warning. If nothing qualifies, let
   the live file exceed 600 lines and say why. Keep
   `release-radar-legacy-2026.md` unchanged.
7. Report only additions, changes, source gaps and archive moves in chat, with
   the live file path. Do not commit.

## Entry and quality rules

- Use continuous `## Product` sections in source-table order, not a new section
  for each run. A run is a check event; it is not the document structure.
- Mark deprecations, removals, support end and required migration work before
  optional features. Retain active warnings until resolved or out of scope.
- No generic release summaries, patch bumps, routine CVEs, marketing claims,
  `no change` bullets or speculative unreleased features. Security qualifies
  only for a default-config RCE or known exploitation.
- Keep the live file and new prose ASCII. Link directly to the official page
  that supports each material claim. A broad releases index is discovery, not
  evidence for a feature. If sources disagree, mark the item pending.
- Do not silently treat a partially read series as swept. Make coverage limits
  and counts visible so the next run knows where to resume.
