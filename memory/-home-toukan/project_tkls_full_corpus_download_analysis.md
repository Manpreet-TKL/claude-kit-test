---
name: tkls-full-corpus-download-analysis
description: "Full TKLS corpus (9,940 tickets + attachments) downloading to ~/tkls-corpus-full since 2026-08-10 evening; analysis brief parked in kit knowledge/ - stats before any model pass."
metadata: 
  node_type: memory
  type: project
  originSessionId: 036e5e32-8be5-48c0-9651-5f9090f3c2ce
  modified: 2026-08-10T20:36:30.086Z
---

Started 2026-08-10 ~evening: full TKLS download (9,940 tickets, all attachment
binaries, serial) into `~/tkls-corpus-full/` in detached screen `tkls-corpus`,
log at `~/tkls-corpus-full/download.log`. Expected 3-6 h, ~7-11 GB. If it
aborted, re-run resumes: `bash ~/claude-kit/scripts/jira_filter_download.sh -j 'project = TKLS ORDER BY created ASC' -a -r -o /home/toukan/tkls-corpus-full`
(`-r/--resume` added and verified 2026-08-10, see [[bulk-jira-download-bash-not-mcp]]).

The analysis brief lives at `~/claude-kit/knowledge/tkls-corpus-analysis-plan.md`
(execute only on request): verify download -> ADF-flatten to text/ + index.tsv ->
grep/awk classifiers (sql, training, majorbug, errorlog, rca, kbfix, upgrade,
notissue, codefix, stale, patterns) -> `analysis/stats.md`. **Hard gate:
Manpreet reviews stats.md before ANY model reads ticket content**; model passes
(Sonnet 5 notes, Haiku triage) are sized from the counts. Kit change + brief are
staged in ~/claude-kit, uncommitted (index also holds unrelated README/codex
changes from another session).
