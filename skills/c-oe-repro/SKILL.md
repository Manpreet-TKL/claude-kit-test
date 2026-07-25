---
name: c-oe-repro
description: OpenEyes bug repro - discover and document a deterministic click-path
disable-model-invocation: false
---

# OpenEyes steps to reproduce

When loaded as context with no task, reply only `Context loaded.` - and nothing else.

**With a task, this is your only job: produce the Steps to Reproduce, then stop.** Drop every other thread - no code refactor, no DB-schema tour, no crawling the tree "to be sure". You are turning a fault into a click-path a stranger can follow, nothing more.

## Two modes - pick one from the input

| Mode | Input | Output | Where it sits |
|---|---|---|---|
| **Document** | a *known* fault - stack trace, controller/module, or the diff just written | the click-path that fault is experienced through | after the code work, feeding `create-oe-pr` |
| **Discover** | a *reported symptom* - "X doesn't work for a user at Y" | a **proven** deterministic click-path plus its evidence | at the front, before anyone reads code |

**Document** is the usual trigger: a PHP fix has just been made and the ticket must tell release-notes readers *how the bug was experienced*, so they can check whether they hit it. Its three inputs are normally already in the conversation - **where** it breaks, **what** goes wrong, and **the check** that differs before vs after the fix. If one is missing, ask for it; don't go hunting.

**Discover** starts with nothing but a symptom and has to *earn* the steps. Read **`subs/discovery.md`** before walking anything: it carries the loop, the full cost ladder, the R1/R2 acceptance bar, the write policy and the subagent briefs.

## Method - cheap, no schema, no tree crawl

OpenEyes is ~14k files; reading them to find the journey is the expensive mistake.

1. **The map - `c-oe-nav`.** Load it with the Skill tool if it isn't in context (same for `c-dblogin`/`c-oe-code` when needed). Its atlas has login, patient search, the Add Event dialog, event views, worklist and admin, plus the event-type -> module table; `subs/page-index.md` (grep, never read) has every one of the 390 pages' exact address. Map the fault's controller/module to the screen that reaches it: a clinical event -> patient > 'Add Event' > that event type; otherwise the main menu or admin.
2. **Exact labels - one grep, not a read.** `grep -n "<field words>\|Save\|Add" protected/modules/<Module>/views/**/form_*.php` on the fix branch. Never invent a label.
3. **Already walked?** `ls ~/claude-kit/skills/c-oe-nav/subs/canned/` - one file per journey, each with a bug ledger. A repeat repro is a replay, not a rediscovery.

Still unknown after that? **Hand the walk to a cheap (Haiku) subagent** and ask only for the quoted labels back. Never spelunk in the main context.

## Cost ladder - climb only as far as you must

| Rung | Cost | Use when |
|---|---|---|
| **0. Decode + grep, no browser** | ~0 | The report quotes a support identifier, or names screen + action + expected/actual. **Most reports** - see `subs/logs.md` for `decodesupportid`, which returns file:line *and* the reporter's user/firm/site/institution/patient ids. |
| **1. Haiku + `journey.mjs`, log-bracketed** | ~3k main / ~30k sub | The click path is derivable offline from the atlas. **Every confirmation replay lives here, always.** `c-oe-nav/subs/probe.md`. |
| **2. `oe-probe-playwright`** | same | Rung 1's image has no bundled Puppeteer. Mechanical fallback. |
| **3. `oe-probe-chrome` skill** | 10-50x (~$5, ~60 turns) | The path *cannot* be derived: gesture-dependent (drag, EyeDraw canvas, hover-only control, autosave modal), the report is too vague to script, a human wants to watch, or a GIF is the evidence. |

> **Chrome discovers the path. Puppeteer proves it. Confirmation replays never run in Chrome.**

Enter rung 3 by invoking the **`oe-probe-chrome`** skill, which owns `drive.sh` - never by hand-rolling a `docker exec` into the container. Scope that session to one job (find and narrate the click path), then immediately distil it into `c-oe-nav/subs/canned/<journey>.md` so every later run of the journey is rung 1.

## The rules - what makes steps followable

Write for someone who has never used the page and has *only these steps* (not the Description). They apply to **both** blockquotes.

