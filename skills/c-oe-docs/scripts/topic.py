#!/usr/bin/env python3
"""
c-oe-docs topic mapper - answer "which manuals cover feature X?" in one call.

Where resolve.py ranks single pages by front matter, this builds a cached graph
of the whole OeDocumentation corpus - every reader page as a node (joined with
data/coverage.json units), typed edges (related:, oe:link, prerequisites:,
admin prereqs), and an idf-weighted full-text term index - then answers a topic
query with the complete related-manual set grouped by facet:

    Create / record        user-guides/patients/adding-events/...
    Configure              user-guides/configuring-openeyes/...
    Data in / integration  devops/...
    Reports / menu bar     user-guides/menu-bar/...
    ...

The term index is what bridges vocabulary gaps: "biometry" also surfaces
devops/iolmaster/iolmaster-import (title "IOLMaster Import"), which no
front-matter search can find. topic_aliases.json adds query-side synonyms the
corpus itself cannot derive (VFA -> visual fields, IOL -> intraocular lens).

Usage:
    topic.py <query> [--limit N] [--all] [--json] [--rebuild] [--docs-root DIR]

    <query>       feature/topic ("biometry", "IOLMaster", "visual fields") or
                  a route/URI (/OphInBiometry/default/create).
    --limit N     max rows per facet (default 8).
    --all         no per-facet cap.
    --json        machine-readable output.
    --rebuild     force a cache rebuild.
    --docs-root   the module checkout (contains data/ and docs/). Default:
                  $OE_DOCS_ROOT, else the known host repo, else in-container,
                  else $PWD.

The graph cache lives under ~/.cache/oe-docs-topic/ (never in the kit tree)
and rebuilds transparently when docs/** or coverage.json change.
"""
import argparse
import hashlib
import json
import math
import os
import re
import sys

DEFAULT_ROOTS = [
    "/home/toukan/Temp10/oedocumentation-test",
    "/var/www/openeyes/protected/modules/OeDocumentation",
]
CACHE_DIR = os.path.expanduser("~/.cache/oe-docs-topic")
CACHE_VERSION = 1
DF_CAP_RATIO = 0.20  # terms in more than this share of pages carry no signal
STOPWORDS = frozenset("""
the and for with that this from are was were has have had not you your can may
its use used using will when where which while whose been being does did doing
each every all any both more most other some such than then them they there
these those into onto over under between about after before during out off
above below only own same too very just also but nor how what who whom why
one two three page pages see section note event events new record records
""".split())

FACETS = [
    ("user-guides/patients/adding-events/", "Create / record"),
    ("user-guides/configuring-openeyes/", "Configure"),
    ("devops/", "Data in / integration"),
    ("user-guides/menu-bar/", "Reports / menu bar"),
    ("user-guides/patients/", "Patient record / viewing"),
    ("user-guides/getting-started/", "Getting started"),
    ("user-guides/introduction/", "Introduction"),
    ("deprecated/", "Deprecated"),
    ("review/", "Review skeletons (unverified)"),
    ("help/", "Authoring / help"),
]


def find_root(explicit):
    for cand in [explicit, os.environ.get("OE_DOCS_ROOT"), *DEFAULT_ROOTS, os.getcwd()]:
        if cand and os.path.isfile(os.path.join(cand, "data", "coverage.json")):
            return cand
    return None


def tokens(s):
    """Split into lowercase tokens; CamelCase words also emit their parts, so
    OphInBiometry matches both 'ophinbiometry' and 'biometry'."""
    out = []
    for word in re.findall(r"[A-Za-z0-9]+", s or ""):
        low = word.lower()
        if len(low) > 2 and low not in STOPWORDS:
            out.append(low)
        parts = re.findall(r"[A-Z]+(?![a-z])|[A-Z][a-z]+|[a-z]+|\d+", word)
        if len(parts) > 1:
            for p in parts:
                pl = p.lower()
                if len(pl) > 2 and pl not in STOPWORDS and pl != low:
                    out.append(pl)
    return out


def norm_route(s):
    return re.sub(r"/+", "/", re.sub(r"[^a-z0-9/]+", "", (s or "").lower())).strip("/")


# ---------------------------------------------------------------- build phase

