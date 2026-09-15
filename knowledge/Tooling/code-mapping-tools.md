# Code Mapping / Codebase-Index Tools for Claude Code

Research notes — compiled 2026-06-18. Target use case: give Claude Code quick,
token-cheap context over **OpenEyes (~40,000 files)**, FOSS, Docker-where-possible,
fast re-index on frequent releases.

## Requirements (as stated)

- FOSS, run through a Docker container where possible.
- Build cost (tokens/time) doesn't matter; **runtime** token consumption must be low.
- App releases very regularly → need a fast way to refresh the index per release.
- Prefer (soft) local embeddings, ideally in MariaDB 11.8 — **not** a hard requirement.
- Want an output artifact that can be stored on a machine / pushed to GitHub and
  then used from the Claude Code CLI.

## Two caveats before trusting any "best of" list

**1. Reddit sentiment could not be verified.** Anthropic's web crawler is blocked
from reddit.com, so no Reddit threads were readable. Ratings below use signals that
*are* verifiable: live GitHub stars (pulled via the GitHub API), npm download volume,
contributor count, corporate backing, and published benchmarks.

**2. Some star counts are not believable as organic adoption.** For reference,
Repomix took ~2 years to reach 26k stars and Serena ~15 months to reach 25k. Against
that baseline:

- `safishamsi/graphify` — **68,365 stars in ~10 weeks** (created Apr 2026), 6,914 forks
- `colbymchenry/codegraph` — **50,659 stars in ~5 months**

Those velocities would be among the fastest in GitHub history and carry the classic
signature of a promotion / star-inflation campaign (huge stars + huge forks + young +
solo maintainer). Treat their stars as marketing, not proof. The trustworthy adoption
signals here are Repomix's downloads, Serena's contributor base + org, and Zilliz
backing claude-context.

## Ranking

Weighted to the criteria above: low runtime tokens, fast re-index per release,
Docker, FOSS, real adoption.

| # | Tool | Stars (verified) | Trust signal | Runtime token save | Re-index on release | Docker | Artifact model | License |
|---|------|------|------|------|------|------|------|------|
| 1 | **Serena** (oraios) | 25.5k | Org + 170 contributors, 15-mo organic | High (symbol-level, reads only what's needed) | **Instant** — live LSP, nothing to rebuild | Yes (official `DOCKER.md`, SSE; "experimental") | Live service (no committed file) | MIT |
| 2 | **claude-context** (zilliztech) | 11.9k | Backed by Zilliz (Milvus vendor) | High (semantic search) | **~5s** Merkle incremental after git pull | Yes (Milvus in Docker) + **Ollama local embeddings** | Vector DB (persisted volume) | MIT |
| 3 | **CodeGraph** (colbymchenry) | 50.7k ⚠️ | Solo maint, 259 open issues, stars suspect | High (graph = fewer tool calls) | Auto file-watcher sync | Designed as local CLI/daemon (Docker unconfirmed) | **Portable SQLite (committable)** | MIT |
| 4 | **Graphify** (safishamsi) | 68.4k ⚠️⚠️ | Solo maint, stars highly suspect | High (AST graph queries) | git post-commit hook | **Yes — HTTP MCP server** | **Portable graph.json (committable)** | MIT |
| 5 | **Repomix** (yamadashy) | 26.3k | **255k npm installs/mo**, 2-yr track record — most credible adoption | Medium, and *poor at 40k files* | None — full re-pack each time | Yes (official image) | Single portable file (committable) | MIT |

⚠️ = star count inflated relative to age; judge on code, not the number.

### Honorable mentions

- **CodeGraphContext** (`CodeGraphContext/CodeGraphContext`) — MIT, Python,
  Docker-native, pluggable Neo4j / KuzuDB / FalkorDB backends. Cleanest *dockerised
  graph DB* option if you want a real graph store.
- **grepai** — 100% local Ollama embeddings, ~97% token cut, single Go binary. Great
  privacy/local fit but very new, solo maintainer.
- **denfry/codebase-index** — fully offline SQLite FTS5 + tree-sitter. Only ~4 stars /
  brand new.

> Note: "codegraph" is an overloaded name. `colbymchenry/codegraph` (SQLite, local
> daemon), `CodeGraphContext/CodeGraphContext` (graph DB, Docker-native) and
> `sdsrss/code-graph-mcp` (Rust, 44 stars, niche) are three different projects.

## The real decision: two architectures

The requirements split along one axis — **commit an artifact** vs **run a service**.

### A. Run a container service — better fit for Docker-first + frequent releases

No stale committed index to regenerate and re-push on every release; the running
indexer just re-syncs.

- **Serena** — top pick. Best token economics; because it's LSP-live there is
  *nothing to rebuild* on release — it always reflects current code. Dockerised.
  Catch: Claude forgets to use it after context compaction, so add a `CLAUDE.md` line
  telling it to prefer Serena's tools.
- **claude-context** — if you specifically want local-embedding semantic search
  ("find the thing that does X" in English). Matches the checklist most literally:
  Docker + Ollama local embeddings + ~5s incremental re-index. Cost: you run a Milvus
  container. Embeddings live in Milvus, not MariaDB — no FOSS code indexer targets
  MariaDB 11.8 yet.

### B. Commit a portable artifact — the originally-described model

- **CodeGraph** (colbymchenry) — best of this class: a single local SQLite graph you
  can commit or scp, kept fresh by a file-watcher. Discount the 50k stars, but the
  artifact-plus-auto-sync model is exactly the "store it on a machine and leave it"
  idea. Docker isn't its native mode (it's a local daemon).
