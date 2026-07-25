# Canned walk - patient with a prior injection series -> repeat the series

Journey: open a patient who already has an intravitreal injection course, add an
Examination in the matching clinic context, bring in the Injection Management element,
and repeat the series for one eye. Walked live via the Claude in Chrome extension
(`docker/oe-chrome-agent/drive.sh`, see `docs/chrome-agent.md`) on OE 1.1.33-dev (snail,
2026-07-23): discovery (patient search + full walk + report) ran ~64 turns / ~$4.85
across 7 driven stages; a replay against a known-good patient with the spine below should
be a single low-turn stage.

Parameters: `<web>` = OE URL (`OE_URL` in the chrome-agent env). Sample patient on the
snail DB: **Marilyn Monroe**, ID 1897143, NHS 446 257 6373, record
`/patient/summary/2098503` - Medical Retina episode (Branch retinal vein occlusion with
macular oedema), a 12-injection Lucentis course, most recent injection 5 May 2015. If
unavailable on a different sample DB, use Find Patient to locate any patient with an
existing Intravitreal injection + Examination event pairing, and confirm the pairing via
the episode/event list before proceeding - don't assume a name carries across DBs.

**Code path, now pinned** (2026-07-25) - the trigger button is
`protected/modules/OphCiExamination/widgets/views/_injection_management_action_buttons.php`
(`id="<eye_side>_continue_injections_<sequence_number>"`), and the adder's Start column is
built in `.../views/InjectionManagement_event_edit_side.php` as an
`OpenEyes.UI.AdderDialog.ItemSet` with `id: '<eye_side>-start-options'`, fed by
`InjectionManagement::getPatientStartOptions()` -> `formatStartOption()`, which reads
`OphCiExamination_Injection_Start_Options` rows and their `year_inc`/`month_inc`/`day_inc`
offsets. **There is no date input by construction** - so ledger item 1's "no date control"
half is provable from code with no browser at all. Re-grep those two files on a newer
version to see whether a date field has since been added.

## Rung 1 replay (cheapest - use this unless a human needs to watch)

Verified end to end on snail 1.1.33-dev, 2026-07-25, via `c-oe-nav/subs/probe.md`'s
`journey.mjs`. Substitute `<pid>` / `<ep>` from any patient with a prior injection series
(`SELECT` in the note below), and `<ctx>` = that episode's `firm_id`. `event_type_id=27`
is Examination on the snail DB - confirm on another.

```
docker exec -i -e OE_ACTIONS='[{"goto":"/patientEvent/create?patient_id=<pid>&event_type_id=27&context_id=<ctx>&episode_id=<ep>"},{"click":"text=\"Manage Elements\""},{"wait":2000},{"click":"[data-test=\"manage-elements-Injection-Management\"]"},{"wait":1500},{"click":"[data-test=\"manage-elements-close-btn\"]"},{"wait":2000},{"click":"[id*=\"continue_injections\"]"},{"wait":2500},{"read":"ul[data-id=\"left-start-options\"], ul[data-id=\"right-start-options\"]"}]' -w /var/www/openeyes <web> node --input-type=module - < scripts/journey.mjs
```

Three selector facts that cost the walk several attempts, all load-bearing:

- **`text="Injection Management"` does not click.** It resolves to a text node, and
  `journey.mjs` fails with `Node is either not clickable or not an Element`. Every element
  in the manager carries `data-test=manage-elements-<name with ()/&and spaces -> ->`
  (`OpenEyes.UI.ManageElements.js`, `buildTreeChildList`) - use that. `text="Manage
  Elements"` itself is fine, because that one is a `<div>`.
- **The create URL needs both `context_id` and `episode_id`**, or it 400s with
  "Episode/Context mismatch".
- **Read the panel as `.oe-element-selector`** to list every available element; `.sidebar`
  returns the unrelated patient event list, and `#js-add-select-search-elements` does not
  exist on this version.

Finding a second patient for an R2 variation replay (see `c-oe-repro/subs/discovery.md`):

```
docker exec <stack>-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -N openeyes -e "SELECT ep.patient_id, ep.id, ep.firm_id, COUNT(*) c FROM event ev JOIN episode ep ON ep.id=ev.episode_id JOIN event_type et ON et.id=ev.event_type_id WHERE et.class_name=\"OphTrIntravitrealinjection\" AND ev.deleted=0 GROUP BY ep.id HAVING c>=3 ORDER BY c DESC LIMIT 5"'
```

## Rung 3 discovery walk (the original)

Procedure (drive via the Claude in Chrome extension - browser_batch clicks + JS reads;
labels are exact, on-screen text):