LIST_KEYS = ("related", "prerequisites")
SCALAR_KEYS = ("title", "status", "uri", "admin_uri", "admin_group", "group",
               "event_type", "reach", "unit_id", "section")


def parse_page(path):
    """Front matter (subset), body oe:link targets, first-paragraph excerpt,
    and the body's term counts."""
    fm = {k: [] for k in LIST_KEYS}
    body_lines = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        return fm, [], "", {}
    lines = text.split("\n")
    i = 0
    if lines and lines[0].strip() == "---":
        cur_list = None
        for i in range(1, len(lines)):
            line = lines[i]
            if line.strip() == "---":
                i += 1
                break
            m = re.match(r"^([A-Za-z_]+):\s*(.*)$", line)
            if m:
                key, val = m.group(1), m.group(2).strip().strip('"').strip("'")
                cur_list = key if key in LIST_KEYS and not val else None
                if key in SCALAR_KEYS and val:
                    fm[key] = val
                elif key in LIST_KEYS and val:
                    fm[key] = [val]
            elif cur_list and re.match(r"^\s+-\s+", line):
                fm[cur_list].append(re.sub(r"^\s+-\s+", "", line).strip().strip('"').strip("'"))
            elif not re.match(r"^\s", line):
                cur_list = None
    body_lines = lines[i:]

    links = re.findall(r'oe:link\s+slug="([^"]+)"', text)

    excerpt = ""
    in_fence = False
    para = []
    for line in body_lines:
        st = line.strip()
        if st.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence or st.startswith(("#", "|", ">", "---")):
            continue
        if not st:
            if para:
                break
            continue
        st = re.sub(r"<!--.*?-->", "", st)
        st = re.sub(r"[*`_]", "", st).strip()
        if st:
            para.append(st)
    if para:
        joined = " ".join(para)
        excerpt = joined[:110] + ("..." if len(joined) > 110 else "")

    counts = {}
    for t in tokens("\n".join(body_lines)):
        counts[t] = counts.get(t, 0) + 1
    return fm, links, excerpt, counts


def derive_module(*candidates):
    for c in candidates:
        m = re.search(r"(?i)\b(oph[a-z]+)\b", c or "")
        if m:
            return m.group(1)
    return ""


def build_graph(root):
    docs_dir = os.path.join(root, "docs")
    with open(os.path.join(root, "data", "coverage.json"), encoding="utf-8") as fh:
        cov_units = json.load(fh).get("units", [])

    units_by_slug = {}
    admin_id_to_slug = {}
    for u in cov_units:
        slug = u.get("doc_slug") or ""
        if not slug:
            continue
        units_by_slug.setdefault(slug, []).append(u)
        uid = u.get("unit_id") or ""
        if uid.startswith("admin."):
            parts = uid.split(".")
            if len(parts) == 3:
                admin_id_to_slug[parts[1] + "/" + parts[2]] = slug

    nodes = []
    ids = {}
    term_counts = []
    raw_edges = []  # (src_slug, dst_slug, type)

    for dirpath, dirnames, filenames in os.walk(docs_dir):
        dirnames[:] = [d for d in sorted(dirnames) if not (
            os.path.relpath(dirpath, docs_dir) == "help" and d == "_evidence")]
        for fn in sorted(filenames):
            if not fn.endswith(".md"):
                continue
            path = os.path.join(dirpath, fn)
            slug = os.path.relpath(path, docs_dir)[:-3].replace(os.sep, "/")
            fm, links, excerpt, counts = parse_page(path)
            units = units_by_slug.get(slug, [])
            u0 = units[0] if units else {}
            node = {
                "slug": slug,
                "title": fm.get("title", "") or u0.get("label", ""),
                "status": fm.get("status", "") or u0.get("doc_status", ""),
                "uri": fm.get("uri", "") or u0.get("uri", ""),
                "admin_uri": fm.get("admin_uri", ""),
                "admin_group": fm.get("admin_group", ""),
                "group": fm.get("group", "") or u0.get("group", ""),
                "event_type": fm.get("event_type", ""),
                "reach": fm.get("reach", ""),
                "label": u0.get("label", ""),
                "kind": u0.get("kind", ""),
                "module": derive_module(
                    fm.get("uri", ""), fm.get("admin_uri", ""), fm.get("unit_id", ""),
                    u0.get("uri", ""), u0.get("unit_id", ""), u0.get("source_ref", "")),
                "excerpt": excerpt,
                "units": [u.get("unit_id", "") for u in units],
            }
            ids[slug] = len(nodes)
            nodes.append(node)
            term_counts.append(counts)
            for r in fm["related"]:
                raw_edges.append((slug, r, "related"))
            for p in fm["prerequisites"]:
                if "/" in p:  # prose entries like "None - ..." are not slugs
                    raw_edges.append((slug, p, "prereq"))
            for l in links:
                raw_edges.append((slug, l, "link"))
            for u in units:
                meta = u.get("meta") or {}
                for pid in (meta.get("hard_prereqs") or []) + (meta.get("soft_prereqs") or []):
                    tgt = admin_id_to_slug.get(pid)
                    if tgt:
                        raw_edges.append((slug, tgt, "prereq"))

    edges = []
    seen = set()
    for src, dst, typ in raw_edges:
        si, di = ids.get(src), ids.get(dst)
        if si is None or di is None or si == di or (si, di, typ) in seen:
            continue
        seen.add((si, di, typ))
        edges.append([si, di, typ])

    # title/label terms count toward the term index too (weighted by repetition
    # they'd never get from one body mention)
    for idx, node in enumerate(nodes):
        for t in tokens(" ".join([node["title"], node["label"], node["admin_group"]])):
            term_counts[idx][t] = term_counts[idx].get(t, 0) + 3

    df_cap = max(30, int(len(nodes) * DF_CAP_RATIO))
    postings = {}
    for idx, counts in enumerate(term_counts):
        for t, tf in counts.items():
            postings.setdefault(t, []).append([idx, tf])
    terms = {t: p for t, p in postings.items() if len(p) <= df_cap}

    return {"version": CACHE_VERSION, "nodes": nodes, "edges": edges, "terms": terms}


