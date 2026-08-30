# OpenEyes bugs

Bugs found while working on something else - documentation campaigns, code
sweeps, ad hoc browsing - rather than filed as a repro against a specific
ticket. `verified/` bugs were reproduced in a browser against a stated
commit or tag; `unverified/` bugs are code-level findings or raw reports that
were never exercised. A finding moves from unverified to verified only once
someone actually reproduces it - don't reclassify on confidence alone.

One file per hunt, named `<source>-<date>.md`, opening with an environment
line (branch/commit or tag, DB, image) so every bug in it carries a version
without repeating one per entry.

A bug that gets fixed for real gets a PR (`create-oe-pr`); it doesn't need an
entry here. These are the ones nobody has actioned yet.

## Current documents

| File | Version | Found via |
|---|---|---|
| `PROGRESS.md` | develop @ `bafadd01b90` | live counts for the 2026-08-30 clinical bug swarm |
| `verified/oe-develop-bug-swarm-2026-08-30-wave-002.md` | develop @ `bafadd01b90` | current-target R1 and R2 clinical repros |
| `unverified/oe-develop-bug-swarm-2026-08-30-wave-001.md` | develop @ `bafadd01b90` | develop-diff candidate discovery by Luna agents 01 through 04; browser verification pending |
| `unverified/oe-develop-bug-swarm-2026-08-30-wave-004.md` | develop @ `bafadd01b90` | version-matched clinical snapshot candidates from Luna agents 15 through 19 |
| `unverified/oe-develop-bug-swarm-2026-08-30-wave-005.md` | develop @ `bafadd01b90` | six unverified review candidates from Luna threads 20 through 30; frontend replay stopped |
| `unverified/planned-clinical-test-walks-2026-08-30.md` | planning inventory | unexecuted clinical walks retained after frontend testing stopped |
| `unverified/replay-openeyes-import-2026-08-30.md` | source ledger, current replay pending | compact O1 through O96 provenance import; non-clinical rows excluded from this run |
| `unverified/replay-tooling-import-2026-08-30.md` | non-product | compact T1 through T231 tooling ledger; excluded from the verified target |
| `unverified/oe-docs-campaign-bugs.md` | develop @ `798f9c0de2` (2026-07-02, ancestor of `v26.1.0-pre3`) | OeDocumentation screenshot/write-up campaign; 532 findings, none reproduced beyond the finder's own pass |
| `verified/oe-develop-bug-hunt-2026-07-29.md` | develop @ `04c938c0a4` (2026-07-29, OE-18003, ancestor of `v26.1.0-pre3`) | scripted + Chrome-driven gauntlets; 9 bugs, each independently replayed by a second agent on a different patient (R1), the 3 HIGH-severity ones a third time with free choices varied (R2) |
| `unverified/oe-develop-bug-hunt-2026-07-29-static.md` | develop @ `04c938c0a4` (same run) | static code sweep companion to the above; code-level hypotheses, explicitly not exercised in a browser |

## Sample database generation project fold

All 327 rows from `oe-sample-db/replay/BUGS.md` are retained under
`unverified/`: 96 OpenEyes or deployment records in the OpenEyes import and 231
sample-generation or replay-tooling records in the non-product tooling import.
Import provenance does not promote any row to verified status.
