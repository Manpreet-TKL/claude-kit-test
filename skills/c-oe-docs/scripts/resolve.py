#!/usr/bin/env python3
"""
c-oe-docs resolver — map an OpenEyes route / URI / topic to its documentation
page in the OeDocumentation corpus, and optionally print that page's markdown.

Mirrors the app's DocumentationRegistry::getDocsByAdminUri() from the
filesystem side: it reads data/coverage.json (the discovered unit -> doc_slug
map) AND scans docs/**/*.md front matter, so it also resolves hand-authored
pages that are not discovered units (help/, sso-*, introduction, _overview).

Usage:
    resolve.py <query> [--show] [--limit N] [--docs-root DIR] [--json]

    <query>   a route/URI  (/OphCoCorrespondence/oeadmin/snippetGroup/list,
                            /patient/summary, OphCiExamination/default/create)
              or free-text topic ("letter snippet groups", "vitrectomy",
                            "allergy severity", "worklist").
    --show    print the matched page's markdown body (best match only).
    --limit   max matches to list (default 8).
    --docs-root DIR   the OeDocumentation module checkout (contains data/ and
                      docs/). Default: $OE_DOCS_ROOT, else the known host repo,
                      else the current directory — first one that has
                      data/coverage.json.
    --json    machine-readable output.
"""
import argparse
import glob
import json
import os
import re
import sys

DEFAULT_ROOTS = [
    "/home/toukan/Temp10/oedocumentation-test",
    "/var/www/openeyes/protected/modules/OeDocumentation",
]


def find_root(explicit):
    for cand in [explicit, os.environ.get("OE_DOCS_ROOT"), *DEFAULT_ROOTS, os.getcwd()]:
        if cand and os.path.isfile(os.path.join(cand, "data", "coverage.json")):
            return cand
    return None


def norm_route(s):
    """Lowercase, drop non [a-z0-9/], collapse slashes — for route matching."""
    return re.sub(r"/+", "/", re.sub(r"[^a-z0-9/]+", "", (s or "").lower())).strip("/")


def tokens(s):
    return [t for t in re.split(r"[^a-z0-9]+", (s or "").lower()) if len(t) > 1]


def parse_front_matter(path):
    """Return (title, uri, status) from a page's YAML front matter (best effort)."""
    title = uri = status = ""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            if fh.readline().strip() != "---":
                return title, uri, status
            for line in fh:
                if line.strip() == "---":
                    break
                m = re.match(r"^(title|admin_uri|uri|status)\s*:\s*(.*)$", line)
                if not m:
                    continue
                key, val = m.group(1), m.group(2).strip().strip('"').strip("'")
                if key == "title":
                    title = val
                elif key == "status":
                    status = val
                elif key in ("admin_uri", "uri") and not uri:
                    uri = val
    except OSError:
        pass
    return title, uri, status


def load_index(root):
    """Build a list of doc records from coverage.json units + a filesystem scan."""
    docs_dir = os.path.join(root, "docs")
    by_slug = {}

    # 1. coverage.json units (authoritative uri -> doc_slug + module/action meta)
    cov = os.path.join(root, "data", "coverage.json")
    with open(cov, encoding="utf-8") as fh:
        units = json.load(fh).get("units", [])
    for u in units:
        slug = u.get("doc_slug") or ""
        if not slug:
            continue
        meta = u.get("meta") or {}
        by_slug[slug] = {
            "slug": slug,
            "uri": u.get("uri") or "",
            "label": u.get("label") or "",
            "group": u.get("group") or "",
            "section": u.get("section") or "",
            "kind": u.get("kind") or "",
            "source_ref": u.get("source_ref") or "",
            "module": meta.get("module") or "",
            "controller": meta.get("controller") or "",
            "action": meta.get("action") or "",
            "title": "",
            "status": u.get("doc_status") or "",
            "path": os.path.join(docs_dir, slug + ".md"),
        }

    # 2. filesystem scan — fill title/uri/status and add non-unit pages
    for path in glob.glob(os.path.join(docs_dir, "**", "*.md"), recursive=True):
        slug = os.path.relpath(path, docs_dir)[:-3]
        if slug.startswith("help/_evidence/"):
            continue  # internal per-unit authoring scaffold, not a reader page
        title, uri, status = parse_front_matter(path)
        rec = by_slug.get(slug)
        if rec is None:
            rec = {
                "slug": slug, "uri": uri, "label": "", "group": "",
                "section": slug.split("/", 1)[0], "kind": "", "source_ref": "",
                "module": "", "controller": "", "action": "",
                "title": title, "status": status, "path": path,
            }
            by_slug[slug] = rec
        else:
            rec["title"] = title or rec["title"]
            rec["uri"] = rec["uri"] or uri
            rec["status"] = status or rec["status"]
    return list(by_slug.values())


