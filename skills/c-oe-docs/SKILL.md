---
name: c-oe-docs
description: Answer "how does X work / where do I configure X" questions about the OpenEyes application by resolving a route, URI, or topic to its OeDocumentation page and reading that page. Use whenever a question is about how an OpenEyes screen, admin setting, clinical event, element, or workflow behaves - before reading app source or guessing.
---

# OpenEyes documentation lookup

The OeDocumentation module carries a verified, app-mirroring markdown corpus (`docs/**`,
~700 pages) covering the whole OpenEyes application, laid out as a physical mirror of how a
user explores it: `user-guides/{introduction,getting-started,configuring-openeyes,patients,
menu-bar}` (every admin page, all clinical event types and their elements, getting-started/
workflow/reference/reporting content) and `devops/` (SSO, integrations). Each page's front
matter records its `uri`/`admin_uri`, `status` (`reviewed` = two-source verified), and
cross-links. `data/coverage.json` is the discovered route -> `doc_slug` map.

When someone asks how an OpenEyes feature works, where a setting lives, or what a screen
records, **resolve it to a doc page and answer from that page** - don't read app source or
answer from memory first. The corpus was verified against code + live app + DB, so it is
the cheapest correct source.

## Primary mechanism - `scripts/resolve.py`

Resolve a route/URI or a free-text topic to the matching page, then read it:

    # list candidate pages (ranked)
    python3 scripts/resolve.py 'letter snippet groups'
    python3 scripts/resolve.py '/OphCoCorrespondence/oeadmin/snippetGroup/list'

    # resolve AND print the best page's markdown in one step
    python3 scripts/resolve.py vitrectomy --show
    python3 scripts/resolve.py '/patient/summary' --show

    # machine-readable
    python3 scripts/resolve.py 'allergy severity' --json

It reads `data/coverage.json` (exact `uri` and module/controller/action matches score
highest) **and** scans `docs/**` front matter, so it also finds hand-authored pages that
are not discovered units (`help/`, `devops/sso/`, `user-guides/introduction/`, every branch's
`_overview`). Route-shaped queries (`/Module/controller/action`) match on URI/route;
everything else is ranked by keyword overlap against title/slug/label/group.
`help/_evidence/*` scaffolds are excluded.

**Docs root:** the module checkout containing `data/` and `docs/`. The script tries
`$OE_DOCS_ROOT`, then the known host repo `~/Temp10/oedocumentation-test`, then the
in-container path, then `$PWD` - first one with `data/coverage.json` wins. Override with
`--docs-root DIR` or `OE_DOCS_ROOT`.

## Answering discipline

1. Resolve -> open the top page (`--show`). If the match is weak (low score / wrong branch),
   list a few candidates and pick by branch (`user-guides/configuring-openeyes/` for admin,
   `user-guides/patients/adding-events/` for clinical, `user-guides/menu-bar/` for
   worklists/registers/reports, `devops/` for SSO/integrations, ...).
2. Answer from the page's prose. Quote on-screen labels exactly; cite the `doc_slug`.
3. Note the page `status` if it matters: `reviewed` is verified; `draft`/`skeleton` is not
   yet confirmed (say so). If nothing matches, say the corpus has no page for it rather
   than inventing behaviour - then, only if needed, fall back to app source.
4. This corpus documents **what the software does** - never derive clinical advice from it.

## Other mechanisms (available; use the resolver first)

- **coverage + sitemap joint index.** `data/coverage.json` (route -> doc_slug, status,
  source_ref) pairs with the `oe-frontend-tests` sitemap (per-page DOM/control selectors) to
  answer "which control on which screen" alongside "what does it do". Join on `uri`.
- **Docset bundles for a Claude Project.** `yiic oedocs export --section=<s>` (and
  `docbuilder buildAll`) lower the corpus into self-contained docset bundles - drop a
  section's bundle into a Claude Project to ground a whole conversation in one manual.
- **oe-map symbol -> doc_slug enrichment.** `source_ref` on each unit (e.g.
  `modules/OphCiExamination/...#action`) lets an oe-map code lookup jump straight from a
  symbol to its documentation page, and back.

When loaded as context with no task, reply only `Context loaded.`
