# Channel templates (Phase 9)

Version-controllable, parameterised Mirth/BridgeLink channel templates derived from
the corpus. A template is a real channel export with the site-specific values lifted
out into named placeholders, plus a `sites.csv` giving one row of values per site and
a `params.json` cataloguing the placeholders. Rendering a template against one site
row reproduces that site's channel exactly (see "byte-exact vs logic-exact" below).

Everything here is generated deterministically by `bin/build_templates.py` from the
redacted `canonical/` copies; the read-only corpus is never touched. The builder
self-verifies: it renders every site row back through its template and asserts the
result reproduces that site's canonical channel, failing loudly otherwise.

## The two placeholder classes

A template carries two distinct kinds of `${...}` placeholder. They are filled at
different times, from different sources, by different owners. Keeping them separate is
the core of the model.

| Class | Example | Filled from | Filled when | In version control? |
|---|---|---|---|---|
| Site-parameter token | `${LISTEN_PORT}`, `${BOARD_CODE}`, `${PRACTICE_CODE}` | `sites.csv` row for the target site | render time (build the channel XML) | yes - values live in `sites.csv` |
| Redaction placeholder | `${REDACTED_PASSWORD}` (also `${REDACTED_PASSPHRASE}`, `${REDACTED_USERNAME}` where present) | the secret store, out of band | deploy time, per site | **no** - value never stored in the repo |

The redaction placeholders are inherited straight from the Wave 0 canonicalisation:
the corpus embeds a single shared 11-char `api` password 356 times (see
`secrets/redaction-log.csv` and `auth/persisted-login.md`), which redaction already
replaced with `${REDACTED_PASSWORD}`. The template keeps that placeholder verbatim and
never resolves it - secret injection is a deploy-time step
(`deployment/deployment-automation.md`), so a rendered-but-not-deployed template is
safe to commit and share. The two families here surface only `${REDACTED_PASSWORD}`
(Newmedica 7 slots, Wales 1); passphrase/username placeholders exist in the redaction
vocabulary but not in these two families.

## How a template is derived (deterministic, auditable)

`bin/build_templates.py` builds a template from a clone family (a set of channels that
are line-aligned copies of one exemplar). For each family it:

1. Selects the family members from `canonical/_manifest.csv` and picks one exemplar.
2. For each declared token, extracts the per-site value at the exact line(s) and
   capture-group given in the token spec, and asserts all occurrences of a token
   within one channel agree (e.g. Wales `BOARD_CODE` appears both in the QPD-3.2
   assignment and in the XSLT `vSender` - both must be the same integer).
3. Builds the template by replacing only the captured span on the exemplar with
   `${TOKEN}` (exact `start:end` slice, never a blind string replace), leaving every
   other byte - including the `${REDACTED_*}` placeholders - untouched.
4. Blanks the transformer sample-message fields (`<inboundTemplate>` /
   `<outboundTemplate>`), which are UI-only and carry no runtime behaviour but in this
   corpus hold patient-shaped sample payloads (see "Sample-message fields" below).
5. Writes `channel.template.xml`, `sites.csv` (one row per member), `params.json`.
6. Verifies: renders every site row back and compares to that site's canonical file
   (with the same sample fields blanked); a mismatch that is not purely whitespace
   aborts the build, and any surviving sample payload aborts it too.

The token model is positional and explicit: `(name, [(line_index, regex), ...], kind,
note)`. This is deliberate - it means a template only parameterises positions a human
declared, and the render-back check proves those positions fully account for the
per-site delta. Nothing is inferred by fuzzy matching.

## Families shipped

| Family | Members | Exemplar | Site tokens | Redaction slots | Reproduction (sample fields blanked) |
|---|--:|---|--:|--:|---|
| `pas-inbound-newmedica-local` | 28 | `PAS In LOCAL-1-0` | 8 | 7 | 28/28 byte-exact (3 sample fields neutralised) |
| `pas-query-mpi-wales` | 8 | `OpenEyes Query - ABUHB` | 5 | 1 | 3/8 byte-exact, 5/8 logic-exact (2 sample fields neutralised) |

These are the two highest-confidence clone families identified in Phase 8
(`comparisons/commonality.md`): Newmedica's 28 per-practice PAS-In channels (script
bodies byte-identical across all 28; the delta lives entirely in connector fields) and
Wales' 8 per-health-board PDQ/MPI query channels (99.4% identical; the sole logic-level
delta is one board-code integer, baked into the script text and the XSLT). Between them
they template 36 near-identical channels. The remaining reuse candidates surfaced in
Phase 8 (the `06f0b8b8` query sextet, the `da67d2ba` DICOM six, the document movers)
are additional template targets for a later pass; the two families here establish the
model and the tooling.

### Site tokens per family

