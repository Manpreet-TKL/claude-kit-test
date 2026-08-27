# Static sweep findings - full detail (2026-07-29)

Companion to `oe-develop-bug-hunt-2026-07-29.md`. All findings are UNVERIFIED code-level hypotheses from parallel readers over develop @ 04c938c0a4; none were exercised in a browser. Sorted by reader confidence.

## S-01: Pathway step_started/step_completed events never dispatched after event save (int vs string always-false compare) (high confidence)

Module: core-event-create - `protected/behaviors/WorklistBehavior.php:285`

dispatchEventAfterPathStepUpdate takes `string $expected_step_status` but every caller passes the int constants PathwayStep::STEP_STARTED/STEP_COMPLETED (ints 1/2, coerced to the strings "1"/"2" by the type hint in coercive mode). The guard then does `(int) $applicable_pathway_step->status === $expected_step_status`, i.e. int === string, which is ALWAYS false in PHP. So the 'step_started'/'step_completed' system events are never dispatched from any updatePathwayStep call - which is the path used by BaseEventTypeController::actionCreate/actionUpdate/updateEventStep (lines 1107, 1296, 1355, 3541, 3546) and OphTrOperationnote. Sibling code at WorklistBehavior.php:244 shows the correct pattern `(int) $expected_step_status === (int) PathwayStep::STEP_STARTED`. git log -L confirms this is a regression from the OE-16213 (#11020) refactor: the old inline code compared `(int)$status === PathwayStep::STEP_COMPLETED` (int===int). Downstream listeners that silently never fire: EventStepObserver::createEvent (sets event_create_url state on new_event steps) and OphCiExamination/OphDrPGDPSD PathstepObserver::createOrUpdateEvent (auto-creates the exam event for the next started step). WorklistController.php:384-386 dispatches these events directly, which is why worklist-driven step clicks still work and masks the bug.

Predicted predicate: After saving an event that completes a pathway step whose next requested step is a hold/new-event step, the next step's observer side effects never happen: the started hold step shows no event-create link state and a PSD/exam step that should auto-create its event does not, while the same step started from the worklist grid works.

```
private function dispatchEventAfterPathStepUpdate(PathwayStep $applicable_pathway_step, string $expected_step_status): void
{
    $applicable_pathway_step->refresh();
    if ((int) $applicable_pathway_step->status === $expected_step_status) {
        if (!is_null($this->stepStatusToDispatchEventMap($expected_step_status))) {
            Yii::app()->event->dispatch(
```

## S-02: Mandatory RTT setting silently disables all Clinic Outcome validation when the RTT widget is absent (high confidence)

**NOT REACHED in browser replay 2026-07-29** - precondition absent on a stock sample database, so this is neither confirmed nor refuted. `enable_rtt_clock_bar` and `mandatory_rtt_clock_state_completion` both default to 0 in `setting_metadata`, with no override row at any scope (installation, institution, site, firm, subspecialty, institution-subspecialty), so `#rtt-clock-app` never renders and the early-return path is never taken. Turn both settings on before retrying. Note also that the element's on-screen name is 'Clinical Outcome', not 'Clinic Outcome'.

Module: OphCiExamination - `protected/modules/OphCiExamination/controllers/DefaultController.php:4338`

OE-17910/OE-18275 rebuilt Clinic Outcome validation around the RTT clock. validateClinicOutcomeEntries early-returns when RTT is enabled AND mandatory, on the theory that the RTT/DNA outcome is enforced instead via RTTClockStateFormModel (the unit test DefaultControllerClinicOutcomeTest documents exactly this intent). But that enforcement only runs when the RTTClockState sub-array is present in POST: setAndValidateClinicOutcomeFromData (line 2979) gates setAndValidateRTTFromData on `$rtt_data` being truthy, and the hidden inputs that produce $rtt_data are rendered by RTTClock_event_edit.php only when the widget renders at all and adder_enabled is true. RTTClockDisplayResolver::resolveForEdit returns null (widget hidden, nothing posted) when the patient has no referral, when the referral has no clock state yet, or - the most common route - when the event was opened outside a worklist context (WorklistBehavior::getCurrentWorklistPatientId reads session worklist ids; without one, resolveReferralId returns null). It also renders no hidden inputs on a tip event whose latest clock state belongs to a different event (adder_enabled false). In all those cases $rtt_data is null, so the RTT form model is never validated ('RTT State cannot be blank.' never fires) AND validateClinicOutcomeEntries returns early - so neither entries nor an RTT outcome is required and a completely empty Clinic Outcome element saves without any error. Before this change 'Entries cannot be blank.' would have fired.

Predicted predicate: With enable_rtt_clock_bar=1 and mandatory_rtt_clock_state_completion=1, saving an Examination whose Clinic Outcome element has no entries (patient without a referral, or event created outside a worklist so no RTT clock is shown) produces zero .errorMessage elements and the event saves, showing an empty Clinic Outcome element on the event view.

```
if ($rtt_enabled && $rtt_data) {
    $errors = $this->setAndValidateRTTFromData(
        $rtt_data,
        $errors,
        Element_OphCiExamination_ClinicOutcome::model()->getElementTypeName()
    );
}
...
private function validateClinicOutcomeEntries($data, $errors, $element, $rtt_data, bool $rtt_enabled): array
{
    if ($rtt_enabled && $this->isRTTClockStateMandatory()) {
        return $errors;
    }
```

## S-03: Add-taper clones the dose input but never syncs the user-typed value (high confidence)

Module: OphDrPrescription - `protected/modules/OphDrPrescription/assets/js/defaultprescription.js:106`

The .js-add-taper handler builds the new taper row by cloning the item row's dose text input, rewriting only its name/id. jQuery .clone()/cloneNode copies the value ATTRIBUTE (the server-rendered default dose), not the value the user typed into the field. The handler proves the sync is intended: for frequency and duration it explicitly calls frequency_input.val(row.find('td.prescriptionItemFrequencyId select').val()) and duration_input.val(...) after cloning, because select clones also lose their selection - but no equivalent dose_input.val(row.find('td.prescriptionItemDose input').val()) exists. Result: a clinician who edits the dose (e.g. changes default '1' to '7') and then clicks the taper button gets a taper row pre-filled with the stale default dose (or empty if the drug has no default), silently prescribing the wrong taper dose unless they notice and re-type it.

Predicted predicate: After typing 7 into a drug row's dose input and clicking the row's taper button, the new taper row's dose input does NOT contain 7 (it shows the drug's original default dose or is empty), while the frequency and duration selections DO carry over.

```
const dose_input = row
    .find("td.prescriptionItemDose input")
    .first()
    .clone();
dose_input.attr("name", dose_input.attr("name").replace(/\[dose\]/, "[taper][" + taper_key + "][dose]"));
...
frequency_input.val(
    row.find("td.prescriptionItemFrequencyId select").val(),
);
...
duration_input.val(row.find("td.prescriptionItemDurationId select").val());
```

## S-04: actionRouteOptions null-deref when route is reset to '-- Select --', leaving stale laterality dropdown (high confidence)

Module: OphDrPrescription - `protected/modules/OphDrPrescription/controllers/DefaultController.php:396`

The route dropdown in each item row is rendered with array('empty' => '-- Select --', 'class' => 'drugRoute', ...) (form_Element_OphDrPrescription_Details_Item.php line 121), and defaultprescription.js lines 27-48 fire GET /OphDrPrescription/Default/RouteOptions with route_id=selected.val() on EVERY change of select.drugRoute, including a change to the empty option (value ''). actionRouteOptions does $route = MedicationRoute::model()->findByPk($route_id); if ($route->has_laterality) with no null check - findByPk('') returns null, so PHP 8 raises 'Attempt to read property on null' and Yii returns a 500. The jQuery success callback never runs, so options_td keeps its previous content: if the user had an eye route selected (laterality dropdown shown) and switches back to '-- Select --', the Eye laterality dropdown remains visible and its value is still POSTed for an item with no route.

Predicted predicate: On a drug row whose Route is set to an eye route (laterality select visible in td.route_option_cell), changing Route back to '-- Select --' leaves the laterality dropdown in place instead of replacing the cell with '-' (the RouteOptions AJAX request returns HTTP 500).

```
public function actionRouteOptions($key, $route_id)
{
    $route = MedicationRoute::model()->findByPk($route_id);
    if ($route->has_laterality) {
```

## S-05: actionGetDispenseLocation null-deref: Dispense Location dropdown left stale when condition has no locations mapped (high confidence)

Module: OphDrPrescription - `protected/modules/OphDrPrescription/controllers/PrescriptionCommonController.php:145`

actionGetDispenseLocation builds a CDbCriteria with compare('dispense_location_institutions.institution_id', $institution_id) and then iterates $dispense_condition->dispense_location_institutions without checking find() for null. When the selected dispense condition has no OphDrPrescription_DispenseCondition_Institution row for the current institution, or its mapping has zero dispense locations for that institution (the join condition then matches no rows), find() returns null and the foreach raises 'Attempt to read property on null' -> HTTP 500. The jQuery success callback in getDispenseLocation (defaultprescription.js lines 523-541) never runs, so the .dispenseLocation select silently keeps the PREVIOUS condition's locations - the user can save a condition/location pair that do not belong together. The model itself demonstrates the required guard: OphDrPrescription_DispenseCondition::getLocationsForCurrentInstitution() wraps the same relation access in isset($dc_institution->dispense_location_institutions).

Predicted predicate: After changing a drug row's Dispense Condition to a condition with no dispense locations mapped for the logged-in institution, the Dispense Location dropdown still shows the previous condition's location options (the GetDispenseLocation AJAX call returns HTTP 500) instead of being emptied and hidden.

```
$dispense_condition = OphDrPrescription_DispenseCondition_Institution::model()->find($criteria);
foreach ($dispense_condition->dispense_location_institutions as $location_institution) {
    echo '<option value="' . $location_institution->dispense_location->id . '">' ...
```

## S-06: Taper dose validation class tests $item->dose instead of $taper->dose (copy-paste) (high confidence)

Module: OphDrPrescription - `protected/modules/OphDrPrescription/views/default/form_Element_OphDrPrescription_Details_Item.php:204`

The taper-row dose input decides whether to attach the client-side 'input-validate numbers-only decimal' classes with the condition ($taper->dose === null || is_numeric($taper->dose) || $item->dose === '') - the third clause was copy-pasted from the item version at line 82 (if ($item->dose === null || is_numeric($item->dose) || $item->dose === '')) and should read $taper->dose === ''. Consequence on the PHP-rendered taper rows (update page and validation-failure re-render): a taper whose dose is the empty string on an item with a non-empty free-text dose escapes the numbers-only keystroke filtering, and conversely a free-text taper dose on an item whose dose was cleared to '' wrongly gets numeric-only filtering, blocking legitimate free-text edits. This is a literal cross-field copy-paste between the item block and the taper block of the same view.

Predicted predicate: On the update form of a prescription whose item dose is free text (e.g. 'Two drops') and whose saved taper dose is empty, the taper dose input is missing the 'numbers-only' and 'decimal' classes (alphabetic input is not filtered), although its own empty dose should have triggered them exactly as it does on the item input.

```
line 82:  if ($item->dose === null || is_numeric($item->dose) || $item->dose === '') {
line 204: if ($taper->dose === null || is_numeric($taper->dose) || $item->dose === '') {
```

## S-07: actionPrintCopy prints hardcoded examination event 3686356 (leftover debug code) (high confidence)

Module: OphDrPrescription - `protected/modules/OphDrPrescription/controllers/DefaultController.php:551`

actionPrintCopy($id) prints the requested prescription and then unconditionally fetches the OphCiExamination module API and calls printEvent(3686356) with a hardcoded event id. 'printCopy' is registered in $action_types as ACTION_TYPE_PRINT, so the route /OphDrPrescription/default/printCopy?id=<any prescription event> is live for any user with print rights. On any deployment where event 3686356 does not exist (i.e. everywhere except whatever database this was debugged against) the printEvent call errors and the request 500s after emitting the prescription; where an event with that id DOES exist, the endpoint appends an unrelated - potentially different patient's - examination print to the output, a data leak.

Predicted predicate: Requesting /OphDrPrescription/default/printCopy?id=<valid prescription event id> produces a PHP error/500 (event 3686356 not found) instead of a printable copy of the prescription; on a database where event id 3686356 exists, the response instead contains another patient's examination print output.

```
public function actionPrintCopy($id)
{
    $this->actionPrint($id);

    $eventid = 3686356;
    $api = Yii::app()->moduleAPI->get('OphCiExamination');
    $api->printEvent($eventid);
}
```

## S-08: Warnings 'Confirm' button dead: wrong `this` in click handler blocks saving (high confidence)

Module: core - `protected/assets/js/OpenEyes.EventDraftController.js:121`

The confirm-popup click handler is a plain function, so inside it `this` is the clicked <button>, not the controller. `this.options` is undefined and the first line throws TypeError before the warnings dialog is built. When an autosave response contains warnings ('There are edits to the patient record more recent than this draft'), requireConfirmBeforeSave() hides the real submit button (.js-event-action-save-confirm, which has form=<form_id>) and shows this popup button (type='button', no form attribute), whose only handler is the broken one - so the event can no longer be saved at all. No other code binds .js-event-action-save-confirm-popup (verified by grep). Bug present since the feature landed (46225f11e9, 2023); OE-16555 reformatted the line but kept `function (event)`.

Predicted predicate: After autosave returns warnings, the footer shows a 'Confirm' button whose click opens no 'Confirm event save' dialog (no .oe-popup-content containing 'This event has the following warnings' appears) and never submits the form; console shows TypeError reading 'autoSaveWarningListSelector'.

```
$(this.options.confirmSavePopupButtonSelector).on('click', function (event) {
    let $warningList = $(this.options.autoSaveWarningListSelector);
    $warningList.empty();

    for (warning of this.warnings) {
```

## S-09: Update view missing connection-error 'Confirm & Save' button targeted by JS (high confidence)

Module: OphCiExamination - `protected/modules/OphCiExamination/views/default/update.php:50`

create.php and step.php both render an EventAction button with class js-event-action-connection-error-save-confirm ('Confirm & Save', faded, hidden), which showConnectionErrorUI() in OpenEyes.EventDraftController.js reveals while hiding the real .js-event-action-save-confirm. update.php omits that button entirely (its event_actions jump from 'save' straight to the 'confirm' popup button). On an update/edit page, any saveDraft failure (network error, or HTTP 404 for a stale draft_id) therefore removes every save button from the event actions: js-event-action-save-confirm is hidden and $(connectionErrorConfirmSaveButtonSelector).show() matches nothing. The user is left with only the connection-error Cancel button (that one IS supplied by BaseEventTypeController::actionUpdate, line 1382).

Predicted predicate: On an examination update page during a draft-save failure, the OE Connection Error tab is shown and no 'Confirm & Save' button (normal or faded) exists anywhere in the event actions, whereas the same failure on a create page still shows a faded 'Confirm & Save'.