1. If no OE tab is already open (a fresh `drive.sh` session always starts on a blank
   tab - it cannot read `OE_URL` itself), navigate to `<web>` first. Then Find Patient
   search "Monroe", open Marilyn Monroe's record (or the re-picked candidate). Confirm
   the Medical Retina episode's event list shows the existing Examination + Intravitreal
   injection pairs before continuing.
2. Click **Add Event**, choose **Context** = "MR Clinic" (Medical Retina), then select
   **Examination** as the new event type. Do not choose a subspecialty/context that
   doesn't carry an injection-eligible diagnosis.
3. On the Examination create form, open **Manage Elements** and add **Injection
   Management** (Clinical Management group). This is a non-destructive toggle - do not
   click Save/Confirm at any point in this walk.
4. In the Injection Management element, for the eye with the active series, click
   **Repeat Lucentis Injections** (label follows the patient's current drug - it won't
   always read "Lucentis").
5. Read the regime-builder row directly from the DOM (don't eyeball highlight colour) -
   which of Drug, Regimes, Injections (count), IOP lowering, Interval, Start, Follow-up,
   Numbering, Consent are pre-selected vs empty. Screenshot for evidence only if a value
   is ambiguous from the DOM read.
6. Click **Cancel**, then **Cancel** again to raise the "Discard auto-saved restore
   point?" modal, then **Cancel and discard**. Confirm the Drafts counter reads 0 and the
   patient's event timeline is unchanged from step 1 - nothing gets saved by this walk.

Drivers: `./drive.sh -f subs/canned/injection-repeat-series.md -t injection-replay "Open <web> (e.g. http://snail-web-1), then re-run the regime-builder step (4-5) and report which of Drug/Regimes/Injections/IOP-lowering/Interval/Start/Follow-up/Numbering/Consent are pre-filled vs empty."`

## Bug ledger

**1. Regime-builder pre-fills drug + numbering but drops the rest, and has no date
input at all** (found 2026-07-23, snail 1.1.33-dev). Clicking "Repeat Lucentis
Injections" pre-selects **Drug** ("Lucentis", carried from the existing course) and
**IOP lowering** ("Not required") and auto-advances **Numbering** ("Automatic #13"), but
leaves **Regimes**, **Injections** (count), **Interval**, **Start**, **Follow-up**, and
**Consent** all unselected. **Start** has no date-input control in the DOM at all - only
relative-offset buttons (Today / Urgent / In 1 Week / In 2 Weeks / In 3 Weeks / In 4
Weeks / In 6 Weeks / In 2 Months / In 3 Months), so there is no way to set an explicit
start date from this control. Screenshot evidence from the discovery run:
`artifacts/repeat-series.jpg` (host-only, not committed - regenerate per walk).

**Replay note (2026-07-23, same day, same patient/DB state):** a same-day map replay
found **Interval** pre-filled ("4 weekly") where the discovery run recorded it as empty -
Drug/IOP lowering/Numbering and the empty Regimes/Injections/Follow-up/Consent/Start all
matched. Not yet reconciled - could be a discovery-run miss or genuinely non-deterministic
pre-fill; the core finding (no date-input control for Start) held on both runs. Re-check
Interval specifically on the next walk of this journey.

**Rung 1 confirmation (2026-07-25, snail 1.1.33-dev).** Replayed twice on the spine above,
with the log bracket from `c-oe-repro/subs/logs.md` around it.

- **Predicate:** `ul[data-id="left-start-options"]` reads exactly
  `Today / Urgent / In 1 Week / In 2 Weeks / In 3 Weeks / In 4 Weeks / In 6 Weeks /
  In 2 Months / In 3 Months`, and a read of
  `#left-start-injection-series input[type=date], ... input.date, ... input[name*=date]`
  finds no node. So the Start column offers nine relative offsets and no date control.
- **R1** (patient 2098503, episode 416523) and **R2** (patient 1999377, episode 169473,
  a different Lucentis course) returned that predicate value **byte-identical**. Both pass;
  the patient is a free choice, not a precondition.
- **Bracket clean** - zero `[error]`/`[warning]` lines in the slice, no exception JSON,
  `application.log` grew 303592 -> 306625 so it had not rotated. Exactly the case the
  caveat in `subs/logs.md` is about: this is a silent rendering-class fault, the bracket
  was never going to fire, and the DOM predicate is the whole oracle.

**What rung 1 does *not* settle:** the pre-fill half of item 1 (which of Drug / Regimes /
Injections / IOP lowering / Interval / Follow-up / Numbering / Consent arrive selected).
`journey.mjs`'s `read` returns text, and every option in those columns renders its label
whether selected or not - so a text read cannot distinguish them and the 2026-07-23
Interval discrepancy above stays open. Settling it needs a class/attribute read, i.e.
rung 3 or an added `journey.mjs` action; do not report the pre-fill list from a text read.
