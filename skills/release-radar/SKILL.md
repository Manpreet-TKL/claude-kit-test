---
name: release-radar
description: Sweep tracked platform releases into a dated digest in radar/
disable-model-invocation: false
---

# Release radar

When loaded as context with no task, reply only `Context loaded.`

Sweeps a fixed list of upstream products for releases since the last sweep and writes
one short dated digest into `~/claude-kit/radar/release-radar.md`.

## Procedure

1. Get today with `date +%F`. Read `~/claude-kit/radar/release-radar.md` and take the
   first `## YYYY-MM-DD` heading in it as the last-run date.
2. **Gate.** If the last run is less than a month before today and the invocation did
   not say `force`, print
   `Last swept <date> - under a month, nothing to do (say "force" to override).`
   and stop. No web calls, no file write. `force` as an argument or anywhere in the
   user's message skips this check. An empty file (no `##` heading) is not a gate.
3. Read `subs/sources.md`. For each product in the order listed there, `WebFetch` the
   **primary** URL - always the same page, every run, so successive digests are
   comparable. If it fails, `WebFetch` that product's **fallback** URL from the same
   table. Only if both fail may you `WebSearch`, and then the bullet is tagged
   `[via search]` so the drift is visible.
4. Report against that product's **"what to report"** entry and its **Scope** column -
   `cumulative` products re-list every qualifying feature above the floor each run,
   `since last run` products only report what is new. Nothing qualifying -> a single
   `- no change` bullet. A lookup that fails -> `- lookup failed: <reason>`; products
   are independent, one failure never aborts the sweep.
5. Prepend the run to the file, newest-first, under `## <today>`, with one `###` per
   product in the source-table order. 3-6 one-line bullets each.
6. Print the same digest in chat, then the file path. Do not commit.

## House rules

- **Features, not increments.** Every bullet answers "is this worth my attention?" A
  patch bump with no user-visible change is not a bullet. Never pad a section to fill it.
- **Security is not a category.** No CVE round-ups. A vulnerability earns one line only
  when it is extremely critical - RCE in a default config, or exploited in the wild.
- Bullets are facts with a version and a date, not marketing copy. No speculation
  about unreleased versions, no "coming soon".
- Keep each bullet under ~120 chars. Lead with the version where one applies:
  `12.0 - ...`. One line per feature; do not merge two features into one bullet.
- Open each product with a one-line `Now: <current version>` state line, then the
  feature bullets.
- ASCII only, plain `-` for dashes, no emojis - house style applies to the file too.
- The file only ever grows at the top. Never rewrite or prune an older run.
- Same pages every run. Never substitute a blog post, a vendor summary, a mirror or a
  search result for a product's table URL - a digest is only comparable to the previous
  one if it came from the same source.
- If a source URL has permanently moved, fix it in `subs/sources.md` and say so in the
  run's bullets; do not work around it here.
