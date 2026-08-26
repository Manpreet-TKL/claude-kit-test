# OpenEyes documentation bug ledger

This is the active defect ledger for findings made while documenting OpenEyes.
Start new entries at **BUG-569**. BUG-001 through BUG-532 remain in the local
historical archive at `~/openeyes_unverified_bugs.md`; do not copy that archive
into this repository because it predates the kit's rules for client data and
publishable evidence.

This file records product defects, not unclear documentation. A documentation
page may cite an existing entry through `known_issues:`. Do not put the defect's
full investigation history into a user guide.

## Recording a finding

1. Search this file and the historical archive for the symptom, visible label,
   route, and affected component before allocating an id.
2. Use the next unused id. Never renumber or reuse an id.
3. Remove client names, real hostnames, internal addresses, credentials,
   patient-shaped data, and identifying exports. Use a generic deployment and
   sample-data description.
4. Mark a code-predicted defect as `SUSPECTED`. Mark it `CONFIRMED` only when a
   repeatable runtime path or equally strong evidence establishes the behaviour.
5. Add the id to a page's `known_issues:` only after the entry exists here.

Use this shape:

```markdown
## BUG-NNN: Short title (SUSPECTED or CONFIRMED)

- **Area**: Module or component, plus where the problem appears.
- **Route**: Generic application URI or URIs.
- **Repro**:
  1. Start from a stated role and sample-data condition.
  2. Perform one visible action per step.
  3. Save, reload, or inspect the resulting state.
- **Expected**: The reasonable outcome.
- **Actual**: The observed outcome.
- **Evidence**: Code, database, test, or live-walk evidence and its date.
- **Severity**: Low, medium, or high, with a short reason.
- **Status**: SUSPECTED or CONFIRMED, plus the application revision.
```

## Active entries

## BUG-557: DM+D Add creates a local medication with a national source identity (SUSPECTED)

- **Area**: Prescription medication catalogue administration and institution
  scoping.
- **Route**: `/OphDrPrescription/OphDrPrescriptionAdmin/dmdDrugsAdmin/list`,
  `/OphDrPrescription/OphDrPrescriptionAdmin/dmdDrugsAdmin/edit` and
  `/OphDrPrescription/OphDrPrescriptionAdmin/dmdDrugsAdmin/save`.
- **Repro**:
  1. Sign in with the installation-level `admin` role and open **Admin > Drugs >
     DM+D Drugs**.
  2. Select **Add**, enter a name which is not a dm+d concept, and save it.
  3. Reopen the row and inspect its source subtype and preferred code.
- **Expected**: A nationally sourced catalogue screen either imports validated
  dm+d concepts only or creates an explicitly local medication which can be
  scoped to the institutions that should use it.
- **Actual**: The generic medication save path creates a row with Source Type
  `DM+D`, Source Subtype `UNMAPPED` and a locally generated `UNMAPPED<n>`
  preferred code. It has not been matched to dm+d, but downstream code treats
  Source Type `DM+D` as a national medication and does not apply the institution
  mapping required for Source Type `LOCAL`.
- **Evidence**: `DmdDrugsAdminController::$list_mode_buttons`,
  `RefMedicationAdminController::actionSave()`, the user-medication source
  constants and the source-type conditions in medication searches were traced
  on 2026-08-26. The application test also deliberately exercises saving a new
  row through this route. No row was created on the shared deployment.
- **Severity**: High. A hand-entered medicine can be presented as nationally
  identified and bypass local institution scoping, undermining catalogue
  provenance and increasing the chance of the wrong medicine being selected.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled browser and
  clinical-picker reproduction.

## BUG-558: Deleting a used medical device breaks its clinical record (CONFIRMED)

- **Area**: Medical Device Usage catalogue and saved event rendering.
- **Route**: `/TrDeviceUsageRecord/deviceAdmin/show?id={id}`,
  `/TrDeviceUsageRecord/deviceAdmin/delete?id={id}` and a saved Medical Device
  Usage Record event containing that device.
- **Repro**:
  1. Record a device on a Medical Device Usage Record event and save it.
  2. Open **Admin > Medical Device Usage > Manage Devices**, open the same device
     and select **Delete Device**.
  3. Reopen the saved clinical event.
- **Expected**: A used catalogue row cannot be deleted, or the clinical entry
  retains the identity needed to display safely.
- **Actual**: The device repository hard-deletes the row. The clinical entry has
  no foreign key to prevent deletion and stores no identity snapshot. Its view
  then calls methods and properties on the missing `medical_device` relation.
- **Evidence**: Controller, repository, event view and migrations were traced on
  2026-08-26. The deployed schema confirms there is no foreign key from
  `trdeviceusagerecord_device_procedure_entry.medical_device_id` to the medical
  device table. It currently contains one linked clinical entry and no orphan;
  no shared data was deleted for the reproduction.
- **Severity**: High. Routine-looking catalogue maintenance can remove the
  traceability identity from a patient record and make the saved event fail to
  render.
- **Status**: CONFIRMED by code and deployed schema on application revision
  `9d6f524ac23b826db3c58c00596471127828989d`.

## BUG-559: Device catalogue edits rewrite historical traceability (SUSPECTED)

- **Area**: Medical Device Usage events and MDOR reporting after catalogue
  maintenance.
- **Route**: `/TrDeviceUsageRecord/deviceAdmin/show?id={id}`,
  `/TrDeviceUsageRecord/categoryAdmin/show?id={id}`, a saved Medical Device
  Usage Record event and `/TrDeviceUsageRecord/DeviceUsageReport/index`.
- **Repro**:
  1. Save a Medical Device Usage Record using an existing device.
  2. Edit that device's UDI, manufacturer, model, alias or category, or edit the
     category's name or GMDN code.
  3. Reopen the old event and generate an MDOR extract covering it.
- **Expected**: The identity and classification recorded at the time of the
  procedure remain auditable, or the interface warns that an edit will rewrite
  historical presentation and reporting.
- **Actual**: The clinical entry stores only `medical_device_id` plus item-level
  quantity, lot, serial and expiry data. The event view and MDOR formatter read
  the current device and category rows, including the current UDI and GMDN code.
  There is no snapshot or effective date.
- **Evidence**: Event schema, model relations, event view and
  `DeviceUsageReportRowFormatter` were traced on 2026-08-26. No shared catalogue
  row was changed to reproduce the write path.