def corpus_stamp(root):
    count, latest = 0, 0.0
    for dirpath, _dirnames, filenames in os.walk(os.path.join(root, "docs")):
        for fn in filenames:
            if fn.endswith(".md"):
                count += 1
                try:
                    latest = max(latest, os.path.getmtime(os.path.join(dirpath, fn)))
                except OSError:
                    pass
    try:
        latest = max(latest, os.path.getmtime(os.path.join(root, "data", "coverage.json")))
    except OSError:
        pass
    return {"count": count, "mtime": round(latest, 2)}


def load_graph(root, rebuild=False):
    stamp = corpus_stamp(root)
    key = hashlib.sha1(os.path.abspath(root).encode()).hexdigest()[:16]
    cache_path = os.path.join(CACHE_DIR, key + ".json")
    if not rebuild and os.path.isfile(cache_path):
        try:
            with open(cache_path, encoding="utf-8") as fh:
                cached = json.load(fh)
            if cached.get("version") == CACHE_VERSION and cached.get("stamp") == stamp:
                return cached
        except (OSError, ValueError):
            pass
    graph = build_graph(root)
    graph["stamp"] = stamp
    os.makedirs(CACHE_DIR, exist_ok=True)
    tmp = cache_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(graph, fh, separators=(",", ":"))
    os.replace(tmp, cache_path)
    return graph


# ---------------------------------------------------------------- query phase

def load_aliases():
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "topic_aliases.json")
    try:
        with open(path, encoding="utf-8") as fh:
            return {k.lower(): v for k, v in json.load(fh).items()}
    except (OSError, ValueError):
        return {}


