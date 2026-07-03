---
name: c-oe-repro
description: OpenEyes bug repro — a frontend click-path anyone can follow
disable-model-invocation: true
---

# OpenEyes steps to reproduce

When loaded as context with no task, reply only `Context loaded.` — and nothing else.

**With a task, this is your only job: produce the frontend Steps to Reproduce, then stop.** Drop every other thread — no code refactor, no DB-schema tour, no crawling the tree "to be sure". You are turning a known fault location into a click-path a stranger can follow, nothing more.

## Why you're here

The usual trigger: a PHP fix has just been made and you need to raise the ticket that tells release-notes readers *how the bug was experienced*, so they can check whether they hit it — or confirm it's gone in their version. So the inputs are normally already in this conversation:

- **Where** it breaks — a stack trace, an error, a controller/module, or the diff just written.
- **What** goes wrong — the one-line symptom.
- **The check** — the observable state that differs before vs after the fix (often already chosen).

If one is missing, ask for it — don't go hunting.

## Method — cheap, no schema, no tree crawl

OpenEyes is ~14k files; reading them to find the journey is the expensive mistake. You already know roughly where the fault is — two cheap sources turn that into a path:

1. **The map — `c-oe-nav`.** If it isn't already in context, load it by Reading `~/.claude/skills/c-oe-nav/SKILL.md` directly (the Skill tool errors on c-* skills — they are user-invocable only); same goes for `c-dblogin`/`c-oe-code` when needed. Its atlas has login, patient search, the Add Event dialog, event views, worklist and admin, plus the event-type → module table. Map the fault's controller/module to the screen that reaches it: a clinical event → patient ▸ 'Add Event' ▸ that event type; otherwise the main menu or admin.
2. **Exact labels — one grep, not a read.** `grep -n "<field words>\|Save\|Add" protected/modules/<Module>/views/**/form_*.php` on the fix branch. Never invent a label.

Still unknown after that? **Hand the walk to a cheap (Haiku) subagent** — a grep, or the `c-oe-nav` in-container probe — and ask only for the quoted labels back. Never spelunk in the main context.

## The rules — what makes steps followable

Write for someone who has never used the page and has *only these steps* (not the Description).

- **Frontend-only, numbered, one sentence per step, verb first.** A repro only rarely leaves the web UI (integration engine, IOLM); if it truly must, say so — otherwise every step is a browser action.
- **Start at login — step 1 is deterministically just "Log in."** ~98% of faults have nothing to do with who can do what, so don't caveat the login with a role or access level the bug doesn't turn on — no "as an administrator", no "(a user with full access)", no naming the actor at all. Under the hood a repro's clinical data-entry flow needs only a minimal role set (typically the 'User', 'View Clinical' and 'Edit' roles); the sample system user (usually `admin`) holds those plus everything else, so any working login reaches the flow — which is exactly why the step doesn't need to say so. Never name credentials or `admin/admin`. The one exception is an access fault, where the permission *is* the point — see *Permission-denied tickets*.
- **Name the exact control and where it sits.** Quote the on-screen label ('Add Event', 'Save', 'Single file'); for icon-only controls give appearance + position ("the 2-people 'User Changes' icon, top-right of the element"). "Go to a page with a sidebar" is not a step.
- **Spell out every choice and mark the free ones:** "choose any subspecialty and context", "search by surname, NHS number or hospital number (any will do)" — so the reader knows a choice exists and that any value works.
- **Reproducible in any instance.** No specific patient — never a hospital/NHS number, name, credentials, seed or sample-DB id. Actor by role, data by *kind* ("a multi-page PDF", "a patient with a recorded risk").
- **Plain language for any app user. No code, no internals.** Say "its page preview images are generated", not "the PDF is rasterised"; describe what the user does and sees, never the function, class or SQL behind it.
- **Self-contained.** Never "the above patient" or "see Description" — repeat inline whatever a step needs.
- **End on the observable fault, stated plainly** — what the reader sees that is wrong ("no detailed information is shown", "the [tuc] code does not appear"), usable before *and* after the fix. A bare server check is fine for a server-side effect (`ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l`) — stop at the command and say "on the server"; container names and cache clears go in the PR's *Notes for reviewer*, not here.
- **Only outcome-shaping parentheticals** ("(one file leaks per page)"); cut incidental detail.