- **Frontend-only, numbered, one sentence per step, verb first.** A repro only rarely leaves the web UI (integration engine, IOLM); if it truly must, say so - otherwise every step is a browser action.
- **No container names, paths or CLI in either blockquote.** Those go in Evidence or the PR's *Notes for Reviewers*. The one exception is a server-side check as the closing observable (below).
- **Start at login - step 1 is deterministically just "Log in."** ~98% of faults have nothing to do with who can do what, so don't caveat the login with a role or access level the bug doesn't turn on - no "as an administrator", no "(a user with full access)", no naming the actor at all. Under the hood a repro's clinical data-entry flow needs only a minimal role set (typically the 'User', 'View Clinical' and 'Edit' roles); the sample system user (usually `admin`) holds those plus everything else, so any working login reaches the flow - which is exactly why the step doesn't need to say so. Never name credentials or `admin/admin`. The one exception is an access fault, where the permission *is* the point - see `subs/edge-cases.md`.
- **Name the exact control and where it sits.** Quote the on-screen label ('Add Event', 'Save', 'Single file'); for icon-only controls give appearance + position ("the 2-people 'User Changes' icon, top-right of the element"). "Go to a page with a sidebar" is not a step.
- **Spell out every choice and mark the free ones:** "choose any subspecialty and context", "search by surname, NHS number or hospital number (any will do)" - so the reader knows a choice exists and that any value works. A choice that turns out *not* to be free is a precondition, and moves to the Environment setup block.
- **Reproducible in any instance.** No specific patient - never a hospital/NHS number, name, credentials, seed or sample-DB id. Actor by role, data by *kind* ("a multi-page PDF", "a patient with a recorded risk").
- **Plain language for any app user. No code, no internals.** Say "its page preview images are generated", not "the PDF is rasterised"; describe what the user does and sees, never the function, class or SQL behind it.
- **Self-contained.** Never "the above patient" or "see Description" - repeat inline whatever a step needs.
- **End on the observable fault, stated plainly** - what the reader sees that is wrong ("no detailed information is shown", "the [tuc] code does not appear"), usable before *and* after the fix. A bare server check is fine for a server-side effect (`ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l`) - stop at the command and say "on the server".
- **Only outcome-shaping parentheticals** ("(one file leaks per page)"); cut incidental detail.

## The output contract - up to two blockquotes

**Environment setup** - one-off configuration a stock sample database lacks. **Omit the block entirely when nothing is needed** (the common case), leaving output byte-identical to the single-block shape `create-oe-pr` already consumes. Skip anything the instance already has. Always admin-UI click steps, never a `yiic` line - `subs/env-setup.md`.

> 1. Under 'Admin' > 'Sites', click 'Add' and create a second site with any name and code.
> 2. Under 'Admin' > 'Users', edit any user, add that site to their 'Sites' and click 'Save'.

**Steps to Reproduce** - what to do once those conditions hold. The two are separate because a developer configures their sample database once and then follows the repro; conflating them makes the repro look non-deterministic.

> 1. Log in.
> 2. Search for any patient by surname, NHS number or hospital number (any will do) and open the record.
> 3. Click 'Add Event', choose any subspecialty and context, and select 'Document'.
> 4. Set any 'Event Sub Type', leave 'Single file' selected under 'Upload', attach a multi-page PDF (one file leaks per page), and click 'Save'.
> 5. Open the patient's lightning viewer (the lightning-bolt icon in the patient sidebar) and select the new event to build its page preview images.
> 6. Run `ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l` on the server before step 1 and again after step 5 - the count grows by one zero-byte `oe_pdfXXXXXX` stub per PDF page.

**Evidence** - plain text below the blocks, for the human. **Not a paste target**; it never goes in the ticket description.

- Verified on: `<version>`, R1 pass, R2 pass (varied: `<what>`).
- Predicate: `<the one command or DOM read>`, value before vs after the trigger step.
- Support identifier: `<id>` -> `<file>:<line>`.
- Log slice: `~/repro-evidence/<date>-<slug>/` - attach these files to the ticket.

Blockquote = paste target, plain text = for the human, matching `create-oe-pr`'s own convention.

## Subs

- **`subs/discovery.md`** - the discovery loop, the rung 0-3 decision rule in full, the R1/R2 determinism bar, the write policy, and the two subagent briefs (Haiku bracketed walk; Chrome path-finding).
- **`subs/logs.md`** - `decodesupportid`, the verified log inventory per image, the before/after bracket one-liners and their fragilities, the audit bracket, the PII rule and the evidence-bundle layout. **Read this before claiming a walk produced no log signature.**
- **`subs/env-setup.md`** - the three kinds of environment gap, admin-UI-not-CLI and its one exception, the lever -> admin-route pointers, and how to probe an undocumented admin form.
- **`subs/edge-cases.md`** - permission-denied tickets, and when steps genuinely can't be clean (no user-observable behaviour, client-only data, intermittent).

If a walk needs DB access - to pick a test patient, resolve the Add-Event `context_id`/`episode_id`, or read before/after state as proof - **load `c-dblogin` first**: it carries the exact login (client is `mariadb`, root password is in a file, not an env var) so you skip the usual fumble.
