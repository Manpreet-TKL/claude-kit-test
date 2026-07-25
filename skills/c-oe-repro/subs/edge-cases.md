# Edge cases - permission faults, and when steps can't be clean

## Permission-denied tickets

Default to a plain "Log in." - **unless the fault itself is an access one** ("permission denied", a 403, a control wrongly hidden/shown, a role that can or can't do something). Then permissions *are* the point and the sample system user (which holds every role) would mask the bug, so the repro must run as a restricted user and spell the set-up out.

- **Get the permission from the fix, not the schema.** The check reads `Yii::app()->user->checkAccess('<Item>')` - operations are named `Oprn*` (e.g. `OprnEditClinical`), tasks `Task*`, with `admin` as the super-role; a denial surfaces as a 403 "You are not authorised..." or a control that's simply missing/greyed. The diff or stack trace already names the exact `<Item>` string - that's your cheapest source; grep the fix branch for `checkAccess(` only if it doesn't. (Table-level view - `authassignment`/`authitemchild` - is in `c-oe-db-schema`; you rarely need it.)
- **Reproduce as a restricted user, and say how to make one.** Since admin can do everything, the repro needs a user missing (or holding) that permission. Roles are assigned per user under **Admin > Users** - editing a user toggles their roles, and each role grants a set of `Oprn*`/`Task*` items.
- **The role change is a precondition, so it belongs in the Environment setup block**, not step 1 of the repro - see `subs/env-setup.md`. Name it by role/operation, never by seed user:

> 1. Under 'Admin' > 'Users', open any user, clear the roles that grant '<the operation>', and click 'Save'.

> 1. Log in as that user.
> 2. ... 
> 3. Observe '<the denial>' / that the '<control>' is missing.

- **R2 on an access fault varies the *user*, not the role.** A second restricted user must hit the same denial; if it doesn't, something else about the first user was load-bearing and you haven't found the precondition yet.

## When steps can't be clean

- **No user-observable behaviour** - a speed/performance improvement, a pure internal refactor, tooling or tech-debt. Nothing to click: **say so and omit the section** (Description + Solution carry the ticket). Don't invent a journey.
- **Client-specific data not in the sample DB** (common when the fix is for a data-shaped fault). First ask whether the gap is closeable: `subs/env-setup.md` exists precisely because a lot of "client-only" states turn out to be one admin screen away, and closing it converts an unprovable repro into an R1/R2 pass. If it genuinely isn't closeable - the data arrives from an integration, or a real clinical history you cannot construct - then the login, patient search and navigation are identical on every instance, so write *those* accurately; state the data as a precondition ("for a patient who has ..."); describe the fault as it *would* appear; and flag that it won't reproduce on a clean sample DB.
- **Intermittent, or an alert that can surface on any page:** best endeavours - give the most precise trigger conditions known and say it is intermittent; never fake a deterministic path. An intermittent fault fails the R1/R2 bar by definition, so say that in the Evidence block rather than claiming a pass.

In all three, the honest statement beats a fabricated path. A wrong step costs far more once it is in the release notes than it does now.
