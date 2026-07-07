# Examination event - elements and navigation

The Examination (`OphCiExamination`, event_type_id 27) is the densest event: a create/edit form made of **elements** the user adds and removes. Which elements appear initially is decided by the admin-configured workflow for the chosen subspecialty/context, so two contexts show different starting forms - say which subspecialty/context a repro assumes. New elements land all the time but the page *structure* (element manager, picker, save flow below) has been stable for years - trust the structure, verify element names.

## Reaching it

- Patient summary > 'Add Event' > subspecialty + context > 'Examination'.
- Direct create URL (sample patient 17891): `/patientEvent/create?patient_id=17891&event_type_id=27&context_id=13&episode_id=601038` (General Ophthalmology; Glaucoma 8/601039, Eye Casualty 2/601040).
- Sample views on 17891: `/OphCiExamination/default/view/3686607` (also `.../3686603`, `.../3686601`). The view page carries a 'Create CVI' shortcut.

## The element manager (create/edit form)

- Form is `#clinical-create`. The element picker opens from `#js-manage-elements-btn`.
- The picker (verified v11.0.18, General Ophthalmology) is a popup listing elements under **26 group headings** - History, Triage, Communication, Visual Function, Adnexal, Anterior Segment, Retina, Orthoptic Testing, ... - with a close strip labelled 'Select elements to add or remove from examination - Close when done' (`[data-test="close-btn"]`).
- Each element in the picker is a button `#manage-elements-{kebab-name}` (e.g. `#manage-elements-visual-acuity`); clicking one fires AJAX `GET /OphCiExamination/Default/ElementForm...` and the element's section then appears in the form with `data-test="{name}-element-section"`. Already-added elements are marked `.added` in the picker.
- Save is `#et_save` (`data-test="et_save"`); validation failures render `.errorMessage` blocks (the `_form_errors` partial) and keep you on the form.
- In repro steps, write the gesture as: open the event > click the element-manager button > pick the quoted element name > fill the named fields > 'Save'.

## Element names

The picker's names come from `element_type` rows - ~59 element classes in `protected/modules/OphCiExamination/models/Element_OphCiExamination_*`, grouped roughly as: history/context (History, Risks, Comorbidities, Observations, Triage, Safeguarding...), visual function (Visual Acuity, Near Visual Acuity, Refraction, Keratometry, Colour Vision, Contrast Sensitivity), anterior segment (Anterior Segment, Cornea, CCT, Gonioscopy), posterior segment (Optic Disc, Fundus, Posterior Pole, OCT, DR Grading), glaucoma (Intraocular Pressure, Bleb Assessment), diagnosis (Diagnoses), plan/management (Management, Clinic Outcome, Clinical Management/Conclusion-type elements, Investigation), in-clinic treatment (Dilation, Laser Management, Injection Management, Drug Administration), scoring (PCR Risk, Post-Op Complications), CVI Status.

Display names ~ the model name with spaces, but **verify the exact on-screen name before quoting it** - which elements a context offers and their labels are DB/version-dependent. Full model census: `c-oe-code` -> `subs/examination-elements.md`. Fast verification: probe the create page and dump the picker (`subs/probe.md`).

## Admin side

Menu > Admin > Examination - the largest admin section (77 pages), all under `/OphCiExamination/admin/<Thing>`. It holds the element lookups (visual-acuity values, colour-vision methods, complications, Botox lookups...), plus the workflow / element-set configuration that decides which elements each subspecialty/context starts with. Pages follow the standard lookup pattern ('Add' `[data-test="add-row"]`, 'Save' `[data-test="save-rows"]` or `#et_admin-save`). Per-page URLs: `~/oe-frontend-tests/docs/sitemap/areas/admin__examination.md` when present, else probe.