Newmedica `pas-inbound-newmedica-local` (per-practice): `CHANNEL_ID` (2 occurrences -
the channel id is self-referenced in the channelMap), `PRACTICE_CODE`,
`PRACTICE_NAME`, `DEST_ID` (destination connector id), `RESPOND_AFTER_PROCESSING`
(a real per-practice behaviour toggle - true/false vary), `UI_RED`/`UI_GREEN`/`UI_BLUE`
(cosmetic channel-list colour).

Wales `pas-query-mpi-wales` (per-board): `CHANNEL_ID`, `BOARD` (short name),
`LISTEN_PORT`, `BOARD_CODE` (2 occurrences - the MPI assigning-authority code appears
in the QPD-3.2 assignment and the XSLT `vSender`), `ARCHIVE_ENABLED` (a real per-board
message-archive toggle).

Two of these tokens (`RESPOND_AFTER_PROCESSING`, `ARCHIVE_ENABLED`) are genuine
behavioural switches that vary across the family, not cosmetics - they would have been
lost by a naive "everything else is identical" assumption. They are surfaced as
first-class config so a rendered channel matches the real per-site behaviour.

## byte-exact vs logic-exact

- **byte-exact** (`byte_exact: true`, Newmedica): every rendered channel equals its
  canonical original byte-for-byte. The family carries no incidental drift.
- **logic-exact** (`byte_exact: false`, Wales): rendered channels are identical after
  whitespace normalisation; the only residual differences are two lines of incidental
  XSLT formatting drift inside the escaped `<template>` string (line 399 - a trailing
  space; line 807 - 5 vs 3 tabs of indentation). These carry no semantic meaning and do
  not correlate with board identity, so they are not tokenised; the template ships the
  exemplar's formatting and the verifier confirms the residual is whitespace-only and
  confined to exactly those two lines. A future normalisation pass could remove the
  drift at source; it is called out rather than silently absorbed.

## Sample-message fields (data-handling)

Mirth transformers carry `<inboundTemplate>` / `<outboundTemplate>` fields holding a
developer sample message used only for building the mapping in the UI - they are not
read at runtime, so a channel deployed without them behaves identically. In this corpus
some of these fields contain **patient-shaped sample payloads** (names, dates of birth,
hospital/NHS numbers). The builder therefore blanks every such field in the emitted
template, and the render-back check aborts if any survives. No template here retains a
message payload.

The same fields were also blanked at source: the Wave 0 canonicaliser
(`bin/build_canonical.py`) now neutralises `<inboundTemplate>`/`<outboundTemplate>`
content across all of `canonical/` and logs each in `secrets/redaction-log.csv`
(see `canonical/NORMALISATION-RULESET.md` and the resolved item in
`unresolved/questions.md`). The template builder keeps its own blanking as a defensive
belt-and-braces, so templates carry no message payload regardless of the canonical
input.

## How to render a template (two phases)

Rendering is a plain, order-independent placeholder substitution - no template engine,
no logic in the template.

1. **Site render** (repo-only, safe to commit): for each site-parameter token, replace
   `${TOKEN}` with the value from that site's `sites.csv` row. After this phase, no
   site token remains; the `${REDACTED_*}` placeholders are deliberately still present.
2. **Secret injection** (deploy-time only): replace each `${REDACTED_*}` placeholder
   with the value fetched from the secret store for that site. This phase runs inside
   the deploy pipeline and its output (containing live credentials) is never written to
   the repo. See `deployment/deployment-automation.md`.

`bin/build_templates.py` performs phase 1 in-process for its self-verification, filling
site tokens only; it leaves `${REDACTED_PASSWORD}` in place, which is why the builder's
"tokens not consumed" check counts only declared site tokens.

## Files in each `templates/<family>/`

| File | Contents |
|---|---|
| `channel.template.xml` | the exemplar channel with `${TOKEN}` / `${REDACTED_*}` placeholders |
| `sites.csv` | one row per site: `channel_name` + one column per site token |
| `params.json` | token catalogue: name, kind, occurrence count, note; family metadata |

## Adding a site or a template

- **New site in an existing family:** add a `sites.csv` row with that site's token
  values. No template change. (For a genuinely new site not derived from the corpus,
  allocate a fresh `CHANNEL_ID` and choose a free `LISTEN_PORT` - there is no estate
  port convention, see `networking/port-map.md`.)
- **New template family:** add a spec (`family`, `exemplar`, member predicate,
  `byte_exact`, token list) to `bin/build_templates.py` and re-run. The render-back
  self-check is the acceptance test - if the declared tokens do not fully account for
  the per-site delta, the build fails and names the offending channel and line.

## Traceability

Every token traces to a source position: `params.json` records the occurrence count
and a note, and the token spec in `bin/build_templates.py` pins each occurrence to a
line index and capture regex in the exemplar. Every family member traces to its
canonical file via `channel_name` in `sites.csv` and `canonical/_manifest.csv`. The
redaction placeholders trace to `secrets/redaction-log.csv`. Confidence: **confirmed**
- the render-back verification is an objective proof that template + row reproduces the
original channel.
