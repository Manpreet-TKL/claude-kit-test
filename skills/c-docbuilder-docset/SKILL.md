---
name: c-docbuilder-docset
description: OeDocBuilder docset contract (read before authoring)
disable-model-invocation: false
---

# OeDocBuilder docset scaffold

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

A **docset** is one folder OeDocBuilder turns into a styled `.docx` + PDF. Emit exactly
this shape; the module's validator rejects anything else.

```
<doc_id>/
├── manifest.json          # all front-matter; doc_id MUST equal this folder name
├── 01_introduction.md     # sections are NN_slug.md, NN two-digit ascending
├── 02_architecture.md
└── assets/img/*.png|jpg    # local images only, referenced by relative path
```

`manifest.json` (JSON, pretty-printed):

```json
{
  "schema_version": 1,
  "doc_id": "<folder-slug>",
  "title": "...", "subtitle": "(optional)",
  "version": "1.0", "date": "YYYY-MM-DD",
  "classification": "Internal",
  "toc": true, "numbering": true,
  "authors":  [ { "name": "...", "role": "Author" } ],
  "revisions": [ { "version": "1.0", "date": "YYYY-MM-DD", "author": "...", "summary": "..." } ],
  "sections": [ { "file": "01_introduction.md" }, { "file": "02_architecture.md" } ]
}
```

Rules: `schema_version` must be `1`; `doc_id` slug `^[a-z0-9][a-z0-9-]{1,63}$` == folder
name; `version` `^\d+(\.\d+){0,2}$` (a string); `date` `YYYY-MM-DD`; `authors` and
`revisions` non-empty; every `.md` on disk listed in `sections`, unique and ascending.
The cover, document-control and contents pages are **generated from the manifest** - do
not author them.

Each section file: **exactly one `# H1` as the first non-blank line**, no skipped heading
levels. Allowed: paragraphs, bold/italic/`code`, fenced code, lists, blockquotes, GFM
pipe tables (<= 8 cols), footnotes, and local `.png`/`.jpg` images
`![Caption](assets/img/x.png){width=140mm}`. **Forbidden** (build errors): raw HTML, raw
pandoc `{=openxml}`/`{=latex}` blocks, remote/absolute/`..` image paths, SVG/GIF,
`_`-prefixed filenames.

Authoritative, exhaustive contract (read if anything above is ambiguous):
`protected/modules/OeDocBuilder/docs/DOC_BUILDER_FORMAT.md`. Working example:
`protected/modules/OeDocBuilder/tests/fixtures/docsets/oe-docbuilder-sample/`. Validate
before shipping: `./protected/yiic docbuilder validate --dir=<path>` (non-zero exit = fix
it).
