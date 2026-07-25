# Environment setup - the block before the steps

The sample database is deliberately small. A client symptom often needs a configuration it lacks - a second site, an extra role, an enabled event type, a lookup row. That configuration is **not** part of the repro: a developer sets it up once to match the reporter's instance, and *then* follows the steps. Keeping them in one list makes a deterministic repro look flaky.

So the deliverable is up to two blockquotes (`SKILL.md`). **Omit the setup block entirely when nothing is needed** - which is the common case, and the reason `create-oe-pr` still consumes the output unchanged.

## Three kinds of gap, three homes

| Gap | Examples | Where it goes |
|---|---|---|
| **Configuration** | institution / site / firm / subspecialty, a role assignment, an enabled event type, a lookup row, a custom menu item | **Environment setup block** - admin-UI steps |
| **Clinical data shape** | "a patient with a prior injection series", "a patient with a recorded risk", "a multi-page PDF" | **Environment setup block** if it is creatable through the UI; otherwise state it in the step as a data *kind* ("for a patient who has ...") |
| **Deployment / infra** | an integration channel, a cron job, a feature env var, a module switch in `<module>/config/common.php` | **Notes for Reviewers** on the PR - never the setup block, because it is not something a user clicks |

If you cannot tell configuration from data shape: configuration is what an administrator sets and every patient then inherits; data shape is what one patient happens to have.

## Admin UI, not CLI

**The shipped setup block is always admin-UI click steps.** Every rule from `SKILL.md` applies to it - verb first, one sentence, exact quoted labels, no sample-DB ids, no credentials, no container names or paths.

You may use a seeder or a factory **during discovery** to reach a state fast. `protected/seeders/` is driven by `./yiic seeder --event_type=... --seeder_class=...` (see `c-oe-code/subs/cli-jobs.md`), and it is fine as a shortcut for *you*. It is not the deliverable, for two reasons: the seeders are Cypress-scoped scenario builders rather than a documented setup path, and a worked invocation is made of exactly the sample-DB ids the output is forbidden to contain (`--firm_id=297 --institution_id=1 --patient_id=17895`). Having used one, write the equivalent UI steps and **verify them once on rung 1** before shipping them.

**The one exception:** a state genuinely unreachable through the UI. Say so plainly, give the CLI line, and label it as the exception - don't quietly pass a `yiic` command off as a user step.

## Levers and where they live

Routes from `c-oe-nav/subs/page-index.md` (`grep '^| admin/core' subs/page-index.md` for the rest of that section):

| Lever | Admin route | Reached by |
|---|---|---|
| Sites | `/admin/sites` | Menu > Admin / Core > Sites; a row opens `admin/editsite?site_id=ID` |
| Users, and their roles | `/admin/users` | Menu > Admin / Core > Users; a row opens `admin/editUser/ID`, where roles are toggled |
| Institutions | `/admin/institutions` | Menu > Admin / Core > Institutions |
| Firms / contexts | `/Admin/context/index` | Menu > Admin / Core > Contexts and Services |
| Subspecialties | `/Admin/Settings/subspecialty/index` | Menu > Admin / Core > Subspecialty |
| Event type custom text | `/admin/editEventTypeCustomText` | Menu > Admin / Core > Event Type Custom Text |
| Teams | `/oeadmin/team/list` | Menu > Admin / Core > Teams |

Roles are **per user**, not a standalone screen: editing a user toggles their roles, and each role grants a set of `Oprn*`/`Task*` items. For access faults specifically, see `subs/edge-cases.md`.

## The documentation gap - and how to close it

`c-oe-nav/subs/admin-forms.md` documents the admin **list** screens. The create/edit forms behind their rows are not covered, and `subs/page-index.md` has no rows for them either (verified: zero hits for `addInstitution`, `editinstitution`, `editUser`). The list-screen entries do record the row's target URI, which is the thread to pull.

So the first time a lever is actually needed, the form behind it has to be probed:

1. Get the edit URI from `admin-forms.md`'s entry for the list screen (e.g. `admin/editsite?site_id=ID`), or from the list page's own row markup.
2. Walk it on rung 1 - a Haiku subagent with `journey.mjs`, `{"goto":"/admin/editsite?site_id=1"}` then `{"dump":true}` - and bring back the quoted labels and required-ness.
3. **Can the result in the existing catalogue**: `c-oe-nav/subs/canned/setup-<lever>.md`, indexed in `c-oe-nav/SKILL.md` like any other journey. Do **not** start a second catalogue inside `c-oe-repro` - the next bug on a different journey needs the same file.

## Worked example

Symptom: a user at a multi-site trust sees no 'Site' selector on the login form. The stock sample instance has one site, so the selector is suppressed and nothing reproduces.

**Environment setup**

> 1. Under 'Admin' > 'Sites', click 'Add' and create a second site with any name and short code.
> 2. Under 'Admin' > 'Users', open any user, add both sites under 'Sites', and click 'Save'.

**Steps to Reproduce**

> 1. Open the login page.
> 2. Enter a valid username and password.
> 3. Observe that the 'Site' list shows only one entry.

Note what the two blocks each did. The setup block created a *precondition* - a fact about the instance. The steps never mention how many sites exist, because by the time they run it is already true. That separation is also what makes R2 meaningful: varying which site the user is given must not change the outcome, or the second site was never the real precondition (`subs/discovery.md`).
