# OpenEyes clinical bug swarm - wave 002 verified bugs

- Target: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Comparison: `origin/master` at `ad2324084788608246a8250e817198c2f26a4fd6`.
- Browser verification: clean sessions with different existing patients.

### OEBUG-0001: Patient Summary crashes before any clinical record is shown (critical, crash) [R1+R2]

- Verified against: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Preconditions: Any existing patient that the logged-in clinician can normally open.
- Expected: Patient Summary renders demographics, clinical alerts, diagnoses,
  episodes, and the Add Event control.
- Actual: The request returns HTTP 500 and shows an Error page before any patient
  summary or event control is available.
- Predicate: HTTP status is 500, the visible first heading is `Error`, and the
  page body contains `Unknown named parameter $unable_to_check_allergies`.
- Distinctness key: `Patient Summary | open existing patient | normal patient record | HTTP 500 before summary | Patient model attributes passed to incompatible PatientDTO constructor`.

> 1. Log in normally and use 'Find Patient' to select any existing patient.
> 2. Open the patient's summary.
> 3. Observe that an Error page replaces the Patient Summary.

- R1: pass by agent 08, clean browser, a different existing patient, HTTP 500 and
  the same named-parameter mapper failure.
- R2: pass by agent 11, clean browser, patient varied again, HTTP 500 with the
  visible `Error` heading.
- Additional check: the primary agent reproduced the same predicate on three
  further existing patients from different identifier ranges.
- Code note: `protected/modules/Diagnoses/widgets/PatientSummary.php:134` maps the
  Patient model through `protected/dto/mappers/ActiveRecordDTOMapper.php:63` into
  `OEShared\DTOs\PatientDTO`; the model supplies an attribute that the DTO
  constructor does not accept.

### OEBUG-0002: Editing existing clinical events crashes during permission checks (critical, crash) [R1+R2]

- Verified against: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Preconditions: An existing clinical event that the logged-in clinician is
  normally allowed to edit.
- Expected: The module edit form opens with the saved clinical content.
- Actual: The request returns HTTP 500 before the form renders.
- Predicate: HTTP status is 500, the visible first heading is `Error`, and the
  page body contains `Unknown named parameter $version`.
- Distinctness key: `Existing event | open edit form | editable event | HTTP 500 before form | Event attributes passed to incompatible EventDTO constructor`.

> 1. Log in normally and open an existing editable clinical event.
> 2. Choose the event's Edit action.
> 3. Observe that an Error page replaces the edit form.

- R1: pass in a clean browser with an existing Examination event.
- R2: pass in a separate clean browser with an existing Correspondence event for
  a different patient.
- Code note: the permission resolver maps the loaded `Event` through
  `protected/dto/mappers/EventMapper.php` into
  `OEShared\\DTOs\\EventDTO`. `GetsDTOAttributes.php` passes every Event model
  attribute, including `version`, while the DTO constructor has no `version`
  parameter. `ActiveRecordDTOMapper.php:63` then fails during named-argument
  construction.

### OEBUG-0003: Allergy administration reports success while a row failed to save (medium, persistence) [R1+R2]

- Verified against: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Preconditions: On the Examination Allergies administration screen, one row is
  invalid and a different row contains a valid change.
- Expected: The save is reported as failed, with the invalid row identified; the
  screen must not present the operation as successful.
- Actual: The valid row is persisted while the invalid row is rejected, and the
  reloaded screen simultaneously shows `Error saving allergy: Name cannot be
  blank.` and `Allergies updated`.
- Predicate: Both contradictory banners are visible after one save, while a
  database read confirms that the valid row changed and the invalid row did not.
- Distinctness key: `Examination admin Allergies | save mixed valid and invalid rows | one row invalid | error and success shown together | flash state set per row without transaction`.

> 1. Open Admin, Examination, Allergies.
> 2. Make one row invalid by clearing its required Name.
> 3. Make a valid change to a different row, such as changing its Active state.
> 4. Select Save.
> 5. Observe that the page reports both an error and `Allergies updated` even
>    though only part of the submitted screen was saved.

- R1: pass in a clean browser using one valid allergy row; the mixed result was
  confirmed in the database.
- R2: pass in a separate clean browser using a different valid allergy row; the
  same two banners appeared and the second mixed result was confirmed in the
  database.
- Cleanup: the two temporary Active-state changes used for replay were restored
  through the same screen and confirmed in the database.
- Code note: `AllergiesController::actionUpdate()` loops through rows without a
  transaction and calls `setFlash('success', ...)` or `setFlash('error', ...)`
  independently for each row. A later success therefore coexists with an earlier
  failure, and the controller redirects after the partial write.

### OEBUG-0004: Driving-status names look editable but are silently discarded (medium, persistence) [R1+R2]

- Verified against: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Preconditions: Access to Admin, Examination, Driving Advice - Status.
- Expected: Changing a status Name and selecting Save persists the new label.
- Actual: The screen reloads with the original label, with no error or warning.
- Predicate: The submitted replacement label disappears and a database read
  confirms that the original `name` value remains unchanged.
- Distinctness key: `Examination admin Driving Advice Status | rename status | existing row | original name silently returns | wrong unindexed form attribute ignored by controller`.

> 1. Open Admin, Examination, Driving Advice - Status.
> 2. Change the Name shown for any existing status.
> 3. Select Save.
> 4. Observe that the original Name returns with no error message.

- R1: pass in a clean browser using the first status row; the database retained
  the original name.
- R2: pass in a separate clean browser using a different status row and a
  different replacement label; the database again retained the original name.
- Code note: every row uses the same unindexed field name
  `SocialHistoryDrivingStatus[driving_status_name]`, but the model attribute is
  `name`. `DrivingSafetyController::actionEditDrivingSafetyStatus()` reads the
  status Active flags and driving-standard assignments, but never reads this
  submitted name.
