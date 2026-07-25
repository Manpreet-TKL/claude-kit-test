## Event create-form field tables

All 23 event types from `paths.md`'s "Add Event dialog -> create pages" table, one
section each. Document's table (`OphCoDocument`) is carried over as-is - verified live
against v11.0.18 back in 2026-07, kept here rather than duplicated in both files. The
other 22 are new: field tables read from
`~/openeyes/protected/modules/<Module>/views/default/` on `develop` (2026-07-24), each
live-checked once against the running app (patient 17891). Where the
live check found a real mismatch it's recorded as a **Live check** note rather than
silently corrected - same convention as `subs/canned/injection-repeat-series.md`'s
Replay notes. `grouping-picker` (a workflow-step selector, not an event field) shows up
as an "extra field" note on several entries below - it's chrome around the form, not
part of it; ignore it. Element field id conventions **vary by module** - some render
the short `#Element_<Name>_<attribute>` form seen in the Document example, others the
fuller `#OEModule_<Module>_models_Element_<Name>_<attribute>`, and a few add an `_0`
suffix - don't assume one pattern across modules; each entry's Live check note records
what that module actually used.

### Biometry create form (OphInBiometry, event_type_id 37) - written from develop view code, live-checked 2026-07-24

Manual entry can be disabled via settings; on create, only Measurement element displays for biometry data entry by eye side.

- 'Axial Length (AL)' text input #Element_OphInBiometry_Measurement_axial_length_<side> (mm; readonly if auto-biometry)
- 'Signal-to-Noise Ratio (SNR)' text input #Element_OphInBiometry_Measurement_snr_<side> (readonly or manual entry if is_auto)
- 'K1' text input #Element_OphInBiometry_Measurement_k1_<side> (D; readonly if auto) + 'K1 Axis' text #Element_OphInBiometry_Measurement_k1_axis_<side> (degrees)
- 'K2' text input #Element_OphInBiometry_Measurement_k2_<side> (D; readonly if auto) + 'K2 Axis' text #Element_OphInBiometry_Measurement_k2_axis_<side> (degrees)
- 'Delta K' computed field (D) with hidden #Element_OphInBiometry_Measurement_delta_k_<side>; marked if manually modified
- 'Anterior Chamber Depth (ACD)' text input #Element_OphInBiometry_Measurement_acd_<side> (mm; readonly if auto)
- 'LVC' and 'LVC Mode' text inputs #Element_OphInBiometry_Measurement_lvc_<side>, #Element_OphInBiometry_Measurement_lvc_mode_<side> (optional)
- 'Status' dropdown #Element_OphInBiometry_Measurement[eye_status_<side>] (selects from Eye_Status table; required)
- Save: Save button posts to create action, then redirects to /OphInBiometry/default/view/<event_id>; if manual entry disabled (setting 'disable_manual_biometry'=off), measurement fields become readonly.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Status field selector written as #Element_OphInBiometry_Measurement[eye_status_<side>] but actual ID is #Element_OphInBiometry_Measurement_eye_status_<side> (square brackets denote name attribute, not ID); Delta K field description incomplete: visible disabled input #input_Element_OphInBiometry_Measurement_delta_k_<side> not mentioned, only hidden field documented; Additional delta_k_axis fields not documented in table: #input_Element_OphInBiometry_Measurement_delta_k_axis_<side> (visible disabled) and #Element_OphInBiometry_Measurement_delta_k_axis_<side> (hidden).

**Functional check (2026-07-24, develop, real Chrome via `docker/oe-chrome-agent`):** a fresh session given only the table above (no view code, no selectors used directly) found and filled Axial Length + Status by their visible labels without trouble - labels are enough, raw `#Element_...` ids aren't needed by a human/browser-tool user. But the table understates the form: on load a blocking modal ("No New Biometry Reports - ... Please generate a new event on your linked device first") appears whose only button (OK) navigates away rather than dismissing in place - work around it, don't click it. The create page also renders (disabled) Calculation and Selection elements (target refraction, lens/IOL power picks - "editing is not available"), plus Comments, Attachments, and read-only Visual Acuity/Near VA/Refraction reference panels - none of which are in the table above, which describes Measurement only.

### CVI create form (OphCoCvi, event_type_id 23) - written from develop view code, live-checked 2026-07-24

CVI create form is lengthy; all elements on default create are required - patient/clinical/consent/admin data collection for Certification of Visual Impairment case.

