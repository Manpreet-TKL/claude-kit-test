# OpenEyes develop frontend bug hunt - 2026-07-29

Environment: snail (local oe-deploy dev stack), OpenEyes develop @ 04c938c0a4 (OE-18003, 2026-07-29), fresh sample DB, migrated up. Web image `oe-web-dev:php8.4-noble` (Apache prefork + mod_php 8.4, xdebug on, YII_DEBUG on - findings verified against user-observable behaviour, not dev-mode cosmetics).
Method: parallel scripted walkers (Playwright in-container) running event-create gauntlets + static code sweep feeding targeted repros + Claude-in-Chrome gesture walks. Verification bar: every VERIFIED bug was independently replayed by a second agent on a different patient from a fresh browser (R1), under a two-sided pass rule (exact predicate observed AND no harness-artifact signature in the verifier's log bracket). The session hit its usage limit at ~15:40 local, killing 10 of 14 gauntlet slices - stated here rather than papered over; that coverage is absent, not clean. After the limit reset, a closing verification-only wave ran the planned R2 pass (varied free choices, a third agent on a third patient, for the HIGH-severity bugs) plus R1 replays for the outstanding candidates. No new bug hunting was done in that wave.

## Verified bugs

Nine bugs. Each was found by one agent and independently replayed by a different agent on a different patient from a fresh browser (R1); the three HIGH-severity ones were replayed a third time by a third agent with every free choice varied (R2). Certainty stamp per bug.

### BUG-01: DNA sample - non-numeric Volume crashes Save with an unhandled DB exception (HIGH, crash) [R1+R2]

Typing a non-numeric value into 'Volume (Millilitres)' passes the module's custom `volume_validator` (loose `<= 0` / `> 99` comparisons that are false for strings under PHP 8) and goes straight to the INSERT, which dies under STRICT_TRANS_TABLES with CDbCommand error 1265 'Data truncated for column volume'. The user gets a raw exception page ('Unable to save element Element_OphInDnasample_Sample.' thrown at BaseEventTypeController.php:2014); the transaction rolls back, so no orphan event - but the input is lost behind an error page instead of a field message.

> 1. Log in.
> 2. Ensure your user holds the 'Genetics Clinical' role and at least one Genetics study exists.
> 3. Find a patient and open their 'Patient Summary'.
> 4. Click 'Add Event', choose subspecialty 'External', context 'External Service', then pick 'DNA sample'.
> 5. Leave 'Type' as the pre-selected 'Blood'.
> 6. Type '50abc' into 'Volume (Millilitres)'.
> 7. Pick any study in the '-- Add --' picker below 'Consented By'.
> 8. Click 'Save'.
> 9. Observe an unhandled exception page ('Exception | Stack Trace') instead of a validation message.

Evidence: finder crash with root-cause CDbCommand 1265 trace; R1 verifier reproduced the identical exception page on a different patient (page headings 'Exception | Stack Trace', banner quoting BaseEventTypeController.php:2014).

R2 (varied free choices, third agent, third patient): crashes on every combination tried - subspecialty/context 'Medical Retina'/'Medical Retinal Service', 'Anaesthetics'/'Anaesthetics Service', 'Uveitis'/'Uveitis Service' and the dialog's own pre-selection; 'Type' Blood, Buccal and 'DNA and RNA' alike; date today or past. The trigger is any Volume string that *starts* with a digit but is not a plain number - '5,5', '2ml', '3/4', '1e2x' all crash. Strings that do not start with a digit ('abc') or start with whitespace (' 12 ml') are handled correctly and produce the proper field message 'Sample: Please enter a value between 1 and 99', which is the positive control that the validator itself still runs. Four independent crashing submissions, each with the CDbCommand 1265 'Data truncated for column volume' pair in the log bracket, no harness-artifact signature.

### BUG-02: Examination - null edit silently discards the Diagnoses 'no diagnoses confirmed' state (HIGH, data-loss) [R1+R2]

A saved Examination whose Diagnoses element has both 'no diagnoses' confirmations ticked shows 'Eye Diagnoses (No change recorded)' / 'Systemic Diagnoses (No change recorded)' on the view, with `diagnoses_record_event.no_entries_confirmed_for` holding the confirmed ids. Opening Edit and saving with no changes strips both annotations and nulls the column - a clinician's explicit "nothing to record" confirmation is silently destroyed by any later touch-and-save of the event.

> 1. Log in.
> 2. Open a patient summary, click 'Add Event', choose the 'Glaucoma' subspecialty with the 'Glaucoma Service' context, and pick 'Examination'.
> 3. Fill the minimal required fields ('History' comment; 'no allergies'/'no risks'/'no family history' ticks; 'Unable to assess' for both Visual Acuity eyes; CCT values and method; a Clinic Outcome).
> 4. In 'Diagnoses' tick both 'no diagnoses' confirmation tick-boxes.
> 5. Click 'Confirm & Save' - the view shows 'Eye Diagnoses (No change recorded)' and 'Systemic Diagnoses (No change recorded)'.
> 6. Click 'Edit', change nothing, click 'Confirm & Save' again.
> 7. Observe the view now shows plain 'Eye Diagnoses' / 'Systemic Diagnoses' - the confirmations are gone.

Evidence: finder reproduced twice (including one fully clean null edit) with `no_entries_confirmed_for` going `["130","9999"]` -> NULL in `diagnoses_record_event`; R1 verifier reproduced end-to-end on a different patient (view annotations present after create, gone after null edit; DB column confirmed populated then NULL).

R2 (varied free choices, third agent, third patient): reproduced in a 'Uveitis' / 'Uveitis Service' workflow rather than Glaucoma, and with only one of the two acknowledgements ticked as well as both - the single confirmation is lost the same way. Header and footer 'Confirm & Save' behave identically. Positive control: the 'Eye Diagnoses' / 'Systemic Diagnoses' headings and their listed entries are still present after the null edit, so the read is seeing the live element and only the '(No change recorded)' annotation disappeared. So the fault is not tied to the Glaucoma pathway or to the both-ticked state.

### BUG-03: DNA sample - future 'Dna date' accepted and saved despite today-max date picker (MEDIUM, validation) [R1]

The calendar widget caps at today, but the text input accepts typed text and `blood_date` has only a 'safe' rule server-side (`Element_OphInDnasample_Sample::rules()`), so a future date saves and displays.

> 1. Log in (user with the 'Genetics Clinical' role).
> 2. Click 'Add Event', choose subspecialty 'External', context 'External Service', then pick 'DNA sample'.
> 3. Click into 'Dna date' and type a future date such as '29 Jul 2030'.
> 4. Type '5' into 'Volume (Millilitres)' and add any study in the '-- Add --' picker.
> 5. Click 'Save'.
> 6. Observe the event saves and the view shows a DNA sample dated in the future.

Evidence: finder saved blood_date 2030-07-29; R1 verifier saved a second event on a different patient, view showing 'Dna date: 29 Jul 2030', clean log bracket.

### BUG-04: DNA sample - empty-form Save shows a range error naming no field, and 'Type' can never error (LOW, validation) [R1]

Saving the untouched form yields 'Please fix the following input errors: Sample: Study(s) cannot be blank. Sample: Please enter a value between 1 and 99'. The 1-99 line is a hardcoded message in `volume_validator` that omits the attribute label (the field is merely empty, not out of range), and 'Type' never errors because `et_ophindnasample_sample.type_id` has column default 1 (Blood) with no placeholder option in the select.

> 1. Log in (user with the 'Genetics Clinical' role).
> 2. Click 'Add Event', choose subspecialty 'External', context 'External Service', then pick 'DNA sample'.
> 3. Click 'Save' without touching any field.
> 4. Observe the banner line 'Sample: Please enter a value between 1 and 99' names no field, and no error appears for 'Type'.

Evidence: R1 verifier reproduced the verbatim banner (`[data-test="validation-errors"]` innerText) on a different patient.

### BUG-05: Drug Administration - typed Dose and Unit are wiped when Route is selected; save then fails 'Dose cannot be blank' (HIGH, data-loss) [R1+R2]

In a custom-order drug row, the route-change handler rebuilds the entire row from the `tr`'s data- attributes only (`OphDrPGDPSD/widgets/js/DrugAdministration.js`, `bindRouteOpt` ~line 646: `processEntry(...)` then `$current_row.remove()`) - the Dose input value and Unit selection are never read, so they are silently discarded. The table's column order (Dose, Unit, Route) means natural left-to-right entry hits this every time; entering Dose/Unit after Route works, proving the wipe is ordering-dependent.

> 1. Log in.
> 2. Open a patient's summary and click 'Add Event'; choose a subspecialty with an existing episode, then 'Drug Administration'.
> 3. Click the green adder button next to 'Add Preset Order' (the 'Add medications' button).
> 4. Type 'Latanoprost' into the adder's search box and click the 'Latanoprost' result.
> 5. Click 'Right Eye' in the laterality column, then the green tick ('Click to add').
> 6. In the new drug row, type '1' into 'Dose' and choose 'drop' in the '-Unit-' dropdown.
> 7. Choose 'Eye' in the '-Route-' dropdown - the row re-renders and Dose/Unit silently reset to empty.
> 8. Click 'Assign Custom Order', then 'Save'.
> 9. Observe 'Drug Administration: Latanoprost Dose cannot be blank.' and 'Unit Term cannot be blank.' despite both having been entered.

Evidence: finder's Yii-debug capture of the failing POST shows `entries[0][dose]=''` / `dose_unit_term=''` while `route_id`/`laterality` survive, plus a passing control run with Route first; R1 verifier reproduced both verbatim error banners and the reset row on a different patient with a clean log bracket.

R2 (varied free choices, third agent, third patient): reproduced with a different drug ('Acetazolamide', which has no default route so the adder forces a laterality choice), a different laterality ('Left Eye'), a different route ('Oral'), a different unit ('mg') and a different dose ('250'), in the 'General Ophthalmology' context. After the Route selection the row read back with no '250' anywhere and the unit list reset to an unselected '-Unit-', and the save banner was verbatim 'Drug Administration: Acetazolamide Dose cannot be blank. Drug Administration: Acetazolamide Unit Term cannot be blank.' Positive control in the same run: entering Route first and Dose/Unit after saved cleanly with 'Drug Administration created.' and the values stored - so the fault is the entry ordering, not the drug, route, unit or context.

### BUG-06: DNA sample - required Study(s) picker has no visible label on the create form (LOW, render) [R1]

The picker row between 'Consented By' and 'Comments' renders with no label at all (only a '-- Add --' dropdown), while every sibling field is labelled ('Type:', 'Dna date:', 'Consented By:') and both validation and the saved view call the field 'Study(s)'. Saving without it errors 'Study(s) cannot be blank' against a control the user cannot identify.

> 1. Log in.
> 2. Ensure your user holds the 'Genetics Clinical' role.
> 3. Find a patient and open their 'Patient Summary'.
> 4. Click 'Add Event', choose subspecialty 'External', context 'External Service', then pick 'DNA sample'.
> 5. Look at the picker row between 'Consented By' and 'Comments'.
> 6. Observe it has no label at all, yet saving without it errors 'Study(s) cannot be blank'.

Evidence: finder and verifier field dumps both list the control as `"" #Element_OphInDnasample_Sample_studies <select:select-one>` (empty accessible label) while all sibling fields carry theirs; verifier reproduced on a second patient (R1, verified=true) with the sibling labels as positive control.

### BUG-07: Examination - Escape does not close the Manage Elements picker (LOW, js) [R1]

The element picker opened from 'Manage Elements' has no Escape handler; the key reaches the page (an instrumented keydown listener confirmed it in the Chrome lane) but nothing is bound, so the overlay can only be dismissed by clicking its close strip or the toggle button. Every other overlay in the app closes on Escape, so the picker traps keyboard users mid-form.

> 1. Log in.
> 2. Open a patient record and start an 'Examination' event in any subspecialty context (verified in 'Medical Retina' / 'Medical Retinal Service').
> 3. In the left-hand event sidebar click the green 'Manage Elements' button - the picker opens over the form showing the element categories and a blue strip reading 'Select elements to add or remove from examination - Close when done'.
> 4. Press Escape.
> 5. Observe nothing happens: the category list and the 'Close when done' strip are still on screen and 'Manage Elements' stays highlighted.
> 6. Click the 'Close when done' strip - the picker closes immediately, confirming only a mouse click dismisses it.

Evidence: chrome lane found it and retested twice; scripted R1 on a different patient ran the driver twice with identical results - after Escape the close strip is still listed as a visible control in the dump (visibility requires a >1x1 box) and a read of `#manage-elements-nav` is byte-identical to the pre-Escape read and still newline-separated (rendered innerText). Positive control: the following click on `[data-test="manage-elements-close-btn"]` succeeded (Playwright requires visible + hit-testable), after which the strip is absent from the dump, the headings revert to the form's own, and the same read comes back as one unbroken string (textContent of a non-rendered element) - so the probe demonstrably distinguishes open from closed. Both runs exited 0, no harness-artifact signature.

### BUG-08: Add Event dialog - clicking the blank part of an 'Existing drafts' row fires a create URL with an empty event type and 400s (MEDIUM, navigation) [R1]

The recent-draft row in the Add Event dialog is styled as one clickable tile (whole row highlights, pointer cursor) but only the text is an anchor to `/patientEvent/loadDraft?draft_id=N`. Clicking anywhere else on the row falls through to the dialog's generic create handler, which builds `/patientEvent/create?...&event_type_id=&...` with no event type; `PatientEventController::resolveEventType` (line 95) then throws CHttpException 400 'Invalid request.' The user loses the dialog and gets a framework error page instead of their draft.

> 1. Log in.
> 2. Give the patient a draft first: open a new 'Examination' for a patient with an existing episode, leave the form on screen about 30 seconds so autosave fires (the address bar gains a draft id), then leave via the patient-name link in the header - not 'Cancel', which offers to discard the draft.
> 3. Go to the patient's 'Patient Overview' and click 'Add Event'.
> 4. Choose the same subspecialty, then the same context.
> 5. Under 'Existing drafts' a row now reads 'Examination' with a relative time such as '4 minutes ago'; the whole row highlights on hover.
> 6. Click that row in its blank right-hand portion - still inside the highlighted area, just past the end of the text.
> 7. Observe 'CHttpException - Invalid request.' instead of the draft opening. Clicking directly on the word 'Examination' opens the draft correctly.

Evidence: chrome lane observed it once; scripted R1 on a different patient reproduced the exact URL (`event_type_id=` empty, `context_id`/`episode_id` populated) and the CHttpException 400 quoting `PatientEventController.php(95)`, with the text-click control opening the draft normally. Clean log bracket.

### BUG-09: Examination - a patient with repeated medications cannot save an untouched form; the prefilled Medication History rows fail their own duplicate validation (MEDIUM, validation) [R1]

The Examination form prefills Medication History from the patient's current medications. When that record contains the same preparation more than once - common on long-running patients - the element's duplicate validator rejects rows the form supplied itself, so an untouched form is unsavable. The message names the offending row only by a bare ordinal ('Medication History: 12- The entry is duplicate'), never by medication name, so nothing on screen tells the user which drug to remove.

> 1. Log in.
> 2. Open the record of a patient with a long medication history that repeats the same preparation several times - the fault only appears when the prefilled list actually contains repeats.
> 3. Click 'Add Event' and choose a subspecialty and context whose Examination workflow includes 'Medication History' (confirmed on both 'Cataract' and 'Uveitis'; contexts with no subspecialty-specific workflow fall back to the 'Default' set, which includes it), then pick 'Examination'.
> 4. If asked 'An existing draft event has been found for this event type. Do you wish to load the existing draft event?', click 'No (delete draft)' to start clean.
> 5. Let the form finish loading. 'Medication History' is already populated, each row showing 'Click here to stop'. Change nothing anywhere.
> 6. Click 'Confirm & Save'.
> 7. Observe the save refused with a run of 'Medication History: <n>- The entry is duplicate' lines (13 of them in the confirmed run) naming rows the form itself supplied, identified only by number.

Evidence: finder hit it in a Cataract context; R1 verifier reproduced on a different patient in a Uveitis context with 13 duplicate lines in the banner, the errors persisting on a re-dump so the event is genuinely unsaved, and the twin's medication record confirmed in the database as holding the same preparation up to 39 times. Clean log bracket, no harness-artifact signature. Note that the first R1 attempt in the earlier wave failed only because that twin's prefilled rows were four distinct drugs - the precondition, not the bug, was missing.

## Unverified candidates

Candidates that did not get a passing independent replay - single-observation walk findings, or findings whose precondition the verifier could not reach. NOT verified; do not ship as bugs without a repro pass. Where a replay was attempted the outcome is recorded on the candidate, and the three could-not-reach-state entries are explicitly not refutations: each names the precondition that was missing.



### CAND-03: promoted to BUG-09 (R1 passed on a second attempt with a patient whose medication record actually repeats a preparation).

### CAND-07: DNA sample - every save logs a mangled unsafe-attribute warning (LOW, log-noise)

Each create/edit POST logs `[warning] Failed to set unsafe attribute "MultiSelectList_Element_OphInDnasample_Sample[studies" ...` (note the unbalanced bracket) from BaseActiveRecord.php(210); data saves correctly, but the warning fires on every save and masks real mass-assignment issues. Observed on all 5 finder saves.

### CAND-08: Examination create form with live EyeDraw canvases can freeze the renderer (UNTRIAGED, chrome lane)

Under CDP automation, the Glaucoma Clinic Examination create form with two Anterior Segment EyeDraw canvases repeatedly froze the Chrome renderer (screenshot timeouts on ~every other interaction, eventual extension disconnect). Possibly automation-specific; not scriptedly verifiable - needs a manual look.

### CAND-09: Examination - Diagnoses2 controller TypeError (MEDIUM-HIGH, js) [R1 REFUTED as stated; narrower trigger still open]

Original claim (chrome lane, 6 observations): every element/data change on the Examination create/edit form fires a paired console error - a Vue bundle error plus `TypeError: Cannot read properties of undefined (reading 'id')` at `OpenEyes.Diagnoses2.Controller.js:65-66`.

R1 refuted the "every interaction" part. A verifier using a console-capturing driver got zero page errors and zero console errors on the twin across four runs and two subspecialty contexts, on page load, opening and closing the Manage Elements picker, ticking the no-diagnosis confirmation, clicking the Visual Acuity add-reading button, and pressing Escape. The refutation is two-sided: a deliberately-throwing control page in the same runs produced both a `[CONSOLE:error]` and a `[PAGEERROR]` line, the access log shows all eight Diagnoses2 scripts returning 200 on the page under test, and a read of `#diagnoses-app` shows the Vue app mounted and rendering the patient's diagnoses - so the silence is informative, not vacuous.

The verifier's static cross-check explains why: the crashing line is inside `Controller.prototype.addDiagnoses`, whose only callers are the adder dialog, the external-element controller and the `OpenEyes.Diagnoses2.js` facade - i.e. it runs only when a diagnosis is actually added. Neither the picker nor the Visual Acuity adder reaches it. That leaves a narrower and still-plausible hypothesis, untested here: the chrome lane's doodle-add observations went through the auto-diagnosis path (an Anterior Segment doodle can auto-create an eye diagnosis), and `disorders[disorders.length - 1].id` throws exactly when `disorders` is empty. Worth one targeted run against a doodle-driven auto-diagnosis before either shipping or dropping it.

### CAND-10: promoted to BUG-07 (R1 passed).

### CAND-11: Examination view - ResponsibleForCareCore.js load-order error (LOW, js) [chrome lane; R1 attempted: could not reach state]

Saved view logs `ResponsibleForCareCore.js:90 - Can not register for diagnoses change events as Diagnoses core JS not loaded`; the core script initialises before/without the Diagnoses core JS.

R1 note: the script is registered from exactly one place, the `AreaOfCare` widget, so only an Examination carrying a Responsible For Care element can emit the message - and none of the twin's three saved Examinations had that element (the whole sample DB held a single `et_ophciexamination_areaofcare` row, belonging to another walker's patient and off-limits). The verifier's console capture was proven live in the same run, so the silence is a real read, but a structurally uninformative one. The static mechanism holds up on inspection (the core self-instantiates after a synchronous ajax and checks `exports.Diagnosis` immediately), which is why this stays a candidate rather than a refutation.

