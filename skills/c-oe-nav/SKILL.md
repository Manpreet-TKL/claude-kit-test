---
name: c-oe-nav
description: OpenEyes frontend click-paths — UI atlas + in-container probe
disable-model-invocation: true
---

# OpenEyes frontend navigation

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself — it just loads knowledge; act only on instructions given in the conversation.

For producing **an exact, human-followable click-path to anything in the OpenEyes frontend** at minimum token cost — bug-PR Steps to Reproduce (the flagship use), test instructions, user guidance, or any task that needs to know how the frontend hangs together. Most paths in the app are the same every time, so nearly every journey composes straight from the pre-recorded sources; probe only what's genuinely unknown. Three sources, in cost order; **never invent a label**:

1. **The atlas** (`subs/paths.md`, `subs/examination.md`) — pre-recorded navigation: login, main menu, patient search/summary, the full Add Event dialog, event views, worklist, admin. Free and always present; the app nav changes little between versions.
2. **The version-matched view code** — in-form field labels live in `protected/modules/<Module>/views/**/form_*.php`, menus in module `config/common.php`, event-type names in `event_type` seeds. Read the checkout matching the target version — for a bug PR that's the fix branch, so it's version-matched by construction.
3. **The live probe** (`subs/probe.md`) — a cheap subagent drives a running sample stack **inside its own web container**: `docker exec` runs `scripts/journey.mjs` on the Puppeteer + Chrome the web-live image already ships (no extra container, nothing installed). One logged-in driver walks gestures, captures JS-rendered labels, and fires endpoints for proof; it returns distilled, quoted labels. For gestures the atlas doesn't record (in-form behaviour, print/upload/search dialogs) and for proof.

## The spine

Login `/site/login` (Username/Password + Institution/Site) → landing = patient search → patient summary `/patient/summary/:id` ("Patient Overview", 'Add Event' `#add-event`) → Add Event dialog (Subspecialty ▸ Context ▸ 'Select New Event') → create form (`#et_save`) → event view `/<Module>/default/view/:id` (icon row top right: print/edit/delete) → main menu (shortcuts icon) for everything else → Admin `/admin` (~30 alphabetical sections, module-prefixed routes; full list in the atlas). Worklist `/worklist/view` is a single-URL panel app. **Roughly 40% of the app sits behind the patient summary's 'Add Event' button** — all clinical event types' create → view → edit — so when a goal touches clinical data entry, the path almost always starts patient → 'Add Event'; the main menu and admin cover most of the rest. Never wait for network-idle; list rows and add-event items open via JS, not hrefs.

## Writing steps (repro, test, or guidance)

1. Map the goal → user gesture: for a bug, which controller action runs the broken code and which route/view reaches it; for any other goal, which screen shows the outcome (atlas table has all 23 event ids/modules).
2. Compose numbered steps from the atlas; pull exact field labels from the fix branch's views. **One imperative sentence per step, leading with the verb** — collapse trivial navigation (log in → search → click the row to open the record = one step), don't split it into a click per line. Quote on-screen words exactly ('Add Event', 'Single file', 'Save'); don't narrate what the reader plainly sees (the post-login landing screen, a page just loading). Keep only parentheticals that change the outcome — free choices ("any subspecialty and context") and preconditions stated with their why ("one file leaks per page"; "a PDF newer than v1.4 — most modern PDFs are v1.5–1.7") — and cut incidental caps, versions and alternate trigger paths.
3. Anything unverified or invisible in code → probe it (subagent, not main context).
4. End on an **observable outcome**: for a bug PR an observable predicate — a literal command or on-screen state usable before *and* after the fix (e.g. `ls -1 /tmp/OE?????? 2>/dev/null | wc -l`), doubling as the PR's Test evidence; for other goals, the visible state that confirms success.
5. Keep deliverable text client-agnostic: no sample patient ids, creds, or box names — those live here, not in PRs/tickets/guides.

Token discipline: atlas + code first; probe only unknown gestures; probes run in a Haiku subagent inside the web container with text dumps (screenshots only to disambiguate).

Subs: `subs/paths.md` (login, menu, patient, Add Event table, event views, worklist, admin), `subs/examination.md` (Examination event + element manager + element census pointers), `subs/probe.md` (in-container Puppeteer probe: discovery, driver, endpoints-for-proof, subagent template, policies). Load `subs/probe-playwright.md` only for images without the bundled Puppeteer/Chrome (dev/debug images carry Playwright; remote-chrome stacks) or when a Playwright run is explicitly requested. Drivers: `scripts/journey.mjs` (Puppeteer, primary), `scripts/journey.playwright.mjs` (fallback).
