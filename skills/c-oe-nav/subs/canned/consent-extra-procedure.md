# Canned walk - consent form -> add an extra procedure

Journey: open a new Consent form event, put content in the 'Intended benefits' and
'Material risks' rich-text boxes, then add a procedure through the 'Extra Procedures'
adder. Walked live via the Claude in Chrome extension (`docker/oe-chrome-agent/drive.sh`,
see `docs/chrome-agent.md`) on OE 1.1.33-dev (2026-07-25) across three driven stages,
~99 turns / ~$4.71 total - two of which were spent on a form that could not exercise the
path at all. Read the preconditions below before spending anything.

Parameters: `<web>` = OE URL, `<stack>` = compose project. `event_type_id=32` is Consent
form on this DB - confirm on another with
`SELECT id FROM event_type WHERE class_name='OphTrConsent'`.

## This journey must run in Chrome, and that is not laziness

The observable is **TinyMCE editor state**, not DOM text. `journey.mjs`'s `read` returns
text only, and TinyMCE renders into an iframe - a rung-1 probe can neither type into the
boxes nor read `tinymce.get(id).getContent()` back out. This is one of the few OE
journeys where rung 3 is the floor rather than the ceiling.

Predicate, run as JS in the walk:

```
['benefits','risks'].map(function(k){var id='Element_OphTrConsent_BenefitsAndRisks_'+k;var e=window.tinymce&&tinymce.get(id);return k+' | editor='+JSON.stringify(e?e.getContent():'NO_EDITOR');}).join(' ||| ')
```

## Two preconditions, both easy to miss

**1. The procedure must not already be on the form.**
`views/default/procedure_selection.php:62-66` opens the `selected_procedures.forEach`
with an early return:

```php
if ($(`input[<?= $proc_hidden_input_identifier ?>][value=${proc.id}]`).length && proc.id !== -1) {
    return;
}
```

so `callbackAddProcedure()` is never reached for a procedure the form already carries.
The stock sample DB has exactly **one** row in `ophtrconsent_procedure_extra` ("Anterior
vitrectomy if required"), so any consent event that already has it is a dead end - the
adder is a visible no-op. Two full Chrome walks were burned on event 3686998 for exactly
this reason. **Always start from a fresh Consent form**, which carries no extra procedure.

**2. The rich-text content must be paragraph-shaped, not a bullet list.**
`assets/js/module.js:434 handleTinyMCEInput()` rebuilds the editor from its own `<li>`
children and `setContent()`s a `<ul>` over the top. A bullet list survives (its items are
re-emitted); a `<p>` does not exist as far as that function is concerned and is dropped.

## Procedure

1. Go to
   `<web>/patientEvent/create?patient_id=<pid>&event_type_id=32&context_id=<ctx>&episode_id=<ep>`
   (both `context_id` and `episode_id` are required, or it 400s "Episode/Context
   mismatch"). Set 'Type' to 'Patient agreement' if the rest of the form is gated on it.
2. Select all in 'Intended benefits' and in 'Material risks' and replace each with one
   plain sentence containing no bullet points. Click outside the box to commit.
3. Run the predicate - **READING A**. It must show `<p>` and no `<li>`, or the walk is
   meaningless.
4. In 'Extra Procedures', click the adder (`#js-add-extra-proc-btn`), pick 'Anterior
   vitrectomy if required', confirm.
5. Wait 5s (the content-replacing code runs in an AJAX `success` callback), run the
   predicate again - **READING B**.

Nothing needs saving; the whole fault is client-side.

Driver: `./drive.sh -f subs/canned/consent-extra-procedure.md -t consent-extra "Follow the procedure and report READING A and READING B. Do this now with tool calls, do not answer from memory."`

Finding a patient/episode/context triple:

```
docker exec <stack>-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -N openeyes -e "SELECT patient_id, id, firm_id FROM episode WHERE deleted=0 AND firm_id IS NOT NULL ORDER BY id DESC LIMIT 5"'
```

## Bug ledger

**1. Adding an extra procedure wipes paragraph-shaped 'Intended benefits' and 'Material
risks' content** (confirmed 2026-07-25, 1.1.33-dev; register entry BUG-037).

- **Predicate:** READING A `benefits | editor="<p>Benefits paragraph text here.</p>" |||
  risks | editor="<p>Risks paragraph text here.</p>"` -> READING B
  `benefits | editor="" ||| risks | editor=""`. Both boxes are visibly empty on screen.
- **R1** (patient 17891, episode 601038, context 13) and **R2** (patient 19382, episode
  601050, context 5) returned that pair byte-identical. Both pass - the patient, episode
  and context are free choices.
- **Mechanism:** `callbackAddProcedure()` (`module.js:469`) fires GETs to
  `/OphTrConsent/default/benefits/<id>` and `/OphTrConsent/default/complications/<id>`,
  and calls `handleTinyMCEInput()` from each `success` callback.
  `extra_procedure_benefit` and `extra_procedure_complication` are both **empty** on the
  sample DB, so `data = []`; with no `<li>` to harvest either, `final_items` is empty and
  the editors are set to `<ul></ul>`, which TinyMCE normalises to `""`. A form whose boxes
  hold a bullet list loses nothing, which is why the fault looks intermittent.
- **No server signature, by construction** - the wipe is pure client-side JS and never
  reaches PHP. `application.log` carried only unrelated "Failed to set unsafe attribute"
  mass-assignment warnings from rendering the consent form, and no new exception log
  appeared. Exactly the silent-fault case `c-oe-repro/subs/logs.md` warns about: the
  bracket was never going to fire and the JS predicate is the entire oracle.
- **Not confirmed:** the register's claim that the underlying `<textarea>.value` survives
  and that Save is then rejected with "Benefits and risks ... cannot be blank". Neither
  walk saved, and the textarea half was only read on the earlier no-op walks. Re-read
  `textarea=` alongside `editor=` and click Save if that half of the report matters.
