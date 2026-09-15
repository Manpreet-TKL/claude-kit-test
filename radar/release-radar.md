# Release radar

Last attempted: 2026-09-12 (Europe/London).
Selected evidence: 67 verified entries; 27 pending checks across 22 products.

This is one continuing section per product. Newer items go above older ones.
`Verified` counts selected entries backed by the linked, direct vendor page;
it does not count every line or release reviewed. `Pending` counts unresolved
checks, including incomplete release-series coverage. `Verified through: not
established` means the date range has not been fully enumerated; it is not a
claim that no relevant releases occurred. Old run-by-run output is preserved
[verbatim](release-radar-legacy-2026.md).

## MariaDB Server

Checked on: 2026-09-12. Window: above deployed 11.8 LTS through 2026-09-12.
Verified through: not established. Evidence: 6 verified; 1 pending (full
11.8-to-current release series still needs enumeration).

- **2026-08-24, 12.3.3 - replication upgrade check.** MariaDB says upgrading a
  replica to 12.3.2 can lose `master_use_gtid`; 12.3.3 fixes the behavior, but
  the setting must be reapplied. Check replica configuration before an OpenEyes
  database upgrade. [12.3 changes](https://mariadb.com/docs/release-notes/community-server/12.3/mariadb-12.3-changes-and-improvements).
- **2026-08-24, 12.3.3 - record-growing UPDATE option.** Setting
  `innodb_index_shrink=OFF` can reduce B-tree latch upgrades when an UPDATE
  grows a record, at the cost of sparser pages. Test only a representative
  OpenEyes write workload with such updates; it is unrelated to ordinary row
  lock contention and has no measured gain here.
  [12.3 changes](https://mariadb.com/docs/release-notes/community-server/12.3/mariadb-12.3-changes-and-improvements).
- **2026-05-28, 12.3.2 LTS GA - candidate query improvements.** Indexed virtual
  columns can assist `GROUP BY`/`ORDER BY`, and reverse-ordered scans gain rowid
  filtering and index condition pushdown. Test large clinical lists and
  derived-field sort queries against the OpenEyes schema; a benefit is possible,
  not measured. [12.3.2 release](https://mariadb.com/docs/release-notes/community-server/12.3/12.3.2),
  [12.3 changes](https://mariadb.com/docs/release-notes/community-server/12.3/mariadb-12.3-changes-and-improvements).
- **2026-05-28, 12.3.2 LTS GA - metadata-lock scalability.** MariaDB lists
  MDL scalability improvements. Benchmark concurrent OpenEyes schema
  introspection and DDL-heavy maintenance before assuming they help normal
  clinical writes; metadata locks and row locks are different bottlenecks.
  [12.3 changes](https://mariadb.com/docs/release-notes/community-server/12.3/mariadb-12.3-changes-and-improvements).
- **2026-05-28, 12.3.2 LTS GA - compatibility audit.** `CONVERSION` and `TO_DATE`
  became reserved, while `big_tables`, `large_page_size` and `storage_engine`
  were removed. Search SQL and server configuration before moving beyond 11.8.
  [12.3 changes](https://mariadb.com/docs/release-notes/community-server/12.3/mariadb-12.3-changes-and-improvements).
- **2026-05-28, 12.3.2 LTS GA - systemd option deprecation.**
  `MYSQLD_OPTS` is deprecated for MariaDB service units. Move any OpenEyes
  database settings supplied there into configuration files before its removal.
  [12.3.2 release](https://mariadb.com/docs/release-notes/community-server/12.3/12.3.2).

## PHP

Checked on: 2026-09-12. Window: deployed 8.4 to 2026-09-12.
Verified through: not established. Evidence: 2 verified; 1 pending (8.5
maintenance and migration series not fully enumerated).

- **2025-11-20, PHP 8.5 - incompatible behavior.** OPcache is built in, so
  loading `opcache.so` explicitly warns; PDO fetch constants also changed.
  Audit container INI files and database test coverage before an 8.5 image
  switch. [8.5 incompatible changes](https://www.php.net/manual/en/migration85.incompatible.php).
- **2025-11-20, PHP 8.5 - optional language tools.** The pipe operator,
  `#[NoDiscard]` and the URI extension are available. These are code-maintenance
  opportunities, not a reason alone to upgrade OpenEyes.
  [8.5 release](https://www.php.net/releases/8.5/en.php).

## Portainer CE

Checked on: 2026-09-12. Window: above 2.39 LTS to 2026-09-12.
Verified through: not established. Evidence: 1 verified; 1 pending (intermediate
CE releases not exhaustively reviewed).

- **2026-08-27, 2.45.0 LTS - operational upgrade candidate.** The CE LTS
  rollup includes Kubernetes node-drain agent failover and native Kubernetes
  write APIs. Check whether those improve the OpenEyes cluster-admin workflow
  before upgrading; the release also records environment-specific limitations.
  [2.45.0 release](https://github.com/portainer/portainer/releases/tag/2.45.0).

## Chrome for Testing

Checked on: 2026-09-12. Window: 152 onward to 2026-09-12.
Verified through: not established. Evidence: 2 verified; 2 pending (release
series incomplete; capture resource impact needs a web-container benchmark).

- **2026-09-08, Chrome 153 - XML parsing path changed.** The Rust XML parser is
  used for `DOMParser`, `responseXML` and external SVG. Test any OpenEyes
  document or image flow using those APIs before advancing the test browser.
  [Chrome 153 notes](https://developer.chrome.com/release-notes/153).
- **2026-08-25, Chrome 152 - XSLT removal approaches.** XSLT has a deprecation
  trial; Chrome plans removal in 158. Check OpenEyes and test fixtures for
  `XSLTProcessor` or browser-side XSLT and migrate any use before that version.
  [Chrome 152 notes](https://developer.chrome.com/release-notes/152),
  [XSLT plan](https://developer.chrome.com/docs/web-platform/deprecating-xslt).

Pending: No official Chrome 152-153 note establishes a lighter screen-capture
mode. Benchmark headless Chrome and screencast options in the web container
before claiming CPU or memory savings.

## Claude Code

Checked on: 2026-09-12. Window: 2.1.220 onward to 2026-09-12.
Verified through: not established. Evidence: 1 verified; 1 pending (intermediate
tags have not all been read).

- **2026-09-11, 2.1.269 - plugin evaluation.** `claude plugin eval` can produce
  scored JSON and HTML output. Useful for checking skill or plugin behavior
  during kit changes, if the local workflow uses plugins.
  [2.1.269 release](https://github.com/anthropics/claude-code/releases/tag/v2.1.269).

## Ubuntu Server LTS

Checked on: 2026-09-12. Window: deployed 24.04 LTS to next LTS, 26.04.
Verified through: not established. Evidence: 4 verified; 1 pending (26.04
point-release changes and image-specific upgrade tests still need review).

- **2026-04-23, 26.04 LTS - runtime jump.** The next OpenEyes deployment target
  moves the distro PHP package to 8.5 and OpenSSH to 10.2p1. Test image builds,
  PHP extensions and SSH automation against 26.04 before changing the base.
  [24.04-to-26.04 summary](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/).
- **2026-04-23, 26.04 LTS - Apache and TLS defaults.** Apache's
  `MemoryDenyWriteExecute=yes` service setting conflicts with mod-php JIT, and
  TLS 1.0/1.1 support is disabled. Check any Apache-based sidecar and legacy
  integration; PHP-FPM is the recommended route for JIT.
  [26.04 changes](https://documentation.ubuntu.com/release-notes/26.04/changes-since-previous-interim/).
- **2026-04-23, 26.04 LTS - command and policy changes.** `sudo-rs` and Rust
  coreutils become defaults, with additional AppArmor profiles. Test deployment
  scripts and container startup rather than assuming command flags and sandbox
  permissions are identical to 24.04.
  [24.04-to-26.04 summary](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/).
- **2026-04-23, 26.04 LTS - older AWS instance families lose support.**
  Ubuntu lists M1-M4, C1/C3/C4, R3/R4, I2/G3 and P2/P3/P3dn as unsupported.
  Check the deployment inventory before selecting a 26.04 AMI in London.
  [24.04-to-26.04 summary](https://documentation.ubuntu.com/release-notes/26.04/summary-for-lts-users/).

## Google Workspace

Checked on: 2026-09-12. Window: 2026-07-26 to 2026-09-12.
Verified through: not established. Evidence: 1 verified; 1 pending (dated
Workspace posts in the interval are not fully enumerated).

- **2026-09-08 - persistent Google Chat drafts.** Unsent drafts resume across
  devices; web rollout began 2026-09-08 for rapid-release domains and is
  scheduled from 2026-09-22 for scheduled-release domains. Useful for interrupted
  support handoffs, subject to the domain's rollout track.
  [Workspace update](https://workspaceupdates.googleblog.com/2026/09/pick-up-where-you-left-off-with-persistent-drafts-in-Google-Chat.html).

## AWS

Checked on: 2026-09-12. Window: one-time 2026-01-01 to 2026-09-12 backfill.
Verified through: not established. Evidence: 5 verified; 2 pending (monthly
London service announcements not fully enumerated; S3 Files region unresolved).

- **2026-09-08, London - S3 Object Lock variable retention.** The new
  variable-retention and event-hold options are available in all AWS regions.
  Possible fit for backup retention policies; test legal-hold and deletion
  semantics before changing existing OpenEyes backups.
  [AWS announcement](https://aws.amazon.com/about-aws/whats-new/2026/09/amazon-s3-object-lock-variable-retention/).
- **2026-08-19, London - fourth Availability Zone.** `eu-west-2d` expands the
  region's placement choices. Review whether database, application and load
  balancer topology can use another zone; it does not itself make a deployment
  multi-AZ. [AWS announcement](https://aws.amazon.com/about-aws/whats-new/2026/08/aws-new-availability-zone-europe/).
- **2026-05-26, London - RDS ENA Express for Multi-AZ replication.** RDS for
  MariaDB and MySQL can use the new network path for replication in London at
  no additional feature charge. Possible benefit for OpenEyes failover lag;
  benchmark replica lag and check instance eligibility before changing RDS
  configuration.
  [AWS announcement](https://aws.amazon.com/about-aws/whats-new/2026/05/amazon-rds-ena-express-multiAZ/).
- **2026-04-23, London - five more S3 checksum algorithms.** AWS says the
  algorithms are available in all regions. Candidate for stronger integrity
  checks on protected-file or backup uploads, after checking SDK support and
  existing checksum handling.
  [AWS announcement](https://aws.amazon.com/about-aws/whats-new/2026/04/s3-five-additional-checksum-algorithms/).
- **2026-03-12, London - EC2 M8i and M8i-flex.** Both families launched in
  `eu-west-2`. Benchmark representative OpenEyes web and database workloads
  against the currently deployed class before treating vendor price/performance
  figures as savings.
  [AWS announcement](https://aws.amazon.com/about-aws/whats-new/2026/03/amazon-ec2-m8i-m8i-flex-additional-regions/).

London unverified: **2026-04-07, S3 Files** exposes S3 buckets as shared file
systems, potentially useful for protected files and file-based tools. The launch
names 34 regions but does not name London. AWS also documents an extra
high-performance storage tier and asynchronous writes back to S3; availability,
cost and consistency must be checked before proposing it for OpenEyes.
[Launch](https://aws.amazon.com/about-aws/whats-new/2026/04/amazon-s3-files/),
[performance details](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-performance.html).

## VS Code

Checked on: 2026-09-12. Window: 1.117 to 1.137.
Verified through: not established. Evidence: 0 verified; 1 pending (monthly
non-AI feature and deprecation notes need a full read; no unverified claim
carried forward).

## SkySQL

Checked on: 2026-09-12. Window: 2026-07-26 to 2026-09-12.
Verified through: not established. Evidence: 0 verified; 1 pending (the official
supported-version list is undated and cannot prove when support changed).

## GCP

Checked on: 2026-09-12. Window: dated 2026 updates to 2026-09-12.
Verified through: not established. Evidence: 1 verified; 2 pending (London
service announcements not fully enumerated; CSEK end dates disagree).

- **2026-07-20, Compute Engine CSEK deprecation - London applies.** New
  customer-supplied encryption key use is deprecated globally, including
  `europe-west2`. Check whether any OpenEyes disk or image automation uses CSEK
  before planning a migration. The official pages disagree on its final removal
  date, so that deadline remains pending.
  [Compute CSEK notice](https://docs.cloud.google.com/compute/docs/deprecations/csek-deprecation-in-compute-engine),
  [deprecation table](https://docs.cloud.google.com/compute/docs/deprecations).

## Docker Compose

Checked on: 2026-09-12. Window: 2026-02-02 to 2026-09-12, plus one-time
historical Kubernetes-like capability inventory. Verified through: not
established. Evidence: 5 verified; 1 pending (remaining release tags in the
window still need review).

- **2026-09-03, v5.5.1 - lifecycle-hook output.** Hook output is exposed in
  Compose logs, helping diagnose startup and shutdown hooks in development
  stacks. Check the current hook use before changing stack files.
  [v5.5.1 release](https://github.com/docker/compose/releases/tag/v5.5.1).
- **2026-07-02, v5.3.0 - init containers.** Compose gained init-container
  support. This can move one-shot preparation out of a long-running OpenEyes
  service, but test ordering and failure behavior in the actual stack.
  [v5.3.0 release](https://github.com/docker/compose/releases/tag/v5.3.0).
- **Historical, reviewed 2026-09-12 - startup ordering.** Compose already
  supports `service_healthy` and `service_completed_successfully` dependencies.
  Use health checks and completed jobs where readiness matters; plain startup
  order alone does not prove MariaDB is ready.
  [startup-order guide](https://docs.docker.com/compose/how-tos/startup-order/).
- **Historical, reviewed 2026-09-12 - resource controls.** Service definitions
  support CPU and memory limits; deploy resources also describe reservations.
  Test the local Compose implementation before treating reservations like
  Kubernetes scheduler guarantees.
  [Compose service reference](https://docs.docker.com/reference/compose-file/services/),
  [deploy reference](https://docs.docker.com/reference/compose-file/deploy/).
- **Historical, reviewed 2026-09-12 - rollout limit.** `docker compose up`
  recreates changed containers. The deploy specification describes
  `update_config` and `rollback_config` for Swarm, so do not assume a local
  Compose stack has Kubernetes-style rolling updates or rollback.
  [Compose up](https://docs.docker.com/reference/cli/docker/compose/up/),
  [deploy reference](https://docs.docker.com/reference/compose-file/deploy/).

## Kubernetes

Checked on: 2026-09-12. Window: 2026-02-02 to 1.37.
Verified through: not established. Evidence: 4 verified; 1 pending (1.36
migration items still need a full read).

- **2026-08-26, 1.37 - kube-dns deprecated.** Kubernetes expects no new
  kube-dns packages after 1.40. Check cluster DNS add-ons and plan a CoreDNS
  migration if any OpenEyes cluster still uses kube-dns.
  [1.37 release](https://kubernetes.io/blog/2026/08/26/kubernetes-v1-37-release/).
- **2026-08-26, 1.37 - kube-proxy IPVS mode deprecated.** The vendor expects
  IPVS to be disabled by default in 1.40 and removed in 1.43. Check
  `KubeProxyConfiguration` before planning a cluster upgrade; the dates are
  roadmap targets, not completed removals.
  [1.37 release](https://kubernetes.io/blog/2026/08/26/kubernetes-v1-37-release/).
- **2026-08-26, 1.37 - kubelet cgroup v1 warning.** The fail-by-default
  setting began in 1.35 and remains in 1.37. Kubelet fails on cgroup v1
  hosts unless explicitly overridden; removal is planned. Check node OS
  and runtime cgroup mode before an OpenEyes cluster upgrade.
  [1.37 release](https://kubernetes.io/blog/2026/08/26/kubernetes-v1-37-release/).
- **2026-08-26, 1.37 - built-in storage migration.**
  StorageVersionMigration is GA and enabled by default. Review storage API
  migration effects on existing OpenEyes resources during the upgrade rehearsal.
  [1.37 release](https://kubernetes.io/blog/2026/08/26/kubernetes-v1-37-release/).

## Helm

Checked on: 2026-09-12. Window: 2026-02-02 to 2026-09-12.
Verified through: not established. Evidence: 3 verified; 1 pending (4.x minor
release and chart migration notes need a full read).

- **2026-09-09, 4.3.0 - reproducible chart archives.** Helm honors
  `SOURCE_DATE_EPOCH` when packaging charts. Test whether this removes
  timestamp-only differences from OpenEyes chart artifacts in CI.
  [4.3.0 release](https://github.com/helm/helm/releases/tag/v4.3.0).
- **2026-09-09, 4.3.0 - rollback reason.** `helm rollback --description`
  records why a rollback was made. Add a short reason to the deployment
  runbook if Helm 4 is adopted.
  [4.3.0 release](https://github.com/helm/helm/releases/tag/v4.3.0).
- **2026-05-14, 4.2.0 - CLI flag deprecations.** `--hide-notes` and
  `--render-subchart-notes` are deprecated. Check deployment scripts before a
  Helm 4 upgrade; chart authors also gain `mustToToml`.
  [4.2.0 release](https://github.com/helm/helm/releases/tag/v4.2.0).

## Traefik

Checked on: 2026-09-12. Window: 3.3 inclusive to 2026-09-12.
Verified through: not established. Evidence: 5 verified; 1 pending (each 3.3+
minor migration and patch series still needs a complete pass).

- **2026-09-04, 3.7.13 - h2c backend behavior.** Traefik no longer forwards
  `Upgrade: h2c` and `HTTP2-Settings` headers. Set an explicit h2c backend
  scheme where required, then test proxy-to-service traffic before upgrading.
  [3.7.13 release](https://github.com/traefik/traefik/releases/tag/v3.7.13).
- **2026-09-12 support check - 3.3 and 3.6 support ended.** The vendor lists
  3.3 with neither active nor security support, and 3.6 security support ended
  2026-08-16. A deployed 3.3/3.6 should be scheduled for a supported 3.7
  migration, with routing tests.
  [support lifecycle](https://doc.traefik.io/traefik/deprecation/releases/).
- **2026-01-14, 3.6.7 - encoded-path policy changed again.** Versions
  3.6.4-3.6.6 rejected several encoded path characters by default with HTTP
  400; 3.6.7 restored the earlier permissive default and makes the restriction
  opt-in. Test escaped OpenEyes URLs and set an explicit policy before changing
  versions. [3.6.7 release](https://github.com/traefik/traefik/releases/tag/v3.6.7),
  [migration guide](https://doc.traefik.io/traefik/migrate/v3/).
- **2025-05-27, 3.4.1 - encoded path handling.** Reserved encoded path
  characters remain encoded for route matching. Test OpenEyes routes with
  escaped path characters when moving from 3.3.
  [3.4.1 release](https://github.com/traefik/traefik/releases/tag/v3.4.1),
  [v3 migration guide](https://doc.traefik.io/traefik/migrate/v3/).
- **2025-04-18, 3.3.6 - request paths are cleaned before routing.**
  `/../`, `/./` and duplicate slashes are collapsed before matching and
  forwarding. Check any OpenEyes route or integration that relies on literal
  path segments when upgrading within 3.3 or beyond.
  [3.3.6 release](https://github.com/traefik/traefik/releases/tag/v3.3.6).

## Docker Engine

Checked on: 2026-09-12. Window: 2026-02-02 to 2026-09-12.
Verified through: not established. Evidence: 3 verified; 2 pending (29.x
release and deprecation series incomplete; current API documentation conflicts).

- **2026-09-03, 29.8.0 - container umask.** `HostConfig.Umask` and
  `docker run --umask` can set the default file-creation mask. Test protected
  file permissions in OpenEyes containers before relying on it.
  [Engine 29 notes](https://docs.docker.com/engine/release-notes/29/).
- **2026-06-18, 29.6.0 - API 1.55 and live resource update.** The API matrix
  lists 1.55 for 29.6, and `POST /containers/{id}/update` gains per-device
  block-I/O settings. Check client negotiation and whether in-place resource
  adjustment helps a container with variable storage load.
  [Engine 29 notes](https://docs.docker.com/engine/release-notes/29/),
  [API matrix](https://docs.docker.com/reference/api/engine/).
- **2025-11-10, 29.0 baseline - API 1.52.** The previous digest placed this
  API number under 29.6.0. Pin compatibility checks to the daemon/API table,
  not a later maintenance release.
  [Engine 29 notes](https://docs.docker.com/engine/release-notes/29/),
  [API version table](https://docs.docker.com/reference/api/engine/).

Pending: Docker's current API reference shows Engine 29.8 as 1.55 in its
matrix but 1.56 in its command-output example. Do not publish a 29.8 API
bump until the official history resolves this discrepancy.
[API reference](https://docs.docker.com/reference/api/engine/).

## Node.js

Checked on: 2026-09-12. Window: Node 24 LTS through 24.21.0.
Verified through: not established. Evidence: 0 verified; 2 pending (the Node
24 maintenance series is incomplete; the Puppeteer unzip regression has no
verified fix in the OpenEyes image, so test before unpinning 24.15).

## Playwright

Checked on: 2026-09-12. Window: 2026-02-02 to 2026-09-12.
Verified through: not established. Evidence: 4 verified; 2 pending
(intervening minor releases; screen-capture resource measurements).

- **2026-09-04, 1.63 - named test locks.** Tests sharing a lock cannot run
  concurrently across files or workers, while other tests stay parallel.
  Use this for OpenEyes browser tests that mutate the same shared setting
  or account instead of serializing the entire suite.
  [1.63.0 release](https://github.com/microsoft/playwright/releases/tag/v1.63.0).
- **2026-09-04, 1.63 - selective trace snapshots.** Trace configuration can
  independently enable DOM, ARIA and screen snapshots. Compare trace size and
  troubleshooting value before reducing screen snapshots in the test container.
  [1.63.0 release](https://github.com/microsoft/playwright/releases/tag/v1.63.0).
- **2026-07-24, 1.62 - WebP screenshots.** WebP output may reduce screenshot
  artifact size, with lossy quality where acceptable. Compare bytes and CPU
  in the web container before adopting it for OpenEyes captures.
  [1.62.0 release](https://github.com/microsoft/playwright/releases/tag/v1.62.0).
- **2026-04-01, 1.59 - live screencast frames.** `page.screencast` streams
  JPEG frames with size and quality controls. Test whether a small frame stream
  can replace repeated full screenshots in the OpenEyes screen-capture path;
  memory and CPU savings are unmeasured.
  [1.59.0 release](https://github.com/microsoft/playwright/releases/tag/v1.59.0),
  [screencast API](https://github.com/microsoft/playwright/blob/main/docs/src/api/class-screencast.md).

## BridgeLink

Checked on: 2026-09-12. Window: 2026-02-02 to 2026-09-12.
Verified through: not established. Evidence: 2 verified; 1 pending (remaining
release tags and deployment migration notes need review).

- **2026-07-22, 26.6.0 - MySQL migration and web admin.** First startup on
  Linux can rename mixed-case MySQL tables; WebAdmin requires a server at least
  26.3.0. Rehearse database upgrade and backup/restore before a BridgeLink
  container jump. [26.6.0 release](https://github.com/Innovar-Healthcare/BridgeLink/releases/tag/v26.6.0).
- **2026-05-15, 26.3.1 - privileged startup blocked by default.** Running as
  root or Administrator now refuses startup unless `server.allowRoot=true` is
  set. Prefer an unprivileged runtime and test volume permissions before
  upgrading the integration container.
  [26.3.1 release](https://github.com/Innovar-Healthcare/BridgeLink/releases/tag/v26.3.1).

## Codex

Checked on: 2026-09-12. Window: 2026-08-02 to 2026-09-12.
Verified through: not established. Evidence: 4 verified; 1 pending (all CLI
releases and model-availability notes in the window need enumeration).

- **2026-09-09, CLI 0.154.0 - `codex mcp-server` removed.** The kit's
  `install.sh -x` bridge still launches that command, and its container
  installs the latest CLI without a version pin. Rebuilding that image with
  0.154.0 or newer can break the bridge; retain a known-working image until
  the launcher is migrated and tested.
  [0.154.0 release](https://github.com/openai/codex/releases/tag/rust-v0.154.0),
  [kit launcher](../install.sh),
  [CLI image](../docker/codex/Dockerfile).
- **2026-09-09, CLI 0.154.0 - GPT-6-Astra model picker.** The model catalog
  exposes GPT-6-Astra in supported configurations. Check account and provider
  availability before changing the kit's pinned implementation model.
  [0.154.0 release](https://github.com/openai/codex/releases/tag/rust-v0.154.0).
- **2026-09-03, CLI 0.153.0 - experimental context token budget.** Eligible
  ChatGPT accounts can set an experimental context budget. It is a control,
  not evidence of lower token consumption; measure a repeatable task before
  changing defaults.
  [0.153.0 release](https://github.com/openai/codex/releases/tag/rust-v0.153.0).
- **2026-09-01, CLI 0.152.0 - MCP output cap.** `output_token_limit` can bound
  returned MCP tool content. Candidate for reducing noisy tool responses in the
  kit, subject to preserving needed evidence.
  [0.152.0 release](https://github.com/openai/codex/releases/tag/rust-v0.152.0).

## Keeper

Checked on: 2026-09-12. Window: one-time 2026-01-01 to 2026-09-12 backfill.
Verified through: not established. Evidence: 8 verified; 1 pending (official
product-specific 2026 release history still needs enumeration).

- **2026-08-24 - KeeperDB multi-connection queries.** KeeperDB 2.5 can open
  several databases at once and run the same query across selected connections
  of one engine type. This could speed OpenEyes schema checks across sites;
  confirm the connection set before running any query against multiple databases.
  [KeeperDB 2.5 notes](https://docs.keeper.io/release-notes/desktop/keeperdb/keeperdb-2.5.0).
- **2026-08-24 - hardware-key passkey login.** Web Vault 18.6 adds FIDO2
  roaming authenticators for passkey sign-in. Check browser extension and admin
  policy compatibility before proposing a sign-in change.
  [Vault 18.6 notes](https://docs.keeper.io/release-notes/desktop/web-vault-+-desktop-app/vault-release-18.6.0).
- **2026-08-14 - Secrets Manager CLI 1.5 breaking change.** AWS syncs using
  `--record` or `--folder` now require `--prefix`; Linux release tarballs now
  carry an architecture suffix. Audit automation before upgrading. The same
  release fixes an AWS secret-name authorization gap and arm64 init-container
  binaries.
  [Secrets Manager CLI 1.5 notes](https://docs.keeper.io/release-notes/enterprise/keeper-secrets-manager/2026/secrets-manager-cli-1.5.0).
- **2026-06-04 - time-bound PAM approval workflows.** Keeper describes
  approval-based privileged sessions. Relevant if shared operational access
  should expire automatically; check plan and policy availability before
  changing an access process.
  [Keeper update](https://www.keepersecurity.com/blog/2026/06/04/whats-new-with-keeper-june-2026/).
- **2026-06-04 - KeeperDB for audited database sessions.** Keeper describes
  browser or desktop database access with credentials kept off the endpoint,
  session recording and MySQL/MariaDB support. Assess the product and license
  before using it for OpenEyes database administration.
  [Keeper update](https://www.keepersecurity.com/blog/2026/06/04/whats-new-with-keeper-june-2026/).
- **2026-06-04 - Vault and browser workflow changes.** Web Vault biometric
  passkeys and browser extension Verify Mode can reduce repeat sign-ins and
  warn on pasted credentials at suspicious sites. Confirm client support and
  admin policy before rollout.
  [Keeper update](https://www.keepersecurity.com/blog/2026/06/04/whats-new-with-keeper-june-2026/).
- **2026-02-04 - Gateway high availability.** Multiple Keeper Gateway
  instances can share a configuration and distribute PAM sessions. Relevant
  if database or server access depends on one Gateway; test failure behavior
  before treating it as HA.
  [Keeper update](https://www.keepersecurity.com/blog/2026/02/04/whats-new-with-keeper-february-2026/).
- **2026-02-04 - Commander SuperShell.** Commander 17.2.2 or newer adds a
  terminal vault browser with search and TOTP countdowns. Candidate for
  container-based operations without opening a desktop Vault window.
  [Keeper update](https://www.keepersecurity.com/blog/2026/02/04/whats-new-with-keeper-february-2026/).

## Jira Cloud

Checked on: 2026-09-12. Window: one-time 2026-01-01 to 2026-09-12 backfill.
Verified through: 2026-09-12. Evidence: 6 verified; 0 pending (the official
2026 monthly announcement archive was reviewed through this date).

- **2026-07-27 - individual capacity planning.** Premium and Enterprise
  planning can allocate work across spaces and account for leave. Useful for
  cross-team delivery planning if the site has the required plan.
  [Jira announcement](https://jirareleases.atlassian.com/announcements/individual-capacity-planning-is-here).
- **2026-07-27 - formula fields.** Calculated fields can be used in Jira work views,
  JQL, dashboards and automation, potentially replacing exported tracking
  spreadsheets. Verify rollout and plan eligibility before changing reports.
  [Jira announcement](https://jirareleases.atlassian.com/announcements/stop-exporting-and-start-calculating-in-jira).
- **2026-07-27 - unified List and All Work view.** The merged List supports JQL,
  parent-child hierarchy, inline edits and saved team configurations. Try it for
  release triage before maintaining separate spreadsheet or board views.
  [Jira announcement](https://jirareleases.atlassian.com/announcements/a-more-powerful-list-view-for-the-way-your-team-actually-works).
- **2026-07-27 - faster team-managed software boards.** Atlassian reports a
  22% faster load and adds inline editing, swimlanes and saved views. Check
  whether the board changes simplify standups on an OpenEyes project.
  [Jira announcement](https://jirareleases.atlassian.com/announcements/a-faster-more-flexible-board-for-software-teams-1).
- **2026-04-27 - free guest access.** Eligible paid Jira plans include
  single-space guest access for external collaborators. Check entitlement and
  space permissions before inviting vendors to an OpenEyes delivery project.
  [Jira announcement](https://jirareleases.atlassian.com/announcements/bring-external-collaborators-into-jira-without-adding-seats).
- **2026-02-20 - structured approvals.** Jira Cloud Premium and Enterprise
  can add auditable approval steps to team-managed and company-managed
  workflows. A candidate for deployment or change approval where those
  decisions currently live only in comments.
  [Jira announcement](https://jirareleases.atlassian.com/announcements/approvals-that-keep-work-moving).
