---
name: oe-document-pdf-probe-recipe
description: OE Document+PDF repro loadout - /a-oe-repro is the sole entry; the paste-ready walk is canned in c-oe-nav subs/canned/document-pdf.md (hand to a Haiku subagent verbatim); grep patched/unpatched in-container before walking
metadata:
  type: project
---

Driving a Document-event PDF upload + page-preview generation (form selectors, gs test-PDF
one-liner, `getImageInfo` trigger, `/tmp/oe_pdf*` leak check) needs zero discovery:

- `/a-oe-repro` is the single entry point (`c-oe-repro-kit` was removed 2026-07-03 at
  Manpreet's request; both skills live in `~/claude-kit/skills/`). Companion `c-*` context
  skills (c-oe-nav, c-dblogin, c-oe-code) are loaded by Reading their SKILL.md directly.
- The exact paste-ready procedure (both OE_ACTIONS lists, gs one-liner, patched-check grep),
  re-verified end-to-end 2026-07-03 on snail-web-1 (2-page PDF -> +2 stubs), is canned in
  `~/.claude/skills/c-oe-nav/subs/canned/document-pdf.md` - hand that file to a Haiku
  subagent verbatim; skip probe.md/paths.md for this walk. The atlas entry is
  `subs/paths.md` "Document create form"; the journey driver's action schema is inline in
  `subs/probe.md` - never read `journey.mjs` for it.
- Pattern that worked: pin selectors/ids in the main context first, then one Haiku
  subagent finishes the walk in ~3 driver runs / ~30k tokens.

Token rules: (1) grep BaseEventTypeController in-container for patched/unpatched before
walking - it predicts the outcome; (2) if the PR.md Test section already documents a live
before/after walk from a prior session, a fresh walk is redundant unless asked.
Related: [[reference_oe_render_testing_gotchas]].