### CAND-12: promoted to BUG-08 (R1 passed).

### CAND-13: Examination - mandatory Responsible For Care auto-populates an Area-of-Care entry with Responsible Organisation 'Unknown' (institution_id=-1), which is itself invalid and blocks save (MEDIUM, workflow trap) [chrome lane; R1 attempted: could not reach state]

The element is mandatory (re-appears after removal) and its auto-included entry defaults to an organisation the validator rejects ("institution cannot be 'Unknown'"); the save only passes after deleting the Area-of-Care entry. A mandatory element whose default state is invalid is a save-blocking trap in the resumed-draft workflow where it was hit.

R1 note: on the twin, adding Responsible For Care through the element picker rendered the widget with an EMPTY entry table (only its `#add-area-of-care` button, zero entry fields in any dump), so there was no auto-populated 'Unknown' entry to reject and the save failed only on unrelated missing fields. The chrome lane hit this in a resumed-draft workflow, where the entry appears to be pre-seeded. Precondition not reproduced, so this is neither confirmed nor refuted - a re-run needs the draft-resume path, not a fresh picker add.

### CAND-14: RETIRED - refuted. 'Confirm & Save' is actionable on a pristine Examination edit page.

The finder saw clicks on `#et_save` and `#et_save_footer` time out on an unmodified `/OphCiExamination/default/update/<id>` across three driver runs. A verifier clicked `#et_save` on pristine update pages in two contexts plus `#et_save_footer` once, and all posted the form with no timeout; BUG-02's R1 and R2 verifiers independently performed clean null edits that saved instantly, in Glaucoma and Uveitis workflows. Four independent clean null edits against three timeouts on one agent's runs makes this a harness actionability artifact on the finder's side (most likely the button still covered, or their own create not yet saved), not application behaviour.