def score(rec, query):
    """Rank a doc against the query. Returns (score, reason) — higher is better."""
    q = query.strip()
    ql = q.lower()

    # --- route / URI queries -------------------------------------------------
    if q.startswith("/") or re.search(r"/[a-z]+/[a-z]", q, re.I):
        nq = norm_route(q)
        nuri = norm_route(rec["uri"])
        if nuri and nq == nuri:
            return 1000, "exact uri"
        if nuri and (nq in nuri or nuri in nq):
            return 700, "uri prefix"
        # module/controller/action from source_ref or meta
        route = norm_route("/".join([rec["module"], rec["controller"], rec["action"]]))
        if route and (nq in route or route in nq):
            return 600, "module/action"
        if rec["source_ref"] and nq in norm_route(rec["source_ref"]):
            return 500, "source_ref"
        # fall through to keyword scoring for partial route words

    # --- topic / keyword queries --------------------------------------------
    qtok = set(tokens(q))
    if not qtok:
        return 0, ""
    title_tok = set(tokens(rec["title"]))
    slug_tok = set(tokens(rec["slug"]))
    label_tok = set(tokens(rec["label"]))
    group_tok = set(tokens(rec["group"]))
    s = 0
    s += 40 * len(qtok & title_tok)
    s += 35 * len(qtok & slug_tok)
    s += 25 * len(qtok & label_tok)
    s += 12 * len(qtok & group_tok)
    # exact phrase in title/slug is a strong signal
    if ql and ql in rec["title"].lower():
        s += 120
    if ql and ql.replace(" ", "-") in rec["slug"].lower():
        s += 120
    # full-token-set coverage bonus
    if qtok and qtok <= (title_tok | slug_tok | label_tok):
        s += 60
    return s, "keyword" if s else ""


def main():
    ap = argparse.ArgumentParser(description="Resolve an OpenEyes route/topic to a doc page.")
    ap.add_argument("query", nargs="+")
    ap.add_argument("--show", action="store_true")
    ap.add_argument("--limit", type=int, default=8)
    ap.add_argument("--docs-root")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    query = " ".join(args.query)

    root = find_root(args.docs_root)
    if not root:
        sys.exit("error: no OeDocumentation checkout found (set OE_DOCS_ROOT to the "
                 "module dir containing data/coverage.json).")

    index = load_index(root)
    ranked = sorted(
        ((score(r, query)[0], score(r, query)[1], r) for r in index),
        key=lambda x: x[0], reverse=True,
    )
    hits = [(sc, why, r) for sc, why, r in ranked if sc > 0][: args.limit]

    if not hits:
        sys.exit(f"no documentation page matched: {query!r}")

    if args.json:
        print(json.dumps([
            {"slug": r["slug"], "title": r["title"] or r["label"], "uri": r["uri"],
             "status": r["status"], "score": sc, "match": why,
             "path": os.path.relpath(r["path"], root)}
            for sc, why, r in hits
        ], indent=2))
        return

    print(f"query: {query!r}   (docs root: {root})\n")
    for sc, why, r in hits:
        name = r["title"] or r["label"] or r["slug"]
        exists = "" if os.path.isfile(r["path"]) else "  [MISSING FILE]"
        print(f"  {sc:>4}  {r['slug']}{exists}")
        print(f"        {name}"
              + (f"   ·  {r['uri']}" if r["uri"] else "")
              + (f"   ·  status={r['status']}" if r["status"] else "")
              + f"   ({why})")
    print()

    if args.show:
        best = hits[0][2]
        print("=" * 78)
        print(f"# {best['slug']}   ({best['path']})")
        print("=" * 78)
        try:
            with open(best["path"], encoding="utf-8", errors="replace") as fh:
                sys.stdout.write(fh.read())
        except OSError as exc:
            sys.exit(f"error reading {best['path']}: {exc}")


if __name__ == "__main__":
    main()