- **Severity**: High. Correcting or reusing reference data can alter the apparent
  identity and classification of devices already recorded against patients and
  included in regulatory extracts.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled before-and-after
  event and report reproduction.

## BUG-536: MDOR Previous Reports exposes every extract request (SUSPECTED)

- **Area**: Medical Device Usage Record reporting and protected-file download.
- **Route**: `/TrDeviceUsageRecord/DeviceUsageReport/index` and the download
  links it renders.
- **Repro**:
  1. On a deployment with MDOR requests made by more than one user or
     institution, sign in as a user who can view device-usage reports.
  2. Open **Reports > Medical Device Usage Record > MDOR extract**.
  3. Inspect **Previous Reports** and try the completed download links.
- **Expected**: The list is limited to requests the user is entitled to see,
  such as their own requests or requests for institutions they can access.
- **Actual**: The repository counts and loads every report request without a
  user or institution condition. Each completed row exposes its protected-file
  download link. The download controller checks only the general protected-file
  permission, not ownership of this report.
- **Evidence**: Code path reviewed on 2026-08-26 in
  `DeviceUsageReportController::actionIndex()`, the Yii
  `DeviceUsageReportRepository::paginated()` implementation,
  `DeviceUsageReportResource::populateFromDTO()` and
  `ProtectedFileController::actionDownload()`. The sample database contains no
  report request made by a second account, so cross-account reproduction was
  not possible.
- **Severity**: High. A completed registry extract contains identifiable patient
  and procedure data and may cover institutions the viewing user cannot
  otherwise report on.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a runtime reproduction
  with two sample accounts.

## BUG-537: MDOR OperationDate comes from the device record rather than the operation (CONFIRMED)

- **Area**: Medical Device Usage Record, generated MDOR CSV.
- **Route**: `/TrDeviceUsageRecord/DeviceUsageReport/index`.
- **Repro**:
  1. Record a Medical Device Usage Record against an older Operation Note.
  2. Request an MDOR extract covering the date on which the device record was
     created.
  3. Compare the CSV `OperationDate` and `OperationTime` with the linked
     Operation Note.
- **Expected**: Fields named `OperationDate` and `OperationTime` contain the
  date and time of the selected operation.
- **Actual**: Both fields are derived from the Medical Device Usage Record
  event's `event_date`. The linked Operation Note is joined for surgeon data
  but its date is never selected.
- **Evidence**: Confirmed on 2026-08-26 in
  `DeviceUsageReportRepository::getReportQueryString()`. An aggregate database
  check found one sample device record, and its event date differs from its
  linked Operation Note date, so the shipped query would export the wrong
  operation date for that record.
- **Severity**: High. The generated file can send an incorrect operation date
  to a national device registry while presenting it under an authoritative
  field name.
- **Status**: CONFIRMED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d`.

## BUG-533: Link a mobile device shortcut opens an invalid address (CONFIRMED)

- **Area**: Desktop shortcuts menu and linked-device pairing.
- **Route**: The menu renders `/javascript:eSignDevicePopup();` instead of
  invoking `eSignDevicePopup()`.
- **Repro**:
  1. Sign in on the desktop as a user who can see the standard shortcuts menu.
  2. Open the shortcuts panel.
  3. Select **Link a mobile device**.
- **Expected**: A dialog headed **Link to mobile device** opens over the current
  screen and shows the pairing QR code and direct address.
- **Actual**: The browser leaves the current screen and requests the invalid
  `/javascript:eSignDevicePopup();` path, which ends on an application error.
- **Evidence**: Reproduced in a real browser on 2026-08-26. The core menu config
  supplies `javascript:eSignDevicePopup();`, but
  `protected/views/base/_menu.php` prefixes every non-empty top-level item with
  the application base path. Its submenu branch already avoids prefixing links
  containing a colon, but the top-level branch does not.
- **Severity**: Medium. The normal desktop pairing entry point is unusable. A
  user can reach the pairing content through an event's Attachments panel and
  **Import from device**, but that workaround is obscure and depends on
  Attachments being enabled for the event type.
- **Status**: CONFIRMED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d`.

## BUG-534: IVT bulk-sign selection survives filter changes and can include hidden rows (SUSPECTED)

- **Area**: IVT Prescribing Worklist bulk PIN signing.
- **Route**: `/OphTrIntravitrealinjection/IVTPrescribingWorklist/default/index`.
- **Repro**:
  1. Sign in as an IVT Prescriber on a deployment with unsigned injection
     prescriptions at more than one institution, site, or result page.
  2. Select an unsigned row.
  3. Change the Institution, Site, or Draft filter so that row is no longer
     visible, or move to another page of results.
  4. Select a visible unsigned row, choose **Sign all by PIN**, and enter a
     valid PIN.
- **Expected**: Only the unsigned rows visibly selected in the current filtered
  result are signed, or a filter/page change clears the earlier selection.
- **Actual**: The earlier id remains in browser `sessionStorage` and is included
  in the bulk request even though its row is hidden. The visible pre-submit
  check examines only checkboxes on the current page, and the server validates
  that ids exist and are unsigned but does not constrain them to the current
  filters. It can therefore sign the hidden row as well.
- **Evidence**: Code path confirmed on 2026-08-26 in
  `signing_injections.js`, `InjectionSequenceSignaturesForm`, the worklist
  controller, and `InjectionSequenceSignatureService`. This deployment has no
  signature rows, so a data-bearing runtime reproduction was not possible.
- **Severity**: High. A clinical user may apply their signature to a patient's
  injection prescription that is no longer visible in the set they believe
  they are signing.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a runtime reproduction
  with suitable non-patient sample data.

## BUG-535: Prescribed Drugs location filter does not filter by location (CONFIRMED)

- **Area**: Prescription reporting, Prescribed Drugs filter panel.
- **Route**: `/OphDrPrescription/report/prescribedDrugs`.
- **Repro**:
  1. Sign in as a user who can open reports.
  2. Open **Reports > Prescription > Prescribed drugs**.
  3. Inspect the list labelled **Dispense Condition/Location**.
  4. Try to choose a location such as Pharmacy, Ward Fridge or Home.
- **Expected**: A field labelled for both condition and location either offers
  both kinds of value or provides separate filters for them.
- **Actual**: The list contains dispense conditions only. Report generation
  applies the selected id only to `dispense_condition_id`; there is no
  `dispense_location_id` filter despite each result displaying a location.
