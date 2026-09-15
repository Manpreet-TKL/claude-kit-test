# Release radar

Dated digests of upstream releases for the products tracked in
`skills/a-release-radar/subs/sources.md`. Written by the `a-release-radar` skill, newest
run first. One `## YYYY-MM-DD` heading per sweep; the topmost one is what the skill's
one-month gate reads. Never rewrite an older run.

## 2026-09-12

Scheduled sweep since 2026-08-02. Docker's Kubernetes-like capabilities and Keeper and
Jira's 2026 features are one-off backfills; later sweeps start from today.

### MariaDB Server (everything above 11.8)
- Now: 12.3.3 is the new LTS, maintained until June 2029; 13.0.1 is RC, 13.1 is development.
- 12.3 - MDL scalability may help OpenEyes workloads with many concurrent sessions; benchmark first.
- 12.3 - reverse index scans gain rowid filtering and index condition pushdown for descending lists.
- 12.3 - GROUP BY and ORDER BY can use virtual-column indexes.
- 12.3.3 - `innodb_index_shrink=OFF` can reduce latch contention on growing UPDATEs, using more page space.
- 12.3 - join-order and index hints add a way to test plans for difficult OpenEyes queries.

### PHP (8.4 and above)
- Now: 8.5.9 and 8.4.24 are the latest stable releases listed on the source page.
- 8.5 - pipe operator `|>` chains function calls.
- 8.5 - `#[NoDiscard]` detects ignored return values.
- 8.5 - Uri extension adds RFC 3986 and WHATWG parsers.
- 8.5 gotcha - OPcache is required; non-numeric string increment and backtick operator are deprecated.

### Portainer CE (everything above 2.39 LTS)
- Now: 2.45.0 is the new LTS (2026-08-27), replacing 2.39 as the upgrade target.
- 2.40 - Kompose can migrate Compose workloads to Kubernetes.
- 2.41 - GitOps Workflows page, editable Git-backed Kubernetes manifests and redeploy action.
- 2.45 - Kubernetes node drain gains agent failover.
- 2.45 - Edge Compute setup is available at first run or through CLI flags.
- Source moved: the old docs URL describes Business Edition; Community Edition uses GitHub releases.

### Chrome for Testing (floor 152.0.7973.0)
- Now: Stable 153.0.8010.36, Beta 154.0.8037.0, Dev 155.0.8048.0, Canary 155.0.8053.0.
- 152 (2026-08-25) - client-side XSLT is deprecated, with an origin trial for more migration time.
- 153 (2026-09-08) - nonstandard `_current` navigation target removed.
- 153 - Rust XML parser now handles DOMParser, responseXML and external SVG; test XML-heavy pages.
- OpenEyes source scan found no `target="_current"`, `XSLTProcessor` or `responseXML` in scoped app code.
- No lighter headless or screencast path is documented in the 152/153 release notes.

### Claude Code (floor 2.1.220)
- Now: 2.1.269 (2026-09-11).
- 2.1.269 - `claude plugin eval` runs reproducible plugin evaluation suites with JSON and HTML results.
- 2.1.269 - Workflow runs can raise the concurrent-agent ceiling to 256 where needed.

### Ubuntu Server LTS (floor 24.04.4)
- Now: 24.04.5 is listed on the official LTS index; its detail page returned HTTP 429.
- lookup failed: package and HWE details for 24.04.5 could not be verified from the release page.

### Google Workspace
- Now: rolling releases through 2026-09-11.
- 2026-09-11 - Google Chat saves unsent drafts across devices.
- 2026-09-11 - Google Sheets doubles the cell limit from 10 million to 20 million.
- 2026-09-11 - Meet hardware can check in companion-mode phones by ultrasound proximity.
- System-audio sharing for full-screen Meet capture was not found in this source window.

### AWS (OpenEyes-relevant)
- Now: rolling announcements; the RSS source was unreadable and the fallback rendered only Loading.
- 2026-09-03 - Aurora MySQL 8.4.8 adds transaction timeout [via search].
- 2026-09-04 - ECS rolling deploys gain configurable early-success thresholds [via search].
- Cost: no price cut was verified from the available dated results.

