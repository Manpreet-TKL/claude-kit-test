# Release radar

Dated digests of upstream releases for the products tracked in
`skills/release-radar/subs/sources.md`. Written by the `release-radar` skill, newest
run first. One `## YYYY-MM-DD` heading per sweep; the topmost one is what the skill's
one-month gate reads. Never rewrite an older run.

## 2026-07-26

First sweep. Cumulative products list everything above their floor.

### MariaDB Server (everything above 11.8)
- Now: 11.8.8 LTS is your line; 12.0 -> 12.3 are GA rolling releases, 13.0 is RC (2026-05-29).
- 12.0 - SYS_REFCURSOR cursor type plus max_open_cursors; passphrase-protected encryption keys.
- 12.1 - associative arrays (`DECLARE TYPE .. TABLE OF .. INDEX BY`); caching_sha2_password plugin for MySQL client compatibility.
- 12.1 - segmented Aria key cache (`aria_pagecache_segments`, up to 128); faster vector distance via extrapolation.
- 12.2 (2026-02-12) - more optimizer hints, join optimizer infers distinct GROUP BY columns in derived tables, JSON 32-level depth limit removed.
- Upgrade read: rolling releases are 1-year support, not LTS - moving off 11.8 means re-upgrading yearly until the next LTS.

### PHP (8.4 and above)
- Now: 8.4.23 (2026-07-03), 8.5.8 (2026-07-02).
- 8.5 - pipe operator `|>` for function chaining; `clone()` as a function with clone-with support.
- 8.5 - `#[NoDiscard]` attribute flags return values that must not be ignored; `void` cast to discard deliberately.
- 8.5 - new Uri extension with RFC 3986 and WHATWG parsers; `get_error_handler()` / `get_exception_handler()`.
- Gotcha: OPcache is no longer optional in 8.5 - it is a required core component.
- Gotcha: deprecated in 8.5 - non-numeric string increment, the backtick operator, and the `(boolean)`/`(integer)`/`(double)`/`(binary)` cast spellings.

### Portainer CE (everything above 2.39 LTS)
- Now: 2.41.0 STS (2026-04-30) is newest; 2.39.5 (2026-07-14) is still the newest LTS - there is no LTS above 2.39 yet.
- GitOps Workflows sidebar page listing every workflow across environments with status summaries.
- Git-backed Kubernetes manifests editable after deployment, plus a Redeploy button to pull and redeploy.
- Helm chart edge stacks deployable from Helm repos or Git, with custom namespace support; Helm Go SDK on v4.
- Kompose migration of Docker Compose workloads to Kubernetes; image pruning from the Images list.
- TUI apps work in the web console and kubectl shell, with terminal resize handling.
- `--remove-orphans` on Compose stack deploys; `--security-opt` on container create.

### Chrome for Testing (floor 152.0.7973.0)
- linux-arm64: still no builds. The CfT tracker issue is closed "not planned" and points at upstream crbug.com/374811603.
- Upstream: Google announced Chrome for ARM64 Linux rolling out in Q2 2026 - not yet reflected in CfT downloads.
- Now: Stable and Beta on 151.0.7922.47, Dev 152.0.7967.2, Canary 152.0.7973.0. Your floor is the Canary build.

### Claude Code (floor 2.1.220)
- 2.1.220 - Opus 5 default with a 1M context window.
- 2.1.219 - dynamic workflow size guidelines (small/medium/large); nested subagent forwarding in stream-json.
- 2.1.218 - `/code-review` runs as a background subagent; screen reader mode.
- 2.1.212 - `/fork` copies a conversation into a background session; `/resume` picker; MCP calls auto-background after 2 minutes.
- 2.1.198 - subagents run in the background by default; Claude in Chrome GA; `Notification` hook for agents.
- 2.1.186 - `claude mcp login` / `logout` CLI commands.

