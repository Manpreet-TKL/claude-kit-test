# OpenEyes History Knowledge Base - build plan

Authored 2026-07-17. Architecture reviewed by codex gpt-5.6-sol at xhigh effort; its five
structural corrections are folded in below and marked [Sol].

## Context

The goal is to capture the entire development history of OpenEyes - every commit, every
Jira ticket, release notes, Confluence docs, and (later) PR discussions - into an offline,
continuously-updatable corpus that:

1. Claude can query fast and precisely ("when was table X introduced", "summarise new
   features in v26.0", "find manual client-data fixes not tied to a ticket").
2. An OpenEyes admin module can browse.
3. A small locally-trained model can act as an offline answer engine over it.
4. Carries a DBA intelligence layer for live databases (health, growth, dump-time,
   per-version pinch points).

Jira is contacted once for backfill then only for deltas; GitHub is read from the local
clone only (PR-API harvesting designed now, built later); the end tool is a docker image
you pull to update.

## Design principles (the five [Sol] corrections that reshape the naive design)

1. **Physical separation, not a `sensitive` column.** OE, TKLS, and live-site
   observations live in three separate database files with separate keys, indexes, and
   mounts (`history-core.db`, `history-tkls.db`, `site-<id>.db`). A flag column is not a
   security boundary. Files and permissions are the boundary.
2. **No single migrated database walked across tags.** OpenEyes history is a DAG with
   concurrent release lines; running an old checkout against a DB migrated by a newer one
   manufactures false schema history. Reset the DB per snapshot; reuse only the container.
3. **Retrieval is part of the answer engine, not a fallback.** Hybrid retrieval (FTS5 +
   exact-identifier columns + a small vector sidecar) - FTS alone misses "make users
   inactive" vs "disable staff". New facts reach users through retrieval immediately.
4. **Model weights are not how facts get in.** Retraining is for behaviour/vocabulary;
   facts arrive via the nightly corpus+retrieval update. Never retrain on deltas alone.
5. **Promise what the sources can contain.** Not "all manual fixes" (SQL typed straight
   into prod is invisible to git) and not "everything a DBA does" (read-only probes can't
   guarantee a restorable backup). Precise claims + visible uncertainty.

Overarching shape [Sol]:

```
 OE git/Jira/Confluence bronze
        -> history-core.db + hybrid index -> API/MCP -> OE admin + answer engine
        -> training sandbox (mounts core ONLY) -> one 4B OE model
 TKLS bronze  -> history-tkls.db  --\
 live probes  -> site-<id>.db     --> privileged LOCAL overlay only (never trained on,
                                      never exported, never in an image layer)
```

## Decisions already made

1. **Sequencing (hard rule):** corpus built and verified FIRST; model phase strictly
   after. Standing cycle: pull delta -> rebuild derived -> re-enrich -> publish index
   (facts live here) -> THEN optional retrain behind an eval gate.
2. **Compute:** can rent/borrow if essential - concrete options + a recommendation below.
3. **GitHub:** design PR schema now, build harvester later.
4. **Model role:** must be the offline answer engine (retrieval-grounded counts as that),
   small, OpenEyes-only, updatable. Honest version designed below.
5. **Jira scope:** OE + TKLS; TKLS client-sensitive, physically isolated, never trained on.
6. **DBA layer:** read-only intelligence/advisory - health, growth, dump-time, per-version
   pinch points.

## Toolchain - FOSS and containerised (hard constraint)

Every tool the pipeline builds, runs, trains, or serves with is open-source and runs in a
container (`docker compose run`/`up`) - no host installs, and no proprietary or paid cloud
service anywhere in the build or serve path. The shipped image updates and answers fully
offline; enrichment and training use local open-weight models, never a cloud LLM API.

Honest caveats (per the "call out what can't be FOSS" rule):
- **Source systems are external SaaS.** Jira Cloud, Confluence Cloud, and (later) GitHub
  host the source data; we read them once via their APIs from FOSS, containerised harvester
  clients. That is data provenance, not a toolchain dependency - nothing downstream needs
  them, and the offline artifact never calls them again.
- **GPU training needs the proprietary NVIDIA driver.** The `train` image itself is FOSS
  and uses the Apache-2.0 nvidia-container-toolkit, but the host driver + CUDA runtime are
  closed (unavoidable hardware enablement). Inference is CPU-only llama.cpp - no driver,
  fully FOSS. A rented/borrowed GPU box supplies the driver; we install nothing on it but
  the container runtime.
- **Claude is an optional consumer, never a build dependency.** The finished KB is a
  client-agnostic artifact (SQLite + HTTP/MCP API); the local 4B model + web UI + MCP
  operate it with zero proprietary software. Claude Code can also query it (a nicer
  reader), but building, updating, and serving the KB require nothing proprietary.

| Component | Role | Licence | Container |
|---|---|---|---|
| Python 3.12 | pipeline runtime | PSF | `pipeline` |
| MariaDB 11.8 / 10.6 | schema-archaeology snapshot engine | GPL-2.0 | official image |
| nikic/php-parser (PHP 8) | static migration parsing | BSD-3 | `php` |
| Tesseract | attachment OCR (allowlisted) | Apache-2.0 | in `pipeline` |
| SQLite + FTS5 | published corpus + full-text | public domain | embedded in `serve` |
| sqlite-vec (or FAISS / hnswlib) | vector sidecar | Apache-2.0 / MIT | embedded in `serve` |
| bge-small / e5-small / nomic-embed | local embeddings | MIT / Apache-2.0 | `embed` (sentence-transformers) |
| Qwen3-32B or Mistral-Small-3 | local enrichment/teacher model | Apache-2.0 | `vllm` (GPU) / `llama.cpp` (CPU) |
| Qwen3-4B | offline answer engine | Apache-2.0 | `llama.cpp` / `ollama` |
| transformers + peft + trl + bitsandbytes (or Axolotl) | QLoRA training | Apache-2.0 / MIT | `train` (+ nvidia-container-toolkit) |
| llama.cpp / ollama | Q4 GGUF inference | MIT | `serve` |
| FastAPI + our MCP server + OE Yii module | query surfaces | MIT / our code (AGPL) | `serve` / OE container |
| docker compose + cron | orchestration | Apache-2.0 | host |

Licence gate: every open-weight model and library is checked for an OSI-approved or
Apache-2.0 licence before use. Explicitly excluded as non-FOSS: Llama-family checkpoints
(Llama Community licence + MAU clause), Gemma (Gemma licence), and Qwen Research-licensed
sizes such as Qwen2.5-Coder-3B (non-commercial). Default to Apache-2.0 Qwen3 / Mistral-Small.

## Verified facts (repo recon)

- Clone `/home/toukan/openeyes`, full (not shallow), origin `git@github.com:OpenEyes/openeyes.git`.
- develop 39,044 commits; 48,421 across refs; history from 2011-01-10.
- 457 tags, 374 release-shaped, `1.2.9` -> `v26.1.0-pre2`. Naming inconsistent (optional
  `v`, `-RC`/`-rc`/`-pre`/`-alpha`, mixed case).
- All work lands on `develop`; long-lived `release/<maj>.<min>.x` per line (only 10.0.x,
  11.0.x, 26.0.x, wales-7.0.x still on origin - old branches deleted, tags survive); cuts
  tagged `vN.N.N`, merged to `master`; fixes cherry-pick between lines (different SHAs).
  Multiple lines current at once (v11.0.18 + v26.0.4). Versions 1..12 then year-based (26).
- ~54% of commit subjects carry a Jira key (21,237/39,044).
- Squash merges: 13 of last 3000 are "Merge pull request" - commit->PR needs the GH API.
- Migrations: 740 core + ~1450 in 37 module dirs (~2190). Single timestamp-sorted runner
  (`OEMigrateCommand`), shared `tbl_migration`. Core history starts at
  `m130913_000000_consolidation.php` - pre-Sep-2013 migrations were squashed; old-era
  schema truth needs old tag checkouts.
- DB MariaDB 10.6 (v6-v10) / 11.8 (v11+); v26 ~2330 base + ~1060 `_version` + 57 views.
  ~99% of tables carry created/last_modified user+date; `_version` appends per save.
- Jira Cloud: OE ~13,000 issues + TKLS desk. Confluence OPD: release notes (v6+), release
  timeline, supported-version policy, coding standards, per-event admin guides.
- Pre-v6 history hazy; schema archaeology there is git-only.

## Data model (silver/gold in history-core.db)

Beyond the obvious `issue / issue_comment / issue_link / issue_changelog / commit /
commit_file / commit_issue / release_line / release / doc_page`, [Sol] requires these as
first-class, not afterthoughts:

- **Claim/evidence spine.** `claim`, `evidence`, `claim_evidence`, `derivation_run`,
  `conflict`, `manual_override`. Every derived assertion (summary, flag, feature date)
  points to exact evidence: issue+comment version, commit OID + diff-hunk hash, migration
  blob hash, Confluence page version, or a probe observation. Citations stay stable even
  after the source changes. This is what makes "cite or abstain" enforceable.
- **Schema as events, not a pair.** `schema_event` (introduced / removed / renamed /
  altered-nullability / altered-default / re-introduced) + `schema_snapshot` (per-tag
  object state) over tables, columns, indexes, FKs, views, triggers, collations.
  Lifecycle summaries are derived. A single introduced/removed pair is inadequate - objects
  get renamed, dropped, and reintroduced, and differ across lines.
- **Feature ontology.** `feature` (canonical) + `feature_alias` + parent/child +
  affected modules + manual merge/split. LLM extraction alone fragments "users inactive"
  / "disable users" / "staff deactivation" into three - curation resolves them to one.
- **Temporal semantics.** Distinct event dates per change: authored, committed, tagged,
  released (stable vs prerelease separately), documented, deployed, observed. Never
  collapse them - "when was X added" has a different answer per lens and per line.
- **Change linkage.** `commit_release` (first stable + first prerelease per line) and
  `implementation_group` via an evidence graph (below) kept separate from ticket linkage.
- **Enrichment/derived:** `summary`, `flag`, `version_report`, `cr_rank` (components
  exposed, not one opaque score), `growth_profile`, `perf_issue`.
- **Operational tables live OUTSIDE the published file** [Sol]: `sync_state`, job/lease
  state, training registry, enrichment cache, `probe_history`, all TKLS-derived rows.

## Milestone 1 - evidence-first core corpus, NO model (the first shippable thing)

Acceptance [Sol]: reproducible builds, exact citations, tag-DAG correctness, schema
snapshot validation. Non-sensitive (OE + Confluence + git only).

### 1a. Repo + git ingestion (offline, free)
- `oe-history/` repo: `pipeline/` (Python 3.12, all via `docker compose run` - no host
  installs), `serve/`, `db/` (gitignored), `Makefile`, own `.env` (not claude-kit's).
- `git fetch --all --tags`; per commit: sha, authored+committed dates, subject, body,
  is_merge, numstat, `git patch-id --stable`. Store OIDs + stats + selected extracted
  hunks - do NOT duplicate every diff into JSONL [Sol]; Git's object DB is the immutable
  patch source (keeps the artifact from ballooning to multi-GB).
- Parse Jira keys `[A-Z][A-Z0-9]{1,9}-\d+` from subject+body -> `commit_issue`.
- Verify: row count == `git rev-list --count --all`; 10 SHAs spot-checked; ~54% key rate.

### 1b. Release timeline + commit->version [Sol algorithm]
- **Proper release-name parser**, not `sort -V` alone: normalise optional `v`, case,
  product flavour, numeric prerelease, ordering `alpha < beta < pre/rc < stable`; store
  first-prerelease and first-stable separately; model `wales-*` as its own channel.
- Per line, attribute commits by `git rev-list <tag> --not <all prior tags on line>`.
  ~18M commit/tag visits total - not a scale problem.
- **Verify tag ancestry**: if a tag descends from its predecessor, subtract only the
  predecessor; else subtract the union and flag the topology anomaly. Preserve tagger date
  AND version order; never silently pick one when they conflict.
- `release_line` EOL/deprecation = last tag on a line once a newer line has a stable tag;
  cross-check the Confluence supported-version policy page.
- Verify: 15 random commits vs filtered `git tag --contains`; v26 dates vs Confluence.

### 1c. Schema archaeology [Sol: reset-per-tag + fingerprints]
Static parse + executable snapshots, but corrected execution:
- **Static (attribution):** parse ~2190 migrations (nikic/php-parser container; regex
  fast-path for plain createTable/addColumn/drop/rename + OEMigration helpers + CSV
  `initialiseData`) -> DDL ops -> creating commit (`git log --diff-filter=A --follow`) ->
  ticket + first release. Source archaeology starts at earliest tag 1.2.9.
- **Executable (ground truth):** reuse a MariaDB container but **reset the DB per tag**.
  Two modes: *clean-install* (fresh schema per unique state = a fresh deployment) and
  *upgrade-path* (sequential only where the next tag is a real descendant). Dump
  information_schema; diff consecutive.
- **Fingerprint-gated execution** (cheaper + still authoritative): compute a schema-input
  fingerprint per tag (migration blob hashes, baseline/import files, runner+helper code,
  module manifests affecting included migrations, engine/profile). Execute a tag only when
  the fingerprint changes; cache by fingerprint. Static parse nominates transition tags;
  require the parsed diff to match the observed `information_schema` diff, escalate
  mismatches. (40-60 `.0`+patch snapshots alone are insufficient for patch-level queries.)
- **Executable start point:** first stable tag after `m130913` consolidation whose
  checkout has a complete reproducible installer - **probe tags around Sep-2013, record
  the first reproducible one, don't guess**. Validate the machinery on v6/v11/v26 first,
  then work backwards. Era containers (php 5.x/7.x, MariaDB 10.x) for old tags;
  skip-and-log the un-runnable, fall back to static there.
- **Baseline SQL is first-class** [Sol]: hash+parse every baseline/import, snapshot after
  full install regardless of whether objects came via migration, attribute to
  `baseline:<file>@<sha>`, record whether it pre-populates `tbl_migration` and the install
  profile (default vs all modules). "Authoritative" always = for a stated tag+engine+profile.
- Verify: 10 known cases answered by SELECT (`thumbnail_*_blob` born m181219 / read-dead
  OE-15491 v26.0.0; `worklist`, `patient_identifier`, esign, user-inactive column).

### 1d. Confluence + OE Jira backfill (one supervised run)
- OE via `/rest/api/3/search/jql` (nextPageToken, 100/page) then per-issue changelog +
  comments; keep raw ADF forever + converted markdown. **Overlap window, not an exact
  `updated>=cursor`; dedupe by object version/hash; advance cursor only after the batch is
  durable; periodic full manifest reconcile** [Sol]. Realistic backfill is longer than a
  few hours once per-issue pagination + retries are counted.
- Confluence CQL `space=OPD`, **page versions not just current** [Sol]; release-notes pages
  tagged with parsed versions. Attachment metadata harvested; binary/OCR allowlisted only
  (OCR via Tesseract, Apache-2.0, in the `pipeline` container).
- Verify: OE issue count matches project; 10 tickets diffed vs web UI; re-run is a no-op.

### 1e. OE-only enrichment (local FOSS teacher model, delta-only, all rows model+prompt versioned)
- Runs on a **local open-weight model in a container** - Apache-2.0 Qwen3-32B or
  Mistral-Small-3 via vLLM on the rented/borrowed GPU, or a Q4 GGUF via llama.cpp on CPU
  when no GPU - so a rebuild is fully offline and free; no cloud LLM API.
- Per-commit one-liners (only where subject uninformative); per-ticket "what actually
  changed"; per-version rollups (new features / major bugfixes / watch-outs) grounded in
  release notes + tickets + commits with **entailment-checked citations** (a citation must
  support the claim, not just mention the same ticket).
- Feature extraction into the ontology (e.g. "users inactive since vN").
- Enrichment outputs cached immutably OUTSIDE the published DB, keyed by canonical input
  hash + model + prompt + policy version, so a full rebuild never re-runs the model.

### 1f. Query surfaces + publication contract [Sol]
- **Store = SQLite, chosen over MariaDB for the corpus + embeddings [consult].** MariaDB
  11.8 native VECTOR/HNSW + InnoDB full-text was evaluated and rejected as the durable
  store: (1) a single SQLite file is a genuine hash-signed, mountable, atomically-swapped,
  rollback-able artifact - an InnoDB data dir is server state with no byte-reproducible
  contract; (2) FTS5 gives the tokenizer/prefix/BM25 control identifier-heavy text needs,
  which InnoDB full-text does not; (3) native HNSW helps only the vector leg of a hybrid
  query and simplifies nothing else (lifecycle, identifier match, temporal joins). MariaDB
  stays archaeology-only. Postgres+pgvector is the fallback ONLY if the KB ever becomes
  multi-user / incrementally-updated / much larger; the HTTP API keeps that swap cheap.
- **The API + versioned stable SQL views are the contract - not physical FTS tables.**
  Version the contract; every answer carries the corpus generation id for reproducibility.
- **Atomic publication:** build off-path; non-WAL published file; run `foreign_key_check`
  + `integrity_check` + row-count invariants + eval smoke tests + `ANALYZE`; hash+sign DB
  and manifest; immutable generation name `history-core-<ts>.db`; switch a `current`
  manifest/symlink; API detects the swap and reopens its pool. **Mount the directory, not
  the file** (inode pinning); readers open `mode=ro&immutable=1`. Retain several
  generations for rollback; manifest records source cursors, git refs+hashes, build-code
  hash, schema version, model/prompt versions, embedding-model id + vector-index params,
  row counts, integrity+eval results. A generation is the whole directory - SQLite file +
  any vector sidecar + chunk manifest + checksums - signed and switched as ONE unit;
  reproducibility means identical source records/chunks/embeddings + measured retrieval
  behaviour, not a byte-identical ANN graph (pin embedding model, library version, insert
  order/threads).
- **Rebuild silver/gold/FTS fully from bronze each run** [Sol] (simpler, no stale-dep
  bugs); incremental only for harvesting, parse caches, enrichment cache, embeddings.
- Surfaces: read-only MCP server (search/timeline/deep_dive/reports), `sqlite3` CLI +
  a `c-oe-history` claude-kit skill (schema + canned queries), HTTP JSON API + minimal
  read-only web UI. **OE module is a thin client over the HTTP API, NOT PDO to a mounted
  sqlite** [Sol] - one place for authz, sensitive overlays, limits, citation formatting,
  generation switching, and a future Postgres swap with no OE-side rewrite.

### 1g. Hybrid retrieval + retrieval eval BEFORE any model work [Sol]
- FTS5 with identifier-aware tokenization + exact normalized columns (`tbl_name`,
  `column_name`, Jira key, class name, version) + a **local FOSS embedding model**
  (MIT/Apache bge-small / e5-small / nomic-embed via sentence-transformers in-container)
  + a **sqlite-vec** vector column in the same file.
- **Measure the vector path, don't assume it [consult]:** sqlite-vec exact search is
  likely fine at ~100k vectors / low concurrency, but at the 500k x 768-dim upper bound a
  full scan touches ~1.5 GB per query - benchmark the upper bound on the appliance's real
  CPU/storage FIRST; only if it misses the latency target, publish a hash-signed
  FAISS/hnswlib HNSW sidecar inside the same generation.
- **Two-path retrieval [consult]:** for a selective identifier/metadata filter, resolve
  eligible chunk ids in SQLite then compute exact similarity over that subset (faster and
  full-recall vs forcing a filter through a global ANN index); for broad semantic queries,
  search the ANN index, over-fetch, then join back to SQLite for metadata/FTS/lineage
  filtering + rank fusion. Coarse filters (repo, doc type, release family,
  current-vs-historical) can be separate ANN namespaces; rare/selective filters use exact
  subset search. Filtered ANN is the trap - post-filtering wrecks recall, callback
  filtering kills ANN speed.
- Retrieval benchmark (Recall@k / MRR) is a Milestone-1 deliverable - the generator can't
  compensate for missing retrieval.

## Milestone 2 - isolated overlays (TKLS + live DBA)

Only after M1's boundaries exist. Each overlay is a physically separate DB, mounted only
into the privileged local service, never into training, never into an image layer.

### 2a. TKLS overlay [Sol enforcement]
- Separate encrypted bronze + `history-tkls.db` + separate FTS/vector + separate key +
  network-disabled enrichment after harvest. Not sent to Claude/API unless a separate
  approved data-processing policy permits.
- **Taint transitively**: a CR rank derived partly from TKLS is TKLS-derived. Keep two
  rankings - public OE-only, and a local TKLS-enriched overlay that is never exported or
  trained on. Declassification (if ever) is a separate manual process with thresholds.

### 2b. Manual-client-data-fix mining [Sol: narrow the claim]
- Claim wording: "repository evidence of likely one-off client-data remediation for which
  no OE/TKLS link was found as of harvest <date>" - not "all manual fixes".
- Heuristic candidates -> LLM classify, **three-valued**: ticketed / apparently-untracked /
  unknown-review. Signals: SQL UPDATE/DELETE/INSERT/backfill/repair; hard-coded
  ids/client-names/date-ranges/env checks; hotfix/support/deploy paths; terms
  manual/live/prod/one-off/data-fix/corrupt; small commits outside migration convention;
  body+trailers not just subject; adjacent-commit/branch/change-group ticket keys; reverse
  Jira lookup. Negative signals: tests, fixtures, demo data, reusable migrations.
- Require quoted evidence + >=2 independent positive signals for high confidence; label
  200-500, measure precision **by era**, target 90-95% precision for "apparently
  untracked"; nothing auto-promoted to "confirmed"; lower-confidence -> review queue in the
  module. Store scope, harvest date, methods tried, reviewer, later corrections.

### 2c. DBA intelligence layer [Sol: read-only advisory, calibrated]
Corpus side (in core): `growth_profile` (event/audit/`*_version`/blob families),
`perf_issue` (per version-range: symptom/cause/fix/evidence) seeded from
`~/client-investigations/bolton/Bolton_prod_slow_analysis.md`, `~/claude-kit/knowledge/mariadb-buffer-pool-audit.md`, the cgroup-memory
runbook, the `performance_indexes_rollup` migration, and perf-flagged tickets/commits.

Live side - per-site `site-<id>.db`, least-privilege account, query budgets + timeouts,
digests normalized so literals/patient-ids are never retained:
- **v1:** server identity/version/config/uptime + app version; expected-vs-live schema
  drift + pending/unknown migrations; per-table+index allocated bytes, approx rows,
  charset/collation anomalies, history-table ratios; daily size samples -> robust
  7/30/90-day **bytes/day** trends (bytes/day over rows/day - InnoDB row counts are
  approximate; detect resets from rebuild/purge/OPTIMIZE; no trend claim before ~7 days,
  30 is a better baseline; rank absolute AND percentage growth); buffer-pool / dirty-page /
  checkpoint / log-wait / purge-history / connection / temp-table / lock-wait / deadlock
  indicators computed as **rates from two samples**; Performance Schema statement-digest
  deltas; redundant/unused-index observations; known per-version issues; **dump-duration
  p50/p90 estimate**.
- **Dump time:** `data_bytes / MB/s` is only the cold-start model; record every real dump
  (duration, options, source+compressed size, host, destination) and fit a per-site robust
  model. Report +/-50-100% before calibration, +/-15-30% after 3-5 comparable dumps.
- **Never** enable logging, run ANALYZE, count every large table, or change variables.
  The LLM summarizes deterministic observations; it does not invent thresholds/metrics.
- **Unrealistic - do not promise:** guaranteeing a backup is restorable, exact dump time,
  exact cheap row counts, diagnosing every incident without host/workload telemetry,
  validating proposed indexes from metadata alone, safe config tuning, killing sessions,
  repairing corruption.
- **Later:** replication health, host disk/CPU/IO, slow-log ingestion (redacted),
  `EXPLAIN FORMAT=JSON` workflows, workload-aware index advice, restore verification in a
  disposable DB, per-site capacity forecasts.
- OE module page + `db_health` MCP tool + API endpoint; strictly SELECT/SHOW.

## Milestone 3 - evaluation suite (gate for anything that ships)

Built before the model, run on every corpus generation and every model candidate [Sol]:
exact table/column/version lifecycle; release containment + cherry-pick cases; feature
aliases + "when added"; how-to grounded in docs; manual-fix classification + correct
uncertainty; DBA arithmetic + calibrated ranges; retrieval Recall@k/MRR; citation
existence+entailment+coverage; unsupported-question abstention; prompt-injection from
Jira/Confluence text (documents are untrusted data, never instructions); TKLS + live-site
canary exfiltration. Split by **time / release line / entity** (not random rows sharing a
ticket). >=98-99% exact on structured facts before release; citation required per claim.

## Milestone 4 - the offline answer engine (strictly last)

[Sol] Honest boundary: a 1.7-4B model cannot memorize the history closed-book. It is the
final offline reasoning+language layer over deterministic structured queries + hybrid
retrieval + mandatory citations + abstention. That is a real offline answer engine;
retrieval is part of it.

### Model choice - decision framework
- **One Qwen3 adapter merged into the GGUF, size set by the eval gate [consult].** Because
  the engine is retrieval-grounded, start at the SMALLEST gate-passing Apache-2.0 checkpoint
  (1.7B-3B) and step up to 4B only if the gate misses - smaller is also the cheapest to
  train slowly (see Low-resource training). If a code-specialised base is wanted, require an
  OSI/Apache-2.0 one - NOT Qwen2.5-Coder-3B (non-commercial Qwen Research licence).
- **One vs three:** start one-model/one-adapter. Split into schema/code/frontend adapters
  ONLY if the eval proves domain interference; three separate models is worst (3x RAM,
  routing errors, can't span domains - and OE questions do span: migrations are PHP, DBA
  issues start in app code, frontend ties to tickets/releases). Specialise the *retrieval
  routes* (schema / code-change / docs-frontend / DBA), not the weights.

| Topology | Train cost | Serving | Cross-domain | Verdict |
|---|---|---|---|---|
| One model, no adapters | 1 run | simplest | native | **start here** |
| One base + 3 LoRA adapters | 3 cheap runs | hot-swap + router | needs routing | only if eval shows interference |
| Three separate models | 3 full runs | 3x RAM | worst | avoid |

The size decision is made by an **eval ladder**, not by taste: build the eval set first,
start at 1.7B-3B and step UP to 4B only if grounded accuracy misses the bar - retrieval-
grounding lowers the floor, and a slower/smaller model changes wall-clock, not final
accuracy. Grounded QA needs reading comprehension + citation discipline, which small models
handle; ungrounded parametric recall is what demands big models and still hallucinates - so
keep it grounded and keep it small.

### Data mix + schedule [Sol]
- Three measured baselines before committing: (1) stock instruct + RAG, (2) OE SFT
  adapter + RAG, (3) CPT + SFT + RAG. **Skip CPT for the first shipping candidate
  [consult]** - retrieval already supplies the facts; noisy diffs/repetitive migrations can
  hurt. Add a small CPT experiment only if the gate exposes a persistent OpenEyes-vocabulary
  deficiency that better retrieval + targeted SFT cannot fix.
- CPT: 25-50M clean OE tokens (exclude vendor/generated/minified/secrets/TKLS/live/
  boilerplate; ~10-20% general PHP/SQL replay against forgetting), one low-LR pass.
- SFT: 25-40k examples - ~35% exact schema/release facts, 25% features/how-to, 15%
  code/change, 10% DBA interpretation, 15% refusal/conflict/insufficient-evidence/citation.
  **Factual labels generated deterministically from gold tables; the local teacher model
  paraphrases, never invents ground truth**; include distractors + conflicting evidence.
  Train ONE epoch first, a 2nd only if held-out gate metrics still climb [consult] - a 4B
  overfits this set (formulaic answers, weaker abstention, unsupported citations even as
  loss falls), so guard leakage across template/repo/release/near-duplicate splits.
- Update schedule: **nightly = corpus+retrieval only (facts queryable at once)**;
  weekly/threshold = full SFT refresh over the whole current QA set / large replay
  reservoir; per-release/monthly = rebuild CPT+SFT from the immutable base. **Never
  delta-only training; never stack an indefinite LoRA chain.** Interim fast refresh may use
  20-30% recent + 70-80% stratified replay, periodically reconstructed from base. Record
  base hash, dataset fingerprint, seed, trainer version, parent per candidate.
- Clinical-adjacent containment: engine explains software history/behaviour, not
  diagnosis/care; no patient-specific data in training; numeric/schema answers validated
  against structured results after generation; conflict/absence must be stated.
- Serve llama.cpp/ollama Q4 GGUF; **CPU inference is fine** - ~3-5 GB for a 4B Q4 + KV
  cache on a modern 8-16 core host. No GPU to run it; GPU is training-only.

### Low-resource, time-is-no-object training [consult]
Trading wall-clock for smaller hardware does NOT cost accuracy: for a fixed
model+data+recipe, a slower/smaller GPU changes only wall-clock, not final loss. Accuracy
here is capped by retrieval quality + SFT/eval-data quality, never by training FLOPs - so
going slow is safe, and the eval gate (not a fixed duration) decides when to stop.
- **Fit a 1.7B-3B QLoRA on a borrowed/owned 12GB card (8GB for 1.7B):** 4-bit NF4 +
  double-quant base, BF16 compute, LoRA rank 16, micro-batch 1 + gradient accumulation
  (16-64) for the intended effective batch, gradient checkpointing, a bitsandbytes paged
  8-bit optimizer, 2K-4K sequence length (measured, not the model max), sequence packing.
  Add DeepSpeed ZeRO-Offload (optimizer state -> CPU RAM) ONLY if it still won't fit -
  offload slows things unpredictably (RAM/PCIe bound). All FOSS.
- **Make a week-long run safe:** resumable checkpoints (adapter + optimizer + scheduler +
  scaler + step + RNG state) copied off-box against spot preemption; test resume once
  early; pin+record seed, library versions, dataset revision, example order, tokenizer,
  quant config, effective batch; evaluate on the gate periodically and stop when held-out
  metrics (citation entailment/coverage, abstention, schema compliance, vocab) plateau -
  Recall@k is scored separately since the adapter can't move a fixed retriever.
- **The economics [consult]:** "slower = fewer resources" is only cheaper when the card is
  owned/borrowed/idle (it minimises hardware CAPABILITY, not total compute/electricity). On
  pay-per-hour RENTAL a week on a cheap GPU can cost MORE than a fast A100 burst - offload
  makes it worse - so compare the cost of a COMPLETE validated run, not the hourly rate; a
  short fast burst usually wins on cash. CPU-only is a false economy above 1.7B (days ->
  weeks/months); even an old 8-12GB GPU is vastly better.

### Training hardware + cost [Sol estimates, mid-2026 spot, QLoRA one-pass; real quotes vary >2x]

Training stack is FOSS + containerised: QLoRA via transformers + peft + trl + bitsandbytes
(or Axolotl) in a `train` image using the Apache-2.0 nvidia-container-toolkit; only the host
GPU driver + CUDA are proprietary (unavoidable). Estimates assume a rented/borrowed GPU box:

| Option | 1.7B initial | 4B initial | Assessment |
|---|---|---|---|
| Spot 4090/24GB ($0.35-0.90/hr) | 5-12 h (~$2-11) | 14-30 h (~$5-27) | cheap; 4B may miss an overnight window |
| Spot A100/80GB ($0.90-1.80/hr) | 2-5 h (~$2-9) | 4-10 h (~$4-18) | **best for initial + release retrains** |
| Borrowed 12GB card | 8-20 h | 30-60 h w/ offload | fine for 1.7B, not 4B |
| Borrowed 24GB card | 5-12 h | 14-30 h | good for experiments/periodic |
| Used RTX 3090 24GB (~$600-900) | as borrowed 24GB | as borrowed 24GB | buy only for ~100+ GPU-h/mo or data-residency |
| CPU-only | weeks | months | not a viable training path |

Weekly 5-20M-token refresh: ~1-3 h on A100 / 2-8 h on 4090, low single-digit dollars.
**Recommendation:** for the explicit "fewer resources, time-is-no-object" goal, run a
1.7B-3B QLoRA long on a borrowed/owned 12GB card (8GB for 1.7B) per Low-resource training
above. If paying by the hour instead, a fast A100 burst is the cheapest complete run (cheap
4090 spot for refreshes); borrow a 24GB card if offered; don't buy unless on-prem is policy.

## Nightly incremental pipeline (spans all milestones)

Order [Sol]: corpus delta -> normalized rebuild -> derived rebuild -> enrichment ->
search/index publication (facts live now) -> optional training candidate -> eval gate ->
model publication. Host cron: `docker compose run pipeline nightly`. Idempotent, per-source
cursors, resumable; full publication rebuild from bronze; weekly image rebuild. Verify: two
runs; second is delta-only; published core identical when nothing changed upstream.

## Governance

Retention, deletion, access-revocation, personal-data handling, attachment policy,
encryption, backups, and the legal right to train on each source. "Immutable bronze" must
not override a deletion or confidentiality obligation - model deletion/restriction
tombstones in bronze. Confluence keeps page versions; Jira attachment binaries are
allowlist-only.

## Reuse (existing assets, not new code)

- `c-oe-code/subs/code-history.md` - tag-filter/pickaxe/`--contains` recipes become
  pipeline code + verification oracles.
- `create-oe-module` - OeHistory scaffold (`oe_special_module`, menu, authitem).
- `OEMigrateCommand` semantics - the snapshot walk + fingerprinting rely on them.
- claude-kit skill mechanism for `c-oe-history`; jiramcp context (URLs, keys, classic-token
  gotcha).
- `c-oe-db-schema` connection recipes + the Bolton/InnoDB runbooks - DBA-layer seeds.

## Top risks [Sol's five]

1. **Plausible-but-wrong answers destroy trust.** -> deterministic structured routes +
   hybrid retrieval + citation entailment + strong abstention + an eval-gated model size.
2. **TKLS/live-site leak into training, cloud prompts, or an exported bundle.** -> physical
   stores + mount isolation + transitive taint + no-egress processing + canaries + artifact
   scanning (positive allowlist, not `WHERE sensitive=0`).
3. **A linear release/schema model fabricates introduction/removal dates.** -> tag DAGs +
   per-line mapping + reset-per-tag snapshots + explicit install profiles + confidence
   bounds.
4. **Promising evidence the sources can't contain** ("all manual fixes", "everything a
   DBA does"). -> precise wording + source-coverage reports + three-valued classification +
   visible uncertainty.
5. **Corpus silently goes stale/irreproducible** (Jira pagination, deletions, tag moves,
   prompt drift, delta-only training). -> overlap cursors + periodic full reconcile + signed
   manifests + full rebuilds + replay training + candidate gates.

## Open items

- GitHub PR harvester deferred: `pr`/`pr_comment` reserved; `implementation_group` evidence
  graph (strong = stable patch-id + compatible paths; medium = Jira key + diff/path/subject
  similarity + close dates; later = PR identity/range-diff/review links; manual override) -
  do NOT union transitively across weak edges; keep ticket linkage separate.
- Pre-monorepo module repos may hold pre-2013 history - a discovery task lists candidates.
- Which host runs the nightly cron + where encrypted TKLS/site stores live (decide at M2).

## First step when build begins

Milestone 1 (non-sensitive, evidence-first, deterministic queries, no model) is the first
shippable target. Concretely: scaffold `oe-history/`, land git ingestion (1a) and the
release timeline (1b), and prove the schema-archaeology machinery (1c) on v6/v11/v26 before
walking the full tag set.