### VS Code (non-AI, floor 1.117.0)
- Now: 1.137 (2026-09); 1.136 was released 2026-09-02.
- 1.132 (2026-08-05) - hybrid Markdown editor can show rendered diffs while editing.
- 1.133 (2026-08-12) - local HTML previews auto-reload when files change.
- 1.134 (2026-08-19) - local HTML files can open in the integrated browser editor.
- No qualifying non-AI performance change appeared in the 1.135-1.137 highlights.

### SkySQL (officially supported)
- Now: source still lists 11.4.5/10.11.11/10.6.20/10.5.25 stable, 11.6.2 preview, 11.7.1 RC.
- no change

### GCP (processors and services)
- Now: rolling release notes through 2026-09-11.
- 2026-08-21 - M4N memory/network-optimized VMs, using 5th-gen Intel Xeon, reached GA.
- No new general-purpose processor generation or OpenEyes-relevant service found in this window.

### Docker Compose
- Now: 5.5.1 (2026-09-03).
- 5.5.1 - lifecycle hook output is captured and shown to operators.
- 5.5.0 - `compose pull` honors `pull_policy` refresh windows; first `up` may recreate containers.
- One-off: 5.3.0 added native pre-start init containers.
- One-off: `depends_on` can wait for a healthy service or a completed one-shot job.
- One-off: local Compose supports `mem_limit` for resource constraints.

### Kubernetes
- Now: 1.37.0 (2026-08-26) is current.
- 1.37 - StorageVersionMigration API graduates to stable.
- 1.37 - metrics.k8s.io/v1 graduates to stable.
- 1.37 - DRA Extended Resource support graduates to stable.
- 1.37 - kubelet still needs an explicit override on cgroup v1 nodes; removal is planned later.

### Helm
- Now: 4.3.0 (2026-09-09) and 3.22.0 (2026-09-10).
- 4.3 - chart templates gain duration functions.
- 4.3 - chart archives honor `SOURCE_DATE_EPOCH` for reproducible builds.
- 4.3 - `helm rollback --description` records the rollback reason.

### Traefik
- Now: 3.7.13 (2026-09-04); the visible releases since 3.7.10 contain fixes only.
- no change - no new Docker-provider or Engine API handling feature found.

### Docker Engine
- Now: 29.8.0 (2026-09-03); no Engine API bump beyond v1.52 was found.
- 29.8 - `--umask` sets the process, exec and healthcheck umask for a container.
- 29.8 - daemon can customize the default AppArmor profile template.
- One-off: Swarm provides desired-state services, multi-host networking and rolling update/rollback.

### Node.js
- Now: 24.21.0 LTS (2026-09-08).
- Watching (puppeteer unzip regression): no named fix or verified unpin; keep the 24.15.0 image pin.
- no other qualifying 24.x feature found in the visible release notes.

### Playwright
- Now: 1.63; its release-notes page does not give a release date.
- 1.63 - named test locks serialize only tests sharing a resource, across files and workers.
- 1.63 - frame locators can search any frame subtree.
- 1.63 - `locator.visible()` filters visible matches.
- 1.63 - trace capture can select DOM, ARIA and screen snapshots separately.
- 1.63 - Ubuntu 20.04 support ends; component-test packages stop receiving updates.

### BridgeLink
- Now: 26.6.0 (2026-07-22) remains the latest feature release.
- no change

### Codex
- Now: CLI 0.154.0 (2026-09-09); matching Python SDK 0.154.0 followed on 2026-09-10.
- 0.154 - GPT-6-Astra enters the model picker and Bedrock catalog.
- 0.154 - experimental `--worktree` and `/worktree` create isolated session checkouts.
- 0.152 - per-tool MCP `output_token_limit` caps tool context.
- 0.153 - experimental token-budget context became available.
- 0.154 - `codex mcp-server` was removed; kit integrations that launch it need migration before upgrading.

