# OpenEyes clinical bug swarm - wave 005 candidates

- Target: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Comparison: `origin/master` at `ad2324084788608246a8250e817198c2f26a4fd6`.
- Method: version-matched read-only review by Luna threads 20 through 30.
- Status: every candidate is unverified and counts as zero verified bugs.
- Closure: frontend testing stopped at the user's request. These candidates must
  not be replayed unless the user explicitly authorises a future run.

### CAND-0016: Closing a disabled-manual-entry warning may leave a Biometry worklist step started

- Preconditions: Manual Biometry entry is disabled, no new device report exists,
  and the clinician starts the related worklist step.
- Expected: Closing the warning cancels or reverts the in-progress step before
  returning to the previous screen.
- Predicted actual: The title-bar close control navigates back without sending the
  worklist cancellation action, so the step can remain started with no event.
- Predicate: The worklist still shows the step as started after the warning is
  closed and the page is reloaded.
- Distinctness key: `Biometry | close manual-entry warning | worklist step started | step remains started | cancellation class only on OK action`.
- Code note: `protected/modules/OphInBiometry/assets/js/module.js:83-104`.

> 1. Disable manual Biometry entry and ensure there is no new device report.
> 2. Start the Biometry worklist step.
> 3. Close the warning with its title-bar close control.
> 4. Reload the worklist and inspect the step state.

### CAND-0017: Examination pathway checkout may use the session patient instead of the event patient

- Preconditions: An Examination is linked to a worklist patient, while the
  current session has no worklist patient or is resolved to a different one.
- Expected: Completing the Clinic Outcome checks out the pathway linked to the
  event being saved.
- Predicted actual: Checkout is skipped or targets the session's current worklist
  patient because the event fallback was removed.
- Predicate: The event patient's pathway remains open, or a different current
  pathway is checked out.
- Distinctness key: `Examination Clinic Outcome | complete pathway | event and session worklist patients differ | wrong pathway state | event fallback removed`.
- Code note: `protected/modules/OphCiExamination/controllers/traits/HandleAutoPathwayCheckout.php:90-104`.

> 1. Open an Examination linked to a worklist patient.
> 2. Establish a session with no current worklist patient or a different one.
> 3. Choose the complete-pathway Clinic Outcome and save.
> 4. Compare the event patient's pathway state with the session pathway state.

### CAND-0018: Nine Positions measurement-only mode may submit invalid movement rows

- Preconditions: A saved Nine Positions reading contains ocular-movement values.
- Expected: Switching to Measurements and saving preserves the existing movement
  data and saves successfully.
- Predicted actual: The toggle disables the movement selects, so browsers omit
  required `movement_id` values while still submitting the existing row IDs.
- Predicate: Save is rejected for missing movement data, or the existing movement
  data is lost.
- Distinctness key: `Examination Nine Positions | save Measurements mode | saved movement rows exist | validation failure or movement loss | required disabled selects omitted from POST`.
- Code note: `protected/modules/OphCiExamination/widgets/js/NinePositions.js:609`.

> 1. Open an Examination containing a saved Nine Positions reading with ocular
>    movement values.
> 2. Select Measurements.
> 3. Save the Examination.
> 4. Reopen it and compare the movement values, or inspect any validation error.

### CAND-0019: Nine Positions Ocular Movements mode leaves measurement controls enabled

- Preconditions: A Nine Positions reading is open for editing.
- Expected: Choosing Ocular Movements focuses the form on movement fields and
  suppresses measurement-only controls.
- Predicted actual: Measurement controls remain visible and enabled because the
  toggle only disables movement selects in the opposite mode.
- Predicate: Measurement inputs remain editable after Ocular Movements is chosen.
- Distinctness key: `Examination Nine Positions | choose Ocular Movements | edit reading | measurement controls remain enabled | one-sided toggle logic`.
- Code note: `protected/modules/OphCiExamination/widgets/js/NinePositions.js:600`.
- Confidence: low. The intended combined-mode behavior needs product confirmation.

> 1. Open a Nine Positions reading in an Examination.
> 2. Select Ocular Movements.
> 3. Inspect whether the measurement inputs remain visible and editable.

### CAND-0020: Removing every Clinic Outcome row may bypass required-outcome validation

- Preconditions: An existing Examination has a saved Clinic Outcome or follow-up
  row and no injection follow-up scheduling that satisfies the same rule.
- Expected: Removing every outcome row blocks save with the required-outcome
  validation message.
- Predicted actual: Validation checks the loaded persisted relation before the
  submitted deletion is applied, so save can proceed with no outcome.
- Predicate: The Examination saves and reopens with no Clinic Outcome entry.
- Distinctness key: `Examination Clinic Outcome | remove all rows and save | existing outcome loaded | event saves without required outcome | validator reads persisted relation`.
- Code note: `protected/modules/OphCiExamination/controllers/DefaultController.php:4383`.

> 1. Edit an Examination that already has a Clinic Outcome or follow-up row.
> 2. Remove every outcome row.
> 3. Save the Examination.
> 4. Reopen it and check whether an outcome remains or validation blocked save.

### CAND-0021: Editing signed intravitreal treatment content may leave the old signature valid

- Preconditions: Injection prescribing is enabled and an active treatment
  sequence already has a signature.
- Expected: Changing signed treatment content invalidates or refreshes the
  signature and requires re-signing.
- Predicted actual: The communication field remains editable, while save has no
  signature invalidation path and view mode continues to display the old
  signature.
- Predicate: Edited treatment content is displayed with the pre-edit signature
  still shown as valid.
- Distinctness key: `Examination IVT | edit signed active treatment | signature exists | old signature remains valid | no invalidation on content change`.
- Code note: `protected/modules/OphCiExamination/controllers/DefaultController.php:1936`.

> 1. Open an active signed intravitreal treatment sequence.
> 2. Change Doctor and Injector Communication.
> 3. Save, then view or print the event.
> 4. Compare the edited content with the signature state.

## Refuted snapshot-only findings

The following were not retained as candidates after the primary agent checked the
complete target checkout or live asset state:

- SortableJS is present at runtime and the tested Allergies screen created a
  working Sortable instance without a JavaScript error.
- Yii's `endClip()` method takes no argument, so a no-argument call is valid.
- CVI alert, RTT, OEScape image, and electronic-signature classes and assets exist
  in the full checkout. Their apparent absence was caused by the deliberately
  narrow local snapshot.