```
update.php event_actions: EventAction::button('Confirm & Save','save',...,'class' => 'js-event-action-save-confirm') is followed directly by the 'confirm' popup button; the block present in create.php lines 62-71 (EventAction::button('Confirm & Save','connection-error-save',...,['class' => 'js-event-action-connection-error-save-confirm fade','style' => 'display: none'])) is absent.
```

## S-10: actionDeleteDrafts lacks 'event_id IS NULL' filter - wipes update restore points (high confidence)

Module: core - `protected/controllers/BaseEventTypeController.php:1606`

The existing-draft banner is populated from getExistingEventDraftsForCreate() (line 828), whose criteria includes 't.event_id IS NULL' - creation drafts only. But actionDeleteDrafts, invoked when the user clicks 'No (delete draft)' on that banner (JS comment: 'Delete the existing drafts for event creation'), builds its criteria WITHOUT the event_id IS NULL condition, so it deletes every EventDraft of that event type for that patient/user - including drafts attached to existing events (update restore points created by autosave during an abandoned edit, which actionUpdate silently restores via $this->draft = $this->event->draft, line 878). Declining an unrelated create draft silently destroys the user's unsaved edits to another examination event.

Predicted predicate: After abandoning an edit of examination event E (autosaved restore point exists) and then clicking 'No (delete draft)' on the create-page banner for the same patient, reopening update?id=E no longer restores the unsaved edits (the marker text typed before abandoning is gone).

```
$criteria->condition = 't.event_type_id = :event_type AND episode.patient_id = :patient AND t.last_modified_user_id = :user';
// vs getExistingEventDraftsForCreate (line 828):
$criteria->condition = 't.event_type_id = :event_type AND episode.patient_id = :patient AND t.last_modified_user_id = :user AND t.event_id IS NULL';
```

## S-11: Sidebar event icon/quicklook stays 'Requires scheduling' forever after operation is scheduled (high confidence)

Module: core / OphTrOperationbooking - `protected/components/EventListDisplayDetailsRepository.php:46`

OE-18118 moved event-list icons and quicklook issue text from live computation into the persisted event_list_display_details table. The staleness check in getEventListDisplayDetailsByIds() only compares t.last_modified_date against `event` plus five joined tables (document_output, patientticketing_ticket, et_ophciexamination_injectionmanagement_v2, et_ophdrprescription_details, ophdrprescription_signature). It has NO join/condition for et_ophtroperationbooking_operation or event_issue - yet EventListDisplayDetailsHelper::addOphTrOperationbookingDetailsToEventListDisplayDetails() derives the persisted icon class ('alert') and text ('Operation Requires scheduling') from $operation->status->name, and buildEventListDisplayStringsForEvent() persists $event->hasIssue()/getIssueText() from event_issue rows. Element_OphTrOperationbooking_Operation::schedule() (lines 1189-1310) saves the element, booking, session and episode and calls $this->event->deleteIssues() - it never saves the `event` row, so event.last_modified_date does not advance. Result: the persisted row is considered fresh forever, and the sidebar keeps showing the pre-scheduling alert state for ALL users indefinitely (same for cancel/reschedule transitions). This is a regression versus pre-refactor behaviour where status was computed live on each cache miss. The per-patient HTML fragment cache in _single_episode_sidebar.php compounds it (its dependency SQL also only watches event/event_draft).

Predicted predicate: After scheduling an operation booking, the patient sidebar entry for that event still shows the 'alert' icon and quicklook issue text 'Operation Requires scheduling' instead of reflecting the Scheduled status, for every user, until something else modifies the event row itself.

```
$criteria->join = 'INNER JOIN event ON event.id = t.event_id'
    . ' LEFT JOIN document_instance di ON di.correspondence_event_id = t.event_id'
    ...
    . ' LEFT JOIN ophdrprescription_signature sig ON sig.element_id = pesign.id';
$criteria->addInCondition('t.event_id', $event_ids);
$criteria->addCondition('t.last_modified_date >= event.last_modified_date');
// no join/condition on et_ophtroperationbooking_operation or event_issue

// Element_OphTrOperationbooking_Operation::schedule():
$this->setStatus('Scheduled', false); ... $this->save();  // element row only
$this->event->deleteIssues();  // event_issue rows only - event.last_modified_date never bumped
```

## S-12: Per-patient shared sidebar HTML cache never invalidates on the status changes the details table tracks (high confidence)

Module: core - `protected/views/patient/_single_episode_sidebar.php:112`

OE-18149 changed the sidebar fragment cache key from per-user to per-patient ('_single_episode_sidebar_patient:{id}display_deleted:{mode}'). Its CDbCacheDependency SQL is MAX(last_modified_date) over `event` UNION `event_draft` for the patient only. But the cached fragment embeds the rendered icon/quicklook strings, whose source statuses legitimately change WITHOUT any event/event_draft row changing: correspondence email output (document_output), ticketing, prescription signatures - exactly the tables the EventListDisplayDetailsRepository staleness check watches. So even when the repository correctly rebuilds a fresh details row (e.g. email goes Pending -> Complete), the shared cached HTML is still served stale to every user until some event/draft row for that patient is modified. Pre-refactor the key was per-user, so at worst a single user saw stale HTML; now the first viewer's fragment is pinned for the whole institution. Manifests only when a real cache backend is configured (CFileCache/memcache), which is the production default.

Predicted predicate: After a correspondence email for an event transitions from Pending to Complete (document_output status change with no event-row change), the patient sidebar quicklook still reads 'Pending' with the pending icon for all users, while re-opening the event itself shows the letter as sent.

```
$sidebar_cache_key = "_single_episode_sidebar_patient:" . $this->patient->id . "display_deleted:" . $display_deleted_in;
...
'sql' => 'SELECT MAX(date) FROM (
            SELECT MAX(ev.last_modified_date) AS date FROM `event` ev ... WHERE ep.patient_id = ...
        UNION
            SELECT MAX(ed.last_modified_date) AS date FROM `event_draft` ed ... ) AS cache_dates'
```

## S-13: Blanket $('#event-content').off('change') in VisualAcuity.js kills element-dirty marking and other delegated change handlers (high confidence)

**REFUTED by browser replay 2026-07-29** - the dirty marker survives in practice. `create.php:128` registers VisualAcuity.js at POS_HEAD from the content view, which Yii renders before the layout, so its blanket `off('change')` runs BEFORE `events_and_episodes.js` (registered from the layout head) binds its delegate. Observed: on a Glaucoma Examination create form with Visual Acuity present, typing into History and then removing that element still raised the close warning 'Are you sure that you wish to close the History element? All data in this element will be lost', which is gated on `element_dirty === "1"`. Poor hygiene and fragile to any registration-order change, but not currently causing data loss.

Module: examination-element-js - `protected/modules/OphCiExamination/assets/js/VisualAcuity.js:159`

Line 159 runs a BLANKET .off('change') on #event-content (no selector/namespace), removing ALL delegated change handlers, before rebinding only the VA .va-selector handler. Collateral removals: the global element_dirty marker (protected/assets/js/events_and_episodes.js:51-57 $('#event-content').on('change','select:not(.dirty-check-ignore), input..., textarea...', markElementDirty)), module.js:917 (postop op-note select) and module.js:994 (diagnosis-selection -> InjectionManagementComplex check), and every PCRCalculation.js mapExaminationToPcr binding. This is live in practice because the VA widget edit view embeds the script tag directly (protected/modules/OphCiExamination/widgets/views/VisualAcuity_event_edit.php:13 <script src=...VisualAcuity.js>), so the file executes a second time in the body; its $(document).ready callback then runs AFTER events_and_episodes.js/module.js (which are AssetManager-flushed in afterRender) have bound their handlers - i.e. the off() fires last on any examination form where VA is open at load. It also re-executes every time VA is added via the sidebar/Manage-elements popup or swapped (jQuery 1.8.3 executes script tags in AJAX-inserted HTML). Consequence: edited elements are never marked dirty, so (a) with element_close_warning_enabled='on', trashing a filled element shows no 'data will be lost' confirm (events_and_episodes.js:219-222 reads element_dirty), and (b) with close_incomplete_exam_elements='on', ExaminationSaveHandler.verifyElements ($('input[name*="element_dirty"][value="1"]')) treats user-filled elements as empty and the 'discard empty elements' save dialog silently removes their data. Introduced by commit 8b94510e11 (OE-14524) where a targeted .off('change','...va-selector') was added on the very next line - the blanket call is a copy-paste overreach.

Predicted predicate: On an examination edit form that contains the Visual Acuity element, changing a select/input/textarea in another open element leaves that element's hidden input[name^='element_dirty'] at value 0 (so its trash icon removes the filled element without any confirmation, and with close_incomplete_exam_elements on, save lists the filled element in the 'discard empty elements' dialog).

```
$('#event-content').off('change')
    .off('change', '.OEModule_OphCiExamination_models_Element_OphCiExamination_VisualAcuity .va-selector')
    .on('change', '.OEModule_OphCiExamination_models_Element_OphCiExamination_VisualAcuity .va-selector', function () {
      updateCviAlertState($(this).closest('section'));
    });
```

## S-14: Cancelling the trash-confirm desyncs Manage-elements popup; re-clicking the entry inserts a duplicate element section (high confidence)

Module: examination-element-js - `protected/assets/js/OpenEyes.UI.ManageElements.js:58`

ManageElements binds its own unconditional handler on every .js-remove-element click (lines 58-60) which immediately un-highlights the popup entry via removeClass('added') (lines 251-255). The ACTUAL removal, however, is gated behind a confirm dialog in events_and_episodes.js:215-240: when element_close_warning_enabled==='on' and element_dirty==='1' (the server-rendered default for EVERY pre-existing element on an update page, element_container_form.php:81-83), removeElement only runs on 'ok'. Clicking Cancel leaves the element open while the popup now shows it as not added. Clicking that popup entry then runs addSelectedElement -> addElementItem (lines 163-173), which unconditionally calls addElement($item.clone(true),...) - and nested_elements.js addElement has NO duplicate guard (it just inserts the fetched section by display order) - so a second identical element section is inserted, with both sections posting the same field names on save.

Predicted predicate: On an examination update page (element_close_warning_enabled on), after clicking an element's trash icon and CANCELLING the confirm, the Manage-elements popup entry for that still-open element has lost its 'added' highlight, and clicking the entry inserts a second identical section of the same element.

```
self.$elementContainer.on('click', '.js-remove-element', function (e) {
    self.removeElement(e.target);
});
...
ManageElements.prototype.removeElement = function ($item) {
    let $elementTypeClass = $($item).parents("section").data('elementTypeClass');
    let element = this.getElementTypeClass($elementTypeClass);
    element.removeClass('added');
}
// events_and_episodes.js:229-236 - removeElement($parent) only inside dialog.on('ok', ...)
```

## S-15: Laser Procedure: right pulse-duration 'from' validated against LEFT eye's 'to' (high confidence)

Module: OphTrLaser - `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php:87`

The rule ['right_pulse_duration_from', 'fromRangeValidation', 'toRangeAttribute' => 'left_pulse_duration_to'] compares the RIGHT eye's pulse-duration From against the LEFT eye's pulse-duration To. fromRangeValidation (line 220) adds an error whenever right_pulse_duration_from > left_pulse_duration_to and both are set. So a both-eyes Laser event with two individually valid ranges (e.g. left 5-10 ms, right 100-200 ms; both inside the numerical 5-1100 bound) is blocked from saving with a nonsensical cross-eye error. The block was introduced whole in OE-15947 (7de44b2955) and the unit test sided_numerical_range_test_provider only covers laser_power, never pulse_duration, so it was never caught. Fields are reachable whenever the Site element's selected laser has measure_in_mj=0 (module.js un-hides/enables [data-measure-in-mj-field="0"] rows).

Predicted predicate: Saving a both-eyes Laser Procedure with left pulse duration 5-10 and right pulse duration 100-200 shows an .errorMessage 'Right Pulse Duration From has to be lower than Left Pulse Duration To' and the event does not save

```
['right_pulse_duration_from', 'fromRangeValidation', 'toRangeAttribute' => 'left_pulse_duration_to'],
['right_pulse_duration_from', 'fromRangeValidation', 'toRangeAttribute' => 'right_pulse_duration_from'],
```

## S-16: Laser Procedure: right pulse-duration 'from' rule compares the field to itself (dead rule) (high confidence)

Module: OphTrLaser - `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php:88`

['right_pulse_duration_from', 'fromRangeValidation', 'toRangeAttribute' => 'right_pulse_duration_from'] compares right_pulse_duration_from against itself; $this->$attribute > $this->$attribute is never true, so the intended right-eye From<=To from-side check never runs. left_pulse_duration_from has no fromRangeValidation rule at all either. The from-side error for an inverted pulse-duration range is therefore never produced on either eye (only the toRangeValidation rules at lines 91-92 catch it, attaching a single error to the To field), unlike laser power where an inverted range produces errors on both fields (rules 85-86 + 89-90).

Predicted predicate: Saving a right-eye-only Laser Procedure with pulse duration From=200, To=100 produces only one .errorMessage ('Right Pulse Duration To has to be higher than Right Pulse Duration From') and no 'has to be lower than' error on the From field, whereas the same inversion on Laser Energy/Power produces two errors

```
['right_pulse_duration_from', 'fromRangeValidation', 'toRangeAttribute' => 'right_pulse_duration_from'],
```

## S-17: Laser Procedure: right_laser_power_from mislabeled 'To', producing a self-referential error (high confidence)

Module: OphTrLaser - `protected/modules/OphTrLaser/models/Element_OphTrLaser_Procedure.php:153`

attributeLabels() maps 'right_laser_power_from' => 'Right Laser Energy/Power To' (copy-paste of the 'to' label). fromRangeValidation builds its message from getAttributeLabel($attribute) and getAttributeLabel($params['toRangeAttribute']), so an inverted right-eye laser power range renders 'Right Laser Energy/Power To has to be lower than Right Laser Energy/Power To' - a self-referential, uncorrectable message. The matching toRangeValidation error reads 'Right Laser Energy/Power To has to be higher than Right Laser Energy/Power To'. Laser power fields are enabled by default (measure_in_mj=1 lasers), so this needs no special laser configuration.

Predicted predicate: Saving a right-eye Laser Procedure with Laser Energy From=600 and To=400 shows the .errorMessage 'Right Laser Energy/Power To has to be lower than Right Laser Energy/Power To' (attribute compared with itself in the message text)

```
'right_laser_power_from' => 'Right Laser Energy/Power To',
'right_laser_power_to' => 'Right Laser Energy/Power To',
```

## S-18: Both-eyes procedure verification is dead: JS reads input name Procedures[] but widget renders Procedures_procs[] (high confidence)