### Keeper (one-off 2026 backfill)
- Now: official release index lists Vault, extension, Secrets Manager and PAM feature streams.
- 2026 - KeeperPAM Workflow adds time-limited, approved access with automatic expiry.
- 2026 - KeeperDB supports monitored MySQL/MariaDB sessions without exposing credentials locally.
- 2026 - Secrets Manager Terraform provider adds ephemeral resources for 25 record types.
- 2026 - Web Vault adds biometric passkey login.
- 2026 - browser Verify Mode warns on credential paste to mismatched sites.
- 2026 - KeeperPAM RBI gains file transfer.

### Jira Cloud (one-off 2026 backfill)
- Now: official Jira launch notes run through 2026-09-04; the September item is early access only.
- 2026-02-20 - structured approvals became available in team- and company-managed spaces.
- 2026-04-27 - Free Guest Access allows external collaborators in one space without extra seats.
- 2026-04-27 - admins can delegate creation of spaces from approved templates.
- 2026-07-27 - Premium/Enterprise capacity planning tracks people and work allocations in Jira.
- 2026-07-27 - formula fields calculate values usable in JQL, dashboards and automation.

### Source notes this run
- MariaDB's old primary URL moved to a generic index; the official Community Server series index replaced it.
- Portainer's old primary URL was for Business Edition; the official Community Edition releases replaced it.
- AWS RSS cannot be read by this web client and its fallback omits announcement data without JavaScript.
- Ubuntu 24.04.5's detail page returned HTTP 429; no package or HWE conclusion was inferred.

## 2026-08-02

Forced run one week after the last sweep. First sweep for products 12-19 (floor
2026-02-02); products 4-11 report the week since 2026-07-26 only.

### MariaDB Server (everything above 11.8)
- Now: 11.8.8 LTS is your line; 12.0.2 -> 12.3.2 stable rolling, 13.0.1 RC (2026-05-29), 13.1.0 preview (2026-06-19).
- 12.0 - SYS_REFCURSOR cursor type plus max_open_cursors; passphrase-protected encryption keys.
- 12.1 - associative arrays (`DECLARE TYPE .. TABLE OF .. INDEX BY`); caching_sha2_password plugin for MySQL client compatibility.
- 12.1 - segmented Aria key cache (`aria_pagecache_segments`, up to 128); faster vector distance via extrapolation.
- 12.2 (2026-02-12) - more optimizer hints, join optimizer infers distinct GROUP BY columns in derived tables, JSON 32-level depth limit removed.
- 12.3 (2026-05-29) - stable, but feature text is on neither source page; carried unlisted again this run.
- Upgrade read: rolling releases are 1-year support, not LTS - moving off 11.8 means re-upgrading yearly until the next LTS.

### PHP (8.4 and above)
- Now: 8.4.24 (2026-07-30), 8.5.8 (2026-07-02).
- 8.5 - pipe operator `|>` for function chaining; `clone()` as a function with clone-with support.
- 8.5 - `#[NoDiscard]` attribute flags return values that must not be ignored; `void` cast to discard deliberately.
- 8.5 - new Uri extension with RFC 3986 and WHATWG parsers; `get_error_handler()` / `get_exception_handler()`.
- Gotcha: OPcache is no longer optional in 8.5 - it is a required core component.
- Gotcha: deprecated in 8.5 - non-numeric string increment, the backtick operator, and the `(boolean)`/`(integer)`/`(double)`/`(binary)` cast spellings.

### Portainer CE (everything above 2.39 LTS)
- Now: 2.41.0 STS (2026-04-30) is newest; 2.39.5 (2026-07-14) is still the newest LTS - there is no LTS above 2.39 yet.
- 2.40 (2026-03-26) - Kompose migration of Docker Compose workloads to Kubernetes; Helm Go SDK on v4.
- 2.40 - `--remove-orphans` on Compose stack deploys; `--security-opt` on container create.
- 2.41 (2026-04-30) - GitOps Workflows sidebar page listing every workflow across environments with status summaries.
- 2.41 - Git-backed Kubernetes manifests editable after deployment, plus a Redeploy button; Helm chart edge stacks from repos or Git with custom namespaces.
- 2.41 - TUI apps work in the web console and kubectl shell; image pruning from the Images list.

