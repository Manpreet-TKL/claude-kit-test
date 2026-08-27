# OpenEyes bugs found during the documentation campaign

Environment: snail-web-1, develop @ 798f9c0de2, sample DB, admin/admin.
Format: BUG-NNN — area, route, repro, expected/actual, evidence, severity.

---

## BUG-001 — Core: single-page PDF render 500s (DocumentRenderServicePuppeteer)

- **Area**: core OpenEyes (outside the special modules), affects OeDocumentation's
  single-page "Generate PDF" pathway and any caller of the puppeteer render service
  that leaves `documents=1` without populating `$patient_names`.
- **Route**: `/OeDocumentation/default/generatePdf/...` (single page), backed by
  `protected/components/DocumentRenderServicePuppeteer.php`.
- **Repro**: logged in as admin, request a single documentation page as PDF.
- **Expected**: PDF returned.
- **Actual**: HTTP 500 — `Undefined array key -1` at
  `DocumentRenderServicePuppeteer.php:128`; hit whenever the caller does not
  populate `$patient_names` but `documents=1`.
- **Evidence**: reproduced 2026-07-04 during Phase 1b export verification
  (the action code itself was untouched and unchanged in git).
- **Severity**: medium (500 on a user-facing export path; workaround = use the
  new OeDocBuilder-based export scopes, which do not use this service).
- **Status**: open, not fixed (core repo is out of campaign scope).

---

## BUG-002 — OphTrLaser: pulse-duration cross-field validation copy-paste bug

- **Area**: OphTrLaser module, Generic Procedure element
  (`Element_OphTrLaser_Procedure`), create/edit Laser event.
- **Route**: `/OphTrLaser/default/create` and `update` (validation on save).
- **Repro**: inspect `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php`
  `rules()` — pulse-duration from/to cross-field checks.
- **Expected**: `left_pulse_duration_from` validated against `left_pulse_duration_to`;
  `right_pulse_duration_from` against `right_pulse_duration_to`, each exactly once.
- **Actual**: `left_pulse_duration_from` gets **no** `fromRangeValidation` rule at all;
  `right_pulse_duration_from` gets it **twice** — once wrongly compared against
  `left_pulse_duration_to`, once against itself.
- **Evidence**: found 2026-07-04 by the Phase 2 adversarial verify agent while
  tracing Laser documentation claims; plain numeric range rules are separate and
  correct, so documented ranges are unaffected.
- **Severity**: low (a left-eye from/to inversion saves without complaint; the
  right eye can be wrongly rejected based on the left eye's value).
- **Status**: open, not fixed (module code change is out of documentation scope).

---

## BUG-003 — Cross-module widget naming: ExaminationChecklistElement reused outside Examination

- **Area**: OphCiExamination widget `ExaminationChecklistElement`
  (`OEModule\OphCiExamination\widgets\ExaminationChecklistElement`), consumed
  as-is by OphTrLaser and OphTrIntravitrealinjection checklist elements.
- **Route**: any Laser or Intravitreal injection event containing the Checklist element.
- **Repro**: inspect the widget class chain (`ExaminationChecklistElement` →
  `ModuleChecklistElement` → `ChecklistElement`) and `getNewElement()`.
- **Expected**: a module-neutral widget name, and a fallback element class
  appropriate to the calling module.
- **Actual**: the Examination-named widget is hardcoded for non-Examination event
  types, and `getNewElement()`'s Examination-specific fallback class is dead code
  in those paths. Functionally fine today; a maintainability trap.
- **Evidence**: found 2026-07-04 while documenting the Laser Checklist element
  (which is functional — it anchors a shared, day-scoped `Element_OphCoChecklist`).
- **Severity**: cosmetic (naming/maintainability only; no user-facing defect).
- **Status**: open, not fixed (refactor is out of documentation scope).

---

## BUG-004 — OphTrLaser: mJ view partial hides pulse duration and spot size

- **Area**: OphTrLaser module, Generic Procedure element view mode.
- **Route**: `/OphTrLaser/default/view/<event_id>` for an event whose Site laser
  has `measure_in_mj = 1`.
- **Repro**: compare
  `views/default/view_Element_OphTrLaser_Procedure_side_measured_in_mj.php`
  (renders only the "Laser Energy Range (mJ)" row) with
  `..._measured_in_mw.php` (also renders "Pulse Duration Range" and "Spot Size");
  `view_Element_OphTrLaser_Procedure_side.php` renders exactly one of the two.
- **Expected**: pulse duration and spot size recorded on the edit form are shown
  on the view screen regardless of the laser's measurement unit.
- **Actual**: for an mJ-measured laser, saved pulse duration and spot size are
  silently absent from the view screen (edit form unaffected).
- **Evidence**: found 2026-07-04 by the Phase 2 glossary verification pass;
  deterministic code path — no live repro available because the sample DB has no
  Generic Procedure instances (see the generic-procedure evidence pack).
- **Severity**: low-medium (recorded clinical values not displayed in read mode).
- **Status**: open, not fixed (module code change is out of documentation scope).
---

## BUG-005 — OphGeneric: DeviceInformation::search() references nonexistent attribute

- **Area**: OphGeneric module, `DeviceInformation` model.
- **Route**: none user-facing today (search() is the admin/grid search path).
- **Repro**: inspect `protected/modules/OphGeneric/models/DeviceInformation.php:108`
  — `search()` compares against `$this->comment`, an attribute that does not
  exist on the model.
- **Expected**: search criteria built only from real attributes.
- **Actual**: dead/copy-pasted comparison against a nonexistent attribute;
  would error if that code path were ever exercised.
- **Evidence**: found 2026-07-04 by the Phase 3 device-information S2 drafter
  while tracing element fields.
- **Severity**: low (latent; no live caller found).
- **Status**: open, not fixed (module code change is out of documentation scope).

---

## BUG-006 — Core data: orphaned event_type row for removed OphInHfa module

- **Area**: sample DB `event_type` table vs shipped modules.
- **Route**: none — the row is invisible in the Add Event dialog because
  `EventType::getEventTypeModules()` filters on registered modules.
- **Repro**: `SELECT id, class_name, can_be_created_manually FROM event_type
  WHERE id = 8` → `OphInHfa`, `can_be_created_manually = 1`; but
  `protected/modules/OphInHfa` does not exist in the container (nor do the
  other 18 legacy imaging/clerical modules with event_type rows: OphCiRefraction,
  OphImOct, OphCoLetterin, OphTrOperation, OphCiAnaesth, etc.).
- **Expected**: event_type rows either shipped with module code or flagged
  inactive.
- **Actual**: 19 orphaned event_type rows for modules absent from the build;
  harmless at runtime but misleading for integrators reading the DB.
- **Evidence**: found 2026-07-04 during Wave 4 scaffolding (module-presence
  census across all 19 single-page groups).
- **Severity**: cosmetic/data hygiene.
- **Status**: open, not fixed (core repo/sample-data change is out of scope).

## BUG-007: Consent form Type default ignores configurable child age limit
- **Where**: `OphTrConsent/controllers/DefaultController.php:204-224`
  (`setElementDefaultOptions_Element_OphTrConsent_Type`) vs
  `OphTrConsent/models/Element_OphTrConsent_Type::setDefaultOptions` (131-146) and
  `Patient::isChild()` (`protected/models/Patient.php:691-699`).
- **Repro**: set `child_age_limit` to any non-default value; create a Consent form (no template)
  for a patient whose age falls between the configured limit and 16.
- **Expected**: the Type default follows `Patient::isChild()` / `child_age_limit`, as the model's
  `setDefaultOptions()` implements.
- **Actual**: the controller hook runs after the model default (via
  `BaseEventTypeController::setElementDefaultOptions`, 585-594) and unconditionally overwrites
  `type_id` using a hardcoded `<= 16` check, so the configurable param has no effect. Boundary
  also disagrees: `isChild()` uses strict `<` (16-year-old = adult at default limit), controller
  uses `<=` (16-year-old = child).
- **Severity**: low/medium — wrong default consent type pre-selected for installations that
  changed `child_age_limit`; clinician can still change it manually.
- **Found by**: Phase 3 consent-form S2 draft, verified by orchestrator against container source
  2026-07-04.

## BUG-006 addendum: Anaesthetic Satisfaction Audit module also absent
- `OphOuAnaestheticsatisfactionaudit` is a 20th module directory absent from this container,
  but unlike the other 19 it still has element_type rows (322, 323, 324, 326; note the id 325
  gap) and `event_type` 28 has `can_be_created_manually = 1`, so the Add Event matrix lists it
  while the dialog silently drops it (module-registration filter). Zero events DB-wide.

## BUG-008: Consent Patient Questions label key typo
- Module/file: OphTrConsent, `models/Element_OphTrConsent_PatientQuestions.php` (attributeLabels, ~line 94)
- The labels array uses key `'refused procedures'` (with a space) but the attribute is `refused_procedures`, so the custom label "Patient refuses some procedures" is never used; Yii falls back to an auto-generated label.
- Verified: yes (container source read directly).
- Severity: low (cosmetic).

## BUG-009: Consent Extra Procedures picker ignores subspecialty/active filtering
- Module/files: OphTrConsent, `models/OphTrConsent_Extra_Procedure.php`, `controllers/ExtraProceduresController.php:35`
- The autocomplete uses `getList($term)`: no subspecialty join, no active-flag filter — every extra procedure matches by term regardless of the admin subspecialty assignments (which the admin UI implies apply). The caller also passes a second argument (`@$_GET['restrict']`) that `getList()` does not accept, so booked/unbooked restriction is silently dropped. The alternative `getListBySubspecialty()` is never called and is itself broken (references undefined SQL alias `proc.active`/`proc.term` — would error if ever used).
- Verified: yes (source read; caller grep).
- Severity: medium (inactive or out-of-subspecialty procedures selectable on consent).

## BUG-010: Operation Note Comments, Location and Biometry elements render nothing on a saved note
- Module: OphTrOperationnote. `view_Element_OphTrOperationnote_Comments.php` and `view_Element_OphTrOperationnote_SiteTheatre.php` contain only a licence header (verified — no output), and `Element_OpNote::getContainer_view_view()` returns false, so a saved note shows no section for either element. Comments data resurfaces only inside the Per-operative drugs view block; Site/Theatre only via the page title bar in view mode (not in print). Biometry's view is deliberately empty too, so it never displays in view or print despite being looped into print. Related: `DefaultController::renderOpenElements()` docblock claims the event date renders as part of Location — false.
- Verified: partially by me (empty views + container bypass confirmed); behaviour trace agent-verified.
- Severity: low/medium — possibly intentional, but data is effectively invisible and the docblock is wrong.

## BUG-011: Op-note CXL Dresden protocol auto-fill silently fails
- Module/file: OphTrOperationnote, `views/default/form_Element_OphTrOperationnote_CXL.php` (`protocolSelection()`, ~lines 417-462)
- Choosing the Dresden protocol tries to set Soak duration "30 minutes" and Total exposure time "30", but neither value exists in the corresponding dropdowns (options cap at 29), so those two fields stay unset with no warning.
- Verified: partially (JS sets the values — confirmed; dropdown cap agent-verified).
- Severity: low.

## BUG-012: GlaucomaTube view hardcodes "Incision site: Corneal"
- Module/file: OphTrOperationnote, `views/default/view_Element_OphTrOperationnote_GlaucomaTube.php:50`
- The read-only view prints a fixed "Corneal" data value with no backing model column — every saved Glaucoma tube note claims a corneal incision site regardless of reality.
- Verified: yes (line 50 read directly).
- Severity: medium (clinically misleading display).

## BUG-013: Genetics/DNA dead-code cluster
- Modules: OphInDnasample / OphInDnaextraction / OphInGeneticresults.
- (a) `OphInDnasample\DefaultController::volumeRemaining()` has no callers. (b) `form_Element_OphInDnaextraction_DnaTests.php` computes `$disabled = !checkAccess('TaskEditGeneticsWithdrawals')` then immediately overwrites it; neither `actionAddTransaction()` nor `actionUpdateDnaTests()` checks the permission — it looks enforced but is a no-op. (c) `et_ophindnaextraction_dnaextraction.extracted_by_text` column is unreferenced. (d) `Element_OphInGeneticresults_Test.withdrawal_source_id` is fully wired at model/DB level (FK, relation, commented-out required rule) but no form field exists anywhere.
- Verified: agent-reported with citations; (d) spot-checked (no view references found).
- Severity: low overall; (b) worth a look — a permission that appears to gate withdrawals does nothing.

## BUG-014 (SUSPECTED, unverified): DNA "automated event" banner may render empty for PAS-created Did Not Attend events
- `Event::afterFind()` unconditionally `json_decode()`s `automated_source`; PASAPI's Did Not Attend creation stores a plain string, which would decode to null and blank `automatedText()` output after the first load. No sample events exist to verify live.
- Severity: unknown/low.

## BUG-015: Diagnoses event type is unroutable by class name
- `event_type.class_name` = `OphCiDiagnoses`, but the module is registered as `Diagnoses` (core config) and `protected/modules/Diagnoses/` has no DefaultController, so `/OphCiDiagnoses/default/view/{id}` cannot resolve. The auto-created Diagnoses record element (element_type 565, event_type 52) attaches to the triggering event's id and is never rendered on any screen of its own.
- Verified: agent source-trace (module registration + missing controller confirmed by find).
- Severity: low/medium — event type exists in the DB but has no viewable route.

## BUG-016: CVI Clinical info "Best recorded right VA" checkbox displays the LEFT eye's stored value
- Module/file: OphCoCvi, `views/default/form_Element_OphCoCvi_ClinicalInfo.php:220`
- The right-eye checkbox posts to `best_recorded_right_va` but its rendered checked-state is bound to `$element->best_recorded_left_va` (copy-paste error; the left checkbox at :253 is bound correctly). Effect: on edit, the right checkbox shows the LEFT flag's saved state — a saved right tick appears lost, and a left tick appears duplicated onto the right, until the user corrects it (or unknowingly re-saves wrong data).
- Verified: yes (line read directly in container).
- Severity: medium (edit form silently misrepresents saved clinical data and can corrupt it on re-save).

## BUG-017 (SUSPECTED, dead code): CVI pre-Esign signature remnants
- Module: OphCoCvi. `Element_OphCoCvi_ClinicalInfo::isSigned()` (~:703-707), `consultant_signature_file_id`, `main_cause_pdf_id`, and `OphCoCvi_Manager::saveUserSignature()` (~:1105-1116) appear to be leftovers from the pre-Esign signature flow with no callers (`saveUserSignature` grep: zero call sites). Caveat: the Esign capture widget has its own same-named `isSigned()` which IS live — the dead one is the ClinicalInfo model method.
- Verified: agent-reported; saveUserSignature zero-caller grep re-run by orchestrator.
- Severity: low (cleanup).
- Related quirk (same batch, documented on page as caveat, not asserted as bug): `best_corrected_right_va_list` is required at issue but the left/binocular equivalents are not (`Element_OphCoCvi_ClinicalInfo.php:107-111`).

## BUG-018 (SUSPECTED): Phasing readings required-by-rule yet zero readings exist across all sample events
- Module: OphCiPhasing. `Element_OphCiPhasing_IntraocularPressure::rules()` (~:86-87) lists `right_readings`/`left_readings` in `requiredIfSide` (and also as `safe`), implying at least one timed reading per active eye — yet `ophciphasing_reading` has 0 rows against 38 saved IOP elements, and the form always renders one non-removable blank reading row. Either the validator never fires for the relation attribute (rule is dead) or the sample data pre-dates it; either way rule and data disagree.
- Verified: rule text + row counts (0/38) confirmed by orchestrator; runtime save behaviour not tested.
- Severity: low.

## BUG-019: Operation checklists calls the Lab Results module API with no null-guard
- Module/files: OphTrOperationchecklists — `form_Element_OphTrOperationchecklists_Admission.php:24`, `view_Element_OphTrOperationchecklists_Admission.php:22`, `form/view_OphTrOperationchecklists_Observations.php` (same pattern).
- `Yii::app()->moduleAPI->get('OphInLabResults')` result is used immediately (`$api->getLabResultTypeResult(...)`) with no falsy check; if OphInLabResults is ever disabled, every Admission/Observations render fatals. Latent in this build (module present).
- Verified: yes (lines read directly).
- Severity: low/medium (crash risk on config change).

## BUG-020: Operation checklists event type has no reachable create path in-app
- Zero references to the module's create route exist outside the module itself (whole-tree grep, confirmed); the event can only be started by hand-typed URL, which without a booking reference lands on a bare "Please select booking" screen. Related dead code: only the Admission element enforces its DB `mandatory` question flag — the flag on every other element (e.g. Discharge Q44) is unenforced.
- Verified: create-path grep re-run by orchestrator; mandatory-flag trace agent-reported (zero "mandatory" hits in controller/module.js).
- Severity: medium if the feature is meant to be live; possibly intentional (unfinished feature).

## BUG-021: token-based action extraction loses actions after string interpolation (SUSPECTED, upstream tooling)
- **Where**: OpenEyes `UrlBenchmarkCommand` — the token-walking action extractor that OeDocumentation's `RouteReflector::extractActionIdsFromFile()` was ported from verbatim. Not present in this container (develop @ 798f9c0de2; `find protected -name UrlBenchmarkCommand.php` = empty), so confirmed only in the port, suspected wherever the original lives.
- **Repro (proven in the port)**: any controller containing `"{$var}"` or `"${var}"` — e.g. core `PatientController.php:267` (`"{$hie_url}"`), `PatientTicketing/DefaultController.php:239` (`{$sort_by_order}`). `token_get_all()` emits the interpolation open as T_CURLY_OPEN / T_DOLLAR_OPEN_CURLY_BRACES (array tokens) but the matching close as a raw `'}'` string token; counting only raw string braces makes depth drift negative, so every `actionX()` after the first interpolation in the file is never matched.
- **Expected**: all public actionX methods enumerated. **Actual**: silent truncation — before the fix, discovery reflected 947 candidate routes; after counting the interpolation opens, 1746. Whole controllers (PatientController after line 267, PatientTicketing) lost most of their actions.
- **Evidence**: fix + probe in OeDocumentation `components/RouteReflector.php` (T_CURLY_OPEN/T_DOLLAR_OPEN_CURLY_BRACES now increment braceDepth); probe shows patient/oEscape, patient/summary, patient/lightningViewer, PatientTicketing routes reflected only after the fix.
- **Severity**: medium for any tool built on this extractor (benchmarks/coverage silently skip most of the app); no end-user impact.

## BUG-022: IVI Post Injection Examination read-only view misrenders two recorded answers (CONFIRMED)
- **Route**: /OphTrIntravitrealinjection/default/view/{id}, Post Injection Examination element (view fields partial, per-side table).
- **Defect A**: the Paracentesis Performed row gets `style="display:none;"` whenever finger_count OR cra_perfused is truthy — but the form always shows the question and the model requires it per treated side (requiredIfSide), so a recorded paracentesis answer (even Yes, with performer) is invisible in the saved view. Verified in the partial: `<tr <?php echo finger_count || cra_perfused ? style display:none : '' ?>`.
- **Defect B**: the IOP row renders a recorded answer as an instruction. Model label is "IOP Checked?" (historical yes/no, with requiredIfIopChecked instrument+reading), but the view prints "IOP should be checked - Please add a Phasing event." for Yes and "IOP does not need to be checked." for No — contradicting what was recorded.
- **Repro**: record finger_count=Yes plus paracentesis=Yes on either eye, save, view the event: paracentesis row absent. Any saved element: IOP row shows instructional text instead of the recorded fact.
- **Expected**: view shows every recorded answer; IOP row states what was recorded. **Actual**: as above.
- **Severity**: medium (A hides recorded clinical data in the canonical read view; B misstates it). Doc page notes the read-view quirk without asserting a defect.

## BUG-023: Examination Observations widget imports a non-existent element class (CONFIRMED code, SUSPECTED runtime)
- **Where**: OphCiExamination widget Observations — imports OEModule\OphCiExamination\models\Observations (aliased ObservationsElement) and returns `new ObservationsElement()` from getNewElement(). No models/Observations class exists in the module (models dir listing verified; the real element is Element_OphCiExamination_Observations).
- **Impact**: fatal "class not found" if getNewElement() ever fires (widget instantiated without an element). Controllers normally pass the element, which is why it hasn't surfaced.
- **Severity**: low-medium latent crash.

## BUG-024: Examination DrivingSafety widget calls an undefined parent method (CONFIRMED code, SUSPECTED runtime)
- **Where**: OphCiExamination widget DrivingSafety — getNewElement() is `return parent::DrivingSafetyElement();`. DrivingSafetyElement is a class-alias import, not a parent method; the parent widget class has no such method, so this throws "undefined method" if reached.
- **Impact**: same latent-path class as BUG-023; likely a copy-paste slip for `new DrivingSafetyElement()`.
- **Severity**: low-medium latent crash.

## BUG-025: Synoptophore reading popup and model disagree on valid ranges (CONFIRMED)
- **Route**: Examination event, Synoptophore element (add/edit reading per gaze position).
- **Repro A**: in the reading popup pick a horizontal angle between 41 and 60 (JS offers -60..60); save — the model only accepts -40..40, so the save is rejected with "is invalid" after the fact.
- **Repro B**: torsion — the JS picker caps at 40 while the model (and its documented valid range) accepts 0..60, so model-valid torsion values 41–60 can never be entered through the UI.
- **Expected**: picker offers exactly what the model accepts. **Actual**: picker over-offers horizontal angle and under-offers torsion (vertical power 0..50 is consistent on both sides).
- **Severity**: medium — user-facing rejection of values the UI itself offered.

## BUG-026: HeadPosture search scenario references non-existent at_risk attribute (CONFIRMED)
- **Where**: Examination Corrective Head Posture element model — rules include `['id, event_id, comments, at_risk', 'safe', 'on' => 'search']` but the model's attributes are tilt/turn/chin/comments; no at_risk column, label or docblock anywhere. Looks copy-pasted from Post-Op Diplopia Risk (which does have at_risk).
- **Impact**: none at runtime today (safe-on-search only); dead reference.
- **Severity**: low.

## BUG-027: Keratometry "Back K1"/"Back K2" fields are mislabeled/mis-validated (CONFIRMED)
- **Where**: Examination Corneal Tomography (Keratometry element). The attributes named axis_anterior_k1_value / axis_anterior_k2_value carry the on-screen labels "Back K1" / "Back K2" and are validated numerical min -150 max -1 (negative-only).
- **Why wrong**: the three signals disagree — the attribute name says anterior axis, the label says posterior (back) K, and the range (negative only, down to -150) fits neither a K reading in dioptres (~+40 to +50, and a genuinely separate Posterior K2 field already exists) nor an axis in degrees (0–180). Any plausible real value entered as a positive number is rejected.
- **Repro**: Examination > Corneal Tomography, enter a positive value in Back K1 → validation error "is invalid".
- **Severity**: medium — the field cannot accept clinically plausible input.

## BUG-028: Keratoconus Monitoring has two fields impossible to set from the UI (CONFIRMED)
- **Where**: Examination Keratoconus Monitoring (CXL History element). trans_prk_value (left/right) is in the model's rules with label "Trans PRK", and ocular_surface_disease_id is a DB column in the docblock (not even in rules) — but zero view or widget files reference either (module-wide grep of views/ and widgets/ = no hits).
- **Impact**: dead columns; "Trans PRK" data can never be recorded despite being modelled and labeled.
- **Severity**: low-medium (silent feature gap, no crash).

## BUG-029: Glaucoma Current Management Plan shows the RIGHT eye's IOP in BOTH eye panels (CONFIRMED)
- **Where**: Examination Glaucoma Current Management Plan element edit form (`views/default/form_Element_OphCiExamination_CurrentManagementPlan.php:89`). The per-eye panel markup is generated inside `foreach (['left' => 'right', 'right' => 'left'] as $side => $eye)`, but the IOP line is hardcoded `$iop['rightIOP']` — never `$iop[$eye . 'IOP']`.
- **Impact**: the LEFT eye panel displays the right eye's latest IOP reading, mmHg value and all. Clinically misleading display in a glaucoma workflow (read-only informational line, not stored data).
- **Repro**: Examination event with an Intraocular Pressure element recording different left/right values, then add Glaucoma Current Management Plan → both panels show the right value.
- **Severity**: medium-high — user-visible wrong clinical value.

## BUG-030: Current Management Plan search() contains syntactically-mangled hyphen expressions (CONFIRMED)
- **Where**: `Element_OphCiExamination_CurrentManagementPlan::search()` — `$criteria->compare('right_drop-related_prob_id', $this->drop - right_related_prob_id)` and `$criteria->compare('left_drop-related_prob_id', $this->left_drop - related_prob_id)`. The DB columns genuinely contain hyphens (`left_drop-related_prob_id`), which PHP cannot express as bare property arithmetic: these parse as subtraction of undefined constants from undefined properties.
- **Impact**: search() fatals if ever invoked; dormant today (element search() boilerplate is unused at runtime).
- **Severity**: low (dead code), but the hyphenated column naming is the root cause and bites any future code touching these attributes.

## BUG-031: Cataract Surgical Management search() compares a non-existent description attribute (CONFIRMED)
- **Where**: `Element_OphCiExamination_CataractSurgicalManagement::search()` line 228 — `$criteria->compare('description', $this->description)`. The table has no `description` column (verified via SHOW COLUMNS) and neither the model nor its parents define a getter; the model only has a `__toString()` that builds a description string.
- **Impact**: search() throws "property not defined" if invoked; dormant boilerplate, same class as BUG-026.
- **Severity**: low.

## BUG-032: Lacrimal element missing the empty-discard exemption its sibling eyedraw elements have (CONFIRMED)
- **Where**: `models/Lacrimal.php` has no `$exclude_element_from_empty_discard_check`, while the equally eyedraw-based MedicalLids.php:45 and SurgicalLids.php:45 (and Fundus, OpticDisc, PosteriorPole) all set it true. Eyedraw default content looks "empty" to the save-time discard check (`assets/js/ExaminationSaveHandler.js`, gated on the `close_incomplete_exam_elements` setting — on in this sample DB).
- **Impact**: an added-but-untouched Lacrimal element triggers the "discard empty elements?" prompt while identical untouched Lids elements are silently kept — inconsistent save behaviour across the adnexal-region trio.
- **Severity**: low-medium (workflow inconsistency, no data loss).

## BUG-033: DNA extraction date field crashes save on non-NHS date format instead of validating (CONFIRMED)
- **Where**: `form_Element_OphInDnaextraction_DnaExtraction.php:51` uses the legacy `$form->datePicker()` widget expecting `j M Y` ("5 Jul 2026"). `Helper::convertNHS2MySQL()` (`protected/components/Helper.php:52-76`) only converts strings matching `NHS_DATE_REGEX` (`/^\d{1,2} \w{3} \d{4}$/`) and silently passes anything else through unchanged; no client- or server-side validation rejects other formats.
- **Impact**: typing e.g. "05-Jul-2026" produces a hard MySQL `SQLSTATE[22007] Incorrect date value` exception (surfaced at `BaseEventTypeController.php:1999`) instead of a field validation error.
- **Repro**: DNA extraction create form, Extracted Date = "05-Jul-2026", Save.
- **Severity**: medium (user-facing crash on a plausible input; recoverable, no data loss).

## BUG-034: Genetic Results optional result_date crashes save when left empty (CONFIRMED)
- **Where**: `Element_OphInGeneticresults_Test::rules()` (`modules/OphInGeneticresults/models/Element_OphInGeneticresults_Test.php:50-55`) lists `result_date` only as `safe` — genuinely optional. The form renders it as a native `<input type="date">`; an untouched input posts an empty string which is inserted verbatim into the DATE column: `SQLSTATE[22007] Incorrect date value: ''`. Unlike the legacy DatePicker path there is no empty→NULL (or empty→today) conversion.
- **Impact**: saving a Genetic Results event without a result date — a documented-optional field — crashes instead of saving with NULL.
- **Repro**: Genetic Results create form, fill required fields, leave Result date empty, Save.
- **Severity**: medium (crash on the default state of an optional field).

## BUG-035: DnaTests form computes a permission flag then discards it (CONFIRMED)
- **Where**: `form_Element_OphInDnaextraction_DnaTests.php:70-71` and `75-76` — `$disabled = !$this->checkAccess('TaskEditGeneticsWithdrawals');` is immediately shadowed: the `renderPartial()` on the next line passes `'disabled' => ($this->action->id === 'view')`. Neither `DefaultController::actionAddTransaction()` nor `actionUpdateDnaTests()` enforces `TaskEditGeneticsWithdrawals` (module-wide grep: no controller references).
- **Impact**: the withdrawals-editing permission is never enforced anywhere — vestigial gating; any user who can edit the event can edit DNA tests/withdrawals.
- **Severity**: low-medium (dead access-control code; real enforcement gap only matters where the role model intends to restrict withdrawals).

## BUG-036: PASAPI-created Did Not Attend events store a plain string in automated_source that afterFind decodes to null (CONFIRMED)
- **Where**: `modules/PASAPI/resources/DidNotAttend.php:114-118` passes `getSource()` — a human-readable message string (the `DNA_autogen_message` setting or a default sentence) — to `DidNotAttendCreator::setSource()`, which assigns it raw to `Event::automated_source`. `Event::beforeSave()` (`models/Event.php:305-308`) only `json_encode`s when the value is NOT a string, so the plain text is stored as-is; `Event::afterFind()` (`models/Event.php:291-293`) unconditionally `json_decode`s it, which returns `null` for any non-JSON text.
- **Impact**: every consumer of `automated_source` on a loaded PASAPI DNA event sees `null` instead of the configured source message (automated-event banner/source attribution lost).
- **Repro**: create a DNA event via the PASAPI DidNotAttend resource, reload it, inspect `automated_source`.
- **Severity**: low-medium (metadata silently lost on read; no crash).

## BUG-037: Consent Extra Procedures adder wipes TinyMCE Benefits and Risks content (REPRODUCED)
- **Where**: Consent form edit page — clicking the Extra Procedures adder's confirm button leaves `tinymce.get(id).getContent()` returning `''` for the Benefits and risks element (element_type 365, `form_Element_OphTrConsent_BenefitsAndRisks.php` uses two direct `tinymce.init()` calls), while the underlying `<textarea>.value` is untouched. Save then fails "Benefits and risks ... cannot be blank" because the editor content, not the textarea, is submitted.
- **Impact**: adding an extra procedure to an existing consent form silently destroys the Benefits and Risks rich-text unless the user knows to re-enter it; save-blocking validation error on data that was on screen a second earlier.
- **Repro**: consent form edit with populated Benefits and risks → Extra Procedures "Click to add" → confirm → Save. Reproduced twice by the creation agent on events 3686997/3686998; workaround was capturing values before the add and re-setting via `setContent()`.
- **Severity**: medium (user-visible data loss in the editor; underlying textarea intact until save).
- **Re-verified 2026-07-25 (1.1.33-dev), and the repro above does not reach it.** Two preconditions were missing, and without both the adder is a visible no-op:
  1. **The procedure must not already be on the form.** `views/default/procedure_selection.php:62-66` opens the `selected_procedures.forEach` with `if ($(\`input[...][value=${proc.id}]\`).length && proc.id !== -1) { return; }`, so `callbackAddProcedure()` is never reached for a procedure the form already carries. `ophtrconsent_procedure_extra` holds exactly one row ("Anterior vitrectomy if required") and its assignment to event 3686998 dates from the sample DB build (`ophtrconsent_procedure_extra_assignment_version` row 1, 2026-07-05 00:33:02) - so that event cannot exercise the path at all. Use a **fresh** Consent form.
  2. **The content must be paragraph-shaped, not a bullet list.** `assets/js/module.js:434 handleTinyMCEInput()` rebuilds the editor from its own `<li>` children and `setContent()`s a `<ul>` over the top; a bullet list survives intact, a `<p>` is dropped. This is why the fault reads as intermittent.
- **Working steps**: Log in → any patient → 'Add Event' → any subspecialty/context → 'Consent form' → set 'Type' → replace 'Intended benefits' and 'Significant, unavoidable or frequently occurring material risks' with one plain sentence each, no bullets → 'Extra Procedures' green '+' adder → select any procedure → confirm. Both editors go empty.
- **Evidence**: `tinymce.get('Element_OphTrConsent_BenefitsAndRisks_benefits').getContent()` goes `"<p>Benefits paragraph text here.</p>"` → `""`; same for `..._risks`. R1 (patient 17891, episode 601038, context 13) and R2 (patient 19382, episode 601050, context 5) byte-identical, so patient/episode/context are free choices. With `extra_procedure_benefit` and `extra_procedure_complication` both empty the AJAX returns `[]`, so `final_items` is empty and the editors are set to `<ul></ul>`, which TinyMCE normalises to `""`. No server-side signature - the wipe never reaches PHP.
- **Still unconfirmed**: that `<textarea>.value` survives and that Save is then rejected with "cannot be blank". Neither replay saved, and the textarea was only read on the two no-op walks. Canned walk: `c-oe-nav/subs/canned/consent-extra-procedure.md`.

## BUG-038: Any consent Edit+Save deletes in-progress Confirm consent / Withdrawal actions (CONFIRMED)
- **Where**: `form_Element_OphTrConsent_Confirm.php` and `form_Element_OphTrConsent_Withdrawal.php` render ONLY an alert box ("available in view mode only") when `action->id` is create/update — no input or hidden field at all. The standard update flow deletes open elements that post no data, so saving the Edit form removes any live Confirm (533) / Withdrawal (532) element and its pending E-Sign signature rows.
- **Impact**: editing anything on a consent event (e.g. adding an extra procedure) silently reverts an in-progress confirmation or withdrawal, including captured signatures.
- **Repro**: run Confirm consent from the view page, then Edit the event, change any field, Save → Confirm state gone. Reproduced twice by the creation agent (3686998 Confirm, 3686997 Withdrawal); mechanism confirmed in source.
- **Severity**: medium-high (silent loss of a signed clinical action).

## BUG-039: Consent Taken by renders second-opinion "No" and never-answered identically as "None" (CONFIRMED)
- **Where**: `view_Element_OphTrConsent_Consenttakenby.php:43` — `$element->second_op ? $element->sec_op_hp : 'None'`. When `second_op = 0` (explicit No, DB-verified on 3686997/3686998) the view prints "None", indistinguishable from an unanswered question; when Yes it prints the HP name rather than "Yes".
- **Impact**: the record of having asked the second-opinion question is invisible on the view page.
- **Severity**: low-medium (information display; data is stored correctly).

## BUG-040: Duplicate DOM ids for the contact adder across consent elements (CONFIRMED)
- **Where**: `form_Element_OphTrConsent_OthersInvolvedDecisionMakingProcess.php:116,190` and `_add_withdrawal_contact.php:23,52` both hardcode `id="add_patient_contact_button"` and adder id `patient_contact_adder`.
- **Impact**: a page containing both elements has colliding ids; `$('#add_patient_contact_button')` binds only the first, so the second adder's open button can drive the wrong dialog.
- **Severity**: low-medium (latent UI misbehaviour whenever both elements are editable on one page).

## BUG-041: Consent contact adder search box never queries — searchSource is empty (CONFIRMED)
- **Where**: `form_Element_OphTrConsent_OthersInvolvedDecisionMakingProcess.php:207-210` — `searchOptions: { searchSource: "", ... }` (same in `_add_withdrawal_contact.php`). The adder is populated from pre-loaded `getContactTypeItemSet()` item sets; typing a search term issues no request and does not filter the list.
- **Impact**: users type a name and get the same full unfiltered contact/user list back regardless of query.
- **Repro**: consent Others Involved (or Withdrawal) → Add contact → type "Jones" → list unchanged.
- **Severity**: low-medium (search UI present but non-functional).

## BUG-042: Every Element_OpNote descendant loses its section container on view and print (CONFIRMED, systemic)
- **Where**: `modules/OphTrOperationnote/models/Element_OpNote.php:19-27` — both `getContainer_view_view()` and `getContainer_print_view()` hard-code `return false;`. Every Operation note element descending from Element_OpNote (via Element_OnDemand / Element_OnDemandEye — i.e. all of them except Checklist, which extends `\BaseEventTypeElement` directly) therefore renders on `/OphTrOperationnote/default/view/<id>` and print with no `<section data-element-type-id=...>` wrapper.
- **Impact**: no per-element anchor/heading structure on op-note view/print; anything that targets elements by container (deep links, styling, our selector-based screenshot capture) fails for all op-note elements except Checklist. Verified live on event 3687017: Checklist has its wrapper, populated Buckle does not.
- **Repro**: open any Operation note event view → inspect DOM → only Checklist has a `section[data-element-type-id]` wrapper.
- **Severity**: medium (structural/uniformity defect across a whole event type).
- **Note added 2026-08-05**: re-confirmed live at `53b077c089` - `section[data-element-type-id='39']` does not match on `/OphTrOperationnote/default/view/3686591` although the Cataract heading and its data render. Two corrections to the entry above. First, the evidence event 3687017 no longer exists; the database was reset to sample and the highest op-note event id is now 3686606. Second, the wrapper **is** emitted on the edit route, because `Element_OnDemand::getContainer_form_view()` returns a real view - so `/OphTrOperationnote/default/update/<id>` is a working surface for anything that needs to target op-note elements by container, and fifteen documentation screenshots now use it.

## BUG-043: Operation note Biometry element renders nothing on the view screen (CONFIRMED)
- **Where**: `modules/OphTrOperationnote/views/default/view_Element_OphTrOperationnote_Biometry.php` is intentionally empty ("// yes, this is empty, no need to display, but because of element types this file is required").
- **Impact**: an element that shows IOL/biometry reference data during create/edit leaves zero trace on the saved event's view — a reader can't tell whether biometry was consulted. Distinct from BUG-042 (this view file is empty regardless of container).
- **Repro**: create an op-note with a cataract/lens procedure (Biometry appears on the form) → save → view: no Biometry output at all.
- **Severity**: low (arguably by design, but inconsistent with every other element's view behaviour).
- **Note added 2026-08-05, and it raises the severity**: the empty view template is not the whole story. `et_ophtroperationnote_biometry` is a **database view keyed on the Biometry event's own id**, so an operation note's event id can never match a row in it, and `getEventElements()` returns `$this->event->getElements()` on update, so the element is never loaded on a saved note either. The element therefore exists only on the create form and is **never saved with the note at all** - there is no data behind the empty template. Verified live at `53b077c089`: no Biometry section and no biometry text on either `/OphTrOperationnote/default/view/3686591` or `/update/3686591`, on a note that carries a "Phacoemulsification and Intraocular lens" procedure for a patient who has Biometry events. Re-read as "a reference panel that is shown once and never recorded", this is medium rather than low.

## BUG-044: CXL "UV total energy" saves crash when the field is left blank (CONFIRMED)
- **Where**: `form_Element_OphTrOperationnote_CXL.php:346-354` renders `uv_total_energy_value` as a plain number field; column `et_ophtroperationnote_cxl.uv_total_energy_value` is `decimal(5,1) NULL`. An empty submit posts `''`, which MySQL strict mode rejects: SQLSTATE 22007 "Incorrect decimal value: '' ". Same defect class as BUG-034.
- **Impact**: saving a CXL op-note with UV total energy blank throws a 500 instead of a validation message or NULL.
- **Repro**: op-note with CXL element → leave UV total energy empty → Save.
- **Severity**: medium (crash on ordinary user input).

## BUG-045: Duplicate DOM ids for both Save-as-draft checkboxes in the E-Sign auto-generate widget (CONFIRMED)
- **Where**: `widgets/views/EventAutoGenerateEsign.php:19-28` and `:38-55` — each Save-as-draft option renders `CHtml::hiddenField(name)` immediately followed by `CHtml::checkBox(name)` with the same name and no explicit `id`, so Yii derives the identical id for both elements: `EventAutoGenerateSaveAsDraft_correspondence` twice, and `EventAutoGenerateSaveAsDraft_prescription` twice.
- **Impact**: invalid HTML; `getElementById`/label-for behaviour resolves to the hidden field, not the checkbox. (Yii's own `uncheckValue` mechanism avoids this by prefixing the hidden id — bypassed here by rendering the hidden field manually.)
- **Repro**: open any event edit screen showing the E-Sign auto-generate rows (e.g. Operation note) → inspect DOM → duplicate ids.
- **Severity**: low-medium (same defect class as BUG-040).

## BUG-046: Botox checklist items hidden behind the default checklist filter (REPRODUCED by agent)
- **Where**: Operation note Checklist element — with the filter control on its default "All" selection, Botox-specific checklist rows are not shown; they only appear after explicitly switching the filter. Reported and reproduced live by the op-note authoring agent on event 3687017; static source verification inconclusive this session (filter logic not located by grep).
- **Impact**: "All" does not mean all — users can miss checklist items relevant to the booked procedure.
- **Repro**: op-note Checklist on a Botox procedure → leave filter at "All" → Botox rows absent.
- **Severity**: medium (data-entry omission risk); needs source-level confirmation before filing upstream.

## BUG-047: "Lens already removed" modal re-triggers on every load of the same op-note (REPRODUCED by agent)
- **Where**: Operation note create/edit — a warning modal about the lens/pseudophakic state re-appears on every subsequent load of the same event, not just the first time the conflicting procedure is chosen. Reported and reproduced live by the op-note authoring agent; the modal's text/trigger was not located by static grep this session (wording differs from obvious candidates), so file with the live repro only.
- **Impact**: repeated interruption; dismissing the same warning every edit invites alert fatigue.
- **Repro**: create an op-note whose procedure conflicts with recorded lens status → dismiss modal → save → re-open for edit → modal fires again.
- **Severity**: low (nuisance, no data loss observed).

## BUG-048: Examination Cataract Surgical Management search() references a non-existent description attribute (CONFIRMED, latent)
- **Where**: `modules/OphCiExamination/models/Element_OphCiExamination_CataractSurgicalManagement.php` `search()` (~line 228) — `$criteria->compare('description', $this->description)`. The table `et_ophciexamination_cataractsurgicalmanagement` has no `description` column and the class defines no such property or getter (only `__toString()` builds a description-like string), so `$this->description` throws a CException the moment `search()` is called.
- **Impact**: latent — `search()` appears to be unused Gii scaffolding for this element, but any future caller (admin grid, API filter) crashes immediately.
- **Repro**: `Element_OphCiExamination_CataractSurgicalManagement::model()->search()` in a console shell → "property ... is not defined".
- **Severity**: low (dead code path today; crash if ever exercised). Originally flagged by the exam batch B agent; independently verified against source + information_schema this session.

## BUG-049: Analytics cataract screen throws a TypeError on load — unguarded null from getSelectedReportURL() (CONFIRMED)
- **Where**: `assets/js/analytics/analytics_cataract.js:284` — `updateChart()` does `getSelectedReportURL()['selected_container']` without a null check. `getSelectedReportURL()` legitimately returns null whenever the currently-selected sidebar item is not one of the six bespoke report types in `dict` (e.g. the default "Clinical" dashboard selection). The two other call sites (lines 267, 322) are guarded; this one is not.
- **Impact**: "TypeError: Cannot read properties of null (reading 'selected_container')" fires on a fresh load of `/analytics/analyticsReports` (observed headless, admin, institution 1/site 1, default Clinical selection) when the search form auto-submits, and would fire on any manual "Update Chart" press while the Clinical dashboard is selected. The bespoke charts themselves still work once one is explicitly selected.
- **Repro**: log in → Analytics → open browser console → TypeError on load; or leave "Clinical" selected and press Update Chart.
- **Severity**: low-medium (console error + dead Update Chart in a common default state; no data loss).

## BUG-050: IOP History element is invisible on saved Examination events — empty event-view template (CONFIRMED)
- **Where**: `modules/OphCiExamination/widgets/views/HistoryIOP_event_view.php` — 16 lines, licence header only, zero markup (verified: 0 non-comment lines). `models/HistoryIOP.php:189-192` `getContainer_print_view()` returns `//patient/element_container_no_view`, so print output is suppressed too.
- **Impact**: the element saves a row (`et_ophciexamination_history_iop`, confirmed on event 3687021) but never renders on the event view or print. Its readings are materialised into Intraocular Pressure elements by `controllers/DefaultController.php:2237` `saveComplexAttributes_HistoryIOP` — today-dated readings land in the current event, past-dated ones spawn brand-new auto-created Examination events. A user who adds IOP History sees the element vanish after save, with an Intraocular Pressure section appearing instead (even if they deliberately removed the default IOP element).
- **Repro**: new Examination on the sample DB → add IOP History, enter a reading (e.g. Goldmann 16 mmHg, 10:00, today) → Save → view page shows no IOP History section; an Intraocular Pressure section renders instead. Edit form still shows the element.
- **Severity**: medium (data is preserved but the UI silently transforms it; docs page `clinical/examination/iop-history.md` had to point its screenshot at the update page). Found by exam batch C agent; view template, print container and materialiser verified in source this session.
- **Note added 2026-08-05**: the evidence event 3687021 no longer exists. The database was reset to sample and the highest event id is now 3687002, so every event id cited in this ledger from before that reset is stale. The defect itself is unchanged - the view template is still empty at `53b077c089` - but anyone re-verifying needs to create a fresh IOP History event first. See also BUG-162, BUG-163 and BUG-164, three further faults on the same element.

## BUG-051: Corneal Tomography "Back K1/K2" fields are repurposed axis columns with a negative-only validation range (CONFIRMED)
- **Where**: `modules/OphCiExamination/models/Element_OphCiExamination_Keratometry.php` — rules(): `right/left_axis_anterior_k1/k2_value` validated `numerical min=-150 max=-1` (Front K fields are `min=1 max=150`); the same axis fields are per-side **required** via `requiredIfSide`; attributeLabels() relabels them 'Back K1'/'Back K2'.
- **Impact**: column/attribute names say "axis" (0–180 degrees territory) but the UI labels say Back K and only negative values (-150..-1) validate. Negative posterior-power values (e.g. -6.2) save fine; anything positive-convention (posterior radius in mm, or an actual axis) can never save, with a confusing "Back K1 is too big" style error. Data analysts reading the schema will misinterpret stored Back-K powers as axes.
- **Repro**: new Examination → add Corneal Tomography → enter Back K1 `6.2` (positive) → save blocked by validation; `-6.2` saves.
- **Severity**: medium (schema/label mismatch + validation trap on a required field). Found by exam batch C agent; rules lines and labels verified in source this session.

## BUG-052: Element picker cannot add the legacy Injection Management element — v2 shadows it under the same display name (CONFIRMED by live probe, DB-corroborated)
- **Where**: Examination "Manage Elements" picker. `element_type` 390 (`Element_OphCiExamination_InjectionManagement`) and 547 (`Element_OphCiExamination_InjectionManagement_v2`) are both named "Injection Management"; the picker's single entry inserts a section with `data-element-type-id="547"`.
- **Impact**: the legacy element is unreachable from the UI; `et_ophciexamination_injectionmanagement` has 0 rows DB-wide on the sample database. Docs page `clinical/examination/injection-management.md` carries an evidence-based `needs=` for this reason.
- **Repro**: new Examination → Manage Elements → only one "Injection Management" entry; adding it yields element type 547, not 390.
- **Severity**: low if 390 is intentionally retired (then it should be deactivated/renamed so tooling and docs don't expect it), medium if sites still need the legacy element. Probed live by exam batch C agent; both element_type rows and the zero row count verified this session.

## BUG-053: Medication History section's remove (trash) control does nothing on the Examination create form (REPRODUCED by agent)
- **Where**: Examination create form, default Medication History element header `.js-remove-element` control.
- **Impact**: clicking remove does not delete the section (the History element's identical control works). Users cannot slim the create form; batch C worked around it by keeping the element.
- **Repro** (agent-observed via puppeteer, not source-traced): open the new-Examination create form → click the trash icon on Medication History → section remains; same click on History removes it.
- **Severity**: low. Static verification not attempted this session — logged at agent-reproduction confidence.

## BUG-054: Event view returns HTTP 500 when the patient's Diagnoses record contains an entry with no observation date (CONFIRMED)
- **Where**: `modules/Diagnoses/resources/DiagnosesInformationResource.php:154-155` — `sortEntriesByObsDate()` calls `strtotime($a->obs_date)` / `strtotime($b->obs_date)` with no null guard. `diagnoses_record_event_entry.obs_date` is nullable and legitimately empty (observation date is optional in the UI).
- **Impact**: on PHP 8.x the `strtotime(null)` deprecation is escalated by the error handler, so any event view page that renders the Diagnoses information resource for a record containing a NULL `obs_date` entry dies with HTTP 500. On this sample DB there are 254 NULL `obs_date` entries; Examination events 3686740 (patient 17891, 4 null-dated entries) and 3686743 (patient 17976, 1 null-dated entry) reproducibly 500, while sibling events whose records have only dated (or no) entries render fine.
- **Repro**: `curl http://localhost/OphCiExamination/default/view/3686740` (authenticated) → 500; application.log shows the strtotime deprecation with this exact stack every time.
- **Severity**: high (whole event view becomes unreachable; data-dependent so it looks intermittent). Found via failed doc screenshot captures this session; sort code, null counts and per-event correlation all verified. Fix sketch: treat NULL obs_date as 0/oldest in the comparator.

## BUG-055: Profile Laser settings save without permission checks and without a key whitelist (CONFIRMED)
- **Where**: `protected/controllers/ProfileController.php` `actionLaserSettings()` (~803-829) — every posted `Settings[key] => value` pair is written to `SettingUser` (delete + insert) with no `profile_user_can_edit` / `profile_user_show_menu` guard and no whitelist against the two laser keys the screen actually renders.
- **Impact**: (a) when `profile_user_show_menu` is off, the view shows an "administratively disabled" banner but the radios stay enabled and a POST still saves — the disable is cosmetic; (b) a logged-in user can POST arbitrary `Settings[<any-key>]` pairs and create/overwrite any user-scoped setting key, not just the laser ones.
- **Repro**: authenticated POST to `/profile/laserSettings` with `Settings[anything]=x` → row appears in `setting_user`; with `profile_user_show_menu=false` the same POST still saves despite the banner.
- **Severity**: low-medium (self-scoped settings only, but a config/permission bypass and unvalidated key writes). Source-verified both directions; view banner logic cross-checked in `views/profile/laser_settings.php`.

## BUG-056: /dashboard/index throws a fatal CException for every authorised user — missing "header" view (CONFIRMED)
- **Where**: `protected/controllers/DashboardController.php:22` sets `$headerTemplate = 'header'`, but `protected/views/dashboard/` contains only `index.php` and `header_oescape.php` — there is no `header.php`. Only `actionOEscape` overrides the template (line 166); `actionIndex` renders with the missing one.
- **Impact**: any user who passes the access rules (surgeons via `isSurgeon()`, admins via role) gets `CException: DashboardController cannot find the requested view "header"` — HTTP 500 — on `/dashboard/index`.
- **Repro**: log in as admin, GET `/dashboard/index` → 500 with the CException above (agent-reproduced live this session; view-file absence verified directly).
- **Severity**: medium (a routed, access-controlled screen is dead; unclear how prominently it is linked in current UI).

## BUG-057: /dashboard/oEscape is unreachable by any role (CONFIRMED)
- **Where**: `protected/controllers/DashboardController.php` `accessRules()` lines ~35-38 gate the `oescape` action to `'roles' => ['none']`.
- **Impact**: 403 for every user including admin — a dormant route, distinct from the working per-patient OEscape at `PatientController::actionOEscape`.
- **Repro**: log in as admin, GET `/dashboard/oEscape` → CHttpException 403 (agent-reproduced live; rule verified in source). Re-verified 2026-08-05 against an account holding **all 66 roles in the system**: still 403, because `none` is not an `authitem` row and `checkAccess()` returns false outright for a name it cannot resolve, so no grant can ever satisfy this rule.
- **Severity**: low (dead route; the real OEscape screen is unaffected).

## BUG-058: Disorder admin access rule matches usernames, not roles — role name listed under 'users' (CONFIRMED)
- **Where**: `protected/controllers/DisorderController.php` accessRules() (~line 40-43): `array('allow', 'actions'=>array('create','update','index','view','delete'), 'users'=>array('TaskCreateDisorder', 'admin'))`. In Yii1 `CAccessControlFilter`, `'users'` compares against literal usernames; RBAC items belong under `'roles'`.
- **Impact**: a user holding the `TaskCreateDisorder` role but not literally named "admin" (or "TaskCreateDisorder") is denied these actions; conversely a user account literally named "TaskCreateDisorder" would pass regardless of roles. The in-action `checkAccess('TaskCreateDisorder')` (~line 394) shows the intended RBAC gate.
- **Repro**: grant a non-admin user the TaskCreateDisorder role, GET `/disorder/index` → denied by the filter before the action runs.
- **Severity**: medium (permission miswire on the disorder reference admin screens). Source-verified.

## BUG-059: "Practitice Summary" typo on the practice view screen (CONFIRMED)
- **Where**: `protected/views/practice/view.php:16` — `<div class="title wordcaps">Practitice Summary</div>`.
- **Impact**: user-visible misspelling in the heading of every GP practice record page (`/practice/view/<id>`).
- **Severity**: low (cosmetic). Source-verified this session.

## BUG-060: /docman/index throws — DocmanController's render targets don't exist and its entry points are orphaned (CONFIRMED)
- **Where**: `protected/controllers/DocmanController.php` — `actionIndex()` (~line 32, comment "for independent front-end testing!") renders `/docman/index`; `addTableToEvent()` renderPartials the same view; `getDocTable()`/`actionAjaxGetDocTableEditRow()` reference `/docman/document_table` and `/docman/document_row_edit`. `protected/views/docman/` contains only `_create.php`, `_update.php`, `document_row_recipient.php` and `table/*` — none of the referenced views exist.
- **Impact**: GET `/docman/index` → CException (missing view) for any authenticated user. No other code path calls `addTableToEvent`/`getDocTable` (repo-wide grep: zero callers), so these are dead entry points. The real Docman recipient table is embedded in Correspondence letter create/update via `OphCoCorrespondence/views/default/form_ElementLetter.php` (`#docman_block`) and is unaffected.
- **Repro**: log in, GET `/docman/index` → 500 CException "cannot find the requested view" (agent-reproduced live; view absence and caller greps verified directly).
- **Severity**: low-medium (broken orphan route; the working feature lives elsewhere).

## BUG-061: NOD Export "no dataset selected" validation branch falls through into zip generation (CONFIRMED)
- **Where**: `protected/controllers/NodExportController.php` `actionGenerate()` (~lines 123-137): when neither `nod_choice[cataract]` nor `nod_choice[amd]` is posted, the code renders the index view plus a JS alert but has no `return` — execution continues into `createZipFile()` (~line 3419), which on failure calls `exit("Cannot open {exportPath}/{zipName}")` and on success builds/sends a zip of whatever stale CSVs match the glob.
- **Impact**: submitting the NOD Export form with nothing ticked produces, at best, the alert followed by a spurious zip download of leftover files, and at worst a raw `exit()` message — instead of a clean validation stop.
- **Repro**: authenticated POST to `/nodExport/generate` with no `nod_choice` keys.
- **Severity**: medium (broken validation on a data-export path). Source-verified; not executed live (export endpoints are not triggered on this container).

## BUG-062: Therapy Application report "First Injection" checkbox is dead; first-injection columns are driven by "Last Injection" (CONFIRMED)

- **Where**: `protected/modules/OphCoTherapyapplication/views/report/applications.php:78-79` renders `CHtml::checkBox('first_injection')`; `protected/modules/OphCoTherapyapplication/controllers/ReportController.php` never reads `$_GET['first_injection']` — the first-injection lookup (lines ~334-360, computing `first_injection_date`) sits inside `if (@$_GET['last_injection'])`, the same guard as the last-injection columns (line ~297).
- **Impact**: Ticking "First Injection" alone changes nothing in the CSV; ticking "Last Injection" adds BOTH last- and first-injection columns. The form silently misleads the user about which checkbox controls which columns.
- **Repro**: Reports > Therapy Applications; tick only "First Injection", generate — no injection columns appear. Tick only "Last Injection" — both last_injection_* and first_injection_date columns appear.
- **Severity**: Low (misleading UI, no data corruption).

## BUG-063: MDOR extract request returns raw HTTP 500 on form validation failure (CONFIRMED)

- **Where**: `protected/modules/TrDeviceUsageRecord/controllers/DeviceUsageReportController.php:80-82` — `actionRequestReport()` does `if (!$report_request_form->validate()) { throw new CHttpException(500); }` instead of re-rendering the form with `getErrors()`.
- **Impact**: Any invalid input (e.g. malformed/absent date range) on the Medical Device Usage Record report screen gives the user a generic 500 error page; the validation messages the form model produces are discarded. 500 also miscategorises a client input error (should be 4xx if thrown at all).
- **Repro**: Reports > Medical Device Usage Record; submit a report request with an invalid date value — browser shows the CHttpException 500 page rather than inline errors.
- **Severity**: Low-Medium (user-facing raw error page on a normal input mistake).

## BUG-064: Manual worklists fatal on every route — views directory renamed manual.disabled but controller actions still live (CONFIRMED)

- **Where**: `protected/controllers/WorklistController.php` — `actionIndex()` (~857-860) redirects to `/worklist/manual`; `actionManual()` (~865-874) renders `//worklist/manual/index`; `actionManualAdd()` (~876-895) renders `//worklist/manual/add`. `protected/views/worklist/` contains `manual.disabled/` and no `manual/` directory, so every render fails.
- **Impact**: `/worklist/index`, `/worklist/manual` and `/worklist/manualAdd` all return HTTP 500 fatal errors for any logged-in user. The directory name suggests the feature was deliberately disabled upstream, but the routes and the index redirect were left live, so users hit raw 500s instead of a 404 or a removed menu entry.
- **Repro**: Log in; browse to `/worklist/index` (or `/worklist/manual`) — CException, view file not found.
- **Severity**: Medium (dead feature left reachable; whole-route 500s).

## BUG-065: PatientTicketing index with unknown cat_id → PHP null dereference 500 instead of 404 (CONFIRMED)

- **Where**: `protected/modules/PatientTicketing/controllers/DefaultController.php` `actionIndex()` throws a clean 404 when `cat_id` is absent (~line 365, "Category ID required") but never checks the category exists; a nonexistent id flows into `protected/services/ModelService.php:142` `modelToResource()` which reads `$model->id` on a null model.
- **Impact**: "Attempt to read property 'id' on null" 500 for any URL with an invalid `cat_id` (e.g. a stale bookmark after a category is deleted), where a 404 is the correct response.
- **Repro**: Log in; browse to `/PatientTicketing/default/index?cat_id=<nonexistent id>`.
- **Severity**: Low (URL-edit/stale-link path; no data impact).

## BUG-066: OeStats module dead on every route — module file named OestatsModule.php but declares class OeStatsModule (CONFIRMED)

- **Where**: `protected/modules/OeStats/OestatsModule.php` (lowercase "estats" in the filename) declares `namespace OEModule\OeStats; class OeStatsModule` (line 12). Yii resolves the registered class `OEModule\OeStats\OeStatsModule` to a file named `OeStatsModule.php`, which does not exist on a case-sensitive filesystem.
- **Impact**: Every OeStats route (`/OeStats/default/index`, `/userStats`, `/versionHistory`) throws `CException: Alias "OEModule\OeStats\OeStatsModule" is invalid`. The whole Stats dashboard (admin menu entry `oestats`) is unusable when the module is enabled.
- **Repro**: Enable OeStats in local config (class per its own declaration); browse to `/OeStats/default/index` logged in as admin.
- **Severity**: Medium (entire module feature dead; trivially fixed by renaming the file).

## BUG-067: OphOuCatprom5 default/index action throws 500 — actionIndex declared but never mapped in action_type_map (CONFIRMED)

- **Where**: `protected/modules/OphOuCatprom5/controllers/DefaultController.php:36` declares `actionIndex()`, but 'index' is never added to `action_type_map`, so `BaseEventTypeController::getActionType()` (`protected/controllers/BaseEventTypeController.php:292`) throws `Exception: Action 'index' has no type associated with it`. Its view file is empty. Module-specific: `/OphCiExamination/default/index` and `/OphDrPrescription/default/index` correctly 404 (no such action).
- **Impact**: Logged-in users browsing `/OphOuCatprom5/default/index` get a raw 500. Dead code shipping in the controller.
- **Repro**: Log in; browse to `/OphOuCatprom5/default/index`.
- **Severity**: Low (URL-only route, not linked from any menu).

## BUG-068: Genetics Study View shows the Edit button on the wrong permission (CONFIRMED)

- **Where**: `protected/modules/Genetics/views/study/view.php:24` gates the Edit button on `checkAccess('OprnEditGeneticPatient')`, but `StudyController::accessRules()` (line ~38) enforces `TaskEditGeneticStudy` for the edit action (and line 128 uses `TaskEditGeneticStudy` for display flags elsewhere).
- **Impact**: A user holding `OprnEditGeneticPatient` but not `TaskEditGeneticStudy` sees an Edit button that 403s when clicked; the reverse combination hides a button the user is actually allowed to use.
- **Repro**: Grant a role only `OprnEditGeneticPatient`; open `/Genetics/study/view/<id>`; click Edit.
- **Severity**: Low (misleading UI; enforcement itself is correct).

## BUG-069: Genetics study-participation consent timestamp is overwritten on every save (CONFIRMED)

- **Where**: `protected/modules/Genetics/controllers/SubjectController.php:335-337` — on every POST where `is_consent_given` is true, `consent_given_on` is set to `date_create('now')`, not only when consent is first recorded.
- **Impact**: Re-saving an already-consented participation record (e.g. to change its status) silently moves the recorded consent date forward to today, destroying the original consent timestamp. Matters wherever that field is relied on as an audit trail.
- **Repro**: Edit a study participation with consent already given; save without touching the consent box; reload — consent date is now today.
- **Severity**: Medium (silent loss of consent audit data).

## BUG-070: "Edit Participation" link permanently hidden — live screen has no UI path (CONFIRMED)

- **Where**: `protected/views/studies/list.php:22-25` — the pencil link to `/Genetics/subject/editStudyStatus/{pivot_id}` carries `class="hidden edit-study-participation"` behind the comment "this link is hidden for now"; no CSS or JS anywhere un-hides it. The backing `SubjectController::actionEditStudyStatus()` remains live and functional.
- **Impact**: The study-participation edit screen (consent/status) is reachable only by hand-typing a URL containing the `genetics_study_subject` pivot id, which is displayed nowhere. The "for now" became permanent.
- **Repro**: Open a genetics subject with a study participation; no edit control is visible; the hidden anchor is present in the DOM.
- **Severity**: Low (deliberate-looking but abandoned; feature effectively orphaned).

## BUG-071: OETrial trial/view without an id throws raw PHP TypeError 500 (CONFIRMED)

- **Where**: `protected/modules/OETrial/controllers/TrialController.php:135` `actionView($id)` — requesting `/OETrial/trial/view` with no id reaches the action and dies with a PHP 8 `TypeError` (missing required argument) rather than Yii's usual CHttpException 400 for missing action parameters; `/OETrial/trial/view/1` resolves normally (302 to login when logged out).
- **Impact**: Truncated/hand-edited trial URLs render a raw TypeError 500 page.
- **Repro**: Browse to `/OETrial/trial/view` (no id), logged in or out.
- **Severity**: Low (malformed-URL robustness; no data impact).

## BUG-072: DICOM Log Viewer "File Name" column renders the integer file id through basename() (CONFIRMED)

- **Where**: `protected/views/dicomlogviewer/dicom_file_log_viewer.php:22,25` — both the row attribute and the visible cell render `basename((string) $val['dicom_file_id'])`, an integer foreign key, not a filename.
- **Impact**: The File Name column shows raw integers (176, 174, ...) instead of DICOM filenames, making the log viewer useless for identifying files. Confirmed live on the sample instance.
- **Repro**: Log in as admin; open the DICOM file log viewer; observe the File Name column.
- **Severity**: Low-Medium (feature renders but conveys no useful information).

## BUG-073: Vestigial /DicomLogViewer/log duplicates /list, reachable only via an orphaned Biometry redirect (CONFIRMED)

- **Where**: `DicomLogViewerController` — `actionLog()` (~58-61) and `actionList()` (~73-75) both render `//dicomlogviewer/index`; only `/list` is menu-registered. The sole reference to `/log` is `OphInBiometry\AdminController::actionFileLog()`, a redirect that is itself linked from no menu or view (grep across the module matches only its definition).
- **Impact**: Dead duplicate route plus a dead-end redirect chain shipping in the codebase; byte-identical content to `/list`.
- **Repro**: Compare `/DicomLogViewer/log` and `/DicomLogViewer/list` logged in.
- **Severity**: Low (dead code; no user harm).

## BUG-074: Bare /baseEventType/* routes throw a null-dereference 500 (CONFIRMED)

- **Where**: `protected/controllers/BaseModuleController.php:44` — `init()` builds `'application.modules.' . $this->getModule()->name`; when `BaseEventTypeController` is routed bare (e.g. `/baseEventType/view/<event id>`, `/baseEventType/renderEventImage/...`) there is no owning module, `getModule()` is null, and the request dies with "Attempt to read property 'name' on null" (HTTP 500).
- **Impact**: URL-reachable 500s on a controller that is (per its own docblock) "an abstract class in all but name" — should 404 or be unroutable.
- **Repro**: Log in; browse to `/baseEventType/view/<any event id>`.
- **Severity**: Low (URL-only; every real event view goes through its module route).

## BUG-075: Admission form crashes for any operation with a listing diagnosis — non-existent singular "disorder" relation (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/views/letters/admission_form.php:183` renders `$operation->diagnosis->disorder->term`, but `Element_OphTrOperationbooking_Diagnosis::relations()` (lines 83-97) defines only `diagnosis_disorders` and `disorders` (both HAS_MANY) — there is no singular `disorder` relation.
- **Impact**: `CException: Property "Element_OphTrOperationbooking_Diagnosis.disorder" is not defined` whenever the admission form is printed for an operation that has a listing diagnosis — the universal case, not sample-data-specific. Reproduced live.
- **Repro**: Log in; print the admission form for any operation booking event with a Diagnosis element.
- **Severity**: Medium-High (patient-facing printable document universally broken when a diagnosis is recorded).

## BUG-076: Admission letter crashes for operations without an active booking — no null check (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/controllers/DefaultController.php:813` — `actionAdmissionLetter()` dereferences `$this->operation->booking->session->theatre->site` with no null check on `booking`.
- **Impact**: "Attempt to read property 'session' on null" for any operation still on the waiting list (no confirmed booking). Reproduced live.
- **Repro**: Log in; request the admission letter for an unbooked operation event.
- **Severity**: Medium (crash on a reachable print action for a common state).

## BUG-077: Admission letter emergency-list flag is always overwritten to false (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/controllers/DefaultController.php:814-818` — the fallback branch sets `$emergency_list = true` (line 816) when the booking session has no firm, but line 818 unconditionally sets `$emergency_list = false` immediately after the block; line 828 passes it to the view as `emergencyList`.
- **Impact**: The admission letter's emergency-list variant can never render — the assignment order defeats the branch. Almost certainly a misplaced default (the `false` belongs before the `if`).
- **Repro**: Code inspection; any emergency-list operation prints as a normal-list letter.
- **Severity**: Low-Medium (silent wrong letter content for emergency-list cases).

## BUG-078: Dead click handler for #btn_print-admissionletter — element rendered nowhere (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/assets/js/booking.js:254-257` binds a click handler to `#btn_print-admissionletter`; no view template in the module or wider codebase renders an element with that id.
- **Impact**: Orphaned JavaScript; the admission-letter print path it implemented is unreachable from this handler.
- **Repro**: `grep -rn btn_print-admissionletter` — only the JS binding matches.
- **Severity**: Low (dead code).

## BUG-079: Transport (TCI) list has no in-app navigation path (CONFIRMED)

- **Where**: `/OphTrOperationbooking/transport/index` — the only references to the route in the codebase are its own view's pagination and form-post-back (`views/transport/_pagination.php:27,36,46`, `views/transport/index.php:29`); no menu registration or link from any other screen.
- **Impact**: A functioning transport-arrangement worklist (confirm/print/CSV) is reachable only by direct or bookmarked URL; new users cannot discover it.
- **Repro**: Search all menus and views for a link to the route; none exists.
- **Severity**: Low (orphaned but working feature).

## BUG-080: Consent Extra Procedures subspecialty scoping has no effect — filtered lookup is dead code with invalid SQL (CONFIRMED)

- **Where**: `protected/modules/OphTrConsent/models/OphTrConsent_Extra_Procedure.php` — `getList($term)` (line 124, no subspecialty/active filter) vs `getListBySubspecialty()` (line 146, never called); `protected/modules/OphTrConsent/controllers/ExtraProceduresController.php:35` — `actionAutocomplete()` calls `getList($_GET['term'], @$_GET['restrict'])` but `getList()` only accepts one parameter, so `restrict` is silently discarded; consent form view `form_Element_OphTrConsent_ExtraProcedures.php:51` wires the picker to `/OphTrConsent/ExtraProcedures/autocomplete`.
- **Impact**: The admin "Extra Procedures Subspecialty Assignment" screen lets an administrator scope which subspecialties/institutions may use each extra procedure, but the Extra Procedures picker on the Consent form always searches the entire `ophtrconsent_procedure_extra` table — the scoping configuration is dead from the clinician's perspective. The only method that would honour it, `OphTrConsent_Extra_Procedure::getListBySubspecialty()`, has zero callers anywhere in the codebase (the `getListBySubspecialty` hits in `widgets/ExtraProcedureSelection.php:82` target the core `Procedure` model, and that widget itself has no render sites), and its SQL is invalid anyway: it selects/orders on a `proc` alias (`proc.active`, `proc.term`) that appears in no FROM/JOIN clause, so it would throw "unknown column" if ever wired up.
- **Repro**: `grep -rn "getListBySubspecialty" protected/ --include='*.php'` — only the definition and the unrelated core-model callers; `grep -n "function actionAutocomplete" -A3 protected/modules/OphTrConsent/controllers/ExtraProceduresController.php` shows the unfiltered `getList()` call; on the live app, any term typed into the Consent form's Extra Procedures search returns procedures regardless of subspecialty assignment.
- **Severity**: medium (configuration UI silently ineffective; no data corruption).

## BUG-081: Examination Safeguarding hasActionableOutcome() reads undefined $element — outcome gating is dead (CONFIRMED)
- **Where**: `modules/OphCiExamination/models/Element_OphCiExamination_Safeguarding.php:176-183`; sole caller `views/default/view_Element_OphCiExamination_Safeguarding.php:6` (used at lines 82 and 118).
- **Impact**: The method is meant to return "user holds Safeguarding permission AND (no outcome yet OR outcome is Follow up required)". `$element` is undefined inside the model method (should be `$this`), so `!isset($element->outcome_id)` is always true and the outcome test never runs — every Safeguarding element is treated as actionable for any user with the Safeguarding role, including elements whose outcome is already resolved. Silent: `isset()` on an undefined variable raises no notice.
- **Repro**: View an Examination with a Safeguarding element whose outcome is not "Follow up required" as a Safeguarding-role user — the actionable UI at view lines 82/118 still renders.
- **Severity**: medium

## BUG-082: Specular Microscopy lookups (microscope, scan quality) have no admin screen (CONFIRMED)
- **Where**: `modules/OphCiExamination/models/OphCiExamination_Specular_Microscope.php` / `OphCiExamination_Scan_Quality.php` (tables `ophciexamination_specular_microscope`, `ophciexamination_scan_quality`).
- **Impact**: The element's two dropdowns cannot be maintained anywhere in the app — no admin controller or GenericAdmin registration references either model (full-tree grep excluding models/views/migrations matches only OeDataDictionary docs). Site-specific devices can only be added by SQL.
- **Repro**: `grep -rln "Specular_Microscope\|Scan_Quality" protected/` minus models/views/migrations → only data-dictionary docs.
- **Severity**: low

## BUG-083: Triage eye-injury picker visibility keyed to the literal lookup label 'Eye injury' (CONFIRMED)
- **Where**: `modules/OphCiExamination/widgets/views/Triage_event_edit.php:256`.
- **Impact**: The Eye Injury column of the Triage adder shows only when the clicked chief-complaint option's rendered text is exactly `Eye injury` (`$(e.target).text() === 'Eye injury'` toggles `th/td[data-id="eye_injury_id"]`). Renaming that admin-editable lookup row silently makes eye-injury detail impossible to record.
- **Repro**: Source lines 254-261; rename the lookup row and the column never appears.
- **Severity**: medium

## BUG-084: Specular Microscopy coefficient of variation accepts negative values — max-only validator (CONFIRMED)
- **Where**: `modules/OphCiExamination/models/Element_OphCiExamination_Specular_Microscopy.php` rules(): `left/right_coefficient_variation_value` `numerical` with `max => 999.99` and no `min`; columns are signed `decimal(5,2)` in `et_ophciexamination_specular_microscopy`.
- **Impact**: CoV (a percentage, non-negative by definition) saves as e.g. `-5.00`. Sibling ECD fields carry `min 500 / max 4000`, so the omission is an outlier, not a pattern.
- **Repro**: rules() array; `SHOW COLUMNS` confirms signed decimal, so nothing downstream blocks it.
- **Severity**: low

## BUG-085: Fundus vitreous single-choice categories enforced only client-side (CONFIRMED)
- **Where**: `modules/OphCiExamination/models/Element_OphCiExamination_Fundus.php` — `getVitreousExaminationData()` marks the hazegrade/fill/tamponade categories `multiSelect => false` (adder-dialog config consumed at `form_Element_OphCiExamination_Fundus.php:19`); rules() line 81 lists `left_vitreous/right_vitreous` as `safe` only; `Vitreous.php` has no category rules; `afterSave()` only sheds eyedraws.
- **Impact**: The one-per-category constraint for Haze Grade / Fill / Tamponade lives entirely in the adder-dialog JS. A crafted or scripted POST can persist several mutually-exclusive values per eye into `ophciexamination_fundus_vitreous`, and they render together on the saved event.
- **Repro**: Static — no server-side validation exists anywhere on the junction; model rules are `safe` passthrough.
- **Severity**: low

## BUG-086: Consent withdrawal fires on an unconfirmed GET and marks the event withdrawn before any reason or signature (CONFIRMED)
- **Where**: `modules/OphTrConsent/views/default/view.php:104` (red button, class `js-add-withdrawal`) + `assets/js/module.js:404-407` (`window.location.href = "/OphTrConsent/default/withdraw?event_id=..."`) + `controllers/DefaultController.php:698` `actionWithdraw()` (no request-method guard).
- **Impact**: One click on "Patient withdraws consent" — no confirmation dialog — immediately saves the Withdrawal element with `withdrawn = 1` and, for the three agreement types, autofills the patient's own contact details. Because the reason only arrives by POST, the GET path also runs the else-branch that DELETES the 'Consent Withdrawn' event issue while leaving `withdrawn = 1` — a withdrawn event with no issue flag until "Proceed with withdraw consent" later re-submits the same action as POST with the reason (the inline JS in `widgets/views/Withdrawal.php` blocks a blank reason client-side; the server never requires one). A state-changing GET is also prefetch/CSRF-exposed. Reversible via Cancel consent withdrawal (`actionRemoveWithdraw`) — itself also a GET.
- **Repro**: Static trace above; live repro is one real click (state-changing, not performed under the Phase 5 GET-only rule).
- **Severity**: medium

## BUG-087: Saving a withdrawal contact silently resets the withdrawn flag and wipes the reason (CONFIRMED)
- **Where**: `modules/OphTrConsent/controllers/DefaultController.php:1499-1521` `actionSaveWithdrawal()` — `$withdrawal->withdrawn = 0; $withdrawal->withdrawal_reason = null;` unconditionally on every contact save.
- **Impact**: On unable-to-consent forms the flow is: click withdraw (`withdrawn = 1`, BUG-086) → "Add withdrawal" to pick the contact → this handler resets `withdrawn = 0` and clears any reason already saved. Abandoning at that point leaves a half-withdrawal (contact recorded, `withdrawn = 0`, no reason); it also destroys an in-progress reason without warning. Possibly intended as staging for a fresh contact-led withdrawal, but it is unconditional and destructive.
- **Repro**: Static read of the method; live repro needs one POST contact-pick plus before/after check of `et_ophtrconsent_withdrawal.withdrawn` / `withdrawal_reason`.
- **Severity**: low

## BUG-088: CVI cannot be issued without Local Authority contact details even when LA consent is declined (CONFIRMED)
- **Where**: `modules/OphCoCvi/models/Element_OphCoCvi_Demographics.php:116-118` — the `required` rule on the `finalise` scenario includes `la_name, la_address, la_telephone, la_postcode, la_postcode_2nd`; `components/OphCoCvi_Manager.php:495-507` `demographicsValidation()` applies it unconditionally, chained by `canIssueCvi()` at :538 (via `controllers/DefaultController.php:336-339`). No validate hooks or consent conditionals exist anywhere in the chain.
- **Impact**: The Consent element's "share with Local Authority" answer only gates *delivery* (`issueCvi()`, Manager ~:717-721 — `consented_to_la` sets `la_delivery`). Issue itself always demands full LA contact details, so a CVI where the patient declined LA sharing (or where LA details are unknown) cannot be issued at all. Possibly intentional for the certificate layout, but inconsistent with the consent model and a hard workflow blocker.
- **Repro**: Complete a CVI on a sample patient, leave the LA fields blank and answer No to LA consent, click the green Issue button → validation errors demand the LA fields (code-traced both directions this session).
- **Severity**: low

## BUG-089: Therapy Application marked historic is still auto-submitted on save (CONFIRMED)
- **Where**: `modules/OphCoTherapyapplication/controllers/DefaultController.php:389-397` `afterCreateEvent()` → `processTherapyApplication()` → `services/OphCoTherapyapplication_Processor.php:261` `processEvent()` / `:479` `processEventForEye()` — none consult `left/right_is_historic` or `statusIsHistoric()`. The historic flag is only read by `Processor::getApplicationStatus()` (:68-76, gated on setting `enable_historic_therapy_applications`), `views/default/view.php:23-45,69` (whole-event edit/print UI suppression) and the worklist status filter.
- **Impact**: With `enable_historic_therapy_applications=on` (exposes the per-eye "Is Historic" checkboxes) and `therapy_application_automatic_submission=on`, saving an application recorded purely as historic still runs the live submission pipeline — commissioner emails fire for a record that only documents a past application — while the UI simultaneously labels the event "Historical" and hides its controls.
- **Repro**: Both settings on; create a Therapy Application with Is Historic ticked for the only affected eye and no process warnings; save → "Application processed" flash, submission emails sent (code-traced both directions; zero is_historic checks in the submission path).
- **Severity**: medium

## BUG-090: Operation checklists creation 500s — code still queries the dropped secondary_diagnosis table (CONFIRMED)
- **Where**: `modules/OphTrOperationchecklists/views/default/form_Element_OphTrOperationchecklists_ProcedureList.php:141-145` calls `CommonOphthalmicDisorder::getList($firm, true, $patient)` (`protected/models/CommonOphthalmicDisorder.php:233-246`) → `Disorder::getPatientDisorders()` (`protected/models/Disorder.php:240-249`) which LEFT JOINs `secondary_diagnosis`. The table does not exist in the develop sample DB and the `SecondaryDiagnosis` model has been deleted from core (`Element_OphCiExamination_DRGrading::_getSecondaryDiagnosis()` is already a deprecated stub).
- **Impact**: Creating an Operation checklists event throws `CDbException` 1146 "Table 'openeyes.secondary_diagnosis' doesn't exist" (HTTP 500) as soon as the ProcedureList step renders — the event type is effectively unusable. Manual Add Event is separately hidden by core migration `m240212_094400_hide_OphCoChecklists_event.php` (which, despite the OphCoChecklists name, deactivates OphTrOperationchecklists), but booking-driven entry points reach the same form. Further leftover references to the dropped table: `protected/commands/ReportsCommand.php`, `OeMerge/components/IngestionEntityRegistry.php`, `OeDataDictionary/scripts/*` (CLI-side); the other `getList()` callers don't pass the patient-disorders flag and are unaffected.
- **Repro**: Log in admin/admin; first select a context whose subspecialty has an episode for the patient, e.g. GET `/patientEvent/create?patient_id=17891&event_type_id=44&context_id=8&episode_id=601039` (with a non-matching firm the episode guard at `BaseEventTypeController.php:784` silently bounces to the patient landing page, masking the bug); then GET `/OphTrOperationchecklists/Default/create?patient_id=17891&unbooked=1` → 500 with the exception above (reproduced live this session).
- **Repro, as a user gestures it** (re-walked 2026-08-05 at `53b077c089`, since the URL form above hides where the failure actually lands):
  1. GET `/patientEvent/create?patient_id=17891&event_type_id=44&context_id=13&episode_id=601038`.
  2. Observe HTTP **200** - the redirect lands on `/OphTrOperationchecklists/Default/create?patient_id=17891` showing "Select a booking", whose only offer is the **Emergency / Unbooked** link (an `href="#"` driven by JavaScript). The create screen itself is not fatal.
  3. Click **Emergency / Unbooked** (equivalently, request the `&unbooked=1` URL above).
  4. `CDbException` 1146 "Table 'openeyes.secondary_diagnosis' doesn't exist" - HTTP 500.
- **Severity**: high

## BUG-091: Checklists Admission/Observations templates call the Lab Results API without a false-check (CONFIRMED)
- **Where**: `modules/OphTrOperationchecklists/views/default/form_Element_OphTrOperationchecklists_Admission.php:24-26`, `view_Element_OphTrOperationchecklists_Admission.php:22-23`, `form_OphTrOperationchecklists_Observations.php:25`, `view_OphTrOperationchecklists_Observations.php:22-24` — each does `$api = Yii::app()->moduleAPI->get('OphInLabResults'); $api->getLabResultTypeResult(...)` with no `if ($api)` guard. `ModuleAPI::get()` returns false for unregistered modules (`protected/components/ModuleAPI.php:35+`).
- **Impact**: On installations without OphInLabResults enabled, rendering the Admission or Observations checklist elements fatals ("Call to a member function getLabResultTypeResult() on bool"). Latent in the sample environment (module enabled there). The module's own controllers show the correct pattern — they guard the OphTrOperationbooking API result before use (`DefaultController.php:159` onward).
- **Repro**: Disable OphInLabResults in the module config; open any checklists event containing Admission or Observations → fatal (static trace; not executed against the sample, which has the module on).
- **Severity**: low

## BUG-092: DNA extraction Edit screen 500s — Caption widget called without its required name param (CONFIRMED)
- **Where**: `protected/modules/OphInDnaextraction/views/default/form_Element_OphInDnaextraction_DnaExtraction.php:86-93` — on the `update` action it renders `$form->widget('Caption', ['label' => 'Volume Remaining', 'value' => ...])` with no `name`. The widget view `protected/widgets/views/Caption.php:38` then calls `CHtml::label($labelText, CHtml::getIdByName($name))` with `$name === null`, and `CHtml::getIdByName()` fatals in `str_replace()` under PHP 8.1 ("Passing null to parameter #3 ($subject)").
- **Impact**: high — every DNA extraction event's Edit screen is a full-page HTTP 500 for all users; extractions can be created but never edited. (The docs' "Volume Remaining shown when editing" claim describes the coded-for intent, so the doc page stands.)
- **Repro**: log in as admin (institution 1, site 1); GET `/OphInDnaextraction/default/update/<any extraction event id>` → 500 with the str_replace/getIdByName trace.
- **Severity**: high
- Found by clin-misc batch 01 verify agent; confirmed by orchestrator in source and live (view of the same event returns 200, update returns 500).

## BUG-093: Voice transcription endpoint is anonymous and CSRF-exempt with no rate limiting (CONFIRMED, intentional per source comment)
- **Where**: `protected/modules/VoiceControl/controllers/VoiceController.php` accessRules — `['allow', 'actions' => ['transcribe'], 'users' => ['*']]`; `protected/modules/VoiceControl/config/common.php:26-28` adds `VoiceControl/voice/transcribe` to `noCsrfValidationRoutes`. A code comment above the rule states this is deliberate (transcribe must be reachable from the pre-auth login page; the whisper sidecar has no auth either — "same trust boundary").
- **Impact**: low (awareness) — any unauthenticated client can POST audio to `/VoiceControl/voice/transcribe` and drive the CPU-heavy whisper sidecar; no rate limit or size throttle at the app layer, so it is a pre-auth resource-exhaustion surface. Not exploitable for data access.
- **Repro**: logged out, `curl -s http://localhost/VoiceControl/voice/transcribe` → `{"error":"POST required"}` HTTP 405 (action reached anonymously, no login redirect); a POST with an `audio_file` part is proxied to whisper.
- **Severity**: low
- Found by review-keep batch verify agent; confirmed by orchestrator (accessRules + noCsrfValidationRoutes in source; anonymous 405 live). Logged for triage visibility despite the intentional-design comment — a perimeter rate limit may still be wanted.

## BUG-094: Optom feedback screen — menu says "Optom Invoice Manager", page says "Optometrist Feedback Manager" (CONFIRMED)
- **Where**: menu label `protected/modules/OphCiExamination/modules/ExaminationAdmin/config/common.php:120` (`'title' => 'Optom Invoice Manager'`, uri `/OphCiExamination/OptomFeedback/list`) vs page heading `protected/modules/OphCiExamination/views/optom/list.php:172` (`<div class="title wordcaps">Optometrist Feedback Manager</div>`).
- **Impact**: low, cosmetic — the menu entry and the screen it opens disagree on the feature's name, which confuses users and documentation alike.
- **Repro**: log in as a user with the `Optom co-ordinator` role (or render the page as admin); compare the top-menu label with the on-page heading.
- **Severity**: low
- Found by review-keep batch verify agent; confirmed by orchestrator in source and live render.

## BUG-095: Genetics per-study "proposers only" view restriction is dead code — never enforced (CONFIRMED)
- **Where**: `protected/modules/Genetics/components/Genetics_AuthRules.php:13-24` — `canViewStudy()` returns true for the list and `$study->isUserProposer($user)` for a specific study. It is wired as the bizrule of `OprnViewGeneticStudy` by migration `m170117_105413_study_view_rbac.php:9-10` (child of `TaskViewGeneticStudy`). But `StudyController::accessRules()` (StudyController.php:33) gates on `TaskViewGeneticStudy` directly, and a repo-wide grep finds no `checkAccess('OprnViewGeneticStudy')` caller anywhere — the operation and its bizrule are never evaluated.
- **Impact**: medium-low — the migration's intent (a study visible only to its proposers) is silently absent: any user with `TaskViewGeneticStudy` can open any study's view page. Misleading for sites that assume the per-study restriction exists.
- **Repro**: `grep -rn "OprnViewGeneticStudy" protected/` → only the migration hits; log in as a Genetics Clinical user who is not a proposer of study X, GET `/Genetics/study/view/X` → renders.
- **Severity**: medium-low
- Found by reference batch 00 verify agent; confirmed by orchestrator (grep + accessRules).

## BUG-096: AiSearch "Show AI summary" always fails — aiSummary route missing from the CSRF whitelist (CONFIRMED)
- **Where**: `protected/modules/AiSearch/config/common.php:39-44` — `noCsrfValidationRoutes` lists `query`, `similar`, `ask`, `coverage` but NOT `AiSearch/semanticSearch/aiSummary`. The view (`views/semanticSearch/index.php:419-423`) JSON-POSTs to `/AiSearch/semanticSearch/aiSummary` with the token only in an `X-CSRF-Token` header and JSON `_csrf` field; OE's `HttpRequest::normalizeRequest()` (protected/components/HttpRequest.php:25-42) only detaches Yii's validator for whitelisted routes, and Yii 1.1's `validateCsrfToken()` reads the token exclusively from `$_POST` — empty for a JSON body.
- **Impact**: medium — the "Show AI summary" button on the semantic search screen can never load a summary; every click gets HTTP 400. The config's own comment ("Our JSON POST endpoint can't supply that, so we whitelist the route") shows aiSummary was simply missed from the list.
- **Repro**: logged in, `curl -X POST -H "Content-Type: application/json" -d '{"patient_id":<id>}' /AiSearch/semanticSearch/aiSummary` → HTTP 400 "The CSRF token could not be verified." (reproduced live).
- **Severity**: medium
- Found by reference batch 00 verify agent (source-only); orchestrator completed the live direction with the 400 repro.

## BUG-097: IVT bookings worklist "needs attention" filter is inert — booking-status conditions live only in LEFT JOIN ON clauses (CONFIRMED; original NULL-bind theory refuted)
- **Where**: `protected/modules/OphCiExamination/modules/ExaminationBookingPages/controllers/IntravitrealinjectionController.php:139-147` `getDefaultPatientListCriteria()` — three `LEFT OUTER JOIN ophciexamination_ivt_booking bookings_{o,s,i} ... AND (booking_status IN ('Not booked','Booking in doubt'))` joins whose aliases are never referenced by any WHERE condition, select column, or later code (`getDataProviderForIndexScreen()` at :73-86 just counts/pages the criteria). The comment at :129 states the intent: "we query the ones needs attention".
- **Impact**: medium-low — the default list is over-inclusive: it returns every patient with an injection-management V2 order on an event dated on/after `ivt_worklist_earliest_date`, including patients whose bookings are all fully booked. The per-row status icons still flag state, but the list itself never restricts to not-booked/in-doubt as the code intends. Secondary latent hazard at :150-160: if the `ivt_worklist_earliest_date` setting ever resolves empty or non-`Y-m-d`, the code silently binds SQL NULL into the INNER-JOIN condition `event.event_date >= :ivt_worklist_earliest_date`, which is never true — the list goes silently empty with no warning. Today that path is unreachable in practice because `setting_metadata` row 278 carries `default_value` 2024-06-07 and `SettingMetadata::getSetting()` falls back to it.
- **Repro**: source trace both directions (no `bookings_` alias outside the three ON clauses; no WHERE added downstream). Live render not possible on the sample environment: admin lacks `TaskIVTBookingsAccess` (`GET /OphCiExamination/bookingpages/intravitrealinjection/index` → 403) and the sample DB has zero `ophciexamination_injectionmanagement_v2_order` rows, so the list is empty there for data reasons either way.
- **Severity**: medium-low
- Found by workflow batch 01 verify agent (as "unset setting binds NULL → list always empty"); orchestrator refuted the NULL-bind mechanism (metadata default exists and getSetting falls back to it) but confirmed the inert booking-status filter and logged the NULL path as a latent hazard.

## BUG-098: Transport screen "no GP practice" warning banner is permanently visible dead markup (CONFIRMED)
- **Where**: `protected/modules/OphTrOperationbooking/views/transport/_list_header.php:27-29` and `views/transport/_list.php:27-30` — an unconditional `<div id="no_gp_warning" class="alert-box alert with-icon hide">` ("One or more patients has no GP practice, please correct in PAS before printing GP letter"). The `hide` class has no rule in any stylesheet the page loads (style_openeyes.css, jquery-ui themes, voice-widget.css — all grepped), there are no inline `<style>` blocks, and a repo-wide grep finds no JS that references `no_gp_warning` or toggles `.hide` — the only `no_gp_warning` hits are the two view files themselves.
- **Impact**: low — the warning shows on every Transport page load regardless of whether any listed patient is missing a GP practice, and it references printing a GP letter, a feature the Transport screen does not have. The properly gated equivalent lives on the waiting list (`views/waitingList/_list.php:233-240` — per-row `if (!$patient->practice ...)` plus `$('#pas_warnings').show()`), suggesting the banner was copied over without its mechanism.
- **Repro**: log in as admin (institution 1, site 1); GET `/OphTrOperationbooking/transport/index` → 200 with the banner div rendered and no CSS/JS to hide it (reproduced live this session).
- **Severity**: low
- Found by workflow batch 01 verify agent; confirmed by orchestrator in source (both views, CSS bundles, JS grep) and live render.

## BUG-099: EUR report — module ReportController override drops the guest guard, so logged-out access 500s instead of redirecting (CONFIRMED)
- **Where**: `protected/modules/OphTrOperationbooking/controllers/ReportController.php:4-11` `accessRules()` returns a single `array('allow', 'actions' => array('EUR','runreport','downloadreport'))` with NO `roles`/`users` key — Yii's `CAccessControlFilter` treats a keyless allow rule as matching everyone, including guests. This overrides the correctly role-gated parent `BaseReportController::accessRules()` (`protected/controllers/BaseReportController.php:27-30` → `array('allow','roles'=>array('Report'))`). `actionEUR()` (:19-23) then hand-checks `checkAccess('Report')` and `throw new CException("Not authorised: Only for consultant")`, which surfaces as a raw stack-trace HTTP 500 rather than the standard login redirect.
- **Impact**: low — minor information disclosure: an unauthenticated request to the EUR report gets a raw exception/stack trace (500) instead of a clean 302 to login. `runreport`/`downloadreport` are also un-gated by the override but only act on `$_POST`, so a guest GET is a harmless no-op there; EUR is the live surface. No documented page content is affected (the doc page is source-correct).
- **Repro**: logged out, `curl -s -o /dev/null -w '%{http_code}' http://localhost/OphTrOperationbooking/report/eur` → `500` (body contains "Not authorised: Only for consultant"), versus `302` for sibling report routes tested the same way (`OphTrIntravitrealinjection/report/injections`) — reproduced live this session.
- **Severity**: low
- Found by reporting batch 01 verify agent; confirmed by orchestrator (subclass override vs role-gated parent in source; guest 500-vs-302 live).

## BUG-100: Prism Reflex - Prism Base admin page shows the wrong heading ("Prism Reflex - Distance") — copy-paste title arg (CONFIRMED)
- **Where**: `protected/modules/OphCiExamination/controllers/traits/AdminForPrismReflex.php:36` — the Prism Base admin action calls `$this->genericAdmin('Prism Reflex - Distance', ...)` with `'description' => 'Prism Base Options for Prism Reflex'` (:39). The title arg is a copy-paste slip (an unrelated "…- Distance" page); it drives the page `<h2>`, while the left-nav breadcrumb is set from the correct menu label "Prism Reflex - Prism Base".
- **Impact**: low, cosmetic — a user who navigates to Prism Base via the correct menu label lands on a page whose heading says "Distance", contradicting the breadcrumb and the menu they clicked.
- **Repro**: log in admin/admin (institution 1, site 1); GET `/OphCiExamination/admin/DioptrePrismPrismBase` → page `<h2>` renders "Prism Reflex - Distance" while the breadcrumb reads "Prism Reflex - Prism Base" (reproduced live this session).
- **Severity**: low
- Found by examination-admin batch 03 verify agent; confirmed by orchestrator in source (:36 title vs :39 description) and live render (h2 vs breadcrumb).

## BUG-101: Clinical Maculopathy admin list shows Retinopathy national-grade labels (R0/R1) — hardcoded relation not overridden in subclass (CONFIRMED)
- **Where**: `protected/modules/OphCiExamination/models/OphCiExamination_Clinical_Grade.php:46` — `relations()` hardcodes `"national" => [BELONGS_TO, 'OphCiExamination_Retinopathy_National_Grade', 'national_grade_default']`. `OphCiExamination_Maculopathy_Clinical_Grade` (`OphCiExamination_Maculopathy_Clinical_Grade.php:35`) extends this base and does NOT override `relations()`, so its `national` relation resolves against the Retinopathy national-grade table. The admin list view renders `$model->national->value` in the "National Grade Default" column.
- **Impact**: low, display-only — the Clinical Maculopathy admin list ("National Grade Default" column) shows Retinopathy grade text (R0/R1) on Maculopathy rows. Stored data is unaffected: the add/edit form branches by pathy and picks the correct national model for its dropdown, so only the list column is mislabelled.
- **Repro**: log in admin/admin (institution 1, site 1); GET `/OphCiExamination/admin/DRGrading/ViewClinicalMaculopathy` → "National Grade Default" column shows R0/R1 (reproduced live: 1×R0, 4×R1, plus one "No maculopathy").
- **Severity**: low
- Found by examination-admin batch 01 verify agent; confirmed by orchestrator in source (hardcoded relation, no subclass override) and live render.

## BUG-102: Visual Outcome analytics chart title hardcodes "(Distance)" regardless of selected VA type (CONFIRMED)
- **Where**: `protected/modules/OphCiExamination/components/VisualOutcomeReport.php:419` — `plotlyConfig()` sets `$this->defaultPlotlyConfig['title'] = 'Visual Acuity (Distance)<br><sub>Total Eyes: ...'` unconditionally, ignoring the selected reading type.
- **Impact**: low, cosmetic — selecting the Near VA type still renders a chart titled "Visual Acuity (Distance)". No data impact; the report body uses the correct type.
- **Repro**: run the Visual Outcome analytics report with the Near type selected → chart title still reads "Visual Acuity (Distance)" (source-confirmed; title string is a static literal).
- **Severity**: low
- Found by reporting batch 00 verify agent; confirmed by orchestrator in source.

## BUG-103: OETrial "Display report" is non-functional — no report view partial exists (CONFIRMED, source)
- **Where**: `protected/modules/OETrial/controllers/ReportController.php` exposes the generic `runReport` action, but `BaseReport::getView()` (`protected/models/BaseReport.php:28,43`) derives the partial name `'_' . strtolower(preg_replace('/^Report/','',$model))` → `_trialcohort`, and there is no `protected/modules/OETrial/views/report/` directory at all (confirmed absent). Rendering the report therefore fails on a missing partial; only the CSV download path works.
- **Impact**: low-medium — the on-screen "Display report" for the trial cohort report cannot render; users must use CSV export. (The doc page was corrected to point at the working entry path.)
- **Repro**: source-confirmed — `views/report/` directory does not exist under OETrial and `getView()` resolves to `_trialcohort`. Full live trigger needs an authenticated POST to `/OETrial/report/runReport?report-name=TrialCohort&trialID=<id>` (not executed under the GET-only rule); the missing-view path is unavoidable once reached.
- **Severity**: low-medium
- Found by reporting batch 00 verify agent; source direction confirmed by orchestrator (missing views/report dir + getView derivation). Distinct from BUG-071 (OETrial trial/view TypeError).

## BUG-104: Visual Outcome LogMAR banding uses sequential ifs — exact 0.00 lands in the wrong band (CONFIRMED)
- **Where**: `protected/modules/OphCiExamination/components/VisualOutcomeReport.php:273-294` — the x-axis (and identically the y-axis) banding uses six independent `if` statements rather than `elseif`. A value of exactly `0.00` matches both `$xPoint <= 0` (band 5, "0.00 or better") and `$xPoint >= 0 && $xPoint <= 0.30` (band 4), and the later assignment wins, so 0.00 readings are counted in the "0.00 to 0.30" band instead of "0.00 or better".
- **Impact**: low — a boundary-value miscount in the Visual Outcome scatter/band chart; exact-0.00 LogMAR readings land one band low. Not describable in plain-English docs, so no doc change.
- **Repro**: source-confirmed — feed a LogMAR value of exactly 0.00; band 4 overwrites band 5.
- **Severity**: low
- Found by reporting batch 00 verify agent; confirmed by orchestrator in source.

## BUG-105: Strabismus Management Treatments/Options have no delete protection and no FK — deleting a treatment silently orphans its options (CONFIRMED)
- **Where**: `protected/modules/OphCiExamination/controllers/traits/AdminForStrabismusManagement.php:26-90` — neither `actionStrabismusManagementTreatments()` nor `actionStrabismusManagementTreatmentOptions()` passes a `cannot_delete` callback to `genericAdmin()`, and neither model carries an `active` flag (so `GenericAdmin`'s `active_prevents_delete` default cannot apply). There is also NO database foreign key from `ophciexamination_strabismusmanagement_treatmentoption.treatment_id` to `ophciexamination_strabismusmanagement_treatment.id` (information_schema.KEY_COLUMN_USAGE returns zero referencing rows).
- **Impact**: low-medium, data integrity — the Strab Mgmt Treatments admin list offers an unconditional delete on every treatment. Deleting a treatment that still has Treatment Options leaves those option rows pointing at a non-existent `treatment_id` (silent orphan), with no app-layer guard and no DB constraint to stop it.
- **Repro**: source + schema confirmed (no callback in either genericAdmin call; no FK on the option table). Not executed live per the GET-only rule (would require a destructive delete POST); the delete control is present and unconditional on `/OphCiExamination/admin/StrabismusManagementTreatments`.
- **Severity**: low-medium
- Found by examination-admin batch 04 verify agent; confirmed by orchestrator in source and DB schema.

## BUG-106: Strab Treatment Options admin screen is silently blank until a not-null filter is supplied in the URL (CONFIRMED)
- **Where**: `protected/controllers/BaseAdminController.php:181-189` sets `filters_ready=false` whenever a filter field declared `allow_null=false` has no GET value; the Strab option screen declares `column_number` as `allow_null=false` (`AdminForStrabismusManagement.php:65-68`). With `filters_ready=false` the list table, Add and Save controls are not rendered — only the filter dropdowns.
- **Impact**: low, UX — GET `/OphCiExamination/admin/StrabismusManagementTreatmentOptions` with no query string returns 200 but shows only filter dropdowns and no list/Add/Save UI and no message explaining why; the screen looks broken. Appending a filter (e.g. `?treatment_id=1&column_number=1`) makes the full `standard generic-admin sortable` list table appear.
- **Repro**: log in admin/admin (institution 1, site 1); GET the option screen with no query → the `standard generic-admin sortable` table is absent (live, 99KB page, no list table); GET again with `?treatment_id=1&column_number=1` → list table present (103KB) — reproduced live this session.
- **Severity**: low
- Found by examination-admin batch 04 verify agent; confirmed by orchestrator in source and live render.

## BUG-107: Visit Intervals admin — institution filter pre-selects by name not id, so current institution never shows selected (CONFIRMED)
- **Where**: `protected/modules/OphCiExamination/controllers/AdminController.php:1030-1032` — the `institution_id` filter field is given `'value' => \Institution::model()->getCurrent()->name` while its `'choices' => \Institution::model()->getTenantedList(true)` returns options keyed by institution **id** (`Institution.php:245` → `$result[$current_institution->id] = $current_institution->name`). The pre-selected value (a name string) can never equal an option key (an id), so no option is marked selected.
- **Impact**: low, UX — on Admin > Examination > Visit Intervals the Institution dropdown always renders on the empty "-- Select --" placeholder (even for a single-institution admin), and because this is a not-null filter the intervals table stays hidden until the institution is manually chosen or `?institution_id=<id>` is appended. Related to the filters_ready pattern in BUG-106.
- **Repro**: log in admin/admin (institution 1); GET `/OphCiExamination/admin/manageVisitIntervals` → the option `<option value="1">The Monachs Trust</option>` is present but carries no `selected` attribute (confirmed live this session); the interval rows do not show until the institution is selected.
- **Severity**: low
- Found by examination-admin batch 05 verify agent; confirmed by orchestrator in source (name-vs-id type mismatch) and live DOM.

## BUG-108: Deleting an in-use Cataract "Reason for Surgery" 500s — FK RESTRICT unhandled by the generic admin delete loop (CONFIRMED; systemic pattern)
- **Where**: `protected/modules/OphCiExamination/controllers/AdminController.php:1087-1094` `actionPrimaryReasonForSurgery()` calls `genericAdmin()` with no `cannot_delete` callback. The generic delete loop `protected/controllers/BaseAdminController.php:301-309` only handles the `false` return from `$item->delete()` (Active-Record validation) and has NO try/catch. The DB enforces `et_ophciexamination_cataractsurgicalmanagement_surgery_reasons.primary_reason_for_surgery_fk` with `DELETE_RULE = RESTRICT` (confirmed via information_schema), so deleting a referenced reason throws an uncaught `CDbException` (1451) → raw framework 500 instead of a friendly "in use" flash. 6 of the 7 seeded reasons are currently referenced.
- **Impact**: low-medium — retiring then purging a still-referenced surgery reason produces a raw error page rather than a graceful message. Contrast the Botox Management lookups, which pass an in-use check and hide the delete control. This is the FK-exists-but-unhandled sibling of BUG-105 (no-FK silent orphan); the same unguarded-genericAdmin shape is also latent on Surgery Management Options (`surgery-management-options`, FK from `et_ophciexamination_currentmanagementplan` confirmed) and likely other genericAdmin lookups lacking a `cannot_delete` callback.
- **Repro**: source + schema confirmed (RESTRICT FK; no callback; delete loop catches only validation, not exceptions). Not executed live per the GET-only rule (needs a destructive delete POST on an inactive-but-referenced row); the delete control appears once a reason is marked inactive.
- **Severity**: low-medium
- Found by examination-admin batch 00 verify agent; confirmed by orchestrator in source, DB schema and reference counts.
- **Additional confirmed instance (Operation booking > Scheduling options)**: `AdminController::actionViewScheduleOptions()` calls `genericAdmin()` on `OphTrOperationbooking_ScheduleOperation_ScheduleOptions` with no `cannot_delete` callback and no model guard; `et_ophtroperationbooking_scheduleope.schedule_options_fk` is `DELETE_RULE = RESTRICT`, and all four seeded options are referenced (267 / 25 / 20 / 81 rows). Deleting any of them from the screen therefore raises an uncaught `CDbException` and, because the delete loop is inside the same transaction as the saves, any other edit made on that visit is discarded with it. Source + DB-schema confirmed by orchestrator at `53b077c089`; not executed live (delete POST).
- **Additional confirmed instance (Anaesthetic Agents)**: `AdminController::actionViewAnaestheticAgent` → `genericAdmin()` with no `cannot_delete` callback; `protected/models/AnaestheticAgent.php` has no `beforeDelete()`/`delete()` guard; all 9 FK references to `anaesthetic_agent.id` are `DELETE_RULE = RESTRICT` (incl. `site_subspecialty_anaesthetic_agent`, `site_subspecialty_anaesthetic_agent_default`). Same unguarded delete-by-omission path → uncaught `CDbException` when deleting a deactivated-but-referenced agent. Source + DB-schema reconfirmed by orchestrator (9× RESTRICT, no model guard); not executed live (delete POST). Reported by the Drugs-A escalation verify agent.

## BUG-109: Admin > Consent > Extra Procedures "Delete" is dead — debug `print_r`/`exit()` short-circuits the delete action (CONFIRMED)
- **Where**: `protected/modules/OphTrConsent/controllers/oeadmin/ExtraProceduresController.php:150-152` — `actionDelete()` reads the selected ids then immediately runs `print_r($procedures); exit();` **before** the real delete `foreach` loop. Left-in debug code.
- **Impact**: low-medium — ticking one or more Extra Procedures rows and clicking Delete returns a raw `Array ( … )` `print_r` dump (or a blank/garbled AJAX response) and deletes nothing. The delete function is completely non-functional; an administrator cannot remove an extra procedure through the UI.
- **Repro**: Admin > Consent > Extra Procedures → tick any row → click Delete. Observed in source (the `exit()` guarantees the outcome); not driven live per the GET-only rule (needs a delete POST).
- **Severity**: low-medium
- Found by admin-clinical batch 00 verify agent; confirmed by orchestrator reading the container source at the cited lines.

## BUG-110: Admin > Consent > Extra Procedures "Active" search filter queries a non-existent column → SQL error (CONFIRMED)
- **Where**: filter control rendered at `protected/modules/OphTrConsent/views/oeadmin/ExtraProcedures/index.php:50-53` ("Only Active" = 1, "Exclude Active" = 0); handled at `ExtraProceduresController.php:47-50`, which adds `t.active = 1` / `t.active != 1` to the search criteria. The backing table `ophtrconsent_procedure_extra` has **no `active` column** (confirmed via `DESCRIBE`: id, term, short_format, snomed_code, snomed_term, aliases, last_modified_*, created_* only).
- **Impact**: low — choosing "Only Active" or "Exclude Active" and searching throws `SQLSTATE 42S22 / Unknown column 't.active'` (a 500 / error response) instead of filtering. The default (blank) filter is unaffected because neither branch fires on an empty value.
- **Related dead code**: `protected/modules/OphTrConsent/models/OphTrConsent_Extra_Procedure.php:158-159` `getListBySubspecialty()` has the same false assumption plus an undeclared table alias `proc` (the FROM clause is unaliased) — it would SQL-error if ever called; currently appears unreferenced. Same root cause: the Extra Procedures code assumes an `active`/deactivation model that was never added to this table.
- **Repro**: Admin > Consent > Extra Procedures → set the Active filter to "Only Active" → Search. Confirmed in source + schema (control rendered, condition added, column absent); live search submission not executed per GET-only discipline, but the three static facts make the SQL error deterministic.
- **Severity**: low
- Found by admin-clinical batch 00 verify agent; confirmed by orchestrator against container source, the view, and `DESCRIBE`.

## BUG-111: Payload-processor Requests admin — "Actions" column toggle checkbox is dead UI (CONFIRMED)
- **Where**: the filter checkbox is rendered at `protected/modules/Api/modules/Request/modules/RequestAdmin/views/request/request_filters.php:144-145` as a hidden `actions=0` + `CHtml::checkBox("actions", …)` labelled "Actions". But in `.../views/request/index.php` every other column's header and cells are visibility-gated on `getParam('show_<column>')` (e.g. `show_id`, `show_overall_status` at lines 40-47) while the Actions column header `<th>Actions</th>` (line 33) and its cell have no guard, and nothing in the view ever reads `getParam('actions')`.
- **Impact**: low — unticking "Actions" and clicking Filter has no effect; the Actions column is always shown. The checkbox name (`actions`) also doesn't match the `show_*` convention the reader would expect.
- **Repro**: log in as admin, open `/Api/Request/admin/request/index?actions=0` — the Actions column remains visible (GET-only, non-destructive).
- **Severity**: low
- Found by admin-sample batch 02 verify agent; confirmed by orchestrator reading both the filter partial and the list view in the container.

## BUG-112: Visual Field Test Presets admin — third column mislabelled "SITA Standard" for all test types (CONFIRMED)
- **Where**: `protected/models/VisualFieldTestPreset.php:95` — `attributeLabels()` hardcodes `'option_id' => 'SITA Standard'`. `option_id` is a generic BELONGS_TO FK to `VisualFieldTestOption` (line 83), whose values are the speed tiers Standard / Fast / Faster.
- **Impact**: low (cosmetic) — the option column header reads "SITA Standard" for every preset regardless of the strategy type, including Goldmann and Estermann presets where SITA does not apply. Same copy-paste-label family as BUG-100.
- **Repro**: `/Admin/worklist/visualFieldTestPresets` — the third column header reads "SITA Standard" for all rows (GET-only).
- **Severity**: low (cosmetic)
- Found by admin-sample batch 02 verify agent; confirmed by orchestrator reading `attributeLabels()` and the `option` relation in the container.

## BUG-113: Anaesthetic Agent Mapping admin — menu label and on-page heading are different names for one screen (CONFIRMED)
- **Where**: menu label `protected/config/core/admin.php:80` = `'Anaesthetic Agent Mapping Op Note'`; on-page heading `protected/controllers/oeadmin/AnaestheticAgentMappingController.php:34` = `setModelDisplayName('Operation Note Anaesthetic Agent Mapping')`.
- **Impact**: low — the sidebar entry (Admin > Drugs) and the page heading name the same screen differently, so a user searching for the screen by its heading text won't match the menu item. Same copy/label family as BUG-094.
- **Repro**: log in admin/admin → Admin > Drugs sidebar; compare the menu link text to the heading on the opened page (GET-only).
- **Severity**: low
- Found by admin-sample batch 01 verify agent; confirmed by orchestrator against `admin.php` and the controller in the container.

## BUG-114: Deleting an in-use Advice Leaflet raw-500s — `isInUse()` guard defined but never wired into the delete path; delete also redirects to the wrong list (CONFIRMED)
- **Where**: `protected/modules/Admin/modules/Leaflets/controllers/LeafletController.php:99-108` `actionDelete()` calls `$leaflet->delete()` unconditionally. The model `protected/modules/OphCiExamination/models/AdviceLeaflet.php` **defines** `isInUse()` (line 228 — true when the leaflet has `leaflet_entries` or `leaflet_consent_assignments`) but neither the controller nor `beforeDelete()` (line 162) ever calls it. `beforeDelete()` cascades away only the category and type assignments — 2 of the 4 RESTRICT foreign keys. The other two, `ophciexamination_advice_leaflet_entry.leaflet_id` and `ophtrconsent_leaflet_assignment.leaflet_id` (both `DELETE_RULE = RESTRICT`, confirmed via information_schema), are exactly the two relations `isInUse()` was written to check.
- **Impact**: low-medium — deleting a leaflet that is recorded in a patient event or attached to a consent throws an uncaught `CDbException` (1451) → raw 500 error page, instead of the graceful "cannot be deleted" block the intended `isInUse()` guard would give. (Outcome matches the doc's "in-use leaflets cannot be deleted", but via an error page, not a clean message.) Secondary defect in the same 8-line method: after a successful delete it redirects to `/Admin/Leaflets/LeafletCategory/index` (the **Categories** list), not the Leaflets list — a copy-paste from `LeafletCategoryController`.
- **Repro**: source + schema confirmed (unused `isInUse()`; `beforeDelete()` handles only 2 of 4 FKs; 2 RESTRICT FKs remain; wrong redirect literal). Not driven live per GET-only (needs a delete POST). Same systemic family as BUG-105/108 (delete paths without a working in-use guard), and notably worse here because the guard exists but is never called.
- **Severity**: low-medium
- Found by admin-sample batch 01 verify agent; the raw-exception mechanism was refined and confirmed by orchestrator (the agent's original "no in-use pre-check" claim was correct in outcome; the precise cause is the un-wired `isInUse()` + partial `beforeDelete()` cascade).

## BUG-115: CVI Preferred Info Format admin — "Require Email" checkbox is inert dead data (CONFIRMED)
- **Where**: the flag is exposed as an editable boolean column via `genericAdmin()` at `protected/modules/OphCoCvi/controllers/AdminController.php:483` (`'field' => 'require_email'`) and persisted on `OphCoCvi_ClericalInfo_PreferredInfoFmt` (`ophcocvi_clericinfo_preferred_info_fmt.require_email`). A full-tree grep shows the only other references are config replication (`OphCoCvi/... ` none in runtime; `OeConfig/config/pages/preferred_info_format.php` SELECT/UPSERT for config sync) and the OeMerge migration tooling — no runtime business logic ever reads it. The CVI clerical/demographics form (`views/default/form_Element_OphCoCvi_Demographics.php:60-61`) renders the Email field unconditionally and never references `require_email`.
- **Impact**: low — an administrator can tick/untick "Require Email" on any preferred-info-format row and Save, but it changes nothing in the application; it is stored, sync-replicated and merged but never acted on. Confusing/dead admin control.
- **Repro**: Admin > CVI > Preferred Info Format → toggle "Require Email" on a row → Save → open a patient's CVI clerical form → the Email field is present regardless of the flag. (Static confirmation via full-tree grep; live toggle is a state-changing Save, not executed per GET-only.)
- **Severity**: low
- Found by admin-sample batch 00 verify agent; the inert-flag core confirmed by orchestrator via full-tree grep. (The agent's additional theory that email behaviour is instead driven by the option Name containing "email" was not reproducible in source and is omitted here.)

## BUG-116: Operation Booking "Session Unavailable Reasons" admin page shows the wrong heading "Patient Unavailable Reasons" (CONFIRMED)
- **Where**: `protected/modules/OphTrOperationbooking/views/admin/sessionunavailablereasons.php:21` hard-codes `<h2>Patient Unavailable Reasons</h2>`. This view is rendered by `AdminController::actionViewSessionUnavailableReasons()` (`protected/modules/OphTrOperationbooking/controllers/AdminController.php:1939-1943`, `$this->render('sessionunavailablereasons')`) and reached from the admin menu entry "Session unavailable reasons" → `/OphTrOperationbooking/admin/viewSessionUnavailableReasons` (`config/common.php:77`). A genuinely separate page exists — menu entry "Patient unavailable reasons" → `actionViewPatientUnavailableReasons()` (`AdminController.php:1818`) with its own `views/admin/patient_unavailable_reasons/` view dir — so the two are distinct admin screens and the Session one is displaying the Patient one's title.
- **Impact**: low/cosmetic — an administrator who opens **Admin > Operation Booking > Session unavailable reasons** sees the page titled "Patient Unavailable Reasons", which is confusing given the adjacent, distinct "Patient unavailable reasons" screen. Functionality is unaffected; only the heading label is wrong.
- **Repro**: log in as admin/admin (institution 1, site 1), GET `/OphTrOperationbooking/admin/viewSessionUnavailableReasons`, observe the `<h2>` reads "Patient Unavailable Reasons" (source-confirmed at `sessionunavailablereasons.php:21`; requires `disable_theatre_diary` setting off, which is the default).
- **Severity**: low
- Found by op-booking escalation verify agent; both directions confirmed by orchestrator in container (view file:line + rendering action + distinct Patient action/view + both menu entries in config/common.php).

## BUG-117: OeStats module fails to load (HTTP 500) on case-sensitive filesystems — module file name does not match the class it declares (CONFIRMED)
- **Where**: `protected/modules/OeStats/OestatsModule.php` (note the lowercase "tats" in the file name) declares `namespace OEModule\OeStats; class OeStatsModule extends \BaseModule` (line 3/12) — i.e. the class is `OEModule\OeStats\OeStatsModule`. Yii/PSR-4 autoloading maps that class to a file named `OeStatsModule.php`, which does not exist on a case-sensitive filesystem (the file is `OestatsModule.php`). The module is registered in `protected/config/local/common.php:61` as `'OeStats' => ['class' => OEModule\OeStats\OeStatsModule::class]` — the registration is correct and matches the class; the file name is the mismatch. (The three sibling modules registered the same way — NodAudit, OeDatabase, OeDocBuilder — have file names that match their class names and load fine.)
- **Impact**: low-medium — whenever the OeStats module is enabled on a case-sensitive filesystem (i.e. any Linux server, including production), every OeStats route throws a `CException` during module resolution before any controller runs. `/OeStats/default/index` (Dashboard), `/OeStats/default/userStats` and `/OeStats/default/versionHistory` are all unreachable. In this documentation environment the module is enabled via `local/common.php:61`, so all three screens currently 500. (OeStats is not enabled by core config, only by this deployment's local config, so a default install may not surface it — but the file/class name mismatch is a latent code defect that guarantees total module failure on Linux whenever the module is turned on.)
- **Repro**: `docker exec snail-web-1 curl -s -o /dev/null -w '%{http_code}\n' http://localhost/OeStats/default/index` → `500` (also 500 when logged in as admin/admin, institution 1, site 1). Source confirmation: `OestatsModule.php` declares `class OeStatsModule`, so the file should be `OeStatsModule.php`.
- **Fix**: rename `OestatsModule.php` → `OeStatsModule.php` (or, less cleanly, add an explicit class-map/alias). No configuration-only fix is possible because the class genuinely is `OeStatsModule`.
- **Severity**: low-medium
- **Latent secondary (not separately logged)**: once the module loads, `OeStats\controllers\DefaultController::accessRules()` returns only `[['allow','roles'=>['admin']]]` with no trailing deny-all, so under Yii's `CAccessControlFilter` a non-admin authenticated user could reach the screens by direct URL (fail-open). Cannot manifest while BUG-117 keeps the module unloadable; flagged for the same fix visit.
- Found by reference-A verify agent (three OeStats pages left correctly in `draft` because the live-verification leg cannot pass); file/class mismatch and live 500 independently reconfirmed by orchestrator in container.

## BUG-118: Practice (GP practice) view screen heading is misspelled "Practitice Summary" (CONFIRMED)
- **Where**: `protected/views/practice/view.php:14` renders `<div class="title wordcaps">Practitice Summary</div>` — "Practitice" should be "Practice".
- **Impact**: low/cosmetic — the practice detail screen (reached from the Practices directory) shows a misspelled page title. No functional effect.
- **Repro**: log in as admin/admin (institution 1, site 1), open a practice from the Practices directory (`/practice/view/<id>`); the heading reads "Practitice Summary". Source-confirmed at `practice/view.php:14`.
- **Severity**: low
- Found by reference-A verify agent; confirmed by orchestrator via container source grep.
- **Duplicate of BUG-059**, which records the same typo in the same view. BUG-059 is the canonical entry; the two cite line 16 and line 14 of `protected/views/practice/view.php` because they were read at different commits. Fix once.

## BUG-119: NOD Audit export confirmation modal gives contradictory (and incorrect) "do not close this window" guidance (CONFIRMED)
- **Where**: `protected/modules/NodAudit/views/default/index.php:150-151` — the confirmation modal says "This process may take **several minutes** and will run in the background." immediately followed by "Do not close this window until the export completes." The two sentences contradict each other, and the second is factually wrong: the export runs server-side and survives navigation/tab closure (the action sets `ignore_user_abort`; the run's progress is tracked by `NodAuditRun` status and offered via a later "Go to Downloads" button, not a live in-page link).
- **Impact**: low — misleading user guidance; a user may needlessly keep the tab open (or fear cancelling by closing it) when the job is unaffected. Purely a wording defect.
- **Repro**: log in as admin/admin (institution 1, site 1), open **NOD Audit** (`/NodAudit/default/index`), start an export to trigger the confirmation modal; read the two adjacent sentences. Source-confirmed at `NodAudit/views/default/index.php:150-151`.
- **Severity**: low
- Found by reference-A verify agent (which also corrected the companion doc `nod-audit-default-run.md` to state the export survives tab closure); modal text confirmed by orchestrator via container source grep.

## BUG-120: Therapy Application "Edit Stop Reason" — Cancel button navigates to the wrong list (Treatments instead of Stop Reasons) (CONFIRMED)
- **Where**: `protected/modules/OphCoTherapyapplication/controllers/AdminController.php` `actionEditStopReason()` renders the `update` view with `'cancel_uri' => '/OphCoTherapyapplication/admin/viewTreatments'`, while a successful save redirects to `viewStopReasons`. The Cancel control therefore returns the admin to the **Treatments** list, not the **Stop Reasons** list they came from.
- **Impact**: low — cancelling an edit of an Exceptional-Circumstances Stop Reason drops the user on a different admin screen than the one they were working in. Confusing navigation; no data effect.
- **Repro**: log in as admin/admin (institution 1, site 1), GET `/OphCoTherapyapplication/admin/editStopReason/1`; the rendered Cancel button carries `data-uri="/OphCoTherapyapplication/admin/viewTreatments"` (GET-confirmed; contrast the Save redirect to `viewStopReasons`).
- **Severity**: low
- Found by therapy/generic-event admin-draft verify agent; confirmed by orchestrator in container source.

## BUG-121: Admin delete paths lack FK-violation handling in several more places — deleting an in-use lookup raw-500s (CONFIRMED; systemic, siblings of BUG-105/108)
- **Summary**: BUG-108 documented the unguarded delete loop in `BaseAdminController::genericAdmin()`. The same "call `->delete()`, check only the boolean, no try/catch around a DB-level `CDbException`" shape recurs in at least three further, independent admin delete paths, each behind a `DELETE_RULE = RESTRICT` foreign key — so deleting a referenced row throws an uncaught exception and renders a raw framework 500 instead of a friendly "in use" message.
- **Confirmed loci**:
  1. **`Admin::deleteModel()`** (`protected/components/Admin.php`, hard-delete `else` branch ~line 718): when the model has no `active` attribute it calls `$model->delete()` unguarded. **DNA Storage Boxes** (`OphInDnaextraction_DnaExtraction_Box`, table `ophindnaextraction_dnaextraction_box`) have no `active` column, so bulk-deleting a box on `/OphInDnaextraction/DnaExtractionBoxAdmin/list` takes this branch; the FK `ophindnaextraction_storage_address → ophindnaextraction_dnaextraction_box` is RESTRICT (DB-confirmed), so deleting an in-use box 500s. (Contrast `OphInLabResults/.../ResultTypeController` which wraps the same pattern in try/catch and renders a red banner.)
  2. **`OphCoTherapyapplication AdminController::actionDeleteStopReasons()`** (~line 634-645): plain `foreach (...) $stop_reason->delete()` loop, no try/catch. FK `ophcotherapya_exceptional_pastintervention.stopreason_id` is RESTRICT (DB-confirmed); sample data references a stop reason, so deleting an in-use Exceptional-Circumstances Stop Reason 500s.
  3. **`OphCoTherapyapplication AdminController::actionDeleteFileCollections()`** (~line 496-511): clears the collection's own file assignments but not `ophcotherapya_exceptional_filecoll_assignment.collection_id` (FK RESTRICT, DB-confirmed). Latent — no referencing rows in the current sample DB — but the same failure mode once a collection is assigned.
- **Impact**: low-medium — as BUG-108: retiring then purging a still-referenced lookup produces a raw error page rather than a graceful message, across several admin screens. No corruption (the DB blocks the delete).
- **Repro**: source + DB-schema confirmed (RESTRICT FKs; unguarded delete calls). Not executed live per the GET-only rule (each needs a destructive delete POST). A related but distinct cosmetic case (not a 500): the Generic Event assessment delete actions echo `'0'` on a blocked delete and the client shows a hardcoded, non-specific "One or more Element attributes could not be deleted as they are in use" message — handled, but misleading; recorded as a gate note only.
- **Severity**: low-medium
- Found by CVI/genetics and therapy/generic-event admin-draft verify agents; delete-path source and every FK delete-rule independently reconfirmed by orchestrator in the container (box has no `active` column; all cited FKs RESTRICT).

## BUG-122: DNA Storage Box name has no length validation before a varchar(5) column — over-length name yields a raw DB "Data too long" error (CONFIRMED)
- **Where**: `OphInDnaextraction_DnaExtraction_Box::rules()` (`protected/modules/OphInDnaextraction/models/OphInDnaextraction_DnaExtraction_Box.php:51-63`) declares `value` (labelled "Box name") only as `required` and `safe` — there is no `length`/`max` validator — and the edit input renders no `maxlength`. The backing column `ophindnaextraction_dnaextraction_box.value` is `varchar(5)` (DB-confirmed). Under MariaDB strict mode a name longer than 5 characters is rejected at the DB layer.
- **Impact**: low — saving a DNA Storage Box with a >5-character name surfaces a raw framework/DB "Data too long for column 'value'" error page instead of a friendly inline validation message. Purely an ungraceful-validation defect (no corruption; the save is rejected).
- **Repro**: source + schema confirmed (no length validator; `varchar(5)`; strict mode). Not driven live per the GET-only rule (needs an over-length save POST on `/OphInDnaextraction/DnaExtractionBoxAdmin`).
- **Severity**: low
- Found by CVI/genetics admin-draft verify agent; model rules and column type reconfirmed by orchestrator in the container.

## BUG-123: PASAPI XPath Remap — admin-created remaps save with NULL institution and are permanently invisible/inert (CONFIRMED)
- **Where**: `protected/modules/PASAPI/modules/PASAPIAdmin/controllers/DefaultController.php` — `actionCreateXpathRemap()` (lines 43-51) and `actionUpdateXpathRemap()` (72-82) populate only `$model->xpath` and `$model->name` from POST; they never set `$model->institution_id`. The `XpathRemap` model has no `beforeSave`/behaviour that fills it (rules mark `institution_id` only `safe`), and the column `pasapi_xpath_remap.institution_id` is nullable with default NULL (DB-confirmed). Meanwhile the admin list query filters `institution_id = <selected_institution>` (line 36) and the runtime lookup `XpathRemap::findByXpath()` filters the same (lines 79-80).
- **Impact**: medium — the admin create/edit form renders an **Institution** dropdown, but that POST value is silently discarded, so every remap saved through the admin UI lands with `institution_id = NULL`. Such a remap never appears in the institution-scoped admin list and is never matched during PAS message processing — the XPath Remap feature is effectively non-functional when configured via its own admin screen. (Niche PAS-integration feature; empty in the sample DB.)
- **Repro**: GET-visible symptom — admin/admin, institution 1: GET `/PASAPI/admin/default/viewXpathRemaps` returns an empty list. Root cause is source + schema confirmed (create/update actions ignore `institution_id`; column defaults NULL; list and runtime both filter on `institution_id`). Not driven live (needs a create POST, which per source would persist NULL and leave the list unchanged).
- **Severity**: medium
- Found by payload-processor-api/pasapi admin verify agent; controller, model, and column nullability independently reconfirmed by orchestrator in the container. (value-remaps.md already documents this accurately as a current limitation — no doc change; this entry records the underlying app defect.)

## BUG-124: OeDataDictionary "Sync to MySQL Comments" — broken access control; any authenticated user can trigger schema-comment DDL via a GET (CONFIRMED)
- **Where**: `protected/modules/OeDataDictionary/controllers/DefaultController.php` — `accessRules()` (lines 11-38) lists `syncComments` in the first allow-block with `'users' => ['@']` (ANY authenticated user), alongside read-only actions, **not** in the `'roles' => ['admin']` block that gates its siblings (`edit`, `save`, `createSkeleton`, `groupSave`, …). `actionSyncComments()` (lines 849-884) has no internal `checkAccess` and no POST/CSRF guard; it iterates every documented table and executes `ALTER TABLE \`{name}\` COMMENT = '...'` (line 866). Access is enforced (`BaseController::filters()` returns `array('accessControl')`, `protected/controllers/BaseController.php:67-69`), so the `@` bucket genuinely applies.
- **Impact**: low-medium — any logged-in user (not just admins) can rewrite the MySQL COMMENT on all ~131 documented tables by issuing a single GET to `/OeDataDictionary/default/syncComments`. This is a privilege-boundary gap (the sibling write actions are admin-only), an unauthorized DDL operation, and — being a GET with no CSRF token — CSRF-triggerable via a crafted link followed by any authenticated user. Blast radius is limited to table COMMENT metadata (it overwrites existing comments with the doc descriptions; no row/data impact) and it is a heavy 131-table loop. The admin-only "Sync to MySQL Comments" button is correctly hidden from non-admins in the UI, but the underlying route is not gated.
- **Repro**: source-confirmed (accessRules bucket + no internal check + GET action body). Deliberately NOT triggered live (it mutates schema comments). A non-admin authenticated session issuing GET `/OeDataDictionary/default/syncComments` would run the sync.
- **Severity**: low-medium
- Found by database/data-dictionary admin verify agent; accessRules buckets, the missing internal check, the GET-only action body, and the enforced accessControl filter independently reconfirmed by orchestrator in the container.

## BUG-125: Patient Ticketing "Clinic Locations" drag-reorder is inert — display_order is saved but never used for ordering (CONFIRMED)
- **Where**: `protected/modules/PatientTicketing/modules/PatientTicketingAdmin/controllers/ClinicLocationsController.php` — `save()` persists `$model->display_order = $step` (line ~77), but `actionIndex()`'s list query (`ClinicLocation::model()->findAll($criteria)`, line 41) builds `$criteria` with only a `queueset_id` condition and no `->order`. The runtime ticket-assignment dropdown does the same: `TicketAssignOutcome::getClinicLocations()` (`protected/modules/PatientTicketing/widgets/TicketAssignOutcome.php:104-113`) builds `$criteria` with no `->order`. The `ClinicLocation` model has no `defaultScope()` and never references `display_order`. The column `patientticketing_clinic_location.display_order` exists (DB-confirmed).
- **Impact**: low — the admin grid renders sortable drag-reorder rows and persists `display_order` on Save, but nothing anywhere orders by it, so both the admin list and the runtime clinic-location dropdown fall back to primary-key/insert order. The reorder control is visually functional but functionally meaningless.
- **Repro**: GET-visible — Admin > Patient Ticketing > Clinic Locations: drag rows to a new order, Save, reload; the list order does not reflect the saved arrangement. Root cause source + schema confirmed (write at line 77; neither read query sets an order clause; no defaultScope). Not driven live via a reorder POST per the GET-only rule.
- **Severity**: low
- Found by patient-ticketing/laser admin verify agent; save path, both read queries, model, and column existence independently reconfirmed by orchestrator in the container.

## BUG-126: Biometry Lens Type edit — Position dropdown placeholder mislabelled "- Select Grade -" (CONFIRMED)
- **Where**: `protected/modules/OphInBiometry/views/admin/edit.php:44` — the `position_id` field renders `CHtml::activeDropDownList(..., ['empty' => '- Select Grade -'])`. The field is "Position" (options come from `OphInBiometry_Lens_Position`), but the empty/placeholder option reads "- Select Grade -", a stale copy-paste label from an unrelated grade form.
- **Impact**: low/cosmetic — every admin adding or editing a lens type sees the Position dropdown's placeholder as "- Select Grade -".
- **Repro**: admin/admin, institution 1, site 1: Admin > Biometry > Lens Types > Add (or edit any lens type); the Position field's placeholder option reads "- Select Grade -". Source-confirmed at edit.php:44.
- **Severity**: low
- Found by correspondence/biometry admin verify agent; view line independently reconfirmed by orchestrator in the container.

## BUG-127: `/patient/episode/<id>` and `/patient/episodes/<id>` are dead routes - the CVI create-cancel redirect lands on a 404 (CONFIRMED)
- **Where**: `PatientController` has no `actionEpisode` and no `actionEpisodes` (neither exists anywhere under `protected/`), yet both action names are still listed in its `accessRules()` allow block (`protected/controllers/PatientController.php:96`). The one live caller is `OphCoCvi/controllers/DefaultController.php:182-183`, which builds its cancel URL as `'/patient/episode/' . $this->episode->id` when an episode is in context and `'/patient/episodes/' . $this->patient->id` when it is not, then `redirect()`s to it. `protected/commands/ReportsCommand.php:409` and `:610` embed the same `/patient/episodes/{patient_id}` link in report output.
- **Route**: `/patient/episode/<episode_id>`, `/patient/episodes/<patient_id>`
- **Repro**:
  1. Log in and open a patient who already has an unissued CVI event.
  2. Start a new CVI: GET `/OphCoCvi/default/create?patient_id=<id>&createnewcvi=0` (the "do not create another CVI" answer), or answer the "one exists that has not been issued" prompt so the controller takes its cancel path.
  3. Observe the browser lands on `/patient/episode/<id>` (or `/patient/episodes/<id>` when the patient has no episode in context).
- **Expected**: cancelling returns the user to the patient's record.
- **Actual**: HTTP 404. Verified live this session with a logged-in session: `/patient/episodes/17885` -> 404, `/patient/episode/600580` -> 404, `/patient/summary/17885` -> 200.
- **Evidence**: in-container Puppeteer capture run, 2026-08-05, container commit `53b077c089`. Two orphaned views belong to the same rot: `protected/views/patient/episodes.php` and `protected/views/patient/_patient_episodes.php` are referenced by nothing in `protected/` and can never render (`_patient_episodes.php:44` itself links to the dead `/patient/episodes/` route). The replacement screen is `/patient/summary/<patient_id>`.
- **Severity**: medium - a normal cancel gesture in the CVI flow dumps the user on an error page.
- **Status**: open. Found while auditing Add Event coverage; the dead route was discovered when checking a reported missing `is_deceased` guard in `episodes.php`, which turned out to be unreachable code (see BUG-134).

## BUG-128: Add Event dialog - the "Support Services" subspecialty tile is a dead end, and its event-list filter is dead code (CONFIRMED)
- **Where**: `protected/components/NewEventDialogHelper.php:26-31` defines a synthetic subspecialty `['id' => 'SS', 'name' => 'Support Services', 'shortName' => 'SS', 'supportServices' => 1]`, used at line 54 for any episode whose firm has no subspecialty. That synthetic entry only ever reaches the dialog through `structureEpisodes()` (the patient's current episodes). The dialog's lookup table is built from `structureAllSubspecialties()` (`:108-138`), which iterates real `subspecialty` rows and never sets a `supportServices` key, so `self.subspecialtiesById['SS']` is always undefined. Two consequences in `protected/assets/js/OpenEyes.UI.Dialog.NewEvent.js`: the tile has no contexts to offer, and the `if (selectedSubspecialty.supportServices)` filter at `:479-486` - the branch that would hide every event type without `data-support-services` - can never be reached, because `updateEventList()` only runs its body once a context (`.step-2.selected`) is chosen.
- **Route**: `/patient/summary/<patient_id>` -> Add Event
- **Repro**:
  1. Log in and open a patient who has a support-services episode (5 exist in the sample data: patients 1919586, 2018037, 1985666, 1974010, 2218014).
  2. Click **Add Event**.
  3. In the Subspecialties column, click the **Support Services** tile.
- **Expected**: either a usable context and event list, or a message explaining that no events can be added under Support Services.
- **Actual**: the Context column renders with its heading and nothing else, the Select New Event column stays `visibility: hidden`, and no message is shown. The dialog is stuck until another subspecialty is clicked. No JavaScript error is raised.
- **Evidence**: driven live 2026-08-05 in the web container (Puppeteer, admin session, patient 1919586): dialog tiles included `SS :: Support Services`; after clicking it, `.step-context` text content was exactly "Context", `.step-event-types` computed `visibility: hidden`, page errors `[]`.
- **Severity**: medium - user-visible dead end on the most-used dialog in the application, reachable for any patient carrying a support-services episode.
- **Status**: open.

## BUG-129: Add Event dialog - event-subtype entries skip the permission check the event-type entries get (CONFIRMED)
- **Where**: `protected/views/patient/add_new_event.php` - the real-event-type branch (`:118-124`) renders each item only when `$this->checkAccess(...$this->getCreateArgsForEventTypeOprn($eventType, array('episode')))` passes; the `else` branch that renders `event_subtype` entries (`:127-133`) performs no `checkAccess` call at all. The subtype entries come from `AddNewEventManager::getAddableEventTypesAndEventSubtypes()` (`protected/components/AddNewEventManager.php:32-52`), which merges every `event_subtype` row with `manual_entry = 1` into the same list; selecting one calls `/patientEvent/create` with an extra `event_subtype` parameter.
- **Route**: `/patient/summary/<patient_id>` -> Add Event
- **Repro**:
  1. Set `manual_entry = 1` on any `event_subtype` row (there is no admin screen for the flag; it is migration/DB-only).
  2. Log in as a user who lacks the create permission for the parent event type.
  3. Open a patient and click **Add Event**.
  4. Look at the Select New Event column.
- **Expected**: the subtype entry is filtered out for a user without the create permission, exactly as an event type would be.
- **Actual**: the subtype entry is offered to every user who can open the dialog.
- **Evidence**: source-confirmed in the container at commit `53b077c089`. Not currently exploitable on this database - `SELECT COUNT(*) FROM event_subtype WHERE manual_entry = 1` is 0 - so this is a latent gap that opens the moment a subtype is seeded.
- **Severity**: medium (latent) - a permission filter that is silently absent on one of the two code paths that populate the same list.
- **Status**: open.

## BUG-130: `OEMigration::insertOEElementType()` has silently discarded `parent_element_type_id` since June 2018 (CONFIRMED)
- **Where**: `protected/components/OEMigration.php:758-767`. The helper checks `if (isset($element_type->columns['element_group_id']))` first and, when that column exists, writes `element_group_id` and never looks at `parent_element_type_id`. The `element_group_id` column was added to `element_type` by `OphCiExamination/migrations/m180626_061532_remove_element_parenting.php` (June 2018), so from that migration onward the first branch always wins and any `parent_element_type_id` a later migration passes is dropped on the floor.
- **Route**: n/a (migration helper)
- **Repro**:
  1. Read `protected/components/OEMigration.php:758-767` and note the `if/else` on `element_group_id`.
  2. Query the two Operation note procedure elements inserted after June 2018: `SELECT id, name, parent_element_type_id FROM element_type WHERE id IN (534, 559);` (Revision of aqueous shunt, PreserFlo MicroShunt).
  3. Compare with the pre-2018 siblings: `SELECT COUNT(*) FROM element_type WHERE parent_element_type_id = 34;`
- **Expected**: `parent_element_type_id = 34` (Procedure list) on both, which is what `m200629_202414_add_revision_aqueous.php` and `m250801_120620_add_preserflo_microshunt_element.php` explicitly request.
- **Actual**: both are `NULL`, while all 12 procedure elements inserted before June 2018 (35 Vitrectomy, 36 Membrane peel, 37 Tamponade, 38 Buckle, 39 Cataract, 404 Generic procedure, 405 Trabeculectomy, 406 Trabectome, 407 Glaucoma Tube, 418 Application of MMC, 426 Biometry, 445 CXL) correctly carry 34.
- **Evidence**: DB-confirmed 2026-08-05 against the live sample database; helper source read in the container at `53b077c089`.
- **Impact**: no runtime effect on the Operation note UI, which attaches procedure elements through the `ophtroperationnote_procedure_element` join table (`DefaultController::getProcedureSpecificElements()`) and is correct for both rows. The affected consumer is anything reading `parent_element_type_id` as the element hierarchy - the documentation coverage manifest does, so these two elements are indexed as top-level rather than as children of Procedure list. Wants a fix in the helper plus a data migration.
- **Severity**: low - silent data-shape defect affecting every element inserted by migration since June 2018.
- **Status**: open.

## BUG-131: Consent form Type dropdown is disabled on every edit, not only after printing (CONFIRMED)
- **Where**: `protected/modules/OphTrConsent/views/default/form_Element_OphTrConsent_Type.php:30-41` sets `$disabled = true` whenever `$this->action->id === "update"`, with no draft/printed condition, and passes it straight to the `type_id` dropdown. No JavaScript re-enables it (`assets/js/module.js` and `Contacts.js` checked). The event view's Edit tab always links to `default/update`.
- **Route**: `/OphTrConsent/default/update/<event_id>`
- **Repro**:
  1. Create a Consent form for any patient and save it as a draft.
  2. Open the event and click the **Edit** tab.
  3. Look at the **Type** field.
- **Expected**: Type is editable while the form is still a draft - the draft/printed distinction the rest of the module observes.
- **Actual**: the dropdown is disabled on every edit, so the consent type can never be changed after the initial create.
- **Evidence**: view source read in the container at `53b077c089`.
- **Severity**: low-medium - either the code should honour the draft state or the intended behaviour needs restating; as it stands a mis-selected consent type forces a new event.
- **Status**: open. Distinct from BUG-007, which concerns the *default* Type selection at create time.

## BUG-132: Genetic Results "External Source" admin controller targets a table that does not exist (CONFIRMED)
- **Where**: `protected/modules/OphInGeneticresults/models/OphInGeneticresults_External_Source.php:50-53` returns `'ophingeneticresults_external_source'` from `tableName()`. No such table exists: `SHOW TABLES LIKE 'ophingeneticresults%'` returns only `ophingeneticresults_test_effect`, `..._test_effect_version`, `..._test_method`, `..._test_method_version`. `ExternalSourceAdminController` (`actionList`, `actionEdit`, `actionDelete`, lines 27/47/63) instantiates `Admin(OphInGeneticresults_External_Source::model(), $this)` in all three actions.
- **Route**: `/OphInGeneticresults/ExternalSourceAdmin/list` (also `/edit`, `/delete`)
- **Repro**:
  1. Log in as an institution admin.
  2. Request `/OphInGeneticresults/ExternalSourceAdmin/list` directly.
- **Expected**: a CRUD list of genetic-results external sources.
- **Actual**: every action on the controller faults on the missing table.
- **Evidence**: model source read in the container and table list queried against the live database, 2026-08-05, commit `53b077c089`. Mitigating: the controller is not linked from any admin menu - `grep -ri 'externalsource' protected/modules/OphInGeneticresults --include='*.php'` finds it only in the controller and model - so it is reachable by direct URL only. Not driven live (an authenticated admin GET was not issued; source and schema are unambiguous).
- **Severity**: low - orphaned admin screen for a niche module, but it is in the same module a documentation reviewer is asked to seed data for.
- **Status**: open.

## BUG-133: Add Event dialog ships an unfinished, hidden "Back Date Event" block (CONFIRMED)
- **Where**: `protected/views/patient/add_new_event.php` - a `<div class="back-date-event" style="display: none;">` preceded by `<!-- TODO: implement back dated event changes -->`, containing a date input and two placeholder `<select>` elements whose option values are literally `01`, `02`, `03`, `..`.
- **Route**: `/patient/summary/<patient_id>` -> Add Event
- **Repro**:
  1. Open any patient and click **Add Event**.
  2. Inspect the dialog's DOM for `div.back-date-event`.
- **Expected**: unfinished UI is either not shipped in the production view or is behind a feature flag.
- **Actual**: it ships hidden, with placeholder option values, in the most-used dialog in the application.
- **Evidence**: view source read in the container at `53b077c089`.
- **Severity**: low - invisible in normal use, but a stylesheet change elsewhere would reveal a non-functional control, and it misleads anyone reading or restyling the dialog.
- **Status**: open.

## BUG-134: Two different "View Only" labels on the disabled Add Event button, and the sidebar label misstates the deceased case (CONFIRMED)
- **Where**: `protected/views/patient/episodes_sidebar.php:36-40` renders `You have View Only rights` when `!(!empty($ordered_episodes) && checkAccess('OprnCreateEpisode')) || $this->patient->is_deceased`; `protected/views/patient/landing_page.php:45-49` renders `You have View Only rights and cannot create events` when `checkAccess('OprnCreateEpisode')` fails.
- **Route**: `/patient/summary/<patient_id>`
- **Repro**:
  1. Log in as a user without `OprnCreateEpisode` and open a patient who has events; read the disabled button in the episode sidebar: "You have View Only rights".
  2. Open a patient who has no events at all; read the disabled button on the no-events panel: "You have View Only rights and cannot create events".
  3. As a user who *does* hold `OprnCreateEpisode`, open a deceased patient; the sidebar button is disabled and reads "You have View Only rights".
- **Expected**: one consistent message, and a message that names the actual reason the button is disabled.
- **Actual**: two wordings for the same condition, and the sidebar wording is shown for three distinct causes - no episodes, no permission, patient deceased - so it is wrong in two of the three.
- **Evidence**: both views read in the container at `53b077c089`. A third view carrying a copy of this markup, `protected/views/patient/episodes.php:24-37`, also omits the `is_deceased` guard the other two apply - but that view is unreachable dead code (see BUG-127), so the missing guard is latent, not a live defect.
- **Severity**: low/cosmetic, but it is the reason the documentation corpus recorded the deceased-patient behaviour incorrectly.
- **Status**: open.

## BUG-135: the genetics event types carry `rbac_operation_suffix` values that nothing reads, and DNA sample's names an operation that does not exist (CONFIRMED)
- **Where**: `event_type` rows 45/46/47 ("DNA sample", "DNA extraction", "Genetic Results") are the only three rows in the table with a non-empty `rbac_operation_suffix` (DB-confirmed), and row 45's value is still `BloodSample`. That column is read in exactly one place: `oe-shared/app/Modules/YiiAuth/AuthRules/EventIsCreatable.php:66-82`, which builds `"OprnCreate" . $event_type->rbac_operation_suffix`. `EventIsCreatable` is the biz rule `canCreateEvent`, and `authitem` binds that rule to `OprnCreateEvent` and to the module-specific create operations only (DB-confirmed) - so it runs only for event types that go through `OprnCreateEvent`. All three genetics modules override that: `OphInDnasample_API.php:20`, `OphInDnaextraction_API.php:20` and `OphInGeneticresults_API.php:21` set `public $createOprn` to `OprnEditDnaSample` / `OprnEditDNAExtraction` / `OprnEditGeneticResults`, and `CreateEventControllerBehavior::getCreateArgsForEventTypeOprn()` (`protected/behaviors/CreateEventControllerBehavior.php:56-68`) prefers `$api->createOprn` over `OprnCreateEvent`. Those three edit operations carry no biz rule at all (DB-confirmed), so `EventIsCreatable` never executes for the only three event types whose suffix it would consume. `protected/modules/Genetics/migrations/m161216_153049_dna_rbac_operation.php` was written to rename `BloodSample` -> `DnaSample` in `event_type` *and* `authitem`, and `tbl_migration` records it as applied (`apply_time` 1630687880); it renamed the auth items but left the `event_type` value at `BloodSample`, so `OprnCreateBloodSample` is a name no `authitem` row has.
- **Route**: `/patient/summary/<patient_id>` -> Add Event; `/patientEvent/create?...&event_type_id=45`
- **Repro**:
  1. Read `event_type`: `SELECT id, name, rbac_operation_suffix FROM event_type WHERE rbac_operation_suffix <> "";` - three rows, row 45 reading `BloodSample`.
  2. Read `authitem` for the operation that value produces: `SELECT name FROM authitem WHERE name = "OprnCreateBloodSample";` - no rows. The operation the seed data actually creates is `OprnCreateDnaSample`, under `TaskCreateDnaSample`.
  3. Read the biz rules on the operations the create path really checks: `SELECT name, bizrule FROM authitem WHERE name IN ("OprnEditDnaSample","OprnEditDNAExtraction","OprnEditGeneticResults");` - all three are NULL, so `canCreateEvent` (and with it `EventIsCreatable`) never runs for these event types and the suffix is never read.
  4. Confirm the suffix is inert rather than blocking: grant a Genetics role, then GET `/patientEvent/create?patient_id=17891&event_type_id=45&context_id=13&episode_id=601038`. The DNA sample create form renders, despite `OprnCreateBloodSample` not existing.
- **Expected**: either the column is read for these event types and holds a real operation name, or the column is not populated for them at all. Not both halves half-done.
- **Actual**: dead configuration on all three rows, one of which is also wrong. `OprnCreateDnaSample` and `TaskCreateDnaSample` are dead `authitem` rows - nothing ever checks them - and the RBAC layer intended to govern genetics event creation is not the one doing it: `OprnEdit*` is. The failure is latent rather than user-visible today, but if any genetics module's `createOprn` override were removed, DNA sample would become uncreatable for every role in the system, because the operation its suffix names does not exist.
- **Evidence**: `event_type`, `authitem` (names and biz rules) and `tbl_migration` rows read from the database 2026-08-05; `EventIsCreatable`, `AuthManagerService::checkAccess()`, `CreateEventControllerBehavior`, `PatientEventController::resolveEventType()` and the three module API classes read in the container at commit `53b077c089`; live create-form render at step 4 captured in-container the same day.
- **Severity**: low - latent. No user-visible effect while the `createOprn` overrides stand.
- **Status**: open. **Rewritten 2026-08-05.** This entry previously claimed that DNA sample could be created by nobody and that granting a Genetics role changed nothing. That was wrong: the 403 seen at the time was an ordinary missing-role refusal - no account in the sample database holds a Genetics role - and once the roles are granted both "DNA sample" and "Genetic Results" appear in the Add Event list (live check: 23 of 23 offerable types listed) and both create forms render. What survives verification is only the dead-configuration finding above.

## BUG-136: Worklist mapping-set uniqueness is enforced only in the browser, and the shipped sample definitions already violate it (CONFIRMED)
- **Where**: `protected/modules/Admin/views/worklist/definition_edit.php:419-462` posts the mapping set to `/Admin/worklist/mappingIsUnique` and, on an `EXACT` match, shows an error and sets `document.getElementById('et_save').disabled = true`. That is the only enforcement: `WorklistController::actionDefinitionUpdate()` (`protected/modules/Admin/controllers/WorklistController.php:125-181`) calls `saveWorklistDefinition()` and `WorklistManager::saveMappings()` and never calls `hasDuplicateMappingSet()` (`protected/components/worklist/WorklistManager.php:510`), and `saveMappings()` itself has no duplicate check. The rule exists because `WorklistManager::getWorklistForMapping()` (`:1779-1802`) must resolve an incoming PAS appointment to exactly one worklist, and calls `addError('More than one worklist matched criteria: ...')` when more than one candidate matches. The four sample worklist definitions (ids 1-4, "Unbooked - Cataract/Eye Casualty/Refractive/Cornea") all carry the identical single mapping `UNBOOKED = true` (DB-confirmed across `worklist_definition_mapping` and `worklist_definition_mapping_value`).
- **Route**: `/Admin/worklist/definitions` -> a definition -> Mappings; `PUT /PASAPI/V<n>/PatientAppointment/<external-id>`
- **Repro**:
  1. Admin > Worklist > Definitions: generate a worklist for today from definition 1 (the **Generate** button).
  2. Generate a worklist for today from definition 2 as well.
  3. `PUT /PASAPI/V3/PatientAppointment/<externalid>` with an `AppointmentMapping` of `UNBOOKED` / `true` for today's date.
  4. Observe HTTP 500 with "More than one worklist matched criteria: ...". Every unbooked appointment for that day now fails.
  5. Separately, for the bypass: POST a definition's mapping form directly (or edit a definition whose duplicate is created after the page loaded); the server accepts the duplicate mapping set without complaint.
- **Expected**: either the server rejects a duplicate mapping set the way the browser does, or the sample dataset does not ship four definitions that share one.
- **Actual**: the uniqueness rule the PAS integration depends on is advisory client-side JavaScript, and the shipped configuration is already in the state the rule exists to prevent - so on any sample-seeded instance, generating more than one of the four unbooked worklists for the same day breaks unbooked appointment loading entirely.
- **Evidence**: controller, manager, view JavaScript and both mapping tables read in the container at `53b077c089`; the 500 was hit live while building the demonstration-data seeder.
- **Severity**: medium.
- **Status**: open.

## BUG-137: Worklist admin "Definition Mappings" button points at an action that does not exist (CONFIRMED)
- **Where**: `protected/modules/Admin/views/worklist/worklist_patients.php:26` renders `EventAction::link('Definition Mappings', '/Admin/worklist/definitionMappings/'.$worklist->worklist_definition_id, ...)`, and `WorklistController::actionDefinitionMappingSort()` (`protected/modules/Admin/controllers/WorklistController.php:614`) redirects to the same `/Admin/worklist/definitionMappings/<id>` after re-ordering mappings. `WorklistController` has no `actionDefinitionMappings` (its mapping screens live inside `actionDefinitionUpdate`).
- **Route**: `/Admin/worklist/worklistPatients/<worklist_id>`
- **Repro**:
  1. Log in as `admin` (institution 1, site 1) and open Admin > Worklist > Definitions.
  2. Open a definition's generated worklists and click through to a worklist's patients (`/Admin/worklist/worklistPatients/2`).
  3. Click **Definition Mappings**.
- **Expected**: the definition's mapping screen opens.
- **Actual**: HTTP 404, `CHttpException` "The system is unable to find the requested action \"definitionMappings\"." Re-ordering mappings takes the same dead redirect, so a successful re-order also ends on the error page.
- **Evidence**: live 404 captured in-container 2026-08-05 at `53b077c089`; the rendered button and its href confirmed on `/Admin/worklist/worklistPatients/2`; controller action list read in the container.
- **Severity**: medium - a visible admin control that always fails, and a successful write operation that lands on an error page.
- **Status**: open.

## BUG-138: PASAPI documents the identifier-resolution header in a spelling the server never delivers (CONFIRMED)
- **Where**: `protected/modules/PASAPI/README.md:71` documents the header as `X_OE_IDENTIFIER_RESOLUTION_CODE: LOCAL-1-0` (underscores), and line 74 misspells it again as `X_OE_IDENTIFIER_RESOLUTION_COD`. Every other header the same README documents uses hyphens (`X-OE-Update-Only`, `X-OE-Partial-Record`). The controllers read `$_SERVER['HTTP_X_OE_IDENTIFIER_RESOLUTION_CODE']` (`protected/modules/PASAPI/controllers/V3Controller.php:43`, read at `:237-241`), which the running Apache populates only from the hyphenated wire form.
- **Route**: `PUT /PASAPI/V<n>/<resource>/<external-id>`
- **Repro**:
  1. `curl -X PUT -u <user>:<pass> -H "Content-Type: application/xml" -H "X_OE_IDENTIFIER_RESOLUTION_CODE: <code>" --data "" http://<host>/PASAPI/V3/PatientAppointment/probe1`
  2. Observe HTTP 404 `<Error>No Identifier Type Code has been provided</Error>` - the header never reached PHP.
  3. Repeat with `-H "X-OE-Identifier-Resolution-Code: <code>"`.
  4. Observe the request get past the header check (a bogus code now returns `No Patient Identifier Type has been found": <code>`; a real one proceeds).
- **Expected**: the documented spelling works, since it is the only instruction an integrator has.
- **Actual**: any integrator following the README gets a 404 whose message says the header was not provided when it was provided exactly as documented. Patient, PatientAppointment and PatientMerge - the three resources that require it - are all unusable until the spelling is guessed.
- **Evidence**: both spellings driven live against the container's own Apache on 2026-08-05 at `53b077c089` (not through any proxy), responses quoted above. Same passage, minor: the error message at `V3Controller.php:533` contains a stray quote - `No Patient Identifier Type has been found": <code>`.
- **Severity**: medium - documentation-only, but it blocks the integration it documents.
- **Status**: open.

## BUG-139: PASAPI documents AppointmentTime as `hh-mm`, and the parser only accepts `H:i` (CONFIRMED)
- **Where**: `protected/modules/PASAPI/README.md:191` and `:223` both show `<AppointmentTime>hh-mm</AppointmentTime>` in the PatientAppointment request bodies. `Appointment::getWhen()` (`protected/modules/PASAPI/resources/Appointment.php:77-83`) concatenates the date and time and parses with `DateTime::createFromFormat('Y-m-d H:i', $concatenated)`, throwing when the parse fails. The module's own feature tests use `11:30` and `10:30`.
- **Route**: `PUT /PASAPI/V<n>/PatientAppointment/<external-id>`
- **Repro**:
  1. PUT a PatientAppointment whose body contains `<AppointmentTime>09-30</AppointmentTime>`, exactly as the README shows.
  2. Observe the request fail with an invalid time format error for AppointmentTime.
  3. Resend the same body with `<AppointmentTime>09:30</AppointmentTime>`.
  4. Observe it succeed.
- **Expected**: the documented format parses.
- **Actual**: the documented format never parses; only `HH:MM` does. The neighbouring `AppointmentDate` placeholder (`yyyy-mm-dd`) is correct, which makes the hyphenated time look deliberate.
- **Evidence**: README and resource class read in the container at `53b077c089`; both forms exercised live while building the demonstration-data seeder.
- **Severity**: low-medium - documentation-only, self-inflicted first-integration failure.
- **Status**: open.

## BUG-140: PASAPI external resource ids silently reject hyphens, and say the id was missing instead (CONFIRMED)
- **Where**: `protected/modules/PASAPI/config/common.php:39-42` (and the V1/V2 equivalents) define the update/delete routes as `PASAPI/<controller:V3>/<resource_type:\w+>/<id:\w+>`. `\w` excludes `-`, so any external id containing a hyphen fails to match the rule; the request then falls through to default route parsing, arrives with no `id`, and `V3Controller::actionUpdate()` (`:314-316`) answers `404 External Resource ID required`.
- **Route**: `PUT /PASAPI/V<n>/<resource>/<external-id>`
- **Repro**:
  1. `curl -X PUT -u <user>:<pass> -H "Content-Type: application/xml" -H "X-OE-Identifier-Resolution-Code: <code>" --data "" http://<host>/PASAPI/V3/PatientAppointment/oedocs-demo-1`
  2. Observe HTTP 404 `<Error>External Resource ID required</Error>`.
  3. Repeat with `oedocsdemo1` as the id; the request is accepted and processed.
- **Expected**: either hyphenated external ids are accepted (PAS-side identifiers commonly contain them), or the rejection says the id is malformed rather than absent.
- **Actual**: the id is present in the URL, and the API reports it as required. Nothing in the README states the character restriction.
- **Evidence**: URL rules read in the container and the 404 reproduced live on 2026-08-05 at `53b077c089`.
- **Severity**: medium - an integrator whose PAS uses hyphenated identifiers gets an error message that points away from the cause.
- **Status**: open.

## BUG-141: A PASAPI request carrying a browser session cookie logs that browser session out (CONFIRMED)
- **Where**: every PASAPI controller authenticates and then calls `\Yii::app()->user->login($identity)` inside `beforeAction()` (`protected/modules/PASAPI/controllers/V3Controller.php:162`, `V2Controller.php:163`, `V1Controller.php:139`). `CWebUser::login()` -> `changeIdentity()` calls `Yii::app()->getSession()->regenerateID(true)` (`vendor/yiisoft/yii/framework/web/auth/CWebUser.php:717`), which issues a new session id and deletes the old session. The API client discards the new cookie; the browser still holds the old id, which no longer exists. `V3Controller::setSessionInstitution()` then writes `selected_institution_id` into that session.
- **Route**: any `PUT`/`DELETE` under `/PASAPI/V<n>/...`
- **Repro**:
  1. Log in to the web interface in a browser (or any client with a cookie jar).
  2. From the same cookie jar, send an authenticated PASAPI request.
  3. Reload any application page.
  4. Observe you are back on the login screen.
- **Expected**: a stateless API call does not disturb an unrelated interactive session; the API should use a stateless identity rather than the web session.
- **Actual**: the interactive session is destroyed, and every API call additionally creates and abandons a PHP session server-side.
- **Evidence**: controller and framework code read in the container at `53b077c089`; reproduced live while building the demonstration-data seeder, which is why the seeder drives PASAPI with an empty cookie jar.
- **Severity**: low - a real PAS integration sends no browser cookie, so the blast radius is testing, scripting and any tooling that reuses one session for both.
- **Status**: open.

## BUG-142: `MultiSelectDropDownList` discards the `id` it is given, emitting selects with no usable id or name (CONFIRMED)
- **Where**: `protected/widgets/MultiSelectDropDownList.php` - `renderDropDown()` reads only `options['dropDown']['name']`, `['data']`, `['selectedItems']` and `['htmlOptions']`, then calls `CHtml::dropDownList((string) $name, null, $data, $html_options)`. `options['dropDown']['id']` is never read. Callers pass it: `protected/modules/OphCoChecklist/views/admin/update_checklist.php:100-115` supplies `'name' => null, 'id' => 'categories'`, and does the same for the other four widgets on the screen. With `$name` null, `CHtml::dropDownList()` derives the id from the empty name, so the element ends up with `id=""` and `name=""`.
- **Route**: `/OphCoChecklist/Admin/EditChecklist?id=<id>` (and the other 15 call sites, including Consent extra procedures, RTT clock state options, Leaflets and Post-op complications)
- **Repro**:
  1. Log in as `admin` (institution 1, site 1) and open Admin > Checklists > Checklists > edit any checklist type.
  2. Inspect the page's `<select>` elements.
  3. Observe five of them rendered as `<select id="" name="" class="cols-full">`, one per multi-select row (Categories, Institutions, ...), despite each widget being given an explicit `id`.
- **Expected**: the widget honours the `id` it is handed, so each control is addressable.
- **Actual**: the id is silently dropped. The controls work (a sibling script binds by wrapper class), but nothing on the page - a label's `for`, a test, an accessibility tool or a screen reader - can address them, and the only way to target one is by its position among identical anonymous selects.
- **Evidence**: widget and caller read in the container at `53b077c089`; the rendered markup captured live on the checklist edit screen 2026-08-05.
- **Severity**: low - functional, but it makes the screen unaddressable and undermines the accessibility of every screen using the widget.
- **Status**: open.

## BUG-143: Admin sidebar offers the Medical Device Usage screens to Institution Admins, who are then refused (CONFIRMED)
- **Where**: `protected/modules/TrDeviceUsageRecord/config/common.php:40-52` restricts both admin entries to `['OprnInstitutionAdmin', 'TaskEditManageMedicalDevices']` and `['OprnInstitutionAdmin', 'TaskEditMedicalDeviceCategories']` respectively, and `MenuHelper`'s `restricted` semantics are any-of - so holding `OprnInstitutionAdmin` alone is enough to be shown both. The controllers behind them allow only the task: `DeviceAdminController::accessRules()` allows `['TaskEditManageMedicalDevices']` and `CategoryAdminController::accessRules()` allows `['TaskEditMedicalDeviceCategories']`, and neither merges `parent::accessRules()`, so `BaseAdminController`'s `OprnInstitutionAdmin` rule never applies.
- **Route**: `/TrDeviceUsageRecord/deviceAdmin/index`, `/TrDeviceUsageRecord/categoryAdmin/index`
- **Repro**:
  1. Create a user holding **Institution Admin** but neither **admin** nor **Manage Device Usage Record**.
  2. Sign in as that user and open the Admin area.
  3. Observe the sidebar offers **Medical Device Usage > Manage Devices** and **Medical Device Categories**.
  4. Select either.
- **Expected**: the screen opens, or the entry is not offered.
- **Actual**: HTTP 403.
- **Evidence**: module config and both controllers read in the container at `53b077c089`. Not driven live: no account in the sample database holds `Institution Admin` without `admin`, and the campaign creates no accounts outside the seeder's own recipe.
- **Severity**: low - misleading rather than harmful; the screens are correctly closed, they are just advertised to people who cannot open them.
- **Status**: open. Found while documenting roles and permissions.

## BUG-144: the Referral module's own pretty admin URLs are dead - all four 404 (CONFIRMED)
- **Where**: `protected/modules/Referral/config/common.php:50-57` declares four parameterless `urlManager` rules (`Referral/admin/rttClockStateOptions`, `Referral/admin/editRttClockStateOption`, `Referral/admin/rttClockStateOptionGroups`, `Referral/admin/sortRttClockStateOptionGroups`). None of them resolves. The two parameterised rules on the following lines (`Referral/admin/<controller:\w+>/<action:\w+>`, plus the `/<id:\d+>` variant) do work, so the short three-segment forms are the only dead ones.
- **Route**: `/Referral/admin/rttClockStateOptions` and its three siblings
- **Repro**:
  1. Request `/Referral/admin/rttClockStateOptions`. Expected: the RTT Clock State Options list.
  2. Observe HTTP **404** - and it is a routing failure, not an access one: the response is the same whether or not a session cookie is sent.
  3. Request `/Referral/admin/RTTClockStateOption/index` (the four-segment form, matched by the parameterised rule). It routes: signed out it is HTTP 302 to `/site/login`, signed in as `admin` it is the list screen.
  4. Request `/Referral/admin/Bogus/index` for the control - HTTP 404, confirming step 3 is the parameterised rule matching rather than a fallback.
  5. Repeat steps 1-2 for `editRttClockStateOption`, `rttClockStateOptionGroups` and `sortRttClockStateOptionGroups`.
- **Expected**: a declared URL rule resolves to the route it names.
- **Actual**: the four named rules never match; only the generic ones do.
- **Evidence**: module config and `protected/config/core/common.php:541-570` read in the container at `53b077c089`; all five requests driven with curl against the container's own Apache 2026-08-05.
- **Severity**: low - nothing in the product links to the short forms (`admin_structure` in the same file already points at the long `/Referral/ReferralAdmin/...` routes, so the sidebar works). The cost is that the config advertises addresses that do not exist, and anyone writing a link, a test or a document from it is misled.
- **Status**: open. Found while documenting the RTT clock state admin screens.

## BUG-145: admin-only sidebar entries sit on controllers that allow any Institution Admin (CONFIRMED)
- **Where**: `BaseAdminController::accessRules()` (`protected/controllers/BaseAdminController.php:100`) returns `[['allow', 'roles' => ['OprnInstitutionAdmin']]]`, and `ModuleAdminController` inherits it unchanged. Several modules nevertheless restrict the matching sidebar entry to the system `admin` role alone - `Referral/config/common.php:65-77` (both RTT screens), `OphCoDocument/config/common.php:45-51` (Document sub type settings), and others. `AdminMenuHelper::userHasAccessByRestriction()` (`protected/components/AdminMenuHelper.php:67`) hides the entry, but nothing tightens the route, and neither Referral admin controller overrides `accessRules()`.
- **Route**: `/Referral/ReferralAdmin/RTTClockStateOption/index`, `/Referral/ReferralAdmin/RTTClockStateOptionGroup/index`, `/OphCoDocument/oeadmin/DocumentSubTypesSettings`
- **Repro**:
  1. Create a user holding **Institution Admin** but not **admin**.
  2. Sign in as that user and open the Admin area. Observe no **Referral** group in the sidebar.
  3. Request `/Referral/ReferralAdmin/RTTClockStateOption/index` directly.
  4. The screen opens, fully editable, including the sort and edit actions.
- **Expected**: the two layers agree - either the entry is offered, or the route refuses it.
- **Actual**: the screen is hidden from the menu and reachable by URL. This is the mirror image of BUG-143, where the menu offers screens the route then refuses.
- **Evidence**: configs and controllers read in the container at `53b077c089`. Not driven live for want of an Institution-Admin-only account (same constraint as BUG-143). `OeDatabase/controllers/DefaultController.php:19-23` shows the intended shape: an admin-only menu entry whose controller also allows only `admin`.
- **Severity**: low - Institution Admin is already a privileged role, so this is a layering inconsistency rather than an escalation; but it means "hidden from the Admin menu" cannot be read as "not permitted", which is exactly how such restrictions tend to be read.
- **Status**: open. Found while documenting the RTT clock state admin screens.

## BUG-146: turning off `enable_rtt_clock_bar` leaves the clock bar on view screens (CONFIRMED)
- **Where**: `protected/modules/Referral/components/RTTClockDisplayResolver.php` - `resolveForEdit()` (:49-51) opens with `if (!$this->isEnabled()) { return null; }`; `resolveForView()` (:95-100) and `resolveForHistory()` (:108-113) never consult `isEnabled()`, which reads the `enable_rtt_clock_bar` installation setting (:160-163).
- **Route**: `/OphCiExamination/default/view/<event_id>` and `/OphCiExamination/default/update/<event_id>` for an event whose referral carries a clock state
- **Repro**:
  1. With `enable_rtt_clock_bar` on, a referral, a clock state and a saved Clinical Outcome, open the examination event in both view and edit. Both show the RTT clock (`[data-test="rtt-clock-view"]` and `#rtt-clock-app` respectively).
  2. Set `enable_rtt_clock_bar` to `0` at `/admin/editSystemSetting?key=enable_rtt_clock_bar&class=SettingInstallation`.
  3. Reload the edit screen - the clock bar is gone, as expected.
  4. Reload the view screen - **the clock bar is still rendered**, as is the historical element view.
- **Expected**: the feature switch governs the feature, or its description says it governs only data entry.
- **Actual**: the switch suppresses only the editable bar. Read-only display of RTT data continues on every view and history screen, so an installation that turns the feature off still shows it to clinicians.
- **Evidence**: resolver read in the container at `53b077c089`; both screens driven live in Chrome 2026-08-05 with the setting toggled off and back on.
- **Severity**: low-medium - defensible as deliberate (the historical record survives the switch), but it is not what the setting name or its description promise, and no other display path is exempted.
- **Status**: open. Found while documenting the RTT clock bar.

## BUG-147: IVT Prescribing Worklist dies whole-screen on a prescription whose sequence has no diagnosis

- **Where**: `protected/modules/OphTrIntravitrealinjection/modules/IVTPrescribingWorklist/views/default/_search_results.php`, the `<td data-test="diagnosis"><?= CHtml::encode($sequence->diagnosis->term) ?></td>` cell. `ophciexamination_injection_order_sequence.diagnosis_id` is nullable and **all 145** sequences in the sample database have it NULL, so the very first prescription raised on a stock installation trips it.
- **Route**: `/OphTrIntravitrealinjection/IVTPrescribingWorklist/default/index`
- **Repro**:
  1. Link an intravitreal treatment drug to a medication (`ophtrintravitinjection_treatment_drug.medication_id`), so prescriptions can be created at all.
  2. Start an injection plan for an eye without selecting a diagnosis.
  3. Sign in as a holder of the **IVT Prescriber** role and open `/OphTrIntravitrealinjection/IVTPrescribingWorklist/default/index`.
- **Expected**: the row lists with an empty Diagnosis cell.
- **Actual**: fatal `Attempt to read property "term" on null`. The whole worklist dies, not just the offending row, so one bad record takes the screen away from every prescriber.
- **Evidence**: view read in the container at `53b077c089`; nullability and the 145/145 NULL count read from the sample DB. The screen itself was walked live in its empty state (no prescriptions exist yet, see BUG-148's cause), so the fault is code- and data-traced rather than observed.
- **Severity**: high - a single row with no diagnosis removes the feature for the whole installation, and no-diagnosis is the sample default.
- **Status**: open. Found while documenting the new IVT prescribing feature.

## BUG-148: `Mandatory` injection prescribing can make an event permanently unsaveable with no PIN box to clear the error

- **Where**: `protected/modules/OphTrIntravitrealinjection/widgets/PrescriptionElementWidget.php::getElementFormModel()` and `forms/PrescriptionFormModel.php::afterValidate()` versus `widgets/views/_prescription_event_edit_side.php`. `setSignedForSide()` is called for every side that carries a sequence, so `afterValidate()` adds "A signature is required for the <side> eye prescription"; but when `PrescriptionDetailsResource` returns null the view renders "No prescription" with neither a PIN field nor a **Sign by PIN** button.
- **Route**: `/OphTrIntravitrealinjection/default/create/:patient_id` and `/OphTrIntravitrealinjection/default/update/:id`
- **Repro**:
  1. In Admin, set **Enable Injection prescribing** to `Mandatory`.
  2. Leave the eye's intravitreal treatment drug without a linked medication (the sample default for all 11 drugs).
  3. Start an injection plan for that eye.
  4. Open an Intravitreal injection event for the patient and press **Save**.
- **Expected**: either the event saves, or the message tells the user what to do next.
- **Actual**: validation fails with a signature error the screen offers no way to satisfy. The event cannot be saved at all, and the only escape is an administrator changing an installation-level setting.
- **Evidence**: widget, form model and view read in the container at `53b077c089`; `injection_prescribing_mode` confirmed `Disabled` installation-wide and all 11 rows of `ophtrintravitinjection_treatment_drug` confirmed `medication_id` NULL in the sample DB, which is why the state could not be driven live.
- **Severity**: high - a hard block on clinical data entry that a clinician cannot resolve.
- **Status**: open. Found while documenting the new IVT prescribing feature.

## BUG-149: the `Optional` injection prescribing mode does nothing its own description promises

- **Where**: the setting is created by `protected/modules/OphTrIntravitrealinjection/migrations/m260513_162620_injection_prescribing.php` and described in Admin as "Shows a warning with option to override when no prescription exists", but `forms/PrescriptionFormModel.php::afterValidate()` branches only on `MANDATORY`.
- **Route**: Admin > Settings (`injection_prescribing_mode`), then `/OphTrIntravitrealinjection/default/create/:patient_id`
- **Repro**:
  1. In Admin, set **Enable Injection prescribing** to `Optional`.
  2. Open an Intravitreal injection event for a patient whose prescription is absent or unsigned.
  3. Press **Save**.
- **Expected**: a warning with an option to override, as the setting's own description states.
- **Actual**: nothing at all. `Optional` behaves identically to leaving the feature off, so an administrator configures a safety net that does not exist.
- **Evidence**: migration text and form model read in the container at `53b077c089`. Not driven live: with `medication_id` NULL on every treatment drug no prescription can exist to warn about (see BUG-148).
- **Severity**: medium - the failure is silent and the setting's wording actively misleads.
- **Status**: open. Found while documenting the new IVT prescribing feature.

## BUG-150: the IVT Prescribing Worklist is unscoped by site or signed status and never clears

- **Where**: `protected/modules/OphTrIntravitrealinjection/modules/IVTPrescribingWorklist/controllers/DefaultController.php::actionIndex()` - both `InjectionSequencePrescription::model()->count()` and the `CDbCriteria` it builds apply no institution, site, firm or signed-status condition, and the screen offers no filter controls.
- **Route**: `/OphTrIntravitrealinjection/IVTPrescribingWorklist/default/index`
- **Repro**:
  1. Raise prescriptions for patients at two different sites.
  2. Sign one of them.
  3. Sign in as a prescriber at one site and open the worklist.
- **Expected**: outstanding work relevant to that user.
- **Actual**: every prescription in the installation, signed and unsigned, from every site and firm, 25 at a time in id order, with nothing to narrow it by. The list stops being actionable after a few weeks of live use.
- **Evidence**: controller read in the container at `53b077c089`; the screen walked live as admin, which rendered the header and the "No prescriptions found" empty state (no rows exist yet).
- **Severity**: medium - usability shading into clinical safety, since outstanding items become impossible to find.
- **Status**: open. Found while documenting the new IVT prescribing feature.

## BUG-151: IVT Prescribing Worklist table has seven headers over six-column rows

- **Where**: `protected/modules/OphTrIntravitrealinjection/modules/IVTPrescribingWorklist/views/default/_search_results.php:38-47` - 7 `<th>` (checkbox, Patient, quicklook, Laterality, Diagnosis, Treatment Drug, and a blank one at `:46` carrying the comment `<!-- PIN entry field to be added later -->`) against 6 `<td>` per row (`:54-65`) and 6 `<col>` in the `<colgroup>`.
- **Route**: `/OphTrIntravitrealinjection/IVTPrescribingWorklist/default/index`
- **Repro**:
  1. Make at least one prescription exist (see BUG-147 step 1).
  2. Open the worklist as an **IVT Prescriber**.
  3. Look at the right-hand end of the table.
- **Expected**: the table has as many columns as the rows fill.
- **Actual**: the blank placeholder header is the last cell, so every row is one cell short at the right-hand end and the table carries a spare empty column with no heading. The data itself stays under its own headers - this does not misalign the cells.
- **Evidence**: view read in the container at `53b077c089`; not observable live because no rows can exist yet.
- **Severity**: low - cosmetic, and self-resolving when the PIN column is built.
- **Status**: open. Found while documenting the new IVT prescribing feature.

## BUG-152: the worklist renders an empty filter panel inside an empty filter panel

- **Where**: `protected/modules/OphTrIntravitrealinjection/modules/IVTPrescribingWorklist/views/default/index.php` wraps `renderPartial('_filters')` in `<nav class="oe-full-side-panel audit-filters">`, and `views/default/_filters.php` opens an identical empty `<nav>` of its own.
- **Route**: `/OphTrIntravitrealinjection/IVTPrescribingWorklist/default/index`
- **Repro**:
  1. Sign in as an **IVT Prescriber** and open the worklist.
  2. Inspect the left-hand side panel.
- **Expected**: filter controls, or no panel at all.
- **Actual**: an empty side panel nested inside an empty side panel, occupying screen width for nothing.
- **Evidence**: both views read in the container at `53b077c089`; the screen was walked live as admin with the panel present and empty.
- **Severity**: low - visual only, but it takes space the results table needs.
- **Status**: open. Found while documenting the new IVT prescribing feature.

## BUG-153: latent null-patient dereference on the IVT Prescribing Worklist

- **Where**: `protected/modules/OphTrIntravitrealinjection/modules/IVTPrescribingWorklist/views/default/_search_results.php` calls `$sequence->getPatient()` and then uses `$patient->id`, while `OphCiExaminationInjectionOrderSequence::getPatient()` ends in `?? null`.
- **Route**: `/OphTrIntravitrealinjection/IVTPrescribingWorklist/default/index`
- **Repro**:
  1. Make a prescription exist whose sequence cannot resolve back to a patient (a deleted or orphaned episode/event chain).
  2. Open the worklist.
- **Expected**: the row is skipped, or its patient cell is blank.
- **Actual**: fatal error on the whole screen - the same failure mode as BUG-147, from the same view.
- **Evidence**: view and model read in the container at `53b077c089`. Needs orphaned data to trigger, so it is latent rather than reproducible on sample data.
- **Severity**: low - unlikely data shape, but it should be fixed alongside BUG-147 since it is one guard away.
- **Status**: open. Found while documenting the new IVT prescribing feature.

## BUG-154: patient search sorts the "Primary Institution" column by patient identifier (CONFIRMED)

- **Where**: `protected/views/patient/results.php:93-114` emits `sort_by=$i` for `$i` 0-7, but `SEARCH_SORT_BY_OPTIONS` in `protected/components/PatientSearchPaginationParameters.php` holds only seven entries, so index 7 falls through the `?? SEARCH_SORT_BY_OPTIONS[0]` default to `'value*1'` - the identifier.
- **Route**: `/patient/search?term=<term>`
- **Repro**:
  1. Log in as admin and open `/patient/search?term=Sharma`.
  2. Select the `Primary Institution` column heading.
  3. Select it a second time to reverse the direction.
- **Expected**: the rows reorder by institution.
- **Actual**: the rows reorder by the identifier in the first column - ascending gave 0000588 through 2018400, descending the exact reverse - and the institution column stays unordered.
- **Evidence**: walked live at `53b077c089` against the sample database; view and component read in the container.
- **Severity**: medium - the column advertises a sort it does not perform, and the wrong ordering is plausible enough to be trusted.
- **Status**: open. Found while documenting patient search.

## BUG-155: the patient search sort arrow is drawn on the wrong columns (CONFIRMED)

- **Where**: `protected/views/patient/results.php:104` and `:113` gate the arrow on `in_array($i, array(0, 2, 4, 5))`, while every heading from index 1 to 7 is rendered as a sort link.
- **Route**: `/patient/search?term=<term>`
- **Repro**:
  1. Open `/patient/search?term=Sharma`.
  2. Compare which headings show a sort arrow against which headings respond to a click.
- **Expected**: an arrow on each sortable heading, and none on the first column, which is not rendered as a link.
- **Actual**: arrows appear on `First name`, `Born` and `Age` only, plus on the unsortable first column; `Title`, `Last name`, `Sex` and `Primary Institution` sort on click with no arrow to say so.
- **Evidence**: walked live at `53b077c089`; view read in the container.
- **Severity**: low - cosmetic, but it hides four of the seven sorts from the user.
- **Status**: open. Found while documenting patient search.

## BUG-156: the patient search "Age" column sorts oldest-first on its first click (CONFIRMED)

- **Where**: `protected/components/PatientSearchPaginationParameters.php` - `SEARCH_SORT_BY_OPTIONS` index 5 (`Age`) is `'dob'`, identical to index 4 (`Born`). Age runs opposite to date of birth, so an ascending date sort is a descending age sort.
- **Route**: `/patient/search?term=<term>&sort_by=5&sort_dir=0`
- **Repro**:
  1. Open `/patient/search?term=Sharma&sort_by=5&sort_dir=0`.
- **Expected**: ascending age - the youngest patient first.
- **Actual**: 97, 96, 94 ... 22 - the oldest patient first.
- **Evidence**: walked live at `53b077c089`; component read in the container.
- **Severity**: low - the sort works, but its direction is inverted against the column's own label.
- **Status**: open. Found while documenting patient search.

## BUG-157: the Patient Summary renders the "Systemic Diagnoses" heading twice (CONFIRMED)

- **Where**: `protected/views/patient/landing_page.php:326` emits `<h3 class="element-title">Systemic Diagnoses</h3>`, and line 336 passes `'title' => 'Systemic Diagnoses'` into the widget rendered immediately inside it.
- **Route**: `/patient/summary/<patient_id>`
- **Repro**:
  1. Open a patient summary with systemic diagnoses recorded.
  2. Read down the left-hand column to the Systemic Diagnoses section.
- **Expected**: one heading, as with the sibling Eye Diagnoses section, which has no outer header of its own.
- **Actual**: the words appear twice, stacked.
- **Evidence**: walked live at `53b077c089` on a sample patient; view read in the container.
- **Severity**: low - cosmetic.
- **Status**: open. Found while documenting the patient summary.

## BUG-158: draft visibility is filtered on one Add Event entry point and not the other

- **Where**: `protected/views/patient/_single_episode_sidebar.php` filters drafts with `patient_id = :patient_id AND (t.is_auto_save != 1 OR t.created_user_id = :created_user_id)`; `protected/views/patient/landing_page.php:63` fetches them with `EventDraft::model()->with('episode')->findAll('patient_id = ?', [$this->patient->id])` and no user condition.
- **Route**: `/patient/summary/<patient_id>` - the Add Event dialog's Existing drafts column, on the no-events path.
- **Repro**:
  1. As user A, start an event on a patient who has no other events and leave it long enough to auto-save.
  2. As user B, open that patient's summary and select Add Event.
  3. Read the Existing drafts column.
- **Expected**: user A's auto-save is hidden from user B, as it is on the episode-sidebar path.
- **Actual**: the no-events path lists it.
- **Evidence**: both views read in the container at `53b077c089`. Not reproduced live - the sample database has zero `event_draft` rows, so the whole drafts column is unexercisable without seeded data.
- **Severity**: low - one user sees another user's unfinished work described by event type and date.
- **Status**: open. Found while documenting the Add Event dialog.

## BUG-159: the no-events panel is chosen by a query that still counts deleted events

- **Where**: `protected/controllers/PatientController.php:236` runs `$events = Event::model()->findAll($criteria);` before line 238 adds `$criteria->compare('t.deleted', 0);`, and `$no_episodes` is derived from that first result.
- **Route**: `/patient/summary/<patient_id>`
- **Repro**:
  1. Find or create a patient whose only events have all been deleted.
  2. Open that patient's summary.
- **Expected**: the "No Events" panel, with its Add Event button - the patient has no events a user can see.
- **Actual**: the normal empty layout, with no obvious way to start a first event.
- **Evidence**: controller read in the container at `53b077c089`. Not reproduced live - no patient in the sample database has only deleted events.
- **Severity**: low - needs an uncommon data shape, but it strands the user on the screen where starting an event matters most.
- **Status**: open. Found while documenting the patient summary.

## BUG-160: the `Active` flag on RTT clock state options and groups changes nothing a clinician sees

- **Where**: `protected/modules/Referral/widgets/RTTClock.php:237-243` - `loadGroups()` calls `->all()` with no active scope - and `:143-152`, where `getStateOptionsForItemSet()` filters by type only. `protected/modules/Referral/repositories/RTTClockStateOptionGroupRepository.php` is a bare `BaseActiveRecordRepository`, and `models/RTTClockStateOptionGroup.php::defaultScope()` orders by `display_order` without touching `active`. The contract says the opposite: `oe-shared/app/Modules/Referral/DTOs/RTTClockStateOptionGroupDTO.php:25` states "only active groups are surfaced to the front end".
- **Route**: `/Referral/admin/RTTClockStateOption/list` and `/Referral/admin/RTTClockStateOptionGroup/list`, surfacing on the examination Clinical Outcome element's RTT Outcome picker.
- **Repro**:
  1. Open Admin > Referral > RTT Clock State Options and select the row for code 36, Patient died.
  2. Untick **Active** and select **Save**.
  3. Open a patient whose referral has a clock state, edit the Clinical Outcome element and select **RTT Outcome**.
  4. Select the **Clock Stop - No Treatment** heading and look for code 36.
  5. Repeat for a whole group: Admin > Referral > RTT Clock State Option Groups, untick **Active** on "Not RTT", save, reopen the picker.
- **Expected**: the retired option is no longer offered, and the retired group no longer appears as a heading.
- **Actual**: both still appear and are still selectable, exactly as before.
- **Evidence**: widget, repository and models read in the container at `53b077c089`, and the DTO contract read in oe-shared. Not executed - the admin screens are read-only in this campaign, and the database still holds 19 of 19 options and 7 of 7 groups active, so nothing was untocked to prove it. The defect is a missing filter in code rather than an observed failure.
- **Severity**: medium - an admin control that saves, reports success and does nothing. The only way to actually withdraw a code is the non-obvious one of removing it from its group.
- **Status**: open. Found while documenting the RTT clock configuration screens.

## BUG-161: an RTT clock state option saved with no group is accepted and then offered nowhere

- **Where**: `protected/modules/Referral/models/RTTClockStateOption.php:92` defaults `group_id` to null with no rule requiring it, and `views/RTTClockStateOption/edit.php:93` offers `'empty' => '- No group -'`. The picker builds its list purely by reducing over the groups' `options` (`widgets/RTTClock.php:143-152`), and `widgets/js/ClinicOutcomeRTTClock.js:288-299` (`_computeSuggestedIds()`) then intersects the suggested ids with that same list - so an ungrouped option can be neither browsed nor suggested.
- **Route**: `/Referral/admin/RTTClockStateOption/add`
- **Repro**:
  1. Open Admin > Referral > RTT Clock State Options and select **Add**.
  2. Set Type to `Outcome`, Code to `77`, Name to `Local test code`, and leave **Group** on "- No group -".
  3. Save. The option appears in the admin list with an empty Group cell.
  4. Edit code 20, Subsequent activity (non-DNA), add `77 - Local test code` to **Allowed next options**, and save.
  5. Open a patient whose current clock state is code 20, edit the Clinical Outcome element and select **RTT Outcome**.
- **Expected**: either the form refuses an option with no group, or the option is reachable somewhere in the picker - at minimum under Suggested, since step 4 named it an allowed next option.
- **Actual**: the option is offered nowhere. It has no heading of its own and is absent from Suggested, with no warning at any point.
- **Evidence**: model, view, widget and picker JavaScript read in the container at `53b077c089`. Not executed - no option was created, and the database still holds zero rows with a null `group_id`.
- **Severity**: low/medium - a silent dead end, made worse by the fact that group membership is the only working retirement mechanism (BUG-160).
- **Status**: open. Found while documenting the RTT clock configuration screens.

## BUG-162: adding a past reading through IOP History overwrites both eyes' IOP comments

- **Where**: `protected/modules/OphCiExamination/controllers/DefaultController.php:2323-2324` sets `left_comments` and `right_comments` on the target Intraocular Pressure element to the literal string "IOP values not recorded for this eye." unconditionally, whatever was already there.
- **Route**: `/OphCiExamination/default/update/<event_id>` - the IOP History element.
- **Repro**:
  1. Open an examination, record an intraocular pressure on each eye with a comment on each, and save.
  2. Reopen the examination for editing and add a past reading through IOP History for the same date.
  3. Save.
- **Expected**: the comments recorded in step 1 survive.
- **Actual**: both comments are replaced by "IOP values not recorded for this eye."
- **Evidence**: controller read in the container at `53b077c089`. Not executed - the application is read-only in this campaign - so this is code-traced rather than observed.
- **Severity**: high - silent loss of clinical free text, on an element where the comment often carries the reason a reading is unusual.
- **Status**: open. Found while documenting the IOP History element.

## BUG-163: IOP History creates a duplicate Examination event for a date that already has one

- **Where**: `protected/modules/OphCiExamination/controllers/DefaultController.php:2275-2294` creates a new `Event` for each past date entered, with no check for an existing examination on that date for that patient.
- **Route**: `/OphCiExamination/default/update/<event_id>` - the IOP History element.
- **Repro**:
  1. Open an examination and enter a past-dated reading through IOP History for a date the patient already has an examination on.
  2. Save.
  3. Enter the same past date again through IOP History on any examination for that patient, and save.
- **Expected**: the reading is added to the existing examination for that date, or the second entry is refused.
- **Actual**: a second Examination event is created on the same date for the same patient, and the timeline shows both.
- **Evidence**: controller read in the container at `53b077c089`. Not executed; code-traced.
- **Severity**: medium/high - duplicated encounters distort the record and every count taken from it.
- **Status**: open. Found while documenting the IOP History element.

## BUG-164: the IOP History add-eye control is permanently hidden

- **Where**: `protected/modules/OphCiExamination/widgets/views/HistoryIOP_event_edit.php:49` wraps the container in `<div class="inactive-form" style="display: none;">`, and nothing in the widget's JavaScript ever unhides it.
- **Route**: `/OphCiExamination/default/update/<event_id>` - the IOP History element.
- **Repro**:
  1. Open an examination for editing and add the IOP History element.
  2. Look for the "Add left eye" / "Add right eye" affordance.
- **Expected**: a control that adds the missing eye to the history table.
- **Actual**: the control is present in the markup but hidden by an inline style with no code path that reveals it, so it can never be used.
- **Evidence**: widget view read in the container at `53b077c089`. Code-traced.
- **Severity**: low/medium - dead affordance; the eye can still be added by other means.
- **Status**: open. Found while documenting the IOP History element.

## BUG-165: the Glaucoma Risk colour band does not move until the element is saved

- **Where**: `protected/modules/OphCiExamination/views/default/form_Element_OphCiExamination_GlaucomaRisk.php:23-25` renders the band server-side from the saved value, with no `change` handler on the risk selector.
- **Route**: `/OphCiExamination/default/update/<event_id>` - the Glaucoma Risk element.
- **Repro**:
  1. Open an examination that already has a Glaucoma Risk recorded, and note the colour band.
  2. Change the risk to a different value without saving.
- **Expected**: the band follows the selection.
- **Actual**: the band keeps showing the previously saved risk, so the screen contradicts the selected value until save.
- **Evidence**: view read in the container at `53b077c089`. Code-traced.
- **Severity**: low - transient, but it is a colour cue clinicians read at a glance.
- **Status**: open. Found while documenting the Glaucoma Risk element.

## BUG-166: Glaucoma Overall Plan defaults ignore institution, site and firm scope

- **Where**: `Element_OphCiExamination_OverallManagementPlan::setDefaultOptions()` (lines 171-178) calls `SettingMetadata::model()->findAll('element_type_id=?', [410])` directly instead of going through `SettingMetadata::getSetting()`, which is what resolves the installation/institution/site/firm precedence chain.
- **Route**: `/OphCiExamination/default/create?patient_id=<id>` - the Glaucoma Overall Plan element.
- **Repro**:
  1. Set a Glaucoma Overall Plan default at institution or site level in the admin settings.
  2. Start a new examination at that institution or site and add the Glaucoma Overall Plan element.
- **Expected**: the element pre-fills with the institution or site default.
- **Actual**: it pre-fills with the installation-level default; the narrower setting is never consulted.
- **Evidence**: model read in the container at `53b077c089`, compared against `SettingMetadata::getSetting()`. Code-traced.
- **Severity**: medium - a configuration screen that saves a value which silently has no effect.
- **Status**: open. Found while documenting the Glaucoma Overall Plan element.

## BUG-167: an orphan `default_rows` setting is offered for the Intraocular Pressure element

- **Where**: `setting_metadata` carries a `default_rows` row for `element_type_id` 316 (Intraocular Pressure), and no code reads it.
- **Route**: the admin settings screen for the Intraocular Pressure element.
- **Repro**:
  1. Open the element settings for Intraocular Pressure in admin.
  2. Set `default_rows` to any value and save.
  3. Start a new examination and add the Intraocular Pressure element.
- **Expected**: the element opens with that many reading rows.
- **Actual**: the row count is unaffected; nothing consumes the setting.
- **Evidence**: `setting_metadata` row read from the database, and no consumer found in the module at `53b077c089`. Code-traced.
- **Severity**: low - a knob that does nothing, but an administrator has no way to tell.
- **Status**: open. Found while documenting the Intraocular Pressure element.

## BUG-168: dilation treatment rows are keyed by drug and side, so a repeated drug overwrites itself

- **Where**: `protected/modules/OphCiExamination/models/Element_OphCiExamination_Dilation.php:237` - `updateTreatments()` keys the incoming treatments by drug plus side, while the edit form permits more than one row for the same drug on the same side.
- **Route**: `/OphCiExamination/default/update/<event_id>` - the Dilation element.
- **Repro**:
  1. Open an examination for editing and add the Dilation element.
  2. Add two rows for the same drug on the same eye, at different times.
  3. Save.
- **Expected**: both administrations are kept, since the times differ.
- **Actual**: the second row overwrites the first, and one administration is lost.
- **Evidence**: model read in the container at `53b077c089`. Code-traced.
- **Severity**: low - needs a repeated drug on one side, but the loss is silent.
- **Status**: open. Found while documenting the Drops and Dilation element.

## BUG-169: Clinical Management's bilateral form gates the long-term entry on the wrong eye

- **Where**: `protected/modules/OphCiExamination/views/_clinicalmanagement_bilateral_edit.php:62` calls `$element->canRecordLongTermEntry($side)` while the surrounding markup renders the field for `$eye_side`.
- **Route**: `/OphCiExamination/default/update/<event_id>` - the Clinical Management element, bilateral layout.
- **Repro**:
  1. Open an examination for editing and add Clinical Management with a bilateral plan.
  2. Arrange for one eye to permit a long-term entry and the other not to.
  3. Read which side offers the long-term entry field.
- **Expected**: each side's field is gated on that side's own eligibility.
- **Actual**: both sides are gated on whichever eye `$side` currently holds, so one side offers a field it should not and the other hides one it should show.
- **Evidence**: view read in the container at `53b077c089`. Code-traced.
- **Severity**: medium - the affordance appears or disappears on the wrong eye, which is exactly the kind of error a clinician will not question.
- **Status**: open. Found while documenting the Clinical Management element.

## BUG-170: a Facial Injections setting is labelled in admin as something else entirely

- **Where**: `facial_injection_auto_suggest_injection_site` is displayed in admin as "Facial - Injection - Extraocular Muscle Injections: Use EMG by Default". The row is created by `protected/migrations/m251107_110820_add_facial_injections_element.php:65-73`.
- **Route**: the admin settings screen for the Facial Injections element.
- **Repro**:
  1. Open the element settings for Facial Injections in admin.
  2. Read the label of the setting whose key is `facial_injection_auto_suggest_injection_site`.
- **Expected**: a label describing injection-site auto-suggestion.
- **Actual**: the label describes EMG defaulting, an unrelated feature, so an administrator setting "EMG by default" is really changing site auto-suggestion.
- **Evidence**: migration and `setting_metadata` row read at `53b077c089`. Code-traced.
- **Severity**: low, but near-certain to be configured wrongly, because the label gives no hint of what it does.
- **Status**: open. Found while documenting the Facial Injections element.

## BUG-171: PCR Risk mirrors `can_lie_flat` in the browser only

- **Where**: `protected/modules/OphCiExamination/views/default/form_Element_OphCiExamination_PcrRisk.php:24-37` mirrors `can_lie_flat` between the two eyes in JavaScript, whereas `diabetic` and `alpha_receptor_blocker` are mirrored server-side as well at lines 157-166.
- **Route**: `/OphCiExamination/default/update/<event_id>` - the PCR Risk element.
- **Repro**:
  1. Record PCR Risk for one eye with "can lie flat" answered.
  2. Add the second eye later, or save with the page's JavaScript not having run.
- **Expected**: the two eyes hold the same patient-level answer, as they do for the diabetic and alpha-blocker questions.
- **Actual**: the two eyes can hold different `can_lie_flat` values, and the risk figures diverge on a question that is not eye-specific.
- **Evidence**: view read in the container at `53b077c089`, compared against the two server-side mirrors in the same file. Code-traced.
- **Severity**: low/medium - the inconsistency feeds a printed risk percentage.
- **Status**: open. Found while documenting the PCR Risk element.

## BUG-172: Facial Injections pre-fills a dilution before any agent has been chosen

- **Where**: `protected/modules/OphCiExamination/widgets/FacialInjection.php:62-66` defaults the dilution from `array_key_first($this->botox_agent_list_data)` while the Agent dropdown still shows its disabled "... select" placeholder.
- **Route**: `/OphCiExamination/default/create?patient_id=<id>` - the Facial Injections element.
- **Repro**:
  1. Start a new examination and add the Facial Injections element.
  2. Read the Dilution field before touching the Agent dropdown.
- **Expected**: the dilution is blank until an agent is selected, since dilution is a property of the agent.
- **Actual**: the first agent's dilution is displayed, and it saves as entered if the user does not notice.
- **Evidence**: widget read in the container at `53b077c089`. Code-traced.
- **Severity**: medium - a dosing figure shown as if chosen, attached to an agent nobody picked.
- **Status**: open. Found while documenting the Facial Injections element.

## BUG-173: Facial Injections copies the previous session's injection rows into a new session

- **Where**: `protected/modules/OphCiExamination/models/FacialInjection.php:62` omits `injections` from `DO_NOT_COPY_FIELDS`, so `copiedFields()` at line 181 returns `dilution`, `injections` and `botox_agent_id`. The injector, supervisor and batch fields are correctly excluded, which shows the intent.
- **Route**: `/OphCiExamination/default/create?patient_id=<id>` - the Facial Injections element.
- **Repro**:
  1. Record a Facial Injections session for a patient with several injections placed on the diagram, and save.
  2. Start a new examination for the same patient and add the Facial Injections element.
- **Expected**: an empty diagram, as with the injector, supervisor and batch fields.
- **Actual**: the previous session's full list of sites, volumes and units is pre-loaded, and saves as though administered today unless the user clears every row.
- **Evidence**: model read in the container at `53b077c089`. Code-traced.
- **Severity**: medium/high - this is a controlled-substance administration record, and the copied rows are indistinguishable from rows entered today.
- **Status**: open. Found while documenting the Facial Injections element.

## BUG-174: Post-Op Complications history includes later-dated entries while the element is new

- **Where**: `protected/modules/OphCiExamination/models/Element_OphCiExamination_PostOpComplications.php:187-204` - `getPostOpHistory()` applies both the `e.event_date <= :date` bound and the self-exclusion only when `!$this->isNewRecord`.
- **Route**: `/OphCiExamination/default/create?patient_id=<id>` - the Post-Op Complications element.
- **Repro**:
  1. Find a patient with a post-operative complication recorded on a future-dated examination, or back-date a new examination behind an existing one.
  2. Start the earlier examination and add the Post-Op Complications element.
  3. Read the history table.
- **Expected**: only complications recorded on or before this examination's date.
- **Actual**: complications from later examinations are listed as history, so the table claims knowledge the encounter did not have.
- **Evidence**: model read in the container at `53b077c089`. Code-traced.
- **Severity**: low - needs back-dating or out-of-order entry, and the table corrects itself once the element is saved.
- **Status**: open. Found while documenting the Post-Op Complications element.

## BUG-175: choosing Checklist in Add Event commits an empty Checklist event before the user enters anything (CONFIRMED)

- **Where**: `protected/modules/OphCoChecklist/controllers/DefaultController.php:54-56`. `actionCreate()` builds a `ChecklistManager` from the episode alone and calls `getTodayChecklistEvent()`, which runs `getOrCreateChecklistElement()` (`components/ChecklistManager.php:115-127`). That method calls `createChecklistEvent()` unconditionally whenever the patient has no checklist element dated today, the transaction is committed, and the controller then redirects to `/OphCoChecklist/default/update/<new_event_id>`. Because the manager was constructed with no context, procedure or step, `getRequiredChecklists()` (lines 74-99) selects nothing and `addRequiredChecklistTypes()` adds no instances.
- **Route**: `/OphCoChecklist/default/create` (reached from the patient summary's Add Event dialog)
- **Repro**:
  1. Log in and open a patient record.
  2. Press **Add Event** and choose **Checklist**.
  3. Without touching the form, press Back or navigate to the patient summary.
  4. Look at the patient's event list.
- **Expected**: nothing is recorded. The user opened a form and abandoned it, and no other event type behaves this way - the rest create the event on Save.
- **Actual**: a committed Checklist event is already in the record, with an `et_ophco_checklist` element row and zero `checklist_instance` rows, so it displays as an empty Checklist. There is no cancel-on-exit.
- **Evidence**: controller and component read in the container at `53b077c089`. Visible in the sample database as Checklist event `3686996`, `created_date 2026-08-05 07:18:47`, `created_user_id 1`, not deleted, with `SELECT COUNT(*) FROM checklist_instance` returning 0.
- **Severity**: medium - it writes to a clinical record before the user has entered anything, and every abandoned attempt leaves a permanent empty event in the timeline.
- **Related**: this is the explanation for the long-standing question about a Checklist event with an element row but no `checklist_instance` rows. It also explains why the documentation seeder's Checklist recipe reported success while producing nothing - its idempotency probe found this event and skipped its work. See BUG-177 for the separate, latent GET-writes path through the same component.
- **Corrected 2026-08-05**: this entry originally blamed the Operation note create form. That was wrong. The op-note path goes through `addRequiredChecklists()`, which creates an event **only when `required_checklist_types` is non-empty**, and that list is only ever populated by joining `checklist_sets` - a table with **0 rows** in this database. The op-note create form therefore writes nothing here. The unconditional path is the Checklist event's own create action, above.
- **Status**: open. Found while documenting the Operation note event, corrected while documenting the Checklist event.

## BUG-177: five event create forms write a Checklist event on the GET that renders them

- **Where**: `protected/modules/OphCoChecklist/components/ChecklistManager.php:101-113`. `addRequiredChecklists()` does its work **only when `!Yii::app()->request->isPostRequest`** - that is, on the GET that renders a create form, and never on the POST that saves it. It is called from five places: `OphTrOperationnote/controllers/DefaultController.php:132`, `OphTrLaser/controllers/DefaultController.php:111`, `OphTrIntravitrealinjection/controllers/DefaultController.php:259`, and `OphCiExamination/controllers/DefaultController.php:735` and `:1095`.
- **Route**: the create action of any of Operation note, Laser, Intravitreal injection or Examination.
- **Repro**:
  1. As an administrator, add at least one row to `checklist_sets` tying a checklist type to a context, procedure or pathway step that the target event will match.
  2. Log in as a clinical user and open a patient who has no Checklist event dated today.
  3. Press **Add Event** and choose one of Operation note, Laser, Intravitreal injection or Examination, so the create form renders.
  4. Navigate away without saving.
  5. Open the patient's event list.
- **Expected**: nothing is recorded until the form is saved.
- **Actual**: a Checklist event has been created and committed, carrying an instance for each matching checklist type.
- **Evidence**: code read in the container at `53b077c089` - the `!isPostRequest` guard at `ChecklistManager.php:103`, and `getAndAddRequiredChecklists()` at lines 283-295 which creates the event whenever `required_checklist_types` is non-empty.
- **Severity**: medium, but **latent rather than reproducible on this installation**: `SELECT COUNT(*) FROM checklist_sets` returns 0 here, so `getRequiredChecklists()` never matches anything and the write never fires. Any deployment that has configured checklist sets is exposed.
- **Status**: open, code-traced only. Not observed live, because the sample database cannot reach the branch. Logged separately from BUG-175 because it is a different entry point with a different trigger condition.

## BUG-178: selecting a booked operation on the Operation Checklists create screen throws a 500 (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/components/OphTrOperationbooking_API.php:220` reads `->find('event_id=?', array($event_id))?->disorder` on `Element_OphTrOperationbooking_Diagnosis`, but that model defines only `diagnosis_disorders` and `disorders` - there is no singular `disorder` relation. It is reached from `OphTrOperationchecklists/controllers/DefaultController.php:829` `getBookingDiagnosis()`.
- **Route**: `/OphTrOperationchecklists/Default/create?patient_id=<patient_id>`
- **Repro**:
  1. Open a patient who has an open operation booking.
  2. Go to `/OphTrOperationchecklists/Default/create?patient_id=<patient_id>`.
  3. Click the booking row to select that operation.
  4. The page 500s.
- **Expected**: the Operation Checklists form opens for the selected booking.
- **Actual**: `CException: Property "Element_OphTrOperationbooking_Diagnosis.disorder" is not defined`.
- **Evidence**: code read in the container at `53b077c089`.
- **Severity**: high for that path - it is the only entry into Operation Checklists for a booked operation.
- **Related**: the same missing `disorder` relation breaks the Admission form (BUG-075) from a different call site. The Emergency / Unbooked row on the same screen fails separately with the dropped `secondary_diagnosis` table (BUG-090). With `can_be_created_manually = 0` also hiding the event type from Add Event (BUG-020), no route into Operation Checklists works in this release.
- **Status**: open.

## BUG-176: confirming an edit from the waiting list can mark an operation Scheduled with no booking

- **Where**: the waiting list's "Edit Booking" then Confirm path posts `schedule_now=1`; `afterUpdateElements` then sets the operation's status to **Scheduled** without creating a booking row and returns the user to the waiting list. A later genuine booking is subsequently treated as a reschedule, because status 2 is in the `array(2, 3, 4)` set the reschedule branch tests.
- **Route**: `/OphTrOperationbooking/booking/waitingList`
- **Repro**:
  1. Open the waiting list and choose Edit Booking on an operation that requires scheduling.
  2. Confirm without picking a theatre session.
  3. Return to the waiting list and look for the operation.
  4. Later, book the operation properly and read the status label.
- **Expected**: either the confirm is refused without a session, or the operation stays on the waiting list.
- **Actual**: the operation is marked Scheduled with no booking behind it, so it leaves the waiting list with no theatre session, and the eventual real booking is labelled "Rescheduled".
- **Evidence**: controller path read in the container at `53b077c089`. Not reproduced - it needs a write, and the sample database has zero Scheduled or Rescheduled rows with no booking, so nothing confirms or refutes it there.
- **Severity**: medium if real - an operation silently disappears from the list of work that still needs scheduling.
- **Status**: open, unconfirmed. Found while documenting the operation booking waiting list.

## BUG-179: the Dashboard screen 500s because its default header view does not exist (CONFIRMED)

- **Where**: `DashboardController` declares `protected $headerTemplate = 'header';` (`protected/controllers/DashboardController.php:22`), and the dashboard layout renders it with `$this->renderPartial($this->getHeaderTemplate());` (`protected/views/layouts/dashboard.php:83`). There is no `header.php` in `protected/views/dashboard/` - the folder holds only `index.php` and `header_oescape.php`. `actionOEscape` escapes the fault by overriding the property to `//dashboard/header_oescape` (`DashboardController.php:166`); `actionIndex` (`:42-45`) leaves the default in place and the layout throws before any content renders.
- **Route**: `/dashboard/index`
- **Repro**:
  1. Log in as a user holding the surgeon role or as a system administrator (the screen refuses everyone else, so the error is only reachable with one of those).
  2. Open `/dashboard/index` directly.
  3. Read the error page.
- **Expected**: the Dashboard landing screen renders.
- **Actual**: `CException: DashboardController cannot find the requested view "header".` The screen produces a server error before anything renders. `/dashboard/oEscape` on the same controller renders normally, which is what makes the missing default header visible as the difference.
- **Evidence**: reproduced live in the container at `53b077c089` - logged at `2026/08/05 11:15:56` in `protected/runtime/application.log` with `REQUEST_URI=/dashboard/index`, stack frames `views/layouts/dashboard.php(83)` -> `DashboardController.php(44)`. Source read in the container.
- **Severity**: medium - the whole screen is unreachable for every surgeon and system administrator, but it is a secondary landing page and no clinical workflow depends on it.
- **Status**: open, confirmed. Found while refreshing documentation screenshots - the page is the one auto-capture in `getting-started` that cannot be photographed.

## BUG-180: an Examination event whose diagnoses carry no observation date fails to render (CONFIRMED)

- **Where**: `DiagnosesInformationResource::sortEntriesByObsDate()` sorts diagnosis entries with `strtotime($a->obs_date) <=> strtotime($b->obs_date)` (`protected/modules/Diagnoses/resources/DiagnosesInformationResource.php:155`). `obs_date` is nullable, and passing null to `strtotime()` is deprecated on PHP 8.1+. The very next clause on the same line already guards its own nullable field with `?->` (`$a->created_datetime?->getTimestamp()`), so the null case was anticipated for one field and missed for the other. The sort is reached whenever the Diagnoses widget renders in summary mode (`Diagnoses/widgets/RecordEvent.php:351` -> `:288` -> `:203`), which is on every Examination event view that has a Diagnoses element.
- **Route**: `/OphCiExamination/default/view/<event_id>`
- **Repro**:
  1. Log in as a user who can view clinical events and open a patient with an Examination event containing a Diagnoses element.
  2. Ensure at least one of that element's diagnosis entries has no observation date - `SELECT e.id, e.obs_date FROM diagnoses_record_event_entry e JOIN diagnoses_record_event re ON re.id = e.record_event_id WHERE re.event_id = <event_id>` returns a row with `obs_date` NULL.
  3. Open the event's view page.
  4. Read the response.
- **Expected**: the Examination event view renders, with the undated diagnosis sorted somewhere deterministic.
- **Actual**: the request returns HTTP 500 and nothing renders. The deprecation is escalated to a fatal by the configured error handler, so whether a given deployment 500s or merely logs depends on its error-reporting configuration; on this stack it 500s.
- **Evidence**: reproduced live in the container at `53b077c089` during the documentation screenshot refresh - `/OphCiExamination/default/view/3686740` returned HTTP 500, and `protected/runtime/application.log` logs `2026/08/05 14:44:23 [error] [php] strtotime(): Passing null to parameter #1 ($datetime) of type string is deprecated (.../DiagnosesInformationResource.php:155)` with `REQUEST_URI=/OphCiExamination/default/view/3686740` and no other error for that request. Event 3686740 (patient 17891) has 8 diagnosis entries, 4 of them with `obs_date` NULL. The sample database holds 254 `diagnoses_record_event_entry` rows with a NULL `obs_date`, so the condition is common rather than exotic.
- **Severity**: high - a clinical event becomes unreadable, and the trigger is ordinary data rather than a rare edge case.
- **Related observation, not a separate bug**: the same event carries an entry with `obs_date` `1996-00-00`. `strtotime()` returns false for a partial date like that, so it sorts as though it were the epoch rather than as 1996. Any fix to the null handling should decide what a partial date means too.
- **Status**: open, confirmed. Found while refreshing documentation screenshots.

## BUG-181: the Cat-PROM5 index route is dead code that returns a server error instead of a not-found (CONFIRMED)

- **Where**: `OEModule\OphOuCatprom5\controllers\DefaultController::actionIndex()` (`protected/modules/OphOuCatprom5/controllers/DefaultController.php:36`) renders a view `index`, and `protected/modules/OphOuCatprom5/views/default/index.php` exists but is **zero bytes**. The action can never run: `BaseEventTypeController::beforeAction()` calls `isPrintAction($action->id)` (`protected/controllers/BaseEventTypeController.php:509`), which calls `getActionType()` (`:491`), which throws when the action is absent from `$action_type_map` (`:289-293`). The default map (`:83-99`) has no `index` entry and this controller does not override it, so the request dies in `beforeAction` before `actionIndex()` is reached.
- **Route**: `/OphOuCatprom5/default/index`
- **Repro**:
  1. Log in as any user who can view clinical events.
  2. Open `/OphOuCatprom5/default/index` directly - nothing in the application links to it, so it has to be typed.
  3. Read the response.
- **Expected**: either a working screen, or a not-found response for a route that does not exist.
- **Actual**: HTTP 500. `Exception: Action 'index' has no type associated with it`.
- **Evidence**: reproduced live in the container at `53b077c089` during the documentation screenshot refresh - `/OphOuCatprom5/default/index` returned HTTP 500, with `protected/runtime/application.log` showing frames `BaseEventTypeController.php(491): getActionType()` and `BaseEventTypeController.php(509): isPrintAction()` under `REQUEST_URI=/OphOuCatprom5/default/index` at `2026/08/05 14:34:25`. `OphOuCatprom5/config/common.php` declares no menu entry for it, and no other event-type controller defines an `actionIndex`.
- **Severity**: low - the route is unreachable through the interface and its view is empty, so nothing a user can click is affected. It is logged because it is dead code that fails noisily, and because route discovery picks it up as a real page.
- **Documentation impact**: the corpus should not carry a page or a screenshot for this route.
- **Status**: open, confirmed. Found while refreshing documentation screenshots.

## BUG-182: the Consultant and Surgeon ticks on Default SSO Permissions are stored but never applied (CONFIRMED)

- **Where**: `User::setdefaultSSORights()` (`protected/models/User.php:918-924`) is the only reader of the SSO default-rights row, and it copies exactly two fields - `global_firm_rights`, and `has_selected_firms` derived from it. The `is_consultant` and `is_surgeon` columns the admin screen writes to `sso_default_user_rights` are never read by anything, so the ticks reach the database and stop there.
- **Route**: `/admin/ssodefaultrights`
- **Repro**:
  1. Log in as a system administrator and open Admin > SSO settings > Default Permissions.
  2. Tick **Consultant** and **Surgeon** and save.
  3. Sign a new user in through SSO so the defaults are applied to them.
  4. Open that user in Admin > Core > Users and read the Consultant and Surgeon flags.
- **Expected**: the new user carries the consultant and surgeon flags the defaults asked for.
- **Actual**: neither flag is set. Re-opening the Default Permissions screen still shows both ticked, so the screen reports a setting the application does not honour.
- **Evidence**: source read in the container at `53b077c089`. Not reproduced end to end - `sso_config` has zero rows in the sample database, so no SSO sign-in can be performed there; the defect is that the two columns have no reader anywhere in the codebase, which is a static fact.
- **Severity**: medium - the screen silently misreports what SSO-provisioned users will get, and the two flags it drops both affect clinical attribution.
- **Status**: open, confirmed by code. Found while documenting the SSO settings admin screens.

## BUG-183: the Common Ophthalmic Disorders institution check compares a group's institution against a row's primary key (CONFIRMED)

- **Where**: `AdminController.php:460` validates the chosen group with `if ($group->institution_id && (int) $group->institution_id !== (int) $common_ophthalmic_disorder->id)`. The right-hand side is the disorder row's **primary key**, not its institution. The equivalent systemic screen gets this right: `protected/controllers/oeadmin/CommonSystemicDisorderController.php:103` compares against `->institution_id`.
- **Route**: `/admin/editcommonophthalmicdisorder`
- **Repro**:
  1. Log in as a system administrator and open Admin > Disorders > Common Ophthalmic Disorder Groups.
  2. Create a group scoped to a single institution rather than leaving the institution blank.
  3. Open Admin > Disorders > Common Ophthalmic Disorders, add a row, and choose that group.
  4. Save and read the validation message.
- **Expected**: the row saves, as the identical operation on the systemic screen does.
- **Actual**: the save is refused with "Group is not available for the selected institution". Any institution-scoped group is unusable, because the comparison it has to pass is against an unrelated integer. A row could only pass by coincidence, if its primary key happened to equal the group's institution id.
- **Evidence**: source read in the container at `53b077c089`. Not reproduced - all three `common_ophthalmic_disorder_group` rows in the sample database have a NULL institution, so the guard is never entered there and reproducing it needs a scoped group created first.
- **Severity**: medium - institution-scoped ophthalmic disorder groups cannot be used at all, and the message blames the data rather than the check.
- **Status**: open, confirmed by code. Found while documenting the disorders admin screens.

## BUG-184: adding the first row to an empty Common Systemic Disorders grid submits a display order of NaN (CONFIRMED)

- **Where**: `protected/views/admin/editcommonsystemicdisorder.php:218` computes the new row's order as `parseInt($('table.generic-admin tbody tr:last-child').find('input[name$="display_order]"]').val()) + 1`. With no rows on screen the selector matches nothing, `.val()` is undefined, and `parseInt(undefined) + 1` is `NaN`, which posts as the string "NaN". The sibling group screen guards exactly this: `protected/views/admin/listcommonsystemicdisordergroup.php:206-207` uses `$last_order_input ? +$last_order_input.value + 1 : 0`.
- **Route**: `/oeadmin/CommonSystemicDisorder/list`
- **Repro**:
  1. Log in as a system administrator and open Admin > Disorders > Common Systemic Disorders.
  2. Set the institution selector to an institution that has no entries, so the grid is empty.
  3. Select **Add** and fill in the disorder.
  4. Save and read the response.
- **Expected**: the first row saves with a display order of 0 or 1.
- **Actual**: the insert is refused. `display_order` is `int(11)` and this server runs with `STRICT_TRANS_TABLES`, so a non-numeric value is a database error rather than a silently coerced zero, and the user sees a raw error instead of a field message.
- **Evidence**: source read in the container at `53b077c089`; `@@sql_mode` read from the database. Not reproduced - all 14 `common_systemic_disorder` rows in the sample database have a NULL institution, so no institution selection produces an empty grid there without first adding an institution-scoped row.
- **Severity**: medium - it blocks the first entry for any institution, which is exactly the configuration step a new deployment performs.
- **Status**: open, confirmed by code. Found while documenting the disorders admin screens.

## BUG-185: a non-administrator leaflet manager silently moves another institution's leaflet to their own (CONFIRMED)

- **Where**: three behaviours combine. The list is unfiltered - `LeafletController::actionIndex()` calls `AdviceLeaflet::model()->findAll()` with no criteria (`protected/modules/Admin/modules/Leaflets/controllers/LeafletController.php:36-38`). The Institution field is hidden from non-administrators - `.../views/leaflets/edit.php:71` wraps it in `if (Yii::app()->user->checkAccess('admin'))`. And the save forces ownership - `LeafletController.php:116-118` overwrites `institution_id` with `Institution::model()->getCurrent()->id` for anyone without `admin`. The sibling category screen does filter its list (`LeafletCategoryController.php:39`), so the omission is specific to leaflets.
- **Route**: `/Admin/Leaflets/Leaflet/index`
- **Repro**:
  1. Log in as a user holding `TaskAdminManageLeaflets` but not the `admin` role.
  2. Open Admin > Leaflets > Leaflets and confirm leaflets belonging to other institutions are listed.
  3. Edit one that belongs to a different institution - make any change, or none.
  4. Save, then check that leaflet's institution as a system administrator.
- **Expected**: either the leaflet is not offered for editing, or its institution is preserved across the save.
- **Actual**: the leaflet is re-homed to the editor's own institution. Nothing on screen says so, because the Institution field is not rendered for that user, and the original institution loses a leaflet without any action of its own.
- **Evidence**: source read in the container at `53b077c089`. Not reproduced - it needs a second institution and a suitably restricted account, neither of which exists usefully in the sample database (only 2 of 46 leaflets are institution-scoped).
- **Severity**: medium - cross-institution data loss from an ordinary save, invisible to the user performing it.
- **Status**: open, confirmed by code. Found while documenting the leaflets admin screens.

## BUG-186: Cancel does nothing on admin edit screens whose Cancel button carries no destination (CONFIRMED)

- **Where**: `protected/assets/js/handleButtons.js:26` builds the fallback destination with `var object = e[parseInt(i) + 1].replace(/^[a-z]+/, '').toLowerCase() + 's';`. `e` is the jQuery event object; the array being walked is `hrefArray`, which the correct branch two lines above uses. Indexing the event object yields undefined, so `.replace()` throws. The handler has already called `e.preventDefault()` and `disableButtons()` by then, so the navigation is cancelled and the buttons stay disabled.
- **Route**: any admin edit screen whose Cancel button has no `data-uri`, for example `/admin/editSystemSetting`
- **Repro**:
  1. Log in as a system administrator and open Admin > System > Settings.
  2. Open a setting for editing.
  3. Select **Cancel**.
  4. Watch the screen and the browser console.
- **Expected**: the screen returns to the settings list.
- **Actual**: nothing happens. The form's buttons are left greyed out, so the only way on is the browser's back button or a reload. The console carries a TypeError from `handleButtons.js`.
- **Evidence**: source read in the container at `53b077c089`. Only the fallback branch is affected; screens whose Cancel carries an explicit destination take an earlier path and work normally, which is why the fault is intermittent across the admin area rather than universal.
- **Severity**: low - no data is lost and every affected screen has a working way out, but the control appears broken.
- **Status**: open, confirmed by code. Found while documenting the system settings admin screens.

## BUG-187: saving a webhook subscriber never shows its confirmation message (CONFIRMED)

- **Where**: `WebhooksAdminController::actionEditSubscriber()` (`protected/modules/Webhooks/modules/WebhooksAdmin/controllers/WebhooksAdminController.php:48-49`) calls `$this->redirect(['subscribers'])` and only then `Yii::app()->user->setFlash('success', 'Subscriber saved')`. `redirect()` ends the request, so the flash is never set and the line is unreachable.
- **Route**: `/Webhooks/admin/WebhooksAdmin/editsubscriber`
- **Repro**:
  1. Log in as a system administrator and open Admin > System > Webhooks Subscribers.
  2. Add a subscriber, or edit an existing one.
  3. Save.
  4. Read the subscribers list the save returns to.
- **Expected**: a success message confirming the subscriber was saved.
- **Actual**: the list appears with no message. The save did work; only the confirmation is missing, so the user has to find their subscriber in the list to know it succeeded.
- **Evidence**: source read in the container at `53b077c089`. Not reproduced - `webhooks_subscriber` has zero rows in the sample database, so the screen has no working context there.
- **Severity**: low - cosmetic, but it makes a save indistinguishable from a silent failure.
- **Status**: open, confirmed by code. Found while documenting the webhooks admin screens.

## BUG-188: the Sites table inside an institution puts every column heading over the wrong box (CONFIRMED)

- **Where**: `protected/views/admin/institutions/edit.php:50-63` declares a twelve-entry `$sites_headers` map that includes `'email' => 'Contact'`. The row partial `protected/views/admin/sites/_site_row.php` never renders an email field - it renders `name, short_name, remote_id`, then the address fields, then `telephone, fax`, then a country dropdown. The extra heading shifts every heading after it one column to the left, so "Contact" sits over the first address box and the mislabelling continues to the end of the row.
- **Route**: `/admin/editInstitution?institution_id=<id>`
- **Repro**:
  1. Log in as a system administrator and open any institution for editing.
  2. Scroll to the Sites section.
  3. Select **Add site** so the table and its headings are drawn.
  4. Read each heading against the box beneath it.
- **Expected**: each heading sits over the field it names.
- **Actual**: from the fourth column onwards every heading names a different field than the box below it.
- **Evidence**: source read in the container at `53b077c089`. The headings are only visible once the table is revealed by the `#add-institution-sites-btn` handler (`edit.php:696-705`), which is why the fault is easy to miss.
- **Severity**: medium - site addresses are entered against the wrong labels, so the data is likely to be entered in the wrong fields.
- **Status**: open, confirmed by code. Found while documenting the institutions admin screen.

## BUG-189: deleting a commissioning body has no confirmation and no in-use check (CONFIRMED)

- **Where**: `AdminController::actionDeleteCommissioningBodies()` (`protected/controllers/AdminController.php:2544`) nulls the `commissioning_body_id` on any linked `commissioning_body_service` and then calls `CommissioningBody::model()->deleteAll($criteria)`. It never calls `canDelete()`. The confirmation dialog the screen ships cannot fire either: the view uses generic `et_add` / `et_delete` element ids while its own JavaScript binds `#et_add_commissioning_body` / `#et_delete_commissioning_body`, so `assets/js/handleButtons.js` handles `#et_delete` and posts straight through.
- **Route**: `/admin/commissioning_bodies`
- **Repro**:
  1. Log in as a system administrator and open Admin > Core > Commissioning Bodies.
  2. Tick a commissioning body that is not referenced by any patient or practice.
  3. Select **Delete** and watch for a prompt.
  4. Repeat with a commissioning body that a patient or a GP practice is linked to.
- **Expected**: a confirmation prompt, then either the deletion or a message naming what still references the record.
- **Actual**: step 3 deletes immediately with no prompt. Step 4 fails on a raw database error page, because `commissioning_body_patient_assignment_cbid_fk` and `commissioning_body_practice_assignment_cbid_fk` are both `ON DELETE RESTRICT`. Either way the linked services have already had their `commissioning_body_id` cleared by the time the delete is attempted, so a failed delete still leaves the services detached.
- **Evidence**: source read in the container at `53b077c089`; foreign-key delete rules read from `information_schema`. Not reproduced - `commissioning_body` has zero rows in the sample database.
- **Severity**: high - an unprompted destructive action, and its failure path leaves related records modified with no way to tell from the screen.
- **Status**: open, confirmed by code. Found while documenting the commissioning bodies admin screens.

## BUG-190: the Element Type Custom Text screen is headed "Event custom text" (CONFIRMED)

- **Where**: `protected/views/admin/custom_text.php:9` hardcodes the `<h3>`, but the view serves both custom-text screens - `AdminController.php:319-341` and `:346-376` both render it.
- **Route**: `/admin/editElementTypeCustomText`
- **Repro**:
  1. Log in as a system administrator and open Admin > Core > Element Type Custom Text.
  2. Read the heading.
  3. Open Admin > Core > Event Type Custom Text and read that heading.
- **Expected**: each screen is headed with the list it manages.
- **Actual**: both are headed "Event custom text". Only the sidebar tells the two screens apart.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - cosmetic, but it makes a screenshot of one screen indistinguishable from the other.
- **Status**: open, confirmed by code. Found while documenting the custom text admin screens.

## BUG-191: the Institutions search box names six fields and searches three (CONFIRMED)

- **Where**: the placeholder at `protected/views/admin/institutions/index.php:32` reads "Name, ID, Pas Code, First name, Last name, Subspeciality Name". The query at `AdminController.php:1295-1306` compares `name`, `remote_id` and `short_name` only.
- **Route**: `/admin/institutions`
- **Repro**:
  1. Log in as a system administrator and open Admin > Core > Institutions.
  2. Read the search box placeholder.
  3. Search for an institution by its PAS code, or by a contact's first or last name.
- **Expected**: the placeholder describes what the box searches.
- **Actual**: three of the six named fields are not searched, so a correct search term returns nothing and looks like missing data.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low.
- **Status**: open, confirmed by code. Found while documenting the institutions admin screen.

## BUG-192: two commissioning-body list screens label a column Code and print the short name (CONFIRMED)

- **Where**: `protected/views/admin/commissioning_body_types/index.php:28,40` heads a column "Code" and prints `shortname`. `protected/views/admin/commissioning_body_service_types/index.php` does the same. Neither table has a code column at all.
- **Route**: `/admin/commissioning_body_types` and `/admin/commissioning_body_service_types`
- **Repro**:
  1. Log in as a system administrator and open Admin > Core > Commissioning Body Types.
  2. Note the value in the Code column for a row.
  3. Open that row and compare it with the Short Name field on the edit form.
- **Expected**: a Code column shows a code, or the column is named for what it holds.
- **Actual**: the Code column repeats the Short Name, and no code exists anywhere in the model.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low.
- **Status**: open, confirmed by code. Found while documenting the commissioning bodies admin screens.

## BUG-193: the Last Name field on a commissioning body service is overwritten by the service name on save (CONFIRMED)

- **Where**: `AdminController::saveEditCommissioningBodyService()` (`protected/controllers/AdminController.php:2732`) assigns `$contact->last_name = $cbs->name;` **after** `$contact->attributes = $_POST['Contact']`, so whatever the user typed is discarded.
- **Route**: `/admin/editCommissioningBodyService?commissioning_body_service_id=<id>`
- **Repro**:
  1. Log in as a system administrator and open a commissioning body service for editing.
  2. Type a surname into **Last Name**.
  3. Save.
  4. Reopen the service and read Last Name.
- **Expected**: the surname is kept, since the field is editable.
- **Actual**: Last Name always holds the service's name.
- **Evidence**: source read in the container at `53b077c089`. Not reproduced - `commissioning_body_service` has zero rows in the sample database.
- **Severity**: medium - the field looks editable and is not, and the value it silently overwrites reaches generated correspondence through `DocumentTarget` and `ElementLetter`.
- **Status**: open, confirmed by code. Found while documenting the commissioning body services admin screen.

## BUG-194: the Parent chosen for a newly added ethnic group is never submitted (CONFIRMED)

- **Where**: the add-row Mustache template `#js-ethnic-group-template` in `protected/views/admin/edit_ethnic_groups.php` renders its parent `<select>` with **no `name` attribute**, so the browser omits it from the post. Every other input in the same template is named (`EthnicGroup[{{index}}][name]`, `[code]`, `[describe_needs]`), and existing rows rendered by the PHP loop have a named field, so only newly added rows are affected.
- **Route**: `/admin/editEthnicGroups`
- **Repro**:
  1. Log in as a system administrator and open Admin > Core > Ethnic Groups.
  2. Select **Add**.
  3. Fill in Name and Code and choose a **Parent**.
  4. Save, then reopen the screen and read the new row's Parent.
- **Expected**: the new group carries the chosen parent.
- **Actual**: the new group has no parent, whatever was chosen. Editing the row a second time works, because by then it is an existing row with a named field.
- **Evidence**: source read in the container at `53b077c089`. Noted alongside: the same template's Delete button reuses `$group->id` leaked from the earlier `foreach`, which is latent but currently harmless.
- **Severity**: medium - the hierarchy is the point of the screen, and the failure is silent.
- **Status**: open, confirmed by code. Found while documenting the ethnic groups admin screen.

## BUG-195: a deleted ethnic group is still offered on the patient demographics screen (CONFIRMED)

- **Where**: `AdminController.php:3256-3316` soft-deletes ethnic groups absent from the post. The patient demographics form loads the list with `EthnicGroup::model()->findAll()` and no `notDeleted()` scope (`protected/views/patient/crud/_form.php:44`). `BaseActiveRecordVersionedSoftDelete` declares no `defaultScope` and `EthnicGroup` adds none, so nothing filters the deleted rows out.
- **Route**: `/admin/editEthnicGroups`, then any patient demographics edit screen
- **Repro**:
  1. Log in as a system administrator and open Admin > Core > Ethnic Groups.
  2. Delete a group and save.
  3. Open any patient's demographics for editing.
  4. Open the Ethnic group list.
- **Expected**: the deleted group is no longer offered.
- **Actual**: it is still in the list and can still be assigned to a patient.
- **Evidence**: source read in the container at `53b077c089`. Not reproduced - all 37 `ethnic_group` rows are live and none is soft-deleted, so demonstrating it needs a deletion performed first.
- **Severity**: medium - an administrator's deletion has no effect on the screen that matters, and new patients can still be recorded against a retired group.
- **Status**: open, confirmed by code. Found while documenting the ethnic groups admin screen.

## BUG-196: paging through the Examination Event Logs discards the search and the status filter (CONFIRMED)

- **Where**: `EventLogController::actionList()` reads its filter from `Yii::app()->request->getPost('search')` and guards on `isPostRequest`, while the `LinkPager` widget in `protected/views/oeadmin/event_log/index.php` generates GET links. Page two therefore arrives with no filter and the action falls back to the unfiltered list.
- **Route**: `/oeadmin/eventLog/list`
- **Repro**:
  1. Log in as a system administrator and open the Examination Event Logs screen.
  2. Enter a search term or choose a status, then select **Search**.
  3. Select page 2.
  4. Read the rows.
- **Expected**: the filter persists across pages.
- **Actual**: page 2 shows the unfiltered list, and returning to page 1 shows it unfiltered too.
- **Evidence**: source read in the container at `53b077c089`. Not reproduced - `automatic_examination_event_log` has zero rows in the sample database. Separate but related: the same action matches whole values only (`event_id = :query` OR `unique_code = :query` OR `examination_date = :query`), so a partial search term never matches anything.
- **Severity**: low - the data is intact and re-searching recovers it.
- **Status**: open, confirmed by code. Found while documenting the event logs admin screen.

## BUG-197: the same site field is called Remote ID in the list and Code on the form (CONFIRMED)

- **Where**: `protected/views/admin/sites/index.php:81` hardcodes `<th>Remote ID</th>`. The edit form prints the model's own label (`protected/views/admin/sites/edit.php:127-129`), and `protected/models/Site.php:132` maps `remote_id` to "Code".
- **Route**: `/admin/sites`, then any site
- **Repro**:
  1. Log in as a system administrator and open Admin > Core > Sites.
  2. Note the Remote ID column.
  3. Open a site and look for a field of that name.
- **Expected**: one name for one field.
- **Actual**: the form has no Remote ID; the same value appears as Code.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - but it is the kind of mismatch that makes documentation look wrong whichever name it picks.
- **Status**: open, confirmed by code. Found while documenting the sites admin screen.

## BUG-198: the Practitioners search ignores the Code column the list displays (CONFIRMED)

- **Where**: `GpController.php:382-386` builds its search over `LOWER(last_name)`, `LOWER(first_name)` and `LOWER(primary_phone)` only, while `protected/views/gp/index.php` renders `nat_id` in a column headed **Code**. The sibling Practices screen does it properly - `PracticeController.php:526-536` searches `code`, the address lines and the postcode.
- **Route**: `/gp/index`
- **Repro**:
  1. Open Practitioners from the menu bar.
  2. Note the value in the **Code** column for any row.
  3. Paste that value into the search box and press Enter.
  4. Read the result.
- **Expected**: the practitioner with that code is returned.
- **Actual**: "No results found." The code is the only unambiguous identifier on the screen, and it is the one field the search does not cover.
- **Evidence**: source read in the container at `53b077c089`. The sample database has 184 `gp` rows, so this is directly reproducible there.
- **Severity**: medium - a user searching by the identifier the screen shows them concludes the record does not exist.
- **Status**: open, confirmed by code. Found while documenting the directories screens.

## BUG-199: the disorder list draws a Specialty filter box that filters nothing (CONFIRMED)

- **Where**: `Disorder::search()` (`protected/models/Disorder.php:175-187`) compares `id`, `fully_specified_name` and `term` only - there is no `compare('specialty_id', ...)`. Both `protected/views/disorder/index.php` and `admin.php` declare the Specialty column inside a `'filter' => $model` grid, so CGridView renders an input for it regardless.
- **Route**: `/disorder/index`
- **Repro**:
  1. Open the disorder list.
  2. Type a specialty name into the **Specialty** box in the grid's filter row.
  3. Press Enter.
  4. Compare the list with what it showed before.
- **Expected**: the list narrows to that specialty.
- **Actual**: the list is unchanged and the typed value is silently discarded, so an unfiltered list looks like a filtered one.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - nothing breaks, but the control invites a user to trust a list that was never filtered.
- **Status**: open, confirmed by code. Found while documenting the shared clinical tools screens.

## BUG-200: the patient CSV upload screen is hard-wired to the trials context (CONFIRMED)

- **Where**: `protected/views/csv/upload.php:9` hardcodes the banner `Patient Upload`, and `:19` renders `<a href="<?= $backuri ?? '/OETrial/trial/' ?>">Go Back to Trials</a>`. `CsvController::actionUpload($context)` renders the view with `array('context' => $context)` only, so `$backuri` is never defined and the fallback always wins. The trial module's own side panel does pass it (`OETrial/views/trial/_side_panel.php:150,159` send `['context' => 'trials', 'backuri' => '/OETrial/trial']`), so the view expects a variable its controller never supplies.
- **Route**: `/csv/upload/<context>`
- **Repro**:
  1. Open the patient import screen from the menu bar in any context other than trials.
  2. Read the banner.
  3. Read the only link in the side panel.
- **Expected**: a banner and a back link matching the context you arrived from.
- **Actual**: the banner always reads "Patient Upload" and the link always reads "Go Back to Trials", pointing at `/OETrial/trial/`.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low to medium - non-trial users are sent somewhere they have never been, and many will not hold trial permissions when they get there.
- **Status**: open, confirmed by code. Found while documenting the patient import screen.

## BUG-201: the Scan Uploaded Files menu entry is offered to everyone and admits only the account literally named admin (CONFIRMED)

- **Where**: two faults at once. The menu entry in `protected/config/core/common.php` (`'virus_scan' => array('title' => 'Scan Uploaded Files', 'uri' => '/VirusScan/index', 'requires_setting' => ...)`) carries no `restricted` key, so it is drawn for every signed-in user. And `VirusScanController`'s access rule is `'users' => array('admin')` (`:14-15`) - in Yii 1 `users` matches the **username**, not a role, so the screen admits exactly one account and no role assignment can ever grant it.
- **Route**: `/VirusScan/index`
- **Repro**:
  1. Enable virus scanning for the deployment.
  2. Sign in as any user other than the account named `admin`, including one holding every administrative role.
  3. Note **Scan Uploaded Files** in the menu bar.
  4. Select it.
- **Expected**: either the entry is hidden from users who cannot use it, or it opens.
- **Actual**: every user is offered the entry and everyone except the `admin` account is refused with a 403.
- **Evidence**: source read in the container at `53b077c089`. Related: the `enable_virus_scanning` row was removed from `setting_metadata` by migration `m240617_170700_remove_virus_scan_setting.php`, so the feature is now switched on by environment only.
- **Severity**: low - a dead-end menu entry rather than a data fault, but the username-based check means the capability cannot be delegated at all, which is a design problem rather than a typo.
- **Status**: open, confirmed by code. Found while documenting the virus scanning screen.

## BUG-202: a required Custom path step field looks optional and fails with a raw application error (CONFIRMED)

- **Where**: `protected/modules/PathwayStep/views/admin/custom_step_form.php` renders the **Standard Pathway type** select with an empty first option and no required marker, while `PathwayStepType` validates the underlying category as mandatory.
- **Route**: Admin > Worklist > Custom path steps > Add
- **Repro**:
  1. Open Admin > Worklist > Custom path steps.
  2. Select **Add**.
  3. Fill in the name and leave **Standard Pathway type** on its blank first option.
  4. Save.
- **Expected**: either the field is marked required and the form redisplays with a field-level error, or a blank value is accepted.
- **Actual**: an application error page reading "Category is empty".
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - a routine configuration task dead-ends on an error page, and nothing on the form says which field caused it.
- **Status**: open, confirmed by code. Found while documenting the worklist and patient ticketing configuration screens.

## BUG-203: Visual field test presets column heading names one algorithm and lists all of them (CONFIRMED)

- **Where**: `protected/modules/OphCiExamination/views/worklist/steps/visualfields.php` - the column heading is the literal string "SITA Standard" while the cells render the preset's SITA algorithm, which may be any of the available values.
- **Route**: Admin > Worklist > Visual field test presets
- **Repro**:
  1. Open Admin > Worklist > Visual field test presets.
  2. Compare the column heading with the values printed beneath it.
- **Expected**: a heading that describes the column, such as "Algorithm".
- **Actual**: the heading reads "SITA Standard", so any row whose algorithm is not SITA Standard appears to contradict its own column.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - cosmetic, but on a screen whose whole purpose is distinguishing algorithms.
- **Status**: open, confirmed by code. Found while documenting the worklist and patient ticketing configuration screens.

## BUG-204: which wait time applies to a pathway is undefined when more than one is configured (CONFIRMED)

- **Where**: `protected/models/Pathway.php`, `getAcceptableWaitTime()` - the method takes `$wait_values[0]` from a result set fetched with no `ORDER BY`, so the row chosen is whatever the database returns first.
- **Route**: any worklist showing a pathway wait-time colour
- **Repro**:
  1. Configure two wait times against a single pathway in Admin > Worklist > Wait times.
  2. Open a worklist containing a patient on that pathway.
  3. Read the wait-time colour.
- **Expected**: a defined rule for which of the configured wait times governs, such as the shortest or the most recently edited.
- **Actual**: the first row the database happens to return wins, so the colour can change between deployments or after unrelated maintenance without any configuration change.
- **Evidence**: source read in the container at `53b077c089`. Latent in sample data: `worklist_wait_time` holds 0 rows, so the multi-row case cannot arise until wait times are configured.
- **Severity**: low - latent, but it makes a clinical-priority colour non-deterministic once the feature is used as designed.
- **Status**: open, confirmed by code. Found while documenting the worklist and patient ticketing configuration screens.

## BUG-205: a queue set that fails validation returns an error page instead of the form (CONFIRMED)

- **Where**: `protected/modules/PatientTicketing/controllers/AdminController.php:183-195` - the validation-failure branch re-renders `form_queue` with `'queue' => null`, and the view dereferences that variable.
- **Route**: Admin > Patient ticketing > Queue sets > edit
- **Repro**:
  1. Open Admin > Patient ticketing > Queue sets.
  2. Open an existing queue set for editing.
  3. Clear a required field.
  4. Save.
- **Expected**: the form redisplayed with the validation errors marked against their fields.
- **Actual**: an application error page. The edit is lost and the user has no indication of which field was at fault.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - a normal validation path is unrecoverable and discards the user's work.
- **Status**: open, confirmed by code. Found while documenting the worklist and patient ticketing configuration screens.

## BUG-206: a custom filter that fails to save reports success, and a failed delete answers both failure and success (CONFIRMED)

- **Where**: `protected/modules/PatientTicketing/modules/PatientTicketingAdmin/controllers/CustomFilterController.php`. In the save action (`:86-93`) `renderEditForm($custom_filter, $errors)` is called without `return`, so execution falls through to the `redirect()` on the next line. In `actionDelete()` (`:99-121`) the `catch` block rolls the transaction back and echoes `0`, then execution continues to `$transaction->commit()` and echoes `1`.
- **Route**: Admin > Patient ticketing > Custom filters
- **Repro**:
  1. Open Admin > Patient ticketing > Custom filters.
  2. Create or edit a filter and enter a value that fails validation.
  3. Save.
  4. Separately, trigger a delete that fails - for example a filter still assigned to a queue set.
- **Expected**: the edit form redisplayed with errors on save failure; a single, truthful response on delete failure.
- **Actual**: on save failure the rendered error form is discarded and the browser is redirected to the list, so an unsaved filter looks saved. On delete failure the response body is `01` and `commit()` is called on an already rolled-back transaction.
- **Evidence**: source read in the container at `53b077c089`. The controller lives under `modules/PatientTicketing/modules/PatientTicketingAdmin/`, not directly under `modules/PatientTicketing/controllers/`.
- **Severity**: medium - silent data loss on the save path; the user is told nothing went wrong.
- **Status**: open, confirmed by code. Found while documenting the worklist and patient ticketing configuration screens.

## BUG-207: the Patient ticketing Institution filter scopes what admin saves but not what the app offers (CONFIRMED)

- **Where**: the PatientTicketing admin controllers apply the institution filter when listing and writing clinic locations and outcome options, but the runtime outcome and location widgets query those tables with no institution condition.
- **Route**: Admin > Patient ticketing > Clinic locations, and Admin > Patient ticketing > Outcome options
- **Repro**:
  1. Open Admin > Patient ticketing > Clinic locations and set the Institution filter to a single institution.
  2. Note the shortened list.
  3. Open a patient ticket in the application and use the outcome or location control.
- **Expected**: the control offers the same institution-scoped list the admin screen defines.
- **Actual**: the control lists every row for every institution. The filter changes only what an administrator sees and saves, not what a clinical user is offered.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - an administrator reasonably reads the filter as configuring the deployment, and it does not.
- **Status**: open, confirmed by code. Found while documenting the worklist and patient ticketing configuration screens.

## BUG-208: the Operations report Role column is never populated and shifts every later cell one column left (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationnote/models/OphTrOperationnote_ReportOperation.php` - the row assembly omits a value for the Role column that the header declares.
- **Route**: Reports > Operation note > Operations
- **Repro**:
  1. Open Reports > Operation note > Operations.
  2. Run the report over a period containing an operation recorded with an assistant or a supervising surgeon.
  3. Read the resulting row against the column headings.
- **Expected**: the surgeon's role in the Role column and every other value under its own heading.
- **Actual**: the Role cell is empty and each subsequent value appears one column to the left of its heading, so the whole row is misread.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - the report is legible but every column after Role is mislabelled.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-209: the EUR report names the wrong permission when refusing, and two of its three actions are unguarded (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/controllers/ReportController.php`. `accessRules()` (`:4-11`) returns a single allow rule listing `EUR`, `runreport` and `downloadreport` with no `roles` or `users` restriction. Only `actionEUR` (`:18-24`) then checks anything, via `checkAccess('Report', ...)`, and it reports the failure as "Not authorised: Only for consultant". `runreport` and `downloadreport` are real actions on `BaseReportController` (`:99`) and carry no check of their own.
- **Route**: `/OphTrOperationbooking/report/eur`
- **Repro**:
  1. Sign in as a user without the Report permission.
  2. Open `/OphTrOperationbooking/report/eur` and note the refusal wording.
  3. Post the report parameters directly to the `runreport` action on the same controller.
  4. Read the response.
- **Expected**: a 403 naming the reporting permission, applied consistently to every action that returns report data.
- **Actual**: the landing action throws a raw `CException` reading "Not authorised: Only for consultant", which names a role that is not what is checked; and `runreport`/`downloadreport` return report data without checking the permission at all.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: high for the unguarded actions - the permission gate on this report can be bypassed by addressing the data-returning actions directly. Medium for the misleading message.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-210: the EUR report returns assessments from every institution (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/models/OphTrOperationbooking_ReportEUR.php:41` - the query is `findAll('t.result = 1 AND event.deleted = 0')` with no institution or site condition.
- **Route**: `/OphTrOperationbooking/report/eur`
- **Repro**:
  1. Sign in at one institution on a multi-institution deployment.
  2. Open Reports > Operation booking > EUR.
  3. Leave both dates empty and run the report.
- **Expected**: assessments belonging to the signed-in institution.
- **Actual**: every passed assessment on the installation, including other institutions'.
- **Evidence**: source read in the container at `53b077c089`. Unobservable in sample data: `eur_event_results` holds 0 rows.
- **Severity**: medium - cross-institution data visibility on a shared deployment.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-211: the Cat-PROM5 chart renames itself and relabels its hover text between the first draw and a redraw (CONFIRMED)

- **Where**: `protected/modules/OphOuCatprom5/components/Catprom5Report.php:372` and `:350-351` supply the initial title and series names; `protected/assets/js/dashboard/OpenEyes.Dash.js:487,493,525` rewrites them on redraw.
- **Route**: Analytics > CA > Cat-PROM5
- **Repro**:
  1. Open Analytics > CA > Cat-PROM5 and read the chart title - it reads "... - All Eyes".
  2. Select **Update Chart** without changing any input. The title now reads "... - Both Eyes".
  3. Select **Eye 2** and update again.
  4. Hover a data point in each of the Pre-op, Post-op and difference modes.
- **Expected**: one consistent wording for the same selection.
- **Actual**: "All Eyes" becomes "Both Eyes" on redraw; Eye 2 renders as "difference- Eye 2" with the space on the wrong side of the hyphen; and the hover label changes from "Score:" to "Diff Post:", continuing to read "Diff Post" even in Pre-op and Post-op modes where the value is not a difference.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - cosmetic, but the hover label misnames the value in two of the three modes.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-212: the Complication Profile hover repeats the complication's own count as the operation total (CONFIRMED)

- **Where**: `CataractComplicationsReport::tracesJson()` - the hover template is given the trace's own value for the field presented as "Total Operations".
- **Route**: Analytics > CA > Complication Profile
- **Repro**:
  1. Open Analytics > CA > Complication Profile.
  2. Hover any bar.
  3. Compare the "Total Operations" figure with the bar's own count.
- **Expected**: the number of operations in view, so the rate shown can be checked against it.
- **Actual**: the complication's own count repeated, so every bar appears to have occurred in 100% of operations.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - the plotted rate is correct; only the hover figure is wrong.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-213: the Complication Profile operation total counts deleted operation notes when a single surgeon is selected (CONFIRMED)

- **Where**: `CataractComplicationsReport::getTotalOperations()` builds the query with `->where('event.deleted=0')` and then, in the single-surgeon branch, calls `->where('surgeon_id = :surgeon', ...)`, which replaces the condition rather than adding to it.
- **Route**: Analytics > CA > Complication Profile
- **Repro**:
  1. Ensure at least one cataract operation note by the selected surgeon has been deleted.
  2. Open Analytics > CA > Complication Profile.
  3. View a single surgeon rather than all surgeons.
  4. Read the Total Operations figure.
- **Expected**: deleted operation notes excluded, as they are in the all-surgeons view.
- **Actual**: deleted notes are counted, inflating the denominator and understating every complication rate. The all-surgeons view is unaffected because it never reaches the overwriting call.
- **Evidence**: verified in the container at `53b077c089`: `protected/modules/OphTrOperationnote/components/CataractComplicationsReport.php:277` sets the deleted condition and `:280` overwrites it.
- **Severity**: medium - a clinical rate is wrong, and wrong only for the per-surgeon view, which is the one an individual consultant looks at.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-214: the Injections CSV puts post-injection visual acuity in two unnamed trailing columns (CONFIRMED)

- **Where**: `protected/modules/OphTrIntravitrealinjection/models/OphTrIntravitrealinjection_ReportInjections.php` - the column assembly for the downloaded file does not match the header row when only a subset of the optional column groups is selected.
- **Route**: Reports > Intravitreal injection > Intravitreal injections
- **Repro**:
  1. Open Reports > Intravitreal injection > Intravitreal injections.
  2. Tick **Summarise patient data** and **Post injection VA** and leave the other optional groups clear.
  3. Run the report and confirm the on-screen table is correct.
  4. Select **Download report** and open the CSV.
- **Expected**: the post-injection visual acuity values under their own headed columns, matching what the screen showed.
- **Actual**: the headed columns read "N/A" and the values appear in two unnamed columns appended to the end of each row. The on-screen table is correct, so the fault is only in the download.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - the download is the artefact people analyse, and the misalignment is silent.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-215: the Injections report Summarise patient data tick-box does the opposite of its label (CONFIRMED)

- **Where**: `protected/modules/OphTrIntravitrealinjection/views/report/injections.php` labels the control **Summarise patient data**, while `OphTrIntravitrealinjection_ReportInjections::run()` treats the unticked state as the summarised one.
- **Route**: Reports > Intravitreal injection > Intravitreal injections
- **Repro**:
  1. Open Reports > Intravitreal injection > Intravitreal injections.
  2. Run the report with **Summarise patient data** clear and note one row per patient, eye, drug and site.
  3. Run it again with the box ticked and note one row per individual injection.
- **Expected**: ticking the box produces the summary.
- **Actual**: ticking the box produces the detailed listing and clearing it produces the summary.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - both outputs are correct data; only the control is inverted.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-216: every Analytics cataract chart omits its most recent day by default (CONFIRMED)

- **Where**: `protected/components/reports/Report.php:134-137` formats the `to` parameter as `Y-m-d`, and the queries compare it with `<=` against `datetime` columns (`protected/modules/OphOuCatprom5/components/Catprom5Report.php:280-282` is one of several). `protected/assets/js/analytics/analytics_toolbox.js:77-95` pre-fills the picker via `initDatePicker(event_date)` with the newest recorded event date, so the default view always lands on the failing boundary.
- **Route**: Analytics > CA (any chart)
- **Repro**:
  1. Open Analytics > CA.
  2. Note that **to** arrives pre-filled with the newest recorded event date rather than empty.
  3. Select **Update Chart** without changing anything.
  4. Compare the count with the number of events recorded on that final day.
- **Expected**: the day shown in the **to** box included in the results.
- **Actual**: `'2026-08-05' >= '2026-08-05 09:14:00'` is false, so every event timed after midnight on the final day is excluded. Because the picker defaults to exactly that day, the newest day of data is missing from the default view of every cataract chart.
- **Evidence**: verified in the container at `53b077c089`: `event.event_date` is a `datetime` column, and the `to` value is formatted date-only before comparison.
- **Severity**: medium - it affects every cataract analytics chart, in the default view, silently.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-217: the PCR Risk adjusted rate is diluted by operations carrying more than one complication (CONFIRMED)

- **Where**: `PcrRiskReport::queryData()` and `dataSet()` - expected risk is accumulated per complication row rather than per operation, so an operation with two complications contributes its expected risk twice.
- **Route**: Analytics > CA > PCR Risk, Adjusted
- **Repro**:
  1. Ensure the period includes at least one cataract operation recorded with two or more complications.
  2. Open Analytics > CA > PCR Risk.
  3. Select the Adjusted view.
  4. Compare it with the Unadjusted view.
- **Expected**: each operation's expected risk counted once.
- **Actual**: expected risk is inflated in proportion to the number of multi-complication operations, which depresses the adjusted rate below the true figure.
- **Evidence**: verified in the container at `53b077c089`. Sample DB: `ophtroperationnote_cataract_complication` holds 494 rows across 487 cataract operations, 4 of which carry more than one complication - so the distortion is present but small here and would grow with a more complicated case mix.
- **Severity**: medium - an outcome measure that consultants are compared on reads better than reality, and by an amount that varies with case complexity.
- **Status**: open, confirmed by code and DB. Found while documenting the surgical, injection, device and outcome reports.

## BUG-218: NOD audit eligibility is decided by the patient's age today rather than at operation (CONFIRMED)

- **Where**: `NodAuditReport::NodEligibilityDataToArray()` - eligibility tests `$current_patient->getAge() >= 18`, which returns the patient's current age.
- **Route**: Analytics > CA > NOD Audit
- **Repro**:
  1. Open Analytics > CA > NOD Audit.
  2. Run it over a historic period containing an operation on a patient who was under 18 at the time but is over 18 now.
  3. Read the Eligibility For NOD Audit bar.
  4. Re-run the same historic period at a later date.
- **Expected**: eligibility judged on the patient's age at the date of the operation, so a historic period always reports the same figures.
- **Actual**: eligibility is judged on age now, so the same historic period yields different figures each time it is run and paediatric operations progressively reclassify as adult ones.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - a national audit figure that is not reproducible for a fixed period.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-219: the NOD audit cannot distinguish "nothing to record" from "not recorded" (CONFIRMED)

- **Where**: `NodAuditReport::InsertDataToArray()`, the cataract surgical management case - the Comorbidities and History measure counts only records carrying a guarded prognosis, so an operation with genuinely no comorbidity scores the same as one where nobody filled the section in.
- **Route**: Analytics > CA > NOD Audit
- **Repro**:
  1. Open Analytics > CA > NOD Audit.
  2. Run it over a period including patients with no comorbidity to record.
  3. Read the Comorbidities and History completeness figure.
- **Expected**: a distinction between a complete record with nothing to flag and an incomplete one.
- **Actual**: both count as incomplete, so completeness is understated for healthy patients.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - it understates data quality rather than misreporting clinical outcome.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-220: the MDOR device usage extract includes deleted events (CONFIRMED)

- **Where**: `oe-laravel/app/Modules/TrDeviceUsageRecord/Repositories/DeviceUsageReportRepository.php` - the extract query filters on `DATE(event.event_date)` and institution only. The string `deleted` does not appear anywhere in the file, so no `event.deleted = 0` condition exists on any query path.
- **Route**: Reports > Medical Device Usage Record > MDOR extract
- **Repro**:
  1. Record a device usage event.
  2. Delete that event.
  3. Request an MDOR extract covering the event's date.
  4. Read the extract.
- **Expected**: the deleted event excluded, as every other report in the application excludes deleted events.
- **Actual**: the deleted event is present in the extract.
- **Evidence**: verified in the container at `53b077c089`: `grep -in deleted` against the repository file returns nothing.
- **Severity**: high - this extract is a submission to a national device registry, so the fault sends withdrawn records to an external body and there is no on-screen indication that it has happened.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-221: the MDOR extract picks arbitrarily between a patient's local identifiers (CONFIRMED)

- **Where**: the `local_patient_identifier` CTE in `DeviceUsageReportRepository.php` uses `row_number()` with no deterministic ordering, so where a patient holds more than one local identifier the one exported is whichever the database returns first.
- **Route**: Reports > Medical Device Usage Record > MDOR extract
- **Repro**:
  1. Ensure a patient holds two local identifiers.
  2. Request an MDOR extract covering one of that patient's device usage events.
  3. Read the identifier column.
  4. Re-run the extract.
- **Expected**: a defined rule for which identifier is exported, applied consistently.
- **Actual**: the identifier can differ between runs of the same extract.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - it needs a patient with duplicate local identifiers to bite, but the extract is a registry submission and identifier stability matters there.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-222: the Cat-PROM5 chart shows every patient on the installation regardless of who is signed in (CONFIRMED)

- **Where**: `protected/modules/OphOuCatprom5/components/Catprom5Report.php` contains no surgeon, institution or site condition anywhere - a case-insensitive grep for `surgeon`, `allSurgeons` and `institution` across the whole file returns nothing. Every other Analytics CA chart scopes by surgeon.
- **Route**: Analytics > CA > Cat-PROM5
- **Repro**:
  1. Sign in as a user without the Service Manager role, which is what grants the all-surgeons view elsewhere.
  2. Open Analytics > CA > Cat-PROM5.
  3. Compare the case count with the number of your own cases.
  4. Toggle **View all surgeons** and update the chart.
- **Expected**: your own cases, with **View all surgeons** widening the scope as it does on the other CA charts.
- **Actual**: every patient on the installation is counted whoever is signed in, and **View all surgeons** has no effect because there is nothing to widen.
- **Evidence**: verified in the container at `53b077c089`.
- **Severity**: medium - outcome data for other institutions' patients is visible to any user who can reach the chart, and the control that appears to govern it is inert.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-223: selecting an Eye 2 point on the Cat-PROM5 chart opens the first eye's operation (CONFIRMED)

- **Where**: `protected/modules/OphOuCatprom5/components/Catprom5Report.php:157` and `:237` - `cataract_element_id` is taken from `eoc2.event_id`, the first operation, in both the Eye 2 branch and the Eye 2 half of the All Eyes union.
- **Route**: Analytics > CA > Cat-PROM5
- **Repro**:
  1. Open Analytics > CA > Cat-PROM5.
  2. Select Eye = Eye 2 and update the chart.
  3. Select a data point to drill down.
  4. Read which operation opens.
- **Expected**: the second eye's operation.
- **Actual**: the first eye's operation, with nothing to indicate the wrong record has been opened.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - the chart itself is right; only the drill-down target is wrong. It is easy to mistake for a data problem.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-224: the Cat-PROM5 chart counts deleted events (CONFIRMED)

- **Where**: `protected/modules/OphOuCatprom5/components/Catprom5Report.php` - none of the five event joins carries an `event.deleted = 0` condition.
- **Route**: Analytics > CA > Cat-PROM5
- **Repro**:
  1. Record a questionnaire and a cataract operation for a patient so the patient appears on the chart.
  2. Delete one of those events.
  3. Reload Analytics > CA > Cat-PROM5.
- **Expected**: the patient's contribution withdrawn along with the deleted event.
- **Actual**: the deleted event continues to contribute to the plotted outcome.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - an outcome measure that does not respond to correction of the record it is derived from.
- **Status**: open, confirmed by code. Found while documenting the surgical, injection, device and outcome reports.

## BUG-225: the EUR report chooses its deciding question by comparing ActiveRecord objects (SUSPECTED)

- **Where**: `OphTrOperationbooking_ReportEUR::run()` - `$deciding_question = max($eur->eurAnswerResults)` applies `max()` to an array of model objects, so PHP falls back to comparing object properties in declaration order and the result is not the highest-scoring answer by any defined measure.
- **Route**: `/OphTrOperationbooking/report/eur`
- **Repro**:
  1. Record an EUR assessment with more than one answer result.
  2. Open Reports > Operation booking > EUR and run it over that assessment's date.
  3. Read the statement given as the deciding question.
- **Expected**: the answer that determined the assessment's outcome.
- **Actual**: an arbitrary one of the answers, determined by PHP's object comparison rules rather than by the report's intent.
- **Evidence**: source read in the container at `53b077c089`. Not reproducible on this deployment: `eur_event_results` holds 0 rows, so the behaviour is inferred from the code alone and the intended selection rule is not documented anywhere in the module.
- **Severity**: unknown, likely low - it needs a multi-answer assessment to differ from the single-answer case.
- **Status**: open, suspected from code only. Found while documenting the surgical, injection, device and outcome reports.

## BUG-226: the Therapy Application worklist "modified today" tick-box discards every other filter, including institution (CONFIRMED)

- **Where**: `protected/modules/OphCoTherapyapplication/controllers/WorklistController.php:126-129` - the extra clause is added with `$criteria->addCondition($condition, 'OR')`, which ORs it against the whole accumulated criteria rather than being bracketed as an additional inclusion.
- **Route**: `/OphCoTherapyapplication/worklist/index`
- **Repro**:
  1. Open the Therapy Application worklist.
  2. Set a status, a NICE compliance value and a date range.
  3. Tick **Include applications that have been modified today**.
  4. Search.
- **Expected**: the applications modified today added to the result set, still within the current institution and the other filters.
- **Actual**: every application modified today is returned regardless of institution, status, compliance, date range or creating user - the OR defeats all of the preceding conditions at once.
- **Evidence**: verified in the container at `53b077c089`: the preceding conditions are added with the default AND, and the final one with `'OR'`.
- **Severity**: high - a filtered clinical worklist silently returns other institutions' applications, and the control that causes it reads as a narrowing option.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-227: Failsafe Management builds its SQL by concatenating unescaped POST values (CONFIRMED)

- **Where**: `protected/modules/OphCiExamination/controllers/ResponsibleForCareManagementController.php`. `:95` passes the raw `$_POST` array to `constructWhereConditionsAndParamsString()`, which at `:145`, `:150`, `:154`, `:165`, `:169` and `:174` builds the WHERE clause with `implode(', ', $data[...])` and, for the subspecialty, the bare concatenation `"ssa.subspecialty_id=".$data["subspecialty"]`. The resulting string is executed through `findAllBySql()`. No value on any of these paths is bound or escaped.
- **Route**: `/OphCiExamination/responsibleForCareManagement/index`
- **Repro**:
  1. Sign in as any user who can reach Failsafe Management.
  2. Submit the filter form with a crafted value in `areas_of_care[]`, `statuses[]`, `institution[]`, `responsible_institution[]` or `subspecialty`.
  3. Observe that the value reaches the executed statement uninterpreted.
- **Expected**: every value bound as a query parameter, as the rest of the application does.
- **Actual**: the values are concatenated into the WHERE string and executed, so the filter form is an SQL injection point for any authenticated user who can open the screen.
- **Evidence**: verified in the container at `53b077c089` by reading the call site and the builder. **Deliberately not exercised against the running application** - the fault is established from the code path alone, and confirming it by injection was neither necessary nor appropriate. Note the method is named `constructWhereConditionsAndParamsString`, so parameter binding was intended and never implemented.
- **Severity**: high - authenticated SQL injection. It sits behind a login and behind whatever permission reaches this screen, which bounds it, but the pattern is unambiguous and appears six times in one method.
- **Status**: open, confirmed by code. Recommend triage ahead of the rest of this batch. Found while documenting the worklist and operation booking screens.

## BUG-228: a Failsafe Management row for a patient with no area of care emits ten cells against nine headers (CONFIRMED)

- **Where**: `protected/modules/OphCiExamination/views/responsibleforcaremanagement/_list.php:27-35` declares nine `<th>`; the blank-patient branch emits ten `<td>` across `:110-113`, `:114` and `:125-129`.
- **Route**: `/OphCiExamination/responsibleForCareManagement/index`
- **Repro**:
  1. Open Failsafe Management.
  2. Search so that the result set includes a patient with no area-of-care entry.
  3. Compare that row's cells with the header row.
- **Expected**: cells aligned with their headings.
- **Actual**: the row runs one column wider than the table, so every value in it sits under the wrong heading and the rows below appear shifted.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - cosmetic, but it makes one row of a clinical safety screen unreadable.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-229: an Optom Invoice Manager patient search matching more than one patient returns nothing (CONFIRMED)

- **Where**: `protected/modules/OphCiExamination/models/AutomaticExaminationEventLog.php:191-193` - the loop `foreach ($results as $result) { $criteria->addCondition('patient.id = ' . $result->id); }` ANDs one equality per match, so two matches produce a condition no row can satisfy.
- **Route**: `/OphCiExamination/optomFeedback/list`
- **Repro**:
  1. Open the Optom Invoice Manager.
  2. Enter a surname or partial identifier matching more than one patient in **Patient Identifier**.
  3. Search.
  4. Repeat with a term matching exactly one patient.
- **Expected**: rows for every matching patient.
- **Actual**: no results at all for the multi-match term, while the single-match term works - so the screen appears to say the patients have no invoices rather than that the search cannot express the question.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - a search that silently returns nothing is read as an answer, and searching by surname is the obvious way to use this screen.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-230: an Optom Invoice Manager row can be set to a status the screen's own filter cannot find (CONFIRMED)

- **Where**: the per-row Invoice Status control offers inactive statuses; the Invoice Status filter above it lists active statuses only.
- **Route**: `/OphCiExamination/optomFeedback/list`
- **Repro**:
  1. Open the Optom Invoice Manager.
  2. Set a row's Invoice Status to a status that is no longer active.
  3. Try to find that row again using the Invoice Status filter.
- **Expected**: any status a row can hold is a status the filter can search for.
- **Actual**: the row cannot be searched back, because the filter never offers the value the row now holds.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - recoverable by clearing the filter, but the row is effectively lost to anyone using the screen as intended.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-231: the Patient Ticketing "no results" message can never appear (CONFIRMED)

- **Where**: `protected/modules/PatientTicketing/views/default/ticketlist.php:86` renders the banner only if a flash message is set, but `views/default/index.php` has already read and cleared that flash before the partial renders.
- **Route**: `/PatientTicketing/default/index`
- **Repro**:
  1. Open Patient Ticketing.
  2. Search for a term that matches no tickets.
- **Expected**: the message "No tickets match that search criteria".
- **Actual**: an empty list with no explanation, indistinguishable from a queue that genuinely has no tickets.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - the correct message exists in the code and is unreachable.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-232: Theatre Diaries reports two validation errors on the first visit of every session (CONFIRMED)

- **Where**: the screen autoloads its saved search on open; with no saved search in the session it posts empty dates, which the controller then rejects.
- **Route**: `/OphTrOperationbooking/theatreDiary/index`
- **Repro**:
  1. Sign in and open Theatre Diaries without having used it earlier in the session.
  2. Read the screen.
- **Expected**: a sensible default date range, or an empty form with no error.
- **Actual**: the screen opens showing "Empty start date" and "Empty end date". The user has done nothing wrong and the errors clear only once a search is run.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - it greets every user on every first visit with two errors, which trains people to ignore the error area on a theatre screen.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-233: the Theatre Diaries Context list is empty until Subspeciality is changed (CONFIRMED)

- **Where**: `Firm::getList()` is called with the literal string `'All'` where a subspecialty id is expected. The controller's own guards at `protected/modules/OphTrOperationbooking/controllers/TheatreDiaryController.php:252` and `:256` treat `'All'` as a sentinel value, confirming it is not an id.
- **Route**: `/OphTrOperationbooking/theatreDiary/index`
- **Repro**:
  1. Open Theatre Diaries.
  2. Open the **Context** list without touching **Subspeciality**.
  3. Change **Subspeciality** to any value and open **Context** again.
- **Expected**: the contexts belonging to the current subspecialty.
- **Actual**: only the placeholder is listed until Subspeciality is changed, so filtering by context appears unavailable on arrival.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - a filter that looks broken on arrival and works only after an unrelated interaction.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-234: one worklist screen appears under three different names, and a filter value is spelled two ways (CONFIRMED)

- **Where**: the Request Form Worklist is named differently in its menu entry, its page heading and its browser title; the Therapy Application worklist renders the same compliance value as both "Non Compliant" and "Non-Compliant".
- **Route**: `/OphCoRequestForm/worklist/index` and `/OphCoTherapyapplication/worklist/index`
- **Repro**:
  1. Compare the Request Form Worklist's menu entry, page heading and browser title.
  2. On the Therapy Application worklist, compare the compliance filter's options with the values printed in the result rows.
- **Expected**: one name per screen and one spelling per value.
- **Actual**: three spellings of the same worklist and two spellings of the same compliance value.
- **Evidence**: source read in the container at `53b077c089`. Related: BUG-094 already records the equivalent mismatch between the Optom menu label and the Optom Invoice Manager heading; this entry covers the other two.
- **Severity**: low - cosmetic individually, but it defeats searching the documentation or the menu for the screen by name.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-235: the partial bookings "Next letter due" filter is applied after pagination, so pages come back short (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/views/waitingList/_list.php:26` takes `$dataProvider->getData()` and `:34` applies `array_filter` to it - that is, to the thirty rows already returned by the query's LIMIT, not to the query.
- **Route**: `/OphTrOperationbooking/waitingList/index`
- **Repro**:
  1. Open the partial bookings waiting list.
  2. Search so the result set runs to several pages.
  3. Set **Next letter due** to one stage.
  4. Page through the results.
- **Expected**: only matching operations, repaginated so the pages are full and the page count reflects the filter.
- **Actual**: each page shows only the matches that happened to fall in that page's thirty rows, so pages come back short or completely empty while the page count never changes. There is no indication that matching records exist on other pages.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: medium - the screen drives letter chasing, and this makes it under-report work that is due.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-236: a present alpha blocker is counted twice in the whiteboard "Risks (N)" heading (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/models/OphTrOperationbooking_Whiteboard.php:511` carries a comment saying alpha blockers are excluded, but the `array_filter` at `:513-515` removes only `Anticoagulants`. The alpha blocker line therefore reaches the `$total_risks++` at `:558`, and `components/views/wb_allergies_and_risks.php:8-9` increments again for the same risk before printing it at `:35`.
- **Route**: `/OphTrOperationbooking/whiteboard/view/<booking_id>`
- **Repro**:
  1. Open the whiteboard for a booking whose patient carries a present Alpha blockers risk assignment marked to display on the whiteboard.
  2. Compare the number in the **Risks (N)** heading with the number of risk boxes shown.
- **Expected**: the count matches the number of risks displayed.
- **Actual**: the count is one higher than the number of boxes.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - the risks themselves are all displayed; only the tally is wrong. It is on a theatre safety display, so it is worth correcting.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-237: the whiteboard consent address returns a 500 for a booking with no consent procedure (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/controllers/WhiteboardController.php:325-329` calls `Element_OphTrConsent_Procedure::model()->find(...)` and then dereferences `$procedure->event_id` with no null check.
- **Route**: `/OphTrOperationbooking/whiteboard/consentForm/<booking_id>`
- **Repro**:
  1. Find a booking that has no linked consent procedure. The **Consent** button is not drawn for it.
  2. Address `/OphTrOperationbooking/whiteboard/consentForm/<booking_id>` directly - by editing the address, or by following a bookmark made when the booking did have a consent form.
- **Expected**: a message explaining there is no consent form, or a redirect back to the whiteboard.
- **Actual**: a 500 error page.
- **Evidence**: source read in the container at `53b077c089`. The button is correctly hidden, so this needs a guessed or stale address to reach - but a bookmarked whiteboard consent form is an ordinary thing for theatre staff to keep.
- **Severity**: low - unreachable by clicking, but the recovery from a stale bookmark is an error page.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-238: a waiting list safety guard tests for markup the screen no longer emits (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/assets/js/WaitingListController.js:159` tests `hasClass('waitinglistOrange')` and matches on `>NO GP<`, neither of which `views/waitingList/_list.php` emits any more.
- **Route**: `/OphTrOperationbooking/waitingList/index`
- **Repro**:
  1. Read the print-selection handler in `WaitingListController.js`.
  2. Compare the class and text it tests for with what the current list view renders.
- **Expected**: either a guard that fires, or no guard.
- **Actual**: the condition can never be true, so the no-GP protection it appears to provide does not exist. No user-visible symptom was found - it is reported because it reads as an active safety check.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - dead code. Logged so nobody assumes the guard is protecting the letter run.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-239: the Transport screen's Completed tick-box is posted and never read (CONFIRMED)

- **Where**: the checkbox is drawn at `protected/modules/OphTrOperationbooking/views/transport/index.php:89` and posted by `assets/js/TransportController.js:183`, but the parameter `include_completed` is never read anywhere in `protected/` outside the JavaScript and the view that emits it. `TransportController::getTransportList()` does not reference it.
- **Route**: `/OphTrOperationbooking/transport/index`
- **Repro**:
  1. Open Transport.
  2. Tick or untick **Completed** under **Include:**.
  3. Select **Filter**.
  4. Compare the result sets.
- **Expected**: completed bookings included or excluded accordingly.
- **Actual**: the two result sets are identical. The control has no effect at all.
- **Evidence**: verified in the container at `53b077c089`: a recursive grep for `include_completed` across `protected/` returns only the view that emits it and the JavaScript that posts it, and no reader.
- **Severity**: medium - a filter that silently does nothing, on a screen whose purpose is working through outstanding transport.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-240: the Transport screen's Method column shows the booking's state rather than the transport method (CONFIRMED)

- **Where**: the header at `protected/modules/OphTrOperationbooking/views/transport/_list_header.php:40` reads "Method", while `views/transport/_list.php:77` prints `$operation->transportStatus`, defined at `models/Element_OphTrOperationbooking_Operation.php:1608-1638`. The same mismatch is carried into the CSV export at `controllers/TransportController.php:311` and `:323`.
- **Route**: `/OphTrOperationbooking/transport/index`
- **Repro**:
  1. Open Transport with rows present.
  2. Read the **Method** column.
  3. Export the CSV and read the same column.
- **Expected**: how the patient is travelling.
- **Actual**: Booked, Rescheduled, Cancelled or Completed - the state of the booking, not the method of transport. The transport method is not shown on the screen at all.
- **Evidence**: source read in the container at `53b077c089`.
- **Severity**: low - the data displayed is correct for what it is, but a transport clerk reads the column as answering a question it does not answer, and the CSV carries the same mislabelling downstream.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-241: the Transport list's colour coding is emitted but has no styling, so every row looks identical (CONFIRMED)

- **Where**: `protected/modules/OphTrOperationbooking/views/transport/_list.php:58` emits `class="status <?= $operation->transportColour ?>"` yielding `Red`, `Green` or `Grey`, and `assets/js/TransportController.js` applies `waitinglistGrey` on confirmation. No rule for `.Red`, `.Green`, `.Grey` or `.waitinglistGrey` exists anywhere in `protected/assets` - neither the compiled `nxblu/dist/css/*.css` nor the sass sources.
- **Route**: `/OphTrOperationbooking/transport/index`
- **Repro**:
  1. Open Transport with rows present.
  2. Compare an overdue row with a future one.
  3. Confirm a row and watch it.
- **Expected**: the red, green and grey distinction the markup implies, and a visible change on confirmation.
- **Actual**: every row is styled identically and confirming a row changes nothing visually. The screen's only urgency signal is absent.
- **Evidence**: verified in the container at `53b077c089`: a grep for the four class names across `protected/assets` returns nothing. Contrast the partial bookings waiting list, whose equivalent key is genuinely styled at `nxblu/src/sass/openeyes/modules/partial-booking/v1/_partial-waiting.scss:78-100` and does render - so this is a gap in Transport specifically, not a retired convention.
- **Severity**: medium - the transport list is worked by urgency, and the urgency cue never renders.
- **Status**: open, confirmed by code. Found while documenting the worklist and operation booking screens.

## BUG-242: saving a webhook subscriber never confirms, because the flash is set after the redirect has already ended the request (CONFIRMED)

- **Where**: `protected/modules/Webhooks/modules/WebhooksAdmin/controllers/WebhooksAdminController.php:47-50`. The success branch reads `$this->redirect(['subscribers']); Yii::app()->user->setFlash('success', 'Subscriber saved');` - in that order. `CController::redirect()` defaults to `$terminate = true` (`vendor/yiisoft/yii/framework/web/CController.php:1026`), which calls `Yii::app()->end()`, so the `setFlash` line is unreachable. Separately, no view in the module renders flashes at all: a grep for `flash` across `protected/modules/Webhooks/` matches only that one dead controller line.
- **Route**: `/Webhooks/admin/WebhooksAdmin/editsubscriber` (Admin > System > Webhooks Subscribers > Add or Edit)
- **Repro**:
  1. Log in as an administrator and open Admin, then System, then Webhooks Subscribers.
  2. Click the button to add a subscriber.
  3. Enter any URL and pick a system event.
  4. Click 'Save'.
  5. Look at the subscribers list you land on.
- **Expected**: a "Subscriber saved" confirmation, which the code plainly intends to show.
- **Actual**: the list redisplays with no confirmation of any kind. The subscriber is saved correctly - only the acknowledgement is missing - so on a screen whose rows are just a URL and an event list, the only way to tell a save worked is to re-read the table.
- **Evidence**: verified in the container at `53b077c089` by reading the controller and the framework's `redirect()` signature, and by grepping the whole module for flash rendering. Two independent reasons the message can never appear.
- **Severity**: low - cosmetic, no data effect, but it is dead code that reads as a working confirmation.
- **Status**: open, confirmed by code. Found while capturing the screenshot for the Webhooks Subscribers page.

## BUG-243: a consent form can never be saved again once a contact is added to "Others involved in the decision making process" (CONFIRMED)

- **Where**: `protected/modules/OphTrConsent/models/Element_OphTrConsent_OthersInvolvedDecisionMakingProcess.php:290-310`. `afterSave()` replays every posted contact row into the underlying `Contact` and its `Address`, unconditionally: `$cont->address->country_id = $data['country_id'];` then `if (!$cont->address->save()) { throw new Exception(...) }`. The posted row's `$data` comes from `Ophtrconsent_OthersInvolvedDecisionMakingProcessContact::getJsonData()` (`Ophtrconsent_OthersInvolvedDecisionMakingProcessContact.php:197-202`), which is just the stored row's attributes - and the stored row's `country_id` is NULL, because the adder that created it never supplied one. `Address` requires a country, so the save throws, and the throw is not caught anywhere.
- **Route**: `/OphTrConsent/default/update/:event_id` (Patient > Consent form > Edit > 'Save')
- **Repro**:
  1. Open any patient, click 'Add Event' and create a Consent form.
  2. On the "Others involved in the decision making process" element, click 'Add contact'.
  3. Pick an OpenEyes user from the adder, choose a contact method, and confirm the adder.
  4. Click 'Save'. The form saves and the contact appears on the event.
  5. Click the edit icon on the event to reopen the form, change nothing, and click 'Save' again.
- **Expected**: the form saves again, unchanged.
- **Actual**: a raw exception page - "Unable to save contact address: Array ( [country_id] => Array ( [0] => Country cannot be blank. ) )". The form is now permanently unsaveable: every subsequent save reposts the same NULL country and throws again. The only escape is deleting the contact row.
- **Evidence**: verified live in the container at `53b077c089`. Event 3687004 was created with one such contact (`ophtrconsent_others_involved_decision_making_process_contact` id 1, `country_id` NULL, `contact_id` 576768); reopening `/OphTrConsent/default/update/3687004` and clicking 'Save' with no edits returns the exception page above. The contact row's NULL country is what is replayed - the adder's payload for an OpenEyes user carries no address country.
- **Severity**: high - an ordinary consent form becomes uneditable after a routine data entry step, and the failure is an unhandled exception rather than a validation message.
- **Status**: open, confirmed live. Found while seeding a Type 4 consent form for the documentation screenshots.

## BUG-244: a comment typed while adding a consent decision contact is silently discarded (CONFIRMED)

- **Where**: `protected/modules/OphTrConsent/models/Element_OphTrConsent_OthersInvolvedDecisionMakingProcess.php:250-262`. `afterSave()` applies the posted comment only on the branch that finds an already-stored row: `$model->comment = $post_data['comment'][$idx];` sits inside `if ($existing_id && $model = ...->find(...))`. The `else` branch, which handles a row just added by the adder, builds the model from the adder's JSON alone (`$model->setAttributes($data)`) and never reads `$post_data['comment']`. The comment box is offered on new rows regardless (`views/default/form_Element_OphTrConsent_OthersInvolvedDecisionMakingProcess.php:97-104`, and again in the mustache template at 171-178).
- **Route**: `/OphTrConsent/default/create?patient_id=:id&unbooked=1` and `/OphTrConsent/default/update/:event_id`
- **Repro**:
  1. Open any patient, click 'Add Event' and create a Consent form.
  2. On the "Others involved in the decision making process" element, click 'Add contact', pick a contact and a contact method, and confirm the adder.
  3. On the new row, click the speech-bubble button in the Comment column.
  4. Type a comment into the box that appears.
  5. Click 'Save' and read the Comment column on the saved event.
- **Expected**: the comment appears against the contact.
- **Actual**: the Comment column is empty and the stored `comment` is NULL. Nothing warns that the text was dropped. Because of BUG-243 the form cannot be reopened and saved again either, so on a form where the contact was added in the same session the comment cannot be recorded at all.
- **Evidence**: verified live in the container at `53b077c089`. A seeded run typed "Phoned to discuss the patient's care plan..." into the comment box of a newly added contact and saved successfully; `ophtrconsent_others_involved_decision_making_process_contact` id 1 came back with `comment` NULL.
- **Severity**: medium - silent data loss on a clinical record, in a field the form invites the user to fill.
- **Status**: open, confirmed live. Found while seeding a Type 4 consent form for the documentation screenshots.

## BUG-245: Extra Procedures Subspecialty Assignment has no effect - the consent form offers every extra procedure regardless (CONFIRMED)

- **Where**: `protected/modules/OphTrConsent/views/default/form_Element_OphTrConsent_ExtraProcedures.php:3` builds the adder's item set from `OphTrConsent_Extra_Procedure::model()->findAll()` - no institution filter, no subspecialty filter, no join to the assignment table. The assignment table itself (`ophtrconsent_extra_proc_subspecialty_assignment`) is read nowhere outside its own admin screen: grepping `protected/` for the model class returns the admin controller's CRUD (`controllers/oeadmin/ExtraProceduresController.php:210-308`), a delete-dependency count (`:140`), the model, the migration and the OeConfig page definition, and nothing else.
- **Route**: `/OphTrConsent/oeadmin/ExtraProcedures/editSubspecialty` (Admin > Consent > Extra Procedures Subspecialty Assignment), observed on `/OphTrConsent/Default/create?patient_id=:id&unbooked=1`
- **Repro**:
  1. Log in as an administrator and open Admin, then Consent, then Extra Procedures, and add a procedure.
  2. Open Extra Procedures Subspecialty Assignment, choose a subspecialty, and assign that procedure to one institution and that subspecialty only.
  3. Open a patient whose context is a different subspecialty, click 'Add Event' and create a Consent form.
  4. On the Extra Procedures element, click the adder.
- **Expected**: the procedure is offered only in the subspecialty and institution it was assigned to - which is what the assignment screen's own presence implies, and what its name says.
- **Actual**: the adder lists every extra procedure defined anywhere in the system, in every subspecialty, at every institution. The assignment is stored and never consulted, so the screen configures nothing.
- **Evidence**: verified in the container at `53b077c089` by reading the form view and grepping every reference to the assignment model and table. Confirmed live: with one procedure assigned to institution 1 / subspecialty 12 only, the adder on a General Ophthalmology consent form offered it, and it is the only row in the table, so no negative case is distinguishable from the positive one - the code path proves the point.
- **Severity**: medium - an administrator can spend real effort scoping procedures per subspecialty with no effect whatsoever, and long procedure lists stay long everywhere.
- **Status**: open, confirmed by code. Found while seeding a Consent form's Extra Procedures element for the documentation screenshots.

## BUG-246: an event whose preview cannot be rendered spins forever in the Lightning Viewer, and the message explaining why is deleted (CONFIRMED)

- **Where**: `protected/assets/js/OpenEyes.UI.LightningViewer.js:191-212` (`setEventImages`) treats every HTTP 200 from `/eventImage/GetImageInfo` as a success. `EventImageController::actionGetImageInfo()` (`protected/controllers/EventImageController.php:112-114`) answers a failed render with **200** and a body of `{"error": "..."}`, so the JS `error` callback never runs. `setEventImages` then loops `response.page_count` times - zero, because the key is absent - appends no preview pages, and unconditionally runs `$currentPreview.find('.no-lightning-image').remove()`, deleting the "No preview is available at this time" paragraph the server had rendered. `showPage()` -> `showImage()` (`:177-189`) is then called on an empty set, and `$image.data('loaded')` on an empty set is `undefined`, so `$('.js-preview-image-loader').toggle(true)` leaves the spinner running with nothing left to replace it.
- **Route**: `/patient/lightningViewer/:patient_id`, endpoint `/eventImage/GetImageInfo?event_id=:id`
- **Repro**:
  1. Log in as an administrator and open a patient who has at least one event with no rendered preview image (any event whose image generation fails - on a stock sample stack, a Document event created through the UI).
  2. Click the lightning-bolt icon in the patient's sidebar to open the Lightning Viewer.
  3. Switch to the group holding that event, or accept the default group if it is already there.
  4. Click that event's icon in the timeline to lock the preview on it.
  5. Wait.
- **Expected**: the preview pane keeps saying "No preview is available at this time", or reports that the preview could not be built - the pane settles into a state the reader can act on.
- **Actual**: the paragraph disappears within a second and a spinner turns indefinitely. Nothing on screen distinguishes "still building" from "will never build", and moving to another event and back repeats it. The pane never recovers for that event.
- **Evidence**: confirmed in the container at `53b077c089` on patient 17891, event 3687000 (Document, no `event_image` rows). Authenticated request to `/eventImage/GetImageInfo?event_id=3687000` returns HTTP 200 with `{"error":"Could not resolve event image(s) for event"}`; the same endpoint for event 3686608 returns `{"page_count":1,"url":"\/eventImage\/3686608?modified=1512734400"}`. A documentation screenshot of the Lightning Viewer taken with a six-second settle after the click shows the spinner and no message.
- **Severity**: low-medium - cosmetic in isolation, but it converts an honest "no preview" into an apparent hang, and the Lightning Viewer's whole purpose is fast visual scanning, so the reader waits on something that will never arrive.
- **Status**: open, confirmed live. Found while capturing the Lightning Viewer screenshots for the documentation corpus.

## BUG-247: an RTT clock can never be started from the application, so the clock bar stays hidden on every referral that has no clock state yet (CONFIRMED code, SUSPECTED runtime)

- **Where**: `protected/modules/Referral/components/RTTClockDisplayResolver.php:61-65` (`resolveForEdit`) returns `null` whenever `$this->repository->latestFor($referral_id)` finds no state, and it does so *before* the create-mode branch at `:69-72`, so a referral with zero clock states renders no RTT section in create mode or edit mode. `ValidatesAndSavesRTT::getRTTClockDisplayData()` (`protected/modules/Referral/controllers/traits/ValidatesAndSavesRTT.php:113-119`) turns that `null` into an empty array, and the Clinical Outcome form widget (`protected/modules/OphCiExamination/views/default/form_Element_OphCiExamination_ClinicOutcome.php:99-103`) then renders nothing. The only writer reachable from a screen is `RTTClockStateService::recordForEvent()`, called from that same hidden widget's POST handler (`ValidatesAndSavesRTT::saveRTTFromData`, `:191-204`). `RTTClockStateService::recordForReferral()` (`oe-shared/app/Modules/Referral/Services/RTTClockStateService.php:79`) - the one writer that does not need an event - has no caller anywhere in `protected/` or `oe-shared/` outside its own unit test, and `ReferralService::recordReferral()` (`oe-shared/app/Modules/Referral/Services/ReferralService.php:51-82`) records no initial state. The result is a closed loop: a state can only be recorded through a widget that only appears once a state exists.
- **Route**: `/OphCiExamination/default/create?patient_id=:id` and `/OphCiExamination/default/update/:event_id`, Clinical Outcome element
- **Repro**:
  1. Log in as an administrator, open Admin > Settings, and set **Enable RTT clock bar** to on (there is no row for the setting until it is saved once; the shipped default is off).
  2. Arrange for a patient to have a referral with no clock state against it - on a stock sample database every patient qualifies, because `referral_referral` is empty, and a referral arriving from the patient-appointment feed carries no state either.
  3. Open that patient and add an **Examination** event.
  4. Scroll to the **Clinical Outcome** element and look for the RTT clock bar and its **RTT Outcome** adder.
- **Expected**: a clinician can start the clock - the adder offers the clock-state options that `referral_rtt_clock_state_option` holds (19 rows on the sample database, in Outcome and DNA groups), and recording one is what a "18-week clock started" outcome means.
- **Actual**: no RTT section is rendered at all, and there is no other screen that offers one. The feature is unreachable from the application until something outside it writes the first `referral_referral_rtt_clock_state` row; after that, the adder appears and works normally.
- **Evidence**: read at `53b077c089` in the container. The sample database's only referral (`referral_referral` id 1, `pas_identifier` `DOCS-RTT-0001`) and its first clock state (`referral_referral_rtt_clock_state` id 1, `event_id` NULL) were both written outside the interface during documentation work; the second state (id 2, `event_id` 3686621) was then recorded through the Clinical Outcome adder, which is what shows the adder works once a first state exists. `grep -rn recordForReferral protected/ oe-shared/ --include=*.php` returns the definition and one unit-test assertion, and nothing else.
- **Severity**: medium - the RTT clock is a reporting-critical feature and its entry point is missing, but a deployment fed by a real PAS may have an integration that writes the opening state, in which case the effect is limited to demonstration and test databases. Worth confirming with the RTT feature's owner whether starting a clock in-application is intended at all.
- **Status**: open, confirmed from source and from the database's provenance; not walked live, because no referral without a clock state can be created to walk it with. Found while auditing the demo-data recipes for steps a person cannot perform in the front end.

## BUG-248: Red Reflex records "No" for an eye nobody answered (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/widgets/views/RedReflex_event_edit.php:38-59` renders each eye's Yes/No pair with `CHtml::radioButton`, checked only when `(string) $element->{"{$eye_side}_has_red_reflex"}` equals `RedReflex::HAS_RED_REFLEX` ('1') or `NO_RED_REFLEX` ('0') (`models/RedReflex.php:36-37`). On a new element the attribute is null, so neither radio starts selected. `models/RedReflex.php:49-59` marks both attributes `safe` and adds only an `in` range validator, which allows an empty value, so nothing requires an answer. `widgets/views/RedReflex_event_view.php:26` then prints `$element->{"{$eye_side}_has_red_reflex"} ? "Yes" : "No"` for every eye the element shows, and `getLetter_string()` (`models/RedReflex.php:100-111`) does the same with `Y`/`N`.
- **Route**: `/OphCiExamination/default/create?patient_id=:id` (Red Reflex element), then `/OphCiExamination/default/view/:event_id`
- **Repro**:
  1. Open a patient and add an **Examination** event.
  2. Add **Red Reflex** from **Manage Elements** if it is not already showing.
  3. Leave both eyes on the element and answer the right eye only - click neither **Yes** nor **No** for the left.
  4. Save the event and read the Red Reflex element on the saved view.
  5. Generate a correspondence letter that includes the examination and read its Red Reflex line.
- **Expected**: an eye nobody answered reads as not recorded, the way it does when the eye is removed from the element.
- **Actual**: it reads **No** on the saved event and `N` in the letter - an assertion the clinician never made, and one that cannot be told apart from a deliberately recorded absent red reflex. The record errs towards the abnormal finding rather than towards silence.
- **Evidence**: read at `53b077c089` in the container. `et_ophciexamination_red_reflex` holds 0 rows on the sample database, so this is confirmed from source and not observed in data; the element has to be added by hand before it can be walked.
- **Severity**: high - a clinical finding is fabricated in both the record and the outgoing letter, and the wrong way round.
- **Status**: open, confirmed from source, not walked. Found during the anterior-segment documentation pass.

## BUG-249: the Conjunctival Hyperaemia saved event labels the grading scale with an auto-generated name (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/widgets/views/ConjunctivalHyperaemia_event_view.php:30` asks for `$element->getAttributeLabel($eye_side . '_conjunctival_hyperaemia')`, but `models/ConjunctivalHyperaemia.php:62-71` defines labels for `{side}_conjunctival_hyperaemia_grade_id` - the attribute name it asks for does not exist. Yii falls back to `CModel::generateAttributeLabel()`, which builds a label from the string it was given.
- **Route**: `/OphCiExamination/default/view/:event_id`, Conjunctival Hyperaemia element
- **Repro**:
  1. Open a patient and add an **Examination** event.
  2. Add **Conjunctival Hyperaemia** from **Manage Elements**, and note that the create form labels the dropdown **ECOS-G scale**.
  3. Grade one eye - for instance **++ Mild** - and save.
  4. Read the element on the saved event.
- **Expected**: **ECOS-G scale: ++ Mild**, the same label the form used.
- **Actual**: **Right Conjunctival Hyperaemia: ++ Mild** - the scale's name is lost at exactly the point a reader needs it to interpret the grade, and the label repeats the element heading instead.
- **Evidence**: read at `53b077c089` in the container. `et_ophciexamination_conjunctival_hyperaemia` holds 0 rows on the sample database; the six grades (Ungraded, - Normal, + Trace, ++ Mild, +++ Moderate, ++++ Severe) are in `ophciexamination_conjunctival_hyperaemia`.
- **Severity**: low - the grade itself is correct and the element heading still identifies the finding.
- **Status**: open, confirmed from source, not walked. Found during the anterior-segment documentation pass.

## BUG-250: a Conjunctival Hyperaemia comment is attributed to whoever created the element, not whoever wrote it (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/models/ConjunctivalHyperaemia.php:114-119` (`getRecordByEye`) returns `'rec_by_name' => $comments ? $this->user->getFullName() : null`, and `user` is the `created_user_id` relation (`:100`). `widgets/views/ConjunctivalHyperaemia_event_view.php:39` prints that name in the comment icon's tooltip as "User comment by ...". The element table carries only element-level `created_user_id` and `last_modified_user_id`; there is no per-comment author column, so no reading of the row can attribute an edited comment correctly.
- **Route**: `/OphCiExamination/default/update/:event_id` then `/OphCiExamination/default/view/:event_id`
- **Repro**:
  1. As one user, add an **Examination** with the **Conjunctival Hyperaemia** element, grade both eyes, leave the comments empty, and save.
  2. Log in as a second user and edit the same event.
  3. Open the comment control on the right eye, type a comment, and save.
  4. On the saved event, hover the comment icon next to that comment.
- **Expected**: the tooltip names the second user, who wrote the comment.
- **Actual**: it names the first user, who created the element.
- **Evidence**: read at `53b077c089` in the container; no rows exist on the sample database, so this is confirmed from source and not observed in data.
- **Severity**: medium - a named clinician is shown as the author of words they did not write, in a clinical record.
- **Status**: open, confirmed from source, not walked. Found during the anterior-segment documentation pass.

## BUG-251: on the KC/CXL-Specific Slit Lamp saved event, the left eye's Cornea value is gated by the right eye's (CONFIRMED code, latent)

- **Where**: `protected/modules/OphCiExamination/views/default/view_Element_OphCiExamination_Slit_Lamp.php:53-61`. The view loops over both sides, and its first three rows use `$eye_side` throughout (`:27`, `:36`, `:45`), but the Cornea row hard-codes the right side in both its label (`getAttributeLabel('right_cornea_id')`) and its guard (`if ($element->right_cornea_id)`) while printing `$element->{$eye_side.'_cornea_id'}`. So the left column prints its Cornea value only when the *right* eye has one.
- **Route**: `/OphCiExamination/default/view/:event_id`, KC/CXL-Specific Slit Lamp element
- **Repro**:
  1. Open a patient and add an **Examination** event.
  2. Add **KC/CXL-Specific Slit Lamp** from **Manage Elements**.
  3. Remove the right eye from the element and set the left **Cornea** to **Scarring**.
  4. Save and read the element on the saved event.
- **Expected**: the left column reads Cornea: Scarring.
- **Actual**: whether it appears at all depends on the right eye's stored value, which the left column never shows.
- **Evidence**: read at `53b077c089` in the container. Latent rather than routinely visible: `Element_OphCiExamination_Slit_Lamp` declares no `sidedFields()`, and the Cornea dropdown has no blank option, so a hidden side still posts and stores **Clear** - `right_cornea_id` is therefore almost always truthy and the guard almost always passes. It fails on any element whose right Cornea is genuinely empty, which import and API paths can produce.
- **Severity**: low - latent in normal use, but the wrong side is read on a clinical view and the same copy-paste would bite harder if a blank option were ever added.
- **Status**: open, confirmed from source, not walked. Found during the cornea and keratoconus documentation pass.

## BUG-252: Corneal Tomography stores a Posterior K2 that no screen can enter or show (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/models/Element_OphCiExamination_Keratometry.php` labels `right_posterior_k2_value` and `left_posterior_k2_value` as **Posterior K2** (`:194`, `:197`), accepts them in `rules()` (`:86`, `:90`) and lists `posterior_k2_value` in `sidedFields()` (`:225`), and the columns exist on `et_ophciexamination_keratometry`. Neither `views/default/form_Element_OphCiExamination_Keratometry.php` nor `views/default/view_Element_OphCiExamination_Keratometry.php` mentions the attribute - a grep for `posterior_k2` across the whole module returns only the model and its test factory.
- **Route**: `/OphCiExamination/default/create?patient_id=:id` and `/OphCiExamination/default/view/:event_id`, Corneal Tomography element
- **Repro**:
  1. Open a patient and add an **Examination** event.
  2. Add **Corneal Tomography** from **Manage Elements** (it sits under **Investigations**, not with the other cornea elements).
  3. Look for a **Posterior K2** field beside Back K1 and Back K2.
  4. Save with the other figures filled in and read the saved element.
- **Expected**: either the field is offered alongside the other six per-eye figures, or it does not exist.
- **Actual**: it exists everywhere except on screen - a labelled, mass-assignable, persisted column that no user can fill in and no user can read, but that reporting and exports can surface as though it were recorded data.
- **Evidence**: read at `53b077c089` in the container; whole-module grep for `posterior_k2` returns `models/Element_OphCiExamination_Keratometry.php` and `factories/models/Element_OphCiExamination_KeratometryFactory.php` only.
- **Severity**: low - nothing user-visible breaks; the risk is an always-empty column being read downstream as a real measurement.
- **Status**: open, confirmed from source, not walked. Found during the cornea and keratoconus documentation pass.

## BUG-253: the Risk element rejects every drug name and accepts "Yes" without one, because its validator reads the wrong variable (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/models/Element_OphCiExamination_HistoryRisk.php:81-90`. `validateName()` writes `$this->$params['type']`, which PHP parses as `($this->$params)['type']` - it looks up a property named after the whole `$params` array, not after `$params['type']`. The result is always NULL, so `NULL === '1'` never fires the "a drug name is required" branch and `NULL !== '1'` always fires the "cannot be supplied" branch. Both rules that use it (`:69-70`) are affected: **Anticoagulant Name** and **Alpha-blocker Name**. The intended expression is `$this->{$params['type']}`.
- **Route**: `/OphCiExamination/default/update/:event_id`, Risk element
- **Repro**:
  1. Open an Examination that already carries the **Risk** element (it cannot be added to a new one - the class is filtered out of the create form and **Manage Elements**).
  2. Answer **Yes** to the anticoagulant question and type a drug name.
  3. Save.
  4. Now clear the name, leave the answer on **Yes**, and save again.
- **Expected**: step 3 saves the name; step 4 is refused, because the rule at `:83-85` means to require a name whenever the answer is yes.
- **Actual**: step 3 is refused with "A drug name cannot be supplied without selecting yes." whatever the answer is, so neither name column can ever hold a value; step 4 saves cleanly. The validation is inverted in one direction and dead in the other.
- **Evidence**: read at `53b077c089` in the container, PHP 8.4.23. `php -r` on an isolated reconstruction of the expression returns NULL. `et_ophciexamination_examinationrisk` holds 0 rows on the sample database, which is consistent with an element nobody can fill in.
- **Severity**: low - the element is deprecated and unreachable from a new event, so the damage is limited to installations that still hold old ones.
- **Status**: open, confirmed from source, not walked. Found during the examination history documentation pass.

## BUG-254: Medication History never enforces the systemic-medication confirmation it calculates (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/models/HistoryMedications.php:100-122` (`afterValidate`). The loop at `:102-114` works out both `$no_systemic_medications` and `$no_ophthalmic_medications`, but `:116` then hard-codes `$no_medications = 'no_ophthalmic_medications'`, and the check at `:117-119` uses only that. The systemic flag is computed and discarded, so **No systemic medications** is never required.
- **Route**: `/OphCiExamination/default/create?patient_id=:id`, Medication History element
- **Repro**:
  1. Open a patient with no medication history and add an **Examination** event.
  2. Leave the Medication History element empty - record no medications and tick neither confirmation box.
  3. Save.
- **Expected**: by symmetry with the eye rule, the event is refused until the systemic confirmation is ticked too.
- **Actual**: only "Please confirm the patient is not taking any eye medications" is raised. Tick that one box and the event saves with the systemic side neither recorded nor confirmed, which is indistinguishable in the record from a patient nobody asked.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: medium - a mandatory clinical check silently is not one, and the gap is invisible on the saved event.
- **Status**: open, confirmed from source, not walked. Found during the examination history documentation pass.

## BUG-255: a stray quote and angle bracket are printed at the end of the Medication History not-at-tip warning (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/widgets/views/HistoryMedications_edit_nottip.php:32`. The paragraph ends `<?= $end ?>">`, and `$end` is already the last of the sentence (`:27`), so the two characters after it are printed as text.
- **Route**: `/OphCiExamination/default/update/:event_id`, Medication History element, on an event that is not the patient's most recent
- **Repro**:
  1. Find a patient with more than one Examination event and open one that is not the latest.
  2. Edit it and look at the warning above the Medication History element.
- **Expected**: the warning ends "...please go to the latest Examination, or create a new Examination."
- **Actual**: it ends `...create a new Examination">`.
- **Evidence**: read at `53b077c089` in the container. Whether the warning renders at all depends on `params['show_notattip_warning'] === 'on'`, which is not set in `protected/config/*.php` or `protected/config/local/*.php` on this deployment, so the defect is invisible here and confirmed from source only.
- **Severity**: low - cosmetic, and only on deployments that switch the warning on.
- **Status**: open, confirmed from source, not walked. Found during the examination history documentation pass.

## BUG-256: the Comorbidities lookup has an administration screen with no way in (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/controllers/AdminController.php:1095` defines `actionManageComorbidities()`, which renders a `genericAdmin` screen headed "Edit Comorbities" (the heading is misspelled). Grepping `protected/` and `oe-shared/` for `ManageComorbidities` returns the definition and nothing else - no module config entry, no admin menu row, no link in any view - so the only way to reach it is to type the URL.
- **Route**: `/OphCiExamination/admin/manageComorbidities`
- **Repro**:
  1. Log in as an administrator and open **Admin**.
  2. Look through the Examination administration sections for a Comorbidities list.
  3. Type the route above into the address bar.
- **Expected**: the list appears in the admin menus like the other Examination lookups.
- **Actual**: it appears nowhere; step 3 opens it perfectly well.
- **Evidence**: read at `53b077c089` in the container. The lookup itself holds 15 active entries with no subspecialty restrictions.
- **Severity**: low - the Comorbidities element is filtered out of new Examinations anyway, so the list is not one an administrator has reason to reach.
- **Status**: open, confirmed from source, not walked. Found during the examination history documentation pass.

## BUG-257: the CVI status element cannot be shown for a patient whose CVI record leaves the blindness question unanswered (CONFIRMED code + db)

- **Where**: `protected/modules/OphCiExamination/views/default/form_Element_OphCiExamination_CVI_Status.php:4` does `PatientOphInfoCviStatus::model()->findByAttributes(array('name' => $latest_cvi_status))->id`. `$latest_cvi_status` comes from `Patient::getCviSummary()` (`protected/models/Patient.php:1736`), which for a patient whose most recent CVI record is a Clinical Information element returns `Element_OphCoCvi_ClinicalInfo::getDisplayConsideredBlind()` (`:390`), and that returns `static::$NULL_BOOLEAN` = `'Not recorded'` (`:65`) whenever `is_considered_blind` is null. Migration `protected/modules/OphCiExamination/migrations/m260728_130217_cvi_status_remove_not_recorded.php` deleted the row named "Not recorded" from `patient_oph_info_cvi_status` and moved existing records to "Unknown", but left the constant behind, so the lookup now finds nothing and the property is read on null.
- **Route**: `/patientEvent/create?patient_id=:id&event_type_id=27&...`, Examination, CVI status element
- **Repro**:
  1. Find a patient whose latest CVI record is an OphCoCvi Clinical Information element with the blindness question unanswered (`et_ophcocvi_clinicinfo.is_considered_blind IS NULL`).
  2. Start a new Examination for that patient.
  3. Open **Manage Elements** and add **CVI status**.
- **Expected**: the element opens with no status pre-selected.
- **Actual**: reading `->id` on the missing lookup raises a PHP warning, and Yii 1's error handler ends the request on any level in `error_reporting`, which on this deployment is 30719 and includes `E_WARNING`. The element never renders.
- **Evidence**: read at `53b077c089` in the container; `patient_oph_info_cvi_status` holds seven rows and none is named "Not recorded"; the sample database's only `et_ophcocvi_clinicinfo` row has `is_considered_blind` null, so the case is reachable here. The same stale string is still printed (harmlessly) by `widgets/views/PatientSummaryPopup.php:50`, `controllers/WorklistController.php:1250` and `views/patient/landing_page.php:185,190,195`.
- **Severity**: high - a clinician cannot add the element at all for the affected patients, and the trigger is a record left deliberately incomplete rather than anything unusual.
- **Status**: open, confirmed from source and database, not walked. Found during the examination vision documentation pass.

## BUG-258: visual acuity conversion tooltips never mark a value as approximate (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/models/Element_OphCiExamination_VisualAcuity.php:331-341`. The `approx` flag is set inside `if ($tt_val->base_value >= $uv->base_value)` and is guarded by `if ($tt_val->base_value < $uv->base_value)`, which cannot be true inside that branch.
- **Route**: `/OphCiExamination/default/update/:event_id`, Visual Acuity element
- **Repro**:
  1. Edit an Examination and hover a reading in the Visual Acuity value list.
  2. Read the conversions offered for the other scales.
- **Expected**: conversions that are the nearest step rather than an exact match are marked as approximate.
- **Actual**: every conversion is presented as exact.
- **Severity**: low - the figures shown are the nearest steps either way; only the qualifier is missing.
- **Status**: open, confirmed from source, not walked. Found during the examination vision documentation pass.

## BUG-259: reopening an Examination re-enters visual acuity readings at another scale's steps (CONFIRMED code + schema)

- **Where**: the element's scale is not stored - `unit_id` is a plain public property (`models/Element_OphCiExamination_VisualAcuity.php:106`) and `et_ophciexamination_visualacuity` has no such column, only `archive_unit_id`. `getUnit()` (`:223`) re-derives one scale for the whole element on every render, and the form then pushes every reading of both eyes through it: `views/default/form_Element_OphCiExamination_VisualAcuity.php:148` calls `$reading->loadClosest($element->unit->id)` inside the per-eye loop, while each reading still posts its own `id` and `unit_id`. `form_Element_OphCiExamination_NearVisualAcuity.php:82` does the same.
- **Route**: `/OphCiExamination/default/update/:event_id`, Visual Acuity element
- **Repro**:
  1. On an Examination in complex mode, record a right-eye reading in one scale and a left-eye reading in a different scale, and save.
  2. Reopen the same event for editing.
  3. Save again without changing anything.
- **Expected**: both readings come back unchanged.
- **Actual**: the readings belonging to the scale that was not derived are re-entered at the nearest step of the derived scale, so a value can change without anyone touching it.
- **Evidence**: read at `53b077c089` in the container. Confirmed from source and the element table's columns; the size of the shift depends on the two scales and has not been measured live.
- **Severity**: medium - a recorded clinical measurement can change on a save that was meant to change nothing.
- **Status**: open, confirmed from source, not walked. Found during the examination vision documentation pass.

## BUG-260: deactivated colour vision methods and values are still offered on the element (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/widgets/ColourVision.php:62` and `:76` build both lists with a plain `findAll()`. Every comparable lookup in the module goes through `HasRelationOptions` or an explicit `active()`/`activeOrPk()` scope; these two do not, and the models' `defaultScope()` only sets an order. Both lists have administration screens - `controllers/traits/AdminForColourVision.php:25` ("Colour Vision Methods") and `:33` ("Colour Vision Method Values") - and both screens carry the usual **Active** tick box.
- **Route**: `/OphCiExamination/admin/colourVisionMethods`, then `/OphCiExamination/default/update/:event_id`
- **Repro**:
  1. As an administrator, open **Colour Vision Methods** and untick **Active** on a method, then save.
  2. Edit an Examination carrying the Colour Vision element and open the green plus picker.
- **Expected**: the deactivated method is no longer offered.
- **Actual**: it is still listed, and can still be recorded.
- **Evidence**: read at `53b077c089` in the container. All 11 methods and all 121 values are active in the sample database, so the defect is latent here and confirmed from source only.
- **Severity**: medium - the Active flag is the only tool an administrator has for retiring a test, and on this element it does nothing.
- **Status**: open, confirmed from source, not walked. Found during the examination vision documentation pass.

## BUG-261: the near visual acuity scale list offers a scale meant for complex recording only (CONFIRMED code + db)

- **Where**: `protected/modules/OphCiExamination/views/default/form_Element_OphCiExamination_NearVisualAcuity.php:50` filters the scale list on `is_near = 1` alone. The distance element filters on `is_va = 1 AND complex_only = 0` (`form_Element_OphCiExamination_VisualAcuity.php:87-88`), and the dropdown in question is the one marked `data-record-mode = RECORD_MODE_SIMPLE`.
- **Route**: `/OphCiExamination/default/update/:event_id`, Near Visual Acuity element
- **Repro**:
  1. Edit an Examination carrying Near Visual Acuity in simple mode.
  2. Open the **VA Scale** dropdown.
- **Expected**: the same exclusion the distance element applies - scales flagged complex-only are not offered.
- **Actual**: **4 card logMAR** is offered, which is `ophciexamination_visual_acuity_unit` id 12 with `is_near = 1` and `complex_only = 1`.
- **Evidence**: read at `53b077c089` in the container; the flags are as stated in the sample database.
- **Severity**: low - the scale works, it is simply offered where the same rule elsewhere hides it.
- **Status**: open, confirmed from source and database, not walked. Found during the examination vision documentation pass.

## BUG-262: the Retinoscopy working distance is labelled one way on the form and another on the saved event (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/models/Retinoscopy.php:119,126` map `right_working_distance_id` and `left_working_distance_id` to `Working`, which is what `widgets/views/Retinoscopy_event_view.php` prints. The edit form asks for a label on the relation rather than the column - `widgets/views/Retinoscopy_event_edit.php:77` calls `getAttributeLabel("{$eye_side}_working_distance")` - and no label is defined for that name, so Yii generates one from the attribute and the form and the picker column both read "Right Working Distance" / "Left Working Distance".
- **Route**: `/OphCiExamination/default/update/:event_id`, Retinoscopy element
- **Repro**:
  1. Edit an Examination carrying Retinoscopy and note the row label above the working distance.
  2. Save and look at the same row on the saved event.
- **Expected**: one name for one field.
- **Actual**: "Right Working Distance" on the form, "Working" on the event.
- **Severity**: low - cosmetic, but it is the kind of mismatch that makes a written instruction wrong on one of the two screens.
- **Status**: open, confirmed from source, not walked. Found during the examination vision documentation pass.

## BUG-263: a Contrast Sensitivity element with a comment and no results loses the comment in letters (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/views/default/letter/ContrastSensitivity.php:23` wraps the entire output in `if (count($element->results) > 0)`, and the comment block at `:48-56` sits inside that branch. The else branch prints the two words "No results" and nothing more.
- **Route**: `/OphCoCorrespondence/...` letter generation from an Examination carrying Contrast Sensitivity
- **Repro**:
  1. Add Contrast Sensitivity to an Examination, leave the results empty, type a comment, and save. The element accepts this - a comment on its own satisfies it.
  2. Create a Correspondence letter for the patient that includes the Examination.
- **Expected**: the comment appears in the letter.
- **Actual**: the letter carries "No results" and the comment is dropped.
- **Severity**: medium - the recorded content of a valid element does not reach the letter, and nothing on screen says so.
- **Status**: open, confirmed from source, not walked. Found during the examination vision documentation pass.

## BUG-264: Correction Given repeats the side in its error message, and a value typed without the picker cannot be saved (CONFIRMED code + schema)

- **Where**: `protected/modules/OphCiExamination/models/CorrectionGiven.php` defines no `attributeLabels()`, so `getAttributeLabel('right_as_found')` falls back to Yii's generated "Right As Found". `BaseEventTypeElement::requiredIfSide()` (`protected/models/BaseEventTypeElement.php:359-371`) builds its message as `ucfirst($side) . ' {attribute} cannot be blank.'` and substitutes that label, producing "Right Right As Found cannot be blank." The message is reachable because `right_as_found` has no database default (`et_ophciexamination_correction_given`, nullable, default null), `sidedDefaults()` returns `[]` (`:79-82`), and the edit form's hidden field posts whatever the model holds - `widgets/views/CorrectionGiven_event_edit.php:40-42` - which is an empty string until the picker is used. `requiredIfSide` treats an empty string as blank.
- **Route**: `/OphCiExamination/default/update/:event_id`, Correction Given element
- **Repro**:
  1. Add Correction Given to an Examination and click to add a side.
  2. Type a refraction straight into the box without opening the green plus picker.
  3. Save.
- **Expected**: the element saves, or is refused with a message naming the field once.
- **Actual**: the save is refused with "Right Right As Found cannot be blank." Nothing on screen indicates that the picker is the only way to set the missing value.
- **Evidence**: read at `53b077c089` in the container. The doubled wording also affects `right_eyedraw` and `left_eyedraw` on Retinoscopy, which has no labels for them either, though those fields are always filled by the drawing widget in practice.
- **Severity**: medium - a plausible way of using the element cannot save, and the message does not say why.
- **Status**: open, confirmed from source and schema, not walked. Found during the examination vision documentation pass.

## BUG-265: opening a saved Operation Checklist with Edit and saving it advances the workflow a stage (CONFIRMED code)

- **Where**: `protected/modules/OphTrOperationchecklists/views/default/update.php:29` has the **Save draft** button commented out and `:34` the `isDraft` hidden input commented out, so `DefaultController.php:214` always reads `$this->isDraft = null`. With no `step_id` in the request - which is the case for the ordinary Edit action, as opposed to the next-stage link - `:219` sets `$this->step = $this->getCurrentStep()->getNextStep()`, and `afterUpdateElements()` (`:1297-1313`) writes that step to `ophtroperationchecklists_event_element_set_assignment` and rewrites `event.info`. `saveEvent()` (`:1548-1558`) additionally sets `draft = '0'` for the same reason.
- **Route**: `/OphTrOperationChecklists/default/update/:event_id`
- **Repro**:
  1. Complete the Admission stage of an Operation Checklist and press **Save**.
  2. Open the saved event and press **Edit**.
  3. Press **Save** without changing anything.
- **Expected**: the event stays at the stage it was at.
- **Actual**: it advances to the next stage, and an event that was a draft stops being one.
- **Evidence**: read at `53b077c089` in the container. Not reproducible on this deployment because the event cannot be created at all (see BUG-090 and BUG-178).
- **Severity**: high - correcting a typo silently signs the patient through to the next stage of a safety checklist.
- **Status**: open, confirmed from source, not walked. Found during the operation checklists documentation pass.

## BUG-266: the Operation Checklist Edit screen has no working state once the checklist is complete (CONFIRMED code)

- **Where**: `protected/modules/OphTrOperationchecklists/controllers/DefaultController.php:1218,1229,1242` all do `$current_step = $this->getNextStep(); foreach ($current_step->items as $item)`. The controller's `getNextStep()` (`:1484-1488`) delegates to `OphTrOperationchecklists_ElementSet::getNextStep()` (`models/OphTrOperationchecklists_ElementSet.php:217-226`), which returns null once the current set is the last position.
- **Route**: `/OphTrOperationChecklists/default/update/:event_id` on an event at the Discharge stage
- **Repro**:
  1. Complete all five stages of an Operation Checklist.
  2. Open the event.
  3. Press **Edit**.
- **Expected**: an editable screen, or no Edit action at all.
- **Actual**: the property is read on null and the class-name list comes back empty, so nothing on the screen is editable. Whether the page renders that way or ends on the warning depends on the error handler; `error_reporting` on this deployment is 30719 and includes `E_WARNING`, which Yii 1 turns into an error page.
- **Evidence**: read at `53b077c089` in the container. Not reproducible here because of BUG-090 and BUG-178; the exact surfacing is therefore unconfirmed.
- **Severity**: high - the last stage of the checklist cannot be corrected once it is signed off.
- **Status**: open, confirmed from source, not walked. Found during the operation checklists documentation pass.

## BUG-267: the recorded EWS is hidden unless a blood glucose was also entered (CONFIRMED code)

- **Where**: `protected/modules/OphTrOperationchecklists/views/default/view_OphTrOperationchecklists_Observations.php:64` prints `(!empty($element->blood_glucose)) ? $element->ews : ''` under the label taken from `getAttributeLabel('ews')` at `:61`. The neighbouring cells all test the field they print.
- **Route**: `/OphTrOperationChecklists/default/view/:event_id`, Admission stage, Observations
- **Repro**:
  1. Create an Operation Checklist and reach the Admission stage.
  2. In Observations enter an EWS and leave Blood Glucose blank.
  3. Save and view the event.
- **Expected**: the EWS appears next to its label.
- **Actual**: the cell is empty; the recorded early warning score is invisible on the saved event.
- **Evidence**: read at `53b077c089` in the container. Not reproducible here because of BUG-090 and BUG-178.
- **Severity**: medium - a recorded observation disappears from the record, and nothing indicates it was ever entered.
- **Status**: open, confirmed from source, not walked. Found during the operation checklists documentation pass.

## BUG-268: a typed Operation Checklist note is discarded whenever the form comes back (CONFIRMED code)

- **Where**: `protected/modules/OphTrOperationchecklists/views/default/form_Element_OphTrOperationchecklists_Note.php:29` fills the field from `$element->notes->notes ?? ''`, but `notes` is a `HAS_MANY` relation (`models/Element_OphTrOperationchecklists_Note.php:70`) and `DefaultController.php:403-411` assigns `$element->notes = [$notes]`. A property read on an array yields nothing, the `??` swallows it, and the field renders empty every time.
- **Route**: `/OphTrOperationChecklists/default/update/:event_id`, Notes element
- **Repro**:
  1. Open an Operation Checklist stage and type a note in the **Comments** field.
  2. Leave a compulsory Admission question unanswered.
  3. Press **Save**.
- **Expected**: the validation message appears and the typed note is still there.
- **Actual**: the note is gone and has to be typed again.
- **Evidence**: read at `53b077c089` in the container. Not reproducible here because of BUG-090 and BUG-178.
- **Severity**: medium - typed clinical text is lost on the one path where a form redisplay is expected.
- **Status**: open, confirmed from source, not walked. Found during the operation checklists documentation pass.

## BUG-269: the COVID-19 swab result is a question with no answers, filled by matching text anywhere on the page (CONFIRMED code + db)

- **Where**: `ophtroperationchecklists_questions` id 13, "COVID-19 swab result", is typed `RADIO` with `requires_answer = 1` and has no rows at all in `ophtroperationchecklists_question_answer_assignment`. Its value is written in by jQuery instead: `views/default/form_Element_OphTrOperationchecklists_Admission.php:72,80` and `views/default/view_Element_OphTrOperationchecklists_Admission.php:43,50` select `$("td:contains(COVID-19)")`, which matches any cell on the page whose text contains those characters.
- **Route**: `/OphTrOperationChecklists/default/update/:event_id`, Admission stage
- **Repro**:
  1. Open the Admission stage of an Operation Checklist.
  2. Look at the COVID-19 swab result row.
- **Expected**: either a question wired to the lab result, or a display-only row that is not presented as an unanswered radio question.
- **Actual**: a required radio question with nothing to choose, whose displayed value depends on a substring match against the rendered page.
- **Evidence**: read at `53b077c089` in the container; question and assignment counts queried directly.
- **Severity**: medium - the row is unanswerable by design and its content is decided by page text rather than by data.
- **Status**: open, confirmed from source and database, not walked. Found during the operation checklists documentation pass.

## BUG-270: the Documentation stage's Fasted question can never be answered (CONFIRMED code + db)

- **Where**: `ophtroperationchecklists_questions` id 21, "Fasted", is typed `RADIO` with `requires_answer = 0` and has no answer assignments. `views/default/checklist_edit.php:53-67` loops over that empty list, so the response cell renders with nothing in it, and because `requires_answer` is 0 the saved-view templates print nothing rather than the usual **Unknown**.
- **Route**: `/OphTrOperationChecklists/default/update/:event_id`, Documentation element
- **Repro**:
  1. Reach the Ward Practitioner stage of an Operation Checklist.
  2. Look at the **Fasted** row in the Documentation element.
- **Expected**: the row offers the answers the other questions offer.
- **Actual**: the row is a label with an empty response cell, on both the form and the saved event.
- **Evidence**: read at `53b077c089` in the container; question and assignment counts queried directly.
- **Severity**: medium - a fasting check that presents as a question but cannot record anything.
- **Status**: open, confirmed from source and database, not walked. Found during the operation checklists documentation pass.

## BUG-271: the Discharge stage's "Patient Carer Understands:" row is a question with no type (CONFIRMED code + db)

- **Where**: `ophtroperationchecklists_questions` id 50 has `type` NULL while carrying three answer assignments. `views/default/checklist_edit.php:53-157` branches on the type and matches nothing, so the row renders as a label with an empty response cell and a comment box beside it. It reads as a section heading, but the tables have a `SECTION` idiom it does not use.
- **Route**: `/OphTrOperationChecklists/default/update/:event_id`, Discharge element
- **Repro**:
  1. Reach the Discharge stage of an Operation Checklist.
  2. Look at the **Patient Carer Understands:** row.
- **Expected**: either a heading, or a question with its three answers offered.
- **Actual**: a heading that nevertheless has a comment box, and three configured answers that can never be picked.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: low - the row works as a heading, which appears to be the intent.
- **Status**: open, confirmed from source and database, not walked. Found during the operation checklists documentation pass.

## BUG-272: unusable rows left in the Operation Checklist question tables (CONFIRMED db)

- **Where**: `ophtroperationchecklists_questions` id 46, "Return from Theatre Time", is typed `TIME` yet carries three Yes/No/N/A rows in `ophtroperationchecklists_question_answer_assignment`, which no code path can reach. `ophtroperationchecklists_answers` ids 12 ("Removed") and 13 ("Taped") are assigned to no question at all.
- **Route**: none - the rows are not reachable from any screen
- **Repro**:
  1. Query the two tables as above.
- **Expected**: answers exist for the questions that use them.
- **Actual**: three inert assignments and two orphaned answers.
- **Evidence**: queried directly at `53b077c089`.
- **Severity**: low - no user-visible effect; recorded because these tables are hand-seeded and the leftovers make the configuration harder to read.
- **Status**: open, confirmed from database, not walked. Found during the operation checklists documentation pass.

## BUG-273: Operation Checklist notes are listed newest-first on the event and oldest-first on the form (CONFIRMED code)

- **Where**: `protected/modules/OphTrOperationchecklists/views/default/form_Element_OphTrOperationchecklists_Note.php:23` fetches the notes with a bare `findAll()`, which returns them in insertion order. The saved view goes through the relation, which is ordered `notes.created_date desc` (`models/Element_OphTrOperationchecklists_Note.php:70`).
- **Route**: `/OphTrOperationChecklists/default/update/:event_id` and `/OphTrOperationChecklists/default/view/:event_id`, Notes element
- **Repro**:
  1. Add three notes to an Operation Checklist across different stages.
  2. Compare the list on the Edit screen with the list on the saved event.
- **Expected**: one order.
- **Actual**: opposite orders on the two screens.
- **Evidence**: read at `53b077c089` in the container. Not reproducible here because of BUG-090 and BUG-178.
- **Severity**: low - the same notes are shown either way, but "the last note" means different things on the two screens.
- **Status**: open, confirmed from source, not walked. Found during the operation checklists documentation pass.

## BUG-274: the ward-to-theatre checklist table emits more cells than it has columns (CONFIRMED code)

- **Where**: `protected/modules/OphTrOperationchecklists/views/default/checklist_view_ward_to_theatre.php:98-99` appends two unconditional empty `<td>` elements after a loop that already emits one cell per completed stage, against a four-column `colgroup` and header.
- **Route**: `/OphTrOperationChecklists/default/view/:event_id`
- **Repro**:
  1. Complete the Ward Practitioner stage, then the Reception Practitioner stage.
  2. View the event.
- **Expected**: four cells per row.
- **Actual**: five cells at two stages and six at three, so the columns no longer line up with their headings.
- **Evidence**: read at `53b077c089` in the container. Not reproducible here because of BUG-090 and BUG-178.
- **Severity**: low - a layout defect on a comparison table whose whole purpose is that the columns line up.
- **Status**: open, confirmed from source, not walked. Found during the operation checklists documentation pass.

## BUG-275: Strabismus Management Treatment Options - filtering by column alone lists every treatment's options and saving detaches all of them (CONFIRMED code/db)

- **Where**: `protected/controllers/BaseAdminController.php:262-266` assigns every filter field's current value onto every row being saved, unconditionally (no filter in `OphCiExamination/controllers/traits/AdminForStrabismusManagement.php:75-87` sets `do_not_set_value_from_filter`). `:186-188` only marks the screen not-ready when a filter value is `null` **and** the column is `NOT NULL`; `ophciexamination_strabismusmanagement_treatmentoption.treatment_id` is nullable, so an empty treatment filter leaves the screen fully editable. `CDbColumnSchema::typecast()` then turns the posted `''` into NULL on save. There is no foreign key from `treatment_id` to the treatment table (only the two `user` audit FKs), so nothing at the DB layer refuses it.
- **Route**: `/OphCiExamination/admin/StrabismusManagementTreatmentOptions`
- **Repro**:
  1. Go to Admin > Examination > Strabismus Management Treatments and click **Options** on any treatment.
  2. The list is blank until a column is chosen, so pick **Column 1** in the second dropdown. The list now shows that treatment's column 1 options.
  3. Set the **Treatment** dropdown back to **-- Select --**. The list reloads (`protected/widgets/js/GenericAdmin.js:19` submits the filter form on change) and now shows the column 1 options of *every* treatment.
  4. Press **Save** without changing anything.
- **Expected**: either the screen refuses to list rows until a treatment is chosen, as it does for the column, or an unchanged save leaves the rows alone.
- **Actual**: every listed row is saved with `treatment_id` NULL. Every column 1 option in the installation is detached from its treatment at once and disappears from the adder; the rows survive but belong to nothing, and only the version table records what they were attached to. The flash message reads "List updated."
- **Evidence**: read at `53b077c089` in the container; nullability, the absent FK and the current row set confirmed against the sample database. Not executed - the repro is a destructive write.
- **Severity**: high - one save on a screen reached by two clicks silently destroys the whole treatment-to-option mapping, with no warning and no FK to stop it. Same root as BUG-105/BUG-106, but the blast radius here is every row on the screen rather than one.
- **Status**: open, confirmed from source and schema, not walked. Found during the strabismus admin documentation pass.

## BUG-276: the "Reason Required" flag on Strabismus Management Treatments does nothing (CONFIRMED code)

- **Where**: the admin screen offers the tick box (`OphCiExamination/controllers/traits/AdminForStrabismusManagement.php:33-36`), the column exists (`migrations/m200922_103732_create_strabismus_management.php:45`), the model saves it (`models/StrabismusManagement_Treatment.php:46,48`) and the widget hands it to the browser (`widgets/StrabismusManagement.php:47`). No JavaScript ever reads it: `reason_required` appears nowhere in `widgets/js/StrabismusManagement.js` or any other `.js` in the module.
- **Route**: `/OphCiExamination/admin/StrabismusManagementTreatments`
- **Repro**:
  1. Tick **Reason Required** against a treatment and save.
  2. Open an Examination with the Strabismus Management element and add an entry for that treatment.
  3. Leave **Reason** unselected and click **Click to add**, then save the event.
- **Expected**: a reason is demanded, either in the adder or on save.
- **Actual**: the entry is added and the event saves with no reason.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: medium - an administrator can set a data-quality rule that is silently never applied, so the record looks governed when it is not.
- **Status**: open, confirmed from source, not walked. Found during the strabismus admin documentation pass.

## BUG-277: Strabismus Management Reasons cannot be reordered (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/widgets/StrabismusManagement.php:75` builds the reason list with a bare `StrabismusManagement_TreatmentReason::model()->findAll()`, and `models/StrabismusManagement_TreatmentReason.php` has no `defaultScope()`, so `display_order` is never applied - the adder gets the rows in primary-key order. Both sibling lookups do order themselves (`models/StrabismusManagement_Treatment.php:37-40`, `models/StrabismusManagement_TreatmentOption.php:34-37`), which is why the same drag on the neighbouring screens does work.
- **Route**: `/OphCiExamination/admin/StrabismusManagementReasons`
- **Repro**:
  1. Drag a reason to the top of the list and save. The admin list keeps the new order.
  2. Open an Examination with the Strabismus Management element and open the entry adder.
- **Expected**: the Reason column follows the administered order.
- **Actual**: it follows the order the reasons were created in.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: low - the reasons are all offered, just not in the intended order, and the admin screen gives no hint that the drag was pointless.
- **Status**: open, confirmed from source, not walked. Found during the strabismus admin documentation pass.

## BUG-278: adder dialogs report a missing mandatory selection as "null must have an option selected." (CONFIRMED code)

- **Where**: `protected/assets/js/OpenEyes.UI.AdderDialog.js:1300` builds the alert as `item.options.header + " must have an option selected."`, and `protected/assets/js/OpenEyes.UI.AdderDialog.ItemSet.js:25` defaults `header` to `null`. Any item set declared `mandatory: true` without a `header` therefore names itself "null". The Strabismus Management treatment column is exactly that (`OphCiExamination/widgets/js/StrabismusManagement.js:40-43`). The same defect shape applies to the number-validation messages at `:1308`, `:1322` and `:1331`.
- **Route**: `/OphCiExamination/default/create?...` - Strabismus Management element
- **Repro**:
  1. Open an Examination with the Strabismus Management element.
  2. Click the green plus to open the entry adder.
  3. Select nothing and click **Click to add**.
- **Expected**: a message naming the column, for example "Treatment must have an option selected."
- **Actual**: "null must have an option selected."
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: low - the dialog does refuse the entry, but the message points at nothing and reads as an application error.
- **Status**: open, confirmed from source, not walked. Found during the strabismus admin documentation pass.

## BUG-279: clearing a row's Name on any admin list deletes the row instead of refusing the save (CONFIRMED code)

- **Where**: `protected/controllers/BaseAdminController.php:231` processes a posted row only when its label field is non-empty (`if (!empty($_POST[$options['label_field']][$i]) || $_POST[$options['label_field']][$i] === "0")`). A row whose Name was cleared is skipped entirely, so it never joins `$items`, and the delete sweep at `:288-296` - `addNotInCondition('id', <ids of processed rows>)` plus the current filters - then finds and deletes it. The model's own `required` rule on `name` never runs, because the model is never given the value to validate.
- **Route**: every generic admin list, for example `/OphCiExamination/admin/StrabismusManagementReasons`
- **Repro**:
  1. Open any admin lookup list.
  2. Clear the text in one row's **Name** box, leaving the row on screen.
  3. Press **Save**.
- **Expected**: "Name cannot be blank", with the row still there.
- **Actual**: "List updated." and the row is gone. Where the row is referenced by a foreign key the request instead ends in a raw 500 (BUG-108's shape), because the delete loop at `:301` handles only a `false` return, not the exception.
- **Evidence**: read at `53b077c089` in the container. Not executed - the repro destroys a row.
- **Severity**: medium - deletion by typo, on screens whose Active column exists precisely so that retiring a value does not have to mean deleting it. The trash control on the same row asks for confirmation; this path does not.
- **Status**: open, confirmed from source, not walked. Found during the strabismus admin documentation pass.

## BUG-280: a new row on an admin list is always saved Active, whatever the Active box says (CONFIRMED code)

- **Where**: `protected/controllers/BaseAdminController.php:239`: `$item->active = (isset($_POST['active'][$i]) || $item->isNewRecord) ? 1 : 0;`. The `isNewRecord` arm forces 1 for every row being created. The Active box is rendered on new rows like any other (`protected/widgets/views/_generic_admin_row.php:81-82`), so it can be unticked and its value is simply discarded.
- **Route**: every generic admin list with an Active column
- **Repro**:
  1. Open any admin lookup list and click **Add**.
  2. Type a name, untick **Active**, and press **Save**.
- **Expected**: the value is created inactive, so it can be prepared before clinicians see it.
- **Actual**: it is created active and is immediately offered on the clinical form. A second save, with the box unticked again, is needed to deactivate it.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: low - one extra save fixes it, but there is no way to add a value without it being live for that moment, and the ignored tick box gives no clue.
- **Status**: open, confirmed from source, not walked. Found during the strabismus admin documentation pass.

## BUG-281: eleven Examination lookups accept names their columns cannot store (CONFIRMED code/db)

- **Where**: eight models validate `name` with `['name', 'length', 'max' => 63, 'min' => 2]` against a `varchar(31)` column - `OphCiExamination/models/` `StereoAcuity_Method.php:60`, `CoverAndPrismCover_Distance.php:60`, `CoverAndPrismCover_HorizontalPrism.php:60`, `CoverAndPrismCover_VerticalPrism.php:60`, `NinePositions_HorizontalEDeviation.php:64`, `NinePositions_HorizontalXDeviation.php:64`, `PrismReflex_PrismBase.php:60`, `PrismReflex_PrismDioptre.php:60`. Three more declare no length rule at all against `varchar(63)` - `StrabismusManagement_Treatment.php:46-48`, `StrabismusManagement_TreatmentOption.php:43`, `StrabismusManagement_TreatmentReason.php:28-29`. `@@sql_mode` includes `STRICT_TRANS_TABLES`, so the DB refuses the over-length value rather than truncating it, and the generic admin save has no try/catch around `$item->save()`.
- **Route**: the matching admin list, for example `/OphCiExamination/admin/DioptrePrismPrismBase` or `/OphCiExamination/admin/StrabismusManagementReasons`
- **Repro**:
  1. Open one of the listed admin lists.
  2. Add a row whose name is longer than the column allows - 40 characters for the `varchar(31)` group, 70 for the strabismus group.
  3. Press **Save**.
- **Expected**: an inline "Name is too long" against that row.
- **Actual**: validation passes, the insert raises an uncaught `CDbException` inside the save transaction, and the screen is replaced by a raw framework error page. Nothing on the page is saved, including edits to other rows.
- **Evidence**: rules read at `53b077c089` in the container; every column type and `sql_mode` confirmed against the sample database. Not executed - the repro is a write.
- **Severity**: low - the over-length name is correctly refused, just not gracefully, and the rest of the page's edits are lost with it. Same class as BUG-122.
- **Status**: open, confirmed from source and schema, not walked. Found during the strabismus and orthoptic admin documentation passes.

## BUG-282: deleting a refraction type blanks the recorded type on every saved reading that used it (CONFIRMED code/db)

- **Where**: `ophciexamination_refraction_reading.type_id` carries no foreign key to `ophciexamination_refraction_type` - the only FKs on the table are the two `user` audit columns (confirmed against `information_schema`). Every sibling lookup on the Examination admin screens does have one. `OphCiExamination_Refraction_Reading::getType_display()` (`protected/modules/OphCiExamination/models/OphCiExamination_Refraction_Reading.php:140-143`) returns `$this->type ? (string) $this->type : $this->type_other`, and all 896 refraction readings in the sample database have an empty `type_other`.
- **Route**: `/OphCiExamination/admin/RefractionType`
- **Repro**:
  1. Go to Admin > Examination > Refraction Types.
  2. Untick **Active** against a type in use and press **Save** - the delete control appears.
  3. Press delete on that row, then **Save**.
  4. Open any saved Examination whose Refraction element used that type.
- **Expected**: the delete is refused because the type is in use, as it is on every neighbouring lookup.
- **Actual**: the delete succeeds and the type column of every affected reading is blank from then on. The number recorded is still there; what instrument or clinician it came from is not.
- **Evidence**: read at `53b077c089` in the container; the absent FK and the 896 readings with blank `type_other` confirmed against the sample database. Not executed - the repro is destructive.
- **Severity**: medium-high - silent, irreversible loss of provenance across the whole installation's refraction history, from a screen whose neighbours all refuse the same action.
- **Status**: open, confirmed from source and schema, not walked. Found during the vision and refraction admin documentation pass.

## BUG-283: adder dialogs render blank column headings (CONFIRMED code)

- **Where**: `protected/assets/js/OpenEyes.UI.AdderDialog.js:350-370` falls back to an empty string when an item set declares no `header`, and prints that as the column's `<th>`. Three widgets leave it out: `OphCiExamination/widgets/js/NinePositions.js` sets a header on only 2 of its 7 item sets (`:181`, `:214`), leaving the horizontal prism position, E deviation, X deviation, vertical prism position and vertical deviation columns blank; `widgets/js/Synoptophore.js` sets one on 4 of 5 (`:44`, `:55`, `:66`, `:71`), leaving deviation blank; `widgets/js/StrabismusManagement.js:40-58` sets none at all, so all five columns are blank. The labels exist - `models/Synoptophore_ReadingForGaze.php:132` supplies "Deviation", and `widgets/Synoptophore.php:54-60` passes the whole `attributeLabels()` array in - they are simply not asked for.
- **Route**: `/OphCiExamination/default/create?...` - Nine Positions, Synoptophore or Strabismus Management element
- **Repro**:
  1. Open an Examination with the Nine Positions element.
  2. Click the green plus in any gaze cell.
- **Expected**: every column headed.
- **Actual**: five of seven headings are blank, and two of the blank ones sit side by side offering short abbreviations, so which is the E deviation and which the X deviation can only be inferred from the values themselves.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: medium on Nine Positions and Strabismus Management, where whole runs of columns are unlabelled; low on Synoptophore, where it is the last column only.
- **Status**: open, confirmed from source, not walked. Found during the orthoptic and strabismus documentation passes.

## BUG-284: Near Visual Acuity complex readings show an empty Fixation column (CONFIRMED code/db)

- **Where**: `protected/modules/OphCiExamination/widgets/views/VisualAcuity_event_edit.php:154` emits the Fixation `<th>` unconditionally in the sided readings tables, while the same header in the both-eyes table at `:55-57` and the matching cell in `VisualAcuity_Reading_event_edit.php:58` are both guarded by `readingsHaveFixation()` (`widgets/VisualAcuity.php:71-74`), which is true only for the distance reading class. Near Visual Acuity extends the same element and reuses the same widget and view, and `ophciexamination_nearvisualacuity_reading` has no `fixation_id` column.
- **Route**: `/OphCiExamination/default/create?...` - Near Visual Acuity element
- **Repro**:
  1. Open an Examination with the Near Visual Acuity element.
  2. Switch it to **Complex inputs**.
  3. Look at the right or left readings table.
- **Expected**: no Fixation column, as in the both-eyes table directly above.
- **Actual**: a Fixation heading with no cells under it, so from that column on the headings no longer line up with the fields they name.
- **Evidence**: read at `53b077c089` in the container; the absent column confirmed against the sample database.
- **Severity**: low-medium - nothing is lost, but the misalignment invites reading the Occluder value as a fixation and vice versa.
- **Status**: open, confirmed from source and schema, not walked. Found during the vision and refraction admin documentation pass.

## BUG-285: moving a visual acuity source between near and distance blanks it on readings already saved with it (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/models/OphCiExamination_VisualAcuity_Reading.php:148-155` builds the source list as `activeOrPk($current_pks)->findAll(['condition' => 'is_near = 0', ...])`. `activeOrPk()` (`protected/behaviors/LookupTable.php:32-42`) merges `active = 1 OR id = <current>`, which is what normally keeps a deactivated-but-recorded value visible; the `is_near` condition is then ANDed on top of it, so it overrides that protection. `OphCiExamination_NearVisualAcuity_Reading.php:60-67` does the same with `is_near = 1`.
- **Route**: `/OphCiExamination/admin/VisualAcuitySource`
- **Repro**:
  1. Go to Admin > Examination > Visual Acuity Sources and tick **Is Near** against a source used on existing distance readings, for example Cardiff Cards. Save.
  2. Open an Examination that recorded a distance reading with that source and click edit.
- **Expected**: the source still shown, as it would be had the source merely been deactivated.
- **Actual**: the **Source** dropdown reads **- Select -**. Saving the event from that state writes the blank back.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: medium - an admin edit intended to reclassify a source silently strips it from historical readings on the next edit of each event, and the admin screen gives no warning that the source is in use.
- **Status**: open, confirmed from source, not walked. Found during the vision and refraction admin documentation pass.

## BUG-286: the only shipped visual acuity occluder is misspelled (CONFIRMED db)

- **Where**: `ophciexamination_visual_acuity_occluder` holds a single active row, id 1, named "Speilmann". The device is the Spielmann translucent occluder.
- **Route**: `/OphCiExamination/admin/VisualAcuityOccluder`, and the **Occluder** dropdown on complex Visual Acuity and Near Visual Acuity readings.
- **Repro**:
  1. Open an Examination with the Visual Acuity element and switch to **Complex inputs**.
  2. Open the **Occluder** dropdown.
- **Expected**: "Spielmann".
- **Actual**: "Speilmann".
- **Evidence**: read from the sample database at `53b077c089`. Shipped reference data, so it is the same wherever it has not been corrected locally.
- **Severity**: low - the value works, it is just misspelled in front of clinicians, and an installation that has already corrected it will not match the documentation.
- **Status**: open, confirmed from data, not walked. Found during the vision and refraction admin documentation pass.

## BUG-287: the Therapy Application data-sharing consent tick is declared required but can never block a save (CONFIRMED code/db)

- **Where**: `protected/modules/OphCoTherapyapplication/models/Element_OphCoTherapyapplication_MrServiceInformation.php:73` lists `patient_sharedata_consent` in the `required` rule. The field is rendered by the shared checkbox widget, which emits a hidden `0` immediately before the box (`protected/widgets/views/CheckBox.php:45,49`), and the view adds a second hidden of its own (`views/default/form_Element_OphCoTherapyapplication_MrServiceInformation.php:43-44`). The attribute is therefore always posted - `"1"` when ticked, `"0"` when not - and Yii's required validator does not treat `"0"` as empty.
- **Route**: `/OphCoTherapyapplication/default/create?patient_id=:id`
- **Repro**:
  1. Start a Therapy Application and complete Diagnosis and Patient Suitability.
  2. In MR Service Information choose a **Consultant** and an **Intended Site** and leave **Patient consents to share data** unticked.
  3. Save.
- **Expected**: "Patient consents to share data cannot be blank", as the required rule intends.
- **Actual**: the event saves, the answer is stored as 0, and the generated funding application prints "Patient consents to share data: No" - indistinguishable from a clinician who deliberately recorded a refusal.
- **Evidence**: read at `53b077c089` in the container; `et_ophcotherapya_mrservicein` holds 12 NULL, 3 zero and 3 one, so the field has been left unanswered in practice.
- **Severity**: medium - a consent question that the form promises to enforce and does not, on the element whose output is sent outside the organisation.
- **Status**: open, confirmed from source and data, not walked. Found during the therapy application documentation pass.

## BUG-288: hiding the radiography field makes every application record today as the angiogram baseline date (CONFIRMED code)

- **Where**: `protected/modules/OphCoTherapyapplication/views/default/form_Element_OphCoTherapyapplication_PatientSuitability_fields.php:87`. When `hide_therapy_app_radiography` is on, the date picker is replaced by `<input type="hidden" ... value="<?= date('Y-m-d') ?>">` rather than by nothing.
- **Route**: Admin > Settings, then `/OphCoTherapyapplication/default/create?patient_id=:id`
- **Repro**:
  1. Set **Hide radiography field from Therapy Application** to on.
  2. Create and save a Therapy Application for any patient.
  3. Read `<side>_angiogram_baseline_date` on the saved element, or switch the setting back off and reopen the event.
- **Expected**: no angiogram baseline date, since the question was deliberately withheld.
- **Actual**: every open eye records the date the event was saved, as though an angiogram had been done that day. Turning the setting back off displays that invented date as a real answer.
- **Evidence**: read at `53b077c089` in the container. Setting 226 is off in this deployment with no installation or institution override, so the path is not currently active here.
- **Severity**: medium - fabricated clinical dates, produced by a configuration option whose purpose is to record nothing.
- **Status**: open, confirmed from source, not walked. Found during the therapy application documentation pass.

## BUG-289: compliant therapy applications are submitted with no attachment, and the one alternative template is unreachable (CONFIRMED code/db)

- **Where**: `protected/modules/OphCoTherapyapplication/services/OphCoTherapyapplication_Processor.php:222-248` resolves the template as `pdf_compliant.php` for a compliant side and `pdf_noncompliant.php` otherwise, returning nothing when the file is absent. `views/email/` contains only `email_compliant.php`, `email_noncompliant.php`, `pdf_compliant_OZU.php` and `pdf_noncompliant.php` - there is no `pdf_compliant.php`. The `_OZU` variant is only chosen when the treatment carries a `template_code`, and all seven rows of `ophcotherapya_treatment` have it empty. The send path attaches only when a PDF was produced (`:486-489`) and sends regardless (`:558`).
- **Route**: `/OphCoTherapyapplication/default/view/:event_id` - **Submit Notification**
- **Repro**:
  1. Configure a Compliant application recipient for the intended site.
  2. Create a Therapy Application that comes out **Compliant** on any shipped treatment.
  3. Press **Submit Notification**.
- **Expected**: either the notification carries the application, or the absence is deliberate and the screen says so.
- **Actual**: the email goes out with no attachment and the event is marked sent. Nothing on screen distinguishes this from a submission that did carry one.
- **Evidence**: read at `53b077c089` in the container; the empty `template_code` on all seven treatments confirmed against the sample database. Not executed - submitting sends real mail.
- **Severity**: medium - flagged as "confirm intent". A compliant notification may legitimately carry no PDF, but the code plainly looks for a file that does not exist, and the Ozurdex template it ships cannot be selected by any shipped configuration.
- **Status**: open, confirmed from source and data, not walked. Found during the therapy application documentation pass.

## BUG-290: the Therapy Application diagnosis pre-fill ignores the therapy disorder list it looks up (CONFIRMED code)

- **Where**: `protected/modules/OphCoTherapyapplication/controllers/DefaultController.php:287-291` builds `$valid_disorders` and `$vd_ids` from `OphCoTherapyapplication_TherapyDisorder`, and then never reads either. The loop at `:294-302` copies the most recent Injection Management diagnosis onto the element unconditionally.
- **Route**: `/OphCoTherapyapplication/default/create?patient_id=:id`
- **Repro**:
  1. Find a patient whose most recent Injection Management sequence carries a diagnosis that is not on the Therapy Application disorder list.
  2. Add Event > Therapy Application for that patient.
- **Expected**: the pre-filled diagnosis is one the screen would itself offer.
- **Actual**: the element opens pre-filled with a diagnosis the adder does not list, so the application can be submitted against a disorder the service has not approved for therapy - and the clinician has no cue that the value came from elsewhere.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: medium - the filter the code sets out to apply is the whole point of the disorder list, and a wrong diagnosis reaches the printed funding application.
- **Status**: open, confirmed from source, not walked. Found during the therapy application documentation pass.

## BUG-291: the two eyes ask the standard-intervention question in different words (CONFIRMED code)

- **Where**: `protected/modules/OphCoTherapyapplication/models/Element_OphCoTherapyapplication_ExceptionalCircumstances.php:261` labels the left field "Is there a standard intervention at this stage"; `:279` labels the right one "Standard Intervention Exists".
- **Route**: `/OphCoTherapyapplication/default/create?patient_id=:id` - Exceptional Circumstances
- **Repro**:
  1. Create a Therapy Application where both eyes come out Non-Compliant.
  2. Compare the first question on the left side with the first question on the right.
- **Expected**: the same question, worded the same way.
- **Actual**: two different wordings for the same field, side by side.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: low - the answers mean the same thing, but the reader has to work that out on a form that goes to a funding panel.
- **Status**: open, confirmed from source, not walked. Found during the therapy application documentation pass.

## BUG-292: the no-recipient warning names the workflow status instead of the application type (CONFIRMED code)

- **Where**: `protected/modules/OphCoTherapyapplication/views/default/view.php:76` interpolates `$status`, which is `getApplicationStatus()` (`:38`, one of pending / sent / re-opened) or the historical constant (`:35`). The lookup that failed was for a recipient of type Compliant or Non-compliant (`services/OphCoTherapyapplication_Processor.php:642-652`).
- **Route**: `/OphCoTherapyapplication/default/view/:event_id`
- **Repro**:
  1. Open a Therapy Application at a site with no configured application recipient.
- **Expected**: a message naming what is missing, for example "No Non-compliant application recipient configured for <site>".
- **Actual**: "No application recipient configured for pending application at <site>, please contact support to resolve this." - which reads as though the problem were the event's status, and gives support nothing to act on.
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: low - Submit is correctly disabled, but the one message that explains why points at the wrong thing.
- **Status**: open, confirmed from source, not walked. Found during the therapy application documentation pass.

## BUG-293: a consultant whose firm has left the subspecialty is dropped from the list and replaced on the next save (CONFIRMED code)

- **Where**: `protected/models/Firm.php:251-268`. The `include_id` escape - the mechanism that keeps an already-recorded firm selectable - is appended inside the `where()` as `... or f.id = :include_id`, and the subspecialty and institution filters are then applied with `andWhere()`. The rescued row is therefore filtered out again by the subspecialty condition. `OphCoTherapyapplication/views/default/form_Element_OphCoTherapyapplication_MrServiceInformation.php:21-29` relies on it for the **Consultant** list.
- **Route**: `/OphCoTherapyapplication/default/update/:event_id`
- **Repro**:
  1. Find a saved Therapy Application whose recorded consultant firm is no longer in the Medical Retina subspecialty, or move that firm to another subspecialty in admin.
  2. Open the event for editing.
- **Expected**: the recorded consultant stays selected, as `include_id` exists to guarantee.
- **Actual**: the firm is absent from the dropdown, the box falls back to **Select**, and saving writes a different consultant - or refuses to save until one is chosen.
- **Evidence**: read at `53b077c089` in the container. Core model, so every caller passing both `include_id` and a subspecialty is affected, not only this screen.
- **Severity**: medium - silent substitution of a recorded clinician on an event that is sent outside the organisation.
- **Status**: open, confirmed from source, not walked. Found during the therapy application documentation pass.

## BUG-294: "Therapy application will expiry in" (CONFIRMED code)

- **Where**: `protected/modules/OphCoTherapyapplication/views/default/form_Element_OphCoTherapyapplication_PatientSuitability.php:70`.
- **Route**: `/OphCoTherapyapplication/default/create?patient_id=:id`
- **Repro**:
  1. Start a Therapy Application for a patient who already has an application with an expiry date.
  2. Read the alert box above Patient Suitability.
- **Expected**: "Therapy application will expire in ...".
- **Actual**: "Therapy application will expiry in ...".
- **Evidence**: read at `53b077c089` in the container.
- **Severity**: low.
- **Status**: open, confirmed from source, not walked. Found during the therapy application documentation pass.

## BUG-295: PIN signing an intravitreal prescription can never succeed - the signatory id is posted empty (CONFIRMED code/db)

- **Where**: `protected/widgets/js/EsignWidget.js:41-46` looks for `.js-user_id-input`, falling back to `.js-user_id-field`. Neither class exists in `protected/modules/OphTrIntravitrealinjection/widgets/views/_prescription_event_edit_side.php`, which renders only `js-pin-input` and `js-sign-button` (`:100-118`); the two views that do carry those classes are `protected/widgets/views/EsignUsernamePINField.php` and `protected/modules/OphTrConsent/widgets/views/EsignUsernamePINField.php`. `submitPin()` at `:400` therefore reads `.val()` off an empty jQuery set, and jQuery serialises the resulting `undefined` as `user_id=`. Server side, `protected/components/actions/GetSignatureByPinAction.php:98` takes that empty string and `:114` passes it to `SignatureHelper::getUserForSigning('')`; `protected/components/SignatureHelper.php:29` does `findByPk($user_id ?? Yii::app()->user->id)`, and because `''` is not null the fallback to the logged-in user never fires.
- **Route**: `/OphTrIntravitrealinjection/default/create/:patient_id` and `/OphTrIntravitrealinjection/default/update/:id`
- **Repro**:
  1. In Admin, set **Enable Injection prescribing** to `Optional`.
  2. Link an intravitreal treatment drug to a medication (Admin > Intravitreal injection > Treatment Drugs > **Link medication**).
  3. Order an injection plan for one eye on an Examination using that drug and save.
  4. Open an Intravitreal injection event for the patient as a holder of **IVT Prescriber**.
  5. Type your six-digit PIN into the prescription's PIN box and press **Sign by PIN**.
- **Expected**: the signature is fetched, the prescription shows as signed and the draft banner clears.
- **Actual**: "An error occurred while trying to fetch your signature. Please contact support." No PIN can ever be accepted, so no intravitreal prescription can be signed by anyone.
- **Evidence**: widget, view, action and helper read in the container at `53b077c089`. `SELECT COUNT(*) FROM user WHERE id = ''` returns 0 in the sample database, so `findByPk('')` matches nothing. Not driven live: all 11 rows of `ophtrintravitinjection_treatment_drug` have `medication_id` NULL and `ophciexamination_injection_sequence_prescription` is empty, so no prescription exists to sign yet.
- **Severity**: high - the signing half of the new prescribing feature cannot work at all. It was previously masked by there being no prescription to sign.
- **Status**: open. Found while documenting the intravitreal injection prescription element.

## BUG-296: the prescription signature is written before the event is validated and survives a failed save (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/widgets/PrescriptionElementWidget.php::updateElementFromData()` (`:128-155`, the call at `:154`) hands the posted proof to `services/PrescriptionSignatureService.php::signFromProof()`, which writes it at `:51` through `$this->repository->store(...)`. `updateElementFromData()` runs inside `BaseEventTypeController::setAndValidateElementsFromData()` (`:1786`), which `actionCreate()` calls at `:1006` - before any of the event save transactions (`:1538`, `:1614`) open. The write is therefore outside the event's transaction and is not rolled back when validation fails.
- **Route**: `/OphTrIntravitrealinjection/default/create/:patient_id` and `/OphTrIntravitrealinjection/default/update/:id`
- **Repro**:
  1. Reach a signable prescription (BUG-295 steps 1 to 4).
  2. Sign the prescription.
  3. Leave a required field elsewhere on the event blank so the save is refused.
  4. Press **Save**.
- **Expected**: the event fails validation and nothing is persisted.
- **Actual**: the event is not saved but the signature is. Reopening the event shows the prescription already signed, with no event to explain it.
- **Evidence**: widget, service and controller read in the container at `53b077c089`. Not driven live, and currently not reachable at all: the proof field is only populated by a successful PIN sign, which BUG-295 makes impossible. Fixing BUG-295 exposes this one.
- **Severity**: medium - a clinical signature recorded against work the application refused to save.
- **Status**: open. Found while documenting the intravitreal injection prescription element.

## BUG-297: filtering the Request Form picker by a named category empties it (CONFIRMED code)

- **Where**: `protected/assets/js/OpenEyes.UI.FormIoController.js:687` - `if (categoryId === controller.options.categoryAllIdValue || categoryIds.includes(categoryId))`. `categoryId` comes from `dataset.id` and is always a string; `categoryIds` is parsed from `data-category_ids`, which `protected/modules/OphCoRequestForm/widgets/views/Form_event_edit.php:71-77` emits as the category rows' integer ids, so `includes` never matches. Only the **All** entry survives the comparison, because `widgets/Form.php:70-74` gives it the literal id `RequestFormCategory::ALL_CATEGORY` and `FormIoController.js:101` compares against the same string. The filter click also fires a search (`OpenEyes.UI.AdderDialog.js:495-508`), but the picker is configured `searchWhenEmpty: false`, so with an empty search box `runItemSearch()` returns at `:1450` having cleared the results.
- **Route**: `/OphCoRequestForm/default/create/:patient_id`, the **+** button on the Form element
- **Repro**:
  1. In Admin > Request Forms, create two templates and give one of them a category.
  2. Add a Request Form event to a patient.
  3. Press the green **+** on the Form element.
  4. Click the named category in the **Request Form Category** column.
- **Expected**: the **Form options** column narrows to that category's templates.
- **Actual**: the **Form options** column empties completely and no search results appear, so the templates in that category cannot be picked. Only **All** shows anything.
- **Evidence**: controller JS, adder JS and view read in the container at `53b077c089`. Not driven live: `request_form_category` and `ophcorequestform_form` are both empty in the sample database, so neither a template nor a category exists yet.
- **Severity**: medium - categories are the only organising feature the picker has, and using one hides everything.
- **Status**: open. Found while documenting the Request Form event.

## BUG-298: a Request Form template chosen from the search results is never attached (CONFIRMED code)

- **Where**: `protected/modules/OphCoRequestForm/widgets/views/Form_event_edit.php:96` guards on `item.itemSet.options.id !== "form-option"`. Items rendered by `OpenEyes.UI.AdderDialog.js::generateListItem()` carry that data (`:715-717`, `$listItem.data('itemSet', itemSet)`), but search results are built in `runItemSearch()` at `:1497-1507` from `constructDataset(result, true)` alone and never get it. `getSelectedItems()` (`:559-566`) returns `$(this).data()`, so `item.itemSet` is `undefined` for a search result and the guard dereferences null.
- **Route**: `/OphCoRequestForm/default/create/:patient_id`, the **+** button on the Form element
- **Repro**:
  1. In Admin > Request Forms, create a template.
  2. Add a Request Form event to a patient.
  3. Press the green **+** on the Form element.
  4. Type the template's name into the search box and click the result.
  5. Press the tick to confirm.
- **Expected**: the template is attached to the event.
- **Actual**: nothing is attached, no message is shown, and the dialog stays open - `onReturn` throws on the undefined `itemSet` before it can set `shouldClose`. The only way to attach a template is the **Form options** column.
- **Evidence**: view and adder JS read in the container at `53b077c089`. Not driven live: `ophcorequestform_form` is empty in the sample database.
- **Severity**: medium - the search box is offered as an equal route to the columns and silently does nothing.
- **Status**: open. Found while documenting the Request Form event.

## BUG-299: the Request Form picker hides list items by id across both columns (CONFIRMED code)

- **Where**: `protected/modules/OphCoRequestForm/widgets/views/Form_event_edit.php:117-127` - `onOpen` walks every `li` in the dialog (`adderDialog.popup.find('li')`) and hides any whose `dataset.id` equals the currently attached template's id, without checking which list the item belongs to. Template ids come from `ophcorequestform_form` and category ids from `request_form_category`, two independent sequences, so the two columns' ids collide routinely.
- **Route**: `/OphCoRequestForm/default/create/:patient_id`, the **+** button on the Form element
- **Repro**:
  1. Create a template whose id happens to equal an existing category's id.
  2. Attach that template to a Request Form event.
  3. Reopen the picker with the **+** button.
- **Expected**: only the attached template is hidden, from the **Form options** column.
- **Actual**: the category with the colliding id also disappears from the **Request Form Category** column, so its templates can no longer be filtered for.
- **Evidence**: view read in the container at `53b077c089`. Data-dependent, so this is a code observation rather than an observed failure; both tables are empty in the sample database.
- **Severity**: low - needs colliding ids, and the category filter is already broken by BUG-297.
- **Status**: open. Found while documenting the Request Form event.

## BUG-300: Consent Taken by records the element's creator as the consultant, not the chosen health professional (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/views/default/form_Element_OphTrConsent_Consenttakenby.php:67` runs `$element->consultant_id = $element->user->id;` whenever `name_hp` is non-empty, but `models/Element_OphTrConsent_Consenttakenby.php:55-66` declares `'user' => array(self::BELONGS_TO, 'User', 'created_user_id')`. The health professional the user picked is carried in `name_hp` (and its hidden field) and never reaches `consultant_id`.
- **Route**: `/OphTrConsent/default/create/:patient_id` and `/OphTrConsent/default/update/:event_id`, the Consent Taken by element
- **Repro**:
  1. Open a patient and add a Consent form event.
  2. On Consent Taken by, click the remove icon on the pre-filled health professional chip.
  3. Search for and select a different health professional.
  4. Save the event.
  5. Read `et_ophtrconsent_consenttakenby` for that event.
- **Expected**: `consultant_id` holds the id of the selected health professional.
- **Actual**: `consultant_id` holds `created_user_id`, the id of whoever created the element. Separately, on a brand-new element `name_hp` is already pre-filled at `:37-39` from `getUserPermissionDetails()['label']` while `created_user_id` is still null, so `$element->user` is null and line 67 emits "Attempt to read property on null".
- **Evidence**: view and model read in the container at `53b077c089`. Not distinguishable in the sample data - both existing rows have creator == consultant.
- **Severity**: medium - the recorded consultant is wrong whenever the form is completed by anyone other than the named professional, and the field is what downstream reporting reads.
- **Status**: open. Found while documenting the Consent form.

## BUG-301: Additional Signatures forces the child layout onto a Type 1 form for a patient aged exactly 16 (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/controllers/DefaultController.php:229-241` (`setElementDefaultOptions_Element_OphTrConsent_AdditionalSignatures`) sets `cf_type_id = 2` for `$patient_age <= 16`, ignoring the type actually chosen. The Type dropdown filters with a strict `<` / `>` pair (`views/default/form_Element_OphTrConsent_Type.php:23-27`), so at exactly 16 every type is offered and the user can legitimately pick Type 1. Related to but distinct from BUG-007, which is about the Type element's own default.
- **Route**: `/OphTrConsent/default/create/:patient_id`
- **Repro**:
  1. Open a patient whose age is exactly 16.
  2. Add a Consent form event.
  3. Set the **Consent form type** dropdown to "1. Patient agreement to investigation or treatment".
  4. Scroll to Additional Signatures.
- **Expected**: the Type 1 layout - witness and interpreter rows.
- **Actual**: the Type 2 layout - parent/guardian rows - so E-Sign then asks for a parental signature and creates no patient signature row on a form that is not a parental agreement.
- **Evidence**: controller and view read in the container at `53b077c089`. No 16-year-old with a consent form exists in the sample database.
- **Severity**: low - only reachable at exactly 16, but the resulting form asks the wrong person to sign.
- **Status**: open. Found while documenting the Consent form.

## BUG-302: Special requirements prints twice on Types 2 and 4 (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/views/default/print2_English.php:98` and `:194`, and `print4_English.php:77` and `:110`, both render the same `Element_OphTrConsent_Specialrequirements->specialreq` - once inside the patient-details table at the top of the form and again under the "Any special requirements:" heading further down. `print1_English.php` (`:215`) and `print3_English.php` (`:203`) render it once.
- **Route**: `/OphTrConsent/default/print/:event_id`
- **Repro**:
  1. Create a Consent form of type 2 (or type 4) and type something into the special requirements box.
  2. Save the event.
  3. Press **Print**.
- **Expected**: the special requirements text appears once.
- **Actual**: it appears twice - in the patient details block and again in its own section.
- **Evidence**: the four print templates read in the container at `53b077c089`.
- **Severity**: low - cosmetic, but these are printed forms that go into a paper record.
- **Status**: open. Found while documenting the Consent form.

## BUG-303: the per-contact-type patient limit is never enforced on the attorney/deputy adder (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/assets/js/Contacts.js:147-165` counts existing rows with `controller.$table.find('.js-contact-label')` before allowing another contact of the same type, and compares that count with `contact_label.max_number_per_patient`. Only `modules/OphCiExamination/widgets/views/ContactsEntry_event_edit.php:20` emits that class; the consent widget view `modules/OphTrConsent/widgets/views/ConsentContactsEntry_event_edit.php` renders no element with it, so the count is always zero.
- **Route**: `/OphTrConsent/default/create/:patient_id`, **Patient's attorney or deputy** on a Type 4 form
- **Repro**:
  1. Add a Consent form event and set the type to "4. Unable to consent".
  2. Under **Patient's attorney or deputy** press **Add Power of Attorney Contact** and add a contact whose contact type has `max_number_per_patient` set to 1 (General Practitioner, contact_label id 83).
  3. Press **Add Power of Attorney Contact** again and add a second contact of the same type.
- **Expected**: the second add is refused with "You have reached the limit for ...".
- **Actual**: both are added; the limit configured on the contact type has no effect on this screen. The same JS does enforce it on the Examination event, where the class is rendered.
- **Evidence**: JS and both widget views read in the container at `53b077c089`.
- **Severity**: low-medium - an administrator setting that silently does nothing on one of the two screens that use it.
- **Status**: open. Found while documenting the Consent form.

## BUG-304: the patient's own GP added as an attorney is saved, hidden, then silently deleted (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/widgets/Contacts.php:64-78` loads the element's rows with `t.contact_id != <patient's GP contact id>`, and `views/default/print4_English.php:164-168` applies the same exclusion, but `controllers/DefaultController.php:914-965` (`saveComplexAttributes_Element_OphTrConsent_PatientAttorneyDeputy`) saves without it and then deletes every existing assignment whose `contact_id` is missing from the posted list.
- **Route**: `/OphTrConsent/default/create/:patient_id` then `/OphTrConsent/default/update/:event_id`, **Patient's attorney or deputy** on a Type 4 form
- **Repro**:
  1. On a Type 4 Consent form, add the patient's own GP as an attorney and answer both statements.
  2. Save. The row is written to `ophtrconsent_patient_attorney_deputy_contact`.
  3. View the saved event and print it - the GP appears in neither.
  4. Edit the event and save again.
- **Expected**: the GP is either shown and kept, or refused at the point of adding.
- **Actual**: from step 3 the row is invisible everywhere in the interface, and step 4 deletes it, because the reload that builds the posted list excludes it.
- **Evidence**: widget, controller and print template read in the container at `53b077c089`. `ophtrconsent_patient_attorney_deputy_contact` has 0 rows in the sample database.
- **Severity**: medium - saved clinical-consent data disappears without any message.
- **Status**: open. Found while documenting the Consent form.

## BUG-305: Supplementary consent shows the Type 1 questions on every edit screen (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/views/default/form_Element_OphTrConsent_SupplementaryConsent.php:33` reads `$form_id = @$_GET['type_id'] ?? '1';` and passes it to `Ophtrconsent_SupplementaryConsentQuestion::findAllMyQuestionsAsgn()`. The Type dropdown is disabled on update (`views/default/form_Element_OphTrConsent_Type.php:29-32`), so no `type_id` is ever present in the update URL and the fallback always wins. Validation independently derives its own form id from `$_POST['Element_OphTrConsent_Type']['type_id'] ?? $this->form_id` (`models/Element_OphTrConsent_SupplementaryConsent.php:104`), which can be a third value.
- **Route**: `/OphTrConsent/default/update/:event_id`
- **Repro**:
  1. In Admin > Consent > Supplementary Consent Questions, add a question scoped to form 3 and another scoped to form 1.
  2. Create and save a Type 3 Consent form.
  3. Open the saved event and press **Edit**.
- **Expected**: the question configured for form 3.
- **Actual**: the form 1 question is offered instead, and the required-question check runs against a different list again.
- **Evidence**: view, model and Type view read in the container at `53b077c089`. Invisible in the sample database, whose single shipped question ("Permissions for images") is unscoped.
- **Severity**: medium - an installation that scopes questions per consent type gets the wrong questions on every edit.
- **Status**: open. Found while documenting the Consent form.

## BUG-306: every consent print template hard-codes the heading "Form 1: Supplementary consent" (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/views/default/print1_English.php:182`, `print2_English.php:161` and `print3_English.php:190` all emit the literal `<h2>Form 1: Supplementary consent</h2>`. The heading also sits outside the surrounding conditional, so it prints above the "no active supplementary consent questions" state as well.
- **Route**: `/OphTrConsent/default/print/:event_id`
- **Repro**:
  1. Create and save a Type 2 or Type 3 Consent form.
  2. Press **Print**.
- **Expected**: a heading naming the form being printed, or no heading when there is nothing under it.
- **Actual**: "Form 1: Supplementary consent" on every type, with an empty section beneath it when no questions are active.
- **Evidence**: the three print templates read in the container at `53b077c089`.
- **Severity**: low - the printed form misidentifies itself.
- **Status**: open. Found while documenting the Consent form.

## BUG-307: the consent leaflet search only ever returns file leaflets, and none exist (CONFIRMED code/db)

- **Where**: `protected/modules/Api/controllers/v2/LeafletController.php:57` adds `$criteria->addColumnCondition(['resource_type' => AdviceLeaflet::RESOURCE_TYPE_FILE]);` to the autocomplete used by the Leaflets picker's search box. The browse list behind the same picker (`modules/OphTrConsent/models/Element_OphTrConsent_Leaflets.php:210-230`) applies no such filter, so the two halves of one dialog offer different sets.
- **Route**: `/OphTrConsent/default/create/:patient_id`, the Leaflets element picker
- **Repro**:
  1. Add a Consent form event and open the Leaflets picker.
  2. Note a leaflet name listed under one of the categories.
  3. Type that name into the picker's search box.
- **Expected**: the leaflet is returned.
- **Actual**: no results. In this database the search returns nothing for any term at all - all 46 rows of `ophciexamination_advice_leaflet` have `resource_type` NULL, so nothing can match the condition.
- **Evidence**: controller and model read in the container at `53b077c089`; `SELECT resource_type, COUNT(*) FROM ophciexamination_advice_leaflet GROUP BY resource_type` returns a single row, NULL / 46.
- **Severity**: medium - the search box is the obvious way to find a leaflet and it is empty out of the box.
- **Status**: open. Found while documenting the Consent form.

## BUG-308: a Consent form opened on a support-services firm raises a TypeError (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/models/Element_OphTrConsent_Leaflets.php:201` passes `\Yii::app()->session->getSelectedFirm()->subspecialty` into `AdviceLeafletCategory::forSubspecialty(Subspecialty $subspecialty)` (`modules/OphCiExamination/models/AdviceLeafletCategory.php:164`), whose parameter is not nullable. `Firm::getSubspecialty()` (`protected/models/Firm.php:481-484`) returns null for a firm with no `service_subspecialty_assignment_id`, which is exactly what a support-services firm is.
- **Route**: `/OphTrConsent/default/create/:patient_id` with a support-services firm selected
- **Repro**:
  1. Select a support-services firm as the current context.
  2. Open a patient and add a Consent form event of type 1, 2 or 3 (any type whose layout includes Leaflets).
- **Expected**: the Leaflets element shows an empty or unfiltered category list.
- **Actual**: `TypeError: forSubspecialty(): Argument #1 ($subspecialty) must be of type Subspecialty, null given` and the whole create screen fails.
- **Evidence**: model, `Firm` and `AdviceLeafletCategory` read in the container at `53b077c089`. Not driven live - the sample database has no active support-services firm to select.
- **Severity**: high where it applies - the event cannot be created at all from that context.
- **Status**: open. Found while documenting the Consent form.

## BUG-309: a contact created with a private contact type can never be found again (CONFIRMED code/db)

- **Where**: `protected/views/contacts/add_new_contact_assignment.php:214-234` builds the **Contact Type** dropdown from `ContactLabel::model()->findAll()` with no `is_private` filter, while the search that has to find the contact afterwards filters to `cl.is_private = 0` (`modules/OphTrConsent/controllers/ContactController.php:59`).
- **Route**: `/OphTrConsent/default/create/:patient_id`, **Add Power of Attorney Contact** on a Type 4 form
- **Repro**:
  1. On a Type 4 Consent form press **Add Power of Attorney Contact**.
  2. Type a name and choose the "Add a new contact:" entry.
  3. Set **Contact Type** to "Power of Attorney", give an address, and press **Submit**. The contact is created and added to the form.
  4. On any other Consent form, search the adder for that person by name, contact type, address or postcode.
- **Expected**: the contact is found and can be reused.
- **Actual**: it is never returned - `contact_label` ids 94 (Parent), 95 (Relative), 96 (Next of Kin), 97 (Carer), 98 (Other) and 100 (Power of Attorney) all have `is_private = 1`, and those are the types this dialog is for. Every attorney or deputy has to be created afresh on each form.
- **Evidence**: both views and the controller read in the container at `53b077c089`; `SELECT id, name, is_private FROM contact_label WHERE is_private = 1` returns exactly those six rows.
- **Severity**: medium - the interface offers reuse and cannot deliver it, and the contact table accumulates duplicates.
- **Status**: open. Found while documenting the Consent form.

## BUG-310: the consent Procedure browse list is not filtered on active (CONFIRMED code)

- **Where**: `protected/models/ProcedureSubspecialtyAssignment::getProcedureListFromSubspecialty()` (`:126-136`) selects every assignment for the subspecialty with no condition on `procedure.active`, and `modules/OphTrConsent/views/default/form_Element_OphTrConsent_Procedure_unbooked.php:2-3` renders that list straight into the adder. The search half of the same adder (`/procedure/autocomplete` -> `Procedure::getList()`, `protected/models/Procedure.php:153-180`) does filter on active.
- **Route**: `/OphTrConsent/default/create/:patient_id`, the Procedure adder
- **Repro**:
  1. In Admin > Procedures, deactivate a procedure that is assigned to a subspecialty.
  2. Add a Consent form event in that subspecialty's context and open the Procedure adder.
- **Expected**: the deactivated procedure is offered by neither half of the adder.
- **Actual**: it is still listed in the browse column, while typing its name into the search box returns nothing.
- **Evidence**: both models and the view read in the container at `53b077c089`. Latent in this database - no subspecialty assignment currently points at an inactive procedure.
- **Severity**: low - needs an administrator to deactivate an assigned procedure first.
- **Status**: open. Found while documenting the Consent form.

## BUG-311: the Consent form discards the POST-derived consent type on create (CONFIRMED code)

- **Where**: `protected/modules/OphTrConsent/controllers/DefaultController.php:322-334` (`initActionCreate`). The first block reads `type_id` out of `$_POST['Element_OphTrConsent_Type']`; the second block, guarded by the identical `is_null(Yii::app()->request->getParam("type_id"))` condition, immediately overwrites it with `TYPE_PATIENT_AGREEMENT_ID`. The first block can never take effect.
- **Route**: `/OphTrConsent/default/create/:patient_id`
- **Repro**:
  1. Add a Consent form event and change the **Consent form type** dropdown to any type other than 1.
  2. Submit the form in a way that posts the type without also carrying `type_id` in the URL - currently only reachable by a failed validation round trip that loses the query string.
- **Expected**: the element list is rebuilt for the posted type.
- **Actual**: it is rebuilt as Type 1. Does not misbehave through the normal interface, where the dropdown navigates with `type_id` as a GET parameter, so the guard is false and the else branch applies.
- **Evidence**: controller read in the container at `53b077c089`.
- **Severity**: low - dead code today, but it is the fallback the form relies on if the query string is ever lost.
- **Status**: open. Found while documenting the Consent form.

## BUG-312: the Therapy Application Diagnoses list can never be reordered - the drag handler binds to markup the screen does not render (CONFIRMED code/db)

- **Where**: `protected/modules/OphCoTherapyapplication/modules/OphCoTherapyapplicationAdmin/controllers/DiagnosisController.php:54` publishes `OphCoTherapyapplication_sort_url` and `:176-190` implements `actionSortDiagnoses`, and `modules/OphCoTherapyapplication/assets/js/admin.js:299-317` calls `$('.sortable').sortable()` and collects ids from `$('div.sortable').children('li')` by `data-attr-id`. The list view `modules/OphCoTherapyapplicationAdmin/views/diagnosis/list_therapy_disorder.php` renders `<table class="standard">` with `<tr class="clickable" data-id="...">` - no `.sortable` container, no `li`, no `data-attr-id` - so the handler binds to nothing and the endpoint is unreachable from the interface.
- **Route**: `/OphCoTherapyapplication/admin/diagnosis/viewDiagnoses`
- **Repro**:
  1. Go to Admin > Therapy application > Diagnoses.
  2. Try to drag a Level 1 disorder to a different position in the list.
  3. Open a Level 1 disorder and try the same on its Level 2 list.
- **Expected**: the rows reorder and a "Re-ordered" confirmation appears, since `display_order` is what the list and the clinician's Therapy Diagnosis picker are sorted by (`DiagnosisController.php:66`, `order = 'display_order asc'`).
- **Actual**: nothing is draggable. `display_order` is only ever set on insert (`:113-121`, max + 1) and there is no other screen that changes it, so the running order of the diagnosis picker is fixed at the order the disorders were first added and can only be changed by deleting and re-adding.
- **Evidence**: controller, view and JS read in the container at `53b077c089`. Also visible in the data: the Level 1 rows in `ophcotherapya_therapydisorder` carry display orders 1, 2, 3, 4, 5, 7, 16, 17, 18, 20, 21 - gapped because the insert takes `MAX(display_order)` across the whole table when there is no parent, so every Level 2 addition advances the Level 1 counter too.
- **Severity**: low-medium - an administrator cannot put the commonly used diagnoses at the top of the clinician's picker, and the reorder feature is written and wired but not reachable.
- **Status**: open. Found while documenting the Therapy application admin screens.

## BUG-313: the Diagnoses restriction screen writes a duplicate row for a disorder added twice in one session (CONFIRMED code)

- **Where**: `protected/modules/OphCoTherapyapplication/modules/OphCoTherapyapplicationAdmin/controllers/DiagnosisController.php:33-43` reads the existing disorder ids once, before the insert loop, and never adds to that array as it creates rows, so the same new id posted twice passes the `!in_array(...)` guard twice. The screen offers no protection either: the autocomplete's `onSelect` in `views/diagnosis/index.php` appends a new `<li>` and hidden input unconditionally, with no check against what is already listed.
- **Route**: `/OphCoTherapyapplication/admin/diagnosis/index`
- **Repro**:
  1. Go to Admin > Therapy application > Diagnoses restriction.
  2. Search for a disorder that is not yet on the list and select it.
  3. Search for the same disorder again and select it a second time - it is added to the list a second time with no warning.
  4. Press **Save** and reload the screen.
- **Expected**: one entry, or a message that the disorder is already on the list.
- **Actual**: two rows in `ophcotherapya_disorder_list` for the same `disorder_id`, and the disorder appears twice on the screen from then on. Removing one of them and saving deletes both, because the reconcile step deletes every row whose `disorder_id` is absent from the posted list.
- **Evidence**: controller and view read in the container at `53b077c089`. The shipped data is clean - 40 rows, no duplicated `disorder_id`.
- **Severity**: low - cosmetic on this screen and harmless downstream, since the allow-list is only ever used as a set, but the list becomes untidy and the removal behaviour is then surprising.
- **Status**: open. Found while documenting the Therapy application admin screens.

## BUG-314: the Cat-PROM5 live Rasch Score preview disagrees with the saved value at raw score 19 (CONFIRMED code/db)

- **Where**: `protected/modules/OphOuCatprom5/views/default/form_CatProm5EventResult.php` carries a hard-coded JavaScript copy of the raw-score-to-Rasch conversion in `scoreToRasch()`, used to update the on-screen preview as the questions are answered. Its `case 19` returns `'4.98'`. The authoritative table `cat_prom5_score_map` gives `4.95` for `raw_score = 19`, and that is what is stored: `controllers/DefaultController.php:20-21` (create) and `:30-31` (update) overwrite the posted `total_rasch_measure` with `CatProm5EventResult::rowScoreToRaschMeasure($raw_score)`, which reads the table. All 21 other values in the JavaScript copy match the table exactly, so 19 is the only divergent score.
- **Route**: `/OphOuCatprom5/default/create?patient_id=<id>` then `/OphOuCatprom5/default/view/<event_id>`
- **Repro**:
  1. Open a patient, press **Add Event** and choose **Cat-PROM5**.
  2. Answer the five scored questions so the raw score totals 19 - question 1 "Yes, all of the time" (3), question 2 "An extremely large amount" (5), question 3 "Appalling" (6), question 4 "All of the time" (3), question 5 "Yes, some difficulty" (2).
  3. Answer question 6 with any option.
  4. Read the **Rasch Score** shown on the form. It reads 4.98.
  5. Press **Save** and read the Rasch Score on the saved event.
- **Expected**: the Rasch Score shown while answering matches the one stored and displayed after saving.
- **Actual**: the form previews 4.98; the saved event shows 4.95. Nothing warns that the number changed.
- **Evidence**: view and controller read in the container at `53b077c089`; `SELECT raw_score, rasch_measure FROM cat_prom5_score_map ORDER BY raw_score` returns 4.95 at 19 and agrees with the JavaScript at every other raw score from 0 to 21.
- **Severity**: low - one score in twenty-two, and the stored value is the correct one, so no bad data is written. It is a credibility problem rather than a data problem: a clinician who noted the previewed figure sees a different number on the saved record. The underlying fault is the duplicated conversion table, which will drift again if the map is ever re-derived.
- **Status**: open. Found while documenting the Cat-PROM5 event.

## BUG-315: deleting a both-eyes HFA result leaves one eye's visual-field trend data behind and never rebuilds the statistic (CONFIRMED code/db)

- **Where**: `protected/modules/OphGeneric/models/HFA.php:161-232` (`softDelete()`). It clears up the patient-level trend data in two steps, and both are wrong for an element recorded against both eyes. First, `PatientStatisticDatapoint::model()->findByAttributes(['stat_type_mnem' => 'md', 'event_id' => $this->event->id])` matches on the event alone, and `findByAttributes` returns at most one row - but a both-eyes result writes one datapoint per eye, so only one of the two is deleted. Second, `PatientStatistic::model()->findByAttributes([..., 'eye_id' => $this->eye_id])` keys the statistic on the element's own `eye_id`, which is 3 ("both") for such an element, while statistics are only ever stored against eye 1 or eye 2 - so the lookup returns null and the branch that either deletes the exhausted statistic or sets `process_datapoints = true` never runs. The same two faults are repeated verbatim for the `vfi` statistic at `:200-232`.
- **Route**: `/OphGeneric/default/view/<event_id>` then the delete action
- **Repro**:
  1. Open a patient who has a Device Information event carrying an HFA element recorded for **both** eyes.
  2. Note the patient's visual-field trend - the Mean Deviation and Visual Field Index statistics hold a datapoint from this event for each eye.
  3. Delete the event.
  4. Re-read the patient's MD and VFI datapoints and statistics.
- **Expected**: both eyes' datapoints for that event are removed, and each affected statistic is either deleted (if it has no datapoints left) or flagged for remodelling so the trend line is recalculated without the deleted result.
- **Actual**: one eye's MD datapoint and one eye's VFI datapoint survive, still attributed to the deleted event, and neither eye's statistic is flagged for remodelling - so the stored gradient and intercept continue to reflect a result that is no longer in the record. A single-eye element is unaffected, because its `eye_id` is 1 or 2 and it only ever has one datapoint per statistic.
- **Evidence**: model read in the container at `53b077c089`. In the sample database `et_ophgeneric_hfa` holds 48 right-only, 52 left-only and 6 both-eyes elements; every one of those 6 has exactly two `ophgeneric_hfa_entry` rows and exactly two `md` datapoints, with `eye_id` 1 and 2. `SELECT stat_type_mnem, eye_id, COUNT(*) FROM patient_statistic GROUP BY 1,2` returns only eye 1 and eye 2, confirming that an `eye_id = 3` lookup can never match.
- **Severity**: medium - silent, persistent bad data in a clinical trend. The visual-field progression statistics are what the analytics screens plot, so a deleted result keeps influencing the line and there is no on-screen sign that it is doing so. Affects only both-eyes results, which are the minority (6 of 106 in the sample data), but nothing warns the user.
- **Status**: open. Found while documenting the Device Information event's HFA element.

## BUG-316: the allergy check that suppresses a defaulted antiseptic or skin-cleansing drug is dead code (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/models/Element_OphTrIntravitrealinjection_Treatment.php`, `setDefaultOptions()`. The method fetches `OphTrIntravitrealinjection_SkinDrug::getDefault()` and `OphTrIntravitrealinjection_AntiSepticDrug::getDefault()` into `$pre_skin_default` and `$pre_anti_default`, then walks each drug's `allergies` relation and sets the local back to `null` when `$patient->hasAllergy($allergy)` is true. It then calls `setDefaultOptionSide(Eye::RIGHT, $patient)` and `setDefaultOptionSide(Eye::LEFT, $patient)` and returns. Neither local is passed in or read again. `setDefaultOptionSide()` re-fetches both defaults itself with the same two `getDefault()` calls and assigns them straight to `{$side}_pre_skin_drug_id` and `{$side}_pre_antisept_drug_id` with no allergy test anywhere in it.
- **Route**: `/patientEvent/create?...&event_type_id=<Intravitreal injection>`
- **Repro** (no setup needed - the sample data already has the assignment):
  1. Open a patient whose Examination record lists an **Iodine** allergy.
  2. Create an Intravitreal injection event for that patient.
  3. Look at **Pre Injection Antiseptic** on the Treatment element, for either eye.
- **Expected**: the drop-down opens with nothing selected, because the default drug is one the patient is allergic to.
- **Actual**: the drop-down opens pre-selected on **Iodine 5%**, for both eyes. The same code path governs **Pre Injection Skin Cleansing**.
- **Evidence**: model read in the container at `53b077c089`. The two allergy loops write only to locals that are provably never read after the loop - the very next statements are the two `setDefaultOptionSide()` calls, and that method opens its own `getDefault()` pair before assigning. The sample database wires the case up end to end: `ophtrintravitinjection_antiseptic_allergy_assignment` holds one row linking antiseptic drug 1 to allergy 3, `SELECT id, name, is_default FROM ophtrintravitinjection_antiseptic_drug` shows drug 1 "Iodine 5%" is the flagged default, `allergy` id 3 is "Iodine", and `SELECT allergy_id, COUNT(DISTINCT patient_id) FROM v_patient_allergies GROUP BY allergy_id` shows 2 patients carry allergy 3.
- **Severity**: medium - the safety feature the code was written to provide does not operate, and it fails in the unsafe direction (an allergen is offered pre-selected rather than withheld). A clinician who trusts the pre-fill can administer a drug the patient is recorded as allergic to.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-317: renaming or deleting the injection reason called "Other" takes down the whole Injection Management element (CONFIRMED code)

- **Where**: three widget views dereference a lookup row found by literal name with no null guard - `protected/modules/OphCiExamination/widgets/views/_injection_management_cancel.php:34`, `_injection_management_observe.php:32` and `_injection_management_stop.php:36`. Each reads `...::model()->find('name=:name', [':name' => 'Other'])->id`. `find()` returns `null` when no row is named exactly "Other", and `->id` on `null` is a fatal error in PHP 8. The equivalent no-treatment path is null-safe by contrast (`OphCiExamination_Injection_No_Treatment_Reasons::isOther()`), which shows the guard was intended.
- **Route**: `/OphCiExamination/admin/InjectionManagement/viewObserveReasons` (or viewCancelReasons / viewStopReasons), then any Examination event carrying an Injection Management element
- **Repro**:
  1. Go to Admin > Examination > Injection Management > Observe reasons.
  2. Open the row named **Other** and rename it to anything else, for example "Other reason". Save.
  3. Open any Examination event that has an Injection Management element.
- **Expected**: at worst the free-text box that "Other" enables never appears; the rest of the element still works.
- **Actual**: the page fatals on `null->id` and the entire Injection Management element fails to render. Deleting the row instead of renaming it has the same effect. The cancel and stop panels fail identically for their own lists.
- **Evidence**: three views read in the container at `53b077c089`; the row exists as id 9 "Other" in `ophciexamination_injection_cancel_reasons`, and the name is the only thing tying code to data - there is no `is_other` column or constant on these three models.
- **Severity**: high - an ordinary, permitted admin edit on a screen that presents the row as freely editable breaks a clinical element for every patient, with no warning on the admin screen and no way to tell from it that the row is load-bearing.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-318: the same "Other" dependency in Switch Treatment fails in JavaScript instead, and blocks the switch (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/widgets/views/InjectionManagement_event_edit.php:126` emits `other_switch_treatment_id: <?= ...find("name=:name", [":name" => OphCiExamination_Injection_Switch_Reasons::$OTHER_NAME])->id ?? null ?>` - the PHP side is null-safe and emits `null`. `protected/modules/OphCiExamination/widgets/js/InjectionManagement.js:362` then does `switch_treatment_reason_is_other = switch_reason.dataset.id === this.options.other_switch_treatment_id.toString();` with no guard, and the option's own default at `:48` is `null`.
- **Route**: an Examination event's Injection Management element, on a cancelled sequence
- **Repro**:
  1. Go to Admin > Examination > Injection Management > Switch reasons and rename or delete the row named **Other**.
  2. Open an Examination event with an Injection Management element and cancel a treatment sequence.
  3. Press **Switch Treatment**, pick any switch reason, and confirm in the adder.
- **Expected**: the switch is recorded, with the free-text box simply unavailable.
- **Actual**: `null.toString()` throws, the adder never returns and the switch cannot be made at all.
- **Evidence**: view and JS read in the container at `53b077c089`. Distinct from BUG-317 in both layer and effect - here the PHP null-coalesce was added but the JS consumer was not updated, so the failure is a blocked action rather than a broken render.
- **Severity**: medium - one clinical action is blocked rather than a whole element, but the cause is equally invisible from the admin screen that triggers it.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-319: deleting an in-use Treatment Drug raises an uncaught database exception (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/controllers/AdminController.php`, `actionDeleteTreatmentDrugs()`. It loops `foreach (...findAllByPk($_POST['treatment_drugs']) as $drug) { if (!$drug->delete()) { $result = 0; } }` and echoes the flag. There is no try/catch and no transaction, so it handles only a `false` return, never a thrown one; `ophtrintravitinjection_treatment_drug` is referenced by RESTRICT foreign keys, so an in-use row throws `CDbException` (SQLSTATE 1451) instead of returning false. The same controller's `actionDeleteInjectionIopInstrument()` does wrap its loop, which shows the intended pattern.
- **Route**: `/OphTrIntravitrealinjection/admin/viewTreatmentDrugs`
- **Repro**:
  1. Go to Admin > Intravitreal injection > Treatment Drugs.
  2. Tick a drug that has already been used on a saved injection sequence.
  3. Press **Delete**.
- **Expected**: the screen reports that the drug is in use and cannot be deleted, and nothing is removed.
- **Actual**: an uncaught exception is returned into the AJAX handler. Because the loop is not transactional, any drugs earlier in the same selection that were not in use have already been deleted when it throws.
- **Evidence**: controller read in the container at `53b077c089`; the guarded sibling action in the same file is the contrast.
- **Severity**: medium - partial deletion plus an unhandled error, on an ordinary admin action.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-320: a duplicated foreign key leaves the right eye's post-injection IOP instrument unprotected (CONFIRMED schema)

- **Where**: `et_ophtrintravitinjection_postinject` carries two constraints named for the two eyes, `fk_left_postinject_instrument` and `fk_right_postinject_instrument`, but both are defined on the **same** column. Querying `information_schema.KEY_COLUMN_USAGE` for that table returns `left_iop_instrument_id` twice, once under each constraint name; `right_iop_instrument_id` appears under no constraint at all.
- **Route**: `/OphTrIntravitrealinjection/admin/viewInjectionIopInstruments`
- **Repro**:
  1. Note an instrument that has been used on the right eye only in saved post-injection examination elements.
  2. Go to Admin > Intravitreal injection > Injection IOP Instruments.
  3. Tick that instrument and press **Delete**.
- **Expected**: the delete is refused because the instrument is in use, as it would be for a left-eye-only instrument.
- **Actual**: the delete succeeds and every right-eye element that referenced it is orphaned, holding an id that no longer resolves.
- **Evidence**: `SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'et_ophtrintravitinjection_postinject' AND REFERENCED_TABLE_NAME IS NOT NULL` returns `fk_left_postinject_instrument left_iop_instrument_id` and `fk_right_postinject_instrument left_iop_instrument_id`.
- **Severity**: medium - a schema-level asymmetry that silently disables referential protection for one eye. Copy-paste in the migration is the obvious cause.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-321: OEHtml::activeDropDownList builds relation drop-downs from every row, ignoring the Active flag (CONFIRMED code)

- **Where**: `protected/helpers/OEHtml.php`, `activeDropDownList()`. When the attribute matches a relation's foreign key it builds the option list with `CHtml::listData($related_model->findAll(), $value_field, $text_field)` - an unfiltered `findAll()`. Every other consumer of these lookup tables uses the `active()` scope from `protected/behaviors/LookupTable.php`.
- **Route**: any form using this helper for a lookup relation, for example the post-injection examination element's IOP instrument selector
- **Repro**:
  1. Go to Admin > Intravitreal injection > Injection IOP Instruments and untick **Active** on one instrument. Save.
  2. Open a form whose instrument drop-down is rendered through this helper.
- **Expected**: the deactivated instrument is no longer offered.
- **Actual**: it is still in the list and can still be chosen.
- **Evidence**: helper read in the container at `53b077c089`; the `active()` scope it does not use is defined in the shared LookupTable behaviour.
- **Severity**: low to medium - deactivating a lookup row is the standard way to retire it without breaking historic records, and on these forms it has no effect. The blast radius is every relation drop-down rendered through this helper, not just the one screen it was found on.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-322: getDefault() on the antiseptic and skin-cleansing drug lists ignores the Active flag (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/models/OphTrIntravitrealinjection_AntiSepticDrug.php` and `..._SkinDrug.php`, both `getDefault()` implemented as `self::model()->find('is_default = ?', [true])` with no `active()` scope.
- **Route**: `/patientEvent/create?...&event_type_id=<Intravitreal injection>`
- **Repro**:
  1. Go to Admin > Intravitreal injection > Antiseptic Drugs.
  2. Untick **Active** on the row that holds **Default**, leaving the Default tick in place. Save.
  3. Create an Intravitreal injection event and look at the Pre Injection Antiseptic drop-down.
- **Expected**: the deactivated drug is neither offered nor pre-selected.
- **Actual**: it is pre-selected on the new element while being absent from the list it is pre-selecting into, so the field shows a value the drop-down cannot reproduce and re-picking it is impossible.
- **Evidence**: both models read in the container at `53b077c089`.
- **Severity**: low - a form arrives in a state the user cannot re-enter, and the pre-fill points at a drug the service has retired.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-323: the Default flag on Injection Start Options is stored and displayed but never read (CONFIRMED code/db)

- **Where**: `OphCiExamination_Injection_Start_Options` declares `is_default => 'Default'`, the admin form renders the tick box and the list screen renders the column, but `protected/modules/OphCiExamination/widgets/InjectionManagement.php`, `getPatientStartOptions()` builds the entire Start column - the name-matched special cases, the `Last+<name>` entries and the event-date entries - without ever consulting `is_default`.
- **Route**: `/OphCiExamination/admin/InjectionManagement/viewStartOptions`, then an Examination event's Injection Management element
- **Repro**:
  1. Go to Admin > Examination > Injection Management > Start options and confirm one row is ticked **Default** ("Today" is, as shipped).
  2. Open an Examination event with an Injection Management element and press **Start injection series**.
  3. Look at the Start column of the adder.
- **Expected**: the row flagged Default is pre-selected.
- **Actual**: nothing is pre-selected. Moving the Default tick to another row changes nothing either.
- **Evidence**: widget method read in the container at `53b077c089` - the whole of `getPatientStartOptions()` contains no reference to `is_default`. `SELECT id, name, is_default FROM ophciexamination_injection_start_options` shows id 1 "Today" flagged Default.
- **Severity**: low - a control that appears to do something and does nothing, so an administrator who moves the Default expects a change and gets none.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-324: Injection Start Options are matched by name, so "Urgent" ships with an increment it can never use and "Soon" is never shipped (CONFIRMED code/db)

- **Where**: `protected/modules/OphCiExamination/widgets/InjectionManagement.php`, `getPatientStartOptions()` special-cases three rows by literal name - `if ($start_option->name === "Today" || $start_option->name === "Urgent" || $start_option->name === "Soon")` - and gives all three the event date, ignoring their `year_inc`, `month_inc` and `day_inc` entirely. Every other row is instead expanded into a `Last+<name>` entry (only when the patient has had that drug before) plus an event-date-plus-increment entry.
- **Route**: `/OphCiExamination/admin/InjectionManagement/viewStartOptions`
- **Repro**:
  1. Go to Admin > Examination > Injection Management > Start options and open **Urgent**. It carries a 2-day increment.
  2. Open an Examination event with an Injection Management element and press **Start injection series**.
  3. Pick **Urgent** in the Start column and read the resulting date.
- **Expected**: either the date is two days after the event date, or the increment fields are not offered on that row.
- **Actual**: the date is the event date. The stored 2-day increment is dead, and editing it has no effect. Separately, the code's third special case, "Soon", has no row in the shipped data at all, so that branch is unreachable as installed - while renaming any row to "Soon" would silently promote it into the special case and discard its increments.
- **Evidence**: widget method read in the container at `53b077c089`. `SELECT id, name, year_inc, month_inc, day_inc FROM ophciexamination_injection_start_options` returns 9 rows: "Today" (0/0/0), "Urgent" (0/0/2), then seven interval rows; there is no "Soon".
- **Severity**: low - a misleading admin screen rather than wrong clinical data, but the name-matching means renaming a row can change what it does, which no part of the screen tells the user.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-325: the Injection Cancel Reasons list offers a non-editable internal row for editing and deletion (CONFIRMED code/db)

- **Where**: `protected/modules/OphCiExamination/modules/ExaminationAdmin/views/injectionmanagement/list_OphCiExamination_Injection_Cancel_Reasons.php:37,40` renders `<tr class="clickable">` and the row's `select[]` checkbox unconditionally. The sibling view `list_OphCiExamination_FollowUp_Options.php:46-55` guards both with `<?php if ($option->editable) { ?>`. The controller action `actionViewCancelReasons()` lists rows with a plain `findAll(['order' => 'display_order asc'])`, so inactive and non-editable rows are included.
- **Route**: `/OphCiExamination/admin/InjectionManagement/viewCancelReasons`
- **Repro**:
  1. Go to Admin > Examination > Injection Management > Cancel reasons.
  2. Find the row **Cancelled after creating unbooked sequence**.
  3. Click it, or tick it and press Delete.
- **Expected**: the row is listed for reference but is neither clickable nor selectable, as non-editable rows are on the Follow-up Options screen.
- **Actual**: it opens for editing and can be renamed or deleted, even though it is the reason the application writes itself when it cancels a sequence during unbooked-series creation.
- **Evidence**: both views read in the container at `53b077c089`. `SELECT id, name, active, editable FROM ophciexamination_injection_cancel_reasons` returns 9 rows, of which id 8 "Cancelled after creating unbooked sequence" is the only one with `editable = 0` (and `active = 0`).
- **Severity**: low - a single internal row is exposed, but renaming it desynchronises the label the application writes from the label it looks for.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-326: Cancel on the Add Injection Defer Reason form goes to a route that does not exist (CONFIRMED code)

- **Where**: `protected/modules/OphCiExamination/modules/ExaminationAdmin/controllers/InjectionManagementController.php:490` renders the add form with `'cancel_uri' => '/OphCiExamination/admin/InjectionManagement/viewInjectionDeferReason'`. The controller has no `actionViewInjectionDeferReason`; the real action is `actionViewDeferReasons` at `:459`, reached as `.../viewDeferReasons`.
- **Route**: `/OphCiExamination/admin/InjectionManagement/addDeferReason`
- **Repro**:
  1. Go to Admin > Examination > Injection Management > Defer reasons.
  2. Press the add button.
  3. Press **Cancel**.
- **Expected**: the form closes and the defer reasons list is shown again.
- **Actual**: a 404. The user has to navigate back to the list by hand.
- **Evidence**: controller read in the container at `53b077c089`; the action list in the same file shows `actionViewDeferReasons` and no action matching the URI in `cancel_uri`.
- **Severity**: low - cosmetic navigation fault on one admin form, nothing is lost.
- **Status**: open. Found while documenting the Intravitreal injection admin screens.

## BUG-327: the "Order" column on generic admin list screens is inert - rows cannot be reordered at all (CONFIRMED code)

- **Where**: two independent faults, either of which alone disables reordering.
  1. **The binding never matches on `genericAdmin()` screens.** `protected/assets/js/oeadmin/list.js:19-23` binds jQuery UI sortable to exactly `$('#generic-admin-list .sortable, #generic-admin-sublist .sortable')`. `BaseAdminController::genericAdmin()` renders `//admin/generic_admin`, which emits a heading `<div class="row divider ...">` and then the `GenericAdmin` widget; the widget view `protected/widgets/views/GenericAdmin.php:39` opens `<div class='<?=$div_wrapper_class?>'>` - a class, never an id. Neither id appears anywhere on that page, so the selector matches nothing and no sortable is ever initialised, whether or not `list.js` was registered.
  2. **The save handler dereferences an element that is not there.** `protected/assets/js/oeadmin/OpenEyes.admin.js:50-52` starts `Admin.saveSorted` with `const tableToSort = document.querySelector('#et_sort'); ... tableToSort.dataset.uri`. `#et_sort` is a bespoke id carried by about fifteen hand-written admin screens that each declare their own `data-uri` sort endpoint. The generic list families do not carry it: neither `protected/views/admin/generic/list.php` (which *does* wrap in `#generic-admin-sublist` / `#generic-admin-list`, so its sortable binds correctly and renders the same `&uarr;&darr;` glyph at `:133`) nor the `GenericAdmin` widget. Dropping a dragged row therefore throws `TypeError: tableToSort is null` before the POST is built.
  Net effect: the widget family cannot be dragged; the newer generic-list family can be dragged but the drop never saves. Carrying `#et_sort` is not sufficient either, because the script that binds it has to be registered as well - Intravitreal injection's **Treatment Drugs** and **Injection IOP Instruments** both render `id="et_sort"` with a working `data-uri` sort endpoint, and both are inert: the module's own `assets/js/admin.js` (the only file that binds `$("#et_sort tbody").sortable(...)`) is never registered by `OphTrIntravitrealinjection/controllers/AdminController.php`, which registers `/js/oeadmin/OpenEyes.admin.js` at `:26` and `/js/oeadmin/list.js` at `:172` and nothing else. Reordering therefore works only on the subset of `#et_sort` screens that also load a script binding it.
- **Route**: any admin lookup screen whose model has a `display_order` column, for example `/OphTrIntravitrealinjection/admin/viewAntiSepticDrugs` (widget family) or an ExaminationAdmin lookup rendered through `admin/generic/list`
- **Repro**:
  1. Open an admin lookup screen that shows an **Order** column with an up/down arrow glyph against each row.
  2. Try to drag a row to a new position, and try clicking the arrows.
  3. Save the page and reload it.
- **Expected**: the row moves and the new order persists, as it does on the screens built round `#et_sort` (Worklist Definitions, Letter Macros, Dispense Locations and similar).
- **Actual**: on the widget family nothing responds to the drag at all; on the newer generic-list family the row drags but the drop raises a JavaScript error and the order is unchanged after reload. The arrow glyph is not a control in either case - nothing in the JavaScript tree binds a click handler to `.reorder` or to the glyph, so it is only ever a drag affordance.
- **Evidence**: `list.js`, `OpenEyes.admin.js`, `generic_admin.php`, `GenericAdmin.php`, `admin/generic/list.php` and `_generic_admin_row.php` all read in the container at `53b077c089`. `grep -rn "sortable(" protected/assets/js/` returns three call sites only (`admin.js:75,76` for an unrelated two-list widget, and `list.js:21`); `grep -rn "et_sort" --include=*.php protected/` returns the fifteen bespoke screens and none of the generic views. `Admin.saveSorted` is defined once, and its first statement is the unguarded `querySelector`.
- **Severity**: medium - display order determines the sequence options appear in on clinical forms, and administrators are given a control that looks operable and is not. There is no error message on the widget family and only a console error on the other, so the failure is silent. Widespread: it affects every `genericAdmin()` lookup screen with a `display_order` column, which is most of the admin lookup tables.
- **Status**: open. Found while documenting the Intravitreal injection admin screens. **Corpus impact**: about 30 documentation pages currently instruct the reader to "use the up and down arrows in the Order column"; that instruction is wrong wherever the screen is one of these two generic families.
- **Correction, 2026-08-06 (failure mode 2 is wrong for the `admin/generic/list.php` family)**: the evidence above rests on `grep -rn "et_sort" --include=*.php protected/`, which only finds the id where it is written out literally. On that family the id is generated: `protected/views/admin/generic/list.php:193-203` calls `EventAction::button('Sort', 'sort', [], ['data-uri' => '/' . $uniqueid . '/sort', ...])`, and `protected/components/EventAction.php:39-45` sets `$action->htmlOptions['id'] = 'et_' . strtolower((string) $name)` when no id is supplied - so the page does carry `#et_sort` with a working `data-uri`, and `Admin.saveSorted` finds it. Reordering therefore WORKS on the whole `admin/generic/list.php` family, including Letter Macros. Failure mode 1 is unaffected: the `GenericAdmin` widget family still never initialises a sortable, because the `#generic-admin-list` / `#generic-admin-sublist` ids it binds to are not emitted there. Corpus impact is correspondingly narrower - the "use the up and down arrows" prose is wrong only on pages rendered through the widget family.
- **Second correction, 2026-08-06 (failure mode 1 holds, but only for the default `//admin/generic_admin` view)**: a reviewer reported failure mode 1 as refuted for the whole `genericAdmin()` family. It is not, but the original wording was too broad in one direction and too narrow in another. Verified at 53b077c089: `GenericAdmin.php:72` does put the `sortable` class on the table when `display_order` is set, and `list.js:19` binds `#generic-admin-list .sortable, #generic-admin-sublist .sortable` - so whether a sortable initialises depends entirely on whether the *view wrapping the widget* carries one of those two ids. `protected/views/admin/generic_admin.php`, the view `BaseAdminController::genericAdmin()` renders (`:202`, `:341`), emits only `<div class="row divider {div_wrapper_class}">` and the widget's own `<div class='{div_wrapper_class}'>` - no id at all. Every screen reached through plain `genericAdmin()` is therefore inert, and `grep -rn "genericAdmin(" --include=*.php protected/` returns 87 call sites across 32 controllers. Screens whose module supplies its own view DO carry the id and DO work: `subspecialty_subsections/index.php:20`, `worklist/definitions.php:24`, `dispense_condition/index.php:21`, `dispense_location/index.php:22` and the ExaminationAdmin `injectionmanagement/list_OphCiExamination_*.php` views each open `id="generic-admin-list"` or `id="generic-admin-sublist"` and hand-write `<table id="et_sort" data-uri="...">`, which satisfies both `list.js` and `Admin.saveSorted`. So the three families are: plain `genericAdmin()` - broken; `admin/generic/list.php` - works; bespoke views - work where the binding script is registered (the Intravitreal injection exception in the original entry still stands).
- **Second binding mechanism checked, and it does not rescue the widget family**: `protected/widgets/js/GenericAdmin.js:54` binds a sortable to `.generic-admin.sortable tbody`, and `GenericAdmin.php:72` does emit exactly those classes - so on paper the widget family could be draggable by this second route. It is not, because that file is not a globally registered asset: `grep -rn "GenericAdmin.js" --include=*.php protected/` returns six registration sites, every one of them inside a single named action (`AdminController.php:530` inside the Common Ophthalmic Disorders action, `OphCiExamination/AdminController.php:81` inside `actionViewIOPInstruments`, plus one each in OphTrConsent Extra Procedures, OphCoMessaging Message Sub Types, OphCoDocument Document Sub Types and Admin Procedure Subspecialty Assignment). None of the plain `genericAdmin()` lookup screens registers it, so no sortable of either kind initialises there. Note also that `GenericAdmin.js`'s `stop:` handler saves nothing - it only re-checks the "default" radio button. Where those six screens do reorder, it is because dragging moves the `<tr>` in the DOM and `BaseAdminController.php:234` then renumbers `display_order` from the order the rows arrive in when the administrator presses **Save**.
- **Sweep result, 2026-08-06**: the seven documentation pages that were still unchecked against this entry - `document/document-sub-type-settings.md`, `checklists/categories.md`, `disorders/common-systemic-disorders.md`, `disorders/common-systemic-disorder-groups.md`, `disorders/common-ophthalmic-disorder-groups.md`, `generic-event/assessment-specialty.md`, `worklist/definitions.md` - are all correct as written and need no change. Each of those screens supplies its own working mechanism: `editcommonsystemicdisorder.php:146` and `editcommonophthalmicdisordergroup.php:158,205` initialise their own sortable inline, `update_AssessmentSpecialty.php:244` likewise, `sub_types/index.php:23` carries `class="standard generic-admin sortable"` on a screen that does register `GenericAdmin.js` and posts `display_order` back at `DocumentSubTypesSettingsController.php:34-41`, and `worklist/definitions.php:24` wraps in `#generic-admin-list`. `checklists/categories.md:63` already states the inert case accurately - `list_OphCoChecklist_ChecklistCategories.php:58` has `tbody class="sortable"` with no binding ancestor, no `#et_sort` and no display-order column at all, which is exactly what the page says.
- **Related, same code path**: `BaseAdminController.php:234` assigns `$item->display_order = $j + 1` on every save, numbering rows from the order they arrive in the POST. Because the drag never initialises on the plain `genericAdmin()` family, that order is always the order the page rendered in, so saving the screen simply rewrites the existing sequence over itself. There is no way to reorder these lists from the interface at all.

## BUG-328: Right eye pulse duration range is validated against the left eye's value (CONFIRMED code)

- **Where**: `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php`, `rules()`. The four range rules read:
  `['left_pulse_duration_from', 'fromRangeValidation', 'toRangeAttribute' => 'left_pulse_duration_to']`,
  `['right_pulse_duration_from', 'fromRangeValidation', 'toRangeAttribute' => 'left_pulse_duration_to']`,
  `['right_pulse_duration_from', 'fromRangeValidation', 'toRangeAttribute' => 'right_pulse_duration_from']`.
- **Route**: `/OphTrLaser/default/create?patient_id=<id>` and `/OphTrLaser/default/update/<event_id>`, Treatment element, Procedure sub-element.
- **Repro**:
  1. Log in and open any patient.
  2. Press Add Event and choose Laser.
  3. On the Treatment element add a procedure for both eyes.
  4. Set the LEFT eye Pulse Duration From to 10 and To to 20.
  5. Set the RIGHT eye Pulse Duration From to 50 and To to 60 - a perfectly valid right eye range.
  6. Save.
- **Expected**: the right eye range is checked against the right eye's own To value, so 50 to 60 saves.
- **Actual**: the right eye From is checked against the LEFT eye's To (20), so a valid right eye range is rejected. The reverse also holds: a genuinely inverted right eye range (From 60, To 50) saves without complaint, because the rule that was meant to catch it compares `right_pulse_duration_from` with itself and can never fail.
- **Evidence**: the three rule lines above, read verbatim in the container at `53b077c089`. The two laser power rules immediately above them are correctly paired (`left_laser_power_from`/`left_laser_power_to`, `right_laser_power_from`/`right_laser_power_to`), which is what makes the pulse duration pair look like a copy and paste slip.
- **Severity**: medium - it both blocks valid clinical data and lets invalid data through, silently, on a treatment record.
- **Status**: open. Found while documenting the Laser event.

## BUG-329: The right eye laser energy "From" field is labelled "To" (CONFIRMED code)

- **Where**: `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php`, `attributeLabels()`: `'right_laser_power_from' => 'Right Laser Energy/Power To'` on the line immediately before `'right_laser_power_to' => 'Right Laser Energy/Power To'`.
- **Route**: `/OphTrLaser/default/create?patient_id=<id>`, Treatment element, right eye Procedure block.
- **Repro**:
  1. Open a Laser event create form for any patient.
  2. Add a procedure for the right eye.
  3. Leave the right eye Laser Energy/Power range invalid or incomplete so validation fires.
  4. Read the validation message, or read the label OpenEyes uses for that field anywhere it prints attribute labels.
- **Expected**: "Right Laser Energy/Power From".
- **Actual**: "Right Laser Energy/Power To", so two different fields carry the same name and a message about the From field appears to be about the To field. The left eye equivalents are labelled correctly.
- **Evidence**: the two label lines read verbatim in the container at `53b077c089`.
- **Severity**: low - cosmetic, but it makes a validation message point at the wrong box.
- **Status**: open. Found while documenting the Laser event.

## BUG-330: The laser procedure picker cannot see procedures already added, so the same procedure can be added twice to one eye (CONFIRMED code)

- **Where**: `protected/modules/OphTrLaser/views/default/form_Element_OphTrLaser_Treatment.php:104` filters on
  `$table.find('input[type="hidden"][name="treatment_<?= $eye_side ?>_procedures[]"][value="' + procedure_id + '"]')`
  but the rows are rendered by `form_Element_OphTrLaser_Laser_Procedure.php:32-35`, which names the hidden input
  `<?=$model_name?>[procedure_assignments][<?=$key?>][procedure_id]`.
- **Route**: `/OphTrLaser/default/create?patient_id=<id>`, Treatment element.
- **Repro**:
  1. Open a Laser event create form for any patient.
  2. Add a procedure to the right eye, for example "Laser capsulotomy".
  3. Open the procedure picker for the right eye again.
  4. Choose the same procedure a second time.
- **Expected**: the picker recognises the procedure is already in the list and does not add it again (the `alreadyUsed` check exists for exactly this).
- **Actual**: the check never matches, because no input on the page is named `treatment_right_procedures[]`. The procedure is added a second time and the eye ends up with a duplicate row, each with its own settings block.
- **Evidence**: `grep -rn "_procedures\[\]" protected/modules/OphTrLaser/` in the container at `53b077c089` returns exactly one hit, the selector itself. The only other occurrences of those two names are `Element_OphTrLaser_Treatment.php:52-53`, where they are `$errorExceptions` keys used to relabel validation errors, not input names.
- **Severity**: medium - the guard reads as working, and duplicated procedures on one eye are a data quality problem on a treatment record.
- **Status**: open. Found while documenting the Laser event.

## BUG-331: Laser procedures removed for your institution still appear on the Laser event form (CONFIRMED code/db)

- **Where**: `protected/modules/OphTrLaser/views/default/form_Element_OphTrLaser_Treatment.php:22`:
  `$lprocs = OphTrLaser_LaserProcedure::model()->with(array('procedure'))->findAll(array('order' => 'procedure.term asc'));`
  - no institution condition. The admin screen behind it is institution aware: `controllers/AdminController.php:137` removes only the institution mapping (`deleteMapping(ReferenceData::LEVEL_INSTITUTION, $institution->id)`) for a non `admin` user, and `:107-112` intends to list only the procedures mapped to the current institution.
- **Route**: admin screen `/OphTrLaser/admin/manageLaserProcedures`; event form `/OphTrLaser/default/create?patient_id=<id>`.
- **Repro**:
  1. Log in as a user who holds Laser administration but not the `admin` operation, with an institution selected.
  2. Go to Admin, Laser, Laser Procedures.
  3. Delete a procedure from the list.
  4. Open any patient, press Add Event and choose Laser.
  5. Open the procedure picker on the Treatment element.
- **Expected**: the procedure you just removed for your institution is no longer offered.
- **Actual**: it is still offered, because the event form loads every row in `ophtrlaser_laserprocedure` regardless of institution mapping.
- **Evidence**: the two source locations above, read in the container at `53b077c089`. In the sample database `SELECT COUNT(*) FROM ophtrlaser_laserprocedure` is 17 while `SELECT COUNT(*) FROM ophtrlaser_laserprocedure_institution` is 0 - so no procedure is mapped to any institution at all, and yet all 17 appear on the event form.
- **Severity**: medium - the admin screen presents itself as controlling what clinicians can pick, and it does not.
- **Status**: open. Found while documenting the Laser event.

## BUG-332: Adding a laser procedure that is already on the list creates a duplicate row (CONFIRMED code/db)

- **Where**: `protected/modules/OphTrLaser/controllers/AdminController.php:156-187`, `actionAddLaserProcedure()`: `$laser_procedure = new OphTrLaser_LaserProcedure(); $laser_procedure->procedure_id = $procedure['proc_id']; $laser_procedure->save();` with no check for an existing row. `models/OphTrLaser_LaserProcedure.php` `rules()` carries only `array('procedure_id', 'required')` and a `safe` search rule - no unique validator - and the table has no unique index on `procedure_id`.
- **Route**: `/OphTrLaser/admin/addLaserProcedure` (Admin, Laser, Laser Procedures, Add).
- **Repro**:
  1. Go to Admin, Laser, Laser Procedures.
  2. Note a procedure already on the list.
  3. Press Add, search for that same procedure and select it.
  4. Save.
  5. Return to the list.
- **Expected**: either the procedure is refused as already present, or the existing row is reused and only the institution mapping is added.
- **Actual**: a second row is created for the same procedure. The list then shows the procedure twice, and so does the picker on the Laser event form.
- **Evidence**: the action and the model rules read in the container at `53b077c089`. The sample database already contains the result: `SELECT procedure_id, COUNT(*) FROM ophtrlaser_laserprocedure GROUP BY procedure_id HAVING COUNT(*) > 1` returns procedure_id 177 with 2 rows.
- **Severity**: low to medium - no data is lost, but the list and the clinician facing picker both show duplicates, and deleting "the" procedure only removes one of them.
- **Status**: open. Found while documenting the Laser event.

## BUG-333: The Laser event's selection hint is never displayed (CONFIRMED code)

- **Where**: `protected/modules/OphTrLaser/assets/js/module.js:106` (`$("#laser_select_hint").slideDown("fast")`) and `:199` (`$("#laser_select_hint").slideUp("fast")`).
- **Route**: `/OphTrLaser/default/create?patient_id=<id>`, Treatment element.
- **Repro**:
  1. Open a Laser event create form.
  2. Perform the gesture the hint is written for - open the procedure picker and make a selection.
  3. Watch for the hint text.
- **Expected**: a hint slides into view, since two separate places in the module's JavaScript are written to show and hide one.
- **Actual**: nothing appears. jQuery matches nothing, both calls are no-ops, and no error is raised.
- **Evidence**: `grep -rn "laser_select_hint" protected/ assets/` in the container at `53b077c089` returns those two JavaScript lines and nothing else - no view, partial or layout renders an element with that id.
- **Severity**: trivial - a piece of on-screen guidance the module was built to give and does not.
- **Status**: open. Found while documenting the Laser event.

## BUG-334: The DNA withdrawal editing permission is computed and then thrown away (CONFIRMED code)

- **Where**: `protected/modules/OphInDnaextraction/views/default/form_Element_OphInDnaextraction_DnaTests.php`, in both render branches. Each does `$disabled = !$this->checkAccess('TaskEditGeneticsWithdrawals');` and then, on the very next line, `renderPartial(... '_dna_test', array('transaction' => $transaction, 'i' => $i, 'disabled' => ($this->action->id === 'view')))` - the `$disabled` it just worked out is never passed.
- **Route**: `/OphInDnaextraction/default/update/<event_id>`, DNA Withdrawals element.
- **Repro**:
  1. Grant a user a role carrying `OprnEditDNAExtraction` but not `OprnEditGeneticsWithdrawals`.
  2. Log in as that user and open a DNA extraction event.
  3. Press **Edit**.
  4. Look at the rows under **DNA Withdrawals**.
- **Expected**: the withdrawal rows are read-only, which is what the permission and the computed flag are for.
- **Actual**: every field is editable and each row keeps its **(remove)** link. The only thing that ever disables the rows is being on the View screen, which is not a permission at all.
- **Evidence**: the two identical `$disabled = ...` / `renderPartial(...)` pairs read verbatim in the container at `53b077c089`. `$disabled` appears nowhere else in the file, and the partial keys its inputs and its remove link off the value it is passed.
- **Severity**: medium - a permission that exists, is named on a task and is checked at the right moment, yet governs nothing.
- **Status**: open. Found while documenting the DNA extraction event.

## BUG-335: Genomic Coordinate is a five-character field with no limit on screen, so an ordinary coordinate fails the save (CONFIRMED code/db)

- **Where**: `et_ophingeneticresults_test.genomic_coordinate` is `varchar(5)`. `protected/modules/OphInGeneticresults/models/Element_OphInGeneticresults_Test.php:56` lists `genomic_coordinate` in the `safe` rule only - there is no length validator - and `views/default/form_Element_OphInGeneticresults_Test.php:115` renders it with `CHtml::activeTextField($element, 'genomic_coordinate', ['class' => 'cols-full'])`, which derives `maxlength` from a string validator and so emits none.
- **Route**: `/OphInGeneticresults/default/create?patient_id=<id>`, Test element.
- **Repro**:
  1. Open a patient and add a Genetic Results event.
  2. Fill Gene, Method, Effect and Result.
  3. Type a normal genomic coordinate into **Genomic Coordinate**, for example `chr17:43094464`.
  4. Save.
- **Expected**: either the field stops accepting text at its limit, or a validation message names the limit.
- **Actual**: the field accepts as much text as you type, gives no warning, and the save is rejected by the database rather than by the form.
- **Evidence**: `SHOW COLUMNS FROM et_ophingeneticresults_test LIKE 'genomic_coordinate'` returns `varchar(5)`; `SELECT @@sql_mode` returns `STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION`, so an over-length value is an error rather than a silent truncation. Model rules and view read in the container at `53b077c089`.
- **Severity**: medium - the field is unusable for the values it is named for, and it fails at the database rather than on the form.
- **Status**: open. Found while documenting the Genetic Results event. The exact database error was not exercised, only derived from the column type and `sql_mode`.

## BUG-336: The "no future dates" limit on Dna date and Extracted Date never takes effect (CONFIRMED code)

- **Where**: two separate faults with the same visible result.
  1. `protected/modules/OphInDnasample/views/default/form_Element_OphInDnasample_Sample.php` passes `array('options' => array('maxDate' => 'today'))` as the widget's `$options`, one level too deep - `BaseEventTypeCActiveForm::datePicker()` (`protected/components/BaseEventTypeCActiveForm.php:241-251`) hands that array straight through as `options`, so `protected/widgets/views/DatePicker.php:53` reads `@$options['maxDate']` as unset and emits `max: ''`.
  2. `protected/modules/OphInDnaextraction/views/default/form_Element_OphInDnaextraction_DnaExtraction.php:51` passes the right shape, `array('maxDate' => 'today')`, but the literal string `today` is emitted straight into the picker: `DatePicker.php:53` is `max: '<?= @$options['maxDate'] ?>'`, with no conversion. The `minDate` branch two lines below it does convert, `min: <?= $options['minDate'] === 'today' ? 'new Date()' : ... ?>` - so the max side is simply missing that translation.
- **Route**: `/OphInDnasample/default/create?patient_id=<id>` and `/OphInDnaextraction/default/create?...`.
- **Repro**:
  1. Open a DNA sample or DNA extraction create form.
  2. Open the date picker on **Dna date** (or **Extracted Date**) and page forward past this month.
  3. Choose a date next year.
  4. Save.
- **Expected**: the picker refuses future dates, which is plainly what the `maxDate` argument is there to do.
- **Actual**: future dates are selectable and save without complaint. Neither model validates the date either.
- **Evidence**: the two form lines, the `datePicker()` helper and `DatePicker.php:53-56` read in the container at `53b077c089`; `grep -n "today" node_modules/pickmeup/js/pickmeup.js` returns only the library's own internal today-highlighting variable, so nothing downstream turns the string into a date.
- **Severity**: low - the fields are pre-filled with today and are rarely wrong in practice, but the guard the forms ask for is not applied on either event.
- **Status**: open. Found while documenting the DNA sample and DNA extraction events. Related: both fields are also silently pre-filled with today by `DatePicker::run()` when the value is empty, so an untouched form records today rather than staying blank.

## BUG-337: Typo in the Genetic Results Exon validation message (CONFIRMED code)

- **Where**: `protected/modules/OphInGeneticresults/models/Element_OphInGeneticresults_Test.php:161`: `$this->addError($attribute, 'This is required when then method is set to ' . $params['method']);`
- **Route**: `/OphInGeneticresults/default/create?patient_id=<id>`, Test element.
- **Repro**:
  1. Add a Genetic Results event.
  2. Set **Method** to Sanger.
  3. Leave **Exon** blank.
  4. Save.
- **Expected**: "This is required when the method is set to Sanger".
- **Actual**: "This is required when then method is set to Sanger".
- **Evidence**: the line read verbatim in the container at `53b077c089`.
- **Severity**: trivial.
- **Status**: open. Found while documenting the Genetic Results event.

## BUG-338: A newly granted role does not change the Add Event dialog for up to an hour (CONFIRMED code)

- **Where**: `protected/views/patient/add_new_event.php:112-114`. The whole event-type list is wrapped in `beginCache('add_event_dialog_event_type_list', ['duration' => 3600, 'varyByRoute' => false, 'varyBySession' => true])`, and the per-event-type `checkAccess()` calls that decide what is listed sit inside that cache block.
- **Route**: `/admin/editUser?id=<user_id>` to grant, then `/patient/summary/<patient_id>` and **Add Event**.
- **Repro**:
  1. Log in as a user and open a patient, press **Add Event** and note which event types are offered.
  2. In another browser, as an administrator, go to Admin, Users, open that user and tick a role that carries create rights for an event type they did not have - a genetics role is the clearest example.
  3. Save.
  4. Back in the first browser, without logging out, open the patient again and press **Add Event**.
- **Expected**: the newly permitted event type is now listed.
- **Actual**: the list is unchanged, and stays unchanged for up to an hour. The reverse also holds - a role that has just been removed keeps its event types on offer, and the user gets a refusal only after picking one.
- **Evidence**: the `beginCache` call read in the container at `53b077c089`; the cache key does not vary by user permissions, only by session, so the entry survives every reload within the session. Logging out and back in starts a new session and rebuilds the list, which is the practical workaround.
- **Severity**: medium - it makes permission changes look like they have not worked, and it is the single most likely reason an administrator reports that granting a role "did nothing". It also means a withdrawn permission is not enforced at the point it is displayed.
- **Status**: open. Found while writing the genetics demo-data recipes, where a role grant is a prerequisite.

## BUG-339: Lens Status on an injection is overwritten from the examination every time the form renders (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/views/default/form_Element_OphTrIntravitrealinjection_AnteriorSegment_OEEyeDraw_fields.php:22` calls `$element->setDefaultOption($this->patient)` unconditionally, on create and on update alike. `models/Element_OphTrIntravitrealinjection_AnteriorSegment.php` `setDefaultOption()` then assigns both `right_lens_status_id` and `left_lens_status_id` from the patient's latest Examination anterior segment element, with no guard on the action and no check for a value already set.
- **Route**: `/OphTrIntravitrealinjection/default/update/<event_id>`, Anterior Segment element.
- **Repro**:
  1. Open a patient who has an Examination carrying an anterior segment element.
  2. Create or edit an Intravitreal injection event for them.
  3. On **Anterior Segment**, change **Lens Status** by hand to something other than what the examination implies.
  4. Trigger a validation error elsewhere on the form, or save and press **Edit** again.
  5. Look at Lens Status.
- **Expected**: the value you chose is kept.
- **Actual**: it is silently replaced by the value derived from the examination. Nothing on screen says the field was changed for you.
- **Evidence**: the call site and the method read verbatim in the container at `53b077c089`. `setDefaultOption()` returns early only when the patient has no examination anterior segment element at all; otherwise it always assigns. The InVitria default in the same file is guarded against re-running on update, which is what makes the missing guard here look accidental.
- **Severity**: high - a clinical field silently reverts, and the reversion happens exactly when the user is re-editing after an error, which is when they are least likely to re-check it.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-340: Lens Status defaults to Aphakic when the examination says nothing about the lens (CONFIRMED code)

- **Where**: `protected/components/BaseAPI.php` `getAnteriorSegmentStatus()`: returns `'Phakic'` if a phakic lens doodle is present, `'Pseudophakic'` if any IOL doodle is present, and falls through to `return 'Aphakic';` otherwise. There is no unknown or not-recorded case.
- **Route**: `/OphTrIntravitrealinjection/default/create?patient_id=<id>`, Anterior Segment element.
- **Repro**:
  1. Record an Examination whose anterior segment diagram carries neither a phakic lens nor an IOL doodle - for example one drawn only for cornea findings.
  2. Create an Intravitreal injection event for that patient.
  3. Read **Lens Status**.
- **Expected**: the field stays on "Select", since the examination does not say.
- **Actual**: it is pre-filled **Aphakic**, asserting a clinically significant finding that nobody recorded. Combined with BUG-339, a corrected value does not survive.
- **Evidence**: the method read verbatim in the container at `53b077c089`; the return type is `string`, so there is no null path available to it as written.
- **Severity**: medium.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-341: The saved injection shows an instruction where the IOP answer should be (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/views/default/view_Element_OphTrIntravitrealinjection_PostInjectionExamination_fields.php:20-35`. The row is labelled with the literal text `IOP:` and its value cell branches on `$element->{$side . '_iop_check'}` to print either "IOP should be checked" (plus "- Please add a Phasing event." when the Phasing module is present) or "IOP does not need to be checked." The recorded answer is never printed.
- **Route**: `/OphTrIntravitrealinjection/default/view/<event_id>`, Post Injection Examination element.
- **Repro**:
  1. Create an Intravitreal injection event and record **IOP Checked?** = Yes on one eye.
  2. Save.
  3. Read the Post Injection Examination section on the saved event.
- **Expected**: "IOP Checked?: Yes" - the model even defines that label, `left_iop_check => 'IOP Checked?'`.
- **Actual**: "IOP: IOP should be checked - Please add a Phasing event." The reader cannot tell from the saved event whether the IOP was checked; they are told what someone ought to do next.
- **Evidence**: the view rows and `models/Element_OphTrIntravitrealinjection_PostInjectionExamination.php` `attributeLabels()` read in the container at `53b077c089`. Every other row in the same table reads its value back normally.
- **Severity**: medium - a recorded clinical answer is not readable on the record it was recorded on.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-342: Two Post Injection Examination fields are labelled with machine-generated names (CONFIRMED code)

- **Where**: two attribute names that `attributeLabels()` does not define.
  1. `view_Element_OphTrIntravitrealinjection_PostInjectionExamination_fields.php:40` asks for `getAttributeLabel($side . '_iop_instrument')` while the label is defined on `left_iop_instrument_id` / `right_iop_instrument_id` ("IOP instrument").
  2. `form_Element_OphTrIntravitrealinjection_PostInjectionExamination_fields.php:66` asks for `getAttributeLabel($side . '_paracentesis_given_by')` while the label is defined on `left_paracentesis_performed_by` / `right_paracentesis_performed_by` ("Paracentesis Performed By?").
- **Route**: `/OphTrIntravitrealinjection/default/view/<event_id>` and `.../update/<event_id>`.
- **Repro**:
  1. View a saved injection event whose Post Injection Examination records an IOP instrument - the row reads "Left Iop Instrument".
  2. Edit an injection event and set **Paracentesis Performed?** to Yes - the row that opens reads "Left Paracentesis Given By".
- **Expected**: "IOP instrument" and "Paracentesis Performed By?", the labels the model already defines.
- **Actual**: Yii falls back to `generateAttributeLabel()` and prints the attribute name in title case, side included.
- **Evidence**: the two view lines and the model's `attributeLabels()` read in the container at `53b077c089`.
- **Severity**: low - cosmetic, but visible on both the form and the saved event, and the correct wording exists three lines away.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-343: The saved injection hides whether a paracentesis was performed while still naming who performed it (CONFIRMED code)

- **Where**: `view_Element_OphTrIntravitrealinjection_PostInjectionExamination_fields.php`. The **Paracentesis Performed?** row carries `<tr <?php echo $element->{$side . '_finger_count'} || $element->{$side . '_cra_perfused'} ? 'style="display:none;"' : '' ?>>`, so it is hidden whenever the patient could count fingers or the CRA was perfused. The **Paracentesis Performed By?** row below it is guarded only by `if ($element->{$side . '_paracentesis_performed_by'})` and has no such condition.
- **Route**: `/OphTrIntravitrealinjection/default/view/<event_id>`.
- **Repro**:
  1. Create an injection event; on Post Injection Examination record **Patient could count fingers?** = Yes and **Paracentesis Performed?** = Yes, naming who performed it.
  2. Save.
  3. Read the Post Injection Examination section.
- **Expected**: both rows show, or neither does.
- **Actual**: the answer row is hidden and the performer row is shown, so the record names a person against a procedure it does not admit happened.
- **Evidence**: the two rows read verbatim in the container at `53b077c089`.
- **Severity**: medium.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-344: Two rows labelled "Doctor & Injector Communication" in the same Injection Management table (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/widgets/views/InjectionManagementElementWidget_event_edit.php:223` renders an editable `activeTextArea` for `{$eye_side}_ivt_procedural_considerations` under that caption; `:261`, inside the same `elseif ($current_sequence)` branch with no intervening branch close, renders `<td>Doctor & Injector Communication</td><td><?= $ivt_procedural_considerations ?></td>` as read-only text.
- **Route**: `/OphTrIntravitrealinjection/default/create?patient_id=<id>`, Injection Management element, for an eye with an active sequence.
- **Repro**:
  1. Open an injection event for a patient with an active injection sequence on one eye.
  2. Read the details table under that eye.
- **Expected**: one row per field.
- **Actual**: the same caption appears twice, once as an editable box and once as text, with no indication which is which.
- **Evidence**: both rows read in the container at `53b077c089`, with the branch structure between them checked - the only `if` opened between the two is closed before the second row.
- **Severity**: low.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-345: Consent Option is demanded for an unbooked injection even when its row is switched off (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/controllers/DefaultController.php:395-405` loops `foreach (['diagnosis_id' => true, 'followup_id' => true, 'consent_option_id' => false] as $attribute => $has_mandatory_setting)`. The two attributes flagged `true` consult their `injection_unbooked_<attribute>_mandatory` setting first; `consent_option_id` is flagged `false` and so falls to `elseif (!$id)`, which raises the error unconditionally. The field it demands is rendered only inside `if ($is_consent_column_enabled)` at `views/default/_treatment_sequence_additional.php:99`, where `$is_consent_column_enabled` comes from `SettingMetadata::model()->getSetting('enable_injection_management_order_consent_column') === 'on'` at `:25`.
- **Route**: `/OphTrIntravitrealinjection/default/create?patient_id=<id>` with an eye set to Unbooked injection.
- **Repro**:
  1. In Admin, System Settings, switch **enable_injection_management_order_consent_column** off.
  2. Open a patient and add an Intravitreal injection event.
  3. On Injection Management set one eye's action to **Unbooked injection**.
  4. Fill everything the form shows and press **Save**.
- **Expected**: no consent requirement, because the field is not on the screen.
- **Actual**: the save is refused with "Consent Option must be selected for Unbooked injection", and there is no control anywhere on the form that can satisfy it. The event cannot be saved at all.
- **Evidence**: the validation loop, `addErrorForUnbookedSequenceAttribute()` at `:930` and the view guard read in the container at `53b077c089`.
- **Severity**: high - on an installation with that column off, unbooked injections cannot be recorded, and the error names a field the user cannot see.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-346: The injection optom letter setting is stored under a key nothing reads (CONFIRMED code/db)

- **Where**: `protected/modules/OphTrIntravitrealinjection/migrations/m200908_095620_add_default_letter_settings.php:52` creates the setting with the key `'default_optom_letter' . $event_type_name` - no separating underscore. `protected/widgets/EventAutoGenerateCheckboxesWidget.php:81` and `protected/behaviors/CreateEventsAfterEventSavedBehavior.php:194` both read `'default_optom_letter_' . $suffix`.
- **Route**: Admin, System Settings ("Default Injection Optom Letter name"); then `/OphTrIntravitrealinjection/default/create?patient_id=<id>`, the "Generate the following:" row.
- **Repro**:
  1. In Admin, System Settings, set **Default Injection Optom Letter name** to the name of a letter macro available in your context, and leave **Auto generate Optom letter after injection** on.
  2. Open a patient and add an Intravitreal injection event, setting one eye to Inject so the row appears.
  3. Look for an "Optom letter (standard)" checkbox in **Generate the following:**.
  4. Save the event and check whether an optom letter was created.
- **Expected**: the checkbox appears and a letter is generated, as it does for an Operation Note.
- **Actual**: only the GP letter and prescription boxes are ever drawn, and no optom letter is generated. The setting is editable in Admin and has a shipped default of "Community Optom", so it looks configured and working.
- **Evidence**: `SELECT * FROM setting_metadata WHERE name LIKE '%Optom%'` returns the key `default_optom_letterophtrintravitrealinjection`, while the Operation Note equivalent is correctly `default_optom_letter_ophtroperationnote`. `SettingMetadata::getSetting()` returns `false` for an unknown key and `OphCoCorrespondence_API::getDefaultMacro()` returns null on a falsy macro name, so `$optom_macro` is always null and the widget's `if ($optom_macro)` block never renders.
- **Severity**: medium - an advertised, on-by-default feature is dead, and the failure is entirely silent.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-347: Injection Comments are printed raw on the saved event (CONFIRMED code)

- **Where**: `protected/modules/OphTrIntravitrealinjection/views/default/view_Element_OphTrIntravitrealinjection_Comments.php:19`: `<div class="data-value"><?php echo $element->comments ?></div>` - a bare echo, with neither `Yii::app()->format->Ntext()` nor `CHtml::encode()`.
- **Route**: `/OphTrIntravitrealinjection/default/view/<event_id>`, Comments element.
- **Repro**:
  1. Create an Intravitreal injection event and type a Comments entry spanning two lines.
  2. Save.
  3. Read the Comments section on the saved event.
- **Expected**: the line break is preserved, as it is in the same module's Complications view.
- **Actual**: the lines run together. Anything that looks like markup is emitted into the page rather than shown as typed.
- **Evidence**: the view line read in the container at `53b077c089`; `view_Element_OphTrIntravitrealinjection_Complications_fields.php:48` uses `Ntext` for the equivalent free-text field. Nothing purifies the value on the way in.
- **Severity**: medium - the formatting loss is certain and everyday; the markup handling was not exercised, only the absence of escaping on the way out and of purification on the way in.
- **Status**: open. Found while documenting the Intravitreal injection event.

## BUG-348: A letter contact rule can never be given a parent - the "Parent rule" dropdown is bound to the wrong field (CONFIRMED code/db)

- **Where**: `protected/modules/OphTrOperationbooking/views/admin/letter_contact_rule/edit.php:42-56`. The first row is captioned with `getAttributeLabel('parent_rule_id')` but its `activeDropDownList` is bound to `rule_order`; the next row renders a text field bound to `rule_order` as well. Both post `OphTrOperationbooking_Letter_Contact_Rule[rule_order]`, and the later one wins, so the dropdown's value is discarded and `parent_rule_id` is never posted at all. The equivalent waiting-list form, `views/admin/waiting_list_contact_rules/edit.php:47-55`, binds `parent_rule_id` correctly.
- **Route**: Admin > Operation booking > Letter contact rules > open a rule.
- **Repro**:
  1. Go to Admin > Operation booking > Letter contact rules.
  2. Open any rule.
  3. Set **Parent rule** to another rule.
  4. Press **Save**.
  5. Re-open the rule, or look at the tree on the list screen.
- **Expected**: the rule becomes a child of the rule you picked.
- **Actual**: nothing changes. The tree can only ever be built by writing `parent_rule_id` directly in the database.
- **Evidence**: both view files read in the container at `53b077c089`. The sample database already holds 13 parented rules out of 19 in `ophtroperationbooking_letter_contact_rule`, so the hierarchy is clearly meant to be used - it just cannot be maintained from the screen that shows it.
- **Severity**: medium - a documented feature of the screen does nothing, silently.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-349: Contact and warning rules are evaluated in an undefined order, not the order the admin screen shows (CONFIRMED code/db)

- **Where**: `OphTrOperationbooking_Letter_Contact_Rule::parse()` (`:157-164`) walks `$this->children`, and the relation is declared `'children' => array(self::HAS_MANY, ..., 'parent_rule_id')` at `:89` with no `order`. The same shape is in `OphTrOperationbooking_Waiting_List_Contact_Rule` (`:153-162`) and `OphTrOperationbooking_Admission_Letter_Warning_Rule`. Only the top-level lookup is ordered - `Element_OphTrOperationbooking_Operation::getWaitingListContact()` sets `$criteria->order = 'rule_order asc'` before `findAll()`, but nothing orders the descent through the children.
- **Route**: Admin > Operation booking > Letter contact rules (and Waiting list contact rules); the effect shows on an admission letter.
- **Repro**:
  1. Give one parent rule two children whose conditions could both match the same booking - for example one with a theatre set and one with nothing set.
  2. Set their **Rule order** to 1 and 2.
  3. Book an operation that matches both.
  4. Generate the admission letter and read the contact it used.
- **Expected**: the child with rule order 1 wins, which is what the tree on the admin screen implies.
- **Actual**: whichever row the database happens to return first wins. The order can change when rows are edited, so the same booking can produce different contacts at different times.
- **Evidence**: the relation declarations and both `parse()` methods read in the container at `53b077c089`; 13 of the 19 seeded letter contact rules are children, so the descent runs in practice.
- **Severity**: medium.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-350: The Child/Adult dimension on contact rules cannot be set, and the letter test always assumes an adult (CONFIRMED code/db)

- **Where**: `is_child` is a real column on both `ophtroperationbooking_letter_contact_rule` and `ophtroperationbooking_waiting_list_contact_rule`, both models compare on it in `applies()`, and both render it in the tree via `getIs_child_TreeText()` ("Child" / "Adult"). Neither edit form offers the field: `views/admin/letter_contact_rule/edit.php:56-61` lists only site, firm, subspecialty and theatre; `views/admin/waiting_list_contact_rules/edit.php:65-69` only site, firm and service. On top of that `AdminController::actionTestLetterContactRules()` (`:247-268`) hard-codes `false` for `$is_child` in both the `applies()` and `parse()` calls, and the letter-contact Test panel (`views/admin/letter_contact_rule/index.php:29-34`) has no Child/Adult control to pass one.
- **Route**: Admin > Operation booking > Letter contact rules; Admin > Operation booking > Waiting list contact rules.
- **Repro**:
  1. Open a letter contact rule and look for a Child/Adult field.
  2. Look at the rule tree on the list screen, which labels rules "Child" or "Adult".
  3. Use the **Test** panel and look for a Child/Adult selector.
- **Expected**: a rule dimension the screen displays can be set on the screen, and the test can exercise it.
- **Actual**: it can only be set by writing to the database. The letter test always answers as though the patient were an adult, so a Child rule can never be shown to match. The waiting-list Test panel does have the selector (`views/admin/waiting_list_contact_rules/index.php:33`), which is what makes the omission look accidental rather than deliberate.
- **Evidence**: both edit views, both index views and the test action read in the container at `53b077c089`. Both rule tables currently hold zero rows with `is_child` set, which is consistent with the field being unreachable.
- **Severity**: low-medium - no live rule is affected today, because none can be created.
- **Status**: open. Found while documenting Admin > Operation booking. See also BUG-351.

## BUG-351: The waiting-list contact rule Test gives an answer the booking would not (CONFIRMED code)

- **Where**: `AdminController::actionTestWaitingListContactRules()` (`:490-513`) builds a criteria carrying only `parent_rule_id is null` and `rule_order asc`, while the runtime lookup `Element_OphTrOperationbooking_Operation::getWaitingListContact()` (`:1414-1420`) additionally joins `institutions` and filters `institutions_institutions.institution_id` to the selected institution. Separately, `OphTrOperationbooking_Waiting_List_Contact_Rule::applies()` (`:142-151`) compares with `!==`, while the Test passes the posted string from the Child/Adult dropdown and the booking passes `$this->getPatient()->isChild()`, a PHP boolean - so a rule with `is_child` set matches in the Test and never matches in a booking. The letter-contact twin uses loose `!=` and is not affected.
- **Route**: Admin > Operation booking > Waiting list contact rules, the **Test** panel.
- **Repro**:
  1. Create a waiting-list contact rule and map it to a different institution from the one you are logged in to.
  2. Use the **Test** panel with values that match it.
  3. Then open an operation booking that matches the same values and read the waiting list contact on the admission letter.
- **Expected**: the Test tells you what the booking will do.
- **Actual**: the Test can name a rule the booking will never reach, because the Test ignores the institution mapping. The same disagreement appears for Child/Adult, for a different reason.
- **Evidence**: both criteria and both `applies()` implementations read in the container at `53b077c089`. `ophtroperationbooking_waiting_list_contact_rule` currently holds no rows, so nothing is misbehaving in this database yet - the defect is in the tool an administrator would use as soon as they created one.
- **Severity**: medium - the Test panel exists to give confidence, and it gives false confidence.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-352: An operation name rule always needs a theatre, so the fallback the code looks for can never exist (CONFIRMED code/db)

- **Where**: `OphTrOperationbooking_Operation_Name_Rule::rules()` (`:59-65`) makes `theatre_id` and `name` both required, and the admin form is the only way to create one. But `Element_OphTrOperationbooking_Operation::getTextOperationName()` (`:1438-1445`) looks the rule up by the booked session's theatre and, failing that, falls back to `find('theatre_id is null')` - a row the application will not let you create.
- **Route**: Admin > Operation booking > Operation name rules > **Add**.
- **Repro**:
  1. Go to Admin > Operation booking > Operation name rules.
  2. Press **Add**, type a name and leave **Theatre** unset.
  3. Press **Save**.
- **Expected**: a default rule that covers theatres with no rule of their own, which is what the second lookup in the code is for.
- **Actual**: the save is refused, "Theatre cannot be blank". A booking in an unruled theatre - or one not yet scheduled - falls through both lookups and gets no operation name at all.
- **Evidence**: the model rules and the lookup read in the container at `53b077c089`. `ophtroperationbooking_operation_name_rule` holds zero rows in this database, so every booking currently takes the fall-through path.
- **Severity**: medium.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-353: Dragging session unavailable reasons into order changes nothing on the admin list (CONFIRMED code)

- **Where**: `views/admin/sessionunavailablereasons.php:36-38` composes a `CDbCriteria` ordered by `display_order asc` and then calls `OphTrOperationbooking_Operation_Session_UnavailableReason::model()->findAll()` with no argument, so the criteria is discarded. Unlike its patient-side twin, that model declares no `defaultScope`, so nothing else supplies the ordering. `AdminController::actionSortSessionUnavailableReasons()` (`:2029-2043`) does save the new `display_order` values correctly. The same build-then-discard shape is in `views/admin/name_rule/index.php` and `views/admin/erod_rule/index.php`.
- **Route**: Admin > Operation booking > Session unavailable reasons.
- **Repro**:
  1. Go to Admin > Operation booking > Session unavailable reasons.
  2. Drag the bottom reason to the top.
  3. Reload the page.
- **Expected**: the list shows the order you set.
- **Actual**: the list is back as it was. The order was saved - the dropdown on a session reflects it - but the screen you set it on never shows it, so it looks as though the drag did not take.
- **Evidence**: the view, the sort action and the model read in the container at `53b077c089`; `OphTrOperationbooking_ScheduleOperation_PatientUnavailableReason` does declare a `defaultScope` on `display_order` (`:71-74`), which is why the patient list behaves correctly and the session one does not.
- **Severity**: low.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-354: Adding a patient unavailable reason without installation admin throws an exception page, while editing the same list is unguarded (CONFIRMED code)

- **Where**: `AdminController::actionAddPatientUnavailableReason()` (`:1863-1876`) wraps the save in `if ($this->checkAccess('admin'))` and otherwise `throw new Exception('User is not an installation level admin')`. `actionEditPatientUnavailableReason()` (`:1832-1845`), `actionSortPatientUnavailableReasons()` and both session equivalents carry no such check.
- **Route**: `/OphTrOperationbooking/admin/viewPatientUnavailableReasons`.
- **Repro**:
  1. Log in as an institution administrator who does not hold the installation-level `admin` role.
  2. Open Admin > Operation booking > Patient unavailable reasons.
  3. Press **Add**, fill in a name and press **Save**.
- **Expected**: either the Add control is not offered, or the save is refused with a message.
- **Actual**: a raw exception page reading "User is not an installation level admin". Editing an existing reason and dragging the list into a new order on the same screen both work for the same user, so the restriction is neither consistent nor explained.
- **Severity**: medium - a permission boundary presented as a crash, and enforced on only one of the three ways to change the list.
- **Evidence**: all four actions read in the container at `53b077c089`.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-355: Deleting a pre-assessment type or location throws, and takes the whole save with it (CONFIRMED code/db)

- **Where**: `OphTrOperationbooking_PreAssessment_Type` and `OphTrOperationbooking_PreAssessment_Location` both extend `BaseActiveRecordVersionedSoftDelete` without declaring `notDeletedField`, so `delete()` (`models/BaseActiveRecordVersionedSoftDelete.php:22-31`) assigns `$this->deleted = 1`. Neither `ophtroperationbooking_preassessment_type` nor `ophtroperationbooking_preassessment_location` has a `deleted` column, so Yii raises "Property ... .deleted is not defined". The generic delete loop `protected/controllers/BaseAdminController.php:296-303` handles only a `false` return, not an exception, and the exception escapes before `$tx->commit()`.
- **Route**: Admin > Operation booking > Pre-assessment Types; Admin > Operation booking > Pre-assessment Locations.
- **Repro**:
  1. Go to Admin > Operation booking > Pre-assessment Locations.
  2. Untick **Active** on any location and press **Save**.
  3. Press the **delete** link that now appears on that row.
  4. Make an unrelated change to another row - rename it, say.
  5. Press **Save**.
- **Expected**: the row goes, or a message explains why it cannot.
- **Actual**: an exception page, `Property "OphTrOperationbooking_PreAssessment_Location.deleted" is not defined`. Because the transaction never commits, the unrelated rename in step 4 is lost too. Clearing a row's **Name** reaches the same code by a different route and fails the same way.
- **Evidence**: both models, the base class and the delete loop read in the container at `53b077c089`; `SHOW COLUMNS` on both tables confirms there is no `deleted` column (id, name, [site_id], active, and the audit columns only).
- **Severity**: high - a control the screen offers produces a crash and silently discards other unsaved work on the same screen.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-356: An operation priority can never be removed, and the attempt reports success (CONFIRMED code)

- **Where**: `OphTrOperationbooking_Operation_Priority` declares `notDeletedField = 'active'` (`:40`), so `BaseActiveRecordVersionedSoftDelete::delete()` only sets `active = 0`. The generic admin row shows the **delete** link only once a row is already inactive (`protected/widgets/views/_generic_admin_row.php:84`, with `active_prevents_delete` defaulting to true at `protected/widgets/GenericAdmin.php:26`), and the listing query `protected/controllers/BaseAdminController.php:336-337` applies no active filter, while the model's `defaultScope` (`:60-63`) only orders. So the delete acts on a row that is already deactivated and leaves it exactly where it was.
- **Route**: Admin > Operation booking > Operation priorities.
- **Repro**:
  1. Go to Admin > Operation booking > Operation priorities.
  2. Untick **Active** on a priority and press **Save**.
  3. Press the **delete** link that appears on that row, then press **Save**.
- **Expected**: the row is removed, or the control is not offered.
- **Actual**: "List updated." and the row is still there, still inactive. There is no way to remove a priority through the screen.
- **Evidence**: the model, the base class, the row partial and the listing query read in the container at `53b077c089`.
- **Severity**: low - the outcome (retired, not removed) is defensible; the control and the success message are not. This shape applies to every generic admin screen whose model uses `notDeletedField = 'active'`.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-357: The whiteboard refresh setting is saved where nothing reads it (CONFIRMED code/db)

- **Where**: `modules/OphTrOperationbooking/controllers/oeadmin/WhiteboardSettingsController.php:33-60` writes the value into `ophtroperationbooking_whiteboard_settings_data` under the key `refresh_after_opbooking_completed`. The only consumer, `modules/OphTrOperationbooking/controllers/WhiteboardController.php:124-131`, reads `Yii::app()->params['refresh_after_opbooking_completed']` instead - and that parameter is defined nowhere. It appears only commented out, at `protected/config/core/common.php:875` and `modules/OphTrOperationbooking/config/common.php:101`, both nested under a `whiteboard` key rather than at the top of `params`, and both carrying a comment claiming they "override admin > Opbooking > whiteboard settings".
- **Route**: Admin > Operation booking > Whiteboard settings; then a whiteboard for a completed booking.
- **Repro**:
  1. Go to Admin > Operation booking > Whiteboard settings.
  2. Set **Allow whiteboard to refresh after Booking is completed (hours)** to 24 and save.
  3. Complete an operation booking.
  4. Open that booking's whiteboard within the next 24 hours and look for **Refresh**.
- **Expected**: the whiteboard stays refreshable for the number of hours you set.
- **Actual**: `isset()` on the undefined parameter is false, the window stays 0, and `extendedEditablePeriod()` returns false - so **Refresh** is gone the moment the booking is completed, whatever the setting says. Uncommenting the config lines would not help either: they sit one level too deep for the key the controller reads.
- **Evidence**: both controllers and both config files read in the container at `53b077c089`; the setting row exists in `ophtroperationbooking_whiteboard_settings` and the saved value in `..._settings_data`, so the write half works exactly as intended.
- **Severity**: medium - the only setting on the screen does nothing, with no indication of it.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-358: The whiteboard setting cannot be cleared, and the attempt fails without a word (CONFIRMED code)

- **Where**: `modules/OphTrOperationbooking/controllers/oeadmin/WhiteboardSettingsController.php:45` guards the whole save with `if ($value !== null && $value !== '')`, so an empty box takes no branch at all - nothing is saved, no error is collected, and the form is simply re-rendered.
- **Route**: Admin > Operation booking > Whiteboard settings > the setting's edit screen.
- **Repro**:
  1. Set the whiteboard refresh setting to any number and save.
  2. Re-open it, clear the box completely and press Save.
  3. Re-open it again.
- **Expected**: the setting is cleared, or the form says the value is required.
- **Actual**: the old value is still there. Nothing on screen says the save did not happen.
- **Evidence**: the controller read in the container at `53b077c089`.
- **Severity**: low.
- **Status**: open. Found while documenting Admin > Operation booking.

## BUG-359: A double quote in a History Macro body breaks the Examination History macro insert (CONFIRMED code)

- Where: `modules/OphCiExamination/views/default/form_Element_OphCiExamination_History.php:27` (`$purifier = new CHtmlPurifier();`) and `:161`, which builds a JavaScript string literal by interpolating the macro body inside double quotes: `+ "<?= html_entity_decode((string) $purifier->purify(rtrim(preg_replace('/[\r\n]+/', '\n', (string) $set['body'])))) ?>"`.
- Route: authored at `/OphCiExamination/admin/HistoryMacro/list`; consumed in any Examination event's History element.
- Repro:
  1. Go to Admin > Examination > History Macros and select **Add**.
  2. Enter a Name, and a Body containing a double quote, for example `Patient reports "floaters" in the right eye`.
  3. Save, then open any patient and create an Examination event with a History element.
  4. Open the macro list on the History element.
- Expected: the macro inserts the sentence with its quotation marks.
- Actual: the emitted JavaScript string is terminated early by the macro's own quote, so the script block is malformed and the macro buttons on the History element stop working.
- Evidence: `HTMLPurifier::purify()` does not escape `"` in text content, verified by running `vendor/yiisoft/yii/framework/vendors/htmlpurifier/HTMLPurifier.standalone.php` directly in the container. The newline handling is a separate matter and is NOT a defect: `preg_replace('/[\r\n]+/', '\n', ...)` emits the two-character sequence backslash-n (verified in-container, hex `5c6e`), which is a valid JavaScript escape.
- Severity: medium. Any apostrophe is safe; only a double quote breaks it, and quoting a patient's own words is exactly what a history macro is for.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-360: Freehand drawing template list headings do not line up with the columns (CONFIRMED code)

- Where: `modules/OphCiExamination/modules/ExaminationAdmin/views/FreehandDraw/index.php:26-32` declares the headings `(checkbox)`, `Name`, `Order`, `Display Order`, `Active`; `_template_row.php:28-36` renders the cells checkbox, reorder handle, name, display order, active.
- Route: `/OphCiExamination/admin/FreehandDraw/index`.
- Repro:
  1. Go to Admin > Examination > Freehand draw templates.
  2. Read the column headings against the rows below them.
- Expected: each heading sits over the column it names.
- Actual: the counts match (five and five) but the labels are shifted by one: **Name** sits over the reorder handle, **Order** sits over the template name, and **Display Order** sits over the number.
- Evidence: the two files above, read at 53b077c089.
- Severity: low. Cosmetic, but it makes the screen read as though the name column were the ordering control.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-361: Clearing the chosen image on a freehand drawing template does nothing (CONFIRMED code)

- Where: `modules/OphCiExamination/modules/ExaminationAdmin/views/FreehandDraw/_form.php:107` binds to `$("#DrawingTemplate_image")`, while `:139` clears `document.getElementById('OphCoDocument_Sub_Types_image').value = null;` - an element id belonging to the Document module's sub-type form, which does not exist on this page.
- Route: `/OphCiExamination/admin/FreehandDraw/index` then select a row, or **Add**.
- Repro:
  1. Go to Admin > Examination > Freehand draw templates and open a template.
  2. Choose an image file.
  3. Use the control that removes the chosen file.
- Expected: the file selection is cleared.
- Actual: the script throws (`Cannot set properties of null`) and the file stays selected. The only way out is to reload the form.
- Evidence: the two lines above, read at 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-362: The freehand drawing template list shows pagination but never paginates (CONFIRMED code)

- Where: `modules/OphCiExamination/modules/ExaminationAdmin/controllers/FreehandDrawController::actionIndex()` calls `$pagination = $this->initPagination($model, $criteria);` and then fetches with `$templates = $model->findAll(['order' => 'display_order']);` - the criteria, and with it the limit and offset the pagination computed, are discarded.
- Route: `/OphCiExamination/admin/FreehandDraw/index`.
- Repro:
  1. Create enough freehand drawing templates to exceed one page.
  2. Go to Admin > Examination > Freehand draw templates.
  3. Select page 2.
- Expected: the second page of templates.
- Actual: every template is listed on every page; the pager is decorative.
- Evidence: the controller action above, read at 53b077c089.
- Severity: low. Harmless while the list is short; it also means reordering by drag always operates on the full list.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-363: Adding the first pupillary abnormality on an empty list is a fatal error (CONFIRMED code/db)

- Where: `modules/OphCiExamination/modules/ExaminationAdmin/controllers/PupillaryAbnormalitiesController.php:91` - `$model->display_order = $model::model()->find(['order' => 'display_order DESC'])->display_order + 1;` with no null check.
- Route: `/OphCiExamination/admin/PupillaryAbnormalities/index`.
- Repro:
  1. On an installation whose `ophciexamination_pupillaryabnormalities_abnormality` table is empty, go to Admin > Examination > Pupillary Abnormalities.
  2. Select **Add**.
  3. Enter a Name and select Save.
- Expected: the first abnormality is created with display order 1.
- Actual: `Attempt to read property "display_order" on null` - an application error page, and nothing is saved.
- Evidence: the line above, read at 53b077c089. The sample database ships rows in this table, so the fault only shows on an installation that has none (or after every row has been deleted).
- Severity: medium on a fresh installation, low afterwards.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-364: Deleting a pupillary abnormality fails silently (CONFIRMED code)

- Where: `modules/OphCiExamination/modules/ExaminationAdmin/controllers/PupillaryAbnormalitiesController::actionDelete()` initialises `$result['errors'] = "";` and then appends with `$result['errors'][] = $abnormality->getErrors();`, and again with `$result['errors'][] = $e->getMessage();` inside the `catch`. On PHP 8 `$x = ""; $x[] = 'v';` throws `Error: [] operator not supported for strings`, and thrown from inside the catch block it is uncaught.
- Route: `/OphCiExamination/admin/PupillaryAbnormalities/index`.
- Repro:
  1. Go to Admin > Examination > Pupillary Abnormalities.
  2. Tick an abnormality that is in use and select the delete button.
- Expected: a message saying the abnormality cannot be deleted because it is in use.
- Actual: the request 500s. The page's `$.ajax` call declares `dataType: 'JSON'` and has no `error:` handler, so nothing at all happens on screen - no message, no row removed.
- Evidence: the controller action above, plus `protected/assets/js/admin.js:171`, read at 53b077c089.
- Severity: medium. The screen gives no indication that the delete was refused.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-365: The Pupillary Abnormalities delete prompt names generic procedures (CONFIRMED code)

- Where: `protected/assets/js/admin.js:171` - the `#et_delete_abnormality` handler's message reads `Please select one or more generic procedure data to delete.`
- Route: `/OphCiExamination/admin/PupillaryAbnormalities/index`.
- Repro:
  1. Go to Admin > Examination > Pupillary Abnormalities.
  2. Select the delete button without ticking anything.
- Expected: a prompt naming pupillary abnormalities.
- Actual: `Please select one or more generic procedure data to delete.`
- Evidence: the line above, read at 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-366: The History Macros list has a Save button that does nothing (CONFIRMED code)

- Where: `modules/OphCiExamination/modules/ExaminationAdmin/views/historymacros/index.php:80-88` renders `CHtml::submitButton('Save', ['id' => 'et_admin-save', 'formmethod' => 'post'])` inside `<form id="admin_historymacros">`, which has no action; `HistoryMacroController::actionList():21-30` has no POST branch.
- Route: `/OphCiExamination/admin/HistoryMacro/list`.
- Repro:
  1. Go to Admin > Examination > History Macros.
  2. Select **Save** at the foot of the list.
- Expected: either no Save button on a list screen, or something saved.
- Actual: the list posts to itself, the controller ignores the post, and the page simply reloads. Nothing is saved and nothing says so.
- Evidence: the view and the controller action above, read at 53b077c089.
- Severity: low, but actively misleading: after reordering rows the button suggests the new order needs saving, and pressing it neither saves nor warns.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-367: Visit Intervals and Follow-up Statuses show an empty screen until the institution is passed in the URL (CONFIRMED code)

- Where: `modules/OphCiExamination/controllers/AdminController.php:1033` (`actionManageVisitIntervals`) and `:1173` (`actionManageClinicOutcomesStatus`) both compute `'filters_ready' => isset($_GET['institution_id']) && $_GET['institution_id'] === Yii::app()->session['selected_institution_id']`. `widgets/views/GenericAdmin.php:69` gates the whole table on `$filters_ready`, and `:134` gates the hidden template row the **Add** button clones.
- Route: `/OphCiExamination/admin/manageVisitIntervals`, `/OphCiExamination/admin/manageClinicOutcomesStatus`.
- Repro:
  1. Go to Admin > Examination > Visit Intervals from the menu.
  2. Read the screen.
  3. Now select your own institution in the filter and apply it.
  4. Select a different institution in the filter and apply it.
- Expected: the list for the institution you are working in on arrival, and the selected institution's list after step 4.
- Actual: step 2 shows the filter and nothing else, because the menu link carries no `institution_id`. Step 3 shows the list. Step 4 shows the filter and nothing else again: the comparison is against the session's institution, so any other institution renders blank rather than empty-with-an-explanation. **Add** is unavailable whenever the table is hidden.
- Evidence: the two controller lines and the two widget lines above, read at 53b077c089.
- Severity: medium. The screen reads as "there is nothing configured here".
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-368: Every admin list reports the same reason when a delete is refused (CONFIRMED code)

- Where: `protected/assets/js/handleButtons.js:62` binds `handleButton($('#et_delete'), ...)`, and `:132-133` parses the response and sets `let msg = "One or more Element attributes could not be deleted as they are in use.";` - a fixed string used for every screen that uses the shared admin Delete button.
- Route: every generic admin list, for example `/OphCiExamination/admin/redFlags`.
- Repro:
  1. Open any generic admin list and tick a row that cannot be deleted.
  2. Select **Delete**.
- Expected: a message naming what you were deleting and why it was refused.
- Actual: `One or more Element attributes could not be deleted as they are in use.` regardless of the screen, the record type, or the actual cause of the failure.
- Evidence: the two lines above, read at 53b077c089.
- Severity: low-medium. On screens that have nothing to do with element attributes, the message reads as an unrelated error.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-369: A follow-up role cannot be made to require a comment (CONFIRMED code/db)

- Where: `modules/OphCiExamination/modules/ExaminationAdmin/views/clinicoutcomeroles/_form.php` offers Name, Institution and Active only. `ophciexamination_clinicoutcome_role.requires_comment` is a real column, is listed as required in `OphCiExamination_ClinicOutcome_Role::rules():71`, and is the only thing that makes the follow-up comment mandatory (`models/ClinicOutcomeEntry.php:193-200`, `roleDependencyValidation`, which raises `"<role>" role requires a comment`).
- Route: `/OphCiExamination/admin/ClinicOutcomeRoles/index`.
- Repro:
  1. Go to Admin > Examination > Follow-up Roles.
  2. Select **Add**, or open an existing role.
  3. Look for a control that makes a comment compulsory for that role.
- Expected: a "requires comment" tick, since the application enforces exactly that flag.
- Actual: there is no such control on either the add or the edit form. New roles take the column default of 0, so the comment can never be made compulsory for a role created through the application.
- Evidence: the form, the model rules, and the consumer above, read at 53b077c089; all six shipped roles have `requires_comment = 0` in the sample database.
- Severity: medium. A documented behaviour of the Examination follow-up element is unreachable from the administration screens.
- Status: CONFIRMED (code + db) on develop @ 53b077c089.

## BUG-370: Every new follow-up role is created at display order 10 (CONFIRMED code/db)

- Where: `ClinicOutcomeRolesController::actionCreate()` never sets `display_order`, and `OphCiExamination_ClinicOutcome_Role` has no `afterConstruct()`, so the row takes the column default (`ophciexamination_clinicoutcome_role.display_order DEFAULT 10`). The model's `defaultScope():52-55` orders by `display_order`.
- Route: `/OphCiExamination/admin/ClinicOutcomeRoles/index`.
- Repro:
  1. Go to Admin > Examination > Follow-up Roles and select **Add**.
  2. Enter a Name and Save.
  3. Read the list, and the Role dropdown on an Examination follow-up element.
- Expected: the new role at the end of the list.
- Actual: it is created at display order 10, tied with **Consultant** (the shipped roles are 10, 20, 30, 40, 50 and 9999), so it appears at or near the top and the tie is broken arbitrarily by the database.
- Evidence: the controller action, the model and `SHOW COLUMNS` / row dump above, at 53b077c089.
- Severity: low. The list is reorderable by drag, so it is fixable on the spot once noticed.
- Status: CONFIRMED (code + db) on develop @ 53b077c089.

## BUG-371: The Inject. Mgmt No Treatment Reason form cannot set the "other" flag or Active (CONFIRMED code/db)

- Where: `modules/OphCiExamination/views/admin/form_OphCiExamination_InjectionManagementComplex_NoTreatmentReason.php` renders Name and Correspondence only. The table `ophciexamination_injectmanagecomplex_notreatmentreason` also carries `other` and `active`, both declared safe in `OphCiExamination_InjectionManagementComplex_NoTreatmentReason::rules():57`. `other` is what makes the free-text box compulsory on the Examination Injection Management element (`models/Element_OphCiExamination_InjectionManagementComplex.php:567`, `requiredIfNoTreatmentOther`) and what suppresses the default correspondence sentence (`getLetter_string():80-90`).
- Route: `/OphCiExamination/admin/viewAllOphCiExamination_InjectionManagementComplex_NoTreatmentReason`.
- Repro:
  1. Go to Admin > Examination > Inject. Mgmt - No Treatment Reasons.
  2. Select **Add**, or open the shipped **Other** row.
  3. Look for a control for the free-text behaviour, or for Active.
- Expected: both, since the list shows Active and the application's behaviour turns on `other`.
- Actual: the form has two text boxes and nothing else. A new reason is always created with `other = 0`, so a locally added "Other (please specify)" reason never asks for the text; and no reason can be retired from this screen.
- Evidence: the form, the model and the two consumers above, read at 53b077c089; in the sample database only row 6, `Other`, has `other = 1`, and it is seeded, not created through the form.
- Severity: medium.
- Status: CONFIRMED (code + db) on develop @ 53b077c089.

## BUG-372: A deactivated invoice status is still offered on the invoice manager rows (CONFIRMED code/db)

- Where: `modules/OphCiExamination/views/optom/list_filter.php:72` builds the filter dropdown with `'condition' => 'active = :active'`, but the per-row dropdown in `models/AutomaticExaminationEventLog::invoiceStatusSelect():228-239` calls `$status->findAll()` with no condition, and `InvoiceStatus` has no `defaultScope`.
- Route: `/OphCiExamination/OptomFeedback/list`; the statuses are administered at `/OphCiExamination/admin/InvoiceStatusList`.
- Repro:
  1. Go to Admin > Examination > Optom Invoice Statuses, open a status and untick **Active**, then Save.
  2. Go to Menu > Optom Invoice Manager.
  3. Open the **Invoice Status** filter, then open the status dropdown on any row.
- Expected: the deactivated status is gone from both.
- Actual: it is gone from the filter but still offered on every row, and can still be assigned - after which no filter can find that row again.
- Evidence: the two code sites above, read at 53b077c089; `ophciexamination_invoice_status` holds five rows, all active.
- Severity: medium.
- Status: CONFIRMED (code + db) on develop @ 53b077c089.

## BUG-373: Renaming or deleting the "No status" invoice status breaks the optometrist portal import (CONFIRMED code/db)

- Where: `modules/OphCiExamination/commands/PortalExamsCommand.php:33` - `$defaultInvoiceStatus = InvoiceStatus::model()->findByAttributes(array('name' => 'No status'));` with no null check, used unconditionally at `:66`, `:101`, `:119` and `:137` as `$defaultInvoiceStatus->id`.
- Route: administered at `/OphCiExamination/admin/InvoiceStatusList`; consumed by the scheduled `portalexams` console command.
- Repro:
  1. Go to Admin > Examination > Optom Invoice Statuses.
  2. Open the row named **No status** and rename it, for example to **Not yet invoiced**.
  3. Wait for (or run) the optometrist portal import.
- Expected: the import continues, filing new records under whatever the default status is now called.
- Actual: `Attempt to read property "id" on null` and the import aborts. Deleting the row has the same effect.
- Evidence: the command above, read at 53b077c089; `ophciexamination_invoice_status` row 5 is `No status`.
- Severity: high where the optometrist portal is in use, none where it is not. The admin screen gives no hint that this one name is load-bearing.
- Status: CONFIRMED (code + db) on develop @ 53b077c089.

## BUG-374: Deleting an invoice status silently orphans the records that used it (CONFIRMED code/schema)

- Where: `modules/OphCiExamination/controllers/AdminController::actionDeleteInvoiceStatus():1282-1296` deletes each selected row with no check for use. `automatic_examination_event_log.invoice_status_id` is a `text` column with no foreign key, so the database does not object.
- Route: `/OphCiExamination/admin/InvoiceStatusList`.
- Repro:
  1. Go to Menu > Optom Invoice Manager and set a row's status to, say, **Rejected**.
  2. Go to Admin > Examination > Optom Invoice Statuses, tick **Rejected** and select **Delete**.
  3. Return to the invoice manager and look at that row.
- Expected: either a refusal because the status is in use, or the affected rows reset to a visible default.
- Actual: the delete succeeds, and the row's status dropdown falls back to the blank ` - ` entry with no record of what was there before.
- Evidence: the controller action above and `SHOW CREATE TABLE automatic_examination_event_log` (no constraint on `invoice_status_id`), at 53b077c089.
- Severity: medium.
- Status: CONFIRMED (code + schema) on develop @ 53b077c089.

## BUG-375: Deleting a red flag breaks the worklist panel for patients already flagged (CONFIRMED code/schema)

- Where: Red flags are administered through `AdminController::actionRedFlags():1455-1457`, which calls `genericAdmin(...)` with deletion enabled and no reference check. `ophciexamination_ae_red_flags_option_assignment.red_flag_id` has no foreign key. `protected/views/worklist/steps/generic_step.php:49-52` then does `OphCiExamination_AE_RedFlags_Options::model()->find('id =?', array($red_flag_option->red_flag_id))->name` with no null check.
- Route: `/OphCiExamination/admin/redFlags`; the failure shows on `/worklist/view`.
- Repro:
  1. Record a red flag against a patient in an Examination event.
  2. Go to Admin > Examination > Red Flags, tick that flag and delete it.
  3. Open a worklist containing that patient and expand the red flag step.
- Expected: the deleted flag is either refused at step 2 or omitted from the panel.
- Actual: `Attempt to read property "name" on null` - the worklist step panel fails for that patient.
- Evidence: the three sites above, read at 53b077c089; `SHOW CREATE TABLE ophciexamination_ae_red_flags_option_assignment` shows constraints only on the user and audit columns. The sample database has 0 assignments, so this is code and schema, not observed.
- Severity: medium.
- Status: CONFIRMED (code + schema) on develop @ 53b077c089.

## BUG-376: A new IOP instrument is saved without validation (CONFIRMED code)

- Where: `modules/OphCiExamination/controllers/AdminController::actionAddIOPInstrument():187` - `if ($model->save(false))`. `OphCiExamination_Instrument::rules():75-79` declares `name` required and carries the `validateInstrumentNotChangedWhenSharedUnlessInstallationAdmin` guard; `save(false)` skips both.
- Route: `/OphCiExamination/admin/ViewIOPInstruments`.
- Repro:
  1. Go to Admin > Examination > IOP Instruments and select **Add**.
  2. Leave **Name** empty and Save.
- Expected: `Name cannot be blank.` against the field.
- Actual: a nameless instrument is written to the database and appears in the list as an empty row, and in the IOP element's instrument dropdown as an empty option.
- Evidence: the controller action and the model rules above, read at 53b077c089. Note the contrast with the edit action, which does validate.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-377: Editing an IOP instrument reports success even when the save was rejected (CONFIRMED code)

- Where: `modules/OphCiExamination/controllers/AdminController::actionUpdateIOPInstrument()` calls `$model->save();` at `:129` and discards the return value, then unconditionally audits, sets `Yii::app()->user->setFlash('success', 'IOP Instrument updated')` at `:142` and redirects to the list.
- Route: `/OphCiExamination/admin/ViewIOPInstruments`.
- Repro:
  1. As an institution administrator (not an installation administrator), go to Admin > Examination > IOP Instruments.
  2. Open an instrument that is shared with other institutions and change its **Name**.
  3. Save.
- Expected: a message explaining that a shared instrument cannot be renamed at institution level.
- Actual: `IOP Instrument updated`, and the list still shows the old name. The rejection comes from `validateInstrumentNotChangedWhenSharedUnlessInstallationAdmin`, which only runs outside the `installationAdminSave` scenario - exactly the case an institution administrator is in.
- Evidence: the controller action above and `OphCiExamination_Instrument::rules():77`, read at 53b077c089.
- Severity: medium. The administrator is told the change was made when it was not.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-378: The generic admin mapping buttons always name the first level, whatever the dropdown says (CONFIRMED code)

- Where: `protected/widgets/views/GenericAdmin.php:202-222` computes `$first_prefix = $model::model()->getModelSuffixForLevel($supported_levels[0]);` and labels both buttons from it (`Add selected to current <first level>` / `Remove selected from current <first level>`), then, when the model supports more than one level, renders a `mapping_level` dropdown offering all of them.
- Route: any generic admin list whose model supports more than one reference-data level, for example `/OphCiExamination/admin/redFlags`.
- Repro:
  1. Open a generic admin list that shows a level dropdown next to the mapping buttons.
  2. Change the dropdown to a level other than the first.
  3. Read the buttons.
- Expected: the button labels follow the dropdown.
- Actual: they keep naming the first supported level, so the button reads "Add selected to current Institution" while the mapping will actually be made at Site or Firm level.
- Evidence: the view above, read at 53b077c089.
- Severity: low-medium. The action taken is the one the dropdown says, not the one the button says.
- Status: CONFIRMED (code) on develop @ 53b077c089.

## BUG-379: An inactive pupillary abnormality is still demanded as required (CONFIRMED code/db)

- Where: `modules/OphCiExamination/components/OphCiExamination_API::getRequiredAbnormalities():3676-3714` filters the set by subspecialty, context, age and gender, but never by `active`, and `OphCiExamination_PupillaryAbnormalities_Abnormality::defaultScope():59-62` only orders by `display_order`.
- Route: administered at `/OphCiExamination/admin/PupillaryAbnormalities/index` and `/OphCiExamination/admin/PupillaryAbnormalityAssignment/index`; enforced in the Examination event's pupillary abnormalities element.
- Repro:
  1. Add an abnormality to a required set at Admin > Examination > Required Pupillary Abnormalities.
  2. Go to Admin > Examination > Pupillary Abnormalities and untick **Active** for that abnormality.
  3. Create an Examination event for a patient the set applies to.
- Expected: the retired abnormality is no longer demanded.
- Actual: it is still listed as required and still has to be answered, even though it is no longer offered as a choice elsewhere.
- Evidence: the API method and the model above, read at 53b077c089. `ophciexamination_pupillaryabnormalities_abnormality` has an `active` column; `ophciexamination_pupillary_abnormality_set` has 0 rows in the sample database, so this is code, not observed.
- Severity: low while no sets are defined; medium on an installation that uses them.
- Status: CONFIRMED (code + db) on develop @ 53b077c089.

## BUG-380: Deleting a benefit ignores the consent form's extra procedures (CONFIRMED code/schema)

- Where: `protected/controllers/oeadmin/BenefitController.php:117-125` (`isBenefitDeletable()`), `:133-146` (`actionDelete()`).
- Route: `/oeadmin/benefit/list` - Menu > Admin / Procedure management > Benefits.
- Repro:
  1. Open a consent form extra procedure and attach a benefit to it, so a row exists in `extra_procedure_benefit`.
  2. Open Admin > Procedure management > Benefits.
  3. Tick that benefit and select Delete.
- Expected: the screen refuses the delete because the benefit is in use.
- Actual: `isBenefitDeletable()` counts rows in `procedure_benefit` only, so it reports the benefit deletable; `$benefit->delete()` then hits the `extra_procedure_benefit_benefit_id_fk` foreign key, which has no ON DELETE action and therefore restricts, and the resulting `CDbException` is not caught - the request ends in an application error.
- Evidence: `$check_dependencies &= !ProcedureBenefit::model()->count('benefit_id = :id', $options);` is the only check in the guard. `information_schema.KEY_COLUMN_USAGE` shows `benefit` referenced by both `procedure_benefit` and `extra_procedure_benefit`; `SHOW CREATE TABLE extra_procedure_benefit` carries `CONSTRAINT extra_procedure_benefit_benefit_id_fk FOREIGN KEY (benefit_id) REFERENCES benefit (id)` with no ON DELETE clause. The sample database has 0 rows in `extra_procedure_benefit`, so the path is unreachable there until an extra procedure is given a benefit.
- Severity: medium.
- Status: CONFIRMED from source and schema at develop 53b077c089. Not driven live - the confirming step is a delete.

## BUG-381: The Complications screen's refusal message never reaches the screen (CONFIRMED code)

- Where: `protected/controllers/oeadmin/ComplicationController.php:118-126` (`isComplicationDeletable()`), `:138-146` (the refusal branch), consumed by `protected/assets/js/handleButtons.js:130-138`.
- Route: `/oeadmin/complication/list` - Menu > Admin / Procedure management > Complications.
- Repro:
  1. Open Admin > Procedure management > Complications.
  2. Tick a complication that is attached to a procedure.
  3. Select Delete.
- Expected: a message naming the complication that could not be deleted.
- Actual: the action echoes `Complication with id 4 cannot be deleted. Other tables depend on it.\n` and then `echo 1`, so the response body is plain text. The button handler does `JSON.parse(html)` with no `try`/`catch`, which throws, so nothing is shown and the ticked rows have already been removed from the table by the handler. The complication reappears on reload.
- Expected also: the guard should cover every consumer. It counts `procedure_complication` only, while `complication` is also referenced by `extra_procedure_complication` and `ophtrlaser_procedure_complication_assignment`; a complication used only by one of those two takes the same restricting-foreign-key route as BUG-380.
- Evidence: the refusal branch echoes a bare single-quoted string (so the `\n` is two literal characters) followed by `echo 1`; `handleButtons.js:132` reads `let reponse = JSON.parse(html);`. Related: BUG-368 records the fixed fallback wording used by the same handler.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-382: Injection-only post-op complications are never offered outside their own subspecialty (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/models/OphCiExamination_PostOpComplications.php:92-102` (`getComplicationsBySubspecialty()`).
- Route: the Post-Op Complications element on an Examination event; administered from `/OphCiExamination/admin/postOpComplications` and `/oeadmin/PostOpComplication/list`.
- Repro:
  1. Mark a post-op complication as an injection complication.
  2. Open an Examination event in a subspecialty the complication is not assigned to and add the Post-Op Complications element.
  3. Open the complication picker.
- Expected: the injection complication is offered, which is what the `is_injection=1` clause is written to do.
- Actual: it is not offered in any subspecialty other than the ones it is explicitly assigned to.
- Evidence: the method calls `addCondition('subspecialty_id=:subspecialty_id')`, then `addCondition('is_injection=1', 'OR')`, then `addCondition('institution_id = :institution_id AND subspecialty_id = :subspecialty_id')`. `CDbCriteria::addCondition` parenthesises what has accumulated, so the result is `(subspecialty_id=:s OR is_injection=1) AND (institution_id=:i AND subspecialty_id=:s)` - the trailing subspecialty test makes the `OR` branch unreachable.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-383: Deactivating a post-op complication does not withdraw it (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/models/OphCiExamination_PostOpComplications.php:92-102` (`getComplicationsBySubspecialty()`) and `:47-50` (`defaultScope()`); `protected/modules/OphCiExamination/controllers/DefaultController.php:792-808` (`actionSearchPostOpComplication()`).
- Route: the Post-Op Complications element on an Examination event.
- Repro:
  1. Untick Active on a post-op complication in Admin > Procedure management > Post-Op Complications and save.
  2. Open an Examination event, add the Post-Op Complications element and open the complication picker.
  3. Also type part of the complication's name into the element's search box.
- Expected: the complication is no longer offered.
- Actual: it is still listed, and the search still returns it.
- Evidence: neither query filters `active`. `getComplicationsBySubspecialty()` builds its criteria from subspecialty, institution and `is_injection` only; `actionSearchPostOpComplication()` is a bare `addSearchCondition('name', $term)`; and the model's `defaultScope()` sets an order and nothing else.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-384: Two admin edit forms always read "Edit Procedure" (CONFIRMED code)

- Where: `protected/views/oeadmin/procedure/edit.php:24` and `protected/views/oeadmin/clinicprocedures/edit.php:20`.
- Route: `/oeadmin/procedure/list` and `/oeadmin/ClinicProcedure/list` - Menu > Admin / Procedure management > Procedures, Clinic Procedure Assignment.
- Repro:
  1. Open Admin > Procedure management > Procedures.
  2. Select Add.
- Expected: a heading reading Add Procedure.
- Actual: the heading reads Edit Procedure. The same happens on Clinic Procedure Assignment, where the heading reads Edit Procedure whether a row is being added or edited.
- Evidence: both views hardcode `<h2>Edit Procedure</h2>`. The sibling screen in the same group does it correctly: `protected/views/oeadmin/postopcomplication/edit.php:21` uses `<?php echo $complication->id ? 'Edit' : 'Add' ?>`.
- Severity: low.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-385: An OPCS code's Active box does nothing (CONFIRMED code/schema)

- Where: `protected/controllers/oeadmin/ProcedureController.php:207` (the picker), `protected/models/Procedure.php:90` (the `opcsCodes` relation), `protected/modules/OphTrOperationnote/views/default/view_Element_OphTrOperationnote_ProcedureList.php:68` and `protected/modules/OphTrOperationbooking/views/default/view_Element_OphTrOperationbooking_Operation.php:44` (the two render sites).
- Route: `/oeadmin/opcsCode/list` - Menu > Admin / Procedure management > OPCS Codes.
- Repro:
  1. Open Admin > Procedure management > OPCS Codes and untick Active on a code that is attached to a procedure. Save.
  2. Open Admin > Procedure management > Procedures, open any procedure and look at the OPCS code picker.
  3. Open a saved operation note or operation booking that carries that procedure.
- Expected: the code is withdrawn from the picker, and arguably left in place on records already saved.
- Actual: it is still offered in the picker and still printed on the event.
- Evidence: `opcs_code` carries an `active tinyint(1) NOT NULL DEFAULT 1` column and `OPCSCode::rules()` marks it safe, but no query in the application filters on it: the only three call sites are `OPCSCode::model()->findAll()` at `ProcedureController.php:207`, an `addInCondition('id', ...)` at `:157`, and `findByPk()` in `OpcsCodeController`. The relation is `'opcsCodes' => array(self::MANY_MANY, 'OPCSCode', 'proc_opcs_assignment(proc_id, opcs_code_id)')` with no condition, and the model declares no `defaultScope`. All 556 shipped codes are active, so the sample database never shows the effect.
- Severity: low.
- Status: CONFIRMED from source and schema at develop 53b077c089.

## BUG-386: Procedure assignments made by another institution reach every institution's pickers (CONFIRMED code)

- Where: `protected/models/Procedure.php:222-245` (`getListBySubspecialty()`), against `protected/controllers/oeadmin/ProcedureController.php:63-80` (`actionList()`).
- Route: `/Admin/procedureSubspecialtyAssignment/edit` sets the assignments; the picker appears on operation note, consent and operation booking through `protected/widgets/ProcedureSelection.php:74` and `protected/widgets/views/ProcedureSelection.php:572`.
- Repro:
  1. As an administrator of institution B, assign a procedure to a subspecialty on Admin > Procedure management > Procedure - Subspecialty Assignment.
  2. Log in at institution A and open Admin > Procedure management > Procedures. The assignment is not listed.
  3. At institution A, open an event in that subspecialty and open the procedure picker.
- Expected: the two agree - either both scope to the institution or neither does.
- Actual: the admin screen scopes to the institution and the clinician's picker does not, so a procedure appears to clinicians at institution A that its own administrators cannot see.
- Evidence: `getListBySubspecialty()` joins `proc_subspecialty_assignment` filtering `psa.subspecialty_id` and `proc.active` only, while `ProcedureController::actionList()` adds `$criteria->compare('pssa.institution_id', Yii::app()->session['selected_institution_id'])`. `EpisodeSummaryWidget.php:63` and `ExtraProcedureSelection.php:82` are the other two callers of the unscoped method.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-387: A new cataract row lands a column out of step on the subspecialty assignment grid (CONFIRMED code)

- Where: `protected/modules/Admin/views/edit_ProcedureSubspecialtyAssignment.php:19-20` (the gate), `:81-95` (the extra column), `:180-210` (the Mustache template `#procedure_assignment_template`).
- Route: `/Admin/procedureSubspecialtyAssignment/edit` - Menu > Admin / Procedure management > Procedure - Subspecialty Assignment.
- Repro:
  1. With the `cataract_eur_switch` setting on, open the screen and choose the Cataract subspecialty. The grid gains a fifth column, Require Effective Use of Resources (EUR) assessment.
  2. Select Add to append a row.
- Expected: the new row has a cell under every column, including an EUR dropdown.
- Actual: the template emits four cells - reorder handle, procedure, institution, delete - so the institution dropdown sits under the EUR heading and the delete link under Institution, and the new row carries no EUR control at all, so a procedure added here cannot be flagged for EUR without saving and reopening.
- Evidence: `$cols_size = (int)$subspecialty_id === 4 && $enable_eur === 'on' ? 'cols-9' : 'cols-5';` at `:20`; the EUR column is appended to `$columns` only inside the same condition at `:81`; the template's `<tr>` contains exactly four `<td>` elements. The sample installation has `cataract_eur_switch` off, so the extra column does not appear there and this could not be observed.
- Severity: low-medium, and only where EUR is switched on.
- Status: CONFIRMED from source at develop 53b077c089. Not observed live - the setting is off in the sample installation.

## BUG-388: The subsection assignment filters lose the institution (CONFIRMED code)

- Where: `protected/views/oeadmin/subspecialty_subsection_assignment/index.php:179-192`.
- Route: `/oeadmin/SubspecialtySubsectionAssignment/list` - Menu > Admin / Procedure management > Procedure - Subspecialty Subsection Assignment.
- Repro:
  1. Open the screen and choose an institution, then a subspecialty subsection, so the address carries both parameters.
  2. Change the subsection dropdown again.
- Expected: the institution stays as chosen.
- Actual: the page reloads with the subsection only and the institution reverts. Changing the institution dropdown when only one parameter is present builds an address ending in `undefined`.
- Evidence: the handlers rebuild the query string positionally from `e.target.baseURI.split('?')[1].split('&')` - the subsection handler keeps `[0]` and drops the rest, the institution handler concatenates `[0]` and `[1]` - rather than reading the named parameters.
- Severity: low-medium.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-389: Nothing stops the same procedure being assigned twice (CONFIRMED schema)

- Where: tables `proc_subspecialty_assignment`, `proc_subspecialty_subsection_assignment` and `lens_removal_procedures`.
- Route: `/Admin/procedureSubspecialtyAssignment/edit`, `/oeadmin/SubspecialtySubsectionAssignment/list`, `/oeadmin/LensRemovalProcedure/list`.
- Repro:
  1. Open Admin > Procedure management > Procedure - Subspecialty Assignment for a subspecialty.
  2. Select Add and choose a procedure that is already in the list.
  3. Save.
- Expected: the duplicate is refused.
- Actual: a second identical assignment is stored, and the procedure then appears twice in the clinician's picker.
- Evidence: `SHOW CREATE TABLE` on all three returns a primary key on `id` and plain indexes behind the foreign keys, with no unique constraint on the assignment pair; the models declare no uniqueness rule.
- Severity: low.
- Status: CONFIRMED from schema at develop 53b077c089. Not driven live.

## BUG-390: A firm with no subspecialty makes the clinic procedure element fatal (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/models/OphCiExamination_ClinicProcedure.php:76`.
- Route: the Clinic Procedures element on an Examination event.
- Repro:
  1. Create a firm that has no service subspecialty assignment, or work in a context whose firm has lost one.
  2. Open an Examination event in that context and add the Clinic Procedures element.
- Expected: an empty procedure list, or a message.
- Actual: an application error, because `serviceSubspecialtyAssignment` is null and `->subspecialty_id` is read from it.
- Evidence: the line is `\Firm::model()->findByPk($firm_id)->serviceSubspecialtyAssignment->subspecialty_id` with no guard. The equivalent read in `protected/widgets/ProcedureSelection.php:64` is written defensively as a ternary that tests the relation first, so the two disagree about whether the relation can be absent.
- Severity: medium where such a firm exists; every firm in the sample installation has an assignment.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-391: An institution administrator is refused their own institution's recipient output types (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/controllers/oeadmin/DocumentRecipientOutputTypesController.php:72-87` (`actionEdit()`).
- Route: `/OphCoCorrespondence/oeadmin/documentRecipientOutputTypes/list` - Menu > Admin / Correspondence > Recipient Output Types.
- Repro:
  1. Log in as an institution administrator who is authenticated against institution 1.
  2. Open Admin > Correspondence > Recipient Output Types and leave the institution set to your own.
  3. Select the GP row.
- Expected: the edit grid opens.
- Actual: `403 User does not have permission to change recipient output types for this institution`. The same user viewing a different institution - one they are not authenticated against - is let through to edit it.
- Evidence: the test is `if ($user->checkAccess('OprnInstitutionAdmin') && $user_has_institution_auth) { throw new CHttpException(403, ...); }`, inside the `!$user->checkAccess('admin')` branch. `$user_has_institution_auth` counts rows joining `institution_authentication` to `user_authentication` for the selected institution, so holding the right role and belonging to the institution is exactly what triggers the refusal. Both halves of the condition need negating.
- Severity: high - the screen is unusable for its intended audience, and the permissive path is the wrong way round.
- Status: CONFIRMED from source at develop 53b077c089. The 403 was not observed in a browser.

## BUG-392: A recipient type can be saved with no delivery route at all (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/controllers/oeadmin/DocumentRecipientOutputTypesController.php:145-147`.
- Route: `/OphCoCorrespondence/oeadmin/documentRecipientOutputTypes/list` - Menu > Admin / Correspondence > Recipient Output Types.
- Repro:
  1. As a system administrator, open Recipient Output Types with the institution set to `All Institutions (Fallback)`.
  2. Open any recipient type, for example `PATIENT`.
  3. Untick every **Enabled** box.
  4. Select Save.
- Expected: `At least 1 output type must be selected`, and nothing saved.
- Actual: the save succeeds and the recipient type is left with no output type, so letters to that recipient have no delivery route.
- Evidence: `$output_types_present` is set from the posted checkbox values, but `CHtml::checkBox` always emits a companion hidden input carrying `0`, so the key is always present and the flag is always true. The guard at `:145` can therefore never fire.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-393: The internal referral output type cannot be edited on the screen that configures it (CONFIRMED code/db)

- Where: `protected/models/DocumentRecipientOutputType.php:79-97` (`getAllAvailableOutputTypes()`), called with `false` at `protected/modules/OphCoCorrespondence/controllers/oeadmin/DocumentRecipientOutputTypesController.php:90`.
- Route: `/OphCoCorrespondence/oeadmin/documentRecipientOutputTypes/list` - Menu > Admin / Correspondence > Recipient Output Types.
- Repro:
  1. Open Recipient Output Types at `All Institutions (Fallback)`.
  2. Select the `INTERNALREFERRAL` row.
- Expected: a grid including the Internal Referral output type, so it can be enabled, disabled or defaulted.
- Actual: the grid lists Docman, Electronic, Email, Email Delayed and Print only. The one output type that recipient exists for is absent, so it can be neither turned off nor set as the default from here. Because a save only deletes rows for output types the grid rendered, the shipped installation-wide `INTERNALREFERRAL / Internalreferral` row survives every save - which is the only reason the feature still works.
- Evidence: the edit action passes `false`, which is the branch that omits `DocumentOutput::TYPE_INTERNAL_REFERRAL`; the list action uses the default `true`, so the row is listed but not editable. `SELECT recipient_type, output_type, institution_id FROM document_recipient_output_type` returns `INTERNALREFERRAL / Internalreferral / NULL` among the 8 installation-level rows.
- Severity: low-medium.
- Status: CONFIRMED from source and DB at develop 53b077c089.

## BUG-394: The recipient output types list reads as empty where the installation-wide setting applies (CONFIRMED code/db)

- Where: `protected/modules/OphCoCorrespondence/controllers/oeadmin/DocumentRecipientOutputTypesController.php:50-52` - `getOutputTypeAssignmentsForInstitution($recipient_type, $institution, true)`.
- Route: `/OphCoCorrespondence/oeadmin/documentRecipientOutputTypes/list` - Menu > Admin / Correspondence > Recipient Output Types.
- Repro:
  1. Open Recipient Output Types and choose institution 1.
  2. Read the `PATIENT` row.
- Expected: some indication that the installation-wide set is in force here.
- Actual: the **Assigned Output Types** cell is blank, which reads as "this recipient has no delivery route", when in fact `PATIENT / Print` applies from installation level.
- Evidence: the third argument is the strict flag, so the list shows only rows recorded at the level being viewed. The sample database has 8 installation-level rows and 3 institution rows, all of them `GP / Docman`, so every other recipient's cell is blank at every institution.
- Severity: low, but it invites an administrator to add a row that was not needed.
- Status: CONFIRMED from source and DB at develop 53b077c089.

## BUG-395: The delivery configuration form always says "Add" (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/views/admin/edit_correspondence_delivery_configuration.php:20`.
- Route: `/OphCoCorrespondence/admin/correspondenceDeliveryConfigurations` - Menu > Admin / Correspondence > Delivery Configurations.
- Repro:
  1. Open Admin > Correspondence > Delivery Configurations.
  2. Select an existing configuration.
- Expected: a heading reading Edit Correspondence Delivery Configuration.
- Actual: it reads Add Correspondence Delivery Configuration.
- Evidence: `<h2><?= $config ? 'Add' : 'Edit' ?> Correspondence Delivery Configuration</h2>`. The ternary is inverted, and `$config` is always a model instance - a new one when adding - so the true branch always wins and the heading never changes.
- Severity: low.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-396: Test Path tests every configuration, not the one selected (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/views/admin/correspondence_delivery_configurations.php:129`.
- Route: `/OphCoCorrespondence/admin/correspondenceDeliveryConfigurations` - Menu > Admin / Correspondence > Delivery Configurations.
- Repro:
  1. Open Delivery Configurations for an institution with more than one row.
  2. Select **Test Path** on one row.
- Expected: only that row's Last test status, date and message change.
- Actual: every row for the institution is tested and updated.
- Evidence: the fetch URL is built as `"...?institution_id=" + institution_id + "id=" + id` - the `&` between the two parameters is missing, so the query string reads `institution_id=1id=3`, `id` is never parsed, and the controller takes its test-everything branch.
- Severity: low. The test only stats directories, so nothing is written to disk; the cost is a misleading screen and a slower response.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-397: A delivery configuration that fails validation ends on an error page (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/controllers/traits/AdminForCorrespondenceDeliveryConfigurations.php:93-96`.
- Route: `/OphCoCorrespondence/admin/editCorrespondenceDeliveryConfiguration` - reached from **Add Config** on Menu > Admin / Correspondence > Delivery Configurations.
- Repro:
  1. Open Delivery Configurations and select **Add Config**.
  2. Leave **Name** empty.
  3. Select Save.
- Expected: `Name cannot be blank.` against the field, with everything else typed still on screen.
- Actual: an application error page carrying the dumped validation errors, and everything typed is lost.
- Evidence: `if (!$config->save()) { throw new Exception("Unable to save correspondence delivery config: " . print_r($config->errors, true)); }` - the failure is thrown rather than re-rendered. `CorrespondenceDeliveryConfiguration` marks `name, content_type, filename_mask, output_type, institution_id` required, so this is reachable from an ordinary typing mistake.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-398: Add Config files the new configuration under your own institution (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/views/admin/correspondence_delivery_configurations.php:76-86` (the **Add Config** button), against `controllers/traits/AdminForCorrespondenceDeliveryConfigurations.php:85-90`.
- Route: `/OphCoCorrespondence/admin/correspondenceDeliveryConfigurations` - Menu > Admin / Correspondence > Delivery Configurations.
- Repro:
  1. As a system administrator, open Delivery Configurations and switch the institution dropdown to a second institution.
  2. Select **Add Config**, fill the form in and Save.
- Expected: the configuration belongs to the institution whose list you were looking at.
- Actual: it belongs to your session institution, and disappears from the list you were working in.
- Evidence: the button's `data-uri` is `/OphCoCorrespondence/admin/editCorrespondenceDeliveryConfiguration` with no `institution_id`, so the action falls back to `Institution::model()->getCurrent()`.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-399: Deleting delivery configurations is not scoped to an institution (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/controllers/traits/AdminForCorrespondenceDeliveryConfigurations.php:108-130`, with the button at `views/admin/correspondence_delivery_configurations.php:87-95`.
- Route: `/OphCoCorrespondence/admin/deleteDeliveryConfigurations` - the **Delete Selected Configurations** button on Menu > Admin / Correspondence > Delivery Configurations.
- Repro:
  1. As a system administrator, open Delivery Configurations, switch to a second institution, tick a row and select **Delete Selected Configurations**.
  2. Observe which list you are returned to.
- Expected: the deletion is checked against the institution being administered, and you are returned to that institution's list.
- Actual: you are returned to your own institution's list, because the button's `data-uri` is `.../deleteDeliveryConfigurations?ids=` with no `institution_id`, so the redirect carries an empty value and the list action falls back to the session institution.
- Actual, second part: the action does `deleteAll` over ids taken straight from the query string with no institution predicate and no ownership check, so a request naming another institution's configuration ids would delete them.
- Evidence: `$ids = explode(",", (string) $ids_string); $criteria->addInCondition('id', $ids); CorrespondenceDeliveryConfiguration::model()->deleteAll($criteria)`. The redirect is `'...?institution_id=' . $institution_id` where `$institution_id` came from the same request.
- Severity: medium for the redirect; the unscoped delete is a cross-institution data-loss risk that needs a crafted request, and was not attempted here because it would write.
- Status: CONFIRMED from source at develop 53b077c089. The cross-institution delete was NOT exercised.

## BUG-400: The Letter footer blank line count setting does nothing (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/components/OphCoCorrespondence_API.php:580-587` (the only reader), reachable only from `protected/controllers/DocmanController.php:244-248`; the ordinary letter path is `protected/modules/OphCoCorrespondence/models/ElementLetter.php:657`.
- Route: `/OphCoCorrespondence/admin/letterSettings/settings` - Menu > Admin / Correspondence > Letter settings.
- Repro:
  1. Open Admin > Correspondence > Letter settings and set **Letter footer blank line count** to 10. Save.
  2. Create a Correspondence event and look at the space above the signature block.
- Expected: ten blank lines.
- Actual: no change. The letter path sets `$this->footer = ""` and builds the sign-off from the e-sign sign-off text instead, so the stored value is never read.
- Evidence: the value's only consumer is `getMacroData()`, which is private and called only from `createCorrespondenceContent()`, whose only caller is `DocmanController::actionCreateNewCorrespondence()`. That action reads `$this->episode->id`, and `$episode` is declared neither on `DocmanController` nor on its parent `BaseController` - the string `episode` appears exactly once in the file, on that line - so the action cannot complete. A second latent fault sits in the same block: `for ($x = 0; $x < $count; $x++)` with `$count` taken straight from the setting, which has no numeric validator; PHP 8.4 evaluates both `0 < "abc"` and `5 < "abc"` as true, so a non-numeric value would loop forever. It is unreachable for the same reason.
- Severity: low - a setting that reads as effective and is not.
- Status: CONFIRMED from source at develop 53b077c089. Not driven live.

## BUG-401: The letter settings editor loops over every setting and redirects on the first success (CONFIRMED code)

- Where: `protected/modules/OphCoCorrespondence/controllers/AdminController.php:102-119` (`actionEditSetting()`).
- Route: `/OphCoCorrespondence/admin/letterSettings/settings` - Menu > Admin / Correspondence > Letter settings.
- Repro: requires a second row in `ophcocorrespondence_letter_settings`, which cannot be created from any screen.
  1. With two or more settings defined, open one and save a value that fails validation.
- Expected: the form redisplays the setting you were editing, with its error.
- Actual: `$metadata` is the loop variable and `$errors` is overwritten on every pass, so the view redisplays whichever setting the loop ended on, carrying the last error recorded. A success on any setting redirects immediately, abandoning the rest of the loop.
- Evidence: `foreach ($letter_settings as $metadata) { ... if (!$setting->save()) { $errors = $setting->errors; } else { $this->redirect(...); } }`, with the render after the loop using `$metadata`.
- Severity: low, and latent - exactly one setting ships, so the loop always has a single pass.
- Status: CONFIRMED from source at develop 53b077c089. NOT reproducible on the sample installation.

## BUG-402: A shipped Botox symptom severity is too long for its own validation rule, which blocks reordering the screen (CONFIRMED code/db)

- Where: `protected/modules/OphCiExamination/models/BotoxManagement_SymptomSeverity.php:55-62` (`['name', 'length', 'max' => 128, 'min' => 2]`) against row 3 of `ophciexamination_botoxmanagement_symptomseverity`, which is 140 characters. The column itself is `varchar(255)`.
- Route: `/OphCiExamination/admin/BotoxManagementSymptomSeverity/index` - Menu > Admin / Examination > Botox Management - Symptom Severity.
- Repro:
  1. Open the screen. Five severities are listed, in display order.
  2. Drag any row past the third one, or delete either of the first two rows.
  3. Select Save.
- Expected: the reorder or the deletion is saved.
- Actual: an error appears against the third row reading that Name is too long (maximum is 128 characters), and nothing at all is saved - not the reorder, not the deletion, not any other edit made in the same visit.
- Evidence: `BaseAdminController::genericAdmin()` recomputes `$item->display_order = $j + 1;` for every posted row (`:337`), so any change in position dirties the affected rows and forces `$item->save()` at `:268`. A single failure populates `$errors`, and `:325` rolls the whole transaction back, so the screen is all-or-nothing. Shipped display orders are a contiguous 1-5, so a Save with no reordering does not dirty the row and does succeed - the fault only surfaces when positions move. The other three Botox lists carry the same 128-character rule but no row over 100 characters.
- Severity: medium. The screen can be added to but cannot be reordered or pruned until an administrator shortens a row they did not intend to touch.
- Status: CONFIRMED from source and DB at develop 53b077c089.

## BUG-403: Renaming a driving status silently does nothing (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/modules/ExaminationAdmin/views/DrivingSafety/driving_safety_status_view.php:22` against `controllers/DrivingSafetyController.php:50-66` (`actionEditDrivingSafetyStatus()`).
- Route: `/OphCiExamination/admin/DrivingSafety/editDrivingSafetyStatus` - Menu > Admin / Examination > Driving Advice - Status.
- Repro:
  1. Open the screen. Each status has an editable Name box.
  2. Change a name.
  3. Select Save.
- Expected: the new name is stored and shows on the Driving element.
- Actual: the page reloads with the original name. Nothing is saved and no message is shown.
- Evidence: the cell renders `\CHTML::activeTextField($status, 'driving_status_name', ['value' => $status->name ?? ''])`. Two things are wrong with that name. The model's column is `name`, not `driving_status_name` (`SocialHistoryDrivingStatus` declares `name` in `attributeLabels()` and the table has no `driving_status_name` column), and the field is not indexed by row, so every row in the grid posts under the same key and only the last would arrive. The controller then reads only `$_POST["...Driving_Safety_Status_Assignment"]["driving_standard"]` and `$_POST["...SocialHistoryDrivingStatus"]["active"]`, so the name is never looked at under either spelling.
- Severity: medium. An editable box that discards what is typed into it, with no error.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-404: An allergy cannot be deactivated (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/modules/ExaminationAdmin/views/Allergies/index.php:68` against `controllers/AllergiesController.php:64` (`actionUpdate()`).
- Route: `/OphCiExamination/admin/Allergies/index` - Menu > Admin / Examination > Allergies.
- Repro:
  1. Open the screen.
  2. Untick Active on any allergy.
  3. Select Save.
- Expected: the allergy stops being offered on the Allergies element.
- Actual: the row comes back ticked. The allergy stays active and stays on offer.
- Evidence: the view emits `CHtml::checkBox("OphCiExamination_Allergy[{$i}][active]", $model->active)`, and Yii 1 always writes a companion hidden input with value `0` under the same name unless `uncheckValue` is set to null. The controller decides the flag with `$attributes['active'] = isset($attributes['active']);`, which is therefore true whether the box was ticked or not. The same pattern appears on the new-row template at `:121`.
- Severity: medium. Retiring an allergy is the only intended way to withdraw it - there is no delete on this screen.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-405: Saving the allergies screen reports only the last row's outcome (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/modules/ExaminationAdmin/controllers/AllergiesController.php:47-92` (`actionUpdate()`).
- Route: `/OphCiExamination/admin/Allergies/index` - Menu > Admin / Examination > Allergies.
- Repro:
  1. Open the screen and make two separate rows invalid - for example clear the name on two allergies.
  2. Select Save.
- Expected: both failures are reported.
- Actual: one error message appears, describing the later row only. If any row after the failing ones saved cleanly, a green "Allergies updated" appears alongside it, so a partly failed save reads as a successful one.
- Evidence: `Yii::app()->user->setFlash('success', $flash_message)` and `setFlash('error', ...)` are both called inside the `foreach`, and each overwrites the previous value of its key. The two keys are independent, so a success and a failure in the same submission both render. Separately, `$allergy = OphCiExaminationAllergy::model()->findByPk($attributes['id'])` at `:55` is unguarded, so a stale id posted from a page left open while another administrator deleted the row produces a fatal rather than a message.
- Severity: low.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-406: The order set for allergy reactions never reaches the clinician (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/widgets/Allergies.php:143` (`getViewData()`).
- Route: admin at `/OphCiExamination/admin/AllergyReactions` - Menu > Admin / Examination > Allergy Reactions; clinical on the Allergies element of any Examination event.
- Repro:
  1. Open Allergy Reactions and drag a reaction to the top of the list.
  2. Select Save. The admin screen keeps the new order.
  3. Open an Examination event, add an allergy, and open the Reactions picker.
- Expected: the reactions are offered in the order just set.
- Actual: they are offered in the database's own order, which in practice is the order the rows were created in.
- Evidence: the widget builds its list with `OphCiExaminationAllergyReaction::model()->active()->findAll()`. The model defines two scopes at `:149-153`, `active` and `bydisplayorder`, and only the first is applied; there is no `defaultScope`. The admin screen does write the order - `BaseAdminController::genericAdmin()` sets `$item->display_order = $j + 1` for every posted row and reloads the list with `array('order' => 'display_order')` at `:328-331`, which is why the ordering appears to have taken.
- Severity: low-medium. The reordering control works and is honoured on the screen that offers it, so there is nothing to tell an administrator that the setting is inert where it matters.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-407: Unticking the large-print AIS flag makes every Examination save fatal (CONFIRMED code/db)

- Where: `protected/modules/OphCiExamination/components/BCAISFlagsManager.php:300-303` (`updateLargePrintIfNeeded()`).
- Route: admin at `/OphCiExamination/admin/AISFlags` - Menu > Admin / Examination > AIS Flags.
- Repro:
  1. Open AIS Flags and untick Large Print on the one flag that carries it, "Requires written information in at least 24-point sans serif font".
  2. Select Save.
  3. Have a patient record arrive from PAS carrying a large-print requirement, or otherwise drive the accessibility flags update.
- Expected: the flag update is skipped, or a warning is recorded.
- Actual: `$large_print_flag` is null and reading `->value` on it is fatal.
- Evidence: `$large_print_flag = AISFlag::model()->find("large_print=1"); $new_entry = $this->addEntry($large_print_flag->value);` with no null check, in a class whose own `addEntry()` at `:212-218` does guard the equivalent lookup and records a warning. The admin screen exposes the flag as an editable checkbox - `views/admin/aisflag.php:73` renders `CHtml::activeCheckBox($data, "[$row]large_print")` - and `large_print` is listed as safe in `models/AISFlag.php:71`, so an administrator can clear it. Exactly one of the 29 shipped flags has `large_print = 1`. The same method carries a second unguarded dereference at `:320`, `$entry->aisFlag->large_print`, which fatals if a flag row referenced by an existing entry has been removed.
- Severity: medium.
- Status: CONFIRMED from source and DB at develop 53b077c089.

## BUG-408: A rejected AIS flag edit produces an application error page (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/controllers/traits/AdminForAISFlag.php:60-70` (`saveAISFlags()`).
- Route: `/OphCiExamination/admin/AISFlags` - Menu > Admin / Examination > AIS Flags.
- Repro:
  1. Open AIS Flags.
  2. Clear the Value or the Display Name on any row, or type more than 70 characters into either.
  3. Select Save.
- Expected: the row is marked with its error and the rest of the edits are held on the form.
- Actual: an application error page appears, carrying `Could not save AIS Flags:` and the raw model error array. Every edit made in the visit is lost.
- Evidence: `if (!$ais_flag->save()) { $transaction->rollback(); throw new RuntimeException("Could not save AIS Flags: " . print_r($ais_flag->getErrors(), true)); }`, with a matching throw at `:61` for a missing id. Separately, `AISFlag::model()->resetScope()->findByPk($posted_AIS_flag["id"])` at `:65` is unguarded, so a stale id fatals instead. This is the same shape as BUG-397 on the correspondence delivery configuration screen.
- Severity: low-medium.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-409: Saving common post-op complications without a subspecialty produces an application error (CONFIRMED code/db)

- Where: `protected/modules/OphCiExamination/controllers/AdminController.php:1195-1211` (`actionUpdatePostOpComplications()`) and `models/OphCiExamination_PostOpComplications.php:150-175` (`assign()`).
- Route: `/OphCiExamination/admin/postOpComplications` - Menu > Admin / Examination > Common Post-Op Complications.
- Repro:
  1. Open the screen. Subspecialty opens on `- Select -`.
  2. Without choosing a subspecialty, add one or more complications.
  3. Select Save.
- Expected: either the save is refused with a message asking for a subspecialty, or the choice is stored against every subspecialty.
- Actual: an application error page reading "Could not save PostOpComplications." The selections are discarded.
- Evidence: the empty option posts `subspecialty_id` as an empty string. `assign()` treats it as falsy and deletes on `subspecialty_id is null`, which matches nothing because the column is `int(10) unsigned NOT NULL`, then builds insert rows carrying `'subspecialty_id' => ''`. Under the installation's `STRICT_TRANS_TABLES` that raises a database exception, which `actionUpdatePostOpComplications()` catches and rethrows as the generic message at `:1205`. Opening the screen with no subspecialty is equally uninformative: `enabled($institution_id, null)` compares `cs.subspecialty_id = NULL`, so the list shows empty even where data exists.
- Severity: medium. It is reached by the screen's own default state.
- Status: CONFIRMED from source and DB at develop 53b077c089.

## BUG-410: The Institution control on common post-op complications can never be changed (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/views/admin/list_OphCiExamination_PostOpComplications.php:32-38` and `protected/assets/js/admin.js:43-47`.
- Route: `/OphCiExamination/admin/postOpComplications` - Menu > Admin / Examination > Common Post-Op Complications.
- Repro:
  1. Open the screen as an installation administrator.
  2. Open the Institution dropdown.
- Expected: the institutions the administrator may configure.
- Actual: exactly one entry, the institution currently being worked in. There is no way to set up another institution's shortlist from this screen, and no indication that the control is decorative.
- Evidence: the dropdown is populated from `Institution::model()->getTenantedList(true)`, and `Institution::getTenantedList()` at `:239-246` returns `[$current->id => $current->name]` whenever `$current_institution_only` is true. Every sibling screen that offers an institution choice passes `false`. The subspecialty control compounds the confusion: `admin.js:43-47` navigates to `.../postOpComplications?subspecialty_id=` and drops `institution_id` entirely, which is harmless only because the controller then defaults it back to the session institution - the same value the dropdown was showing.
- Severity: low.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-411: Installation-wide post-op complication rows can be seen but never removed (CONFIRMED code/schema)

- Where: `protected/modules/OphCiExamination/models/OphCiExamination_PostOpComplications.php:113-126` (`enabled()`) against `:150-160` (`assign()`).
- Route: `/OphCiExamination/admin/postOpComplications` - Menu > Admin / Examination > Common Post-Op Complications.
- Repro: requires a row in `ophciexamination_postop_complications_subspecialty` with a null `institution_id`, which no screen creates.
  1. With such a row present, open the screen for any institution. The complication is listed as enabled.
  2. Remove it and select Save.
- Expected: it is removed.
- Actual: it comes straight back, and the save has additionally written a second copy of it against the current institution.
- Evidence: `enabled()` matches `(cs.institution_id IS NULL OR cs.institution_id = :institution_id)`, so a null-institution row shows for every institution. `assign()` deletes only `institution_id = :institution_id`, so it never removes one, and then re-inserts everything left on screen with the current institution id. The column is `institution_id int(10) unsigned DEFAULT NULL` and, unlike `subspecialty_id` and `complication_id`, carries no foreign key.
- Severity: low, and latent - all 45 rows on the sample installation belong to institution 1.
- Status: CONFIRMED from source and schema at develop 53b077c089. NOT reproducible on the sample installation.

## BUG-412: The order set for common post-op complications never reaches the clinician (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/models/OphCiExamination_PostOpComplications.php:92-103` (`getComplicationsBySubspecialty()`) and `:47-50` (`defaultScope()`).
- Route: admin at `/OphCiExamination/admin/postOpComplications`; clinical on the post-op complications picker of an Examination event.
- Repro:
  1. Open Common Post-Op Complications, choose a subspecialty, and drag the shortlist into a deliberate order - most common first.
  2. Select Save.
  3. Open an Examination in that subspecialty and open the post-op complications picker.
- Expected: the shortlist is offered in the order just set.
- Actual: it is offered in the complications' own global display order.
- Evidence: `assign()` writes a per-institution, per-subspecialty `display_order` into `ophciexamination_postop_complications_subspecialty` from the posted row order, and `enabled()` reads it back with `'order' => 'cs.display_order'` for the admin screen. The clinician-facing `getComplicationsBySubspecialty()` sets no order of its own, so it inherits `defaultScope()`, which orders by `t.display_order` - the column on the complication itself, shared by every institution and subspecialty. Nothing reads `cs.display_order` outside the admin screen.
- Severity: medium. Ordering the shortlist is the main thing this screen is for.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-413: The "available" complications scope filters nothing (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/models/OphCiExamination_PostOpComplications.php:128-141` (`available()`).
- Route: `/OphCiExamination/admin/postOpComplications` - Menu > Admin / Examination > Common Post-Op Complications.
- Repro:
  1. Deactivate a post-op complication on `/oeadmin/PostOpComplication/list`.
  2. Open Common Post-Op Complications and open the "Add a Complication" dropdown.
- Expected: the deactivated complication is not offered, and neither are complications already on the shortlist.
- Actual: every complication in the installation is offered, active or not, whether or not it is already enabled.
- Evidence: the method is documented "Named scope to fetch available (non-enabled) items for the given subspecialty" but merges only a `LEFT JOIN` and an `order` - there is no condition of any kind, on `active`, on the subspecialty, or on whether an assignment row exists. The join also multiplies rows by their assignment count; that part is masked because `AdminController.php:1191` funnels the result through `CHtml::listData(..., 'id', 'name', '')`, which collapses duplicate ids. This is the admin-side half of the same root cause as BUG-383.
- Severity: low.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-414: A rejected element attribute renders a page reading "error1" (CONFIRMED code)

- Where: `protected/controllers/oeadmin/ExaminationElementAttributesController.php:145-147`, `:166-176` and `:193-196` (`actionUpdate()`).
- Route: `/oeadmin/ExaminationElementAttributes/list` - Menu > Admin / Examination > Element Attributes.
- Repro:
  1. Open Element Attributes and select Add.
  2. Leave the Name empty, or reuse the name of an existing attribute.
  3. Select Save.
- Expected: the form redisplays with the field marked.
- Actual: a blank page containing the single word `error1` (or `error` on the add-with-element path). The typed values are gone and there is no way back except the browser's own controls.
- Evidence: each failure branch is `echo 'error1'; print_r($newOCEA->getErrors(), true);`. Passing `true` as the second argument to `print_r` returns the string instead of printing it, so even the diagnostic the author intended is discarded and only the literal marker reaches the browser. The edit branch at `:194` compounds it by printing `$newOCEA` - the empty new model created at the top of the action - rather than `$attribute`, the model that actually failed.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-415: The element attribute search action is broken three ways and unreachable (CONFIRMED code/db)

- Where: `protected/controllers/oeadmin/ExaminationElementAttributesController.php:258-275` (`actionSearch()`).
- Route: `/oeadmin/ExaminationElementAttributes/search`, which no screen links to.
- Repro: not reachable from the interface. Requesting the route directly as an AJAX call exercises it.
- Expected: a list of matching attribute names.
- Actual: a database error.
- Evidence: three independent faults in eighteen lines. `$criteria->addCondition(array('LOWER(name) LIKE :term'), 'OR')` passes an array where a string is expected. `$params` is only assigned inside the `term` branch, so `$criteria->params = $params` at `:270` reads an undefined variable on any other path. And `$criteria->addCondition('active = 1')` at `:269` names a column that `ophciexamination_attribute` does not have - its columns are id, name, label, institution_id, display_order, is_multiselect and the four audit columns.
- Severity: low, and latent - nothing calls it.
- Status: CONFIRMED from source and DB at develop 53b077c089.

## BUG-416: Four Investigation element attributes are configurable but never shown (CONFIRMED code/db)

- Where: `protected/modules/OphCiExamination/views/default/form_Element_OphCiExamination_Investigation.php`, which contains no reference to attributes at all.
- Route: admin at `/oeadmin/ExaminationElementAttributes/list` - Menu > Admin / Examination > Element Attributes; clinical on the Investigation element of an Examination event.
- Repro:
  1. Open Element Attributes. Four rows are listed against the Investigation element: Visual Fields, OCT, B-Scan and Topography.
  2. Select Manage Options on any of them and add, remove or reorder its options.
  3. Open an Examination event and add the Investigation element.
- Expected: the attribute and its options appear on the element.
- Actual: the element shows no attributes. Nothing an administrator does on those four rows has any effect anywhere.
- Evidence: attributes reach an element through `DefaultController::getAttributes()` at `:1450-1458`. The only callers are `form_Element_OphCiExamination_History.php:87`, `form_Element_OphCiExamination_Management.php:44`, `form_Element_OphCiExamination_AdnexalComorbidity.php:48`, the shared `_attributes.php` partial (rendered only by `form_Element_OphCiExamination_Conclusion.php:21`) and the two widget views `ClinicalManagement_event_edit.php:28` and `AdviceGiven.php:32`. The Investigation form is not among them. The four rows carry 37 options between them in `ophciexamination_attribute_option`.
- Severity: medium. The screen presents them exactly like the twelve attributes that do work.
- Status: CONFIRMED from source and DB at develop 53b077c089.

## BUG-417: Deleting an element attribute destroys its options before checking whether it may be deleted (CONFIRMED code)

- Where: `protected/controllers/oeadmin/ExaminationElementAttributesController.php:222-255` (`actionDelete()`).
- Route: `/oeadmin/ExaminationElementAttributes/list` - Menu > Admin / Examination > Element Attributes.
- Repro:
  1. Open Element Attributes and tick an attribute whose options are in use on saved events.
  2. Delete it with the option to remove its sub-records.
- Expected: the in-use check refuses the whole operation and nothing is removed.
- Actual: every option belonging to the attribute is deleted first, and only then does the guard run and report "Cannot delete; Attribute Element is in use". The attribute survives with no options, and the events that referenced them have lost their labels.
- Evidence: `if (Yii::app()->request->getPost('DELETE_SUBS_ALSO')) { $this->deleteAttributeElements($element); }` runs at `:231-233`, before `if ($element && $this->isAttributeElementDeletable($element))` at `:235`. `deleteAttributeElements()` at `:298-301` is an unconditional `OphCiExamination_AttributeOption::model()->deleteAll('attribute_element_id = :id', ...)`. It is also typed `OphCiExamination_AttributeElement $element` and called before the `$element &&` test, so an attribute with no element mapping fatals on the argument type instead.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-418: The Element Attributes list puts three headings over the wrong columns (CONFIRMED code)

- Where: `protected/views/admin/generic/listInstitution.php:88-115` (header loop) against `:126-165` (body loop), as used by `controllers/oeadmin/ExaminationElementAttributesController.php:36-75`.
- Route: `/oeadmin/ExaminationElementAttributes/list` - Menu > Admin / Examination > Element Attributes.
- Repro:
  1. Open Element Attributes.
  2. Read the column headings against the rows beneath them.
- Expected: each heading names the column below it.
- Actual: the element name sits under a heading reading Action, and the Manage Options link sits under the heading for the element column.
- Evidence: the header loop emits `<th>Action</th>` in the slot belonging to the `attribute_elements.id` field and then a normal heading for `attribute_element_types.name`. The body loop skips `attribute_elements.id` entirely, keeping its value in `$mappingId`, and appends the Manage Options cell after the element-name cell. Both rows end up six cells wide, so nothing looks obviously broken - the fourth and fifth headings are simply describing each other's data.
- Severity: low.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-419: The Manage Options link breaks if an attribute maps to more than one element (CONFIRMED code)

- Where: `protected/views/admin/generic/listInstitution.php:150-152` and `:157-161`, resolved through `protected/components/Admin.php:807-823` (`attributeValue()`).
- Route: `/oeadmin/ExaminationElementAttributes/list` - Menu > Admin / Examination > Element Attributes.
- Repro: requires an attribute with two rows in `ophciexamination_attribute_element`, which the interface does not create.
  1. With such an attribute present, open Element Attributes and select its Manage Options link.
- Expected: the options for that mapping.
- Actual: the link carries `attribute_element_id=3,7` and the target cannot resolve it.
- Evidence: `$mappingId = $admin->attributeValue($row, 'attribute_elements.id')`, and for a has-many relation `attributeValue()` falls through to `implode(',', $manyResult)`. The guard `if (($mappingId > 0))` compares a leading-numeric string, so it passes and the link is still drawn. The controller's own write paths assume one mapping throughout - `actionUpdate()` creates exactly one and `findByAttributes(array('attribute_id' => $attributeId))` at `:216` reads back only the first.
- Severity: low, and latent - each of the 19 shipped attributes has exactly one mapping.
- Status: CONFIRMED from source and DB at develop 53b077c089. NOT reproducible on the sample installation.

## BUG-420: The Clinical Maculopathy edit form is labelled for retinopathy (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/modules/ExaminationAdmin/views/DrGrading/form_OphCiExamination_Clinical_Pathy.php:37`, reached through `views/DrGrading/update_clinical.php:35` from `controllers/DRGradingController.php:208` and `:234`.
- Route: `/OphCiExamination/admin/DRGrading/ViewClinicalMaculopathy` - Menu > Admin / Examination > DR Grading - Clinical Maculopathy.
- Repro:
  1. Open DR Grading - Clinical Maculopathy.
  2. Select any row, or select Add.
- Expected: the form's first field is labelled Maculopathy clinical grade.
- Actual: it is labelled Retinopathy clinical grade, on both the edit and the add form.
- Evidence: the form partial hardcodes `<td>Retinopathy clinical grade</td>`, where the list template that sits beside it interpolates the same value correctly at `list_OphCiExamination_Clinical_Pathy.php:53` (`<th><?=$pathy?> clinical grade</th>`). Both maculopathy actions pass `'pathy' => 'Maculopathy'` into the shared view, so the value is available and simply not used. The two retinopathy actions pass `'pathy' => 'Retinopathy'`, which is why the defect is invisible on the retinopathy screens.
- Severity: low - wrong wording only, the field saves to the right table.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-421: "Photocoagulation scaring" is misspelt where clinicians read it (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/widgets/views/DRGrading_event_edit.php:297` (adder header) and `protected/modules/OphCiExamination/components/OphCiExamination_API.php:1546` (rendered table).
- Route: patient summary > Add Event > Examination > DR Grading element; and any correspondence or view that renders the API's DR grading table.
- Repro:
  1. Open a patient and start or edit an Examination carrying the DR Grading element.
  2. Open the Photocoagulation adder on either eye.
- Expected: "Photocoagulation scarring", as the administration screen and its menu entry spell it.
- Actual: "Photocoagulation scaring" in the adder header and in the API-rendered summary table.
- Evidence: the adder is configured with `"header": "Photocoagulation scaring"`; the API emits `<td>Photocoagulation scaring</td>`. The admin menu entry at `modules/ExaminationAdmin/config/common.php:97` reads "DR Grading - Photocoagulation Scarring" and its view file is `list_OphCiExamination_Photocoagulation_Scarring.php`, so the two halves of the feature disagree. The model class is itself named `OphCiExamination_Photocoagulation_Scaring`, so the misspelling is carried in code as well as in display text.
- Severity: low.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-422: Five shipped national retinopathy grades contain a literal question mark (CONFIRMED db)

- Where: `ophciexamination_drgrading_national_retinopathy`, rows 7, 8, 9, 10 and 12.
- Route: `/OphCiExamination/admin/DRGrading/ViewNationalRetinopathy` - Menu > Admin / Examination > DR Grading - National Retinopathy.
- Repro:
  1. Open DR Grading - National Retinopathy.
  2. Tick Show Deleted.
  3. Read rows 7 to 12.
- Expected: "R1 - Mild NPDR" and similar.
- Actual: "R1 ? Mild NPDR", "R2 ? Moderate NPDR", "R3S ? Stable treated PDR", "R3A ? Active PDR", "R2 ? Severe NPDR".
- Evidence: `SELECT HEX(value)` on row 7 returns `5231203F204D696C64204E504452`, so the byte is a genuine `0x3F` question mark stored in the data, not a rendering or client encoding artefact. The same five rows carry `deleted = 1`, so they surface only with Show Deleted ticked and on gradings recorded before they were withdrawn; the five live rows (R0, R1, R2, R3A, R3S) are unaffected.
- Severity: low, and confined to withdrawn rows.
- Status: CONFIRMED from DB on the sample installation at develop 53b077c089.

## BUG-423: A shipped Botox symptom frequency has mismatched quotation marks (CONFIRMED db)

- Where: `ophciexamination_botoxmanagement_symptomfrequency`, row 5.
- Route: `/OphCiExamination/admin/BotoxManagementSymptomFrequency/index` - Menu > Admin / Examination > Botox Management - Symptom Frequency; and the Botox Management element's frequency picker.
- Repro:
  1. Open Botox Management - Symptom Frequency.
  2. Read the fifth row.
- Expected: matched quotation marks around the quoted word.
- Actual: `Functionally 'blind" due to persistent eye closure (blepharospasm) more than 50% of the waking time"` - an opening single quote closed by a double quote, and a stray double quote at the end.
- Evidence: read directly from the shipped row. The text reaches the clinician unchanged, because the picker renders the stored name.
- Severity: low.
- Status: CONFIRMED from DB on the sample installation at develop 53b077c089.

## BUG-424: The Add Driving Advice Status form silently discards Display order and Active (CONFIRMED code/db)

- Where: `protected/modules/OphCiExamination/modules/ExaminationAdmin/controllers/DrivingSafetyController.php:99` against `protected/modules/OphCiExamination/models/SocialHistoryDrivingStatus.php:60-67`.
- Route: `/OphCiExamination/admin/DrivingSafety/editDrivingSafetyStatus` > Add - Menu > Admin / Examination > Driving Advice - Status.
- Repro:
  1. Open Driving Advice - Status and select Add.
  2. Enter a Name, type a Display order, and untick Active.
  3. Select Save.
- Expected: the status is stored inactive and in the position given.
- Actual: it is stored active with no display order, so it is offered to clinicians immediately and appears at the top of their list.
- Evidence: the add form offers all three fields (`views/DrivingSafety/driving_safety_status_create.php` renders `activeTextField($model, 'display_order')` and `activeCheckbox($model, 'active')`), but the model declares only `array('name', 'safe')` outside the search scenario, so the mass assignment at `$model->attributes = $_POST[...]` drops the other two without error. The column defaults then apply: `active` defaults to 1 and `display_order` to NULL. The clinician's picker reads the list through `models/traits/HasRelationOptions.php:99-108`, which does `->activeOrPk($current_pks)->findAll(['order' => 'display_order asc'])`, and NULL sorts first in MySQL, so the new status lands above every configured one.
- Severity: medium - the new status goes live at the top of the list whatever the administrator chose.
- Status: CONFIRMED from source and DB at develop 53b077c089.

## BUG-425: The last driving standard cannot be removed from a status (CONFIRMED code)

- Where: `protected/modules/OphCiExamination/modules/ExaminationAdmin/controllers/DrivingSafetyController.php:56` and `:68-70`, against `protected/widgets/views/MultiSelectList.php:125-127`.
- Route: `/OphCiExamination/admin/DrivingSafety/editDrivingSafetyStatus` - Menu > Admin / Examination > Driving Advice - Status.
- Repro:
  1. Open Driving Advice - Status.
  2. On a status that has exactly one standard, remove it with the cross beside it.
  3. Select Save.
- Expected: the status is left with no standards.
- Actual: the standard is still there. Removing it a second time and saving again does work.
- Evidence: the controller rebuilds assignments only for statuses present in the POST - `$standards = $_POST[...]['driving_standard'] ?? []` and then `foreach ($standards as $index => $standard_entry)`, with `deleteAllByAttributes` inside that loop. Each selected standard is posted by a hidden input inside its own list item, so a status whose items have all been removed posts nothing at all under its key and is never visited. The widget does emit a placeholder input for an empty selection, but only under `if (Yii::app()->request->isPostRequest && empty($selected_ids))`, which is false on the page as first loaded and true only on the page re-rendered after a save - hence the second attempt succeeding. Assignment failures in the same loop are reported through `setFlash('Error', ...)` with a capitalised key that the layout does not render, so a partial failure is silent.
- Severity: medium.
- Status: CONFIRMED from source at develop 53b077c089.

## BUG-426: The Eye Medications section of an Examination is always empty - every eye drop and intravitreal injection is filed as systemic (CONFIRMED code/db)

- Where: `protected/models/MedicationRoute.php:32-33` declares `final const int ROUTE_EYE = 1;` and `final const int ROUTE_INTRAVITREAL = 6;`. Neither id exists: `medication_route` runs from id 21 to id 89 (69 rows), with Eye at id 54 and Intravitreal at id 77. The two constants are the whole basis of the eye/systemic split in `protected/modules/OphCiExamination/widgets/views/HistoryMedications_event_view.php:36` (`in_array($e->route_id, array(MedicationRoute::ROUTE_EYE, MedicationRoute::ROUTE_INTRAVITREAL))`) and `:74` (the same test negated), and again in `HistoryMedications_prescription_print_view.php:8` and `:38`. The first test can never be true and the second is always true.
- Route: `/OphCiExamination/default/view/<event_id>` for any Examination carrying the History Medications element, and the prescription print view.
- Repro:
  1. Open a patient who has a current medication recorded with the **Eye** or **Intravitreal** route.
  2. Open an Examination event that carries the Medications element and read the event view (not the edit form).
  3. Look at the **Eye Medications** and **Systemic Medications** headings.
- Expected: eye drops and intravitreal injections under **Eye Medications**, everything else under **Systemic Medications**.
- Actual: **Eye Medications** renders its heading with nothing under it, and the eye medications appear in the **Systemic Medications** list along with the tablets. Printing a prescription splits it the same wrong way.
- Evidence: constants and both view files read in the container at develop 53b077c089. `SELECT id, term FROM medication_route WHERE id IN (1,6)` returns nothing; `SELECT MIN(id), MAX(id), COUNT(*) FROM medication_route` returns 21, 89, 69; Eye is id 54 and Intravitreal is id 77. The same model already carries a correct route test - `isEyeRoute()` at `:165` returns `has_laterality == 1`, and `listEyeRouteIds()` at `:181-193` builds the id list from it - and that is what `HistoryMedications_event_edit.php:350` and `MedicationManagement_event_edit.php:456` use. Only the read-only views use the constants.
- Severity: medium-high. The split exists so that a clinician reading an Examination can see at a glance what is going into the eye. It never works, and it fails in the direction that hides the eye medications inside a longer systemic list rather than leaving them out. The edit form gets it right, so the error only shows once the event is saved and read back.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-427: Deactivating a medication route blanks it out of every prescription that already uses it (CONFIRMED code)

- Where: `MedicationRoute::activeOrPk()` (`protected/models/MedicationRoute.php:142-150`) is meant to keep an already-saved route in a picker even after it stops being offered: it builds `deleted_date IS NULL` OR `id IN (<saved ids>)` and merges that into the model criteria. Both callers then hand `findAll()` a second condition, and `CDbCriteria::mergeWith()` joins the two with AND: `protected/modules/OphDrPrescription/views/default/form_Element_OphDrPrescription_Details_Item.php:114-118` passes `'condition' => 'source_type =:source_type AND is_active=1'`. The saved-id escape clause is therefore ANDed with `is_active=1` and does nothing. The Examination medication elements build the same list without the escape clause at all - `OphCiExamination/models/BaseMedicationElement.php:202-206`.
- Route: `/OphDrPrescription/default/update/<event_id>` (and the Examination medication elements) for any record whose route has since been deactivated on `/OphDrPrescription/routesAdmin/list`.
- Repro:
  1. Record a prescription item with a route, and save it.
  2. Go to **Admin > Drugs > Medication Routes**, tick that route and select **Deactivate**.
  3. Reopen the prescription for editing and look at the item's route.
  4. Save the prescription without touching that item.
- Expected: the saved route still shown and still selected, marked as no longer offered for new items - which is exactly what `activeOrPk` was written to do.
- Actual: the dropdown falls back to **-- Select --**, so the route reads as never having been chosen; saving the event then writes that empty value over the recorded route. No warning is shown at any point.
- Evidence: `activeOrPk` and both call sites read in the container at develop 53b077c089; `CDbCriteria::mergeWith($criteria, $useAnd = true)` parenthesises each side and joins with AND. Latent in the sample database, where all 69 routes are `source_type = 'DM+D'` and `is_active = 1` - the Deactivate button on the routes admin screen is what triggers it.
- Severity: medium. The route is part of how a medicine is given; losing it silently on an unrelated edit is a records defect, and the escape clause meant to prevent exactly this is inert.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-428: A medication route added through the admin screen is invisible to clinicians unless Source Type is typed exactly "DM+D" (CONFIRMED code/db)

- Where: `RoutesAdminController::actionAdd()` (`protected/modules/OphDrPrescription/controllers/RoutesAdminController.php:86-97`) offers Term, Source Type, Source Subtype and Has Laterality, all free text or tick boxes, with no guidance and no validation. Every clinician-facing route picker filters on one exact literal: `BaseMedicationElement::getRouteOptions()` (`OphCiExamination/models/BaseMedicationElement.php:202-206`) and `form_Element_OphDrPrescription_Details_Item.php:115-118` both use `'condition' => 'source_type =:source_type AND is_active=1'` with `':source_type' => 'DM+D'`.
- Route: `/OphDrPrescription/routesAdmin/add`
- Repro:
  1. Go to **Admin > Drugs > Medication Routes** and select **Add**.
  2. Enter a **Term**, leave **Source Type** blank, and select **Save**.
  3. Open a prescription or an Examination medication element and open the route dropdown.
- Expected: either the new route offered, or the form saying what Source Type has to be.
- Actual: the route is saved and appears in this admin list, but no clinician can ever pick it. It does show in some administrative pickers - the medication default-route field at `RefMedicationAdminController.php:141` lists every undeleted route regardless of source - so the value looks live from the admin side while being unusable from the clinical side.
- Evidence: controller, both filter sites and the unfiltered admin picker read in the container at develop 53b077c089. `SELECT source_type, is_active, COUNT(*) FROM medication_route GROUP BY source_type, is_active` returns a single group, `DM+D / 1 / 69` - every shipped route carries the literal, and nothing on the Add form says so.
- Severity: medium. Adding a route is one of the few things this screen is for, and the way to make it work is undiscoverable.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-429: A medication route can be saved with no Term at all (CONFIRMED code/db)

- Where: `MedicationRoute::rules()` (`protected/models/MedicationRoute.php:46-58`) has no `required` rule on any attribute; `term` carries only `array('term, code, source_type, source_subtype', 'length', 'max' => 45)`, which an empty string satisfies. `Admin::editModel()` (`protected/components/Admin.php:627`) mass-assigns the post and saves on `validate()`.
- Route: `/OphDrPrescription/routesAdmin/add`
- Repro:
  1. Go to **Admin > Drugs > Medication Routes** and select **Add**.
  2. Leave every box empty and select **Save**.
- Expected: "Term cannot be blank".
- Actual: the row saves. It appears in the routes list as a blank line, and wherever routes are listed without a source filter - the medication default-route picker at `RefMedicationAdminController.php:141`, the drug-set editor at `views/admin/medication/edit_sets.php:34` - it appears as a blank, selectable option. `MedicationRoute::__toString()` returns the empty term, so nothing anywhere names it.
- Evidence: rules and the save path read in the container at develop 53b077c089; `medication_route.term` is `varchar(255) DEFAULT NULL`, so the column accepts it.
- Severity: low-medium. One mis-click leaves an unnamed row that cannot be told apart from any other unnamed row, and there is no delete on this screen to remove it.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-430: A new medication route is always created active, because the Add form has no Active box (CONFIRMED code/db)

- Where: `RoutesAdminController::actionAdd()` (`protected/modules/OphDrPrescription/controllers/RoutesAdminController.php:89-94`) sets the edit fields to Term, Source Type, Source Subtype and Has Laterality. `actionEdit()` at `:75-81` sets the same four plus `'is_active' => 'checkbox'`. With no field rendered on Add, nothing is posted for `is_active` and the column default applies: `medication_route.is_active tinyint(1) DEFAULT 1`.
- Route: `/OphDrPrescription/routesAdmin/add`
- Repro:
  1. Go to **Admin > Drugs > Medication Routes** and select **Add**.
  2. Enter a **Term** and a **Source Type** of `DM+D`, and select **Save**.
  3. Look at the **Active** column on the row you just created.
- Expected: the option to prepare a route before it is offered, as the Edit form allows.
- Actual: the route is live on every prescription and Examination medication picker the moment it is saved. Deactivating it takes a second pass through the Edit form. This is the same outcome as BUG-280 but a different mechanism - there the tick box is rendered and its value discarded, here the field is simply absent.
- Evidence: both actions and the table default read in the container at develop 53b077c089.
- Severity: low. One extra edit fixes it, but there is no way to stage a route.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-431: Deactivate on the Medication Routes screen makes the row vanish as though it had been deleted (CONFIRMED code)

- Where: the button is labelled **Deactivate** and posts to `/OphDrPrescription/routesAdmin/deactivate`, which sets `is_active = 0` and saves (`RoutesAdminController.php:54-63` and `:99-114`). It carries `id="et_delete"`, so the shared handler at `protected/assets/js/handleButtons.js:62-140` runs it. On a successful response that handler removes the row from the table - `:113-118`, `$form.find('table.standard tbody input[type="checkbox"]:checked').closest('tr').remove()` - unless the object name is one of `users`, `teams` or `pgdpsds`, the three screens whose delete button also only deactivates. `MedicationRoutes` is not in that list. With nothing ticked, the same handler alerts "Please select one or more items to delete."
- Route: `/OphDrPrescription/routesAdmin/list`
- Repro:
  1. Go to **Admin > Drugs > Medication Routes**.
  2. Select **Deactivate** with no row ticked, and read the message.
  3. Tick a route and select **Deactivate**.
  4. Reload the page.
- Expected: the row stays and its **Active** column changes to a cross, as it does on the Users and Teams screens; and a prompt that talks about deactivating.
- Actual: the message says "Please select one or more items to delete"; the row disappears on success, so the route reads as deleted, and it reappears - inactive - only after a reload. Nothing warns first, and there is no undo on the screen. A refused save additionally reports the fixed wording recorded in BUG-368.
- Evidence: controller and `handleButtons.js` read in the container at develop 53b077c089. `updateActiveIcon($form)` at `:110-112` is the correct branch and is reached only for the three hard-coded names.
- Severity: low-medium. The screen has no delete at all, so a row disappearing is a false report of an irreversible action.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-432: The Add and Edit forms for medication routes are headed with the raw class name (CONFIRMED code)

- Where: `protected/views/admin/generic/edit.php:28` prints `($admin->getModel()->id ? 'Edit' : 'Add') . ' ' . $admin->getModelDisplayName()`, and `Admin::getModelDisplayName()` (`protected/components/Admin.php:279-286`) falls back to `$this->modelName` when no display name was set. `RoutesAdminController::actionList()` calls `setModelDisplayName('Medication Routes')` at `:67`, but `actionEdit()` (`:71-84`) and `actionAdd()` (`:86-97`) do not.
- Route: `/OphDrPrescription/routesAdmin/add` and `/OphDrPrescription/routesAdmin/edit/<id>`
- Repro:
  1. Go to **Admin > Drugs > Medication Routes**.
  2. Select **Add**, or select a row to edit it.
  3. Read the heading.
- Expected: "Add Medication Route" / "Edit Medication Route", matching the list heading.
- Actual: "Add MedicationRoute" / "Edit MedicationRoute".
- Evidence: view, component and controller read in the container at develop 53b077c089.
- Severity: low - cosmetic, but it is the page title and it exposes an internal name.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-433: Clearing one signatory role's name on the Prescription Signatures screen deletes every signatory role (CONFIRMED code)

- Where: `SignaturesController::updateSignaturesFromPost()` (`protected/modules/OphDrPrescription/modules/OphDrPrescriptionAdmin/controllers/SignaturesController.php:59-86`) collects `$delete_except_ids[]` only for rows that saved (`:73-77`), then calls `deleteSignatures($delete_except_ids, $current_institution_id)`. `deleteSignatures()` at `:88-107` starts `$criteria = null;` and builds the "keep these" condition only `if ($ids_top_keep)`. With an empty keep-list the criteria stays null, so `findAllAtLevels()` returns every signatory role at that level and the loop at `:104-106` deletes all of them. `SecondarySignatory::rules()` carries `['name', 'required']`, so a single blank name is enough to fail that row - and if it is the only row, or if every row is blanked, nothing is kept.
- Route: `/OphDrPrescription/OphDrPrescriptionAdmin/signatures/edit`
- Repro:
  1. Go to **Admin > Prescription > Signatures**.
  2. Clear the **Name** on the only row, or on every row.
  3. Select **Save**.
- Expected: "Name cannot be blank" against the row, with nothing deleted.
- Actual: every signatory role at that level is deleted from the database. The screen redraws showing the rows you posted with their validation errors, so the loss is not visible until the page is reloaded. There is no confirmation and no undo. The four roles that ship - Screened by, Dispensed by, Checked by, Counselled by - are installation-level and shared by every institution, so one administrator can remove them for everyone.
- Expected knock-on: once the list is empty the pharmacy worklist stops returning anything at all (see BUG-437).
- Evidence: controller read in the container at develop 53b077c089. `SELECT id, name, institution_id FROM secondary_signatory` returns the four installation-level rows, all with `institution_id` NULL. Not executed - the repro destroys shipped reference data.
- Severity: high. Reference data that prescriptions are signed against is deleted by a typo, silently, and the deletion is what the code does on the failure path rather than in spite of it.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-434: The Prescription Signatures screen edits whichever institution the URL names, without checking it is yours (CONFIRMED code)

- Where: `SignaturesController::setCurrentInstitutionVariable()` (`:29-34`) is `Institution::model()->findByPk($this->request->getParam('institution_id')) ?: (!$this->checkAccess('admin') ? Institution::model()->getCurrent() : null);` - a bare primary-key lookup with no tenancy test. The institution picker in the view is tenanted (`views/signatures/edit.php:31`, `Institution::model()->getTenantedList(!Yii::app()->user->checkAccess('admin'))`), so the restriction exists in the dropdown only. On save, `updateSignaturesFromPost()` at `:62` takes `$_POST['institution_id']` and writes it straight onto every row at `:72`, again unchecked.
- Route: `/OphDrPrescription/OphDrPrescriptionAdmin/signatures/edit?institution_id=<any id>`
- Repro:
  1. Sign in as an administrator for one institution only.
  2. Open **Admin > Prescription > Signatures** and note the institution picker lists only your own.
  3. Append `?institution_id=<the id of an institution you do not administer>` to the address.
  4. Edit a row and select **Save**.
- Expected: the request refused, or the institution silently forced back to one of yours.
- Actual: another institution's signatory roles are listed and can be renamed, deactivated, added to and deleted.
- Evidence: controller and view read in the container at develop 53b077c089. Not executed - the repro writes to another institution's reference data.
- Severity: medium. It needs a guessed id and an administrator account, but the screen is the one place these roles are held and the change lands on another organisation's prescriptions.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-435: Renaming a signatory role hides every signature already recorded under the old name (CONFIRMED code/schema)

- Where: a recorded prescription signature stores the role as a copied string, not a reference. `Element_OphDrPrescription_Esign::getSecondarySignatures()` (`protected/modules/OphDrPrescription/models/Element_OphDrPrescription_Esign.php:212-218`) builds each required signature with `$signatory->signatory_role = $secondary_signatory->name;`, and `getViewSignatures()` at `:245-251` pairs a saved signature to a required one by string equality: `$sign->signatory_role === $secondary_signatory->signatory_role`. `ophdrprescription_signature.signatory_role` is `varchar(64) NOT NULL` with no foreign key to `secondary_signatory`, so nothing propagates a rename.
- Route: **Admin > Prescription > Signatures**, then any signed prescription at `/OphDrPrescription/default/view/<event_id>`
- Repro:
  1. Have a prescription signed under a signatory role - for example **Checked by**.
  2. Go to **Admin > Prescription > Signatures** and rename that role, for example to **Checked and verified by**.
  3. Reopen the signed prescription.
- Expected: the recorded signature still shown, under whichever wording is current.
- Actual: the role is listed as unsigned. The saved signature row still exists in the database but no longer matches any configured role, so it is not displayed at all - the fact that someone signed, and who, disappears from the record. The prescription also returns to the pharmacy worklist as incomplete, permanently, because the same string comparison drives the outstanding-signature count (`OphDrPrescriptionPharmacyWorklist/controllers/DefaultController.php:183-186`).
- Evidence: model and controller read in the container at develop 53b077c089; `SHOW CREATE TABLE ophdrprescription_signature` confirms `signatory_role varchar(64) NOT NULL` and no foreign key. Sample database has no recorded signatures yet, so this is documented from source.
- Severity: medium-high. Renaming a role is an ordinary administrative act with no warning attached, and the effect is on the audit trail of a controlled document.
- Status: CONFIRMED (code/schema) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-436: An apostrophe in a signatory role's name breaks the pharmacy worklist (CONFIRMED code)

- Where: `OphDrPrescriptionPharmacyWorklist/controllers/DefaultController.php:183-184` builds the outstanding-signature subquery by string concatenation: `"... AND sub_sig.signatory_role IN ('" . implode("','", $signatory_roles) . "'))"`. The role names come straight from `secondary_signatory.name`, and `SecondarySignatory::rules()` validates only `['name', 'required']` and `['name', 'length', 'max' => 50]` - no character restriction. Every other condition in the same method is parameterised; this one is not.
- Route: `/OphDrPrescription/OphDrPrescriptionPharmacyWorklist` after adding a role whose name contains an apostrophe
- Repro:
  1. Go to **Admin > Prescription > Signatures** and add a role named, for example, **Sister's check**.
  2. Open the pharmacy worklist.
- Expected: the role saved and the worklist unaffected.
- Actual: the apostrophe closes the quoted list early and the page ends in a database error. The role name is administrator-supplied text reaching SQL unescaped, so the fault is a quoting fault rather than only a display one.
- Evidence: controller and model rules read in the container at develop 53b077c089. Not executed - the repro writes shared reference data and would leave the worklist broken for every user until the row is removed.
- Severity: medium. Natural English role names contain apostrophes, so this is reachable without trying, and it breaks a shared screen for everyone rather than only for the person who typed it.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-437: A fully signed prescription can never be shown on the pharmacy worklist, and no prescription at all is shown if the signatory list is empty (CONFIRMED code)

- Where: `OphDrPrescriptionPharmacyWorklist/controllers/DefaultController.php:186` adds, unconditionally and on top of whatever the user filtered for, `$criteria->addCondition("$all_roles_complete_query < " . count($signatory_roles));` - "fewer signatures recorded than there are configured roles". The screen's own filter builder (`:112-138`) offers every signatory role with **signed** / **not signed** and AND/OR, so a filter such as "Dispensed by signed AND Checked by signed" is offered and can never match. When no signatory roles are configured, `$signatory_roles` is empty, the subquery degenerates to `IN ('')` and the condition becomes `0 < 0`, which is false for every row.
- Route: `/OphDrPrescription/OphDrPrescriptionPharmacyWorklist`
- Repro:
  1. Open the pharmacy worklist and build a filter asking for every signatory role **signed**.
  2. Search.
  3. Separately, delete every row on **Admin > Prescription > Signatures** (BUG-433 makes this easy to do by accident) and reopen the worklist.
- Expected: a prescription that has been fully signed still findable, and an empty signatory list treated as "nothing outstanding to check" rather than as "show nothing".
- Actual: a fully signed prescription drops off the worklist and cannot be brought back by any filter; with no signatory roles configured the worklist is empty whatever is searched for, and nothing on screen says why.
- Evidence: controller read in the container at develop 53b077c089. The sample database ships four roles and no recorded signatures (`SELECT COUNT(*) FROM ophdrprescription_signature` returns 0), so every prescription currently satisfies `0 < 4` and the list looks healthy - the fault only shows once signing starts or the roles are removed.
- Severity: medium. The worklist is how pharmacy finds work, and the one state it cannot represent is "finished".
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-438: A saved prescriber signature can be dropped and shown as unsigned, depending on the order the signature rows come back (CONFIRMED code)

- Where: `Element_OphDrPrescription_Esign::getPrescriberSignatureObject()` (`protected/modules/OphDrPrescription/models/Element_OphDrPrescription_Esign.php:150-155`) reads `array_filter($this->signatures, fn($sign) => (int)$sign->type === BaseSignature::TYPE_LOGGEDIN_USER)[0] ?? null`. `array_filter` preserves the original keys, so the result only has a key `0` when the prescriber's signature happens to be the first element of `$this->signatures`. The `signatures` relation (`:85`) declares no `order`, so the order is whatever the database returns. When the lookup misses, `:161-163` quietly substitutes a fresh, unsigned prescriber object.
- Route: `/OphDrPrescription/default/update/<event_id>` and the prescription view
- Repro:
  1. Sign a prescription as the prescriber and have at least one secondary signature recorded against the same element.
  2. Reopen the prescription so the sign-off panel is rebuilt.
- Expected: the prescriber's recorded signature shown as recorded.
- Actual: whenever the prescriber's row is not the first returned, the panel shows the prescriber as unsigned and asks for the signature again; the recorded row is still in the database but is not the one displayed.
- Evidence: model read in the container at develop 53b077c089; `array_filter` key preservation is standard PHP behaviour, and the sibling call at `:235-236` does the same filter correctly with `reset()`. Latent in the sample database, which has no recorded signatures at all.
- Severity: low-medium, and conditional on row order - but the failure mode is a signature that reads as missing.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-439: Sorting the Local Drugs or DM+D Drugs list by Alternative Terms ends in a database error (CONFIRMED code/db)

- Where: `RefMedicationAdminController::actionList()` (`protected/modules/OphDrPrescription/controllers/RefMedicationAdminController.php:36-46`) puts `'alternativeTerms'` into `setListFields()`. `Medication::alternativeTerms()` (`protected/models/Medication.php:334`) is a method that builds a string - it is not a column and not a relation. `Admin::isSortableColumn()` (`protected/components/Admin.php:845-864`) refuses only sub-lists, lists with a `display_order`, names beginning `has_`, and anything the controller named in `unsortableColumns`; this controller names nothing, so the heading renders as a sort link. `ModelSearch` (`protected/components/ModelSearch.php:271-281`) then sets `$this->criteria->order = 't.' . $sortColumn` unchanged - `relationalAttribute()` at `:428-454` rewrites only names containing a dot.
- Route: `/OphDrPrescription/OphDrPrescriptionAdmin/localDrugsAdmin/list` and `/OphDrPrescription/OphDrPrescriptionAdmin/dmdDrugsAdmin/list`
- Repro:
  1. Go to **Admin > Drugs > Local Drugs** (or **DM+D Drugs**).
  2. Select the **Alternative Terms** column heading.
- Expected: the list sorted by alternative term, or the heading not offered as a link.
- Actual: an application error page. The same heading on both screens is the only one that does this; the rest sort normally.
- Evidence: controller, `Admin::isSortableColumn()` and `ModelSearch` read in the container at develop 53b077c089. The generated statement was run directly against the database: `SELECT id FROM medication t ORDER BY t.alternativeTerms LIMIT 1` returns `ERROR 1054 (42S22): Unknown column 't.alternativeTerms' in 'ORDER BY'`. The sibling screen guards the same hazard by hand - `RoutesAdminController.php:38-41` rewrites its two getter columns back to real column names before the criteria is used.
- Severity: medium. It is one click on a normal-looking column heading, and it takes out the whole screen rather than only the sort.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-440: Deleting several local drugs at once stops at the first refusal and reports that none were deleted (CONFIRMED code)

- Where: `RefMedicationAdminController::actionDelete()` (`protected/modules/OphDrPrescription/controllers/RefMedicationAdminController.php:421-439`) loops over the posted ids deleting each one, with the `try` around the whole loop and no transaction. A drug that is in use raises a foreign-key exception, which leaves the loop at that point: the drugs handled before it are already gone, the drugs after it are never looked at, and the handler answers `0`. `protected/assets/js/handleButtons.js:117-140` reads any answer other than `1` as a failure and shows "One or more Element attributes could not be deleted as they are in use.", removing no rows from the table.
- Route: `/OphDrPrescription/OphDrPrescriptionAdmin/localDrugsAdmin/list`
- Repro:
  1. Go to **Admin > Drugs > Local Drugs**.
  2. Tick two drugs nothing has used and one that has been prescribed or recorded on a patient, so that the used one is not first in the list order.
  3. Select **Delete**.
  4. Reload the page.
- Expected: either all three deleted, or none, with a message saying which one was refused.
- Actual: a message saying the deletion could not be done, and the table still showing all three rows - but after the reload the two unused drugs have gone. The message names neither the drug that was refused nor the ones that were deleted, and deleting one at a time is the only way to find out.
- Evidence: controller and `handleButtons.js` read in the container at develop 53b077c089. Deleting a single drug works normally; this is only the multiple-selection path.
- Severity: medium. It is silent partial data loss, and the message says the opposite of what happened.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-441: The Formulary drugs admin screen is unreachable, and fails on every load if reached (CONFIRMED code/db)

- Where: `FormularyDrugsAdminController::actionList()` (`protected/modules/OphDrPrescription/controllers/FormularyDrugsAdminController.php:22-38`) joins `medication_set_rule AS medSetRule` at `:31` and then adds the condition `'medSetRule.usageCode.usage_code = "Formulary"'` at `:32` - a three-part name that SQL reads as database.table.column. `usageCode` is a Yii relation name and is never joined. The controller is also referenced nowhere else: it appears in no `admin_structure` block, so nothing in the Admin menu links to it.
- Route: `/OphDrPrescription/formularyDrugsAdmin/list` (by direct address only)
- Repro:
  1. Open the address directly - there is no menu entry for it.
- Expected: either a working Formulary drugs list in the Drugs menu, or the controller removed.
- Actual: an application error page. `listFields` also carries `itemsCount`, a method rather than a column, so its heading would have BUG-439's fault as well.
- Evidence: controller read in the container at develop 53b077c089; `protected/modules/OphDrPrescription/config/common.php:24-40` lists the twelve Drugs menu entries and this is not among them; `grep -rn "FormularyDrugs" --include=*.php protected/` returns only the class declaration. The generated statement was run directly against the database: `SELECT COUNT(*) FROM medication_set t JOIN medication_set_rule AS medSetRule ON medSetRule.medication_set_id = t.id WHERE (medSetRule.usageCode.usage_code = "Formulary")` returns `ERROR 1054 (42S22): Unknown column 'medSetRule.usageCode.usage_code' in 'WHERE'`.
- Severity: low - dead code, not reachable by any user journey. Recorded so that the absence of a Formulary drugs documentation page is explained rather than looking like a gap.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-442: A failed Local Drug Mappings save is reported the same way as a successful one (CONFIRMED code)

- Where: `LocalDrugsAdminController::actionEditLocalDrugInstitutionMappings()` (`protected/modules/OphDrPrescription/modules/OphDrPrescriptionAdmin/controllers/LocalDrugsAdminController.php:82-117`) collects failures into `$errors` at `:107-109`, rolls the transaction back at `:111-112`, and then falls through to the same `$this->redirect(...)` at `:116` that the success path takes. `$errors` is never put in a flash message, logged or rendered.
- Route: `/OphDrPrescription/OphDrPrescriptionAdmin/localDrugsAdmin/ListLocalDrugInstitutionMappings`
- Repro:
  1. Go to **Admin > Drugs > Local Drug Mappings**.
  2. Change some ticks and select **Save**.
  3. Compare the ticks after the reload with what you set.
- Expected: a message when the save was refused.
- Actual: the screen reloads exactly as it does on success. The only way to notice that nothing was saved is to re-read the ticks, and because the rollback covers the whole page, one bad row silently discards every change made alongside it.
- Evidence: controller read in the container at develop 53b077c089.
- Severity: medium. These mappings decide which local drugs an institution's prescribers can pick, so a silently discarded save is discovered by a clinician not finding a drug.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-443: Saving Local Drug Mappings always returns you to the first page (CONFIRMED code)

- Where: `LocalDrugsAdminController::actionEditLocalDrugInstitutionMappings():116` redirects to the bare list address with no page number. The list paginates at twenty rows (`:77`, `'pagination' => array('pagesize' => 20)`).
- Route: `/OphDrPrescription/OphDrPrescriptionAdmin/localDrugsAdmin/ListLocalDrugInstitutionMappings`
- Repro:
  1. Go to **Admin > Drugs > Local Drug Mappings** and page forward to, say, page 4.
  2. Change a tick and select **Save**.
- Expected: page 4 again.
- Actual: page 1. Working through a long list means paging back to where you were after every save, and it is easy to lose your place and skip a page.
- Evidence: controller read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-444: The sort column on every generic admin list is put into the query unescaped (CONFIRMED code)

- Where: `ModelSearch::initialiseSearch()` (`protected/components/ModelSearch.php:271-281`) takes the `c` query parameter straight from the request and assigns `$this->criteria->order = ($sortPrefix === false ? 't.' : '') . $sortColumn;`. Yii does not quote or validate `CDbCriteria::order` - it is concatenated into the statement as written. Nothing on the path checks the value against the model's columns: `relationalAttribute()` at `:428-454` only splits on a dot, and `Admin::isSortableColumn()` governs which headings are drawn as links, not which values are accepted.
- Route: every screen rendered through `protected/views/admin/generic/list.php`, for example `/OphDrPrescription/OphDrPrescriptionAdmin/localDrugsAdmin/list?c=<value>`
- Repro:
  1. Open any generic admin list.
  2. Add a `c=` parameter to the address holding something that is not one of the screen's columns.
  3. Reload.
- Expected: an unknown sort column ignored, or the request refused.
- Actual: the value reaches the `ORDER BY` clause as typed. A name that is not a column produces a database error page (this is the mechanism behind BUG-439); anything else is executed. The parameter is a GET parameter, so no form token is involved.
- Evidence: `ModelSearch`, `Admin::isSortableColumn()` and the list view read in the container at develop 53b077c089. Confirmed from source only - no payload was constructed or run.
- Severity: medium. It needs an authenticated administrator session, and administrators legitimately read most of this data anyway, but it is an unvalidated request parameter reaching SQL on a large family of screens and it should be constrained to the screen's own column list.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-445: Deleting a drug set silently detaches every allergy and risk definition that pointed at it (CONFIRMED code/db)

- Where: `MedicationSet::beforeDelete()` (`protected/models/MedicationSet.php:828-863`) deletes the set's rules, items and auto-rule rows, and then at `:851-859` walks `medicationSetAllergyItems` and `medicationSetRiskItems` setting `medication_set_id = null` and saving. Both columns are nullable (`ophciexamination_allergy.medication_set_id` and `ophciexamination_risk_tag.medication_set_id`), so the write succeeds and the foreign keys - both declared RESTRICT (`fk_allergy_to_set`, `fk_ref_set_id`) - never fire. Nothing warns, and the return value of `save()` is not checked either.
- Route: `/OphDrPrescription/admin/AutoSetRule/index`
- Repro:
  1. Go to **Admin > Examination > Allergies** and note an allergy that names a drug set.
  2. Go to **Admin > Drugs > Drug Sets**, tick that set and select **Delete**.
  3. Return to the allergy.
- Expected: the deletion refused while an allergy or risk still points at the set, or at least a warning naming what will be detached.
- Actual: the set is deleted and the allergy is silently emptied of its drug list. The allergy still exists and is still offered to clinicians, but it no longer knows which medications trigger it, so prescribing one of those drugs raises no allergy warning. The same happens to risk definitions.
- Evidence: model read in the container at develop 53b077c089; column nullability and the two RESTRICT constraints read from `information_schema`. In the sample database 18 allergies and 2 risk tags name a drug set, out of 113 sets.
- Severity: high. It removes a clinical safety check with no message and no trace on the screen that did it.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-446: Deleting several drug sets at once stops at the first refusal and reports that none were deleted (CONFIRMED code)

- Where: `AutoSetRuleController::actionDelete()` (`protected/modules/OphDrPrescription/modules/OphDrPrescriptionAdmin/controllers/AutoSetRuleController.php:376-396`) opens a transaction **inside** the loop, one per set, and commits each before moving to the next. The first set that cannot be deleted - one another set is built from, for instance - rolls back only its own transaction, logs, answers `0` and stops. Everything deleted before it is already committed; everything after it is never attempted.
- Route: `/OphDrPrescription/admin/AutoSetRule/index`
- Repro:
  1. Go to **Admin > Drugs > Drug Sets**.
  2. Tick two sets nothing depends on and one that another set includes, so the depended-on set is not first.
  3. Select **Delete**, then reload the page.
- Expected: all three deleted, or none, with a message naming the one that was refused.
- Actual: the screen reports the deletion failed and no rows leave the table, but after the reload the first two sets have gone. Nothing names the set that blocked it or the ones that were removed.
- Evidence: controller read in the container at develop 53b077c089.
- Severity: medium. Partial data loss reported as no loss at all, on a screen where each deleted set also detaches allergies (BUG-445).
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-447: The Medication sets admin screens are unreachable, and their save discards validation failures without a word (CONFIRMED code)

- Where: `RefSetAdminController` and its subclass `PrescriptionDrugSetsAdminController` (`protected/modules/OphDrPrescription/controllers/`) provide a second, older family of drug-set admin screens. No menu reaches them: the module's `config/common.php:26-40` Drugs block has entries for twelve screens and none of these, and the only line that ever pointed here - `'All Sets' => '/OphDrPrescription/admin/DrugSet/index'` at `:27` - is commented out. Reached by direct address, `RefSetAdminController::actionSave()` (`:75-126`) calls `$model->save()` at `:88` and never looks at the result, then builds each usage rule and calls `$medSetRule->save()` at `:114` without checking that either, and redirects to the list at `:125` whatever happened. `MedicationSet::rules()` (`:84-103`) makes `name` required and unique; `MedicationSetRule::rules()` (`:57-74`) makes `medication_set_id` and `usage_code_id` required and the site/subspecialty/usage-code combination unique.
- Route: `/OphDrPrescription/refSetAdmin/list` (by direct address only)
- Repro:
  1. Open the address directly - there is no menu entry for it.
  2. Open a set, clear its **Name** or type the name of another set, and select **Save**.
- Expected: the screen to be either maintained and linked, or removed.
- Actual: the list reappears with no message and the rename has not happened. Creating a new set this way is worse: the set itself fails to save, so every usage rule is then written against an empty set id and fails too, and the screen still returns to the list as though the set had been created. The supported screen for this work is **Admin > Drugs > Drug Sets**, which is why the documentation has no page for this family.
- Evidence: controllers, models and module config read in the container at develop 53b077c089. `grep -rn "refSetAdmin" --include=*.php protected/` returns only the class itself and the three redirects inside `PrescriptionDrugSetsAdminController`; `grep -rn "DrugSet/index"` returns the commented-out menu line and a comment in `AutoSetRuleController.php:133`.
- Severity: low - dead code, not reachable by any user journey. Recorded so that the absence of a "Medication sets" documentation page is explained rather than looking like a gap, and so that the screen is not simply re-linked in this state.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Drugs admin screens.

## BUG-448: The CVI Clinical Disorder Section screen can only ever create adult sections (CONFIRMED code/db)

- Where: `OEModule\OphCoCvi\controllers\AdminController::actionAddClinicalDisorderSection()` (`protected/modules/OphCoCvi/controllers/AdminController.php:197-231`) takes the patient type from a `$patient_type` URL parameter and nothing else. Three things prevent that parameter from ever carrying the value the administrator meant. The **Add** button on the list supplies no query string at all - `views/default/clinical_disorder_section.php:57` builds it as `'data-uri' => '/OphCoCvi/admin/addClinicalDisorderSection'` - unlike the sibling Clinical Disorder screen's Add button, which does carry `?patient_type=...` from the current filter (`clinical_disorders.php:63`). The form cannot supply it either: `views/default/edit_clinical_disorder_section.php` renders exactly two controls, **Name** and **Active**, so `$section->attributes = $_POST[...]` has nothing to assign, even though `patient_type` is in the model's safe list (`OphCoCvi_ClinicalInfo_Disorder_Section.php:64`). And the guard that consumes the parameter is `if ($patient_type)` at `:202`, which discards the adult value in any case, because `PATIENT_TYPE_ADULT = 0` (`:47`) and PHP treats `'0'` as false - so even correcting the Add button could only ever produce children's sections, never adult ones. The same `if ($patient_type)` at `:216` drops the filter from the redirect. With nothing setting the column, the row is written with the schema default: `ophcocvi_clinicinfo_disorder_section.patient_type` is `tinyint(1) unsigned NOT NULL DEFAULT 0`, and 0 is adult. The **Edit** form has no patient type field either, so the section cannot be moved to the children's list afterwards from any screen.
- Route: `/OphCoCvi/admin/clinicalDisorderSection` (Admin > CVI > Clinical Disorder Section)
- Repro:
  1. Open **Admin > CVI > Clinical Disorder Section**.
  2. Choose `Diagnosis for patients under the age of 18` in the drop-down and select **Search**. The list now shows the children's sections.
  3. Select **Add**, type a **Name**, leave **Active** ticked and select **Save**.
  4. Filter to the children's list again. The new section is not there.
  5. Filter to `Diagnosis for patients 18 years of age or over`. The new section is there instead.
  6. Open the new section and look for a way to move it. There is none.
- Expected: the section to be created for the patient type the administrator was working in, or for the form to offer the choice.
- Actual: every section created on this screen is an adult section, whatever list you were looking at, and it cannot be reassigned afterwards. Adding a heading to the under-18 CVI form is not possible through the interface at all. Sections are read back by patient type - `DefaultController::getDisorderSections()` (`:1357-1369`) calls `findAllByAttributes(['patient_type' => $patient_type, 'deleted' => 0])`, which is what `form_Element_OphCoCvi_ClinicalInfo_Disorder_Assignment_Disorders.php:68` and `view_..._Disorders.php:16` iterate, and the visually-impaired printout repeats at `Element_OphCoCvi_ClinicalInfo.php:1386-1392` - so a section put in the wrong list is simply absent from the CVI form the administrator was trying to change.
- Evidence: controller, both views, the model rules and all three readers read in the container at develop 53b077c089. Schema: `information_schema.COLUMNS` gives `patient_type tinyint(1) unsigned NOT NULL DEFAULT 0` on that table. Sample database: `SELECT patient_type, COUNT(*) FROM ophcocvi_clinicinfo_disorder_section GROUP BY patient_type` returns `0 -> 17` and `1 -> 8`, so the eight children's sections shipped with the product are the only ones that will ever exist.
- Severity: medium - the adult list can still be extended, and the workaround is a database update. Nothing warns the administrator, and the new heading simply does not appear on the form they were trying to change.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the CVI admin screens.

## BUG-449: The Signature Import Log puts the request's sort direction straight into the ORDER BY clause (CONFIRMED code)

- Where: `DicomLogViewerController::actionSignatureList($type = 1, $sortby = 'DESC', $page = 1)` (`protected/controllers/DicomLogViewerController.php:78-92`) builds its ordering as `$criteria->order = "import_datetime " . $sortby;`. `$sortby` arrives from the query string and is neither whitelisted against `ASC`/`DESC` nor escaped, and Yii 1 concatenates `CDbCriteria::order` into the statement verbatim rather than quoting or validating it. The column heading that produces the parameter only ever sends `ASC` or `DESC` (`protected/views/dicomlogviewer/signature_import_log.php:38`), so nothing in ordinary use exercises it.
- Route: `/DicomLogViewer/signatureList?sortby=...` (Admin > CVI > Signature Import Log)
- Repro:
  1. Open **Admin > CVI > Signature Import Log**.
  2. Select the **Import Date** column heading. The address gains `?sortby=ASC` and the list re-orders.
  3. Edit the address by hand to put anything else in `sortby`. It reaches the database inside the ORDER BY clause.
- Expected: the parameter to be checked against the two directions the screen offers, and anything else rejected or ignored.
- Actual: it is concatenated into the statement as written.
- Evidence: controller and view read in the container at develop 53b077c089. Confirmed from source only - no payload was constructed or run. Same class of defect as BUG-444, which covers the sort **column** on the generic admin lists; this is a separate, hand-written code path and needs its own fix.
- Severity: medium - the screen is behind `OprnInstitutionAdmin` or `TaskAdminManageSignatureImportLog` (`protected/modules/OphCoCvi/config/common.php:30`), so it is not reachable by an ordinary clinical user.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the CVI admin screens.

## BUG-450: A new CVI clinical disorder takes its display order from the sections table (CONFIRMED code/db)

- Where: `AdminController::actionAddClinicalDisorder()` (`protected/modules/OphCoCvi/controllers/AdminController.php:77-79`) sets the new disorder's position with `OphCoCvi_ClinicalInfo_Disorder::model()->findBySql('SELECT display_order FROM ophcocvi_clinicinfo_disorder_section ORDER BY display_order DESC LIMIT 1')` and then `$disorder->display_order = $max_display_order->display_order + 1`. The model is the disorder, but the table named in the statement is `ophcocvi_clinicinfo_disorder_section` - the sections table. The number the new disorder is given therefore has nothing to do with the disorders it is being ordered among, and it changes whenever a section is added. The neighbouring `actionAddClinicalDisorderSection()` (`:206-210`) reads the same table, which for a section is the right one.
- Route: `/OphCoCvi/admin/clinicalDisorders` (Admin > CVI > Clinical Disorder)
- Repro:
  1. Open **Admin > CVI > Clinical Disorder** and select **Add**.
  2. Fill the form in and select **Save**.
  3. Look at the new row's position among the other disorders of its section on a CVI event's Clinical Information element.
- Expected: the disorder to be placed after the last disorder in its section.
- Actual: it is placed using the highest display order found in the sections table.
- Evidence: controller read in the container at develop 53b077c089. Sample database: sections run to `MAX(display_order) = 29` while the 74 disorders run 1 to 27, so a disorder added today is written with 30 - past the end of every section's list, which hides the mistake. The two ranges are unrelated and nothing keeps them apart.
- Severity: low - the visible effect today is only that new disorders sort last. It becomes wrong the moment the two tables' ranges cross.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the CVI admin screens.

## BUG-451: The CVI clinical disorder screens have no way to delete a row, though the handlers for it exist (CONFIRMED code)

- Where: `AdminController::actionDeleteClinicalDisorderSection()` (`protected/modules/OphCoCvi/controllers/AdminController.php:265-285`) and `actionDeleteClinicalDisorders()` (`:287-307`) both read a posted list of ids, delete each row and echo `1` or `0`. Neither is reachable. `views/default/clinical_disorder_section.php` and `views/default/clinical_disorders.php` each render one **Add** button in the table foot and no **Delete**, and neither table has a selection column, so there is nothing to post. `grep -rn "deleteClinicalDisorder" --include=*.php --include=*.js protected/` returns the two declarations and nothing else in the whole application.
- Route: `/OphCoCvi/admin/clinicalDisorders` and `/OphCoCvi/admin/clinicalDisorderSection`
- Repro:
  1. Open **Admin > CVI > Clinical Disorder** or **Clinical Disorder Section**.
  2. Look for a way to remove an entry. There is no Delete button and no tick boxes.
- Expected: either a Delete control, or the unused handlers removed.
- Actual: an administrator can add and edit but never remove. Untick **Active** on the entry instead - that is what the screens leave you, and it is what the documentation tells the reader to do.
- Evidence: controllers and both views read in the container at develop 53b077c089.
- Severity: low - deactivating covers the need, and for a clinical disorder already recorded against a CVI event it is the safer action anyway. Recorded so the missing button reads as a known gap rather than a documentation omission.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the CVI admin screens.

## BUG-452: Cancel on an admin form throws and leaves the form frozen wherever no cancel destination was given (CONFIRMED code)

- Where: `protected/assets/js/handleButtons.js:5-31` binds `#et_cancel`. If the button carries a `data-uri` it navigates there and all is well. If it does not, the handler tries to work the destination out from the address: it splits the URL, finds the segment `admin`, and at `:22` computes `object = ucfirst(hrefArray[i + 1]...)` from the **array**, but then at `:26`, in the branch that runs for everything except Edit User and Add User, computes `var object = e[i + 1].replace(...)` from **`e`** - the jQuery event object, which has no numeric properties. `e[i + 1]` is `undefined` and `.replace` on it throws a TypeError, so the navigation line beneath it never runs. The freeze comes from `buttons.js:18-28`: `handleButton` calls `disableButtons()` before it calls the callback, so Save and Cancel are already greyed out when the callback throws. `FormActions` supplies `data-uri` only when the form passes `cancel-uri` (`protected/widgets/views/FormActions.php:28-40`), which 45 places do; the forms that call `$form->formActions()` with no arguments get the broken path.
- Route: any admin form that renders `FormActions` without a `cancel-uri`. Confirmed instance: `/OphCoCvi/admin/addClinicalDisorderSection` and `/OphCoCvi/admin/editClinicalDisorderSection/<id>` (Admin > CVI > Clinical Disorder Section).
- Repro:
  1. Open **Admin > CVI > Clinical Disorder Section** and select **Add**.
  2. Select **Cancel**.
  3. Both buttons grey out and the page does not move. The browser console shows `TypeError: Cannot read properties of undefined (reading 'replace')`.
  4. Leave the form with the browser's Back button - nothing was saved.
- Expected: Cancel to return to the list it was opened from.
- Actual: it disables the form's buttons and throws, leaving the administrator on a form with no working controls. Nothing is saved - the handler calls `e.preventDefault()` at `:6` before it throws, so the form is not submitted.
- Evidence: `handleButtons.js`, `buttons.js`, `FormActions.php` and the calling views read in the container at develop 53b077c089. `grep -rn "formActions()" --include=*.php protected/` returns seven bare call sites: `views/admin/addcontactlocation.php:52` (which rebinds `#et_cancel` itself at `:66` and so escapes), `views/studies/editStatus.php:64`, `OphTrOperationbooking/views/admin/patient_unavailable_reasons/edit.php:57`, `OphTrOperationbooking/views/admin/editsessionunavailablereason.php:33`, `OphTrOperationbooking/views/admin/editschedulingoption.php:33`, `OphCoCorrespondence/views/admin/secretary/edit.php:97` and `OphCoCvi/views/default/edit_clinical_disorder_section.php:41`. Only the CVI pair was exercised while documenting; the other five are the same code path and are recorded here so they are checked together.
- Severity: medium - Cancel is a dead control on the affected forms and the page has to be left with the browser. No data is lost or wrongly written.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the CVI admin screens.

## BUG-453: Manage Lasers refuses to save 52 of the 65 lasers it ships with, and reports the refusal as a success (CONFIRMED code/db)

- Where: `protected/modules/OphTrLaser/models/OphTrLaser_Site_Laser.php:78` validates `wavelength` with `array('wavelength', 'numerical', 'integerOnly' => true, 'min' => 200, 'max' => 2000, 'message' => 'Wavelength is a number between 200 to 2000 only.')`, and `:73` makes it required. The edit form posts the stored value straight back (`views/admin/form_OphTrLaser_Site_Laser.php:82-89`), so `actionEditLaser()` (`controllers/AdminController.php:73-100`) revalidates a value the installation itself supplied and `$model->save()` returns false. `:96` then sets the failure text on the success channel: `Yii::app()->user->setFlash('success', 'Laser: error saving laser')`.
- Route: `/OphTrLaser/admin/manageLasers`, then a row, i.e. `/OphTrLaser/admin/editLaser/<id>`
- Repro:
  1. Open **Admin > Laser > Manage Lasers**.
  2. Select any row whose **Wavelength** column shows `0` - most of them.
  3. Change nothing, or change only **Active** to `No`.
  4. Select **Save**.
- Expected: the laser saves, or the wavelength rule is not applied to a value the administrator did not touch.
- Actual: the save is refused with "Wavelength is a number between 200 to 2000 only." and the page stays on the form. The administrator cannot deactivate a decommissioned laser without also inventing a wavelength for it. The accompanying "Laser: error saving laser" message is set as a flash of type `success`, so it is rendered in the confirmation style rather than as an error.
- Evidence: model, controller and form read in the container at develop 53b077c089. Sample database: `SELECT COUNT(*), SUM(wavelength BETWEEN 200 AND 2000) FROM ophtrlaser_site_laser` returns 65 rows of which 13 are inside the permitted range. 49 store `0` and three (the `Coherent Novus Omni` rows) store `515577647`, which reads as the three wavelengths 515, 577 and 647 concatenated rather than one number.
- Severity: medium - the screen's edit path is unusable for the great majority of the shipped estate, and the one message it does show is styled as a success.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Laser admin screens.

## BUG-454: Editing a laser whose site belongs to another institution loses the site (CONFIRMED code/db)

- Where: `protected/modules/OphTrLaser/views/admin/form_OphTrLaser_Site_Laser.php:55-60` builds the **Site** drop-down from `Site::model()->getListForCurrentInstitution()` (`protected/models/Site.php:176-184`), which returns the sites of the institution the administrator is logged in to - not the sites of the institution named on the form, and not the laser's own site. The script at `:117-158` then refetches the list from `/Site/getSitesByInstitution?institution_id=<the Institution field>` and rewrites the options, landing on the same set. A laser whose `site_id` is not in that set has no matching option, so the drop-down falls back to `- Site -`. The list screen has no such problem: it prints `$model->site->name` directly (`views/admin/list_OphTrLaser_Manage_Lasers.php:46`).
- Route: `/OphTrLaser/admin/manageLasers`, then a row belonging to a site of another institution
- Repro:
  1. Log in to an institution, and open **Admin > Laser > Manage Lasers**.
  2. Find a row whose **Site** column names a site that belongs to a different institution. In the sample database, logged in to institution 1, the fourteen rows showing **Holby City General Hospital** are such rows: they carry `institution_id` 1 while site 4 belongs to institution 119, so the list's own condition (`AdminController.php:29-31`) includes them.
  3. Select the row.
  4. Read the **Site** field.
- Expected: the form to open on the laser's stored site.
- Actual: **Site** reads `- Site -`. The stored site is neither shown nor selectable, and since `site_id` is required the form cannot be saved without choosing one of the current institution's sites, which moves the laser.
- Evidence: form, list view, controller and `Site::getListForCurrentInstitution()` read in the container at develop 53b077c089. Sample database: `SELECT l.site_id, s.institution_id, COUNT(*) FROM ophtrlaser_site_laser l JOIN site s ON s.id = l.site_id GROUP BY 1, 2` returns 20 rows at site 1, 17 at site 3 and 14 at site 22793 (all institution 1) and 14 at site 4 (institution 119); every one of the 65 rows carries `institution_id` 1.
- Severity: medium - no data is written wrongly on its own, but the only way past the form is to reassign the laser to a different site.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Laser admin screens.

## BUG-455: The laser procedure search stores the last suggestion offered, not the one you select (CONFIRMED code/db)

- Where: `protected/modules/OphTrLaser/views/admin/edit_OphTrLaser_Procedure.php:196-207`. Inside the loop that renders the suggestion list, `:206` runs `$('[name="Procedure[proc_id]"]').val(li.dataset.id);` for every suggestion, so once typing stops the hidden field holds the id of whichever suggestion was rendered last. `selectProc()` at `:143-164` overwrites it correctly when a suggestion is clicked, and nothing resets it when none is. `AdminController::actionAddLaserProcedure()` (`:156-187`) saves `$_POST['Procedure']['proc_id']`; the visible text box, `Procedure[term]`, is never read.
- Route: `/OphTrLaser/admin/addLaserProcedure` (Admin > Laser > Manage Laser Procedures, then **Add**)
- Repro:
  1. Open **Admin > Laser > Manage Laser Procedures** and select **Add**.
  2. Type `laser` into **Laser Procedure**. A suggestion list appears.
  3. Do not click a suggestion. Select **Save**.
  4. Read the new row in the list.
- Expected: nothing is added, or the form asks which procedure was meant.
- Actual: the procedure added is the last entry in the suggestion list, which is the alphabetically last match rather than anything the administrator indicated. In the sample database the search above offers seven procedures and the row created is `Scanning laser ophthalmoscopy`.
- Evidence: view and controller read in the container at develop 53b077c089. Sample database: `SELECT p.id, p.term FROM proc p LEFT JOIN ophtrlaser_laserprocedure ol ON p.id = ol.procedure_id WHERE ol.id IS NULL AND p.term LIKE '%laser%' ORDER BY p.term` returns Argon laser trabeculoplasty, Diode Laser, Eye : laser of retina / iris or posterior capsule, Laser coagulation ciliary body, Laser Prp, PTK - Laser superficial keratectomy, Scanning laser ophthalmoscopy - in the same order the screen builds the list (`setJSVars()`, `AdminController.php:225-240`, orders by `p.term`).
- Severity: medium - a wrong procedure is added to the clinician-facing picker, and the screen gives no sign of it.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Laser admin screens.

## BUG-456: Adding a laser procedure returns to the list as though it worked even when nothing was saved (CONFIRMED code)

- Where: `protected/modules/OphTrLaser/controllers/AdminController.php:170-186`, `actionAddLaserProcedure()`: `$laser_procedure->save();` discards the return value and `$this->redirect(['/OphTrLaser/admin/manageLaserProcedures'])` runs unconditionally. `OphTrLaser_LaserProcedure::rules()` requires `procedure_id`, so a submission carrying an empty `Procedure[proc_id]` fails validation and writes nothing. No flash message is set on any path, successful or not, and the errors on the model are discarded with it.
- Route: `/OphTrLaser/admin/addLaserProcedure`
- Repro:
  1. Open **Admin > Laser > Manage Laser Procedures** and select **Add**.
  2. Leave **Laser Procedure** empty, or type a term that matches nothing - the screen shows "No procedure matched".
  3. Select **Save**.
- Expected: the form comes back with "Procedure cannot be blank", or a message says nothing was added.
- Actual: the list reopens unchanged and silently. The same action reports a successful add in exactly the same way, so there is nothing to tell the two apart other than counting the rows.
- Evidence: controller and model read in the container at develop 53b077c089.
- Severity: low - nothing is written wrongly, but a failed add is indistinguishable from a successful one.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Laser admin screens.

## BUG-457: The Laser Operators admin screen has a view and a script but no controller actions (CONFIRMED code)

- Where: `protected/modules/OphTrLaser/views/admin/laser_operators.php` renders a full list screen - a select-all column, a **Full name** column, rows linking to `OphTrLaser/admin/editLaserOperator/<id>`, and **Add** and **Delete** buttons - and `protected/modules/OphTrLaser/assets/js/admin.js:3-29` binds those buttons to `/OphTrLaser/admin/addLaserOperator` and `/OphTrLaser/admin/deleteOperators`. `controllers/AdminController.php` declares none of `actionLaserOperators`, `actionAddLaserOperator`, `actionEditLaserOperator` or `actionDeleteOperators`; `config/common.php` carries no menu entry for the screen; and nothing renders the view. The module's `admin.js` is not registered anywhere either. `grep -rniE "laserOperator" protected/` returns the view, the module's `admin.js`, and `DefaultController::siteLaserOperatorCheck()` (`:81-86`) - which despite its name only checks that the institution has at least one laser and has nothing to do with an operators list.
- Route: none. `/OphTrLaser/admin/laserOperators` and the three actions above all 404.
- Repro:
  1. Open **Admin** and read the **Laser** box. It offers Manage Laser Procedures, Manage Lasers and Manage Laser lens options, and nothing else.
  2. Request `/OphTrLaser/admin/laserOperators` directly.
- Expected: either a working screen reachable from the menu, or the view and script removed.
- Actual: the screen cannot be reached. Laser operators are not a maintained list at all: the **Laser operator** drop-down on the Laser event is built from every user of the institution (`views/default/form_Element_OphTrLaser_Site.php:24-32`), and `Element_OphTrLaser_Site::setDefaultOptions()` carries the comment "in a future we want to remove the 'Laser Operators' list", so the removal is deliberate and unfinished.
- Evidence: view, module script, controller, module config and the event form read in the container at develop 53b077c089.
- Severity: low - nothing is broken for a user, who cannot reach any of it. Recorded so the leftover files read as a known remnant.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Laser admin screens.

## BUG-458: Deactivating a laser lens quietly clears it from any event that is edited afterwards (CONFIRMED code/db)

- Where: `protected/modules/OphTrLaser/views/default/form_Element_OphTrLaser_Procedure.php:5` builds the lens list as `CHtml::listData(OphTrLaser_Procedure_Lens::model()->findAll(['condition' => 'active = 1']), 'id', 'name')` - active rows only, with no fallback to the value the element already holds. `views/default/form_Element_OphTrLaser_Procedure_side.php:121-131` renders it with `'empty' => '… select'`, so an element whose `left_lens_id` or `right_lens_id` names a deactivated lens has no matching option and the browser falls back to the empty one. `models/Element_OphTrLaser_Procedure.php:69-77` marks both columns `safe` and nothing else, so the empty value posts back and is written. Both columns are nullable (`int(11) NULL DEFAULT NULL`). The comparable list on the Lasers screen does not have this problem: the laser drop-down is built with `activeOrPk($element->laser_id)` (`views/default/form_Element_OphTrLaser_Site.php:17`), which is exactly the fallback missing here.
- Route: `/OphTrLaser/admin/manageLaserLensOptions` to deactivate, then `/OphTrLaser/default/update/<event_id>` on an event that used the lens.
- Repro:
  1. Record a Laser event and set **Lens used** on one eye.
  2. Open **Admin > Laser > Manage Laser lens options**, untick **Active** for that lens and select **Save**.
  3. Reopen the event and select the edit icon.
  4. Read **Lens used** on that eye. It reads `… select`.
  5. Change something else on the event and select **Save**.
- Expected: the lens already recorded stays selected and stays recorded, the way the laser itself does.
- Actual: the drop-down opens with nothing selected and re-saving writes NULL, so the record of which lens was used is lost. The event *view* still shows the lens, because the relation is read directly, so the loss is only visible after an edit.
- Evidence: the two views, the element model and the site element's `activeOrPk` comparison read in the container at develop 53b077c089. Schema from `information_schema.COLUMNS`. Not reproduced live: `SELECT COUNT(*) FROM et_ophtrlaser_procedure` is 0 in the sample database, so no recorded event carries a lens to test with.
- Severity: medium - a clinical detail already recorded is discarded by an unrelated edit, and nothing on screen says so.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Laser admin screens.

## BUG-459: The copy icon in the Support Information dialog copies nothing (CONFIRMED code)

- Where: `protected/assets/js/OpenEyes.UI.CopyToClipboard.js:16-23` defaults the controller's `wrapper` option to `'.patient-details'`, and `:27-29` delegates the click handler from that wrapper. The only instantiation in the tree, at `:59-61`, passes no options, so the handler is bound to `.patient-details`. The icon it is meant to serve is rendered by `protected/views/site/debuginfo.php:121`, and `protected/assets/js/OpenEyes.UI.Dialog.js:338`/`:350` attach dialog content to `body`, so the icon is never a descendant of `.patient-details` and the delegated handler never fires. `grep -rn "CopyToClipboardController" protected/` finds no other usage.
- Route: `/site/debuginfo`, opened as a dialog from the OpenEyes logo panel.
- Repro:
  1. Sign in.
  2. Select the **OpenEyes** logo, top left.
  3. Select **Support diagnostic info**.
  4. In the **Support Information** dialog, select the copy icon beside the details.
  5. Paste into any text editor.
- Expected: the diagnostic block is on the clipboard.
- Actual: nothing is copied and nothing on screen says so.
- Evidence: the three files read in the container at develop 53b077c089. Code-confirmed; the icon has not been clicked live.
- Severity: medium - it is the one control on that screen whose whole purpose is to make a support report easy to send.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Site pages.

## BUG-460: Image info is left out of the copied support block (CONFIRMED code)

- Where: `protected/views/site/debuginfo.php:78-118` is the `.js-to-copy-to-clipboard` block; the closing tag is at `:118` and **Image info** is emitted at `:120`, outside it.
- Route: `/site/debuginfo`.
- Repro:
  1. Open the **Support Information** dialog as above.
  2. Copy the details (assumes BUG-459 is fixed).
  3. Compare the pasted text with what the dialog shows.
- Expected: everything the dialog shows is copied.
- Actual: **Image info** is silently dropped - which is the line a support desk most often needs to know which build is running.
- Evidence: the view read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Site pages.

## BUG-461: The home page search hint always says ID, whatever the institution calls its identifier (CONFIRMED code/db)

- Where: `protected/views/base/_search_bar.php:76` emits the literal string "Search by ID, or Name (click for options)" with only a date-of-birth conditional, while the same view's sidebar at `:24` and `:53` uses `$search_by_message`, which `PatientIdentifierHelper.php:372-405` resolves per site and then per institution from `patient_identifier_type`.
- Route: `/site/index`.
- Repro:
  1. Sign in to an institution whose primary identifier is not called "ID" - in the sample data, Holby City General, which uses CRN.
  2. Read the link under the home page search box.
  3. Search for a patient and read the "Search by ..." heading in the results sidebar.
- Expected: both name the identifier that institution actually uses.
- Actual: the home page always says ID; the sidebar names the real identifier, so the two disagree on the same screen.
- Evidence: the view and the helper read in the container at develop 53b077c089; `patient_identifier_type` row 4 (CRN, institution 119) carries its own label.
- Severity: low, but it is on the first screen every user sees.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Site pages.

## BUG-462: Choosing an institution with no sites clears the context instead of the site (CONFIRMED code)

- Where: `protected/components/views/SiteAndFirmWidget.php:188-192`. The `if` branch sets `.js-site` from the response; the `else` branch - taken when the chosen institution returns no sites - clears `.js-firm` instead of `.js-site`.
- Route: the **Select a new Site and/or Context** dialog, on changing the Institution drop-down.
- Repro:
  1. Sign in on an installation with SSO institution authentication, so the Institution drop-down is enabled.
  2. Select the **change** link in the top right banner.
  3. Choose an institution that has no sites.
- Expected: the Site select is cleared, because none of its options belong to the chosen institution.
- Actual: the previous institution's site stays selected and the context is blanked instead, so the dialog can be confirmed with a site the institution does not own.
- Evidence: the widget read in the container at develop 53b077c089. Not reproducible on the sample data: both institution authentications are `LOCAL`, so the Institution drop-down is disabled and this branch cannot run.
- Severity: medium if reachable.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Site pages.

## BUG-463: The site and context dialog fetches from the domain root, ignoring the application base URL (CONFIRMED code)

- Where: `protected/components/views/SiteAndFirmWidget.php:169` opens `'/site/getInstitutionSitesAndFirms?id=' + institutionId` with no base-URL prefix, where the rest of the application builds URLs through `Yii::app()->createUrl`.
- Route: the **Select a new Site and/out Context** dialog, on changing the Institution drop-down.
- Repro:
  1. Serve OpenEyes from a sub-path rather than the domain root.
  2. Open the banner **change** link.
  3. Change the Institution drop-down.
- Expected: the site and context lists refresh.
- Actual: the request goes to the domain root and 404s; the lists never refresh.
- Evidence: the widget read in the container at develop 53b077c089. Not reproducible on a root-served installation, which is what the sample stack is.
- Severity: low, deployment-dependent.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Site pages.

## BUG-464: The merged patient record error page can never be shown (CONFIRMED code)

- Where: `protected/controllers/SiteController.php:139-158` computes `$error_code = (int) $error['code'];` and looks for a view named `error<integer>`, so a view named `errorPAS` can never be selected. `protected/views/error/errorPAS.php` - the "Merged patient record" page, the only error view carrying "Click here to go back to the search page" - is therefore dead. `grep -rn "errorPAS" protected/` finds no other render.
- Route: any merged-patient-record error.
- Repro:
  1. Trigger the merged-record error condition.
  2. Read the page.
- Expected: the merged-record explanation with a link back to patient search.
- Actual: the generic fault page, which explains nothing and offers no route out.
- Evidence: the controller and the view read in the container at develop 53b077c089.
- Severity: low-medium - a dead end where an explanatory page with a way back was written.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Site pages.

## BUG-465: Error pages print Phone and email labels with nothing after them (CONFIRMED code/db)

- Where: `protected/views/error/support.php:6-10` prints the **Support Options** labels unconditionally, including "Immediate support (8:00am to 6:00pm) - Phone" and a `mailto:` link, with no guard on whether the values exist.
- Route: any error page.
- Repro:
  1. Request an address that does not exist.
  2. Read the **Support Options** block.
- Expected: the block is suppressed, or says the contact details are not configured.
- Actual: the labels print with nothing after them, and the email is an empty `mailto:` link that opens a blank message.
- Evidence: the view read in the container at develop 53b077c089; `setting_metadata` defaults `helpdesk_phone` and `helpdesk_email` to empty strings and `setting_installation` holds no override rows, so every stock installation shows it.
- Severity: low - partly a configuration gap, but a view should not print an empty contact detail on a page a user reaches when something has already gone wrong.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Site pages.

## BUG-466: The site and context reminder says firm where every other screen uses the configured label (CONFIRMED code)

- Where: `protected/components/views/SiteAndFirmWidgetReminder.php:34-47` hard-codes "site and firm" into the reminder text, where `protected/models/Firm.php:178-182` provides `Firm::contextLabel()` and the switcher, the form labels and the dialog title all use it.
- Route: first sign-in for a user without global firm rights and with no saved firm selections.
- Repro:
  1. Rename the context label for the installation.
  2. Sign in as a user with global firm rights off and no saved selections.
  3. Read the reminder dialog.
- Expected: the dialog uses the installation's configured label, as its neighbours do.
- Actual: it says "firm", which on an installation that calls them something else reads as a different concept.
- Evidence: the widget and the model read in the container at develop 53b077c089. Not reachable in the sample data: no account has global firm rights off with no saved selections.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Site pages.

## BUG-467: The cleartext PIN is written to the audit log and shown on the Audit Trail screen (CONFIRMED code)

- Where: `protected/models/User.php:1126` builds `$audit_data = ($flag ? 'Success' : 'Failed') . ": update pincode to $pincode for user {$this->id}";` and passes it to `$this->audit('pincode', $audit_action, $audit_data);`. `protected/views/audit/_list_row.php:95` prints `$log->data` verbatim.
- Route: `/profile/pincode` writes the row; `/audit` displays it.
- Repro:
  1. Sign in and open **profile > Pincode**.
  2. Reveal the PIN and select **Regenerate Pincode**.
  3. Sign in as a user holding the Audit role and open the Audit Trail.
  4. Filter on the pincode action and read the Data column.
- Expected: the audit records that a PIN was changed, not what it was changed to.
- Actual: the `data` column holds the PIN in cleartext, for example `Success: update pincode to 431907 for user 12`, and the screen prints it.
- Evidence: the model and the view read in the container at develop 53b077c089.
- Severity: high - the PIN is the e-signature credential used to sign prescriptions, so anyone with audit access can read every user's live PIN, and the log keeps it after the user forgets it.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-468: The delete confirmation for a pre-fill template cannot be declined (CONFIRMED code)

- Where: `protected/views/profile/manage_event_templates.php:164-186` asks "Are you sure you wish to delete this event template?" through `OpenEyes.UI.Dialog.Alert`, whose `_defaultOptions` carry only `okButton: 'OK'`, and puts the delete in the close callback. `protected/assets/js/OpenEyes.UI.Dialog.js:396-397` fires `dialog.options.closeCallback()` on any close, including the cross.
- Route: `/profile/manageEventTemplates`.
- Repro:
  1. Create a pre-fill template from an operation note.
  2. Open **profile > Pre-fill templates**.
  3. Select the bin beside the template.
  4. Close the dialog with the cross rather than selecting **OK**.
- Expected: a confirmation offering **OK** and **Cancel**, where closing the dialog cancels.
- Actual: there is no Cancel, and dismissing the dialog deletes the template anyway.
- Evidence: the view and the dialog component read in the container at develop 53b077c089.
- Severity: medium-high - a destructive action worded as a question that cannot be answered no.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-469: Renaming or deleting a pre-fill template checks no ownership (CONFIRMED code)

- Where: `protected/controllers/ProfileController.php:729` and `:754` both do `EventTemplate::model()->findByPk($id)` and act on whatever comes back, with no comparison against the signed-in user.
- Route: `POST /profile/modifyEventTemplates`, `POST /profile/deleteEventTemplates`.
- Repro:
  1. Sign in as user A.
  2. Open **profile > Pre-fill templates**.
  3. POST `template_ids[]=<id of a template belonging to user B>` to `/profile/deleteEventTemplates`.
- Expected: the request is refused - a user can only modify their own templates.
- Actual: another user's template is renamed or deleted. An id that does not exist additionally calls `->save()` or `->opnote_template` on `null` and fatals.
- Evidence: the controller read in the container at develop 53b077c089. Requires a crafted request; not reachable by clicking, because the screen only lists your own.
- Severity: high (authorisation).
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-470: The read-only profile fields setting is enforced only in the browser (CONFIRMED code)

- Where: `protected/controllers/ProfileController.php:74-85` assigns `title`, `first_name`, `last_name`, `correspondence_sign_off_user_id` and `correspondence_sign_off_text` straight from `$_POST` with no re-check of `isUserFieldReadOnly()`, which is what rendered them read-only in the first place.
- Route: `POST /profile/info`.
- Repro:
  1. Configure `profile_user_readonly_fields` to include `first_name`.
  2. Open **profile > Basic information** and confirm the field renders read-only.
  3. POST `User[first_name]=Changed`.
- Expected: the server ignores a field the installation has marked read-only.
- Actual: the value is saved.
- Evidence: the controller read in the container at develop 53b077c089.
- Severity: medium - the setting reads as a policy control and is cosmetic.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-471: Turning off self-service profile editing traps an expired password in a redirect loop (CONFIRMED code)

- Where: `protected/controllers/ProfileController.php:37-38` redirects away from the whole controller when `profile_user_can_edit` is false, and it does so *before* calling `parent::beforeAction()`. `BaseController::beforeAction()` is where the password-expiry gate sends every request to `/profile/password`, and that page is correctly on the gate's whitelist - but the child's redirect runs first.
- Route: any page, on an installation with `profile_user_can_edit` false.
- Repro:
  1. Set `profile_user_can_edit` to false.
  2. Let a local user's password pass its expiry date.
  3. Sign in as that user.
- Expected: the user reaches the password-change page, or is told what to do.
- Actual: the expiry gate sends the browser to `/profile/password`, the profile controller sends it back to `/`, and the browser loops until it gives up.
- Severity: high in that configuration, which is not the shipped default. The whitelist is correct; the ordering inside `beforeAction()` defeats it.
- Evidence: both controllers read in the container at develop 53b077c089.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-472: The PIN check that guards an email change passes for a user who has no PIN (CONFIRMED code)

- Where: `protected/controllers/ProfileController.php:250` is `return $user->getPincode() === $pincode;` with no guard. Its sibling `actionCheckPincode()` at `:232` guards with `if ($user_auth->user->pincode && ...)` and carries a comment saying the guard exists so "a user without a PIN generated" cannot "have their email changed without requiring a PIN to be entered".
- Route: `POST /profile/info`.
- Repro:
  1. Take an account that has never opened **profile > Pincode**, so it has no `user_pincode` row.
  2. POST `User[email]=new@example.com` together with `User_pincode_final=No Pincode`.
- Expected: the check fails and the email is not changed.
- Actual: both sides of the comparison are the same placeholder, so the check passes and the email is changed with no PIN.
- Evidence: the controller read in the container at develop 53b077c089. Requires a crafted request. The guard was clearly intended and was applied to only one of the two call sites.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-473: A failed SSO role save says nothing, and the edit path commits half the change (CONFIRMED code)

- Where: `protected/models/SsoRoles.php:88-95` wraps the insert in its own `catch (Exception $e) { $transaction->rollback(); }`, so the unique-key violation never reaches `protected/controllers/SsoController.php:335-338` and its `addError('name', 'SSO Role "..." already exists')` is unreachable. On the edit path the assignment rows are deleted and reinserted first, then `$this->save()` returns false without throwing - `BaseActiveRecord::save()` converts the `CDbException` into a model error - so `$transaction->commit()` still runs.
- Route: `POST /sso/addSSORoles`, `POST /sso/editSSORoles`.
- Repro (add):
  1. Open **Admin > SSO settings > SSO Roles Mappings**.
  2. Select **Add SSO Role**.
  3. Type `admin` into **SSO Role**, a name already in use, pick a role and select **Save**.
- Repro (edit):
  1. Create a second mapping named `test`.
  2. Open it, rename it to `admin`, change its **Associated OE Roles** and select **Save**.
- Expected: an error saying the name is already in use, and nothing saved.
- Actual (add): no row, no error and no message - the list simply comes back unchanged.
- Actual (edit): the associated roles change and the name does not, with no message either way. The mapping now grants something different from what the screen was asked for.
- Evidence: the model and the controller read in the container at develop 53b077c089.
- Severity: medium - silent divergence between what an administrator asked for and what is stored, on a screen that decides who can sign in.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the SSO role mapping page.

## BUG-474: Delete SSO Role has no confirmation, and a failed delete returns a blank page (CONFIRMED code)

- Where: `protected/views/sso/editSSORoles.php:116-119` binds `#et_delete_role` to `window.location.href = '/sso/deleteSSORoles/<id>'` with no prompt. `protected/controllers/SsoController.php:349-376` rolls back in its `catch` and then neither renders nor redirects, so a failure returns an empty response; an unknown id calls `->delete()` on `null`, which is a PHP `Error` and is not caught by `catch (Exception $e)` at all.
- Route: `/sso/editSSORoles/<id>`.
- Repro:
  1. Open **Admin > SSO settings > SSO Roles Mappings**.
  2. Select a mapping.
  3. Select **Delete SSO Role**.
- Expected: a confirmation, given what the deletion does.
- Actual: the mapping is deleted on the first click. Everyone who reached OpenEyes through that group is refused at the next sign-in, and nothing on the screen warned that it was about to happen.
- Evidence: the view and the controller read in the container at develop 53b077c089.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the SSO role mapping page.

## BUG-475: The SSO admission check is case-sensitive while the mapping table is not (CONFIRMED code/db)

- Where: `protected/models/User.php:968` decides admission with `array_intersect($roles, $ssoRoleNames)` in PHP, which is case-sensitive. The lookup that follows, `SsoRoles` `find("name = :role")`, runs against a `utf8mb3_unicode_ci` column carrying a unique key, so the database matches case-insensitively and cannot hold two spellings at once.
- Route: SSO sign-in.
- Repro:
  1. Create a mapping named `Oe Clinician`.
  2. Configure the provider to send the group as `OE Clinician`.
  3. Sign in through SSO.
- Expected: consistent matching, or a warning on the admin screen that case matters.
- Actual: the sign-in is refused with "no valid OpenEyes roles assigned", while the mapping the administrator is looking at appears to match.
- Evidence: the model read in the container at develop 53b077c089; column collation from `information_schema.COLUMNS`.
- Severity: low.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the SSO role mapping page.

## BUG-476: An SSO mapping with no roles admits the user and strips every role they had (CONFIRMED code)

- Where: `protected/models/User.php:968` admits on the group *name* alone; `:983-998` then builds the role set from the mapping's associated roles and `saveRoles()` at `:560-574` replaces the user's assignments with it.
- Route: SSO sign-in.
- Repro:
  1. Open **Admin > SSO settings > SSO Roles Mappings**.
  2. Open a mapping, remove every entry under **Associated OE Roles** and select **Save**. The list then shows **N/A** in the roles column.
  3. Have a member of that group sign in.
- Expected: either the user's roles are left alone, or the sign-in is refused with an explanation.
- Actual: the user is signed in with no permissions at all, and every role they previously held is revoked. Nothing says so; the application simply refuses them everywhere.
- Evidence: the model read in the container at develop 53b077c089. The two checks - name present, roles empty - clearly disagree with each other.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the SSO role mapping page.

## BUG-477: The profile sidebar never marks the page you are on (CONFIRMED code)

- Where: `protected/views/profile/sidebar.php:20` and `:23` compare `action->id` (for example `sites`) against `preg_replace('/^\/admin\//', '', $uri)` (which is `/profile/sites`, since the pattern only strips an `/admin/` prefix). The two can never be equal, so `class="active"` is never emitted and the `<span class="viewing">` branch is dead.
- Route: any `/profile/*` page.
- Repro:
  1. Open **profile > Sites**.
  2. Read the sidebar.
- Expected: the current entry is highlighted.
- Actual: no entry is ever highlighted, on any profile page.
- Evidence: the view read in the container at develop 53b077c089.
- Severity: cosmetic.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-478: Out-of-office validation errors are keyed on the label, so no field is highlighted (CONFIRMED code)

- Where: `protected/models/UserOutOfOffice.php:107` and `:114` call `$this->addError($this->getAttributeLabel($attribute), ...)`, passing the label where the attribute name belongs. The duration validator adds its error under the invented key `Out of office duration`.
- Route: `/profile/info`.
- Repro:
  1. Open **profile > Basic information**.
  2. Switch out of office on.
  3. Leave **From** empty and save.
- Expected: the **From** field is highlighted with "cannot be blank".
- Actual: the summary reads `From: From cannot be blank` and no field is marked, so on a long form the reader has to hunt for it.
- Evidence: the model read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-479: Profile Institutions lists logins that have been deactivated (CONFIRMED code)

- Where: `protected/views/profile/institutions.php:32` iterates the unfiltered `authentications` relation with no active check and no marker, where the sibling Sites page marks an unusable entry `(inactive)`.
- Route: `/profile/institutions`.
- Repro:
  1. Have an administrator deactivate one of a user's institution logins.
  2. Sign in as that user and open **profile > Institutions**.
- Expected: only usable logins, or the same `(inactive)` marker Sites uses.
- Actual: the deactivated login is listed as though the user could still sign in there.
- Evidence: the view read in the container at develop 53b077c089. Code-only: the sample database holds no inactive rows.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-480: A rejected password never says which rule it broke (CONFIRMED code)

- Where: `protected/forms/ProfileChangePasswordForm.php:73` calls `PasswordValidator::validateValue()`, which returns rule-specific messages, then discards them: `if ($errors) { $this->addError($attribute, 'Password does not meet requirements'); }`.
- Route: `/profile/password`.
- Repro:
  1. Open **profile > Change password**.
  2. Enter `abcdefgh` as the new password.
  3. Select **Save**.
- Expected: "must contain a number", or whichever rule failed.
- Actual: "Password does not meet requirements", with no way to discover the policy from the screen.
- Evidence: the form read in the container at develop 53b077c089.
- Severity: low-medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Profile pages.

## BUG-481: The Extra Procedures Active filter is a database error, because the table has no active column (CONFIRMED code/db)

- Where: `protected/modules/OphTrConsent/controllers/oeadmin/ExtraProceduresController.php`, `actionList()`, adds a `t.active` condition for the **Only Active** and **Exclude Active** options. `ophtrconsent_procedure_extra` has ten columns and none of them is `active`.
- Route: `/OphTrConsent/oeadmin/ExtraProcedures/list`.
- Repro:
  1. Open **Admin > Consent form > Extra Procedures**.
  2. Set the drop-down beside the search box to **Only Active**.
  3. Select **Search**.
- Expected: a filtered list.
- Actual: a database error page naming an unknown column. **Exclude Active** does the same; only **All** works.
- Evidence: the controller read in the container at develop 53b077c089; `DESCRIBE ophtrconsent_procedure_extra`.
- Severity: medium - two of the three options on a control that is on the screen by default.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-482: The Extra Procedures Delete button prints an array dump and deletes nothing (CONFIRMED code)

- Where: `protected/modules/OphTrConsent/controllers/oeadmin/ExtraProceduresController.php`, `actionDelete()` opens with `print_r($procedures); exit();`, so the delete loop below it is unreachable. The button is at `views/oeadmin/ExtraProcedures/index.php:120-129` and is enabled by the script at `:148-157`.
- Route: `POST /OphTrConsent/oeadmin/ExtraProcedures/delete`.
- Repro:
  1. Open **Admin > Consent form > Extra Procedures**.
  2. Tick a row whose tick box is drawn.
  3. Select **Delete**.
- Expected: the procedure is deleted.
- Actual: a blank page carrying a PHP `Array ( ... )` dump, and nothing is deleted. There is no other route to removing an extra procedure.
- Evidence: the controller and the view read in the container at develop 53b077c089. It reads as debugging code left in.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-483: Saving the extra-procedure subspecialty screen reassigns another institution's rows to your own (CONFIRMED code)

- Where: `protected/modules/OphTrConsent/controllers/oeadmin/ExtraProceduresController.php`, `actionEditSubspecialty()`. When the count scoped to your institution is 0, the display query drops the institution filter and lists other institutions' rows. The save loop then forces `institution_id = Institution::model()->getCurrent()->id` for any user who is not `admin`.
- Route: `/OphTrConsent/oeadmin/ExtraProcedures/EditSubspecialty?subspecialty_id=<id>`.
- Repro:
  1. Sign in as an institution admin at an institution with no assignments for a given subspecialty - in the sample data, anything other than The Monachs Trust.
  2. Open **Admin > Consent form > Extra Procedures Subspecialty Assignment**.
  3. Choose **General Ophthalmology**.
  4. Note that rows are listed with another institution's name in the **Institution** column.
  5. Select **Save**.
- Expected: an empty list, or the other institution's rows left alone.
- Actual: every displayed row is rewritten to the current institution, so one organisation's configuration is silently moved to another. The screen gives no warning, and the rows it shows are exactly the ones it is about to take.
- Evidence: the controller read in the container at develop 53b077c089. Not browser-confirmed.
- Severity: high - cross-institution data loss from a Save that looks like a no-op.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-484: The first extra-procedure assignment added to an empty subspecialty cannot be saved (CONFIRMED code/db)

- Where: `protected/modules/OphTrConsent/views/oeadmin/ExtraProcedures/edit_ExtraProcedureSubspecialtyAssignment.php:133` computes the new row's order as `parseInt($('table.generic-admin tbody tr:last-child ').find('input[name^="display_order"]').val()) + 1`. On an empty grid the last row is CGridView's empty-text row, so the result is `NaN`. The model carries no rule on `display_order`, the column is `int(8) NOT NULL`, and `@@sql_mode` includes `STRICT_TRANS_TABLES`.
- Route: `/OphTrConsent/oeadmin/ExtraProcedures/EditSubspecialty?subspecialty_id=<id>`.
- Repro:
  1. Choose a subspecialty with no assignments.
  2. Select **Add**.
  3. Choose a procedure.
  4. Select **Save**.
- Expected: the assignment is saved.
- Actual: the insert is refused, the transaction rolls back, and a warning flash carries raw database text. Dragging the row before saving works around it, because the sort handler rewrites `display_order`.
- Evidence: the view read in the container at develop 53b077c089; `SELECT @@sql_mode`. This screen's **Add** is its own handler rather than GenericAdmin's `.generic-admin-add`, which has a correct fallback of 1 - that is what the fix looks like.
- Severity: medium.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-485: Supplementary consent questions are displayed by one form type and validated against another (CONFIRMED code)

- Where: `protected/modules/OphTrConsent/views/default/form_Element_OphTrConsent_SupplementaryConsent.php:33` chooses which questions to render with `$form_id = @$_GET['type_id'] ?? '1';`, while `models/Element_OphTrConsent_SupplementaryConsent.php:107` validates against `$_POST['Element_OphTrConsent_Type']['type_id']` - the type actually chosen on screen.
- Route: `/OphTrConsent/Default/create?patient_id=<id>&unbooked=1`, and `/OphTrConsent/Default/update/<event_id>`.
- Repro:
  1. Open **Admin > Consent form > Supplementary Consent** and create a question with an assignment scoped to **Consent Form Type** form 3, **Required** Yes.
  2. Open a patient, **Add Event > Consent form**, and select **Create consent** for an unbooked procedure.
  3. Set **Type** to form 3 on the form.
  4. Save.
- Expected: the question is shown and can be answered.
- Actual: it is never rendered, because the create URL carries no `type_id` and the display falls back to form 1, but validation demands it - "Did not receive answer for required question '...'" with nothing on screen to answer. The same fallback makes form-type-scoped questions invisible on update, and a patient aged 16 or under, whose form is set to type 2 automatically, is shown type 1's questions.
- Evidence: the view and the element model read in the container at develop 53b077c089. Not browser-confirmed; this is the highest-value item on the consent walking list.
- Severity: high - an unanswerable required question blocks the save with no way forward on screen.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-486: The two printed-text fields on supplementary consent are never printed (CONFIRMED code)

- Where: `Ophtrconsent_SupplementaryConsentQuestionAssignment::question_output` and `Ophtrconsent_SupplementaryConsentQuestionAnswer::answer_output`. A grep across `protected/` and `templates/` finds them only in the admin views, the list search conditions and the data dictionary. `views/default/_print_supplementary_consent.php` prints `question_text` - falling back to the question's `name` - and the answer's `display`.
- Route: `/OphTrConsent/oeadmin/SupplementaryConsent/editAssignment/<id>` and `/.../editAnswer/<id>`.
- Repro:
  1. Set a distinctive **Question printed Text** on an assignment and **Answer printed text** on an answer.
  2. Complete that question on a consent form.
  3. Print the form.
- Expected: the printed wording is used on the printout, which is what both labels say.
- Actual: the on-screen wording is printed. Both fields are write-only.
- Evidence: exhaustive grep and the print view read in the container at develop 53b077c089.
- Severity: low, but it is configuration that reads as if it works.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-487: Removing every procedure from an existing consent template saves the rest of the change and then fatals (CONFIRMED code)

- Where: `protected/modules/OphTrConsent/controllers/oeadmin/TemplateController.php`, `actionEdit()` validates, saves, sets the success flash, and only then calls `$model->saveProcedures($templateAtt['procedures'])`. `models/OphTrConsent_Template.php:54` requires `procedures`, but the requirement passes because the relation lazy-loads when the key is absent from the POST, and `widgets/views/MultiSelectList.php` emits its empty marker only on a re-rendered POST. `saveProcedures(array $procedures)` therefore receives `null`.
- Route: `/OphTrConsent/oeadmin/Template/edit/<id>`.
- Repro:
  1. Open **Admin > Consent form > Template**.
  2. Open a template.
  3. Remove every entry from **Procedures**.
  4. Select **Save**.
- Expected: "The template must have at least one procedure", which is what creating a new one with no procedures correctly says.
- Actual: the name and scope changes are written, then an error page. The procedure list is unchanged, so the template survives - but the administrator has no way to tell which half succeeded.
- Evidence: the controller, the model and the widget read in the container at develop 53b077c089. Path traced end to end, not executed.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-488: The Additional Risks screen confirms a save by naming a different feature (CONFIRMED code)

- Where: `protected/modules/OphTrConsent/controllers/oeadmin/AdditionalRisksController.php` sets `Yii::app()->user->setFlash('success', 'Common Systemic Disorder Group created');`.
- Route: `/OphTrConsent/oeadmin/AdditionalRisks/list`.
- Repro:
  1. Open **Admin > Consent form > Additional Risks**.
  2. Change any wording.
  3. Select **Save**.
- Expected: a message about additional risks.
- Actual: "Common Systemic Disorder Group created", whatever was done and whether or not anything was created.
- Evidence: the controller read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-489: A new contact method has no signature option selected and cannot be saved (CONFIRMED code/db)

- Where: `protected/modules/OphTrConsent/views/oeadmin/contact_methods/_row.php:45-50` passes `['separator' => '&nbsp;', 'selected' => '2']` to `CHtml::activeRadioButtonList`, which ignores `selected` and takes its state from the model attribute. `need_signature` is `tinyint(1) NOT NULL` with a NULL default, so a new model carries nothing. `controllers/oeadmin/PatientContactMethodController.php` throws `'Unable to save contact_methods: ' . print_r(...)` when the save fails.
- Route: `/OphTrConsent/oeadmin/PatientContactMethod/list`.
- Repro:
  1. Open **Admin > Consent form > Contact method**.
  2. Select **Add**.
  3. Type a name, tick **Active**, and leave the **Need Signature** radios alone.
  4. Select **Save**.
- Expected: the default of **Signature is optional** the view is clearly trying to set, or an inline validation message.
- Actual: an exception page with raw error output - and because this screen saves the whole table at once, every other edit on screen is lost with it.
- Evidence: the view, the controller and the column default read in the container at develop 53b077c089.
- Severity: medium.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-490: Contact methods and patient relationships ignore their Active flag on the consent form (CONFIRMED code)

- Where: `protected/modules/OphTrConsent/models/Element_OphTrConsent_OthersInvolvedDecisionMakingProcess.php` builds both `getRelationshipItemSet()` and `getContactMethodItemSet()` from `model()->findAll()` with no `active` condition, and `models/Element_OphTrConsent_Withdrawal.php` does the same for relationships.
- Route: the "Others involved in the decision making process" element on a type 4 consent form, and the **Add withdrawal** adder on any saved form.
- Repro:
  1. Open **Admin > Consent form > Contact method**, clear **Active** on **Telephone**, and Save.
  2. Open a type 4 consent form and add a contact.
  3. Open the **Contact method** column.
- Expected: Telephone is no longer offered.
- Actual: it is still offered, and the same is true of a retired relationship. Neither list has a delete, so deactivating is the only retirement route there is - and it does nothing.
- Evidence: both element models read in the container at develop 53b077c089.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-491: A contact with no explicit signature answer reads as No signature instead of falling back to the contact method (CONFIRMED code)

- Where: `Ophtrconsent_OthersInvolvedDecisionMakingProcessContact::getSignatureRequired()` is written as `(int)$this->signature_required ?? (int)$this->consentPatientContactMethod->need_signature`. The cast makes the left operand an int and never null, so the `??` branch is unreachable.
- Route: the "Others involved in the decision making process" element on a type 4 consent form.
- Repro:
  1. Configure a contact method whose **Need Signature** is **Signature require**.
  2. Add a contact using that method without answering the per-contact signature question.
  3. Read whether a signature is asked for.
- Expected: the contact method's own setting applies, which is what the fallback was written for.
- Actual: the contact reads as **No signature**, so a signature the configuration asks for is never collected.
- Evidence: the model read in the container at develop 53b077c089.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-492: The consent layout order is discarded as soon as the form is saved (CONFIRMED code/db)

- Where: `protected/modules/OphTrConsent/controllers/DefaultController.php:1168-1176` (`getEventElements()`) uses `Event::getElements()` for a saved event, and `protected/models/EventType.php:337-350` (`getAllElementTypes()`) orders by `display_order` on `element_type` rather than on `ophtrconsent_type_assessment`.
- Route: `/OphTrConsent/oeadmin/ConsentLayouts/list`, then `/OphTrConsent/Default/view/<event_id>`.
- Repro:
  1. Note the configured type 1 layout order - Type, E-Sign, Procedure, Extra Procedures, Leaflets, Benefits and risks, and so on.
  2. Create and save a type 1 consent form.
  3. Reopen it.
- Expected: the configured order.
- Actual: E-Sign, Type, Leaflets, Procedure, Benefits and risks, Patient Questions, Extra Procedures - the element types' own built-in order. Which sections appear is honoured; the sequence is not, so the drag-to-reorder on the admin screen governs the create screen only.
- Evidence: both files read in the container at develop 53b077c089, with the `display_order` values queried from both tables.
- Severity: low-medium - the admin screen advertises control it does not have after the first save.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-493: Four wording and dead-code defects on the Consent form admin screens (CONFIRMED code)

- Where and what:
  1. `views/oeadmin/templates/list_template.php:166` - the Templates delete alert reads "Please select one or more generic procedure data to delete."
  2. `views/oeadmin/templates/form_OphTrConsent_Template.php:87` - the template edit form labels the field **Subpecialty**, although `attributeLabels()` spells it correctly, so the typo is in the view's own literal.
  3. `views/oeadmin/ExtraProcedures/index.php` - the search placeholder advertises "OPCS Code, Default Duration", neither of which is a field on the model or is searched.
  4. `OphTrConsent_Extra_Procedure::getListBySubspecialty()` at `:146-169` is dead code: nothing calls it, and it joins on a column that does not exist.
- Route: `/OphTrConsent/oeadmin/Template/list`, `/OphTrConsent/oeadmin/Template/edit/<id>`, `/OphTrConsent/oeadmin/ExtraProcedures/list`.
- Repro: open each screen and read the string named above.
- Expected: wording that matches the screen, and no method that could not run if it were called.
- Actual: as listed. Grouped into one entry because each is a single string and none changes what the screen does.
- Evidence: the four files read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Consent form admin screens.

## BUG-494: The Primary Institution column on patient search results sorts by patient identifier (CONFIRMED code)

- Where: `protected/views/patient/results.php:82-91` renders eight column headings, each a sort link carrying its index. `protected/components/PatientSearchPaginationParameters.php:27-35` defines only seven sort options, and the lookup at `:75` falls back with `?? SEARCH_SORT_BY_OPTIONS[0]`.
- Route: `/patient/search`.
- Repro:
  1. Sign in and search a surname that returns several patients.
  2. Select the **Primary Institution** column heading.
- Expected: the list is sorted by institution.
- Actual: index 7 has no entry, so the fallback applies and the list sorts by identifier (`value*1`). Selecting the heading a second time reverses that same sort, so it looks like a working control.
- Evidence: both files read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting patient search.

## BUG-495: Only four of the eight results columns are styled as sortable, though all eight are sort links (CONFIRMED code)

- Where: `protected/views/patient/results.php:104` and `:113` apply the `sortable` class with `in_array($i, array(0, 2, 4, 5))`.
- Route: `/patient/search`.
- Repro:
  1. Run a search that returns several patients.
  2. Compare the **Title**, **Last name** and **Sex** headings with **First name** and **Born**.
- Expected: the same affordance on every heading, since every heading is a link.
- Actual: four headings carry the sortable styling and the rest look like plain text, so users believe they cannot sort by last name.
- Evidence: the view read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting patient search.

## BUG-496: The search hint advertises a name-and-year pattern the search rejects (CONFIRMED code)

- Where: `protected/views/base/_search_bar.php:30-36` lists **Initial Family + DOB** with the example `D Smith 1975`; `protected/components/PatientSearchTerms.php:8` (`PATIENT_NAME_REGEX`) accepts a date only in `d/m/y` form.
- Route: `/` - the search hint popup behind **Search by ID, or Name and Date of Birth (click for options)**, with `dob_mandatory_in_search` on.
- Repro:
  1. Turn on DOB-mandatory search.
  2. Open the search hint popup on the home screen.
  3. Copy the advertised example `D Smith 1975` into the search box and search.
- Expected: a name-plus-date-of-birth search.
- Actual: the string fails the name pattern, so it is classified as a number and searched as an identifier, and no patient is found.
- Evidence: both files read in the container at develop 53b077c089, and `preg_match` run against the pattern inside the container.
- Severity: medium - the application documents a pattern it refuses.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting patient search.

## BUG-497: With DOB mandatory, a name-only search silently becomes an identifier search (CONFIRMED code)

- Where: `protected/components/PatientSearchTerms.php:151-153` returns an empty term set when a date of birth is required and absent, and the caller then falls through to the number branch.
- Route: `/patient/search`.
- Repro:
  1. Turn on DOB-mandatory search.
  2. Type `Smith` into the search box and search.
- Expected: "a date of birth is required", or an equivalent message.
- Actual: the search runs as an identifier lookup and reports that no patient was found, so the user retypes the name rather than adding the date.
- Evidence: the component read in the container at develop 53b077c089.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting patient search.

## BUG-498: A stale site cookie can leave the login screen stuck on a null element (SUSPECTED code)

- Where: `protected/views/site/login.php:251-257` (site branch) and `:183-188` (institution branch) call `document.querySelector('.js-site[data-id="..."]').classList.contains(...)` against the id held in the `current_site_id` cookie. The site list at `:14` is built from active sites only.
- Route: `/site/login`, with `require_site_on_login` on.
- Repro (reasoned from source, not executed):
  1. Sign in at a site while `require_site_on_login` is on, so the cookie is written.
  2. Have that site deactivated in admin.
  3. Return to the login screen.
- Expected: the stale cookie is ignored and the site list is shown.
- Actual (expected from the code): the selector matches nothing, `.classList` throws, and the step machine stops before the site step is drawn.
- Evidence: the view read in the container at develop 53b077c089. Not reproduced - the sample has `require_site_on_login` off, so the branch never runs there. This one needs a live check before it is treated as real.
- Severity: medium if confirmed.
- Status: SUSPECTED (code) on develop @ 53b077c089. Found while documenting the login screens.

## BUG-499: Remember me is implemented but has no control on the login screen (CONFIRMED code)

- Where: `protected/models/LoginForm.php:60` labels a `rememberMe` attribute and `:155` sets `$duration = $this->rememberMe ? 3600*24*30 : 0`. The whole of `protected/views/site/login.php` (391 lines) renders no such control.
- Route: `/site/login`.
- Repro:
  1. Open the login screen.
  2. Look for a **Remember me** tick box.
- Expected: either the control exists, or the 30-day branch is removed.
- Actual: every session is created with duration 0, and the 30-day path is unreachable.
- Evidence: both files read in the container at develop 53b077c089.
- Severity: low - a dead feature rather than a malfunction, but it is the kind of thing a user asks for and is told does not exist.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the login screens.

## BUG-500: Any attempt during a softlock extends it, including one with the correct password (CONFIRMED code)

- Where: `protected/components/UserIdentity.php:361-365` treats a softlocked user as inactive, so a correct password still enters the failure branch. `protected/components/PasswordUtils.php:139-147` and `:165-169`, with `oe-shared/app/Services/UserService.php:84-100`, then call `incrementFailedTries`, whose `setHarsherStatus` uses a `<=` comparison that re-applies the same status and pushes `password_softlocked_until` out by another interval.
- Route: `/site/login`.
- Repro:
  1. Fail sign-in enough times to trigger the softlock.
  2. Wait for the lock interval to pass.
  3. Sign in with the correct password.
- Expected: sign-in succeeds once the lock has expired, or the lock runs down regardless of further attempts.
- Actual: each attempt made while locked resets the clock, so a user who keeps trying is never let back in and reads the same message indefinitely.
- Evidence: the three files read in the container at develop 53b077c089. Plausibly deliberate anti-brute-force behaviour rather than a defect, which is why it is logged as behaviour worth a decision; either way the screen never says the clock has restarted.
- Severity: medium - support burden.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the login screens.

## BUG-501: The OEScape dashboard renders a view that does not exist (CONFIRMED code)

- Where: `protected/controllers/DashboardController.php:177` renders `//dashboard/oescape`; `protected/views/dashboard/` contains only `header_oescape.php` and `index.php`.
- Route: `/dashboard/oEscape`.
- Repro:
  1. Grant a user whatever access the route asks for.
  2. Open `/dashboard/oEscape`.
- Expected: the OEScape summary.
- Actual: a missing-view error. This is a **second, independent** defect on the route already logged as BUG-057 (the action is granted to a role named `none`, which does not exist in `authitem`, so nobody can reach it) - unblocking the access alone would land the user on this error.
- Evidence: the controller read and the view directory listed in the container at develop 53b077c089.
- Severity: medium - it is what BUG-057 is hiding.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the home screens. See also BUG-057.

## BUG-502: Deleting a quick-text category deletes the first row in the table instead (CONFIRMED code)

- Where: `protected/modules/OphTrOperationnote/controllers/AttributesAdminController.php:82` passes the posted id to `find($id)`, which treats a scalar as a SQL condition (`WHERE 5`) rather than a primary key.
- Route: `POST /OphTrOperationnote/AttributesAdmin/list`.
- Repro:
  1. Open **Admin > Operation note > Generic Operation Quick Text** and create three categories.
  2. Tick the third.
  3. Select **Delete**.
- Expected: the third category is deleted.
- Actual: the **first** row in the table is deleted, together with all its phrases via `beforeDelete()`. Ticking N rows destroys the first N rows. With one row ticked the browser removes the ticked row from the display, so the screen and the database disagree until a reload; with more than one ticked the controller echoes `"111"`, which fails the `=== '1'` test in `protected/assets/js/handleButtons.js:107-145` but still parses as JSON, so the operator is told "One or more Element attributes could not be deleted as they are in use." while rows were in fact destroyed.
- Evidence: the controller, `handleButtons.js` and `OphTrOperationnote_Attribute::beforeDelete()` read in the container at develop 53b077c089.
- Severity: high - silent destruction of the wrong record, with a message saying nothing was deleted.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-503: The quick-text list's Search button raises a fatal error (CONFIRMED code)

- Where: `AttributesAdminController.php:31` puts `getItemsAdminLink` into `setListFields`; `protected/components/Admin.php:773-789` (`searchAll()`) copies it into `compare_to`; `protected/components/ModelSearch.php:259-262` and `:307-311` see `method_exists($model, 'getItemsAdminLink')`, call it, and index the returned HTML string as an array.
- Route: `/OphTrOperationnote/AttributesAdmin/list`.
- Repro:
  1. Open **Admin > Operation note > Generic Operation Quick Text**.
  2. Select **Search** (with or without a search term).
- Expected: a filtered list.
- Actual: `TypeError: Cannot access offset of type string on string` on PHP 8.4. The search box on this screen cannot be used at all.
- Evidence: the three files read in the container at develop 53b077c089; the PHP version and the offset behaviour checked with `php -r` in the container.
- Severity: high - the control is unusable.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-504: Saving a narrower personnel-type default set rewrites the broader set it inherited from (CONFIRMED code/db)

- Where: `protected/modules/OphTrOperationnote/controllers/AdminController.php:329` fetches with `findTenanted(..., false)`, which falls back to a broader record, and `:370` then does `$set->attributes = $data;` on that same record. `PersonnelTypeSet::findTenanted()` orders `site_id DESC, subspecialty_id DESC, institution_id DESC`.
- Route: `/OphTrOperationnote/admin/personnelTypeDefaultSets`.
- Repro:
  1. Open the screen and choose any subspecialty, leaving institution and site blank - the installation-level set is shown.
  2. Choose an institution. The same items are shown, having been fetched by fallback.
  3. Select **Save**.
- Expected: a new institution-level set, leaving the installation-level one alone.
- Actual: the installation-level record is re-saved carrying an `institution_id`, so it stops being the default for every other institution and site. **Delete entire set for this institution** destroys the installation-level record the same way. All 17 sets that ship are installation-level, so this fires on the very first narrower save anyone makes.
- Evidence: the controller (`:296-401`) and the model read in the container at develop 53b077c089; `SELECT` on the set table shows 17 rows, all with `institution_id IS NULL AND site_id IS NULL`.
- Severity: high.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-505: Personnel-type default set failures are collected into a variable that is never rendered (CONFIRMED code)

- Where: `AdminController.php:333` initialises `$errors = []`, `:349` and `:380` assign failures to `$error` (singular), and `:399` passes `'errors' => $errors` - still empty - to the view.
- Route: `/OphTrOperationnote/admin/personnelTypeDefaultSets`.
- Repro: cause any save or delete on that screen to fail.
- Expected: the failure is reported.
- Actual: the page re-renders looking unchanged, and the administrator believes the change was saved.
- Evidence: the controller read in the container at develop 53b077c089.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-506: Blanking a protected personnel type's name deletes it and orphans everything that referenced it (CONFIRMED code/db)

- Where: `protected/controllers/BaseAdminController.php:153-365` (`genericAdmin()`) skips a posted row whose label field is empty, and then sweeps every row not present in the post with `addNotInCondition('id', ...)`.
- Route: `/OphTrOperationnote/admin/personnelTypes`.
- Repro:
  1. Open **Admin > Operation note > Personnel Types**.
  2. Clear the text of **Assistant**, which has no delete link because it is in use.
  3. Select **Save**.
- Expected: a validation error, or the row protected as the missing delete link implies.
- Actual: the row is skipped by the save, then deleted by the sweep. `personnel_type` has no inbound foreign keys, so the 87 operation-note rows and 17 default-set items that referenced it are left pointing at nothing.
- Evidence: the base controller and `PersonnelType::isInUse()` read in the container at develop 53b077c089; `SHOW CREATE TABLE` on the referencing tables shows no foreign key.
- Severity: high.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-507: Set Default on the operative-device mapping screen does not clear the previous default (CONFIRMED code)

- Where: `OperativeDeviceMappingController::actionSetDefault` sets `default = 1` on the chosen row without clearing its siblings for the same site and subspecialty.
- Route: `/OphTrOperationnote/OperativeDeviceMapping/list`.
- Repro:
  1. Choose a site and a subspecialty.
  2. Select **Set Default** on one agent, then on a second.
- Expected: one default per site-and-subspecialty pair.
- Actual: both are flagged, and both are pre-selected in **Agents** on every new Cataract element. The only route back is **Remove Default** on the one you did not want.
- Evidence: the controller read in the container at develop 53b077c089.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-508: The mapping screen acts without confirmation and ignores its own search configuration (CONFIRMED code)

- Where: `protected/assets/js/oeadmin/listAutocomplete.js` - `deleteItem`, `setDefaultItem`, `removeDefaultItem` and `addItem` each fire a bare AJAX GET and reload, with no dialog. `protected/widgets/AutoCompleteSearch.php:32-35` and `protected/views/admin/generic/listAutocomplete.php:140-149` never emit the controller's placeholder, `$minLength` or `$triggerSearch`.
- Route: `/OphTrOperationnote/OperativeDeviceMapping/list`.
- Repro:
  1. Select **Delete** on any mapping row.
  2. Separately, look at the search box at the foot of the table.
- Expected: a confirmation before a delete; the placeholder the controller sets ("search for adding operative devices").
- Actual: the row is gone with no dialog and no undo, and the box reads the generic "Type to search". The controller's `allowBlankSearch => 1` is dead code because `$triggerSearch` is never emitted.
- Evidence: the script, the widget and the view read in the container at develop 53b077c089.
- Severity: low-medium - the missing confirmation is the material part.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-509: Three defects in the post-op instructions row script (CONFIRMED code)

- Where: `protected/modules/OphTrOperationnote/views/admin/postOpInstructions/list.php`.
  1. Both save and delete run `beforeSend: $tr.find('td.actions .wrapper').hide()` and restore the controls only when `data.success === 1`, so a failed row save hides that row's controls until the page is reloaded.
  2. On save success the script runs `$actions.find('a.delete').removeClass('hidden')`, but a freshly added row is rendered without an `a.delete` element, so a new instruction never gains a delete link without a reload.
  3. The **Add** button carries `'data-uri' => '/OphCiExamination/admin/addInvoiceStatus'`, a copy-paste from another module. It is inert today only because the page's own script binds `#add_new`.
- Route: `/OphTrOperationnote/admin/postOpInstructions`.
- Repro: cause a row save to fail for (1); add a row and look for its delete link for (2); read the button markup for (3).
- Expected: controls return after a failure, a new row behaves like an existing one, and the button points at its own module.
- Actual: as described. Grouped into one entry because all three are in the same short script.
- Evidence: the view read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-510: Post-op instructions have no validation, no ordering control and no pagination (CONFIRMED code/db)

- Where: `OphTrOperationnote_PostopInstruction::rules()` is empty; `AdminController::actionPostOpInstructions()` (`:229-259`) renders `findAll()` with no order, no filter and no pagination.
- Route: `/OphTrOperationnote/admin/postOpInstructions`.
- Repro:
  1. Open the screen - all 272 shipped rows are drawn on one page in no particular order.
  2. Select **Add**, leave **Content** blank, and save.
- Expected: a required-field error, and a list an administrator can navigate.
- Actual: the blank instruction is saved and offered to clinicians. The clinical adder orders by `display_order`, which this screen never sets, so the order the surgeon sees cannot be controlled from here at all.
- Evidence: the model and the controller read in the container at develop 53b077c089; the row count from the database.
- Severity: medium.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-511: The incision-length screen is always headed Add, and its value is unvalidated (CONFIRMED code)

- Where: the module's incision-length form view carries the heading "Add incision length" as a literal, so editing an existing default is headed as if it were a new one. `OphTrOperationnote_CataractIncisionLengthDefault::rules()` requires `firm_id` and `value` and applies a uniqueness rule to `firm_id`, with no numeric rule on `value`, which is a `float NULL` column.
- Route: `/OphTrOperationnote/admin/viewIncisionLengthDefaults`.
- Repro:
  1. Open an existing default and read the heading.
  2. Type a word into **Value** and save.
  3. Separately, add a second default for a context that already has one.
- Expected: an Edit heading, a numeric check, and a duplicate message naming the context.
- Actual: the heading always says Add; non-numeric text is accepted; and `CUniqueValidator` prints the context's primary key rather than its name, so the message does not identify the offending service.
- Evidence: the view and the model read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-512: Paging the generic default comments list discards the search (CONFIRMED code)

- Where: `views/admin/list_OphTrOperationNote_Generic_Procedure_Data.php:21-42` posts the search form, `:95` renders a `LinkPager` that links with GET, and `GenericProcedureDataController::actionList():36` only reads the search terms on a POST.
- Route: `/OphTrOperationnote/GenericProcedureData/list`.
- Repro:
  1. Search for a procedure.
  2. Select page 2.
- Expected: page 2 of the search results.
- Actual: page 2 of the unfiltered 294-row list.
- Evidence: the view and the controller read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-513: A failed save on generic default comments is announced on the success channel (CONFIRMED code)

- Where: `GenericProcedureDataController.php:91` calls `setFlash('success', 'Generic Operation data: error saving')`.
- Route: `/OphTrOperationnote/GenericProcedureData/list`.
- Repro: cause a save to fail.
- Expected: an error-styled message.
- Actual: the failure text is drawn in the green success banner, so it reads at a glance as if the save worked.
- Evidence: the controller read in the container at develop 53b077c089. Same pattern as BUG-453.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-514: Default comment text is echoed unescaped in the admin list (CONFIRMED code)

- Where: `views/admin/list_OphTrOperationNote_Generic_Procedure_Data.php:60` renders `<?= $model->default_text ?>` with no `CHtml::encode`.
- Route: `/OphTrOperationnote/GenericProcedureData/list`.
- Repro:
  1. Edit any row and put markup into **Default Text**.
  2. Save and return to the list.
- Expected: the markup shown as text.
- Actual: it renders as part of the page. The clinical side uses `CHtml::textArea` and is safe, so the exposure is admin-to-admin only, but this is the one unescaped output in the group.
- Evidence: the view read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-515: The generic-comments search placeholder warns about case sensitivity that does not apply to the column being searched (CONFIRMED code/db)

- Where: `views/admin/list_OphTrOperationNote_Generic_Procedure_Data.php:31` - placeholder "Search Term , Procedure Id - (all are case sensitive)"; `GenericProcedureDataController.php:42-45` searches `proc.term`, `snomed_term` and `aliases`.
- Route: `/OphTrOperationnote/GenericProcedureData/list`.
- Repro: search a procedure name in lower case.
- Expected: the placeholder to describe the search.
- Actual: `proc.term` is `latin1_swedish_ci`, so the main column matches case-insensitively; only `snomed_term` and `aliases` (both `utf8mb3_bin`) are case-sensitive. The warning is wrong for the column people actually search.
- Evidence: the view and controller read in the container at develop 53b077c089; collations from `information_schema.columns`.
- Severity: cosmetic.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-516: Default comments can be edited for procedures that have their own element, where they can never appear (CONFIRMED code/db)

- Where: `GenericProcedureDataController::actionAdd()` excludes procedures that have a dedicated element, and `actionEdit()` applies no such filter. The default text only ever reaches a **generic procedure** element.
- Route: `/OphTrOperationnote/GenericProcedureData/list`.
- Repro:
  1. Open the row for procedure 77, "Cross-linking of cornea", which ships in the sample data and also has a row in `ophtroperationnote_procedure_element`.
  2. Type default text and save.
- Expected: the screen says the text cannot reach a note, or the row is not offered.
- Actual: the row is editable and gives no hint, so an administrator can spend time configuring text that no surgeon will ever see. The sample data ships one such row already.
- Evidence: the controller read in the container at develop 53b077c089; both tables queried.
- Severity: low.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-517: The quick-text Procedure list offers procedures whose picker can never appear (CONFIRMED code)

- Where: `AttributesAdminController.php:54-60` builds the drop-down from `Procedure::model()->findAll(array('order'=>'term'))` with no filter; `views/default/form_Element_OphTrOperationnote_GenericProcedure.php:108-114` only renders the "+" picker on a generic procedure element.
- Route: `/OphTrOperationnote/AttributesAdmin/list`.
- Repro:
  1. Add a quick-text category and choose a procedure that has a dedicated element - one of the 32.
  2. Create an operation note using that procedure.
- Expected: the picker, or a warning at configuration time.
- Actual: no "+" ever appears, and nothing on the admin screen says why.
- Evidence: the controller and the form view read in the container at develop 53b077c089. Same shape as BUG-516.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-518: Quick-text ordering is drawn on screen but never wired up (CONFIRMED code)

- Where: `views/admin/generic/list.php:102-104` renders `<tbody class="sortable">` and a hidden **Sort** button because `display_order` is a list field, but the sortable is only initialised by `protected/assets/js/oeadmin/list.js:19-23`, and `AttributesAdminController` extends `BaseAdminController` rather than `ModuleAdminController`, so nothing ever registers that file.
- Route: `/OphTrOperationnote/AttributesAdmin/list`.
- Repro:
  1. Open the list.
  2. Select the up or down arrow in the **Display Order** column.
- Expected: the row moves.
- Actual: nothing happens, and the order can only be influenced by the sequence in which categories were created.
- Evidence: the view, the script and the controller's parent class read in the container at develop 53b077c089.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-519: No destructive action on the Operation note admin screens asks for confirmation (CONFIRMED code)

- Where: `protected/assets/js/handleButtons.js:62-145` (the generic **Delete**), `protected/modules/OphTrOperationnote/assets/js/admin.js` (Generic Operation Default Comments), and `protected/assets/js/oeadmin/listAutocomplete.js` (every mapping action). `GenericProcedureDataController::actionDelete()` is a straight `deleteAll`.
- Route: every list screen under **Admin > Operation note**.
- Repro: select **Delete** on any row on any of those screens.
- Expected: a confirmation dialog, as other parts of the application use.
- Actual: the record goes immediately, with no dialog and no undo. Logged as one entry because it is one missing convention rather than seven separate faults, and because it compounds BUG-502, where the wrong row is the one that goes.
- Evidence: the three scripts and the controller read in the container at develop 53b077c089.
- Severity: medium in aggregate.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the Operation note admin screens.

## BUG-520: Quarantining an infected image fails because only the PDF placeholder can ever match (CONFIRMED code/db)

- Where: `protected/controllers/VirusScanController.php:114-115` looks a replacement placeholder up by `mime_content_type($file)` and dereferences the result on the next line. The four rows in `quarantined_placeholder_file` carry mimetypes `application/pdf`, `application/png`, `application/jpeg` and `application/gif`; `mime_content_type` returns `image/png`, `image/jpeg` and `image/gif` for those formats, so three of the four rows are unreachable.
- Route: `/VirusScan/scanProtectedFiles`.
- Repro:
  1. Turn virus scanning on for the deployment.
  2. Sign in as an account holding the Virus Scanning permission.
  3. Have an uploaded PNG or JPEG in protected files that the scanner flags.
  4. Select **Scan Uploaded Files** and run the scan.
- Expected: the file is quarantined and replaced with a placeholder of its own type.
- Actual: an application error part-way through the scan, after the file has already been copied into quarantine - so the scan stops with the estate half-processed.
- Evidence: the controller read in the container at develop 53b077c089; the placeholder table queried. The mimetype mismatch is confirmed; the crash follows from it and was not executed, because `quarantined_file` is empty in the sample database.
- Severity: medium.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the menu-bar core screens.

## BUG-521: The quarantined copy's permissions are set in decimal, not octal (CONFIRMED code)

- Where: `protected/controllers/VirusScanController.php:117` - `chmod($quarantined_file->getQuarantinedUID(), 600);`.
- Route: `/VirusScan/scanProtectedFiles`.
- Repro:
  1. Turn virus scanning on and run a scan with an infected PDF present.
  2. Inspect the permissions of the file written under the quarantine directory.
- Expected: `0600`, owner read and write only, which is plainly what the literal is meant to say.
- Actual: decimal 600 is octal 1130 - group-writable, world-executable, sticky bit set, and not readable by its own owner. A quarantined infected file ends up more widely accessible than the code intends.
- Evidence: the controller read in the container at develop 53b077c089. The literal is confirmed; the resulting mode is arithmetic rather than observation.
- Severity: medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the menu-bar core screens.

## BUG-522: The medication form and stop routes cannot run at all (CONFIRMED code/db)

- Where: `protected/controllers/MedicationController.php` (220 lines) works against `ArchiveMedication`, whose `tableName()` returns `archive_medication`.
- Routes: `/medication/form`, `/medication/stop`.
- Repro:
  1. Sign in as an account holding **Edit** or **API access**.
  2. Type `/medication/form/1` into the address bar.
- Expected: a form, or an honest "not found".
- Actual: an application error. Without a patient the action is refused as a bad request; with one it fatals on the missing table. `/medication/stop` gives "The requested page does not exist." from `BaseController::fetchModel()` (`protected/controllers/BaseController.php:357-369`) before the missing table is even reached.
- Evidence: the controller read in the container at develop 53b077c089; `archive_medication`, `drug`, `drug_route`, `drug_frequency`, `drug_route_option` and `medication_stop_reason` are all absent from the schema; no `MedicationStopReason.php` exists in the tree; nothing links to either route.
- Severity: low - confirmed dead code, reachable only by typing the address. The honest fix is deletion rather than repair.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the menu-bar core screens.

## BUG-523: Association rows on both directory summaries are styled as clickable and are not (CONFIRMED code)

- Where: `protected/views/gp/view.php:100` and `protected/views/practice/view.php:92` emit `<tr class="clickable">`, but neither file binds a handler - unlike `protected/views/gp/index.php:106` and `protected/views/practice/index.php:96`, which do.
- Routes: `/gp/view/<id>`, `/practice/view/<id>`.
- Repro:
  1. Run with `OE_USE_CPA_MODEL` set, so associations exist.
  2. Open a practitioner with at least one practice.
  3. Hover a row under **Associated Practices** - the cursor changes to a hand.
  4. Select it.
- Expected: the practice opens, which is what the identical styling does on the two list screens.
- Actual: nothing happens.
- Evidence: the four views read in the container at develop 53b077c089. Not observed live - `contact_practice_associate` holds no rows here.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the menu-bar directory screens.

## BUG-524: Import Patients is offered on one permission and demands five (CONFIRMED code)

- Where: the menu entry at `protected/config/core/common.php:714-719` carries `'restricted' => array('admin')`; `CsvController::uploadAccess()` at `:14-20` requires `admin` **and** `TaskAddPatient` **and** `TaskEditEpisode` **and** `TaskEditEvent` **and** `TaskCreateTrial`, joined by `&&`.
- Route: `/csv/upload?context=patients`.
- Repro:
  1. Turn `enable_patient_import` on.
  2. Sign in as an account holding `admin` but not `TaskCreateTrial`.
  3. Note **Import Patients** in the menu bar and select it.
- Expected: the entry appears for people who can use it.
- Actual: the entry is drawn on one permission while the screen demands five, so it is a dead end for anyone missing any of the other four. It also demands a **trials** permission in order to import patients, which nothing on the screen explains.
- Evidence: both files read in the container at develop 53b077c089. Adjacent to BUG-200, which is a different fault on the same screen.
- Severity: low-medium.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the menu-bar core screens.

## BUG-525: A practice's name is assembled by two different rules on two screens (CONFIRMED code)

- Where: `protected/views/practice/index.php:52` prints `contact->first_name` alone; `protected/views/practice/view.php:38` prints `contact->getFullName()`.
- Routes: `/practice/index` and `/practice/view/<id>`.
- Repro:
  1. Give a practice contact a surname or a title through **Update Practice Details**.
  2. Find it on the list, then open it.
- Expected: the same name on both screens.
- Actual: the list shows the first-name part only; the record shows the assembled full name.
- Evidence: both views read in the container at develop 53b077c089. The two agree on this data only because `ProcessHscicDataCommand::importPractice()` puts the whole practice name into `first_name` and never sets a surname, so the user-visible symptom is predicted rather than seen.
- Severity: low.
- Status: CONFIRMED (code) on develop @ 53b077c089. Found while documenting the menu-bar directory screens.

## BUG-526: Nothing on the practice screens shows whether a practice is still open (CONFIRMED code/db)

- Where: `Practice.is_active` is maintained by `protected/commands/ProcessHscicDataCommand.php` - set from the national file's status, and cleared at `:1211` for practices the file has dropped - but neither `protected/views/practice/index.php` nor `protected/views/practice/view.php` renders it.
- Routes: `/practice/index`, `/practice/view/<id>`.
- Repro:
  1. Open **Practices**.
  2. Look for any indication of state on a practice the national file no longer carries.
- Expected: what the practitioner directory already does - an **Active** column with a cross on the closed ones.
- Actual: open and closed practices are indistinguishable, and a user can attach a closed practice to a patient with no warning.
- Evidence: the command and both views read in the container at develop 53b077c089; the column confirmed present in the schema. All 179 sample practices are active, so it cannot be demonstrated on this data.
- Severity: low, with clinical consequences on a live system.
- Status: CONFIRMED (code/db) on develop @ 53b077c089. Found while documenting the menu-bar directory screens.

## BUG-527: The practice summary dereferences a practitioner's contact label without a guard (SUSPECTED code)

- Where: `protected/views/practice/view.php:96` - `$cpa->gp->contact->label->name`.
- Route: `/practice/view/<id>`.
- Repro (reasoned from source, not executed):
  1. Run with associations enabled.
  2. Attach a practitioner whose contact has no label to a practice.
  3. Open the practice.
- Expected: a blank **Role** cell.
- Actual (predicted): an application error.
- Evidence: the view read in the container at develop 53b077c089. `contact_practice_associate` is empty here, so it cannot be triggered on this data.
- Severity: low if confirmed.
- Status: SUSPECTED (code) on develop @ 53b077c089. Found while documenting the menu-bar directory screens.

## BUG-528: The disorder summary dereferences a specialty without a guard (SUSPECTED code)

- Where: `protected/views/disorder/view.php:50` - `isset($model->specialty_id) ? Specialty::model()->findByPk($model->specialty_id)->name : ''`, which guards the id being set but not the row being found.
- Route: `/disorder/view/<id>`.
- Repro: delete a specialty while disorders still point at it, then open one of those disorders.
- Expected: a blank specialty.
- Actual (predicted): an application error.
- Evidence: the view read in the container at develop 53b077c089. A left join of `disorder` against `specialty` returns no orphans in the sample database, so it cannot fire here and may be unreachable if specialties are never hard-deleted. Recorded for completeness rather than for action.
- Severity: very low.
- Status: SUSPECTED (code) on develop @ 53b077c089. Found while documenting the menu-bar core screens.

## BUG-529: A patient CSV with no diagnosis column raises three PHP warnings per row (SUSPECTED code)

- Where: `protected/helpers/CsvImportManager.php:484` - the `else` branch, reached precisely when the `diagnosis` key is absent, then reads `$patient_raw_data[$diagnosis_field]`, at which point the mandatory diagnosis keys are absent too.
- Route: `/csv/preview?context=patients`.
- Repro:
  1. Build a patient CSV with no `diagnosis` column.
  2. Upload it and read the preview.
- Expected: a clean preview.
- Actual: three "Undefined array key" warnings per row. `null != ''` is false, so no import error is raised and the import still works - whether the warnings reach the screen depends on the deployment's error display.
- Evidence: the helper read in the container at develop 53b077c089. Not uploaded.
- Severity: very low.
- Status: SUSPECTED (code) on develop @ 53b077c089. Found while documenting the menu-bar core screens.

## BUG-530: Team form's user-row template hardcodes a PHP $key where Mustache {{key}} belongs (CONFIRMED live)

- Where: `protected/views/default/_user_team_assignment.php:96` - the Mustache template block (`#user_row_template`) renders its no-permission branch with PHP `<?= $key ?>` where the permission branch correctly uses `{{key}}`. `$key` is the loop variable of the earlier `foreach ($assigned_users ...)`, so it is undefined when the team has no members yet, and holds the LAST member's index when it does.
- Route: `/oeadmin/team/add` and `/oeadmin/team/edit/{id}`, rendered for a user without the change-team-role permission (`$can_change_team_role` false).
- Repro:
  1. Log in as a user who can open the team form but lacks the team-role permission.
  2. Open Add Team (no members yet), or edit a team and add a user via the picker.
- Expected: the form renders; each added row posts under its own index.
- Actual: with no members the page 500s ("Undefined variable $key" at line 96); with members every JS-added row's hidden task field reuses the last existing member's index, so a new member's task overwrites an existing member's on save.
- Evidence: 500 reproduced live on snail-web-1 during the demo-data seeding walks (2026-08-09); the collision branch read in the container source.
- Severity: medium (form unusable for non-privileged users; silent data overwrite in the members case).
- Status: CONFIRMED (500 branch) / SUSPECTED (index-collision branch) on develop @ 53b077c089. Found while seeding the teams admin recipe.

## BUG-531: Required Systemic Diagnoses set form - picking from the disorder search never saves (CONFIRMED live)

- Where: `protected/modules/OphCiExamination/modules/ExaminationAdmin/views/systemicdiagnosesassignment/_form.php` - the inline `OpenEyes.UI.AutoCompleteSearch.init` `onSelect` writes the picked id with `input.siblings('.savedDiagnosis').val(response.id)`, but the form's custom `singleTemplate` nests the hidden `.savedDiagnosis` input inside a sibling `<div>`, so `siblings()` matches nothing and the id is never stored. The visible search input is itself named `[disorder_id]` and ends up submitting the label text, which the trailing empty hidden input then overrides.
- Route: `/OphCiExamination/admin/SystemicDiagAssignment/create` (and edit - same partial).
- Repro:
  1. Admin > Examination > Required Systemic Diagnoses > Add.
  2. Add a diagnosis row, type into the disorder search, pick a suggestion - the label renders in the row as if selected.
  3. Save.
- Expected: the set saves with the picked diagnosis.
- Actual: "Please fix the following input errors: Disorder cannot be blank." for every row, whatever was picked. The screen cannot be completed through its search control at all.
- Workaround: the commonly-used diagnoses dropdown on the same row goes through `DiagnosesSearchController.addDiagnosis`, which uses `$row.find('.savedDiagnosis')` and works.
- Evidence: reproduced twice live on snail-web-1 by the seed suite (2026-08-10): row shows "Marfan's syndrome", hidden input stays empty, save rejects; template and handler read in the container source.
- Severity: medium (admin screen's primary control is dead; obscure workaround only).
- Status: CONFIRMED on develop @ 53b077c089. Found while seeding the required systemic diagnoses set recipe.

## BUG-532: Pathway Step Groups cannot be attached to or used by pathway steps (CONFIRMED code/db/live)

- Where: `protected/modules/Admin/controllers/WorklistController.php::actionPathwayStepGroups()`, `protected/models/PathwayStepGroup.php`, and `PathwayStepType.pathway_step_group_id`.
- Route: `/Admin/worklist/pathwayStepGroups`.
- Repro:
  1. Open **Admin > Worklist > Pathway Step Groups**.
  2. Add a group, optionally restrict it to sites or subspecialties, and save.
  3. Open the pathway-step and pathway-preset administration screens and look for a way to assign a step to that group or for any changed grouping or filtering.
- Expected: a group can be attached to pathway step types, and its order, site and subspecialty restrictions affect the steps offered in the worklist pathway interface.
- Actual: the screen only creates and edits group rows. There is no frontend control that assigns a pathway step type to a group, and no worklist or clinical runtime code consumes the relation. All 16 pathway step types in the sample database have a null group id, including the shipped **Custom** group.
- Evidence: the screen walked live; the controller, models, migrations and whole source tree inspected; the three group tables and `pathway_step_type.pathway_step_group_id` queried in the sample database.
- Severity: low - the unused configuration is misleading, but it does not disturb existing worklists.
- Status: CONFIRMED (code/db/live) on develop @ 9d6f524ac23b826db3c58c00596471127828989d. Found while documenting the Worklist administration screens.
