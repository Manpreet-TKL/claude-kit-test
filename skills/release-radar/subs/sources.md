# Release radar - sources

Sweep in this order.

**The primary URL is the source of record.** Fetch the same page for a product on every
run so successive digests are comparable. Use the fallback only when the primary fails
outright, and only search when both fail (tag those bullets `[via search]`).

**Scope** column: `cumulative` = report every qualifying feature above the floor on
every run, even ones already listed in an earlier sweep (the point is a standing
upgrade-decision list). `since last run` = only what is new since the previous sweep.
A date floor (`since YYYY-MM-DD`) bounds the first sweep only; once a digest exists,
the last-run date takes over.

| # | Product | Floor | Scope | Primary (source of record) | Fallback |
|---|---|---|---|---|---|
| 1 | MariaDB Server | above 11.8, exclusive | cumulative | `https://mariadb.com/kb/en/release-notes/` | `https://mariadb.org/mariadb/all-releases/` |
| 2 | PHP | 8.4 | cumulative | `https://www.php.net/releases/` | `https://www.php.net/ChangeLog-8.php` |
| 3 | Portainer CE | above 2.39 LTS | cumulative | `https://docs.portainer.io/release-notes` | `https://github.com/portainer/portainer/releases.atom` |
| 4 | Chrome for Testing | 152.0.7973.0 | since last run | `https://googlechromelabs.github.io/chrome-for-testing/` | `https://github.com/GoogleChromeLabs/chrome-for-testing/issues` |
| 5 | Claude Code | 2.1.220 | since last run | `https://github.com/anthropics/claude-code/releases` | `https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md` |
| 6 | Ubuntu Server LTS | 24.04.4 | since last run | `https://documentation.ubuntu.com/release-notes/24.04/` | `https://ubuntu.com/about/release-cycle` |
| 7 | Google Workspace | rolling | since last run | `https://workspaceupdates.googleblog.com/` | `https://workspace.google.com/blog/product-announcements` |
| 8 | AWS | rolling | since last run | `https://aws.amazon.com/about-aws/whats-new/recent/feed/` | `https://aws.amazon.com/new/` |
| 9 | VS Code | 1.117.0 | since last run | `https://code.visualstudio.com/updates` | `https://github.com/microsoft/vscode/releases.atom` |
| 10 | SkySQL | since 2026-07-26 | since last run | `https://docs.skysql.com/Reference%20Guide/MariaDB%20Server%20Versions/` | `https://skysql.com/press-release` |
| 11 | GCP | rolling | since last run | `https://docs.cloud.google.com/release-notes` | `https://docs.cloud.google.com/compute/docs/release-notes` |
| 12 | Docker Compose | since 2026-02-02 | since last run | `https://github.com/docker/compose/releases` | `https://docs.docker.com/compose/releases/release-notes/` |
| 13 | Kubernetes | since 2026-02-02 | since last run | `https://kubernetes.io/blog/` | `https://kubernetes.io/releases/` |
| 14 | Helm | since 2026-02-02 | since last run | `https://github.com/helm/helm/releases` | `https://helm.sh/blog/` |
| 15 | Traefik | since 2026-02-02 | since last run | `https://github.com/traefik/traefik/releases` | `https://github.com/traefik/traefik/releases.atom` |
| 16 | Docker Engine | since 2026-02-02 | since last run | `https://docs.docker.com/engine/release-notes/` | `https://github.com/moby/moby/releases.atom` |
| 17 | Node.js | since 2026-02-02 | since last run | `https://github.com/nodejs/node/releases` | `https://github.com/nodejs/node/releases.atom` |
| 18 | Playwright | since 2026-02-02 | since last run | `https://playwright.dev/docs/release-notes` | `https://github.com/microsoft/playwright/releases.atom` |
| 19 | BridgeLink | since 2026-02-02 | since last run | `https://github.com/Innovar-Healthcare/BridgeLink/releases` | `https://github.com/Innovar-Healthcare/BridgeLink/releases.atom` |

## What to report, per product

The question every bullet answers is **"is this worth my attention?"** - not "what
changed". A patch-level bump with no user-visible feature is not worth a line.

