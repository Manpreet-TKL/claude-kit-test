# Bulk Jira corpus download + triage (2026-07, TKLS)

Downloading a Jira filter's whole corpus to disk and triaging it. Written after
a 106-ticket run that worked but wasted a lot of tokens doing by-model what a
bash script and cheap agents should have done. The lesson is the pipeline shape,
not the ticket content.

## The rule: download cheap, reduce cheap, orchestrate thin

A corpus job is download -> reduce -> collate. Ticket text should cross an
expensive model's context ZERO times. The efficient split:

1. **Download with a bash/REST script - zero model tokens.**
   `~/claude-kit/scripts/jira_filter_download.sh` pulls the filter to disk:
   `keys.txt`, full issue JSON with all comments, and `-a` for attachment
   binaries. Runs in minutes; the model never sees a byte of it.
2. **Reduce with the CHEAPEST agent that can judge - a map step.** Fan out one
   small agent per ticket (or per few) that reads `issues/<key>.json` from disk
   and writes a compact structured summary to `analysis/<key>.json`. This is
   Haiku's job (or codex `luna`/`terra`) - "read a ticket, classify it, extract
   a few fields" needs no flagship reasoning. Each agent's context holds one
   ticket and emits a few hundred bytes.
3. **Collate deterministically - zero model tokens.** A stdlib Python script
   merges the per-ticket summaries into the final CSV/report. No model reads the
   corpus to aggregate it.
4. **Orchestrator (Claude) does very little.** Spawns the waves, runs the
   collation script, spot-checks a handful of tickets by hand, writes the final
   narrative from the *collated* numbers. It never ingests the corpus.

The map-reduce is the point: N cheap agents each shorten one ticket, then a
script (not a model) reduces N summaries to one answer.

## What went wrong the first time (do not repeat)

- **Fetched issues via Claude subagents over MCP and transcribed to disk.**
  ~565k tokens and 35 min for 3.3 MB of bodies, because every payload crossed
  model context twice (tool result + Write). The bash script did the same
  bodies AND 909 MB of attachments in 221 s at zero tokens. See
  [[bulk-jira-download-bash-not-mcp]] (auto-memory).
- **Ran the whole reduce step on codex `gpt-5.6-sol` at `xhigh`.** Flagship, max
  effort, 40 billable runs - for "read a support ticket and tag it devops vs
  bug". Overkill. A Haiku fan-out (or codex `luna`) does this at a fraction of
  the cost. Match the model to the task; reserve sol/xhigh for genuinely
  ambiguous reasoning, not classification.
- **Passing ticket bodies through the orchestrator to summarise.** Never. The
  orchestrator works off the collated JSON/CSV the map step produced.

## jira_filter_download.sh - what it handles

Usage: `./jira_filter_download.sh -f 19720 -a` or
`./jira_filter_download.sh -j '<jql>' -o /path`. Sources
`generated/.atlassian.env` (classic unscoped token - scoped tokens 401 at the
site URL). It bakes in the REST-path gotchas so callers do not rediscover them:

- Enhanced search (`/rest/api/3/search/jql`) returns `total: -1`; the only count
  is walking pages to exhaustion.
- Pagination is `nextPageToken` only; `startAt` is ignored. REST accepts 100/page
  (the MCP server caps at 50).
- The inline comment block on an issue is one page; tickets with more comments
  are topped up from the `/comment` endpoint and merged.
- `-a` downloads attachments from their content URLs with `curl -L` (they
  redirect to signed media hosts). Filenames are prefixed with the attachment id
  because Jira allows duplicate filenames on one ticket. This sidesteps the MCP
  `jira_download_attachments` path entirely, which returns base64 inline
  (~250k tokens/MB - impossible for big attachments; one ticket here carried
  ~570 MB).

Raw REST differs from the MCP server in two ways worth knowing: the MCP server
rewrites JQL, appending `AND (project IN (...))` from `JIRA_PROJECTS_FILTER`, and
obfuscates emails ("sami dot khan at ..."). Raw REST does neither.

## Feasibility pitfalls for a full-TKLS export (~9,900 tickets)

- **Filter drift mid-export.** A ticket closed 3 min after the key snapshot, so
  a second pass saw 105 not 106. Snapshot `keys.txt` first, drive every later
  stage off the snapshot, top up drifted issues individually.
- **Model transcription corrupts data** - one issue was written with an invalid
  `\*` JSON escape. Never let a model retype a payload a pipe could carry;
  jq-validate every file.
- Disk is a non-issue (attachments dominate - budget ~9 MB/ticket here). Expect
  429s at scale; `curl --retry N` honours Retry-After.
- Verdict: full export is viable at ~half a day, bandwidth-bound, near-zero
  tokens via the script; NOT viable via MCP subagents (~53M tokens, ~2 days).

## Running the reduce step on codex in the kit container

If the reducer is codex (not Haiku), two container gotchas bite every run - full
detail in [[codex-docker-swarm-gotchas]] (auto-memory) and
`knowledge/codex-compatibility.md`:

1. Pass `sandbox: "danger-full-access"` per call - codex cannot nest its bwrap
   sandbox inside the container, which is already the boundary.
2. Agents inherit `~/.codex/AGENTS.md` (symlinked to the kit CLAUDE.md) and
   `~/.codex/skills/`, so on Jira work they invoke `jiramcp` and stall touching
   the gate flag on the read-only kit mount. Drop an `AGENTS.md` (or the
   higher-precedence `AGENTS.override.md`, per codex-compatibility.md) in the
   agent's `cwd` saying "offline, no Jira, no MCP, no skills, everything is
   local". Derailments stop dead.
3. The harness aborts an agent after 1800 s of silence; single big-thread
   tickets need "read once, write promptly" or a one-key slice.

## Reusable corpus layout

```
<corpus>/
  keys.txt          snapshot of keys, filter order (record the snapshot time)
  listing.json      light fields for the final join (summary, priority, ...)
  issues/<key>.json full issue + all comments (from the script)
  attachments/<key>/ id-prefixed binaries
  triage-brief.md   the map-step brief + output schema
  AGENTS.md         offline override for codex reducers
  analysis/<key>.json  one compact summary per ticket (map output)
```

Collate `listing.json` + `analysis/*` into the deliverable with a stdlib script;
validate every key in `keys.txt` appears exactly once and the repro/flag fields
obey their own rules before trusting the output.