### Ubuntu Server LTS (floor 24.04.4)
- Now: 24.04.4 (2026-02-12), HWE stack on kernel 6.14 (GA kernel remains 6.8).
- Archive versions still as shipped at 24.04: python 3.12 default, php 8.3.6, docker 24.0.7, clamav 1.0.0 LTS.
- 24.04.4 itself is hardware enablement only - USB-C daisy-chain kernel crash, Intel MIPI camera detection, WiFi firmware.
- GNU screen 5 is not called out anywhere in the noble notes, so `scripts/screen5_install.sh` is still the route (not confirmed by the page, inferred from its absence).

### Google Workspace
- Meet (2026-07-22) - notes, transcripts and recordings auto-file into a Google Meet folder with per-meeting subfolders, and attendees now get shortcuts in their own Drive, not just the host.
- Meet (2026-07-21) - rebuilt web homepage as a hub for meeting notes and attachments.
- Calendar (2026-07-23) - delegate icons in guest lists across event details, full-screen create and side-by-side scheduling.
- Sheets (2026-07-22) - improved combo chart support for multi-series visualisations.
- Classroom (2026-07-21) - role-based homepages for teachers, students and admins from 2026-07-27; collapsible modules.
- Not seen this run: system-audio sharing in screen share.

### AWS (OpenEyes-relevant)
- NLB Listener Rules for custom traffic routing (2026-07-22), at no additional charge - routing logic that was ALB-only.
- ALB access logs can now be delivered to CloudWatch Logs (2026-07-23).
- ECS Service Connect zone-aware routing (2026-07-23) - keeps traffic in-AZ, cuts cross-AZ data charges.
- ECS Action Logs for deployment and orchestration visibility (2026-07-21).
- EKS supports EFA and placement groups on Auto Mode and Karpenter (2026-07-22).
- Cost/perf: M8a on 5th Gen AMD EPYC Turin, +30% vs M7a; M8id on custom Intel Xeon 6, +43% vs M6id; I8ge on Graviton4, +60% compute vs Graviton2 (all 2026-07-22/23).
- RDS for MySQL 9.7 available in the Database Preview Environment (2026-07-23).

### VS Code (non-AI, floor 1.117.0)
- Now: 1.130 (2026-07-22).
- Terminal: clickable file links in git diffs - `i/` and `w/` mnemonic prefixes are stripped so files open.
- Engineering: the codebase now compiles with released TypeScript 7, and the extension matches.
- Thin run: 1.130 has almost nothing non-AI. No editor, debugging, remote or performance work in this release - the changelog is overwhelmingly agents and chat.

### SkySQL (officially supported)
- Server versions offered: MariaDB 11.4.5, 10.11.11, 10.6.20, 10.5.25 stable; 11.6.2 vector preview; 11.7.1 RC.
- Nothing at 11.8 or above - SkySQL is a full LTS line behind the MariaDB you run.
- No public changelog exists, so "newly supported" can only be read off the server-versions doc. Treat this section as low-signal until a changelog appears.

### GCP (processors and services)
- No new processor generation this period - no Axion or next-gen Intel/AMD machine family announced in June-July 2026.
- Compute Engine (2026-07-16) - Hyperdisk Balanced HA on C4 up to 1,600 MiB/s, from 600 MiB/s on c4-standard-16.
- Artifact Registry (2026-07-24) - connector repositories GA: proxy an upstream registry with no caching.
- Cloud Router BGP named sets GA (2026-07-23); Firestore Security Rules editable in the console (2026-07-20).
- Cloud SQL for MySQL moved 8.4.8 -> 8.4.10 (2026-07-16).
- Deprecation worth diarising: customer-supplied encryption keys (CSEK) for disks, snapshots and images are disabled 2027-07-20.

### Source drift this run
- MariaDB `kb/en/release-notes/` and `mariadb.org/mariadb/all-releases/` both carry version lists but no feature text; series features came from the per-series "Changes & Improvements" docs found by search.
- Google Workspace Updates blog rate-limited an earlier fetch this session (`google.com/sorry` redirect); it answered on retry.
