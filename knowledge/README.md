# Knowledge

Durable lessons, one topic per file. Read only the topics relevant to the task.
Plans and queued work belong in `todo/`; do not start them unprompted.

| Category | Contents |
|---|---|
| [Database](Database/) | SQL, MariaDB, schema, locking, performance and data maintenance. |
| [Openeyes](Openeyes/) | Application behavior, code, integrations and documentation. |
| [Infrastructure](Infrastructure/) | Deployments, containers, Helm, AWS and runtime services. |
| [Tooling](Tooling/) | Agent setup, browsers, Git and development tools. |
| [Process](Process/) | Support workflows, Jira triage and team procedures. |

Use the closest category for new lessons and extend an existing topic first.
Old memory records may name a former flat path. Find that filename recursively
under `knowledge/`; historical records are intentionally unchanged. No content
here is loaded automatically.

## Database

- [bolton-performance.md](Database/bolton-performance.md)
- [mariadb-buffer-pool-audit.md](Database/mariadb-buffer-pool-audit.md)
- [oe-18464-unique-code-concurrency-and-solutions.md](Database/oe-18464-unique-code-concurrency-and-solutions.md)
- [oe-attachment-blob-dump.md](Database/oe-attachment-blob-dump.md)
- [oe-cleardown-policy.md](Database/oe-cleardown-policy.md)
- [oe-cleardown-versions.md](Database/oe-cleardown-versions.md)
- [oe-event-table-lock-contention.md](Database/oe-event-table-lock-contention.md)
- [oe-latest-views-performance.md](Database/oe-latest-views-performance.md)
- [oe-orphaned-archive-allergy-fk.md](Database/oe-orphaned-archive-allergy-fk.md)
- [oe-query-design.md](Database/oe-query-design.md)
- [oe-query-explain.md](Database/oe-query-explain.md)
- [oe-query-optimization.md](Database/oe-query-optimization.md)
- [oe-query-patterns-sorting-and-date-predicates.md](Database/oe-query-patterns-sorting-and-date-predicates.md)
- [oe-restore-tables-from-large-dump.md](Database/oe-restore-tables-from-large-dump.md)
- [oe-schema-cache.md](Database/oe-schema-cache.md)
- [oe-temporal-data.md](Database/oe-temporal-data.md)
- [oe-unique-codes.md](Database/oe-unique-codes.md)
- [oe-web-db-connections.md](Database/oe-web-db-connections.md)

## Openeyes

- [iolmaster-import.md](Openeyes/iolmaster-import.md)
- [oe-adha-my-health-record.md](Openeyes/oe-adha-my-health-record.md)
- [oe-community-portal.md](Openeyes/oe-community-portal.md)
- [oe-cookie-security.md](Openeyes/oe-cookie-security.md)
- [oe-debugbar-data-analysis.md](Openeyes/oe-debugbar-data-analysis.md)
- [oe-deprecated-element-types.md](Openeyes/oe-deprecated-element-types.md)
- [oe-docman-delivery.md](Openeyes/oe-docman-delivery.md)
- [oe-docman-delivery-performance-analysis.md](Openeyes/oe-docman-delivery-performance-analysis.md)
- [oe-docs-campaign.md](Openeyes/oe-docs-campaign.md)
- [oe-docs-shot-id-inventory.md](Openeyes/oe-docs-shot-id-inventory.md)
- [oe-documentation-bug-ledger.md](Openeyes/oe-documentation-bug-ledger.md)
- [oe-event-image-performance-analysis.md](Openeyes/oe-event-image-performance-analysis.md)
- [oe-event-image-pipeline.md](Openeyes/oe-event-image-pipeline.md)
- [oe-ghostscript-conversion-improvements.md](Openeyes/oe-ghostscript-conversion-improvements.md)
- [oe-hscic-gp-import-modernisation.md](Openeyes/oe-hscic-gp-import-modernisation.md)
- [oe-login-overlay-performance.md](Openeyes/oe-login-overlay-performance.md)
- [oe-nodaudit-validation.md](Openeyes/oe-nodaudit-validation.md)
- [oe-page-benchmarking.md](Openeyes/oe-page-benchmarking.md)
- [oe-patient-search.md](Openeyes/oe-patient-search.md)
- [oe-sharepoint-entra-integration.md](Openeyes/oe-sharepoint-entra-integration.md)
- [oe-sso-setup.md](Openeyes/oe-sso-setup.md)
- [oe-tmp-file-origins.md](Openeyes/oe-tmp-file-origins.md)
- [oe-v10-typical-usage-and-load-profile.md](Openeyes/oe-v10-typical-usage-and-load-profile.md)
- [oe-worklist-fix-patterns.md](Openeyes/oe-worklist-fix-patterns.md)
- [openeyes-api-families.md](Openeyes/openeyes-api-families.md)
- [openeyes-dmd.md](Openeyes/openeyes-dmd.md)
- [openeyes-dmd-update-plan.md](Openeyes/openeyes-dmd-update-plan.md)
- [openeyes-knowledge-tree.md](Openeyes/openeyes-knowledge-tree.md)
- [payload-processor.md](Openeyes/payload-processor.md)
- [payload-processor-settings.md](Openeyes/payload-processor-settings.md)

## Infrastructure

- [aws-cost-explorer-poc.md](Infrastructure/aws-cost-explorer-poc.md)
- [aws-cur2-export.md](Infrastructure/aws-cur2-export.md)
- [aws-production-deployments.md](Infrastructure/aws-production-deployments.md)
- [helm-monitoring-integration.md](Infrastructure/helm-monitoring-integration.md)
- [helm-scheduled-restarts.md](Infrastructure/helm-scheduled-restarts.md)
- [helm-vs-oe-deploy.md](Infrastructure/helm-vs-oe-deploy.md)
- [oe-deploy-portainer.md](Infrastructure/oe-deploy-portainer.md)
- [oe-horizon-redis.md](Infrastructure/oe-horizon-redis.md)
- [oe-laravel-startup-config-cache.md](Infrastructure/oe-laravel-startup-config-cache.md)
- [oeimagebuilder-apache-logging-and-performance.md](Infrastructure/oeimagebuilder-apache-logging-and-performance.md)
- [oeimagebuilder-node-puppeteer-regression.md](Infrastructure/oeimagebuilder-node-puppeteer-regression.md)

## Tooling

- [corpus-indexing.md](Tooling/corpus-indexing.md)
- [claude-in-chrome-permission-persistence.md](Tooling/claude-in-chrome-permission-persistence.md)
- [code-mapping-tools.md](Tooling/code-mapping-tools.md)
- [codex-compatibility.md](Tooling/codex-compatibility.md)
- [github-signed-commits.md](Tooling/github-signed-commits.md)
- [oe-deploy-git-history-purge.md](Tooling/oe-deploy-git-history-purge.md)
- [probe-discipline.md](Tooling/probe-discipline.md)
- [screen-tui-scrollback.md](Tooling/screen-tui-scrollback.md)

## Process

- [corpus-downloads.md](Process/corpus-downloads.md)
- [jira-corpus-triage.md](Process/jira-corpus-triage.md)
- [jira-devops-dashboard.md](Process/jira-devops-dashboard.md)
- [jira-support-dashboard.md](Process/jira-support-dashboard.md)
- [jira-tkls-process.md](Process/jira-tkls-process.md)