### CAND-15: Examination view - a diagnosis entry with a null observation date breaks the view's sort (LOW, latent) [incidental, not hunted]

Seen incidentally by a verifier, not by a finder: one saved Examination view returned HTTP 500 with the page 'PHP error | Stack Trace' at `protected/modules/Diagnoses/resources/DiagnosesInformationResource.php:155`, inside `sortEntriesByObsDate`'s `usort` comparator. The 500 itself is a dev-image artifact - the log shows the underlying event is the PHP 8.4 deprecation `strtotime(): Passing null to parameter #1 ($datetime) of type string`, which this image renders as a fatal because `error_reporting=E_ALL` and `YII_DEBUG` are on; a production install would render the page. What survives outside dev mode is a real but minor defect: `strtotime(null)` yields false, so any diagnosis entry with a null `obs_date` sorts arbitrarily against the others. Do not report this as a 500 - report the null-date comparator.

## Static sweep findings (unverified, code-level)

76 hypotheses from 14 parallel code readers over develop @ 04c938c0a4 (36 high / 32 medium / 8 low confidence). NONE were exercised in a browser - they are code-level predictions with file:line and a testable predicate each, NOT verified bugs. Full detail per finding (description, predicted predicate, code quote) in `oe-develop-bug-hunt-2026-07-29-static.md`. Two sweep areas (e-signature widgets, procedure-selection widgets) never ran - the session usage limit killed them; that coverage is absent, not clean. Highest-value items:

