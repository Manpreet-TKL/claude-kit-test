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
| `unverified/oe-docs-campaign-bugs.md` | develop @ `798f9c0de2` (2026-07-02, ancestor of `v26.1.0-pre3`) | OeDocumentation screenshot/write-up campaign; 532 findings, none reproduced beyond the finder's own pass |
| `verified/oe-develop-bug-hunt-2026-07-29.md` | develop @ `04c938c0a4` (2026-07-29, OE-18003, ancestor of `v26.1.0-pre3`) | scripted + Chrome-driven gauntlets; 9 bugs, each independently replayed by a second agent on a different patient (R1), the 3 HIGH-severity ones a third time with free choices varied (R2) |
| `unverified/oe-develop-bug-hunt-2026-07-29-static.md` | develop @ `04c938c0a4` (same run) | static code sweep companion to the above; code-level hypotheses, explicitly not exercised in a browser |