Module: OphTrOperationnote - `protected/modules/OphTrOperationnote/assets/js/module.js:329`

The eye_id change handler for the ProcedureList element builds the verifyprocedure AJAX query from $('input[name="Procedures[]"]'), but the ProcedureSelection widget (identifier 'procs') renders its hidden inputs as name='Procedures_procs[]' (protected/widgets/views/ProcedureSelection.php line 98 server-side and line 298 for JS-added rows; grep shows nothing anywhere renders plain Procedures[]). So procs stays empty, the if(procs.length>0) branch is skipped, and the else branch silently accepts 'Both eyes'. The entire guard - the /OphTrOperationnote/default/verifyprocedure call, the 'requires a specific eye selection' alert, and the radio revert to the previous eye - never runs. Server-side there is no equivalent guard either (Element_OphTrOperationnote_ProcedureList rules are only 'eye_id, procedures required'), so a user can add Phacoemulsification under Right, click Both, and save an op note recording a cataract extraction on 'Both eyes', which the code explicitly intends to block. The saved Cataract element then calls afterSave shredElementEyedraws with eye id 3, and getSelectedEyeForEyedraw silently maps Both to Right for the eyedraw.

Predicted predicate: With Phacoemulsification already in the procedure list, clicking the 'Both' eye radio produces no warning dialog and Both stays selected (expected: alert 'The following procedure requires a specific eye selection...' and revert to the previous eye)

```
$('input[name="Procedures[]"]').map(function () {
    if (procs.length > 0) {
        procs += "&";
    }
    procs += "proc" + i + "=" + $(this).val();
    i += 1;
});

if (procs.length > 0) {
```

## S-19: loadElementByProcedure echoes 'must-select-eye' then continues into foreach with a null element - PHP fatal on every guard hit (high confidence)

Module: OphTrOperationnote - `protected/modules/OphTrOperationnote/controllers/DefaultController.php:517`

In actionLoadElementByProcedure (plain-create branch, lines 507-527), the eye guard runs inside array_map: when eye is not Left/Right it does `echo 'must-select-eye'; return;` - returning null INTO the mapped array instead of out of the action. Execution then reaches `foreach ($processed_elements as $i => $element)` at line 530 which dereferences the null ($element->elementType at 533, then renderElement -> $element->getDefaultView() in BaseEventTypeController.php:2232-2234 is a 'call to a member function on null' fatal Error). Every legitimate hit of the eye guard - adding a Cataract/Buckle/Vitrectomy/PreserFlo procedure while Both or no eye is selected (the JS sends eye=3 or eye=undefined from the checked radio, module.js:70-99) - therefore produces a PHP fatal after partial output. Depending on output buffering this turns the response into a 500, so the jQuery success callback never fires and the user gets neither the 'must select eye' alert nor the new element: a total silent failure of the add-procedure action.

Predicted predicate: GET /OphTrOperationnote/Default/loadElementByProcedure?procedure_id=<phaco_id>&eye=3&patient_id=P returns a PHP error page / HTTP 500 (or 'must-select-eye' followed by error output) instead of the bare string 'must-select-eye'

```
if ($element instanceof Element_OnDemandEye && $element->requires_eye) {
    $eye_id = $this->getApp()->request->getParam('eye');
    if (!in_array($eye_id, array(Eye::LEFT, Eye::RIGHT))) {
        echo 'must-select-eye';
        return;
    }
...
}, $procedureSpecificElements);
...
foreach ($processed_elements as $i => $element) {
...
    $element_class = $element->elementType->class_name;
```

## S-20: must-select-eye cleanup targets selectors that do not exist (.procedureItem, #procedureList, unmatched regex) - procedure stays listed without its element (high confidence)

Module: OphTrOperationnote - `protected/modules/OphTrOperationnote/assets/js/module.js:103`

When the loadElementByProcedure response matches 'must-select-eye', the handler tries to remove the just-added procedure row and warn the user. All three DOM references are wrong for the create form: (1) $('.procedureItem') matches nothing - the edit-mode ProcedureSelection widget renders rows as <tr class='item'> ('procedureItem' exists only in the readonly/minimal widget variants); (2) the RegExp '<input type="hidden" value="..." name="Procedures' cannot match the actual markup, which is <input class='js-procedure' type='hidden' value='...' name='Procedures_procs[]' (attribute order and quoting differ); (3) $('#procedureList') should be #procedureList_procs. Net effect: even when the alert is shown, the eye-specific procedure remains in the procedure list with no corresponding element, and the op note can then be saved recording e.g. Phacoemulsification with no Cataract element at all (saveComplexAttributes_..._ProcedureList persists $data['Procedures_procs']). Data is silently dropped between what the user sees listed and the clinical elements captured.

Predicted predicate: After adding an eye-specific procedure with 'Both' (or no eye) selected, the procedure row remains visible in #procedureList_procs and no Cataract element section is added to the form

```
const $procedureItem = $(".procedureItem");
$procedureItem.map(function (e) {
    const r = new RegExp(
        '<input type="hidden" value="' +
            procedure_id +
            '" name="Procedures',
    );
    if ($(this).html().match(r)) {
        $(this).remove();
    }
});
if ($procedureItem.length === 0) {
    $("#procedureList").hide();
}
```

## S-21: procedure_requires_eye() omits Element_OphTrOperationnote_PreserFloMicroShunt - verifyprocedure contradicts loadElementByProcedure (high confidence)

Module: OphTrOperationnote - `protected/modules/OphTrOperationnote/controllers/DefaultController.php:705`

procedure_requires_eye() hardcodes only Cataract, Buckle and Vitrectomy element classes, but Element_OphTrOperationnote_PreserFloMicroShunt also extends Element_OnDemandEye (models/Element_OphTrOperationnote_PreserFloMicroShunt.php:45) and inherits requires_eye = true without overriding it. So actionVerifyprocedure (line 663) answers 'yes' (safe for Both eyes) for a procedure mapped to the PreserFlo element, while actionLoadElementByProcedure's runtime guard (line 514, keyed on the very same requires_eye flag) refuses the same procedure with 'must-select-eye' when eye is not Left/Right. The two halves of the eye-requirement contract disagree: if the Both-eyes JS check is ever fixed (candidate 1), PreserFlo procedures would still slip through verification and then hit the broken must-select-eye path when the element loads. The correct implementation would test the element class's requires_eye property (or instanceof Element_OnDemandEye) instead of a stale hardcoded list.

Predicted predicate: GET /OphTrOperationnote/default/verifyprocedure?name=<PreserFlo MicroShunt procedure term> prints 'yes' while GET /OphTrOperationnote/Default/loadElementByProcedure?procedure_id=<same_proc>&eye=3&patient_id=P responds with must-select-eye/error

```
if (in_array($element_type->class_name, array('Element_OphTrOperationnote_Cataract', 'Element_OphTrOperationnote_Buckle', 'Element_OphTrOperationnote_Vitrectomy'))) {
    return true;
}
```

## S-22: SyntaxError in update-template popup script kills 'Update template' button on Schedule page (high confidence)

Module: OphTrOperationbooking - `protected/modules/OphTrOperationbooking/views/booking/schedule.php:206`