- S-01 (high): Pathway `step_started`/`step_completed` events are never dispatched after an event save - `protected/behaviors/WorklistBehavior.php:285` compares an int status against a string parameter, always false. A regression from the OE-16213 refactor; worklist-driven step clicks still work, which masks it.
- S-02 (high): Mandatory RTT setting silently disables all Clinic Outcome validation when the RTT widget is absent - `protected/modules/OphCiExamination/controllers/DefaultController.php:4338`. An empty Clinic Outcome saves with no error whenever the RTT clock does not render (no referral, or event opened outside a worklist).
- S-13 (high): REFUTED by replay - see below.
- S-42 (medium): Clinic Outcome error text demands an RTT/DNA outcome the form gives no way to record when the RTT widget did not render - `DefaultController.php:4351`.

Two of these were taken to the browser in the closing verification wave; that is 2 of 76, so the rest remain unexercised predictions.

- S-02 NOT REACHED (precondition absent on a stock sample database, so neither confirmed nor refuted). Both gating settings ship off: `enable_rtt_clock_bar` and `mandatory_rtt_clock_state_completion` default to 0 in `setting_metadata` and there is no override row at any scope (installation, institution, site, firm, subspecialty, institution-subspecialty). Exercising this needs both switched on first. Two incidental facts from the attempt: the element's on-screen name is 'Clinical Outcome', not 'Clinic Outcome', and the RTT widget's `#rtt-clock-app` is correspondingly absent.
- S-13 REFUTED. The predicted consequence does not occur: on an Examination create form with Visual Acuity present, typing into a different element and then removing that element still raises 'Are you sure that you wish to close the History element? All data in this element will be lost', and that dialog is gated on `element_dirty === "1"` - so the dirty marker survives. The ordering explains it: `create.php:128` registers VisualAcuity.js at POS_HEAD from the content view, which Yii renders before the layout, so its `$('#event-content').off('change')` runs before `events_and_episodes.js` (registered from the layout head) binds its delegate. The blanket `off('change')` is still poor hygiene and would break if the registration order ever changed, but it is not currently causing data loss.