### Chrome for Testing (floor 152.0.7973.0)
- Watching linux-arm64: still none - platforms remain linux64, mac-arm64/x64, win32/64 on every channel.
- Now: Stable 151.0.7922.71, Beta 152.0.7977.8, Dev 153.0.7979.3, Canary 153.0.7986.0.
- Otherwise no change - Dev/Canary rolled to 153 with no capability changes on the page.

### Claude Code (floor 2.1.220)
- Now: 2.1.220 (2026-07-25) is still the latest release.
- no change

### Ubuntu Server LTS (floor 24.04.4)
- Now: 24.04.4, GA kernel 6.8; 24.04.5 not yet published.
- The notes' known-issues section now references an HWE 6.17 kernel (6.17.0-14.14) - last sweep the HWE stack was 6.14.

### Google Workspace
- Meet homepage hub (announced 2026-07-21) began rolling out 2026-07-27 [via search].
- Meet hardware user feedback now lands in the Admin console, with context-tailored response options [via search].
- Still not seen: system-audio sharing in screen share.

### AWS (OpenEyes-relevant)
- EKS Provisioned Control Plane: HPA sync concurrency raised up to 40x the Kubernetes default (2026-07-28).
- EKS OIDC discovery endpoint reachable over PrivateLink at no additional cost (2026-07-27).
- EC2 Auto Scaling instance refresh now usable as a CloudFormation update policy (2026-07-29).
- Cost: RDS for Oracle Reserved Instances on R8i/M8i, up to 53% vs on-demand (2026-07-31).
- Cost: Bedrock price cuts - OpenAI GPT-5.6 Luna up to 80% cheaper, Terra 20% (2026-07-30).

### VS Code (non-AI, floor 1.117.0)
- Now: 1.131 (2026-07-29).
- Terminal: new setting to disable the resize dimensions overlay; live updates use non-interrupting ARIA status announcements.
- Perf: Python extension defers Conda discovery, consolidates environment scans, and Pylance reuses the last-known interpreter during refresh.
- Another thin non-AI release - nothing in editor, debugging or remote this month.

### SkySQL (officially supported)
- Now: unchanged - 11.4.5/10.11.11/10.6.20/10.5.25 stable, 11.6.2 vector preview, 11.7.1 RC.
- no change - still a full LTS line behind the MariaDB you run.

### GCP (processors and services)
- No new processor generation this period.
- Confidential VMs: 255+ vCPUs on AMD SEV C3D/C4D instances (2026-07-29).
- Cloud SQL for MySQL: zero-downtime CMEK re-encryption (2026-07-29).
- Cloud Load Balancing: global external passthrough Network Load Balancer in preview (2026-07-31).

### Docker Compose (first sweep, floor 2026-02-02)
- Now: 5.3.1 (2026-07-07).
- 5.3.0 (2026-07-02) - native init containers (pre-start init containers).
- 5.2.0 (2026-06-23) - new reconciliation algorithm between observed and expected state.
- 5.2.0 - `rawsetenv` message type for provider plugins.
- 5.1.4 (2026-05-20) - stop lifecycle hook for external providers.

### Kubernetes (first sweep, floor 2026-02-02)
- Now: 1.36 "Haru" (2026-04-22) is current; 1.35 (2025-12-17) and 1.34 in support.
- 1.36 - user namespaces GA.
- 1.36 - fine-grained kubelet API authorization GA.
- 1.36 - volume group snapshots GA.
- 1.36 - deprecation: Service externalIPs deprecated and headed for removal.