## Worked example (PDF-preview temp-file leak)

> 1. Log in.
> 2. Search for any patient by surname, NHS number or hospital number (any will do) and open the record.
> 3. Click 'Add Event', choose any subspecialty and context, and select 'Document'.
> 4. Set any 'Event Sub Type', leave 'Single file' selected under 'Upload', attach a multi-page PDF (one file leaks per page), and click 'Save'.
> 5. Open the patient's lightning viewer (the lightning-bolt icon in the patient sidebar) and select the new event to build its page preview images.
> 6. Run `ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l` on the server before step 1 and again after step 5 — the count grows by one zero-byte `oe_pdfXXXXXX` stub per PDF page.

## Permission-denied tickets

Default to a plain "Log in." — **unless the fault itself is an access one** ("permission denied", a 403, a control wrongly hidden/shown, a role that can or can't do something). Then permissions *are* the point and the sample system user (which holds every role) would mask the bug, so the repro must run as a restricted user and spell the set-up out.

- **Get the permission from the fix, not the schema.** The check reads `Yii::app()->user->checkAccess('<Item>')` — operations are named `Oprn*` (e.g. `OprnEditClinical`), tasks `Task*`, with `admin` as the super-role; a denial surfaces as a 403 "You are not authorised…" or a control that's simply missing/greyed. The diff or stack trace already names the exact `<Item>` string — that's your cheapest source; grep the fix branch for `checkAccess(` only if it doesn't. (Table-level view — `authassignment`/`authitemchild` — is in `c-oe-db-schema`; you rarely need it.)
- **Reproduce as a restricted user, and say how to make one.** Since admin can do everything, the repro needs a user missing (or holding) that permission. Roles are assigned per user under **Admin ▸ Users** — editing a user toggles their roles, and each role grants a set of `Oprn*`/`Task*` items. Fold that into the steps as an explicit precondition so the reader lands on the right side of the check.
- **Then include the permission in the steps**, by role/operation, never a seed user — e.g. "1. Under 'Admin' ▸ 'Users', edit a user so their roles do *not* grant '<the operation>', and log in as them. … Observe '<the denial>' / the '<control>' is missing."

## When steps can't be clean

- **No user-observable behaviour** — a speed/performance improvement, a pure internal refactor, tooling or tech-debt. Nothing to click: **say so and omit the section** (Description + Solution carry the ticket). Don't invent a journey.
- **Client-specific data not in the sample DB** (common when the fix is for a data-shaped fault): the login, patient search and navigation are identical on every instance, so write *those* accurately; then state the data as a precondition ("for a patient who has …") and describe the fault as it *would* appear — flag that it won't reproduce on a clean sample DB.
- **Intermittent, or an alert that can surface on any page:** best endeavours — give the most precise trigger conditions known and say it is intermittent; never fake a deterministic path.

## After generating — verify in a frontend

Before the steps ship in release notes, offer to walk them in a running instance: the `c-oe-nav` probe drives the exact click-path in a Haiku subagent and reports whether the fault shows. For data-dependent or intermittent repros, at least confirm the navigation is real even if the fault itself can't be forced. A wrong step costs far more once it is in the release notes than now.

If the walk needs DB access — to pick a test patient, resolve the Add-Event `context_id`/`episode_id`, or read the fault's before/after state as proof — **load the `c-dblogin` skill first** (if it isn't already): it carries the exact login (client is `mariadb`, root password is in a file, not an env var) so you skip the usual `mysql`-vs-`mariadb` fumble. The probe's `subs/probe.md` lists the cheapest lookup queries.

Corpus of good/bad examples with margin notes: `~/good_steps_to_reproduce.txt`, `~/bad_steps_to_reproduce.txt`.
