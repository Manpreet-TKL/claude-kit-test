# OpenEyes → Laravel rewrite plan

Draft v0.6, 2026-08-16 (v0.6 adds R54–R56: reference-data release pipeline, sample-database profiles incl. legacy-equivalent and story-driven large history, and a blast-radius/impact map; v0.5 added R50–R53: output-equivalence corpus, concurrency/load test plan with scenarios, high-speed parallel cutover, three-majors-a-year adaptability; v0.4 added R47–R49: frontend-first after discovery with an identical login page confirmed by an early visual walk, a completeness rule, and configuration visibility/secrets handling; v0.3 added R44–R46: chunked delivery around usage-limit resets, a feature register proving every function and its tests, and use of the OpenEyes layout repos in discovery; v0.2 added R33–R43: construction record, DevOps notes, schema tamper checks, fast/secure/multi-arch builds, separate Docker repo + VM install, pattern lint, anonymisation labels on models, early login milestone, test determinism). Target: Yii 1.1 OpenEyes (~14k code files, ~2,500 tables, ~17k columns) → Laravel 13 on PHP 8.4, MariaDB 11.8 LTS, identical frontend, drop-in containers.

How to read: sections 1–3 are decisions; sections 4–9 are phases in execution order (Phase 0 → 5); section 10 is the token plan; 11–13 are quality/docs/governance; 14 is sequencing and risks; appendices hold the rule sets. Anything marked *spike* is a decision that needs a measured experiment before it is final. Anything marked *guess* is a number to be replaced by pilot data.

## 1. Requirement → section map

| # | Requirement (your list) | Where |
|---|---|---|
| R1 | Token consumption planned/minimised | §10 |
| R2 | TDD, driven by walks | §7.1, §11 |
| R3 | Frontend identical; same or separate asset repo | §3.2, §7.4 |
| R4 | All known bugs fixed | §4.5, §7.6 |
| R5 | Schema redesign (slow queries, NF, naming, indexes, patterns, growth, versions, no blobs) | §5 |
| R6 | Current coding standards followed | §6.3, App. A |
| R7 | Tests for everything | §11 |
| R8 | Everything API-exportable | §6.5 |
| R9 | Lightweight Docker image | §9.1 |
| R10 | AI-friendly code segmentation | §6.2, §10.4 |
| R11 | Config/settings independent, export/import | §5.9, §6.7 |
| R12 | Seed DB per version, settings via CSV | §6.8 |
| R13 | Scale to millions, Kubernetes, many web containers | §9.2 |
| R14 | Deprecated code/schema marked with proof | §4.2, §5.10 |
| R15 | Tracker mini-app for 14k files | §4.1, App. C |
| R16 | Old→new schema jump; drop-in web containers | §5.11, §5.14 |
| R17 | Strict, consistent naming rules | App. A, §6.4 |
| R18 | Frontend extremely fast | §7.5 |
| R19 | Factories for all features | §6.6 |
| R20 | Playwright parity tests | §7.2 |
| R21 | Post-migration data validation | §5.11 |
| R22 | Docs module, markdown, separate repo | §12 |
| R23 | Very few queries per page | §5.3, §7.5 |
| R24 | MCP to build a test database | §6.9 |
| R25 | All data anonymisable | §6.10 |
| R26 | All features present (yiic, common.php, bash aliases) | §8.3 |
| R27 | No vulnerable components | §9.3 |
| R28 | Injection protection on every field | §6.11 |
| R29 | Tables labelled by category | §5.5, App. B |
| R30 | Every feature documented + human edge-case test plan | §11, §12 |
| R31 | Docs for schema rules and container components | §12 |
| R32 | Integration tests incl. IOLM + payload processor rewrite | §8.1, §8.2, §8.5 |
| R33 | Document how everything was constructed | §12.1 |
| R34 | DevOps notes: how it works, how to troubleshoot | §12.2, §9.4 |
| R35 | Schema version-controlled; checks that it has not been altered | §5.13 |
| R36 | Fast Docker builds | §9.5 |
| R37 | Containers without security vulnerabilities | §9.3 |
| R38 | Dockerfile in a separate repo; app installable on a traditional VM | §3.2, §9.6 |
| R39 | Static analysis enforcing developer patterns (e.g. no foreach in migrations) | §6.4, App. F |
| R40 | Data models labelled with how to anonymise live data | §6.10, §5.5 |
| R41 | Something to log into as early as possible | §14 (M0) |
| R42 | arm64 Linux compatible | §9.7 |
| R43 | Tests deterministic, no false positives | §11.1, §11.2 |
| R44 | Work in chunks that fit usage-limit windows; pause/resume without waste | §10.8, §14 |
| R45 | Feature register: every function present, with tests | §4.6, §11 |
| R46 | Use the OpenEyes layout/documentation repos in discovery | §4.0 |
| R47 | Frontend up first after discovery; login page identical; early visual walk confirms; absolutely everything covered | §2, §7.4, §14 (M0a) |
| R48 | See every configurable variable and the resultant config of an instance (like `common.php`) | §6.12 |
| R49 | Secrets handled as today (env/Docker secrets), not a mandatory `.env` file | §6.12 |
| R50 | Prove the app works the same (e.g. 100 sample letters old vs new) | §7.7 |
| R51 | Concurrency testing with a modern tool and a scenario list | §11.3 |
| R52 | High-speed cutover; data shifted in parallel; minimal downtime | §5.14 |
| R53 | Three major releases a year: adaptable to high-cadence feature work | §13.1 |
| R54 | Reference data released on its own cadence with checksums and rollback | §6.13 |
| R55 | Sample databases: legacy-equivalent, fuller configuration, large complex history from stories (Playwright ported) | §6.8 |
| R56 | Blast radius obvious when a piece of code, component, table or setting changes | §6.14, §13 |

## 2. Guiding principles

- Machines read the old code; models read specs. The legacy tree is mined by scripts into JSON facts once. No LLM ever reads OpenEyes end to end (§10).
- Framework defaults are the convention. Every deviation from Laravel defaults costs tokens and review effort forever, so deviations need an ADR. Naming rules (App. A) mostly say "do what Laravel does".
- Tests are the acceptance oracle. A walk becomes a Playwright parity spec + a Pest feature test before any implementation; green means done, not "looks right".
- Schema first. The target schema is designed from measured workload (§4.4) before feature work; the app is shaped to the schema, not the reverse.
- Vertical slices. One module = models + actions + HTTP + views + factories + tests + docs in one directory, so an agent or a human can load a whole feature in one context.
- Evidence, not opinion, for deletion. Nothing is marked deprecated/obsolete without recorded proof (§4.2, §5.9).
- One image, many roles. Web, queue worker, scheduler, IOLM, payload processor and MCP are the same image with different commands.
- Absolutely everything carries over. Completeness is defined mechanically, not by feel: every legacy file dispositioned in the tracker, every feature in the register `present` or `deprecated-with-proof` with linked tests, every walk parity-green, every legacy route answering. Anything outside those four lists does not exist, so the lists are built first (Phase 0) and the frontend shell is stood up immediately after (M0a) so gaps are visible early.

## 3. Stack decisions

### 3.1 Runtime and libraries

| Component | Choice | Why / notes |
|---|---|---|
| Framework | Laravel 13.x | Released 17 Mar 2026; bug fixes to Q3 2027, security to Q1 2028. Laravel 12 bug-fix window ended 13 Aug 2026, so start on 13. Minimum PHP 8.3, supports 8.3–8.5. |
| PHP | 8.4 | Middle of the supported band; move to 8.5 once PCOV/extension coverage in the image is verified. |
| Database | MariaDB 11.8 LTS | Maintained to June 2028. Use Laravel's native `mariadb` driver. utf8mb4 + UCA 14.0.0 collations are the server default; note the 11.8 internal timestamp change for system-versioned tables (relevant to §5.6). |
| App server | Laravel Octane + FrankenPHP (worker mode) | Boots the framework once per worker; official images `dunglas/frankenphp` (project now under github.com/php/frankenphp). Worker mode requires stateless code — enforce with an arch test (§6.4) and run the browser suite against Octane in CI. |
| Cache/session/queue/locks | Redis (or Valkey) + Horizon | Required for multiple web containers; also backs `migrate --isolated`, `onOneServer` scheduler locks and rate limits. |
| Object storage | S3-compatible (MinIO/Garage/SeaweedFS on-prem) via Flysystem | No blobs in the DB (§5.7). |
| Testing | Pest 4 (unit, feature, arch, type-coverage, mutation) + Playwright (TypeScript) | Pest 4 ships Playwright-based browser testing, but the cross-app parity harness stays plain Playwright so the same specs run against Yii and Laravel. |
| Static analysis | Larastan (max level), Laravel Pint, Rector, Psalm taint analysis (CI-only), Deptrac | Deterministic feedback before any model iteration (§10.4). |
| API | Sanctum (first-party tokens) / Passport OAuth 2.1 if third parties need it, `dedoc/scramble` for OpenAPI, `spatie/laravel-query-builder`, `spatie/laravel-data` | §6.5. |
| AI tooling | `laravel/boost` (dev only), `laravel/mcp` (test-DB MCP server, §6.9) | Boost: MCP tools for schema/routes/tinker + version-specific guidelines in `.ai/guidelines`. |
| Feature flags | Laravel Pennant | Bug-fix behaviour switches and cutover toggles. |
| Perf visibility | Laravel Pulse (FOSS), OpenTelemetry PHP exporter, Prometheus | Nightwatch is SaaS; skip. |
| Docs rendering | `league/commonmark` inside a Docs module | §12. |
| Tracker mini-app | Laravel + Filament (MIT) | §4.1. |
| Rich text | `mews/purifier` (HTMLPurifier) | Only sanctioned path for unescaped output (§6.11). |

*Spike:* Octane/FrankenPHP versus plain php-fpm behind Caddy — measure p95 on the five heaviest walks on the anonymised seed DB before committing; keep the app Octane-safe either way.

### 3.2 Repositories

| Repo | Contents |
|---|---|
| `openeyes-laravel` | The application (modular monolith, §6.1), `deploy/vm/` (systemd units, Caddy/nginx samples, install notes), Playwright parity suite. Contains no Dockerfile: it must install on a plain Ubuntu 24.04 VM with composer + artisan (§9.6). |
| `openeyes-docker` | Base runtime image (PHP 8.4 + extensions), app Dockerfile, compose stacks, Helm chart, build/scan/sign pipeline (§9.1, §9.3, §9.5, §9.7). |
| `openeyes-phpstan-rules` | Custom PHPStan/Rector rules and Pest arch presets encoding the pattern rules (App. F); consumed by every PHP repo. |
| `openeyes-ui-assets` | Existing CSS/JS/images/fonts, byte-identical at first, published as an npm package (`@openeyes/ui`) with semver. Blade views live in the app; only assets live here. Rationale: independent cadence, and parity is provable by hash. |
| `openeyes-docs` | Markdown docs cloned into a documented content root and read directly by the built-in Docs feature (§12). |
| `openeyes-rewrite-tracker` | Mini-app + its DB (§4.1). |
| `openeyes-legacy-facts` | Generated JSON specs mined from Yii code, walks, and workload captures (§4.2–4.4). Read-only input for generation. |

Licensing note: OpenEyes is AGPL-3.0. Decide early whether the rewrite is a derivative work (it will reuse assets and behaviour); it changes what can be private.

## 4. Phase 0 — Inventory and instrumentation (script-driven, near-zero tokens)

Everything in this phase is produced by scripts and stored in the tracker DB and `openeyes-legacy-facts`. It is the input to schema design and to every later unit of work.

### 4.0 Knowledge sources: the OpenEyes layout repos

Before touching code, ingest the repos and sites that already describe how OpenEyes is put together (the ToukanLabs/AppertaFoundation OpenEyes core and module repos, `oe_installer`, the Docker repo, the Sample DB repo, `eyedraw`, `openeyes.github.io`, the public Confluence docs, the module wiki pages, and any internal ToukanLabs layout repos you have) into `openeyes-legacy-facts/sources/` and into your vector KB. They seed, at near-zero tokens: the module and event-type list, element inventories, the settings catalogue, integration list, glossary, and the first cut of the feature register (4.6). Rules: docs are evidence with a lower weight than code and walks (they go stale), so every fact carries its source and is confirmed by the AST facts (4.2) or a walk (4.3) before it drives design; conflicts are logged in the tracker. Nothing from these repos is pasted into model prompts — the facts are extracted by script and referenced by id.

### 4.1 Rewrite tracker mini-app

Small Laravel + Filament app on its own MariaDB 11.8 (or a schema on your dev server). Tables (full DDL in App. C):

- `legacy_files` — one row per `git ls-files` path (14k): module, kind (php-controller, php-model, php-view, js, css, bash, yiic, config, test, fixture, other), sha, loc, status (`pending`, `analysed`, `migrated`, `deprecated`, `obsolete`, `blocked`, `asset-copied`), evidence JSON, target paths, unit_id, tokens_used, pr_url.
- `legacy_tables` (2,500) and `legacy_columns` (17k) — mapping to new table/column, decision (`keep`, `rename`, `merge`, `split`, `drop`), proof JSON, category (App. B).
- `walks` — walk id, module, role, steps hash, golden artefact paths, query digest stats, status.
- `bugs` — imported bug list, linked to walks and units, fix status, `parity_exception` flag.
- `units` — units of work (§10.2): manifest, model used, tokens in/out, started/finished, PR.
- `commands` — yiic commands, cron entries, bash aliases, `common.php` keys → target artisan command/config key.
- `legacy_routes` — every Yii route (from urlManager rules + controller/action reflection) → new route, status.

Imports: CSVs from the extraction scripts (`LOAD DATA LOCAL INFILE`). Writes: a tiny HTTP API + an MCP tool (`tracker.set_status`) so Claude Code sessions can mark work done without extra tokens; a GitHub Action flips `migrated` when a PR merges with `Migrates: <path>` trailers. Dashboard: % by module, tokens per unit, bugs closed, walks green, tables mapped, deprecation-proof coverage. Definition of "rewrite complete" = every `legacy_files` row is `migrated`, `deprecated`, `obsolete`, or `asset-copied` with evidence.

### 4.2 Legacy fact extraction (AST, no LLM)

Use `nikic/php-parser` (plus a Yii 1.1 bootstrap to reflect runtime config) to emit, per file, into `openeyes-legacy-facts/`:

- Controllers/actions: routes, access rules, request params read, models touched, views rendered, JSON responses shape.
- Models: table, `rules()` (validation), `relations()`, scopes, `behaviors()`, version-table usage.
- Views: DOM inventory (elements, ids, classes, form fields, JS hooks) — obtained by rendering, not parsing (see 4.3).
- Modules: element types, event types, `common.php` and per-module config keys, yiic commands and their options, cron/`schedule` entries, bash aliases in the Docker image.
- Static reachability: PHPStan dead-code detector (`shipmonk/dead-code-detector`), `composer-unused`, a call graph, `git log -1 --format=%cd` per file.

Deprecation proof (code) is the union of: 0 hits in walk coverage (4.3), 0 static references, 0 production route hits over ≥ 90 days of access logs, last commit date. Store as `evidence` on `legacy_files`; status `obsolete` (dead) or `deprecated` (reachable but replaced by design, with the ADR/unit that replaces it).

### 4.3 Walk harness against the old app

Assumed walk shape (adapter if yours differs): `{id, module, role, preconditions:{fixture}, steps:[{action, target, value, expect}]}`. Add a generator that turns each walk into a Playwright spec, then run the whole suite against the Yii app in a controlled container to capture, per walk:

- Golden artefacts: `toMatchAriaSnapshot` DOM/ARIA snapshot, `toHaveScreenshot` per step, response bodies for XHR/JSON, network log, console errors.
- SQL workload: MariaDB `general_log=ON` (table output) with `long_query_time=0`, `log_slow_verbosity=query_plan,explain` for the slow log; walks run serially so log slices are attributable by time; also `performance_schema.events_statements_summary_by_digest`. Result: per-walk query count, digests, rows examined, EXPLAINs.
- PHP coverage: run Yii under PCOV during the walk suite; per-file "executed by any walk" flag → feeds 4.2 evidence.
- Timing: server time per step (baseline for §7.5 budgets).

Also run every yiic command and cron job under coverage with the sample DB, and capture their SQL. Result: the complete observed workload of the current system, keyed by walk/command.

### 4.4 Database workload and schema profiling

On a production-like replica (anonymised copy, §6.10) run for ≥ 90 days where possible, otherwise on the full walk suite:

- `userstat=ON` → `information_schema.TABLE_STATISTICS`, `INDEX_STATISTICS` (11.8 added QUERIES and extra columns) — rows read/changed per table, index usage → unused tables/indexes with numbers.
- Slow log with `long_query_time=0` + `log_slow_verbosity=query_plan,explain`; `pt-query-digest` (Percona Toolkit works against MariaDB logs) → ranked digests by total time, rows examined/sent ratio, filesort/temp usage.
- `sys.schema_redundant_indexes`, `sys.schema_unused_indexes`, `pt-duplicate-key-checker` → duplicate/redundant index list.
- Column profiler script per column: null %, distinct count, min/max length, sample values, type-fit (e.g. INT stored in VARCHAR, dates as text) → 17k rows in `legacy_columns.profile`.
- FK/orphan audit: declared FKs versus implied FKs (columns named `*_id` without constraint), orphan counts.
- Version tables: size, growth per month, read frequency (almost always ~0 reads) → §5.6 evidence.
- Blob audit: BLOB/TEXT columns holding files/base64/images by content sniffing → §5.7 list.
- Growth model: rows and bytes per table per year from `created_date`/`last_modified_date` histograms → §5.6/5.7 targets.

### 4.5 Bug list ingestion

Import the bug list into `bugs`; for each, link the walk(s) that exercise the behaviour (by module/screen text match, then human confirmation), mark whether the fix changes visible behaviour (`parity_exception=true`, requires a short spec) or is invisible (data/perf). Bugs become acceptance tests in the unit that owns the screen (§7.6).

### 4.6 Feature register (every function of the old system, and the tests that prove it)

- One row per function of the legacy system in `features` (tracker) with a stable id `F-<module>-<nnn>`: name, description in one paragraph, kind (screen, action, API endpoint, yiic command, cron job, setting, report/extract, integration, permission, print/letter template), legacy sources (files, routes, tables), walks that exercise it, roles that can use it, module, status (`pending`, `in-progress`, `present`, `deprecated-with-proof`), and its new unit(s).
- Built by scripts from 4.0–4.3 (controller/action reflection, routes, yiic/cron inventory, settings catalogue, walks) and then reviewed by a human once per module. Every legacy controller action, command, cron entry, setting and route must map to at least one feature or to an `obsolete/deprecated` entry with proof; unmapped items fail a tracker check.
- Test linkage: `feature_tests` links each feature to test identifiers (Pest test names, Playwright spec ids, contract/corpus tests, migration validation checks). Rule: a feature is `present` only when it has ≥ 1 automated test per kind it needs (screen → parity + feature test; endpoint → contract test; command → command test; setting → export/import round-trip) and its `test-plan.md` edge cases are listed. A CI test reads the register and fails if a merged unit claims a feature without linked tests, or if a test annotation (`#[Feature('F-exam-012')]` / Playwright tag `@F-exam-012`) references an unknown feature.
- The document itself: `docs/features/register.md` is generated from the tracker per release (feature, description, roles, walks, tests, status), plus per-module pages, so "is everything there?" is answerable by reading one page and the answer is backed by test names that exist in the repo.

Exit criteria for Phase 0: tracker populated for 100% of files/tables/columns/walks/commands/bugs; feature register drafted for every module; workload captured; golden artefacts stored; deprecation candidates listed with evidence.

## 5. Phase 1 — Target schema (highest priority)

### 5.1 Method

- Design per bounded context: core (patients, episodes, events, users, institutions/sites/firms, settings, audit) first, then one context per OpenEyes module. Each context is a design packet: legacy tables in scope, workload digests that touch them (from 4.3/4.4), the walks that read them, target DDL, read-model decisions, and the mapping rows in `legacy_tables`/`legacy_columns`.
- Migrations are the schema source of truth (`php artisan schema:dump` per release for fast test setup); ERDs and `docs/schema/tables/*.md` are generated from the live schema, never hand-maintained.
- Every design packet closes with the schema lint suite (5.12) green and a token-cheap review: a human reads the packet, not the DDL.

### 5.2 Structural rules (details in App. A)

- Laravel defaults everywhere they exist: snake_case plural tables, `id BIGINT UNSIGNED` PK, `<singular>_id` FKs, `created_at`/`updated_at`, Laravel's default index/FK names. Module-owned tables carry a short registered prefix (`exam_`, `opbook_`, …), never the legacy `et_ophci…` forms.
- Public identifiers: `uuid` (ordered v7 via `HasUuids`) on entities exposed by the API or files (patients, events, documents); integer PKs stay internal. Prevents enumeration and survives multi-container generation.
- Types by profile: right-size VARCHAR from column profiles; INT-in-VARCHAR fixed; dates as DATE/DATETIME; no MySQL ENUM (lookup table or PHP enum backed by VARCHAR(32)); JSON only for read models, device payload snapshots and EyeDraw, with `CHECK (JSON_VALID(col))`; no BLOB outside the allowlist (5.7).
- Every `*_id` column has a real FK (`ON DELETE RESTRICT` default; cascade only for pure children such as element rows of an event). Every FK column is indexed.
- `institution_id` on all `patient`, `clinical` and `config` tables: multi-tenancy today, shard key later. `created_by`/`updated_by` (nullable FK `users`) on `patient`/`clinical`/`config`. No soft deletes on clinical data — use `voided_at` + reason.
- utf8mb4 / `utf8mb4_uca1400_ai_ci` set explicitly in `config/database.php`; InnoDB DYNAMIC; `PAGE_COMPRESSED=1` for history and archive tables.

### 5.3 Normalisation and retrieval patterns

- Write model in 3NF/BCNF; each deliberate denormalisation (e.g. `patient_id` on `events`, avoiding the episode hop) needs an ADR and an invariant test.
- The event/element pattern stays one table per element type (that is normalised). Two smells to evaluate per module (*spike* on the three largest modules): (a) split-eye elements storing `left_*`/`right_*` column pairs → child rows keyed by `side`; (b) hundreds of tiny per-module lookup tables → keep as separate FK-typed tables but generate them from one migration helper with standard columns (`id, code, name, display_order, is_active`) so they cost nothing to maintain.
- Retrieval-driven design: for each of the top ~100 digests and each walk with > 20 queries today, write the target access path (table + index + expected plan) into the design packet. Typical OpenEyes hot paths: patient search, patient overview (episodes/events list), event view (all elements), worklists/clinic lists, correspondence, audit views.
- Read models (CQRS-lite) only where measured: `event_summaries` (per event: type, date, subspecialty, one-line summary, flags — makes patient overview 1–2 queries), a patient search table (normalised tokens + hospital/NHS numbers), worklist projections. Maintained by the same Action that writes the source rows, rebuildable via `oe:readmodel:rebuild <name>`, covered by consistency tests.
- Query budget baked into the schema packet: ≤ 12 queries per full page, ≤ 5 per XHR, list pages = 1 main query + ≤ 3 lookup queries; anything above needs an ADR (§7.5 enforces).

### 5.4 Indexing

- Composite indexes derived from digests (leftmost-prefix rule; equality columns first, then range, then order-by), covering indexes for the top list pages, FULLTEXT only where a spike shows it beats plain indexes for patient search.
- Duplicate/redundant removal: lint from `information_schema.STATISTICS` (an index whose columns are a leftmost prefix of another is redundant) + `sys.schema_redundant_indexes` on the loaded seed. Before dropping anything inherited, mark it `IGNORED` (MariaDB ≥ 10.6) for a cycle and watch `INDEX_STATISTICS`.
- Index budget: ≤ 6 secondary indexes per table unless justified in the packet (write amplification on clinical tables).

### 5.5 Table categories and column classification (App. B)

- Every table declares one category in a machine-readable table comment (`cat=clinical; owner=exam; retention=nhs-adult; versioned=yes`) via a migration macro, and the model carries the matching `#[TableCategory]` attribute; a schema test asserts both exist and agree.
- Every column carries a data class in its comment where relevant (`class=pii|phi|secret|free_text|identifier`). The anonymiser (§6.10), the config exporter (§6.7) and the docs generator all read this registry; nothing is hand-listed twice.
- Truncation/reset tooling refuses `system`; seeders may reset `operational` and `integration`; `config`/`reference`/`identity` are the export bundle; `patient`/`clinical`/`audit` are the anonymisation scope and archiving scope.

### 5.6 Versioning without unbounded growth

Today: shadow `_version` tables for almost everything, written on every save, almost never read (verify with 4.4). Options:

- A. MariaDB system-versioned tables (`WITH SYSTEM VERSIONING`) with `AS OF` queries, per-column exclusion (`WITHOUT SYSTEM VERSIONING` on large text/JSON columns), history partitioned by `SYSTEM_TIME INTERVAL 1 YEAR` for cheap pruning. Caveats to *spike* on the ten largest clinical tables: partitioned tables cannot have foreign keys in MariaDB (so partitioned history means no FKs on that table), referential-action limits on versioned tables, the 11.8 timestamp representation change, write overhead, and whether legacy `_version` rows can be back-loaded (`system_versioning_insert_history`, verify on 11.8).
- B. One append-only `audit_changes` table (JSON diff, actor, reason, request id) written by an Eloquent observer; partitioned by month; ideal for "who changed what", weak for "table as of".
- C. Generated per-table history tables like today, partitioned by month, no FKs on history.

Recommendation: A for an explicit list of `patient`/`clinical` tables where medico-legal reconstruction matters (unpartitioned + `DELETE HISTORY BEFORE SYSTEM_TIME` if the spike shows FKs must stay), B for `config`/`identity`, none for `reference`/`system`/`operational`. Never version blob-ish or free-text narrative columns: narrative goes into an append-only `notes`/`revisions` table (rows never change, so nothing to version). Retention per policy (configurable years), pruned by a scheduled job, history/current size ratio charted in Pulse with an alert.

### 5.7 No blobs in the database

- `documents` table (metadata only: `uuid, storage_key, sha256, bytes, mime, kind, patient_id, event_id, retention_class, scanned_at`) + object storage via Flysystem S3; content-addressed keys; served through the app with authorisation (signed URLs only for short-lived internal use); ClamAV on ingest (your existing setup); dedupe by hash; derived thumbnails/PDF renders are their own objects.
- Allowlist of columns that may hold binary/base64: empty by default; anything found in the 4.4 blob audit gets a migration job that extracts to the bucket and verifies sha256 in the migration report.
- Bucket layout by category and year (`clinical/2026/…`) so archive tiering (5.8) is a prefix move.

### 5.8 Growth control: archiving and retention

- Retention classes (`nhs-adult`, `nhs-child`, `nhs-deceased`, `admin`) as configuration, defaults from the NHS Records Management Code of Practice; never hard-coded.
- Tiering: hot (active) → warm (patients with no activity for N years: rows moved to `archive_*` tables in the same schema — same DDL, `PAGE_COMPRESSED=1`, no versioning, still queryable and restorable by `oe:archive:restore <patient>`) → cold (exported as encrypted NDJSON + object manifest to the bucket, then deleted after retention). Every move logged in `archive_log`.
- Archiving is per patient graph (patient → episodes → events → elements → documents), driven by the schema registry (categories + FKs), so a new element type is archived without new code.
- Growth budget per category charted; alert when `clinical` grows > x% per quarter beyond the model from 4.4.

### 5.9 Config and reference data separation

- Natural keys (`code`/`key`) on all `config`/`reference`/`identity` tables; surrogate ids stay internal. Cross-references between config tables resolve by natural key on import.
- Settings normalised: `setting_definitions` (key, type, default, allowed values, scope levels) + `setting_values` (definition, scope type/id: installation/institution/site/firm/user, value). Environment/infrastructure config (DB, Redis, storage, mail) stays in `.env`/`config/*.php`; institution behaviour lives in the DB.

### 5.10 Deprecating schema items with proof

For every legacy table/column not carried forward, `legacy_columns.proof` holds `{userstat_rows_read_90d, userstat_rows_changed_90d, walk_query_hits, code_refs, row_count, non_null_pct, distinct_values, last_write_at}` and the decision (`drop`, `merge-into`, `superseded-by`). `docs/schema/dropped.md` is generated from that. If the legacy DB keeps running for a period, tag its objects `COMMENT='[deprecated proof=tracker:legacy_columns:<id>]'`. The new schema never contains deprecated items.

### 5.11 Migration engine, validation, cutover, drop-in replacement

Engine (a `Migration` module of artisan commands, excluded from the production image or behind a flag):

- Extract: `mariadb-dump --tab` / `SELECT … INTO OUTFILE` per legacy table into a staging area; Transform: set-based SQL in an `oe_stage` schema (PHP streaming only where SQL cannot express it); Load: `LOAD DATA LOCAL INFILE` into the new schema with FK checks off and secondary indexes deferred (your bulk-restore runbook), then index rebuild, FK enable, read-model rebuild, blob extraction to bucket. Every step writes counts and durations to `migration_runs`.
- Incremental mode via `last_modified_date`/id watermarks so rehearsals stay warm and the final delta is minutes; small tables reload fully.

Validation (`oe:migrate:validate`, HTML report into the tracker; gate = zero unexplained differences):

- Row counts per mapping expression; column checksums (CRC32/MD5 over normalised values ordered by natural key, chunked); FK/orphan zero-checks; invariants (every event has patient and episode; per-event element counts equal legacy); value-domain checks (all legacy codes resolved to new lookups); sample deep-diff of N random patients between a legacy projection and the new API; blob manifest (object exists, sha256 matches, bytes match); walk parity on migrated data for a sample of real (anonymised) patients.

Cutover and drop-in:

- Compatibility contract documented and tested: same hostnames/paths (generated legacy route table → new routes, 301 or direct), same env var names via a `config/openeyes.php` shim, same ports, `/up` health, same integration entry points (HL7/PAS, IOLM folders, payload endpoints). CI test: every URL seen in 90 days of access logs returns 200/301/403 on the new stack.
- ≥ 3 full rehearsals on the anonymised copy; measure and parallelise by table group until the run fits the agreed window (the high-speed design is §5.14).
- Optional dark launch: mirror read-only production traffic to the new stack (kept current by incremental ETL) and diff HTML text/JSON responses — parity evidence from real usage, inside the trust boundary.
- Cutover: legacy in read-only maintenance → final delta → validate → flip ingress → keep legacy warm for T hours. Decide and publish the rollback policy for writes made during T (reverse ETL for a short allowlist of tables, or manual re-entry). Pennant flags let bug-fix behaviour be enabled per institution during bedding-in.

### 5.12 Deliverables, tests, spikes

- Deliverables: migrations + `schema:dump`, generated ERD (Mermaid) and `docs/schema/tables/*.md`, `docs/schema/rules.md`, ADRs (versioning, read models, split-eye elements, lookups, ids), mapping CSVs, dropped.md.
- Schema lint (Pest, runs on the migrated test DB): naming regexes; every table has a category and model attribute; every column classified; every `*_id` has FK and index; no duplicate/redundant indexes; no ENUM/BLOB outside allowlists; every `clinical`/`patient` table has `institution_id`; every versioned table is on the explicit list; charset/collation uniform.
- Spikes before freezing core: system-versioning + FK/partition behaviour; split-eye normalisation cost; patient search index vs FULLTEXT vs Meilisearch; JSON read-model write cost; Octane vs php-fpm.

### 5.13 Schema version control and tamper/drift checks

- Versioned artefacts per release: migrations, `database/schema/mariadb-schema.sql` (`schema:dump`), `database/schema/fingerprint.json`, and `database/migrations.lock` (filename → sha256 for every migration ever merged to `main`).
- Fingerprint: `oe:schema:fingerprint` normalises `Schema::getTables/getColumns/getIndexes/getForeignKeys` plus `SHOW CREATE TABLE` (AUTO_INCREMENT values stripped, keys sorted, rotating `SYSTEM_TIME` partition lists reduced to the partition scheme) into canonical JSON and hashes it. The committed value changes only in a PR that also contains the migration; CI runs `migrate:fresh` on both architectures and fails if the live fingerprint differs from the committed one, or if `schema:dump` output differs from the committed dump.
- Immutability: CI fails if any migration listed in `migrations.lock` has a hash different from the recorded one — released migrations are never edited, fixes are new migrations. Squashing is allowed only at documented schema reset points before v1.0.
- Runtime: `oe:schema:verify` compares the live DB with the fingerprint recorded for `APP_VERSION` (also stored in `schema_fingerprints`); it runs in the Kubernetes startup probe, hourly from the scheduler, and inside `oe:doctor` (§12.2). On mismatch, `OE_SCHEMA_STRICT=true` (production default) puts the app into maintenance mode with a clear message and raises an alert; `false` logs and continues (dev).
- Privilege separation: the runtime DB user has DML only (`SELECT, INSERT, UPDATE, DELETE, EXECUTE`); the migration Job uses a separate DDL user; nobody holds interactive DDL rights on production outside a logged break-glass procedure.
- DDL audit: MariaDB Server Audit plugin with `server_audit_events=QUERY_DDL` shipped to the log pipeline; alert on DDL outside a migration Job window. Policy: no manual DDL, ever; anything done under break-glass is codified as a migration within 24 h and the fingerprint re-baselined by PR.

### 5.14 High-speed cutover (minutes, not hours)

Clients will not accept a long outage, so the design target is write-unavailability ≤ 15 minutes and a total window ≤ 1 hour per client instance (*guess*, proven in rehearsal), with reads still served by the read-only legacy app throughout.

- Everything possible happens before the window: (1) parallel bulk load of the full history days ahead using mydumper/myloader or per-table `SELECT INTO OUTFILE` → `LOAD DATA LOCAL INFILE`, N workers partitioned by table group and by patient-id range for the big clinical tables (your bulk-load tuning: FK/unique checks off, indexes deferred, safety-off InnoDB during load, then rebuilt); (2) blob extraction to object storage ahead of time (content-addressed, so re-runs only add new objects); (3) read models and indexes built, buffer pool warmed (`innodb_buffer_pool_dump/load`), config bundle imported; (4) continuous catch-up: incremental ETL every few minutes from watermarks (`last_modified_date`/max id) or, for tables without reliable timestamps, from the legacy binlog — a dedicated replica of legacy for change capture with a small CDC reader per table group turning row events into staging upserts — so the delta at freeze time is minutes of change.
- The window itself: legacy into read-only maintenance → capture binlog position/watermark → final delta with the same parallel workers → fast validation tier (row counts per table, checksums over the delta rows, invariants on touched patients, FK/orphan checks) → flip ingress → new stack live. Full checksums run afterwards as background reconciliation with a report; a discrepancy found later is fixed by a targeted repair job, not by rolling back.
- Parallelism rules: workers per table group sized to the target DB's write capacity in rehearsal; the delta pipeline is idempotent (upsert by natural/legacy key) so it can be re-run; throughput per worker and remaining delta visible in the tracker (`migration_runs`) live during the window.
- Rollback: legacy stays warm read-only for T hours; new-app writes during T are captured from the new DB's binlog so a reverse delta for an allowlist of tables is possible if rollback is ever ordered — the decision criteria are written before the window.
- Per-client cadence: each client instance is cut over independently with the same runbook; rehearsals on the client's own anonymised data set the timings; a go/no-go checklist with measured numbers replaces estimates.

## 6. Phase 2 — Application skeleton and conventions

### 6.1 Structure: modular monolith

```
app/                      # thin: kernel wiring only
modules/core/<Module>/    # first-party modules released as application source
modules/custom/<Module>/  # optional image-time clones or Git submodules
  Actions/                # one class per use case (Create*, Update*, Void*, Export*)
  Models/                 # Eloquent, #[TableCategory], explicit casts/relations
  Data/                   # spatie/laravel-data DTOs used by web + API + MCP
  Http/{Controllers,Requests,Resources}
  Views/                  # Blade, DOM identical to legacy
  Database/{Migrations,Factories,Seeders,seed-csv/}
  Console/                # artisan commands replacing yiic
  Tests/{Unit,Feature,Arch}
  module.json             # name, prefix, owner, legacy module ids
```

Module boundaries are enforced by Deptrac (a module may depend on `Core` and its own namespace only; cross-module calls go through published Actions/DTOs). Element and event types register through a `Core` registry (attribute-based discovery, cached), replacing the Yii module config. Modules use the application-owned `module.json` loader, not Composer package discovery. Duplicate codes, namespaces and attempts by `modules/custom` to replace a core module fail at startup.

Module PHP namespaces map directly from the module root. Do not add a `src` directory.

### 6.2 AI-friendly segmentation

- ≤ 300 lines per file, one class per file, no magic (no dynamic class resolution, no macros/mixins in modules, explicit relation return types for Larastan generics).
- Path predictability: given a feature name, the file locations are derivable (Action → Request → Resource → View → Factory → Test → docs).
- Root `CLAUDE.md` ≤ 150 lines pointing to `.ai/guidelines` (Boost-managed) and to the docs index; per-module `README.md` ≤ 60 lines. Frozen per phase (§10.4).
- A generated `docs/index.json` (feature → files → tests → docs) that Boost/your vector KB can serve; agents fetch by feature, never by directory scan.

### 6.3 Coding standards

- Keep the current OpenEyes phpcs ruleset (PSR-12 base) expressed as Pint config plus phpcs for the rules Pint cannot express; Larastan level max with a baseline of zero; strict types in every file; final classes by default; PHP enums for closed sets; readonly DTOs. Any legacy convention that conflicts with a Laravel default is decided once in an ADR (App. A).

### 6.4 Rule enforcement (naming, patterns, safety)

- Pest architecture tests: suffixes/namespaces (`*Action`, `*Request`, `*Resource`, `*Factory`, `*Test`), every Model has a Factory and a `#[TableCategory]`, every controller method type-hints a FormRequest or takes only route bindings, no `dd/dump/env()` outside config, no `DB::raw`/`whereRaw` outside `Core\Database\Raw` (arch `not->toUse`), no static mutable state (Octane safety), models never used from views.
- Deptrac layers; PHPStan custom rules for the few things arch tests cannot see (interpolated SQL strings, unescaped Blade). Psalm taint analysis in a nightly job.
- Naming lint for DB (5.12) and for routes/API (`kebab-case` paths, canonical unversioned `/api`, resource nouns).
- Project-specific pattern rules live in `openeyes-phpstan-rules` (App. F): each rule has an id (`OE-MIG-001`), a one-line message ending in a docs URL, a rationale page with good/bad examples, and its own tests. No PHPStan baseline files are permitted, so the violation count on `main` is always zero; new rules land with the code that satisfies them.
- Everything above runs in the pre-commit hook and CI; failures are cheap, deterministic feedback (§10.4).

### 6.5 API-first

- Every capability is an Action; web controllers and `/api` controllers both call Actions and return either a Blade view or an API Resource. No logic in controllers.
- OpenAPI generated by Scramble on every build, published in the Docs module; contract tests validate responses against the spec. Bulk exports as NDJSON streams (patients, events, audit) for research/reporting; FHIR R4 mapping deferred to a later phase unless a customer requires it.
- Auth: Sanctum tokens for first-party/API clients; Passport OAuth 2.1 only if third parties need it. Rate limits per token.

### 6.6 Factories for everything

- Every model gets a factory generated from the schema registry (types → faker), then hand-tuned states for clinical scenarios. Above model factories: scenario builders (`PatientWithCataractPathway::make()`, `ClinicWithWorklist::make()`) reused by feature tests, seeders, the MCP server and Playwright fixtures. Arch test: model without factory fails CI.

### 6.7 Config export/import

- `oe:config:export --out=dir` writes one CSV per `config`/`reference`/`identity` table (natural keys, deterministic order) plus `manifest.json` (app version, schema version, source institution, checksums). `oe:config:import dir --dry-run` prints the diff, then upserts idempotently. Runs on both directions of the cutover and for standing up new institutions.

### 6.8 Sample databases: profiles, stories, seeds per version

- `oe:seed:build --version=vX --profile=<name> --settings=uk-nhs,demo-institution [--stories=all|<set> --scale=N]` → applies migrations, loads chosen `seed-csv/` sets with `LOAD DATA LOCAL INFILE`, runs the profile's generators, rebuilds read models, verifies invariants, produces `seed-vX-<profile>.sql.zst` (CI artefact per tag, restorable in seconds; also what the MCP server hands out, §6.9). CSV sets are versioned with the app; the manifest records which sets, stories and seed value built a database, so any profile is reproducible.
- Profiles:
  - `minimal` — reference data, one institution/site/firm, a handful of users; unit and feature tests.
  - `sample-legacy` — content-equivalent to today's OpenEyes sample database, produced by running the migration engine (§5.11) over the legacy sample DB. It doubles as a permanent migration test fixture and is the dataset the parity walks and the equivalence corpus (§7.7) run on, so "same as the current sample" is proven by the validator rather than assumed.
  - `config-full` — every configurable option exercised: several institutions/sites/firms, all subspecialties and event types enabled, worklists, letter templates and macros, IOL sets, roles/permissions, integrations switched on; used for config export/import round-trips, admin screens and demos.
  - `history-large` — thousands of patients with multi-year, multi-episode histories generated from stories at a chosen scale; used for perf, soak and concurrency (§11.3), archiving and read-model tests.
- Stories: your existing story repo becomes the source of the complex histories. Each story is expressed once in a portable format (YAML/PHP: actors, timeline steps, expected outcomes) and executed by a story runner through Actions/API with a stepped test clock (`Carbon::setTestNow` per step, so timestamps reflect the history) and seeded randomness — that is how `history-large` is built fast and deterministically. The Playwright versions of the stories are ported incrementally as UI walks (§4.3 format) and run against a subset per release to prove the UI path produces the same outcome as the runner; every story's expected outcomes become invariant tests reused by validation. Porting is tracked as units in the tracker with the story id.

### 6.9 MCP test-database server

- `laravel/mcp` server registered in `routes/ai.php`, local transport (`Mcp::local`) for Claude Code and HTTP + Sanctum for CI. Tools: `create_test_database(version, profile, settings[], stories?, scale?)` for any profile in §6.8, `seed_settings_from_csv(dir)`, `generate_patients(n, scenario)`, `snapshot(name)`, `restore(name)`, `anonymise_from_dump(path)`, `describe_schema(table?)`, `run_walk(id)`. Same code paths as the artisan commands, so tests cover both. Tested with the MCP Inspector and Pest.

### 6.10 Anonymisation

- Registry-driven (5.5): `oe:anonymise` walks every `pii`/`phi`/`identifier` column with deterministic pseudonymisation (HMAC with a per-run key) so joins and lookups stay consistent; free text is the hard part — regex/dictionary redaction (NHS numbers, dates, names from the patient table) first, optional local-LLM pass on your GPU box for narrative fields, and a verification sample gate. Runs only on copies (from `mariadb-backup`/dump), never in place on production. The anonymised snapshot is the only data developers, CI, Claude and the tracker ever see.
- Models are the labels: every model in the `patient`, `clinical`, `identity`, `audit`, `operational` and `integration` categories declares `public static function anonymisation(): AnonymisationMap` with one strategy per column — `keep`, `null`, `hash` (HMAC, deterministic), `fake:<kind>` (name, address, postcode, phone, email, nhs_number, hospital_number), `date_shift` (constant offset per patient so intervals survive), `redact_free_text`, `drop_row`. Column comments (`class=…`) and the model map must agree (arch test); every `pii/phi/free_text/identifier` column must have a strategy; a new column without one fails CI (OE-MOD-004). `docs/schema/anonymisation.md` is generated from the maps, and `oe:anonymise --plan` prints the per-table plan before touching data.

### 6.11 Injection protection on every field

- FormRequest for every mutating and every parameterised read endpoint (arch-enforced); Eloquent/Query Builder bindings only (`DB::raw` confined to `Core\Database\Raw` with tests); Blade `{{ }}` everywhere, `{!! !!}` only through a purifier component (PHPStan rule); CSP with nonces, `SameSite`, secure cookies; file uploads: MIME sniffing, size limits, ClamAV, stored in the bucket not the web root; shell-outs via Symfony Process with argument arrays; `LOAD DATA` paths allowlisted; Psalm taint nightly; OWASP ZAP baseline against the test container weekly.

### 6.12 Configuration visibility and secrets

- Every configurable variable is declared once, with metadata: infrastructure/env-level variables in `config/openeyes/*.php` (each key with a docblock: purpose, type, default, example, `secret: true|false`, since-version) and institution-level settings in `setting_definitions` (§5.9). A lint fails on any `env()` call or setting key that lacks a declaration, so the catalogue cannot drift from the code.
- `docs/configuration/reference.md` is generated from those declarations: every env var and setting, default, type, description, which role reads it — the equivalent of reading `common.php` today, but complete and always current.
- Resultant config for a running instance: `php artisan oe:config:show [--json] [--scope=institution:X --scope=site:Y]` prints the effective value of every variable with its source (default → config file → environment → `_FILE` secret → DB setting at each scope) — secrets redacted to their source ("set from `DB_PASSWORD_FILE`"). The same view is available read-only in the admin UI (`/admin/config`) and as `/api/system/config` for tooling; `oe:config:diff <instance-export>` compares two instances. This replaces "read `common.php` on the box".
- Secrets: handled as today — real environment variables and Docker/Kubernetes secrets mounted as files. Laravel does not need a `.env` file when the variables are present in the process environment; a small bootstrap loader (before config load) resolves the `*_FILE` convention (`DB_PASSWORD_FILE=/run/secrets/db_password` → `DB_PASSWORD`) so compose secrets, Kubernetes secret mounts and the VM path (`/etc/openeyes/secrets/*` or systemd `EnvironmentFile=`) all work unchanged. `.env` exists only for local development and is never baked into images or committed; `config:cache` is run at container start (not build) so it captures the mounted values; `oe:doctor` reports which secrets are set and from where without printing them.

### 6.13 Reference-data release pipeline (own cadence, checksums, rollback)

- `reference` tables (5.5) are fed by a pipeline separate from app releases: `oe:refdata:import <set>@<version> --from=<file|url> [--dry-run]` for dm+d (weekly, TRUD), SNOMED CT UK subsets (TRUD, licence recorded), drug and formulary sets, IOL catalogues (manufacturer CSVs), procedure/lookup sets, postcode/organisation data. Each import is staged into `refdata_releases` (set, version, source checksum, row counts, importer version), validated (natural keys unique, every code referenced by clinical rows still present or explicitly mapped, no orphaning of settings that point at codes), then activated transactionally by flipping the active version; the previous version stays for one-command rollback.
- Compatibility matrix: each set declares the app schema versions it supports; the importer refuses mismatches; CI imports a fixture subset of every set on every build and the full sets nightly.
- Per-institution optionality where the sets allow it (formularies, IOL inventories) via the config bundle (§6.7); provenance (source, licence, version, checksum) shown in the admin UI and generated into `docs/configuration/reference-data.md`.

### 6.14 Blast radius: the impact map

- One graph, generated, always current: nodes = modules, files, classes, Actions, routes/API endpoints, Blade components, JS assets, tables/columns, settings, feature-register ids, walks, tests, docs pages; edges from static analysis (PHPStan/Deptrac import graph, route → controller → Action → model → table, Blade component usage, `#[Feature]`/`@F-` annotations, setting reads), from the schema (FK graph via recursive CTE, read models and anonymiser/archiver/exporter readers per table), and from dynamic evidence (per-test file coverage from PCOV, per-walk route/table capture as in §4.3 but on the new app, regenerated nightly so it cannot go stale).
- `oe:impact <file|class|table|column|setting|component|feature>` prints the blast radius: affected modules and features, walks and tests to run, tables/endpoints/docs touched, consumers of a table (exports, anonymiser, archiver, IOLM/payload), and a risk grade (clinical table, PII, public API, shared component). The same report is posted by a PR bot on every pull request from the diff, and the schema fingerprint diff (5.13) feeds it for migrations.
- Uses beyond visibility: test-impact selection (PR pipelines run the affected tests and walks first, the full suite still runs nightly), CODEOWNERS derived from module ownership, and a token saver — Claude Code sessions read `oe:impact` output instead of exploring (§10.4).
- Guardrails: a change whose impact report is empty for a non-trivial diff fails the bot check (the map is broken, not the change); the map's own coverage is measured (share of files with at least one edge) and reported in the tracker.

## 7. Phase 3 — Feature migration loop (TDD from walks)

### 7.1 The unit loop

A unit = one feature slice (an element type, a screen, a command, an API resource) defined in the tracker with a manifest (§10.2). Order inside a unit, always:

1. Scripts pre-generate: Playwright parity spec from the walk(s) with golden artefacts (§4.3); a Pest feature test skeleton replaying the same HTTP steps with DB assertions and a query budget; FormRequest rule skeleton mapped from the Yii `rules()` facts; factory/resource/docs stubs.
2. Red: the tests fail against the empty module.
3. Green: implement Action, model, request, resource, view. Run only the affected tests (`pest --dirty`/`--filter`, one Playwright spec).
4. Parity: run the spec against the new app; DOM/ARIA snapshot and text must match the golden artefacts except for approved `parity_exception` bugs (§7.6).
5. Budget: query count and server time within limits (§7.5).
6. Docs: `overview.md`/`behaviour.md`/`api.md`/`test-plan.md` filled (§12); tracker updated; PR with trailers.

Core first (auth/roles, institutions/sites/firms, patients, episodes, events, settings, audit, worklists), then modules by production traffic weight (from access logs), then long tail. Modules that share elements (Examination) are split into many small units.

### 7.2 Playwright parity harness

- One TypeScript suite runs against both apps via `BASE_URL`; fixtures come from the seed profile + factories (through the MCP server or an artisan endpoint enabled in `testing`).
- Assertions per step: `toMatchAriaSnapshot` (structure), text content of the main container, `toHaveScreenshot` with a per-walk tolerance (fonts/antialiasing), zero console errors, XHR JSON bodies (keys sorted, volatile fields masked), response status. Golden artefacts are versioned with the walk id and legacy app version.
- Sharded in CI (5–10 runners), retries = 0 (flakes are bugs), Octane server under test.
- Pest 4 browser plugin is optional for in-repo smoke tests; the parity suite stays framework-agnostic so it can keep running against legacy until decommission.

### 7.3 Pest tests per unit

- Unit tests for Actions/DTOs/domain rules; feature tests for web + API (same Action, both surfaces); arch tests (§6.4); factory tests (every factory + state builds and persists); consistency tests for read models; migration validation tests for the unit's tables. Mutation testing (`pest --mutate`) on Actions with a minimum score; 100 % type coverage.

### 7.4 Frontend: identical by construction

- Order of work: the unauthenticated login page and the authenticated shell (header, nav, footer, patient banner) come first, before any feature — they are the visual contract every other page inherits (§14, M0a).
- Assets from `openeyes-ui-assets` (§3.2), byte-identical initially, served by Vite with hashed filenames and immutable cache headers. Blade views/components reproduce the legacy DOM (ids, classes, data attributes, form names) so the existing JS keeps working untouched. Any DOM difference must be an approved bug/UX exception; the parity suite is the proof.
- Later, optional: split legacy JS into ES modules and add tests, without changing behaviour — a separate track after cutover.

### 7.5 Performance budgets

- Server: ≤ 12 queries per full page, ≤ 5 per XHR, p95 server time on the perf seed ≤ 300 ms for the 20 heaviest walks (baseline from §4.3). Enforced with `expectsDatabaseQueryCount()` in feature tests, `Model::preventLazyLoading()`/`shouldBeStrict()` outside production, and a `testing`-only `X-Query-Count`/`Server-Timing` header read by Playwright.
- Rendering: Octane worker mode, response compression and HTTP/2 from Caddy, fragment caching for reference-only fragments, cached lookup tables (`Cache::remember` with invalidation on config import), read models for list pages, no Livewire (extra round trips).
- Client: Lighthouse CI on the ten most-used pages with budgets (LCP, TBT), asset budgets per page; comparison against legacy baseline is part of the parity report.

### 7.6 Bugs and UX exceptions

- Every imported bug is attached to a unit; the fix is a test first (regression) and, if behaviour changes visibly, a `parity_exception` on the affected walk with a one-paragraph spec signed off in the tracker. "Old app felt awful" changes follow the same path (spec → sign-off → tests → parity exception). Bugs that are pure data/perf close via validation or budget tests. Pennant flags for fixes that institutions must opt into.

### 7.7 Proving the app works the same: the output-equivalence corpus

- The same anonymised dataset is loaded into a legacy instance and the new stack (the migration engine provides it). For every artefact type the old app produces, an equivalence set is generated on both sides by driving the same walks/API and compared by a type-specific comparator: letters and other PDFs (≥ 100 per letter-template family, stratified by site/subspecialty/template — text-layer diff after normalising dates/ids, plus per-page raster diff with an explicit pixel-ratio threshold, fonts pinned on both sides); prescriptions, labels and printed forms; extract/report CSVs (NOD audit extracts and the rest: cell by cell); outbound HL7 messages (segment/field-normalised); emails/notifications (rendered text); API JSON (sorted keys, masked volatile fields); worklists/clinic lists and search results (row sets and ordering); audit entries produced per action (count and shape).
- Corpus sizes: minimum 100 items per artefact family, or the whole population when smaller; a recorded random seed makes the corpus reproducible; the corpus is versioned against the legacy app version that rendered it.
- Pass criteria: zero unexplained differences. Every allowed difference is a bug id or a UX exception recorded per artefact type (e.g. "letter footer date format → BUG-123"), so nothing hides inside a tolerance; every comparator must fail on a known-different pair (canary, §11.2).
- Runs: on the pilot module first (letters are the natural start), then nightly for migrated modules, and as a cutover gate on rehearsal data; results in the tracker (`equivalence_runs`) with side-by-side diffs.

## 8. Phase 4 — Integrations and everything outside the web UI

### 8.1 IOLM (IOLMaster biometry import)

- Rewrite as a worker role of the same image: a watcher/ingest command (`oe:iolm:ingest`) or HTTP receiver, parsing device exports (XML/DICOM as today — inventory the exact formats and drop folders in Phase 0) into `integration` staging tables, patient matching rules as a tested Action, then the same `CreateBiometryEvent` Action the UI uses. Idempotency by payload hash; quarantine table for unmatched payloads with an admin screen; metrics on `imported/quarantined/failed`.
- Contract tests from a corpus of anonymised real payloads with golden outputs; property tests for the parser.

### 8.2 Payload processor

- Same shape: receiver (queue consumer or HTTP) → staging → validate/transform → domain Actions; each payload type is a class with schema validation and a golden corpus. Rewritten containers keep the same external contract (endpoints, folders, ack semantics) documented in the compatibility contract (§5.11).

### 8.3 yiic commands, `common.php`, cron, bash aliases

- Every yiic command from the inventory (§4.2) becomes `oe:<module>:<verb-noun>` with the same behaviour and a test; a `bin/oe` wrapper and `/etc/profile.d/openeyes.sh` in the image reproduce the aliases (`oe-migrate`, `oe-update`, …) mapped onto artisan. Cron becomes the Laravel scheduler (`onOneServer`, `withoutOverlapping`). `common.php` keys map to `config/openeyes/*.php` (infra) or settings tables (institution); the tracker holds key → target.

### 8.4 Other external interfaces

- Inventory in Phase 0: PAS/HL7 feeds, printing, email/SMS, DesktopAppLauncher/FORUM URL protocols, reporting extracts (NOD audit extracts you already specified), OpenImage. Each gets a contract test and an owner before cutover.

### 8.5 Integration test rig

- Docker Compose (and the same in CI): MariaDB 11.8, Redis, MinIO, app web, worker(s), IOLM ingest, payload processor, a fake device/PAS emitter that replays the anonymised corpus. Assertions: events appear via API, audit rows exist, objects exist in the bucket, metrics move. Nightly against the perf seed.

## 9. Phase 5 — Infrastructure

### 9.1 Docker image

- Lives in `openeyes-docker` (§3.2), not in the app repo. Two images: `openeyes-base` (`dunglas/frankenphp:1-php8.4-alpine` pinned by digest + only the required extensions: pdo_mysql, intl, bcmath, pcntl, redis, zip, opcache, gd/imagick if needed; rebuilt weekly and on CVE) and `openeyes-app` (`FROM openeyes-base` + vendor + built `@openeyes/ui` assets + `php artisan optimize`). Non-root user, read-only root filesystem with `tmpfs` for `storage/framework`, healthcheck `/up`, no composer/node/compilers/package manager binaries in the final image, `.env` never baked. Target < 150 MB (*guess*; the static-binary route can go smaller but limits extensions — spike). CI fails on size regression > 10 %.
- One image, roles by command: web (`octane:frankenphp`), horizon, scheduler (`schedule:work`), `oe:iolm:ingest`, payload processor, MCP server, one-off migration Job.

### 9.2 Kubernetes and scale

- Stateless web (Redis sessions/cache), HPA on RPS/CPU; Horizon workers scaled by queue depth (KEDA); scheduler single replica or CronJob; migrations as a pre-deploy Job (`migrate --force --isolated`); Helm chart in `openeyes-docker`; ConfigMaps for non-secret config, Secrets for keys; JSON logs to stdout; PodDisruptionBudgets; rolling deploys with `/up` readiness.
- Data tier: MariaDB primary + read replicas (mariadb-operator; ProxySQL or MaxScale for split), Laravel `read`/`write` connections with `sticky`; Redis Sentinel/Valkey; S3-compatible object storage; backups per your existing `mariadb-backup` streaming runbook plus object-store versioning.
- Millions-of-users honesty: horizontal web scale is straightforward once stateless; the ceiling is the single writer. Levers in order: query budgets and read models (§5.3), read replicas, hot/warm/cold tiering (§5.8), queueing non-interactive writes, then sharding by `institution_id` (schema is ready for it because every patient/clinical/config row carries it).

### 9.3 Supply-chain and container security

- Dependencies: `composer audit` + `roave/security-advisories`, `npm audit`, OSV-Scanner on lockfiles, Renovate weekly PRs (including base-image digest bumps), CycloneDX SBOM per release rendered in the docs (§12). CI blocks on any known vulnerability with a fix available; exceptions are time-boxed in the tracker.
- Containers: every build scanned by Trivy (`--severity HIGH,CRITICAL --ignore-unfixed --exit-code 1`) and cross-checked by Grype; deployed images rescanned nightly against the fresh vulnerability DB and findings open tickets; unfixable findings recorded in an OpenVEX file with owner and expiry (≤ 30 days) that CI re-evaluates; SBOM (Syft) attached and image signed with cosign; the cluster admits only signed images carrying a passing-scan attestation (Kyverno policy). Hadolint on Dockerfiles, `--cap-drop=ALL`, default seccomp, non-root, read-only FS, no `apk`/`apt` binaries left in the final layer so nothing can be installed at runtime; a separate `openeyes-debug` image for `kubectl debug` sessions.
- Definition of "no vulnerabilities" (enforced, not aspirational): zero fixable HIGH/CRITICAL at build time and in the nightly rescan, and a VEX statement for every unfixable one.
- Runtime: network policies (web → DB/Redis/S3 only), secrets never in env dumps (`config:show` redaction), OWASP ZAP baseline weekly.

### 9.4 Observability

- Pulse for slow queries/requests/jobs; OpenTelemetry PHP for traces; Prometheus metrics; Grafana dashboards for query counts per route, history/current table ratios, queue depth, ingest quarantine, token spend (§10.6).

### 9.5 Fast Docker builds

- Split expensive from cheap: extension compilation happens weekly in `openeyes-base`; app builds only copy code and run composer/npm/optimize.
- Layer order for cache hits: `COPY composer.json composer.lock` → `composer install --no-dev --no-scripts --no-autoloader --prefer-dist` with `--mount=type=cache,target=/tmp/composer` → `COPY package*.json` → `npm ci` with a cache mount → `COPY . .` → `composer dump-autoload -o`, `npm run build`, `php artisan optimize`. `.dockerignore` excludes tests, docs, node_modules, .git, storage.
- BuildKit everywhere (`docker buildx bake` for the matrix), registry cache (`--cache-to type=registry,mode=max`) shared by CI and developers, base pinned by digest so cache keys are stable, `SOURCE_DATE_EPOCH` for reproducible layers, hadolint in pre-commit.
- Local dev never rebuilds for code changes (bind mount + `octane:frankenphp --watch`); rebuilds only when lockfiles change.
- Targets (*guess*, measured in CI with a gate): warm app build < 90 s, cold < 8 min per architecture, base rebuild < 15 min.

### 9.6 Traditional VM installation path

- The app repo makes no container assumptions: paths from `.env`, `LOG_CHANNEL` selectable (stdout for containers, `daily` files for VMs), storage path configurable, no baked hostnames, works under Octane and under plain php-fpm.
- `deploy/vm/`: install notes for Ubuntu 24.04 (amd64 and arm64), systemd units for `octane:frankenphp` (or php-fpm + Caddy/nginx), Horizon and `schedule:work`, sample Caddyfile/nginx conf, logrotate, an idempotent `install.sh` (Ansible role later if wanted), and the same `bin/oe` aliases as the image.
- Release tarball built by CI (`openeyes-vX.Y.Z-<arch>.tar.gz` with vendor/ and built assets) so a VM install needs no composer/node on the box — the modern `oe_installer`.
- Blocking CI job `vm-install`: a fresh Ubuntu 24.04 runner (amd64 and arm64) installs from the tarball, runs migrations and the minimal seed, starts the services and runs the smoke walks. The container path can never become the only working path.

### 9.7 arm64 Linux

- Multi-arch images (`linux/amd64`, `linux/arm64`) via buildx with native arm64 runners (GitHub `ubuntu-24.04-arm` — check availability for private repos on your plan — or a self-hosted arm64 box), not QEMU emulation for tests. FrankenPHP, MariaDB 11.8, Redis/Valkey and MinIO publish arm64 images; PHP extensions are compiled per architecture in the base image.
- Full Pest suite, schema fingerprint check and a Playwright shard run on both architectures; the parity gate is ARIA/text based so per-arch font rendering cannot break it, and screenshots use per-platform snapshot directories.
- No amd64-only binaries: audit npm optional dependencies (rollup/esbuild/sharp) and PHP tooling for arm64; the VM install job (§9.6) runs on arm64 too.

## 10. Token economy plan

### 10.1 Where tokens go if unmanaged

14k files at roughly 1.5–3k tokens each is 20–40M tokens to read the tree once (*guess*), and agent sessions re-read. Reading legacy code is therefore banned as a way of learning what the app does; scripts learn (§4), models build.

### 10.2 Unit-of-work protocol

- Manifest (≤ 2k tokens) generated by the tracker: unit id, walk ids, the trimmed legacy facts for exactly this feature (form fields + validation, DOM inventory, tables/columns with new mapping, digests, bugs), target file list, tests that must pass, token cap and iteration cap, model tier.
- Fresh Claude Code session per unit; the session's first action is to read the manifest and the pre-generated tests, not the repo. Ends with `tracker.set_status`. Over cap → status `blocked` and a human decides; no heroic sessions.
- Two-agent split for larger units: implementer (writes) and verifier (reads diff + runs tests, small context) — the verifier returns a terse verdict, not the diff.

### 10.3 Scripts generate, models decide

Generated without a model: Playwright specs, Pest skeletons, FormRequest rule maps (Yii `required`→`required`, `length max`→`max:`, `numerical`→`numeric`/`integer`, `in`→`in:`, `exist`→`exists:`…), factory skeletons from schema types, API Resource field lists, docs stubs, tracker updates, docs index, ERDs, migration DDL rendered from design packets, dropped.md, SBOM docs. Models spend tokens on: schema design decisions, business rules in Actions, edge cases, bug fixes, ADRs, review.

### 10.4 Context hygiene

- Stable prefix for prompt caching: `CLAUDE.md` + `.ai/guidelines` frozen per phase; volatile material last in the prompt.
- No directory scans; navigation through `docs/index.json`, Boost's schema/route tools and Larastan errors. No pasted framework docs (Boost `search-docs`). Repomix `--compress` maps only in design sessions.
- Terse test output (`pest --compact`, `--bail`), pre-commit Pint/Larastan so style errors never round-trip, ≤ 300-line files, tests filtered to the unit.

### 10.5 Model routing

- Haiku: classification (bug↔walk linking, file kinds, doc metadata), commit summaries.
- Sonnet: routine units (element CRUD, factories, resources, tests), doc filling.
- Opus/Fable-class: schema design packets, migration mapping decisions, cross-module refactors, hard bugs, ADR review.
- Batch API for offline generation (test-plan drafts, classification, doc stubs) at reduced cost.

### 10.6 Measurement

- Claude Code OpenTelemetry export into your Prometheus/Grafana (`CLAUDE_CODE_ENABLE_TELEMETRY=1`, `OTEL_METRICS_EXPORTER=otlp`, `OTEL_RESOURCE_ATTRIBUTES=oe.unit=<id>`); metrics include `claude_code.token.usage` and cost. The tracker stores tokens per unit and per model; weekly burn-down against the plan; alerts on units > 2× median.

### 10.7 Pilot and estimation

- Run two pilot modules through the full protocol (one simple event type, one Examination subset), ~10 units each, and record tokens by unit type. Formula: total ≈ Σ(units per type × median tokens per type) × (1 + iteration factor) + design sessions + review. Placeholders until the pilot: simple element unit 80–200k tokens, complex screen 300–800k, schema packet 200–500k (*guess*). Decide model mix and caps from pilot data; re-estimate quarterly.

### 10.8 Working in chunks around usage-limit resets

Claude Code on a subscription is metered against a rolling 5-hour session window plus a weekly cap shared with the Claude apps (see `/usage` in Claude Code or Settings > Usage; extra usage at API rates is optional). The plan is therefore cut into chunks that fit a window and can be dropped and picked up without wasting tokens.

- Chunk = the ordered queue of units for one window, generated by the tracker (`oe-tracker chunk --window=5h --tier=sonnet`) from measured tokens per unit type (§10.7) with 15 % headroom. Rule of thumb until the pilot: one schema design packet, or 2–4 routine units, or one complex screen per window.
- Every unit is resumable by design: work happens on a `feat/<module>-U<id>` branch; a Claude Code Stop hook writes `RESUME.md` (< 1k tokens: what is done, what is failing, next step) and pushes; the tracker marks the unit `paused` with the branch. The next session starts by reading `RESUME.md` and the manifest only — never the conversation history (`--resume` is used only inside the same window for the same unit).
- Stop conditions: a unit stops at the end of the window even if incomplete; nothing is left uncommitted; no "just one more thing". If the window closes mid-unit, the loss is bounded to that unit's last step.
- Fill the gaps with token-free work: Phase 0 extraction, seed builds, migration rehearsals, validation runs, parity suites, docs generation and Batch API jobs (separate API billing) run while the subscription window is exhausted; the tracker's queue shows "runnable without a model" items.
- Weekly cap planning: schedule Opus/Fable-tier design sessions early in the week and routine Sonnet units later; watch `/usage` and the OTel token metrics (§10.6); when the weekly bar is at 80 %, the tracker only hands out script work and review tasks.
- Milestones and phases are expressed as chunk counts, not calendar days, in the tracker; the phase table in §14 keeps calendar guesses only for planning conversations.

## 11. Testing strategy and gates

| Artefact | Required tests |
|---|---|
| Model | factory test, arch (category, factory), schema lint |
| Action | unit tests, mutation score ≥ threshold |
| Web/API endpoint | feature test (both surfaces), contract test vs OpenAPI, query budget |
| Screen/walk | Playwright parity spec, Lighthouse budget (top pages) |
| Migration mapping | validation checks (§5.11) |
| Command/job | feature test with seed, scheduler test |
| Integration | corpus contract tests, compose rig |
| Config/reference set | export→import round-trip test |
| Docs | coverage test (all four files, non-stub) |
| Feature (register entry) | ≥ 1 linked test per required kind; register coverage test (§4.6) |

Gates in CI (all blocking): Pint, Larastan max, Pest unit/feature/arch, mutation threshold on Actions, type coverage 100 %, schema lint, factory coverage, docs coverage, OpenAPI diff, Playwright parity shard, query budgets, security audits, image size, nightly migration validation and Psalm taint. Human edge-case test plans (`test-plan.md`) are drafted from walks + FormRequest rules + bug list, reviewed by a clinician/tester, and tracked to completion in the tracker before a module is declared migrated.

### 11.1 Determinism policy (no flaky tests)

- Clock frozen in the base TestCase (`Carbon::setTestNow`) and in Playwright (`page.clock.install()`); no `sleep`, no `waitForTimeout`, no wall-clock timeouts inside assertions.
- Randomness seeded per test (Faker seed derived from the test name; `Str::createUuidsUsingSequence`/`createUlidsUsing` in tests); factories never call an unseeded RNG.
- Isolation: `RefreshDatabase` on a DB restored from `schema:dump`, one DB per parallel process, Redis `array` or flushed per test, `Queue::fake`/`sync`, `Http::preventStrayRequests()`, `Mail`/`Notification`/`Storage` fakes by default; no shared mutable state, no dependence on row ids.
- Order independence: CI runs the suite in random order and prints the seed; a nightly job runs reversed and shuffled orders; retries are 0 everywhere (Pest and Playwright); a test that needs a retry is a bug with a ticket.
- Environment pinned: `TZ=UTC`, `LANG=C.UTF-8`, `sql_mode`, collation, MariaDB and browser versions pinned; Playwright runs in the same image as CI with bundled fonts, fixed viewport/deviceScaleFactor, `reducedMotion`, animations disabled, `timezoneId`/`locale` set. Golden artefacts from the legacy app are captured under exactly the same pinned conditions, otherwise parity diffs are noise.
- Every list/paginated query has an explicit `ORDER BY` with a unique tiebreaker (OE-SQL-002) so parity output cannot vary between runs.

### 11.2 No false positives (green must mean correct)

- PHPUnit strictness on: `failOnRisky`, `failOnWarning`, `beStrictAboutTestsThatDoNotTestAnything`, `beStrictAboutOutputDuringTests`; a test without assertions fails; `assertTrue(true)`, `markTestSkipped` without a ticket id and `expect.soft` are banned by lint (OE-TST-*).
- Mutation testing on Actions/Models (`pest --mutate`) with a minimum score is the systematic check that tests constrain behaviour; snapshot/golden updates are impossible in CI (`--update-snapshots` blocked), so a stale golden can only be refreshed by a reviewed PR with the diff attached.
- Parity masks are explicit allowlists of volatile fields (timestamps, uuids, CSRF tokens) recorded per walk; a blanket ignore is a lint failure. Each parity spec asserts something positive (text present, aria snapshot) so an empty page cannot pass.
- Known-bad build canary: nightly, CI injects a deliberate defect (a mutated Action and a broken Blade view) and asserts the suites go red; if they stay green the pipeline is broken and the run fails. Same for the migration validator: a corrupted staging row must be reported.
- Tracker statuses change only from CI on green pipelines, never by hand-typed "done".

### 11.3 Concurrency and load testing

Tooling: Grafana k6 (HTTP scenarios plus `k6/browser` for real-browser flows; thresholds as code; PR smoke and nightly full runs), Playwright multi-context for deterministic two-user race scenarios, Pest for transaction/lock-level races, MariaDB `performance_schema.data_lock_waits` and `SHOW ENGINE INNODB STATUS` for deadlock evidence, Pulse/OTel traces to attribute latency, and chaos steps (kill an Octane worker or pod mid-request, Redis failover, injected replica lag). Scenarios live in `tests/Concurrency/`, each with a pass criterion:

1. Two clinicians edit the same event/element at once → optimistic concurrency (row `version`/`updated_at` check) rejects the stale save with a conflict message; no silent overwrite; audit shows both attempts.
2. Same patient open in two tabs/devices by one user; save from both.
3. Concurrent creation of events in one episode (ordering, numbering, "latest event" pointers).
4. Double-submit / retried POST → idempotency key per form; exactly one event created.
5. Worklist/clinic list: many users changing status/check-in on the same list; counts consistent; no lost updates.
6. Booking the same theatre/clinic slot from two sessions → unique constraint plus friendly error.
7. Patient merge while other users edit the merged records.
8. Letter generation for the same event from two sessions → one document, dedupe by hash.
9. IOLM/payload import racing manual entry on the same patient → matching rules hold, quarantine, no duplicates.
10. Sequence/number generation under load (hospital numbers, letter numbers, invoice numbers): 1,000 parallel requests, unique, gapless where required.
11. Session concurrency: same user on two devices; forced logout or permission change takes effect within one request.
12. Setting change while requests are in flight → cache invalidation across all containers.
13. Scheduler and queue: `withoutOverlapping`/`onOneServer` proven with three replicas; jobs idempotent under retry; failed-job replay never duplicates clinical rows.
14. Octane state leakage: request A's user/patient never visible in request B under 200 concurrent mixed-user requests (auth, container singletons, static caches).
15. Read-your-writes with read replicas (`sticky`) after create → redirect → view.
16. Long transactions (archive, anonymise, read-model rebuild) against live traffic: no lock waits beyond threshold; manager-owned DDL while the frontend is drained, plus a separate rehearsal of the incident-only live-DDL runbook against synthetic traffic.
17. Rate limiter and login brute-force protection under distributed load; lockouts per account, not per pod.
18. Deadlock injection (two transactions in opposite lock order) → detected, retried once, surfaced, never lost.

Targets on the perf seed at each client's expected concurrency ×3: p95 within budget (§7.5), error rate < 0.1 %, zero lost updates and zero unrecovered deadlocks, invariants (§5.11) intact after a two-hour soak. Runs: PR-level smoke (10 VUs), nightly full, pre-cutover soak on rehearsal data.

## 12. Documentation

- Repo `openeyes-docs`, markdown only, cloned into a documented content root at image build time, read directly by the built-in Docs feature and rendered at `/docs` (authenticated, searchable - your vector search or FTS).
- Layout: `features/<module>/<feature>/{overview,behaviour,api,test-plan}.md`; `schema/{rules,decisions,dropped}.md` + generated `schema/tables/*.md`; `adr/NNNN-*.md`; `platform/{container,kubernetes,security,observability}.md` (container page generated from the SBOM: every package/extension, version, purpose, CVE status); `operations/*` (runbooks; exportable to your c-note text format if wanted); `migration/{mapping,validation-report,cutover}.md`.
- Rule: hand-written where judgement lives, generated where facts live; a docs coverage test blocks merges.

### 12.1 Construction record (how everything was built)

- `docs/construction/`: `methodology.md` (this plan, kept current), `pipeline.md` (every Phase 0 script and generator: inputs, outputs, versions, how to rerun), `tools.lock.json` (versions of every tool used, regenerated by CI), `legacy-facts.md` (commit hash and checksums of the `openeyes-legacy-facts` snapshot used), `units/` (per-release export from the tracker: unit → manifest → PR → tests → tokens and model tier), the ADR index, and a "build a new module the same way" walkthrough.
- Provenance in code: generated files carry a header `// @generated by oe-gen/<generator>@<version> from <input>#<hash>`; hand-edited generated files must drop the header and say why in the PR; a lint checks headers against `tools.lock.json`.
- Schema construction: each design packet (5.1) is committed under `docs/schema/packets/<context>.md` with the workload evidence it was designed from, so any table can be traced to the digests, walks and legacy columns that shaped it.

### 12.2 DevOps notes: how it works and how to troubleshoot

- `docs/operations/how-it-works/`: boot sequence and entrypoint (what runs before the first request), config precedence (`.env` → config cache → settings tables), roles and their commands (web, horizon, scheduler, IOLM, payload, MCP, migration Job), request lifecycle with request id, sessions/cache/queues in Redis, storage and signed URLs, auth/permissions, ingest pipelines and quarantine, migrations Job and schema verify, health probes, logging/tracing/metrics, backups and restore, upgrade and rollback.
- `docs/operations/troubleshooting/`: symptom → checks → fix pages with exact commands and expected output, log strings quoted verbatim so greps land (login loop, "Schema fingerprint mismatch", queue not draining, Octane worker memory/restart loops, migration lock stuck, IOLM payload quarantined, storage 403, slow page → Pulse query, cert/clock issues, seed/anonymise failures).
- `oe:doctor` command: DB/Redis/storage reachability, migrations status, schema fingerprint, queue heartbeat, scheduler last run, Octane workers, disk, clock skew, cert expiry, config cache state — each check prints the same identifier as its troubleshooting page. `php artisan about` gets an OpenEyes section (version, schema fingerprint, seed profile, feature flags).
- The same pages can be mirrored into the TKL text-note KB by a converter if you want them grep-able there; the markdown source stays authoritative.

## 13. Governance

- Definition of done per unit: tests green (§11), parity green or approved exceptions, budgets met, docs present, tracker updated, PR trailers (`Unit:`, `Migrates:`, `Fixes:`), impact report reviewed (§6.14), reviewer sign-off.
- ADRs for every deviation from defaults and every schema decision; weekly tracker review (progress, tokens, blocked units); UX-change sign-off owner named; release = tag + seed artefact + SBOM + docs build.

### 13.1 Release cadence: three major releases a year

- Calendar: majors every four months (e.g. February/June/October), the February major absorbing the yearly Laravel and PHP majors; patch releases on demand. Each release = tag, seed artefact, SBOM, docs build, feature-register delta, upgrade-test evidence.
- Trunk-based development with Pennant flags: features merge behind flags continuously; a release is a dated set of flag flips, not a merge crunch; a lint fails on flags older than one release.
- Adding features fast: generators (`oe:make:module`, `oe:make:element`, `oe:make:event-type`) scaffold model, migration with category comment, factory, Actions, Requests, Resources, Blade view from the component library, tests, walk skeleton and docs stubs; a new element type is a day of business logic, not plumbing. Element/event registration is attribute-based discovery, so no central file is edited and modules can ship in parallel.
- Schema evolution for zero-downtime releases: expand/contract migrations (add nullable/defaulted, backfill via `oe:data:*`, contract next release), online DDL only (`ALGORITHM=INSTANT`/`INPLACE`, `LOCK=NONE`; a lint flags operations that rebuild large tables and routes them to a maintenance-window path), N-1 compatibility for one release, fingerprint re-baselined per release.
- API and config compatibility: canonical `/api` is additive-only within supported releases, deprecations are announced one release ahead with `Deprecation`/`Sunset` headers; setting definitions are versioned with export-bundle upgrade transforms; walks and goldens are versioned per release — after cutover the parity suite becomes the regression suite with goldens taken from the previous release.
- Upgrade path proven per release: CI upgrades N-1 → N on the anonymised snapshot, runs migrations, validation, register coverage and the full walk suite; blue-green deploys with the DB compatible one release back; downgrade documented where possible.
- People and comms: the feature-register delta becomes the release notes and the human test plan for the release; the training environment is refreshed from the release seed; the support policy states which releases receive security fixes.

## 14. Sequencing, exit criteria, risks

Phases are delivered as chunks that fit usage windows (§10.8); durations below assume roughly two windows of model work per weekday plus script work in between.

| Phase | Content | Exit criteria | Duration (*guess*) |
|---|---|---|---|
| 0 | Inventory, walks harness, workload capture, tracker | 100 % inventory; goldens + workload stored | 3–5 weeks |
| 1 | Core schema packets + spikes; module packets continue in parallel with Phase 3 | Core migrations + lint green; ADRs; migration engine skeleton | 6–10 weeks |
| 2 | App skeleton, conventions, arch tests, seeds, MCP, factories, CI, image | Empty app passes all gates; M0 live; pilot units done; token model calibrated | 3–4 weeks of work, started in week 1 in parallel with Phases 0–1 (it needs no legacy facts) |
| 3 | Units, core → heavy modules → long tail; bug fixes | All files `migrated/deprecated/obsolete/asset-copied`; parity green | bulk of the project |
| 4 | IOLM, payload processor, commands, interfaces | Contract + rig tests green | overlaps 3 |
| 5 | Infra hardening, rehearsals, dark launch, cutover | ≥ 3 rehearsals in window; validation zero-diff; runbook approved | overlaps 3, ends at cutover |

Risks and mitigations: walk coverage gaps (coverage report from §4.3 identifies unexercised files early); hidden features in commands/cron (inventory before design); versioning spike fails (fallback B/C decided up front); legacy data quality blocks validation (classify differences: fix in transform, accept with record, or fix in legacy first); performance surprises under Octane (spike + fpm fallback); token overrun (caps, routing, pilot re-estimation); licence question (decide before code); key-person dependency (docs and tracker are the memory, not people); UX sign-off latency (named owner, weekly slot); dark-launch PII (inside trust boundary only); M0 pressure freezing the core schema too early (provisional status and schema reset points until v1.0 are explicit, 5.13).

Milestones (what you can put in front of people):

- M0a "the front door" — target week 3–4, the first thing after Phase 0 has enough facts: the identical unauthenticated login page, error pages and the authenticated shell served by the new stack from `@openeyes/ui`, with a login that works against migrated (anonymised) users. Gate: an early visual walk — the login/shell walks run against legacy and new with ARIA snapshot, text and screenshot comparison, and the report is reviewed by you before any feature work starts. From here on every new page is added to the same visual walk, so drift is caught page by page rather than at the end.
- M0 "walking skeleton" — target week 6–8 from start (Phase 2 runs from week 1 alongside Phases 0–1; M0 needs only the core design packet, which is Phase 1's first output): a stack on your server (compose, later Kubernetes) with login (users/roles from the first ETL mapping, anonymised), the identical UI shell from `@openeyes/ui`, patient search, read-only patient overview and one read-only event view, `/api/patients`, `/docs`, `oe:doctor`, refreshed nightly from the anonymised legacy snapshot by the early ETL. Its core schema is provisional (schema reset points allowed until v1.0, 5.13). Feedback goes into the tracker as bugs/UX notes against walks. To make this happen the core design packet (patients, episodes, events, users, institutions) is the first Phase 1 output and the ETL for those tables is built before anything else.
- M1: pilot modules fully migrated with parity green; token model calibrated.
- M2: core and top-traffic modules migrated; dark launch starts.
- M3: all units migrated; rehearsals in window; cutover.

## 15. Active subplan - 2026-08-30 to 2026-08-31

This subplan supersedes the completed greater-than-40-percent execution target.
It starts from legacy `ad2324084788608246a8250e817198c2f26a4fd6`, Laravel
`bac68960899df26f26427ea24ed81ea83849b11e` at 40.4147 percent weighted
coverage, and Docker `ef578cd1a85a536bdfb8b7b746a07d831ac0ecee`.

The durable stopping condition is:

`Continue the frozen-scope OpenEyes Laravel rewrite integration from the pinned baselines. Do not complete, hand off, or voluntarily idle before 2026-08-31T12:00:00+01:00. Finish only at the first safe integrated checkpoint at or after that time.`

Finishing an item takes the next item automatically. A blocked item records
evidence and deferral, then work moves to an unblocked item. No functional slice
starts after 06:30 BST; verification and reconciliation continue through 12:00.
The user extended the original 08:00 terminal guard to 12:00 BST at 07:00 BST.
The scope freeze remains in force throughout the extension.

| Window | Work | Acceptance |
|---|---|---|
| Start to T+30 minutes | Confirm clean pinned repositories, record this subplan and activate the durable goal | Baselines, deadline, queue and dual terminal condition are recorded |
| T+30 minutes to T+2 hours | Build the canonical source manifest, reconcile missing legacy paths, review scripts and documentation, add ledger integrity checks | Exactly 14,125 canonical paths, matching SHA-1 values, zero missing paths and no obsolete row without evidence |
| T+2 to T+4 hours | Add request telemetry, global page readiness, renderer activity telemetry and home client or server guards | Focused tests pass, telemetry contains no sensitive fields and 100 rapid clicks remain bounded |
| T+4 hours to 06:30 | Close rolling functional slices with migration confidence packs | Every completed slice has behavior, authorization, bounded queries, ledger evidence and one browser smoke |
| 06:30 to 12:00 | Freeze new scope, reconcile repositories and ledgers, run the final test batch and fix attributable failures | No new feature is opened and the staged diff plus verification evidence is coherent at or after 12:00 |

The rolling functional queue is:

1. Complete event storage and attachment workflows: attachment-type configuration, secure local upload, link, view and delete, manual correspondence attachments and the device-import boundary.
2. Close shared medication gaps, beginning with automatic medication-set composition and rebuild plus verified consumers. Do not rework working prescription, taper, signing, printing, report or pharmacy paths for coverage alone.
3. Close ordinary vision and refraction recording, history, configuration and shared-consumer gaps. Exact print and visual geometry wait for fidelity work.
4. Complete webhook payload parity and transactional-outbox consumers where legacy callers are evidenced.
5. Continue the shared census and ordinary core behavior only after the preceding user-facing slices are safe.

An unknown authoritative clinical rule defers only that narrow behavior. It never
authorizes guessing or ending the run.

Every hourly checkpoint records current problem and acceptance condition,
completed evidence, current work, `next_item`, `after_next`, blockers and
deferrals, exact coverage and canonical ledger counts, query or performance
changes, tests run or deferred, `verification_state`, and repository state.

The final batch runs focused tests first. If schema changed it then runs a clean
seven-schema migration and tiny seed. When focused gates are green, run full Pest
once, the production frontend build, renderer or container checks if changed,
and affected Playwright flows once with no retry. Mutation, exhaustive visual
comparison, full UAT, external integrations and production load are not claimed
by this run. Stage and show all affected repository diffs. Do not commit or push.

### 15.1 Integrated checkpoints

The run has completed its architecture-shaping foundation, the first functional
queue slices and eighty-three bounded legacy census clusters. The canonical source manifest contains all 14,125
tracked legacy paths with matching blob SHA-1 values, exactly one canonical row
per path, zero missing paths and zero rows still pending review. The current
weighted canonical coverage is 49.8284 percent after the inventory
denominator correction. The old 40.4147 percent figure remains the historical
pre-census baseline and is not comparable to this exhaustive denominator.

Request telemetry, the global page readiness contract, renderer activity
telemetry and guarded home navigation are implemented with focused privacy,
persistent-worker reset, capacity and rapid-click tests. The completed vertical
slices are manual correspondence attachments, automatic Medication Set
composition and rebuild, and live same-event Refraction or Retinoscopy sources
for Correction Given. The fourth slice now preserves exact legacy webhook
receiver payloads for clinical events, allergies, clinic outcomes, diagnoses,
history risks and associated contacts through the transactional outbox. Delivery
uses immutable payloads, bounded per-subscriber batches and retries, current
endpoint validation and recorded acknowledgement. The focused pack exercises all
12 element family and action combinations, contact label coding, constant six
query projection for both 1 and 100 occurrences, manager authorization, exact
HTTP bodies and one no-retry browser smoke. Each completed slice has focused
authorization, validation, storage or transactional, query-bound and browser
evidence. Exact correspondence PDF concatenation, institution-selected automatic
formularies, exact legacy vision geometry, PASAPI callers and a live external
webhook receiver remain narrow recorded deferrals. The rolling queue now proceeds
to the shared legacy census and ordinary core behavior. The diagnosis census
reconciled 75 canonical shared paths and added a flat three-query current-
diagnosis confidence gate for both small and large fixtures. Mandatory response
state, final clinical sign-off and migration rehearsal remain explicit narrow
deferrals. The diagnosis browser smoke did not run because the isolated Chrome
sidecar's DevTools endpoint was unavailable before application access.

The diagnosis pack exposed a central EventView cost of 431 queries in two live
requests. Event element presence is now resolved in one bounded union query and
inactive Examination configuration is loaded through a named authenticated API
only when the panel is activated. The initial focused EventView request fell to
69 queries and 117,739 response bytes while saved elements, the six default
panels, Next Steps and prescription redirects remain eager. Focused server and
frontend gates passed. Two live requests under persistent workers each used 69
queries and 117,875 response bytes, with server durations of 1,018 and 667
milliseconds compared with the earlier 431-query and approximately 335-kilobyte
responses. The isolated Chrome DevTools endpoint remained unavailable, so this
performance correction has live HTTP evidence but no new browser smoke.

The Stereo Acuity census then reviewed its remaining 16 canonical supporting
paths. Its confidence pack now follows the lazy configuration contract and
covers configuration, authorization, explicit result state, method and
correction snapshots, head-posture dependency, replacement and deletion
history, and flat page query growth. All 9 focused tests passed with 150
assertions; a saved page used 73 queries with one entry and 71 with 100 entries.
Compact correspondence letter output and exact compact-expand geometry remain
recorded deferrals under DIV-110, and the unavailable isolated Chrome endpoint
prevented a new browser smoke from being claimed.

The Prism Fusion Range census reviewed its remaining 13 supporting paths and
updated the aggregate mapping. All 8 focused tests passed with 124 assertions,
covering lazy configuration, authorization, measurement bounds, required data,
correction snapshots, head-posture dependency, history and query growth from 1
to 100 saved entries. The correspondence table remains reviewed but at zero
coverage under DIV-112; exact widget geometry is partial pending fidelity work.

The Sensory Function census reviewed 23 previously pending supporting paths and
updated its aggregate mapping. All 9 focused tests passed with 143 assertions.
The query gate loads 1 and 100 entries with two ordered corrections per entry,
confirming that the nested `entries.corrections` relation does not add query
growth. The three portable lookup families and admin screens are covered; exact
correspondence wording and compact-view geometry remain partial under DIV-157.

The Convergence and Accommodation census reviewed its seven pending supporting
paths and credited the existing Cypress source only partially. All 9 focused
tests passed with 132 assertions. The page query budget remained bounded from a
minimum description through the 65,535-byte maximum. A current browser workflow
is not claimed because the isolated Chrome endpoint remains unavailable.

The CCT census reviewed its eight pending supporting paths. All 9 focused tests
passed with 109 assertions, covering lazy method configuration, authentication,
per-eye bounds and database invariants, stable method snapshots, retired-method
editing, exclusion and deletion history, portable configuration and bounded
page queries. A saved page used 71 queries for both a one-byte note and the
4,096-byte maximum. The exact seven legacy method names and display orders are
preserved. Copy-forward and patient-level projections remain explicit deferrals
under DIV-123 and DIV-122, and exact layout remains later fidelity work.

The shared corrective-head-posture census reviewed the three remaining legacy
test-trait paths. It also corrected stale Head Posture and Cover Test assertions
to exercise the named lazy configuration endpoints introduced by the EventView
performance work. The focused Head Posture, Convergence and Cover Test pack
passed 25 tests with 335 assertions. Stable Used and Not Used values, unknown
value rejection and both singleton and child-entry same-event dependencies are
covered. A Head Posture page used 69 queries for both a one-byte comment and the
65,535-byte maximum. Trait mappings remain partial because DIV-105 still requires
the remaining legacy consumers and migration reconciliation before closure.

The Cover Test census reviewed its remaining 22 canonical supporting paths and
updated the aggregate mapping. The focused Cover Test, application-surface and
configuration-authorization pack passed 24 tests with 3,137 assertions,
including 11 Cover Test tests. The page used 75 queries with both 1 and 100
entries. Three missing vocabulary administration screens and editing of an
existing reading are now restored. The production frontend build passed in the
existing glibc Node container; the Alpine application image could not load its
optional Rolldown native module. Exact letter output remains reviewed at zero
coverage under DIV-228. Copy-forward, exact compact and expanded geometry, and
a current browser smoke remain recorded deferrals.

The Prism Reflex census reviewed its remaining 19 canonical supporting paths
and updated the aggregate mapping. All 9 focused tests passed with 150
assertions. The confidence pack now covers lazy configuration, authentication,
required entries, stable lookup and correction snapshots, head-posture
dependency, retired-choice editing, replacement and deletion history, portable
configuration, all three administration screens, and page query growth from 1
to 100 saved entries. The two pages stayed within the 95-query budget with no
material growth. Exact letter composition remains deferred under DIV-152, and
exact compact and expanded geometry remains later fidelity work.

The Synoptophore census reviewed its remaining 19 canonical supporting paths
and updated the aggregate mapping. All 8 focused tests passed with 129
assertions, and the production frontend build passed. The confidence pack now
covers lazy configuration, authentication, eye and angle selection, unique
gazes, all five bounded measurements, stable direction and deviation snapshots,
retired-choice editing, replacement and deletion history, portable
configuration, both administration screens, and page-query growth from 1 to
the 18-reading limit. The editor now exposes all measurement fields in the
explicit row interface recorded by DIV-155; the previous component could add a
blank reading but did not expose any way to enter its measurements. Exact
three-by-three visual geometry remains later fidelity work.

The Conjunctival Hyperaemia census reviewed its remaining 28 canonical
supporting paths and corrected WebP inventory classification from repository
metadata to assets. The combined element and ocular-surface history pack passed
11 tests with 132 assertions. Five target reference images are byte-identical
to the pinned legacy assets, the image picker now exposes their descriptions as
accessible alternative text, and stale DIV-118 is closed. The named lazy
configuration, sided grades and comments, exclusion clearing, validation,
deletion history and page-query budget at the 65,535-byte comment limit are
covered. Existing institution-scoped keyset history narrows stale DIV-119 to
the exact `hyg` shortcode formats. Those formats, legacy recorder display
metadata, copy-forward and a current browser smoke remain explicit deferrals.

The Lacrimal census reviewed its remaining six canonical paths. The focused
Lacrimal and shared event-search pack passed 14 tests with 142 assertions. The
event-search projection now retains the exact Lacrimal, Laxity and Mucocele
labels plus the `duct` alias without a database-backed index, and the shared
test now derives its expected term count from the element registry. Exact
EyeDraw distributions, sided storage, doodle allowlisting, report and comment
presentation, exclusion clearing, database constraints, deletion history and
authentication remain covered. Saved-page queries stayed at 70 for both a
one-byte comment and the 65,535-byte maximum. Search-to-doodle insertion,
copy-forward and diagnosis-policy projections remain narrow deferrals under
DIV-255; the isolated Chrome endpoint remains unavailable.

The Anterior Segment census reviewed its remaining 13 canonical supporting
paths. The combined element and ocular-surface history pack passed 10 tests
with 135 assertions. It now explicitly covers the fixed cortical and nuclear
grade mappings, paired frontal and cross-section EyeDraw validation, sided
storage, automatic report and derived lens projections, exclusion clearing,
database constraints, deletion history, authentication and bounded patient
history. Saved-page queries stayed at 70 for both a one-byte description and
the 65,535-byte maximum. The legacy print view remains reviewed at zero
coverage, and patient-level doodle shredding, copy-forward, diagnosis policy
and search-to-doodle insertion remain deferred under the narrowed DIV-258.

Residual reconciliation then closed the three already-proven Convergence and
Accommodation, Prism Reflex and Cover Test schema migrations plus the two
Social History accommodation lookup paths. The Social History pack passed 7
tests after its stale eager-configuration assertion was moved to the named
authenticated lazy endpoint; the combined ledger gate passed 9 tests with 117
assertions. All seven ordered accommodation choices, portable configuration
and immutable clinical snapshots remain covered. These five rows add no new
clinical behavior or divergence.

Two misclassified singleton rows were then audited without adding unsupported
coverage. The Intravitreal consent-timeout spelling migration is now owned by
the injection feature and remains a zero-credit deferral until an authoritative
expiry and re-confirmation contract exists. The standalone Keratoconus Stage
model is obsolete with path-specific evidence: pinned-tree search finds no
runtime caller, only static-analysis baseline references, while both live
Keratoconus workflows use explicit fields and no stage lookup. Ledger integrity
remains green and weighted coverage is unchanged.

The treatment-workflow migration residual then reviewed four canonical paths.
The two Previous Ophthalmic History migrations map to the versioned Ophthalmic
Surgery aggregate and its explicit performed state. Multiple Injection
Management stop reasons remain a narrow deferred ongoing-action contract even
though their versioned reason vocabulary exists. The Clinical Outcome checkout
visibility and default settings remain deferred with the owning pathway
transaction. Lazy-configuration assertions for Ophthalmic Surgery, Injection
Management and Clinical Outcome now exercise their authenticated named config
endpoints. The combined clinical and ledger pack passed 36 tests with 494
assertions.

The webhook residual census reviewed its remaining 11 canonical paths. Exact
allergy, history-risk and clinical-event fixture behavior maps to the durable
payload outbox, bounded subscriber projection and isolated delivery worker.
In-process HTTP fakes replace the legacy file receiver, blocking sleeps and
test-only queue endpoint, while the empty admin asset placeholder is obsolete
with path-specific evidence. AIS flags retain a stable event-code seam, but the
configured direct endpoint, change caller and PAS-owned delivery remain zero or
minimal credit under DIV-252. The exact-payload storage test was corrected for
the current immutable wire-payload contract, and the webhook, outbox, manager
and ledger packs pass after that correction.

The event-storage and attachment census reviewed its remaining 59 canonical
paths. Exact event-owned protected storage, indexed SHA-256 reconciliation,
authorization, portable type and event policy administration, safe links,
bounded canonical APIs, expiring linked-device uploads and versioned manual
correspondence attachments map to current implementation and focused evidence.
The legacy thumbnail grid and PDF.js attachment pane, raw attachment-data admin,
attachment-type subspecialty filtering, the one-time BLOB extraction command and
atomic OphGeneric device reports remain low-credit recorded deferrals rather
than inferred parity. One zero-byte admin asset placeholder is obsolete with
path-specific replacement evidence, while the vendored PDF.js icon is reviewed
at zero coverage without being treated as an application feature. The combined
attachment, file-storage, correspondence and ledger pack passed 35 tests with
602 assertions.

The five-row mixed Examination residual was reassigned to its actual owners
rather than credited as Orthoptics. The Cataract CSV archive, both corneal
cross-linking lookup models and the Injection Management diagnosis-question
admin view remain zero-credit deferrals under their existing divergence
records. The diagnosis shortcode migration has partial evidence from the
current structured diagnosis projection, while its exact correspondence token
remains deferred. Operation Note cross-linking records were not counted as a
replacement for the distinct Examination lookups. The Cataract, diagnosis,
Injection Management and ledger pack passed 36 tests with 512 assertions after
three stale Cataract assertions were corrected to use the named lazy
configuration endpoint.

The Genetics and Device Usage residual reviewed its remaining 21 canonical
paths and reassigned event-specific authorization migrations and the two linked
device waiting views to their actual owners. Existing DNA Sample, DNA
Extraction and Genetic Results policies receive partial credit while exact
legacy role and task assignments remain deferred. External Mutalyzer validation,
the configured DocMan service-account role and exact Genetics artwork remain
reviewed at zero coverage. Device report persistence and capabilities map to the
current protected versioned CSV lifecycle, while queued MDOR submission remains
deferred. The linked-device waiting page now visibly identifies its current
user, and its 10-second poll remains bounded. The combined Genetics, Device
Usage, file-storage and ledger pack passed 52 tests with 857 assertions. The
device-report projection also held its query count flat from 1 to 100 usage
entries, and the production frontend build passed.

The Consent factory residual reviewed 13 canonical test-support paths and
classified them as tests rather than runtime code. Event, type, procedure,
confirmation, supplementary-question and attorney-or-deputy fixture states map
to direct public-service and API tests over the normalized aggregate. Signature
factories remain partial under DIV-100 because exact generated signature images,
the separate legacy signing permission and linked-device transport are not
claimed. The complete Consent server pack passed 75 tests with 932 assertions,
covering start modes, authorization, stable snapshots, lifecycle transitions,
PIN and drawn evidence, supplementary controls, configuration portability,
bounded render payloads and module registration.

The Consent presentation and integration residual reviewed 10 canonical paths.
Three legacy icons, Concentric launch, hard-delete confirmation and exact
letter-head composition remain explicit zero-credit deferrals. Consent render
input and readiness provide only partial event-image credit because the legacy
event-image surface and screenshot fidelity are not claimed. The mixed Other
summary maps partially to typed witness, interpreter and guardian requirements
plus supplementary answers, while image permission maps to the normalized
configured supplementary-answer contract. The standalone legacy Mocha runner is
replaced by maintained container-run Consent feature tests.

The Consent support residual reviewed five canonical paths. Additional-risk
subspecialty assignment maps to the normalized scoped additional-risk row and
portable configuration family. Supplementary-question seeding and procedure
fixtures map to deterministic public-contract tests over immutable normalized
snapshots. The best-interest attachment model remains an explicit zero-credit
deferral because the target has no accepted attachment lifecycle or document
composition contract for that evidence.

The Consent migration residual reviewed all 31 remaining canonical migration
paths. Fresh-schema repairs and duplicate element cleanup are accounted only
where the normalized target cannot enter the legacy state. Current type, layout,
procedure, decision-party, supplementary-answer, signature and leaflet
contracts receive bounded credit from direct tests. Historical row transforms
remain partial, while the site-specific advanced-decision transform,
best-interest attachments, the retired information flag and configured COVID-19
print section remain explicit zero-credit deferrals. No legacy data import or
exact PDF fidelity is claimed by this census.

The Biometry residual reviewed its remaining 45 canonical paths and closed an
architecture-shaping lens metadata gap. Institution-scoped lens configuration,
the bounded picker and immutable calculation and selection snapshots now retain
the exact name, display name, description, stable chamber position, comments and
formula constants needed by clinical display, rendering and Operation Note. A
clean seven-schema migration, tiny seed and schema verification passed. The
integrated Biometry and ledger pack passed 66 tests with 882 assertions after a
direct snapshot fixture was updated for the required display-name invariant, and
the production frontend build passed. The picker remains one bounded query and
renderer payload construction remains six clinical reads. The 45-path census
keeps temporary watcher and retired SignOff artifacts, exact print artwork,
importer persistence, production lens rows, historical transforms and
unsupported clinical rules at zero or partial credit rather than inferring
parity. Production lens row and institution mapping migration, parser and queue
work, approved formula goldens and exact print fidelity remain explicit DIV-463
closure conditions.

The Case Search medication residual reviewed its final two canonical paths and
restored active-medication IS and IS NOT criteria without coupling saved searches
to target database identifiers. Bounded autocomplete resolves an active stable
source and code pair, while a maintained institution-scoped current-medication
projection supports indexed EXISTS and NOT EXISTS filters, including patients
with no medication for IS NOT. Projection rebuilds occur after medication review
saves and soft deletion. The focused Case Search and Medication Management pack
passed 21 tests with 471 assertions; malformed and inactive portable keys are
rejected, small and large cohorts have the same query count, and the index plan
names the projection index. A clean seven-schema migration, tiny seed, schema
verification and the production frontend build passed. The isolated Chrome
endpoint remains unavailable, so no new browser smoke is claimed.

The Patient Ticketing residual reviewed its remaining 30 canonical support
paths and closed an architecture-shaping worklist index mismatch. The named
worklist now declares a 30-query budget, remains constant between one and 25
tickets, and uses an institution, queue-set, open-state, priority, creation-time
and ID index without filesort. Caching remains disabled because ticket state,
ownership and permissions must be authoritative. A clean seven-schema
migration, tiny seed and schema verification passed. The integrated ticketing
pack passed 23 tests with 264 assertions, followed by a 12-test seed and
worklist rerun with 83 assertions. Both legacy appointment-type defaults now
have stable portable codes. Reusable transition graphs, queue event-type and
event-context rules, per-user runtime widget assignments, a safe bounded bulk
move and the session-specific virtual-clinic alert remain explicit deferrals.
The isolated Chrome endpoint remains unavailable, so no new browser smoke is
claimed.

The shared medication residual reviewed its remaining 23 root canonical paths
and closed the active common-list consumer gap. Medication Management and
History Medications now receive institution-scoped Common eye and Common
systemic quick picks, with optional site and subspecialty rules, deterministic
configured order, stable-identity de-duplication and a 50-row bound per group.
The consumer is uncached and its query count remains constant from two matching
sets to 27. The wider medication pack passed 69 tests with 1,623 assertions and
the production frontend build passed. The legacy 2017 History Medications
migration provides path-specific retirement evidence for the archived
patient-level medication and adherence screens; archive rows remain in the
cutover inventory. Full production DM+D ingestion, historical imports and
backfills, legacy optional picker filters, specialist PGD and PSD consumers,
exact visual and physical output, and clinical UAT remain explicit deferrals.

The legacy Request queue residual reviewed 57 canonical paths and established
the device-import boundary without inferring a clinical transform. The canonical
`POST /api/device-imports` operation accepts the evidenced `dicom_request`,
streams its payload to protected object storage, hashes replay identity, and
rejects divergent retries. Queue work requires the exact `device-import`
container role. An expiring single-owner queue lease and independent request
leases cap `dicom_queue` at its legacy five active requests, recover abandoned
work, and apply a bounded 20-attempt retry policy. The claim query remains
constant from one to 100 ready rows and names its queue, status, availability,
and ID index without filesort. The focused intake, manifest, permission-first,
and telemetry pack passed 23 tests with 2,582 assertions. Generic queue
administration, service-account authentication, payload-family limits,
acknowledgement semantics, routine execution and logging, and all OphGeneric
clinical transforms remain explicit zero-credit deferrals pending the traffic
corpus. The isolated Chrome endpoint remains unavailable; this API-only seam
does not claim a browser smoke.

The Therapy Application presentation census reviewed its 25 pending legacy
view paths and corrected one previously misclassified PDF path. The lifecycle
aggregate now snapshots institution ownership and uses bounded institution,
patient, status and applied-date indexes rather than deriving tenancy through
neighbouring-table joins. A clean seven-schema migration, tiny seed and schema
verification passed. The integrated Therapy Application, injection-warning,
manifest and ledger pack passed 63 tests with 3,385 assertions; its uncached
worklist remains four queries from one to 31 rows and the optimizer-selected index plan has
no filesort. Email, PDF, recipient, file-bundle, intervention-detail and report
behavior remains explicit zero-credit work under DIV-095 and DIV-096. The
isolated Chrome endpoint remains unavailable, so no browser smoke is claimed.

The matching Therapy Application migration census reviewed 43 pending ledger
rows: 25 canonical paths and 18 secondary feature mappings. Supported aggregate,
site, consent, comments, history, diagnosis-scope, paper-consent, historical-state
and validity-warning contracts map to verified target schema and behavior.
Arbitrary decision trees, exact legacy fixture import, detailed interventions,
treatment-number and existence-only lookbacks, shortcodes, sender and recipient
configuration, email history and automatic submission remain path-specific
zero-credit deferrals. That checkpoint verified 14,125 canonical paths, 1,418
pending reviews and 43.5051 percent weighted coverage. The same integrated pack
passed 63 tests with 3,385 assertions.

The follow-on Therapy Application model, factory and test censuses reviewed 52
pending rows without raising canonical coverage. They copied existing evidence
only to secondary mappings and kept email, recipient, cost, arbitrary-decision
and detailed-intervention behavior at zero credit. The remaining configuration,
command, report, helper, seeder, service and small admin census reviewed a further
20 rows. It confirmed that two copied common-drug fragments have no caller in the
pinned module and recorded the funding report, file collection, resend, alert and
visual-acuity decision behavior as path-specific deferrals. The audit also found
and corrected treatment-only injection-drug and validity fields that had been
attached to the institution admin screen. A focused contract now fixes their
ownership to the Therapy Application Treatments screen. The integrated manifest,
Therapy Application, injection-warning and ledger pack passes 64 tests with 3,391
assertions. That checkpoint verified 14,125 canonical paths, zero missing paths,
1,388 pending reviews and 43.5051 percent weighted coverage.

The Therapy Application tail then reviewed all 47 duplicate presentation and
script mappings and the three remaining canonical image assets. The duplicate
rows reuse only canonical evidence; the two legacy navigation icons and funding
watermark remain zero-credit visual and output-fidelity work. No pending path now
remains in the pinned Therapy Application module. The shared Leaflets shell also
reconciled five canonical and ten secondary paths to the existing portable admin,
PDF storage, permission and validation contracts. Its focused manifest and ledger
pack passes 22 tests with 2,497 assertions. Finally, four post-hoc Injection
Management renumbering paths remain zero-credit ongoing-action work because saved
series are intentionally immutable, and two general address-administration paths
remain zero credit while only the reusable contact seam exists. The six Admin
test seeders are also fully reviewed. Deterministic target fixtures replace the
procedure and Operation Note personnel data, and partially replace mailbox,
clinical-team and mixed multitenancy data without claiming deferred team
hierarchy or exact assignment-screen behavior. Worklist definition generation,
site display contexts and patient population remain zero-credit work under
DIV-300. The seven remaining pending Worklist-named paths are now reconciled as
well. The shared WorklistPatient transfer shape receives only partial credit for
the indexed current ClinicalPathway snapshot. Definition ordering, display
contexts, wait-time rules and the migration-time IVT historical cutoff remain
explicit zero-credit deferrals. The focused Next Steps and ledger pack passes 12
tests with 146 assertions. The final six pending Admin paths are now reviewed.
Portable scoped settings and attachment types partially replace the subspecialty
browser controller, while PAS connection JSON, identifier assignments, update
policy and ordered patient-resolution rules remain zero-credit until a canonical
PAS ingestion contract owns them. The Settings, Event Attachment and ledger pack
passes 18 tests with 171 assertions. The shared Medication Set DTO and its
Eloquent mapper are replaced by the stable-code portable family and atomic
composition projection, with a focused six-test and 53-assertion pack. The
remaining 14 Medication Set models, repositories, factories and tests now map
to the same stable-code configuration, taper, automatic rebuild and bounded
consumer contracts. The integrated Medication Set, Prescription, common
consumer and ledger pack passes 30 tests with 997 assertions. The FileLedger
verifies at 14,125 canonical paths, zero missing paths, 1,339 pending reviews and
43.6799 percent weighted coverage. Eight embedded runtime seam rows are now
reconciled too. Native Laravel queued jobs replace the shared job marker and
dispatcher wrappers, named connection transactions replace the ambiguous
default connection wrapper, and webhook HTTP remains inside the durable bounded
delivery worker. The webhook, system event, audit and ledger pack passes 43
tests with 173 assertions. The FileLedger now has 1,331 pending reviews and
43.7337 percent weighted coverage. The forty-fourth cluster reconciles 12 shared
Yii compatibility and versioning foundation paths. That review found that model
event listeners did not cover Eloquent bulk updates or deletes. The application
now uses one history-aware Eloquent builder for ordinary and bulk writes to
models carrying the history marker. It locks and hydrates affected pre-images,
writes them in bounded batches on the owning connection and transaction, ignores
maintenance-only changes, and keeps query growth constant from one to 100 rows.
The focused history, event deletion, Colour Vision, schema, migration-policy and
ledger pack passes 25 tests with 213 assertions, and a representative high-write
clinical pack passes 63 tests with 1,945 assertions. The FileLedger now has 1,319
pending reviews and 43.8140 percent weighted coverage. The forty-fifth cluster
reviews all 52 embedded YiiAuth paths without mistaking authentication for
authorization parity. Native Laravel active-user login, session regeneration,
logout invalidation and audit replace 11 temporary Yii session and provider
compatibility paths. Thirteen item, assignment, repository and factory paths map
only to the bounded direct type-2 role projection. The remaining 28 global role
hierarchy and executable business-rule paths stay explicit zero-credit deferrals
under DIV-098 until a reviewed route-to-ability crosswalk exists. The login,
audit, role-audience, permission-first, configuration authorization, schema and
ledger pack passes 49 tests with 921 assertions.

The forty-sixth cluster closes the webhook notification and follow-up cycle by
preserving seven established xAPI read paths for events, patients, allergies,
diagnoses, history risks, associated contacts and contact labels. JSON response,
active-account, dedicated capability, one-request Basic authentication, audit,
stable route ownership and persistent-worker identity-reset boundaries are
explicit. The associated-contact resource stays at the same query count from 1
to 101 contacts and uses its bounded composite index. The combined xAPI,
webhook, manifest and login pack passes 51 tests with 2,728 assertions. The xAPI
census reviews 169 pending paths, credits only 75 evidenced read-side paths and
leaves writes, external-identifier lookup, generic event mapping, complete code
systems and OpenAPI generation as path-specific zero-credit deferrals under
DIV-467. The FileLedger now has 1,110 pending reviews and 44.2385 percent
weighted coverage.

The forty-seventh cluster reviews the 24 remaining canonical legacy Api module
adapter paths and their secondary mappings. It credits only the supported basic
authentication, bounded patient and Document reads, Document generation, and
source-owned EyeDraw policy evidence. The anonymous cross-origin signature
import, exact v1 and v2 response wrappers, generated CRUD views, and unused
presentation assets remain path-specific zero-credit deferrals. The empty
module asset and its commented test scaffold are obsolete with explicit
replacement evidence. The Document date predicate now uses an indexable
half-open range. The combined Document, patient-search, and EyeDraw pack passes
24 tests with 241 assertions. The FileLedger now has 1,086 pending reviews and
44.2833 percent weighted coverage.

The forty-eighth cluster reviews the 68 pending embedded-Laravel diagnosis
models, mappers, repositories, lifecycle hooks, event tests, and supporting
tests. The six mutable status buckets and serialized cumulative state map only
to the typed rebuildable current projection under DIV-075. During the audit the
required-diagnosis route was corrected from an unrelated orthoptics owner to
`F-OPHCI-DIAGNOSES`. Its context selector is an explicit seam: institution,
firm, subspecialty, age, gender and timeout modes are functional, while the
editor prompt and satisfaction history remain deferred under DIV-077. The route
is authenticated and audited, and its query budget stays at four from 1 to 101
matching requirements. The combined diagnosis, required-diagnosis, webhook and
system-event pack passes 48 tests with 319 assertions. A clean seven-schema
migration, complete configuration and tiny seed, schema verification, and the
seeded xAPI capability assertion also pass. The FileLedger now has 1,018 pending
reviews and 44.7081 percent weighted coverage.

The forty-ninth cluster reviews 25 pending patient mapper, identifier mapper,
repository, shared contract, shared DTO and matching unit-test rows. The schema
packet retains identifier-type institution and site scope, validation and
display rules, the legacy uniqueness shape, history, verification status and
source provenance. Patient presentation deliberately excludes integration-only
source data. Exact identifier and surname searches use bounded projections and
stay at four queries from 1 to 101 patients. Display ordering, identifier code
assignments, automatic numbering, complete PAS assignments and generic DTO or
repository envelopes remain deferred under DIV-468. The patient-identifier and
configuration pack passes 11 tests with 321 assertions; the identifier and
patient-search pack passes 11 tests with 112 assertions. The FileLedger now has
997 pending reviews and 44.8376 percent weighted coverage.

The fiftieth cluster reviews 86 pending embedded webhook mappings: 82 secondary
feature mappings and four canonical test-fixture paths. Stable subscription
codes, portable configuration, exact verified payloads, after-commit durable
enqueue, a six-query projection from 1 to 100 occurrences, bounded delivery,
acknowledgement, retry and authenticated xAPI follow-up replace the legacy
request-memory transaction stack. Legacy hard deletion is explicitly replaced
with deactivation so history remains attributable; an inactive subscriber gets
no new intent and pending work becomes terminal without HTTP. The focused pack
passes 30 tests with 120 assertions. Fifty-six unsupported or unverified paths
in the exact 174-path webhook feature ledger retain zero credit. The FileLedger
now has 993 pending reviews and 44.8767 percent weighted coverage.

The fifty-first cluster reviews 64 canonical embedded allergy mapper, model,
repository, shared DTO, service, observer, event, fixture and test paths. A new
institution-scoped `patient_allergy_current` pointer replaces the group-wise
maximum on the patient flag read path. Save and soft-delete writes rebuild the
pointer inside the clinical transaction under a patient row lock, and the
upgrade migration backfills exact latest live source elements. Patient flag
reads stay at two clinical queries from 1 to 100 patients and use the serving
scope index. The focused allergy and flag pack passes 11 tests with 160
assertions; a clean seven-schema migration, complete configuration and tiny
seed, schema verification, and seeded xAPI capability assertion pass. The
multi-patient general-health summary, importer reconciliation, exact header
wiring and legacy SQL compatibility view remain deferred under DIV-469. The
FileLedger now has 929 pending reviews and 45.2767 percent weighted coverage.

The fifty-second cluster reviews 25 canonical embedded History Risks mapper,
model, repository, shared DTO, observer, event, fixture and test paths. The
patient flag page now uses maintained institution-scoped current pointers for
accessibility, allergies and history risks, eliminating every group-wise latest
query on that page. Editor saves, element and event soft deletion, and
safeguarding risk resolution rebuild the relevant pointer in the clinical
transaction under a patient row lock. Each of the three reads stays at two
clinical queries from 1 to 100 patients and uses its scope index. The focused
patient-safety pack passes 33 tests with 468 assertions, and the clean
seven-schema migration, complete configuration and tiny seed, schema
verification, and seeded xAPI capability assertion pass. Import reconciliation,
the multi-patient general-health worklist, complete PAS mapping, and independent
proof of all headers, popups, correspondence and whiteboards remain deferred
under DIV-470. The FileLedger now has 904 pending reviews and 45.4393 percent
weighted coverage.

The fifty-third cluster reviews 70 canonical embedded Clinic Outcome mapper,
model, repository, contract, shared DTO, observer, event, fixture and test
paths. The direct aggregate preserves ordered follow-up, discharge and virtual
review entries, immutable relationship snapshots, conditional clinical
invariants, episode state, one patient ticket, bounded patient history and
seven portable configuration families. Stable created, updated and deleted
event payloads enter the transactional outbox only after commit. The due-work
query uses its patient and state index, and patient history is institution
scoped, keyset paginated and capped at 50 rows plus one. The focused aggregate,
history, webhook and configuration pack passes 48 tests with 380 assertions.
Automated-event linkage, the aggregate xAPI resource, RTT, PAS, correspondence,
pathway checkout, Injection Management AUTO rows, reports, worklists, search,
public generation and exact UI remain deferred under DIV-298. The FileLedger
now has 834 pending reviews and 45.8850 percent weighted coverage.

The fifty-fourth cluster reviews the final 23 pending embedded
OphCiExamination paths: Diagnosis and singular Risk mappers, models,
repositories, DTOs, codeables, services, provider, factories and tests. The
direct Diagnosis record and rebuildable patient projection replace its generic
repository and stay at three presentation queries for small and large fixtures.
History Risks preserves the tri-state values, current negative defaults,
codeable metadata, direct event writes and current pointer. The request-built
element registry replaces container bindings without worker-persistent state.
The generic DTO create-event-with-elements service remains deferred under
DIV-467 rather than receiving inferred parity. The focused diagnosis, risk,
xAPI and event-view pack passes 43 tests with 596 assertions. No embedded
OphCiExamination path remains pending. The FileLedger now has 811 pending
reviews and 46.0316 percent weighted coverage.

The fifty-fifth cluster reviews 42 canonical embedded core configuration model,
factory and unit-test paths. Stable contact labels, countries, disorders, OPCS
codes, settings, patient identifier types and statuses, services, specialties,
subspecialties, sites, institutions and firms map to direct configuration
models, portable natural-key families, complete history and authorized
administration. The clean seven-schema migration, tiny seed, schema verification
and focused configuration pack pass, including 50 tests with 746 assertions.
The contacts test now derives its URL from deployment configuration and selects
the row it created without depending on earlier test data. Legacy
institution-specific authentication methods and active-method tenant selection
remain behind the stable provider-registry seam in DIV-471. The FileLedger now
has 769 pending reviews and 46.2966 percent weighted coverage.

The fifty-sixth cluster reviews 24 canonical embedded audit model, lookup
satellite, factory and unit-test paths. The accepted DIV-010 design replaces
eight normalized models and their lookup writes with one append-only audit row
and stable scalar snapshots. Access audits survive clinical rollback while
routine write audits join the clinical transaction. Login, failure, logout,
patient and event access, search and clinical rollback behavior pass 10 focused
tests with 54 assertions. Historical satellite ETL and production-shaped
throughput remain deferred under DIV-010 and DIV-012. The FileLedger now has
745 pending reviews and 46.4354 percent weighted coverage.

The fifty-seventh cluster reviews seven canonical shared xAPI codeable-concept
service and test paths. The bounded read model emits stable coding objects and
code-system URLs for the webhook follow-up resources. JSON and capability
boundaries, one-request authentication reset, read audits, named route
ownership, no-state responses and constant associated-contact query growth all
pass six focused tests with 163 assertions. The generic multi-system search
cache and broad code-system catalogue remain deferred under DIV-467. The
FileLedger now has 738 pending reviews and 46.4722 percent weighted coverage.

The fifty-eighth cluster reviews 19 canonical shared core service and service
test paths. Request-built typed services and direct Eloquent aggregates replace
generic repository access for patient, episode, event, element, contact,
context and user behavior. Event creation and episode claiming, all-or-nothing
element batch saves, authentication, stable context relationships and bounded
event-view growth pass 23 focused tests with 149 assertions. Provider-specific
global authentication selection remains deferred under DIV-471. The FileLedger
now has 719 pending reviews and 46.5804 percent weighted coverage.

The fifty-ninth cluster reviews 39 canonical embedded support model, factory
and unit-test paths. Address, location, GP and practice facts map to
institution-owned contact snapshots; procedure and complication catalogues,
setting metadata and specialty types map to portable configuration; follow-up
periods map to Clinic Outcome; CVI retains a bounded ethnicity snapshot; and
local authentication remains direct while external providers stay behind
DIV-471. Configuration, settings, Clinic Outcome, CVI validation and login pass
36 focused tests with 432 assertions. The FileLedger now has 680 pending
reviews and 46.7855 percent weighted coverage.

The sixtieth cluster reviews 75 canonical embedded model-to-DTO mapper and
mapper-test paths. Direct models, typed clinical aggregates, bounded
projections and portable configuration replace the generic mapper layer for
configuration, contacts, events, diagnoses, Clinic Outcome and the bounded CVI
ethnicity snapshot. Provider-specific authentication mapping remains behind
DIV-471 and no generic compatibility layer receives inferred parity. The
focused consumer pack passes 60 tests with 616 assertions. The FileLedger now
has 605 pending reviews and 47.1652 percent weighted coverage.

The sixty-first cluster reviews 83 canonical Laravel repository
implementations, shared repository contracts, concerns and unit-test paths.
Direct models, typed application services and bounded projections replace only
the repository calls exercised by current configuration, contact, event,
diagnosis, Clinic Outcome, CVI and login consumers. The generic DTO,
query-builder, codeable-concept and table-derived element repository framework
is not recreated under DIV-467, while external authentication selection remains
behind DIV-471. The dirty shared schema exposed one pre-existing exact-fixture
assumption in the contacts test; the clean seven-schema migration, tiny seed,
schema verification and full focused pack pass 84 tests with 1,031 assertions.
The FileLedger now has 522 pending reviews and 47.5552 percent weighted
coverage.

The sixty-second cluster reviews 63 canonical shared DTO, DTO contract, trait,
framework exception, fixture and unit-test paths. Stable configuration models,
typed contact and event aggregates, Diagnosis and Clinic Outcome records, and
the bounded CVI ethnicity snapshot replace verified transport objects. The
generic mutable DTO, mapper, patch, relation and internal exception framework
receives only low partial credit under DIV-467 and is not recreated. The focused
consumer pack passes 76 tests with 909 assertions. The FileLedger now has 459
pending reviews and 47.7664 percent weighted coverage.

The sixty-third cluster reviews 34 canonical embedded module factories, model
tests, compatibility fixtures and scope or history helpers. Diagnosis-state
factories map to the typed aggregate, Operation Note surgeon fixtures map to
portable eligible-surgeon configuration, and patient, contact and event model
tests map to their direct bounded consumers. Broad Yii compatibility and
version-tracker helpers receive low partial credit under DIV-467. The focused
pack passes 81 tests with 1,554 assertions, including fixed query growth for
diagnoses, event views and bulk history. The previously missing Patient Search
feature-progress row is now derived from its exact 27-path ledger. The
FileLedger now has 425 pending reviews and 47.9104 percent weighted coverage.

The sixty-fourth cluster reviews 18 canonical embedded DTO, mapper, repository,
model-test and Yii-compatible code-generator commands and templates. Source
inspection confirms they are development-only scaffolds for the generic layer
the target does not expose. They are explicitly deferred under DIV-467 with
zero coverage until a proven target extension workflow needs equivalent
tooling, so the census closes without inflating application parity. The
FileLedger now has 407 pending reviews and remains at 47.9104 percent weighted
coverage.

The sixty-fifth cluster reviews 34 canonical embedded Laravel framework shell,
configuration, build, public-entry, resource and repository-support paths.
Thirty paths retain direct target equivalents; the target skin, application
entry point and named JSON xAPI resources replace three others. Horizon remains
explicitly deferred under DIV-467 with zero credit. The focused pack passes 26
backend tests with 2,685 assertions and three JavaScript contract tests,
including privacy-bounded telemetry, query-free manifest generation, page
readiness and the 100-click home guard. The FileLedger now has 373 pending
reviews and 48.1138 percent weighted coverage.

The sixty-sixth cluster reviews 32 canonical embedded request, validation,
middleware, service, resource-exception and focused-test paths. Direct typed
identifier and fuzzy-date validation, authenticated JSON xAPI resources,
append-only audit, explicit settings precedence and request-built context
replace verified callers without worker-persistent generic state. Generic DTO
resource discovery and package version behavior remain partial under DIV-467.
The focused pack passes 57 tests with 2,985 assertions, including bounded
identifier and diagnosis queries, one-request authentication reset and
query-free route discovery. The FileLedger now has 341 pending reviews and
48.2677 percent weighted coverage.

The sixty-seventh cluster reviews the final 52 canonical embedded Laravel
application, provider, factory, migration and test-harness paths. Direct event
transactions, named routes, deterministic fixtures, surgeon eligibility,
diagnosis and xAPI boundaries retain evidence-backed credit. The exact
ephemeral failed-job schema is retained, while the unproven database queue
fallback, Horizon dashboard, event-group model and generic factory discovery
remain zero-credit deferrals. The focused pack passes 182 tests with 4,934
assertions. No canonical `oe-laravel/` path remains pending. The FileLedger now
has 289 pending reviews and 48.4867 percent weighted coverage.

The sixty-eighth cluster reviews the final 40 canonical shared-library paths.
Request-scoped context, typed settings, named routes, direct audit, stable
system events, bounded xAPI projections and clinical laterality retain direct
evidence. The generic event-owned writer and multi-system coding conflict layer
remain zero-credit deferrals under DIV-467. The focused pack passes 138 tests
with 3,587 assertions. No canonical `oe-shared/` path remains pending. The
FileLedger now has 249 pending reviews and 48.6874 percent weighted coverage.

The sixty-ninth cluster reviews the final 78 canonical shared-medication paths.
Portable medication configuration, automatic and tenant-scoped sets, shared
History and Management consumers, prescription safety, signatures, amendment
history and current-state projections retain direct evidence. The reachable
legacy adherence editor, generic attribute and form vocabularies, exact dm+d
bulk reference-data import and historical merge reconciliation remain explicit
zero-credit deferrals under DIV-280. The focused confidence pack passes 86 tests
with 1,979 assertions, including fixed query growth for automatic sets, common
consumers, patient medication projections and prescription history. No canonical
shared-medication path remains pending. The FileLedger now has 171 pending
reviews and 49.0752 percent weighted coverage.

The seventieth cluster reviews the final 43 canonical Examination schema and
configuration paths. Portable workflows, scoped draft restore points, typed
required diagnoses, visual acuity configuration, surgical history, Clinic
Outcome and correspondence or Biometry seams retain direct evidence. Further
Findings, exact visual acuity reporting views, the default iris colour,
per-event workflow completion, disorder time, incomplete-element auto-close and
unmapped fixture corpora remain explicit zero-credit or partial deferrals. The
focused pack passes 86 tests with 1,493 assertions; its single correspondence
failure on the long-lived shared schema is attributed to contaminated contact
fixtures because the complete 13-test Correspondence suite passes with 257
assertions after a clean seven-schema migration, tiny seed and schema verify.
No canonical Examination schema/configuration path remains pending. The
FileLedger now has 128 pending reviews and 49.2123 percent weighted coverage.

The seventy-first cluster reviews the final 40 canonical Examination UI
workflow paths. Shared raster controls, lazy element configuration, portable
workflow administration, IOP and Refraction contracts, device intake, event
presentation, pathway progression, visual-acuity correspondence snapshots and
renderer seams retain direct or partial evidence. CXL Outcome, Further Findings
and exact print or raster fidelity remain explicit zero-credit deferrals. A
stale Refraction assertion exposed by the focused pack now verifies the lazy
configuration endpoint and exact ordered vocabulary. The PHP confidence pack
passes 138 tests with 5,315 assertions and the JavaScript readiness, 100-click
guard and draft-refraction pack passes 3 tests. No canonical Examination UI
workflow path remains pending. The FileLedger now has 88 pending reviews and
49.3943 percent weighted coverage.

The seventy-second cluster reviews the final 35 canonical Examination General
Health and Safety paths. Patient diagnoses, required-diagnosis rules, common
systemic disorders, History Risks configuration, bounded History text and exact
allergy or risk system-event families retain direct evidence. CXL History,
History macros, procedure-to-risk assignments and medication-derived risk
discovery remain explicit zero-credit or partial deferrals. The focused pack
passes 113 tests with 1,252 assertions, including fixed diagnosis query counts
and stable outbox family mapping. No canonical Examination General Health and
Safety path remains pending. The FileLedger now has 53 pending reviews and
49.5372 percent weighted coverage.

The seventy-third cluster reviews the final 26 canonical Examination
domain-consumer paths. Portable workflow rules and element sets, bounded
injection booking, typed protected event attachments, feature-owned
correspondence generators and the institution-scoped Accessibility projection
retain direct evidence. The PASAPI V1 and V2 AIS adapters remain partial and
the CXL Outcome aggregate remains an explicit zero-credit deferral. The shared
confidence run passes 77 tests with 1,264 assertions before reproducing the
known fixture contamination in one Correspondence assertion; a clean
seven-schema migration, tiny seed and schema verification then pass the exact
Correspondence suite with 13 tests and 257 assertions. No canonical
Examination domain-consumer path remains pending. The FileLedger now has 27
pending reviews and 49.6624 percent weighted coverage.

The seventy-fourth cluster reviews the final 23 canonical Core Administration
Configuration paths. Portable administration, operation-note configuration,
Facial Injection configuration, document workflows and procedure-set consumers
retain direct or partial evidence. Exact procedure warnings and catalogues,
OEScape compatibility and bulk death-cancellation behavior remain explicit
deferrals. The first focused run exposed stale Facial Injection assertions for
the established lazy configuration contract and a semantic API fixture without
an owning institution. The corrected confidence pack passes 112 tests with
4,602 assertions. The FileLedger then has four pending reviews and 49.7368
percent weighted coverage.

The seventy-fifth cluster reviews the final four canonical paths: the legacy
BaseAPI and CoreAPI components, the Injection Management therapy-application
Cypress workflow and the therapy-application consent-settings migration. Typed
feature services, the application-surface manifest, Intravitreal Injection
warnings and per-treatment validity retain evidence. Broad Yii compatibility,
digital-consent handoff and exact presentation settings remain explicit partial
or zero-credit deferrals. The FileLedger verifies exact equality with the pinned
14,125-path manifest, matching blob SHA-1 values, zero missing paths and zero
pending canonical reviews. Weighted canonical coverage is 49.7578 percent.

The seventy-sixth cluster closes the three pending Therapy Application
secondary mappings and the reachable Event Export rendering seam. A
module-owned payload adapter produces a complete deterministic Therapy
Application snapshot with two bounded clinical queries for either one or two
eyes and registers before the renderer registry freezes. Mandatory, Optional
and Hidden warning modes, together with the absence of the retired fork-only
override setting, are explicitly characterized. A clean seven-schema
migration, tiny seed and schema verification pass the focused renderer and
warning pack with 37 tests and 673 assertions; the preceding full module pack
passes 46 tests with 890 assertions. The feature has no pending secondary
mappings and the FileLedger remains at 14,125 canonical paths, zero missing,
zero pending and 49.7652 percent weighted coverage.

The seventy-seventh cluster extends the isolated Event Export pipeline with
typed Document, Checklist and Phasing payloads and reconciles their duplicate
legacy mappings. Checklist retains ordered snapshotted definitions and answers
in three bounded clinical queries. Phasing retains snapshotted instruments and
at most 96 ordered readings in two bounded clinical queries. Both fail closed
on overflow. Document uses three bounded metadata queries, exposes no protected
storage locator or file content, and fails closed for file-bearing Events until
bounded image and PDF composition exists; comments-only output is complete. Two
clean seven-schema migrations, tiny seeds and schema verifications pass the
focused packs with 56 tests and 384 assertions, then 36 tests and 220
assertions. The Event Export feature is 73.7 percent across its exact 55 paths,
and the FileLedger verifies 14,125 canonical paths, zero missing, zero pending
and 49.7885 percent weighted coverage.

The seventy-eighth cluster adds a complete typed Request Form payload to the
isolated Event Export pipeline. One clinical query retains the snapshotted form
identity, status, typed definition and answers, administration notes and change
metadata without patient or internal configuration identifiers. The expanded
100-field fixture remains one query and missing source state fails closed. A
clean seven-schema migration, tiny seed and schema verification pack passes 46
tests with 420 assertions. Event Export reaches 75.4 percent across its exact 55
paths, Core Webhooks reaches 67.9 percent across its exact 231 paths, and the
FileLedger verifies 14,125 canonical paths, zero missing, zero pending and
49.7951 percent weighted coverage.

The seventy-ninth cluster adds the complete Operation Booking aggregate to the
isolated Event Export pipeline. Five indexed clinical reads retain the current
booking, schedule, contact and preassessment snapshots plus ordered procedures,
anaesthetic types, diagnoses and unavailability windows. Each child family is
capped at 64 rows and overflow fails closed. The small and large fixtures remain
five queries and expose no internal identity or import fields. A clean
seven-schema migration, tiny seed and schema verification pack passes 48 tests
with 675 assertions. Event Export reaches 77.1 percent across its exact 55
paths, Core Webhooks reaches 68.3 percent across its exact 231 paths, and the
FileLedger verifies 14,125 canonical paths, zero missing, zero pending and
49.8018 percent weighted coverage.

The eightieth cluster adds a complete Laser payload to the isolated Event
Export pipeline. Two indexed clinical reads retain the snapshotted site, device,
operator, six drawing slots and at most 50 ordered per-eye procedures with their
unit-specific measurements, lenses and complications. Overflow fails closed,
and the small and large fixtures remain two queries without internal identities
or import provenance. A clean seven-schema migration, tiny seed and schema
verification pack passes 40 tests with 354 assertions. Event Export reaches
78.8 percent across its exact 55 paths, Core Webhooks reaches 68.7 percent
across its exact 231 paths, and the FileLedger verifies 14,125 canonical paths,
zero missing, zero pending and 49.8084 percent weighted coverage.

The eighty-first cluster adds a complete Operation Note payload to the isolated
Event Export pipeline. Five indexed clinical reads retain the snapshotted site,
theatre, source mode and booking reference, surgeon, personnel, anaesthetic
selections, instructions, generation choices, procedures and typed section
content. Each child family is capped independently at 64 rows and overflow fails
closed. Recursive internal identifiers, usernames, source booking identifiers
and import provenance are excluded, and the small and large fixtures remain five
queries. A clean seven-schema migration, tiny seed and schema verification pack
passes 65 tests with 1,295 assertions. Event Export reaches 80.5 percent across
its exact 55 paths, Core Webhooks reaches 69.1 percent across its exact 231
paths, and the FileLedger verifies 14,125 canonical paths, zero missing, zero
pending and 49.8151 percent weighted coverage.

The eighty-second cluster adds a complete Messaging payload to the isolated
Event Export pipeline. Three indexed clinical reads retain the immutable
message type, status, text, sender and thread summary with at most 128 ordered
recipient and comment snapshots. Overflow fails closed, and internal patient,
institution, mailbox and configuration identifiers plus import provenance are
excluded. The small and large fixtures remain three queries. A clean
seven-schema migration, tiny seed and schema verification pack passes 45 tests
with 355 assertions. Event Export reaches 82.3 percent across its exact 55
paths, Core Webhooks reaches 69.5 percent across its exact 231 paths,
OphCoMessaging reaches 93.1 percent across its exact 86 paths, and the
FileLedger verifies 14,125 canonical paths, zero missing, zero pending and
49.8217 percent weighted coverage.

The eighty-third cluster adds a complete Prescription payload to the isolated
Event Export pipeline. Four indexed clinical reads retain the immutable
prescription, ordered medication and taper snapshots, dispensing data, primary
signature and secondary-signature roles. The authoritative limits of 50 items
and 20 tapers per item are retained, secondary signatures are capped at 64, and
overflow fails closed. Internal patient, configuration and source identifiers,
usernames and import provenance are excluded. The small and large fixtures
remain four queries. A clean seven-schema migration, tiny seed and schema
verification pack passes 55 tests with 1,099 assertions. Event Export reaches
84.0 percent across its exact 55 paths, Prescription reaches 55.9 percent
across its reconciled 235 paths, and the FileLedger verifies 14,125 canonical
paths, zero missing, zero pending and 49.8284 percent weighted coverage.

### 15.2 Frozen-scope integration verification

New functional scope stopped at 06:30 BST after cluster 83. The required single
full Pest run completed with 2,211 passed, 133 failed and 34,151 assertions. It
is not recorded as a passing full suite. Representative clean-schema isolation
found one attributable application regression: webhook capture converted
missing legacy institution ownership to zero before the existing authenticated
institution fallback could run. The capture and payload boundary now preserve
null ownership, normalize legacy zero to null, still reject negative ownership,
and retain the transactional outbox fallback. A focused regression test proves
the fallback.

The other sampled failures were stale tests that expected every inactive
Examination element configuration inline, plus two manager schedule assertions
run under the web role. The tests now follow the named lazy configuration
endpoint and the clean-room verifier can select the runtime role explicitly.
Independent seven-schema reruns pass Adnexal 13 tests and 150 assertions,
Clinical Management 13 and 225, Drug Administration 3 and 49, Refraction 14 and
195, Retinoscopy 13 and 190, and manager-role optometrist portal delivery and
retrieval 8 and 74. A final foundation pack passes 90 tests and 3,158 assertions
across webhooks, outbox and xAPI, request telemetry, home rate limiting, the
application-surface manifest, EventView query growth and FileLedger integrity.
A broader lazy-configuration regression pack passes 194 tests and 2,956
assertions across 21 Examination element families. A clean schema and storage
pack passes 39 tests and 560 assertions across correspondence attachments,
automatic medication sets and their consumers, device-import leasing, patient
identifiers and flag projections, history twins, and configuration export and
import. Its correspondence query gate now compares one related row with 121
related rows, avoiding the false zero-row eager-load difference while retaining
the fixed query-count and serving-index assertions.
A separate patient-safety and case-search integration pack passes 51 tests and
710 assertions. It covers maintained allergy, accessibility and history-risk
state, portable medication criteria with fixed cohort query growth, diagnosis
projection reconciliation, required-diagnosis policy, and authenticated event
search.
A cross-module clean-schema pack passes 59 tests and 879 assertions for
Biometry calculation and import boundaries, Therapy Application lifecycle and
rendering, Patient Ticketing ownership and bounded worklists, and protected
genetics/device-usage reporting.
A further clinical integration pack passes 110 tests and 1,738 assertions for
Medication Management, injection workflows, Clinical Outcome, EyeDraw policy,
linked-device file storage, login, and associated-contact security.
All renderer payload adapters then pass together at 37 tests and 258 assertions,
covering deterministic bounded payloads, fail-closed child limits, missing
element rejection, and registration before renderer freeze. At 09:18 BST the
original post-08:00 integrated checkpoint was recorded. The user-requested
12:00 BST continuation keeps functional scope frozen and accepts only
integration verification or attributable corrections.

At 09:22 BST, the remaining webhook, outbox, manager API, xAPI resource, and
Ophthalmic Surgery changed-surface clean pack passed 86 tests and 782
assertions after a fresh seven-schema migration, tiny seed, and schema
verification. It confirms canonical transport-neutral delivery, post-commit
outbox behavior, bounded claims, xAPI persistent-worker isolation, and the
Ophthalmic Surgery contract without opening new functional scope.

At 09:26 BST, an independent clean-room FileLedger integrity pack also passed
2 tests and 22 assertions, including the immutable pinned-source equality check
and the `oe:porting-ledger:verify` command output.

At 09:44 BST, the two stale Correction Given tests were aligned with the
existing lazy configuration contract: EventView exposes no source configuration
until its named configuration endpoint is requested. The focused clean-room
pack passed 9 tests and 129 assertions, then the complete staged PHPUnit and
Pest surface passed 620 tests and 10,615 assertions after a fresh schema
migration. This was an assertion correction only and opened no new functional
scope.

At 09:50 BST, a static migration audit found one application-clock `now()`
call in the outbox payload migration. It now uses the database
`CURRENT_TIMESTAMP(6)` expression, preserving the historical state transition
without application-clock behavior. The affected fresh-schema webhook, outbox,
manager API, xAPI resource and Ophthalmic Surgery pack passed again at 86 tests
and 782 assertions; the audit reports no remaining prohibited migration calls.

At 09:55 BST, the complete staged PHPUnit and Pest surface passed again after
that migration correction: 620 tests and 10,615 assertions in 142.26 seconds
after a fresh schema migration.

The ledger command independently reports 14,125 canonical paths, 18,421 rows,
zero missing, zero pending review and 49.8284 percent weighted coverage. Changed
PHP files pass scoped Pint validation across 209 staged files, repository diffs
pass whitespace checks, and the isolated
renderer image passes its live PDF, PNG, capacity, context cleanup and bounded
telemetry contract. The local production web image passes its complete image
contract at 223,366,255 bytes. The production frontend build, three JavaScript
contract tests and strict Composer validation are green. The unavailable
isolated Chrome endpoint is the only execution blocker: affected browser smoke
and exact output fidelity are deferred and are not claimed.

The repository-wide Pint invocation also identifies one style issue in the
untouched `PermissionFirstRouteAuthorizationTest.php`; it is a pre-existing
baseline issue and is outside the frozen rewrite diff.

## 16. Active subplan - 2026-08-31 to 2026-09-02

### 16.1 Persistence, baseline and terminal condition

The durable goal is:

`Continue the OpenEyes Laravel rewrite from the pinned baselines. Do not
complete, hand off, or voluntarily idle before
2026-09-02T07:00:00+01:00. Finish only at the first safe integrated checkpoint
at or after that time.`

The run starts at legacy `ad2324084788608246a8250e817198c2f26a4fd6`, Laravel
`bac68960899df26f26427ea24ed81ea83849b11e`, and Docker
`ef578cd1a85a536bdfb8b7b746a07d831ac0ecee`. The FileLedger starts at 14,125
canonical paths, 18,421 rows, zero missing, zero pending, and 49.8284 percent
weighted coverage. The verified focused surface has 620 passing tests and
10,615 assertions. The prior complete Pest attempt has 2,211 passing, 133
failing, and 34,151 assertions and is not claimed green.

Seventy percent weighted coverage is a loose aim only. A lower honest result is
accepted when the remaining available work is lower value than the security,
performance, clinical, integration, or final-verification work in this subplan.

### 16.2 Run schedule

| Window | Work | Acceptance |
|---|---|---|
| Start to 14:00 BST, 31 August | Record this correction and master ordering, activate the durable goal, fetch and verify both writable remotes, create the paired branch, review existing staged ownership, and preserve the first checkpoint. | Baselines, deadline, known failures, branch, queue, and dual terminal condition are recorded. |
| 14:00 to 15:30 | Time-box major component security viability to 90 minutes. | PHP, Laravel, FrankenPHP, MariaDB, Redis, Node build tooling, Chromium, Puppeteer, base images, authentication, and SSO have support state, reachable critical risk, mitigation, proof link, and replacement decision. |
| 15:30 to 20:00 | Reproduce and classify the 133 full-suite failures. Fix attributable failures only and retain focused green gates. | Focused tests remain green; each remaining full-suite failure has current evidence and ownership. |
| 20:00 to 23:00 | Recreate the stale isolated Chrome sidecar with the existing Docker setup and run affected no-retry browser smokes. | Page readiness, guarded navigation, renderer readiness, and affected user workflows have current browser evidence or an exact external blocker. |
| 23:00 to 04:00 BST, 1 September | Build the test-only query-plan inspector, operation budgets, command, and tiny/history-heavy profiles. | Missing indexes, unbounded scans, row growth, filesort, and temporary-table plans fail focused tests without leaking SQL into operational telemetry. |
| 04:00 to 12:00 | Apply query-plan gates to the highest-risk current reads. | EventView, patient summary/search, specialist worklists, NOD/reporting, and the next evidenced hot paths have explicit budgets and bounded waivers only where justified. |
| 12:00 to 02:00 BST, 2 September | Work the rolling functional queue one integrated slice at a time. | Each completed slice has behavior, authorization, invariants, small/large query proof, relevant schema/index evidence, FileLedger evidence, and one browser smoke where user-facing. |
| 02:00 to 07:00 | Freeze new scope. Reconcile ledgers and plans, run the final verification batch, fix attributable failures, stage the writable repository changes, show their diffs, and record the next checkpoint. | No new feature is open; staged diffs, branch tips, tests, coverage, performance evidence, and deferrals are coherent at or after 07:00. |

Admin tooltips and the shared field-help facility remain in the master-plan
backlog. They are not active-run work and do not displace query-plan or
functional integration time.

If execution runs late, lower rolling-queue items are dropped first. The
security gate, query-plan foundation, 02:00 scope freeze, and final integration
window are not compressed. A missing authoritative clinical rule defers only
that narrow behavior; it does not justify guessing or ending the run.

### 16.3 Rolling functional queue

1. Inspect the already staged attachment, device-import, medication-set,
   vision/refraction, and webhook work. Close the first incomplete acceptance
   packet and skip anything already complete; never rework a passing surface to
   inflate coverage.
2. Close remaining caller-evidenced Event Export or webhook payload parity.
3. Build the main worklist feature and API parity register, then finish its
   schema, current-projection, patient-safety, outbox, transport-neutral live
   event and delta recovery, generation, diagnostics, query-budget, and load
   acceptance packet. Preserve every one of the 88 behavioral parity items and
   old API compatibility. Private Reverb/Echo delivery is preferred, but it
   cannot begin until the shared instance hot lock, unchanged mapping writes,
   and global publisher lock are removed and verified. Do not rush a partial
   implementation into this run merely to claim breadth.
4. Take the next high-value canonical FileLedger slice only after the preceding
   work is integrated safely.

#### Worklist realtime scaling correction

The active worklist implementation is paused at the attendance reconciliation
checkpoint until this correction governs its next changes. The relational
`worklist_row_current` projection, transactional database outbox, authorized
snapshot, and HTTP delta remain authoritative. The live event contract is
transport-neutral. Laravel Reverb and Echo are the preferred implementation,
using private per-worklist channels, compact versioned `upsert` and `remove`
batches, one browser-memory snapshot, cursor recovery, and a visible degraded
state. WebSockets are notification transport, not clinical state. Full-list
polling and `please refresh` broadcasts are rejected.

All 88 `WL-001` through `WL-088` behavioral capabilities remain required. The
register wording for WL-002, WL-003, WL-004, WL-086, and WL-087 is extended for
high-water cursors, projection versions, authorization expiry, transport-neutral
recovery, migrated-data plans, and the final scale gate. No transport or scale
work marks a behavioral capability complete on its own.

The next implementation order is mandatory:

1. Integrate the already bounded attendance and appointment-order checkpoint.
2. Remove the ordinary same-worklist `worklist_instance` write lock. Stop
   rewriting unchanged mappings and intake issues, diff real changes, remove
   redundant reads, and prove query, rows-written, lock-wait, deadlock,
   redo-byte, transaction-time, and final-state budgets under hot-clinic writes.
3. Replace the single global Redis publisher lock with stable application-derived
   institution/worklist partitions, one expiring ordered lease per partition,
   bounded database claims, network I/O after claim commit, crash recovery,
   metrics, and a worklist-specific queue. `SKIP LOCKED` alone is insufficient.
4. Recheck snapshot and delta for one and 25 clinics on migrated-scale data with
   `ANALYZE FORMAT=JSON`, including actual rows, loops, pages, reads, sort work,
   and temporary-table work. Choose the multi-clinic query shape from measured
   I/O and concurrency. Do not force an index or join order.
5. Add dedicated Reverb Kubernetes workloads, central Redis scaling, `/app` and
   `/apps` routing, health checks, disruption budget, topology spread, graceful
   drain, explicit connection limits, fixed database connection budgets, custom
   HPA signals, and native event-loop capacity proof. The current image uses
   `ext-event`; `ext-uv` is only an alternative subject to compatibility and
   measured capacity.
6. Add private subscriptions, 100-250 ms display coalescing, browser patching,
   reconnect jitter, cursor recovery, degraded state, and access-policy expiry.
7. Pass the complete matrix below before any high-scale readiness claim.
8. Then implement administration explanations and safe generation controls,
   followed by institution-switched gradual rollout with authoritative state
   comparison.

Browser memory is the first cache, `worklist_row_current` is the bounded database
cache/projection, Redis is only a bounded replay cache, and the database outbox
is durable recovery. Shared Redis snapshot fragments remain a measured candidate
and are never assumed by the scale design. This is essential for thousands of
users whose clinic, filter, sort, role, and display configurations differ.
Every supported server-side filter and sort is a finite named query shape with a
budget; tests cover every individual shape, the worst combinations, and a
pairwise configuration set. Browser-only display choices create no server query
or channel variant.

| Scenario | Active final gate |
|---|---|
| Concurrent dashboards | 5,000 connected, plus a 10,000 stretch run; record sockets per pod, subscriptions, memory, event-loop lag, and reconnect rate. |
| Multi-clinic users | At least 1,000 dashboards watch 25 clinics each with correct authorization and bounded initial reads. |
| Subscription cardinality | 5,000 dashboards each watch 25 private worklist channels, producing 125,000 authorized subscriptions over 5,000 sockets without an authorization or reconnect storm. |
| Configuration diversity | 5,000 dashboards use a heavy-tailed mix of clinic selections, filters, sorts, roles, and display settings; a worst-case run gives every dashboard a unique configuration and no shared snapshot cache hit. |
| Hot clinic fan-out | 1,000 watchers receive 100 appointment changes per second; batching meets visibility objectives and final state is exact. |
| Broad update burst | 250 appointment changes per second across many worklists; clinical writes remain bounded and oldest outbox age recovers after the burst. |
| Identical cold snapshots | 100 simultaneous identical requests across web pods do not stampede MariaDB; single-flight is required if shared caching is enabled. |
| Unique pod traffic | 100 simultaneous unique snapshot requests forced to one web pod remain within connection budgets and shed overload predictably. |
| Same-clinic writes | Concurrent updates show no instance-row serialization, deadlock accumulation, lost projection version, or incorrect count. |
| Publisher skew | One hot partition does not delay unrelated partitions and order is exact within each worklist. |
| Mixed Reverb features | Expected peak traffic from other realtime features does not breach worklist latency or disconnect objectives. |
| Reverb pod loss | Kill or drain a pod; clients reconnect with jitter and delta recovery reaches the exact fresh-snapshot state. |
| Redis loss | Clinical writes continue, dashboards show degraded state, and recovery creates neither a polling nor reconnect swarm. |
| MariaDB pressure | Query, I/O, lock, redo, binlog, and connection budgets hold; backpressure protects clinical writes first. |
| Large-data plans | One- and 25-clinic `ANALYZE FORMAT=JSON` evidence has bounded rows and pages with no unbounded sort or temporary-table work. |
| Authorization change | Revoked access cannot keep receiving live patches or recover rows from the old worklist. |

The 100-per-second hot-clinic and 250-per-second broad gates are deliberately far
above hundreds of appointment updates per minute. They are sustained workload
gates, not brief request spikes. Run long soaks as well as peaks. Initial service
objectives are snapshot p95 at most 750 ms under agreed concurrency, visible
change p95 at most one second and p99 at most two seconds after commit, healthy
oldest outbox age below two seconds, exact reconnect recovery, and no lost
committed state or unauthorized row. The previous 500-dashboard and
50-change-per-second test remains an early test only.

The next tranche also evaluates optional database connection pooling after the
representative migrated-data harness has measured real connection demand. It is
not implementation work for the current checkpoint. The comparison keeps direct
connections as a supported mode and covers both multi-container, multi-node
deployments and older single-host monoliths. It must measure backend connection
caps, TLS/authentication reuse, burst smoothing, read routing, and observability
against the added stateful dependency, queueing latency, transaction/session
state safety, prepared statements, temporary tables, sticky reads, failover,
clinical workload priority, and pool-loss recovery. Enabling or disabling the
pool must not change application repository code or connection naming, and a
pool cannot replace admission control or the fixed deployment connection budget.

The later admin/configuration tranche must also implement the master-plan
deployment-owned setting override contract. It starts from the existing
`OE_BANNER_SHORT` behavior but uses one declared resolver and metadata registry:
an environment override wins only for an explicitly eligible setting, the
admin field becomes disabled and visibly deployment-managed, secret values stay
redacted, and omitting the override preserves today's database-backed behavior.
This is a stable configuration seam, not work for the current checkpoint.

### 16.4 Query-plan implementation gate

The test-only contract is a `QueryPlanInspector`, a declarative
`QueryPlanBudget` registry keyed by application-surface operation id, and
`oe:query-plan:verify --profile=tiny|history-heavy --json=<path>`. It inspects
bounded SELECT statements only. It uses `EXPLAIN FORMAT=JSON` with a traditional
fallback. Evidence records selected and possible indexes, but the gate does not
force or require a named optimizer choice. It fails unbounded ALL or index
scans, estimated-row growth, filesort, and temporary-table plans. SQL and
bindings stay in the test process and never enter request telemetry. Any waiver
is path-specific, row-bounded, owned, and justified.

Runtime queries must not use index or join-order hints. CI rejects `FORCE INDEX`,
`USE INDEX`, `IGNORE INDEX`, `STRAIGHT_JOIN`, and query-builder equivalents. An
exceptional hint requires the auditable registry and evidence defined by
master-plan section 5.8.0 decision 16. Static EXPLAIN cannot prove an actual disk
spill; that requires the later large-data runtime and slow-log gate.

Runtime analysis is not claimed by this run. `ANALYZE FORMAT=JSON`, MariaDB
extended slow-log plan statistics, the external legacy `UrlBenchmarkCommand`,
and route-driven elapsed-time benchmarking wait for a successful anonymized
production-scale migration rehearsal.

The later developer request profiler must not change the query shape being
built now. The repository already carries `fruitcake/laravel-debugbar` as a
locked development dependency, while production Composer installation excludes
all development packages. Before go-live, publish a narrow safe configuration
and prove all database connections and statements are visible with duration,
connection, application backtrace, accumulated database time, total request
time, request-local peak memory, and redirect, fetch, XHR, and Inertia capture.
The slow threshold highlights but does not filter. Bindings and request data,
public history storage, query-result replay, configuration and session
collectors, and third-party visual EXPLAIN remain disabled.

Built-in exact duplicate highlighting is not accepted as the N+1 gate because
the same query family with different bindings may not be grouped. Add a bounded
development-only query-family collector over `QueryExecuted` that normalizes
placeholders and groups by connection and application caller, then reports
count, cumulative and maximum duration, and first call site. Pair it with the
existing small-versus-large query-count tests and a bounded local/test
lazy-loading-violation rollout. Collection happens after execution, adds no
query comments or database statements, and does not wrap or reshape application
queries. Debugbar timing is attribution evidence only because collection itself
adds overhead; uninstrumented request telemetry and the later route benchmark
remain timing evidence.

After go-live, privacy-bounded OELOG identifies the named slow operation. The
detailed toolbar runs only in a private support or performance image against
representative anonymized data, combined with MariaDB slow-log and
performance-schema evidence. A production-only problem requires a separate
approved, audited, expiring diagnostic procedure. The ordinary production image
must contain no Debugbar package or route, and ordinary logs never contain SQL,
bindings, request values, debug datasets, raw URLs, or patient identifiers.

### 16.5 Security viability gate

The 90-minute review records component or image digest, support state, official
proof link, reachable exposure, mitigation or replacement decision, review
date, and owner. A component is replaced now only if it is end-of-life,
unmaintained, or has a reachable critical issue without a safe mitigation.
Security evidence is added to `docs/security/component-assurance.md`; raw scan
artifacts remain in CI or release storage. No secret, PHI, client data, private
host, raw URL, SQL, binding, or payload is recorded.

### 16.6 Final verification order

After the 02:00 scope freeze:

1. Verify exact FileLedger set equality, blob SHA-1, one canonical row, source
   classification, final disposition, and obsolete rationale.
2. Run focused tests for every changed boundary.
3. If schema changed, run a clean seven-schema migration, tiny seed, and schema
   verification.
4. Run the full Pest suite once when focused gates are green; record any
   remaining failure without converting it into a false pass.
5. Run tiny query-plan verification plus the seven-schema
   no-database-automation assertion. Run the history-heavy profile when its
   production-scale migration fixture exists; record that exact data dependency
   instead of treating tiny data as large-data proof.
6. Run strict Composer, scoped Pint, JavaScript tests, and the production
   frontend build.
7. Run renderer and production web image checks if affected.
8. Run affected Playwright flows once without retries.
9. Reconcile coverage, plans, security evidence, branch tips, staged diffs, and
   working trees.
10. At a later cleanup checkpoint, inventory disposable containers, networks,
    and named volumes by exact run or Compose project. Explicitly include stale
    `oe-patient*` and `oe-laravel*` test, debug, browser, web, database, and Redis
    containers. Review age, Compose ownership, activity, restart policy,
    mounted volumes, and memory use so abandoned environments cannot accumulate
    into host OOM pressure. Remove only exact reviewed projects. Remove a
    retained volume only after its test database and artifacts are no longer
    needed as evidence or for reproduction. Never use a broad Docker prune, and
    leave active or unidentified resources untouched.

Every hourly on-disk checkpoint records the current problem and acceptance,
completed evidence, current work, `next_item`, `after_next`, blockers,
deferrals, exact ledger and coverage values, query and plan changes, tests run
and deferred, and repository branch, staged-diff, and verification state.

### 16.7 Git delivery boundary

The later global repository rule supersedes the earlier one-off override. Both
writable application repositories remain on `rewrite/2026-09-02-0700`. Review,
stage, and show each bounded diff, but do not commit or push. There is no force
push, amend, hook bypass, hard reset, protected-branch write, or pull-request
mutation. Legacy OpenEyes stays read-only. Claude-kit plan changes also remain
staged and unpushed. Record exact branch tips, staged files, and verification at
each checkpoint.

### 16.8 Immediate next checkpoint after this run

The next checkpoint begins with a bounded human-readability and reuse review of
the code changed in this run before another broad functional slice opens. It
prefers clear names, short cohesive methods, explicit data flow, shallow
nesting, and ordinary framework conventions. Comments explain only non-obvious
clinical rules, security boundaries, concurrency, performance constraints, or
architectural reasons. A shared abstraction lands only when it makes at least
two real consumers easier to follow; otherwise the opportunity and trigger are
recorded in the master plan. There is no wholesale refactor, broad formatting,
directory reshuffle, or speculative abstraction. Focused behavior,
authorization, query count, and query-plan gates must remain unchanged or
improve. The current one-off Git override does not carry into that checkpoint.

### 16.9 Final rewrite migration-consolidation gate

After functional rewrite completion and before the first production-scale data
migration, inventory every Laravel migration by table and DDL operation. Fold
unreleased later column, index, foreign-key, default, and safe-transform changes
into the table's initial creation migration or bounded-context schema packet so
the database does not rebuild the same table repeatedly. Keep a separate
ordered data transform only where a real schema or data dependency requires it.

Prove the pre- and post-consolidation final schemas are equivalent across all
seven schemas, then run a fresh migration, tiny seed, representative import,
and DDL rebuild/timing audit. Record replacement mapping for each removed
migration. Never rewrite history already applied to a supported production
deployment; if any rewrite migration has shipped, retain its immutable upgrade
path and introduce a versioned fresh-install baseline instead. Every
unavoidable post-load DDL operation records its rebuild cost, locking behavior,
and online migration plan.

### 16.10 Hourly checkpoint - 2026-08-31 14:15 BST

- Current problem and acceptance: the component security viability gate is
  integrated. The active problem is reproducing the previous 133 full-suite
  failures at the current branch tips and assigning each failure group to an
  attributable rewrite defect, test-order or fixture defect, pre-existing
  baseline issue, or external execution blocker.
- Completed evidence: live component versions and official support sources are
  recorded. Composer and npm audits are clean. The raw production web scan found
  four compiled Go findings; reviewed reachability shows that all four affected
  handlers are absent from the production Caddy configuration, and version 2 of
  the OpenVEX record makes those assumptions explicit. The VEX-filtered web scan
  has zero High or Critical findings. The renderer retains 73 High and eight
  Critical Debian findings with no available fixed version and is not described
  as clean. Its production footprint was reduced by 252 unneeded packages and
  all global Node package-manager findings were removed while the full renderer
  contract stayed green. Puppeteer 25.8.0 now refuses readiness unless live
  Chrome exactly matches its declared 152.0.7977.42 revision. A separate useful
  note is stored at `/home/toukan/puppeteer-renderer-notes-2026-08-31.md`.
- Completed application boundary: login POST now has hashed five-attempt
  username-plus-address and 30-attempt address buckets. Focused login and audit
  verification passed 12 tests with 93 assertions, and scoped Pint passed. The
  security decision and proof links are recorded in
  `docs/security/component-assurance.md`.
- Current work: build one current development application image, run the full
  Pest suite once without retries, preserve the failure output, and group the
  current failures by first causal exception.
- `next_item`: reproduce and classify the full Pest suite at Laravel
  `0577035b01e1` and Docker `4b0c9af93660`.
- `after_next`: fix only attributable failure groups while retaining the focused
  security and 620-test rewrite gates, then recreate the isolated Chrome
  sidecar for the affected no-retry browser smokes.
- Blockers and deferrals: external SSO is still an unreached contract seam. The
  renderer's 81 unfixed Debian findings require a dated residual-risk decision
  on every release. Full security accreditation, penetration testing, and
  provider-specific SSO testing are not claimed. Browser verification remains
  deferred until the existing isolated sidecar is recreated.
- Coverage and ledger: unchanged at 14,125 canonical legacy paths, 18,421 total
  mappings, zero missing, zero pending review, and 49.8284 percent weighted
  coverage. No inventory row or security evidence was used to inflate coverage.
- Query and performance changes: no clinical query shape or page budget changed.
  Login bounding uses cache-backed limiter counters and adds no database query.
  The renderer remains capped at two active slots and continues to use one
  persistent browser with isolated contexts.
- Tests and builds: the renderer compatibility, capacity, PDF, PNG, cleanup, and
  telemetry image contract passed. A fresh development image initially exposed
  that exact Alpine package revision pins were no longer resolvable after an
  OpenSSH security revision. Development Git, Node 24, npm 11, and OpenSSH 10
  now accept security patches within their intended major line; the image builds
  successfully. The freshly built image passed the 12-test security pack and
  scoped Pint. Full Pest is pending this checkpoint.
- Repository and `verification_state`: Laravel commit `0577035b01e1` and Docker
  commit `4b0c9af93660` are pushed on `rewrite/2026-09-02-0700`; both working
  trees and pinned legacy OpenEyes are clean. These three Claude-kit plan files
  remain staged only. `verification_state=security-gate-green; full-pest-pending`.

### 16.11 Hourly checkpoint - 2026-08-31 17:17 BST

- Current problem and acceptance: the no-hint query-plan foundation and its first
  high-risk query set are integrated. Acceptance requires optimizer-selected
  bounded plans, no filesort or temporary table for the registered tiny-data
  operations, privacy-bounded evidence, a clean seven-schema migration, and a
  clean full suite after query statistics have changed.
- Completed evidence: `oe:query-plan:verify --profile=tiny` passes seven stable
  operation budgets for event and patient timelines, patient search, pharmacy,
  injection prescriptions, operation-booking waiting work, and the ready for
  second eye report. The post-full-suite evidence is
  `/home/toukan/openeyes-query-plan-evidence-clean-20260831/query-plan-after-full.json`
  with SHA-256 `4125a1bf1ac92df426aa5d08d280d4d01aaa81ee33603b53b14de3005d247094`.
  All seven plans report `filesort=false`, `temporary_table=false`, and bounded
  estimated rows. The evidence contains no SQL or bindings.
- Completed query correction: the ready for second eye report no longer uses a
  wide join whose chosen start table makes the final order unstable. It reads an
  institution-scoped ordered candidate page from the comments row, then hydrates
  at most 100 events with repeated institution and live-record checks. New imports
  snapshot institution; authoritative existing rows were backfilled; legacy rows
  with no event institution remain null and are excluded. The report has stable
  keyset paging and no small-to-large query-count growth.
- Completed policy: all current runtime and test optimizer hints were removed.
  The repository test scans application, migration, route, and test PHP for query
  builder hints, SQL index hints, `STRAIGHT_JOIN`, optimizer comments, and result
  hints. The exception registry is empty and requires an operation owner, reason,
  high-data evidence, concurrency evidence, and review trigger before any entry
  can pass.
- Current work: continue the rolling functional queue from the first genuinely
  incomplete caller-evidenced slice after pushing the Laravel query-plan
  checkpoint.
- `next_item`: inspect webhook and Event Export legacy-caller evidence against
  the already green canonical outbox and webhook payload tests, then close only
  a demonstrated parity gap.
- `after_next`: prepare the main worklist feature and API parity register from
  the ticket analysis without rushing its high-concurrency implementation.
- Blockers and deferrals: the history-heavy query-plan profile is deliberately
  unavailable until a production-scale migrated fixture exists. Static EXPLAIN
  cannot prove disk spill or concurrent cost. The later large-data gate must use
  runtime statement statistics, slow-log plan data, and workload concurrency.
  Browser smokes still require recreation of the stale isolated sidecar. The raw
  schema-metadata cache proposal is recorded for later design and is not being
  implemented in this checkpoint.
- Coverage and ledger: unchanged at 14,125 canonical legacy paths, 18,421 total
  mappings, zero missing, zero pending review, and 49.8284 percent weighted
  coverage. This performance checkpoint adds no inventory-only coverage.
- Query and performance changes: event timeline ordering now has an indexed ID
  tiebreaker; operation-booking waiting work uses an indexed generated live flag;
  the report candidate keys are co-located on the comments row; and plan budgets
  fail on cost properties without constraining MariaDB's index choice. The simple
  explanation is stored at
  `/home/toukan/ready-for-second-eye-query-plan-problem-2026-08-31.md`.
- Tests and builds: a fresh MariaDB 11.8 database ran exactly 296 migrations,
  loaded the tiny seed, and passed all seven-schema, history-twin, audit-partition,
  and hygiene checks. The broad focused pack passed 122 tests with 2,183
  assertions. Scoped Pint passed 30 files. The clean full Pest suite passed 2,356
  tests with 35,888 assertions in 684.18 seconds. Its JUnit evidence SHA-256 is
  `1740f7f32ec5d76ff6e023e8911e01c207d544658eabc81432005f8ab847e988`.
  The seven query plans passed again after the full suite.
- Repository and `verification_state`: Laravel is clean on
  `rewrite/2026-09-02-0700` at pushed commit `c2e892f624c7`; Docker is clean at
  pushed commit `4b0c9af93660`; pinned legacy OpenEyes is clean at
  `ad2324084788`. These Claude-kit plan files remain stage-only.
  `verification_state=query-plan-foundation-green; checkpoint-pushed`.

### 16.12 Hourly checkpoint - 2026-08-31 18:00 BST

- Current problem and acceptance: the exceptionally lightweight worklist is now
  bounded by a source-backed parity register, and the isolated browser gate is
  restored against current production images. The next acceptance boundary is
  one coherent worklist schema packet covering the system actor, appointment
  ordering, patient-safety projection, PAS mapping failures, current projection,
  and transactional outbox before any partial schema is opened.
- Completed worklist evidence: `docs/porting/worklist-parity-register.csv`
  records 88 unique `WL-001` through `WL-088` capabilities from legacy
  controllers, route and manager inventories, Cypress and Playwright flows, and
  the worklist Jira analysis. It covers dashboard, row, filter, pathway,
  configuration, generation, integration, concurrency, diagnostics, rebuild,
  manual, and security behavior. Each row names its canonical operation, legacy
  evidence, data class, performance contract, and acceptance condition. The
  guard test passes with 822 assertions.
- Completed triage: the generic Event Export webhook path already preserves its
  proven callers and payload contract. The schedule seam is deliberately
  deferred because there is no authoritative system-actor model or schedule
  registry and the current export revision is content-derived rather than the
  legacy last-modified marker. Per-event schedule preparation would also risk an
  N+1 path. The DICOM device-import boundary is already complete and its generic
  MIME, body-site, routine-library, and form-encoded candidates have no
  authoritative caller evidence, so neither surface was reworked for coverage.
- Completed browser recovery: the stale browser sidecar had lost Chrome and Xvfb
  and contained a runaway probe. It was recreated with its machine-local profile.
  The shared login probe now starts at the configured root, recognizes both Yii
  and Laravel forms, dispatches real input events for Vue, and fails on an
  unrecognized login page. A clean current production stack then completed the
  manager-owned seven-schema migration and tiny seed. In that stack, 100 rapid
  Home clicks issued exactly one Messages request, exposed the accessible busy
  state, ended at `/messages` with `oePageState=ready`, and emitted
  `oe:page-ready` contract version 1.
- `next_item`: assemble and review the coherent worklist schema packet from the
  88-capability register and existing patient, appointment, pathway, messaging,
  audit, and PAS contracts. Do not create tables until ambiguous ownership and
  ordering decisions are explicit.
- `after_next`: implement the smallest coherent projection/outbox foundation and
  its migration confidence pack, or record a narrow authoritative-rule deferral
  and advance to the next high-value canonical slice.
- Blockers and deferrals: the Event Export scheduling seam needs a system actor,
  schedule ownership, and stable revision contract. No running legacy web stack
  was available to repeat the Yii branch of the shared login probe, although its
  existing selectors and institution/site handling remain in place. Production-
  scale worklist load, runtime query I/O, and the history-heavy plan profile wait
  for migrated large data. The schema-metadata generation/cache proposal remains
  a raw later-design item; current source inspection found no request-path
  Laravel equivalent of Yii's repeated `SHOW FULL COLUMNS` behavior.
- Coverage and ledger: unchanged at 14,125 canonical legacy paths, 18,421 total
  mappings, zero missing, zero pending review, and 49.8284 percent weighted
  coverage. The parity register is acceptance evidence and adds no coverage.
- Query and performance changes: no production query changed. The worklist
  register fixes budgets of no more than four clinical and eight total snapshot
  queries, no more than two clinical delta queries, zero clinical reads per
  stream subscriber, and no medications or patient/event history on routine
  rows. The then-recorded 500-dashboard, 25-clinic, and 50-change-per-second
  test is retained only as an early gate; the active final gate is now the full
  matrix in section 16.3.
- Tests, builds, and `verification_state`: the worklist register test passes one
  test with 822 assertions and scoped Pint passes. The browser login script
  passes Node syntax checking in its container. Current production web and
  manager images built successfully; a clean manager migration, schema verify,
  and tiny seed completed; the no-retry browser smoke passed the readiness and
  100-click guards. Laravel is clean at pushed commit `2d6db8e57cc2` on
  `rewrite/2026-09-02-0700`; Docker remains clean at `4b0c9af93660`; legacy
  remains read-only at `ad2324084788`; Claude-kit changes remain stage-only.
  `verification_state=worklist-register-green; current-image-browser-green;
  checkpoint-pushed`.

### 16.13 Hourly checkpoint - 2026-08-31 18:53 BST

- Current problem and acceptance condition: establish the smallest coherent
  worklist write and read foundation without presenting it as full worklist
  parity. Appointment identity, source ordering, actor identity, clinic moves,
  cancellation and rebooking, current-row maintenance, unmatched evidence, and
  bounded dashboard ordering must be explicit and transactional. A small and
  larger fixture must use the same query count and the ordering plan must use
  neither filesort nor a temporary table.
- Completed evidence: audit now accepts explicit `user`, `manager`, and
  `integration` actors. The worklist schema packet separates versioned
  definitions and mappings in `oe_config` from authoritative instances,
  appointments, normalized source mappings, the decision-bearing current-row
  projection, privacy-bounded intake issues, and a transactional change outbox
  in `oe_clinical`. Appointment identity is
  `(institution_id, source_system, external_id)`. The writer rejects stale or
  conflicting source sequences, locks moved instances in deterministic order,
  retries a duplicate-key creation race, keeps cancellation tombstones, and
  atomically maintains row counts, projection, outbox, and audit. The reader
  accepts 1 to 25 positive instance ids, returns at most 100 rows, and uses an
  opaque versioned keyset cursor with a unique appointment-id tiebreaker.
- Current work: checkpoint `fd5fd86` is pushed on
  `rewrite/2026-09-02-0700`. Exact bounded definition matching and idempotent
  automatic instance generation are complete. Do not widen the existing
  active-pathway uniqueness rule until multi-clinic clinical semantics are
  proven.
- `next_item`: implement the caller-evidenced PAS appointment adapter, exact
  full-versus-partial merge rules, and indexed definition-to-instance
  resolution without widening pathway semantics.
- `after_next`: publish the transactional change outbox and expose authorized
  snapshot and cursor-delta routes through the application-surface manifest.
- Blockers and deferrals: legacy provides no authoritative global source
  sequence or timestamp contract, so only callers that supply a sequence use
  sequence ordering. The adapter must merge omitted partial fields before
  invoking the normalized writer. Attendance-before-pathway ordering and one
  patient appearing across multiple clinics still need clinical acceptance
  evidence. PAS HTTP adapters, pathways, publisher, routes, live transport now
  governed by section 16.3, admin UI,
  dashboard UI, rebuild command, and browser smoke are not claimed by this
  checkpoint.
- Coverage and ledger: 14,125 canonical paths, 18,421 total mappings, zero
  missing, zero pending review, and 49.8779 percent weighted coverage. Eight
  exact legacy rows received conservative matcher, generator, model, migration,
  and schedule evidence; the parity register itself still adds no coverage.
- Query and performance changes: the matcher loads candidates and mapping rows
  in exactly two configuration queries for both one and 40 definitions. JSON
  EXPLAIN reports neither filesort nor temporary table for either plan. The
  routine snapshot remains one clinical query at limits 1 and 100, and no
  optimizer hint is present.
- Tests, builds, and `verification_state`: the existing clean MariaDB 11.8
  checkpoint ran all 298 migrations across seven schemas, schema verification,
  and the tiny seed after the consolidated schema packet. The final matcher,
  generator, schedule, query-plan, migration-policy, optimizer-policy, snapshot,
  and ledger pack passed 29 tests and 239 assertions. A three-year daily fixture
  generated 1,097 instances and an immediate rerun remained idempotent. Scoped
  Pint, strict Composer validation, locked dependency audit, ledger verification,
  and `git diff --check` pass. Laravel is clean at pushed commit `fd5fd86`.
  `verification_state=worklist-matching-generation-green;
  fresh-seven-schema-green; ledger-green; checkpoint-pushed`.

### 16.14 Hourly checkpoint - 2026-08-31 20:50 BST

- Current problem and acceptance condition: preserve the caller-proven PAS V1,
  V2, and V3 appointment transports while preventing unsafe XML, cross-tenant
  writes, partial-record corruption, configuration retry storms, and query
  growth. All versions must converge on one normalized writer, the exact
  instance lookup must be indexed, and the warmed small and large fixtures must
  use the same query count.
- Completed evidence: one bounded parser now rejects DTD and entity input,
  nested or duplicate scalars, unknown fields, excessive mappings, invalid
  identifiers, and payloads over 64 KiB. Controllers preserve the legacy
  identifier-type locations, authenticate through the existing XAPI boundary,
  enforce `can_use_xapi`, and derive institution scope from the authenticated
  integration account. The adapter uses the exact two-query definition matcher
  and one-query instance resolver, merges partial updates under a row lock,
  rejects partial creates and partial list moves, records cancellation
  tombstones, and permits a later full Scheduled message to rebook. Unmatched
  input is accepted with a bounded warning and diagnostic code so a local
  configuration mistake does not create an external retry swarm.
- Current work: the PAS implementation and ledger evidence are ready for the
  next Laravel checkpoint. The active terminal condition remains the first safe
  integrated checkpoint at or after 2026-09-02 07:00 BST.
- `next_item`: publish the transactional worklist change outbox and expose
  authorized bounded snapshot and cursor-delta operations through the
  application-surface manifest.
- `after_next`: add worklist administration diagnostics and preview behavior,
  then begin the lightweight dashboard shell without loading patient history or
  medications on routine rows.
- Blockers and deferrals: authoritative pathway and assignee side effects remain
  narrow evidence gates. The existing one-active-pathway patient constraint is
  unchanged. Live transport now governed by section 16.3, full dashboard UI,
  admin reconciliation, rebuild proof, and
  production-scale concurrency are not claimed.
- Coverage and ledger: 14,125 canonical paths, 18,421 total mappings, zero
  missing, zero pending review, and 49.9746 percent weighted coverage.
- Query and performance changes: exact instance resolution is one indexed query
  with no filesort, temporary table, or optimizer hint. After warming framework
  and authentication setup, the full PAS write uses 24 database operations on
  both the normal fixture and a fixture with 40 extra definitions, within the
  declared budget of 30.
- Tests, builds, and `verification_state`: the final PAS, worklist foundation,
  matcher, generator, application-surface, XAPI, optimizer-policy, and
  migration-policy pack passed 44 tests and 2,846 assertions. Scoped Pint,
  FileLedger verification, and `git diff --check` pass.
  `verification_state=pas-intake-green; query-growth-green; ledger-green;
  checkpoint-ready`.

### 16.15 Hourly checkpoint - 2026-08-31 21:49 BST

- Current problem and acceptance condition: turn the transactional worklist
  outbox into a safe low-latency delivery seam and expose authorized snapshot
  and delta reads without making Redis authoritative or reintroducing full-list
  polling. One and 25-clinic fixtures must keep fixed query counts; delta plans
  must avoid filesort, temporary tables, and optimizer hints; queue or stream
  failure must leave committed changes recoverable.
- Completed evidence: `worklist.snapshot` and `worklist.delta` are named,
  manifest-owned, unversioned `/api` operations guarded by an active
  `can_view_worklists` user and exact same-institution instance selection. The
  snapshot returns at most 100 bounded current rows plus a selection-bound
  sync cursor in three clinical queries. The database delta returns at most 100
  ordered committed changes in two clinical queries. It excludes audit actor
  fields, medications, and event history. A cursor cannot be reused after the
  selected clinics change.
- Current work: Laravel checkpoint `f7776ba` is pushed on
  `rewrite/2026-09-02-0700`. After-commit queue wakeup, manager-only scheduled
  reconciliation, and one bounded publisher converge on the clinical outbox.
  Redis is only a delivery hint; atomic publication deduplicates retrying
  outbox ids and trims the stream, dedupe hash, and order list to the configured
  retained window.
- `next_item`: implement caller-evidenced attendance and appointment-order
  reconciliation without widening the one-active-pathway rule.
- `after_next`: add worklist administration diagnostics and generation preview,
  then build the lightweight dashboard shell and authenticated live delivery.
- Blockers and deferrals: authoritative pathway and assignee side effects,
  multi-clinic pathway semantics, authenticated live transport, client row reduction,
  filters, patient detail, administration, rebuild proof, production-scale
  concurrency, and browser parity remain explicit gates. Redis eviction or
  outage is not a correctness blocker because the database delta is
  authoritative.
- Coverage and ledger: 14,125 canonical paths, 18,423 total mappings, zero
  missing, zero pending review, and 49.9771 percent weighted coverage. The 64.8
  percent worklist feature number covers only 23 exact paths assigned so far and
  is not full worklist coverage.
- Query and performance changes: snapshot requests use three clinical queries
  for both one and 25 selected clinics; delta uses two. Publisher database work
  is two queries for both one and 100 events. The delta EXPLAIN has no filesort,
  temporary table, full-scan problem, or optimizer hint. A real Redis fixture
  retains exactly 100 stream entries and 100 dedupe ids under out-of-order
  retries.
- Tests, builds, and `verification_state`: a fresh seven-schema run completed
  all 298 migrations, the explicit seed loader, schema verification, and
  schedule verification. The final delivery, PAS, worklist foundation,
  application-surface, seed-permission, schedule, ledger, migration-policy,
  optimizer-policy, and schema pack passed 54 tests and 3,716 assertions.
  Scoped Pint passed all 24 changed PHP files and `git diff --check` passed.
  `verification_state=worklist-read-delivery-green; fresh-seven-schema-green;
  ledger-green; checkpoint-pushed`.

### 16.16 Hourly checkpoint - 2026-08-31 22:28 BST

- Current problem and acceptance condition: pause further worklist implementation
  and incorporate `/home/toukan/openeyes-worklist-realtime-scaling-plan.md` as an
  architecture correction. The plans must support thousands of simultaneously
  open dashboards with different configurations and sustained appointment update
  rates well above hundreds per minute, without a shared database hot row,
  publisher head-of-line blocking, full-list polling, or assumed cache reuse.
- Completed plan evidence: the master and active plans now use one authorized
  bounded snapshot held in browser memory, private per-worklist Reverb/Echo
  channels, compact projection-versioned patches, high-water cursor and database
  delta recovery, visible degraded state, and a durable transactional outbox.
  Web, Reverb, publisher queue, Redis, and MariaDB have independent capacity and
  backpressure signals. The full load and failure matrix is the final scale gate.
- Parity evidence: all 88 `WL-001` through `WL-088` behavioral capabilities
  remain. WL-002, WL-003, WL-004, WL-086, and WL-087 now carry the corrected
  transport, cursor, migrated-plan, configuration-diversity, hot-row, write-
  amplification, partitioned-publisher, and failure-recovery acceptance language.
- Current work: the caller-evidenced attendance reconciliation is integrated and
  pushed at Laravel `14fe2a4`. An Attended update creates and checks in one
  configured bounded pathway; Scheduled undoes only check-in; stale sequence,
  cancellation, rebooking, and re-attendance converge without duplicate pathway
  state. No administration, dashboard, Reverb, or further behavioral slice has
  been opened.
- `next_item`: remove the ordinary same-worklist instance lock, unchanged mapping
  and issue writes, and redundant reads with true same-clinic contention
  evidence.
- `after_next`: replace the global publisher lock with stable logical partitions,
  expiring ordered claims, crash recovery, worklist-specific queueing, and lag
  metrics before any private-channel delivery work.
- Blockers and deferrals: the final large-data plan, 5,000-dashboard,
  configuration-diversity, 100-per-second hot-clinic, 250-per-second broad,
  failure, and soak gates require the later representative migrated-data and
  deployment test environment. The 64/128 partition count is only a candidate.
  Reverb, `ext-uv`, Redis scale, ingress, and Kubernetes capacity are not claimed.
- Coverage and ledger: the attendance checkpoint reports 14,125 canonical
  paths, 18,423 mappings, zero missing, zero pending review, and 49.9778 percent
  weighted coverage. The register correction adds no coverage and does not turn
  a scale gate into behavioral completion.
- Query and performance changes: no new runtime query is introduced by this plan
  correction. The final matrix explicitly tests 5,000 dashboards with a
  heavy-tailed configuration mix and a worst case in which every dashboard is
  unique and receives no shared snapshot-cache hit. Hot writes record queries,
  rows read and written, locks, deadlocks, redo, binlog, transaction time, and I/O.
- Tests, builds, and `verification_state`: the unchanged 88-row register passes
  one test with 822 assertions. The focused worklist and policy pack passes 70
  tests with 3,813 assertions; after the explicit tiny seed restored its existing
  fixture precondition, Next Steps passes 10 tests with 124 assertions. Scoped
  Pint, ledger verification, and both repository diff checks pass. Laravel is
  clean and pushed at `14fe2a4`; Claude-kit remains stage-only.
  `verification_state=realtime-scale-plan-incorporated;
  attendance-reconciliation-green; checkpoint-pushed`.

### 16.17 Hourly checkpoint - 2026-08-31 22:57 BST

- Current problem and acceptance condition: remove the shared instance hot row
  and unchanged supporting-table writes from ordinary same-clinic appointment
  updates, without weakening membership counts, ordered intake, diagnostics, or
  the transactional projection and outbox.
- Completed evidence: Laravel checkpoint `5a5eb1a` is pushed on
  `rewrite/2026-09-02-0700`. Appointment identity remains the exclusive row lock.
  The shared instance row is accessed only for an actual add, remove, or move,
  with deterministic lock order and membership-only count changes. Mappings are
  diffed as a bounded set and issues change only for an error-state transition or
  changed evidence.
- Current work: no dashboard, administration, Reverb, or new behavior is open.
  The next architecture-now boundary is the global publisher.
- `next_item`: replace the global Redis publisher lock with stable logical
  partitions, expiring ordered claims, network I/O outside database transactions,
  crash recovery, a worklist-specific queue, and lag plus retry metrics.
- `after_next`: prove partition ordering, skew, expiry recovery, Redis failure,
  and bounded database work before adding private channel delivery.
- Blockers and deferrals: the deterministic lock test proves exclusion of the
  known ordinary-update hot row but does not claim the final 100-per-second hot
  clinic, 250-per-second broad burst, membership-change, redo, binlog, I/O, or
  soak gates. Those remain in the migrated-scale matrix.
- Coverage and ledger: exact coverage remains 49.9778 percent across 14,125
  canonical paths and 18,423 mappings, with zero missing and zero pending review.
  This architecture correction does not inflate behavioral coverage.
- Query and performance changes: while a second connection held the shared
  instance row lock, a same-clinic update completed in 0.36 seconds with no
  instance query, mapping mutation, or issue query. An identical unmatched update
  made zero mapping and issue mutations; changed evidence made exactly one of
  each. Ordinary PAS create remains 21 operations and attendance remains 36.
- Tests and `verification_state`: the focused worklist, PAS, manifest, home guard,
  optimizer-plan, and parity pack passes 56 tests with 3,668 assertions. Scoped
  Pint, `git diff --check`, and ledger verification pass. Laravel is clean and
  pushed at `5a5eb1a`; Claude-kit remains stage-only.
  `verification_state=ordinary-hot-row-removed; diff-writes-green;
  ledger-green; checkpoint-pushed`.

### 16.18 Hourly checkpoint - 2026-09-01 00:02 BST

- Current problem and acceptance condition: remove the global publisher lock and
  network-in-transaction behavior before any realtime dashboard delivery. Claims
  must be bounded, ordered within a worklist, independently recoverable, and unable
  to let one hot partition block every other clinic.
- Completed evidence: Laravel `59f13a3` adds 64 stable application-derived
  partitions, schema-backed generation and token fenced leases, 100-row claims,
  expiry recovery, fixed query counts, Redis cluster hash tags, and bounded lag and
  retry telemetry. Docker `f8d87fb` adds an isolated `worklist-broadcast` Compose
  worker while preserving the ordinary webhook and default queue worker.
- Current work: the user-requested current-date demo worklist factory is being
  reconciled against both the checked-in developer command and the deploy-supplied
  sample post-migration script.
- `next_item`: replace the Bash-generated rolling demo worklist scenario with an
  opt-in manager command and idempotent bounded factory.
- `after_next`: create an early synthetic scale fixture and measure one- and
  25-clinic snapshot, delta, and publisher partition behavior without claiming the
  final migrated-data gate.
- Blockers and deferrals: the final 5,000-dashboard and 100/250-change-per-second
  matrix still requires representative migrated data and deployment capacity. The
  fixed count of 64 is an initial implementation, not a final capacity conclusion.
- Coverage and ledger: 14,125 canonical paths, 18,423 mappings, zero missing and
  zero pending review remain exact at 49.9778 percent before the sample ledger
  correction.
- Query and performance changes: publisher claims use the partition, pending, and
  age indexes without filesort, temporary tables, or hints. One and 100 rows use the
  same bounded statement count. Redis failure cannot hold a database transaction.
- Tests and `verification_state`: publisher partition, contention, expiry, failure,
  Redis, queue-role, migration, and optimizer-policy checks pass. Laravel and Docker
  checkpoints are pushed; Claude-kit remains stage-only.
  `verification_state=partitioned-publisher-green; dedicated-worker-green;
  checkpoint-pushed`.

### 16.19 Hourly checkpoint - 2026-09-01 00:16 BST

- Current problem and acceptance condition: demo deployments must be able to create
  useful worklists around the current date without downloading a sample repository,
  generating SQL in Bash, or making row-by-row writes.
- Completed evidence: Laravel `0cecd17` adds the disabled-by-default
  `oe:seed:worklist-demo` manager command and bulk factory. With the frozen date
  2026-09-01 it creates 8 definitions, 242 instances and 913 appointments from
  2026-08-30 through 2026-10-01, including current-row and Code projections. A rerun
  is idempotent and initial state deliberately creates no live-update outbox swarm.
  Docker `0994b0c` passes the explicit opt-in through all application roles and
  documents manager-only use in demo deployments.
- Current work: no functional dashboard or administrator slice is open. The next
  work is the early worklist scale fixture and measured query-plan boundary.
- `next_item`: build a configurable synthetic worklist scale fixture that is
  separate from the friendly demo scenario, then measure the one- and 25-clinic hot
  reads and partition distribution on large fixtures.
- `after_next`: use the measured evidence to close any schema or query-shape issue,
  then establish the Reverb and Echo deployment seam without enabling broad live
  use.
- Blockers and deferrals: the generic legacy copy-forward and arbitrary random
  attribute developer command remains partial. Representative migrated production
  distributions and the final scale and failure matrix remain later gates.
- Coverage and ledger: the canonical ledger remains exact at 14,125 paths and
  18,423 mappings with zero missing and zero pending review. The checked-in generic
  developer command is honestly 50 percent partial; the external sample script is
  tracked separately at its pinned blob and revision.
- Query and performance changes: the factory uses at most 25 statements across the
  configuration, clinical, and audit schemas for all 1,163 core records, has no
  per-patient lookup loop, and sends no initial outbox messages.
- Tests and `verification_state`: a fresh seven-schema Compose release passes with
  web, manager, ordinary queue, dedicated worklist queue, renderer, MariaDB, and
  Redis healthy. After loading the explicit tiny profile, the mixed worklist,
  schema, ledger, migration, and no-hint pack passes 36 tests with 1,226 assertions.
  The same fresh schema proves the snapshot, delta, and publisher hot plans have no
  filesort or temporary table. Image role checks and scoped Pint pass.
  `verification_state=sample-factory-green; fresh-seven-schema-green;
  mixed-query-plan-green; checkpoint-pushed`.

### 16.20 Hourly checkpoint - 2026-09-01 00:36 BST

- Current problem and acceptance condition: prove an early one- versus 25-clinic
  read boundary and publisher skew before adding realtime transport. The database
  must not sort the selected population, query count must remain constant, and the
  optimized shape must preserve global schedule and priority cursor order.
- Completed evidence: a transaction-scoped scale fixture creates 25 worklists,
  10,000 appointments, 10,000 current rows, and 10,000 changes using 500-row bulk
  inserts. The original multi-clinic `IN` shape exposed filesort for schedule and
  priority. The replacement uses at most 25 index-ordered `UNION ALL` branches,
  each limited to 101 candidates, followed by a bounded application top-N merge.
  The consolidated schema packet makes the worklist foreign key the leading column
  of each serving index, removing the competing automatic single-column index.
- Current work: reconcile and stage the scale checkpoint. No dashboard UI,
  subscription, Reverb, administrator, or new clinical behavior is open.
- `next_item`: establish the Reverb and Echo deployment seam, including pinned
  compatible versions, dedicated scalable runtime roles, private-channel
  authorization boundaries, health, graceful drain, and disabled-by-default
  configuration without yet claiming live dashboard parity.
- `after_next`: add compact private per-worklist batch delivery, browser reduction,
  cursor recovery, degraded state, and authorization expiry, then begin the full
  configuration and browser parity sequence.
- Blockers and deferrals: the 10,000-row fixture is intentionally synthetic. It
  does not replace representative migrated distributions, `ANALYZE FORMAT=JSON`
  actual pages and I/O, 1,000 simultaneous 25-clinic dashboards, 5,000 sockets,
  125,000 subscriptions, sustained 100-per-second hot-clinic changes,
  250-per-second broad changes, Redis or Reverb failure, or soak gates.
- Coverage and ledger: exact behavioral coverage remains 49.9778 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. This performance foundation does not inflate coverage.
- Query and performance changes: every one- and 25-clinic schedule and priority
  branch uses its optimizer-selected serving index with no filesort, temporary
  table, full scan, or hint. Each page is one clinical statement and merges at
  most 2,525 bounded candidates. Two pages for both sorts return 200 unique rows
  in exact global order. Delta remains cursor-indexed. Ten thousand deterministic
  worklist ids use all 64 publisher partitions with measured counts from 123 to
  192 per partition.
- Tests and `verification_state`: the current-source clean seven-schema migration
  and schema verification pass, followed by the explicit tiny seed. The focused
  worklist, query-plan, migration, and no-hint pack passes 39 tests with 1,239
  assertions. Scoped Pint and repository diff checks pass. The disposable test
  database volumes were recreated twice: once exposed the stale pre-change image,
  and the second current-source run proved the intended migration.
  `verification_state=synthetic-scale-gate-green; multi-clinic-filesort-removed;
  clean-schema-green; final-migrated-scale-gate-deferred`.

### 16.21 Hourly checkpoint - 2026-09-01 01:09 BST

- Current problem and acceptance condition: establish a production-shaped but
  disabled realtime deployment seam before connecting clinical worklist events.
  Reverb must be independently deployable and scalable, query-free in the web
  shell, isolated from database credentials and clinical volumes, exact-origin
  restricted, health checked, gracefully stoppable, and verified against the
  installed PHP event loop.
- Completed evidence: Laravel now carries compatibility-major constraints for
  Reverb 1, Echo 2, and Pusher JS 8 with exact Composer and npm lock files. The
  runtime verifier rejects missing credentials, wildcard or mismatched origins,
  incoherent endpoints, oversize limits, wrong role, disabled central scaling,
  and an unsupported event loop. Compose and Helm provide a disabled-by-default
  Reverb role, independent service and two-replica deployment, exact `/app` and
  `/apps` routing, no sticky sessions, a separate secret with no database
  credentials, health, topology spread, a disruption budget, and graceful
  termination.
- Current work: add a bounded private worklist subscription lease and compact
  delivery contract. No complete dashboard, administrator surface, or broad
  live-use switch is open.
- `next_item`: issue a short-lived signed lease from an already authorized
  snapshot, authorize each opaque per-worklist private channel without a second
  worklist lookup, and prove cross-user, cross-institution, guessed-channel, and
  stale-policy rejection.
- `after_next`: publish one compact version-collapsed batch per claimed worklist
  group, then add browser row reduction, cursor-gap recovery, reconnect jitter,
  visible degraded state, and bounded lease renewal.
- Blockers and deferrals: the configured 6,000-connection process ceiling is a
  safety limit, not measured capacity. No Kubernetes cluster, migrated-data load,
  5,000-dashboard, 125,000-subscription, failure-injection, mixed-traffic, or soak
  gate has run. Those claims remain explicitly deferred to the final scale matrix.
- Coverage and ledger: exact behavioral coverage remains 49.9778 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. Deployment plumbing does not inflate coverage.
- Query and performance changes: the global Inertia realtime property reads
  configuration only and performs no database query. Reverb has no database
  credentials or clinical mounts. Two replicas at the provisional 6,000 socket
  ceiling provide a configuration envelope of 12,000 sockets, but no usable
  capacity claim is made before load and failure proof.
- Tests and `verification_state`: the live Redis-only production image starts,
  returns `{"health":"OK"}`, reports `React\\EventLoop\\ExtEventLoop`, rejects a
  low open-file limit and wrong role, and exits cleanly within five seconds. The
  dedicated image verifier, web image verifier, Compose profile render, Helm lint
  and enabled/disabled chart verifier pass. Realtime PHP tests pass 4 tests with
  19 assertions; the combined application manifest and operational pack passes
  48 tests with 2,771 assertions; JavaScript tests pass 7 tests. Strict Composer,
  scoped Pint, production frontend build, and diff checks pass. One mixed
  worklist run omitted the Redis host and had one infrastructure failure; its
  exact Redis-backed delivery subset then passes 8 tests with 166 assertions.
  `verification_state=reverb-echo-seam-green; native-event-loop-proven;
  private-delivery-not-open; final-scale-gate-deferred; changes-staged`.

### 16.22 Hourly checkpoint - 2026-09-01 01:33 BST

- Current problem and acceptance condition: make private worklist delivery
  authorized, compact, recoverable, and bounded before any dashboard enables it.
  One browser connection may select 1 to 25 worklists, one authorization request
  must cover the selection, patches must never cause a full-page refresh, and any
  stream or enqueue failure must leave the whole publisher claim recoverable.
- Completed evidence: the authorized snapshot now issues a five-minute encrypted
  lease for the exact user, institution, policy version, and selected worklists.
  One rate-limited authorization request signs up to 25 private channels, rechecks
  the full leased selection in one clinical query, renews the lease, and rejects
  guessed channels, cross-institution access, retired worklists, expired leases,
  and stale user policy. The generic broadcasting endpoint cannot authorize a
  worklist channel.
- Completed delivery evidence: one claimed outbox group is collapsed to the
  newest appointment projection version, split below an 8,000-byte application
  budget, and queued on `worklist-broadcast` only after the durable Redis stream
  accepts the complete claim. An individually oversize row becomes a bounded
  recovery marker. Redis or broadcast enqueue failure keeps every claim row
  pending for idempotent retry and no network call runs inside a database
  transaction.
- Completed browser evidence: the page-local reducer accepts only newer
  projection versions, converges when a clinic move arrives out of order, updates
  schedule or priority order and counts locally, and stores no persistent patient
  data. One synchronous subscription set produces one batched authorization
  request. Reconnect and authorization recovery are jittered, gap recovery reads
  at most 20 delta pages, a separate timer preserves lease renewal, and transport
  failure is visibly degraded or recovering.
- Current work: reconcile this private-delivery checkpoint and keep realtime
  disabled by default. No dashboard, filter, administrator surface, institution
  rollout switch, or scale claim is open.
- `next_item`: connect the live session to the first bounded dashboard component
  while preserving the finite named filter and sort contracts, then prove one
  browser smoke without enabling broad live use.
- `after_next`: close worklist configuration and row-action parity in register
  order, including clear administration diagnostics and safe generation preview,
  before the representative migrated-data and complete load/failure matrix.
- Blockers and deferrals: Pusher JS 8.6 uses an internal fixed one-second socket
  retry after connection closure and does not expose the required exponential
  reconnect jitter. The application now jitters private reauthorization and HTTP
  delta recovery, which protects those web and database paths, but this is not
  proof against a synchronized socket reconnect storm. Before the Reverb pod-loss
  gate, select and verify a maintained configurable reconnect strategy or a
  narrowly owned client patch. The 5,000-dashboard, 125,000-subscription,
  100-per-second hot-clinic, 250-per-second broad update, mixed traffic, pod loss,
  Redis loss, migrated-data, and soak gates remain deferred.
- Coverage and ledger: exact behavioral coverage remains 49.9778 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. Deployment and scale plumbing do not inflate coverage.
- Query and performance changes: snapshot lease creation is query-free. One
  subscription authorization for 25 channels performs one bounded access query,
  not 25 queries. Live patches perform zero clinical reads in the web request;
  only a gap or reconnect invokes the bounded delta path. The broadcast payload
  limit retains at least 1,000 bytes of headroom under Reverb's message limit.
- Tests and repository state: the focused worklist, manifest, realtime, parity,
  and no-hint pack passes 55 tests with 3,733 assertions. The private delivery
  subset passes 22 tests with 294 assertions; JavaScript passes 16 tests; scoped
  Pint passes 28 files; the production frontend build, Helm verifier, Compose
  realtime render, and staged diff checks pass. The build retains its existing
  unresolved runtime SVG and large EventView chunk warnings. Laravel and Docker
  changes are staged only, with no commit or push.
  `verification_state=private-auth-green; compact-delivery-green;
  browser-recovery-green; fixed-socket-retry-blocker-recorded;
  final-scale-gate-deferred; changes-staged`.

### 16.23 Hourly checkpoint - 2026-09-01 01:57 BST

- Current problem and acceptance condition: expose the first usable worklist
  dashboard without recreating the legacy refresh swarm. The shell must be
  query-free, clinic discovery and patient reads must be independently bounded,
  one to 25 selected clinics must keep constant query growth, and disabled live
  delivery must be obvious rather than silently stale.
- Completed evidence: the named and manifest-owned `worklist.index` shell passes
  only a validated local date, finite `schedule` or `priority` sort, and at most
  25 distinct clinic ids. The current-date picker reads at most 100 open clinics
  in one institution-scoped indexed query. The dashboard requests one keyset
  snapshot only after a selection, combines clinics without medication or event
  history reads, preserves clinic identity, supports load-more pages, and stops
  all fetch and live-session work on unmount.
- Completed browser evidence: a clean seven-schema production stack loaded the
  tiny seed and the opt-in current-date worklist factory, producing 8 definitions,
  242 instances, and 913 appointments around 2026-09-01. The isolated browser
  found eight current-date clinics, selected two in one rapid interaction, opened
  nine combined patient rows, and showed `Realtime disabled`. The trace contained
  one snapshot request, no polling request, and no console error. A lost rapid
  checkbox update found by the first smoke was corrected with an explicit bounded
  set update and the rebuilt production image passed.
- Current work: the bounded dashboard checkpoint is reconciled and staged. Live
  delivery remains disabled by default and no broad rollout or capacity claim is
  made.
- `next_item`: replace the 100-clinic picker truncation boundary with indexed
  keyset paging and a bounded load-more control so every current-date clinic can
  be reached without an unbounded response or name-search scan.
- `after_next`: preserve separate-clinic presentation and names, then implement
  the first saved and recent filter contracts in parity-register order without
  adding client-side full-set filtering.
- Blockers and deferrals: Pusher JS 8.6 fixed one-second socket retry remains the
  pod-loss reconnect-storm blocker. Expired outbox-retention cursor detection,
  explicit 100-250 ms display batching, exact legacy row and filter parity,
  migrated-data configuration diversity, 5,000 dashboards, 125,000 subscriptions,
  sustained hot and broad writes, failure recovery, and soak remain open.
- Coverage and ledger: exact behavioral coverage remains 49.9778 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. This dashboard seam does not inflate coverage.
- Query and performance changes: the dashboard document executes zero clinical
  queries, clinic options execute one, snapshot executes three for one or 25
  clinics, and live patches execute none. Query-plan assertions reject filesort,
  temporary-table work, full scans, and optimizer hints. Initial live enablement
  will add a bounded two-query recovery read after subscriptions are established;
  it is intentionally separate from the snapshot budget.
- Tests and repository state: the focused worklist, manifest, realtime, parity,
  and no-hint pack passes 57 tests with 3,774 assertions. JavaScript passes 17
  tests, scoped Pint passes 6 files, the production frontend build passes with
  the existing runtime SVG and large EventView warnings, the rebuilt-image browser
  smoke passes, and staged diff checks pass. Laravel and Docker changes are staged
  only, with no commit or push.
  `verification_state=dashboard-browser-green; no-polling-proven;
  picker-keyset-open; fixed-socket-retry-blocker-recorded;
  final-scale-gate-deferred; changes-staged`.

### 16.24 Hourly checkpoint - 2026-09-01 02:06 BST

- Current problem and acceptance condition: make every current-date clinic
  reachable without an unbounded response, offset pagination, a broad name scan,
  filesort, temporary table, or optimizer hint. Each continuation must remain one
  query and must not duplicate or skip equal-time clinics.
- Completed evidence: clinic options now use a date-bound versioned cursor over
  `(starts_at, id)`, return at most 25 narrow rows, and expose one bounded
  load-more control. Malformed and cross-date cursors return validation errors.
  A 101-clinic fixture was traversed in five queries with 101 unique ordered ids,
  no overlap, and the expected first and last clinics.
- Query-shape correction: the first continuation attempt used the normal expanded
  `starts_at > x OR (starts_at = x AND id > y)` predicate. MariaDB selected a
  table scan and filesort. A row comparison alone still selected the cheap sort
  when asked for 101 of 104 rows. Reducing the page to the same 25-clinic bound
  as the user selection made both first and continuation plans use range access
  on `ix_worklist_instance_dashboard` with no filesort or temporary table. No
  hint was added. Unused definition name and end-time columns were removed from
  this hot projection.
- Completed browser evidence: the rebuilt production image showed the first 25
  of 38 current-date test clinics, loaded all 38 with one continuation request,
  retained the two rapid selections, rendered nine combined patient rows, made
  one snapshot request, made no polling request, and emitted no console error.
- Current work: indexed clinic paging is integrated and staged. The dashboard
  still identifies selected results by numeric worklist id, so separate-clinic
  presentation parity is not yet closed.
- `next_item`: carry the already loaded clinic names into the selected dashboard
  presentation, preserve a single combined projection read, and prove separate
  clinic identity without a per-clinic or per-row database lookup.
- `after_next`: implement saved and recent filter contracts in parity-register
  order, including ownership, deterministic ordering, and no stale criteria when
  switching filters.
- Blockers and deferrals: the fixed Pusher JS socket retry, expired outbox cursor
  fallback, display batching, exact filter and row-action parity, administrator
  diagnostics, migrated-data diversity, and complete scale and failure matrix
  remain open.
- Coverage and ledger: exact behavioral coverage remains 49.9778 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review.
- Tests and repository state: the focused worklist pack passes 57 tests with
  3,814 assertions. The options test alone passes 10 tests with 160 assertions;
  JavaScript passes 17 tests; scoped Pint passes 5 files; production build,
  rebuilt-image browser smoke, and staged diff checks pass. Changes remain staged
  only, with no commit or push.
  `verification_state=picker-keyset-green; continued-plan-green;
  browser-paging-green; separate-presentation-open;
  final-scale-gate-deferred; changes-staged`.

### 16.25 Hourly checkpoint - 2026-09-01 02:19 BST

- Current problem and acceptance condition: preserve the verified legacy choice
  between one table per clinic and one combined table without adding a clinic
  query, per-row lookup, full snapshot refresh, or client request when the user
  changes presentation. Counts must describe the whole clinic rather than only
  the first bounded patient page.
- Completed evidence: the verified Worklist View documentation confirms that
  separate tables are the default and `Show patients in combined single list`
  is the explicit alternative. The existing one-query authorization read now
  returns each selected clinic's id, name, start time, and maintained row count.
  The snapshot still executes three clinical queries for one or 25 clinics and
  the shell remains query-free. The high-water cursor is captured before the
  metadata read so a membership change cannot be hidden between an older count
  and a newer cursor.
- Count and hot-row behavior: totals initialize from `worklist_instance.row_count`
  instead of the at-most-100 loaded rows. Only a membership add, move, or remove
  carries the resulting authoritative total through the existing transactional
  outbox, compact broadcast, and delta response. An ordinary same-clinic update
  carries no total and retains the earlier no-shared-instance-row write path.
- Completed browser evidence: the rebuilt production image paged from 25 to all
  38 clinic options, preserved two rapid selections, and rendered the two chosen
  clinics as two named tables with one and eight patients. Selecting the combined
  option produced one named nine-row table with zero additional requests. The
  run made one snapshot request, made no polling request, and emitted no console
  error.
- Current work: separate and combined presentation is integrated and staged.
  Long-lived live state can still accumulate changed rows beyond the currently
  loaded keyset window, and removing a visible row does not yet fetch the next
  eligible row. That is a bounded-memory and exact-window issue, not a reason to
  reintroduce full refresh polling.
- `next_item`: add an explicit loaded-window capacity and a bounded snapshot
  reconciliation path for live inserts, reorders, and visible removals, while
  preserving delta recovery and zero full-snapshot polling.
- `after_next`: implement saved and recent filter contracts in parity-register
  order, including ownership, deterministic ordering, and complete replacement
  of stale criteria when switching filters.
- Blockers and deferrals: Pusher JS 8.6's fixed one-second socket retry, expired
  outbox-retention cursor fallback, 100-250 ms display batching, exact row-action
  and filter parity, administrator diagnostics, migrated-data diversity, and the
  complete scale and failure matrix remain open.
- Coverage and ledger: exact behavioral coverage remains 49.9778 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. Presentation and count corrections do not inflate coverage.
- Tests and repository state: the focused worklist, manifest, realtime, ledger,
  and parity pack passes 57 tests with 3,839 assertions. JavaScript passes 17
  tests; scoped Pint passes 10 files; the production frontend build and rebuilt
  production-image browser smoke pass; staged diff checks pass. Laravel, Docker,
  and plan changes remain staged only, with no commit or push.
  `verification_state=separate-combined-green; authoritative-counts-green;
  snapshot-query-budget-unchanged; live-window-reconciliation-open;
  final-scale-gate-deferred; changes-staged`.

### 16.26 Hourly checkpoint - 2026-09-01 02:31 BST

- Current problem and acceptance condition: a dashboard left open through a hot
  clinic must not retain every changed appointment or issue a replacement
  snapshot for every live insertion, reorder, or removal. Its in-browser row and
  version state must stay bounded by pages the user explicitly loaded, while
  cross-clinic moves and snapshot/live races still converge.
- Completed evidence: the reducer now has an explicit loaded-row capacity of 100
  plus at most 100 for each successful user-triggered keyset page. Every live
  batch is reduced, sorted, pruned, and version-compacted once. A 100-change test
  proves two loaded rows and two retained versions remain two while the
  authoritative total advances to 102. Both possible delivery orders for a
  same-version clinic move converge on the new clinic. A removal received while
  a keyset page is in flight cannot be restored by the older page response.
- Reconciliation behavior: live changes never trigger a snapshot. When the
  authoritative total exceeds a fully consumed loaded window, the page exposes
  an explicit `Refresh loaded window` action. That action replaces the bounded
  snapshot and live session from a new high-water cursor. A failed refresh keeps
  the old visible data and exposes the error for a deliberate retry.
- Query and fan-out consequence: update fan-out remains compact WebSocket data;
  there is no per-change read and no client polling. A clinic with hundreds of
  changes per minute therefore cannot multiply those changes into thousands of
  full snapshot queries. Exact off-window membership is reconciled only at a
  user boundary.
- Current work: bounded live-window reconciliation is integrated and staged.
  Saved and recent filters are the next unresolved dashboard contract.
- `next_item`: implement saved-filter ownership and overwrite semantics plus a
  bounded recent-filter contract, using verified legacy behavior and stable
  deterministic ordering.
- `after_next`: implement the next row-action and administrator parity items,
  then extend the realistic concurrency and failure proof without enabling
  broad production live delivery.
- Blockers and deferrals: Pusher JS 8.6's fixed one-second socket retry, expired
  outbox-retention cursor fallback, 100-250 ms display batching, exact remaining
  row actions, administrator diagnostics, migrated-data diversity, and the full
  5,000-dashboard scale and failure matrix remain open.
- Coverage and ledger: exact behavioral coverage remains 49.9778 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. This correctness correction does not inflate coverage.
- Tests and repository state: JavaScript passes 19 tests; the manifest and
  worklist read gate passes 22 tests with 2,593 assertions; scoped Pint and the
  production frontend build pass. The existing SVG resolution and large
  EventView chunk warnings remain unchanged. Laravel, Docker, and plan changes
  remain staged only, with no commit or push.
  `verification_state=live-window-bounded; no-snapshot-fanout;
  move-order-green; page-race-green; saved-filters-next;
  final-scale-gate-deferred; changes-staged`.

### 16.27 Hourly checkpoint - 2026-09-01 02:49 BST

- Current problem and acceptance condition: saved and recent worklist filters
  must be private, bounded, deterministic, and replace the complete supported
  setup without adding clinical reads or making the dashboard shell query the
  database. The scale plan must explicitly cover thousands of users whose
  configurations do not share cache entries as well as hundreds of updates per
  minute.
- Completed filter evidence: one versioned configuration table now stores
  institution and user scoped saved and recent filters. Blank and overlength
  names are rejected, a same-name save atomically replaces all supported
  criteria, recents deduplicate exact criteria and retain five, one chosen
  filter follows the user, and only the owner can choose or retire a saved
  filter. The supported v1 criteria are the local date, finite sort, combined
  presentation, and one to 25 ordered clinic ids. Site, context, date ranges,
  quick filters, and optional predicates remain explicitly open rather than
  being silently discarded.
- Completed browser evidence: the rebuilt production image loaded two clinics,
  recorded a recent setup, switched separate and combined presentation without
  another snapshot, saved a favourite, changed local state, restored the full
  favourite, restored a different recent setup, restored the chosen setup after
  a parameter-free navigation, and deleted the favourite with no console error
  or polling request.
- Scale audit: the final gate is deliberately above the requested operating
  case. It has 5,000 connected dashboards and a 10,000 stretch, 125,000 private
  subscriptions, 5,000 unique configurations with no cache-hit assumption, a
  new 1,000-dashboard diverse cold-start wave, 100 appointment changes per
  second to one hot clinic, and 250 per second across clinics. Long soaks remain
  mandatory because passing a short peak does not prove connection, cursor, or
  queue stability.
- Current work: reconcile the filter routes, legacy sources, and plan records,
  then close the remaining site and date filter contracts before opening wider
  row behavior.
- `next_item`: implement WL-019 and WL-020 with an explicit site contract and a
  date-clear operation that changes no other criterion, preserving the
  query-free shell and bounded clinic discovery.
- `after_next`: complete the bounded row DTO and visible owner parity, then add
  page-bounded select-all without opening patient history or medication reads.
- Blockers and deferrals: full site, context, date-range, quick, and optional
  clinical filtering remains open. The Pusher JS fixed one-second reconnect,
  expired outbox-retention cursor fallback, explicit 100-250 ms publisher
  display window, representative migrated data, the complete scale and failure
  matrix, and soak remain required before broad live use.
- Coverage and ledger: exact behavioral coverage is 50.0447 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. Only exact saved/recent filter sources increased coverage; the wider
  filter query and UI remain partial or deferred.
- Query and performance evidence: listing filters performs one bounded
  configuration query returning at most 100 saved and five recent rows and zero
  clinical queries. The dashboard document remains query-free, clinic options
  remain one indexed query, snapshot remains three clinical queries for one or
  25 clinics, and live patches perform none.
- Tests and repository state: the focused filter, ledger, manifest, worklist
  read, delivery, and scale-plan pack passes 42 tests with 2,918 assertions.
  The preceding integrated pack passes 63 tests with 3,921 assertions;
  JavaScript passes 21 tests; scoped Pint and the production frontend build
  pass. Laravel, Docker, scaling-plan, and execution-plan changes remain staged
  or ready to stage only, with no commit or push.
  `verification_state=saved-recent-filter-v1-green;
  owner-order-replacement-green; browser-filter-smoke-green;
  requested-scale-covered-by-higher-gate; site-date-filter-next;
  final-scale-gate-deferred; changes-staged`.

### 16.28 Hourly checkpoint - 2026-09-01 03:09 BST

- Current problem and acceptance condition: site changes must restrict the clinic
  picker to active definition contexts without losing an explicit clinic
  selection or allowing an older response to replace a newer choice. Clearing
  the date must return to today while preserving every non-date criterion. Both
  paths must stay bounded and use no optimizer hint.
- Completed evidence: the dashboard now carries an explicit active site in URL,
  saved, and recent criteria. The picker resolves global and site-specific
  definitions in one bounded configuration query, then reads the current-date
  instances in one indexed clinical query. Its cursor is bound to both site and
  date. An inactive or cross-institution site cannot expose a definition. Rapid
  site changes use a request generation guard, so only the newest response can
  update the picker while explicit selected ids remain in memory.
- Date behavior: the named authenticated `worklist.filter.clear-dates` surface
  removes only the date, redirects to today's worklist, and preserves site, sort,
  combined presentation, and the ordered explicit clinic ids. It performs no
  clinical write.
- Browser evidence: a rebuilt production image exposed two sites. A temporary
  site-specific demo definition produced eight options at site 1 and seven at
  site 2. The hidden clinic returned selected after a rapid `1 -> 2 -> 1`
  sequence. Date reset preserved both clinic ids, priority ordering, combined
  mode, and site 1, removed the date query parameter, defaulted the field to
  2026-09-01, and emitted no console error. The temporary context was removed
  after the smoke.
- Demo fixture evidence: the requested Bash-free rolling worklist fixture was
  already completed at Laravel `0cecd17` and Docker `0994b0c`. The disabled by
  default manager command uses the idempotent bulk `WorklistSampleDataFactory`,
  defaults to today's date, accepts a reproducible reference date, and creates
  eight scenarios without putting demo writes in migrations.
- `next_item`: complete the bounded row DTO and visible owner parity, including
  the accepted safety and source fields that belong in the always-visible row,
  without opening patient history, event, or medication reads.
- `after_next`: add page-bounded select-all behavior, then take the first safe
  administrator diagnostic item while continuing the scale and failure proof.
- Blockers and deferrals: site selection is local to the worklist rather than a
  completed application-wide context switch. Firm and subspecialty context,
  date ranges, quick filters, optional predicates, stable cross-installation
  saved-filter mapping, Pusher JS reconnect backoff, expired cursor recovery,
  display batching, migrated data, and the full scale matrix remain open.
- Coverage and ledger: exact behavioral coverage is 50.0624 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. Only the exact site-change listener, its legacy proof, and the bounded
  part of the filtering browser source gained credit.
- Query and performance evidence: option discovery uses one configuration query
  and one clinical query. Small and 101-row fixtures retain constant query count;
  current and continued pages plus definition visibility show no filesort or
  temporary table. MariaDB selected a valid definition-first range index in the
  focused fixture, and the gate deliberately enforces cost properties without
  forcing or naming one optimizer choice.
- Tests and repository state: site, date, filter, and worklist read tests pass 20
  tests with 312 assertions. Ledger, manifest, and sample-factory gates pass 16
  tests with 2,468 assertions. JavaScript passes 21 tests, scoped Pint passes,
  the production frontend build passes with only its existing warnings, and both
  production-image browser smokes pass. Laravel, Docker, scaling-plan, and plan
  changes remain staged or ready to stage only, with no commit or push.
  `verification_state=site-definition-visibility-green;
  stale-site-response-guarded; date-reset-green; sample-factory-already-green;
  final-scale-gate-deferred; changes-staged`.

### 16.29 Hourly checkpoint - 2026-09-01 03:22 BST

- Current problem and acceptance condition: the routine worklist row must retain
  its accepted always-visible identity, appointment, clinic-source, owner,
  priority, pathway or waiting, and safety information without reopening any
  neighbouring patient, event-history, or medication lookup. Snapshot and live
  delivery must not drift into different row contracts, and an owner must remain
  visible when no pathway exists.
- Completed evidence: one `WorklistRowData` contract now normalizes the bounded
  current-row attributes for both transactional outbox upserts and snapshot
  responses. It emits stable UTC instants, patient identity and demographics,
  bounded clinic display attributes, owner, priority, pathway and waiting state,
  all three safety-source states, and the exact list-visible AIS, allergy, and
  level-one alert decisions. Internal change timestamps and all wider clinical
  collections remain absent.
- Browser evidence: a rebuilt production image rendered appointment status,
  identifier, DOB, sex, a clinic source attribute, an owner with `pathway_id`
  null, priority, next step, AIS, allergy, and alert from one snapshot request.
  It made no delta polling request and emitted no console error. The temporary
  row overrides were removed after the smoke.
- `next_item`: add WL-028 page-bounded select-all over only the currently loaded
  eligible rows, with an explicit selected count and no selection crossing an
  unloaded keyset cursor.
- `after_next`: implement the first bounded administrator diagnostic and safe
  generation-preview item, then continue the scale and failure proof.
- Blockers and deferrals: authoritative patient-flag source writes do not yet
  refresh every affected current worklist row, so WL-022 source-to-projection
  parity remains open. Pathway steps and actions, comments, total duration,
  patient detail, print, wider filters, reconnect backoff, expired-cursor
  recovery, display batching, migrated data, and the full scale matrix remain.
- Coverage and ledger: exact behavioral coverage is 50.0716 percent across
  14,125 canonical paths and 18,423 mappings, with zero missing and zero pending
  review. Credit is limited to the always-visible part of the legacy row, owner,
  and patient-flag evidence.
- Query and performance evidence: the snapshot stays at three clinical queries
  for one or 25 clinics, and the stable DTO adds no database access. The
  10,000-row schedule and priority gates still use one independently limited
  ordered branch per selected clinic with no filesort, temporary table, or
  optimizer hint.
- Tests and repository state: worklist read, write, and 10,000-row plan tests
  pass 20 tests with 326 assertions. Ledger integrity passes two tests with 22
  assertions. JavaScript passes 21 tests; scoped Pint and the production frontend
  build pass with only existing warnings; the production browser smoke passes.
  Laravel, Docker, scaling-plan, and plan changes remain staged or ready to stage
  only, with no commit or push.
  `verification_state=bounded-row-dto-green; snapshot-live-contract-aligned;
  owner-without-pathway-green; production-browser-row-smoke-green;
  flag-source-refresh-deferred; select-all-next; changes-staged`.

### 16.30 Hourly checkpoint - 2026-09-01 03:39 BST

- Current problem and acceptance condition: WL-028 selection must never turn one
  page action into an unbounded patient operation. A clinician may select or
  clear only valid appointment rows already loaded in the visible section, must
  see checked and partial state, and live removal must not leave a stale id.
- Completed evidence: the dashboard keeps selection in bounded client state.
  The section computation derives appointment ids and selection state once per
  render from its already loaded rows. Applying a live view reconciles selected
  ids against that bounded row set. Select all, row deselect, and clear make no
  server request and cannot cross an unloaded keyset cursor.
- Browser evidence: the rebuilt production image selected all eight loaded rows,
  showed eight selected, changed to seven with the section checkbox
  indeterminate after one row was cleared, then returned to zero. The selection
  sequence made no HTTP request and emitted no console error.
- `next_item`: implement the first bounded administrator diagnostic and safe
  generation preview, starting with the repeated missing-clinic configuration
  failure without putting generation work on the dashboard request path.
- `after_next`: extend configuration diagnostics to the next highest-evidence
  self-service problem, then continue the final scale and failure proof.
- Blockers and deferrals: pathway transitions, steps, comments, duration,
  patient detail, print, source-triggered safety refresh, reconnect backoff,
  migrated data, and the complete failure and soak matrix remain open. Selection
  deliberately creates no bulk clinical action contract.
- Coverage and ledger: exact behavioral coverage remains 50.0716 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. The new secondary mapping records the select-all evidence without
  inflating the already higher canonical score for its mixed legacy test file.
- Query and performance evidence: selection uses no database query and no HTTP
  request. The existing snapshot remains the sole bounded source of selectable
  rows and retains its three-clinical-query budget.
- Tests and repository state: JavaScript passes 23 tests, FileLedger integrity
  passes two tests with 22 assertions, the production frontend and container
  builds pass with only existing warnings, and the production browser smoke
  passes. Laravel, Docker, scaling-plan, and plan changes remain staged or ready
  to stage only, with no commit or push.
  `verification_state=page-bounded-selection-green; stale-selection-pruned;
  selection-network-zero; production-browser-selection-smoke-green;
  administrator-diagnostic-next; changes-staged`.

### 16.31 Hourly checkpoint - 2026-09-01 03:43 BST

- Current problem and acceptance condition: the first administrator diagnostic
  must explain repeated missing-clinic causes before a patient is missed, while
  keeping generation work outside the web request and avoiding a new expensive
  administration dashboard.
- Completed evidence: a separately authorized read-only route now shows active
  definitions, the maintained generated-through marker, configured target,
  bounded missing range, and exact recurrence estimate from the same planner as
  manager generation. It also shows leading or trailing mapping-key and value
  whitespace with normalized suggestions and privacy-bounded open intake reason
  totals. The page contains no generation control and states that generation is
  a manager-only bounded background task.
- Browser evidence: the rebuilt production image rendered all generation
  previews. A temporary trailing-space mapping produced the expected current
  and normalized values, after which the source row was restored. The page made
  no mutation request and emitted no console error.
- `next_item`: detect normalized mapping collisions and exact definition
  mismatches before correction, using bounded set-based diagnostics.
- `after_next`: add duplicate-instance and manager-generation heartbeat
  diagnostics, then continue the final scale and failure proof.
- Blockers and deferrals: configuration writes, explicit confirmed queueing,
  existing job state, feed horizon, replay, actual indexed instance gaps, and
  corrective actions remain open. The page does not claim these parity items.
  Migrated data and the complete concurrency, failure, and soak matrix remain
  the final scale gate.
- Coverage and ledger: exact behavioral coverage is 50.0762 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. Credit is limited to the reviewed legacy definition, mapping, instance
  preview, controller, and manager-generation evidence.
- Query and performance evidence: the page uses exactly three queries for one
  and 41 definitions. All definition, mapping, and unmatched-reason plans avoid
  filesort, temporary-table work, and optimizer hints. Permission denial occurs
  before any diagnostic query.
- Tests and repository state: focused diagnostics, ledger, parity, manifest,
  and generation reconciliation passes 24 tests with 3,345 assertions. Scoped
  Pint, the wider 39-test worklist pack, production frontend build, production
  image rebuild, and browser smoke pass. Changes remain staged or ready to stage
  only, with no commit or push.
  `verification_state=admin-diagnostics-green; web-generation-disabled;
  generation-planner-shared; diagnostic-query-budget-three;
  diagnostic-plans-no-sort-or-temp; production-browser-admin-smoke-green;
  mapping-collision-diagnostics-next; changes-staged`.

### 16.32 Hourly checkpoint - 2026-09-01 03:51 BST

- Current problem and acceptance condition: exact mapping permits subtle
  configuration conflicts that either make a definition match too broadly or
  make more than one definition match. The page must find high-confidence
  conflicts without fuzzy guessing, configuration writes, or more queries.
- Completed evidence: the existing bounded mapping result is now inspected for
  keys and values that collapse after trim and case normalization. The same
  result identifies active definitions with no mapping criteria and pairs with
  identical exact criteria, the same identifier type, and overlapping active
  dates. Findings name only configuration row ids and values already visible to
  an authorized configuration administrator. Nothing is corrected
  automatically.
- Browser evidence: four disposable definitions demonstrated normalized key and
  value collisions, an unconstrained definition, and an identical overlapping
  definition pair in the rebuilt production image. The page made no mutation
  request and emitted no console error. All disposable configuration rows were
  removed after the smoke.
- `next_item`: add duplicate-instance and manager-generation heartbeat
  diagnostics without scanning patient membership.
- `after_next`: add a safe duplicate reconciliation preview, then bounded replay
  planning for corrected configuration.
- Blockers and deferrals: fuzzy suggestions against inbound values are withheld
  because a close spelling is not authoritative clinical configuration.
  Save-time rejection, corrective writes, replay, and actual instance-gap proof
  remain open. The final migrated-data concurrency, failure, and soak matrix is
  unchanged.
- Coverage and ledger: exact behavioral coverage remains 50.0762 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. The new evidence deepens the already credited diagnostic mappings and
  does not inflate coverage.
- Query and performance evidence: all conflict checks run in bounded PHP over
  the existing definition and mapping result. The page still uses exactly three
  queries for one and 41 definitions, and all database plans avoid filesort,
  temporary-table work, and optimizer hints.
- Tests and repository state: the reconciled diagnostic, generation, route,
  ledger, read, and scale pack passes 39 tests with 3,584 assertions. Scoped
  Pint, production frontend build, production image build, and browser smoke
  pass. Changes remain staged or ready to stage only, with no commit or push.
  `verification_state=normalized-mapping-collisions-green;
  unconstrained-definition-warning-green; exact-signature-collision-green;
  diagnostic-query-budget-still-three; production-browser-conflict-smoke-green;
  temporary-browser-fixture-removed; generation-health-next; changes-staged`.

### 16.33 Hourly checkpoint - 2026-09-01 04:15 BST

- Current problem and acceptance condition: administrators could not tell when
  the manager last generated worklist instances or whether the projected
  instance set contained duplicate definition and start-time groups. Health
  must not be masked by manually scoped runs, and diagnostics must remain
  bounded, read-only, and free of patient membership scans.
- Completed evidence: the scheduled unscoped manager command now maintains one
  ephemeral heartbeat row with running, succeeded, failed, duration, row-count,
  last-success, and bounded failure-code fields. Manually scoped maintenance
  runs do not update it. The administrator page reports never-run, running,
  stuck, failed, stale, and healthy states. A covering-index aggregate reports
  duplicate groups over the bounded generation horizon and labels stored-empty
  extras as candidates only.
- Browser and manager evidence: a rebuilt production web image displayed a
  healthy manager heartbeat and two disposable empty duplicate instances with
  no mutation request or console error. The production manager image completed
  the scheduled command and recorded a successful heartbeat. All disposable
  rows were removed afterwards.
- `next_item`: add an authoritative read-only duplicate reconciliation preview
  that rechecks actual membership before proposing any action.
- `after_next`: define bounded replay planning for corrected configuration,
  then continue the next unblocked worklist administration parity item.
- Blockers and deferrals: no instance is deleted, merged, or retired in this
  checkpoint. Stored row counts are not sufficient authority for mutation.
  Configuration writes, replay, actual instance-gap proof, and the complete
  migrated-data concurrency, failure, and soak matrix remain open.
- Coverage and ledger: exact behavioral coverage is 50.0776 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. Credit is limited to the reviewed manager-generation and worklist
  definition evidence.
- Query and performance evidence: the page uses exactly five queries for one
  and 41 definitions. All definition, mapping, unmatched-reason, duplicate, and
  heartbeat plans avoid filesort, temporary-table work, and optimizer hints.
  The duplicate query uses a covering index and does not inspect appointment or
  patient rows.
- Tests and repository state: the focused diagnostics and generation pack
  passes 13 tests with 113 assertions; the reconciled wider worklist pack passes
  39 tests with 3,584 assertions. Scoped Pint, frontend unit tests, production
  frontend build, production web and manager image checks, production browser
  smoke, clean seven-schema migration, schema verification, and tiny seed pass.
  Changes remain staged or ready to stage only, with no commit or push.
  `verification_state=generation-heartbeat-green;
  manual-runs-cannot-mask-scheduler-health; duplicate-group-diagnostic-green;
  diagnostic-query-budget-five; diagnostic-plans-no-sort-or-temp;
  production-browser-and-manager-smoke-green; fresh-schema-green;
  authoritative-reconciliation-preview-next; changes-staged`.

### 16.34 Hourly checkpoint - 2026-09-01 04:32 BST

- Current problem and acceptance condition: duplicate metadata and stored row
  counts were not authoritative enough to decide which generated instance was
  empty. The preview must recheck the source appointment and current projection
  under a consistent snapshot, stay bounded, and never mutate an instance.
- Completed evidence: duplicate groups are capped at 500 and 20 instances per
  group. One optional batched membership query verifies both the active source
  appointments and current row projection. The preview keeps the only populated
  instance, reports verified empty extras, and withholds action on drift, mixed
  kinds, non-open status, multiple populated instances, a concurrent count
  mismatch, or an oversized group.
- Browser evidence: a rebuilt production image showed that a higher numbered
  populated instance was kept while the empty lower numbered instance was only
  proposed for retirement. The browser made no mutation request and reported no
  console error. All disposable appointment, projection, instance, and heartbeat
  rows were removed afterwards.
- `next_item`: add bounded replay planning for corrected worklist configuration
  without fuzzy matching or automatic correction.
- `after_next`: continue the next unblocked administrator parity item or
  projection rebuild proof.
- Blockers and deferrals: no instance is deleted, merged, or retired. The
  audited queued retirement action, keyset instance inspection, authoritative
  semantic configuration correction and replay, and the complete migrated-data
  concurrency, failure, and soak matrix remain open.
- Coverage and ledger: exact behavioral coverage is 50.0801 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review.
- Query and performance evidence: diagnostics use five queries without
  duplicates and six when duplicate membership is verified for both one and 41
  definitions. All six query plans avoid filesort, temporary-table work, and
  optimizer hints.
- Tests and repository state: focused diagnostics pass 7 tests with 84
  assertions; the clean wider worklist pack passes 59 tests with 1,643
  assertions. JavaScript passes 23 tests. Scoped Pint, production build, and a
  production browser smoke pass. Changes remain staged or ready to stage only,
  with no commit or push. `verification_state=duplicate-membership-snapshot-green;
  populated-instance-kept; drift-and-oversized-groups-withheld;
  diagnostic-query-budget-six; diagnostic-plans-no-sort-or-temp;
  production-browser-zero-mutation; disposable-fixtures-removed;
  bounded-replay-planning-next; changes-staged`.

### 16.35 Hourly checkpoint - 2026-09-01 05:02 BST

- Current problem and acceptance condition: corrected exact configuration may
  make retained unmatched appointments eligible, but the application had no
  bounded way to show that impact without mutating intake state or repeating
  definition queries per appointment.
- Completed evidence: retained appointments now snapshot their intake patient
  identifier type. The diagnostics page loads the latest 500 open unmatched
  appointments and at most 32,000 mapping rows, compiles the bounded exact
  definition catalog once, and reports privacy-safe current-reason to
  current-result totals. It does not change appointments, issues, definitions,
  generated clinics, or audit state, and replay remains explicitly disabled.
- Browser evidence: a rebuilt production image showed one retained appointment
  becoming `definition-match-ready`, while replay stayed `No`. The browser made
  no mutating request and reported no console error. The exact fixture and web
  container were removed afterwards.
- `next_item`: resolve definition-ready preview candidates to exact generated
  instances without mutation or patient-history reads.
- `after_next`: define corrected-version evidence and a separately authorized,
  audited, idempotent queued replay contract, or move to the next unblocked
  administration or projection-rebuild proof if authoritative rules are absent.
- Blockers and deferrals: a current definition match does not prove that the
  generated instance exists or that a configuration correction was authorized.
  Actual correction, replay, audit, queue chunking, post-run proof, feed health,
  and the complete migrated-data concurrency, failure, and soak matrix remain
  open.
- Coverage and ledger: exact behavioral coverage is 50.0808 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review.
- Query and performance evidence: diagnostics stay at exactly eight queries for
  one and 41 definitions and for 501 unmatched appointments. The 501-row replay
  candidate query uses its covering schema-packet index and all eight plans
  avoid filesort, temporary-table work, and optimizer hints.
- Tests and repository state: the clean worklist pack passes 73 tests with 1,857
  assertions; a new seven-schema build passes all 298 migrations, tiny seed,
  schema verification, and 8 fresh-schema diagnostics tests with 109 assertions.
  JavaScript passes 23 tests. Scoped Pint, production image build, and production
  browser smoke pass. Changes remain staged or ready to stage only, with no
  commit or push. `verification_state=replay-impact-preview-green;
  identifier-type-snapshot-green; diagnostic-query-budget-eight;
  501-candidate-plan-no-sort-or-temp; fresh-schema-green;
  production-browser-zero-mutation; disposable-fixtures-removed;
  generated-instance-resolution-next; changes-staged`.

### 16.36 Hourly checkpoint - 2026-09-01 05:19 BST

- Current problem and acceptance condition: a current exact definition match
  did not prove that one usable generated clinic existed for the appointment.
  Resolution had to avoid one temporal database query per appointment, remain
  bounded for 500 candidates, and keep replay mutation closed.
- Completed evidence: the compiled definition catalog now derives the same
  automatic natural key as instance generation. One institution-scoped batch
  query resolves up to 500 unique keys, after which the preview validates the
  definition, automatic kind, open or closed state, and appointment time window
  in memory. Missing, deleted, manual, retired, mismatched, and out-of-window
  instances are reported as safe failure codes. No patient history is read, no
  instance key is returned, and appointments, intake issues, definitions,
  instances, and audit state remain unchanged.
- Browser evidence: a rebuilt production FrankenPHP image showed one checked
  appointment, one definition-ready match, one exact instance-ready result, and
  replay `No`. The browser made no mutating request and reported no console
  error. The synthetic appointment, issue, mapping, definition, instance,
  browser script, and web container were removed afterwards.
- `next_item`: define the minimum corrected-version evidence that proves why a
  retained unmatched appointment is eligible for replay, without inventing a
  clinical correction rule.
- `after_next`: define a separately authorized, audited, idempotent queued
  replay contract that rechecks all evidence inside the mutation transaction,
  or move to the next unblocked administrator or projection-rebuild proof when
  authoritative correction evidence is absent.
- Blockers and deferrals: preview readiness is not authorization to replay.
  Correction provenance, version evidence, least-privilege mutation authority,
  audit, chunk ownership, idempotency, concurrency recheck, post-run proof, feed
  health, and the complete migrated-data failure and soak matrix remain open.
- Coverage and ledger: exact behavioral coverage is 50.0811 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review.
- Query and performance evidence: diagnostics use exactly nine queries for one
  and 41 definitions and for 501 unmatched appointments. The exact instance
  read is one unique-index batch with no query-count growth. Its 500-key plan
  and all other diagnostic plans avoid filesort, temporary-table work, and
  optimizer hints.
- Tests and repository state: focused diagnostics and generation pass 16 tests
  with 175 assertions; the clean worklist confidence pack passes 74 tests with
  1,871 assertions. JavaScript passes 23 tests. Scoped Pint, the 500-key query
  plan, production frontend build, production image build, and the no-retry
  production browser smoke pass. Changes remain staged or ready to stage only,
  with no commit or push. `verification_state=exact-instance-resolution-green;
  unsafe-instance-states-withheld; diagnostic-query-budget-nine;
  500-key-unique-index-plan-no-sort-or-temp; wide-worklist-pack-green;
  production-browser-zero-mutation; disposable-fixtures-removed;
  corrected-version-evidence-next; changes-staged`.

### 16.37 Hourly checkpoint - 2026-09-01 05:34 BST

- Current problem and acceptance condition: replay readiness needed an exact,
  privacy-safe version of the retained input, current configuration decision,
  open issue, and target instance. Repeating an unchanged preview had to be
  stable, any relevant change had to invalidate it, and the evidence could not
  make the indexed candidate query widen, sort, or use a hint.
- Completed evidence: exact-definition catalogs now have a deterministic
  behavior revision independent of input row order. Each candidate contributes
  a private fingerprint covering stored source and ordering revisions, intake
  identifier and schedule snapshots, mapping values, issue evidence and state,
  current match result, and exact instance identity, lock version, state, and
  time window. The response contains only contract version 1 and one opaque
  snapshot digest. Raw source identifiers, mapping values, appointment IDs,
  issue IDs, instance IDs, and patient data are not returned. Upstream data
  corrections remain owned by the normal PAS adapter.
- Browser evidence: a production FrankenPHP image reached global page state
  `ready`, showed evidence contract `v1`, a 12-character snapshot correlation
  value, and replay `No`. The browser made no mutating request and reported no
  console error. Its temporary script, network attachment, and web container
  were removed.
- `next_item`: define the separate replay capability, durable bounded batch and
  item records, explicit authorization request, audit envelope, and idempotent
  transaction-time evidence recheck before enabling any mutation.
- `after_next`: implement the smallest safe queued replay path if that contract
  remains source-faithful; otherwise record the narrow blocker and advance to
  feed health or projection rebuild proof.
- Blockers and deferrals: the evidence digest is not replay authority. No
  replay endpoint, mutation capability, queue record, appointment correction,
  issue resolution, audit action, or post-run reconciliation is enabled yet.
  The complete migrated-data concurrency, failure, and soak matrix remains
  open.
- Coverage and ledger: exact behavioral coverage remains 50.0811 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. This architecture seam adds no unsupported coverage credit.
- Query and performance evidence: a wider candidate projection caused MariaDB
  to choose filesort during the first focused run. The final implementation
  keeps that narrow indexed query and fetches evidence through one bounded
  primary-key batch. Diagnostics use exactly ten queries for one and 41
  definitions and for 501 unmatched candidates. All inspected plans avoid
  filesort, temporary-table work, and optimizer hints.
- Tests and repository state: focused matching and diagnostics pass 18 tests
  with 189 assertions; the clean worklist confidence pack passes 84 tests with
  1,901 assertions. JavaScript passes 23 tests. Scoped Pint, relevant primary
  and unique index-plan assertions, production frontend and image builds, and
  the production browser smoke pass. Changes remain staged or ready to stage
  only, with no commit or push. `verification_state=replay-evidence-v1-green;
  deterministic-configuration-revision; source-issue-instance-invalidation;
  diagnostic-query-budget-ten; all-diagnostic-plans-no-sort-or-temp;
  no-index-hint; wide-worklist-pack-green; production-browser-zero-mutation;
  disposable-runtime-removed; queued-replay-contract-next; changes-staged`.

### 16.38 Hourly checkpoint - 2026-09-01 06:48 BST

- Current problem and acceptance condition: enabling administrator replay
  required reconstructable retained inputs, a separately authorized request,
  durable bounded work, transaction-time evidence rechecks, idempotent retry,
  audit, and privacy-safe progress. A configuration change could not occur
  between the evidence decision and the clinical write.
- Completed evidence: each appointment now retains a normalized bounded source
  packet and a source-only digest. Replay stores the exact opaque evidence and
  target revisions in durable batch and item rows, accepts only a server-
  recomputed evidence version and preview revision, processes 25 items at a
  time, and rechecks source, issue, mapping, generated instance, and projection
  state before applying the ordinary projection writer. The configuration rows
  remain locked over each clinical chunk. Retry preserves completed items,
  safely resumes failed batches with unchanged evidence, and records bounded
  replay audit events. The browser receives only batch state and counts.
- Production evidence: the opt-in current-date factory generated 8 definitions,
  242 instances, and 913 appointments with canonical retained source hashes. A
  production FrankenPHP browser flow created one replay-ready issue, submitted
  one authorized request, observed HTTP 202 followed by two successful status
  reads, and finished with 1 applied, 0 skipped, 0 failed, no browser error, and
  no replay-ready item left. The dedicated queue completed the job in 121.46
  milliseconds. OELOG fields contained no URL, route parameter, SQL, payload,
  or patient identifier.
- `next_item`: inspect and remove any remaining shared worklist-instance write
  serialization on membership changes, then prove same-clinic writers do not
  collapse onto one hot row.
- `after_next`: complete the publisher partition and backpressure proof before
  widening realtime delivery or opening more worklist behavior.
- Blockers and deferrals: this is safe current-configuration replay only. It
  does not correct upstream clinical data, guess fuzzy mappings, or complete the
  migrated-data load, failure, and soak matrix. Full administrator repair and
  projection rebuild workflows remain open.
- Coverage and ledger: exact behavioral coverage remains 50.0811 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. No coverage credit was added for architecture-only evidence.
- Query and performance evidence: diagnostics remain fixed at ten service
  queries for one or 41 definitions and 501 candidates. Replay submission uses
  ten service queries and status uses one. All inspected plans avoid filesort,
  temporary-table work, and optimizer hints.
- Tests and repository state: the combined replay, foundation, and sample pack
  passes 28 tests with 371 assertions; the configuration-lock replay pack passes
  11 tests with 128 assertions; the clean worklist confidence pack passes 84
  tests with 1,901 assertions. JavaScript passes 23 tests. Clean seven-schema
  migration, tiny seed, schema verification, ledger gates, scoped Pint,
  production frontend and web, manager, and queue images, and the no-retry
  production browser flow pass. Changes remain staged only, with no commit or
  push. `verification_state=queued-replay-v1-green; retained-input-canonical;
  configuration-locked-per-chunk; retry-idempotent; production-browser-one-
  applied; privacy-bounded-telemetry; diagnostic-query-budget-ten;
  no-filesort-no-temp-no-hint; membership-contention-next; changes-staged`.

### 16.39 Hourly checkpoint - 2026-09-01 07:40 BST

- Current problem and acceptance condition: membership-changing appointment
  writes still converged on the shared `worklist_instance` row. They had to
  preserve exact clinic totals and the rare retirement fence while allowing
  ordinary same-clinic and concurrent membership writers to proceed without
  one exclusive hot-row queue.
- Completed evidence: `worklist_instance.row_count` is removed from the initial
  schema packet. Each membership change adjusts one of 64 fixed,
  appointment-stable count shards. Membership validation holds only a shared
  instance lock, so many writers can proceed while still excluding a future
  exclusive retirement. Signed membership deltas replace absolute totals in
  new outbox events, while old absolute events remain readable during rollout.
  A snapshot now establishes its high-water cursor, authorized counts, and rows
  inside one repeatable-read clinical transaction. Later page loads validate
  metadata without replacing counts already advanced by live deltas.
- Factory evidence: the opt-in manager factory replaces the deploy-supplied
  Bash generation step for current-date demo worklists. On a clean production
  stack it ran twice with identical results: 8 definitions, 242 instances, and
  913 appointments from 2026-08-30 through 2026-10-01. A browser saw eight
  current-date clinic choices and opened a populated clinic with the exact
  patient count and no page or API errors.
- `next_item`: add stable publisher backlog, oldest-age, partition-lag, rate,
  retry, and failure visibility, then make enqueue and reconciliation
  backpressure explicit and bounded around the existing 64 partition workers.
- `after_next`: add the manager-only projection rebuild with an authoritative
  count and hash proof before representative migrated-data scale testing.
- Blockers and deferrals: this removes the known membership counter hot row but
  does not claim the final sustained 100-per-second hot-clinic or 250-per-second
  broad write rate, redo and binlog cost, 5,000-dashboard or 125,000-subscription
  capacity, failure matrix, or soak. Those require representative migrated data
  and deployment-level measurement.
- Coverage and ledger: exact behavioral coverage remains 50.0811 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. The concurrency correction adds no unsupported coverage credit.
- Query and performance evidence: totals for 25 selected clinics read at most
  1,600 narrow shard rows in one primary-key query. The plan stays indexed beside
  100 unrelated clinics and uses no filesort, temporary table, full-scan waiver,
  or optimizer hint. The schema boot gate now requires repeatable-read for the
  coherent snapshot contract.
- Tests and repository state: the clean worklist pack passes 86 tests with 2,032
  assertions; JavaScript passes 24 tests; ledger and parity gates pass 3 tests
  with 845 assertions. All 298 migrations, tiny seed, schema verification,
  scoped Pint, production build, real queue replay, and current-date dashboard
  browser smoke pass. Changes remain staged or ready to stage only, with no
  commit or push. `verification_state=membership-hot-row-removed;
  sixty-four-count-shards; shared-retirement-fence; signed-delta-compatible;
  repeatable-read-boot-gate; one-query-count-plan; no-sort-temp-or-hint;
  factory-idempotent-production; browser-current-date-green;
  publisher-backpressure-next; changes-staged`.

### 16.40 Hourly checkpoint - 2026-09-01 08:16 BST

- Current problem and acceptance condition: reconciliation could inspect an
  unbounded outbox and directly perform network delivery in the manager, while
  one publisher job had no explicit work or time ceiling. Backlog repair had to
  remain durable, privacy bounded, independently scalable, and unable to delay
  ordinary queue work.
- Completed evidence: manager reconciliation reads at most 1,001 oldest pending
  rows through the indexed pending-and-time order, reports an honest lower bound
  when capped, and schedules at most one job attempt for each of 64 partitions.
  A job publishes batches of 100 and yields after at most ten batches or two
  seconds. It exposes only partition, batch, count, duration, result, and bounded
  retry or failure statistics. The ordinary queue consumes `webhooks,default`;
  the separate worklist queue consumes only `worklist-broadcast` and has its own
  replicas and resource budget in Helm.
- Runtime evidence: after correcting a deliberately invalid synthetic partition
  fixture, the production-style queue drained all 640 pending changes across
  eight partitions with zero remaining database or Redis backlog. The ordinary
  queue emitted no publisher run. A 10,000-row test backlog scheduled exactly 64
  attempts without an exact full-table count.
- Manager startup correction: the existing manager pattern runs migration and
  schema verification before publishing readiness. A cold Compose gate exposed
  that its probe budget was shorter than initialization. Since major-version
  migrations can take an hour, Compose and Kubernetes now allow 75 minutes for
  the manager, web marker check, and queue waits, release immediately on success,
  and retain strict steady-state readiness and liveness afterwards.
- `next_item`: add the manager-only authoritative worklist projection rebuild
  with keyset chunks plus before-and-after count and hash proof.
- `after_next`: complete per-partition lag and rate evidence, then prepare the
  representative migrated-data publisher and realtime failure matrix.
- Blockers and deferrals: the 640-change drain and 10,000-row backlog are early
  bounded proofs, not the final sustained 100-per-second hot-clinic or
  250-per-second broad rate, redo or binlog I/O, 5,000 dashboards, 125,000
  subscriptions, failure recovery, or soak claim.
- Coverage and ledger: exact behavioral coverage remains 50.0811 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. Architecture-only publisher and deployment evidence adds no coverage.
- Tests and repository state: focused publisher tests pass 13 tests with 211
  assertions; the fresh worklist pack passes 98 tests with 2,076 assertions;
  JavaScript passes 24 tests; ledger and parity gates pass 3 tests with 845
  assertions. All 298 migrations, schema verification, tiny seed, scoped Pint,
  production frontend and role images, Helm, image, cold Compose, queue, and
  current-date browser gates pass. Changes remain staged or ready to stage only,
  with no commit or push. `verification_state=publisher-sample-bounded;
  manager-network-work-removed; job-batch-and-time-capped;
  dedicated-worklist-queue; runtime-640-drained; ordinary-queue-isolated;
  major-migration-startup-75-minutes; no-sort-temp-or-hint;
  projection-rebuild-next; changes-staged`.

### 16.41 Hourly checkpoint - 2026-09-01 08:48 BST

- Current problem and acceptance condition: a current worklist row can drift
  from its authoritative appointment, retained display and safety input, or
  current pathway without receiving another PAS message. The repair must run
  only in the manager, remain bounded and resumable, allow live writes, prove
  what it observed, and publish every repair through the normal client path.
- Completed evidence: `oe:worklist:rebuild-projection` captures a fixed maximum
  appointment id, keyset reads at most 500 ids at a time, and reconciles each
  appointment in its own short transaction. It verifies the retained input SHA
  and source revision, match state, live institution-scoped target instance and
  definition, and authoritative worklist-created pathway and requested step.
  Invalid narrow records fail closed with bounded reason codes and no patient
  values in output.
- Revision and proof contract: source `ingest_revision` remains the external
  ordering watermark. Independent `projection_revision` advances above both
  the aggregate and any current-row version whenever projected content is
  repaired, so a connected browser cannot discard the outbox event as stale.
  The run reports keyed before, expected, and actual hashes over the exact
  observed revisions. A repeatable-read final snapshot compares current-row
  count with the sum of all 64 count shards. Only a zero-failure matching proof
  is audited as completed.
- `next_item`: expose bounded per-partition lag and recent publish-rate evidence
  without a full outbox count or unbounded metrics cardinality.
- `after_next`: add source feed health to the administrator diagnostics, then
  prepare the representative migrated-data publisher, realtime, failure, and
  soak harness rather than claiming capacity from synthetic small data.
- Blockers and deferrals: this is a correctness and lock-shape proof, not the
  final migrated-data throughput, redo, binlog, 5,000-dashboard,
  125,000-subscription, failure-recovery, or soak gate. The first wide test run
  in the new isolated network had no Redis service; its only failure was the
  direct Redis delivery test and passed when the missing test prerequisite was
  added.
- Coverage and ledger: exact behavioral coverage remains 50.0811 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. The `WorklistManager.php` target evidence is expanded without
  increasing its conservative 60 percent score.
- Query and performance evidence: the institution-scoped keyset cursor has a
  matching `(institution_id, id)` index in the initial schema packet. Its plan
  and the existing snapshot plan use no filesort, temporary table, full-scan
  waiver, or optimizer hint. A two-connection MariaDB test holds one appointment
  lock while another appointment in the same clinic updates in under the
  bounded wait gate.
- Tests and repository state: a fresh database passed all 298 migrations and
  tiny seed. The clean worklist pack passes 93 tests with 2,079 assertions; the
  focused foundation passes 10 tests with 148 assertions; contention passes 3
  tests with 14 assertions. Scoped Pint and diff checks pass. Changes remain
  staged or ready to stage only, with no commit or push.
  `verification_state=projection-rebuild-keyset; appointment-local-lock;
  separate-monotonic-projection-revision; retained-input-sha-verified;
  authoritative-pathway-row; keyed-before-expected-after-proof;
  repeatable-read-count-proof; client-outbox-repair; privacy-bounded-failures;
  no-sort-temp-hint; partition-rate-next; changes-staged`.

### 16.42 Hourly checkpoint - 2026-09-01 09:36 BST

- Current problem and acceptance condition: publisher health must expose useful
  lag and recent-rate evidence without exact outbox counts, group-by scans, hot
  rows, or unbounded metric cardinality. Administrator feed health must report
  real source activity without treating a quiet PAS feed as failed or confusing
  broadcast acceptance with browser receipt.
- Completed publisher evidence: the existing fenced partition-completion write
  now maintains cumulative and current and immediately previous UTC-minute
  publish counts. A single bounded query reads the fixed 64 state rows and each
  partition's indexed pending head. The scheduled command keeps one scalar
  summary; `--details` emits exactly the fixed maximum of 64 privacy-bounded
  records. An affected-row mismatch aborts completion before the cursor or
  counters can drift.
- Completed source evidence: accepted upstream appointment writes alone set
  nullable `last_ingested_at`. Duplicate, stale, conflicting, derived replay,
  and projection-rebuild paths cannot refresh it. The authorized diagnostics
  page shows this intake activity, the oldest institution pending delivery, and
  the latest broadcast-fabric acceptance. It labels the contract
  `activity-not-heartbeat-v1` and explicitly states that browser receipt is not
  proved.
- `next_item`: define and implement explicit PAS worklist intake concurrency and
  backpressure from the frozen synchronous caller contract, failing clearly
  before clinical database connections are exhausted.
- `after_next`: prepare the representative migrated-data load and failure
  harness, then run the complete dashboard, subscription, publisher, recovery,
  I/O, and soak matrix only when representative data and the intended scaled
  topology exist.
- Blockers and deferrals: migrated-data redo, binlog, institution-health index
  write cost, 5,000 dashboards, 125,000 subscriptions, source heartbeat,
  browser acknowledgement, failure recovery, and soak remain unclaimed. The
  first disposable proof stack lacked six category schemas and a later attempt
  inherited MariaDB's server-default collation; a fourth untouched stack with
  all seven application-contract collations passed.
- Coverage and ledger: exact behavioral coverage remains 50.0811 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. `WorklistManager.php` remains conservatively scored at 60 percent and
  all 88 worklist parity rows remain present.
- Query and performance evidence: partition status is one query beside 1 and
  1,001 pending changes. All three source-health reads retain explicit limits
  and matching indexes. Every inspected plan avoids filesort, temporary table,
  full-scan waiver, and optimizer hint. The final migrated-data gate must
  measure the added institution-health index's write, redo, and binlog cost.
- Tests and repository state: a fresh MariaDB 11.8 stack passed all 298
  migrations and tiny seed. Focused worklist tests pass 44 tests with 663
  assertions; the wider worklist pack passes 88 tests with 2,004 assertions;
  JavaScript passes 24 tests; ledger and parity pass 3 tests with 845
  assertions. Scoped Pint, production web, manager, and queue builds, manager
  summary plus 64-detail execution, and a no-retry production browser smoke all
  pass. Changes remain staged or ready to stage only, with no commit or push.
  `verification_state=partition-lag-one-query; fixed-cardinality-64;
  rolling-minute-rates; affected-row-fenced; writer-owned-intake-time;
  activity-not-heartbeat; broadcast-not-browser-receipt;
  source-plans-indexed; no-sort-temp-hint; production-browser-ready;
  pas-ingress-backpressure-next; changes-staged`.

### 16.43 Hourly checkpoint - 2026-09-01 10:05 BST

- Current problem and acceptance condition: frozen V1, V2, and V3 PAS
  appointment callers require immediate synchronous results, so intake must be
  bounded across pods and institutions without moving the clinical transaction
  behind a queue or exhausting MariaDB connections.
- Completed intake gate: authenticated and capability-authorized appointment
  requests use one atomic zero-wait Redis sorted-set lease gate. Defaults cap a
  deployment at 16 active requests and one institution at 8, use Redis server
  time, purge expired leases, and require the 35-second lease to exceed the
  30-second request maximum. Saturation returns XML 503 with `Retry-After` and
  performs zero clinical queries. One hundred repeated saturated acquisitions
  never exceed the two-slot test capacity.
- Completed failure behavior: Redis admission coordination loss is the narrow
  fail-open case required by the scaling contract. It emits privacy-bounded
  telemetry and continues under finite FrankenPHP worker and request limits.
  Invalid configuration or invalid coordinator state fails closed before
  clinical work. Release failure cannot alter a committed caller response and
  the opaque lease expires automatically.
- Manager review: the manager removes readiness, verifies modules and schedule,
  runs migrations and schema verification, publishes the release marker, then
  starts cron and the Laravel scheduler. Compose and Kubernetes startup gates
  allow 75 minutes for major-version migrations that can last an hour; strict
  steady-state health checks begin after startup. No manager change is needed.
- `next_item`: perform one short worklist redesign-risk review covering the
  projection, transaction, publisher, transport, authorization, and admission
  boundaries, then stop current scale tuning unless a finding would force the
  whole feature to be replaced.
- `after_next`: return to the highest-value functional rewrite slice. Build the
  realistic synthetic or migrated-data load harness later, when it can choose
  query and view shapes, indexes, partition and worker counts, optional
  connection pooling, and capacity from meaningful evidence.
- Blockers and deferrals: a representative migrated production dataset and final
  scaled topology do not yet exist. Sustained 100-per-second hot-clinic writes,
  250-per-second broad writes, 5,000 dashboards, 125,000 subscriptions, 5,000
  unique configurations, redo, binlog, database I/O, failure recovery, and soak
  remain explicitly unclaimed.
- Coverage and ledger: exact behavioral coverage remains 50.0811 percent across
  14,125 canonical paths and 18,424 mappings, with zero missing and zero pending
  review. Controller, route, and appointment-test rows now cite the admission
  evidence without raising their conservative coverage scores. All 88 worklist
  parity rows remain present.
- Query and performance evidence: capacity and invalid-state rejections perform
  zero clinical queries. The widened worklist pack passes 111 tests with 2,255
  assertions, including fixed query counts, query plans, same-clinic contention,
  all PAS versions, and the real Redis gate. No serving query, index, optimizer
  hint, filesort waiver, or temporary-table waiver changed in this checkpoint.
- Tests and repository state: the focused intake and adapter pack passes 16 tests
  with 232 assertions; ledger and parity pass 3 tests with 845 assertions; scoped
  Pint passes. Current production web, manager, and queue images build and pass
  their role and configuration verification; the web image is 227,701,877 bytes.
  The earlier clean Compose gate passed all 298 migrations, schema verification,
  tiny seed, and healthy web, manager, and queue roles. Changes remain staged or
  ready to stage only, with no commit or push.
  `verification_state=pas-sync-contract-preserved; atomic-zero-wait-admission;
  global-and-institution-capacity; redis-server-time; expiring-opaque-leases;
  saturation-before-clinical-db; redis-loss-platform-bounded;
  invalid-state-fail-closed; bounded-telemetry; manager-startup-75m;
  worklist-111-2255; ledger-parity-3-845; production-images-verified;
  worklist-redesign-risk-review-next; realistic-load-later; changes-staged`.

### 16.44 Worklist redesign-risk review - 2026-09-01 10:20 BST

- Review result: no current finding requires the worklist system to be replaced
  later. The expensive-to-change boundaries are established and remain suitable
  for hundreds of appointment updates per minute and thousands of differently
  configured connected dashboards, subject to the explicitly deferred realistic
  load and failure gate.
- Stable architecture: appointment writes lock the source appointment rather
  than an ordinary shared clinic row, update the narrow current-row projection,
  and create the durable outbox in a short clinical transaction. Publisher
  claims and completion use fenced per-partition transactions, while Redis and
  Reverb I/O occur outside those transactions. Snapshot reads select only the
  bounded current-row DTO, accept at most 25 authorized worklists, and use
  keyset cursors. Delta recovery is cursor-based and bounded. The browser has no
  full-list polling or forced reload loop.
- Isolation and change seams: private-channel authorization rechecks the leased
  selection in one bounded clinical access query. Reverb has a separately
  scalable role and deliberately receives no database credentials. The
  worklist publisher has its own queue and resource limits. The compact
  versioned patch contract is transport-neutral, so the known Pusher JavaScript
  reconnect-jitter limitation can be patched or replaced without replacing the
  projection, outbox, authorization, or browser state model.
- Deferred tuning: representative synthetic or migrated data will choose the
  final snapshot SQL or view shape, indexes, partition and count-shard numbers,
  batch coalescing, worker and Reverb capacity, optional connection pooling,
  retention, and reconnect timing. Current small-fixture evidence rejects
  obviously unsafe designs but is not a concurrency or production-capacity
  claim.
- Static check: the worklist application and browser paths contain no interval
  polling, page reload, advisory or table lock, or index hint. The realtime
  deployment rejects the clinical Secret and receives Redis plus Reverb state
  only; the independently scalable worklist queue retains the database access
  required to drain the durable outbox.
- `next_item`: stop worklist scale tuning and begin the next high-value
  functional slice with a bounded patient-summary read review, limited first to
  behavior and data-shape decisions that would otherwise become expensive to
  change after migration.
- `after_next`: implement the smallest caller-evidenced patient-summary slice
  with authorization, clinical invariants, constant query growth, relevant
  plan evidence, FileLedger mappings, and one browser smoke; defer realistic
  history-heavy tuning until representative data exists.
- Coverage, verification, and repository state: coverage remains 50.0811
  percent across 14,125 canonical paths and 18,424 mappings. No production code,
  query, index, schema, parity item, or coverage score changed in this review.
  Checkpoint 28 focused and wider test evidence remains current. Changes remain
  staged or ready to stage only, with no commit or push.
  `verification_state=worklist-redesign-risk-review-green;
  no-whole-system-rewrite-blocker; architecture-seams-stable;
  realistic-load-and-tuning-deferred; patient-summary-bounded-review-next`.

### 16.45 Patient-summary bounded event timeline - 2026-09-01 11:05 BST

- Current problem and acceptance condition: the legacy patient sidebar walks a
  patient's full episode and event graph, performs neighbouring lookups while
  rendering rows, and therefore grows in both response data and query work for
  history-heavy patients. The first patient-summary slice must make initial page
  cost independent of total event history without guessing at later visual
  parity.
- Completed storage and lifecycle contract: the initial clinical schema packet
  now contains `patient_event_timeline`, keyed by event and indexed on
  `(patient_id, event_date, event_id)`. Event create, update, soft-delete, and
  delete lifecycle events maintain the same-row patient, episode, type, and date
  projection. Tiny seed loading rebuilds the projection after its bulk fixture
  load. The first real legacy bulk importer must write or rebuild it before web
  readiness; a live online rebuild is not implied.
- Completed read contract: `patients.show` loads at most 51 narrow projection
  rows to return 50, then resolves event types in one batch. The named
  `api.patients.event-timeline.index` operation uses patient-bound versioned
  keyset cursors, a maximum page size of 100, normal authentication and
  break-glass authorization, validation, stable input metadata, and no retry or
  offset scan.
- Completed rendering contract: the patient page and shared event sidebar render
  the bounded DTO and expose one accessible `Load older events` action. Sorting
  and expand or collapse remain local. Legacy draft rows, deleted-event
  placement, institution and specialty grouping, issue state, laterality, and
  rich quicklook data remain explicit parity work rather than hidden query work.
- Query and performance evidence: one versus 160 events uses the same two
  clinical queries for the timeline page. MariaDB selects
  `ix_patient_event_timeline_page` without filesort, a temporary table, a full
  scan, or an optimizer hint. The declarative `patients.show` plan budget now
  checks the real projection and the initial controller no longer eager-loads
  all episodes and events.
- Verification: a clean seven-schema MariaDB 11.8 stack passed all 298
  migrations, tiny seed, schema verification, and all seven query-plan budgets.
  The focused pack passed 28 tests with 2,557 assertions; login passed 7 tests
  with 70 assertions; JavaScript passed 24 tests; scoped Pint and the production
  frontend build passed. A production FrankenPHP browser flow reached
  `ready`, rendered 50 of 60 events, loaded the final 10 with exactly one
  timeline request, and made no mutation request or failing response.
- `next_item`: review the existing bounded medication-consumer projection for
  direct patient-summary use, then add the smallest clinically useful current
  medication presentation only if it preserves a strict initial-page query and
  row budget.
- `after_next`: continue the next caller-evidenced patient-summary or ordinary
  vision and refraction gap. Reserve history-heavy tuning and the final patient
  summary interaction design for representative migrated data and later UAT.
- Coverage and repository state: exact behavioral coverage is 50.0882 percent
  across 14,125 canonical paths and 18,424 mappings, with zero missing and zero
  pending review. Only the two directly reviewed legacy sidebar files gained
  conservative partial evidence. Changes remain staged or ready to stage only,
  with no commit or push.
  `verification_state=patient-timeline-projection; bounded-50-plus-one;
  patient-bound-keyset-cursor; event-lifecycle-maintained; two-query-constant;
  indexed-no-sort-temp-hint; clean-298-migrations; browser-50-to-60-one-request;
  ledger-14125-18424-50.0882; medication-summary-review-next`.

### 16.46 Patient-summary medication panels and event-image control - 2026-09-01 11:50 BST

- Classification: keeping the established patient-summary layout and removing
  medication N+1 families are architecture-now work. The optional progressive
  event-image mode is a seam-now change and stays off until its serving workflow
  and both-mode browser tests exist. Its bounded initial group size is selected
  later from clinical usability and realistic load evidence rather than fixed
  at 10. The compact default patient summary remains an independent far-future
  change request.
- Patient-summary rule: the full legacy layout is the default acceptance target,
  including panel order, labels, clinical content placement, current and stopped
  medication sections, laterality, dates, tooltips, and source links. Internal
  projections and batching may differ. Any deliberate visible divergence needs
  a recorded decision before release.
- PR review rule: local medication performance PR folders are checked as evidence
  against current Laravel behavior and are not copied automatically. The active
  regression gate covers per-row lineage walks, lazy reference hydration,
  prescription-item relations, repeated medication-set checks, and comparator
  queries while sorting.
- Medication acceptance: one lazy overview request is shared by the eye and
  systemic panels. It must merge untracked final prescriptions into current
  rows, retain stopped rows and their collapsed presentation, use precomputed
  stable sort values, stay institution and time bounded, and have constant query
  count from one through 100 lineages. No current row may be hidden merely to
  satisfy an arbitrary presentation limit; an explicit safety link is required
  if a bounded source cap is reached.
- Event-image emergency control: add the installation setting
  `generate_event_images`, default `on`. With the setting off, compatible cached
  images remain readable, cache misses reject before PNG rendering or artifact
  writes, PDF output remains enabled, and the future patient-summary image
  section handles the unavailable result without retries. Revision safeguards
  remain authoritative, so the emergency mode never serves a clinically stale
  artifact merely to avoid generation.
- Release-control pattern: optional high-impact behavior starts in the legacy
  mode and records an owner, both-mode tests, telemetry, rollback, and removal or
  approval gate. Internal correctness and performance fixes do not receive a
  permanent feature switch by default.
- Completed medication retrieval: an authoritative institution snapshot now
  lives on medication-management and history rows and is indexed with patient,
  recorded time, event, and row identity. Patient-summary reads no longer join
  through events merely to establish institution. The bounded overview loads
  tracked history and otherwise-untracked final prescription sources in two
  capped sets, resolves prescription lineage eagerly, and sorts from precomputed
  values. One and 25 linked prescription rows use the same query count and the
  source links identify the originating prescription item.
- Completed presentation: one parent-owned lazy request is shared by the legacy
  Eye Medications and Systemic Medications panels. Current and stopped groups,
  established labels and ids, Nil and no-current states, laterality, dates,
  collapsed stopped rows, comments, information affordances, and current source
  links are present. Reaching the source cap is explicit and offers the full
  medication view. Exact legacy change-history tooltip detail and the remaining
  patient-summary panels are still open, so this is not a full-layout parity
  claim.
- Completed emergency image seam: the installation setting
  `generate_event_images` defaults to `on`. When disabled, a compatible cached
  PNG is returned, a cache miss is rejected before renderer or filesystem work,
  and PDF and HTML generation remain available. Rejection telemetry contains
  only bounded output and result fields. The event-image serving endpoint and
  graceful patient-summary unavailable state remain required before this
  workflow is called ported. The separate progressive-image feature remains off
  by default and its initial group size remains an evidence-led later decision,
  not a fixed count.
- Query and verification evidence: the patient-medication focused pack passed
  97 tests with 1,719 assertions, the ledger pack passed 2 tests with 22
  assertions, JavaScript passed 24 tests, scoped Pint passed, and the production
  frontend build passed. A clean seven-schema MariaDB 11.8 database retains all
  298 migrations, tiny seed and schema verification. All nine plan budgets pass
  without filesort, temporary table, scan, or optimizer hint. A production
  browser rendered one current eye medication and one stopped systemic
  medication, expanded stopped rows, made exactly one GET for both panels, and
  produced no mutation, failed request, runtime error, or console error.
- `next_item`: close the smallest caller-evidenced missing legacy
  patient-summary panel while retaining its established placement and using a
  bounded DTO with constant query growth.
- `after_next`: continue the next missing patient-summary panel or ordinary
  vision and refraction gap. Add paginated continuation before claiming exact
  medication content for patients whose source set exceeds the current safety
  cap.
- Coverage and repository state: exact behavioral coverage is 50.0897 percent
  across 14,125 canonical paths and 18,424 mappings, with zero missing and zero
  pending review. Changes remain staged or ready to stage only, with no commit
  or push.
  `verification_state=medication-summary-browser-green;
  medication-lineage-query-count-constant; source-cap-explicit;
  event-image-cache-only-emergency-policy-green;
  progressive-image-default-off-size-undecided;
  clean-298-migrations; nine-query-plans-green;
  ledger-14125-18424-50.0897; next-patient-panel-active`.

### 16.47 Patient-summary diagnosis placement - 2026-09-01 12:12 BST

- Current problem and acceptance condition: the patient page placed confirmed
  systemic diagnoses in the Eye Diagnoses panel and exposed a non-legacy Other
  Diagnosis States panel. The safe slice must restore the familiar eye and
  systemic placement without reintroducing unbounded patient-history reads.
- Completed presentation: the established Eye Diagnoses and Systemic Diagnoses
  panels now appear on their respective sides of the medication panels. The
  bounded DTO separates specialties, excludes resolved, refuted, and
  entered-in-error states from the landing view, merges the same bilateral
  disorder, and retains priority, active fade, uncertainty or differential,
  comments, laterality, dates, and the configured ophthalmic event link. The
  non-legacy mixed-state panel is removed.
- Bounded-read contract: the current-state projection reads at most 501 narrow
  source rows, presents 500, and raises an explicit safety message when the
  source set exceeds that bound. One and 510 added diagnosis rows both use
  three queries. A declarative `patients.show` query-plan budget verifies the
  indexed patient, disorder, and eye ordering without a filesort, temporary
  table, scan, or optimizer hint.
- Remaining parity: exact change-history dialogs, rich bilateral and comment
  tooltips, nil-confirmation evidence, mandatory diagnosis statuses,
  configurable expanding panels, exact fuzzy-date typography, and the missing
  Eye Procedures and Systemic Procedures panels remain open. The 500-row
  safety boundary also needs a clinically usable continuation before complete
  high-volume diagnosis-summary parity is claimed.
- Verification: a new seven-schema MariaDB 11.8 stack passed all 298 migrations,
  tiny seed, schema verification, and ten query-plan budgets. The ordered
  patient-summary regression pack passed 29 tests with 381 assertions after a
  new timeline-test rollback guard removed cross-file fixture leakage. The
  ledger pack passed 2 tests with 22 assertions. Scoped Pint, the production
  frontend build, and a production FrankenPHP image passed. A real browser
  found Cataract only in Eye Diagnoses, Diabetes mellitus only in Systemic
  Diagnoses, preserved panel order and event-link policy, made one medication
  GET, and produced no mutation, failed request, runtime error, or console
  error.
- `next_item`: inspect the existing patient-summary eye and systemic procedure
  serving paths and implement the smallest bounded familiar panel only where
  authoritative current-state rules already exist.
- `after_next`: otherwise advance to the next ordinary vision or refraction
  patient-summary gap without guessing a clinical rule.
- Coverage and repository state: exact behavioral coverage is 50.0915 percent
  across 14,125 canonical paths and 18,424 mappings, with zero missing and zero
  pending review. Five directly reviewed diagnosis-summary files gained
  conservative evidence. Changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=diagnosis-specialty-placement-green;
  bilateral-current-state-merge; three-query-constant;
  indexed-no-sort-temp-scan-hint; clean-298-migrations;
  browser-panel-order-and-link-policy-green;
  timeline-test-isolation-fixed; ledger-14125-18424-50.0915;
  patient-procedure-panel-review-next`.

### 16.48 Patient-summary procedure panels - 2026-09-01 12:34 BST

- Current problem and acceptance condition: the familiar Eye Procedures and
  Systemic Procedures panels were absent. The replacement must preserve their
  clinical sources, order, laterality, fuzzy dates, explicit empty states and
  source links without reviving unbounded neighbouring-table reads.
- Completed eye-procedure contract: the latest recorded ophthalmic surgery
  state contributes performed entries only. It is merged with at most 100
  newest Operation Note events and 100 newest Laser events plus one look-ahead
  per external source. Operation Note procedure names are combined per event;
  Laser entries group by procedure code and resolve bilateral laterality. The
  final eye list is ordered newest first and capped at 500 rows with an explicit
  continuation warning rather than silent truncation. Injections remain absent,
  matching the current legacy landing-page behavior.
- Completed systemic-procedure contract: the latest recorded systemic surgery
  state contributes performed entries only, ordered newest first. Both panels
  distinguish `Nil recorded` from the clinician-recorded no-previous-procedure
  state and occupy the established six-panel order around diagnoses and
  medications. Locally recorded history has no fabricated source event link;
  Operation Note and Laser summaries link to their authoritative events.
- Query and performance evidence: one versus 100 local ophthalmic and systemic
  entries uses the same eight clinical queries when all four sources are
  present. Four declarative `patients.show` budgets prove the latest local,
  Operation Note and Laser source reads use serving indexes without filesort,
  a temporary table, a scan, or an optimizer hint. The complete tiny registry
  now passes 14 budgets.
- Verification: scoped Pint passed. The ordered patient-summary, image-policy,
  query-plan and ledger pack passed 36 tests with 450 assertions. The focused
  procedure and query-plan pack passed 8 tests with 82 assertions, including a
  101-event look-ahead proof. The production frontend and web image built, and
  a production FrankenPHP browser found all six panels in order, accepted both
  procedure empty states, made one medication GET, and produced no mutation,
  failed response, runtime error, or console error.
- Remaining parity: exact popup interactions and a clinically usable path to
  inspect rows beyond the safety boundary remain open. Representative migrated
  history is still required before tuning the bounds. These gaps do not change
  the bounded source or panel architecture.
- `next_item`: inspect the existing indexed cross-source refraction reader and
  the legacy patient-summary REF presentation, then add only the smallest
  familiar bounded presentation supported by authoritative rules.
- `after_next`: continue the next ordinary vision or refraction workflow gap
  with the migration confidence pack, without starting broad patient-summary
  redesign or realistic-load tuning early.
- Coverage and repository state: exact behavioral coverage is 50.0966 percent
  across 14,125 canonical paths and 18,433 mappings, with zero missing and zero
  pending review. Nine directly reviewed legacy paths gained secondary
  procedure-summary evidence. Changes remain staged or ready to stage only,
  with no commit or push.
  `verification_state=patient-procedure-panels-green;
  legacy-six-panel-order; external-100-plus-one; eye-row-cap-500-explicit;
  eight-query-constant; indexed-no-sort-temp-scan-hint;
  production-browser-green; ledger-14125-18433-50.0966;
  patient-refraction-summary-review-next`.

### 16.49 Patient-summary refraction row - 2026-09-01 12:50 BST

- Current problem and acceptance condition: the patient page still displayed a
  hard-coded `REF Unknown / N/A` even though bounded refraction readers existed.
  The replacement must match the familiar right, left, unknown and date row,
  preserve authoritative source precedence, and remain fixed-query on large
  histories.
- Completed behavior: `PatientRefraction` now supplies the patient overview
  from Correction Given, Refraction and Retinoscopy. The newest event date wins;
  same-event precedence remains Correction Given, Refraction, then Retinoscopy.
  Deterministic row ties use event and row identity. Refraction readings retain
  the legacy priority string, including spherical equivalent and type. The Vue
  row renders right and left values, per-eye `NA`, whole-row `Unknown`, and the
  NHS event date in the established location.
- Query and performance evidence: all three source readers use bounded narrow
  projections. One versus 100 historical rows in every source remains at four
  clinical queries. Three new `patients.show` plan budgets pass against the
  existing latest-source indexes, taking the tiny registry to 17. Retinoscopy
  ordering now includes its indexed event tie-break, removing the initially
  detected filesort without an optimizer hint, new index, or schema change.
- Verification: scoped Pint passed. The focused refraction and query-plan pack
  passed 17 tests with 233 assertions. After the one browser-only row was
  removed from the disposable database, the ordered patient-summary,
  refraction, image-policy, query-plan and ledger pack passed 50 tests with 640
  assertions. The production frontend and web image built. A production
  FrankenPHP browser displayed the expected three REF list items and NHS date,
  retained all six panels, made one medication GET, and produced no mutation,
  failed request, runtime error, or console error.
- Remaining parity: patient-summary and worklist popup consumers have not been
  claimed. Their shared source contract is now available, but each needs its own
  presentation gate. This slice makes no event-image policy change: progressive
  loading remains off by default and its initial group size remains undecided
  until clinical and realistic-load evidence exists.
- `next_item`: inspect the current patient-summary visual-acuity row against
  `getMostRecentVADataStandardised` and close only source or presentation gaps
  supported by the pinned legacy contract.
- `after_next`: continue the next ordinary vision and refraction gap with one
  representative parity path, authorization, bounded-query proof, serving-plan
  evidence, and a production browser smoke.
- Coverage and repository state: exact behavioral coverage remains 50.0966
  percent across 14,125 canonical paths and 18,435 mappings, with zero missing
  and zero pending review. The two new secondary rows record already-covered
  canonical sources and therefore do not inflate coverage. Changes remain
  staged or ready to stage only, with no commit or push.
  `verification_state=patient-refraction-row-green;
  legacy-three-source-precedence; four-query-constant;
  indexed-no-sort-temp-scan-hint; focused-17-233;
  integrated-50-640; production-build-and-browser-green;
  ledger-14125-18435-50.0966; patient-va-review-next`.

### 16.50 Patient-summary visual-acuity row - 2026-09-01 13:10 BST

- Current problem and acceptance condition: the patient page selected the
  newest VA reading independently for each eye, so it could combine different
  examination dates. It also omitted BEO and method abbreviations and displayed
  logMAR text that is not present in the established patient-summary row. The
  replacement must preserve `getMostRecentVADataStandardised`, use one latest
  element, remain bounded on large histories, and retain the familiar layout.
- Completed behavior: `PatientVisualAcuity` selects one latest live element,
  then chooses the greatest base value for BEO, right and left within that same
  element, with the later reading winning an equal-value tie. The patient row
  presents optional BEO, right and left `Unknown` fallbacks, exact `ua`, `ph`
  and `rx` method abbreviations, and the NHS event date. The HTTP boundary and
  database both enforce at most six readings per side, making the 18-row source
  bound authoritative for imports as well as normal entry.
- Query and performance evidence: one versus 100 historical elements stays at
  two narrow clinical queries. Two new `patients.show` plan budgets use the
  existing element-time and element-eye-sequence indexes with no filesort,
  temporary table, scan, or optimizer hint. The tiny registry now has 19
  budgets.
- Verification: scoped Pint and PHP syntax passed. The focused visual-acuity,
  event-delete and query-plan pack passed 23 tests with 359 assertions. The
  ordered patient-summary, vision, image-policy, query-plan and ledger pack
  passed 70 tests with 951 assertions. A second empty seven-schema build passed
  all 298 migrations, tiny seed, schema verification and the post-build focused
  gate at 25 tests with 382 assertions. A production frontend and web image
  built. One production FrankenPHP browser displayed `BEO 6/6 ua`, `R 6/9 ua`
  and `L 6/12 ua` from one event, retained the refraction row and all six
  panels, made one medication GET, and produced no mutation, failed response,
  runtime error, or console error. The two exact browser-only rows were removed
  and the original simple VA state was restored.
- Event-image clarification: progressive image loading remains a separate
  optional feature and remains off by default. Its initial group is not fixed
  at 10 or any other number; clinical usability and realistic-load evidence
  select a sensible bound before implementation. The default-on emergency
  generation gate remains separate.
- Evidence correction: the pinned Near Visual Acuity model returns false from
  `canCopy()`, and its user guide says that no copy option is provided. The
  misleadingly named fixture supports editing a Near VA scale in an existing
  event. Near VA copy-forward is therefore not a gap and must not be invented.
- `next_item`: inspect per-institution and per-subspecialty visual-acuity
  default-scale administration, then implement only the smallest stable
  configuration seam supported by the pinned source.
- `after_next`: inspect the distance and Near VA default record-mode settings,
  then continue the next ordinary vision or refraction gap without guessing a
  clinical rule.
- Coverage and repository state: exact behavioral coverage remains 50.0966
  percent across 14,125 canonical paths and 18,437 mappings, with zero missing
  and zero pending review. The two new secondary rows add exact evidence for
  canonical paths already at 100 percent and therefore do not inflate
  coverage. Changes remain staged or ready to stage only, with no commit or
  push.
  `verification_state=patient-va-row-green;
  one-latest-element; beo-right-left-exact; two-query-constant;
  database-six-per-side-bound; indexed-no-sort-temp-scan-hint;
  focused-23-359; fresh-schema-298-and-25-382; integrated-70-951;
  production-build-and-browser-green; ledger-14125-18437-50.0966;
  scale-default-settings-next`.

### 16.51 Visual-acuity scale defaults and plan correction - 2026-09-01 13:40 BST

- Classification: the scale-setting contract and its query shape are
  architecture-now work because every distance and Near VA editor consumes
  them. A subspecialty override is a seam-now, implementation-later item until
  the event has authoritative firm ownership under DIV-009.
- Evidence correction: pinned source and documentation prove that Near VA has
  history but deliberately no copy-forward. `VisualAcuityCopyingSeeder` creates
  a Near VA record and alternate scales for an edit-scale test. The active
  queue and ledger no longer treat Near copy-forward as missing behavior.
- Completed behavior: the exact legacy setting keys now hold stable scale
  codes. Distance and Near editors resolve installation defaults and
  institution overrides from the immutable event institution and site
  snapshots. A missing, inactive, or otherwise unavailable configured scale
  falls back to the established Snellen Metre or Reduced Snellen code and then
  the first active compatible scale. Existing retired scale snapshots remain
  readable.
- Query and schema evidence: one versus 100 additional scale configurations
  has fixed query growth within explicit 16-query configuration budgets. The
  normal scale pickers now use `(active, display_order)` serving indexes and a
  deterministic `id` tie-break. Related scale values are ordered only after
  their bounded eager load. Exact MariaDB plans use the scale-picker and unique
  setting-key indexes without filesort, a temporary table, a scan, an index
  hint, or forced optimizer behavior.
- Verification: scoped Pint and PHP syntax passed. The distance, Near and
  settings pack passed 51 tests with 2,972 assertions. An empty seven-schema
  MariaDB 11.8 stack passed all 298 migrations, tiny seed and schema
  verification, followed by the same 51-test pack. A production frontend and
  web image built, and a production FrankenPHP browser displayed ETDRS Letters
  for distance and Jaeger (Approx) for Near from institution settings with one
  successful lazy configuration request and no mutation, failed request,
  runtime error, or console error.
- Event-image clarification: the optional progressive feature remains off by
  default. No initial image count is prescribed. Its future bound is selected
  from clinical usability and realistic-load evidence. The separate default-on
  emergency gate continues to serve compatible existing images while blocking
  only new generation.
- `next_item`: inspect and implement the evidence-backed default record-mode
  setting seam for distance and Near VA without broadening firm ownership.
- `after_next`: continue the next caller-evidenced ordinary vision, refraction,
  or patient-summary gap with a migration confidence pack.
- Blocker and deferral: subspecialty scale selection remains deferred until
  event-to-firm ownership is authoritative. This narrow deferral does not block
  installation and institution defaults.
- Coverage and repository state: exact behavioral coverage is 50.0981 percent
  across 14,125 canonical paths and 18,437 mappings, with zero missing and zero
  pending review. Changes remain staged or ready to stage only, with no commit
  or push.
  `verification_state=va-scale-defaults-green;
  near-copy-nonfeature-corrected; event-context-setting-resolution;
  fixed-query-growth-100-extra-scales; indexed-no-sort-temp-scan-hint;
  focused-and-clean-51-2972; fresh-schema-298; production-browser-green;
  progressive-images-default-off-size-evidence-led;
  ledger-14125-18437-50.0981; va-record-mode-settings-next`.

### 16.52 Visual-acuity record-mode defaults - 2026-09-01 13:55 BST

- Classification: default record mode is architecture-now configuration
  because it changes the initial clinical form shape. The legacy subspecialty
  overrides remain a seam-now, implementation-later item until DIV-009 gives
  the event authoritative firm and subspecialty ownership.
- Completed behavior: distance and Near VA have separate stable setting keys
  because the rewrite setting key is globally unique. Installation defaults
  and institution overrides select `simple` or `complex` from immutable event
  context. Missing or invalid values fall back to `simple`. A new complex
  element starts right, left and BEO active. The previous Near VA first-firm
  guess based on the logged-in user's institution has been removed.
- Legacy fidelity: the setting labels preserve Standard VA without BEO and
  Extended VA with BEO. The established default remains simple, so introducing
  this seam does not silently change existing installations. The Strabismus
  and Paediatrics complex defaults are recorded but not guessed.
- Verification: scoped Pint passed. The distance, Near, settings and ledger
  pack passed 44 tests with 579 assertions after loading the two definitions
  into a clean schema. Existing one-versus-100 configuration fixtures remain
  within their fixed 16-query budgets. A fresh production frontend and web
  image built. A production FrankenPHP browser opened both new elements with
  institution-selected complex mode, active BEO forms, three Near eye columns,
  no distance simple-only scale selector, one successful lazy configuration
  response, and no mutation, failed request, runtime error, or console error.
- Event-image clarification: progressive loading remains off by default. Its
  initial group is not 10 or any other prescribed number; a later clinical and
  realistic-load gate chooses the sensible bounded policy.
- `next_item`: inspect the remaining ordinary vision and refraction ledger
  gaps against pinned callers and choose the smallest clinically useful slice
  that does not require invented firm ownership.
- `after_next`: continue the next patient-summary parity gap or ordinary
  vision/refraction consumer with fixed query growth and one browser smoke.
- Coverage and repository state: exact behavioral coverage is 50.0983 percent
  across 14,125 canonical paths and 18,437 mappings, with zero missing and zero
  pending review. Changes remain staged or ready to stage only, with no commit
  or push.
  `verification_state=va-record-mode-defaults-green;
  distinct-stable-setting-keys; event-context-not-user-first-firm;
  simple-fallback; complex-beo-active; fixed-query-budget;
  focused-44-579; production-build-and-browser-green;
  subspecialty-defaults-deferred-div009;
  progressive-images-default-off-size-evidence-led;
  ledger-14125-18437-50.0983; next-gap-evidence-review`.

### 16.53 Visual-acuity equivalent-value tooltips - 2026-09-01 14:05 BST

- Classification: equivalent-value display is ordinary presentation parity.
  It uses the bounded scale configuration already loaded for each VA form and
  introduces no storage, route, authorization, or query-shape change.
- Completed behavior: saved and editable distance and Near VA readings now
  expose the closest active value from every other active compatible scale.
  The existing scale order gives deterministic tie resolution. This covers
  simple and complex distance readings, BEO and individual eyes, and simple
  and complex Near VA readings.
- Safety and accessibility: scale names and values are escaped before entering
  rich tooltip markup. The same content is also present as a plain `title`, so
  the information does not depend on the legacy tooltip initializer.
- Verification: a production frontend and web image built successfully. A
  production FrankenPHP browser proved saved distance, editable distance and
  newly added Near VA tooltip values, with one successful lazy configuration
  response and no mutation, failed request, runtime error, or console error.
  The immediately preceding 44-test, 579-assertion VA pack remains the backend
  proof for configuration, equivalence, settings and fixed query budgets.
- Fidelity boundary: the clinical equivalent values are present. Exact legacy
  hover geometry and visual styling remain part of the later fidelity gate.
- Event-image clarification: progressive loading remains off by default. Its
  eventual bound and interaction are selected from clinical usability and
  realistic-load evidence, not a fixed image count.
- `next_item`: inspect the pinned Near VA history caller and the rewrite's
  bounded history API to decide whether a familiar lazy history presentation
  can be closed without inventing chart or unit-conversion behavior.
- `after_next`: if that presentation is not safely bounded, record the narrow
  deferral and take the next caller-evidenced vision, refraction, or patient-
  summary gap.
- Coverage and repository state: exact behavioral coverage is 50.0989 percent
  across 14,125 canonical paths and 18,437 mappings, with zero missing and zero
  pending review. Changes remain staged or ready to stage only, with no commit
  or push.
  `verification_state=va-equivalent-tooltips-green;
  bounded-loaded-scales-only; deterministic-closest-active-values;
  escaped-rich-and-plain-title; no-new-query-or-schema;
  production-build-and-browser-green; prior-va-44-579-green;
  progressive-images-default-off-size-evidence-led;
  ledger-14125-18437-50.0989; near-va-history-evidence-review-next`.

### 16.54 Distance visual-acuity history data seam and ledger correction - 2026-09-01 14:20 BST

- Evidence correction: the pinned
  `OphCiExamination_Episode_VisualAcuityHistory` widget is a distance VA
  history consumer. It is not evidence for a Near VA chart. The canonical and
  secondary ledger rows have been corrected from Near VA to distance VA or the
  separate OEscape event-image side panel. No Near VA history behavior has
  been invented.
- Completed seam: a named, unversioned and patient-bound history endpoint now
  returns newest-first best BEO, right and left distance readings, including
  base value, stable scale identity and method identity. The default page is
  20 rows, the maximum is 50, and the versioned cursor includes the patient and
  complete ordering tuple so it cannot be replayed across patients.
- Performance: one versus 101 history elements remains at two clinical
  queries. The element page uses `ix_va_element_patient_time`; the bounded
  child read uses
  `et_ophci_va_reading_element_id_eye_id_seq_unique`. Direct MariaDB plans use
  those exact keys with no filesort, temporary table, scan, forced index or
  optimizer hint.
- Routing and authorization: the operation is
  `api.patients.visual-acuity.history`, owned by
  `F-EXAMINATION-VISION-REFRACTION`, requires an authenticated current-
  institution context, appears in the application-surface manifest, and does
  not add a query to manifest generation. Invalid or cross-patient cursors are
  rejected with 422.
- Verification: scoped Pint passed. The history, manifest and ledger pack
  passed 17 tests with 2,518 assertions. A production web image built, its
  route resolved to the expected controller, and a production browser proved
  one authenticated history row with no mutation, failed request, runtime
  error or console error.
- Fidelity boundary: the familiar patient-summary chart has not changed. The
  chart, unit selector, VFI and MD combination, operation markers, OEscape
  image panel, interactions and exact geometry remain later presentation and
  fidelity gates.
- Event-image clarification: progressive loading remains off by default. Its
  eventual policy and interaction will be selected from clinical usability
  and realistic-load evidence, not a fixed image count.
- `next_item`: inspect the remaining low-coverage vision and refraction ledger
  paths against pinned callers and choose the smallest non-fidelity behavior
  with an authoritative clinical rule.
- `after_next`: continue another bounded ordinary vision, refraction or
  patient-summary slice without chasing coverage percentage.
- Coverage and repository state: exact behavioral coverage is 50.1000 percent
  across 14,125 canonical paths and 18,437 mappings, with zero missing and zero
  pending review. Changes remain staged or ready to stage only, with no commit
  or push.
  `verification_state=distance-va-history-data-seam-green;
  near-va-misclassification-corrected; patient-bound-keyset-20-default-50-max;
  fixed-two-query-growth; exact-serving-indexes; no-filesort-temp-scan-or-hint;
  manifest-and-auth-green; focused-17-2518; production-build-and-browser-green;
  familiar-chart-deferred; progressive-images-default-off-size-evidence-led;
  ledger-14125-18437-50.1000; next-gap-evidence-review`.

### 16.55 Automatic personal-mailbox lifecycle - 2026-09-01 14:40 BST

- Classification: the user-save listener is ordinary shared-core messaging
  parity. Recursive team mailbox grants remain a separate high-risk
  authorization boundary and are not implied by this slice.
- Completed behavior: saving an active user now creates the missing personal
  mailbox and direct assignment. Repeated saves return the same mailbox, an
  inactive user waits until activation, and the creation-time display name is
  retained as in the pinned behavior.
- Identity and concurrency: the portable mailbox code is derived
  deterministically from the unique username. A transaction locks the user
  row before lookup and creation, and the existing mailbox and assignment
  unique constraints close concurrent duplicate attempts. An existing code
  assigned to any other user is rejected even when that assignment is
  inactive, so a retired mailbox can never disclose an old thread to a new
  owner.
- Performance: the active personal-mailbox lookup stays at one query for one
  and 101 mailboxes. The initial schema now carries
  `ix_mailbox_personal_active`; the optimizer-selected bounded plan has no
  filesort, temporary table, scan, forced index or optimizer hint.
- Narrow deferrals: AIS webhook publication still waits for the canonical PAS
  AIS resource because publishing the legacy absolute link today would point
  at a route that does not exist. Team hierarchy expansion remains blocked on
  deployed-data validation and clinical safety approval under DIV-060.
- Verification: scoped Pint passed. A clean seven-schema MariaDB 11.8
  migration and tiny seed passed. The lifecycle, messaging, configuration and
  affected file-storage pack passed 27 tests with 340 assertions before the
  final owner-reuse invariant was added; the final lifecycle rerun passed four
  tests with 16 assertions.
- Event-image clarification: progressive loading remains off by default. Its
  eventual policy and interaction remain evidence-led and have no prescribed
  image count.
- `next_item`: inspect the pinned CVI status and patient-summary callers for a
  bounded non-fidelity behavior, otherwise take the next attachment or shared-
  core behavior with an authoritative contract.
- `after_next`: continue the ordinary shared-core census while preserving the
  AIS resource and team-access deferrals.
- Coverage and repository state: exact behavioral coverage is 50.1024 percent
  across 14,125 canonical paths and 18,437 mappings, with zero missing and zero
  pending review. Changes remain staged or ready to stage only, with no commit
  or push.
  `verification_state=personal-mailbox-lifecycle-green;
  active-user-save-idempotent; user-row-lock; retired-owner-reuse-rejected;
  fixed-one-query-growth; optimizer-selected-serving-index;
  no-filesort-temp-scan-or-hint; clean-seven-schema-and-tiny-seed;
  regression-27-340; final-lifecycle-4-16; team-access-deferred-div060;
  ais-webhook-resource-deferred; progressive-images-default-off-size-evidence-led;
  ledger-14125-18437-50.1024; cvi-caller-review-next`.

### 16.56 Direct patient CVI fallback and cross-source precedence - 2026-09-01 15:20 BST

- Completed behavior: the legacy patient-level CVI picker is now available on
  the familiar patient summary with its exact five choices and fuzzy date. A
  direct patient record is used only when no live Examination or formal CVI
  source exists. Event sources always win; the later event date wins between
  them, with formal CVI winning an equal-date tie.
- Safety and lifecycle: the direct row is versioned, audited and protected by
  optimistic concurrency. Saving or deleting an event source rebuilds the
  single current projection and restores the direct patient fallback when the
  last event source disappears. The editor is permission-gated and the read is
  institution-bound.
- Bounded patient page: the initial patient page reads only the one-row current
  projection. The direct configuration and combined source history load only
  when requested. The direct fallback read remains one indexed query as
  unrelated volume grows; its central query-plan budget has no filesort,
  temporary table, scan, forced index or optimizer hint.
- Routing and inventory: the named unversioned manual GET and PUT operations
  are in the application-surface manifest, while the existing history endpoint
  now includes direct and event sources. CVI divergence, API, page, feature and
  FileLedger records describe the implemented seam without claiming worklist,
  popup, search, reporting, ODT or delivery parity.
- Verification: a clean MariaDB 11.8 build passed all 298 migrations, tiny
  seed, schema verification and all 20 central query-plan budgets. The final
  combined manifest, ledger and CVI confidence pack passed 32 tests with 2,768
  assertions; scoped Pint and the production frontend and image passed. A
  production browser proved zero eager detail requests, lazy history, edit and
  fuzzy-date round-trip, current projection refresh, full reload persistence,
  seed restoration and no failed response or console error.
- Event-image clarification: progressive loading remains off by default. Its
  eventual policy and initial group remain evidence-led rather than fixed.
- `next_item`: reconcile the remaining pinned attachment and event-storage
  callers, and take only the smallest authoritative incomplete behavior.
- `after_next`: continue the ordinary shared-core census or the next bounded
  patient-summary behavior while preserving the AIS resource deferral.
- Coverage and repository state: exact behavioral coverage is 50.1196 percent
  across 14,125 canonical paths and 18,437 mappings, with zero missing and zero
  pending review. Changes remain staged or ready to stage only, with no commit
  or push.
  `verification_state=direct-cvi-fallback-green;
  exact-five-choice-picker; fuzzy-date-and-optimistic-version;
  event-sources-always-win; formal-equal-date-tie;
  direct-restored-after-event-delete; lazy-detail-zero-initial-requests;
  fixed-one-query-direct-read; central-20-plan-budgets-green;
  no-filesort-temp-scan-or-hint; clean-298-migrations-tiny-seed-schema;
  final-pack-32-2768; production-build-image-and-browser-green;
  progressive-images-default-off-size-evidence-led;
  ledger-14125-18437-50.1196; attachment-caller-reconciliation-next`.

### 16.57 Direct event attachment-type eligibility - 2026-09-01 15:50 BST

- Completed behavior: attachment types now have the pinned legacy
  `is_event_attachments_enabled` control, independently of event-type policy.
  The declarative admin screen, portable configuration family, event picker,
  canonical attachment API, compatibility route and linked-device picker use
  the same active-and-enabled rule. Older portable exports without the new
  field import safely with direct event use off.
- Security and bounds: disabled types are rejected again at every reachable
  write boundary, not only hidden in selectors. Selectors use bounded
  projections and stable ordering. The schema packet contains the eligibility,
  active, display order and name index before bulk import; MariaDB selects it
  without filesort, a temporary table, scan, forced index or optimizer hint.
- Verification: a clean MariaDB 11.8 build passed all 298 migrations, tiny seed
  and schema verification. The final focused attachment and plan pack passed 25
  tests with 321 assertions; the preceding integrated pack passed 33 tests with
  379 assertions and the security and ledger pack passed 13 tests with 330
  assertions. All 21 central query-plan budgets pass. The production frontend,
  web image and image contract pass. A production browser disabled Clinical
  Photograph in the real admin screen, proved its absence from the event and
  linked-device pickers while other types remained, restored it, and recorded
  no failed response or console error.
- Narrow deferrals: historical blob extraction and import belong to the later
  migrated-data rehearsal. Protected-file malware scanning remains a much later
  security gate. Exact attachment presentation geometry remains a fidelity
  gate. Progressive event-image loading remains off by default and its first
  group is still an evidence-led decision, not a fixed count.
- `next_item`: inspect remaining pinned shared-medication callers and automatic
  medication-set consumers for the smallest authoritative incomplete behavior.
- `after_next`: continue ordinary vision, refraction or shared-core census only
  after the medication caller review, without reopening closed attachment
  behavior merely for coverage.
- Coverage and repository state: exact behavioral coverage remains 50.1196
  percent across 14,125 canonical paths and 18,437 mappings, with zero missing
  and zero pending review. Changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=direct-attachment-type-eligibility-green;
  admin-portable-config-and-old-export-default-off; all-write-paths-enforced;
  bounded-picker-index; no-filesort-temp-scan-or-hint;
  clean-298-migrations-tiny-seed-schema; focused-25-321;
  integrated-33-379; security-ledger-13-330; central-21-plans;
  production-build-image-contract-browser-green; browser-seed-restored;
  progressive-images-default-off-size-evidence-led;
  ledger-14125-18437-50.1196; shared-medication-caller-review-next`.

### 16.58 Automatic medication-set caller review - 2026-09-01 16:05 BST

- Completed evidence review: the existing automatic Medication Set path already
  covers the safe pinned subset. It atomically materializes explicit medication
  rules and recursively included manual or automatic sets, rejects cycles and
  missing active sources before replacement, supports one-set and all-set
  idempotent rebuilds, and is consumed by the current Prescription and Operation
  Note generation paths. One versus twenty source sets remains within the same
  eight-query rebuild budget.
- Narrow deferrals: attribute selectors require the authoritative medication
  attribute import. Parent and child expansion requires the authoritative dm+d
  hierarchy import. Neither clinical meaning is guessed. Selected-firm context
  is a wider DIV-009 architecture item used by many element families and must
  not be hidden behind a medication-specific first-active-firm guess.
- Scope decision: no working prescription, taper, signing, printing, reporting,
  pharmacy or medication-management path is reopened merely to increase
  coverage. Progressive event-image loading remains off by default; its initial
  group remains an evidence-led clinical and realistic-load decision rather
  than a fixed count.
- `next_item`: implement the exact bounded previous-visit Visual Acuity loss
  warning from the pinned calculator without inventing the separate
  post-injection history projection.
- `after_next`: continue the smallest authoritative ordinary vision, refraction
  or shared-core behavior after the warning confidence pack is safe.
- Coverage and repository state: no production code or coverage changed in this
  review. Exact behavioral coverage remains 50.1196 percent across 14,125
  canonical paths and 18,437 mappings, with zero missing and zero pending
  review. Changes remain staged or ready to stage only, with no commit or push.
  `verification_state=automatic-set-safe-subset-already-green;
  explicit-and-nested-composition; atomic-idempotent-rebuild;
  fixed-eight-query-source-growth; current-consumers-verified;
  medication-attribute-import-deferred; dmd-hierarchy-import-deferred;
  shared-firm-context-div-009; no-coverage-change;
  progressive-images-default-off-size-evidence-led;
  ledger-14125-18437-50.1196; previous-va-loss-warning-next`.

### 16.59 Previous-visit Visual Acuity loss warning - 2026-09-01 16:22 BST

- Completed behavior: saved and in-progress Visual Acuity elements now show the
  pinned warning when the best corrected reading has lost at least five ETDRS
  letters from the newest earlier Visual Acuity element. The calculation keeps
  the exact corrected method set, conversion, threshold, NHS date and wording,
  including deterministic ordering for two events at the same clinical time.
- Performance and bounds: the previous element is one backwards indexed range
  read and its maximum six readings per side are eager-loaded in one bounded
  query. Query count is unchanged between one and 100 historical elements. Two
  central EXPLAIN budgets cover the element and reading reads; all 23 budgets
  pass without filesort, a temporary table, a scan, a forced index or an
  optimizer hint.
- Verification: scoped Pint passed. A clean MariaDB 11.8 database had already
  passed all 298 migrations, tiny seed and schema verification. The final
  focused pack passed 25 tests with 352 assertions, ledger integrity passed two
  tests with 22 assertions, and the production web image and image contract
  passed. A production browser displayed exact right and left warning text,
  reached the global ready state and recorded no failed request, runtime error
  or console error.
- Narrow deferrals: the post-injection warning and OEscape hover/header
  consumers need a normalized patient, eye and clinical-time projection before
  they can be bounded safely. They are not approximated with an unbounded
  cross-table history scan. Progressive event-image loading remains off by
  default and its initial group remains an evidence-led clinical and
  realistic-load decision rather than a fixed count.
- `next_item`: implement the pinned Retinoscopy copy-forward behavior with
  explicit provenance and retained working-distance snapshots.
- `after_next`: reconcile the remaining pinned Visual Acuity and Near Visual
  Acuity browser behaviors against the existing implementation, then continue
  the smallest authoritative ordinary vision, refraction or shared-core gap.
- Coverage and repository state: exact behavioral coverage is 50.1228 percent
  across 14,125 canonical paths and 18,437 mappings, with zero missing and zero
  pending review. Changes remain staged or ready to stage only, with no commit
  or push.
  `verification_state=previous-visit-va-warning-green;
  exact-five-letter-threshold-methods-conversion-wording-and-date;
  same-time-event-tiebreak; one-vs-100-fixed-query-growth;
  central-23-plans-no-filesort-temp-scan-or-hint; focused-25-352;
  ledger-2-22; production-build-image-contract-browser-green;
  ledger-14125-18437-50.1228; retinoscopy-copy-forward-next`.

### 16.60 Retinoscopy copy-forward evidence closure - 2026-09-01 16:31 BST

- Completed evidence review: the target already had the complete pinned
  Retinoscopy copy-forward behavior. Its date-safe previous-event selector
  copies both eyes, working distances, angles, powers, dilation and comments;
  persistence records the source event and retains the source distance
  snapshots even when configuration later changes. Future sources are rejected.
  No duplicate production implementation was added.
- Performance and bounds: an explicit confidence gate now proves the
  configuration query count does not grow from one to 21 prior Retinoscopy
  events and remains within a four-query budget. The existing patient-history
  index assertion proves the optimizer-selected covering index without a forced
  index or optimizer hint.
- Verification: scoped Pint passed. The Retinoscopy API, element and ledger pack
  passed 16 tests with 236 assertions. A production-image browser copied the
  exact bilateral values and comments, saved the element with provenance,
  reached the global ready state and recorded no unexpected failed response,
  runtime error or console error. The expected missing-draft 404 was classified
  separately from workflow errors. Disposable fixture rows were removed.
- Accounting correction: the canonical pinned Cypress specification is now
  reviewed and mapped at 100 percent to the existing implementation and test
  evidence. Exact behavioral coverage is 50.1298 percent across 14,125
  canonical paths and 18,437 mappings, with zero missing and zero pending
  review.
- `next_item`: reconcile the pinned Visual Acuity and Near Visual Acuity Cypress
  behaviors against the existing target and implement only an authoritative
  functional gap.
- `after_next`: continue the smallest bounded ordinary vision, refraction or
  shared-core behavior without starting print or visual-fidelity work.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=retinoscopy-existing-behavior-closed;
  bilateral-copy-and-provenance-browser-green; one-vs-21-fixed-query-growth;
  focused-16-236; optimizer-selected-index-no-hint;
  ledger-14125-18437-50.1298; va-near-cypress-reconciliation-next`.

### 16.61 Visual Acuity edit-scale parity and Driving Advice boundary - 2026-09-01 16:48 BST

- Completed behavior: an explicit confidence test now proves that two saved
  1/60 Snellen readings can change to ETDRS while editing without losing either
  reading or selecting the inactive same-base N/A row. The nearest active
  ETDRS value is retained. A separate test proves that a saved simple Near VA
  reading changes to Jaeger (Approx), including its persisted configuration
  snapshot.
- Browser evidence: a production-image no-retry flow created a disposable
  Examination, changed both distance and Near VA scales, saved them together
  through the real `Confirm & Save` event batch, rendered both saved results,
  reopened edit mode and retained both selections and all readings. The global
  page state was `ready` and there were no browser errors. The disposable event
  was deleted through the normal application workflow.
- Authoritative boundary: the pinned distance VA Cypress file also exercises
  automatic Driving Advice opening from unsaved same-page VA and Social
  History state. The target has bounded persisted-state suggestions, but no
  reviewed cross-element draft-state contract. This clinically sensitive gap
  remains explicit under DIV-316 rather than being improvised inside one Vue
  component. The distance Cypress row is therefore partial at 35 percent; the
  complete Near VA Cypress row is mapped at 100 percent.
- Verification: scoped Pint passed. The two edit-scale tests passed with 20
  assertions and the ledger pack passed two tests with 22 assertions. Exact
  behavioral coverage is 50.1394 percent across 14,125 canonical paths and
  18,437 mappings, with zero missing and zero pending review.
- `next_item`: reconcile the pinned Correction Given Cypress behavior against
  the existing bounded refraction implementation and add only authoritative
  missing behavior.
- `after_next`: continue the smallest ordinary vision, refraction or shared-core
  Cypress contract without starting fidelity work.
- Blocker and deferral: unsaved Driving Advice automation waits for a reviewed
  event-draft coordination contract and dedicated clinical acceptance under
  DIV-316. Progressive event-image loading remains off by default and its
  initial group remains evidence-led rather than fixed.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=va-near-edit-scale-green; focused-2-20;
  event-batch-browser-green; saved-edit-reopen-green; page-ready-no-errors;
  driving-advice-unsaved-deferred-div316; ledger-2-22;
  ledger-14125-18437-50.1394; correction-given-cypress-next`.

### 16.62 Correction Given one-eye browser contract - 2026-09-01 16:56 BST

- Pinned contract: the complete legacy Cypress file contains one workflow. A
  user removes the left eye, chooses an adjusted right-eye order with free-text
  refraction, saves the Examination and continues to see the left eye as Not
  recorded.
- Completed evidence: the existing Laravel editor already implements the
  behavior. A first-save characterization now proves the stored eye enum,
  adjusted order, trimmed right-eye value, cleared left-eye fields and saved
  presentation. No duplicate production path was added.
- Browser evidence: a production-image no-retry flow created a disposable
  Examination, added Correction Given through Manage Elements, removed the left
  side, selected Adjusted and Input Refraction, entered the right-eye value and
  saved through the real event batch. Saved presentation showed Order as
  Adjusted and Not recorded; edit reopen retained Add left side. The global
  page state was `ready`, no browser errors were recorded and the event was
  deleted through the normal application route.
- Verification: scoped Pint passed. The focused test passed with 31 assertions
  and the final ledger pack passed two tests with 22 assertions. Exact
  behavioral coverage is 50.1465 percent across 14,125 canonical paths and
  18,437 mappings, with zero missing and zero pending review.
- `next_item`: reconcile the pinned Cover Test Cypress behavior against the
  target and implement only a bounded authoritative gap.
- `after_next`: continue the smallest ordinary Examination or shared-core
  contract without starting visual-fidelity or speculative cross-element work.
- Blocker and deferral: exact Correction Given geometry and deferred dependent
  surfaces remain under DIV-323. Progressive event-image loading remains off
  by default and no fixed initial image count is selected.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=correction-given-existing-behavior-closed;
  one-eye-first-save-1-31; production-browser-green; saved-not-recorded-green;
  edit-reopen-green; page-ready-no-errors; ledger-2-22;
  ledger-14125-18437-50.1465; cover-test-cypress-next`.

### 16.63 Cover Test row editing and browser-test direction - 2026-09-01 17:12 BST

- Completed behavior: the existing Cover Test row dialog now exposes the
  already persisted per-reading comment and places the legacy horizontal and
  vertical bounds on the numeric controls. Add, edit and removal still use the
  bounded aggregate and preserve every configured selection.
- Browser evidence: a no-retry Playwright flow on the final production image
  created a disposable Examination, added Cover Test through Manage Elements,
  selected all seven row fields, reopened the row, updated its note, saved the
  real event batch and reopened edit mode. Every value and the changed note
  were retained, the global page state was `ready`, and no browser errors were
  recorded. The event was deleted through the normal application route.
- Performance and verification: the one-versus-100-entry test now rejects only
  upward query growth instead of treating fewer warmed queries as a failure.
  The final Cover Test pack passed 11 tests with 187 assertions, the JavaScript
  pack passed 24 tests, the ledger pack passed two tests with 22 assertions,
  the production frontend build and image contract passed, and exact coverage
  is 50.1477 percent across 14,125 canonical paths and 18,437 mappings.
- Browser-test rule: create no Cypress tests during the port. Cypress is legacy
  evidence only and its remaining specifications are not an active work queue.
  Browser confidence packs use Playwright. After the rest of the codebase is
  ported, reconcile any still-relevant Cypress behavior and express retained
  browser coverage in Playwright before final parity closure. The canonical
  Cover Test Cypress row therefore remains pending at zero coverage.
- `next_item`: select the next bounded ordinary Examination behavior from
  pinned models, views, callers and OeDocumentation rather than from Cypress.
- `after_next`: continue source-driven shared-core behavior, then return to the
  ordered webhook or outbox queue only where an unclosed legacy caller exists.
- Blocker and deferral: exact Cover Test markup and visual geometry remain a
  fidelity gate. Remaining Cypress reconciliation is deferred until the end of
  functional porting and cannot inflate current progress.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=cover-test-note-editor-green; cover-test-11-187;
  javascript-24-green; production-playwright-green; page-ready-no-errors;
  production-build-and-image-contract-green; ledger-2-22;
  ledger-14125-18437-50.1477; cypress-deferred-playwright-current`.

### 16.64 Medication History legacy confirmation parity - 2026-09-01 17:23 BST

- Completed behavior: an empty Medication History review now requires the
  legacy eye-medication confirmation only. The systemic confirmation remains
  optional, while either confirmation is still rejected when a current
  medication of that kind is present. This matches the pinned model and current
  OeDocumentation instead of inventing a stronger clinical rule.
- Focused evidence: the full Medication History element file passes eight tests
  with 124 assertions. Its shared event helper now supplies immutable
  institution and site snapshots required by the current schema, so six older
  scenarios once again exercise their intended behavior instead of failing in
  setup. Scoped Pint passes.
- Browser and runtime evidence: a no-retry Playwright flow on the final
  production image created an Examination, selected `No eye medications`, left
  `No systemic medications` clear, saved the whole event and verified the exact
  saved presentation. The global page state was `ready`, no browser errors were
  recorded, the event was deleted through the normal application route, and a
  database check found zero surviving disposable events from this slice. The
  production image contract passes.
- Accounting: the canonical pinned HistoryMedications model row alone records
  the corrected validation and browser evidence at 92 percent. Broader risk,
  Prescription-source, presentation and import work remains open. The ledger
  pack passes two tests with 22 assertions and reports 50.1478 percent across
  14,125 canonical paths and 18,437 mappings, with zero missing and zero pending
  review.
- `next_item`: inspect the next bounded ordinary Examination behavior from
  pinned models, views, callers and OeDocumentation, prioritising an
  authoritative rule that does not require a cross-element clinical guess.
- `after_next`: continue source-driven shared-core behavior, then return to the
  ordered webhook or outbox queue only where an unclosed legacy caller exists.
- Blocker and deferral: allergy-specific warnings, risk-drug automation and
  Prescription-origin composition remain separate clinically sensitive gates.
  No Cypress test or Cypress-led reconciliation is added during porting.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=history-medications-8-124; legacy-eye-confirmation-green;
  systemic-optional-green; production-playwright-green; page-ready-no-errors;
  disposable-events-zero; production-image-contract-green; ledger-2-22;
  ledger-14125-18437-50.1478`.

### 16.65 Application-owned legacy system-event callers - 2026-09-01 17:39 BST

- Completed behavior: user saves, successful web logins, and individual or
  batch clinical element saves now emit the corresponding typed legacy system
  event through the existing durable outbox. Each caller supplies only bounded
  scalar identifiers and explicitly names the configuration or clinical
  connection whose commit owns the signal. Rollback therefore emits nothing,
  while ordinary no-transaction login dispatch remains immediate.
- Integrity boundary: personal mailbox creation stays synchronous and
  idempotent in the user-save lifecycle before the `UserSaved` signal. The
  rewrite does not move this required invariant into an eventual listener.
  Available immutable institution context is propagated without inventing a
  value for imported rows where the snapshot is null.
- Failure boundary: an after-commit outbox or listener failure is caught after
  the source transaction is durable and emits only a bounded operational error.
  Sensitive exception text and occurrence identifiers are not logged, and the
  committed source action is not presented to the caller as rolled back.
- Verification: scoped Pint passes. The system-event module, durable outbox,
  login, personal-mailbox and event-batch pack passes 60 tests with 470
  assertions. The production web image builds and its repository-owned image
  contract passes at 227,838,933 bytes. This slice changes no rendered page, so
  it does not add a browser flow.
- Accounting: both user event envelopes and the canonical clinical-save event
  are now fully adapted. The ledger pack passes two tests with 22 assertions
  and reports 50.1575 percent across 14,125 canonical paths and 18,437 rows,
  with zero missing and zero pending review.
- `next_item`: select the next bounded ordinary behavior from pinned models,
  views, callers and OeDocumentation, favoring a self-contained contract over
  a broad component rewrite.
- `after_next`: continue source-driven shared-core breadth, then return to
  another legacy event caller only when its owning workflow and volume are
  authoritative.
- Blockers and deferrals: `SessionSiteChanged` waits for one stable institution,
  site and firm context-switch contract. The old login-wide stale-draft warning
  is not guessed on top of the rewrite's per-event restore points. Request and
  transaction event callers are not added merely to inflate event volume. No
  Cypress work is created during porting.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=application-system-event-callers-green;
  system-event-pack-60-470; bounded-post-commit-failure-green;
  production-image-contract-green; ledger-2-22;
  ledger-14125-18437-50.1575; next-source-contract-review`.

### 16.66 Pain latest-Examination correspondence and search - 2026-09-01 18:00 BST

- Completed behavior: the stable patient-bound `aps` operation returns every
  ordered Pain score and local time from the latest Examination using the exact
  legacy HTML fragment. If that latest Examination contains no Pain, it returns
  empty instead of incorrectly falling back to an older Pain element. A newer
  non-Examination event does not change the selection.
- Shared consumer: the existing typed Pain declaration supplies its stable code,
  label and element target through the common event search index with no
  database query. No parallel search registry is added.
- Performance and storage: the selection reads the maintained patient event
  timeline through a new `(patient_id, event_type_id, event_date, event_id)`
  index, then reads Pain by its unique event key. It stays at four queries from
  one to 151 Examination events. The plan uses the new index with no filesort,
  temporary table, group-wise maximum, forced index, or optimizer hint. The
  migration was applied through a manager-role container.
- Verification: scoped Pint passes. The Pain, application-surface, migration
  policy and ledger pack passes 19 tests with 2,469 assertions. The production
  image builds and its repository-owned contract passes at 227,843,241 bytes.
  This is an API and shared index slice with no changed rendered workflow, so it
  does not add a browser flow.
- Verification boundary: the existing Pain page test reaches a pre-existing
  500 in this reused database because its configuration schema lacks the
  already-staged `attachment_type.is_event_attachments_enabled` column. The new
  Pain tests are green and the failure is not attributed to this slice.
- Accounting: five Pain source mappings are now fully adapted. The ledger pack
  passes and reports 50.1722 percent across 14,125 canonical paths and 18,437
  rows, with zero missing and zero pending review. Pain feature coverage is
  87.0 percent.
- `next_item`: select the next bounded ordinary Examination or shared-core
  behavior from pinned models, views, callers and OeDocumentation.
- `after_next`: continue source-driven functional breadth, returning to shared
  correspondence only through an authoritative caller.
- Blockers and deferrals: Pain historical and clinical import and export,
  public generation, formal OpenAPI publication, help, author attribution and
  exact visual fidelity remain later gates. No Cypress work is created during
  porting.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=pain-aps-exact-green; latest-examination-no-fallback;
  event-search-zero-query; query-count-4-fixed; timeline-type-index-green;
  no-filesort-no-temporary-no-hint; manager-migration-green;
  focused-pack-19-2469; production-image-contract-green;
  ledger-14125-18437-50.1722`.

### 16.67 Triage latest-Examination correspondence - 2026-09-01 18:10 BST

- Completed behavior: the named patient-bound operation returns `cce`, `cco`,
  `ccc`, and `pri` from the immutable eye, chief-complaint, comment, and
  priority snapshots on the latest Examination. If that Examination contains
  no Triage element, all four values are empty and an older Triage element is
  not substituted. A newer non-Examination event does not change selection.
- Reuse boundary: Pain and Triage now share one small
  `PatientLatestExamination` selector. Element-specific presentation remains in
  the owning service, avoiding a generic correspondence abstraction.
- Performance: the Triage path stays at three queries from one to 151
  Examination events. The existing covering patient-timeline index serves the
  candidate read with no filesort, temporary table, group-wise maximum, forced
  index, or optimizer hint.
- Verification: scoped Pint passes. Triage, Pain, and application-surface tests
  pass 20 tests with 2,471 assertions. The ledger and migration-policy pack
  passes three tests with 23 assertions. The production image builds and its
  repository-owned contract passes at 227,847,631 bytes. This API-only slice
  changes no rendered page and therefore adds no browser flow.
- Accounting: four canonical or secondary correspondence sources are fully
  adapted and the mixed API source advances only for its trait composition.
  The ledger reports 50.1849 percent across 14,125 canonical paths and 18,437
  rows, with zero missing and zero pending review. Triage feature coverage is
  68.8 percent.
- `next_item`: inspect the pinned latest-Examination Safeguarding
  correspondence contract and add it only if its rule is authoritative.
- `after_next`: continue the smallest source-driven Examination or shared-core
  behavior without opening worklist, report, PAS, or visual-fidelity scope.
- Blockers and deferrals: diagnosis mismatch, cross-institution site search,
  latest-priority worklist behavior, the A&E report, PAS ECDS output,
  interchange, public generation, formal OpenAPI publication, help, and exact
  visual fidelity remain later Triage gates. No Cypress work is created or used
  as the implementation queue during porting.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=triage-shortcodes-exact-green;
  latest-examination-no-fallback; shared-latest-selector-green;
  query-count-3-fixed; timeline-type-index-green;
  no-filesort-no-temporary-no-hint; focused-pack-20-2471;
  ledger-pack-3-23; production-image-contract-green;
  ledger-14125-18437-50.1849`.

### 16.68 Safeguarding latest-Examination correspondence - 2026-09-01 18:21 BST

- Completed behavior: the named patient-bound `asc` operation returns ordered
  immutable concern terms from the latest Examination using the exact legacy
  HTML fragment. When the latest Examination has no Safeguarding element, it
  returns `No safeguarding issues identified` and does not fall back to an
  older concern. A newer non-Examination event does not change selection.
- Performance: the operation reuses `PatientLatestExamination`, reads the
  element and its bounded entries eagerly, and stays at four queries from one
  to 151 Examination events. The covering timeline index is selected with no
  filesort, temporary table, forced index, or optimizer hint.
- Verification: scoped Pint passes. Safeguarding, Triage, Pain, and
  application-surface tests pass 24 tests with 2,492 assertions. The ledger and
  migration-policy pack passes three tests with 23 assertions. The production
  image builds and its repository-owned contract passes at 227,851,271 bytes.
  This API-only slice changes no rendered page and adds no browser flow.
- Accounting: the incorrectly Pain-tagged canonical legacy test is assigned to
  Safeguarding, and one explicit secondary module-API mapping raises the ledger
  to 18,438 rows without changing the 14,125 canonical path set. Exact coverage
  is 50.1913 percent, with zero missing and zero pending review. The corrected
  General Health and Safety feature set has 396 unique paths, 16 fully covered
  paths, 11 deferred paths, and 84.0 percent unweighted coverage.
- `next_item`: inspect the next bounded shared correspondence or ordinary
  Examination contract from pinned source and existing consumers.
- `after_next`: continue source-driven breadth without opening Safeguarding
  RBAC, remaining projections, visual fidelity, or Cypress work.
- Blockers and deferrals: the global Safeguarding ability mapping remains under
  DIV-098 and DIV-244. Other module projections and exact geometry stay
  deferred. The existing-element and zero-entry edge is not reinterpreted
  beyond the pinned legacy contract without a reviewed clinical rule.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=safeguarding-asc-exact-green;
  latest-examination-no-fallback; saved-concern-snapshots-green;
  query-count-4-fixed; timeline-type-index-green;
  no-filesort-no-temporary-no-hint; focused-pack-24-2492;
  ledger-pack-3-23; production-image-contract-green;
  ledger-14125-18438-50.1913`.

### 16.69 Observations correspondence projection - 2026-09-01 18:37 BST

- Completed behavior: the named patient-bound Observations correspondence
  operation returns the exact versioned `lbp`, `lst`, `lbg`, `lhb`, `lht`,
  `lwt`, `lpu`, and `bmi` values from the latest live Observations aggregate.
  BMI independently selects that aggregate's newest valid height and weight.
  A newer empty aggregate returns empty values and never exposes an older
  aggregate. The separate clinical latest-value endpoint retains its existing
  cross-event, zero-safe, same-row BMI semantics.
- Performance: the bounded read uses two queries from one to 151 historical
  elements. The latest-element query selects
  `ix_observations_patient_history`; the at-most-100 entry read selects
  `uq_observation_entry_live_seq` and finishes its tiny sort in PHP. Neither
  plan uses a filesort, temporary table, forced index, or optimizer hint.
- Verification: scoped Pint passes. On a fresh MariaDB 11.8 database, all 299
  migrations, the tiny seed, and seven-schema verification pass. The combined
  Observations and application-surface pack passes 24 tests with 2,567
  assertions, and the ledger and migration-policy pack passes three tests with
  23 assertions. The production image builds and its repository-owned contract
  passes at 227,856,623 bytes. This is an API-only slice, so it adds no browser
  smoke and creates no Cypress test.
- Accounting: exact legacy API helpers, three historical shortcode migrations,
  and their source test are represented without adding inventory-only credit.
  The ledger remains exactly 14,125 canonical paths and 18,438 rows, with zero
  missing and zero pending review. Exact coverage is 50.2062 percent. The
  corrected Observations feature set has 33 unique paths, 31 fully covered
  paths, zero status-deferred paths, and 96.4 percent unweighted coverage.
- `next_item`: inspect the two remaining partial Observations event-search
  migrations and implement only an exact source-backed typed contract.
- `after_next`: continue the smallest source-driven Examination or shared-core
  behavior without opening macro-catalog, template, visual-fidelity, or Cypress
  work.
- Blockers and deferrals: the wider macro catalog and template integration
  remain under DIV-306. The reused test database lacks a previously migrated
  `attachment_type` column; the fresh seven-schema proof establishes that the
  changed slice is clean. Cypress remains legacy evidence only and is not used
  as the active implementation queue.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=observation-correspondence-eight-codes-green;
  latest-aggregate-no-fallback; independent-bmi-sources-green;
  query-count-2-fixed; no-filesort-no-temporary-no-hint;
  fresh-299-migrations-tiny-seed-schema-green; focused-pack-24-2567;
  ledger-pack-3-23; production-image-contract-green;
  ledger-14125-18438-50.2062`.

### 16.70 Observations generated event search - 2026-09-01 18:51 BST

- Completed behavior: `ObservationsElementType` now owns all ten exact pinned
  search labels and aliases, including `Obs`, `BP`, the three Oxygen
  Saturation aliases, and `Body Mass Index`. The later Temperature correction
  resolves to a stable `temperature` target. Selecting a result activates the
  element, scrolls to an existing field anchor, and focuses its live input.
- Performance: the shared event index remains a bounded source-controlled
  projection. Once the event type is loaded, generation issues zero database
  queries and needs no mutable search table, cache, recursive query, or
  optimizer hint.
- Verification: scoped Pint passes and the containerized JavaScript suite
  passes 24 tests. A fresh MariaDB 11.8 database passes all 299 migrations and
  the tiny seed. Event Search, Observations recording, and correspondence pass
  19 tests with 178 assertions; the ledger and migration-policy pack passes
  three tests with 23 assertions. The production image and its contract pass at
  227,859,147 bytes. A no-retry production Playwright smoke proved all ten
  generated terms, the Oxygen Saturation alias, corrected Temperature target,
  and live focus for both fields with no browser errors. No Cypress test was
  created or consulted as the active queue.
- Accounting: the two remaining partial search-migration mappings are now
  source-backed and fully covered. The Observations feature has 33 exact paths,
  all 33 fully covered, zero status-deferred paths, and 100.0 percent
  unweighted coverage. The global ledger remains exactly 14,125 canonical paths
  and 18,438 rows, with zero missing and zero pending review. Exact coverage is
  50.2104 percent.
- `next_item`: inspect the familiar patient-summary IOP row against pinned
  source and existing bounded readers before choosing any implementation.
- `after_next`: continue the smallest source-driven Examination or shared-core
  behavior without opening visual-fidelity, macro-catalog, template, or Cypress
  scope.
- Blockers and deferrals: historical descriptions, icons, split-eye search,
  fuzzy suggestions, and pixel fidelity remain shared later gates under
  DIV-307 and DIV-372. The reviewed clinical documentation does not describe
  event-search behavior. The reused database retains unrelated
  `attachment_type` migration drift; the clean database proves the changed
  event page and API contract.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=observations-search-ten-terms-green;
  oxygen-alias-green; temperature-target-green; live-field-focus-green;
  generated-index-zero-query; fresh-299-migrations-tiny-seed-green;
  focused-pack-19-178; javascript-24-green; ledger-pack-3-23;
  production-playwright-no-browser-errors;
  production-image-contract-227859147; ledger-14125-18438-50.2104`.

### 16.71 Familiar patient-summary Allergies panel - 2026-09-01 19:20 BST

- Completed behavior: the patient overview keeps a dedicated Allergies section
  in the familiar general-health order. It preserves present, none-known, and
  not-checked alerts plus immutable allergy labels, severity, reactions,
  comments, and category icons. The panel issues one focused request only when
  it approaches the viewport. It does not add an unproven edit link or an IOP
  row that the pinned Patient Summary documentation does not describe.
- Performance and security: the route is named, manifest-owned, institution
  scoped, patient-bound, audited without patient data, and backed by
  `patient_allergy_current`. The clinical service stays at five queries from
  one to one hundred entries. Its plan selects
  `uq_patient_allergy_current_scope` with no filesort, temporary table, forced
  index, or optimizer hint. Caching is `none`.
- Verification: the three-test allergy pack passes 50 assertions. The
  neighboring allergy, flag, general-health, manifest, and login pack passes 33
  tests with 2,724 assertions except one transient combined-order login
  failure; the failed case then passes alone and the full Login file passes all
  seven tests with 71 assertions. Scoped Pint and all 24 containerized
  JavaScript tests pass. The Playwright workflow creates an Examination allergy,
  proves one lazy request and familiar presentation with no browser errors,
  then deletes the event and verifies a 404. The production image and its
  repository contract pass at 227,873,593 bytes.
- Accounting: the patient view, source widget, source test, route, projection,
  and data-governance records now carry direct evidence. The General Health and
  Safety feature has 397 exact paths, 17 fully covered paths, 11
  status-deferred paths, and 84.1 percent unweighted coverage. The global ledger
  remains exactly 14,125 canonical paths and 18,438 rows, with zero missing and
  zero pending review. Exact coverage is 50.2188 percent.
- `next_item`: inspect the pinned patient-summary Risks sources and the existing
  current projection before choosing a bounded panel.
- `after_next`: continue source-driven patient-summary breadth without opening
  compact-view redesign, exact pixel fidelity, migrated-scale tuning, or
  Cypress reconciliation.
- Blockers and deferrals: exact pixel geometry, imported-data reconciliation,
  the six-section general-health batch, and full clinical safety sign-off remain
  under DIV-469. The disposable browser server needed Laravel `--no-reload` to
  preserve container-injected `APP_KEY`; its reused database also needed the
  already-migrated attachment eligibility column restored. Both were confined
  to the disposable fixture and are recorded for Docker follow-up. Cypress
  remains legacy evidence only.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=patient-summary-allergy-three-states-green;
  foreign-source-and-deletion-green; query-count-5-fixed;
  no-filesort-no-temporary-no-hint; focused-pack-3-50;
  neighboring-pack-33-2724-with-isolated-login-recheck;
  login-pack-7-71; javascript-24-green; playwright-one-lazy-request-green;
  production-image-contract-227873593; ledger-14125-18438-50.2188`.

### 16.72 Familiar patient-summary Risks panel - 2026-09-01 19:42 BST

- Completed behavior: the patient overview keeps its dedicated Risks section
  after Allergies. It preserves the familiar Alerts tri-state, presents level
  one risks first, retains immutable risk names, Other text, and comments, and
  appends current diabetes diagnosis terms. Diabetes alone makes the alert
  present. The panel issues one focused request only when it approaches the
  viewport, and it does not add an unproven edit link.
- Performance and security: the named manifest route is institution scoped,
  patient bound, and privacy-bounded in telemetry. The read uses the maintained
  `patient_history_risks_current` pointer and stays at six queries from one to
  one hundred risks. Its pointer and diagnosis plans have no filesort,
  temporary table, forced index, or optimizer hint. Diagnosis output is capped
  at one hundred rows with an explicit overflow warning. Caching is `none`.
- Verification: the final five-test Risks pack passes 75 assertions, including
  the one-hundred-row overflow boundary. The wider Risks, Allergies, flag,
  element, and general-health pack passes 21 tests with 286 assertions. Scoped
  Pint and all 24 containerized JavaScript tests pass. The final Playwright
  workflow creates a level-one risk with a comment, proves one lazy request and
  the familiar warning with no browser errors, deletes the event, and verifies
  a 404. The production image and repository contract pass at 227,888,715
  bytes.
- Accounting: the patient view, source widget, source patient-summary section,
  route, current pointer, and governance records carry direct evidence. General
  Health and Safety has 398 exact paths, 17 fully covered paths, 11
  status-deferred paths, 33,504 highest-per-path points, and 84.2 percent
  unweighted coverage. The global ledger remains exactly 14,125 canonical paths
  and 18,438 rows, with zero missing and zero pending review. Exact coverage is
  50.2261 percent.
- `next_item`: inspect the pinned Family History patient-summary source, current
  projection, callers, and OeDocumentation before selecting any behavior.
- `after_next`: inspect the next familiar patient-summary section only where
  presentation and clinical rules are authoritative.
- Blockers and deferrals: exact pixel geometry, imported-data reconciliation,
  medication-derived risk automation, remaining popup, correspondence, and
  whiteboard consumers, and full clinical safety sign-off remain later gates.
  Cypress remains legacy evidence only and is not an implementation queue.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=patient-summary-risks-three-states-green;
  level-one-order-and-diabetes-green; query-count-6-fixed;
  no-filesort-no-temporary-no-hint; final-risks-pack-5-75;
  neighboring-pack-21-286; javascript-24-green;
  playwright-one-lazy-request-green; production-image-contract-227888715;
  ledger-14125-18438-50.2261`.

### 16.73 Familiar patient-summary Family History panel - 2026-09-01 19:58 BST

- Completed behavior: the patient overview keeps its dedicated Family History
  section after Risks. It preserves the familiar unknown and no-history text
  and the recorded Relative, Side, Condition, and Comments table using
  immutable saved labels and Other values. The panel issues one focused
  request only when it approaches the viewport and does not add an unproven
  patient-summary edit route.
- Performance and security: the named manifest route is institution scoped,
  patient bound, and privacy-bounded in telemetry. The read uses the maintained
  `patient_family_history_current` pointer and stays at three service queries
  from one to one hundred and one entries. The pointer and entry ordering plans
  have no filesort, temporary table, forced index, or optimizer hint. Output is
  capped at one hundred rows with an explicit overflow warning. Caching is
  `none`.
- Verification: a fresh MariaDB 11.8 database passes all 300 migrations,
  schema verification, the tiny seed, and the focused four-test 68-assertion
  pack. The final neighboring Family History pack passes 14 tests with 195
  assertions; the ledger, manifest, and migration-policy pack passes 14 tests
  with 2,444 assertions; scoped Pint and all 24 containerized JavaScript tests
  pass. The final Playwright workflow creates Family History through the real
  Examination API, proves one lazy request and the familiar four-column table
  with no browser errors, deletes the event, and verifies a 404. The production
  image and repository contract pass at 227,907,079 bytes.
- Accounting: Family History source, patient-summary section, route, pointer,
  and governance records carry direct evidence. General Health and Safety has
  399 exact paths, 17 fully covered paths, 11 status-deferred paths, 33,608
  highest-per-path points, and 84.2 percent unweighted coverage. The global
  ledger remains exactly 14,125 canonical paths and 18,438 rows, with zero
  missing and zero pending review. Exact coverage is 50.2335 percent.
- `next_item`: inspect the next familiar patient-summary section from pinned
  source and OeDocumentation without inventing clinical behavior.
- `after_next`: continue source-driven patient-summary breadth only where
  presentation and clinical rules are authoritative.
- Blockers and deferrals: cross-event copy-forward, the combined Family Social
  tile, direct patient-summary editing, exact pixel geometry, and clinical
  sign-off remain later gates. Cypress remains legacy evidence only and is not
  an implementation queue.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=patient-summary-family-history-three-states-green;
  query-count-3-fixed; no-filesort-no-temporary-no-hint;
  fresh-migrations-300-schema-tiny-green; focused-pack-4-68;
  neighboring-pack-14-195; ledger-manifest-migration-14-2444;
  javascript-24-green; playwright-one-lazy-request-green;
  production-image-contract-227907079; ledger-14125-18438-50.2335`.

### 16.74 Familiar patient-summary Social History panel - 2026-09-01 20:20 BST

- Completed behavior: the patient overview keeps its dedicated Social History
  section after Family History. It preserves `Nil recorded` and the familiar
  Employment, Driving Status, Smoking Status, Accommodation, Comments, Carer,
  Alcohol Intake, and Substance Misuse row order. Immutable saved labels,
  line-separated driving statuses, the type-of-job precedence rule, and a zero
  alcohol value are retained. The panel issues one focused request only when it
  approaches the viewport and does not add an unproven edit route.
- Performance and security: the named manifest route is institution scoped,
  patient bound, and privacy-bounded in telemetry. The read uses the maintained
  `patient_social_history_current` pointer and stays at three service queries
  from one to six driving statuses. The pointer and status plans have no
  filesort, temporary table, forced index, or optimizer hint. The schema bounds
  one saved element to six driving statuses. Caching is `none`.
- Verification: a fresh MariaDB 11.8 database passes all 301 migrations,
  schema verification, the tiny seed, and the focused four-test 63-assertion
  pack. The final neighboring pack passes 17 tests with 242 assertions; scoped
  Pint, the 14-test 2,444-assertion ledger, manifest, and migration-policy pack,
  and all 24 containerized JavaScript tests pass. The final Playwright
  workflow creates Social History through the real Examination API, proves one
  lazy request and the familiar eight-row table with no browser errors, deletes
  the event, and verifies cleanup. The production build and the 227,925,809-byte
  image contract pass.
- Accounting: Social History source, patient-summary section, route, pointer,
  and governance records carry direct evidence. General Health and Safety has
  399 exact paths, 17 fully covered paths, 11 status-deferred paths, 33,804
  highest-per-path points, and 84.7 percent unweighted coverage. The global
  ledger remains exactly 14,125 canonical paths and 18,438 rows, with zero
  missing and zero pending review. Exact coverage is 50.2474 percent.
- `next_item`: inspect the next pinned patient-summary section and choose only
  an authoritative bounded behavior.
- `after_next`: continue source-driven patient-summary breadth without opening
  combined popup, exact visual fidelity, or Cypress scope.
- Blockers and deferrals: the six-section General Health worklist still uses
  its existing bounded aggregate. Historical bulk import, combined Family
  Social popup behavior, exact pixel geometry, and clinical sign-off remain
  later gates. Cypress remains legacy evidence only and is not an
  implementation queue.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=patient-summary-social-history-green;
  exact-eight-row-order-and-zero-alcohol-green; query-count-3-fixed;
  no-filesort-no-temporary-no-hint;
  fresh-migrations-301-schema-tiny-green; focused-pack-4-63;
  neighboring-pack-17-242; ledger-manifest-migration-14-2444;
  javascript-24-green;
  playwright-one-lazy-request-green;
  production-image-contract-227925809; ledger-14125-18438-50.2474`.

### 16.75 Familiar patient-summary AIS panel - 2026-09-01 20:36 BST

- Completed behavior: the patient overview places its AIS section before
  Management Summaries, matching the pinned landing order. It preserves the
  familiar grey or orange header, `Nil recorded`, saved entry order, grey or
  orange entry icons, immutable labels, and the saved language suffix. The
  panel issues one focused request only when it approaches the viewport.
- Performance and security: the named manifest route is institution scoped,
  patient bound, and privacy-bounded in telemetry. It reads the existing
  maintained `patient_accessibility_current` pointer and stays at three service
  queries from one to one hundred and one stored entries. Output is capped at
  one hundred entries with an explicit overflow warning. The pointer and entry
  plans have no filesort, temporary table, forced index, or optimizer hint.
  Caching is `none`.
- Verification: the focused pack passes 3 tests with 51 assertions; the
  neighboring Accessibility aggregate, patient flag, Family History, and
  Social History pack passes 22 tests with 355 assertions. Scoped Pint, the
  14-test 2,444-assertion ledger, manifest, and migration-policy pack, and all
  24 containerized JavaScript tests pass. A clean dependency production build
  passes. The final Playwright workflow creates Accessibility and
  Communication through the real Examination API, proves section order,
  warning semantics, immutable labels, the saved language suffix, one lazy
  request, no browser errors, and cleanup. The production image contract is
  227,938,356 bytes.
- Accounting: the exact Accessibility entry, widget, landing view, route, and
  tests carry direct evidence. Orthoptics and clinical decisions retains its
  fixed 283-path denominator, with 10,178 highest-per-path points and 36.0
  percent unweighted coverage. The global ledger remains exactly 14,125
  canonical paths and 18,438 rows, with zero missing and zero pending review.
  Exact coverage is 50.2493 percent.
- `next_item`: inspect the next familiar patient-summary section from pinned
  source and OeDocumentation and choose only an authoritative bounded behavior.
- `after_next`: continue source-driven patient-summary breadth without opening
  compact AIS popup, PAS synchronization, exact visual fidelity, or Cypress
  scope.
- Blockers and deferrals: compact AIS popups, PAS import and export,
  accessibility-specific events, remaining header, list, correspondence, and
  whiteboard consumers, imported-data reconciliation, exact pixel geometry,
  and clinical sign-off remain later gates. Cypress remains legacy evidence
  only and is not an implementation queue.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=patient-summary-ais-familiar-panel-green;
  exact-warning-order-label-language-green; query-count-3-fixed;
  output-cap-100-explicit-overflow; no-filesort-no-temporary-no-hint;
  focused-pack-3-51; neighboring-pack-22-355;
  ledger-manifest-migration-14-2444; javascript-24-green;
  clean-dependency-production-build-green;
  playwright-one-lazy-request-green;
  production-image-contract-227938356; ledger-14125-18438-50.2493`.

### 16.76 Familiar patient-summary Appointments panel - 2026-09-01 21:05 BST

- Completed behavior: the patient overview replaces its static appointment
  placeholder with the familiar current Appointments table. Future and current
  appointments remain date-ascending and show time, worklist, clinic date, and
  the saved Status attribute. Matching live Did Not Attend evidence supplies
  the familiar fallback status. `Past Appointments (n)` remains separate and
  loads bounded date-descending rows only after its accessible toggle opens.
- Performance and security: both named manifest routes are institution scoped,
  patient bound, privacy-bounded in telemetry, and read only. The current
  summary stays at three service queries and each past keyset page at two,
  independent of fixture size. The initial ordered-ID phase uses the maintained
  current projection and the second phase batches at most one hundred detail
  rows without loading whole worklists. Current output is capped at one hundred
  with an explicit overflow warning; past pages default to fifty and cap at one
  hundred. All serving plans have no filesort, temporary table, forced index,
  or optimizer hint. Caching is `none`.
- Verification: the focused pack passes 4 tests with 70 assertions and the
  neighboring appointment foundation, worklist read, PAS adapter, and
  Accessibility pack passes 40 tests with 664 assertions. The final appointment,
  ledger, manifest, and migration-policy pack passes 18 tests with 2,514
  assertions. Scoped Pint and all 24 containerized JavaScript tests pass. A
  fresh seven-schema run passes every migration, schema verification, and the
  tiny seed. A clean production build passes. The final Playwright workflow
  proves one lazy summary request, no premature history request, one history
  request after expansion, familiar current and past rows, section order, no
  browser errors, and exact fixture cleanup. The production image contract is
  227,966,731 bytes.
- Accounting: the exact legacy widget, view, row partial, and past-load caller
  carry direct evidence. Worklist has 3,390 highest-per-path points over 53
  assigned source paths and 64.0 percent unweighted coverage. The global ledger
  remains exactly 14,125 canonical paths and 18,439 rows, with zero missing and
  zero pending review. Exact coverage is 50.2699 percent.
- `next_item`: inspect pinned Problems and Plans patient-summary source, the
  current target, and OeDocumentation before choosing a bounded behavior.
- `after_next`: inspect Injection Management or the next authoritative
  patient-summary section without opening visual-fidelity or Cypress scope.
- Blockers and deferrals: the separate appointment popup branch, imported-data
  reconciliation, exact pixel geometry, realistic migrated-data load tuning,
  and clinical sign-off remain later gates. Cypress remains legacy evidence
  only and is not an implementation queue.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=patient-summary-appointments-familiar-panel-green;
  current-and-past-parity-green; dna-stable-identity-green;
  summary-query-count-3-fixed; history-query-count-2-fixed;
  current-cap-100-explicit-overflow; past-keyset-50-default-100-max;
  no-filesort-no-temporary-no-hint; focused-pack-4-70;
  neighboring-pack-40-664; ledger-manifest-migration-appointment-18-2514;
  javascript-24-green; fresh-seven-schema-migrations-seed-green;
  clean-production-build-green; playwright-lazy-history-green;
  production-image-contract-227966731; ledger-14125-18439-50.2699`.

### 16.77 Familiar read-only patient-summary Problems and Plans panel - 2026-09-01 21:24 BST

- Completed behavior: the patient overview now replaces its static Problems and
  Plans placeholder with the familiar ordered current list and created
  metadata. The exact `Past/closed problems (n)` count remains separate and
  loads bounded closed rows only after its accessible toggle opens. The main
  landing-page caller remains read only, so this slice does not invent popup
  add, close, or reorder behavior.
- Performance and security: both named manifest routes are institution scoped,
  patient bound, privacy-bounded in telemetry, and read only. The current
  summary stays at three service queries and each past keyset page at two,
  independent of fixture size. Current output is capped at one hundred with an
  explicit overflow warning; past pages default to fifty and cap at one
  hundred. All serving plans use the declared patient, state, deletion, order,
  and identity index with no filesort, temporary table, forced index, or
  optimizer hint. Caching is `none`.
- Verification: the focused pack passes 4 tests with 70 assertions and the
  neighboring Problems and Plans, Appointments, Accessibility, Family History,
  and Social History pack passes 19 tests with 322 assertions. The final
  Problems and Plans, ledger, manifest, and migration-policy pack passes 18
  tests with 2,514 assertions. Scoped Pint and all 24 containerized JavaScript
  tests pass. A fresh seven-schema run passes every migration, schema
  verification, and the tiny seed. A clean production build passes. The final
  Playwright workflow proves one lazy summary request, no premature history
  request, one history request after expansion, familiar current and past rows,
  no editable control, no browser errors, and exact fixture cleanup. The final
  production image contract is 227,994,073 bytes.
- Accounting: the exact legacy model, widget, view, and landing-page caller
  carry direct evidence. Patient Summary has 225 highest-per-path points over
  its exact 4-path denominator and 56.3 percent unweighted coverage. The global
  ledger remains exactly 14,125 canonical paths and 18,440 rows, with zero
  missing and zero pending review. Exact coverage is 50.2858 percent.
- `next_item`: inspect pinned Injection Management patient-summary source, the
  current target, callers, and OeDocumentation before choosing a bounded
  behavior.
- `after_next`: continue the next source-driven patient-summary or ordinary
  shared-core gap without opening popup mutation, visual-fidelity, or Cypress
  scope.
- Blockers and deferrals: editable Problems and Plans popup creation, closure,
  reordering, authorization, and concurrency behavior remain a separate
  surface. Imported-data reconciliation, exact pixel geometry, realistic
  migrated-data load tuning, and clinical sign-off remain later gates. Cypress
  remains legacy evidence only and is not an implementation queue.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=patient-summary-problems-plans-read-only-green;
  current-and-past-parity-green; summary-query-count-3-fixed;
  history-query-count-2-fixed; current-cap-100-explicit-overflow;
  past-keyset-50-default-100-max; no-filesort-no-temporary-no-hint;
  focused-pack-4-70; neighboring-pack-19-322;
  ledger-manifest-migration-problems-plans-18-2514;
  javascript-24-green; fresh-seven-schema-migrations-seed-green;
  clean-production-build-green; playwright-lazy-history-read-only-green;
  production-image-contract-227994073; ledger-14125-18440-50.2858`.

### 16.78 Familiar read-only patient-summary Injection Management panel - 2026-09-01 21:56 BST

- Completed behavior: the patient overview now conditionally shows the familiar
  read-only Injection Management panel after Problems and Plans. Right eye is
  always presented before left eye. Each side distinguishes no current plan,
  no-treatment with its saved reason, and an active treatment plan with the
  diagnosis, drug, regime, bounded planned sequence, interval, start option,
  IOP-lowering instruction, and follow-up details. A patient with no historical
  Injection Management element sees no empty panel.
- Performance and security: the named manifest route is authenticated,
  institution scoped, patient bound, privacy-bounded in telemetry, and read
  only. The browser issues one request only as the panel approaches the
  viewport. The summary stays at three clinical queries from one to one hundred
  plan items. The active-series read uses the patient, status, deletion, eye,
  and identity serving index. The item read uses the existing unique series and
  sequence index after the redundant identity ordering was removed. Realistic
  noise fixtures prove no filesort, temporary table, forced index, or optimizer
  hint. Caching is `none`.
- Verification: the final focused pack passes 16 tests with 211 assertions,
  the wider Injection Management, prescription, and Intravitreal Injection
  pack passes 68 tests with 1,089 assertions, and the ledger, manifest, and
  migration-policy pack passes 14 tests with 2,444 assertions. Scoped Pint and
  all 24 containerized JavaScript tests pass. A fresh seven-schema run passes
  all 301 migrations, schema verification, and the tiny seed. A clean
  production build passes and produces image
  `sha256:4477c1d2b49782cd69977ce6712d4028e863c038fe11cc68ed1c2648f2304e1c`
  at 228,016,071 bytes. The one no-retry Playwright run observed the expected
  one lazy request, bilateral ordering, active plan, empty opposite side, no
  editable controls, correct section placement, no browser errors, and exact
  fixture cleanup. Its command exited non-zero only because the harness
  expected `Treat and Extend` instead of the configured `Treat and extend`;
  that assertion is corrected and syntax checked but deliberately not rerun.
- Accounting: the pinned model, widget, patient-mode view, and landing-page
  caller carry direct evidence while ongoing actions and longitudinal history
  stay deferred. Injection Management has 12,186 highest-per-path points over
  its exact 138-path graph and 88.3 percent unweighted coverage, with 82 full
  paths and 6 inventoried-deferred paths. The global ledger remains exactly
  14,125 canonical paths and 18,441 rows, with zero missing and zero pending
  review. Exact coverage is 50.2871 percent.
- `next_item`: inspect the next authoritative patient-summary section or small
  shared-core gap from pinned source and OeDocumentation before choosing a
  bounded behavior.
- `after_next`: continue source-driven functional breadth without opening
  Injection Management ongoing actions, exact visual fidelity, or Cypress
  scope.
- Blockers and deferrals: stop, observe, switch, defer, cancel, last-injection,
  longitudinal history, exact progress icons, imported-data reconciliation,
  realistic migrated-data load tuning, and clinical sign-off remain later
  gates. Cypress remains legacy evidence only and is not an implementation
  queue.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=patient-summary-injection-management-read-only-green;
  bilateral-current-plan-parity-green; summary-query-count-3-fixed;
  plan-item-bound-100; no-filesort-no-temporary-no-hint;
  focused-pack-16-211; neighboring-pack-68-1089;
  ledger-manifest-migration-14-2444; javascript-24-green;
  fresh-seven-schema-migrations-seed-green; clean-production-build-green;
  playwright-behavior-observed-harness-label-case-failed-no-rerun;
  production-image-contract-228016071; ledger-14125-18441-50.2871`.

### 16.79 Request-scoped current context and bounded Management Summaries - 2026-09-01 22:55 BST

- Completed foundation: login now resolves an authorized active institution,
  site, firm, service, and subspecialty into immutable request-scoped state.
  The accessible global picker validates changes, persists user defaults and
  session state, and emits only bounded audit identifiers. It remains safe for
  persistent workers and its option lists use exactly two configuration
  queries at small and large fixture sizes.
- Clinical ownership: interactive event creation reuses one live episode per
  patient and subspecialty and snapshots the selected context onto episodes,
  events, and Management Summary rows. A direct current firm owns the episode
  when allowed; the portable fallback uses equality predicates and declared
  indexes without an expression sort, forced index, or optimizer hint.
- Completed behavior: the familiar patient-summary Management Summaries panel
  now presents one current summary per subspecialty, its plan and recorded user,
  and an exact previous count. Older summaries are fetched only after expansion
  through patient-, institution-, and subspecialty-bound keyset pages. The
  current read remains at three clinical queries for small and large fixtures.
- Verification: fresh seven-schema migration passes all 301 migrations, schema
  verification, and the tiny seed. The combined context and Management Summary
  pack passes 35 tests with 469 assertions. The focused summary pack passes 3
  tests with 66 assertions. The ledger, manifest, and permission pack passes 17
  tests with 2,504 assertions. Scoped Pint, all 24 JavaScript tests, and the
  production frontend build pass. Image
  `sha256:5460c6499d48fc76a15ded19dd2c6cf008e0496121e5b18fc8b0b9f7adb4ca3b`
  is 228,078,375 bytes.
- Browser boundary: the one no-retry Playwright workflow authenticated,
  selected Cataract, created event 267, and reached the real element picker
  without browser errors. It stopped on an ambiguous harness locator before
  saving Clinical Management. Fixture cleanup deleted the event and confirmed
  no current projection. The locator is corrected and syntax checked but is
  deliberately not rerun, so browser sign-off remains deferred.
- Accounting: Clinical Management has 4,970 highest-per-path points over its
  exact 56-path graph and 88.8 percent unweighted coverage. Current Context has
  969 points over its 12-path graph and 80.8 percent coverage. The global ledger
  remains exactly 14,125 canonical paths and 18,441 rows, with zero missing and
  zero pending review. Exact coverage is 50.3591 percent.
- `next_item`: audit remaining event creators by source category and record
  which use selected interactive context, copy a source event, or require an
  explicit external mapping; implement only a bounded creator if this exposes
  an architecture-rewrite risk.
- `after_next`: inspect automatic medication-set composition and rebuild from
  pinned source and verified consumers before choosing a bounded behavior.
- Blockers and deferrals: provider-constrained institution selection,
  integration-header context, recent-firm ordering, historical reconciliation,
  background and derived event creators, exact Management Summary styling,
  wider dependent consumers, realistic migrated-data tuning, and clinical
  sign-off remain later gates. Cypress remains legacy evidence only and no new
  Cypress test is created or run during functional porting.
- Repository state: changes remain staged or ready to stage only, with no
  commit or push.
  `verification_state=current-context-backend-green;
  management-summary-backend-green-browser-deferred;
  context-option-query-count-2-fixed; summary-query-count-3-fixed;
  history-keyset-patient-institution-subspecialty-bound;
  no-filesort-no-temporary-no-hint; combined-pack-35-469;
  focused-summary-pack-3-66; ledger-manifest-permission-17-2504;
  javascript-24-green; fresh-seven-schema-migrations-seed-green;
  clean-production-build-green; playwright-element-picker-observed-locator-
  ambiguity-no-rerun; production-image-contract-228078375;
  ledger-14125-18441-50.3591`.

### 16.80 Complete automatic medication-set composition - 2026-09-01 23:55 BST

- Completed behavior: automatic Medication Sets now compose explicit medication
  rules, recursively included sets, normalized medication attribute options, and
  indexed parent or child dm+d hierarchy rules. Portable Medication import uses
  stable parent natural keys, rejects self-reference and cycles, and synchronizes
  the complete normalized attribute assignment document with history.
- Concurrency and performance: one zero-wait MariaDB named advisory lock rejects
  a competing rebuild immediately, bounded row locks protect the automatic sets,
  and projection replacement remains atomic. Targeted parent, child, explicit
  identity and attribute queries avoid whole-catalogue scans. Query-plan proof
  reports no filesort, temporary table, forced index or optimizer hint.
- Consumer safety: explicit rules retain prescribing defaults and tapers. Rows
  derived from hierarchy or attributes keep null defaults. The interactive
  Prescription editor presents them for review using only existing medication
  dose, unit and route fallbacks. Non-interactive Operation Note generation now
  rejects an incomplete generated set with a clear validation error.
- Verification: a clean seven-schema MariaDB migration passed all 301 migrations,
  tiny seed and schema verification. The focused automatic-set and shared
  consumer pack passed 7 tests with 65 assertions, including advisory-lock
  contention and strict generated-draft behavior. Scoped Pint, 24 JavaScript
  tests and the production frontend build pass. A single no-retry Playwright flow
  added a hierarchy and attribute generated set to Prescription, observed all
  three expected rows, `oePageState=ready`, and no console error. The disposable
  clinical data and temporary web container were removed, followed by a second
  clean migration, seed and schema verification.
- Accounting: the ledger remains exactly 14,125 canonical paths and 18,441 rows,
  with zero missing and zero pending review. Exact coverage is 50.3667 percent.
  The medication attribute migration is fully represented; the automatic-set
  schema is 95 percent because historical raw-row conversion is not yet rehearsed;
  that conversion remains 55 percent until realistic migrated-data testing.
- `next_item`: diagnose the isolated prior-Prescription discovery failure that
  reports a missing repeat-prescription `event_id`, and fix it only if it is
  attributable to the current staged application context or projection work.
- `after_next`: select the next smallest authoritative ordinary vision,
  refraction or shared-core behavior from pinned source without opening new
  Cypress, visual-fidelity or realistic-load scope.
- Blockers and deferrals: historical raw Medication Set row conversion, imported
  catalogue reconciliation, realistic catalogue scale, selected-firm migration,
  exact visual fidelity and clinical sign-off remain later gates. Working
  signing, printing, reporting and pharmacy paths are not reopened for coverage.
- Repository state: changes remain staged or ready to stage only, with no commit
  or push. `verification_state=automatic-set-complete-reachable-rule-shape;
  normalized-parent-and-attributes; atomic-zero-wait-lock;
  focused-pack-7-65; ledger-policy-3-23; migrations-301-seed-schema-green;
  javascript-24-green; production-build-green; playwright-green;
  ledger-14125-18441-50.3667`.

### 16.81 Selected-context seed and same-episode Prescription regression - 2026-09-02 00:02 BST

- Attributable failure: the selected-subspecialty episode contract correctly
  opens a new episode when an existing open episode has no context snapshot. The
  tiny seed still created all 20 episodes with the old three-column shape, so a
  newly created Prescription moved to a second episode and the pinned legacy
  same-episode repeat action could not find the earlier Prescription.
- Correction: the tiny seed now gives every open episode the authoritative City
  Cataract service firm and subspecialty snapshot. The repeat query stays scoped
  to one episode, preserving the legacy clinical boundary rather than widening
  it across unrelated subspecialties. The regression test now also proves the
  new event reuses the prior Prescription episode.
- Verification: the exact failing test first reproduced on a fresh 301-migration
  schema with the missing repeat event. After reseeding, it passed with 42
  assertions. The full Prescription, event-creation and current-context pack then
  passed 35 tests with 1,031 assertions. Scoped Pint passes.
- `next_item`: inspect the next smallest authoritative ordinary vision,
  refraction or shared-core gap from pinned source and verified callers.
- `after_next`: continue source-driven functional breadth until the 02:00 scope
  freeze without starting Cypress, visual-fidelity or realistic-load work.
- Blockers and deferrals: migrated legacy episodes without service snapshots need
  an explicit data-migration reconciliation policy and are not assigned a guessed
  subspecialty at request time.
- Repository state: changes remain staged or ready to stage only, with no commit
  or push. `verification_state=repeat-prescription-regression-fixed;
  same-episode-boundary-retained; fresh-schema-reproduction;
  focused-1-42; integrated-35-1031; pint-green`.

### 16.82 Live Refraction source evidence reconciliation - 2026-09-02 00:17 BST

- Source review: the current Refraction and Retinoscopy Vue editors already emit
  bounded per-eye draft values to Correction Given. Removing a source removes
  its draft, and the server remains authoritative by validating Refraction and
  recalculating Retinoscopy inside the atomic event batch save. The familiar
  patient-summary REF row already reads the same cross-source precedence through
  four fixed indexed clinical queries.
- Correction: stale secondary FileLedger mappings no longer describe these
  interactions or the patient-summary row as deferred. Six old aggregate rows
  from the broad vision census now point to the existing implementation and
  evidence and are marked reviewed. Canonical ownership and exact visual
  deferrals are unchanged, so this is evidence reconciliation rather than a new
  feature claim.
- Verification: a disposable exact seven-schema namespace passed all 301
  migrations, the tiny seed and schema verification. The current source then
  passed 27 Refraction, Retinoscopy and Correction Given tests with 395
  assertions. All 24 JavaScript tests pass. The seven schemas and temporary
  database user were deleted and both absence counts returned zero.
- Accounting: Refraction is 77.7 percent across 94 mappings, Retinoscopy is 92.4
  percent across 25, Correction Given is 92.1 percent across 14, and the broad
  vision/refraction group is 25.4 percent across 286. Highest-per-path global
  coverage remains exactly 50.3667 percent over 14,125 canonical paths and
  18,441 rows.
- `next_item`: inspect one final caller-evidenced ordinary vision or shared-core
  gap and open it only if it can close safely before the 02:00 scope freeze.
- `after_next`: freeze new functional scope at 02:00 and begin ledger, plan,
  repository and test-batch integration through the 07:00 terminal checkpoint.
- Blockers and deferrals: configurable workflow placement, shared history UI,
  Case Search, NOD, CXL, Refractive Outcome, Biometry, worklist consumers,
  historical ETL, OpenAPI publication, in-application help, print layout and
  exact visual fidelity remain later gates. No Cypress test is created or run.
- Repository state: changes remain staged or ready to stage only, with no commit
  or push. `verification_state=live-refraction-drafts-confirmed;
  authoritative-atomic-source-validation; focused-27-395;
  javascript-24-green; migrations-301-seed-schema-green;
  disposable-schemas-and-user-removed; ledger-14125-18441-50.3667`.

### 16.83 Early functional freeze at the workflow boundary - 2026-09-02 00:24 BST

- Source finding: the pinned Strabismus workflow creates one ordered element set
  for Strabismus and Paediatrics containing Refraction, Retinoscopy, Correction
  Given and the other orthoptic elements. The target already has normalized
  workflow tables, portable administration and a context resolver, but the
  Examination controller and page do not consume that resolver and no
  authoritative legacy workflow import has populated the target contract.
- Decision: do not hard-code just Retinoscopy and Correction Given into the
  default editor. That would preserve one visible symptom while bypassing the
  shared workflow feature. Do not connect the resolver during the final window
  without migrated fixtures and a query budget. Freeze new functional scope at
  this safe checkpoint and begin integration verification before 02:00.
- Next tranche acceptance: migrate complete ordered workflow definitions by
  stable context keys; resolve from the event's immutable institution, firm,
  subspecialty and episode status; bound candidate and item reads; expose the
  selected set in the existing element DTO; and prove Cataract, Strabismus and
  Paediatrics activation in one no-retry Playwright flow. Retain manual Manage
  Elements fallback and fail to the current safe defaults if configuration is
  absent or invalid.
- Repository state: no workflow code or schema changed in this checkpoint.
  `verification_state=functional-scope-frozen-early;
  workflow-resolver-disconnected-confirmed;
  authoritative-import-missing; no-partial-hard-coded-workaround`.

### 16.84 Frozen integration checkpoint - 2026-09-02 01:12 BST

- Full-suite diagnosis: the normal monolithic Pest process accumulated beyond
  the 512 MiB test contract. A temporary 1024 MiB diagnostic process completed
  with 2,554 passing tests, 21 failures, and 39,420 assertions. The temporary
  allowance was removed. Every failure was classified as a cold-versus-warm
  query measurement, stale assertion, missing test context, Redis host
  configuration, or one attributable bounded UNION plan-inspection gap.
- Failure closure: the corrected 21-failure pack passes 193 tests with 2,550
  assertions. Query-growth tests now compare warmed small and warmed large
  requests. The UNION inspector rejects a branch without its own positive
  integer limit, while retaining bounded Eloquent and query-builder unions.
- Schema and plan proof: a fresh manager-equivalent seven-schema namespace
  using `utf8mb4_unicode_ci` passed all 301 migrations, the tiny seed, and
  schema verification. All 23 named tiny query-plan budgets pass without
  filesort, temporary table, forced index, or optimizer hint. The unfiltered
  patient event timeline now uses its page-order index after that index gained
  the optional event-type key as a trailing column and the unused episode
  projection was removed. The separate type-first index remains available.
- Frontend proof: all 24 JavaScript tests pass from the current lockfile in a
  disposable executable dependency volume. The production frontend build
  passes with 831 modules. The two existing SVG runtime references and the
  large EventView chunk remain recorded warnings, not hidden passes.
- Container proof: fresh current-worktree web, manager, queue, Reverb,
  renderer, and development images pass the complete Docker verification
  suite. The production image is 228,105,174 bytes. Live renderer browser
  compatibility, two-slot isolation, manager startup, queue roles, realtime,
  development boundaries, isolated Compose deployment, and Helm role and
  scaling guards are green. The manager remained healthy through its normal
  migration startup window.
- Accounting: the FileLedger remains 14,125 canonical paths and 18,441 rows,
  with zero missing and zero pending review. Highest-per-path weighted coverage
  remains 50.3667 percent. No verification-only row increases coverage.
- `next_item`: run the focused ledger, manifest, migration-policy and
  no-database-automation gates, then one bounded affected Playwright batch.
- `after_next`: reconcile plans and staged diffs, remove the exact disposable
  verification database namespace after its last use, and record hourly
  checkpoints through the first safe integrated boundary at or after 07:00.
- Complete bounded proof: all 364 discovered Unit and Feature files ran exactly
  once in five fresh 512 MiB processes. The groups passed 2,577 tests with
  39,560 assertions in total. This proves the current test surface, but the
  grouping and aggregation were manual and are not yet a reusable CI contract.
- Browser boundary: the one no-retry affected Playwright attempt reached the
  application but received HTTP 500 while creating an Examination against the
  reused browser fixture. The focused Refraction and event-save tests are green,
  so this is recorded as an unresolved stale-fixture or harness failure rather
  than a claimed application pass or a proved current feature regression.
- Deferred resource cleanup evidence: 33 running containers currently start
  with `oe-patient` or `oe-laravel`, alongside 40 matching named volumes and
  four matching networks. The two largest verification databases alone use
  about 4.35 GiB. All matching containers have restart policy `no`; only the
  `oe-laravel-browser-current` four-service stack carries Compose project
  labels, so most resources require exact provenance review before removal.
  The host had 7.3 GiB available memory and no swap at the snapshot. The user
  explicitly allowed these resources to remain for now. Do not remove them in
  this run; use the exact-project cleanup gate in section 16.6 later.
- Blockers and deferrals: the immediately following checkpoint must persist the
  deterministic chunk contract so every discovered Pest test runs exactly once
  across fresh 512 MiB processes, with explicit schema ownership and aggregated
  failure reporting. Realistic migrated-data load, clinical sign-off, full
  visual comparison, and Cypress reconciliation remain later gates.

### 16.85 Deterministic bounded-memory verification infrastructure

`phpunit.xml` remains at 512 MiB. The Docker test contract now includes
`tests/run-pest-chunks.sh`, a plain shell runner that discovers the complete
Unit and Feature file set from the immutable development image, rejects unsafe
or duplicate paths, assigns each file exactly once to stable suites of no more
than 80 files, and runs each suite in a fresh development container. Exact
assignment is reconciled before success. JUnit output supplies per-chunk and
aggregate file, test, assertion, duration, failure, error and skip counts, but
never SQL, bindings, fixture values or environment secrets. Failed evidence is
retained in its exact temporary directory; passing evidence is removed.

Application verification now requires `OE_TEST_SCHEMA_PREPARED=TRUE` in
addition to the existing disposable database and Redis confirmations. This is
set only after the manager-equivalent seven-schema migration, tiny seed and
schema verification sequence, so the sequential chunks neither own migration
setup nor depend silently on a partially prepared schema. The production image
contract verifies the runner's syntax, bounded chunk size, exact assignment,
and integration into `tests/verify-all.sh`.

Fresh complete proof on 2 September discovered and assigned all 364 files once
across five containers. All 2,578 tests and 39,568 assertions passed with zero
failures, errors or skips. A first run against a reused database correctly
exposed two stale-fixture counts and one test helper defined in another test
file; the helper moved to shared Pest setup and its focused 25-test pack passed
326 assertions before this clean run. No process memory limit was raised and no
test-orchestration framework was introduced.

### 16.86 Bounded readability and reuse review

The immediate review found no application change that is safer than retaining
the current proven control flow during the frozen integration window. The main
worklist page is large, but it already delegates live-state, session, filter,
selection and subscription behavior to small JavaScript modules; its remaining
code coordinates those contracts and presentation. The replay preview and
administration diagnostics services are large but cohesive and bounded. They
must not be split until realistic load and failure evidence identifies a stable
seam. The automatic medication-set rebuild remains deliberately explicit
because its graph traversal is clinical and performance sensitive; do not hide
it behind a generic graph abstraction without a second real catalogue consumer.

Three narrow reuse opportunities are recorded for later proof, not speculative
refactoring now:

1. Patient-summary panels repeat the same lazy-load, loading, error and
   `IntersectionObserver` lifecycle. Extract one small tested composable only
   after parity and browser coverage are stable, while keeping clinical panel
   presentation separate.
2. Patient and worklist readers repeat URL-safe base64 JSON cursor mechanics.
   Introduce a typed codec only if caller-owned shape and context validation,
   invalid cursor tests and mismatched-patient tests remain obvious. Do not
   create a generic pagination framework.
3. Worklist dashboard and diagnostic pages repeat same-origin JSON, CSRF and
   error handling. Extract a tiny client only if both consumers retain the same
   semantics after the realistic load and failure matrix.

The verification runner itself removed the only detected cross-test-file
function dependency. Further review should prefer meaningful names and comments
only for non-obvious clinical or architectural reasons. It must not trigger a
wholesale rewrite-wide refactor.

### 16.87 Reusable full integration proof - 2026-09-02 02:54 BST

The current final development image passed the complete application-enabled
Docker verifier in one invocation against a fresh manager-prepared seven-schema
namespace. The same invocation passed every production role, renderer and
development-role boundary, isolated Compose startup and migration health, Helm
guards, strict Composer validation, documentation and module checks, and Pint
over all 2,880 PHP files in the image. Its reusable bounded-memory runner then
discovered all 364 Unit and Feature files, assigned every file exactly once to
five fresh 512 MiB containers, and passed 2,578 tests with 39,568 assertions
and zero failures, errors or skips.

The separate final database and governance gates remain green: all 23 named
tiny query-plan budgets pass without filesort, temporary table, forced index or
optimizer hint, and the FileLedger, application-surface manifest,
migration-policy and optimizer-hint pack passes 16 tests with 2,446 assertions.
Composer and npm audits report no known advisories, all 24 JavaScript tests
pass, and the production frontend build completes with 831 modules. The two
known SVG runtime references and large EventView chunk remain explicit build
warnings. The no-retry Playwright attempt remains unresolved at the reused
fixture's HTTP 500 boundary and is not promoted to a pass.

- `next_item`: reconcile the hourly record, active and master plans, TODO and
  staged diffs without opening new functional scope.
- `after_next`: at or after 07:00 BST, remove only the exact disposable
  verification schemas and users, repeat final repository-state checks, and
  close at the first safe integrated checkpoint.
- `blockers`: no backend, schema, query-plan, packaging or container blocker is
  open. Browser evidence remains explicitly unresolved rather than retried.
- `verification_state=full-reusable-integration-green; browser-unresolved;
  final-time-guard-active`.

### 16.88 Fresh-schema repeat and runner operating rule - 2026-09-02 03:22 BST

The exact runner was repeated after its final ShellCheck readability correction.
An initial repeat against the already-used `0031` namespace retained its JUnit
evidence and reported two fixture-count failures: one extra patient contact and
one extra correspondence recipient. Both tests had passed during the first
complete run, and every other chunk in the repeat remained green. This is
expected contamination from reusing a sequential integration database, not an
application regression.

A new `0032` namespace was therefore created with seven empty schemas and a
dedicated disposable user. It passed all 301 migrations, the tiny seed and
schema verification before any tests ran. The unchanged runner then discovered
and assigned all 364 files exactly once and passed 2,578 tests with 39,568
assertions, zero failures, zero errors and zero skips in 497.22 seconds. The two
previously failing tests passed in their normal sorted position. The superseded
failed JUnit directory was removed only after this complete replacement proof;
the successful runner removed its own temporary evidence as designed.

`OE_TEST_SCHEMA_PREPARED=TRUE` means a newly prepared and previously unused
namespace for each complete run. A successful migration and schema check alone
does not make a test-mutated namespace pristine. Repeat runs must create a new
disposable namespace rather than treating later fixture-count failures as code
regressions or weakening exact assertions.

Focused ShellCheck and `bash -n` pass the runner and Reverb verifier after the
readability correction. The live Reverb image check also passes. No application
code changed during this reconciliation.

### 16.89 Long-lived worklist subscription renewal correction - 2026-09-02 03:42 BST

The frozen integration audit found one boundary defect in the long-lived
worklist client. The private-channel authorizer replaced the subscription's
original channel array with a set of prefixed authorization names. The first
subscription worked, but a later timed lease renewal would return that set to
the live session, whose subscribe and leave paths require the original
unprefixed array. A dashboard left open long enough to renew could therefore
stop receiving changes even though the short initial-subscription tests passed.

The authorizer now keeps the normalized unprefixed channel array in the lease
and a separate private-channel set for authorization checks. It rejects
duplicates and clears both values on teardown. The existing live-session test
now uses the real authorizer normalizer, runs the actual renewal timer, proves
the renewed unprefixed subscriptions and leaves, and proves final cleanup.

All 24 JavaScript tests pass in the exact final development image. The corrected
source hashes match both production and development image contents. Rebuilt
`final2` web, manager, queue, Reverb, web-development, manager-development and
queue-development images pass their focused role, runtime, development-tooling
and live Reverb checks. The production web image is 228,106,526 bytes. No PHP,
schema or dependency file changed after the fresh 2,578-test, 39,568-assertion
proof, so that complete backend proof remains current.

- `next_item`: record the actual 04:00 hourly checkpoint and continue frozen
  security, integration and repository-state reconciliation.
- `after_next`: repeat the 05:00 and 06:00 evidence checkpoints, then remove
  only the exact disposable database verification resources at or after 07:00.
- `blockers`: the one no-retry browser attempt remains unresolved at its reused
  fixture HTTP 500 boundary. Realistic worklist load and failure testing remains
  a later scale gate.
- `verification_state=final-images-and-long-lived-renewal-green;
  full-backend-proof-current; browser-unresolved; final-time-guard-active`.

### 16.90 Snapshot, membership and ordered-delivery correction - 2026-09-02 04:00 BST

The frozen worklist boundary audit found three related correctness risks that
only appear when snapshot loading and long-lived delivery overlap. The snapshot
response now exposes its already-validated high-water event ID and initializes
each selected worklist's live cursor from it, so membership count deltas already
reflected by the snapshot are not applied again. Delta recovery also skips only
that known overlap.

Batch construction now preserves every outbox event containing a membership
delta. Ordinary row-only updates for the same appointment still collapse to the
latest version, but a join followed by a leave can no longer lose its first
count transition. The partition publisher remains the only queued boundary and
hands each batch to Reverb synchronously in its existing ordered loop. A failed
handoff therefore leaves the durable outbox claim retryable instead of adding a
second queue that can reorder adjacent batches.

The client validates strictly increasing event IDs and the advertised final
cursor before applying either a live batch or a delta page. Duplicate or
reordered contents fail closed before changing counts and trigger authoritative
recovery. This check does not require contiguous global IDs, so unrelated
worklist events may still create normal gaps.

Focused worklist PHP passes 28 tests with 466 assertions, including query-count
and query-plan checks. The containerized JavaScript suite passes 26 tests. A new
and previously unused `0033` seven-schema namespace passed all 301 migrations,
the tiny seed and schema verification, and the exact-current 364-file Pest run
is in progress. The latest JavaScript-only ordering guard will be copied into a
rebuilt exact image before the next image and frontend gates.

- `next_item`: complete the fresh `0033` Pest run and rebuild the exact final
  images with the JavaScript ordering guard.
- `after_next`: repeat role, frontend, ledger and staged-state gates without
  opening functional scope.
- `blockers`: the one no-retry browser attempt remains unresolved at its reused
  fixture HTTP 500 boundary. Realistic worklist load and failure testing remains
  a later scale gate.
- `verification_state=worklist-delivery-correctness-focused-green;
  exact-full-pest-active; browser-unresolved; final-time-guard-active`.

### 16.91 Final delivery recovery and replacement proof - 2026-09-02 04:35 BST

The long-lived lease audit found one further failure boundary. Renewal used to
wait for delta recovery before leaving the old channels, so a stalled recovery
could leave an aged subscription receiving changes indefinitely. Renewal now
leaves the old channels before recovery. A recovery failure remains
unsubscribed, exposes degraded state and retries after five seconds; stopping
the session during the await cannot create a later subscription. The exact
containerized JavaScript suite passes 26 tests, including failed recovery and
successful retry, reordered batches and pages, snapshot overlap, count
underflow, bounded retained rows and the 100-click home guard.

The `0033` full-run database container disappeared during the final feature
chunk. The first failure was `MySQL server has gone away`; the remaining 12
errors were connection-refused failures in worklist scale, contention and XAPI
tests. Docker and kernel logs contain no OOM report for the interval, and the
host retained about 11 GiB available memory, but the container was already
removed before it could be inspected. The cause is therefore not claimed. This
run is infrastructure-interrupted evidence, not an application result.

A replacement `0034` namespace was created on the surviving healthy MariaDB
11.8 test service. Its first migration attempt correctly exposed that schemas
created without an explicit collation inherit the server's newer
`utf8mb4_uca1400_ai_ci`, which conflicts with the application's
`utf8mb4_unicode_ci` contract. Only the seven disposable schemas were recreated
with the explicit application collation. They then passed all 301 migrations,
the tiny seed, history-twin and hygiene schema verification. This reinforces
the schema-packet rule: test and deployment schema creation must set the
application collation and must not inherit a release-dependent server default.

The rebuilt exact development image then discovered and assigned all 364 Pest
files once in five fresh 512 MiB containers. It passed 2,579 tests with 39,572
assertions and zero failures, errors or skips in 518.01 seconds. This includes
the worklist scale, contention, ordered-delivery, replay, dashboard, diagnostic
and XAPI tests beyond the point of the interrupted run. The superseded failed
JUnit directory was removed only after this complete replacement proof.

The rebuilt production web, manager, queue and Reverb images and all required
development variants pass role isolation, runtime boundaries, live Reverb,
renderer compatibility, isolated Compose migration health and Helm checks.
The temporary Compose project removed only its own containers, networks and
volumes. Source hashes for the four corrected worklist JavaScript files match
their copies inside the final development image. All 23 named tiny query-plan
budgets pass without filesort, temporary table, unbounded scan, forced index or
optimizer hint. The FileLedger, application-surface manifest, migration policy
and optimizer-hint pack passes 16 tests with 2,446 assertions. Pint passes all
2,880 PHP files, Composer validation is strict and both Composer and npm audits
report no known vulnerability.

- `next_item`: record the actual 05:00 hourly checkpoint and reconcile the
  staged tree without opening functional scope.
- `after_next`: repeat the 06:00 checkpoint, retain the exact approved
  `oe-patient*` and `oe-laravel*` stacks, then remove only the disposable
  `0034` schemas and user at or after 07:00.
- `blockers`: the one no-retry browser attempt remains unresolved at its reused
  fixture HTTP 500 boundary. Realistic migrated-data load, worklist soak and
  failure testing, and clinical sign-off remain later gates.
- `verification_state=exact-current-full-integration-green;
  infrastructure-interruption-replaced; browser-unresolved;
  final-time-guard-active`.

### 16.92 Patient-summary access boundary and exact test image - 2026-09-02 05:00 BST

The exact `final4` development image route inventory contains 203 canonical
`/api/patients/{patient}` routes. Every route is named and carries both `auth`
and `break-glass`. The six patient-summary APIs added in this tranche now have
one compact direct-request regression that proves a user from another
institution is redirected to the patient challenge before any controller is
entered. The focused BreakGlass pack passes 10 tests with 65 assertions. This
proves the institution challenge boundary only. It does not claim the global
role and permission parity that remains blocked by `DIV-098`.

A fresh disposable `0035` namespace passed all 301 migrations, the tiny seed,
and schema verification before the focused test. Its seven schemas and user
were then removed and their absence was verified. The staged
`BreakGlassTest.php` SHA-256 exactly matches the copy in the rebuilt `final4`
development image, the image copy passes PHP syntax, and all 26 JavaScript unit
tests pass. No application behavior changed in this checkpoint.

The source and deployment trees remain bounded. Laravel has 405 staged files
with 29,626 additions and 1,813 deletions; Docker has 24 staged files with
1,477 additions and 17 deletions. Neither repository has an unstaged or
untracked file and both staged diffs pass `git diff --cached --check`. No
literal credential pattern, staged test artifact, log, key file, optimizer
hint, live-schema introspection call, or database trigger, event, procedure, or
function DDL was found in the relevant staged application source.

The approved resource inventory is now 32 running `oe-patient*` or
`oe-laravel*` containers and 40 matching named volumes. All 32 use restart
policy `no`; only the four-service `oe-laravel-browser-current` stack has a
Compose project label. The largest matching process is the retained wave
database at about 2.63 GiB. The host has about 10 GiB available memory and no
swap. These resources remain untouched under the user's explicit instruction;
the later exact-project cleanup gate remains the OOM-prevention action.

- `next_item`: reconcile the full staged diff and final security, query,
  container, and resource evidence without opening functional scope.
- `after_next`: record the actual 06:00 checkpoint, then at or after 07:00
  remove only the disposable `0034` schemas and user and repeat the final
  repository, ledger, and staged-state gates.
- `blockers`: the one no-retry browser attempt remains unresolved at a reused
  fixture HTTP 500 boundary. Realistic migrated-data load, worklist soak and
  failure testing, global authorization parity, clinical sign-off, visual
  fidelity, and Cypress remain later gates.
- `verification_state=patient-summary-break-glass-regression-green;
  exact-development-test-images-green; full-integration-proof-current;
  global-auth-policy-deferred; final-time-guard-active`.

### 16.93 Frozen architecture reconciliation and materialized-plan detection - 2026-09-02 06:00 BST

No new functional scope was opened. A read-only worklist review found no
architecture-level reason to rewrite the current foundation again. All 88
behavioural parity rows remain governed and the exact register test passes one
test with 823 assertions. Routine reads are bounded and cursor based, counts
are split across 64 shards, publication ownership is split across 64
partitions, and network delivery is outside database transactions. This is an
early redesign-risk gate only. It does not claim that hundreds of updates per
minute or thousands of differently configured users have passed the later
realistic synthetic and migrated-data load, failure, and soak matrix.

The patient-summary review found the familiar core panel order and bounded
summary services intact. Progressive event-image loading remains off and no
arbitrary first-ten limit was introduced. The installation-wide
`generate_event_images` setting defaults on, can reject only new preview-PNG
generation, and leaves cached images and non-image outputs available. Exact
visual comparison, clinical sign-off, and representative high-event-volume
tuning remain later gates.

The MariaDB 11.8.9 plan audit found that an unmerged derived query can be
materialized even when the JSON plan has no literal `temporary_table` key and
traditional `Extra` says only `Using index`. The inspector now treats JSON
`materialized` or `materialization` nodes and traditional `DERIVED`,
`LATERAL DERIVED`, or `MATERIALIZED` select types as temporary work. Its exact
development-image pack passes five tests with 15 assertions. All 23 named tiny
query budgets still pass without filesort, temporary work, unbounded scans,
forced indexes, or optimizer hints. The history-heavy profile continues to
fail closed until a representative large fixture exists.

Operational request telemetry remains request scoped and allowlisted: request
ID, operation ID, method class, status, duration, query count, total database
time, slowest query time, response bytes, and peak request memory only. Its
regression injects SQL, bindings, a URL, and an exception message and proves
none are emitted. Ordinary web paths perform no schema discovery or DDL.
Partition extension is the explicit exception: only the manager role registers
the monthly `oe:schema:partition-roll` schedule, guarded by
`withoutOverlapping` and `onOneServer`; it is not a web-request behavior.

The exact integration proof remains current. Fresh `0034` passed all 301
migrations, the tiny seed, seven-schema verification, and every one of the 364
Pest files in five fresh 512 MiB processes: 2,579 tests and 39,572 assertions
with no failures, errors, or skips. The worklist register passes one test with
823 assertions, the query-plan unit pack passes five with 15, and the
database-free ledger and policy pack passes five with 25. The final source
matches both `openeyes-web:checkpoint-20260902-final5-development`
(`sha256:3824a7d768bfe549156fd02346e9658e305ffeceadb2905550416f8002e04612`)
and `openeyes-web:checkpoint-20260902-final4-queryplan`
(`sha256:e7215b99a39a69cedd27af0d8d80c3c745e84f0c864d0e4407ddc415a6d059f1`)
for the late query-plan, telemetry, schedule, and parity files. The manager,
queue, Reverb, and renderer image IDs remain the recorded `final4-queryplan`
or renderer-checkpoint IDs.

Laravel has 406 staged files with 29,669 additions and 1,815 deletions; Docker
has 24 with 1,477 additions and 17 deletions. Both repositories have zero
unstaged or untracked files and pass `git diff --cached --check`. The ledger
has 18,441 rows and exactly 14,125 unique canonical paths, zero canonical rows
at `pending-review`, 2,267 secondary mappings still at `pending-review`, and
5,020 reviewed canonical rows whose implementation status remains `pending`.
Coverage remains 50.3667 percent.

The approved resource set remains 32 running `oe-patient*` or `oe-laravel*`
containers and 40 matching named volumes, using about 7.173 GiB. None reports
an OOM kill, all have restart policy `no`, all lack a Docker memory limit, and
the host has about 9.7 GiB available with no swap. They remain untouched. The
future exact-project and exact-volume cleanup gate is retained as an explicit
OOM-prevention task and forbids broad prune.

- `next_item`: perform final staged-diff, ledger, schema-target, image, and
  resource reconciliation without opening functional scope.
- `after_next`: at or after 07:00 BST, remove only the exact seven disposable
  `0034` schemas and dedicated user, verify their absence, record the final
  integrated checkpoint, and complete the durable goal.
- `blockers`: the one no-retry browser attempt remains unresolved at a reused
  fixture HTTP 500 boundary. Realistic migrated-data worklist load and soak,
  global authorization parity under `DIV-098`, exact patient-summary visual
  comparison, clinical sign-off, renderer fidelity, and Cypress remain later
  gates.
- `verification_state=frozen-architecture-reconciled;
  materialized-plan-detection-green; full-integration-proof-current;
  resource-cleanup-deferred; final-time-guard-active`.

### 16.94 Terminal integrated checkpoint - 2026-09-02 07:01 BST

The dual terminal condition is satisfied. The 07:00 BST time guard passed and
the final integration checkpoint is now recorded. No new functional scope was
opened after the 06:30 freeze.

Only the exact disposable verification database resources were removed:
`oe_final_recovery_20260902_0034_{archive,audit,clinical,config,ephemeral,history,sys}`
and `oe_final_recovery_0034@%`. A post-delete query reports zero remaining
schemas and zero remaining users. This test namespace is not recoverable in
place, but it contained no authoritative data and is reproducible from the
staged migrations and tiny seed. The retained wave database, Redis, web, and
all other approved stacks were not stopped or removed.

The final proof remains the fresh `0034` run completed before disposal: all
301 migrations, tiny seed, seven-schema verification, and 2,579 tests with
39,572 assertions across all 364 Pest files in five fresh 512 MiB processes,
with no failures, errors, or skips. Focused final evidence also includes all 88
worklist parity rows, the materialized-derived query-plan detector, all 23 tiny
query budgets, the application-surface manifest, FileLedger integrity,
migration policy, optimizer-hint policy, 26 JavaScript tests, the production
frontend build, role-isolated application images, live renderer PDF and PNG
checks, Compose migration health, and Helm rendering.

Laravel remains on `rewrite/2026-09-02-0700` at `0cecd17564c3`, with 406
staged files and no unstaged or untracked files. Docker remains on the same
branch at `0994b0cc1655`, with 24 staged files and no unstaged or untracked
files. Both staged diffs pass `git diff --cached --check`. Nothing was
committed or pushed. The kit retains its pre-existing untracked browser
artifact directory untouched.

Coverage closes this run at 50.3667 percent over exactly 14,125 unique
canonical paths and 18,441 mappings. There are zero missing canonical paths,
zero canonical rows at `pending-review`, 2,267 secondary mappings still at
`pending-review`, and 5,020 reviewed canonical rows whose implementation
status remains `pending`. The loose 70 percent aim did not displace the fixed
architecture, verification, and integration gates.

The approved local resource inventory remains 32 running `oe-patient*` or
`oe-laravel*` containers and 40 matching named volumes, using about 7.170 GiB.
They remain available for review. The separate future task will remove only
exact reviewed projects and volumes to reduce OOM risk and will never run a
broad prune.

- `next_item`: in the next checkpoint, perform the already-planned bounded
  readability, simple-comment, reusable-pattern, and reuse-opportunity review.
  Establish simple patterns where they reduce repetition, but do not refactor
  the whole tranche or make code harder to follow.
- `after_next`: resume the ordered master programme from the highest-value
  unblocked slice under the migration confidence pack, while keeping worklist
  production-scale load, failure, and soak testing at its later large-data
  gate.
- `blockers`: one no-retry browser attempt remains unresolved at a reused
  fixture HTTP 500 boundary. Global authorization parity remains deferred
  under `DIV-098`. Migrated-scale tuning, exact patient-summary visual
  comparison, clinical sign-off, renderer fidelity and capacity, full UAT,
  security documentation proof, and Cypress reconciliation remain later
  gates and are not claimed by this run.
- `verification_state=terminal-time-guard-passed;
  exact-disposable-schema-cleanup-verified; full-integration-proof-green;
  staged-no-commit-no-push; checkpoint-complete`.

### 16.95 Evidence-backed 70 percent coverage wave - 2026-09-02 10:52 BST

This tranche starts from the completed 07:01 checkpoint and retains the pinned
legacy `ad2324084788608246a8250e817198c2f26a4fd6`, Laravel
`0cecd17564c3aa8100d1f31d3fbe3ff8cfcde0e2` with its staged rewrite, and Docker
`0994b0cc16557368e9553fa9c4b501e248f85ed0` with its staged runtime changes.
The exact starting ledger is 711,430 points over 14,125 canonical paths, or
50.3667 percent. The 70.0000 percent aim is 988,750 points, leaving a
277,320-point gap, equivalent to 2,774 fully covered zero-credit paths after
rounding up.

The durable terminal contract is active. Work continues without voluntary
idling until `2026-09-03T14:00:00+01:00`, new functional scope freezes at 10:30
BST on 3 September, and the run ends at the first safe integrated checkpoint
at or after 14:00. If evidence-backed coverage remains below 70 percent, the
actual result and remaining evidence are reported. Clinical, security,
architecture, performance, and evidence gates are never weakened to reach the
number, and reaching it early does not end the run.

The current coverage calculation remains highest score per unique pinned path.
The verifier will additionally report per-source-class points and percentages,
including code-only coverage, and accept an optional minimum target. Review,
inventory, copied assets, generic package references, or secondary mappings do
not earn credit. Vendored dependencies, tests, migrations, and assets require
their exact replacement, behavior, schema, assertion, consumer, or evidenced
retirement contract. Cypress remains zero-credit source evidence until the
end-of-porting Playwright reconciliation.

Resource control is the first gate. An external non-secret inventory records
all 40 running rewrite containers found across the `oe-laravel*`,
`oe-patient*`, `oe-va-*`, and `oe-personal-mailbox*` groups, their images,
purpose, ownership, age, memory, mounts, restart policy, OOM state, evidence,
and recovery command. Retain only
`oe-laravel-wave-{web,redis,db}-20260830`; stop but do not remove the other 37
exact reviewed containers. Preserve every volume and network. The retained web,
Redis, and MariaDB containers are capped at 1 GiB, 512 MiB, and 4 GiB
respectively. Temporary application processes use 512 MiB and no more than two
run concurrently. A new container cannot start below 8 GiB host available
memory; below 6 GiB temporary containers stop and the work checkpoints.

The fixed implementation order is:

1. Add the class-level coverage report and optional minimum gate.
2. Complete the pinned component, licence, SBOM, support-lifecycle, and
   consumer-capability census for jQuery UI, PDF.js, and the remaining vendored
   families. A large missing component is deferred rather than rushed.
3. Close already implemented `partial`, `ported-partial`, `replaced-by`,
   `adapted`, and `tests-rewritten` rows across the legacy Laravel, shared, API,
   shell, schema, test, fixture, and asset surfaces.
4. Work the functional queue: event storage and attachments; medication-set
   rebuild and shared consumers; vision, refraction, and history safety;
   caller-evidenced webhooks; CVI; orthoptics and ocular surface; anterior and
   retina; then Operation Booking and Operation Note residuals.
5. Do not reopen worklist scale architecture. Only an evidenced defect that
   would force a later redesign can enter this tranche.

Every functional slice keeps the migration confidence pack: happy path,
authorization, validation and clinical invariants, constant small-to-large
query behavior, relevant plan and index evidence, schema proof where storage
changes, and one no-retry Playwright smoke for a user-facing flow. Hourly
checkpoints add code-only coverage, container count and memory, host available
memory, current evidence, next item, after-next item, blockers, tests, and exact
repository state.

At 10:30 BST on 3 September, no new scope opens. Final verification is focused
packs first, then one fresh seven-schema migration and tiny seed, schema
verification, the deterministic complete Pest runner in fresh 512 MiB
processes, JavaScript tests, production frontend build, changed-file Pint,
dependency audits, application surfaces, query-plan budgets, and only the
affected Docker, Compose, Helm, renderer, and Playwright gates. Temporary
resources stop after their gate. The three wave containers remain for the next
wave. All writable changes are staged and checked; nothing is committed or
pushed.

The later cleanup gate now explicitly retains the current 40 matching named
volumes, nine attached anonymous database volumes, and seven matching networks.
After a clean reproducibility run and human evidence-retention approval, remove
the exact stopped containers first, then the exact verified unmounted volumes
and networks. Record the loss and reproduction path. Broad Docker pruning is
forbidden.

### 16.96 Hourly checkpoint - 2026-09-02 11:28 BST

- `current_problem`: close the resource and evidence-foundation gates before
  assigning any additional legacy-path credit.
- `acceptance_condition`: retain only the active three-container stack, preserve
  all recovery data, prove exact per-source-class accounting, and narrow copied
  legacy browser dependencies without changing EyeDraw behavior.
- `completed_evidence`: all 40 rewrite containers were inventoried; the 37 idle
  containers are stopped and the three wave containers remain healthy within
  1 GiB web, 512 MiB Redis, and 4 GiB MariaDB limits. Host available memory rose
  from about 9.9 GiB to 16.0 GiB. All 40 matching named volumes, nine attached
  anonymous database volumes, and seven networks remain. The ledger verifier
  reports 14,125 canonical paths, 18,441 mappings, 711,430 points, 50.3667
  percent overall, and 422,470 points over 7,306 code paths, or 57.8251 percent.
  Its optional minimum gate passes the current threshold and rejects both an
  unmet and an invalid threshold. Ten internal Diagnosis Vue paths are now
  correctly classified as code instead of copied dependencies, with their
  pinned hashes unchanged.
- `current_work`: the copied EyeDraw browser stack is removed from the global
  application shell and loaded in dependency order only when an EyeDraw
  component mounts. Concurrent components share one load and users receive an
  accessible failure state. This narrows exposure but does not clear the old
  jQuery 1.8.3 or EventEmitter2 0.4.13 copies for release.
- `next_item`: audit already implemented partial and replacement rows against
  concrete target code and tests, then assign only path-specific earned credit.
- `after_next`: resume the fixed event-storage and attachment queue, followed by
  medication and ordinary vision, refraction, and history gaps.
- `blockers_and_deferrals`: copied jQuery and EventEmitter must be upgraded or
  more strongly isolated before release. The prior one-shot browser attempt
  remains unresolved at a reused-fixture HTTP 500 boundary. Cypress, realistic
  migrated-data load, visual fidelity, UAT, and clinical sign-off remain later
  gates.
- `query_and_performance`: no functional query shape changed in this checkpoint.
  The retained database namespace was rebuilt only after proving it was the
  dedicated seven-schema wave test namespace. All 301 migrations, the tiny
  seed, and seven-schema verification then passed.
- `tests`: the ledger pack passes three tests with 45 assertions; all 28
  JavaScript tests pass; the production frontend build passes; and the Lacrimal
  EyeDraw confidence pack passes nine tests with 117 assertions against the
  fresh schemas. Existing unresolved SVG and large-chunk build warnings remain.
- `repository_state`: legacy remains clean and read-only. Laravel and Docker
  retain their previously staged rewrite. Current Laravel and plan changes are
  not committed or pushed.
- `verification_state=resource-cleanup-green; source-class-ledger-green;
  fresh-301-migration-seed-schema-proof-green; eyedraw-on-demand-loader-green;
  coverage-50.3667; code-coverage-57.8251; terminal-time-guard-active`.

### 16.97 Hourly checkpoint - 2026-09-02 12:00 BST

- `current_problem`: finish the event-storage and attachment slice with the
  configured defaults that legacy correspondence macros apply automatically.
- `acceptance_condition`: authorized portable configuration can select the
  four currently implemented latest same-subspecialty event types and PDF
  advice leaflets; manual and generated letters persist the resolved immutable
  attachment snapshots; small and large histories use the same fixed query
  count and an indexed plan with no filesort, temporary table, or optimizer
  hint; schema and consumer regression gates remain green.
- `completed_evidence`: a normalized versioned macro-attachment table and
  configuration family now replace the overloaded legacy columns. The macro
  picker bulk-loads at most 100 macros and 50 defaults per macro. Automatic
  drafts and the patient generation API resolve defaults only when callers omit
  attachments, while an explicit empty list remains empty. Hidden and print
  flags participate in the render content identity. All 301 migrations, the
  tiny seed, and seven-schema verification passed from an empty dedicated
  namespace.
- `current_work`: reconcile the highest-value automatic medication-set paths
  against their real rebuild and consumer behavior before changing code or
  assigning more credit.
- `next_item`: close one evidenced automatic medication-set consumer gap, or
  record that the intended consumers are already complete and move on.
- `after_next`: continue ordinary vision, refraction, and history gaps, then
  webhook payload and transactional outbox parity.
- `blockers_and_deferrals`: actual PDF concatenation, body-shortcode attachment
  expansion, exact legacy administration styling, and the slice browser smoke
  remain deferred. The prior one-shot browser attempt remains unresolved at a
  reused-fixture HTTP 500 boundary. Cypress, migrated-scale load, fidelity,
  UAT, and clinical sign-off remain later gates.
- `query_and_performance`: macro choices and defaults are bounded in bulk. The
  latest same-subspecialty event read performs at most four fixed `LIMIT 1`
  queries over the maintained patient event timeline. Small and 100-row large
  fixtures have identical query counts. The exact composite index is selected
  with no filesort, temporary table, group-wise maximum, or index hint.
- `tests`: the focused correspondence attachment pack passes eight tests with
  71 assertions; the wider correspondence, timeline, and configuration pack
  passes 27 tests with 593 assertions; the attachment, injection consumer, and
  migration-policy pack passes 44 tests with 716 assertions; the ledger and
  schema pack passes four tests with 47 assertions; all 28 JavaScript tests and
  the production frontend build pass. Existing SVG and large-chunk build
  warnings remain.
- `coverage`: 14,125 canonical paths and 18,450 mapping rows yield 711,596
  points, or 50.3785 percent overall. Code coverage is 422,586 points over
  7,306 code paths, or 57.8410 percent. Correspondence is 88.2 percent over its
  exact 296-file owning-module inventory.
- `repository_state`: legacy remains clean and read-only. Laravel and Docker
  retain the approved staged rewrite. Current Laravel and planning changes are
  not committed or pushed.
- `verification_state=correspondence-macro-attachments-green;
  fixed-latest-event-query-green; fresh-301-migration-seed-schema-proof-green;
  coverage-50.3785; code-coverage-57.8410; terminal-time-guard-active`.

### 16.98 Hourly checkpoint - 2026-09-02 13:00 BST

- `current_problem`: close the caller-evidenced AIS webhook and external read
  contract without guessing the unresolved clinical ownership rules for PAS
  writes.
- `acceptance_condition`: accessibility entry changes emit once only after
  commit, unchanged or consent-only saves emit nothing, the typed subscriber
  pipeline projects the exact event without request-time HTTP, and xAPI plus
  PASAPI V2 and V3 expose a bounded deleted-owner-safe resource with fixed query
  growth. AIS reads must not inherit worklist intake backpressure.
- `completed_evidence`: the exact legacy
  `PatientAISFlagsChangedSystemEvent` identity now carries an authenticated
  xAPI resource link through the durable outbox and matching subscriber
  projection. The V2 and V3 legacy XML reads preserve `Value`, PAS `Language`,
  and the missing-patient response. The route boundary now limits
  `pas-worklist-intake` to appointment mutations. PAS AIS PUT, PATCH, DELETE,
  and incoming institution ownership remain explicit under DIV-252.
- `current_work`: start the highest-value evidence-backed CVI residual without
  reopening completed clinical flows merely to add coverage.
- `next_item`: close one bounded CVI residual with direct legacy caller and
  migration-confidence evidence.
- `after_next`: continue ordinary orthoptics and ocular-surface residuals, then
  anterior and retina.
- `blockers_and_deferrals`: incoming AIS mutation semantics remain clinically
  unsafe to infer. The prior one-shot browser attempt remains unresolved at a
  reused-fixture HTTP 500 boundary. Cypress, migrated-scale load, fidelity,
  UAT, and clinical sign-off remain later gates.
- `query_and_performance`: AIS reads use a bounded projection and have the same
  five queries for small and 43-row fixtures. The serving indexes are available
  and the inspected plans have no filesort, temporary table, or index hint.
- `tests`: the combined xAPI and webhook pack passes 40 tests with 342
  assertions, including the new subscriber projection and middleware-boundary
  proofs. The ledger pack passes three tests with 47 assertions. The slice also
  retains the fresh 301-migration, tiny-seed, and seven-schema proof.
- `coverage`: 14,125 canonical paths and 18,457 mapping rows yield 712,744
  points, or 50.4597 percent overall. Code coverage is 423,382 points over
  7,306 code paths, or 57.9499 percent. Webhooks are 70.6 percent over their
  exact 231-path inventory; the bounded PAS AIS read subset is 44.2 percent
  over its six newly classified owning paths.
- `repository_state`: legacy remains clean and read-only. Laravel and Docker
  retain the approved staged rewrite. Current Laravel and planning changes are
  not committed or pushed.
- `verification_state=ais-webhook-and-read-parity-green;
  worklist-intake-boundary-green; fixed-ais-query-growth;
  fresh-301-migration-seed-schema-proof-green; coverage-50.4597;
  code-coverage-57.9499; terminal-time-guard-active`.

### 16.99 Hourly checkpoint - 2026-09-02 14:00 BST

- `current_problem`: finish the bounded orthoptic correspondence residual by
  porting the latest saved Examination finding strings into the real letter
  editor without guessing how structured Cover Test and Prism Fusion tables
  should be represented.
- `acceptance_condition`: the four source-exact text findings are available
  through a stable authenticated operation, only the latest visible
  Examination is considered, missing findings do not fall back to an older
  event, the request stays query-bounded, and the editor appends the selected
  finding without losing its existing body.
- `completed_evidence`: Convergence and Accommodation, Prism Reflex, Sensory
  Function, and Stereoacuity now expose their exact saved-snapshot strings.
  The correspondence editor has an on-demand accessible finding picker. Cover
  Test and Prism Fusion stay explicitly deferred behind a shared safe
  structured/table rendering contract. The exact 241-path feature cohort has
  been reconciled from its immutable manifest rather than inferred from stale
  feature totals.
- `current_work`: select the next bounded anterior or retina residual using
  exact current ledger evidence and direct legacy caller evidence.
- `next_item`: close the highest-yield safe anterior or retina residual with a
  migration confidence pack.
- `after_next`: audit copied vendored components for exact versions, reachability,
  major security risk, and a replacement or isolation decision.
- `blockers_and_deferrals`: Cover Test and Prism Fusion correspondence output
  remain deferred because the safe reusable table representation is not yet
  established. The prior one-shot browser attempt remains unresolved at a
  reused-fixture HTTP 500 boundary. Cypress, migrated-scale load, fidelity,
  UAT, and clinical sign-off remain later gates.
- `query_and_performance`: the service performs no more than five fixed
  queries. Direct authenticated requests used four to six queries depending on
  the finding and middleware path. The serving plan uses the intended indexes
  with no filesort, temporary table, group-wise maximum, or index hint.
- `tests`: the focused finding and correspondence pack passes 17 tests with
  296 assertions; the wider ledger, documentation, and finding pack passes 29
  tests with 559 assertions; all 30 JavaScript tests and the production
  frontend build pass. Pint and `git diff --check` pass. Existing SVG and
  large-chunk build warnings remain.
- `coverage`: 14,125 canonical paths and 18,476 mapping rows yield 713,115
  points, or 50.4859 percent overall. Code coverage is 423,554 points over
  7,306 code paths, or 57.9734 percent. The exact Examination, orthoptics, and
  ocular-surface cohort is 92.5 percent over its 241-path manifest.
- `repository_state`: legacy remains clean and read-only. Laravel and Docker
  retain the approved staged rewrite. Current Laravel and planning changes are
  not committed or pushed.
- `verification_state=orthoptic-correspondence-findings-green;
  latest-visible-examination-contract-green; fixed-query-growth;
  fresh-301-migration-seed-schema-proof-green; coverage-50.4859;
  code-coverage-57.9734; terminal-time-guard-active`.

### 16.100 Hourly checkpoint - 2026-09-02 15:00 BST

- `current_problem`: preserve the legacy Trial permission boundaries and make
  the normal list and participant reads indexable before assigning exact
  source-path credit.
- `acceptance_condition`: list, detail, create, manage, participant edit, and
  identified export access remain distinct; public listing is opt in and does
  not expose details; CSV export is bounded and spreadsheet safe; default list
  plans use same-row indexed projections without hints, filesorts, temporary
  tables, or query growth.
- `completed_evidence`: separate Trial capabilities are stored and enforced;
  public listing defaults off; identified export requires both export and
  trial-management access; user-controlled CSV cells are formula neutralized;
  stable route metadata covers all ten current Trial operations. A fresh
  seven-schema database ran all 302 migrations, the tiny seed, schema
  verification, and a rollback plus reapply of the new migration.
- `current_work`: reconcile the exact pinned OETrial inventory and publish only
  path-specific evidence for implemented behavior.
- `next_item`: close Trial ledger, feature, page, API, and working-out records,
  then stage the verified slice.
- `after_next`: select the next high-yield unblocked module from exact
  zero-coverage source paths and apply the migration confidence pack.
- `blockers_and_deferrals`: Trial delete, user-assignment mutation,
  non-intervention bulk status, popup, upload, and full cohort report behavior
  remain deferred rather than inferred. The prior one-shot browser attempt
  remains unresolved at a reused-fixture HTTP 500 boundary. Cypress,
  migrated-scale load, fidelity, UAT, and clinical sign-off remain later gates.
- `query_and_performance`: the default Trial and participant ordering plans use
  generated same-row values and their exact composite indexes. The list query
  count is unchanged between one and 51 trials. The plans have no filesort,
  temporary table, or index hint. CSV streams in 500-row chunks.
- `tests`: 14 Trial tests pass with 184 assertions. The combined Trial,
  settings, route-manifest, and migration-policy pack passes 35 tests with
  2,679 assertions. All 30 JavaScript tests and the clean disposable production
  build pass. The clean-room migration rollback and reapply also pass.
- `coverage`: before the active Trial reconciliation, 14,125 canonical paths
  and 18,476 mapping rows yield 713,515 points, or 50.5142 percent overall.
  Code coverage is 423,654 points over 7,306 code paths, or 57.9871 percent.
- `repository_state`: legacy remains clean and read-only. Laravel and Docker
  retain the approved staged rewrite. Current Laravel and planning changes are
  not committed or pushed.
- `verification_state=trial-authorization-boundary-green;
  trial-default-query-plans-green; fresh-302-migration-seed-schema-green;
  migration-rollback-reapply-green; coverage-50.5142;
  code-coverage-57.9871; trial-ledger-reconciliation-active;
  terminal-time-guard-active`.

### 16.101 Hourly checkpoint - 2026-09-02 17:00 BST

- `current_problem`: preserve the legacy event-creation permission boundary and
  the clinically important deceased-patient invariant across every current
  direct entry route, not only the patient-page control.
- `acceptance_condition`: a user needs explicit event-creation capability and
  a living patient before event choices or specialist entry points are usable;
  denied and deceased patients must fail before payload validation; the default
  migration must preserve current rewrite users until the legacy permission
  import is mapped; and the seven-schema proof must remain clean.
- `completed_evidence`: one shared gate now governs patient and event page
  choices, child event creation, core event entry, Consent, CVI, and Biometry.
  The UI retains the familiar read-only state when creation is unavailable.
  The new permission defaults off for new users, while the migration explicitly
  enables existing rewrite users to avoid an accidental release-time lockout.
  A clean namespace ran all 303 migrations, the tiny seed, schema verification,
  rollback of the newest migration, reapplication, and schema verification.
- `current_work`: stage the verified event-creation slice and select the next
  exact zero-coverage source cohort that is already represented by working
  behavior or can be closed without guessing clinical rules.
- `next_item`: reconcile the source-exact patient event creation helpers and
  views against the new shared boundary, then implement only a bounded missing
  behavior justified by direct legacy evidence.
- `after_next`: continue the highest-yield safe patient-summary or module
  residual, preserving the fixed queue and migration confidence pack.
- `blockers_and_deferrals`: exact import mapping for legacy
  `OprnCreateEpisode`, draft restoration, full service and subspecialty event
  selection, and worklist-step context remain open. The prior one-shot browser
  attempt remains unresolved at a reused-fixture HTTP 500 boundary. Cypress,
  migrated-scale load, fidelity, UAT, and clinical sign-off remain later gates.
- `query_and_performance`: denied patient pages skip event-type, site, and child
  creation-choice queries. The authorization gate adds no list query and uses
  no optimizer hint, filesort, or temporary table.
- `tests`: the affected backend pack passes 93 tests with more than 4,700
  assertions; the documentation, ledger, and manifest pack passes 36 tests
  with 2,956 assertions; all 30 JavaScript tests and the production frontend
  build pass. The first disposable migration setup was interrupted before its
  ledger was complete. A second setup exposed MariaDB 11.8's default
  `utf8mb4_uca1400_ai_ci` collation conflicting with the application's
  `utf8mb4_unicode_ci` contract. Recreating the exact disposable schemas with
  the application collation produced the complete green 303-migration proof.
- `coverage`: 14,125 canonical paths and 18,632 mapping rows yield exact
  behavioral coverage of 51.5241 percent. Code coverage is 59.1191 percent over
  7,306 code paths. F-CORE-AUTH is 32.7167 percent over its exact 60-path
  inventory, with the remaining behaviors explicitly deferred.
- `repository_state`: legacy remains clean and read-only. The seven exact
  disposable `oe_eventauth_20260902_*` schemas were deleted after verifying
  zero active sessions; retained wave databases and all Docker volumes remain.
  Laravel and Docker retain the approved staged rewrite. Nothing is committed
  or pushed.
- `verification_state=event-creation-capability-green;
  deceased-patient-invariant-green; fresh-303-migration-seed-schema-green;
  migration-rollback-reapply-green; frontend-unit-and-build-green;
  coverage-51.5241; code-coverage-59.1191; terminal-time-guard-active`.

### 16.102 Hourly checkpoint - 2026-09-02 17:45 BST

- `current_problem`: restore the separate familiar patient-details surface
  without adding eager contact queries to the heavily used clinical overview or
  allowing one institution to read another institution's contact assignments.
- `acceptance_condition`: the demographics control opens a named and owned
  details page; the clinical overview remains visually unchanged; associated
  contacts load only on demand, are institution scoped and bounded; and query
  count does not grow between small and large fixtures.
- `completed_evidence`: the patient-details page reuses one bounded patient
  presenter, keeps the existing overview unchanged, exposes the configured
  identifier display, and lazily loads GP, practice, and associated contacts.
  The contact API now validates patient institution ownership, reads at most
  101 live assignments, returns at most 100 plus an overflow marker, and keeps
  the existing contact mutations separate.
- `current_work`: stage the verified patient-details slice and select the next
  source-exact patient episode or ordinary clinical residual that can be closed
  without guessing migration or clinical rules.
- `next_item`: reconcile the bounded patient episode and event group sources
  against the existing timeline and episode services, then implement only the
  missing familiar behavior supported by those sources.
- `after_next`: resume the fixed vision, refraction, history, webhook, anterior,
  retina, and operation residual queue using the migration confidence pack.
- `blockers_and_deferrals`: date of death, ethnicity, patient telephone, next
  of kin, commissioning bodies, complete episode grouping, and identifier
  ordering remain open. The prior one-shot browser attempt remains unresolved
  at a reused-fixture HTTP 500 boundary. Cypress, migrated-scale load, fidelity,
  UAT, and clinical sign-off remain later gates.
- `query_and_performance`: associated contacts use fixed query growth, have no
  filesort or temporary table, expose the composite patient index as a possible
  index, and use no optimizer hint. A skewed small fixture may legitimately use
  an ordered primary-key scan, so the migrated-data gate remains mandatory.
- `tests`: the combined patient, contact, manifest, break-glass, and event
  timeline pack passes 54 tests with 3,038 assertions. All 30 JavaScript tests
  and the 837-module production frontend build pass. Ledger integrity passes.
- `coverage`: 14,125 canonical paths and 18,632 mapping rows yield exact
  behavioral coverage of 51.5834 percent. Code coverage is 59.2338 percent over
  7,306 code paths. F-CORE-PATIENT-SEARCH is 73.7073 percent over its corrected
  exact 41-path inventory.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. The three-container
  wave stack remains running, all other recorded rewrite containers remain
  stopped, and no volume was removed. Nothing is committed or pushed.
- `verification_state=patient-details-route-green;
  associated-contact-institution-boundary-green;
  associated-contact-query-bound-green; frontend-unit-and-build-green;
  ledger-14125-canonical-18632-rows; coverage-51.5834;
  code-coverage-59.2338; terminal-time-guard-active`.

### 16.103 Hourly checkpoint - 2026-09-02 18:15 BST

- `current_problem`: restore authoritative episode chronology and the familiar
  All Episodes patient-details panel without deriving group-wise dates from
  events or adding an unbounded patient graph read.
- `acceptance_condition`: the initial schema packet contains episode start and
  end dates plus the serving index; the application owns their lifecycle; the
  familiar grouped table and complete open and closed counts are present; rows
  and queries remain bounded; and no optimizer hint or database automation is
  introduced.
- `completed_evidence`: the episode row now stores start and end dates with its
  history twin. Application-created episodes default start date in PHP. Only
  the latest Clinic Outcome controls current status and end date. Patient
  details read at most 101 rows, render at most 100, group by specialty, and
  expose full indexed counts with an explicit overflow state.
- `current_work`: stage the verified episode slice and inspect the exact zero
  and low-credit source inventory for the highest-yield behavior already
  supported by target code and tests before opening another schema change.
- `next_item`: select and close one source-exact ordinary clinical cohort using
  its representative happy path, authorization or invariant proof, query
  growth check, serving-plan check, and browser-smoke accounting.
- `after_next`: continue the fixed vision, refraction, history, webhook,
  anterior, retina, and operation residual queue.
- `blockers_and_deferrals`: clickable episode rows, generic legacy episode
  traversal, exact styling, migrated-volume plan proof, and browser proof remain
  open. The prior one-shot browser attempt remains unresolved at a reused
  fixture HTTP 500 boundary. Cypress, fidelity, UAT, and clinical sign-off
  remain later gates.
- `query_and_performance`: the summary projects only displayed fields, caps the
  ordered episode read, uses fixed query growth, exposes
  `ix_episode_patient_summary` as a possible index, and proves no filesort or
  temporary table. A skewed tiny fixture may legitimately choose the primary
  key, so migrated-volume verification remains mandatory and no index is
  forced.
- `tests`: a fresh namespace passes all 303 migrations, tiny seed, and
  seven-schema verification. The combined episode, patient, contact,
  Break Glass, event timeline, and migration-policy pack passes 39 tests with
  450 assertions. All 30 JavaScript tests and the 837-module production build
  pass. Ledger integrity passes.
- `coverage`: 14,125 canonical paths and 18,632 mapping rows yield exact
  behavioral coverage of 51.5941 percent. Code coverage is 59.2543 percent over
  7,306 code paths. F-CORE-PATIENT-SEARCH is 74.4524 percent over its exact
  42-path inventory and F-CORE-CURRENT-CONTEXT is 78.0000 percent over 13 paths.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. The three-container
  wave stack remains running, all other recorded rewrite containers remain
  stopped, and no volume was removed. Nothing is committed or pushed.
- `verification_state=episode-schema-packet-green;
  authoritative-episode-dates-green; episode-summary-query-bound-green;
  hidden-database-automation-guard-green; frontend-unit-and-build-green;
  ledger-14125-canonical-18632-rows; coverage-51.5941;
  code-coverage-59.2543; terminal-time-guard-active`.

### 16.104 Browser proof closure - 2026-09-02 18:20 BST

- `current_problem`: close the recorded no-retry browser gap without reusing a
  contaminated fixture or leaving another application stack running.
- `acceptance_condition`: a current-source disposable web container serves the
  fresh 303-migration namespace; one Playwright journey logs in and reads the
  patient details, bounded All Episodes, and associated contacts surfaces; no
  retry is used; and the disposable container is stopped afterward.
- `completed_evidence`: the direct PHP development server retained the
  container-provided test key and served `/login` successfully. One Playwright
  1.55 journey logged in, loaded patient 1 details, and read Personal Details,
  All Episodes, General Practitioner, and Associated contacts. The All Episodes
  panel showed one open Cataract episode with its authoritative start date.
- `current_work`: select the next source-exact bounded clinical cohort and open
  only its migration confidence pack.
- `next_item`: close one useful event-image, medication, vision, refraction,
  history, webhook, anterior, retina, or operation residual already supported
  by authoritative legacy evidence.
- `after_next`: continue one safe vertical slice at a time, prioritising real
  user behavior rather than low-value percentage movement.
- `blockers_and_deferrals`: clickable episode rows, exact styling, migrated-data
  plan proof, Cypress, fidelity, UAT, and clinical sign-off remain later gates.
  The earlier HTTP 500 was a disposable harness configuration failure: the
  `artisan serve` child did not retain the injected application key. It was not
  an application-route failure.
- `query_and_performance`: the browser used the existing bounded patient-detail
  services. It introduced no new application query, index, cache, or hint.
- `tests`: one no-retry Playwright 1.55 journey passed all nine actions. It
  created no clinical data and no screenshots. The disposable web container
  was stopped, leaving only the capped web, database, and Redis wave stack.
- `coverage`: unchanged at 51.5941 percent overall and 59.2543 percent for code
  across 14,125 canonical paths and 18,632 mapping rows.
- `repository_state`: no diagnostic source change remains. Existing Laravel,
  Docker, and planning work stays staged. Nothing is committed or pushed.
- `verification_state=no-retry-browser-green; patient-details-browser-green;
  episode-panel-browser-green; associated-contacts-browser-green;
  disposable-web-stopped; terminal-time-guard-active`.

### 16.105 Hourly checkpoint - 2026-09-02 19:00 BST

- `current_problem`: reconcile implemented zero-credit shared and clinical
  paths without inflating coverage from inventory or name-only matches.
- `acceptance_condition`: every claimed path is read against the pinned source
  and current target behavior or tests; unmatched behavior stays at zero; no
  broad extrapolation is permitted.
- `completed_evidence`: direct source review closed CXL History, medication
  attribute factories, shared settings, contacts, current context, language,
  closed genetics lookups, Eye laterality, the PAS AIS read field, and shared
  checklist widgets. The dedicated legacy Safeguarding dashboard is absent and
  remains uncredited.
- `current_work`: inspect the next exact source-backed zero or low-credit path
  already supported by current clinical or API behavior.
- `next_item`: close one bounded source-exact shared, clinical, or API cohort
  with its direct behavior, authorization or invariant, and focused proof.
- `after_next`: implement the next missing ordinary vision, refraction,
  history, webhook, anterior, retina, or operation slice when reconciliation
  cannot prove an existing replacement.
- `blockers_and_deferrals`: the rough 70 percent aim is not reachable by
  accounting alone. PAS patient and contact writes, the Safeguarding dashboard,
  rich settings HTML, environment overrides, tooltips, CXL Outcome and dataset
  extraction, exact visuals, UAT, and migrated-scale proof remain deferred.
- `query_and_performance`: enum contracts add no queries. Existing AIS reads
  have fixed query count and no filesort, temporary table, or optimizer hint.
  Checklist chronology is indexed and join-free. Settings caching invalidates
  after commit and contact reads remain bounded.
- `tests`: ledger integrity passes three tests with 47 assertions. The focused
  settings, contacts, context, language and AIS, genetics, Eye, xAPI, checklist,
  and audit baseline packs all pass, in addition to the 18:20 no-retry browser
  proof.
- `coverage`: 14,125 canonical paths and 18,632 mapping rows yield exact
  behavioral coverage of 51.8961 percent. Code coverage is 59.8115 percent over
  7,306 code paths. F-OPHCO-CHECKLIST is 97.8378 percent over its exact 74-path
  inventory.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running and no volume was removed. Nothing is
  committed or pushed.
- `verification_state=source-exact-reconciliation-green;
  ledger-integrity-green; no-index-hints; ledger-14125-canonical-18632-rows;
  coverage-51.8961; code-coverage-59.8115; terminal-time-guard-active`.

### 16.106 Hourly checkpoint - 2026-09-02 20:00 BST

- `current_problem`: close source-backed gaps while keeping every canonical
  inventory row aligned with its highest reviewed evidence.
- `acceptance_condition`: each claimed legacy path has direct target behavior
  and focused proof, and the canonical row carries the highest reviewed score
  without removing secondary feature ownership.
- `completed_evidence`: all 27 concrete legacy webhook identities are exact.
  Patient medication initial rendering performs no medication queries and its
  browser proof makes one shared lazy request for both panels. Medication
  attributes, Trial, and Therapy evidence is reconciled. The ledger verifier
  now rejects a canonical score below reviewed secondary evidence, leaving no
  canonical row below its reviewed maximum and no zero canonical row backed by
  a positive reviewed secondary.
- `current_work`: complete the exact xAPI patient lookup by identifier with
  padding validation, authorization, bounded queries, manifest ownership, and
  pinned source evidence.
- `next_item`: stage and reconcile the xAPI identifier slice after its full
  focused pack, query plan, privacy-bounded audit, and ledger gates pass.
- `after_next`: continue one authoritative codeable-concept, CVI, or operation
  slice without opening broad speculative scope.
- `blockers_and_deferrals`: the rough 70 percent aim is not reachable by
  accounting alone. Broad inference, exact visuals, UAT, and migrated-data load
  remain deferred.
- `query_and_performance`: no new page query was introduced. The patient
  medication browser journey makes one shared request. Trial reads remain
  bounded. The identifier lookup must use its unique key without filesort,
  temporary tables, or optimizer hints.
- `tests`: webhook passes 68 tests with 475 assertions; patient medication
  passes five with 101 plus browser proof; medication attributes pass nine with
  71; Trial passes 23 with 296; Therapy and ledger pass six with 78; and ledger
  integrity passes four with 50.
- `coverage`: 14,125 canonical paths and 18,631 mapping rows yield exact
  behavioral coverage of 51.9832 percent. Code coverage is 59.9677 percent over
  7,306 code paths.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=canonical-maximum-invariant-green;
  canonical-below-reviewed-maximum-zero;
  canonical-zero-with-positive-secondary-zero; no-index-hints;
  ledger-14125-canonical-18631-rows; coverage-51.9832;
  code-coverage-59.9677; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.107 Hourly checkpoint - 2026-09-02 21:00 BST

- `current_problem`: complete source-compatible xAPI allergy and history-risk
  state writes without exposing their bookkeeping episodes to clinical users.
- `acceptance_condition`: authorization and current-institution checks precede
  writes; full-state validation, exact code systems, audit, webhooks, padded
  fuzzy dates, history, and bounded indexed change-tracker reuse are proved.
- `completed_evidence`: xAPI now accepts complete allergy and history-risk
  states, preserves negative entries, writes Examination events through one
  hidden change-tracker episode per patient, emits audit and webhook effects,
  and returns source-compatible code-system lists and detail resources. The
  live generated key and plain history snapshot pass rollback and reapplication
  plus seven-schema verification across all 304 migrations.
- `current_work`: reconcile only the pinned xAPI resource and test paths now
  directly backed by the completed behavior and focused tests.
- `next_item`: stage the exact xAPI evidence reconciliation after the canonical
  maximum and ledger integrity gates pass.
- `after_next`: select the next authoritative ordinary clinical or operation
  residual and close one migration confidence pack.
- `blockers_and_deferrals`: generated OpenAPI, broad remaining code systems,
  browser proof for this API-only slice, and migrated-scale load remain later.
  The rough 70 percent aim remains subordinate to exact evidence.
- `query_and_performance`: small and large full-state writes have the same
  query count below the declared budget of 45. Change-tracker lookup selects
  its unique generated key without filesort, temporary tables, or hints.
- `tests`: the combined xAPI, schema, and patient episode pack passes 27 tests
  with 419 assertions. Direct schema verification passes all seven schemas and
  304 migrations. The newest migration rolls back and reapplies cleanly.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 52.0492 percent. Code coverage is 60.0582 percent over
  7,306 code paths.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=xapi-clinical-state-green;
  exact-code-system-resources-green; schema-seven-304-green;
  migration-rollback-reapply-green; fixed-query-growth-under-45;
  no-filesort-temporary-or-index-hints; ledger-14125-canonical-18635-rows;
  coverage-52.0492; code-coverage-60.0582;
  only-three-wave-containers-running; terminal-time-guard-active`.

### 16.108 Hourly checkpoint - 2026-09-02 21:45 BST

- `current_problem`: replace uncached request-time xAPI class discovery without
  copying its unbounded user catalogue or losing supported code-system parity.
- `acceptance_condition`: every authoritative low-cardinality system has named
  authenticated index and detail routes, active filtering, source identifiers,
  bounded output, fixed query growth, and an index plan without hints.
- `completed_evidence`: fourteen additional source code systems now use an
  explicit catalogue backed by rewrite models. Lists stop with HTTP 413 rather
  than silently truncating above 1,000 concepts. Supported detail resources
  retain source field shapes and legacy identifiers.
- `current_work`: review source patient and associated-contact writes against
  the target identity, typed-address, and institution/site location schema.
- `next_item`: open that write slice only if the normalized schema and clinical
  ownership rules are authoritative; otherwise record the boundary and move on.
- `after_next`: close the next source-exact ordinary clinical or operation
  residual with a migration confidence pack.
- `blockers_and_deferrals`: user discovery remains unbounded in the source and
  needs pagination. Address type and specialty type lack complete target lookup
  schemas. Institution legacy metadata, generated OpenAPI, API browser proof,
  and migrated-scale load remain later. The rough 70 percent aim remains
  subordinate to exact evidence.
- `query_and_performance`: the actual limited catalogue query has constant query
  count below five between small and large fixtures. Its picker index avoids
  filesort and temporary tables without an optimizer hint.
- `tests`: the combined code-system and clinical-state pack passes 16 tests with
  200 assertions. Overflow, inactive records, list and detail identifiers,
  query growth, and the execution plan are covered.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 52.3124 percent. Code coverage is 60.3945 percent over
  7,306 code paths.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=xapi-code-systems-green; overflow-413-green;
  fixed-query-growth-under-5; no-filesort-temporary-or-index-hints;
  ledger-14125-canonical-18635-rows; coverage-52.3124;
  code-coverage-60.3945; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.109 Hourly checkpoint - 2026-09-02 22:08 BST

- `current_problem`: establish a safe PAS Patient V2 and V3 core without
  silently discarding normalized clinical records whose ownership is not yet
  authoritative.
- `acceptance_condition`: bounded authenticated XML intake must resolve every
  supplied typed identifier, reject conflicting identities, preserve partial
  updates, write atomically, remain query bounded, and expose named owned
  application surfaces.
- `completed_evidence`: V2 URL identity and V3 typed identifier lists now map
  through portable code assignment data. Core demographics, death state,
  phone, mobile, email, identifiers, and primary institution are written in one
  transaction with a privacy-bounded audit record. Unsupported nested records
  fail explicitly rather than being ignored.
- `current_work`: stage the PAS Patient slice and rank remaining zero and
  low-credit source cohorts by implementation value and safe exact yield.
- `next_item`: open the highest-yield source-exact cohort whose behavior and
  schema ownership can be established without guessing.
- `after_next`: close another ordinary shared clinical or integration slice
  with a migration confidence pack.
- `blockers_and_deferrals`: normalized addresses, related contacts, GP and
  practice, language and interpreter, risks, configurable resolver and
  deletion policy, concurrent duplicate intake, and worklist projection refresh
  remain governed by DIV-472. The rough 70 percent aim remains subordinate to
  exact evidence.
- `query_and_performance`: identifier resolution limits the database to 17
  candidate rows and sorts at most 16 patient IDs in PHP. Query count stays
  fixed below 32 with 100 unrelated patients, and the actual composite-index
  plan uses neither filesort nor temporary table nor optimizer hint.
- `tests`: the PAS Patient pack passes seven tests with 58 assertions. Scoped
  Pint passes 14 files. The 305th migration, tiny seed, route manifest, combined
  PAS and xAPI regression pack, and complete ledger integrity gate pass.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 52.4536 percent. Code coverage is 60.5272 percent over
  7,306 code paths. The directly assigned PASAPI set is 63.0233 percent over 43
  paths.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=pas-patient-7-tests-58-assertions-green;
  pint-14-files-green; migration-305-and-tiny-seed-green;
  fixed-query-growth-under-32; no-filesort-temporary-or-index-hints;
  ledger-14125-canonical-18635-rows; coverage-52.4536;
  code-coverage-60.5272; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.110 Hourly checkpoint - 2026-09-02 22:48 BST

- `current_problem`: restore patient medication adherence because the pinned
  controller and views remain reachable even though the 2017 migration moved
  the backing table into the archive.
- `acceptance_condition`: preserve the five ordered levels and bounded comments
  with current-institution ownership, explicit edit permission, concurrency
  protection, history, privacy-bounded audit, fixed queries and a working page.
- `completed_evidence`: the medication page and summary panel present current
  adherence. Writes serialize first creation on the patient, use an optimistic
  version, reject stale or unauthorized input, and never put comments in the
  audit payload. Source rows previously labeled obsolete now cite the working
  replacement.
- `current_work`: stage the adherence slice and rank the next exact ordinary
  clinical or operation residual.
- `next_item`: open one bounded source-exact slice whose clinical and storage
  rules can be established without inference.
- `after_next`: continue the fixed functional queue through safe integrated
  checkpoints until the 10:30 scope freeze.
- `blockers_and_deferrals`: existing archive adherence rows require an explicit
  identity, duplicate and retention mapping under DIV-473. The reused browser
  fixture has migration-ledger drift around `episode.start_date`; a clean
  disposable schema passed instead. Migrated-volume tuning, exact visual
  fidelity and UAT remain later gates.
- `query_and_performance`: presentation performs exactly two reads through one
  hundred unrelated adherence rows. Both centralized plans select the intended
  indexes and use neither filesort, temporary table nor optimizer hint.
- `tests`: the focused backend pack passes 12 tests with 258 assertions and
  scoped Pint passes. All 30 JavaScript tests, the 837-module production build,
  clean 306-migration tiny seed, and a Playwright write-reload journey pass.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 52.4752 percent. Code coverage is 60.5546 percent over
  7,306 code paths. The shared medication feature is 55.7077 percent over its
  exact 195 paths.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=adherence-pack-12-tests-258-assertions-green;
  clean-306-migrations-and-tiny-seed-green; playwright-write-reload-green;
  fixed-two-query-read; no-filesort-temporary-or-index-hints;
  ledger-14125-canonical-18635-rows; coverage-52.4752;
  code-coverage-60.5546; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.111 Hourly checkpoint - 2026-09-02 23:18 BST

- `current_problem`: restore the reachable Operation Booking Effective Use of
  Resources decision and report without copying the legacy row-by-row report
  lookups or trusting a browser-supplied clinical result.
- `acceptance_condition`: preserve the three-question, eye-specific sequential
  decision, gate configured Cataract bookings on a same-eye pass, freeze a
  booked assessment, and expose the six-column report with its date and
  consultant filters through explicit authorization and bounded reads.
- `completed_evidence`: stable-code questions and answers now drive a
  server-calculated result with optimistic versioning, history and
  privacy-bounded audit. Booking reads the effective institution or global
  `need_eur` rule. The dedicated report is institution scoped, keyset paginated,
  CSV safe, and retains the six legacy fields.
- `current_work`: reconcile and stage the complete EUR slice, then rank the next
  exact ordinary Operation Booking or clinical residual.
- `next_item`: close remaining source-backed Operation Booking residuals that do
  not rework already functional booking paths.
- `after_next`: return to the fixed ordinary queue, selecting a bounded
  vision/refraction/history or webhook residual whose rules are authoritative.
- `blockers_and_deferrals`: historical EUR results and responses need approved
  duplicate and missing-configuration cutover rules before full migration credit.
  Representative migrated-volume report latency remains a later scale gate.
- `query_and_performance`: report candidates use one bounded indexed query,
  consultant and identifier inputs are capped, and plan verification finds no
  filesort, temporary table, or optimizer hint. PDF and image work is unchanged.
- `tests`: the combined EUR and neighbouring Operation Booking pack passes 38
  tests with 3,102 assertions. The ledger pack passes four tests with 50
  assertions, all 30 JavaScript tests pass, and the 838-module production build
  passes with only the existing EventView chunk warning.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 52.6012 percent. Code coverage is 60.6901 percent over
  7,306 code paths.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=eur-pack-38-tests-3102-assertions-green;
  ledger-4-tests-50-assertions-green; javascript-30-green;
  production-build-838-modules-green; no-filesort-temporary-or-index-hints;
  ledger-14125-canonical-18635-rows; coverage-52.6012;
  code-coverage-60.6901; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.112 Hourly checkpoint - 2026-09-02 23:26 BST

- `current_problem`: account for copied legacy browser and test distributions
  without treating third-party files as newly ported application behavior.
- `acceptance_condition`: identify an exact pinned distribution boundary,
  prove that every credited legacy path belongs to it, prove the replacement
  dependency or retirement, and keep first-party code coverage separate.
- `completed_evidence`: an explicit dependency map closes 848 exact paths in
  Chosen, Dialog Polyfill, Font Awesome, Google Code Prettify, jQuery
  Mousewheel, jQuery Placeholder, jQuery UI, jQuery Cookie, jQuery Tags Input,
  Lodash, Mocha, RRule, and the Sinon built distribution. The ledger test
  proves that each mapped path exists, is classified as a vendored dependency,
  has exact evidence, and has an absent copied target dependency.
- `current_work`: return to source-backed first-party behavior after staging
  the dependency evidence and plan checkpoint.
- `next_item`: close a bounded clinically important visual-acuity residual with
  authoritative calculation rules and fixed query growth.
- `after_next`: continue through the fixed ordinary clinical queue, selecting
  the highest-value safe first-party slice rather than more inventory credit.
- `blockers_and_deferrals`: legacy jQuery and EventEmitter copies remain because
  EyeDraw still consumes them. PDF.js remains because document-viewer parity is
  not proven. Those 344 paths stay at zero instead of receiving speculative
  retirement credit.
- `query_and_performance`: no runtime query or index changed. The dependency
  evidence adds no request path and no optimizer hint.
- `tests`: the dependency and ledger pack passes seven tests with 6,350
  assertions. Scoped Pint passes. Containerized production dependency audits
  report zero known Composer or npm advisories in the locked production sets.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 58.6047 percent. Code coverage remains 60.6901
  percent over 7,306 code paths; vendored-dependency coverage is 71.0570
  percent over 1,192 paths.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=dependency-ledger-7-tests-6350-assertions-green;
  production-composer-audit-zero-advisories;
  production-npm-audit-zero-advisories; ledger-14125-canonical-18635-rows;
  coverage-58.6047; code-coverage-60.6901;
  vendored-dependency-coverage-71.0570;
  only-three-wave-containers-running; terminal-time-guard-active`.

### 16.113 Hourly checkpoint - 2026-09-02 23:48 BST

- `current_problem`: restore the clinically important best-corrected
  visual-acuity loss warning since a patient's first completed intravitreal
  injection without copying the legacy full-history loops.
- `acceptance_condition`: preserve the exact five-letter threshold and message,
  maintain authoritative injection ownership and time in application code,
  bound both-eye reads, prove fixed query growth and usable indexes, and retain
  historical import behavior.
- `completed_evidence`: Visual Acuity now compares each eye's first completed
  injection baseline with the best corrected value recorded since that
  injection. Intravitreal Injection clinical writes and historical imports
  maintain patient and performed-at projection fields. A database constraint
  rejects invalid injection ownership, and history twins retain the projection.
- `current_work`: stage the verified slice and select the next source-exact
  first-party behavior from the fixed ordinary clinical queue.
- `next_item`: close the highest-value authoritative vision, refraction,
  history, anterior, retina, or operation residual that fits one migration
  confidence pack.
- `after_next`: reconcile only exact pinned paths backed by that behavior, then
  repeat the focused test and query-plan gates.
- `blockers_and_deferrals`: historical injection projection backfill remains a
  cutover task. OEscape unit conversion, header and hover behavior, history
  graph geometry, exact visual fidelity, migrated-volume load, and clinical UAT
  remain governed by DIV-242 and the later gates.
- `query_and_performance`: both eyes require at most four bounded queries. The
  first-injection and best-since-injection reads use same-row projection and
  covering indexes, have fixed growth through 100 unrelated history rows, and
  use no filesort, temporary table, optimizer hint, or forced index.
- `tests`: the affected backend pack passes 89 tests with 1,405 assertions; all
  32 tiny query budgets pass; all 30 JavaScript tests and the 838-module
  production build pass; the dependency and ledger pack passes seven tests
  with 6,350 assertions; and a fresh seven-schema namespace passes all 308
  migrations, the tiny seed, and schema verification.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 58.6079 percent. Code coverage is 60.6961 percent
  over 7,306 code paths. The exact Visual Acuity and Refraction cohort is
  26.1977 percent across 258 unique paths.
- `repository_state`: the exact disposable seven-schema namespace was removed
  after zero active sessions were confirmed. Legacy remains clean and
  read-only. Laravel, Docker, and planning repositories retain the approved
  staged rewrite. Only the three capped wave containers remain running.
  Nothing is committed or pushed.
- `verification_state=va-injection-loss-pack-89-tests-1405-assertions-green;
  query-plan-32-green; javascript-30-green;
  production-build-838-modules-green;
  clean-seven-schema-308-migrations-tiny-seed-green;
  ledger-14125-canonical-18635-rows; coverage-58.6079;
  code-coverage-60.6961; no-filesort-temporary-or-index-hints;
  disposable-schema-cleanup-verified; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.114 Hourly checkpoint - 2026-09-03 00:18 BST

- `current_problem`: restore the clinically useful Therapy Application report
  without implying that internal document generation proves external funding
  delivery.
- `acceptance_condition`: provide named authenticated page, API, and CSV
  surfaces; scope them to the current institution and at most 366 days; retain
  optional MR-firm filtering; keep CSV safe; and prove bounded indexed reads.
- `completed_evidence`: the report presents clinical application facts and
  internal generation status and date. External submission, pending email, and
  first or last injection delivery semantics remain explicitly deferred rather
  than being inferred from internal workflow state.
- `current_work`: inspect the exact unowned patient and event presentation
  paths, map only contracts already proved by the target, and open the next
  authoritative ordinary clinical slice.
- `next_item`: reconcile directly evidenced patient and event presentation
  paths without crediting untouched automated inventory.
- `after_next`: continue the fixed vision, refraction, history, anterior,
  retina, and operation queue one migration confidence pack at a time.
- `blockers_and_deferrals`: external funding submission, pending email, first
  and last injection semantics, cross-institution reporting, exact browser UI,
  migrated-volume load, and UAT remain later gates.
- `query_and_performance`: report reads stay fixed from one to 31 applications.
  Current-institution, date, and optional firm filters have same-row covering
  indexes and use no filesort, temporary table, optimizer hint, or forced
  index. All 34 registered query-plan budgets pass.
- `tests`: the focused report pack passes four tests with 89 assertions; the
  affected integrated pack passes 52 tests with 3,120 assertions; all 30
  JavaScript tests and the 839-module production build pass; and a fresh
  seven-schema namespace passes all 308 migrations, the tiny seed, and schema
  verification.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 58.6171 percent. Code coverage is 60.7139 percent
  over 7,306 code paths. Therapy Application coverage is 52.2864 percent over
  213 unique canonical paths.
- `repository_state`: the exact disposable schema namespace and clean build
  volume were removed after verification. Legacy remains clean and read-only.
  Laravel, Docker, and planning repositories retain the approved staged
  rewrite. Only the three capped wave containers remain running. Nothing is
  committed or pushed.
- `verification_state=therapy-report-focused-4-tests-89-assertions-green;
  integrated-52-tests-3120-assertions-green; query-plan-34-green;
  javascript-30-green; production-build-839-modules-green;
  clean-seven-schema-308-migrations-tiny-seed-green;
  ledger-14125-canonical-18635-rows; coverage-58.6171;
  code-coverage-60.7139; no-filesort-temporary-or-index-hints;
  disposable-schema-cleanup-verified; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.115 Hourly checkpoint - 2026-09-03 00:48 BST

- `current_problem`: retire the copied PDF.js distribution without losing the
  authenticated event-document workflow or weakening file response security.
- `acceptance_condition`: every pinned PDF.js path has exact replacement
  evidence, the current protected PDF response is authorized and sandboxed,
  the browser build has no direct PDF.js dependency, and remaining live
  vendored dependencies receive no credit.
- `completed_evidence`: all 337 PDF.js distribution paths map to the existing
  event-scoped upload and authorized patient and event view route. The response
  retains the recorded PDF MIME type, inline disposition, nosniff, private
  no-store caching, and restrictive sandbox CSP. Nine exact zero-behavior PHP
  blobs have separate pinned-SHA retirement proof. Familiar patient header AIS,
  allergy, accessibility, deceased, and Break Glass flags are also bounded and
  verified.
- `current_work`: reconcile only direct patient and event shell equivalence,
  then move to the next first-party clinical cohort.
- `next_item`: map only directly proven patient and event shell source paths.
- `after_next`: close the next bounded vision, refraction, history, anterior,
  retina, or operation migration confidence pack.
- `blockers_and_deferrals`: seven copied EyeDraw dependency paths remain at
  zero because active consumers still need them. Exact PDF rendering fidelity,
  broad patient and event visual parity, migrated-scale load, UAT, and clinical
  sign-off remain later gates.
- `query_and_performance`: this replacement adds no server query or rendering
  process. It reuses the existing protected response and the browser native PDF
  viewer. No optimizer hint or forced index is introduced.
- `tests`: the focused dependency, attachment, document, and ledger pack passes
  32 tests with 8,677 assertions; all 33 JavaScript tests and the 840-module
  production build pass.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 61.0784 percent. Code coverage is 60.8600 percent,
  and vendored-dependency coverage is 99.3289 percent.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=pdf-and-ledger-32-tests-8677-assertions-green;
  patient-header-javascript-33-tests-green; production-build-840-modules-green;
  ledger-14125-canonical-18635-rows; coverage-61.0784;
  code-coverage-60.8600; vendored-dependency-coverage-99.3289;
  protected-response-security-headers-green;
  no-filesort-temporary-or-index-hints; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.116 Integrated checkpoint - 2026-09-03 00:50 BST

- `current_problem`: the event editor eagerly imported every clinical element,
  making every event open download and parse a 1,233.67 KiB minified page chunk.
- `acceptance_condition`: load only element components present on the current
  event, preserve deterministic element resolution and event icons, and fail a
  production build if the central EventView chunk exceeds 100 KiB.
- `completed_evidence`: EventView now uses cached async components from a lazy
  module map. A shared event-code helper keeps current semantic icons consistent
  across EventView, the event sidebar, patient overview, add-event popup, and
  device upload. The EventView chunk is now 70.98 KiB minified and 20.58 KiB
  gzip, down about 94 percent and 92 percent respectively. Eleven patient and
  event shell paths and sixteen direct legacy bitmap variants have conservative
  partial ledger evidence.
- `current_work`: open the next authoritative first-party clinical slice.
- `next_item`: close one bounded vision, refraction, history, anterior, retina,
  or operation migration confidence pack.
- `after_next`: reconcile only the exact pinned paths directly exercised by that
  completed slice, then take the next fixed queue item.
- `blockers_and_deferrals`: exact bitmap rendering, event date editing, legacy
  episode grouping, visual fidelity, migrated-scale load, UAT, and clinical
  sign-off remain later gates.
- `query_and_performance`: this change adds no server query. It removes unused
  initial JavaScript from every event view and introduces a hard production
  bundle budget. No optimizer hint or forced index is introduced.
- `tests`: the EventView performance pack passes three tests with 38 assertions,
  all 35 JavaScript tests pass, the 841-module production build passes its new
  bundle gate, and the ledger integrity pack passes five tests with 114
  assertions.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 61.1524 percent. Code coverage is 60.9483 percent.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=event-view-performance-3-tests-38-assertions-green;
  javascript-35-tests-green; production-build-841-modules-green;
  event-view-chunk-70.98-kib-minified-20.58-kib-gzip;
  bundle-budget-under-100-kib-green;
  ledger-integrity-5-tests-114-assertions-green;
  ledger-14125-canonical-18635-rows; coverage-61.1524;
  code-coverage-60.9483; no-filesort-temporary-or-index-hints;
  only-three-wave-containers-running; terminal-time-guard-active`.

### 16.117 Hourly checkpoint - 2026-09-03 01:05 BST

- `current_problem`: the patient page did not expose Visual Acuity history, and
  the existing safe API did not preserve the legacy ability to view recorded
  measurements in another configured notation.
- `acceptance_condition`: provide an authorized, bounded, lazy history panel;
  offer only active scales with usable values; preserve original notation; and
  prove exact legacy nearest-value conversion, fixed query growth, indexed
  plans, and one real browser journey.
- `completed_evidence`: the collapsed patient-page panel now loads Both Eyes,
  Right Eye, and Left Eye history on demand with event links and qualifiers. It
  defaults to the configured distance scale and switches among active usable
  scales. A real authenticated journey changed 6/9 and 6/12 to logMAR 0.18 and
  0.30 while retaining the original recorded values in the response. Four exact
  legacy source paths have conservative partial ledger evidence.
- `current_work`: open the next authoritative first-party clinical slice.
- `next_item`: close one bounded vision, refraction, anterior, retina, or
  operation migration confidence pack.
- `after_next`: reconcile only the exact pinned paths directly exercised by the
  completed slice, then take the next fixed queue item.
- `blockers_and_deferrals`: exact graph geometry, print fidelity, broad visual
  parity, migrated-volume load, UAT, and clinical sign-off remain later gates.
- `query_and_performance`: query growth remains fixed at two clinical and two
  configuration queries from small to large fixtures. The selected plans use
  indexes without filesort, temporary tables, optimizer hints, or forced
  indexes. Clinical history is uncached and authoritative; configuration reuses
  the existing source-versioned settings cache.
- `tests`: the focused pack passes four tests with 96 assertions, the affected
  integrated pack passes 47 tests with 2,939 assertions, all 38 JavaScript tests
  pass, the 843-module production build passes, and one authenticated Playwright
  journey proves the displayed Snellen-to-logMAR conversion.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 61.1564 percent. Code coverage is 60.9539 percent.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. The disposable
  browser container and volumes were removed; only the three capped wave
  containers remain running. Nothing is committed or pushed.
- `verification_state=visual-acuity-history-4-tests-96-assertions-green;
  integrated-47-tests-2939-assertions-green; javascript-38-tests-green;
  production-build-843-modules-green;
  playwright-snellen-logmar-conversion-green;
  fixed-two-clinical-two-config-query-growth;
  no-filesort-temporary-or-index-hints;
  ledger-14125-canonical-18635-rows; coverage-61.1564;
  code-coverage-60.9539; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.118 Hourly checkpoint - 2026-09-03 01:15 BST

- `current_problem`: Operation Booking stored immutable listing-diagnosis
  snapshots, but its patient-level reason-for-surgery correspondence value and
  three output formats remained unreachable in the target.
- `acceptance_condition`: select the newest live booking, return empty output
  for missing data, preserve string, table, and list formats, escape every
  diagnosis, reject invalid parameters, authorize the patient, publish the
  operation, and prove bounded indexed query behavior.
- `completed_evidence`: one named patient operation now returns no more than 50
  ordered diagnosis snapshots from the newest live booking. It ignores a newer
  deleted event, accepts case-insensitive format names, preserves all three
  legacy formats, and escapes unsafe labels. Three exact pinned source paths are
  now fully evidenced.
- `current_work`: select the next authoritative ordinary clinical residual from
  the fixed queue.
- `next_item`: close one bounded source-exact vision, refraction, anterior,
  retina, or operation migration confidence pack.
- `after_next`: reconcile only the exact source paths directly exercised, then
  continue the fixed queue without broad inference.
- `blockers_and_deferrals`: general database-driven shortcode registration,
  rich correspondence integration, migrated-volume load, exact visual parity,
  UAT, and complex Operation Booking rule families remain later gates.
- `query_and_performance`: the read remains fixed at two clinical queries after
  100 historical bookings. Both bounded plans use optimizer-selected indexes
  without filesort, temporary tables, index hints, or forced join order. No
  result cache is used; immutable diagnosis snapshots remain authoritative.
- `tests`: the focused pack passes five tests with 38 assertions; the Operation
  Booking and route pack passes 44 clinical and route tests; and the final
  documentation, ledger, PAS regression, and optimizer-policy pack passes 50
  tests with 753 assertions.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 61.1674 percent. Code coverage is 60.9635 percent and
  the exact 408-path Operation Booking feature cohort is 79.9020 percent.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=rfs-focused-5-tests-38-assertions-green;
  operation-and-route-pack-44-clinical-tests-green;
  final-doc-ledger-pas-policy-pack-50-tests-753-assertions-green;
  fixed-two-query-growth-through-100-history-rows;
  no-filesort-temporary-or-index-hints; manifest-query-free;
  ledger-14125-canonical-18635-rows; coverage-61.1674;
  code-coverage-60.9635; operation-booking-feature-79.9020;
  only-three-wave-containers-running; terminal-time-guard-active`.

### 16.119 Hourly checkpoint - 2026-09-03 01:35 BST

- `current_problem`: replace the legacy pre-operative Refraction and Visual
  Acuity event scan without changing the values embedded in correspondence.
- `acceptance_condition`: share one latest-live Operation Note boundary, select
  only a live examination that does not follow that boundary, preserve the
  legacy two-eye values and empty states, publish named authenticated
  operations, and prove fixed indexed query behavior.
- `completed_evidence`: two named patient operations now select one qualifying
  Refraction or Visual Acuity aggregate. Refraction retains spherical
  equivalents, priority readings, missing-eye text, and the two-eye table.
  Visual Acuity retains the best stored right and left notation from the same
  examination. A small shared boundary owns the latest Operation Note rule.
- `current_work`: inspect exact latest-operation-note correspondence gaps for
  another bounded source-backed consumer.
- `next_item`: close the next safe operation or anterior and retina migration
  confidence pack.
- `after_next`: reconcile only directly exercised pinned paths, then continue
  the fixed queue.
- `blockers_and_deferrals`: database-driven general shortcode registration,
  other specialty consumers, migrated-volume load, rich letter editing, exact
  visual parity, UAT, and clinical sign-off remain later gates.
- `query_and_performance`: each value stays fixed at three clinical queries
  after 100 older examinations. The six serving plans use optimizer-selected
  indexes without filesort, temporary tables, optimizer hints, or forced join
  order. No result cache is used.
- `tests`: the combined focused pack passes ten tests with 81 assertions. The
  affected Refraction, Visual Acuity, manifest, ledger, and optimizer-policy
  pack passes 41 tests with 2,834 assertions. Pint passes all eight touched PHP
  and route files.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 61.1681 percent. Code coverage is 60.9635 percent,
  the exact Refraction cohort is 80.5978 percent, and the broad Vision and
  Refraction cohort is 26.4147 percent.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. Only the three
  capped wave containers remain running. Nothing is committed or pushed.
- `verification_state=pre-operation-focused-10-tests-81-assertions-green;
  integrated-41-tests-2834-assertions-green;
  fixed-three-query-growth-through-100-history-rows;
  six-query-plans-no-filesort-temporary-or-index-hints; manifest-query-free;
  ledger-14125-canonical-18635-rows; coverage-61.1681;
  code-coverage-60.9635; refraction-feature-80.5978;
  vision-refraction-feature-26.4147; only-three-wave-containers-running;
  terminal-time-guard-active`.

### 16.120 Integrated checkpoint - 2026-09-03 02:06 BST

- `current_problem`: close two small but reachable source-backed clinical gaps
  without broad ledger inference: latest Operation Note correspondence values
  and the Examination CXL Outcome element.
- `acceptance_condition`: keep both reads and configuration queries bounded,
  preserve immutable clinical meaning, reject unauthorized or invalid writes,
  use optimizer-selected serving indexes without hints, and complete one real
  browser save for the user-facing element.
- `completed_evidence`: latest IOL type, IOL power, and operated eye now come
  from independent newest-live Operation Note sources through three fixed
  indexed queries. CXL Outcome now records required laterality, diagnosis, and
  outcome from versioned stable-code configuration and retains immutable code
  and label snapshots when selected configuration is later retired.
- `current_work`: inspect the next exact first-party Examination or device
  import residual with authoritative legacy behavior.
- `next_item`: close one bounded source-exact migration confidence pack.
- `after_next`: reconcile only its directly exercised pinned paths, then
  continue the fixed clinical queue until the 10:30 scope freeze.
- `blockers_and_deferrals`: historical nullable CXL Outcome rows need a
  governed cutover rule. The CXL dataset, CL Removed, Quality Score, general
  database-driven shortcodes, migrated-volume load, exact visual parity, UAT,
  and clinical sign-off remain later gates.
- `query_and_performance`: Operation Note correspondence stays at three
  clinical queries through 100 older notes. CXL configuration stays at three
  queries through 100 extra options. Its bounded projections and covering
  display-order indexes produce plans with no filesort or temporary table.
  Neither slice uses an optimizer hint or result cache.
- `tests`: Operation Note correspondence passes five focused tests with 45
  assertions and the affected Operation Note pack passes 55 tests with 3,720
  assertions. CXL Outcome passes seven focused tests with 106 assertions, a
  full tiny seed, the 844-module production build, and one authenticated real
  browser add-save-render journey. EventView remains under its 100 KiB budget
  at 71.17 KiB minified and 20.61 KiB gzip.
- `coverage`: 14,125 canonical paths and 18,635 mapping rows yield exact
  behavioral coverage of 61.2038 percent. Code coverage is 61.0312 percent.
  The Examination domain-consumer cohort is 78.4304 percent and its UI cohort
  is 73.6831 percent.
- `repository_state`: legacy remains clean and read-only. Laravel, Docker, and
  planning repositories retain the approved staged rewrite. The disposable
  CXL fixture, web container, and Chrome network attachment were removed. Only
  the three capped wave containers remain running. Nothing is committed or
  pushed.
- `verification_state=operation-note-correspondence-5-tests-45-assertions-green;
  affected-operation-note-55-tests-3720-assertions-green;
  cxl-outcome-7-tests-106-assertions-green; full-tiny-seed-green;
  production-build-844-modules-green; authenticated-browser-save-green;
  fixed-query-growth; no-filesort-temporary-or-index-hints;
  event-view-under-100-kib; ledger-14125-canonical-18635-rows;
  coverage-61.2038; code-coverage-61.0312;
  only-three-wave-containers-running; terminal-time-guard-active`.

### 16.121 Integrated checkpoint - 2026-09-03 02:25 BST

The reachable patient-summary Problems and Plans editor is restored without copying its unsafe identifier trust or row-by-row update pattern.

Delivered:

- The familiar ordered active list, creation row, drag reorder, keyboard reorder, removal confirmation, metadata, and separately disclosed Past/closed problems remain on the patient summary.
- A dedicated `can_edit_patient_problems_plans` capability is deny by default, recorded on user history, exposed through the summary, and required by both write routes.
- The server verifies current-institution patient ownership and entry ownership. All writes for a patient serialize on the patient row, and a reorder must contain exactly the current active set so stale clients receive HTTP 409.
- Reorder history and writes remain constant in statement count between two and one hundred entries by using one history-backed set update rather than one save per entry.
- More than one hundred active entries remains visible as an overflow warning but disables editing rather than silently dropping entries.
- DIV-476 records the security, concurrency, permission-import, and popup-fidelity differences.

Verification:

- The focused pack passes 8 tests and 129 assertions.
- The existing current and past read plans use `ix_patient_problem_plan_summary` without filesort, temporary table, optimizer hint, or forced index.
- The production build passes across 844 modules. `PatientView` is 74.32 KiB minified and 17.94 KiB gzip.
- One authenticated browser journey added two entries, moved the second using the keyboard control, confirmed and closed the first, and displayed it in Past/closed problems with no browser or HTTP errors.
- The named synthetic browser rows, their history, and their audit rows were removed. The disposable web container was stopped and Chrome was disconnected from the wave network. Only the three capped wave containers remain running.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 total rows, with zero missing or pending-review canonical paths. Exact highest-per-path coverage is 61.2155 percent overall and 61.0538 percent for code. The six-path Problems and Plans cohort is 95.0000 percent.

Deferred:

- Legacy Edit permission mapping during import, popup-only exact geometry, migrated-scale load and usability, UAT, and clinical sign-off.

Next:

1. Inspect the next ordinary first-party residual with authoritative behavior and a bounded schema packet.
2. Close another source-exact migration confidence pack without chasing marginal coverage.
3. Keep the 10:30 BST scope freeze and 14:00 BST safe-checkpoint terminal guard active.

### 16.122 Integrated checkpoint - 2026-09-03 03:01 BST

Patient identifier display and search rules now have one portable, indexed configuration contract instead of implicit page-specific choices.

Delivered:

- Institution and optional site rules retain display order, searchability, protocol prefixes, identifier and status necessity, automatic-number configuration, and administrator-only edit configuration with complete history.
- Site rules fall back independently for LOCAL and GLOBAL identifier usage, matching the pinned legacy helper rather than replacing one usage type when only the other is configured.
- Numeric searches remove spaces and hyphens, validate and pad through the configured type, and match exactly. Prefixes such as `nhs:` restrict the candidate types. Surname search remains unchanged.
- Hidden identifiers are absent from search results, patient summary, and patient details. Visible identifiers use the configured order and familiar formatting.
- The rule family has a reachable generic administration screen and portable natural-key import and export.

Verification:

- A fresh disposable seven-schema namespace passed the complete migration chain, tiny seed, and `oe:schema:verify`. The 48-test integrated identifier, search, PAS boundary, administration, manifest, migration, and hint-policy pack passed with 2,869 assertions. The exact disposable schemas were then removed.
- Small and one-hundred-patient fixtures use the same seven queries. Institution and site rule reads use the declared composite index and avoid filesort, temporary tables, optimizer hints, and forced indexes.
- One corrected browser harness run performed normalized `nhs:` search, rendered the familiar patient header, and opened the two-row administration screen with page state `ready` and no browser or HTTP errors. The initial harness observed the same correct behavior but rejected normal title capitalization; this was a harness assertion defect, not an application retry.
- The temporary web container was removed and Chrome was disconnected from the wave network. Only the three capped wave containers remain on that network.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero missing or pending-review canonical paths. Exact coverage is 61.2742 percent overall and 61.1040 percent for code. The 62-path patient-search cohort is 77.2903 percent.

Deferred:

- First-name and date-of-birth parsing, institution `any_number_search_allowed`, configurable primary and secondary usage settings, automatic allocation, patient-write enforcement, patient merge behavior, exact embedded institution-page layout, migrated-scale load, UAT, and clinical sign-off.

Next:

1. Inspect another ordinary first-party residual with authoritative behavior and a bounded migration confidence pack.
2. Preserve the 10:30 BST new-scope freeze and use the remaining pre-freeze time only for useful source-exact slices.
3. Re-run integration, reconcile plans and ledgers, and stage exact files before the first safe checkpoint at or after 14:00 BST.

### 16.123 Integrated checkpoint - 2026-09-03 03:30 BST

The event-image foundation now serves one secure current preview without starting Chromium in a clinical web worker.

Delivered:

- Authenticated, current-institution routes report image state, enqueue one deduplicated request, and stream only the exact content-addressed protected artifact.
- New generation can be disabled while compatible cached images remain viewable. A missing image then returns a graceful unavailable state without creating work.
- Exactly two manager-owned rendering workers match the renderer capacity. Request leases, finite retries, scheduled reconciliation, and a per-user rate limit bound duplicate or abandoned work.
- New artifacts are written directly to protected storage. No clinical image blob or storage path is exposed.
- DIV-477 records the deliberate single-preview boundary and all unported multi-image behavior.

Verification:

- The event-image workflow passes 10 tests and 105 assertions. The complete affected schedule, rendering, migration, manifest, and ledger pack passes 95 tests and 2,967 assertions.
- The first combined queue index produced `Using filesort`. Splitting it into queue-order and expired-lease indexes gives an automatic no-filesort and no-temporary-table plan assertion without optimizer hints or forced indexes.
- The newest migration rolled back and reapplied cleanly. All 312 retained migrations pass seven-schema verification.
- A rebuilt manager image proves two rendering workers are present, monitored, and fail health when either worker stops.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero missing or pending-review canonical paths. Exact coverage is 61.3691 percent overall and 61.2142 percent for code. The 18-path event-image cohort is 74.4444 percent.

Deferred:

- Eye, page, document, and attachment image collections, proactive all-event or patient batches, historical image-blob migration, patient-summary controls, migrated-scale capacity, output-corpus fidelity, Playwright, UAT, and clinical sign-off.

Next:

1. Select the next bounded authoritative first-party residual from the fixed queue.
2. Keep performance shape, schema packet, authorization, and migration evidence ahead of the loose coverage aim.
3. Freeze new scope at 10:30 BST, then run final integration and reconciliation through the first safe checkpoint at or after 14:00 BST.

### 16.124 Integrated checkpoint - 2026-09-03 04:15 BST

Medication forms now survive every implemented shared medication path through one portable, immutable contract.

Delivered:

- Versioned forms use stable source and code keys, and medications carry an optional default form.
- Medication-set items and automatic recipes may override the medication default without adding a per-item form lookup.
- Medication Management, History Medications, Prescription, prescription generation, repeat sets, and common-set consumers all retain the selected form snapshot.
- Live workflows reject unknown or retired forms. Inactive configuration imports may round-trip retired references so migration does not silently substitute a different formulation.
- Generic administration exposes forms and medication default-form keys without introducing a second API family.

Verification:

- The complete focused pack passes 53 tests and 1,461 assertions, including inactive retired-form round-trip coverage and small-to-large consumer query checks.
- A clean isolated Node 24 dependency install and production frontend build pass with 844 transformed modules.
- All 312 migrations and the tiny seed passed in the fresh seven-schema namespace, followed by complete schema verification.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero missing or pending-review canonical paths. Exact coverage is 61.4009 percent overall and 61.2416 percent for code. The 196-path shared medication consumer cohort is 57.7194 percent.

Deferred:

- The complete authoritative DM+D form catalogue loader, legacy clinical-row cutover, alternate-form selection UI, migrated-volume load, exact visual parity, UAT, and clinical sign-off remain under DIV-280 and DIV-478.

Next:

1. Inspect the bounded Corneal Tomography choice residual and credit only source-exact behavior.
2. Continue the fixed ordinary Examination, device-import, and operation queue with another migration confidence pack.
3. Freeze new scope at 10:30 BST, then run final integration and reconciliation through the first safe checkpoint at or after 14:00 BST.

### 16.125 Integrated checkpoint - 2026-09-03 04:50 BST

Red Flag choices now preserve every legacy context-mapping level through one bounded contract.

Delivered:

- One normalized history-backed mapping joins an option to exactly one institution, site, specialty, subspecialty, or firm.
- The picker preserves the source any-matching-level union. It uses five independently indexable existence checks in one bounded option query rather than a cross-table OR or optimizer hint.
- Configuration imports and exports stable codes and references for all five context types, retains retired mappings as inactive history, and rejects out-of-institution site or firm references.
- The generic administration table now renders object-based JSON as readable JSON while retaining existing scalar-list presentation.
- The four fixed Corneal Tomography vocabulary paths and four Red Flags context model paths receive exact evidence only for the behavior now directly proved.

Verification:

- The Red Flags pack passes 17 tests and 147 assertions. The combined Red Flags, ledger-integrity, and migration-policy pack passes 24 tests and 263 assertions.
- The selector stays at one configuration query from seven through 107 options. EXPLAIN reports no filesort or temporary table, and source contains no optimizer or forced-index hint.
- A fresh isolated seven-schema run passed all 312 migrations and the tiny seed before the browser gate.
- The production frontend build passes with 844 transformed modules.
- One authenticated browser journey entered examination edit mode, activated Red Flags, saw all seven context-selected choices, and loaded readable context JSON in administration with no unexpected browser, runtime, or HTTP errors.
- The disposable web container and Chrome network attachment were removed. Only the three capped wave containers remain running.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero missing or pending-review canonical paths. Exact coverage is 61.4576 percent overall and 61.3511 percent for code. The 24-path Red Flags cohort is 67.7083 percent.

Deferred:

- Red Flags pathway icon and popup behavior, worklist filtering, general search, shared history presentation, OpenAPI publication, target help, exact visual parity, migrated-volume load, UAT, and clinical sign-off remain under DIV-315.

Next:

1. Select the next bounded source-exact Examination, device-import, or operation cohort.
2. Close another migration confidence pack and reconcile only its directly exercised paths.
3. Freeze new scope at 10:30 BST, then run final integration and reconciliation through the first safe checkpoint at or after 14:00 BST.

### 16.126 Integrated checkpoint - 2026-09-03 05:10 BST

The embedded Laravel xAPI prototype now retains its directly proved event linkage, context, and Clinic Outcome shapes.

Delivered:

- Event resources expose the source worklist-patient, step, template, information, and firm-context fields from bounded event snapshots.
- Clinic Outcome resources preserve the legacy typed entry shape through the existing complete-state read contract.
- The existing bounded code-system and coding-resource implementation is reconciled only to source files whose behavior is directly exercised.
- Thirty-nine exact zero-evidence paths in the embedded Laravel prototype now have reviewed evidence. Address, contact-location, generic event mapping, service-account, generated specification, and uncertain diagnosis-rule paths remain uncredited.

Verification:

- The focused xAPI pack passes 60 tests and 815 assertions.
- Clinic Outcome reads remain at one query from one through 51 entries.
- The event worklist-patient lookup uses its index without filesort, temporary table, optimizer hint, or forced index.
- A fresh isolated seven-schema run passed all 312 migrations, the tiny seed, and complete schema verification.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero missing or pending-review canonical paths. Exact coverage is 61.7337 percent overall and 61.4332 percent for code. The 458-path embedded Laravel census cohort is 62.6288 percent.

Deferred:

- Generic event mapping, complete contact and location fidelity, generated OpenAPI publication, service-account behavior, authoritative mandatory-diagnosis and no-diagnosis rules, migrated-scale load, UAT, and clinical sign-off remain explicit later gates.

Next:

1. Inspect the remaining embedded Laravel zero paths or select another bounded clinical slice with authoritative behavior.
2. Close another source-exact migration confidence pack before the 10:30 BST scope freeze.
3. Preserve the final integration and reconciliation window through the first safe checkpoint at or after 14:00 BST.

### 16.127 Integrated checkpoint - 2026-09-03 05:25 BST

The current CVI implementation now has direct evidence for its consolidated schema packets and the source behavior already present.

Delivered:

- The six-section draft, clinician and patient signatures, issue lifecycle, register, local-authority configuration, deterministic render payload, patient-status precedence, and visual-acuity alert are reconciled to exact legacy sources.
- Sixty-six formerly zero paths now map to the final target schema, fixed-choice contracts, legacy fixture intent, current tests, and two small frontend entry points.
- The target creates retained CVI columns and indexes in bounded initial migrations rather than replaying the source sequence of table rebuilds, renames, and incremental column additions.
- This evidence is deliberately limited to schema shape and current behavior. It does not claim that historical rows, signatures, documents, or delivery state have been transformed.

Verification:

- The complete focused CVI pack passes 74 tests and 1,878 assertions.
- An explicit schema test proves the final columns, history twins, one-live-draft uniqueness, patient-history ordering, and lifecycle indexes.
- No application runtime schema introspection was introduced. The schema checks exist only in the migration confidence pack.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero missing or pending-review canonical paths. Exact coverage is 62.1475 percent overall, 61.5278 percent for code, and 60.7084 percent for migrations. The 214-path CVI cohort is 66.0187 percent.

Deferred:

- Historical row and postal-signature transforms, mutable disorder administration, statutory PDF fidelity, external delivery, migrated-scale load, UAT, and clinical sign-off remain explicit gates.

Next:

1. Close the bounded Cover Test and Prism Fusion Range correspondence residuals without broadening into print fidelity.
2. Select another authoritative clinical slice before the 10:30 BST scope freeze.
3. Preserve the final integration and reconciliation window through the first safe checkpoint at or after 14:00 BST.

### 16.128 Integrated checkpoint - 2026-09-03 05:36 BST

The shared Examination correspondence operation now closes the bounded Cover Test, Prism Fusion Range, and dated Conjunctival Hyperaemia residuals.

Delivered:

- Cover Test correspondence preserves every saved row in order, including distance, correction, Corrective Head Posture state, row comments, horizontal and vertical prism results, and parent comments.
- Prism Fusion Range correspondence preserves prism-over-eye, correction, Corrective Head Posture state, all recorded Near and Distance directions, row order, and parent comments.
- Conjunctival Hyperaemia uses the current letter date as an explicit reference and returns the latest grading within the preceding seven days. A newer Examination without the element does not hide a valid older reading, and an empty window returns `Ungraded`.
- The dated query joins the maintained patient timeline directly to the unique element event key. It adds no schema introspection, no wide history scan, and no optimizer hint.

Verification:

- The related backend pack passes 47 tests and 745 assertions, including authorization, validation, exact wording, boundary dates, immutable snapshots, and fixed query growth.
- All 39 JavaScript unit tests pass, including letter-date URL generation.
- The production Docker asset stage builds 844 modules successfully.
- The small-to-large dated read has fixed query count through 100 unrelated historical events. MariaDB selects the patient timeline and unique element indexes without filesort, temporary table, forced index, or any other hint.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero missing or pending-review canonical paths. Exact coverage is 62.1738 percent overall and 61.5672 percent for code. The 240-path Examination orthoptics and ocular-surface cohort is 74.2250 percent.

Deferred:

- Anterior Segment print fidelity, Cover Test copy-forward, unused Hyperaemia HTML variants, migrated-scale load, final rebuilt-browser smoke, UAT, and clinical sign-off remain explicit later gates. The standing browser container predates this slice, so no browser claim is made here.

Next:

1. Select the next bounded source-exact first-party residual.
2. Close another migration confidence pack before the 10:30 BST scope freeze.
3. Rebuild the final browser environment and exercise all affected UI journeys once during integration.

### 16.129 Integrated checkpoint - 2026-09-03 05:58 BST

The bounded Biometry comment residual is now closed without changing formula
logic or query shape.

Delivered:

- Imported device comments and manually entered general comments remain on the
  immutable source envelope and participate in its content digest.
- Each append-only per-eye calculation snapshot accepts a separate optional
  plain-text clinical comment. Both comment classes are bounded to the MariaDB
  `TEXT` limit and rendered through escaped Vue interpolation.
- The event renderer and Operation Note projection expose the exact source and
  current per-eye comments without disclosing internal import identity.
- The unreleased initial Biometry schema packet creates both final columns. No
  post-load table rebuild, runtime schema lookup, query change, or optimizer hint
  was added.

Verification:

- A fresh seven-schema namespace ran all 312 migrations, tiny seed, schema
  verification, and 117 focused tests with 4,496 assertions.
- The focused set covers manual and automated input, bounds, immutable source
  storage, calculation snapshots, render revision, Operation Note consumption,
  authorization, route inventory, migration policy, and the query-free
  application-surface manifest.
- Scoped Pint passes for all 16 affected PHP files. The temporary schemas and
  test container were removed and verified absent.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with
  zero missing or pending-review canonical paths. Exact coverage is 62.1895
  percent overall and 61.5702 percent for code. The 144-path Biometry feature is
  80.5347 percent.

Deferred:

- Cataract target auto-fill and comparison, raw measurement warning parity,
  importer watcher and parser, merge and retry behavior, exact layout,
  migrated-volume load, UAT, and clinical sign-off remain under `DIV-463`.

Next:

1. Select the next bounded authoritative first-party residual from the fixed queue.
2. Close another source-exact migration confidence pack before the 10:30 BST scope freeze.
3. Preserve the final rebuilt-browser, full-suite, ledger, plan, and repository reconciliation gates through the first safe checkpoint at or after 14:00 BST.

### 16.130 Integrated checkpoint - 2026-09-03 07:21 BST

Portable History macros are now restored without importing legacy HTML into
the clinical record.

Delivered:

- Each macro has a stable code, bounded name and body, active state, ordering,
  optional subspecialty assignments, versioned history, and generic
  administration import and export.
- The History picker combines global and current-subspecialty macros using two
  bounded indexed reads. Query count is fixed from one through 101 macros.
- Selecting multiple macros appends their bodies in configured order as
  literal plain text. Text that resembles HTML is not interpreted as markup.
- Both serving plans avoid filesort, temporary tables, forced indexes, and all
  other optimizer hints.

Verification:

- The clean-room pack passed all 312 migrations, tiny seed, seven-schema
  verification, and 61 tests with 3,848 assertions.
- The production frontend build passed with 844 modules.
- An authenticated Playwright journey created two macros, inserted both into a
  real Examination event, saved through the global workflow, confirmed the
  exact plain-text result with no browser errors, deleted the temporary event,
  and verified its absence.
- The disposable schemas and web container were removed. The FileLedger remains
  exactly 14,125 canonical paths and 18,635 rows with zero missing or
  pending-review canonical paths. Exact coverage is 62.2377 percent overall,
  61.6496 percent for code, and 60.8279 percent for migrations. The 401-path
  feature cohort is 86.6933 percent.

Deferred:

- Historical macro transformation, exact visual fidelity, migrated-volume
  load, UAT, and clinical sign-off remain later gates.

Next:

1. Restore bounded Injection Management diagnosis-specific required questions.
2. Inspect the next authoritative clinical residual before the 10:30 BST scope freeze.
3. Preserve final integration and the 14:00 BST terminal guard.

### 16.131 Integrated checkpoint - 2026-09-03 07:45 BST

Diagnosis-specific required Yes or No questions are now restored in Injection
Management.

Delivered:

- Versioned stable-code question configuration preserves the legacy ID,
  diagnosis concept, wording, order, active state, and full history.
- The editor presents active questions for the selected diagnosis. The server
  requires the exact question-code set, rejects missing and injected answers,
  and accepts only boolean Yes or No values.
- Saved clinical answers retain the original code and wording after a question
  is retired or renamed. Validation and persistence reuse one request-local,
  bounded configuration snapshot.
- Generic administration uses a numeric diagnosis concept field instead of
  loading the whole disorder catalogue. Query count is fixed from one to one
  hundred questions, its serving index remains optimizer-selected, and the plan
  uses no filesort, temporary table, forced index, or optimizer hint.

Verification:

- Two clean-room runs passed all 312 migrations, tiny seed, seven-schema
  verification, and the final 34-test pack with 1,943 assertions.
- The production frontend build passed with 844 modules.
- An authenticated Playwright journey configured and viewed the question,
  answered No in the real Examination editor, saved it, verified the immutable
  semantic API snapshot with no browser errors, and removed the temporary event.
- The browser web container and disposable schemas were removed. The FileLedger
  remains exactly 14,125 canonical paths and 18,635 rows with zero missing or
  pending-review canonical paths. Exact coverage is 62.2593 percent overall,
  61.6913 percent for code, and 60.8279 percent for migrations. The current
  145-path Injection Management cohort is 69.6414 percent.

Deferred:

- Ongoing actions, historical transformation, exact layout, migrated-volume
  load, UAT, and clinical sign-off remain later gates under DIV-294.

Next:

1. Inspect the next bounded source-exact clinical residual.
2. Close another safe migration-confidence pack before the 10:30 BST scope freeze.
3. Preserve final integration and the 14:00 BST terminal guard.

### 16.132 Integrated checkpoint - 2026-09-03 08:26 BST

Saved Examination elements now supply a deterministic event-preview payload.

Delivered:

- The rendering registry selects a bounded Examination adapter for saved events.
  It attaches the minimal event type, primes element presence once, and loads DTOs
  only for element types that are actually present.
- Each branch in the shared presence union stops after its first match. One versus
  one hundred saved medication rows and one hundred unrelated events retain the
  same query count of at most eight.
- The content revision is derived from stable JSON. Browser renderer resolution
  remains outside web requests, and event export fails closed with the explicit
  `examination_fidelity_pending` reason until output fidelity is proved.
- The exact presence query plan uses no filesort, temporary table, forced index,
  or optimizer hint.

Verification:

- Scoped Pint passed all six affected PHP files.
- A final clean-room run passed all 312 migrations, tiny seed, seven-schema
  verification, and the two-test Examination rendering pack with 24 assertions.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero
  missing or pending-review canonical paths. Exact coverage is 62.2603 percent
  overall, 61.6927 percent for code, and 60.8279 percent for migrations. The
  18-path event-image cohort is 75.2778 percent.

Deferred:

- Exact legacy image fidelity, multiple-image collections, historical blob
  migration, patient-summary controls, migrated-scale capacity, Playwright UAT,
  and clinical sign-off remain explicit DIV-477 gates.

Next:

1. Select one globally uncredited authoritative source residual.
2. Freeze new scope at 10:30 BST, then run integration and reconciliation.
3. Preserve the 14:00 BST terminal guard and report honest coverage.

### 16.133 Integrated checkpoint - 2026-09-03 09:03 BST

Type 4 best-interest decisions now own protected support documents.

Delivered:

- An authorized user can attach PDF, JPEG, PNG or GIF evidence up to 2 MiB only
  after an owned same-institution Type 4 draft exists. Finalised forms and
  cross-event deletion attempts fail closed.
- The active set is capped at 20. Event presentation uses one bounded joined
  metadata query and canonical protected-file view and download operations.
- Deletion soft-deletes both records while retaining the protected object for a
  governed later prune. The initial Consent schema packet creates the relation,
  history twin, foreign keys, uniqueness and serving index once.
- A stale module-wide route assertion now distinguishes event-creation routes,
  which also require `can_create_events`, from ordinary Consent operations.
- The canonical Consent read API now returns the aggregate version needed by
  clients for optimistic-concurrency writes.

Verification:

- Scoped formatting and the 844-module production frontend build pass.
- A clean-room run passed all 312 migrations, tiny seed, seven-schema
  verification, 97 tests and 3,550 assertions across the full Consent, route
  manifest, ledger and migration-policy pack.
- Query count is fixed from one to 20 documents and the exact joined plan uses no
  filesort, temporary table, forced index or optimizer hint.
- A follow-up clean-room pack passed seven tests with 48 assertions after the
  browser exposed the missing read-version field. An authenticated no-retry
  Playwright journey then created a Type 4 draft, uploaded and read one protected
  PDF, removed it, deleted the temporary event and reported no browser errors.
- The disposable browser container and seven schemas were removed, leaving only
  the three capped wave containers.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with zero
  missing or pending-review canonical paths. Exact coverage is 62.2741 percent
  overall, 61.7057 percent for code and 60.8641 percent for migrations. The
  exact 276-path Consent cohort is 85.4022 percent.

Deferred:

- Historical attachment import, generated-document composition, exact
  presentation, migrated-scale load, full Playwright UAT, information-governance
  review and clinical sign-off remain explicit DIV-100 gates.

Next:

1. Select one final bounded source-exact slice that can close before 10:30 BST.
2. Freeze new scope at 10:30 BST, then run integration and reconciliation.
3. Preserve the 14:00 BST terminal guard and report honest coverage.

### 16.134 Integrated checkpoint - 2026-09-03 09:32 BST

The final bounded pre-freeze slice closes source-faithful Responsible For Care
authorization and linked OCT in-event search retirement.

Delivered:

- The fail-safe management page, read API, and transition APIs now require one
  default-deny `can_manage_responsible_for_care_worklist` capability before
  model binding. The administrator seed retains the legacy administrator grant.
- The capability is represented on both the live user and history twin, shared
  to Inertia for shortcut visibility, and declared exactly in every application
  surface manifest entry.
- The generated in-event search exposes exactly one linked OCT root, keeps
  manual OCT under its distinct label, and omits the retired manual child terms.

Verification:

- A clean-room run passed all 313 migrations, tiny seed, seven-schema
  verification, 44 focused tests and 4,537 assertions.
- Scoped Pint passed for the six affected PHP files, and all 39 JavaScript unit
  tests passed.
- A rebuilt authenticated no-retry Playwright journey created separate clinical
  and management events, exercised all three history surfaces, both management
  APIs and three administration screens, reported no browser errors, and
  removed the disposable stack and schemas.
- The slice adds no query shape, index hint or forced index.
- The FileLedger remains exactly 14,125 canonical paths and 18,635 rows with
  zero missing or pending-review canonical paths. Exact coverage is 62.2883
  percent overall, 61.7057 percent for code and 60.9438 percent for migrations.
  Responsible For Care is 96.7544 percent across 57 paths, while linked and
  manual OCT are 57.3967 percent across 121 paths.

Deferred:

- Legacy capability assignment import, linked OCT cutover, exact visual
  fidelity, migrated-scale load, UAT and clinical sign-off remain explicit
  DIV-273, DIV-269 and DIV-345 gates.

Next:

1. Open no further functional scope.
2. Run the complete integration, ledger, build, security and Docker gates.
3. Reconcile and stage exact changes before the first safe checkpoint at or
   after 14:00 BST, reporting honest coverage below the loose target if needed.

### 16.135 Scope-freeze checkpoint - 2026-09-03 10:30 BST

The 10:30 BST freeze is now in force. No new functional slice may be opened in
this run.

Completed evidence:

- Exact coverage remains 62.2883 percent overall, 61.7057 percent for code and
  60.9438 percent for migrations across 14,125 canonical paths and 18,635
  mapping rows. The loose 70 percent aim is not a licence to weaken evidence or
  open marginal work.
- The latest clean database proof passed all 313 migrations, tiny seed and
  seven-schema verification. Locked Composer and npm dependency audits report
  no known production security advisories.
- A fresh isolated correction pack passed 56 tests with 684 assertions after
  bounding the worklist scale fixture and correcting stale export, medication
  and query-budget expectations.

Current integration state:

- A complete one-process Pest diagnostic ran through the Feature suite and into
  the Unit tail before cumulative process memory reached the configured 512 MiB
  ceiling. The worklist scale case itself completed in 5.59 seconds; the prior
  unbounded fixture allocation is fixed.
- Fresh isolated reruns closed the Injection Prescription failures and proved
  Patient Search green. One Event export assertion still expected two Event
  queries although the saved Examination preview intentionally performs a third
  bounded primary-key lookup; that attributable assertion correction is being
  verified now.
- The canonical final test gate uses bounded fresh-container chunks so request,
  framework and test state cannot accumulate across the whole suite.

Next:

1. Verify the final focused integration correction in a clean seven-schema run.
2. Build and verify the exact production, manager, queue, Reverb, renderer and
   development images, then run the bounded canonical test runner.
3. Reconcile the ledger and plans, stage only intended files, and finish at the
   first safe checkpoint at or after 14:00 BST.

Blockers and deferrals:

- Seventy percent cannot be reached safely in the remaining integration window;
  the honest result will remain below the loose aim.
- Migrated-volume scale, full UAT, fidelity corpora and clinical sign-off remain
  later gates. They are not claimed by this run.

### 16.136 Bounded integration checkpoint - 2026-09-03 11:10 BST

Functional scope remains frozen. The final canonical verification is now green:

- A clean database applied all 313 migrations, loaded the tiny seed and passed
  seven-schema verification.
- The six-chunk runner assigned every one of 390 Pest files exactly once across
  fresh development containers. All 2,800 tests and 50,520 assertions passed
  with zero failures, errors or skips in 612.97 seconds.
- The repository-wide Pint check passed all 3,015 files. All 39 JavaScript unit
  tests passed. Strict Composer validation, the locked Composer audit and the
  production npm audit are green with no known advisories.
- Exact production, manager, queue, Reverb, renderer, development,
  manager-development and queue-development images were built. The complete
  Docker verifier passed role isolation, live health, a disposable Compose
  deployment and Helm rendering. The production image is 228,898,200 bytes.
- The production frontend build transformed 844 modules and retained the
  100 KiB EventView chunk gate. No product code changed after that build.
- The FileLedger verifies exactly 14,125 canonical paths and 18,635 mapping
  rows, with zero missing or pending-review canonical paths. Coverage remains
  62.2883 percent overall, 61.7057 percent for code and 60.9474 percent for
  migrations.
- The disposable test containers and schemas are removed. Only the three
  retained rewrite wave services remain running.

The first canonical run found one stale Patient Search assertion which assumed
that the four-row tiny seed could not have gained a legitimate event from an
earlier test file. The corrected assertion proves the 50-row bound and the two
known legacy events without depending on untouched shared fixture state. It
passed a clean focused run and the complete canonical rerun.

Next:

1. Stage only intended Laravel, Docker and plan files, excluding the generated
   worker and unrelated browser artifacts.
2. Inspect cached diffs, file modes, repository state and resource state.
3. Maintain the integration freeze and record the final checkpoint at the first
   safe boundary at or after 14:00 BST.

The 70 percent aim remains honestly unmet. Migrated-volume scale, full UAT,
fidelity corpora, production load and clinical sign-off remain later gates and
are not claimed by this run.

### 16.137 Integration and policy checkpoint - 2026-09-03 12:10 BST

Functional scope remains frozen. The staged result and the exact images now
have a second independent coherence and policy pass:

- All 544 runtime and manifest files copied into the exact development image
  match the staged product tree, with no missing or different file.
- The optimizer-hint policy now scans every first-party PHP area. Its exception
  registry is empty, and the expanded gate passed after a clean database ran all
  313 migrations, the tiny seed and seven-schema verification. No live database
  automation or first-party SQL file was found.
- The current application exposes 801 routes, including 626 canonical `/api`
  routes and no `/api/v1` route. Only Laravel's broadcasting authorization and
  health routes are unnamed; the application-surface contract remains named,
  feature-owned and query-free.
- Syntax checks pass for all 600 staged PHP files and all 12 staged Docker shell
  scripts. The exact renderer verifier is green, Debugbar is present only in the
  development image, all 39 JavaScript tests pass, and the locked Composer and
  npm audits remain clear.
- The staged sets contain exactly 774 Laravel files, 27 Docker files and 12
  Claude-kit files, with no tracked unstaged changes, mode changes, renames or
  copies. `public/frankenphp-worker.php` and the unrelated browser artifact
  directory remain untracked and excluded.
- The exact resource inventory still contains 40 rewrite containers: three are
  running and 37 are stopped. The recorded named volumes and networks are
  preserved, no disposable verification schema remains, and the host has
  18 GiB available memory with no swap.
- The master and active plans consistently preserve the canonical unversioned
  API, later documentation timing, no optimizer hints, migration-only schema
  invalidation, and the ordered post-rewrite performance program. The separate
  Puppeteer and query-plan evidence notes remain outside the repositories.

Next:

1. Keep the exact staged sets frozen and continue low-cost evidence audits.
2. Repeat the ledger, cached-diff, repository and resource checks near the
   terminal boundary.
3. Record the final integrated checkpoint at the first safe boundary at or
   after 14:00 BST.

Coverage remains 62.2883 percent overall, 61.7057 percent for code and 60.9474
percent for migrations across 14,125 canonical paths and 18,635 mappings. The
70 percent aim is honestly unmet. Migrated-volume scale, full UAT, fidelity
corpora, production load and clinical sign-off remain later gates.

### 16.138 Final release-evidence checkpoint - 2026-09-03 13:10 BST

Functional scope and the staged product remain frozen. The final architecture
and release-evidence review found no new implementation blocker:

- A fresh exact ledger run still passes with 14,125 canonical paths, 18,635
  mappings, zero missing paths and zero pending-review canonical rows. Coverage
  remains 62.2883 percent overall, 61.7057 percent for code and 60.9474 percent
  for migrations.
- The exact production web image successfully builds Laravel configuration,
  event, route and view caches. All eight exact images remain present with the
  expected revision label and non-root runtime user.
- The automatic query-plan inspector detects filesort, temporary and hidden
  materialized plans, unsafe scans and row-estimate growth. Its five tests and
  15 assertions pass, and its waiver contract remains bounded and auditable.
  Runtime disk-spill and storage-engine I/O proof still waits for realistic
  migrated data.
- A first-party scan finds no `SHOW FULL COLUMNS`, schema-builder discovery or
  other schema metadata read on a web request path. The only runtime metadata
  reader is the transitional manager-owned partition roller, which must be
  removed or receive incident-level justification before production-scale
  migration.
- The worklist appointment-local writer, narrow projection, transactional
  outbox, partitioned publisher, bounded recovery and private compact-patch
  design still expose no whole-system rewrite blocker. This is not a load claim:
  the complete migrated-data, concurrency, failure and soak matrix remains the
  final scale gate.
- The component-security review remains deliberately honest. The old EyeDraw
  dependency stack still needs release-blocking upgrade or isolation evidence,
  and the renderer retains 81 High or Critical Debian findings without fixed
  versions. Resource isolation limits risk but is not a clean security result.
- The exact resource inventory remains 40 rewrite containers, with three
  running and 37 stopped. Earlier named fixture schemas remain on the preserved
  wave volume; no current final-verifier namespace was created or left behind.
  The retained database stays within its 4 GiB cap and the host has 18 GiB
  available memory with no swap.
- The staged diffs remained byte-identical throughout the evidence hold. The
  existing root-owned empty worker and unrelated browser artifact directory
  remain untracked and excluded.

Next:

1. Repeat the ledger, cached-diff, branch, resource and exclusion checks near
   14:00 BST.
2. Record the final integrated checkpoint at the first safe boundary at or
   after 14:00 BST.
3. Leave the intended changes staged for human review without committing or
   pushing.

The loose 70 percent aim is not reachable safely in this run. Migrated-volume
scale, full UAT, output fidelity, production load, clinical sign-off and the
open component-security decisions remain explicit later gates.

### 16.139 Terminal integrated checkpoint - 2026-09-03 14:00 BST

The time guard was satisfied at 14:00:14 BST and the final integration condition
is complete. The bounded coverage tranche closes at a safe unchanged product
boundary:

- Exact highest-per-path coverage is 62.2883 percent overall, 61.7057 percent
  for code and 60.9474 percent for migrations across 14,125 canonical paths and
  18,635 mappings. There are zero missing paths and zero pending-review
  canonical rows. This is an 11.9216 percentage-point increase from the 50.3667
  baseline and an honest 7.7117 points below the loose 70 percent aim.
- The clean database applied all 313 migrations, loaded the tiny seed and passed
  seven-schema verification. The canonical six-chunk runner covered all 390
  Pest files exactly once and passed 2,800 tests with 50,520 assertions and zero
  failures, errors or skips.
- Repository-wide Pint passed 3,015 files, all 39 JavaScript tests passed,
  strict Composer validation and both dependency audits passed, and the
  production frontend built 844 modules. EventView remains 71.17 KiB, below its
  100 KiB gate.
- The rebuilt authenticated Consent upload, view and removal journey and the
  Responsible For Care journey passed without retries or browser errors.
- All eight exact role images remain present with their expected revision and
  non-root user. The full image, renderer, Compose and Helm verifier passed, and
  the production image separately built configuration, event, route and view
  caches. There are zero disposable verifier containers, networks or volumes.
- Production-image verification passes for 33 documentation pages, 10 modules,
  801 owned routes and disabled-by-default realtime. The automatic query-plan,
  optimizer-hint, migration-policy and ledger governance gates remain green.
- No product or Docker file changed after canonical verification. The final
  intended sets contain 774 staged Laravel files, 27 staged Docker files and 12
  staged Claude-kit files, with zero tracked unstaged changes. The root-owned
  empty worker and unrelated browser artifact directory remain untracked and
  excluded.
- All four repository tips remain equal to their local upstream refs. No commit
  or push was made. Legacy OpenEyes remains untouched at the pinned source SHA.
- The exact rewrite resource inventory remains 40 containers, with three
  running and 37 stopped. The preserved wave stack is capped and the host has
  ample available memory; earlier fixture schemas and recorded volumes remain
  for the later exact cleanup decision.

This checkpoint does not claim migrated-volume performance, database I/O
closure, the full worklist concurrency and failure matrix, renderer fidelity or
capacity, full UAT, accessibility acceptance, clinical sign-off, EyeDraw
dependency isolation, acceptance of the renderer operating-system residuals,
or removal of the transitional partition DDL. Those remain ordered master-plan
gates.

The next run starts only after human review and follows the master plan from
clinically useful functional breadth through the dedicated worklist program,
remaining high-value modules, representative migration, measured performance,
documentation, security evidence, UAT and release proof. The overall rewrite
remains open; only this bounded terminal tranche is complete.

### 16.140 Active dual 80 percent tranche - 2026-09-03 18:40 BST

This tranche implements master section 26.14 and stops at the first safe
integrated checkpoint at or after 06:40 BST on 4 September 2026. It then pauses
for human confirmation before any further tranche. The frozen inputs are legacy
`ad2324084788608246a8250e817198c2f26a4fd6`, Laravel
`160005dcbbfd27b04ceb769e9fd2445f354a3533`, and Docker
`67cfbca98a63d176af739686992e4aa0b303604d`.

The start report is 14,125 canonical paths, 18,635 mappings, 8,798.22 exact
equivalents, 62.2883 percent overall coverage, 7,306 code paths, 4,508.22 code
equivalents and 61.7057 percent code coverage. The hard completion gate is at
least 80.0000 percent in both measures. This requires another 2,501.78 overall
equivalents and 1,336.58 code equivalents from the starting point. The 81
percent forecast is a buffer only.

The opening integrity repair reclassifies the 3,500 automated placeholder
canonical rows from the false `reviewed` state to `pending-review` without
adding coverage. It adds a separate code minimum to the verifier, exposes
unowned and invalid-evidence counts, and prevents nonzero unowned rows. The
first implementation queue then follows core shared behavior, worklist,
integration boundaries, medication, clinical modules, patient summary and
documents, reporting and administration, and residual high-yield first-party
cohorts. The hour-eight scope freeze is 02:40 BST. The final four hours are for
focused tests, clean migration proof where applicable, bounded complete Pest
chunks, the production asset build, affected Playwright smoke, exact ledgers,
resource checks and staged review evidence.

Current problem and acceptance condition: correct the ledger state before any
new score is accepted. Completed evidence: all three repository tips match the
approved baselines; the product and Docker trees have no tracked unstaged
change; the existing empty untracked worker is excluded; the capped three
container wave stack is the only running rewrite stack. Current work: add and
test the ledger invariants and dual gate. Next item: assign evidence-backed
ownership to the existing nonzero worklist rows and select the first unowned
core cohort. After-next item: close the first safe core vertical slice with its
migration confidence pack. Blockers: none. Verification state: baseline only;
new gates are not yet claimed.

Implementation checkpoint at 02:00 BST on 4 September 2026: the ledger now
enforces honest automated review state, exact source classification, owned
nonzero evidence, and independent overall and code thresholds. Evidence-backed
reconciliation plus bounded core, worklist, case-search, patient and event,
operation-booking, event-image, settings, PAS address, ethnicity, GP, practice,
associated-contact, and identifier-status work raises the exact result to
73.2123 percent overall and 77.1439 percent for 6,159 code paths. There are
14,125 canonical paths, 18,643 mappings, zero missing paths, 1,221 pending-review
canonical rows, 1,291 unowned canonical rows, and zero reviewed placeholders.
The 80 percent gates remain unmet by 6.7877 and 2.8561 percentage points
respectively and are not claimed.

The required readability checkpoint found the new code focused and direct. Do
not refactor the tranche again. A later reuse opportunity is the similar PAS GP,
practice, and associated-contact field and address hydration, but their identity,
validation, and lifecycle rules differ enough that a shared abstraction is not
yet simpler. A real current-asset Playwright smoke exposed and then cleared a
stale-build harness failure. Login, patient summary, worklist, and the new event
image page now render without browser errors; the populated image page's measured
15-query ceiling is recorded and covered by a seeded-patient test. The final
integration phase reruns all bounded gates after the 02:40 scope freeze and keeps
the 06:40 terminal guard active.

Scope-freeze checkpoint at 02:40 BST on 4 September 2026: no new functional
slice may now start. Coverage remains honestly fixed at 73.2123 percent overall
and 77.1439 percent for code. The consolidated changed-test pack passes 223
tests with 42,960 assertions after `LoginTest` was made responsible for clearing
the exact named-limiter keys its examples reserve. Two consecutive same-minute
Login runs now pass, with no production limiter change. The focused worklist
pack passes 92 tests with 2,056 assertions, all 47 query-plan budgets pass, the
seven final schemas still verify all 315 migrations, all 804 routes and 33 help
pages verify, 3,036 PHP files parse, all 44 JavaScript tests pass, and the
848-module production build is green. An optional Composer strict-PSR probe
reports fourteen test-local helper classes declared inside Pest files; normal
strict Composer validation passes, so reorganizing those helpers is recorded as
later test debt rather than expanding this frozen tranche. Complete bounded
verification, plan reconciliation, intended-file staging, disposable-resource
cleanup, and the 06:40 terminal guard are now the only active work.

Post-freeze integration checkpoint at 04:00 BST on 4 September 2026: intended
diff review found and fixed one attributable saved-search list N+1 without
opening a new feature. Identifier, diagnosis, medication, allergy, family
relative, and family condition keys now resolve in six batched configuration
queries for either one or the maximum one hundred saved rows. The focused Case
Search pack passes 14 tests with 262 assertions, the changed pack passes 224
tests with 42,976 assertions, and the complete deterministic rerun passes all
391 canonical files with 2,882 tests and 83,089 assertions. A second complete
run in six fresh randomized shards passes the same totals under seeds 906401
through 906406. The deliberately unbounded one-process randomized diagnostic
reached its 512 MiB PHP test allowance after sustained passing work, confirming
the bounded-run requirement rather than a product failure. A current-asset browser
smoke proves the Advanced Search page and saved-search list with no console,
page, or failed-response errors. Coverage remains 73.2123 percent overall and
77.1439 percent for code; both 80 percent gates remain honestly unmet.

Post-freeze integration checkpoint at 05:00 BST on 4 September 2026: two
attributable late defects found during frozen diff review are corrected.
Batched settings resolution now bounds every scope branch and orders at most
800 scalar rows in PHP, so the two-query override plan uses neither filesort nor
temporary-table work. The event-image projection migration now backfills
existing rows by one set-based event-type join; rollback and reapplication leave
all 65 existing rows with zero grouping mismatches and zero unknown groups. A
fresh randomized affected-file run passes 224 tests with 42,978 assertions
under seed 9050001. The focused integration, renderer, security, worklist, and
clinical packs; all 47 query budgets; seven-schema 315-migration verification;
documentation; syntax; formatting; JavaScript; production build; dependency
audits; route ownership; and cache boot are green. Coverage remains 73.2123
percent overall and 77.1439 percent for code. Exact staging and
disposable-resource cleanup remain for after the 06:00 checkpoint.

Final integration checkpoint at 06:00 BST on 4 September 2026: the unchanged
final product diff passes a fresh complete randomized six-shard run of all 391
canonical runnable PHP test files, totaling 2,882 tests and 83,091 assertions
with zero failures, errors, or skips under seeds 907501 through 907506. The
selector also read six bootstrap and support PHP files which define no tests;
they are excluded from the 391 runnable-file count. Seven-schema verification
remains green across all 315 migrations. All 47 query-plan budgets, 33
documentation pages, 44 JavaScript tests, the 3,035-file Pint check, production
build, dependency audits, manager schedule, route ownership, cache boot, exact
ledger integrity, and policy scans remain green. A final randomized changed-file
pack passes 224 tests and 42,978 assertions under seed 907612. Coverage remains
73.2123 percent overall and 77.1439 percent for code. Exact cleanup and intended
staging are next; no product source changed after the recorded attributable
fixes.

Terminal integrated checkpoint at 06:40 BST on 4 September 2026: the time
guard and final integration condition are satisfied. Exact coverage closes
honestly at 73.2123 percent overall and 77.1439 percent for code. The two 80
percent goals remain unmet by 6.7877 and 2.8561 percentage points. A second
independent complete randomized six-shard run passes all 391 canonical runnable
PHP test files, 2,882 tests, and 83,091 assertions under seeds 907701 through
907706. The final seven-schema, 315-migration verifier, 47 query budgets, 33
documentation pages, 3,035-file Pint check, 44 JavaScript tests, dependency
audits, 848-module build, route, cache, and schedule gates, and exact ledger
integrity remain green. The terminal handoff is limited to removal of the seven
disposable schemas and dedicated runner, staging exactly 108 Laravel paths and
the three planning files, and preserving every unrelated container, volume,
network, and Claude-kit change. No commit or push is made.

### 16.141 Planned adaptive code-equivalence program - 2026-09-04

This plan executes master section 26.15 only after explicit user authorization.
It has no invented deadline and is not an active tranche. The planning inputs
are legacy `ad2324084788608246a8250e817198c2f26a4fd6`, Laravel
`1ad12cba8bb7a138346d90918b0ac2d1d2624a3c`, and Docker
`67cfbca98a63d176af739686992e4aa0b303604d`; recheck all three at execution
start. Authorization starts neither a deadline nor a durable time guard unless
the user specifies one separately.

#### Objective and decision staircase

Aim eventually for 100 percent semantic disposition of canonical legacy code.
Use 80, 85, 90, 92.5, 95, and 98 percent as evidence reviews, not stopping
rules. This is FileLedger port coverage for `source_class=code`, not PHPUnit line
coverage.

| Review | Code equivalents | Gain required | Residual allowed | Decision |
|---:|---:|---:|---:|---|
| Baseline | 4,751.29 of 6,159 | - | 1,407.71 | 77.1438545 percent |
| 80 percent | 4,927.20 | 175.91 | 1,231.80 | First verified ratchet |
| 85 percent | 5,235.15 | 483.86 | 923.85 | Second verified ratchet |
| 90 percent | 5,543.10 | 791.81 | 615.90 | Review residual shape; migration readiness is independent |
| 92.5 percent | 5,697.075 | 945.785 | 461.925 | Breadth ratchet, never a finish line |
| 95 percent | 5,851.05 | 1,099.76 | 307.95 | Independently audit every residual path |
| 98 percent | 6,035.82 | 1,284.53 | 123.18 | Provisional functional-porting boundary |
| 100 percent | 6,159.00 | 1,407.71 | 0 | Final semantic code disposition |

Current scores move in 0.01-equivalent increments, so 5,697.08 is the first
attainable total above the exact 92.5 threshold. The command
`php artisan oe:porting-ledger:verify --minimum-code=92.5` remains authoritative.
At 95, run `php artisan oe:porting-ledger:verify --minimum=80 --minimum-code=95`
so the earlier overall gate is retained. The 98 and 100 reviews retain
`--minimum=80` and use explicit `--minimum-code=98` and `--minimum-code=100`
values plus their behavioral gates.
Every ratchet command supplies its exact `--minimum-code` value, and a committed
machine-readable floor keeps CI and the final orchestrator aligned. If one slice
crosses several thresholds, run only the complete gate at the highest crossed
threshold.

If non-code scores remain unchanged, 95 percent code coverage projects to about
80.9982 percent overall FileLedger coverage, not 95 percent overall.

Ninety percent is not safe as a finish line because every currently nonzero path
could be perfected to reach 93.2619 percent while all 415 zero-score paths remain
untouched. At least 107.05 equivalents from current zero paths are needed for 95
percent and 291.82 for 98 percent. At least 223.45 equivalents from the current
deferred cohort are needed for 95 percent even if every other path reaches full
credit.

Continue beyond a percentage while mandatory or coherent high-value work is
unblocked. The first planned phase change occurs when schema and core-contract
readiness justify the migrated-data and failure-evidence review; its timing is
independent of the score. Only a genuine safety or architecture blocker
interrupts earlier. Do not start fidelity or full human-evidence work merely
because a percentage was reached. At a phase change, every residual path has an
owner, exact missing behavior, risk, prerequisite, and resume trigger. Resume
after the evidence phase. One hundred percent means fully ported, completely
replaced, or authoritatively retired; it never means copying obsolete or harmful
legacy code.

The percentage can never leave authentication, authorization, Break Glass,
patient identity, clinical-write boundaries, clinically important invariants,
atomic history, audit or outbox behavior, signing, calculations, irreversible
transforms, required routes, APIs, jobs, webhooks, device or external callers,
required migration behavior, familiar patient-summary content, or any of the 88
worklist behaviors unresolved at functional-porting completion.

Every review divides residuals into mandatory, high-value, and evidence-gated
tiers. Mandatory safety, integrity, migration, concurrency, and caller behavior
closes regardless of score. High-use, high-load, recurrent-support, shared, and
architecture-shaping behavior continues unless explicitly risk-accepted.
Obsolete glue, unused optional behavior, fidelity, unavailable external systems,
or work genuinely awaiting later evidence may defer only with an owner, reason,
risk, prerequisite, and resume trigger. A normal tranche handoff for human review
is not a pause of this percentage program.

At 95 and 98, publish a tail decision record for every residual cohort: path
count and equivalents, reachability, callers, prerequisite evidence, clinical
and operational risk, closure effort, retirement authority, and likelihood of
later invalidation. Continue to 100 when coherent closure or authoritative
retirement is cheaper and safer than maintaining exceptions. A provisional
boundary below 100 is acceptable only when no mandatory or unaccepted high-value
behavior remains and every residual is evidence-gated with an owner and resume
trigger.

#### Stage 0 - exact preflight and accounting repair

Acceptance: current source truth, evidence truth, and resource ownership are
known before any score or behavior changes.

1. Verify the three commits, exact 14,125-path manifest equality, 6,159-path code
   denominator, highest-per-path scoring, source classes, ledger hash, and clean
   separation of intended and unrelated repository state.
2. Record exact containers, networks, named volumes, schema namespaces, and host
   memory. Remove only exact disposable resources after their evidence is no
   longer needed.
3. Correct the duplicate `DIV-464`, add missing divergence statuses, and
   reconcile unreferenced divergence documents.
4. Generate a canonical code-only feature scoreboard. Freeze the opening 415
   zero-score and 546 deferred path lists and report their gains separately.
5. Freeze the legacy controller-action inventory and classify each action as
   reachable, internal-only, test-only, or path-specifically retired.
6. Split broad census buckets into owned operations without awarding coverage.
   Separate PageRegister backend tests from actual Playwright evidence. Establish
   a tracked, versioned browser-test owner and shared helper that waits for
   `oe:page-ready`, fails on the error state, and captures page, console, and
   failed-response errors. External ad hoc journeys remain interim evidence.
7. Record the runnable PHP test manifest and hash, application-surface count,
   query-budget count and hash, seven-schema configuration, locked dependencies,
   exact source commits and dirty state, and the immutable development image ID
   and revision label.
8. Add the final-disposition verifier contract now. Its 100 percent allowlist is
   reviewed, owned, score 100, and semantically ported, approved
   replacement/adaptation, or authoritatively retired with path-specific proof.
   Reject `partial`, `partial-symbol`, `ported-partial`, `ported-current-slice`,
   `deferred`, `accounted-no-feature`, `pending-review`, and unresolved evidence.
   Resolve every target path, test ID, divergence ID, and evidence ID before
   accepting nonzero credit.
9. Run a short component security delta review. Only a critical reachable flaw
   or a component that must be replaced changes the immediate queue.
10. Harden the bounded test runner and add one fail-closed final orchestrator
    before the first complete milestone. It must support a captured random seed,
    immutable image identity, resource limits and timeouts, durable JUnit and
    manifest evidence, fresh schema and Redis ownership, and every final gate
    listed below. Replace or mark the current monolithic manual CI test job
    non-authoritative until it runs that bounded contract.
11. Add a committed machine-readable coverage ratchet consumed by the CLI, CI,
    and final orchestrator. Strict evidence mode fails on unowned canonical code
    rows and unresolved nonzero claims.
12. Reconcile the current PHP support declaration mismatch between README,
    Composer policy, and CI before component-version evidence is accepted.

#### Stage 1 - architecture that later breadth must not invalidate

Acceptance: clinical and configuration writes cannot lose integration or audit
evidence, authorization has one source, and storage or connection seams do not
require a later broad rewrite.

1. Make the general system-event and webhook outbox occurrence durable and
   atomic with its owning source transaction. Keep network delivery after commit.
   Prove commit, rollback, duplicate, listener, restart, cleanup, and network
   failure. Prevent after-commit callback leakage between persistent-worker
   requests. Retain the separate durable worklist outbox.
2. Make source write, history, audit, and durable outbox use the originating
   write connection on the same primary server. Reporting and replica lanes are
   read-only and never receive those writes.
3. Establish one resolver for legacy roles, inheritance, SSO, institution
   context, capabilities, and Break Glass. Routes, commands, queues, and
   integrations share its policy metadata and deny before sensitive binding.
4. Establish predictable clinical, reporting, integration, and maintenance
   workload-lane configuration while retaining today's one-host, one-user
   default. Explicit overrides fail closed. Pooling and real replica routing wait
   for migrated-data evidence.
5. Enforce audited and versioned source-of-truth writes and maintain a small
   owned exception registry for imports, migrations, projections, and ephemeral
   records.
6. Consolidate protected-file access behind one storage-neutral contract for
   authorized streaming, immutable identity, ownership, retention, and
   reconciliation across local development and durable object storage. Reserve a
   minimal quarantine state; choose a scanner later.
7. Freeze typed audit events, route ownership and input metadata, cache
   ownership, privacy-bounded telemetry, page readiness, worker reset, and
   per-context schema packet rules. Preserve the unversioned clinical `/api`.
8. Build and verify the development profiler on safe fixtures. It observes all
   connections, N+1 groups, source attribution, request and database time,
   memory, Inertia and fetch requests, and persistent-worker reset without
   changing query shape, and it is excluded from production images.
9. Remove or unschedule the transitional `oe:schema:partition-roll` application
   path, which currently performs `ALTER TABLE`, before Stage 1 exits and before
   the first percentage ratchet. Any rare extreme exception needs an owner,
   rationale, detection, rollback, and release approval. A named forbidden-code
   and exception-register verifier rejects DDL, schema discovery, forced indexes,
   optimizer and join-order hints, triggers, routines, and database events in
   request, queue, integration, reporting, and scheduled application paths.
   Versioned migrations may perform DDL; manager migration and schema-verification
   tooling may inspect schema metadata.

#### Stages 2 onward - functional portfolio

The initial portfolio accounts for the complete 1,407.71-equivalent code gap.
The figures are available debt, not stage targets or advance credit. Stage 0
publishes exact feature-ID membership and one scoring owner per canonical path,
then recalculates these pools after census reassignment. Architecture seams earn
no duplicate score.

| Stage | Bounded cluster | Available gap |
|---:|---|---:|
| 2 | Authentication, authorization, context, patient identity, PAS, patient search, Case Search behavior and event timeline | 293.52 |
| 3 | Administration, files, device intake, webhooks, system events, documents, event images and xAPI | 207.08 |
| 4 | Worklist, Patient Ticketing, Next Steps and Clinical Outcome | 89.25 |
| 5 | Examination, diagnoses, patient summary, shared medication consumers, IOP, OCT, vision and refraction | 288.35 |
| 6 | Therapy, surgery, Consent, CVI, Correspondence and DocMan, Prescription, Biometry, Intravitreal Injection, Messaging, Request Forms, checklists, Device Usage and Event Export | 284.33 |
| Continuous | Laravel, shared, and API census paths reassigned to owning consumers | 187.91 |
| Clinical-first tail | Trials, Triage, Laser, Cataract Surgical Management, CVI Status, then remaining owned clinical and administration paths | 57.27 |

Stage 2 closes the permission matrix, SSO and LDAP behavior, Break Glass,
event-creation authorization, patient create/edit/merge, identifier rules,
configured search, PAS intake and resolver order, concurrent identity handling,
GP and Practice administration, and a monitored replacement for the broken GP
download. Close basic reachable Case Search behavior and API contracts now;
defer only its data-sensitive query redesign.

Stage 3 closes protected upload/link/view/delete, manual correspondence
attachments, device interpretation after its representative payload contract is
frozen, webhook parity and durable consumers, event-image lifecycle and global
generation controls, event and element history, environment-owned settings, and
remaining bounded xAPI resources. Admin tooltips, the documentation module, and
scanner deployment remain later unless a missing explanation is itself unsafe.
The renderer remains private and isolated with compatible pinned full Chromium
and Puppeteer, one persistent browser, isolated contexts, maximum concurrency
two, hard resource limits, and explicit render readiness. PDF and PNG have
separate gates. Do not switch engines or claim fidelity during breadth work.

Stage 4 resolves all 88 worklist behavior rows including old API compatibility,
filters, favourites, lists, comments, assignment, pathway steps, configuration,
mapping, generation visibility, diagnostics, deltas, subscriptions, rebuild, and
recovery. Only three rows are currently recorded as covered and 85 remain.
Retain and verify the existing factory-owned current-date sample-data path so
demos do not depend on manual post-migration shell scripts. Preserve
appointment-local locking, the durable clinical outbox, bounded details,
partitioned publishers, unchanged-mapping suppression, and network work outside
transactions. Prove only concurrency threats that could force a system redesign
now; keep the complete migrated-data load and failure matrix for its later gate.

Stage 5 preserves familiar patient-summary panel order, labels, clinical
placement, source links, and access to complete content while making retrieval
bounded. Close required-diagnosis behavior, medication-chain prewarming and
consumers, event chronology, sensible lazy image access, IOP and visual-acuity
history, refraction, OCT, examination consumers, and reviewed automatic
diagnosis changes. Progressive images stay off by default, and no arbitrary
image batch size is selected. The global generation-off switch serves old images
while suppressing new work gracefully. The compact summary remains far future.
Stage acceptance includes a side-by-side representative-patient check of the
familiarity rules and default-off progressive behavior. Later large-history
tuning repeats that proof.

Stage 6 closes Therapy Application, Operation Booking, Operation Note, Consent,
CVI, Correspondence and DocMan delivery, Prescription, Biometry, Intravitreal
Injection, Messaging and the home/inbox behavior, Request Forms, both checklist
families, Genetics Device Usage, Event Export, and their authenticated consumers.
Signing, clinical calculations, statutory output, and irreversible transitions
receive stronger immediate proof.

Census paths are reassigned and reconciled continuously through their owning
features, complete symbol parity, or path-specific caller and retirement
evidence. They are not a late standalone coverage lane. The clinical-first tail
starts with Trials, Triage, Laser, Cataract Surgical Management, and CVI Status
before ordinary administration. Do not build a generic compatibility layer or
port dead generated code for points. Analytics, advanced-search performance,
and data-distribution-sensitive redesign wait for migrated data unless a
reachable correctness or safety contract must close now. The NOD special module
remains valuable but is outside this pinned denominator and cannot increase this
score.

#### Per-slice migration confidence pack

No canonical path gains score until its slice has:

1. Exact pinned legacy path, action, caller, and symbol evidence, plus owned
   target symbols and a stable operation ID.
2. A representative parity or characterization happy path and an approved
   divergence for each intentional behavior change.
3. Authorization, validation, audit, institution/site/patient/event ownership,
   and clinically important invariant tests.
4. Warmed small-versus-large query comparison on every used connection, a fixed
   or bounded query ceiling, bounded projection and pagination, and registered
   plan budgets for hot reads.
5. Cost-property rejection of filesort, temporary tables, materialization,
   unsafe scans, and excessive row estimates. Never force an index or join order.
6. A complete schema packet, transform test, clean migration proof, and small
   representative import when persistence changes. No trigger, stored routine,
   database event, hidden business-logic view, runtime DDL, or runtime schema
   discovery.
7. Relevant JavaScript tests and one current production-asset, one-worker,
   zero-retry Playwright smoke for a user-facing workflow, waiting for
   `oe:page-ready`. Do not add Cypress.
8. Integrator-owned ledger, PageRegister, route, API, divergence,
   documentation-status, and query-budget evidence.

Uploads additionally prove IDOR, traversal, type, size, content state,
authorization, and audit. Transactional integrations prove commit publication
and rollback suppression. Telemetry tests forbid raw URLs, route values, SQL,
bindings, payloads, secrets, and patient identifiers.

Calculations, signing, statutory output, irreversible transforms, and high-risk
divergences receive targeted clinical review during their slice. They do not
wait for the later full paired UAT corpus.

#### Tranche and verification cadence

Use repeatable 12-hour tranches, with no calendar promise until a tranche is
authorized. T+0 to T+1 verifies pins, resources, prior-diff readability, exact
candidate paths, and acceptance evidence. T+1 to T+8 delivers bounded slices.
Freeze new scope at T+8, or earlier when the measured complete-gate duration plus
contingency requires it. T+8 to T+12 contains only attributable fixes, complete
integration, reconciliation, exact cleanup, and staging. Finish at the first safe
integrated boundary at or after T+12. If a milestone gate is still running or
fails, retain resumable evidence and continue verification without new scope; do
not ratchet or claim the checkpoint. Then show the diff and pause for human
review.

Shared routes, registries, PageRegister, divergence identifiers, ledgers, shared
schema, and shared seeds remain integrator-owned. Parallel workers return
bounded fragments. Hourly records retain current problem and acceptance,
completed evidence, current work, next and after-next items, blockers, raw points,
zero/deferred/partial gains, residual by feature and status, open critical
behavior, worklist parity, query changes, tests and explicit gaps or deferrals,
memory and OOM state, and exact repository and resource state.

At the earlier of three credited slices or one additional percentage point of
code coverage, run the combined affected PHP tests in fresh processes, related
query budgets, route and authorization checks, ledger integrity, relevant
JavaScript tests, and the production build when assets changed. After every slice
that changes migrations, rebuild and verify all seven schemas from empty.

At 80, 85, 90, 92.5, 95, 98, and 100 percent, ratchet the verified minimum only
after this deterministic complete-gate protocol succeeds:

1. Create a new disposable seven-schema namespace, run manager-equivalent
   migrations, load `oe:seed:load --profile=tiny`, run `oe:schema:verify`, and
   record its namespace and clean Redis identifier. This proves the whole chain
   from empty. When new tail migrations exist, separately prepare an upgrade
   fixture at the prior baseline, then apply, roll back, and reapply only those
   exact tail migrations. An edited unreleased historical migration receives a
   clean-chain proof rather than a misleading batch rollback.
2. Freeze HEAD plus a canonical digest of every file admitted to the Docker build
   context, including staged, unstaged, and admitted untracked files. Embed that
   identity in the image, resolve its tag once to an immutable image ID, reject
   post-build source drift, and use that image ID for discovery and all shards.
3. Discover Unit and Feature tests independently, fail on discovery errors or an
   empty group, hash complete discovered and assigned manifests, and run
   sequential fresh containers with no more than 80 runnable files each. Never
   use one cumulative 512 MiB Pest process as the complete gate.
4. Hold an exclusive host runner lock, repeat the host-memory preflight before
   every shard, and run sequentially by default. Apply a measured
   container-memory limit above PHP's 512 MiB allowance, swap and PID limits, and
   a per-shard timeout. Record host availability, peak container memory, original
   exit status, timeout, and Docker `OOMKilled` state.
5. Require and retain valid JUnit for every normally completed shard. Missing
   JUnit after timeout, signal, or OOM is an explicit gate failure with retained
   container logs, original exit status, and `OOMKilled` evidence; do not remove
   the abnormal container before inspection. Persist all artifacts on success and
   failure.
6. Record source identity, manifests, schema and Redis IDs, seeds, exit
   classifications, aggregate test metrics, duration, memory and OOM state, exact
   MariaDB and Redis image IDs and server versions, `sql_mode`, optimizer settings,
   schema and seed hashes, Docker engine and runtime versions, and effective
   resource limits.

At 95, 98, and 100, create a second independent seven-schema namespace and clean
Redis state, then repeat the complete pass with a captured master seed that
shuffles the full test-file manifest before sharding and supplies recorded
derived Pest or PHPUnit random-order seeds. Randomizing within fixed alphabetical
shards is not independent.

The current runner and manual CI do not yet implement this protocol. Stage 0 must
close that gap before the first milestone claim; earlier test evidence cannot be
treated as this gate.

One fail-closed milestone orchestrator runs fresh data preparation, deterministic
and required randomized Pest passes, strict FileLedger integrity and the exact
minimum, `oe:query-plan:verify --profile=tiny --json=<artifact>`, module,
documentation, realtime, route, authorization, manager-schedule, and named
forbidden-code checks, `npm run test:unit`, `npm run build`, fresh Composer and
npm audits bound to exact lockfiles, pinned copied or vendored distribution
hashes, affected immutable image checks, and the complete tracked Playwright smoke
manifest for all credited user-facing workflows. The browser gate launches the
same immutable application image against the recorded disposable schemas and
Redis namespace, waits for required manager, web, realtime, and renderer health,
uses owned synthetic login fixtures, then runs Playwright with current built
assets, one worker, zero retries, and `oe:page-ready`. The current manual
monolithic CI job is non-authoritative until aligned with this bounded contract.

"All query budgets" means all registered factories, currently 47, rather than
every SQL statement. Every changed operation registers its hot queries, and each
complete gate records the registry count and hash. The `tiny` profile proves
structural plan properties only; no migrated-data performance claim follows while
the history-heavy profile remains unavailable. A change to relevant application
code, tests, fixtures, seeds, migrations, dependency locks, build inputs, images,
verification tooling, database or cache runtime identity, material server
settings, or resource limits invalidates the affected complete evidence.

#### Phase changes and final disposition

At the first checkpoint where schema-bearing mandatory contexts, irreversible
transforms, and core contracts meet their recorded readiness criteria, pause for
an exploratory anonymized production-volume import. This may occur before or
after a percentage review; percentage neither triggers nor blocks it. Capture
the exact database, PHP, framework, renderer, browser, and dependency versions.
Use the run for schema, cardinality, transform, reconciliation, and performance
discovery. It is not the final migration rehearsal and is repeated after final
schema consolidation.

Only with representative large data may the external untracked legacy
`UrlBenchmarkCommand`, Laravel surface benchmark, development profiler, safe
`ANALYZE FORMAT=JSON`, slow-log statistics, and storage-engine counters drive
latency, filesort, temporary-table, row-examination, and I/O changes for a ready
workflow. Representative data unlocks these checks; it does not make unfinished
behavior ready. Decide pooling and replica use from this evidence, without index
hints.

Resume mandatory and high-value breadth using migrated-data findings, including
the 95 and 98 reviews and data-dependent tails. Pass separate PDF and PNG
fidelity gates once representative output families exist, then complete
evidence-led refactoring and mutation or exhaustive hardening. Freeze product
behavior, output contracts, schema, and release components when those changes
settle.

Use this post-data readiness queue:

1. Worklist is first once all 88 behaviors and its publisher and subscription
   paths exist. Run 5,000 dashboards, 125,000 subscriptions, 100 appointment
   changes per second, the 250-per-second broad burst, reconnect and dependency
   failures, and soak behavior. It does not wait for unrelated Stage 2 or Stage 3
   breadth once Stage 1 and its required authorization, context, and
   configuration seams are complete.
2. If Worklist is not ready, take the next ready Case Search, Advanced Search,
   Analytics, or supplied NOD replacement item and return to Worklist immediately
   when it is ready. The NOD special module has a separate reporting-lane
   functional and migrated-volume release gate and earns no FileLedger points for
   this pinned denominator.
3. Run patient-summary large-history retrieval after Stage 5 and repeat its
   familiarity proof.
4. Establish representative renderer capacity and a PDF fidelity baseline before
   end-to-end DocMan bulk delivery.
5. Run PNG and event-image fidelity and capacity as a separate gate.
6. Finish remaining owned census and specialist tails.

Basic reachable behavior and API contracts are completed before the import where
possible; only data-sensitive query and storage redesign waits for representative
volume.

At that freeze, the final 100 percent semantic gate requires every code row to
be fully ported, completely replaced, or authoritatively retired, with zero
partial, deferred, unowned, or unresolved final statuses, the complete critical
behavior register, the strengthened disposition verifier, and integration proof
appropriate to every credited cohort. Repeat the fresh deterministic and
independently randomized complete gates and the full milestone orchestrator.
Percentage does not trigger or delay the freeze.

Passing 100 percent for the 6,159 canonical code paths does not finish the
all-source ledger. Rewrite completion still requires owned final disposition of
all 14,125 canonical paths, including documentation, data, build, configuration,
asset, vendored, licence, and repository-metadata classes.

Before the final migration rehearsal, complete the component inventory, SBOM,
supported LTS release-line policy, resolved build attestation, end-of-support
alerts, and the automated Puppeteer/Chromium compatibility check, then freeze
the release-candidate stack. Configuration uses a supported release line such
as MariaDB 11.8 rather than a patch tag, while the built artifact records exact
resolved components.

As the final schema-writing task, consolidate the unreleased migration chain to
remove avoidable repeated table rebuilds. Any later schema change invalidates
consolidation and the final rehearsal. Do not rewrite a migration already
applied to a supported production deployment. Then run the final
release-relevant migration, reconciliation, performance, capacity, fidelity
regression, and cutover-duration proof. Consolidation changes migration and
verification inputs, so rerun the complete 100 percent deterministic/randomized
technical matrix against the consolidated chain.

Passing a percentage review does not claim rewrite or release completion. The
master plan retains separate gates for large-data correctness and performance,
worklist scale, renderer fidelity, security, documentation, accessibility, UAT,
clinical sign-off, rollback, and cutover. After behavior and migrated-data
performance stabilize, build the route-linked Laravel help capability and
generated corpus from BSpecs and divergences rather than porting the legacy
OeDocumentation special module. Operational guidance, scanning evaluation, and
final security evidence follow, then paired UAT. Safety-critical field help stays
in its owning slice; the general admin-tooltip backlog is nonblocking post-rewrite
work and does not gate UAT or release. The compact patient summary remains
post-rewrite.

After the last application, migration, image, verification-tool, security, or
UAT-driven code correction, rerun the full milestone orchestrator and required
100 percent deterministic/randomized pair before release evidence is frozen. A
pre-correction pass is not the final technical gate.

Any relevant application, test, fixture, seed, migration, dependency lock,
build-input, image, verification-tool, query, renderer, security-control, or
user-visible change after a final evidence gate invalidates the affected
migration, regression, performance, fidelity, documentation, security, and UAT
evidence and requires it to be rerun.

The handoff is staged evidence only. Do not commit, push, amend, force, bypass
hooks, hard-reset, broadly prune Docker resources, or modify the pinned legacy
repository.

### 16.142 Active continuation - 2026-09-06 to 2026-09-07

The user authorized continued execution of section 16.141 through 09:00 BST on
7 September 2026. The durable goal is active. No voluntary completion, handoff,
or idle period occurs before `2026-09-07T09:00:00+01:00`; finish only at the first
safe verified integration checkpoint at or after that time. Freeze new functional
scope at 07:00 BST and use the remaining time for attributable fixes, integration,
verification, reconciliation, and staging. Take the next unblocked item whenever
an item closes or a narrow behavior requires unavailable authoritative evidence.

Opening pins remain legacy `ad2324084788608246a8250e817198c2f26a4fd6`, Laravel
`1ad12cba8bb7a138346d90918b0ac2d1d2624a3c`, and Docker
`67cfbca98a63d176af739686992e4aa0b303604d`. Existing staged changes are the previous
integrated checkpoint and must be preserved. The zero-byte untracked public
worker file remains excluded. Opening reported coverage is 73.2123 percent overall
and 77.1439 percent code; recalculate before any credit change.

The first queue item is the source-reviewed role, task, operation, and SSO
assignment crosswalk, including strict mappings, defaults, and revocation. Close
the smallest safe authorization behavior supported by that evidence. Continue
the remaining Stage 1 foundations and then the Stage 2 and Stage 3 functional
portfolio in dependency order. No architecture seam earns duplicate coverage.
Record every narrow external or clinical-rule deferral and advance unblocked work.

Hourly FileLedger progress records include next and after-next work, exact
verification state, source identity, residual coverage, resource ownership,
blockers, and cleanup. Only bounded container runtimes and sequential test shards
are used. At opening the host has about 18 GB available and no rewrite test
containers running. Retain disposable volumes for the separately planned cleanup;
remove only this run's exact containers and networks when no longer needed.

The final checkpoint uses the existing milestone orchestrator and the exact
verified coverage floors. Keep substantial-data load, renderer fidelity, external
SSO interoperability, paired UAT, and clinical sign-off separate from synthetic
technical evidence. All intended diffs are staged for review; nothing is committed
or pushed, including planning-repository changes.

At 23:31 BST the user requested four hours of low-token, long-running work.
Until 03:31 BST on 7 September, prioritize rebuilt-image milestone verification,
bounded full test runs, existing query and renderer checks, and component scans.
Defer new functional implementation during this window. Investigate attributable
failures only as needed to keep verification useful. Continue recording hourly
evidence and resource ownership; the 09:00 BST terminal condition is unchanged.

During this window the user explicitly requested a one-hour conversation sleep
at the next safe boundary. That timed sleep completed and automatic resumption
was recorded at 02:36 BST. The bounded renderer job continued unattended; source
edits and database transactions were closed before the pause. This is an
authorized exception to the no-idling rule, not an early handoff or cancellation
of the 09:00 BST terminal condition.

At 03:27 BST the user ended the low-token verification focus and requested
functional porting again. Prioritize complete source-faithful behavior and the
connections between workflows, with focused parity, authorization, audit and
query checks. Do not spend another block on endurance or speculative foundations.
The active slice is transactional user-role administration and the shared SSO
assignment action: preserve direct grants and retained conditions, revoke removed
roles, reject stale edits, and keep assignment changes atomic with audit. Provider
response verification and runtime role-to-clinical-capability activation remain
separate mandatory work; an internal assignment action does not prove SSO login.
Continue the existing dependency order without a new planning pause unless a
genuine architecture decision requires user input. Full regression evidence from
before new porting is a baseline, not a verification claim for subsequent edits.

At 04:35 BST the transactional role writer and its administration page have
focused backend and browser evidence. The writer uses current assignment reads,
shared definition locks and bounded retries; both MariaDB snapshot-isolation
modes are tested. Role, audit, notification, manifest and ledger checks passed
121 tests. Source-faithful SSO assignment remains an internal verified seam, not
an active external provider or completed clinical permission graph.

The next implemented profile slice is out-of-office configuration and the
primary/CC message-recipient warning. The combined current backend pack passed
123 tests with 37,971 assertions. Warnings use one query for up to six selected
mailboxes; the profile uses one domain query plus four cold context queries.
Configuration history and audit are atomic. The initial schema packet is applied
to the disposable fixture; clean seven-schema recreation is still a final gate.
The first browser attempt proved save/reload but omitted the existing event Edit
tab; the corrected tracked flow passed once with zero page, console, HTTP or
stderr errors. No message was sent, original settings were restored and only its
new disposable event was soft-deleted during cleanup. The warning requests each
used one query; temporary browser and web containers were removed.

Strict ledger counts are 14,125 canonical paths, 18,643 rows, zero missing,
1,220 pending reviews and 1,290 unowned paths, with zero unowned code. Overall
coverage is 73.2251 percent and code coverage 77.1585 percent. The opening baseline
is immutable; assertions now check non-regression against it rather than forcing
the current ledger to remain identical. Next port bounded mailbox name lookup
and selected-recipient validation, then continue the source-reviewed Stage 2
portfolio. Event edit and age-lock rules are under review; do not infer a clinical
module override or administrator status.

At 05:00 BST bounded mailbox search, selected-recipient validation and the shared
primary, CC and inbox sender picker are complete. The current focused pack passes
113 tests with 35,687 assertions. Both browser checks passed without retries or
browser errors. Search uses at most two queries for small and 1,000-mailbox
fixtures, with selected recipients retained across search pages. Query-plan
registry coverage is now 49 statements. A reproduced batch-element validation
context override is fixed and covered. Coverage is unchanged at 73.2251 percent
overall and 77.1585 percent code; the existing MailboxFinder credit is not counted
again. Current source inventory is 5,353 files. The development image used for
the browser includes the current UI but predates the final backend correction;
all eight image rebuilds and the full current-source milestone remain final gates.

Next port the source-reviewed patient activity hotlist, currently a placeholder,
with owner-only mutations, bounded patient projections, same-day reopen behavior,
and manager-owned automatic closing. After-next is integration of the remaining
source-supported Stage 2 cohort if time permits. No new functional scope starts
after 07:00 BST. Clinical permission activation, external SSO, migrated-volume
load, UAT and component-security release gates remain explicitly open.

At 06:00 BST the owner-only patient hotlist is implemented and its final focused
pack passes 101 tests with 38,101 assertions. The first browser walk passed with
zero errors and zero retries. Reads remain at most six queries with small and
1,000-patient fixtures; close batching is manager-owned, with no database
automation. Display theme now reuses the scoped settings contract and supports
Default, Light, Dark and Auto. Its corrected 51-test pack and 76-test ledger pack
pass. The first theme browser walk found an implicit-label accessibility issue
before changing any preference; an explicit label is fixed but awaits rebuilding
and a separately recorded corrected walk. The original failure is retained.

Patient details now consume the already imported telephone, death date and
ethnicity without changing the panel layout. The current details, PAS and access
pack passes 36 tests with 343 assertions. Small and 1,000-unrelated-contact reads
use equal query counts with one indexed contact projection and no sort or temp
table. The synthetic browser walk and source reconciliation are current work.
Patient merge and deleted-record exceptions remain separate source-rule work.

Next finish these two browser gates and their ledgers. After-next is the next
source-supported Stage 2 slice before 07:00, then all eight current-source images,
clean seven-schema migration, full PHP and browser milestone. Verification state
is focused-green and browser-partial, not integrated-green. Coverage remains
73.2251 percent overall and 77.1585 percent code. Exact canonical counts remain
14,125 paths and 18,643 rows with zero missing, 1,217 pending and 1,287 unowned;
unowned code is zero. Inventory additions earn no credit. Shared database and
Redis stay memory-capped; temporary browser and web containers are removed after
each walk. No commit or push. The 09:00 safe-checkpoint terminal guard remains.

At 06:41 BST the bounded preferred-site editor and selector integration are
implemented. Preferences never grant access or silently change current context.
Its small and 1,004-site fixture uses five page/context queries, with no N+1,
filesort or temporary table. The 110-test focused and ledger pack passes with
35,919 assertions. A further 13-test import/details pack passes with 97 assertions
and real CSRF enforcement. All 49 JavaScript unit tests and the full 3,084-file
style check pass. Query-plan registry coverage is 53 statements and the source
inventory is 5,386 files; neither figure earns legacy coverage.

Theme browser testing found and fixed both an implicit label and same-URL Inertia
reload event handling. The corrected theme walk passes. The patient-details walk
exposed a real machine-integration CSRF omission, now corrected with independent
Basic authentication and no browser/session exemption. Its next failure was an
oversized synthetic identifier, corrected without weakening application
validation. Preferred-site browser assertions now open the actual context picker.
Both corrected walks pass with zero errors and zero retries within each walk;
all earlier failures are retained. The runtime image and separately mounted
corrected script identities are explicit, not full current-source milestone proof.

One disposable database exceeded its 1,536 MiB cgroup limit. The host still had
about 18 GiB available. The interrupted run was retained, the affected test
container stopped, and only that database's memory/swap cap raised to 2,048 MiB.
Recovery and transaction rollback were confirmed before the green rerun.
Temporary browser/web containers are removed after every walk; volumes remain
for the existing later cleanup task.

New functional scope closes early at this safe boundary. Current work is clean
seven-schema recreation, rollback/reapply of the three new migrations before
seeding, then all eight current-source images and the complete milestone. The
09:00 BST terminal guard remains. During immutable-image verification, hourly
and final evidence goes to the external run directory and this active plan;
do not edit packaged progress CSVs and silently invalidate the measured images.
The final checkpoint must record the exact image/source identities and any
attributable failures, not reuse the opening full-suite result.

Next port the remaining Stage 2 account/profile and patient identity behavior
after integration. Separate preferred firms from permissions and reconcile the
older UserFirm ledger mapping: user_firm is a versioned preference, not
firm_user_assignment or user_firm_rights. Its earlier 100-point model mapping
needs a path-specific review before declaring final coverage. Site addresses,
service-level rights, institution-auth selection, password lifecycle, patient
merge/deleted-record exceptions and historical import remain open. Do not infer
these rules or claim that the application is complete. Reported ledger totals
remain 73.2251 percent overall and 77.1585 percent code, subject to that review.

At 07:00 BST all eight source-matched images are rebuilt. Clean initialization
applies 318 migrations across seven schemas; tiny seed, 53 query-plan budgets,
49 JavaScript tests, production build, 3,084-file style check, all image checks,
and real Compose and Helm startup pass. The complete Pest suite is running and
has reported a Cover Test query-growth assertion in its first feature shard.
Preserve the exact failure before diagnosis; do not call this integrated-green.
The final seven-scenario browser manifest remains pending behind that gate.

The temporary Compose verification stack lacked application/database memory
limits. Runtime-only limits were applied to its exact owned containers; the
successful check removed that project. Next diagnose attributable suite failures
and make those limits permanent through a test-only Compose override, without
changing production defaults. After-next rebuild source-matched images and rerun
the complete milestone. New functional scope remains frozen and the 09:00 safe
checkpoint terminal condition remains. Counts and provisional coverage are
unchanged. External checkpoint-0700.json records source identities, evidence,
blockers and resource state; do not mutate packaged progress during this run.

At 07:17 BST the complete 403-file Pest manifest has finished: 3,065 passed and
four failed out of 3,069 tests, with 88,063 assertions. Exact failures were the
new shared theme's cold-query cost against three old page ceilings and one old
scheduler count before hotlist-close. The corrective 63-test pack passes with
498 assertions. Cover Test now compares equally warm one-entry and 100-entry
fixtures, while retaining a separate cold ceiling; settings independently prove
two cold queries and zero warm. The added manager job is asserted exactly once.

The UserFirm preference-versus-permission review is complete. Its model's 100
points and factory's 90 points were invalid and are removed. Current UserSite
storage and owner-site fixtures now score 90 after their focused, browser and
clean-chain evidence; historical import remains open. No other new slice earns
extra credit here. Exact coverage is now 73.2152 percent overall and 77.1463
percent code, with 415 zero-score and 546 deferred code paths. The 14,125
canonical paths, 18,643 rows, zero missing, 1,217 pending, 1,287 unowned and zero
unowned code are unchanged. Opening snapshots and overall ratchets stay intact;
the single named correction is tested. The reconciled ledger/site pack passes
62 tests and 35,474 assertions.

The Compose verifier now applies a test-only resource-limits file from startup
and asserts actual cgroup memory, swap, CPU and PID limits. Production defaults
are unchanged. Next stage these corrections, rebuild all eight images and run
the complete milestone into a new evidence directory, retaining the failed run.
After-next complete independent randomized verification and reconcile the final
checkpoint. New functional scope stays closed until the next run. The 09:00
terminal guard and later historical-data, security, UAT and clinical gates remain.

At 08:00 BST the corrected fixed-file-manifest PHP pass has completed all 403
files: 3,070 tests, 88,086 assertions, zero failures, errors or skips. It used
captured within-shard random ordering, not ordinary Pest order. Five browser
scenarios passed; the sixth timed out at login and the seventh was not reached.
An unchanged-image diagnostic then proved five successful logins followed by
HTTP 429 with Retry-After 57. The production limiter remains unchanged. The
browser runner now waits 61 seconds after each group of five one-login scenarios,
with no automatic retries. Its regression and all 50 JavaScript tests pass.

The milestone now prevents the second-pass seed leaking into the first pass.
The long pre-Pest formatting/static helper also receives the existing shard
memory, swap, CPU and PID caps. All eight images were rebuilt against application
digest 6e63ca91abc423ff873c51cd3bdf8899c79d0d7c5b09cd382909a57df3905eba.
Docker context identity is unchanged because its test tooling is excluded;
ordinary-image-identities.json records the separate current harness hashes.
The source remains frozen and both product repositories have no unstaged tracked
changes. The builder is stopped again; retained database volumes are untouched.

The fresh ordinary-order milestone is running with independent schemas and
Redis state. Clean 318 migrations, seven-schema verification, strict ledger,
1,695-action census, all 53 registered query budgets, module and schedule checks,
initial formatting and JavaScript tests have passed. Build, image, Compose,
Helm, full Pest and the seven-scenario browser gate remain the current sequence.
After-next is an independent fresh schema/Redis pass that shuffles the complete
test-file manifest before sharding with master seed 2026090703. Require an
explicit ordinary-order result plus the independent shuffled result, not two
copies of fixed alphabetical shard assignment.

Coverage remains 73.2152 percent overall and 77.1463 percent code; all canonical
counts and the named UserFirm correction are unchanged. Fresh online Composer
and npm audits report zero advisories against the exact lockfiles; this does not
clear the separate container security release gate. External checkpoint-0800.json
records full verification state, next and after-next work, ownership and deferrals.
The profile/context closure review confirms that preferred firms, permission
grants, service rights, institution authentication and the profile PIN/password
lifecycle remain distinct mandatory next-tranche behavior. No further functional
scope opens in this run. The 09:00 BST safe-checkpoint terminal guard remains.

At 08:53 BST the previous immutable source completed both independent full PHP
passes: 403 files, 3,070 tests and 88,086 assertions per pass, no failures, errors
or skips. The ordinary pass used no random seed; the second used fresh schemas,
separate Redis state and a shuffled manifest. All seven paced browser scenarios
passed with zero retries. These results remain prior-build evidence, not proof
of the correction below.

Final review at 08:39 reproduced an outbox replay bug in both MariaDB snapshot
modes. An identical occurrence committed by another connection was invisible to
the source transaction's older snapshot and was falsely reported as different
data. The duplicate lookup now uses a shared-lock current read. Snapshot mode
may raise MariaDB 1020; the complete owning transaction must handle the bounded
retry, never just an outbox fragment. The two-mode regression preserves true
divergent-payload rejection. The focused pack passes 105 tests and 640 assertions;
the initial failed test assumption and reproduction logs are retained.

All eight images were rebuilt with application digest
316b6124039f550af776ead0182cb57e28d495f510783166135c6d3e7f217ff0.
The final short schema-hashing helper is now resource-capped too, and its actual
limits and unchanged hash output were verified. Docker context identity remains
0c1c3596ea19efc4828311bfe9b96b55301b92b2cd9168627a17302e2c4f05b7.
The corrected ordinary milestone has completed fresh migrations and initial
contracts and is running the remaining checks. After-next is a fresh independent
fully shuffled pass with master seed 2026090704. These required checks may cross
09:00; finish only at the next safe verified checkpoint. No new functional scope
has opened and coverage credit is unchanged.

Exact rebuilt runtime-image security scans are retained separately: each PHP
runtime image reports four high and two critical package findings; the unchanged
renderer reports 95 high and eight critical findings. Counts are per package and
target, not unique vulnerabilities. The security release gate remains open.
The builder is stopped; disposable database restarts preserve its exact image,
settings, limits and retained volume. Only this run's owned transient resources
may be cleaned up. The final outbox evidence directories supersede the earlier
full-pass directories for integration acceptance.

At 09:00 BST the time guard is satisfied, but the integration guard is not yet
satisfied. The corrected image has passed 318 clean migrations, seven-schema
checks, the strict ledger, 1,695-action census, all 53 query budgets, 50 JavaScript
tests, frontend build, image isolation, Compose and Helm. The final static helper
is running before full ordinary-order PHP and seven paced browser scenarios.
After-next is the independent fresh shuffled pass, exact evidence comparison,
staging and owned resource cleanup. External checkpoint-0900.json records source
and harness identities, verification state, next work, deferrals and resource
ownership. Coverage remains 73.2152 percent overall and 77.1463 percent code.
Continue to the first safe verified checkpoint; no new functional scope opens.

## Appendix A — Naming and pattern rules (enforced by lint/arch tests)

Database

1. Tables: snake_case, plural, ≤ 40 chars; module-owned tables use a registered ≤ 8-char prefix (`exam_`, `opbook_`, `corr_`…); core tables have no prefix; archive copies `archive_<table>`; read models `<noun>_summaries`/`_projections`.
2. Columns: snake_case; PK `id`; FK `<singular>_id`; booleans `is_/has_/can_`; datetimes `_at`; dates `_on`; no type suffixes, no Hungarian, abbreviations only from the registry (`iop`, `va`, `nhs`, `dob`, `uuid`).
3. Lookup tables: `<prefix>_<noun>_types|statuses|methods` with `id, code (unique), name, display_order, is_active`; referenced by `<noun>_type_id`.
4. Indexes/FKs: Laravel default names; unique constraints on natural keys; every FK indexed; no ENUM; JSON allowed only where 5.2 permits.
5. Comments: table `cat=…; owner=…; retention=…; versioned=yes|no`; column `class=pii|phi|secret|free_text|identifier` where relevant.

PHP

6. Namespaces `Modules\<Module>\<Layer>`; one class per file; suffixes `Action`, `Request`, `Resource`, `Policy`, `Job`, `Event`, `Listener`, `Factory`, `Seeder`, `Test`, `Command`; DTOs in `Data` without suffix; enums singular in `Enums`.
7. Actions expose one public method `handle()`; controllers only call Actions; models never in views; no `DB::raw` outside `Core\Database\Raw`.
8. Strict types, `final` by default, typed properties, PHP enums for closed sets, readonly DTOs, no `env()` outside config, no static mutable state.

Routes/API/UI

9. Routes kebab-case, names `module.resource.action`; canonical API `/api/<resources>` with uuids; API Resource field names match DB column names in snake_case.
10. Blade views `modules/core/<Module>/Views/<feature>/<action>.blade.php` for first-party code; custom modules mirror the path under `modules/custom`; components `x-oe-<thing>`; legacy ids/classes preserved verbatim.
11. Artisan `oe:<module>:<verb>-<noun>`; config keys `openeyes.<module>.<key>`; setting keys `<module>.<feature>.<key>`.
12. Git: branches `feat/<module>-U<id>`, commit trailers `Unit: U<id>`, `Migrates: <legacy path>`, `Fixes: <bug id>`; tests named `it('does x when y')`.

## Appendix B — Table categories

| Code | Meaning | Truncate/reset | Export bundle | Anonymise scope | Versioning default |
|---|---|---|---|---|---|
| `system` | framework/infra (migrations, jobs, cache, sessions, pulse) | never | no | no | none |
| `config` | installation/institution/site/firm/user settings, templates, macros | never by tooling | yes | no | audit (B) |
| `reference` | coded clinical/reference sets (drugs, procedures, IOL models, lookups) | never | yes | no | none |
| `identity` | users, roles, permissions | never | yes (roles/permissions), users optional | staff PII yes | audit (B) |
| `patient` | demographics, identifiers, contacts | never | no | yes | system-versioned (A) on listed tables |
| `clinical` | episodes, events, elements, documents metadata, read models | never | no | yes | A on listed tables |
| `audit` | history, audit_changes, access logs | retention job only | no | yes | none |
| `operational` | notifications, locks, imports staging, worklist caches | seeders may reset | no | yes | none |
| `integration` | inbound/outbound payload staging and quarantine | retention job | no | yes | none |
| `archive` | warm copies of patient/clinical | archive job only | no | yes | none |

## Appendix C — Tracker schema (sketch)

```sql
CREATE TABLE legacy_files (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, path VARCHAR(500) NOT NULL UNIQUE,
  module VARCHAR(64), kind VARCHAR(32), sha CHAR(40), loc INT, status VARCHAR(16) NOT NULL DEFAULT 'pending',
  evidence JSON CHECK (JSON_VALID(evidence)), target_paths JSON, unit_id BIGINT UNSIGNED, tokens_used INT,
  pr_url VARCHAR(255), updated_at TIMESTAMP, INDEX (module, status), INDEX (unit_id));
CREATE TABLE legacy_tables (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, name VARCHAR(64) UNIQUE, module VARCHAR(64),
  rows_est BIGINT, category VARCHAR(16), decision VARCHAR(16), new_table VARCHAR(64), proof JSON, packet_id INT);
CREATE TABLE legacy_columns (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, table_id BIGINT UNSIGNED, name VARCHAR(64),
  type VARCHAR(64), profile JSON, decision VARCHAR(16), new_table VARCHAR(64), new_column VARCHAR(64), proof JSON,
  UNIQUE (table_id, name));
CREATE TABLE walks (id BIGINT UNSIGNED PRIMARY KEY, module VARCHAR(64), role VARCHAR(32), steps_hash CHAR(64),
  golden_path VARCHAR(255), query_count INT, digests JSON, status VARCHAR(16), unit_id BIGINT UNSIGNED);
CREATE TABLE units (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, module VARCHAR(64), title VARCHAR(255),
  manifest JSON, model_tier VARCHAR(16), tokens_in BIGINT, tokens_out BIGINT, status VARCHAR(16),
  started_at TIMESTAMP NULL, finished_at TIMESTAMP NULL, pr_url VARCHAR(255));
CREATE TABLE bugs (id BIGINT UNSIGNED PRIMARY KEY, external_id VARCHAR(32), title VARCHAR(255), module VARCHAR(64),
  parity_exception TINYINT(1) DEFAULT 0, spec TEXT, unit_id BIGINT UNSIGNED, status VARCHAR(16));
CREATE TABLE features (id VARCHAR(24) PRIMARY KEY, module VARCHAR(64), kind VARCHAR(24), name VARCHAR(255),
  description TEXT, roles JSON, legacy_sources JSON, walk_ids JSON, status VARCHAR(24), unit_id BIGINT UNSIGNED);
CREATE TABLE feature_tests (feature_id VARCHAR(24), test_kind VARCHAR(16), test_ref VARCHAR(255),
  PRIMARY KEY (feature_id, test_kind, test_ref));
CREATE TABLE commands (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, kind VARCHAR(16), name VARCHAR(128),
  source VARCHAR(255), target VARCHAR(255), status VARCHAR(16));
CREATE TABLE legacy_routes (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, method VARCHAR(8), pattern VARCHAR(255),
  hits_90d BIGINT, new_route VARCHAR(255), status VARCHAR(16));
```

## Appendix D — Tooling (pin on adoption)

Laravel 13.x, PHP 8.4, MariaDB 11.8, FrankenPHP 1.x (`dunglas/frankenphp`), Octane, Horizon, Pennant, Pulse, Sanctum, `laravel/mcp`, `laravel/boost` (dev), Pest 4 + browser/mutate/type-coverage plugins, Playwright (TS), Larastan, Pint, Rector, Psalm (taint), Deptrac, `spatie/laravel-data`, `spatie/laravel-query-builder`, `dedoc/scramble`, `league/commonmark`, `mews/purifier`, `nikic/php-parser`, `shipmonk/dead-code-detector`, `composer-unused`, Percona Toolkit (`pt-query-digest`, `pt-duplicate-key-checker`), Trivy/Grype, OSV-Scanner, Renovate, CycloneDX, Filament (tracker), Lighthouse CI, OWASP ZAP, mariadb-operator, KEDA, MinIO/Garage, hadolint, shellcheck, sqlfluff, eslint-plugin-playwright, Syft, cosign, Kyverno, OpenVEX, MariaDB Server Audit plugin.

## Appendix E — Open questions

1. Walk storage format and where preconditions/fixtures live (adapter design in §4.3).
2. IOLM and payload processor: exact inputs (folders, XML/DICOM schemas, endpoints), volumes, ack semantics.
3. Coding standards document location (to encode in Pint/phpcs).
4. Retention policy per record class and who signs it off.
5. Hosting targets (single on-prem cluster vs many institutions), and whether sharding by institution is on the horizon.
6. Rollback policy for writes during the post-cutover window.
7. Licence decision for the new codebase.
8. UX-change sign-off owner.

## Appendix F — Static analysis rule catalogue (initial)

Implemented in `openeyes-phpstan-rules` (PHPStan rules with tests; Rector autofix where possible), Pest arch presets, ESLint (`eslint-plugin-playwright`) for TypeScript tests, hadolint, shellcheck, sqlfluff (mysql dialect) for `.sql` seeds. Every message ends with `see docs/standards/rules/<id>.md`.

Migrations

- OE-MIG-001 No loops (`foreach`, `for`, `while`, `do`) in migration files.
- OE-MIG-002 No Eloquent models, events or facades other than `Schema`/`DB` in migrations (models drift; migrations are frozen in time).
- OE-MIG-003 Data changes are set-based SQL (`DB::statement`, `DB::table()->update/insertUsing/upsert`); `->get()`, `->each()`, `chunk()`, `cursor()` are forbidden in migrations.
- OE-MIG-004 One structural theme per file; name `YYYY_MM_DD_HHMMSS_<verb>_<table>[_<detail>]`.
- OE-MIG-005 Every `create` sets the table category comment via the macro; every classified column has its `class=` comment.
- OE-MIG-006 `down()` present and exercised in CI (`migrate:rollback` of the last N); no drops of `system`/`config` tables outside `down()`.
- OE-MIG-007 No `env()`, HTTP, filesystem access, `sleep`, or `now()` in migrations.
- OE-MIG-008 Released migrations are immutable (`migrations.lock`, 5.13).
- OE-MIG-009 Long-running data changes belong to `oe:data:*` commands run by the migration Job, not to schema migrations.

Models and data

- OE-MOD-001 `#[TableCategory]` present and equal to the DB comment.
- OE-MOD-002 Factory exists for every model.
- OE-MOD-003 Explicit `$fillable`/`$casts`; relations have return types.
- OE-MOD-004 Anonymisation map covers every classified column (§6.10).
- OE-MOD-005 No cross-module relations except through `Core` interfaces.

Queries

- OE-SQL-001 No `DB::raw`/`whereRaw`/`selectRaw` with interpolated strings outside `Core\Database\Raw`.
- OE-SQL-002 Every `get()`/`paginate()`/`cursorPaginate()` chain used for lists has `orderBy` (or `latest/oldest`) with a unique tiebreaker.
- OE-SQL-003 No queries in Blade views or in loops over collections (N+1 shape).

Actions, HTTP, views

- OE-ACT-001 One public `handle()` per Action; controllers only call Actions and return views/resources.
- OE-HTTP-001 Every mutating or parameterised action type-hints a FormRequest.
- OE-VIEW-001 No `{!! !!}` outside the purifier component; no inline `<script>` without the CSP nonce component.
- OE-OCT-001 No static mutable state, no `app()` singletons holding request data (Octane safety).

Tests

- OE-TST-001 No `sleep`/`usleep`/`waitForTimeout`; OE-TST-002 no unfrozen `now()`; OE-TST-003 no `markTestSkipped` without ticket id; OE-TST-004 no assertion-free tests, no `assertTrue(true)`, no `expect.soft`; OE-TST-005 no `retries` in Playwright config; OE-TST-006 no `--update-snapshots` in CI scripts.

Ops

- OE-OPS-001 Dockerfiles: pinned digests, non-root, healthcheck, no `latest` (hadolint + custom); OE-OPS-002 shell scripts pass shellcheck; OE-OPS-003 Helm charts lint and render with the test values.

## Sources

https://laravel-news.com/laravel-13-released
https://laravel.com/docs/13.x/releases
https://laravel.com/docs/13.x/mcp
https://laravel.com/docs/13.x/boost
https://laravel.com/docs/13.x/octane
https://frankenphp.dev/docs/laravel/
https://pestphp.com/docs/pest-v4-is-here-now-with-browser-testing
https://mariadb.org/11-8-lts-released/
https://mariadb.com/docs/release-notes/community-server/11.8/what-is-mariadb-118
https://code.claude.com/docs/en/monitoring-usage
