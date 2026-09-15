# Release radar sources and relevance

Use these official pages for discovery, then link the dated, version-specific
page that proves each selected entry. An index, RSS feed, downloads list or search
result alone does not prove a feature. If an index is shallow, follow versioned
archives or migration guides to cover the entire interval. Record a gap rather
than advancing `Verified through` on an incomplete read.

| # | Product | Initial floor | Official discovery and detail sources |
|---|---|---|---|
| 1 | MariaDB Server | Above deployed 11.8 LTS | [Community release notes](https://mariadb.com/docs/release-notes/community-server); open each series' Changes and Improvements and deprecation notes. |
| 2 | PHP | Deployed 8.4 onward | [PHP releases](https://www.php.net/releases/), [migration guides](https://www.php.net/manual/en/appendices.php); open the version's new features and incompatible changes. |
| 3 | Portainer CE | Above 2.39 LTS | [Community Edition releases](https://github.com/portainer/portainer/releases); follow version tags, not Business Edition notes. |
| 4 | Chrome for Testing | 152.0.7973.0 onward | [Builds](https://googlechromelabs.github.io/chrome-for-testing/), [versioned browser notes](https://developer.chrome.com/release-notes/); use the latter for behavior. |
| 5 | Claude Code | 2.1.220 onward | [Releases](https://github.com/anthropics/claude-code/releases), [upstream changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md). |
| 6 | Ubuntu Server LTS | Next LTS after deployed 24.04, currently 26.04 | [LTS index](https://documentation.ubuntu.com/release-notes/), [26.04 release notes](https://documentation.ubuntu.com/release-notes/26.04/); read the summary from the deployed LTS and point-release notes. Recompute the next LTS when the deployed version changes. |
| 7 | Google Workspace | Dated updates | [Workspace Updates](https://workspaceupdates.googleblog.com/); open dated posts, not marketing roundups. |
| 8 | AWS | 2026-01-01 one-time backfill, then watermark | [What's New](https://aws.amazon.com/about-aws/whats-new/), [AWS documentation](https://docs.aws.amazon.com/), [regional capabilities](https://builder.aws.com/build/capabilities); use dated announcement pages and verify `eu-west-2` availability. If a listing requires JavaScript, search the official AWS site by month and service, then open the direct result. |
| 9 | VS Code | 1.117 onward | [Versioned updates](https://code.visualstudio.com/updates); use each monthly version's feature and deprecation notes. |
| 10 | SkySQL | 2026-07-26 onward | [Supported server versions](https://docs.skysql.com/Reference%20Guide/MariaDB%20Server%20Versions/), [product news](https://skysql.com/); dated official evidence is required to call support new. |
| 11 | GCP | Dated updates | [Release notes](https://docs.cloud.google.com/release-notes), [Compute notes](https://docs.cloud.google.com/compute/docs/release-notes), [regions and zones](https://docs.cloud.google.com/compute/docs/regions-zones); verify `europe-west2` zone or service availability. |
| 12 | Docker Compose | 2026-02-02 onward; Kubernetes-like history once | [Compose releases](https://github.com/docker/compose/releases), [Compose specification](https://docs.docker.com/compose/compose-file/), [startup ordering](https://docs.docker.com/compose/how-tos/startup-order/); distinguish historical capability from new release. |
| 13 | Kubernetes | 2026-02-02 onward | [Releases](https://kubernetes.io/releases/), [official release posts](https://kubernetes.io/blog/); use migration and deprecated API notes. |
| 14 | Helm | 2026-02-02 onward | [Helm releases](https://github.com/helm/helm/releases), [Helm blog](https://helm.sh/blog/); follow major-version migration notes. |
| 15 | Traefik | 3.3 inclusive, then every minor onward | [Releases](https://github.com/traefik/traefik/releases), [v3 migration guide](https://doc.traefik.io/traefik/migrate/v3/), [support lifecycle](https://doc.traefik.io/traefik/deprecation/releases/); read each 3.3+ minor's migration page, including changes lost from the short GitHub listing. |
| 16 | Docker Engine | 29.0 breaking-change baseline, then 2026-02-02 onward | [Engine release notes](https://docs.docker.com/engine/release-notes/); include Engine API and deprecation sections. |
| 17 | Node.js | 24 LTS onward | [Node releases](https://github.com/nodejs/node/releases), [release schedule](https://nodejs.org/en/about/previous-releases); verify the Puppeteer unzip regression by test before saying fixed. |
| 18 | Playwright | 2026-02-02 onward | [Versioned release notes](https://playwright.dev/docs/release-notes), [GitHub releases for dates](https://github.com/microsoft/playwright/releases); do not infer dates from cadence. |
| 19 | BridgeLink | 2026-02-02 onward | [Releases](https://github.com/Innovar-Healthcare/BridgeLink/releases); open the dated tag notes. |
| 20 | Codex | 2026-08-02 onward | [Official changelog](https://learn.chatgpt.com/docs/changelog), [CLI releases](https://github.com/openai/codex/releases); distinguish model availability from CLI changes. |
| 21 | Keeper | 2026-01-01 one-time backfill, then watermark | [Release-note index](https://docs.keeper.io/llms.txt), [official release notes](https://docs.keeper.io/release-notes), [dated product posts](https://www.keepersecurity.com/blog/category/release-notes/); use the index to enumerate product histories, then open the direct dated note. |
| 22 | Jira Cloud | 2026-01-01 one-time backfill, then watermark | [Jira releases](https://jirareleases.atlassian.com/); use Jump to Month and open each dated announcement. |

## Relevance tests

1. **MariaDB:** Optimize likely OpenEyes schema workloads: large joins, descending clinical lists, indexed virtual columns, concurrency and replication. Say which query pattern could benefit and require a benchmark; retain upgrade deprecations and LTS support dates.
2. **PHP:** New language/runtime capability and incompatibilities from 8.4 to the next line. Flag removed or deprecated syntax, extensions and changed defaults that code or containers may use.
3. **Portainer CE:** Features above 2.39 that change stack, Kubernetes, Edge, authentication or admin workflows; LTS change and upgrade steps.
4. **Chrome for Testing:** Browser behavior that could break OpenEyes or tests; useful CDP, headless and capture changes. Prioritize measured CPU/memory, lighter headless-shell or screencast improvements in the web container.
5. **Claude Code:** Major workflow or tool changes, not minor flags and fixes.
6. **Ubuntu Server LTS:** Always compare the deployed OpenEyes LTS to the next LTS. Include service/package jumps, changed defaults, removed support, image/platform compatibility and migration blockers. Do not follow interim releases as upgrade targets.
7. **Google Workspace:** Concrete end-user or admin capability, especially meeting and screen-sharing workflows. Skip generic AI announcements.
8. **AWS:** EC2, EKS/ECS, RDS/Aurora MySQL/MariaDB, ELB, S3, ECR, IAM and Route 53 that affect OpenEyes in London. Cost savings always qualify when the service/region applies. Do not lose S3 Files; track London availability and file/object behavior before suggesting adoption.
9. **VS Code:** Non-AI editor, terminal, remote or debug improvements, especially measurable performance and memory changes.
10. **SkySQL:** Newly officially supported server versions, clouds, regions and features moving to GA. Undated current version lists are status only.
11. **GCP:** London-available processor generations, services and deployment options relevant to OpenEyes; cost or breaking change. Zone-specific availability matters.
12. **Docker Compose:** New Compose features plus one historical inventory of Kubernetes-like capabilities: resource constraints, init containers, health/dependency ordering and lifecycle/rollout controls. Label old behavior historical; after this run track only new releases.
13. **Kubernetes:** Stable or GA minor-release changes, API removals, deprecations and migration work; skip alpha and patches.
14. **Helm:** Chart/CLI features, v3-to-v4 migration and deprecations; skip patches.
15. **Traefik:** From 3.3 onward, Docker provider/API compatibility, routing and middleware features, config migrations, removals and support end. A currently unsupported version is an active warning.
16. **Docker Engine:** New API number always qualifies; resource, lifecycle, network, build, CLI and deprecation changes that affect deployment.
17. **Node.js:** Track the 24.x Puppeteer unzip regression and test a proposed unpin. Otherwise relevant LTS promotions and runtime features.
18. **Playwright:** Test, trace, screencast and browser compatibility changes; deprecations that affect current tests.
19. **BridgeLink:** Connectors/protocols, Java/Jetty support, admin and deployment migration; hardening that changes startup behavior.
20. **Codex:** New CLI/app/IDE/cloud features, measured token efficiency, new models, default model and availability changes. Distinguish feature from model release.
21. **Keeper:** New Vault, extension, Admin Console, Secrets Manager and PAM workflows; support or removal deadlines.
22. **Jira Cloud:** New board, search, automation, work management and service-management features that materially change daily use; support or removal deadlines.