The second inline <script> block (rendered when the event was created from a template whose data was modified, i.e. template=UPDATE_OR_CREATE and $template set) is a corrupted copy of the working block in views/default/view.php lines 236-250. The .forEach( call parenthesis is never closed and a stray '}' follows, so the whole script block is a guaranteed JS SyntaxError and never executes. The click handler for the 'Update template' button (.js-open-update-opbooking-template-popup, rendered at line 82) is therefore never attached, and the update popup can never be opened from the Schedule Operation page. Reachability is proven: DefaultController.php:497 sets successUri='booking/schedule/' when schedule_now is posted (the #et_save_and_schedule button sets hidden input schedule_now, module.js ~line 97), and BaseEventTypeController.php:1072 redirects to successUri.$event->id.'?template='.$template_status where OphTrOperationbooking_Template.php:131 returns EventTemplate::UPDATE_OR_CREATE when template-sourced data changed. The first script block (save-template popup, lines 142-158) parses fine, so only the update path is dead. view.php holds the intact version, proving the intent.

Predicted predicate: On /OphTrOperationbooking/booking/schedule/<event_id>?template=UPDATE_OR_CREATE, clicking the 'Update template' button does nothing: .js-update-opbooking-template-popup keeps style display:none, and the console shows Uncaught SyntaxError (missing ) after argument list) from the inline script.

```
                ).forEach(function (e) {
                    e.addEventListener(
                        'click',
                        function () {
                            document.querySelector('.js-update-opbooking-template-popup').style.display = 'none';
                        }
                    );
                }
                    }
            if (['interactive', 'complete'].includes(document.readyState)) {
```

## S-23: Theatre diary admission-time errors never highlight rows: #oprow_ prefix vs unprefixed row ids (high confidence)

Module: OphTrOperationbooking - `protected/modules/OphTrOperationbooking/assets/js/TheatreDiaryController.js:630`

saveSession's success handler looks up per-operation error rows via $("#oprow_" + operation_id) (lines 630 and 638) and the admit-time input via input[name="admitTime_<id>"] to select/focus it. But _booking_table_row.php line 37 renders rows as <tr id="<?=$booking->element_id ?>" ...> with NO oprow_ prefix, and TheatreDiaryController.php actionSaveSession keys the JSON error map by that same bare element id ($errors[(int)$m[1]] = $formErrors['admission_time'][0]). So the intended branch (red row highlight + focus the offending time input + friendly message) is unreachable; every admission-time validation error falls into the nonOpErrs branch and is shown as 'Please check the following errors:<ul><li><raw numeric element id>: <message></li></ul>' - leaking an internal DB id to the user and leaving the bad row unmarked. Admission-time errors are genuinely producible: OphTrOperationbooking_Operation_Booking rules include a match pattern and lessThanSessionEndTimeValidate ('Please enter a valid admission time in the 24-hour clock format') for times past session end. git log -S traces the oprow_ selector to OE-9386 (#5238); the row template has never carried the prefix.

Predicted predicate: In Theatre Diary edit mode, entering an invalid admission time (e.g. past the session end) and clicking Update session shows a generic error dialog 'Please check the following errors:' listing a raw numeric id, while the booking row is never highlighted red and the time input is not focused.

```
if (!$("#oprow_" + operation_id).length) {
    nonOpErrs += "<li>" + operation_id + ": " + errors[operation_id] + "</li>";
} else {
    $("#oprow_" + operation_id).attr("style", "background-color: #f00;");
...
_booking_table_row.php:37: <tr id="<?=$booking->element_id ?>" data-test="theatre-diary-row" ...>
```

## S-24: Cross-element [proc_id] duplicate check silently blocks adding extra procedures on id collision (high confidence)

Module: consent-create - `protected/modules/OphTrConsent/views/default/procedure_selection.php:64`

procedure_selection.php is a shared partial rendered twice on the consent form: once for the Procedures element (rows named Element_OphTrConsent_Procedure[procedure_assignments][i][proc_id]) and once for the Extra procedures element (Element_OphTrConsent_ExtraProcedures[extra_procedure_assignments][i][proc_id]). Neither caller overrides $proc_hidden_input_identifier (default at line 5: 'name$="[proc_id]"'), so the adder's duplicate guard at line 64 matches hidden inputs DOCUMENT-WIDE across both elements. procedure.id and ophtrconsent_procedure_extra.id are independent auto-increment tables, so ids collide routinely (both start at 1). If a core procedure with id N is already listed, selecting an extra procedure whose extra-table id is N (or vice versa) hits the guard and returns: no row is appended, no benefits/complications fetch fires, and no message is shown - the add silently does nothing.

Predicted predicate: With a procedure already listed in the Procedures element, confirming an extra procedure whose ophtrconsent_procedure_extra.id equals that procedure's procedure.id adds no row to #js-extra-proc-entries and shows no error or feedback.

```
$proc_hidden_input_identifier = $proc_hidden_input_identifier ?? 'name$="[proc_id]"';
...
if ($(`input[<?= $proc_hidden_input_identifier ?>][value=${proc.id}]`).length && proc.id !== -1) {
    return;
}
```

## S-25: Undefined patientContactLimit in Contacts.js disables per-patient contact-type limit in Add-new-contact dialog (high confidence)

Module: consent-create - `protected/modules/OphTrConsent/assets/js/Contacts.js:231`

In initialiseDialogTriggers the #contact_label_id change handler computes the limit into a local named contactLabelLimit (line 230) but then gates the check on `typeof patientContactLimit !== 'undefined'` (line 231). patientContactLimit is only a `let` local inside addEntry (line 103) - it is never in scope here, so the guard is always false, contactTypeLimitReached stays false, and contactLabelError stays "". The server side completes the hole: ContactController::actionSaveNewContact only raises the contact_label_limit error when the CLIENT posts a non-empty contact_label_error string, so the max_number_per_patient limit on contact labels is never enforced when adding contacts through the 'Add a new contact' dialog (Power of Attorney contacts on CF4 consents). The same limit works via the plain adder path (addEntry sets its own patientContactLimit), proving the intended behaviour.

Predicted predicate: In the Add-a-new-contact dialog reached from the Power of Attorney contacts adder, selecting a contact type whose max_number_per_patient is already reached for this patient shows no limit warning, and saving succeeds - exceeding the configured limit.

```
let contactLabelLimit = controller.getContactLabelLimit(selectedLabel);
if (typeof patientContactLimit !== 'undefined') {
    contactTypeLimitReached = controller.isContactTypeAboveLimit(selectedLabel, contactLabelLimit);
}

contactLabelError = controller.handleContactTypeLabelError(contactTypeLimitReached, selectedLabel);
```

## S-26: Consent taken by: consultant_id is set from created_user_id, never from the selected health professional (high confidence)

Module: consent-create - `protected/modules/OphTrConsent/views/default/form_Element_OphTrConsent_Consenttakenby.php:67`

When name_hp is non-empty (it always is - line 39 prefills it from getUserPermissionDetails()['label']), the form view executes `$element->consultant_id = $element->user->id;` before rendering the hidden consultant_id field (line 73). The model's 'user' relation is BELONGS_TO User via created_user_id (models/Element_OphTrConsent_Consenttakenby.php), not the chosen health professional. The autocomplete onSelect JS only writes the display NAME into #Element_OphTrConsent_Consenttakenby_name_hp and never touches consultant_id. Net effect: on create $element->user is null (new record, null created_user_id) so consultant_id posts empty; on every update it is silently rewritten to the event CREATOR's user id, regardless of which health professional was searched and selected. The stored consultant is wrong data on a consent record; no consent view renders this element's consultant relation, so the corruption is only visible in the DB/reporting.

Predicted predicate: After selecting health professional X (different from the logged-in creator) in 'Consent taken by' and saving, et_ophtrconsent_consenttakenby.consultant_id is NULL on create and equals created_user_id after an edit-save - never X's user id.

```
<?php if (strcmp((string) $element->name_hp, "") !== 0) { ?>
    ...
    <?php
        $element->consultant_id = $element->user->id;
}
?>
...
echo $form->hiddenField($element, 'consultant_id');
```

## S-27: handleTinyMCEInput discards all non-list content typed into Benefits/Risks whenever a procedure is added (high confidence)

Module: consent-create - `protected/modules/OphTrConsent/assets/js/module.js:446`

Every procedure add (core or extra) triggers callbackAddProcedure, whose AJAX success calls handleTinyMCEInput on the Benefits and Risks TinyMCE editors. That function harvests ONLY <li> nodes from the current editor content (line 446: tinyMCE_content.find("li")), merges them with the fetched items, and REPLACES the whole editor with `<ul>...</ul>` (line 466: tinyMCE.setContent). Any free text the clinician typed as paragraphs (TinyMCE default output is <p> for plain typing, e.g. after pressing Enter to leave the list or typing into an empty editor) is silently destroyed the next time any procedure is added. The editor is a rich-text control that permits paragraphs, so this is reachable in normal use.

Predicted predicate: After typing a plain paragraph (non-bullet) into the Benefits editor and then adding a procedure via the adder, the typed paragraph disappears from the Benefits editor - only bullet-list items remain.

```
const tinyMCE_content = $(tinyMCE.getContent());
const tinyMCE_content_items = tinyMCE_content.find("li");
...
tinyMCE.setContent(`<ul>${final_items.join("")}</ul>`);
```

## S-28: Deceased recipient: getAddress returns double-encoded JSON, recipient row crashes (high confidence)

Module: OphCoCorrespondence - `protected/modules/OphCoCorrespondence/components/OphCoCorrespondence_API.php:684`

OphCoCorrespondence_API::getAddress returns `json_encode(array('errors' => 'DECEASED'))` (a STRING) for deceased contacts while every other path returns an array. DefaultController::actionGetAddress then calls renderJSON($data), which is `echo json_encode($data)` (RenderJsonTrait line 38), so the response body is a JSON-encoded string, not an object. docman.js updateRow (protected/assets/js/docman.js, success handler at line 454) declares dataType:'json', so `resp` becomes the plain string '{"errors":"DECEASED"}'. `resp.address`, `resp.contact_name` etc. are undefined, and line 479 `.val(resp.contact_type.toUpperCase())` throws TypeError, aborting the handler before the `$("#dm_table .docman_loader").hide()` at the end. There is also no 'errors' key check anywhere in updateRow, so even a correctly-encoded response would be unhandled. Selecting the deceased patient as a recipient (the Patient option is always present - ElementLetter::getAddress_targets line 465 adds it unconditionally) leaves the row blank with the loading spinner stuck and no deceased warning.

Predicted predicate: After choosing the deceased patient in the To recipient dropdown, #Document_Target_Address_0 stays empty and the #dm_table .docman_loader spinner remains visible indefinitely; no dialog or message about the patient being deceased appears.

```
OphCoCorrespondence_API.php:683-685:
        if (method_exists($contact, 'isDeceased') && $contact->isDeceased()) {
            return json_encode(array('errors' => 'DECEASED'));
        }
DefaultController.php:151-152:
        $data = $api->getAddress($_GET['patient_id'], $_GET['contact']);
        $this->renderJSON($data);
docman.js:479-480:
                        .val(resp.contact_type.toUpperCase())
                        .trigger("change", [{ email: resp.email }]);
```

## S-29: Deceased patient + Patient-recipient macro: raw {"error":"DECEASED"} JSON injected into recipients HTML (high confidence)

Module: OphCoCorrespondence - `protected/modules/OphCoCorrespondence/components/OphCoCorrespondence_API.php:339`

OphCoCorrespondence_API::getMacroTargets ECHOES `json_encode(array('error' => 'DECEASED'))` and returns null when the macro's recipient is Patient and the patient is deceased. But its callers do not treat it as an endpoint: DocmanController::actionAjaxGetMacroTargets (line 237) calls it via ElementLetter::getLetterRecipients while rendering the '/docman/_create' partial, so the echoed JSON is concatenated BEFORE the partial's HTML in the AJAX response. docman.js fetchDocumentRecipients (line 250) does `$("#dm_table").replaceWith(resp)` with no error handling, so the leading text node renders as literal `{"error":"DECEASED"}` text in the recipients area. The same echo corrupts the full-page GET create output when such a macro is the default macro (getLetterRecipients called from form_ElementLetter.php line 285).

Predicted predicate: After selecting a macro whose recipient is Patient on a deceased patient's create page, the literal text {"error":"DECEASED"} is visible in the page near the recipients table.

```
OphCoCorrespondence_API.php:338-341:
            if ($patient->date_of_death) {
                echo json_encode(array('error' => 'DECEASED'));
                return;
            }
DocmanController.php:234-239:
        echo $this->renderPartial('/docman/_create', array(
                'macro_id' => $macro_id,
                ...
                'letter_recipients' => $element->getLetterRecipients($patient, $macro_id),
```

## S-30: Deceased patient + CC-patient macro: null->email crash makes macro recipients 500 (high confidence)

Module: OphCoCorrespondence - `protected/modules/OphCoCorrespondence/models/ElementLetter.php:1477`

In ElementLetter::getLetterRecipients the cc loop reads `'email' => Contact::model()->findByPk($contact_id)->email,` with no null guard (the equivalent 'to' branch at line 1439 has `->email ?? null`). getMacroTargets' deceased-cc branch (OphCoCorrespondence_API.php lines 381-383) sets only contact_name and address for the cc row - no contact_id - so `$contact_id` is null (line 1465 `$target["contact_id"] ?? null`), findByPk(null) returns null, and the property read raises 'Attempt to read property on null', which Yii 1.1 (no error_reporting override) converts to a fatal error page / HTTP 500. Reached whenever a macro with cc_patient is selected for a deceased patient: DocmanController::actionAjaxGetMacroTargets 500s and docman.js fetchDocumentRecipients has no error callback, so the recipient table silently never updates; if that macro is the default macro the whole create page 500s.

Predicted predicate: Selecting a macro configured with 'CC patient' on a deceased patient's create page updates the letter body/subject but the recipients table gains no CC row and shows no deceased warning (the ajaxGetMacroTargets request returns HTTP 500).

```
ElementLetter.php:1477:
                    'email' => Contact::model()->findByPk($contact_id)->email,
OphCoCorrespondence_API.php:381-383:
            if ($patient->date_of_death) {
                $data['cc'][$k]['contact_name'] = "Warning: the patient cannot be cc'd because they are deceased.";
                $data['cc'][$k]['address'] = null;
```

## S-31: Empty Categories selection hides ALL pathway steps while panel says "All" (high confidence)

Module: worklist - `protected/assets/js/worklist/OpenEyes.UI.WorklistFilterPanel.js:460`

The adder's onReturn builds `let stepTypeCategories = [];` and only fills it from selected li's; the categories itemset is not mandatory, so the user can toggle OFF the pre-selected 'All' li (single click on the highlighted item) and confirm with nothing selected, storing an empty array unconditionally via `controller.stepTypeCategories = stepTypeCategories;`. The server sanitises [] to 'all' (WorklistFilterQuery constructor lines 164-182), so the worklist query itself is unaffected - but the CLIENT-side setPathwayStepFilters in views/worklist/index.php (lines 1244-1260) has the opposite semantics: for a Set it adds `hide-pathstep-type-<cat>` to #js-clinic-manager for every category NOT in the Set, so an empty Set adds hide-pathstep-type-clinical AND hide-pathstep-type-administrative, hiding every pathway step button. Meanwhile setPathStepCategoriesRow([]) produces an empty label which falls back to 'All' (lines 812-814), so the panel claims no category filtering is active. The state persists across reloads via the recent-filter session restore. The cypress suite (pathway-step-filtering.cy.js) never exercises the deselect-to-empty path.

Predicted predicate: #js-clinic-manager carries both hide-pathstep-type-clinical and hide-pathstep-type-administrative classes (every .oe-pathstep-btn hidden) while [data-test="filter-panel-categories"] reads "All"

```
let stepTypeCategories = [];
...
} else if (into === "stepTypeCategories") {
    if (item.id === "all") {
        stepTypeCategories = "all";
    } else {
        stepTypeCategories.push(item.id);
    }
}
...
controller.stepTypeCategories = stepTypeCategories;

// index.php setPathwayStepFilters:
allPathwayStepTypeCategories.forEach((category) => {
    if (!chosenCategories.has(category)) {
        mainElement.classList.add(`hide-pathstep-type-${category}`)
    }
});
```

## S-32: Context dropdown snaps back: server override discards the requested context (high confidence)

Module: worklist - `protected/controllers/WorklistController.php:2199`

actionAvailableFilterOptions unconditionally rewrites contexts.selected to the first Recent (or first Other) firm whenever the selected subspecialty is not 'all', ignoring the selected_context_id the client just sent. The panel's context change handler (WorklistFilterPanel.js lines 165-168) sets filter.context and immediately calls populateFilterOptions(filter, true); when the async response arrives, setSelectedContext(data.contexts.selected) reverts the dropdown to the first firm. So with any subspecialty chosen, picking any context other than the first visibly un-picks itself, while controller.filter.context silently keeps the user's choice - dropdown and applied/saved filter disagree.

Predicted predicate: With a subspecialty selected, choosing any context other than the first option makes the context dropdown revert to the first option within about a second of the options fetch

```
if ($options['subspecialties']['selected'] !== WorklistFilterQuery::ALL_SUBSPECIALTIES) {
    unset($options['contexts']['list']['ungrouped'][WorklistFilterQuery::ALL_CONTEXTS]);

    $grouped_contexts = $options['contexts']['list']['grouped'];

    $options['contexts']['selected'] =
        array_keys($grouped_contexts[SiteAndFirmWidget::RECENT_FIRM_CATEGORY])[0] ??
        array_keys($grouped_contexts[SiteAndFirmWidget::OTHER_FIRM_CATEGORY])[0];
}
```

## S-33: Server-coerced site/subspecialty/context never written back into the filter model (high confidence)

Module: worklist - `protected/assets/js/worklist/OpenEyes.UI.WorklistFilterPanel.js:504`

populateFilterOptions applies the response's coerced selections to the DOM dropdowns only (setSelectedSite/Subspecialty/Context); controller.filter is never updated from the response. After the user changes subspecialty, the server forces a context of the new subspecialty into the dropdown (see the override in actionAvailableFilterOptions), but filter.context still holds the previous subspecialty's firm - or 'all'. Apply (storeFilter POST) and star-save both serialise filter.context, so the session filter and any saved favourite carry a context different from the one displayed. The favourites entry then renders the stale context via idMappings.contexts.get(filter.context) - blank when the stale value is 'all', since the override also removed the 'Any context' option from the DOM that refreshMappings scrapes. Note the divergence starts at page load too: the constructor seeds filter.subspecialty/context from the DOM's preselected current-firm values, not 'all'.

Predicted predicate: Change subspecialty only (leave the auto-populated context untouched), star-save a favourite: the favourite entry's context line is blank or shows the pre-change context, not the context displayed in the dropdown

```
if (setSelected) {
    this.setSelectedSite(data.sites.selected);
    this.setSelectedSubspecialty(data.subspecialties.selected);
    this.setSelectedContext(data.contexts.selected);
}

this.controller.refreshMappings();
```

## S-34: Reset to defaults leaves category filtering active (and sets optional to an Array) (high confidence)

Module: worklist - `protected/assets/js/worklist/OpenEyes.UI.WorklistFilterPanel.js:202`

The "Reset to defaults" handler resets worklistDefinitions, optional and sortBy but omits stepTypeCategories (and period). After filtering to e.g. Administrative and applying, clicking reset leaves filter.stepTypeCategories as the category Set: the panel categories row keeps showing 'Administrative' and the next apply keeps the clinical steps hidden - the reset silently does not reset the newest filter row (categories were added by OE-18295 and this handler was never extended). Secondary defect: `controller.optional = []` stores an Array where the setter and consumers expect a Map ([].size is undefined, so makeOptionalFiltersTemplateData skips its 'All' branch and renders an empty string for the optional row in favourite entries).

Predicted predicate: After selecting category 'Administrative', applying, then clicking "Reset to defaults", [data-test="filter-panel-categories"] still reads "Administrative" (and clinical steps stay hidden after the next apply)

```
this.panel.find(".js-restore-filter-defaults").click(function () {
    controller.worklistDefinitions = 'all';
    controller.optional = [];
    controller.sortBy = 0;
})
```

## S-35: Menu link builder drops the colon guard: 'javascript:' menu items now navigate to a 404 (high confidence)

Module: core menu (_menu.php, changed in OE-18088 #12342 merged 2026-07-28) - `protected/views/base/_menu.php:40`

Commit 71250ba600 rewrote the top-level link builder from `elseif ($item['uri'] !== '#' && strpos((string) $item['uri'], ':') === false) { $link = createURL('site/index').ltrim(...) }` to `if ($link && $link !== '#') { $link = Yii::app()->createURL('site/index') . ltrim((string) $link, '/'); }` - the `strpos(':')` guard that protected protocol/javascript URIs was removed for TOP-LEVEL items (the sub-item branch on line 57 still keeps it: `strpos((string) $sub_item['uri'], ':') === false`). common.php still ships the unrestricted top-level item 'esign_device_popup' => ['title' => 'Link a mobile device', 'uri' => 'javascript:eSignDevicePopup();'] (protected/config/core/common.php:730-733). urlManager maps '' => 'site/index' so createURL('site/index') returns '/', producing href="/javascript:eSignDevicePopup();". Clicking navigates the browser to that path, which matches no route -> Yii 404 error page, instead of running the global eSignDevicePopup() (defined in protected/assets/js/script-utils.js). Every logged-in desktop user sees this item.

Predicted predicate: In the shortcuts menu (top-right menu icon), the 'Link a mobile device' anchor has href '/javascript:eSignDevicePopup();' and clicking it leaves the page and lands on an error page ('Error 404' / 'Unable to resolve the request') instead of opening the mobile-device-linking popup in place.

```
if ($link && $link !== '#') {
    $link = Yii::app()->createURL('site/index') . ltrim((string) $link, '/');
}
// vs. sub-items which kept the guard:
$sub_link = ($sub_item['uri'] !== '#' && strpos((string) $sub_item['uri'], ':') === false) ? Yii::app()->createURL('site/index') . ltrim((string) $sub_item['uri'], '/') : $sub_item['uri'];
// common.php:732: 'uri' => 'javascript:eSignDevicePopup();',
```

## S-36: Forum tracker seed migration ignores institution-level enable_forum_integration, deleting the menu item on upgraded installs (high confidence)

Module: migrations (OE-18089 #12289) - `protected/migrations/m260709_101000_seed_forum_tracker_custom_menu_item.php:11`

The migration only seeds the forum_tracker custom_menu_item row when `getEffectiveSetting('enable_forum_integration') === 'on'`, and getEffectiveSetting reads ONLY setting_installation then setting_metadata.default_value. But enable_forum_integration is an INSTITUTION-level setting: m210510_060538 sets lowest_setting_level='INSTITUTION' for it, and m180414_125301 seeded a permanent setting_installation row with value 'off'. At runtime SettingMetadata::getSetting checks SettingInstitution BEFORE SettingInstallation ($CONTEXT_CLASSES order, SettingMetadata.php:44-53), so an install that enabled FORUM the normal way (per institution, rows in setting_institution='on') reports 'on' at runtime while the migration reads the stale installation-level 'off' and skips seeding. Since the same PR deleted the static 'forum' menu_bar_items entry from common.php, such installs lose the 'Track patients in FORUM' menu item entirely after upgrade - the forum_enabled session key can never be set, and the PatientPanel force-reload block (PatientPanel.php:172-189) becomes permanently dead, while the Biometry-event 'Open In Forum' buttons (gated on the same setting, which still reads 'on') keep appearing. The imagenet twin (m260709_101100) is safe only because enable_imagenet_integration defaulted to INSTALLATION level.

Predicted predicate: On an install where FORUM integration is enabled at institution level, after migration the shortcuts menu contains no 'Track patients in FORUM' entry (custom_menu_item has no provider_key='forum_tracker' row), while a FORUM-imported Biometry event still shows its 'Open In Forum' button.

```
if ($this->getEffectiveSetting('enable_forum_integration') !== 'on') {
    return true;
}
...
$installation_value = $this->dbConnection->createCommand()
    ->select('value')
    ->from('setting_installation')  // never queries setting_institution
// m210510_060538: array('lowest_setting_level' => 'INSTITUTION') applied to 'enable_forum_integration'
// m180414_125301: $this->insert('setting_installation', array('key' => 'enable_forum_integration', 'value' => 'off'));
```

## S-37: Worklist session state wrongly reset when active (string) and resolved (int) patient ids are compared with !== (medium confidence)

Module: core-event-create - `protected/controllers/BaseEventTypeController.php:3751`

validateOrResetWorklistSessionState (added by OE-18173 #12201, June 2026) compares `$active !== $resolved`. active_worklist_patient_id is always a string: PatientEventController::actionCreate line 227 stores `$app->request->getQuery('worklist_patient_id')`. resolved_worklist_patient_id is set by WorklistBehavior from WorklistPatientResolver::resolve(), and one resolver branch - getWorklistPatientFromPatientTicketing(): ?int - returns an int. When both refer to the SAME patient ticketing worklist entry, "123" !== 123 is true, so resetActiveWorklistSessionState() wipes active_step_id and active_worklist_patient_id. Also note initActionCreate runs BEFORE parent::beforeAction raises onBeforeAction (BaseEventTypeController::beforeAction lines 552/562), so the resolved id seen here is from the PREVIOUS request, making the stale-compare path routine, not exotic. Effect: an event created from a patient-ticketing-sourced pathway step loses its step link - saveEvent's session step association (line 1948) never runs, the step is not completed, and the event has no step_id.

Predicted predicate: Creating an event via a pathway step for a patient whose worklist entry was resolved through PatientTicketing leaves the pathway step un-completed after save, and the saved event is not linked to the step, even though the same flow works for ordinary worklist patients.

```
$active = Yii::app()->session['active_worklist_patient_id'] ?? null;
$resolved = Yii::app()->session['resolved_worklist_patient_id'] ?? null;
if ($active && $resolved && $active !== $resolved) {
    $this->resetActiveWorklistSessionState();
    return;
}
```

## S-38: actionCreate renders a blank page when afterCreateElements returns errors (bare return after rollback) (medium confidence)

Module: core-event-create - `protected/controllers/BaseEventTypeController.php:1039`

In actionCreate's POST branch, if afterCreateElements($this->event) contributes errors the code rolls back the transaction and does a bare `return;` from actionCreate - no render, no redirect, no flash. The user gets an empty 200 response and loses their form input. Contrast actionUpdate (lines 1300-1304) where the same condition falls through so the create/update view re-renders with the errors. Reach today is narrow: OphTrOperationnote overrides the whole flow with createOpNote (which handles this correctly), and OphCiExamination's persistPcrRisk gets no POST data under the 'PcrRisk' key on exam (element posts under the namespaced class name), so afterCreateElements rarely errors in practice - but any module hook returning an error hits the blank page.

Predicted predicate: Submitting a create form where a module's afterCreateElements hook reports an error yields a completely blank page (no .errorMessage, no event view) and the event is not created.

```
$errors = array_merge($errors, $this->afterCreateElements($this->event));

if (!empty($errors)) {
    $transaction->rollback();
    return;
}
```

## S-39: updateEventStep ignores its $event parameter when finding the step and never saves the assigned step_id (medium confidence)

Module: core-event-create - `protected/controllers/BaseEventTypeController.php:3535`

updateEventStep($event = null) defaults $event to $this->event but then calls `$this->findApplicableStep($this->event, ...)` - hard-coded to $this->event, so a caller passing a different event (OphInBiometry DefaultController.php:145 passes $unlinkedEvent) searches for a step applicable to the WRONG event. Worse, `$event->step_id = $applicable_pathway_step->id;` is assigned but never persisted: no $event->save() follows, and in the actionCreate flow updateEventStep runs at line 1032, AFTER saveEvent already saved the event. So for an ad hoc create on a pathway patient the step is marked completed but event.step_id stays NULL in the DB (except when saveEvent's separate session-based branch at line 1948 set it first). Result: the event->step association used by eventHasStepThatIsApplicable and step-linked UI is missing.

Predicted predicate: After creating an event for a worklist patient without going through a step click (no active_step_id in session), the pathway step shows completed but the saved event is not linked to it (event view shows no step association; DB event.step_id is NULL).

```
$event ??= $this->event;

$applicable_pathway_step = $this->findApplicableStep($this->event, Pathway::STARTED_STEPS_TYPE);

if (isset($applicable_pathway_step)) {
    $pathway = $applicable_pathway_step->pathway;
    $event->step_id = $applicable_pathway_step->id;

    $this->updatePathwayStep($applicable_pathway_step, PathwayStep::STEP_COMPLETED);
```

## S-40: saveEvent dereferences null PathwayStep when session active_step_id is stale (medium confidence)

Module: core-event-create - `protected/controllers/BaseEventTypeController.php:1954`

saveEvent loads `$step = PathwayStep::model()->findByPk(Yii::app()->session['active_step_id']);` and immediately calls `$step->getState('event_type')` with no null check. active_step_id is set by PatientEventController::actionCreate from a query parameter and survives in the session; if the step has since been deleted (pathway reset/re-created, worklist cleardown) findByPk returns null and the save throws 'Call to a member function getState() on null' inside the transaction - a 500 on clicking Save, form input lost. validateOrResetWorklistSessionState validates the worklist patient but never validates that active_step_id still exists.

Predicted predicate: Clicking Save on an event create form after the originating pathway step was deleted (session active_step_id stale) produces a PHP error page (getState() on null) instead of saving or showing a validation message.

```
$step = PathwayStep::model()->findByPk(Yii::app()->session['active_step_id']);

if ($step->getState('event_type') === $this->event->eventType->class_name) {
```

## S-41: actionLoadDraft null-derefs when no runtime-selectable fallback firm exists in the institution (medium confidence)

Module: core-event-create - `protected/controllers/PatientEventController.php:280`

When the draft's saved firm id is unavailable, actionLoadDraft falls back to `Firm::model()->find(...runtime_selectable=1...)` scoped to the current institution and immediately reads `$event_firm->id`. If the episode's subspecialty has no runtime-selectable firm in the user's selected institution, find() returns null and the line fatals - the user clicking a draft link from the hotlist (/base/_hotlist.php:118), episode sidebar (_single_episode_sidebar_draft_entry.php:18) or add-new-event screen (add_new_event.php:90) gets a PHP error page instead of the intended flash + context reset. The code even prepares a graceful path (flash message + 'context not found' exception) that this null-deref preempts. Additionally line 293 builds `$draft->originating_url . "&draft_id="` assuming originating_url already contains a query string.

Predicted predicate: Opening a saved draft from the hotlist/sidebar while logged into an institution that has no runtime-selectable firm for the draft's subspecialty shows a PHP error page (property id on null) instead of loading the draft with a context-reset warning.

```
$event_firm = Firm::model()->find(
    "service_subspecialty_assignment_id=:service_subspecialty_assignment_id AND institution_id=:institution_id AND runtime_selectable=1",
    [...]
);
$event_firm_id = $event_firm->id;
```

## S-42: Clinic Outcome error demands an RTT/DNA outcome the form gives no way to record (medium confidence)

Module: OphCiExamination - `protected/modules/OphCiExamination/controllers/DefaultController.php:4351`

In the non-mandatory branch of validateClinicOutcomeEntries, the error message is chosen purely on `$rtt_enabled` - i.e. the institution-level 'enable_rtt_clock_bar' setting - not on whether the RTT clock actually rendered for this patient/event. When RTT is enabled but RTTClockDisplayResolver::resolveForEdit returned null (patient has no referral, referral has no clock state, or event opened outside a worklist context) the form contains no #rtt-clock-app adder and no RTT hidden inputs, yet an empty Clinic Outcome fails validation with OUTCOME_OR_RTT_REQUIRED_ERROR = 'Either an RTT/DNA outcome or a clinical outcome entry is required.' - directing the user to record an RTT/DNA outcome that the form cannot record. The correct message for that state is OUTCOME_REQUIRED_ERROR ('Entries cannot be blank.'). Same root observation as the mandatory-mode bypass but a distinct, independently fixable branch.

Predicted predicate: With enable_rtt_clock_bar=1 and mandatory_rtt_clock_state_completion=0, for a patient with no referral, saving an Examination with an empty Clinic Outcome element shows an .errorMessage containing 'Either an RTT/DNA outcome or a clinical outcome entry is required.' while the page contains no #rtt-clock-app element and no RTT outcome/DNA adder buttons.

```
$has_entries = $element && !empty($element->entries);
$has_rtt_outcome = $rtt_enabled && !empty($rtt_data['state_option_id']);

if (!$has_entries && !$has_rtt_outcome) {
    $clinic_outcome_name = Element_OphCiExamination_ClinicOutcome::model()->getElementTypeName();
    $errors[$clinic_outcome_name][] = $rtt_enabled
        ? Element_OphCiExamination_ClinicOutcome::OUTCOME_OR_RTT_REQUIRED_ERROR
        : Element_OphCiExamination_ClinicOutcome::OUTCOME_REQUIRED_ERROR;
```

## S-43: Taper model forces numerical dose while item dose (which the UI clones into tapers) may be free text (medium confidence)

Module: OphDrPrescription - `protected/modules/OphDrPrescription/models/OphDrPrescription_ItemTaper.php:66`

OphDrPrescription_ItemTaper::rules() contains array('dose', 'numerical'), but the parent OphDrPrescription_Item has no numerical rule on dose - free-text doses are an explicitly supported item feature (the view at form_Element_OphDrPrescription_Details_Item.php line 82 only applies numbers-only client filtering when the dose is already numeric/empty, and line 200-206 applies the same free-text tolerance to taper inputs). The add-taper JS clones the item's dose input into the taper row, so for a drug whose dose is free text (e.g. 'As directed', '2 drops') the taper is born with a value the server will always reject: saving produces a validation error on the taper dose that the UI itself invited, and the only way out is inventing a numeric dose. UI and model contract disagree.

Predicted predicate: Adding a drug whose dose field contains free text (e.g. 'As directed'), clicking the taper button (which clones that dose into the taper row), and pressing #et_save yields a .errorMessage validation error about the taper dose not being a number, even though the identical free-text dose on the item itself passes validation.

```
public function rules()
{
    return array(
        array('item_id, frequency_id, duration_id', 'required'),
        ...
        array('dose', 'numerical'),
```

## S-44: addItem() sets $.ajaxSetup({async:false}) globally and never restores it (medium confidence)

Module: OphDrPrescription - `protected/modules/OphDrPrescription/assets/js/defaultprescription.js:474`

addItem() begins with $.ajaxSetup({ async: false }); and there is no matching call anywhere in the module to restore async:true. $.ajaxSetup mutates jQuery's GLOBAL defaults, so from the moment the first drug is added, every subsequent AJAX request on the create page runs synchronously on the main thread: each adder-dialog search keystroke (runItemSearch), RouteOptions, GetDispenseLocation, the esign endpoints and the save/finalize POSTs all block the UI for the full round-trip. On a slow connection the whole tab freezes per keystroke while searching for the second drug. The browser also logs the 'Synchronous XMLHttpRequest on the main thread is deprecated' warning for each request, which is directly observable in the console after the first item is added but not before.

Predicted predicate: Before adding any drug, adder-dialog search requests are asynchronous; after adding the first drug, every subsequent XHR from the page (including each search keystroke in the adder) is synchronous - the browser console logs 'Synchronous XMLHttpRequest on the main thread is deprecated' for each request and the UI freezes during them.

```
// Add item to prescription
function addItem(label, item_id) {
    // we need to call different functions for admin and public pages here
    $.ajaxSetup({ async: false });
```

## S-45: saveDraft 404 for expired draft rendered as fake connection error, save locked out (medium confidence)

Module: core - `protected/assets/js/OpenEyes.EventDraftController.js:291`

actionSaveDraft throws CHttpException(404,'Cannot find draft with provided ID') when the posted draft_id no longer exists (BaseEventTypeController.php lines 1540-1544). The JS $.ajax error handler treats every non-2xx identically as a lost connection: showConnectionErrorUI() hides the working save/cancel buttons and shows the connection-error set, and the popup tells the user it is a 'Network connection error / error with the OpenEyes server'. The 'Re-test the connection' button just re-runs attemptDraftSave with the same stale input#draft_id, so it 404s forever and the page can never leave the error state - the user cannot save the event despite full connectivity. Realistic trigger: ClearExpiredDraftSavesCommand deletes is_auto_save drafts (its TIMESTAMP(NOW())-TIMESTAMP(...) arithmetic expires them after as little as ~8.6h), so a create/update tab left open overnight hits this every morning; also two tabs on the same create page after one saves.

Predicted predicate: With the server fully reachable, once input#draft_id references a deleted draft the 'OE Connection Error' tab appears, the real Confirm & Save button is hidden, and clicking 'Re-test the connection' never clears the error state.

```
error: (err) => {
    if (!this.disableAutosave) {
        this.showConnectionErrorUI();
    }
},  // controller: if (empty($draft)) { throw new \CHttpException(404, "Cannot find draft with provided ID"); }
```

## S-46: Autosave 'handle' dispatch re-enables read-only Area of Care inputs (medium confidence)

Module: OphCiExamination - `protected/modules/OphCiExamination/widgets/js/ResponsibleForCare.js:86`

EventDraftController.doJSONParsing() dispatches the same 'handle' CustomEvent used by the real save to every .js-save-handler-function node on each 30s autosave, flagged only via handle_event.draft = true. The AreaOfCare listener unconditionally runs $('#OEModule_OphCiExamination_models_Element_OphCiExamination_AreaOfCare_element :input').prop('disabled', false) - a save-time side effect meant to make disabled fields submit - without checking event.draft (unlike MedicationManagement's mm-handler-1 which checks e.originalEvent.draft). When the element is rendered read-only because it is not the tip version ($is_latest_element = $element->isAtTip() false sets all its inputs disabled), the first autosave silently re-enables all of it, letting the user edit and autosave/submit data from a stale element. Same pattern exists in OphGeneric Assessment_DeviceInformation.php line 394 (enableAllAbacInputs on 'handle').

Predicted predicate: On an examination edit page where the Area of Care element loads greyed-out/disabled (not the latest version), its inputs become editable ~30 seconds after page load without any user interaction (count of :input[disabled] inside the element drops to 0).

```
document.querySelector('#area-of-care-save-handler').addEventListener("handle", function () {
    $('#OEModule_OphCiExamination_models_Element_OphCiExamination_AreaOfCare_element :input').prop("disabled", false);
});  // vs MM: if (prescription_modified && !e.originalEvent.draft) {...}
```

## S-47: Handheld existing-draft banner lacks the data attributes the draft controller reads - 'delete draft' navigates with undefined params (medium confidence)

Module: core - `protected/views/patient/event_content_handheld.php:19`

The desktop chrome (event_content.php lines 121-138) renders the existing-draft banner with data-patient-id, data-event-type-id, data-context-id and data-service-id. The handheld variant renders the same banner ids/classes (so the same OpenEyes.EventDraftController.js handlers bind) but omits all four data attributes. In deleteExistingDrafts()'s success handler the controller calls createEvent({patient_id: $(banner).data('patient-id'), event_type_id: ..., context_id: ..., service_id: ...}) - all undefined on handheld - producing a navigation to /patientEvent/create with 'undefined' query params, which PatientEventController rejects. The handheld chrome also lacks the input#draft_id element the controller's draftIdSelector expects.

Predicted predicate: On the handheld event create chrome, choosing the 'No (delete draft and start fresh)' option on the existing-draft banner navigates to /patientEvent/create?patient_id=undefined&... and lands on an error page instead of a fresh event.

```
desktop event_content.php: data-patient-id="..." data-event-type-id="..." data-context-id="..." data-service-id="..."
handheld banner: same #js-... button ids but no data-* attributes
OpenEyes.EventDraftController.js: controller.createEvent({ patient_id: $(banner).data('patient-id'), event_type_id: $(banner).data('event-type-id'), context_id: $(banner).data('context-id'), service_id: $(banner).data('service-id') })
```

## S-48: Handheld event form omits Event[last_modified_date] hidden field - concurrent-edit conflict detection silently disabled (medium confidence)

Module: core - `protected/views/patient/event_content_handheld.php:1`

Desktop event_content.php emits a HiddenField widget for Event[last_modified_date] (lines 70-77), which BaseEventTypeController (~lines 1809-1818) string-compares against the current DB value on update: if (!$this->event->isNewRecord && $has_last_modified_date_value && $data['Event']['last_modified_date'] !== $this->event->last_modified_date) { ... errors['conflict'] ... }. The guard $has_last_modified_date_value means a form that never posts the field skips the check entirely rather than failing safe. event_content_handheld.php contains no DatePicker/HiddenField/draft_id block at all, so any event type edited through the handheld chrome silently loses the 'event was recently modified by another user' protection: the second saver overwrites the first with no warning.

Predicted predicate: Editing the same event concurrently from a desktop session and a handheld session, the handheld save never shows the 'The event was recently modified by...' conflict error and silently overwrites the other user's changes, while the desktop session in the same scenario does show it.

```
BaseEventTypeController: $has_last_modified_date_value = isset($data['Event']) && isset($data['Event']['last_modified_date']);
if (!$this->event->isNewRecord && $has_last_modified_date_value && $data['Event']['last_modified_date'] !== $this->event->last_modified_date) { ... $errors['conflict'][] = ... }
event_content_handheld.php: no HiddenField('Event','last_modified_date',...) anywhere
```

## S-49: Correspondence email in PENDING_RETRY renders as 'Complete' with the done icon (medium confidence)

Module: core / OphCoCorrespondence - `protected/components/EventListDisplayDetailsHelper.php:318`

addOphCoCorrespondenceDetailsToEventListDisplayDetails() maps document output statuses to the sidebar icon: SENDING/PENDING -> 'Pending', literal 'FAILED' -> 'Failed', anything else falls through to $eventStatus = 'Complete' / icon 'done'. DocumentOutput defines STATUS_PENDING_RETRY = 'PENDING_RETRY' (an email that failed at least once and is queued for retry), which hits the default branch and is displayed as Complete. The logic was copied verbatim from the removed Event.php code in OE-18118, but the refactor makes it worse: the wrong 'Complete' string is now persisted into event_list_display_details, and (per the repository check) is only re-derived when document_output.last_modified_date advances again.

Predicted predicate: An event whose correspondence email is in PENDING_RETRY (delivery failed, awaiting retry) shows the green 'done' tick and quicklook 'Complete' in the patient sidebar instead of a pending/failed indicator.

```
if ($email->output_status === DocumentOutput::STATUS_SENDING || $email->output_status === DocumentOutput::STATUS_PENDING) { $eventStatus = "Pending"; continue; }
if ($email->output_status === 'FAILED') { $eventStatus = "Failed"; continue; }
...
if (!isset($eventStatus)) { $eventStatus = "Complete"; }
// DocumentOutput.php: const STATUS_PENDING_RETRY = 'PENDING_RETRY'; - unhandled, falls to Complete
```

## S-50: Rejected sidebar load still marks Manage-elements popup entry 'added', leaving a stuck un-addable item (medium confidence)

Module: examination-element-js - `protected/assets/js/OpenEyes.UI.ManageElements.js:62`

ManageElements marks the popup entry as 'added' on EVERY sidebar element click (lines 62-64 -> updatePopupItem lines 199-204 adds the class unless the entry is 'mandatory'), regardless of whether the element actually loads. PatientSidebar.loadClickedItem (OpenEyes.UI.PatientSidebar.js:198-203) gates loading on a data('validation-function'); Medication Management carries medicationManagementValidationFunction (module.js ~1001-1074), which does a sync GET to MedicationManagementEditable and returns false with an alert when MM is not editable (e.g. a later examination already contains MM). In that case no section is added, but the popup entry is now 'added'. Clicking the entry in the popup then routes to removeElementItem (lines 218-246): with no matching section, $element.children('input').val() is undefined (not '1') and $element.length===1 is false, so BOTH branches no-op and the class is never cleared - the entry is stuck highlighted and the element can never be added from the popup for the rest of the session. The same desync occurs for any failed/errored element AJAX load, since 'added' is applied optimistically at click time.

Predicted predicate: After clicking Medication Management in the sidebar and receiving the 'not editable' alert (no element added), the Manage-elements popup shows Medication Management highlighted as added, and clicking that popup entry does nothing (no section appears or is removed).

```
self.$sidebar.on('click', '.element', function (e) {
    self.updatePopupItem($(e.target));
});
// updatePopupItem: if (!menuElement.hasClass('mandatory')) { menuElement.addClass('added'); }
// removeElementItem: if ($element.children("input").val() == '1') {...} else if ($element.length === 1) {...}  // no-op when section absent
```

## S-51: addElementByTypeClass waits on a 'loaded' event that is never triggered - callbacks silently dropped for in-flight elements (medium confidence)

Module: examination-element-js - `protected/assets/js/OpenEyes.UI.PatientSidebar.js:311`

When the target element's sidebar anchor has class 'loading' (AJAX ElementForm request in flight), addElementByTypeClass binds the caller's callback to a jQuery 'loaded' event on the anchor. Nothing in the codebase ever triggers 'loaded' (grep for trigger('loaded') across protected/**/*.js is empty); loadClickedItem's completion callback (lines 221-227) only adds 'selected'/removes 'loading'. So any programmatic add that races an in-progress load silently drops its callback and the handler leaks on the anchor. Affected callers: module.js:1640 (FurtherFindings - updateFindings never runs, so the findings text is never appended to the element once it finishes loading), HistoryRisks.js:54, ResponsibleForCareCore.js:38, DrivingSafetyCore.js:123, InjectionManagementFollowup.js:316, ClinicOutcome.js:661.

Predicted predicate: Triggering a Further Findings append (or a HistoryRisks 'risk' add) while the target element is still AJAX-loading results in the element appearing WITHOUT the requested content once the load completes - the follow-up callback never fires.

```
if ($href.hasClass("loading")) {
    $href.on("loaded", function () {
        if (typeof callback === "function") {
            callback();
        }
    });
}
```

## S-52: Biometry Data: r1 duplicated in requiredIfSide rule, duplicate error and likely lost axial_length requirement (medium confidence)

Module: OphInBiometry - `protected/modules/OphInBiometry/models/Element_OphInBiometry_BiometryData.php:76`

Both required rules list the same attribute twice: array('r1_left,r1_left, r2_left', 'requiredIfSide', 'side' => 'left') and the mirrored right rule at line 77. Yii's CValidator::validate iterates the attribute list without deduplication, so requiredIfSide runs twice for r1 and BaseEventTypeElement::addError appends the identical 'Left R1 cannot be blank.' message twice to the model's error stack, which the event error summary renders as two identical lines. The duplication also strongly suggests a third attribute (axial_length_left/right, first in the adjacent safe list and rendered right above R1 in form_Element_OphInBiometry_BiometryData_fields.php) was meant to be required and silently is not.

Predicted predicate: Saving a manually-entered Biometry event with an active left side and R1 left blank lists the error 'Left R1 cannot be blank.' twice in the validation error box (and no error for the empty Axial Length field)

```
array('r1_left,r1_left, r2_left', 'requiredIfSide', 'side' => 'left'),
array('r1_right,r1_right, r2_right', 'requiredIfSide', 'side' => 'right'),
```

## S-53: Posted OperativeDevice ids looked up via the assignment model OphTrOperationnote_CataractOperativeDevice::findByPk (medium confidence)

Module: OphTrOperationnote - `protected/modules/OphTrOperationnote/controllers/DefaultController.php:1453`

setComplexAttributes_Element_OphTrOperationnote_Cataract receives OperativeDevice ids in $data['OphTrOperationnote_CataractOperativeDevices'] (the multiSelectList in form_Element_OphTrOperationnote_Cataract_OEEyeDraw_fields.php:278-283 is populated from getOperativeDeviceList = CHtml::listData of OperativeDevice models), but resolves them with OphTrOperationnote_CataractOperativeDevice::model()->findByPk($oa_id) - the assignment-row model whose pk is unrelated to device ids. The complications block directly above uses the correct pattern. The same copy-paste bug exists in the model's applyComplexData (models/Element_OphTrOperationnote_Cataract.php:675), where the elseif branch right below it correctly uses OperativeDevice::model()->findByPk($device). The DB save path is unaffected (saveComplexAttributes calls updateOperativeDevices with the raw ids), but $element->operative_devices is populated with wrong-type records (or nulls) on every POST, so on validation-failure redisplay getOperativeDeviceList feeds assignment-row ids into activeOrPk as include_ids - a selected-but-inactive Agent loses its name/entry in the redisplayed Agents control, and anything pre-save that reads $element->operative_devices sees garbage.

Predicted predicate: After a failed validation submit of a cataract op note that had an inactive (but previously selected) Agent device ticked, the redisplayed Agents list no longer shows that device's name

```
if (isset($data['OphTrOperationnote_CataractOperativeDevices']) && is_array($data['OphTrOperationnote_CataractOperativeDevices'])) {
    foreach ($data['OphTrOperationnote_CataractOperativeDevices'] as $oa_id) {
        $devices[] = OphTrOperationnote_CataractOperativeDevice::model()->findByPk($oa_id);
    }
}
$element->operative_devices = $devices;
```

## S-54: Template 'prefilled' highlight never clears when user edits the field (dead handlers) (medium confidence)

Module: OphTrOperationbooking - `protected/modules/OphTrOperationbooking/assets/js/module.js:239`

applyPrefillClassesTo (line 466) adds class 'prefilled' to inputs/textareas/selects whose value matches data-prefilled-value (populated when creating from an event template). The handlers meant to REMOVE that class when the user changes the value are all provably dead: the keyup handler tests ["input, textarea"].includes(e.target.tagName) - the array contains the single string "input, textarea" and tagName is uppercase ("INPUT"), so it is always false; the change handler tests e.target.tagName === "input" / "select" (never true, tagName is uppercase); and even if those guards passed, the bodies call nonexistent DOM methods e.target.hasClass()/removeClass() (jQuery methods on a raw element) and e.target.name("name") which would throw TypeError. Net effect: once a field on the op-booking create form is marked prefilled from a template, the highlight class stays no matter what the user types or selects, so the UI keeps asserting the value came from the template after it was edited.

Predicted predicate: On an op-booking create form opened from a template, a text field carrying class 'prefilled' keeps that class (and its highlight styling) after the user types a different value into it.

```
document.querySelector("body").addEventListener("keyup", function (e) {
    if (["input, textarea"].includes(e.target.tagName)) {
        if (e.target.hasClass("prefilled") && ...
...
document.querySelector("body").addEventListener("change", function (e) {
    if (e.target.tagName === "input") {
```

## S-55: Priority-change save/schedule button toggle bound to hidden uncheck input - never fires, would throw if it did (medium confidence)

Module: OphTrOperationbooking - `protected/modules/OphTrOperationbooking/assets/js/module.js:210`

document.querySelector('input[name="Element_OphTrOperationbooking_Operation[priority_id]"]') matches the FIRST input with that name - which, because the priority field is rendered by the RadioButtonList widget in 'nowrapper' mode, is the leading CHtml::hiddenField($name, '') that the widget emits BEFORE the radios (protected/widgets/views/RadioButtonList.php lines 42-44) to force POST of an empty value. A hidden input never receives user 'change' events, so the listener that is supposed to hide 'Save and Schedule now'/'Save and Schedule later' when a non-schedulable priority is picked (using the priority_canschedule jsVar registered in DefaultController beforeAction lines 91-95) never runs. Double defect: even if it did fire, the body calls document.getElementById("et_save").show() and .hide() - raw DOM elements have no show/hide methods (no polyfill exists in the module or core.js), so it would throw TypeError on first invocation. Result: selecting a priority that cannot be scheduled leaves the schedule buttons visible and clickable, deferring the restriction to a later server-side rejection instead of the intended immediate UI change.

Predicted predicate: On the op-booking create form, selecting a priority radio whose priority_canschedule entry is false leaves #et_save_and_schedule and #et_save_and_schedule_later visible (they should be hidden), and no change handler fires (no TypeError either, because the listener sits on the hidden input).

```
const priority_field = document.querySelector(
    'input[name="Element_OphTrOperationbooking_Operation[priority_id]"]',
);
if (priority_field) {
    priority_field.addEventListener("change", function (e) {
        ...
        if (!priority_canschedule[priority_id]) {
            document.getElementById("et_save").show();
```

## S-56: setBenefitsAndRisksFromProcedures leaves benefits/risks as literal '</ul>' when procedures have no active benefits/complications (medium confidence)

Module: consent-create - `protected/modules/OphTrConsent/models/Element_OphTrConsent_BenefitsAndRisks.php:178`

On create-from-booking or create-from-template (DefaultController::setElementDefaultOptions_Element_OphTrConsent_BenefitsAndRisks lines 193-196), the opening '<ul><li>' is only emitted inside the foreach when $i == 0, but the closing `$this->benefits .= '</ul>';` (line 178, same for risks at 187) runs unconditionally. If the booked/template procedures have zero active benefits (or complications), the field becomes the literal string '</ul>'. Consequences: (a) the form view's empty-value bootstrap only fires when val() === '' so the '<ul><li></li></ul>' scaffold is skipped; (b) the browser drops the orphan close tag so the editor LOOKS empty; (c) the model's required rule on benefits/risks passes because '</ul>' is non-empty - a visually blank mandatory field saves without any .errorMessage, storing markup garbage.

Predicted predicate: Creating a consent from a booking whose procedure has no configured active benefits yields textarea#Element_OphTrConsent_BenefitsAndRisks_benefits with value exactly '</ul>', a visually empty Benefits editor, and a successful save with no .errorMessage for Benefits.

```
foreach ($benefits as $i => $benefit) {
    if ($i == 0) {
        $this->benefits = '<ul><li>' . ucfirst((string) $benefit->name) . '</li>';
    } else {
        $this->benefits .= '<li>' . $benefit->name . '</li>';
    }
}
$this->benefits .= '</ul>';
```

## S-57: Extra-procedure benefits/complications URLs omit baseUrl, breaking sub-path deployments (medium confidence)

Module: consent-create - `protected/modules/OphTrConsent/assets/js/module.js:470`

callbackAddProcedure builds the core-procedure URLs with the baseUrl prefix but the extra-procedure branches as root-absolute paths ('/OphTrConsent/default/benefits/' and '/OphTrConsent/default/complications/'). The inconsistency is within the same ternary, two lines apart. On any OpenEyes instance served under a URL sub-path (non-empty baseUrl), adding an extra procedure fires GETs to the wrong root path, both fetches 404, and the Benefits/Risks editors are silently not updated for extra procedures while core procedures still work. On root-hosted instances the strings coincide, which is why it goes unnoticed. Same pattern exists for the .js-add-withdrawal/.js-add-confirm redirects at lines 404-412.

Predicted predicate: On an instance with a non-empty baseUrl, adding an extra procedure appends nothing to the Benefits/Risks editors (network log shows 404 on /OphTrConsent/default/benefits/<id>), while adding a core procedure updates them.

```
const benefits_url = is_extra
    ? "/OphTrConsent/default/benefits/" + procedure_id
    : baseUrl + "/procedure/benefits/" + procedure_id;
const complications_url = is_extra
    ? "/OphTrConsent/default/complications/" + procedure_id
    : baseUrl + "/procedure/complications/" + procedure_id;
```

## S-58: OE-18106 regression: quick-text strings containing any tag lose all line breaks (medium confidence)

Module: OphCoCorrespondence - `protected/modules/OphCoCorrespondence/assets/js/module.js:1390`

formatLineBreakInContent (added in commit d25e1f440f, OE-18106, 2026-07-16) returns the text with NO newline-to-<br> conversion as soon as the very loose regex /<[a-z][\s\S]*>/i matches anywhere in the string. Previously the code was `text.replace(/\n(?!<)/g, "<br>")` - it converted newlines except those already followed by a tag. Now a multi-line quick-text ('stringgroup') entry that mixes plain-text lines with a single inline tag (e.g. '<b>Dose</b>' on one line) - or even just a '<' followed by a letter, like 'IOP <21mmHg' - takes the early-return branch, its \n survive unconverted, and TinyMCE's insertContent (used at line 721 via element_letter_controller.addAtCursor) collapses raw newlines to spaces, so the inserted text runs into a single line.

Predicted predicate: Inserting a multi-line quick-text string that contains an inline HTML tag (or a '<' followed by a letter) into the letter body renders it as a single line - the line breaks between plain-text lines are lost.

```
module.js:1390-1398:
function formatLineBreakInContent(text) {
    const trimmed_text = text.trim();

    if (/<[a-z][\s\S]*>/i.test(text)) {
        return trimmed_text;
    }

    return trimmed_text.replace(/\r?\n/g, "<br>");
}
module.js:721:
                    element_letter_controller.addAtCursor(formatLineBreakInContent(text));
```

## S-59: Attachment metadata mangled on validation-error round trip (wrong POST keys) (medium confidence)

Module: OphCoCorrespondence - `protected/modules/OphCoCorrespondence/widgets/AssociatedContentViewTable.php:88`

The form posts attachment rows as AssociatedContent[N][attachments_print_appended], [attachments_system_hidden], [attachments_short_code] (widgets/views/_associated_table_row.php lines 53/61/69). But on a POST re-render (validation error) AssociatedContentViewTable::getAssociatedContentsFromPost reads $content['is_print_appended'] ?? 1, $content['is_system_hidden'] ?? 0 and $content['short_code'] ?? null - keys that are never posted. So after any failed save, every attachment row is rebuilt with is_print_appended forced to 1, is_system_hidden dropped to 0 and short_code dropped to null; the re-rendered hidden inputs then post those wrong values and the eventual save persists them (a not-print-appended macro attachment becomes print-appended, its custom short code is replaced by a regenerated one). Related same-family defect: EventAssociatedContentManager::saveFromPost line 131 reads $data['is_system_hidden'] ?? 0 (posted key is attachments_system_hidden), so is_system_hidden is saved as 0 even on a clean first save.

Predicted predicate: After a save attempt that fails validation (e.g. no recipient), an attachment row that previously had NO attachments_print_appended hidden input re-renders with input[name='AssociatedContent[0][attachments_print_appended]'] present with value 1, and its attachments_short_code / attachments_system_hidden hidden inputs are gone from the form.

```
AssociatedContentViewTable.php:87-89:
                $content['is_system_hidden'] ?? 0,
                $content['is_print_appended'] ?? 1,
                $content['short_code'] ?? null,
_associated_table_row.php:61:
                    name="AssociatedContent[<?= $row_index ?>][attachments_print_appended]"
EventAssociatedContentManager.php:131:
                'is_system_hidden' => $data['is_system_hidden'] ?? 0,
```

## S-60: updateCorrespondence called with this=window: macro dropdown never clears (incl. DECEASED path) (medium confidence)

Module: OphCoCorrespondence - `protected/modules/OphCoCorrespondence/assets/js/module.js:48`

updateCorrespondence captures `const obj = $(this)` and calls `obj.val("")` both after successfully applying a macro (line 74) and after the DECEASED alert (line 68) - originally to reset the macro <select>. But docman.js changeSelectedMacro (line 76) invokes it as a plain function - `updateCorrespondence(macro_id)` - so `this` is window and `$(window).val("")` silently no-ops. Net effect: #macro_id keeps the selected value. Most visible on the deceased path: the alert says the macro cannot be used and no letter fields populate, but the dropdown still displays the forbidden macro, and re-choosing the SAME macro fires no change event, so the user cannot retry without picking a different option first.

Predicted predicate: After the 'The patient is deceased so this macro cannot be used.' alert is dismissed, the #macro_id dropdown still shows the selected macro instead of resetting to its empty placeholder, and re-selecting the same macro does nothing.

```
module.js:48:
    const obj = $(this);
module.js:63-69:
                if (data["error"] == "DECEASED") {
                    new OpenEyes.UI.Dialog.Alert({...}).open();
                    obj.val("");
                    return false;
                }
docman.js:75-77:
                if (this.module_correspondence == 1) {
                    updateCorrespondence(macro_id);
                }
```

## S-61: All four internal-referral validators crash every save if 'Internal Referral' letter type is inactive (medium confidence)

Module: OphCoCorrespondence - `protected/modules/OphCoCorrespondence/models/ElementLetter.php:173`

internalReferralServiceValidator, internalReferralFirmValidator, internalReferralConditionValidator and internalReferralToLocationIdValidator (ElementLetter.php lines 169-214) each run on EVERY validate() and do `LetterType::model()->findByAttributes(['name' => 'Internal Referral', 'is_active' => 1])` followed by an unguarded `$letter_type->id`. If an admin deactivates (or renames) the 'Internal Referral' letter type, findByAttributes returns null and the property read raises 'Attempt to read property on null' - which Yii renders as a fatal error page - so saving ANY correspondence letter of ANY type fails. Config-dependent, but a single admin toggle bricks the whole module's save path.

Predicted predicate: With the 'Internal Referral' letter type deactivated in admin, pressing Save on any correspondence create form returns a Yii error page (Attempt to read property "id" on null) instead of saving or showing validation messages.

```
ElementLetter.php:171-173:
        $letter_type = LetterType::model()->findByAttributes(array('name' => 'Internal Referral', 'is_active' => 1));

        if ($letter_type->id === $this->letter_type_id) {
```

## S-62: setDefaultOptions reads $episode->firm on null episode when user has a sign-off delegate (medium confidence)

Module: OphCoCorrespondence - `protected/modules/OphCoCorrespondence/models/ElementLetter.php:727`

In ElementLetter::setDefaultOptions, $episode = $patient->getEpisodeForCurrentSubspecialty() (line 666) is null when the patient has no episode for the current firm's subspecialty - the normal state when creating a first correspondence in a new episode. Every other use is guarded by `if ($episode ...)`, but line 727 `$api->getFooterText($signOffUser, $episode->firm)` is not: it executes whenever the logged-in user has correspondence_sign_off_user_id set ($user->signOffUser). PHP 8 raises 'Attempt to read property firm on null' and Yii renders a fatal error page, so the GET create page never loads for such user/patient combinations. Notably $signature_text is assigned and never used (the footer is hard-set to "" at line 657), so the crash is the line's only effect.

Predicted predicate: For a user with a configured sign-off delegate, opening the correspondence create page for a patient with no episode in the current subspecialty shows a Yii error page (Attempt to read property firm on null) instead of the letter form.

```
ElementLetter.php:666:
            $episode = $patient->getEpisodeForCurrentSubspecialty();
ElementLetter.php:722-728:
            if (Yii::app()->user) {
                $user = User::model()->findByPk(Yii::app()->user->getId());
                /** @var User $user */
                if ($user) {
                    if ($signOffUser = $user->signOffUser) {
                        $signature_text = $api->getFooterText($signOffUser, $episode->firm);
                    }
```

## S-63: fromJSON drops the 'all' default for subspecialty on legacy filters (medium confidence)

Module: worklist - `protected/assets/js/worklist/OpenEyes.WorklistFilter.js:164`

WorklistFilter.fromJSON defaults worklistDefinitions/worklists/stepTypeCategories with `?? 'all'`, and the PHP side defaults subspecialty with `$filter->subspecialty ?? self::ALL_SUBSPECIALTIES` (WorklistFilterQuery line 129), but the JS line for subspecialty has no default. A saved/recent filter stored before the subspecialty field existed loads with subspecialty === undefined; populateFilterOptions then falls back to the DOM's current selection (`filter.subspecialty ?? selectedOptions.selectedSubspecialty`, line 485), so the panel displays the current firm's subspecialty as if it were part of the loaded filter while the server applies ALL subspecialties. compare()-based dedupe of recents also misfires between undefined and 'all', creating duplicate recent entries for the same effective filter.

Predicted predicate: Loading a pre-subspecialty favourite leaves the subspecialty dropdown showing the current firm's subspecialty while the resulting patient list is not filtered by subspecialty

```
result.subspecialty = data.subspecialty;
...
result.worklistDefinitions = decodeToStringOrSet(data.worklistDefinitions ?? 'all');
result.worklists = decodeToStringOrSet(data.worklists ?? 'all');
result.stepTypeCategories = decodeToStringOrSet(data.stepTypeCategories ?? 'all');
```

## S-64: Legacy favourites with specific worklists render blank list names (medium confidence)

Module: worklist - `protected/assets/js/worklist/OpenEyes.UI.WorklistFilterPanel.js:47`

makeFilterEntryData's else branch (legacy filter: worklists array present, worklistDefinitions absent) passes idMappings.worklists into makeListsTemplateData - but that map's values are plain title strings (WorklistFiltersController line 277: `this.mappings.worklists.set(worklistData.id, worklistData.title)`), while makeListsTemplateData reads `listNames.get(list).name`. `.name` on a string is undefined, so every list renders {title: undefined} and the favourite/recent entry shows empty bullets where the list names should be. The worklists-to-worklistDefinitions migration (WorklistFilterQuery::decodeAndUpdateFilter) only runs server-side when a filter is used in a query; retrieveFilters returns the raw stored JSON, so unmigrated legacy favourites hit this branch on every page load.

Predicted predicate: A pre-migration favourite with specific worklists shows blank list names in its favourites-tab entry

```
}).map(function (list) {
    return { title: listNames.get(list).name };
});
```

## S-65: availableFilterOptions errors when the user has no firms for the chosen subspecialty (medium confidence)

Module: worklist - `protected/controllers/WorklistController.php:2204`

In the context override, `??` only shields the left operand. If the user has no firms in either group for the selected subspecialty (SiteAndFirmWidget::getFirmListForDropdown always creates both 'Recent' and 'Other' keys, possibly as empty arrays), the LHS is null and the RHS `array_keys([])[0]` raises 'Undefined array key 0' (PHP 8 warning, converted to an error page by Yii's default error handling). The JS caller's .catch only console.errors, so the dropdowns silently stop updating: the context dropdown keeps the previous subspecialty's contexts and the mappings go stale. Even if warnings are suppressed, contexts.selected becomes null and, with 'Any context' unset and both optgroups empty, the context dropdown is left with no selectable option.

Predicted predicate: Selecting a subspecialty for which the user has no firms leaves the context dropdown un-updated (previous subspecialty's contexts still listed) with a failed /worklist/availableFilterOptions request in the network log

```
$options['contexts']['selected'] =
    array_keys($grouped_contexts[SiteAndFirmWidget::RECENT_FIRM_CATEGORY])[0] ??
    array_keys($grouped_contexts[SiteAndFirmWidget::OTHER_FIRM_CATEGORY])[0];
```

## S-66: PatientPanel never re-launches FORUM/IMAGEnet when tracking is toggled off and on for the same patient (medium confidence)

Module: PatientPanel widget - `protected/widgets/PatientPanel.php:177`

getWidgets() fires `oelauncher('forum')` only when `!hasState('last_patient') || getState('last_patient') != $this->patient->id`, and last_patient is never cleared when tracking is switched off - ExternalPatientTrackerMenuItemProvider::activate() returns ToggleActivationResult(sessionKey: forum_enabled, onValue: null) and CustomMenuItemController::handleProviderActivation only sets that one key. Sequence: user tracks patient X (launcher fires, last_patient=X), clicks 'Stop tracking in FORUM', later clicks 'Track patients in FORUM' again while still on X's record -> forum_enabled='on' but last_patient==X, so no forceforum script is registered and FORUM is never told to load X; it stays on whatever it last showed until the user opens a different patient. The stale-state structure predates OE-18088 but the commit rewrote exactly this comparison (from identifier value to patient id) without adding a reset on toggle, and the new toggle path (ToggleActivationResult) is the only writer of the flag, so the pairing is now fully in view of the new code.

Predicted predicate: After enabling tracking, stopping it, and re-enabling it while remaining on the same patient's record, the rendered page HTML contains no `oelauncher('forum');` (script id 'forceforum') even though the menu shows 'Stop tracking in FORUM' (tracking on).

```
if (!Yii::app()->user->hasState('last_patient') || Yii::app()->user->getState('last_patient') != $this->patient->id) {
    if ($forum_enabled) {
        Yii::app()->clientScript->registerScript("forceforum", "oelauncher('forum');", CClientScript::POS_LOAD);
    }
...
    Yii::app()->user->setState('last_patient', $this->patient->id);
}
// toggle-off path only does: Yii::app()->user->setState($result->sessionKey, $result->onValue); // null
```

## S-67: Forum/ImageNet control split: custom menu item admin text promises control over Biometry event buttons that still obey the old setting (medium confidence)

Module: oe-shared menu providers vs OphInBiometry/OphGeneric views - `oe-shared/app/Services/Menu/Providers/ForumTrackerMenuItemProvider.php:41`

After OE-18089 the menu tracker is driven solely by the custom_menu_item row (active flag, admin Custom Menu Items screen), but the event-level launch buttons still read the legacy settings: OphInBiometry/views/default/view.php:29 and OphGeneric/views/default/view.php:27 gate 'Open In Forum' on `SettingMetadata::getSetting('enable_forum_integration') === 'on'`, and OphGeneric view.php:41 gates 'Open In ImageNet' on enable_imagenet_integration. The provider's admin-facing configDescription explicitly claims the opposite contract: 'When enabled, a link to view patient records and biometry events in Zeiss Forum will be shown in the main menu and on Biometry Events'. So an admin who deactivates (or deletes) the forum_tracker custom menu item still sees 'Open In Forum' on Biometry events, and an admin who creates the item on an install where the setting is off gets a menu tracker whose companion event buttons never appear - two disconnected control planes for what is documented as one toggle.

Predicted predicate: With the forum_tracker custom menu item set inactive in Admin > Custom Menu Items (its promised 'disable'), a FORUM-imported Biometry event view still renders the 'Open In Forum' event action button.

```
// provider admin text: 'When enabled, a link to view patient records and biometry events in Zeiss Forum will be shown in the main menu and on Biometry Events (if that event was added to OpenEyes by Forum).'
// but OphInBiometry/views/default/view.php:29 still:
if (!empty($sop) && \SettingMetadata::model()->getSetting('enable_forum_integration') === 'on') {
    array_unshift($this->event_actions, EventAction::link('Open In Forum', ('oelauncher:forumsop/' . $sop), ...));
```

## S-68: JSON menu activation (CITO) fails silently on any non-JSON response: popup flashes and closes with no error (medium confidence)

Module: core menu activation script (OE-18089/OE-18088) - `protected/views/base/_menu.php:104`

The generic data-activation='json' click handler does `fetch(...).then(r => r.json()).then(...)` and its `.catch` only closes the pre-opened popup - it never shows a message. actionActivate throws CHttpException (400 'Patient ID is required', 403 permission, 404 'This menu item is no longer available' when an admin deactivates/deletes the item mid-session - the cached menu can keep serving the stale link for up to 1h per MenuHelper's 3600s session cache) and an expired session 302s to the HTML login page; in every one of those cases the response body is an HTML error page, response.json() rejects, and the user's only feedback for clicking 'Open in CITO' is a popup window that opens and instantly closes. The intended error path (OpenEyes.UI.Dialog.Alert with data.message) is only reachable when the server returns well-formed JSON with success=false.

Predicted predicate: Clicking 'Open in CITO' when the activate endpoint returns an error page (e.g. the menu item was deactivated after the menu was cached, or the session expired) opens a blank popup that immediately closes, with no alert dialog and no message anywhere on the page.

```
.then(function (response) { return response.json(); })
...
.catch(function () {
    if (popup) {
        popup.close();
    }
});
```

## S-69: Handheld existing-draft banner has dead Yes/No buttons and no data attributes (low confidence)

Module: core-event-create - `protected/views/patient/event_content_handheld.php:27`

The handheld create layout renders the same existing-draft banner as event_content.php but WITHOUT the data-patient-id/data-event-type-id/data-context-id/data-service-id attributes (present at event_content.php:126-131) and without the existing-draft-url. Furthermore the only code that binds #js-load-existing-draft/#js-delete-existing-draft is OpenEyes.EventDraftController, which is instantiated solely in OphCiExamination's create.php/update.php/step.php - not in any handheld view. So on a handheld create page with an existing draft, the Yes/No buttons do nothing at all (no click handlers), and even if a handler existed the delete-then-create path would read undefined data attributes. Low severity in practice because only the exam module auto-saves drafts and exam does not use the handheld layout, but any module adopting drafts + handheld hits it immediately.

Predicted predicate: On a handheld event create page showing the 'existing draft' banner, clicking Yes or No does nothing (no navigation, no banner dismissal).

```
<button id="js-load-existing-draft" class="button blue hint">Yes</button>
```

## S-70: AddNew.Controller createEvent TypeError when ticketMoveController exists without the moveTicket panel DOM (low confidence)

Module: core-event-create - `protected/assets/js/OpenEyes.Event.AddNew.Controller.js:107`

createEvent() guards only on `typeof window.ticketMoveController !== "undefined"` and then unconditionally chains `document.querySelector('.PatientTicketing-moveTicket').querySelector('[name=to_queue_id]').value`. ticketMoveController is a global set once by the PatientTicketing JS; on pages where the script is loaded but the .PatientTicketing-moveTicket panel is not rendered (e.g. ticket already moved/closed, or panel hidden for the user's queue permissions), querySelector returns null and the chained call throws a TypeError - the click on the quick-add event icon silently does nothing (error only in console), so the user cannot create the event from that button.

Predicted predicate: On a patient page where PatientTicketing scripts are loaded but no move-ticket panel is present, clicking the add-new-event quick button throws 'Cannot read properties of null' in the console and no create page opens.

```
if (typeof window.ticketMoveController !== "undefined" && document.querySelector('.PatientTicketing-moveTicket').querySelector('[name=to_queue_id]').value !== "") {
```

## S-71: 'Cancel and discard' triggers createEvent with undefined banner data (low confidence)

Module: core - `protected/assets/js/OpenEyes.EventDraftController.js:208`

OE-16555 (723f7f614e) rewrote deleteExistingDrafts' success callback to always call OpenEyes.Event.AddNew.Controller().createEvent() with data attributes read from #js-existing-draft-banner. deleteExistingDrafts is shared by two paths: the banner 'No (delete draft)' button (banner present, works) and the discard-dialog 'Cancel and discard' button (line 84, deleteExistingDrafts(false)). The discard dialog can only ever be reached when the banner is NOT on the page (the draft-cancel button only shows once autosave runs, and autosave is disabled whenever the banner is present), so every discard runs createEvent with $(...).data() of an empty set: all undefined. createEvent does window.stop() then window.location = '/patientEvent/create?patient_id=undefined&event_type_id=undefined&context_id=undefined&service_id=undefined', racing the subsequent cancel-anchor click; if the assignment wins (slow handler/browser scheduling) the user lands on an error page instead of the patient landing page.

Predicted predicate: Clicking 'Cancel and discard' in the discard-restore-point dialog issues a navigation/request to /patientEvent/create?patient_id=undefined&event_type_id=undefined&context_id=undefined&service_id=undefined; when it wins the race with the cancel link the browser shows an error page instead of the patient landing page.

```
success: (response) => {
    let controller = new OpenEyes.Event.AddNew.Controller();
    controller.createEvent({
        patient_id: $(this.options.existingDraftBannerSelector).data('patient-id'),
        event_type_id: $(this.options.existingDraftBannerSelector).data('event-type-id'),
```

## S-72: Sidebar event entry reads $event->institution->name unguarded - fatal on events with NULL institution (low confidence)

Module: core - `protected/views/patient/_single_episode_sidebar_event_entry.php:38`

Line 38 renders data-institution="<?= $event->institution->name ?>" with no null guard, while line 60 of the same partial renders <?= $event->institution ?? '-' ?> - the null-coalescing there is concrete evidence the authors expect events with a NULL institution relation (legacy/imported events predating the institution column). On PHP 8+, ->name on null throws Error, and because this partial renders inside the beginCache fragment loop, one such event aborts rendering of the whole patient sidebar.

Predicted predicate: Opening any event or episode view for a patient that has at least one event with institution_id NULL produces a 500/blank sidebar instead of the event list.

```
line 38: data-institution="<?= $event->institution->name ?>"
line 60: <?= $event->institution ?? '-' ?>
```

## S-73: Expand-collapsed-element handler matches by empty data-element-id on create - wrong element expanded once a second collapsed-by-default element exists (low confidence)

Module: core - `protected/assets/js/events_and_episodes.js:21`

The OE-17660 collapsed-element stub button handler does document.querySelector('section.collapsed[data-element-id="' + element_id + '"]') where element_id comes from the stub's data attribute. On the create action every element is new, so data-element-id is empty for all of them and the selector is section.collapsed[data-element-id=""] - querySelector returns the FIRST such section regardless of which stub was clicked. Latent today because only Element_OphTrOperationbooking_Diagnoses overrides isCollapsedByDefault() to true, so at most one collapsed section exists per form; the moment a second element type opts in, clicking the second stub expands (and hides the stub of) the first element instead.

Predicted predicate: On an event create form containing two or more collapsed-by-default elements, clicking the expand button of the second stub expands the first collapsed element while the second stays hidden.

```
let element_id = ...dataset.elementId; // '' for new elements on create
document.querySelector('section.collapsed[data-element-id="' + element_id + '"]').style.display = 'block';
```

## S-74: swapElement crashes and leaves the Visual Acuity element permanently disabled when the sidebar has no VA menu entry (low confidence)

Module: examination-element-js - `protected/modules/OphCiExamination/assets/js/VisualAcuity.js:405`

swapElement assigns $parentLi only inside 'if ($menuLi)' (lines 390-402), but PatientSidebar.findMenuItemForElementClass (OpenEyes.UI.PatientSidebar.js:334-347) returns undefined when the sidebar tree - built from the CURRENT workflow step's element set - has no entry for the class (e.g. an open VA/NearVA element brought in by copy-forward or saved under a different workflow step whose set lacks it). Line 404 has already faded the element to opacity 0.5 and disabled every select/input/button before line 405 throws 'TypeError: $parentLi is undefined', so the AJAX swap never fires and the element is left permanently greyed out and uneditable. Triggered by the unit dropdown change or the Simple/Full 'va-change-complexity' toggle (lines 71-81).

Predicted predicate: On an examination whose sidebar lacks a (Near) Visual Acuity entry while the element is open, changing the VA unit or record mode leaves the element at half opacity with all fields disabled and a TypeError in the console; the form change never happens.

```
element_to_swap.css('opacity', '0.5').find('select, input, button').prop('disabled', 'disabled');
const element = $parentLi.clone(true);  // $parentLi is undefined when $menuLi was falsy
```

## S-75: Clicking a mandatory entry in the Manage-elements popup inserts a duplicate of the already-open mandatory element (low confidence)

Module: examination-element-js - `protected/assets/js/OpenEyes.UI.ManageElements.js:152`

Open mandatory elements never receive the 'added' class in the popup (buildTreeChildList lines 323-330 skips 'added' for 'mandatory' items), and the popup click path has no mandatory guard: addSelectedElement (lines 146-158) sees !hasClass('added') and calls addElementItem, which unconditionally runs addElement($item.clone(true),...) - and nested_elements.js addElement has no duplicate check, it simply fetches ElementForm and inserts the section by display order. Result: a second copy of a mandatory element that is already on the form, with colliding POSTed field names. Caveat: could only be prevented by CSS pointer-events on li.mandatory, and no such rule exists in the repo's stylesheets (compiled theme package not in tree), so JS-wise the path is open.

Predicted predicate: Opening the Manage-elements popup on an examination and clicking an entry styled as mandatory inserts a second identical section of that mandatory element into the form.

```
if (loadItem) {
    if (!$item.hasClass('added')) {
        this.addElementItem($item);   // no 'mandatory' check anywhere in this path
    } else {
        this.removeElementItem($item);
    }
}
// buildTreeChildList: if open AND mandatory -> 'added' is never applied
```

## S-76: $.isNumeric(iolPower); is a no-op statement - the guard block below always runs (low confidence)

Module: OphTrOperationnote - `protected/modules/OphTrOperationnote/assets/js/module.js:1652`

In loadBiometryElementData, the intended `if ($.isNumeric(iolPower)) { ... }` was written as an expression statement `$.isNumeric(iolPower);` followed by a bare block, so the assignment to #Element_OphTrOperationnote_Cataract_iol_power executes unconditionally whenever iolPower is truthy. The parallel predictedRefraction branch above (lines 1635-1645) shows the intended pattern: it explicitly special-cases the non-numeric sentinel 'None'. iolPower comes from .js-iol-display's text (form_Element_OphTrOperationnote_Biometry_Data_Fields.php:68 renders the raw iol_power_<side> attribute with no fallback), and unlike predictedRefraction it is not .trim()'d (line 1623), so any non-numeric or whitespace-padded biometry value is copied verbatim into the IOL power input on load and on every eyedrawAfterReset. Certain dead check; observable impact limited to biometry data that carries non-numeric iol power, hence low confidence as a UI-visible bug.

Predicted predicate: When the highlighted biometry eye shows a non-numeric IOL power value, the Cataract element's IOL power input is populated with that non-numeric text on page load

```
if (iolPower && (nonzero_iol_power || is_templated)) {
    $.isNumeric(iolPower);
    {
        $("#Element_OphTrOperationnote_Cataract_iol_power").val(iolPower);
    }
}
```

