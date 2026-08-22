# oe-map — portable, Claude-queryable + human-rich knowledge map of OpenEyes

> Durable copy of the approved plan (transient plan-file:
> `~/.claude/plans/humming-waddling-squid.md`). Status: **approved 2026-06-26**, build not
> yet started.

## Context

OpenEyes is a ~14.7k-file AGPL ophthalmology EHR spanning three frameworks in one repo
(legacy Yii 1.1 `protected/`, PSR-4 replatform `OE\`, Laravel `oe-laravel/`, shared
`oe-shared/`). We want one pre-computed artifact that serves **two consumers**:

1. **Claude** — load codebase context into a fresh session *fast* and at *low token cost*.
2. **A human** — a rich interactive experience like the `understand-anything` plugin.

A working **v1 already exists** at `/home/toukan/oe-map/`: a stdlib-only deterministic
extractor (`build_map.py`) producing `graph.db` (SQLite + FTS5: `files`/`symbols`/`edges`/
`layers`/`file_layer`/`meta`; 14,653 files, 54,077 symbols, 30,235 edges, 50 layers),
`nodes.ndjson`/`edges.ndjson`, `schema.md`, `index.md`, and a read-only `oe-map` SQL
wrapper. The `summary` columns are NULL, reserved for LLM enrichment. This plan wraps v1
into a transportable project and adds the missing layers.

## Relationship to the understand-anything plugin (what we reuse vs replace)

The `understand-anything` plugin is two separable halves:

- **(a) the `/understand` build pipeline** — Node scripts + LLM subagents that scan a repo
  and emit `.understand-anything/knowledge-graph.json`. **We do NOT use this.** It requires
  Node ≥22 on the host (we allow no host installs) and its whole-repo LLM scan does not
  scale to OpenEyes' ~12.5k code files (hundreds–~1000 batches). We replace it with our own
  deterministic + precise extractor (`build_map.py`, runs on python stdlib / in Docker) plus
  a resumable enrichment pass.
- **(b) the React/Vite dashboard** — visualizes a `knowledge-graph.json` (nodes/edges/
  layers/tours, deep-dive, code viewer). **We DO reuse this, in Phase 6.** We export our
  `graph.db` into its `knowledge-graph.json` schema (`{version, project, nodes[], edges[],
  layers[], tour[]}` — verified 1:1 mappable) and build/serve the pinned (v2.8.1, MIT)
  dashboard **inside Docker**, fully offline. Its code-viewer wants the source mounted —
  wired read-only when present, degrades gracefully without it.

We additionally **reuse three of their analyzer agents** (`domain-analyzer`,
`article-analyzer`, `tour-builder`) as *enrichment steps* that write into **our** schema —
giving us their semantic layers without their broken-at-scale `/understand` scanner.

Net: **our map (a superset of their data), their viewer, plus their best analyzer agents
as enrichment.** The plugin is a Phase-6 frontend dependency + a source of reusable
enrichment agents — never the build-time scanner.

## Constraints (all honored)

- FOSS only; **zero external API calls** at build or view time — Claude (Anthropic) calls
  during enrichment are the only permitted network LLM channel; the frontend makes **no**
  network calls (all JS vendored, no CDN).
- **No host installs** beyond Claude plugins and Docker images. Structural rebuild + Claude
  query path run on **python3 stdlib** (already present); everything heavier (PHP-AST
  parser, tree-sitter, the React dashboard) runs **inside Docker**.
- Transportable: a git repo that is also `docker build`-able and a Claude plugin; **usable
  without the OpenEyes source present** (source only needed to rebuild/refresh).
- Creation token cost irrelevant; **maintenance must be low-token** (diff-driven) and
  creation must be **pausable/resumable** (kill + re-run continues, never redoes finished work).
- Output formats: Markdown + JSON + SQLite only.
- **AGPL-3.0 guardrail:** the artifact ships metadata + LLM summaries + symbol/line refs
  only — **never verbatim source**. The live source viewer is a rebuild-only feature that
  activates when the source is mounted.

## Locked decisions

- **Extraction = precise + call graph from the start.** A Docker build stage with PHP +
  composer + `nikic/php-parser` (PHP AST) and node + tree-sitter (JS/TS/Vue) produces the
  graph, adding `calls` edges (who-calls-whom, resolved via `NameResolver` + symbol table)
  and deterministic config-wiring edges `observes`/`provides` (parsed from each module's
  `config/common.php` `event.observers` + `components`). The stdlib **regex extractor stays
  as the zero-dependency fallback** so the map is still rebuildable on a host with no Docker
  (at reduced precision). Both write the **same schema**.
- **Frontend = reuse the understand-anything dashboard** (see section above).
- **Parity target = full superset of understand-anything.** We populate, into our own
  schema, all of UA's layers: their 21 node types (code + non-code `service`/`endpoint`/
  `table`/`schema`/`pipeline`/`resource`, the **domain** layer `domain`/`flow`/`step`, the
  **knowledge** layer `article`/`entity`/`topic`/`claim`/`source`, and `concept` nodes),
  their broader edge vocabulary, and per-node `tags`/`complexity`/`languageNotes` +
  `domainMeta`/`knowledgeMeta`. Structural tiers come from the deterministic/precise
  extractor; the domain/knowledge/concept/tag tiers come from LLM enrichment, reusing UA's
  `domain-analyzer`/`article-analyzer`/`tour-builder` agents where useful. Net result is a
  strict superset of what UA would produce — and unlike UA, it covers the whole repo.
- **Claude fast-context primary = a generated Markdown tree** (per-layer / per-module /
  index), read with Read/Grep — zero runtime, token-dense. **SQL over `graph.db` via the
  `oe-map` wrapper is the precision fallback** for long-tail structural queries.
- **Canonical store split:** `exports/*.ndjson` is the diff-friendly source of truth;
  `graph.db` is a rebuildable index (`load_db.py`) committed for clone-and-go convenience —
  avoids 37 MB binary churn bloating git history.
- **Resumable enrichment state lives in the DB** (`enrich_state` keyed by `content_hash`),
  so the work queue is a derived query and resume is free.

## Repo layout (`/home/toukan/oe-map/`, `git init`; not committed/pushed by me)

```
oe-map/
  .claude-plugin/{plugin.json, marketplace.json}     # installable as a Claude plugin
  skills/
    oe-map/SKILL.md            # model-INVOCABLE front door: markdown-first router + SQL fallback
    oe-map-enrich/SKILL.md     # resumable enrichment orchestrator
    oe-map-dashboard/SKILL.md  # `docker compose up` the human dashboard, print URL
  build/
    build_map.py               # v1 extractor + --extractor=regex|precise
    extractors/{regex.py, precise/}   # precise/: php-parser CLI script + tree-sitter pass
    enrich.py                  # stdlib enrichment state machine (queue/apply/status)
    export_markdown.py         # graph.db -> artifact/map/** (deterministic, no LLM)
    export_graph_json.py       # graph.db -> understand-anything knowledge-graph.json
    load_db.py                 # rebuild graph.db from committed ndjson (offline)
  artifact/                    # THE PORTABLE PAYLOAD (committed)
    graph.db  manifest.json  index.md  schema.md
    map/{_index.md, layers/<layer>.md, modules/<Module>.md}
    exports/{nodes.ndjson, edges.ndjson, knowledge-graph.json}
  frontend/                    # Dockerised UA dashboard wiring (built in container)
  oe-map                       # stdlib read-only SQL wrapper (root, points at artifact/graph.db)
  Dockerfile  docker-compose.yml  README.md  .gitignore
```

## Data-model additions (extend `schema.md` + the DB)

Structural core stays `files`/`symbols`/`edges`/`layers`; the superset adds an overlay so we
can represent every UA node/edge type and export `knowledge-graph.json` losslessly.

- **Structural:** new edge `type`s `calls` (weighted, PHP-AST), `observes`/`provides` (config).
- **Per-node enrichment columns** on `files`+`symbols`: `summary` (files needs `ALTER ADD`;
  symbols already has it), `tags` (JSON array), `complexity` (`simple|moderate|complex`),
  `language_notes`, `node_type` (the UA-typed role: `service`/`endpoint`/`table`/`schema`/
  `pipeline`/`resource`/`config`/`document`/`class`/`function`/`module`/…), derived
  deterministically where possible (endpoint←routes, table←migrations/AR) else by enrichment.
- **Overlay node tiers** (non-file/symbol nodes, populated by enrichment):
  `concepts(id, name, summary, tags, node_ids)`;
  `domains(id, name, summary, entry_type, business_rules, entities)`,
  `flows(id, domain, name, summary)`, `flow_steps(flow, ord, name, summary, node_ids)`;
  `knowledge_nodes(id, type[article|entity|topic|claim|source], name, summary, file,
  wikilinks, backlinks, category)`.
- **Generalized edges:** widen the `edges.type` vocabulary toward UA's set as we populate
  it (e.g. `contains`, `routes`, `reads_from`/`writes_to`, `subscribes`/`publishes`,
  `contains_flow`/`flow_step`/`cross_domain`, `cites`/`builds_on`/`exemplifies`).
- **State/aux:** `enrich_state(path PK, content_hash, status[pending|done|error], model,
  enriched_at, attempts, error)`; `module_state(module PK, files_hash, status, enriched_at)`;
  `tours(module, ord, title, body, node_ids)`.
- **Exporter** (`export_graph_json.py`) UNIONs `files`+`symbols`+overlay tiers into UA's flat
  `nodes[]` (carrying `tags`/`complexity`/`languageNotes`/`domainMeta`/`knowledgeMeta`) and
  maps our edge types to UA's, so the dashboard renders every tier.

## Resumable enrichment spec

- **Unit of work = file** (matches extractor + git diff granularity; bounds each LLM call).
  Tier-2 unit = **module** (narrative page + tours), regenerated only when its `files_hash` moves.
- **Work queue is a derived query:** a file needs work iff no `enrich_state` row, OR
  `status<>'done'`, OR `content_hash <> current_sha256`. No separate todo list to desync.
  Order by module, then graph in-degree (base classes / hubs first) so any partial run is coherent.
- **Loop:** `build_map.py` refreshes structure (cheap, no LLM) → orchestrator skill drains
  the queue in batches of ~15–40 files grouped by module → a **per-batch subagent** reads
  files and writes summaries as JSON to `artifact/.enrich/batch-NNN.json` (returns only a
  count, so file bodies never enter the main context — the low-token trick) → `enrich.py
  apply` writes summaries + `status='done'` + `content_hash` in **one transaction per batch**.
- **Resume:** kill anytime → at most the in-flight batch is lost (re-queued); re-invoking the
  skill recomputes the queue and continues. Hitting a usage limit is exactly this case.
  `/loop oe-map-enrich` can auto-pace but correctness must NOT depend on it.
- **Incremental maintenance:** `meta.last_enriched_commit` + `git diff --name-only` +
  per-file sha256 → a 10-file PR re-enriches ~10 files + the 1–2 module pages whose
  `files_hash` changed, not 12k files. Re-applying a batch is idempotent (UPSERT by path/symbol).

## Phased build order (each phase independently valuable; each ends with a verify)

- **Phase 0 — Scaffold + discoverability.** `git init`; restructure v1 into the tree above
  (move `build_map.py`→`build/`, `graph.db`→`artifact/`, repoint the `oe-map` wrapper);
  `.claude-plugin/` manifest; model-invocable `skills/oe-map/SKILL.md`; update the
  `c-oe-code` pointer to the new paths.
  **Verify:** a fresh session asked "subclasses of `BaseEventTypeElement`?" auto-invokes the
  skill and answers via `./oe-map`/markdown without being told where the map is.
- **Phase 1 — Markdown knowledge tree (fast-context primary).** `export_markdown.py` →
  `map/_index.md` + per-layer + per-module pages (deterministic).
  **Verify:** `map/modules/OphCiExamination.md` lists element classes + `extends` + entry
  points; a fresh Claude answers "what's in OphCiExamination" from one Read, no SQL.
- **Phase 2 — Dockerised precise extraction + self-contained image.** Multi-stage
  `Dockerfile`: builder (PHP+composer+nikic/php-parser, node+tree-sitter) runs
  `--extractor=precise` → `graph.db` with `calls`/`observes`/`provides`; slim runtime stage
  bakes `artifact/` + python3 + `oe-map`. Regex fallback preserved.
  **Verify:** `calls` edge count > 0 and a known controller→service call resolves;
  `docker run oe-map ./oe-map "SELECT count(*) FROM files"` → `14653` offline; regex
  fallback still rebuilds the structural graph with no Docker.
- **Phase 3 — Resumable enrichment.** `enrich_state`/`module_state` migration, `enrich.py`,
  orchestrator skill + per-batch subagent, content-hash diffing. Run over one module first.
  **Verify:** kill mid-run, re-invoke → `done` files skipped, remainder processed,
  `symbols.summary`/`files.summary` populated; a second no-change run does **zero** LLM work.
- **Phase 4 — Incremental maintenance.** Wire `last_enriched_commit` + sha256 + `git diff`.
  **Verify:** touch one element class, refresh → exactly 1 file + 1 module page re-enriched.
- **Phase 5 — Semantic superset layers (LLM).** Beyond module narratives + `tours`:
  populate the overlay tiers to match/exceed UA — `concept` nodes; the **domain** layer
  (`domains`/`flows`/`flow_steps` for the clinical/business workflows: referral → triage →
  examination → outcome, etc.); the **knowledge** layer from the repo's `*.md` design notes
  (`knowledge_nodes` + wikilinks/backlinks); fine `node_type` typing; and per-node
  `tags`/`complexity`. Reuse UA's `domain-analyzer`/`article-analyzer`/`tour-builder` agents
  as enrichment workers writing into our schema. Resumable/diff-driven like Phase 3.
  **Verify:** every tour/flow `node_id` resolves; a `domains→flows→flow_steps` chain exists
  for a known OE workflow; the docs-knowledge graph has wikilinked `article`/`entity` nodes;
  exported `knowledge-graph.json` validates against UA's schema and the dashboard renders the
  domain + knowledge tiers (not just code).
- **Phase 6 — understand-anything dashboard (Docker frontend).** `export_graph_json.py` →
  `knowledge-graph.json` (UA schema); `docker-compose.yml` service builds the pinned UA
  dashboard and serves our graph offline; code-viewer wired to a read-only OE mount when present.
  **Verify:** `docker compose up`, browser offline → graph + layers + tours render,
  **no external requests** in the network panel; deep-dive shows summaries.

## Critical files

- `/home/toukan/oe-map/build_map.py` — extractor to make pluggable (`--extractor`), add
  `calls`/`observes`/`provides`, add the enrich/state migrations.
- `/home/toukan/oe-map/oe-map` — stdlib read-only SQL wrapper (repoint to `artifact/graph.db`).
- `/home/toukan/oe-map/schema.md` — schema contract to extend (new edge types + tables).
- `/home/toukan/claude-kit/skills/c-oe-code/SKILL.md` — style pattern for the new
  model-invocable `oe-map` skill; update its `~/oe-map/` pointer to the new paths.
- understand-anything plugin (`~/.claude/plugins/cache/understand-anything/understand-anything/2.8.1/`)
  — `knowledge-graph.json` schema to mirror in the exporter; dashboard package to build in Docker.

## Notes / guardrails

- I will **not** `git commit` or `git push` (per global rules) — `git init` + stage only; you commit.
- Whole-repo LLM enrichment is sanctioned (tokens-to-create don't matter) and fully
  resumable; the enrich skill is also scope-able (`/oe-map-enrich OphCiExamination`) if you'd
  rather enrich high-value modules first.
- Build-time network (pip/composer/pnpm in `docker build`) is permitted; the **running**
  artifact is fully offline. A python-stdlib-only path guarantees a no-network rebuild still
  works at reduced precision.