- **Evidence**: Reproduced in a real browser on 2026-08-26. The report form
  fills the list from `OphDrPrescription_DispenseCondition`, and
  `OphDrPrescription_ReportPrescribedDrugs::run()` constrains only
  `event_medication_use.dispense_condition_id`.
- **Severity**: Medium. A pharmacy or governance user can reasonably believe a
  location was selected and treat an unexpectedly broad extract as
  location-specific.
- **Status**: CONFIRMED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d`.

## BUG-538: MDOR queue failure leaves a permanent queued request after an error (CONFIRMED)

- **Area**: Medical Device Usage Record report request and asynchronous queue
  dispatch.
- **Route**: `/TrDeviceUsageRecord/DeviceUsageReport/requestReport`.
- **Repro**:
  1. Use a deployment where the configured report queue cannot accept a job.
  2. Open **Reports > Medical Device Usage Record > MDOR extract**.
  3. Enter a valid date range and select **Request Report**.
  4. Reopen the report list after the request fails.
- **Expected**: The report request and queue dispatch succeed together, or the
  request is rolled back and the user receives a useful message.
- **Actual**: The request row is committed before the job is dispatched. A queue
  connection failure then produces an unhandled application error, while the
  saved request remains `queued` and can never complete without manual action.
- **Evidence**: Reproduced in a real browser on 2026-08-26 with a Redis
  authentication failure. `DeviceUsageReportService::request()` stores the
  report first and calls the dispatcher afterwards without a transaction or
  error-status update spanning both actions. The database contained the queued
  row immediately after the error.
- **Severity**: Medium. The user sees a failure but the list accumulates a
  misleading permanent request, and retrying creates more rows.
- **Status**: CONFIRMED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d`.

## BUG-539: MDOR generation overwrites the first protected-file record (CONFIRMED)

- **Area**: Laravel protected-file repository used by MDOR report generation.
- **Route**: A report is requested from
  `/TrDeviceUsageRecord/DeviceUsageReport/index`; completed rows download through
  `/ProtectedFile/Download/<id>`.
- **Repro**:
  1. Start with an installation that already has protected-file records.
  2. Request and process an MDOR extract.
  3. Inspect the report's `file_id` and protected-file row 1.
  4. Process a second extract and compare both report links and row 1 again.
- **Expected**: Each extract creates a new protected-file row and leaves every
  existing protected file unchanged. Each completed request keeps its own file.
- **Actual**: `ProtectedFileRepository::store()` calls `updateOrCreate([], data)`
  for a new DTO. The empty match condition selects the first row, so that row is
  overwritten instead of a new row being inserted. Every processed report then
  points to id 1, and the next report replaces the file behind earlier requests.
- **Evidence**: Reproduced while generating sample extracts on 2026-08-26. After
  two runs, both report rows held `file_id = 1`; protected-file row 1 had been
  rewritten with the name `DeviceUsageReport.csv` and the second generation
  timestamp. The repository code passes an empty attribute array to Eloquent
  `updateOrCreate()` whenever `dto->id` is null.
- **Severity**: High. Generating a registry report corrupts the metadata for an
  unrelated existing protected file, can make that original file inaccessible,
  and makes historical report links return a later extract containing different
  patient data.
