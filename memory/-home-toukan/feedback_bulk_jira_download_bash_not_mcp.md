---
name: bulk-jira-download-bash-not-mcp
description: "Bulk Jira corpus downloads go through a bash/REST script, never MCP-agent fetch-and-transcribe; Claude orchestrates thin and codex reads from disk."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1ced0e38-87c4-48ff-9d7d-7464777185b0
  modified: 2026-07-20T15:50:43.611Z
---

Downloading 106 TKLS issues (~2.4 MB) via Claude subagents calling
`mcp__atlassian__jira_get_issue` and transcribing to disk cost ~400k+ subagent
tokens and ~30 min wall time: every payload passes through model context twice
(tool result + Write), oversized results overflow the inline limit (recover via
`jq -r '.result'` on the saved tool-result file), and context compactions drop
fetched payloads forcing re-fetches. A curl/jq script does the same job in
minutes at zero model tokens.

**Why:** Manpreet (2026-07-20): "it should not have taken a lot of tokens to
download the tickets, it should have been a case of using a bash script then
reading the corpus using codex and Claude not doing much."

**How to apply:** For any bulk Jira export, run
`~/claude-kit/scripts/jira_filter_download.sh` (REST v3 enhanced search,
`nextPageToken` paging, comment top-up, `-a` for attachment binaries via direct
content URLs - no base64-in-context). The jiramcp MCP-only rule still governs
interactive/triage access; the script is the sanctioned path for bulk corpus
downloads. Claude's job is orchestration only - point codex (or subagents) at
the on-disk corpus instead of piping ticket bodies through model context.