- Site #Element_OphCoCvi_EventInfo_site_id dropdown (empty option '- Please Select -'; populated from Site::model()->getListForCurrentInstitution()).
- Consultant in Charge #Element_OphCoCvi_EventInfo_consultant_in_charge_of_this_cvi_id dropdown of firms (filtered to current subspecialty, empty '- Please Select -').
- Demographics section: Title/Surname, Other names, Address, Postcode (split 2 fields), Email, Telephone, DOB, Sex (Gender dropdown), Ethnic Group (grouped dropdown with 'describe other' textarea shown conditionally), NHS/ID number, GP Name/Address/Postcode/Telephone, Local Authority Name/Address/Postcode/Telephone/Email.
- ClinicalInfo section: Examination date (date picker max today), Blind status radios (e.g. 'Severely sight impaired'/'Sight impaired'), Information booklet radios, ECLO radios, Visual Acuity type dropdown (Snellen/LogMAR), Best corrected VA dropdowns (Right/Left/Binocular), Best recorded checkboxes per eye, Field of Vision dropdown, Low Vision Service status, Disorder assignments grid (add/remove eyes/disorders, sections with comments), Diagnosis not covered textarea.
- Clerical Info section: Patient factors (multi-row dynamic yes/no/don't know radios with optional comments per factor), Preferred info format dropdown, Preferred format multi-select, Preferred communication textarea, Preferred language (Language dropdown + text override), Interpreter required radios (Yes/No).
- Consent section: Three radio booleans - consented_to_gp, consented_to_la, consented_to_rcop (each Yes/No/null).
- Save: Save button posts form to controller; on success redirects to /OphCoCvi/default/view/<event_id> to display the created CVI event.

**Gate behaviour (2026-07-24, develop, `OphCoCvi\DefaultController::actionCreate()`):** the standard create URL only renders the form above directly when the patient has fewer than `cvi_limit` (default 1) existing CVI events. Once that limit is met, `actionCreate` instead renders `select_event.php` - "This patient already has a CVI. Are you sure you want to create a new one?" plus a list of their existing CVIs - and its "Proceed to Create new CVI" button re-requests the same URL with `&createnewcvi=1` appended. That button is itself gated by `getManager()->canCreateEventForPatient()`: if the patient's existing CVI hasn't been issued yet, the button renders disabled (`href="#"`) and there is no way to reach the create form until that CVI is issued - this is a genuine business rule, not a probe/routing failure. First live check (patient 17891, who already had an unissued CVI) hit this gate and wrongly logged the form as "NOT REACHABLE"; a second check against a patient with zero existing CVI events (17885, ctx 5/ep 600580) loaded the real create form directly and matched the field table above field-for-field (Event Info, Demographics, Consent, Clinical Info, Clerical Info sections all present as described).

### Cat-PROM5 create form (OphOuCatprom5, event_type_id 42) - written from develop view code, live-checked 2026-07-24

Cat-PROM5 questionnaire with 6 mandatory vision-assessment questions; raw and Rasch scores auto-calculated and displayed as radio selections change.

- 'Questions 1-6' radio groups #CatProm5AnswerResult_<answer_id> (inline radios with 3-7 answer options each: Q1 'No/Some/Most/All of the time', Q2 'Not at all' through 'Extremely large amount', Q3 'Excellent' through 'Appalling', Q4 'Never' through 'All of the time', Q5 reading difficulty scale, Q6 questionnaire administrator; all required, none preselected).
- 'Raw Score (Absolute)' display #CatProm5EventResult_total_raw_score (hidden input, read-only display, auto-calculated from selected answers, defaults to 0).
- 'Rasch Score' display (read-only, auto-calculated from raw score via lookup table, defaults to 'Please answer questions 1-5').
- Save: Save button (level: save) POSTs event and redirects to /OphOuCatprom5/default/view/event_id.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** matched the live form, no corrections needed.

### Checklist create form (OphCoChecklist, event_type_id 50) - written from develop view code, live-checked 2026-07-24

Dynamic widget-based interface using AdderDialog to select and add checklist items; no traditional form fields.

- Hidden field 'Element ID' #Element_OphCoChecklist_id - stores element record id.
- 'Add checklists' button #add-checklists-btn (green plus icon) - opens AdderDialog overlay to select checklists.
- 'Checklist Category' filter dropdown in AdderDialog (header 'Checklist Category', id 'checklist-category-filter') - options include 'All' (default) and category names from ChecklistCategory table.
- 'Checklist Option' searchable selector in AdderDialog (header 'Checklist Option', id 'checklist-options') - displays ChecklistType.checklist_short_title, searchable via /OphCoChecklist/default/searchChecklistTypes.
- ChecklistEntries display area - renders selected checklist items; shows 'No checklists added' message when empty.
- Optional 'Cancel and remove Checklist' button - shown only if element is not required in UI; deletes event if no items added.
- Save: Save button submits form and redirects to /OphCoChecklist/default/view/{event_id}.

**Not a traditional create form, by design (2026-07-24, develop, `OphCoChecklist\DefaultController::actionCreate()`):** this event type has no blank-create view at all. `actionCreate` always calls `ChecklistManager::getTodayChecklistEvent()`, which finds-or-creates "today's" checklist event for the *patient* (by patient_id + `DATE(event_date) = CURDATE()`, not scoped to episode) and immediately redirects to `/OphCoChecklist/default/update/<event_id>` - so the redirect to an existing event's edit URL seen in the first check (event 3687026) was correct behaviour, not a routing failure: that event was simply already today's checklist for that patient. The redirect target lands in **View** mode by default (only the sidebar's `grouping-picker` select is visible then, which is what the first check saw and mistook for "the only field") - click the header 'Edit' tab/`#add-checklists-btn` to reach the interface this table describes. Confirmed on a patient with no checklist event yet today (17885, ctx 5/ep 600580): the create URL auto-created event 3687027 and redirected to its update page; clicking `#add-checklists-btn` opened the AdderDialog with a live search field (`[data-test="adder-search-input"]`, not the `#checklist-options` id in the table above - update that selector) matching the 'Checklist Option' searchable selector described above.

### Consent form create form (OphTrConsent, event_type_id 32) - written from develop view code, live-checked 2026-07-24

Consent form element type 32; type selection determines element visibility, creating per-type variants of the overall form - adult patient agreement type is default on fresh create for adults.

- 'Type' dropdown #Element_OphTrConsent_Type_type_id (required; options: Patient agreement, Parental agreement, Patient/parental agreement, Unable to consent; patient/parental auto-preselected based on age; disabled on update).
- 'Procedure' table: add/remove rows for procedures with right/left/both eye selector; 'Anaesthetic type' checkboxes below (from AnaestheticType table); procedure rows editable if unbooked, read-only if from booking.
- 'Leaflets' table: selected leaflets with remove icons per row; 'Add' button #add-leaflet-btn opens dialog filtering by category and leaflet name (searchable).
- 'Benefits' textarea #Element_OphTrConsent_BenefitsAndRisks_benefits and 'Material risks' textarea #Element_OphTrConsent_BenefitsAndRisks_risks (both required; TinyMCE rich-text with bullet-list preset; pre-filled from procedures, editable; 'Add additional risks' button offers dropdown list by subspecialty/institution).
- Save: Save as draft (form_id=clinical-create, posts to /OphTrConsent/default/create or /update/{event_id}); draft stays editable until printed/confirmed. 'Save and print' also available; no direct link pattern - lands on /OphTrConsent/default/view/{event_id}.

**Live check (2026-07-24, develop, ctx 13/ep 601038):** form loaded but some details above didn't match live - Benefits textarea #Element_OphTrConsent_BenefitsAndRisks_benefits not listed in visible fields (implemented as TinyMCE rich editor, not plain textarea); Material risks textarea #Element_OphTrConsent_BenefitsAndRisks_risks not listed in visible fields (implemented as TinyMCE rich editor, not plain textarea); Procedure table rows and eye selectors not initially visible (empty on form load; can be added via #js-add-proc-btn); Leaflets table rows not initially visible (empty on form load; can be added via #add-leaflet-btn).

### Correspondence create form (OphCoCorrespondence, event_type_id 26) - written from develop view code, live-checked 2026-07-24

Fresh create form shows a single Letter element with recipients table; internal referral fields appear conditionally if letter type is set to Internal Referral.

- 'Letter Type' dropdown #Element_ElementLetter_letter_type_id, empty option 'Select'; options from LetterType::model()->getActiveLetterTypes() - sample: 1 = 'General Letter', 2 = 'Internal Referral'
- 'Site' dropdown #Element_ElementLetter_site_id (required), empty option 'Select'; options from Site::model()->getLongListForCurrentInstitution()
- 'Letter Date' datePicker #Element_ElementLetter_date (required if not draft), maxDate=today, sample pre-filled with current date
- 'Visit Date' datePicker #Element_ElementLetter_clinic_date (optional), maxDate=today, null allowed
- 'Direct Line' textField #Element_ElementLetter_direct_line, 'Direct Fax' textField #Element_ElementLetter_fax (optional contact info)
- 'Salutation' textArea #Element_ElementLetter_introduction (required if not draft), 'Use Nickname' checkbox #Element_ElementLetter_use_nickname (required), 'Re' textArea #Element_ElementLetter_re, 'Body' textArea #Element_ElementLetter_body (large editor, required if not draft, max 1MB)
- 'Letter Templates' dropdown #macro_id (optional, triggers macro data population), 'Enclosures' - add/remove dynamic text fields #EnclosureItems[*]
- 'To' recipient row (mandatory): contact type/name/address/delivery methods; 'Cc' recipients (add-via-button) same fields; 'Approved by clinician' radioButtons #Element_ElementLetter_is_signed_off (conditional, if ask_correspondence_approval=on)
- Save: Save button redirects to /OphCoCorrespondence/default/view/<event_id> (saves event with letter element and document targets via Document::createNewDocSet); three actions: 'Save Draft' (draft=1), 'Save' (draft=0), 'Save and Print' (draft=0, sets print=1).

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - 'Body' textArea field (#Element_ElementLetter_body) not found in form; 'Enclosures' dynamic fields (#EnclosureItems[*]) not found in form; 'Approved by clinician' radioButtons (#Element_ElementLetter_is_signed_off) not found (E-Sign/PIN fields present instead); Date field IDs use _0 suffix and lack Element_ prefix: #ElementLetter_date_0, #ElementLetter_clinic_date_0 (written specified #Element_ElementLetter_date, #Element_ElementLetter_clinic_date); Some field IDs missing Element_ prefix: #ElementLetter_letter_type_id and #ElementLetter_site_id (written specified Element_ prefix).

### DNA sample create form (OphInDnasample, event_type_id 45) - written from develop view code, live-checked 2026-07-24

Single open element (DNA Sample). 'Consented By' pre-selects current user; 'Dna date' maxes at today; 'Volume' required for Blood type only (1-99 ml); '(if other, please specify)' appears conditional when Type is 'Other'.

- 'Type' dropdown #Element_OphInDnasample_Sample_type_id (required; empty option '- Select -'; populates from OphInDnasample_Sample_Type.name)
- 'Dna date' date picker #Element_OphInDnasample_Sample_blood_date (maxDate: 'today')
- 'Volume (Millilitres)' text field #Element_OphInDnasample_Sample_volume (required for Blood type only; validated 1-99)
- 'Destination if not IOO' text field #Element_OphInDnasample_Sample_destination (required if is_local=0)
- 'Consented By' dropdown #Element_OphInDnasample_Sample_consented_by (required; filtered to Genetics roles; current user pre-selected)
- 'Study(s)' multiSelectList #Element_OphInDnasample_Sample_studies (required; populates from GeneticsStudy.name)
- 'Comments' text field #Element_OphInDnasample_Sample_comments
- '(if other, please specify)' text field #Element_OphInDnasample_Sample_other_sample_type (conditional; shown when type_id='4' or validation error)
- Save: Save button posts form to /OphInDnasample/default/create; redirects to /OphInDnasample/default/view/<event_id> on success.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - 'Dna date' field selector is #Element_OphInDnasample_Sample_blood_date_0, not #Element_OphInDnasample_Sample_blood_date as written; 'Study(s)' field has no visible label in the form (shown as empty string), not labeled 'Study(s)' as written.

### Did Not Attend create form (OphCiDidNotAttend, event_type_id 41) - written from develop view code, live-checked 2026-07-24

- 'Comment' textarea #comments_comment (5 rows, autosize class; placeholder 'Enter comments here'; required).
- Save: Save button posts to /OphCiDidNotAttend/default/create, redirects to /OphCiDidNotAttend/default/view/{event_id} on success.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Textarea selector is #OEModule_OphCiDidNotAttend_models_Comments_comment, not #comments_comment; Extra field not mentioned in written table: grouping-picker select (name="grouping-picker").

### Document create form (OphCoDocument, event_type_id 40) - verified live v11.0.18 (2026-07)

The trigger path for the PDF/render temp-file bug family (`oe_pdf` stubs, `magick-*` pixel cache): upload a PDF, then build its page previews.

- 'Event Sub Type' dropdown `#Element_OphCoDocument_Document_event_sub_type` (empty option '-- Select --'; options from `ophcodocument_sub_types` - sample id 1 = "General").
- 'Upload' row radios: 'Single file' `#upload_single` (checked by default), 'Right/Left sides'.
- File input `#Document_single_document_row_id` (`.js-document-file-input`) is `display:none` - the probe's upload action works on it anyway. Drop-zone label: "Click to select file, DROP here or press Ctrl + V to paste".
- In-container test PDF (web-live ships ghostscript; one `showpage` per page): `gs -q -o /tmp/twopage.pdf -sDEVICE=pdfwrite -dDEVICEWIDTHPOINTS=300 -dDEVICEHEIGHTPOINTS=300 -c "showpage showpage"`.
- 'Save' `#et_save` -> lands on `/OphCoDocument/default/view/<event_id>` - take the id from the URL for endpoint work.
- Page previews build server-side (`createPdfPreviewImages()`): fire logged-in `GET /eventImage/getImageInfo?event_id=<id>` (the same path the lightning-viewer icon fires) and re-fire after a few seconds until the JSON shows `page_count`. Temp-leak pairing: `docker exec <stack>-web-1 sh -c 'ls -1 /tmp/oe_pdf* 2>/dev/null | wc -l'` before/after.

### Drug Administration create form (OphDrPGDPSD, event_type_id 48) - written from develop view code, live-checked 2026-07-24

Drug Administration uses widget-driven form with no traditional form_Element_* files; fields managed via JavaScript templates and dynamically rendered order blocks (presets or custom medications).

- Assignment selector: Add Preset Order (PSDs/PGDs from presets list) or Add medications button opens adder dialog for custom orders; each adds an order block with preset name and type badge.
- Drug/Medication table (per assignment): columns for Drug, Dose, Route, Administered By (user), Date, Time; rows represent individual medication entries within the assignment.
- Medication dropdown - populated from active medications; displays preferred term with allergy warning icon if patient allergic to medication.
- Dose numeric input + Dose Unit Term dropdown -Unit- (options: mg, ml, units, etc. from UNIT_OF_MEASURE attribute) + Route dropdown -Route- (options from medication_route table).
- Laterality radios (Right/Left/Both) render for ophthalmic/eye routes; Administered By (user) and administered Date/Time capture (optional, for recording when drug given); PIN signature widget if require_pin_for_drug_administration setting enabled.
- Comments textarea (hidden by default; Add comment button shows/hides); Cancel/Remove buttons (red) for managing or deleting assignments; must have at least one assignment recorded.
- Save: Save button submits form to /OphDrPGDPSD/default/create (POST) and lands at /OphDrPGDPSD/default/view/<event_id> on success; creates Drug Administration event with assignments and medications.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Comments textarea and 'Add comment' button not found - written table expects these to be visible on form (even if hidden by default, button should be present to toggle visibility).

### Examination create form (OphCiExamination, event_type_id 27) - written from develop view code, live-checked 2026-07-24

Cannot determine default elements without database query - workflow-driven form composition varies by subspecialty/context configuration.

- Form container: #examination-create with form ID 'examination-create' (BaseEventTypeCActiveForm)
- Save button #et_save ('Confirm & Save' level='save')
- Elements loaded dynamically from workflow's first step via renderOpenElements()
- Each element rendered from /views/default/form_Element_OphCiExamination_<Name>.php
- Element IDs follow pattern #Element_OphCiExamination_<ElementClass>_<attribute>
- Default elements depend on: subspecialty_id, episode_status_id, firm_id (workflow rule matching)
- Sample elements (structure only - not necessarily defaults): History (textarea description field), Visual Acuity (dropdown unit_id + complex controls), Management (textarea comments + adder button)
- Save: Redirect to /OphCiExamination/default/view/<event_id> after 'Confirm & Save' succeeds.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Element ID pattern uses OEModule_..._models_ prefix, not the bare Element_ prefix stated in written table; Sample elements (History, Visual Acuity, Management) not found in dumped form - only CCT element visible.

### Genetic Results create form (OphInGeneticresults, event_type_id 47) - written from develop view code, live-checked 2026-07-24

Single Test element with required genetic fields (Gene, Method, Effect, Homozygosity); method-specific validation (Exon required if Sanger); saves to /OphInGeneticresults/default/view/<event_id>.

- 'Gene' dropdown #Element_OphInGeneticresults_Test_gene_id (required; empty option '- Select -'; options from PedigreeGene sorted by name).
- 'Method' dropdown #Element_OphInGeneticresults_Test_method_id (required; empty option '- Select -'; options from Test_Method; Exon field required when set to 'Sanger').
- 'Effect' dropdown #Element_OphInGeneticresults_Test_effect_id (required; empty option '- Select -'; options from Test_Effect sorted by name).
- 'Homozygosity' radios #Element_OphInGeneticresults_Test_homo (required; options: 'Yes' [value 1], 'No' [value 0]).
- 'Exon', 'Base Change Type', 'Base Change', 'Amino Acid Change Type', 'Amino Acid Change', 'Genomic Coordinate', 'Genome Version', 'Gene Transcript', 'Assay' text/dropdown fields; all optional.
- 'Result' text, 'Result Date' date field, 'Comments' textarea; all optional and pre-filled from withdrawal source if available.
- Save: Save button triggers form POST to /OphInGeneticresults/default/create (validates required fields, then redirects to /OphInGeneticresults/default/view/<event_id>).

**Live check (2026-07-24, develop, ctx 8/ep 601039):** matched the live form, no corrections needed.

### Intravitreal injection create form (OphTrIntravitrealinjection, event_type_id 33) - written from develop view code, live-checked 2026-07-24

Treatment form requires both left and right eye selections via separate Treatment/Anaesthetic forms; treatment drug selection is disabled until injection management action is set (inject/inject-other); batch expiry date warnings when batch has expired.

- 'Site' dropdown #Element_OphTrIntravitrealinjection_Site_site_id; lists institution sites.
- 'Anaesthetic' left/right radios: type (topical/intracameral/retrobulbar/peribulbar) #Element_OphTrIntravitrealinjection_Anaesthetic_<side>_anaesthetictype_id, delivery method (subconjunctival/sub-Tenon's/other) #..._<side>_anaestheticdelivery_id, agent dropdown (lidocaine/xylocaine/other) #..._<side>_anaestheticagent_id.
- 'Treatment' drug dropdown #Element_OphTrIntravitrealinjection_Treatment_<side>_drug_id (disabled initially); populated when injection action selected.
- 'Treatment' number field #Element_OphTrIntravitrealinjection_Treatment_<side>_number (readonly, auto-calculated); override checkbox + reason textarea.
- 'Treatment' batch number #..._<side>_batch_number + expiry date #..._<side>_batch_expiry_date (date picker, warns if expired vs event date).
- 'Treatment' IOP lowering options (pre/post): checkboxes for required #..._<side>_pre_ioplowering_required + multi-select drug list #..._<side>_pre_ioploweringdrugs (conditional rows).
- 'Treatment' injection time #..._<side>_injection_time (time picker, defaults to now); injector name search + hidden id #..._<side>_injection_given_by_id.
- Save: Save button triggers form submit (id=clinical-create); lands at /OphTrIntravitrealinjection/default/view/<event_id>.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - grouping-picker select field present but not in written bullets; Anaesthetic section (type/delivery/agent radios and dropdowns) not visible in empty form; Treatment section (drug dropdown, number field, batch/expiry, IOP lowering, injection time, injector) not visible in empty form; Comments textarea and Checklist sections present but not described in written bullets.

### Lab Results create form (OphInLabResults, event_type_id 39) - written from develop view code, live-checked 2026-07-24

Lab Results type (default INR) is selected via a Details dropdown; the entry form then loads dynamically with time/result fields matching the lab type's field format.

- 'Type' dropdown #Element_OphInLabResults_Details_result_type_id, required (empty 'Select' option; populated from current institution's lab result types).
- 'Time of Recording' time field #Element_OphInLabResults_Entry_time, required (HH:mm format, pre-filled with current time; appears after type selection via AJAX).
- 'Result' number field #Element_OphInLabResults_Entry_result, required (step 0.1, min 0.1, max 50; validates against result type's min/max range; appears after type selection via AJAX).
- 'Unit' text field #Element_OphInLabResults_Entry_unit, optional (shown only if result type has show_units=true; default pre-filled from result type; may be read-only depending on allow_unit_change setting).
- 'Comment' textarea #Element_OphInLabResults_Entry_comment, optional (max 250 characters; appears after type selection via AJAX).
- Save: Save button posts form to /OphInLabResults/default/view/{event_id} after creating/updating the Lab Results event with selected type and result values.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Extra field present: 'grouping-picker' [name="grouping-picker"] <select:select-one> appears on the form but is not mentioned in the written field table.

### Laser create form (OphTrLaser, event_type_id 20) - written from develop view code, live-checked 2026-07-24

Treatment element uses side-selector with AdderDialog for procedures; fresh create shows inactive left/right eyes until activated.

- 'Site' dropdown #Element_OphTrLaser_Site_site_id, filtered by current institution; empty option 'Select'.
- 'Laser' dropdown #Element_OphTrLaser_Site_laser_id, updates based on selected site; empty option 'Select'.
- 'Laser operator' dropdown #Element_OphTrLaser_Site_operator_id, lists authorized users; empty option 'Select'.
- Treatment element: left/right eye sections; 'Add [side] side' link to activate each eye, then 'Add procedure' button (AdderDialog multi-select from ophtrlaser_laserprocedure list).
- When procedure added: loads procedure-specific element (Generic Procedure) with laser power/pulses/energy/lens/complications per side.
- Save: Save button (level 'save') submits form and redirects to /OphTrLaser/default/view/{event_id}.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - 'Add [side] side' link buttons appear empty (no text) in dump - written description implies visible link text; 'Add procedure' button not clearly visible as labeled button in dump output; Comments field (#Element_OphTrLaser_Comments_comments) present but not mentioned in written bullets; grouping-picker select field present but not mentioned in written bullets.

### Medical Device Usage Record create form (TrDeviceUsageRecord, event_type_id 51) - written from develop view code, live-checked 2026-07-24

Fresh create shows only SelectedEvent element; DeviceProcedure (which records device usage) is added via element menu and is required before save.

- Selected event - hidden input #Element_SelectedEvent_selected_event_id (class js-selected-event-id-field); displays JS-driven table of available past procedures from OphTrOperationnote; selection required.
- Laterality - hidden input #Element_SelectedEvent_selected_event_laterality (class js-selected-event-laterality-field); enum (right/left/both/unsided); synced via SelectedEventController when event row clicked; required.
- Procedure (DeviceProcedure element) - scannable device entry form; renders after add via '+' menu as required element; procedure_id + procedure_laterality required; device entries added via scan/manual UDI input.
- Device entries - per-device row (hidden medical_device_id, laterality, quantity int default 1; optional batch_number/serial_number/expiry_date/comment depending on device config).
- Device scanning - GS1DigitalLinkToolkit.js loaded; scan input or manual UDI button >= 8 chars; 'Find device by name' button provides fallback picker.
- Save: Save button 'Confirm & Save' POSTs form to /TrDeviceUsageRecord/default/save; redirects to /TrDeviceUsageRecord/default/view/{event_id} on success.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Selected event uses visible 'Select event' buttons instead of hidden input #Element_SelectedEvent_selected_event_id; Laterality field #Element_SelectedEvent_selected_event_laterality not found in form; Extra field 'grouping-picker' [name='grouping-picker'] not mentioned in written table.

### Message create form (OphCoMessaging, event_type_id 38) - written from develop view code, live-checked 2026-07-24

Messages are immutable after sending; form hides editor and shows read-only view for existing messages, dynamically populated from message type configuration with optional CC recipients.

- 'Send to' AutoCompleteSearch #fao-search; searches mailbox recipients by name; displays selected recipient in multi-select list; required (validates at least one primary recipient).
- 'Copy to' AutoCompleteSearch #copyto-search; optional CC recipients (configurable limit, default 5); multi-select list with remove icons; hidden fields store mailbox_id + primary_recipient=0 per recipient.
- 'Type' radio buttons #Element_OphCoMessaging_Message_message_type_id_<value>; options from OphCoMessaging_Message_MessageType sorted by display_order; required; default set from SettingMetadata.
- 'Priority' checkbox #Element_OphCoMessaging_Message_urgent; marks message urgent; unchecked by default; shows status-urgent icon when checked.
- 'Your Message' textarea #Element_OphCoMessaging_Message_message_text (class msg-write); placeholder 'Your Message...'; required; includes preview/edit toggle buttons on create.
- Sender mailbox hidden field #Element_OphCoMessaging_Message_sender_mailbox_id; auto-populated from logged-in user's personal mailbox.
- Save: Send message button (id et_save) submits form to /OphCoMessaging/default/create; on success creates Event and redirects to /OphCoMessaging/default/view/<event_id>.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Type radio buttons have longer ID prefix: Element_ vs OEModule_OphCoMessaging_models_Element_; Priority checkbox has longer ID prefix: Element_ vs OEModule_OphCoMessaging_models_Element_; Your Message textarea has longer ID prefix: Element_ vs OEModule_OphCoMessaging_models_Element_; Extra field not mentioned in table: grouping-picker select dropdown; Sender mailbox hidden field not visible in dump (may be hidden).

### Operation booking create form (OphTrOperationbooking, event_type_id 30) - written from develop view code, live-checked 2026-07-24

PreAssessment element conditionally omitted if no active pre-assessment types configured; requires diagnosis & operation details before scheduling.

- Listing diagnoses: 'Eye' radios (Left/Right/Both #listing-diagnoses-eye-id-radio-*), disorder display panel, hidden disorder list, '+' button opens search popup to add diagnoses.
- Procedures & laterality: 'Eye' hidden field #Element_OphTrOperationbooking_Operation_eye_id displays as icons; procedure widget (duration calculator, complexity radios: Standard/Intermediate/High), site dropdown #Element_OphTrOperationbooking_Operation_site_id.
- Consultation & decision: 'Consultant required' yes/no radios, 'Named consultant' dropdown #Element_OphTrOperationbooking_Operation_named_consultant_id (empty 'Select'); 'Decision date' datepicker (maxDate today); Priority radios.
- Anaesthetic & medication: 'Anaesthetic Type' checkboxes, 'Anaesthetic choice' radios (Flexible/Mandatory/Not applicable), optional 'Anaesthetist cover required' checkbox; 'Stop medication' yes/no + details textarea; 'Overnight stay required' radios.
- Scheduling: 'Schedule options' radios (values from OphTrOperationbooking_ScheduleOperation_Options table); 'Patient unavailables' table (start date, end date, reason dropdown) with add/remove buttons; special equipment yes/no + details.
- Admission & contact: 'Comments' textarea (placeholder 'Scheduling guidance for admissions team'), 'RTT comments' textarea; 'Patient booking contact number' textfield #Element_OphTrOperationbooking_ContactDetails_patient_booking_contact_number (pre-fills with patient.primary_phone); 'Doctor organising admission' autocomplete search.
- 'Pre-Assessment type' radios (values from active ophtroperationbooking_preassessment_type); 'Location' dropdown (conditionally visible if type.use_location=1).
- Save: Save button posts form (id 'et_save' or 'et_save_and_schedule_later'/'et_save_and_schedule'), redirects to /OphTrOperationbooking/default/view/<event_id>.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Listing diagnoses eye selector ID: written expects '#listing-diagnoses-eye-id-radio-*' but actual is '#Element_OphTrOperationbooking_Diagnosis_eye_id_*'; Named consultant dropdown not found in form (spec lists '#Element_OphTrOperationbooking_Operation_named_consultant_id'); Anaesthetic choice: spec lists 3 options (Flexible/Mandatory/Not applicable) but form shows only 2 radio inputs.

### Operation note create form (OphTrOperationnote, event_type_id 4) - written from develop view code, live-checked 2026-07-24

Default-required elements include Procedures, Anaesthetic type/delivery, Surgeon, Post-Op Drugs, and Comments; save creates event via /OphTrOperationnote/default/view.

- Procedures: eye radios (Right/Left/Both) + procedure selector widget - eye_id sets form visibility
- Anaesthetic Type: checkboxes for GA/LA/NoA/Sed; LA Delivery Methods hidden unless LA selected; Given by (Anaesthetist) radios; Agents multiselect; Complications multiselect
- Surgeon: dropdown #Element_OphTrOperationnote_Surgeon_surgeon_id ('-- Please select --' empty option); Personnel section renders dynamic rows with person-type selector
- Post-Op Drugs: multiselect list with add-dialog (Drug[] hidden inputs per selection)
- Post-Op Instructions textarea + Operation Comments textarea + auto-generate events checkboxes (Rx/GP letter/Optom); prefilled values from templates
- Save: Save button (#et_save) creates a new Operation note event; redirects to /OphTrOperationnote/default/view/{event_id}.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Procedures eye radios: Written says Right/Left/Both but only 2 options found (eye_id_1 and eye_id_2); Anaesthetic Type checkbox labels differ: written says GA/LA/NoA/Sed but live form shows GA/LA/Sedation/No Anaesthetic; Missing Anaesthetic fields: LA Delivery Methods, Given by (Anaesthetist) radios, Agents multiselect, and Complications multiselect not rendered on form; Missing Post-Op Drugs multiselect list and Drug[] hidden inputs in form dump; Personnel section: No person-type selector visible in rendered form, only search input fields shown.

### Phasing create form (OphCiPhasing, event_type_id 31) - written from develop view code, live-checked 2026-07-24

Split-sided element; both eyes toggle inactive by default on create; user must click 'Add side' to enable fields for each eye.

- 'Right/Left eyes' selector: #Element_OphCiPhasing_IntraocularPressure_eye_id (hidden field; toggled via 'Add/Remove side' UI; required).
- 'Instrument' dropdown: #Element_OphCiPhasing_IntraocularPressure_right_instrument_id (right eye), #Element_OphCiPhasing_IntraocularPressure_left_instrument_id (left eye); options from ophciphasing_instrument lookup; required if side active.
- 'Dilated' radio per side: Yes/No buttons (required if side active).
- 'Readings' table per side: Time (HH:MM, defaults to current time) and Value (mm Hg) text inputs; minimum one row required per active side.
- 'Comments' textarea: #Element_OphCiPhasing_IntraocularPressure_right_comments (right), #Element_OphCiPhasing_IntraocularPressure_left_comments (left); optional, placeholder 'Enter comments ...'
- Save: Save button submits form to /OphCiPhasing/default/create and redirects to /OphCiPhasing/default/view/&lt;event_id&gt;.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Right/Left eyes selector field ID not found - written expects #Element_OphCiPhasing_IntraocularPressure_eye_id, actual form has grouping-picker (different ID/name); Instrument, dilated, readings, and comments field IDs have full namespace prefix (OEModule_OphCiPhasing_models_Element_) not shown in written table - written IDs are shortened; Save URL uses capital D in route path (/OphCiPhasing/Default/create) vs written /OphCiPhasing/default/create.

### Prescription create form (OphDrPrescription, event_type_id 14) - written from develop view code, live-checked 2026-07-24

Prescription draft-saveable without signature; finalization requires prescriber signature; items table starts empty, populated via multiselect dialogs.

- Prescription items table: empty on create, add drugs via 'Add prescription' button (multiselect dialog with Common Systemic/Ophthalmic categories) or 'Add standard set' menu; supports search with brand-name toggle.
- 'Dose' textField with numeric validation (decimal allowed); 'Unit' dropdown initially empty (option '-Unit-').
- 'Route' dropdown from DM+D medication routes (empty '-- Select --'; required).
- 'Options' dropdown for route-specific laterality/laterality choices (conditional, visible only if route has laterality).
- 'Frequency' dropdown (empty '-- Select --'; required); 'Duration' dropdown (empty '-- Select --'; required).
- 'Dispense Condition' dropdown #Element_OphDrPrescription_Details_items_[key]_dispense_condition_id; 'Location' dropdown conditional on dispense condition.
- 'Comments' textArea #Element_OphDrPrescription_Details_comments (optional, 4 rows; expandable comment icon on each drug row).
- 'Prescriber Signature' section (Esign widget, table format; toggles action buttons: Save Draft hidden until signed, Save/Print buttons shown only when signed).
- Save: Save redirects to /OphDrPrescription/default/view/<event_id>; Save Draft button allows unsigned draft; Save/Print buttons appear only when prescription is signed (signature toggles button visibility via JS).

**Live check (2026-07-24, develop, ctx 8/ep 601039):** matched the live form, no corrections needed.

### Request Form create form (OphCoRequestForm, event_type_id 49) - written from develop view code, live-checked 2026-07-24

OphCoRequestForm uses form.io-based dynamic form rendering; on fresh create, only the form selector button appears until a form is chosen from the filtered catalog.

- 'Add Form' button #add-form-btn - AdderDialog filtered by category/institution/site/firm/subspecialty to select from active form catalog
- Form.io container #form-io-container - renders dynamic form fields after selection; shows 'No forms added' placeholder on initial load
- 'Form Definition ID' hidden field #form_io_definition_json - stores selected form's form_io_definition_id (required)
- 'Status' hidden field #form_status_id - stores form's initial status_id (required)
- 'Form Data' hidden field .js-form-io-input - stores user-entered form response data as JSON
- 'Administrator Notes' textarea (worklist edit mode only) - freeform admin annotations
- 'Edit Status' radio buttons (worklist edit mode only) - selects from form's configured status options
- Save: Save button (#create-form submit) creates event and Element_OphCoRequestForm record with form definition + user data; redirects to /OphCoRequestForm/default/view/{event_id}.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** matched the live form, no corrections needed.

### Therapy Application create form (OphCoTherapyapplication, event_type_id 35) - written from develop view code, live-checked 2026-07-24

Multiple elements split by left/right eye (separate inputs per side); ExceptionalCircumstances conditionally shown only if Patient Suitability is Non-Compliant; many fields conditional on system settings.

- Therapydiagnosis (split-eye): diagnosis1_id #Element_OphCoTherapyapplication_Therapydiagnosis_[left|right]_diagnosis1_id and diagnosis2_id hidden inputs per side; dynamically populated from diagnosis API/therapy mapping; eye_id hidden tracks active sides.
- PatientSuitability (split-eye): treatment_id dropdown #Element_OphCoTherapyapplication_PatientSuitability_[left|right]_treatment_id (required, populated from therapy treatments); angiogram_baseline_date picker (optional, hides if hide_therapy_app_radiography=on); is_historic checkbox (conditional on enable_historic_therapy_applications); consent_done_on_paper checkbox (conditional on allow_therapy_application_consent_on_paper); comments textarea per side.
- DecisionTree (nested in PatientSuitability): dynamically generated multi-field compliance assessment embedded per side via partial; template-driven JavaScript initialization.
- RelativeContraindications (global): three yes/no radioButtons - cerebrovascular_accident #Element_OphCoTherapyapplication_RelativeContraindications_cerebrovascular_accident, ischaemic_attack, myocardial_infarction.
- MrServiceInformation (global): consultant_id dropdown #Element_OphCoTherapyapplication_MrServiceInformation_consultant_id (MR subspecialty firms), site_id dropdown (current institution), patient_sharedata_consent checkbox.
- ExceptionalCircumstances (split-eye): multi-field form (standard_intervention_exists yes/no, intervention_id radio buttons, patient_factors yes/no, patient_different/gain/expectations textareas, start_period_id dropdown, filecollections multi-select); conditionally shown/disabled per side based on PatientSuitability compliance; conditional sub-fields include deviationreasons multi-select, urgency_reason textarea, and past intervention tables.
- Save: Save posts to OphCoTherapyapplication/default/create (form id 'clinical-create'), validates all required elements, creates Event with type_id 35, then redirects to /OphCoTherapyapplication/default/view/{event_id}.

**Live check (2026-07-24, develop, ctx 8/ep 601039):** form loaded but some details above didn't match live - Therapydiagnosis: diagnosis2_id fields not found (only diagnosis1_id present); PatientSuitability: is_historic checkbox not found; PatientSuitability: consent_done_on_paper checkbox not found; ExceptionalCircumstances: additional fields not mentioned in written table (standard_intervention_id select, standard_previous radio, condition_rare radio, incidence textarea, patient_factor_details textarea, description textarea); ExceptionalCircumstances: past intervention tables mentioned but no table elements captured.