- **Graphify** (safishamsi) — same artifact idea but served over a dockerised HTTP MCP
  endpoint, re-index wired to a git post-commit hook.

## Recommendation

**Start with Serena** (lowest ongoing effort, best token savings, releases are a
non-event). If after a week you want English-language semantic search across the 40k
files, **add claude-context with a local Ollama embedder** alongside it.

Skip the committed-artifact tools unless there's a concrete reason to version the
index in git — for a frequently-released app, a live re-syncing service is less to
maintain than regenerating and re-pushing a graph file every release.

### On MariaDB 11.8 embeddings

No off-the-shelf FOSS code indexer stores embeddings in MariaDB. The AST/symbol
approach (Serena, CodeGraph) already cuts runtime tokens *without* embeddings —
embeddings only buy fuzzy natural-language search on top. If MariaDB-vector ever
becomes a real requirement, it's a bespoke RAG: local embedder (e.g. via Ollama) →
store vectors in MariaDB 11.8 using `llama-index-vector-stores-mariadb` → expose to
Claude as its own MCP tool.

### The one rule that makes any of these actually save tokens

Do **not** let Claude load the raw index (`graph.json` / packed file) into context —
at 40k files that costs more than grepping. The win comes entirely from Claude making
*scoped queries* against the served index (MCP query tools / hooks). Keep the raw
artifact out of the prompt.

## Sources

- GitHub API, star counts pulled live 2026-06-18:
  [oraios/serena](https://github.com/oraios/serena) 25.5k ·
  [zilliztech/claude-context](https://github.com/zilliztech/claude-context) 11.9k ·
  [colbymchenry/codegraph](https://github.com/colbymchenry/codegraph) 50.7k ·
  [safishamsi/graphify](https://github.com/safishamsi/graphify) 68.4k ·
  [yamadashy/repomix](https://github.com/yamadashy/repomix) 26.3k
- [Serena Docker docs (DOCKER.md)](https://github.com/oraios/serena/blob/main/DOCKER.md)
- [claude-context — Merkle incremental indexing + Ollama](https://github.com/zilliztech/claude-context)
- [CodeGraphContext — Docker-native graph option](https://github.com/CodeGraphContext/CodeGraphContext)
- [Code Intelligence Tools for AI Agents Compared — Ry Walker](https://rywalker.com/research/code-intelligence-tools)
- [MariaDB 11.8 Vector overview](https://mariadb.com/docs/server/reference/sql-structure/vectors/vector-overview) ·
  [llama-index-vector-stores-mariadb (PyPI)](https://pypi.org/project/llama-index-vector-stores-mariadb/)
