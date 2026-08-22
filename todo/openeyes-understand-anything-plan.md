# OpenEyes — Understand Anything build runbook (Anthropic-only)

_Compiled 2026-06-25. Purpose: build an extremely rich, queryable knowledge graph
over **OpenEyes @ `develop`** so that bugs described in plain English can be fixed
with Claude Code without hand-holding — while guaranteeing **no third-party API
calls** (Anthropic only, via Claude Code)._

---

## 1. What this builds and how it works

Understand Anything (`Egonex-AI/Understand-Anything`) is a Claude Code **plugin**
that runs a **multi-agent pipeline** over a repo and emits a portable knowledge
graph. Two layers:

- **Structural (local, no network):** tree-sitter parses every file into a syntax
  tree and extracts the skeleton — imports/exports, function/class/method
  definitions, call and dependency edges. No model, no API.
- **Semantic (the model):** the host agent's model reads the parsed structure
  alongside the source and writes what a parser can't — plain-English summaries,
  tags, architectural-layer assignments, business-domain mapping, guided
  explanations. **Here, "the model" is Claude via Claude Code → Anthropic.**

Output is written to **`.understand-anything/knowledge-graph.json`** plus a
generated dashboard. Once built, the artifact is queried locally; only the
*generation* spends model tokens.

## 2. The Anthropic-only guarantee — and how it is enforced here

Understand Anything has **no documented switch** to "lock" it to one provider — it
simply uses whatever model the host platform is configured to use, and does its
semantic work *through that host model* (there is no separate embedding/vector step
that could phone a different vendor). So the guarantee is **environmental**, and on
this machine it already holds. Verified 2026-06-25:

