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
- Naming lint for DB (5.12) and for routes/API (`kebab-case` paths, versioned `/api/v1`, resource nouns).
- Project-specific pattern rules live in `openeyes-phpstan-rules` (App. F): each rule has an id (`OE-MIG-001`), a one-line message ending in a docs URL, a rationale page with good/bad examples, and its own tests. No PHPStan baseline files are permitted, so the violation count on `main` is always zero; new rules land with the code that satisfies them.
- Everything above runs in the pre-commit hook and CI; failures are cheap, deterministic feedback (§10.4).

### 6.5 API-first

- Every capability is an Action; web controllers and `/api/v1` controllers both call Actions and return either a Blade view or an API Resource. No logic in controllers.
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
- Resultant config for a running instance: `php artisan oe:config:show [--json] [--scope=institution:X --scope=site:Y]` prints the effective value of every variable with its source (default → config file → environment → `_FILE` secret → DB setting at each scope) — secrets redacted to their source ("set from `DB_PASSWORD_FILE`"). The same view is available read-only in the admin UI (`/admin/config`) and as `/api/v1/system/config` for tooling; `oe:config:diff <instance-export>` compares two instances. This replaces "read `common.php` on the box".
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
16. Long transactions (archive, anonymise, read-model rebuild) against live traffic: no lock waits beyond threshold; online DDL from a migration Job during traffic.
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
- API and config compatibility: `/api/v1` additive-only, deprecations announced one release ahead with `Deprecation`/`Sunset` headers; setting definitions versioned with export-bundle upgrade transforms; walks and goldens versioned per release — after cutover the parity suite becomes the regression suite with goldens taken from the previous release.
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
- M0 "walking skeleton" — target week 6–8 from start (Phase 2 runs from week 1 alongside Phases 0–1; M0 needs only the core design packet, which is Phase 1's first output): a stack on your server (compose, later Kubernetes) with login (users/roles from the first ETL mapping, anonymised), the identical UI shell from `@openeyes/ui`, patient search, read-only patient overview and one read-only event view, `/api/v1/patients`, `/docs`, `oe:doctor`, refreshed nightly from the anonymised legacy snapshot by the early ETL. Its core schema is provisional (schema reset points allowed until v1.0, 5.13). Feedback goes into the tracker as bugs/UX notes against walks. To make this happen the core design packet (patients, episodes, events, users, institutions) is the first Phase 1 output and the ETL for those tables is built before anything else.
- M1: pilot modules fully migrated with parity green; token model calibrated.
- M2: core and top-traffic modules migrated; dark launch starts.
- M3: all units migrated; rehearsals in window; cutover.

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

9. Routes kebab-case, names `module.resource.action`; API `/api/v1/<resources>` with uuids; API Resource field names match DB column names in snake_case.
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