### Helm (first sweep, floor 2026-02-02)
- Now: 4.2.3 and 3.21.3 (both 2026-07-09); release notes flag v3 as approaching end-of-life.
- 4.2.0 (2026-05-14) - `mustToToml` template function.
- 4.2.0 - `--dry-run=server` now respects `generateName:` in manifests.
- 4.2.0 - deprecates `--hide-notes` and `--render-subchart-notes`.

### Traefik (first sweep, floor 2026-02-02)
- Now: 3.7.10 / 3.6.25 / 2.11.54 (all 2026-07-31).
- First sweep truncated: the releases page only reaches early July and every visible release on all three lines is bug/CVE fixes; 3.7.0's feature notes fall off the page.
- Nothing visible touching the Docker provider or its API-version handling.

### Docker Engine (first sweep, floor 2026-02-02)
- Now: 29.7.1 (2026-07-31), Engine API v1.52.
- 29.3.0 (2026-03-05) - minimum API version lowered from v1.44 back to v1.40.
- 29.5.0 - `docker image load`/`save` support multiple platform selection.
- 29.6.0 (2026-06-18) - new Engine API v1.52: per-device blkio via container update, `GET /images/{name}/attestations`.
- 29.6.0 - deprecation warning for container links on the default bridge.
- 29.7.0 (2026-07-30) - `image` mount type leaves experimental; new `default-stop-timeout` daemon option.

### Node.js (first sweep, floor 2026-02-02)
- Now: 24.18.1 LTS (2026-07-29).
- Watching (puppeteer unzip regression): 24.17.0 (2026-06-18) and 24.18.x shipped, but no extraction/unzip fix is named in their notes - verify by test before lifting the 24.15 pin.
- 24.18.0 (2026-06-23) - TurboSHAKE and KangarooTwelve in Web Crypto.
- 24.18.0 - `http` writeInformation for arbitrary 1xx status codes.

### Playwright (first sweep, floor 2026-02-02)
- Now: 1.62 (the release-notes page carries no dates; 1.57-1.62 taken as the floor window from cadence).
- 1.57 - switched from Chromium to Chrome for Testing builds (headed `chrome`, headless `chrome-headless-shell`); removed `page.accessibility`.
- 1.58 - Timeline tab in merged HTML reports; removed `_react`/`_vue` and `:light` selectors and the `devtools` option.
- 1.59 - screencast API with action annotations; `browser.bind()` shares launched browsers with the CLI and other instances.
- 1.61 - virtual WebAuthn passkeys via the Credentials API; WebStorage API for local/sessionStorage.
- 1.62 - `AbortSignal` cancellation and isolated retries; headless clipboard isolated from the OS; Debian 11 dropped.

### BridgeLink (first sweep, floor 2026-02-02)
- Now: v26.6.0 (2026-07-22); versioning jumped 4.6.1 -> 26.3.0 (calendar-style) this spring.
- 26.3.0 (2026-04-07) - Jetty 9.4 -> 12.0, Java 17+ required; SMTP OAuth 2.0 client-credentials auth; Version History merged into core.
- 26.3.1 (2026-05-15) - refuses to start as root/Administrator; keystore default-password detection; hardened password policy on by default.
- 26.6.0 (2026-07-22) - WebAdmin browser-based administration console; plugin UI endpoints for declarative plugin interfaces.
- 26.6.0 - MySQL table-case migration for case-sensitive servers; opt-in channel context in server logs.

### Source drift this run
- MariaDB primary is an index page with no version or feature text - the series list came from the fallback (mariadb.org all-releases); 12.3/13.x feature text is on neither page.
- Google Workspace primary rate-limited (`google.com/sorry`) and the fallback blog is undated - the two dated bullets are [via search].
- Playwright's release-notes page carries no dates; the floor window is inferred from release cadence.
- Traefik's releases page depth (~10 entries) hides everything before early July - 3.7.0's feature notes are unreachable from the source of record.
- Claude Code's releases page reports 2.1.220 (2026-07-25) as latest - an unusually quiet week, taken at face value.

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
