# Examination event - elements and navigation

The Examination (`OphCiExamination`, event_type_id 27) is the densest event: a create/edit form made of **elements** the user adds and removes. Which elements appear initially is decided by the admin-configured workflow for the chosen subspecialty/context, so two contexts show different starting forms - say which subspecialty/context a repro assumes. New elements land all the time but the page *structure* (element manager, picker, save flow below) has been stable for years - trust the structure, verify element names.

## Reaching it

- Patient summary > 'Add Event' > subspecialty + context > 'Examination'.
- Direct create URL (sample patient 17891): `/patientEvent/create?patient_id=17891&event_type_id=27&context_id=13&episode_id=601038` (General Ophthalmology; Glaucoma 8/601039, Eye Casualty 2/601040).
- Sample views on 17891: `/OphCiExamination/default/view/3686607` (also `.../3686603`, `.../3686601`). The view page carries a 'Create CVI' shortcut.

## The element manager (create/edit form)

- Form is `#clinical-create`. The element picker opens from `#js-manage-elements-btn`; the popup itself is `#manage-elements-nav`.
- The picker is a popup listing elements under **26 group headings** - History, Triage, Communication, Visual Function, Adnexal, Anterior Segment, Retina, Orthoptic Testing, ... - with a close strip labelled 'Select elements to add or remove from examination - Close when done' (`[data-test="manage-elements-close-btn"]`).
- Each element in the picker is `li#manage-elements-{Name}` where the display name **keeps its capitalisation** and each of the characters `( ) space / &` becomes a hyphen: `li#manage-elements-Visual-Acuity`, `li#manage-elements-Clinical-Management`, `li#manage-elements-Vitreous---Fundus` (for 'Vitreous & Fundus'). Built in `protected/assets/js/OpenEyes.UI.ManageElements.js:316-317` (`this.name.replace(/[() /&]/g, '-')`), which also carries the same string in `data-test`. Clicking one fires AJAX `GET /OphCiExamination/Default/ElementForm...` and the element appears in the form; **clicking an element that is already open REMOVES it** (the item is a toggle, green -> blue), raising an `OpenEyes.UI.Dialog.Confirm` first if it holds data - so only click names not currently open.
- Save is `#et_save` (`data-test="et_save"`). Update pages render a second, identical footer button `#et_save_footer`; create pages have only the header one.
- **Validation failures do NOT render in `.errorMessage`** on this module - they render in a top alert banner ('Please fix the following input errors: ...'). Probing `.errorMessage` times out even when errors are visibly on screen; read the banner instead (`journey.playwright.mjs` surfaces it under the dump's `banners:` line).
- On the saved **view** page only some elements get a `section[data-test="{Name}-element-section"]` wrapper - Management, Family/Social, Diagnoses and Medications render inside a `data-test`-less summary grid. A missing section node is therefore not proof of missing data; probe with `text=` or a `#event-content` read.
- The picker has **no keyboard dismissal at all** - `OpenEyes.UI.ManageElements.js` binds no `keydown`/`keyup` handler, and the nav is toggled only by clicks on the close strip, the toggle button and the element container. Escape does nothing (the keystroke arrives; there is no listener), so a walk must click `[data-test="manage-elements-close-btn"]` to close it.
- Telling open from closed without a screenshot: read `#manage-elements-nav`. Open, it returns rendered `innerText` (newline-separated); closed, the same read returns one unbroken string (`textContent` of a non-rendered element).

Selectors above re-verified live on develop @ 04c938c0a4 (2026-07-29); the earlier v11.0.18 note claimed lowercase-kebab picker ids and `[data-test="close-btn"]`, which do not match the shipped JS.

## Field mechanics worth knowing before scripting a walk

- **Minimal valid Examination** (scripted, no gestures): History wants its `_description` textarea; Visual Acuity and Near Visual Acuity accept the per-eye `unable_to_assess` checkboxes in lieu of readings; Intraocular Pressure accepts per-side comments (`#iop-{side}-comment-button` reveals the textarea) in lieu of readings; Gonioscopy and Anterior Segment satisfy their `requiredIfSide` eyedraw rules through auto-added default doodles, so they save with no interaction.
- **Clinical Management** input ids depend on the element's record mode: unilateral mode has `..._Element_OphCiExamination_Management_unilateral_comments` and no `_comments` field at all; `#cm-change-record-mode` switches to bilateral and renames the inputs. Filling the "documented" `_comments` id silently times out.
- **Clinic Outcome 'Discharge'** is a three-part adder: after clicking 'Discharge', the dialog reveals `ul[data-id="discharge-status-options"]` and `ul[data-id="discharge-destination-options"]`, and BOTH need a selection before `[data-test="add-icon-btn"]`, else a client-side alert blocks the add.
- **Diagnoses** 'no diagnoses' confirmations are `[data-test="no-diagnosis-confirmed"]` (`>> nth=0` systemic, `>> nth=1` ophthalmic); they persist to `diagnoses_record_event.no_entries_confirmed_for` and show as '(No change recorded)' on the view.
- The Glaucoma Clinic workflow pre-loads ~13 elements (History, Anterior Segment, VA, IOP, Macula, PCR Risk, Clinical Outcome, ...) - picker tests must account for pre-added tiles.
- **Which elements a context offers** comes from `ophciexamination_workflow_rule`. A context with no subspecialty-specific rule falls back to the catch-all rule (all selectors NULL) pointing at workflow 'Default', whose set includes Medication History and Clinical Outcome. Query the rule before assuming an element is on the form.
- The outcome element's on-screen name is **'Clinical Outcome'**, not 'Clinic Outcome' - so the picker id is `li#manage-elements-Clinical-Outcome`. The model and controller call it ClinicOutcome, which is what misleads.
- **Medication History** is prefilled from the patient's current medications and validated for duplicates, so a patient whose record repeats a preparation cannot save an untouched form. Pick a patient with distinct medications unless that is what you are testing.
- On a stock sample database the **RTT clock never renders**: `enable_rtt_clock_bar` and `mandatory_rtt_clock_state_completion` both default to 0 in `setting_metadata` with no override row at any scope, so `#rtt-clock-app` is absent and the RTT-gated Clinic Outcome paths are unreachable until both are switched on.
- **Responsible For Care** added fresh from the picker renders an empty entry table (just `#add-area-of-care`); `et_ophciexamination_areaofcare` is essentially empty in sample data. Its auto-populated-entry behaviour only shows on the draft-resume path.
- **Drafts**: create/edit autosaves an `event_draft` row almost immediately and the URL silently gains `?draft_id=N`. A later create visit pops 'An existing draft event has been found' (`#js-load-existing-draft` / `#js-delete-existing-draft`), but an unsaved *update* draft is restored **silently** into the edit page with only a '<Element> - deleted by <user>' banner - so a later Confirm & Save can commit changes from an abandoned session. Deleting the `event_draft` rows in the DB is the reliable inter-walk reset.
- In repro steps, write the gesture as: open the event > click the element-manager button > pick the quoted element name > fill the named fields > 'Save'.

## Element names

The picker's names come from `element_type` rows - ~59 element classes in `protected/modules/OphCiExamination/models/Element_OphCiExamination_*`, grouped roughly as: history/context (History, Risks, Comorbidities, Observations, Triage, Safeguarding...), visual function (Visual Acuity, Near Visual Acuity, Refraction, Keratometry, Colour Vision, Contrast Sensitivity), anterior segment (Anterior Segment, Cornea, CCT, Gonioscopy), posterior segment (Optic Disc, Fundus, Posterior Pole, OCT, DR Grading), glaucoma (Intraocular Pressure, Bleb Assessment), diagnosis (Diagnoses), plan/management (Management, Clinic Outcome, Clinical Management/Conclusion-type elements, Investigation), in-clinic treatment (Dilation, Laser Management, Injection Management, Drug Administration), scoring (PCR Risk, Post-Op Complications), CVI Status.

Display names ~ the model name with spaces, but **verify the exact on-screen name before quoting it** - which elements a context offers and their labels are DB/version-dependent. Full model census: `c-oe-code` -> `subs/examination-elements.md`. Fast verification: probe the create page and dump the picker (`subs/probe.md`).

## Admin side

Menu > Admin > Examination - the largest admin section (77 pages), all under `/OphCiExamination/admin/<Thing>`. It holds the element lookups (visual-acuity values, colour-vision methods, complications, Botox lookups...), plus the workflow / element-set configuration that decides which elements each subspecialty/context starts with. Pages follow the standard lookup pattern ('Add' `[data-test="add-row"]`, 'Save' `[data-test="save-rows"]` or `#et_admin-save`). Per-page URLs: `grep '^| admin/examination' subs/page-index.md`.