| Check | State |
|---|---|
| Host platform | Claude Code (Anthropic's official CLI) |
| `model` | `opus[1m]` (Anthropic) |
| `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL` / `baseUrl` | **unset** everywhere (env, `settings.json`, `~/.claude.json`) — no proxy/Ollama redirect |
| `settings.json` `env` block | only `CLAUDE_AUTOCOMPACT_*` — no provider override |
| `OPENAI_API_KEY` / `VOYAGE_API_KEY` / `GEMINI_API_KEY` / `OLLAMA_HOST` | **unset** — no third-party model/embedding key exists to call |

**Rules to keep it Anthropic-only:**
1. Do **not** set `ANTHROPIC_BASE_URL` to an Ollama/proxy endpoint.
2. Do **not** configure Ollama/OpenAI/Voyage/Gemini as the model or embedding
   provider (the README's "point at a local model such as Ollama" path is exactly
   what we are *avoiding*).
3. Run `/understand` only from **this** Claude Code session.

Under these conditions the only network egress during the build is Claude Code →
Anthropic. (The **dashboard** is a separate local web UI — see §6 — and serves the
already-built JSON; it makes no model calls.)

## 3. Current environment / readiness

| Item | State | Note |
|---|---|---|
| `~/openeyes` | **on `develop`**, HEAD `d94353442b`, clean | 14,653 tracked files / 369M; 11,271 php, 1,035 js, 245 ts |
| ` ↳ vendor/ · node_modules/` | **absent** | build sees first-party code only — leaner & cheaper than the "~40k" estimate |
| ` ↳ submodule` | `protected/assets/nxblu` (`openeyes/nxblu`) | analyzed only if the submodule is initialized |
| `~/PayloadProcessor` | on `master`, clean | 310 files; `develop` exists **remote-only**; origin `git@github.com:openeyes/PayloadProcessor.git` |
| `~/IOLMasterImport` | on `master`, clean | 147 files, **Java-dominant** (68 java, 36 jar, 8 php); `develop` remote-only; origin `git@github.com:openeyes/IOLMasterImport.git` |
| Runtimes | docker 29.6.0 ✓ · git 2.43 ✓ · python3 3.12.3 ✓ · **node/npm ✗** | node needed for the dashboard (and possibly the parser) — install when reached |
| Plugin | **not installed** | only the official marketplace is registered |

## 4. Branch posture ("up to the develop branch")

- **OpenEyes** is the build target and is already on `develop`. The graph is pinned
  to **`develop @ d94353442b`** — record this SHA so the artifact is reproducible
  and you know exactly what release-line it reflects.
- **Refresh per release:** when `develop` moves, `git pull` then re-run
  `/understand` — it re-analyzes **only changed files** (cheap). Optional
  `--auto-update` installs a post-commit hook to keep it current automatically.
  (OpenEyes releases frequently, so the incremental path is the norm after the
  first build.)

## 5. Cross-repo scope (PayloadProcessor / IOLMaster, "when needed")

Understand Anything analyzes **one directory tree**; cross-repo graphs are not a
native feature. The plan therefore is:

- **Primary:** full graph over `~/openeyes@develop`.
- **PayloadProcessor / IOLMaster:** built as **their own** graphs and consulted when
  a bug touches the integration boundary (payload processing, IOLMaster biometry
  import). PayloadProcessor is tiny (310 files) — a near-free extra build.
- **Build order:** **OpenEyes first.** `IOLMasterImport` and `PayloadProcessor` are
  built after, on demand.
- **IOLMasterImport posture:** present at `~/IOLMasterImport`, on `master` (its
  `develop` is remote-only), Java-dominant — tree-sitter handles Java, so it graphs
  cleanly. When an IOLMaster-import bug needs it:
  `git -C ~/IOLMasterImport fetch origin develop && git -C ~/IOLMasterImport checkout develop`
  then `/understand IOLMasterImport --review`.
- **PayloadProcessor posture:** **default on-demand** — left on `master` for now;
  when a payload bug appears, `git fetch origin develop && git checkout develop`
  then `/understand PayloadProcessor --review`. (Branches are not switched unprompted.)

## 6. Prerequisites to clear before/around the build

1. **Install the plugin** (Claude Code REPL):
   ```
   /plugin marketplace add Egonex-AI/Understand-Anything
   /plugin install understand-anything
   ```
2. **node/npm** — absent. The graph build runs through Claude Code's agents, but
   the **dashboard** (`/understand-dashboard`) needs node, and the parser may too.
   Preferred fix (dockerised, no host install): run node from a container when the
   dashboard is needed. Install only if a build step demands it.
3. **IOLMaster** — resolve per §5 if its context is wanted.

## 7. Runbook — kicking it off

> The build is triggered by the `/understand` **slash command**, which the user
> runs in the Claude Code REPL — a plugin pipeline can't be launched from inside an
> agent tool loop. Steps 1–2 are one-time; step 3 is the build.

1. Install the plugin (§6.1).
2. Confirm Anthropic-only (§2) — already satisfied; no action unless config changes.
3. **Build OpenEyes (rich):** from `/home/toukan`, run
   ```
   /understand openeyes --review
   ```
   `--review` runs a full completeness pass over the graph (richest result). Expect
   a large first-run token spend — acceptable per the goal; subsequent runs are
   incremental.
4. **(Optional) PayloadProcessor:**
   ```
   /understand PayloadProcessor --review
   ```
5. **Explore / use:**
   - `/understand-dashboard` — interactive web view (needs node, §6.2)
   - `/understand-chat <question>` — ask the graph in English
   - `/understand-explain <file>` — deep-dive a file/subsystem
6. **Commit the artifact** (optional, for sharing): commit everything under
   `.understand-anything/` **except** `intermediate/` and `diff-overlay.json`.
   Caveat: committing the JSON into the OE repo adds churn each release — prefer
   regenerating locally, or keep it in a sibling location, unless the team wants it
   versioned.

## 8. How Claude then uses it (and the one thing that makes it click)

The graph gives Claude a precise map of *where and how*. Pair it with a curated
root **`CLAUDE.md`** carrying the OpenEyes domain *why* — the institution/site
model, docman auth, the resetuserlock NULL-institution quirk, Traefik routing, etc.
Retrieval finds the code; the `CLAUDE.md` supplies the intent a parser can't infer.
Together, a one-line English bug report is usually enough for Claude to land in the
right place with the right assumptions.

## 9. Cost expectation

First build: large (semantic pass over ~14.7k mostly-PHP first-party files) — by
design, and cheaper than the "40k" estimate because vendor/node_modules are absent.
Every run after that re-analyzes only changed files, so per-release refreshes are
inexpensive.