Full compact index (S-numbers match the companion file):

- S-01 (high): Pathway step_started/step_completed events never dispatched after event save (int vs string always-false compare) - `protected/behaviors/WorklistBehavior.php:285`
- S-02 (high): Mandatory RTT setting silently disables all Clinic Outcome validation when the RTT widget is absent - `protected/modules/OphCiExamination/controllers/DefaultController.php:4338`
- S-03 (high): Add-taper clones the dose input but never syncs the user-typed value - `protected/modules/OphDrPrescription/assets/js/defaultprescription.js:106`
- S-04 (high): actionRouteOptions null-deref when route is reset to '-- Select --', leaving stale laterality dropdown - `protected/modules/OphDrPrescription/controllers/DefaultController.php:396`
- S-05 (high): actionGetDispenseLocation null-deref: Dispense Location dropdown left stale when condition has no locations mapped - `protected/modules/OphDrPrescription/controllers/PrescriptionCommonController.php:145`
- S-06 (high): Taper dose validation class tests $item->dose instead of $taper->dose (copy-paste) - `protected/modules/OphDrPrescription/views/default/form_Element_OphDrPrescription_Details_Item.php:204`
- S-07 (high): actionPrintCopy prints hardcoded examination event 3686356 (leftover debug code) - `protected/modules/OphDrPrescription/controllers/DefaultController.php:551`
- S-08 (high): Warnings 'Confirm' button dead: wrong `this` in click handler blocks saving - `protected/assets/js/OpenEyes.EventDraftController.js:121`
- S-09 (high): Update view missing connection-error 'Confirm & Save' button targeted by JS - `protected/modules/OphCiExamination/views/default/update.php:50`
- S-10 (high): actionDeleteDrafts lacks 'event_id IS NULL' filter - wipes update restore points - `protected/controllers/BaseEventTypeController.php:1606`
- S-11 (high): Sidebar event icon/quicklook stays 'Requires scheduling' forever after operation is scheduled - `protected/components/EventListDisplayDetailsRepository.php:46`
- S-12 (high): Per-patient shared sidebar HTML cache never invalidates on the status changes the details table tracks - `protected/views/patient/_single_episode_sidebar.php:112`
- S-13 (high): Blanket $('#event-content').off('change') in VisualAcuity.js kills element-dirty marking and other delegated change handlers - `protected/modules/OphCiExamination/assets/js/VisualAcuity.js:159`
- S-14 (high): Cancelling the trash-confirm desyncs Manage-elements popup; re-clicking the entry inserts a duplicate element section - `protected/assets/js/OpenEyes.UI.ManageElements.js:58`
- S-15 (high): Laser Procedure: right pulse-duration 'from' validated against LEFT eye's 'to' - `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php:87`
- S-16 (high): Laser Procedure: right pulse-duration 'from' rule compares the field to itself (dead rule) - `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php:88`
- S-17 (high): Laser Procedure: right_laser_power_from mislabeled 'To', producing a self-referential error - `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php:153`
- S-18 (high): Both-eyes procedure verification is dead: JS reads input name Procedures[] but widget renders Procedures_procs[] - `protected/modules/OphTrOperationnote/assets/js/module.js:329`
- S-19 (high): loadElementByProcedure echoes 'must-select-eye' then continues into foreach with a null element - PHP fatal on every guard hit - `protected/modules/OphTrOperationnote/controllers/DefaultController.php:517`
- S-20 (high): must-select-eye cleanup targets selectors that do not exist (.procedureItem, #procedureList, unmatched regex) - procedure stays listed without its element - `protected/modules/OphTrOperationnote/assets/js/module.js:103`
- S-21 (high): procedure_requires_eye() omits Element_OphTrOperationnote_PreserFloMicroShunt - verifyprocedure contradicts loadElementByProcedure - `protected/modules/OphTrOperationnote/controllers/DefaultController.php:705`
- S-22 (high): SyntaxError in update-template popup script kills 'Update template' button on Schedule page - `protected/modules/OphTrOperationbooking/views/booking/schedule.php:206`
- S-23 (high): Theatre diary admission-time errors never highlight rows: #oprow_ prefix vs unprefixed row ids - `protected/modules/OphTrOperationbooking/assets/js/TheatreDiaryController.js:630`
- S-24 (high): Cross-element [proc_id] duplicate check silently blocks adding extra procedures on id collision - `protected/modules/OphTrConsent/views/default/procedure_selection.php:64`
- S-25 (high): Undefined patientContactLimit in Contacts.js disables per-patient contact-type limit in Add-new-contact dialog - `protected/modules/OphTrConsent/assets/js/Contacts.js:231`
- S-26 (high): Consent taken by: consultant_id is set from created_user_id, never from the selected health professional - `protected/modules/OphTrConsent/views/default/form_Element_OphTrConsent_Consenttakenby.php:67`
- S-27 (high): handleTinyMCEInput discards all non-list content typed into Benefits/Risks whenever a procedure is added - `protected/modules/OphTrConsent/assets/js/module.js:446`
- S-28 (high): Deceased recipient: getAddress returns double-encoded JSON, recipient row crashes - `protected/modules/OphCoCorrespondence/components/OphCoCorrespondence_API.php:684`
- S-29 (high): Deceased patient + Patient-recipient macro: raw {"error":"DECEASED"} JSON injected into recipients HTML - `protected/modules/OphCoCorrespondence/components/OphCoCorrespondence_API.php:339`
- S-30 (high): Deceased patient + CC-patient macro: null->email crash makes macro recipients 500 - `protected/modules/OphCoCorrespondence/models/ElementLetter.php:1477`
- S-31 (high): Empty Categories selection hides ALL pathway steps while panel says "All" - `protected/assets/js/worklist/OpenEyes.UI.WorklistFilterPanel.js:460`
- S-32 (high): Context dropdown snaps back: server override discards the requested context - `protected/controllers/WorklistController.php:2199`
- S-33 (high): Server-coerced site/subspecialty/context never written back into the filter model - `protected/assets/js/worklist/OpenEyes.UI.WorklistFilterPanel.js:504`
- S-34 (high): Reset to defaults leaves category filtering active (and sets optional to an Array) - `protected/assets/js/worklist/OpenEyes.UI.WorklistFilterPanel.js:202`
- S-35 (high): Menu link builder drops the colon guard: 'javascript:' menu items now navigate to a 404 - `protected/views/base/_menu.php:40`
- S-36 (high): Forum tracker seed migration ignores institution-level enable_forum_integration, deleting the menu item on upgraded installs - `protected/migrations/m260709_101000_seed_forum_tracker_custom_menu_item.php:11`
- S-37 (medium): Worklist session state wrongly reset when active (string) and resolved (int) patient ids are compared with !== - `protected/controllers/BaseEventTypeController.php:3751`
- S-38 (medium): actionCreate renders a blank page when afterCreateElements returns errors (bare return after rollback) - `protected/controllers/BaseEventTypeController.php:1039`
- S-39 (medium): updateEventStep ignores its $event parameter when finding the step and never saves the assigned step_id - `protected/controllers/BaseEventTypeController.php:3535`
- S-40 (medium): saveEvent dereferences null PathwayStep when session active_step_id is stale - `protected/controllers/BaseEventTypeController.php:1954`
- S-41 (medium): actionLoadDraft null-derefs when no runtime-selectable fallback firm exists in the institution - `protected/controllers/PatientEventController.php:280`
- S-42 (medium): Clinic Outcome error demands an RTT/DNA outcome the form gives no way to record - `protected/modules/OphCiExamination/controllers/DefaultController.php:4351`
- S-43 (medium): Taper model forces numerical dose while item dose (which the UI clones into tapers) may be free text - `protected/modules/OphDrPrescription/models/OphDrPrescription_ItemTaper.php:66`
- S-44 (medium): addItem() sets $.ajaxSetup({async:false}) globally and never restores it - `protected/modules/OphDrPrescription/assets/js/defaultprescription.js:474`
- S-45 (medium): saveDraft 404 for expired draft rendered as fake connection error, save locked out - `protected/assets/js/OpenEyes.EventDraftController.js:291`
- S-46 (medium): Autosave 'handle' dispatch re-enables read-only Area of Care inputs - `protected/modules/OphCiExamination/widgets/js/ResponsibleForCare.js:86`
- S-47 (medium): Handheld existing-draft banner lacks the data attributes the draft controller reads - 'delete draft' navigates with undefined params - `protected/views/patient/event_content_handheld.php:19`
- S-48 (medium): Handheld event form omits Event[last_modified_date] hidden field - concurrent-edit conflict detection silently disabled - `protected/views/patient/event_content_handheld.php:1`
- S-49 (medium): Correspondence email in PENDING_RETRY renders as 'Complete' with the done icon - `protected/components/EventListDisplayDetailsHelper.php:318`
- S-50 (medium): Rejected sidebar load still marks Manage-elements popup entry 'added', leaving a stuck un-addable item - `protected/assets/js/OpenEyes.UI.ManageElements.js:62`
- S-51 (medium): addElementByTypeClass waits on a 'loaded' event that is never triggered - callbacks silently dropped for in-flight elements - `protected/assets/js/OpenEyes.UI.PatientSidebar.js:311`
- S-52 (medium): Biometry Data: r1 duplicated in requiredIfSide rule, duplicate error and likely lost axial_length requirement - `protected/modules/OphInBiometry/models/Element_OphInBiometry_BiometryData.php:76`
- S-53 (medium): Posted OperativeDevice ids looked up via the assignment model OphTrOperationnote_CataractOperativeDevice::findByPk - `protected/modules/OphTrOperationnote/controllers/DefaultController.php:1453`
- S-54 (medium): Template 'prefilled' highlight never clears when user edits the field (dead handlers) - `protected/modules/OphTrOperationbooking/assets/js/module.js:239`
- S-55 (medium): Priority-change save/schedule button toggle bound to hidden uncheck input - never fires, would throw if it did - `protected/modules/OphTrOperationbooking/assets/js/module.js:210`
- S-56 (medium): setBenefitsAndRisksFromProcedures leaves benefits/risks as literal '</ul>' when procedures have no active benefits/complications - `protected/modules/OphTrConsent/models/Element_OphTrConsent_BenefitsAndRisks.php:178`
- S-57 (medium): Extra-procedure benefits/complications URLs omit baseUrl, breaking sub-path deployments - `protected/modules/OphTrConsent/assets/js/module.js:470`
- S-58 (medium): OE-18106 regression: quick-text strings containing any tag lose all line breaks - `protected/modules/OphCoCorrespondence/assets/js/module.js:1390`
- S-59 (medium): Attachment metadata mangled on validation-error round trip (wrong POST keys) - `protected/modules/OphCoCorrespondence/widgets/AssociatedContentViewTable.php:88`
- S-60 (medium): updateCorrespondence called with this=window: macro dropdown never clears (incl. DECEASED path) - `protected/modules/OphCoCorrespondence/assets/js/module.js:48`
- S-61 (medium): All four internal-referral validators crash every save if 'Internal Referral' letter type is inactive - `protected/modules/OphCoCorrespondence/models/ElementLetter.php:173`
- S-62 (medium): setDefaultOptions reads $episode->firm on null episode when user has a sign-off delegate - `protected/modules/OphCoCorrespondence/models/ElementLetter.php:727`
- S-63 (medium): fromJSON drops the 'all' default for subspecialty on legacy filters - `protected/assets/js/worklist/OpenEyes.WorklistFilter.js:164`
- S-64 (medium): Legacy favourites with specific worklists render blank list names - `protected/assets/js/worklist/OpenEyes.UI.WorklistFilterPanel.js:47`
- S-65 (medium): availableFilterOptions errors when the user has no firms for the chosen subspecialty - `protected/controllers/WorklistController.php:2204`
- S-66 (medium): PatientPanel never re-launches FORUM/IMAGEnet when tracking is toggled off and on for the same patient - `protected/widgets/PatientPanel.php:177`
- S-67 (medium): Forum/ImageNet control split: custom menu item admin text promises control over Biometry event buttons that still obey the old setting - `oe-shared/app/Services/Menu/Providers/ForumTrackerMenuItemProvider.php:41`
- S-68 (medium): JSON menu activation (CITO) fails silently on any non-JSON response: popup flashes and closes with no error - `protected/views/base/_menu.php:104`
- S-69 (low): Handheld existing-draft banner has dead Yes/No buttons and no data attributes - `protected/views/patient/event_content_handheld.php:27`
- S-70 (low): AddNew.Controller createEvent TypeError when ticketMoveController exists without the moveTicket panel DOM - `protected/assets/js/OpenEyes.Event.AddNew.Controller.js:107`
- S-71 (low): 'Cancel and discard' triggers createEvent with undefined banner data - `protected/assets/js/OpenEyes.EventDraftController.js:208`
- S-72 (low): Sidebar event entry reads $event->institution->name unguarded - fatal on events with NULL institution - `protected/views/patient/_single_episode_sidebar_event_entry.php:38`
- S-73 (low): Expand-collapsed-element handler matches by empty data-element-id on create - wrong element expanded once a second collapsed-by-default element exists - `protected/assets/js/events_and_episodes.js:21`
- S-74 (low): swapElement crashes and leaves the Visual Acuity element permanently disabled when the sidebar has no VA menu entry - `protected/modules/OphCiExamination/assets/js/VisualAcuity.js:405`
- S-75 (low): Clicking a mandatory entry in the Manage-elements popup inserts a duplicate of the already-open mandatory element - `protected/assets/js/OpenEyes.UI.ManageElements.js:152`
- S-76 (low): $.isNumeric(iolPower); is a no-op statement - the guard block below always runs - `protected/modules/OphTrOperationnote/assets/js/module.js:1652`

## Learnings - how the OpenEyes frontend works

Seeded from pre-hunt code analysis (file:line refs are develop @ 04c938c0a4):

- Create-form autosave drafts are keyed (event_type_id, patient_id, last_modified_user_id) with `event_id IS NULL` - `BaseEventTypeController::getExistingEventDraftsForCreate()` (`protected/controllers/BaseEventTypeController.php:823-833`). Same user + same patient + same event type anywhere = the create form offers the other session's draft. Autosave fires every 30s (`protected/assets/js/OpenEyes.EventDraftController.js:60,137`).
- A successful save deletes ALL unassociated drafts matching (patient, event_type, user) - `EventDraft::removeDraftForEvent()` (`protected/models/EventDraft.php:119-136`); a second in-flight session's next autosave then 404s ("Cannot find draft", `BaseEventTypeController.php:1540-1543`).
- `Patient::getOrCreateEpisodeForFirm()` is find-then-insert with no lock and no unique key on episode(patient_id, firm_id) (`protected/models/Patient.php:927-969`) - two concurrent first-events in a new context can create duplicate episodes.
- Sessions are DB-backed (`user_session`, OESession extends CDbHttpSession) with NO single-session enforcement - concurrent logins for one user coexist. Idle expiry ~24 min. No session GC in web requests (gc_probability=0); a console command clears expired rows.
- Login picks the default firm from `user->last_firm_id` (`protected/components/UserIdentity.php:460-473`) - any context switch by one session silently changes every later login's default context for that user.
- Event edit is serialised by a MySQL GET_LOCK busy-spin (`Event::lock()`, `protected/models/Event.php:859-866`).

From the walk lanes (2026-07-29):

- Examination validation errors do NOT render in `.errorMessage` - they render in a top alert banner (the journey driver surfaces them under the dump's `banners:` line). Probe via dump, not an `.errorMessage` read.
- Element picker item ids are `li#manage-elements-<Name>` where the element name keeps its capitalisation and each of `() /&` becomes `-` (`#manage-elements-Clinical-Management`, `#manage-elements-Vitreous---Fundus`). Clicking an already-open element REMOVES it (toggle, green -> blue), confirmed independently by the scripted and chrome lanes.
- The Glaucoma Clinic Examination template pre-loads ~13 elements (History, Anterior Segment, VA, IOP, Macula, PCR Risk, Clinical Outcome...) - element-picker tests must account for pre-added tiles.
- Clinical Management input ids depend on record mode: unilateral mode has `..._Management_unilateral_comments` (no `_comments`); `#cm-change-record-mode` switches to bilateral and renames the inputs.
- Clinic Outcome 'Discharge' is a three-part adder: status list AND destination list (`ul[data-id="discharge-status-options"]` / `discharge-destination-options`) must each get a selection before the add button.
- On the saved Examination VIEW only some elements get `section[data-test="<Name>-element-section"]` wrappers; Management, Family/Social, Diagnoses and Medications render inside a data-test-less summary grid.
- DNA sample create is RBAC-gated by module API `createOprn='OprnEditDnaSample'` checked in `PatientEventController::resolveEventType` - plain admin 403s ('Permission denied for creating event type.'); the sample DB ships zero Genetics role assignments.
- DNA sample 'Type' silently defaults to Blood: `et_ophindnasample_sample.type_id` column default 1 and no placeholder option in the live select.
- Document upload: `setInputFiles` on the display:none `#Document_single_document_row_id` works; a valid PDF shows 'Annotate'/'Download' within ~1.5s; a disallowed .txt raises a blocking JS alert (`[data-test="alert-ok"]`) that makes `#et_save` unclickable until dismissed.
- Journey driver: every goto/click/select/upload auto-dumps after settle - there is no `{"dump":true}` action (briefs claiming one are wrong; agents adapted by reading auto-dumps).
- AdderDialog medication search fires only on the input's keyup: Playwright `fill()` sets the value without triggering `findRefMedications`, so no results appear; `fill` then `press: End` runs the search.
- Drug Administration keeps BOTH adder dialogs (preset order + custom medications) in the DOM at once - every dialog selector needs `:visible` or the hidden twin matches first; `#js-add-medications` stays disabled ~1.5s until the JS controller inits.
- Prescription has no `#et_save` while unsigned - only 'Save draft' (`#et_save_draft`) and 'PIN sign'. A draft save still enforces item validation (laterality for Eye route, Duration, Dispense Condition/Location) but Frequency/Dose may stay empty; the empty-save error is a modal UI Alert (`[data-test="alert-ok"]`), not a banner.
- Examination create/update autosaves an `event_draft` row almost immediately (URL silently gains `?draft_id=N`). A later create visit pops the draft dialog, but an unsaved UPDATE-draft is restored silently into the edit page with only an '<Element> - deleted by <user>' banner - a later Confirm & Save commits changes from the abandoned session. Deleting `event_draft` rows in DB is the reliable inter-walk reset.
- Update pages render two save buttons (header `#et_save` plus footer `#et_save_footer`); create pages only the header one.
- Scripted minimal-valid Examination: History description; VA/Near VA via `unable_to_assess` checkboxes; IOP via per-side comments (`#iop-<side>-comment-button` reveals the textarea); Gonioscopy/Anterior Segment satisfy their eyedraw rules through auto-added default doodles.
- When any OE dialog is open the driver dump scopes to the popup; its `page behind: "Timed out"` label belongs to the always-present hidden `#js-overlay`, not a real session expiry.
- The dev image's Yii debug data (`protected/runtime/debug/<tag>.data`) holds full POST bodies - fastest proof of client-side value loss - but the index rotates after ~58 requests, so read it immediately.
- Chrome gesture lane positives (no defect found): EyeDraw doodle add/drag/delete clean; VA adder popup commits readings; saved-view section collapse/re-expand restores cleanly; an Anterior Segment Hyphaema doodle auto-creates a dated 'Hyphaema' eye diagnosis (by design, but worth knowing when counting diagnoses).

From the verification wave (2026-07-29, later):

- Which elements an Examination context offers comes from `ophciexamination_workflow_rule`; a context with no subspecialty-specific rule falls back to the catch-all rule (all selectors NULL) pointing at workflow 'Default', whose set includes Medication History and Clinical Outcome.
- The outcome element's on-screen name is 'Clinical Outcome', not 'Clinic Outcome' - the picker id is `li#manage-elements-Clinical-Outcome`. The model and controller are named ClinicOutcome, which is what misleads.
- The Manage Elements picker binds no keyboard handler at all, so Escape cannot close it; and open-vs-closed is readable without a screenshot, because a read of `#manage-elements-nav` returns newline-separated `innerText` while open and one unbroken `textContent` string while closed.
- The RTT clock is off on a stock sample database (`enable_rtt_clock_bar` and `mandatory_rtt_clock_state_completion` default to 0, no override at any scope), so `#rtt-clock-app` never renders and every RTT-gated path is unreachable until both are switched on.
- Yii renders a content view before the layout, so a `POS_HEAD` script registered from the create view runs before scripts registered from the layout head. That ordering is load-bearing: it is why `VisualAcuity.js`'s blanket `$('#event-content').off('change')` does not currently destroy the element-dirty delegate.
- Element-dirty state is observable from a walk without touching the DB: dirty an element, click its remove icon, and the close-warning dialog ('All data in this element will be lost') appears only when `element_dirty` is 1.
- Medication History is prefilled from the patient's current medications and duplicate-validated, so patient choice decides whether an untouched Examination is savable at all.

## Run log

- 2026-07-29: mcauto stack + snail-oe-manager-1 stopped for the hunt window; snail-db-1 moved c2m4 -> c4m16 and restarted. Pre-reset DB was EMPTY (0 patients/episodes/events - schema only).
- Reset complete (exit 0): container checkout at develop 04c938c0a4, migrations tail m260723_100000, fresh sample DB (2284 patients / 1247 episodes / 6902 events). Canaries all green: Playwright login OK, login TTFB 30-60ms, 11G free RAM, Examination create renders headless at shm=64M, test PDF fixture in /tmp/twopage.pdf. Baseline: epoch 1785333710, application.log 525553 bytes, audit MAX(id)=109.
- Hunt clock started ~15:02 UTC: wave-1 gauntlet workflow launched (14 slices, all 23 event types, concurrency 4, one patient per slice, disjoint verifier pool held back). Static sweep workflow still running. Chrome gesture session 1 launched on reserved patient (Examination element picker + EyeDraw).
- Chrome session 1 lost its extension mid-walk (renderer freeze with two EyeDraw canvases -> CAND-08); session 2 relaunched with adapted tactics and completed the full gesture pass (CAND-09..13 + positives).
- ~15:40 local (14:40 UTC): session usage limit hit (resets 16:10 local). 10 of 14 gauntlet slices and 2 of 16 static sweep areas died unstarted-or-mid-flight. Completed: gauntlet slices exam-base-adjacent 4 (exam-elements-A, exam-elements-B, document-dna, prescription-drugadmin; 53 scripted walks), static sweep 14/16 areas (76 code-level findings). Event types never gauntleted: op note, consent, correspondence, message, op booking, request form, injection, laser, phasing, DNA checklist, CVI, CatProm5, lab results, genetic tests, therapy, device, biometry - absence of findings there is absence of coverage, not cleanliness.
- Verification wave 1: 7 R1 replays ran (6-bug wave + 1 late), 6 verified (BUG-01..06), 1 could-not-reach-state (CAND-03: twin's prefilled meds held no duplicate pair - precondition failure, not refutation). R2 forfeited to the usage limit at that point.
- Wrap 15:45-15:55 local: journals harvested, register written, snail-oe-manager-1 + mcauto restarted. snail-db-1 stays on the c4m16 profile (revert to c2m4 on request).
- Durable frontend learnings folded into the `c-oe-nav` skill (`subs/examination.md`, `subs/event-forms.md`, `subs/probe.md`, plus a SKILL.md pointer), with the stale element-picker selectors corrected against the running code. Left in the working tree, unstaged, for review; nothing committed.
- Verification wave 2 (16:30-17:15 local, verification only, no new hunting): 12 replays at concurrency 4 - 3 R2 on the HIGH bugs, 7 R1 on outstanding candidates, 2 R1 on the highest-value static findings. All 12 agents completed, none errored. Result: 3 R2 passes (BUG-01, BUG-02, BUG-05), 3 candidate promotions (BUG-07, BUG-08, BUG-09), 2 refutations (CAND-14 retired, static S-13 refuted with a working mechanism), 1 partial refutation (CAND-09's 'every interaction' claim killed, a narrower trigger left open), 3 could-not-reach-state (CAND-11, CAND-13, static S-02 - all precondition failures with positive controls, none of them refutations). One incidental observation logged as CAND-15.
- Final counts: 9 verified bugs (3 of them R1+R2), 6 live candidates, 1 retired, 76 static hypotheses of which 2 were exercised. 19 R1/R2 replays run across both waves.
