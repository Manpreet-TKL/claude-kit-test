---
name: project_claude_kit_public_remote
description: "claude-kit's git remote is PUBLIC; the Mirth/client-derived material in it is Manpreet's to handle - do not edit or re-audit it."
metadata: 
  node_type: memory
  type: project
  originSessionId: 0af9796a-f816-4a45-88fb-2a869a5c8c0e
  modified: 2026-07-25T12:16:21.401Z
---

`~/claude-kit`'s remote (`claude-kit-test`) is a **public** GitHub repo - verified
2026-07-25 by an unauthenticated `GET /repos/...` returning 200. Treat every tracked
file as already published.

Two consequences:

1. **Secrets never go in the kit.** Enforced as a hard rule in `claude-md/CLAUDE.md`;
   credentials live under `~/.claude/mcp-env/` (Atlassian, GitHub) and
   `~/.claude/oe-chrome-agent/` (walker logins). `install.sh` migrates legacy in-repo
   copies out on its next run. See [[feedback_bulk_jira_download_bash_not_mcp]] for the
   script that reads the Atlassian one.
2. **The client-derived material is Manpreet's to handle, not mine.** That covers
   `knowledge/mirth-channel-corpus/`, the `c-mcchannels` skill and its subs,
   `knowledge/bolton-performance.md`, and the Mirth analysis memory file
   ([[project_mirth_channel_corpus_analysis]]). Between them they carry named client
   organisations, internal hostnames and IPs, per-site security findings and one live
   shared service-account credential in clear - all already pushed.

**Why:** asked directly on 2026-07-25 whether to redact these, Manpreet chose "leave
for you" on both the credential and the client identifiers. A well-meant redaction
sweep would rewrite files he is mid-way through deciding about, and would not unpublish
anything anyway.

**How to apply:** when auditing the kit, sweep everything else and report what those
files contain, but make no edits to them and do not re-open the decision. Do not stage
them. For any *new* mechanism, put the secret under `~/.claude/` from the start.