1. **MariaDB Server** - features in the series **above** 11.8 (11.9, 12.x, ...), so the
   answer to "should I move off 11.8 LTS" is readable at a glance. Engine features,
   SQL/syntax additions, replication and optimiser changes, vector/JSON work,
   deprecations that would bite on upgrade. Not point-release bug fixes.
2. **PHP** - syntax and language features, new stdlib/extension capability, and
   **gotchas**: BC breaks, deprecations, behaviour changes that would bite an existing
   codebase. 8.4 and 8.5 both in scope.
3. **Portainer CE** - every new feature above 2.39, cumulative, so the next-LTS decision
   is one read. UI/UX, stacks, Edge, Kubernetes, auth/RBAC capability. Not CVE counts.
4. **Chrome for Testing** - **Watching: linux-arm64 builds.** Then any other
   capability change (new channels, download layout, CDP or headless behaviour).
   Version numbers alone are not a feature.
5. **Claude Code** - major features only. New subsystems, new tools, a new way of
   driving the CLI. Not per-release bug fixes, not minor flag tweaks.
6. **Ubuntu Server LTS** - what actually lands in the archive: notable package version
   bumps (clamav, GNU screen 5, openssl, php, docker), new kernel/HWE stack, and
   anything newly included or dropped. Point-release number alone is not a bullet.
7. **Google Workspace** - end-user capability changes of the "you can now do X" kind
   (example: sharing system audio when screen-sharing, not just a tab). Admin-console
   changes count when they unlock something. Skip AI feature marketing.
8. **AWS** - filter to what touches an OpenEyes deployment: EC2, EKS/ECS, RDS and
   Aurora MySQL, ELB, S3, ECR, IAM, Route 53. **Cost savings and price cuts always
   qualify.** Ignore ML, analytics, and region-availability announcements.
9. **VS Code** - **non-AI features only**, and **performance work is the most
   interesting thing on the page**. Editor, terminal, debugging, remote/SSH, profiles,
   startup and memory. Skip anything Copilot, chat, or agent shaped.
10. **SkySQL** - what they now **officially support**: newly offered MariaDB/MySQL
    server versions, clouds, regions, instance sizes, features moving preview -> GA.
11. **GCP** - **new processor generations and new services**, plus anything that
    changes what an OpenEyes deployment can run on. Skip incremental quota and console
    tweaks.
12. **Docker Compose** - new features only, one line each: new compose-spec keys, new
    CLI commands and flags, watch/develop capability, provider integrations. Never bug
    fixes, never dependency bumps.
13. **Kubernetes** - new minor releases: headline features (stable/GA graduations
    first), and **API removals and deprecations that bite on upgrade**. Skip
    alpha-stage features and patch releases.
14. **Helm** - CLI and chart-format features, changes that affect existing v3 charts
    on the way to Helm 4, deprecations. Not bug-fix point releases.
15. **Traefik** - routing, middleware and provider features, and **anything touching
    the Docker provider or its API-version handling** (the class of change that broke
    pre-3.6 against a newer engine). Breaking config changes and deprecations qualify;
    patch fixes do not.
16. **Docker Engine** - engine and API features: **a new Engine API version number
    always gets a line** (proxy compatibility), build/buildkit capability, CLI
    features, deprecations and removals. Not patch bug fixes.
17. **Node.js** - **Watching: the 24.x release that clears the puppeteer Chrome-unzip
    regression** (broke at 24.16.0, images pin 24.15.0; 24.17.0/24.18.x shipped with
    no named fix - resolution needs a verified-by-test unpin). Then notable 24.x LTS
    features and any new LTS promotion; skip current-line churn.
18. **Playwright** - test-runner and API features, UI mode / trace viewer capability,
    browser-support changes (new channels, dropped versions). Skip the routine
    per-release browser version bumps.
19. **BridgeLink** - every feature release: new connectors and protocols, admin/launcher
    capability, Java-support changes, security hardening of the run-as-root class, and
    anything migration-relevant from the Mirth 4.5 lineage.

## Security

Security is **not** a category here. Mention a vulnerability only when it is
extremely critical - remote code execution in a default configuration, or actively
exploited in the wild - and then in one line. Routine CVE round-ups never appear.

A source URL that has permanently moved gets fixed here, in this table - a promoted
fallback becomes the new primary. Do not silently substitute a different page at run
time; consistency of source is what makes one digest comparable to the next.