def seed_scores(graph, query, alias_map):
    nodes = graph["nodes"]
    n = len(nodes)
    qtok = tokens(query)
    alias_phrases = []
    for t in set(qtok) | {query.lower().strip()}:
        alias_phrases.extend(alias_map.get(t, []))
    atok = [t for p in alias_phrases for t in tokens(p) if t not in qtok]

    scores = [0.0] * n
    reasons = [set() for _ in range(n)]
    hit_tokens = [set() for _ in range(n)]  # which primary tokens each page matched

    def field_pass(qt, weight, primary):
        qs = set(qt)
        if not qs:
            return
        for idx, node in enumerate(nodes):
            ntok = set(tokens(node["title"])) | set(tokens(node["slug"])) \
                | set(tokens(node["label"]))
            s = 0
            s += 40 * len(qs & set(tokens(node["title"])))
            s += 35 * len(qs & set(tokens(node["slug"])))
            s += 25 * len(qs & set(tokens(node["label"])))
            s += 12 * len(qs & set(tokens(node["group"] + " " + node["admin_group"])))
            s += 10 * len(qs & set(tokens(node["reach"])))
            if s:
                scores[idx] += weight * s
                reasons[idx].add("match")
                if primary:
                    hit_tokens[idx] |= qs & (ntok | set(tokens(node["reach"])))

    field_pass(qtok, 1.0, True)
    field_pass(atok, 0.5, False)

    ql = query.lower().strip()
    for idx, node in enumerate(nodes):
        if ql and ql in node["title"].lower():
            scores[idx] += 120
        if ql and ql.replace(" ", "-") in node["slug"].lower():
            scores[idx] += 120

    if query.startswith("/") or re.search(r"/[a-z]+/[a-z]", query, re.I):
        nq = norm_route(query)
        for idx, node in enumerate(nodes):
            for uri in (node["uri"], node["admin_uri"]):
                nu = norm_route(uri)
                if nu and nq == nu:
                    scores[idx] += 1000
                    reasons[idx].add("uri")
                elif nu and (nq in nu or nu in nq):
                    scores[idx] += 700
                    reasons[idx].add("uri")

    terms = graph["terms"]
    for qt, weight in [(t, 1.0) for t in qtok] + [(t, 0.5) for t in atok]:
        postings = terms.get(qt)
        if not postings:
            continue
        idf = math.log(n / len(postings))
        for idx, tf in postings:
            scores[idx] += weight * min(45.0, 6.0 * idf * math.log(1 + tf))
            reasons[idx].add("term")
            if weight == 1.0:
                hit_tokens[idx].add(qt)

    # pages matching EVERY query token outrank ones matching a single common
    # word ("axial length" must beat "Default Incision Length")
    qset = set(qtok)
    if len(qset) > 1:
        for idx in range(n):
            if scores[idx] and hit_tokens[idx] >= qset:
                scores[idx] = 1.5 * scores[idx] + 60
    return scores, reasons


def cluster_key(node):
    if node["module"]:
        return "module:" + node["module"].lower()
    return "folder:" + (node["slug"].rsplit("/", 1)[0] if "/" in node["slug"] else node["slug"])


def facet_of(slug):
    for prefix, name in FACETS:
        if slug.startswith(prefix):
            return name
    return "Other"


def run_query(graph, query, alias_map):
    nodes = graph["nodes"]
    scores, reasons = seed_scores(graph, query, alias_map)
    ranked = sorted(range(len(nodes)), key=lambda i: -scores[i])
    seeds = [i for i in ranked if scores[i] > 0][:40]
    if not seeds:
        return None

    # cluster the strongest seeds to expose "which feature did you mean"
    clusters = {}
    for i in seeds[:20]:
        key = cluster_key(nodes[i])
        c = clusters.setdefault(key, {"key": key, "score": 0.0, "members": []})
        c["members"].append(i)
    for c in clusters.values():
        # best member dominates: many weak one-word matches must not outvote
        # one page that matched the whole query
        member_scores = sorted((scores[i] for i in c["members"]), reverse=True)
        c["score"] = member_scores[0] + 0.25 * sum(member_scores[1:])
    ordered = sorted(clusters.values(), key=lambda c: -c["score"])
    top = ordered[0]
    ambiguous = [c for c in ordered[1:4]
                 if c["score"] >= 0.4 * top["score"] and len(c["members"]) >= 2]

    picked = {}

    def add(idx, why):
        if idx not in picked:
            picked[idx] = {"idx": idx, "score": scores[idx], "why": set()}
        picked[idx]["why"].add(why)

    for i in seeds:
        add(i, "match" if "match" in reasons[i] or "uri" in reasons[i] else "term")

    # pull in structural neighbours of the strongest seeds even when they never
    # mention the query term (element pages, config counterparts)
    strong = seeds[:8]
    strong_set = set(strong)
    # whole-folder pulls only where the folder itself is about the query -
    # otherwise a consumer page (op-note/biometry) drags in its ~20 siblings
    qtok = set(tokens(query))
    folders = set()
    for rank, i in enumerate(strong[:3]):
        if "/" not in nodes[i]["slug"]:
            continue
        folder = nodes[i]["slug"].rsplit("/", 1)[0]
        if rank == 0 or (qtok & set(tokens(folder.rsplit("/", 1)[-1]))):
            folders.add(folder)
    for idx, node in enumerate(nodes):
        if "/" in node["slug"] and node["slug"].rsplit("/", 1)[0] in folders:
            add(idx, "sibling")
    for si, di, typ in graph["edges"]:
        if si in strong_set:
            add(di, typ)
        elif di in strong_set:
            add(si, typ)

    facets = {}
    for rec in picked.values():
        facets.setdefault(facet_of(nodes[rec["idx"]]["slug"]), []).append(rec)
    for rows in facets.values():
        rows.sort(key=lambda r: -r["score"])
    facet_order = [name for _p, name in FACETS] + ["Other"]
    ordered_facets = [(f, facets[f]) for f in facet_order if f in facets]
    return {"top": top, "ambiguous": ambiguous, "facets": ordered_facets}