- **Status**: CONFIRMED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d`.

## BUG-540: Empty unique-code pool silently leaves a cataract note without a code (SUSPECTED)

- **Area**: Operation Note cataract follow-up unique-code assignment.
- **Route**: Saving a new or edited cataract Operation note through
  `/OphTrOperationnote/default/create` or
  `/OphTrOperationnote/default/update/<event_id>`.
- **Repro**:
  1. On a non-production deployment, mark every unused unique code inactive or
     otherwise make the active unused pool empty.
  2. Save an Operation note that contains the Cataract element.
  3. Inspect the event's unique-code mapping and generate correspondence whose
     template contains `[puc]`.
- **Expected**: OpenEyes either assigns a code or prevents completion with a
  clear operational error so the follow-up reference cannot be omitted.
- **Actual**: The save path receives no code id, attempts to save an invalid
  mapping, ignores the failed save result and continues. The Operation note is
  therefore expected to save without a mapping, and `[puc]` later expands to an
  empty value.
- **Evidence**: Code path reviewed on 2026-08-26 in
  `BaseController::getActiveUnusedUniqueCode()`,
  `BaseController::createNewUniqueCodeMapping()` and
  `BaseEventTypeController::updateUniqueCode()`. The active unused pool in the
  sample database was not empty, so the destructive empty-pool condition was
  not reproduced at runtime.
- **Severity**: High. Correspondence can leave without the reference needed to
  route a post-operative examination back to the patient's cataract operation,
  with no visible failure at the point the note is saved.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled runtime
  reproduction with an empty non-production pool.

## BUG-541: Patient unique-code shortcode ignores an older coded cataract note (SUSPECTED)

- **Area**: Correspondence `[puc]` shortcode and Operation Note lookup.
- **Route**: Creating correspondence for a patient after more than one
  Operation note has been recorded.
- **Repro**:
  1. With non-production sample data, save a cataract Operation note and verify
     that it has a unique-code mapping.
  2. Save a newer non-cataract Operation note for the same patient.
  3. Create correspondence from a template containing `[puc]`.
- **Expected**: The shortcode returns the most recent applicable cataract
  Operation note's unique code, or makes the required event selection explicit.
- **Actual**: The shortcode asks for the patient's latest Operation note of any
  kind, then looks only for a mapping on that event. Because non-cataract notes
  do not receive mappings, the expected result is blank even though the earlier
  cataract note has a valid code.
- **Evidence**: Code path reviewed on 2026-08-26 in
  `PatientShortcode::replaceViaModuleApi()`,
  `OphTrOperationnote_API::getPatientUniqueCode()`,
  `OphTrOperationnote_API::getLatestEventUniqueCode()` and
  `BaseAPI::getLatestEvent()`. The sample database has only historical cataract
  fixtures without unique-code mappings, so the two-note sequence was not
  reproduced at runtime.
- **Severity**: High. A clinically valid cataract follow-up reference can
  disappear from correspondence because an unrelated later operation exists,
  preventing the returned result from being matched automatically.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled runtime
  reproduction with two mapped sample events.

## BUG-542: Visual Fields discards the Other assessment explanation (SUSPECTED)

- **Area**: Visual Fields Result element, Assessment Result.
- **Route**: Editing an imported event through
  `/OphInVisualfields/default/update/<event_id>`.
- **Repro**:
  1. On a non-production deployment with an imported Visual Fields event, open
     the event for editing.
  2. In Result, choose **Other** under **Assessment Result**.
  3. Enter an explanation in **Other - please specify**, save, then reopen the
     event.
- **Expected**: The explanation is retained and shown with the Other result.
- **Actual**: The current code is expected to discard the explanation. The form
  submits `other`, but the model's only safety rule names ` other` with a leading
  space. Yii mass assignment therefore omits the real attribute before save.
- **Evidence**: Code path reviewed on 2026-08-26 in
  `form_Element_OphInVisualfields_Result.php`,
  `Element_OphInVisualfields_Result::rules()` and
  `BaseEventTypeController::setElementAttributesFromData()`. The sample database
  has no Visual Fields events and the event cannot be created manually, so the
  save-and-reopen sequence could not be reproduced.
- **Severity**: Medium. A clinician can type a non-standard defect description
  into a visible field and receive no warning that the detail will be lost.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending reproduction with an
  imported sample event.

## BUG-543: Show instruments hides only the IOP table heading (SUSPECTED)

- **Area**: Examination, Intraocular Pressure element settings and edit form.
- **Route**: Admin Settings, then a new or editable Examination containing
  Intraocular Pressure.
- **Repro**:
  1. As an administrator, set **Show instruments** to Off in the Examination
     settings group.
  2. Open an Examination with an Intraocular Pressure reading.
  3. Compare the table heading with the reading row beneath it.
- **Expected**: The Instrument heading and instrument value cells are both
  hidden, leaving the other columns aligned.
- **Actual**: The setting guards only the `Instrument` heading. Every reading
  row still renders its hidden instrument id and visible instrument name, so
  the body has an extra cell and no matching heading.
- **Evidence**: Code reviewed on 2026-08-26 in
  `form_Element_OphCiExamination_IntraocularPressure_side.php` and
  `form_Element_OphCiExamination_IntraocularPressure_reading.php`. The setting
  was not changed on the shared running deployment, so the visual result was
  not reproduced there.
- **Severity**: Low. No clinical value is changed, but the setting does not do
  what it says and the misaligned table can make a reading harder to interpret.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending runtime confirmation.

## BUG-544: Three obsolete Examination settings remain editable (SUSPECTED)

- **Area**: Examination element settings for Visual Acuity and Intraocular
  Pressure.
- **Route**: Admin Settings, Examination group.
- **Repro**:
  1. Change **Show Notes**, **Link Instruments** or **Default number of
     readings** and save.
  2. Start a new Examination containing the corresponding element.
  3. Compare its fields and initial reading rows with the previous behaviour.
- **Expected**: An editable setting changes the behaviour named on the screen,
  or an obsolete setting is removed from the screen.
- **Actual**: No current consumer was found for any of the three values.
  **Link Instruments** is copied to a JavaScript variable that nothing reads;
  the other two are not read by the current Examination module.
- **Evidence**: Setting metadata and all current application references were
  reviewed on 2026-08-26. The metadata itself marks **Show Notes** as no longer
  used and describes **Link Instruments** as ineffective. No runtime settings
  were changed on the shared deployment.
- **Severity**: Low. Administrators can spend time testing controls that have
  no effect, but patient records are not altered.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending runtime confirmation.

## BUG-545: Cataract defaults are editable but ignored by new notes (SUSPECTED)

- **Area**: Operation Note settings and Cataract element default drawing
  positions.
- **Route**: Admin Settings, Operation Note group, then a new cataract Operation
  note.
- **Repro**:
  1. Change **Default Incision Length**, **Incision centre position left eye**,
     **Incision centre position right eye**, **Surgeon position left eye**,
     **Surgeon position right eye**, **Incision length** or **Number of ports**
     on Admin Settings.
  2. Start a cataract Operation note and select a surgeon.
  3. Inspect the starting Cataract EyeDraw and incision length.
- **Expected**: The installation or institution setting supplies the named
  default, or the obsolete row is not offered.
- **Actual**: The creation path does not read any of the values saved by Admin
  Settings. Diagram defaults come only from old per-user `SettingUser` rows for
  the selected surgeon. Incision length checks an old per-user row for the
  signed-in user, then falls back to a firm-specific Cataract Incision Length
  Default or an application configuration parameter. It never reads the
  installation or institution value stored for **Default Incision Length**.
- **Evidence**: Code reviewed on 2026-08-26 in
  `OphTrOperationnote_DefaultController::getUserSettings()`,
  `setOpNoteSettings()` and
  `Element_OphTrOperationnote_Cataract::afterConstruct()`. An application-wide
  source search found no settings-table consumer for `default_incision_length`.
  The sample database has no Cataract `SettingUser` rows, so the obsolete user
  path could not be compared at runtime.
- **Severity**: Medium. An administrator can believe they have standardised a
  surgical diagram or incision default when new notes will not use that value.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending runtime confirmation with
  controlled sample settings.

## BUG-546: Fife is marked unused but controls only one intended field (SUSPECTED)

- **Area**: System settings and Operation Note Anaesthetic, Preparation and
  Cataract elements.
- **Route**: Admin Settings, System group, then a new or saved Operation note.
- **Repro**:
  1. Set **Fife** to On.
  2. Open an Operation note containing Anaesthetic, Preparation and Cataract
     elements.
  3. Compare the fields made visible in each element.
- **Expected**: A setting described as unused is absent, or all remaining code
  paths controlled by it can resolve the same value.
- **Actual**: The metadata scopes **Fife** to the Anaesthetic element. Its
  Anaesthetic Witness field can therefore still be enabled, despite the
  metadata saying the setting is no longer used. Preparation and Cataract also
  ask for `fife`, but cannot resolve an Anaesthetic-scoped setting through their
  own element setting lookup, so their guarded fields remain hidden.
- **Evidence**: Setting metadata and the Anaesthetic, Preparation and Cataract
  edit/view templates were reviewed on 2026-08-26. The shared deployment was
  not changed to exercise a deployment-specific legacy switch.
- **Severity**: Medium. The screen and code disagree about whether the feature
  exists, and enabling it produces only part of the apparent intended form.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending controlled runtime
  confirmation.

## BUG-547: Four Core settings have no current consumer (SUSPECTED)

- **Area**: Core settings for administrative email addresses and automatic
  hospital-number allocation.
- **Route**: Admin Settings, Core group, and the local Add Patient workflow.
- **Repro**:
  1. Change **Admin Email**, **Alerts Email**, **Auto Increment Start Number**
     or **Hospital Number Auto Increment** and save.
  2. Exercise the relevant system notification or add a local patient.
  3. Compare the recipient or generated hospital number with the saved value.
- **Expected**: Each editable setting affects the behaviour described on the
  screen, or an obsolete row is removed.
- **Actual**: No current application consumer was found for these four keys.
  Local patient-number generation is now configured on Patient Identifier
  Types instead of through the two Core rows.
- **Evidence**: A full application source search and the current settings
  metadata were reviewed on 2026-08-26. The keys appear in migrations and test
  fixtures but no active runtime lookup was found. No shared deployment setting
  was changed.
- **Severity**: Medium. A deployment can believe an alert recipient or an
  identifier-allocation rule is configured when it is not being applied.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending controlled runtime
  confirmation.

## BUG-548: IVT unbooked mandatory settings have no current consumer (SUSPECTED)

- **Area**: Intravitreal Injection settings and unbooked injection validation.
- **Route**: Admin Settings, Intravitreal Injection group, then a new unbooked
  Intravitreal Injection event.
- **Repro**:
  1. Set **Injection - Unbooked - Diagnosis Mandatory** and **Injection -
     Unbooked - Follow-up Mandatory** to On.
  2. Create an unbooked injection without the corresponding value.
  3. Attempt to save the event.
- **Expected**: Saving is blocked until the enabled mandatory fields are
  completed.
- **Actual**: No current code reads either key, so the settings are expected to
  have no effect on validation.
- **Evidence**: The setting migrations and a full application source search
  were reviewed on 2026-08-26. Each key appears only in migrations and settings
  metadata. The shared deployment was not changed to run the save path.
- **Severity**: Medium. A service may rely on the settings as a data-quality
  control even though incomplete injection events remain possible.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending controlled runtime
  confirmation.

## BUG-549: Queue Set priority and completed filter switches are ignored (SUSPECTED)

- **Area**: Patient Ticketing Queue Set administration and the ticket-list
  search panel.
- **Route**: `/PatientTicketing/admin/` and `/PatientTicketing/default`.
- **Repro**:
  1. Edit a Queue Set and set **Filter Priority** and **Filter Completed
     Patients** to No.
  2. Open that Queue Set's ticket list.
  3. Inspect the search panel.
- **Expected**: The priority choices and Completed checkbox are hidden when
  their corresponding Queue Set controls are set to No.
- **Actual**: The ticket-list view always renders both controls. It consults
  the Queue Set values for the Subspecialty and Context filters, but never
  checks `filter_priority` or `filter_closed_tickets`.
- **Evidence**: Code reviewed on 2026-08-26 in
  `views/admin/form_queueset.php` and `views/default/_ticketlist_search.php`.
  The shared deployment was not changed to reproduce a configuration-only
  display defect.
- **Severity**: Low. Filtering still works, but an administrator cannot simplify
  the panel as the Queue Set form promises.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending runtime confirmation.

## BUG-550: Seeded RTT codes 21 and 99 stop clocks that should keep running (SUSPECTED)

- **Area**: Referral To Treatment clock-state catalogue and clock display.
- **Route**: `/Referral/ReferralAdmin/RTTClockStateOption/index`, then an
  Examination Clinical Outcome carrying code 21 or 99.
- **Repro**:
  1. Confirm that seeded code 21, **Transfer to another provider**, and code
     99, **Not yet known**, both have **Clock running** set to No.
  2. Record either option on a referral whose clock is running.
  3. Reopen the encounter after several days and inspect the week count.
- **Expected**: Code 21 remains a subsequent activity during an RTT period, and
  code 99 is treated like a subsequent activity until it is corrected, so the
  accumulated wait continues.
- **Actual**: Both seeded options set `clock_running` to false. The display
  calculator therefore freezes the accumulated days at the recorded state.
- **Evidence**: The seeded database rows, `RTTDisplayClockCalculator` and the
  June 2026 NHS Data Dictionary definition of Referral To Treatment Period
  Status were compared on 2026-08-26. The database contains 19 active options;
  only codes 10, 11, 12 and the two code 20 variants are marked as running.
- **Severity**: High. Selecting either nationally continuing status can
  understate the patient's wait and leave the visible clock stopped.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled saved-event
  reproduction.

## BUG-551: RTT Start and Restart options carry the previous wait forward (SUSPECTED)

- **Area**: Referral To Treatment state recording from Examination Clinical
  Outcome.
- **Route**: `/OphCiExamination/default/create` or
  `/OphCiExamination/default/update/{event_id}` with the RTT clock enabled.
- **Repro**:
  1. Open a referral with an existing accumulated RTT wait.
  2. Record seeded code 11, **Active monitoring end - new pathway**, or code
     12, **Consultant referral - new condition**.
  3. Save and inspect the new clock state and displayed week count.
- **Expected**: A status which begins a new RTT period starts with the elapsed
  days appropriate to that new period, normally zero at its start.
- **Actual**: `RTTClockStateFormModel::toDTO()` always copies the days
  accumulated on the referral's latest state. It does not inspect the selected
  option or reset the total for codes 11 or 12, so the new period inherits the
  previous period's wait.
- **Evidence**: The form model, state service, seeded option catalogue and June
  2026 NHS Data Dictionary definitions were compared on 2026-08-26. No shared
  deployment data was changed to create a new RTT period.
- **Severity**: High. A genuinely new RTT period can begin already carrying the
  completed pathway's wait, making the displayed duration misleading.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled saved-event
  reproduction.

## BUG-552: Allergy category and severity order is ignored by the clinical picker (SUSPECTED)

- **Area**: Examination Allergies and Intolerances configuration and clinical
  entry picker.
- **Route**: `/OphCiExamination/admin/AllergyCategory/index`,
  `/OphCiExamination/admin/AllergySeverity/index` and an Examination event that
  includes Allergies and Intolerances.
- **Repro**:
  1. Change the display order of the allergy categories or severities.
  2. Open an Examination and use the Allergies and Intolerances add dialog.
  3. Compare the Category and Severity columns with the saved admin order.
- **Expected**: The clinical picker follows the display order maintained on the
  corresponding administration screen.
- **Actual**: `Allergies::getViewData()` loads categories with an unordered
  `findAll()` and severities with `active()->findAll()`, also without an order.
  The current database demonstrates the mismatch: severity display order is
  Fatal through Mild, while the same active-table query without an order returns
  Mild through Fatal. Saved allergy summaries separately sort present entries by
  severity display order, so the order has an effect after recording but not
  while choosing a severity.
- **Evidence**: The two admin controllers, category and severity models,
  Allergies widget and element sorting code were compared with the live lookup
  tables on 2026-08-26. No patient record or administration value was changed.
- **Severity**: Medium. A safety-related configuration control is silently
  ignored at the point where clinicians choose a value, and the picker can use
  the reverse of the administrator's intended severity sequence.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled browser
  reproduction after changing the order.

## BUG-553: IOL Master log opens but cannot load data for an institution administrator (SUSPECTED)

- **Area**: Biometry IOL Master Import Log Viewer access control.
- **Route**: `/DicomLogViewer/list` and `/DicomLogViewer/search`.
- **Repro**:
  1. Sign in with `OprnInstitutionAdmin` but without the installation-level
     `admin` role.
  2. Open **Admin > Biometry > IOL Master Import Log Viewer**.
  3. Select **Search** to load the import rows.
- **Expected**: A role allowed to open the log viewer can load its data, or the
  route is not offered to that role.
- **Actual**: `accessRules()` allows `OprnInstitutionAdmin` for `list` only. The
  page renders an initially empty table and its Search button calls `search`,
  which falls through to the later installation-admin-only rule. The data AJAX
  request is therefore forbidden even though the screen itself opens.
- **Evidence**: `DicomLogViewerController::accessRules()`, `actionList()`,
  `actionSearch()` and `protected/views/dicomlogviewer/index.php` were compared
  on 2026-08-26. No role was changed to reproduce the write-free access path.
- **Severity**: Medium. The intended operational role reaches a diagnostic page
  that appears empty and cannot retrieve the evidence needed to investigate an
  import failure.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a minimal-role browser
  reproduction.

## BUG-554: IOL Master log silently stops at 200 files (SUSPECTED)

- **Area**: Biometry IOL Master Import Log Viewer result paging.
- **Route**: `/DicomLogViewer/list` and `/DicomLogViewer/search`.
- **Repro**:
  1. Use a database containing more than 200 DICOM file records.
  2. Open the import log and search without a restrictive filter.
  3. Try to move beyond the first 200 matching files.
- **Expected**: The full matching history can be paged or the screen says that
  the result has been limited.
- **Actual**: `getDicomFiles()` applies `items_per_page = 200` and an offset, but
  `getData()` calculates the total by counting that already limited query. The
  JSON response contains only `data.items`, and the code which renders pagination
  sits after `Yii::app()->end()`. The screen therefore exposes no next page and
  gives no indication that older matches were omitted.
- **Evidence**: Controller and view code were compared with the read-only DICOM
  tables on 2026-08-26. The current demonstration data has 176 file rows, so a
  larger-data browser reproduction is still required.
- **Severity**: Medium. An administrator investigating an older import can
  conclude that no log exists when it is merely beyond an undisclosed cap.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a database with more than
  200 DICOM file records.

## BUG-555: Deactivating a lens type also removes every institution assignment (SUSPECTED)

- **Area**: Biometry Lens Types bulk action.
- **Route**: `/OphInBiometry/lensTypeAdmin/list` and
  `/OphInBiometry/lensTypeAdmin/delete`.
- **Repro**:
  1. Assign one lens type to two institutions.
  2. Select it on **Admin > Biometry > Lens Types** and choose **Deactivate Lens
     Type**.
  3. Edit the row, make it active again, and inspect its institution assignments.
- **Expected**: Deactivation changes availability while preserving the scope
  needed if the same lens is later reactivated.
- **Actual**: `actionDelete()` calls `deleteMappings(LEVEL_INSTITUTION)` before
  `delete()`. For this soft-delete model, `delete()` sets `active = 0`, while the
  first call deletes every institution mapping. Reactivation therefore does not
  restore where the lens was available. Unticking **Active** on the edit form
  does not have this extra effect, so the two ways to deactivate behave
  differently.
- **Evidence**: Lens Type controller, model, mapped-reference-data trait and
  list form were compared with the read-only lens and mapping tables on
  2026-08-26. No mapping was changed.
- **Severity**: Medium. A maintenance action presented as deactivation silently
  discards configuration for all institutions and creates avoidable work or a
  missing lens when the model is returned to service.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled browser
  reproduction.

## BUG-556: IOL Master Reprocess button calls a function the current page never loads (SUSPECTED)

- **Area**: Biometry IOL Master Import Log Viewer reprocessing action.
- **Route**: `/DicomLogViewer/list` after loading rows with
  `/DicomLogViewer/search`.
- **Repro**:
  1. Sign in with the installation-level `admin` role and load the IOL Master
     import rows.
  2. Select **More** on a row.
  3. Select **Reprocess file**.
- **Expected**: The browser posts the filename to `/DicomLogViewer/reprocess` and
  reports that reprocessing was scheduled.
- **Actual**: The current `index.php` builds rows and the More dialog from
  Mustache templates. Its button calls `reprocessFile()`, but that function is
  defined only in the legacy `_list_row.php` partial. `actionSearch()` returns
  JSON and ends the request before the old partial-rendering lines, so the
  function is never added to the current page and the button is predicted to
  raise a JavaScript reference error.
- **Evidence**: Controller, current index template and legacy row partial were
  traced on 2026-08-26. No import was requeued because doing so would change the
  running integration state.
- **Severity**: Medium. The only recovery action offered by the log viewer does
  nothing, leaving an administrator to intervene in the queue outside the
  documented interface.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a non-production browser
  reproduction.

## BUG-560: Institution Admin can manage installation-wide shared mailboxes through a hidden route (SUSPECTED)

- **Area**: Internal Messaging shared mailbox administration and institution
  isolation.
- **Route**: `/OphCoMessaging/SharedMailboxSettings` and
  `/OphCoMessaging/SharedMailboxSettings/edit?id={id}`.
- **Repro**:
  1. Sign in with `OprnInstitutionAdmin` but without the installation-level
     `admin` role.
  2. Confirm **Admin > Message** does not show **Shared mailboxes**.
  3. Enter `/OphCoMessaging/SharedMailboxSettings` directly and inspect the list
     and Add/Edit controls.
- **Expected**: The menu and controller enforce the same role. If Institution
  Admin is intended to manage mailboxes, the data and list are scoped to that
  administrator's institution.
- **Actual**: The menu entry is restricted to `admin`, but
  `SharedMailboxSettingsController` inherits `BaseAdminController::accessRules()`,
  which permits `OprnInstitutionAdmin`. The controller adds no narrower check,
  lists every non-personal mailbox, and permits saving its user and team
  assignments. The `mailbox` table has no institution column, so the resulting
  administration is installation-wide.
- **Evidence**: The Messaging menu configuration, controller inheritance,
  `BaseAdminController` access rule, list criteria, save path and read-only
  mailbox schema were compared on 2026-08-26. The current demonstration database
  has no shared mailbox row, so no record was opened or changed.
- **Severity**: High. A role intended to administer one institution can reach a
  hidden route which is capable of creating or changing shared inbox access for
  the whole installation.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a minimal-role browser
  reproduction.

## BUG-561: Request Queue shows an editable success counter but ignores changes (CONFIRMED)

- **Area**: Payload Processor API Request Queue administration.
- **Route**: `/Api/Request/admin/requestQueue/edit?id={queue}`.
- **Repro**:
  1. Sign in with the installation-level `admin` role and open an existing
     Request Queue.
  2. Change **Total Success Count** and select **Save**.
  3. Reopen the queue and compare the stored counter.
- **Expected**: A value presented as an editable text field is saved, or a
  worker-owned counter is displayed read-only.
- **Actual**: The form accepts the changed number and returns to the queue list,
  but the displayed counter keeps its original value. No validation or warning
  explains that the change was ignored.
- **Evidence**: On 2026-08-26, a live application walk changed **Total Success
  Count** on an inactive sample queue from 1359 to 1360. After Save, the list
  still showed 1359. The original value therefore remained in place and no
  cleanup change was required.
- **Severity**: Low. The misleading fields waste administrator time and make a
  queue's counters appear manually repairable when the tested field is not, but the
  worker remains the normal owner of all counters.
- **Status**: CONFIRMED on the current develop deployment on 2026-08-26.

## BUG-562: Payload Processor request queue override is never applied (SUSPECTED)

- **Area**: Payload Processor API request intake and queue selection.
- **Route**: `/Api/Request/queue/add` and the equivalent manual-upload route.
- **Repro**:
  1. Configure a request type whose default queue is `queue-a`, with a second
     valid queue named `queue-b`.
  2. Submit a test request for that type while supplying
     `request_override_default_queue=queue-b` as request data.
  3. Inspect the saved request and the `execute_request_queue` on its first
     request routine.
- **Expected**: The request records the valid override and its routine is queued
  on `queue-b`, or the unused override field is removed so the data model does
  not advertise a capability the receive path lacks.
- **Actual**: `BaseRequestHandler::addQueryString()` assigns only the request
  type and system message to the Request model. Other query values are stored
  as attachment data. `RequestSaveHandler::enqueue()` then unconditionally uses
  the request type's `default_request_queue`; it never reads
  `request_override_default_queue`. No other application path writes the field.
- **Evidence**: The request controller, base handler, save handler, Request
  model, queue administration controller and schema were traced on 2026-08-26.
  No live request was submitted because that would enqueue integration work.
- **Severity**: Medium. An integration that relies on the apparent per-request
  override is silently routed to the default worker queue, which can mix
  workloads or defeat an intended priority lane.
- **Status**: SUSPECTED on application revision
  `9d6f524ac23b826db3c58c00596471127828989d` pending a controlled request on a
  non-production worker.

## BUG-563: Attachment Type ignores its attachment-enabled field (CONFIRMED)

- **Area**: Payload Processor API Attachment Type administration and event
  attachment availability.
- **Route**: `/Api/Request/admin/attachmentType/add` and
  `/Api/Request/admin/attachmentType/edit?id={type}`.
- **Repro**:
  1. Sign in with the installation-level `admin` role and open an Attachment
     Type for editing.
  2. Change **Is Attachments Enabled** from `0` to `1`, or from `1` to `0`, and
     select **Save**.
  3. Reopen the row and inspect the stored value.
- **Expected**: The flag changes, or the worker-owned field is not offered as an
  editable input on this screen.
- **Actual**: The form accepts the changed number and reports no validation
  error, but reopening the row shows the original number.
- **Evidence**: On 2026-08-26, a live application walk changed **Is Attachments
  Enabled** from 0 to 1 on a disabled sample attachment type and selected Save.
  Reopening the same row showed 0. The original value therefore remained in
  place and no cleanup change was required.
- **Severity**: Medium. An administrator can believe a file category was
  enabled or disabled when clinical event attachment availability did not
  change.
- **Status**: CONFIRMED on the current develop deployment on 2026-08-26.

## BUG-564: Editing an Attachment Type opens the MIME Type list (CONFIRMED)

- **Area**: Payload Processor API Attachment Type administration navigation.
- **Route**: `/Api/Request/admin/attachmentType/edit?id={type}`.
- **Repro**:
  1. Sign in with the installation-level `admin` role and edit an Attachment
     Type.
  2. Select **Save** with valid values.
  3. Observe the screen shown after the successful save.
- **Expected**: OpenEyes returns to the Attachment Type list so the saved row can
  be checked in context.
- **Actual**: OpenEyes opens the neighbouring MIME Type screen instead of the
  Attachment Type list.
- **Evidence**: On 2026-08-26, a live application walk opened an existing
  attachment type and selected Save. The browser opened the MIME Type list.
- **Severity**: Low. Data is saved, but the unexpected context switch makes it
  look as though the administrator changed the wrong list.
- **Status**: CONFIRMED on the current develop deployment on 2026-08-26.

## BUG-565: Payload request viewers expose raw confidential data (CONFIRMED)

- **Area**: Payload Processor API request inspection and manual upload history.
- **Route**: `/Api/Request/admin/default/manualupload` and
  `/Api/Request/admin/request/index`.
- **Repro**:
  1. Sign in with the installation-level `admin` role and open either request
     list.
  2. Select **Show attachments** on a request which contains request headers or
     a clinical payload.
  3. Inspect the expanded attachment table.
- **Expected**: Secrets and patient data are redacted, summarised, or placed
  behind a separate privileged reveal action with an explicit warning.
- **Actual**: The expanded table can render raw attachment text directly on the
  page, including request headers, reusable authentication material, and
  patient-shaped clinical data.
- **Evidence**: A live application walk on 2026-08-26 expanded one existing
  sample request. The evidence was reviewed in place and was not copied into the
  documentation or this ledger.
- **Severity**: High. A support user can accidentally disclose credentials or
  confidential clinical data in screenshots, tickets, or copied diagnostics.
- **Status**: CONFIRMED on the current develop deployment on 2026-08-26.

## BUG-566: PASAPI remap forms accept blank data and lose institution (CONFIRMED)

- **Area**: PASAPI Value Remaps administration.
- **Route**: `/PASAPI/admin/default/viewXpathRemaps`,
  `/PASAPI/admin/default/createXpathRemap` and
  `/PASAPI/admin/default/createRemapValue/{id}`.
- **Repro**:
  1. Sign in with the installation-level `admin` role and select **Add New**.
  2. Leave the remap form blank and select **Create**.
  3. Create another disposable remap with an XPath, a name, and an institution.
  4. Return to the institution-scoped remap list, then open the disposable
     remap's value page and submit a blank value pair.
- **Expected**: XPath, name, institution, input, and mapped value are validated
  as required where the screen depends on them. A valid remap remains visible
  for its selected institution.
- **Actual**: A blank remap reports that it was added. A named remap also reports
  success but does not appear in the list because the selected institution is
  not retained. Its value form accepts a blank input and output pair.
- **Evidence**: A live application walk on 2026-08-26 created only disposable
  sample rows, reproduced all three symptoms, and removed the rows through the
  application. Returning to the remap list confirmed that no disposable row was
  visible.
- **Severity**: High. An administrator can be told a mapping was created even
  though it is unreachable from the institution list and cannot be relied on by
  the intended integration.
- **Status**: CONFIRMED on the current develop deployment on 2026-08-26.

## BUG-567: Assessment value lists display a stray backtick (CONFIRMED)

- **Area**: Generic Event Assessment reference-data administration.
- **Route**: `/OphGeneric/admin/Assessment/viewAssessmentAdditionalValue` and
  `/OphGeneric/admin/Assessment/viewAssessmentChangeValue`.
- **Repro**:
  1. Sign in with the installation-level `admin` role.
  2. Open **Assessment Additional Value** or **Assessment Change Value**.
  3. Inspect the start of the main page content.
- **Expected**: The page starts with the list heading and controls.
- **Actual**: A literal backtick is rendered immediately before the list.
- **Evidence**: The character was visible on both screens during a live
  application walk on 2026-08-26.
- **Severity**: Low. The defect is cosmetic but makes the administration page
  look unfinished.
- **Status**: CONFIRMED on the current develop deployment on 2026-08-26.

## BUG-568: Enabled Generic Event subtype did not appear in Add Event (SUSPECTED)

- **Area**: Generic Event subtype administration and the clinical Add Event
  dialog.
- **Route**: `/OphGeneric/admin/Default/editEventSubType` and a patient summary's
  **Add Event** dialog.
- **Repro**:
  1. Sign in with the installation-level `admin` role and open an existing
     Generic Event subtype.
  2. Select **Enable manual creation** and save.
  3. Open a sample patient, open **Add Event**, and look for that subtype.
  4. Return to the subtype and restore its original setting.
- **Expected**: A subtype enabled for manual creation is offered from the Add
  Event workflow, or the administration screen explains any other prerequisite.
- **Actual**: The checkbox persisted, but the enabled sample subtype was not
  present in the freshly loaded Add Event dialog. The screen gave no indication
  of another prerequisite.
- **Evidence**: A reversible live application walk on 2026-08-26 enabled the
  existing Visual Fields subtype, reloaded a patient summary, and inspected the
  Add Event choices. The checkbox was then restored to its original off state
  and rechecked.
- **Severity**: Medium. The administration screen can imply that a subtype is
  available to clinicians when it remains absent from the workflow.
- **Status**: SUSPECTED on the current develop deployment on 2026-08-26 pending
  repetition on a deployment where the Generic Event clinical module is known
  to be enabled.

## BUG-569: Direct Mirth logs route fails when its database is not configured (CONFIRMED)

- **Area**: Mirth Connect Logs administration.
- **Route**: `/Mirth/admin/list`.
- **Repro**:
  1. Use a deployment with no Mirth database connection configured.
  2. Sign in with the installation-level `admin` role.
  3. Confirm that **Admin > System** does not offer **Mirth Connect Logs**.
  4. Open `/Mirth/admin/list` directly.
- **Expected**: The route explains that Mirth logging is not configured, redirects
  to a safe administration page, or returns a normal not-found response.
- **Actual**: The page fails before the search screen renders and exposes an
  unhandled `CDbConnection.connectionString cannot be empty` exception.
- **Evidence**: A live application walk on 2026-08-26 checked the expanded System
  menu and the direct route. The debug bar was disabled and was not used.
- **Severity**: Low. The menu correctly hides the unavailable feature, but a saved
  direct link produces an internal exception page rather than a useful boundary.
- **Status**: CONFIRMED on the current develop deployment on 2026-08-26.

## BUG-570: Legacy medication addresses expose developer exceptions (CONFIRMED)

- **Area**: Legacy medication routes.
- **Route**: `/medication/form` and `/medication/stop`.
- **Repro**:
  1. Sign in and open `/medication/form` directly.
  2. Return to a normal page, then open `/medication/stop` directly.
- **Expected**: Each address redirects to the current medication workflow, returns a
  normal not-found response, or explains that the old route is unavailable.
- **Actual**: The form address exposes **Your request is invalid** on a developer
  exception page. The stop address exposes **Patient with PK '' not found** on a
  developer exception page. Neither address renders medication controls.
- **Evidence**: Both addresses were walked separately in the current application on
  2026-08-26. A current Examination event was also opened and visibly showed Eye
  Medications, Systemic Medications, and Stopped Medications. The debug bar was
  disabled and was not used.
- **Severity**: Low. Normal users have no reason to use these addresses, but old links
  and automated route inventories can expose internal exception pages.
- **Status**: CONFIRMED on the current develop deployment on 2026-08-26.

The next available id is BUG-571.
