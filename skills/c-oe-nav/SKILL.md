---
name: c-oe-nav
description: OpenEyes frontend navigation — hardcoded UI atlas plus a containerised browser probe for writing exact repro steps
disable-model-invocation: true
---

# OpenEyes frontend navigation

When loaded as context with no task, reply only `Context loaded.`

For turning a root cause into **Steps to Reproduce a human can follow exactly** in the OpenEyes UI — and for any task that needs to know how the frontend hangs together. Three sources, in cost order; **never invent a label**:

1. **The atlas** (`subs/paths.md`, `subs/examination.md`) — pre-recorded navigation: login, main menu, patient search/summary, the full Add Event dialog, event views, worklist, admin. Free and always present; the app nav changes little between versions.
2. **The fix branch's view code** — in-form field labels live in `protected/modules/<Module>/views/**/form_*.php`, menus in module `config/common.php`, event-type names in `event_type` seeds. Version-matched by construction: fixing v11 means reading v11's views.
3. **The live probe** (`subs/probe.md` + `scripts/journey.mjs`) — a cheap subagent drives a real browser in a container against a running sample stack and returns distilled, quoted labels. For gestures the atlas doesn't record (in-form behaviour, print/upload/search dialogs) and for proof.

## The spine

Login `/site/login` (Username/Password + Institution/Site) → landing = patient search → patient summary `/patient/summary/:id` ("Patient Overview", 'Add Event' `#add-event`) → Add Event dialog (Subspecialty ▸ Context ▸ 'Select New Event') → create form (`#et_save`) → event view `/<Module>/default/view/:id` (icon row top right: print/edit/delete) → main menu (shortcuts icon) for everything else → Admin `/admin` (33 sections, module-prefixed routes). Worklist `/worklist/view` is a single-URL panel app. Never wait for network-idle; list rows and add-event items open via JS, not hrefs.

## Writing Steps to Reproduce

1. Map root cause → user gesture: which controller action runs the broken code, which route/view reaches it, which event type (atlas table has all 23 ids/modules).
2. Compose numbered steps from the atlas; pull exact field labels from the fix branch's views. **One imperative sentence per step, leading with the verb** — collapse trivial navigation (log in → search → click the row to open the record = one step), don't split it into a click per line. Quote on-screen words exactly ('Add Event', 'Single file', 'Save'); don't narrate what the reader plainly sees (the post-login landing screen, a page just loading). Keep only parentheticals that change the outcome — free choices ("any subspecialty and context") and preconditions stated with their why ("one file leaks per page"; "a PDF newer than v1.4 — most modern PDFs are v1.5–1.7") — and cut incidental caps, versions and alternate trigger paths.
3. Anything unverified or invisible in code → probe it (subagent, not main context).
4. End on an **observable predicate** — a literal command or on-screen outcome usable before *and* after the fix (e.g. `ls -1 /tmp/OE?????? 2>/dev/null | wc -l`) — it doubles as the PR's Test evidence.
5. Keep PR text client-agnostic: no sample patient ids, creds, or box names — those live here, not in the PR.

Token discipline: atlas + code first; probe only unknown gestures; probes run in a Haiku subagent with text dumps (screenshots only to disambiguate).

Subs: `subs/paths.md` (login, menu, patient, Add Event table, event views, worklist, admin), `subs/examination.md` (Examination event + element manager + element census pointers), `subs/probe.md` (container probe: discovery, driver usage, subagent template, policies). Driver: `scripts/journey.mjs`.