def cluster_label(graph, cluster):
    nodes = graph["nodes"]
    node = nodes[cluster["members"][0]]
    if cluster["key"].startswith("module:"):
        pretty = node["module"]
        for i in cluster["members"]:
            m = re.search(r"\b(Oph[A-Z][A-Za-z]+)\b",
                          nodes[i]["uri"] + " " + nodes[i]["admin_uri"] + " "
                          + " ".join(nodes[i]["units"]))
            if m:
                pretty = m.group(1)
                break
        return "%s (module %s)" % (node["title"] or node["label"] or node["slug"], pretty)
    return "%s (%s)" % (node["title"] or node["slug"], cluster["key"][7:])


def main():
    ap = argparse.ArgumentParser(description="Map a topic to its full manual set.")
    ap.add_argument("query", nargs="+")
    ap.add_argument("--limit", type=int, default=8)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--rebuild", action="store_true")
    ap.add_argument("--docs-root")
    args = ap.parse_args()
    query = " ".join(args.query)

    root = find_root(args.docs_root)
    if not root:
        sys.exit("error: no OeDocumentation checkout found (set OE_DOCS_ROOT to the "
                 "module dir containing data/coverage.json).")

    graph = load_graph(root, rebuild=args.rebuild)
    result = run_query(graph, query, load_aliases())
    if not result:
        sys.exit(f"no documentation page matched: {query!r}")

    nodes = graph["nodes"]
    cap = 10 ** 9 if args.all else args.limit

    if args.json:
        out = {
            "query": query,
            "topic": cluster_label(graph, result["top"]),
            "also_matched": [cluster_label(graph, c) for c in result["ambiguous"]],
            "facets": {
                name: [{"slug": nodes[r["idx"]]["slug"],
                        "title": nodes[r["idx"]]["title"] or nodes[r["idx"]]["label"],
                        "status": nodes[r["idx"]]["status"],
                        "why": sorted(r["why"]),
                        "score": round(r["score"], 1)}
                       for r in rows[:cap]]
                for name, rows in result["facets"]
            },
        }
        print(json.dumps(out, indent=2))
        return

    print(f"query: {query!r}   (docs root: {root})")
    print(f"topic: {cluster_label(graph, result['top'])}")
    if result["ambiguous"]:
        print("also matched (rerun with a more specific query if this was meant):")
        for c in result["ambiguous"]:
            print(f"  - {cluster_label(graph, c)}")
    for name, rows in result["facets"]:
        shown = rows[:cap]
        print(f"\n{name}:")
        for r in shown:
            node = nodes[r["idx"]]
            status = node["status"] or "?"
            why = ",".join(sorted(r["why"]))
            title = node["title"] or node["label"] or ""
            line = f"  {node['slug']} [{status}] ({why})"
            if title and title.lower() not in node["slug"].lower():
                line += f" - {title}"
            print(line)
            if node["excerpt"]:
                print(f"      {node['excerpt']}")
        if len(rows) > len(shown):
            print(f"  (+{len(rows) - len(shown)} more - rerun with --all)")
    print()


if __name__ == "__main__":
    main()
