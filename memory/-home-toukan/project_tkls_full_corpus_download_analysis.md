---
name: tkls-full-corpus-download-analysis
description: "Full TKLS corpus (9,940 tickets + attachments, 22 GB) DOWNLOADED to ~/jira-corpus/full (complete by 2026-08-19); analysis brief queued in kit todo/ - stats gate before any model pass."
metadata: 
  node_type: memory
  type: project
  originSessionId: 036e5e32-8be5-48c0-9651-5f9090f3c2ce
  modified: 2026-08-10T20:36:30.086Z
---

Full TKLS download (9,940 tickets, all attachment binaries) into `~/jira-corpus/full/`
started 2026-08-10 and is COMPLETE (log ends "DOWNLOAD COMPLETE"; keys.txt 9,940 =
issues/ 9,940; 22 GB on disk; verified 2026-08-19). To top up or repair, the same
command resumes idempotently: `bash ~/claude-kit/scripts/jira_filter_download.sh -j 'project = TKLS ORDER BY created ASC' -a -r -o /home/toukan/jira-corpus/full`
(see [[bulk-jira-download-bash-not-mcp]]).

The analysis brief lives at `~/claude-kit/todo/tkls-corpus-analysis-plan.md`
(execute only on request): verify download -> ADF-flatten to text/ + index.tsv ->
grep/awk classifiers (sql, training, majorbug, errorlog, rca, kbfix, upgrade,
notissue, codefix, stale, patterns) -> `analysis/stats.md`. **Hard gate:
Manpreet reviews stats.md before ANY model reads ticket content**; model passes
(Sonnet 5 notes, Haiku triage) are sized from the counts. Queued as a line in
`~/claude-kit/todo/TODO.md`.
