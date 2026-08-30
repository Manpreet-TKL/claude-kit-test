# Replay OpenEyes candidate import

- Imported: 2026-08-30.
- Source: `/home/toukan/oe-sample-db/replay/BUGS.md`.
- Scope: O1 through O96, compacted from the replay project's OpenEyes and deployment ledger.
- Status: unverified against the current target. No entry in this file counts toward the verified target.
- Promotion rule: independently reproduce on the pinned target, pass R1 and R2, then deduplicate by terminal predicate.
- Privacy: source text was compacted and obvious sample record identifiers were omitted.

### O1: Patient registration and patient update

- Candidate state: unverified clinical product candidate.
- Symptom: Every successful save of the patient CRUD form writes one episode_version and one event_version row whose base episode / event row never exists. Confirmed by exact counts across 4 registrations on a clean instance: episode +0, event +0, episode_version +4, event_version +4, orphan count 0 before and exactly 4 after. Re-confirmed on the update route (walk 13, marking a patient deceased): episode_version +1 / event_version +1, both orphans, on a patient who...
- Impact or evidence: Nothing - but it silently inflates the two biggest version tables, and any generator that models version rows as "one per save of a real row" will be wrong. It is per save, not per patient, so the source DB's share is a function of edit volume as well as of its 2.14M patients....
- Original status: open, worked around (measure with exact counts, not auto_increment)
- Source location: `BUGS.md:350`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O2: Examination

- Candidate state: unverified clinical product candidate.
- Symptom: Loading the create form is already a write: it creates the episode and an event_draft before the clinician has entered anything. Module-specific, not base-controller behaviour: loading the Intravitreal injection create form on the same instance writes no event_draft at all - only audit and user_session rows. Abandoning the form leaves the episode behind, and a later run on the same patient opens on a "load existing draft?" prompt that blocks the form...
- Impact or evidence: Any walk that opens an Examination form and does not save leaves a permanent episode with no events - a shape that also exists in the source DB and must not be assumed to mean "clinical activity happened".
- Original status: open, worked around (dismissDraftPrompt)
- Source location: `BUGS.md:349`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O3: Examination / Diagnoses

- Candidate state: unverified clinical product candidate.
- Symptom: The save is refused with "Please add a diagnosis or acknowledge that no updates are needed", but the acknowledgement control it names is not on the page. NoEntryConfirmation.vue renders the checkbox only when !mandatoryForSpeciality, and Glaucoma makes disorder data mandatory - so the error offers a route the UI has deliberately removed.
- Impact or evidence: Nothing, once you know: adding a real diagnosis is the only route. Costs a debug loop per person who meets it, because the obvious next move (find the checkbox) cannot succeed.
- Original status: open, worked around (walk 03 adds a diagnosis when the checkbox is absent)
- Source location: `BUGS.md:348`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O4: Device Usage Record

- Candidate state: unverified clinical product candidate.
- Symptom: Saving the create form with no input returns the generic "Application Error ... please contact support" page with an incident id, not a validation message. Every other module in the sweep returned a field-level error for the same move.
- Impact or evidence: The walk cannot learn what the form requires from the form, so this event type needs its requirements read out of the source instead.
- Original status: open
- Source location: `BUGS.md:347`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O5: Lab results

- Candidate state: unverified clinical product candidate.
- Symptom: The Result entry's unit box declares no maxlength and its column is very short, so an over-long value is not truncated by the browser and not caught by validation - it reaches the INSERT and returns the generic "Application Error" page. SQLSTATE[22001] ... Data too long for column 'unit', then Exception: Unable to save element Element_OphInLabResults_Entry from BaseEventTypeController.php:2014. The same shape will exist on every short varchar OE renders...
- Impact or evidence: Nothing, once the walk caps its own input - but a user who pastes a phrase into a unit box gets an incident id instead of "too long".
- Original status: open, worked around (walk 06 caps text at the declared maxlength and uses a short token where none is declared)
- Source location: `BUGS.md:346`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O6: Operation note / auto-generated correspondence

- Candidate state: unverified clinical product candidate.
- Symptom: Ticking "generate GP letter after op note" on a patient with no GP saves the op note and creates no letter and no warning. The save returns success, the sidebar shows one new event, and the only trace is protected/runtime/application.log: [Error Message] => GP letter could not be created because the patient has no GP. The same tick on a patient who has a GP writes a Correspondence event, three document_ families and an esign row.
- Impact or evidence: Silent data loss of the clinician's intent, and for this project a footprint that changes by a whole event type depending on a patient attribute the form never mentions. It also means "how many op notes generated a letter" in the source DB is a function of GP coverage, not of...
- Original status: open
- Source location: `BUGS.md:345`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O7: Validation display

- Candidate state: unverified clinical product candidate.
- Symptom: A field error attached to a collapsed or off-screen element renders the summary header "Please fix the following input errors:" with nothing under it. The message exists in the DOM but has no bounding box, so it is invisible both to the user who has not scrolled and to any scraper that filters on visibility. Seen on Op note ("Anaesthetic: Type cannot be empty") and again on the auto-generate signature refusal.
- Impact or evidence: The form appears to refuse for no reason. Cost two debug runs before the scraper was changed to read the named error containers regardless of visibility.
- Original status: open, worked around (scrapeErrors also scans .alert-box li, .field-error, .errorMessage)
- Source location: `BUGS.md:344`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O8: Operation note / adder

- Candidate state: unverified clinical product candidate.
- Symptom: The procedure adder's subsections column holds a single option labelled "None" and it is the left-most, first-listed option in the dialog. Picking it is indistinguishable from picking a procedure until the save is refused, and on the booked route it is not refused at all - the note inherits the booking's procedures and saves with the operator's actual choice silently discarded.
- Impact or evidence: A walk (or a clinician) that clicks the first option gets a note whose procedure list is not what they chose.
- Original status: open, worked around (walk 11 picks from the select column explicitly)
- Source location: `BUGS.md:343`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O9: Intravitreal injection / optional elements

- Candidate state: excluded provenance record - source says this is not a product defect.
- Symptom: Five element types have no add-link and are unreachable. Not a defect - withdrawn. The five (Treatment, Anaesthetic, Anterior segment, Post-injection examination, Complications) are element_type.default = 0 and views/default/_optional_element.php is empty on purpose: the module adds them from its own JS. Every .js-inject-action click calls toggleElements(eye, add = action in [inject, inject-other]), which fetches each default = 0 element for that eye only...
- Impact or evidence: None. The original observation - four elements on the create form - was true and the inference from it was wrong: the sweep never clicked an inject action, and that click is the whole mechanism. Recorded rather than deleted because the mistaken workaround cost more than the bug...
- Original status: wont-fix - not a bug
- Source location: `BUGS.md:342`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O10: Intravitreal injection / injection order sequence

- Candidate state: unverified clinical product candidate.
- Symptom: Saving an unbooked injection with consent option "Consented" posts additional[<side>][OphCiExaminationInjectionOrderSequence][consent_option_date] as an empty string, because that date lives in a CHtml::hiddenField(..., null, ...) that only the drug-change handler ever writes - and it writes it only when the drug already has an active consent. assignConsentData then passes '' through Helper::convertNHS2MySQL into a DATE column. Under STRICT_TRANS_TABLES...
- Impact or evidence: The save. A clinician who picks the top option of a four-item dropdown gets an incident id, not a validation message. Blank is not an escape - the unbooked route refuses with "Consent Option must be selected for Unbooked injection" - so the walkable set is the three date-free...
- Original status: open, worked around (walk 16 sets the consent select itself, after the generic fill)
- Source location: `BUGS.md:341`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O11: Deployment / sql_mode

- Candidate state: unverified clinical product candidate.
- Symptom: The replay instance runs STRICT_TRANS_TABLES and the source instance does not (ALLOW_INVALID_DATES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION), both MariaDB 11.8 from the same deploy template. Wherever OE posts an empty string into a date or numeric column, the source coerces and warns while the replay 500s. Not a defect in either database - a defect in relying on the mode.
- Impact or evidence: Any walk that trips it, and more importantly the fidelity argument: a form the source accepts can be unreachable on the replay instance for a reason that has nothing to do with the form. Found through O10; there is no reason to think it is the only instance.
- Original status: open, blocker B8
- Source location: `BUGS.md:340`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O12: Messaging / out-of-office check

- Candidate state: unverified clinical product candidate.
- Symptom: Picking any recipient fires checkUserOutOfOffice, which posts YII_CSRF_TOKEN: $('input[name="YII_CSRF_TOKEN"]').val() - the first token input in the DOM, not the page's own form and not the JS global YII_CSRF_TOKEN. On the patient layout the first one belongs to the family-history widget (#edit-family-history), which is served from a cached fragment: across two separate logins its token was byte-identical while the live token changed. The POST is refused...
- Impact or evidence: Every message on every patient, for as long as the fragment is cached (APCu here). The modal greys the page, so the next click - Preview & check - resolves but is never actionable, which reads as a broken selector rather than a failed request. The check itself never runs, so no...
- Original status: open, worked around (walk 19 dismisses the alert immediately after picking a recipient)
- Source location: `BUGS.md:339`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O13: Messaging / out-of-office check

- Candidate state: unverified clinical product candidate.
- Symptom: The same $.ajax call posts event_date: $('extra-info .js-event-date').val(). The first selector is missing its . - extra-info is a class, not a tag - so the expression matches nothing and event_date posts as undefined on every request. The server-side handler reads it to decide whether the recipient is out of office on the day of the event.
- Impact or evidence: Nothing visible, and that is the problem: even once O12 is fixed, the out-of-office window would be evaluated against no date at all. Found by reading the source while diagnosing O12, not by the walk - a silent defect underneath a loud one.
- Original status: open
- Source location: `BUGS.md:338`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O14: Add Event / subspecialty chooser

- Candidate state: unverified clinical product candidate.
- Symptom: #js-add-subspecialty-btn signals "not yet usable" with a class (disabled, pointer-events: none) and no disabled attribute. A click therefore lands on the wrapper div rather than being refused, so every automated caller - and every user whose pointer events are synthesised - gets silence instead of a refusal.
- Impact or evidence: Any subspecialty with more than one service firm is unclickable until a service is picked, with no feedback saying so. Cost a debug loop on Medical Retina; the error names <div class="change-subspecialty"> intercepting pointer events, which is a true statement about the wrong...
- Original status: open, worked around (T13)
- Source location: `BUGS.md:337`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O15: Therapy application / diagnosis adder

- Candidate state: unverified clinical product candidate.
- Symptom: The per-eye diagnosis adder offers the intersection of the patient's recorded ophthalmic diagnoses with ophcotherapya_disorder_list. When that intersection is empty the adder still opens - empty - and the save is refused with "Right Diagnosis cannot be blank", a message about a field the form will never let you fill.
- Impact or evidence: The precondition (a previous event naming an allowed disorder) is stated nowhere the operator can see, and the two symptoms of missing it - an empty dialog and a blank-field error - both point away from it.
- Original status: open, worked around (walk 21 fails fast with an explicit message; walk 03 gained OE_DIAGNOSIS to establish the precondition)
- Source location: `BUGS.md:336`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O16: Therapy application / NICE compliance

- Candidate state: unverified clinical product candidate.
- Symptom: Saving writes one ophcotherapya_patientsuit_decisiontreenoderesponse row per question node in the chosen treatment's decision tree, per eye, whether or not that node was ever reached. A four-question application on Lucentis stores 20 rows, sixteen of them empty. Confirmed by delta and by reading the rows back: only the answered nodes carry values.
- Impact or evidence: Nothing clinically, but it makes a vocabulary choice into a size knob - the same walk costs 0 extra rows on Avastin (tree 1, no questions) and 40 on a both-eyes Lucentis. Any generator that draws treatments uniformly instead of from the source mix will miss this table by a...
- Original status: open - product behaviour, recorded because the atlas has to predict it
- Source location: `BUGS.md:335`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O17: Examination / Diagnoses adder

- Candidate state: unverified clinical product candidate.
- Symptom: The disorder search box runs its query on keyup. Setting the value programmatically - which is what fill() does, and what any assistive tooling or paste-by-script does - fires input and change but never keyup, so the value sits in the box and the results list stays empty. There is no "no results" state either: an empty list and an unsearched list look identical.
- Impact or evidence: Nothing for a human typing. For the harness it meant the named-diagnosis route silently produced nothing, which is the failure mode that costs the most to diagnose because the page looks correct.
- Original status: open, worked around (walk 03 uses pressSequentially)
- Source location: `BUGS.md:334`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O18: Admin / edit user

- Candidate state: unverified clinical product candidate.
- Symptom: actionEditUser treats the POST as the complete new state of two sets it never shows as such. saveRoles($posted ?: []) is a full replace, so an absent or empty User[roles][] revokes every role the user holds; then UserAuthentication::model()->deleteAll() removes every user_authentication row whose id was not posted, which for the only account on an instance is a lockout. Both happen without a confirmation step, and the roles widget hides its state in...
- Impact or evidence: Nothing for a human who loads the form and submits it - the fields are pre-populated. It is a live hazard for anything that constructs the POST itself, and it means a walk that grants one role has to carry all 36 others plus both authentication rows through the request or...
- Original status: open, worked around (walk 22 reads both sets first, refuses to submit on a zero read, and re-reads afterwards to warn on anything revoked)
- Source location: `BUGS.md:333`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O19: Add Event dialog / caching

- Candidate state: unverified clinical product candidate.
- Symptom: <ul id="event-type-list"> is wrapped in beginCache('add_event_dialog_event_type_list', ['duration' => 3600, 'varyByRoute' => false, 'varyBySession' => true]). The list is filtered per user by checkAccess, so it is permission-dependent output cached for an hour against the session that first rendered it. A role granted to yourself, or to a colleague already logged in, does not appear until the cache expires or the session ends.
- Impact or evidence: Nothing for the harness - every walk logs in fresh, so it never sees a warm cache. It matters for anyone who grants a permission and then checks whether it worked in the same session, which is the obvious thing to do: the answer is "no" for up to an hour, with no indication that...
- Original status: open - product behaviour, recorded because it makes a working walk look broken
- Source location: `BUGS.md:332`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O20: OphInGeneticresults / empty date

- Candidate state: unverified clinical product candidate.
- Symptom: Leaving Result Date blank posts result_date='', and nothing between the form and the database converts it to NULL. MariaDB in strict mode refuses '' for a date column, so the save dies as CDbCommand::execute() failed: SQLSTATE[22007] Incorrect date value: '', wrapped as Exception: Unable to save element Element_OphInGeneticresults_Test at BaseEventTypeController.php:2014, and the operator gets the generic Application Error page with a support reference.
- Impact or evidence: An optional field, left empty, produces a 500 rather than a saved event or a validation message. The event is lost. For the harness it is worse than a validation failure, because the error text names nothing at all - the field only became identifiable from the application log.
- Original status: open, worked around (walk 25 always sends a date)
- Source location: `BUGS.md:331`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O21: OphInGeneticresults / required fields

- Candidate state: unverified clinical product candidate.
- Symptom: Homozygosity is mandatory - the save is refused with "Homozygosity cannot be blank" - and the form gives no indication of it. It renders as an unmarked radio pair among a dozen genuinely optional fields, next to gene_id, which is marked. The same pattern shows up in OphInDnasample, where Volume is mandatory, range-validated 1..99, carries no unit and has no default.
- Impact or evidence: Each unmarked required field costs a full save-and-read cycle to find, and they are found one at a time because the form stops at the first failure. For the atlas it means a module's field list cannot be trusted to say which fields the generator must supply - only a refused save...
- Original status: open - recorded so the walk carries the fields explicitly
- Source location: `BUGS.md:330`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O22: Genetics admin / Crud list screens

- Candidate state: unverified clinical product candidate.
- Symptom: /Genetics/gene/list and /Genetics/study/list call $admin->getSearch()->setDefaultResults(false), so they render the column headers, the add/delete button bar and a Total of N items footer - with no data rows - until a search is submitted. The footer count is computed from the real total, so the page simultaneously says "1 item" and shows none.
- Impact or evidence: An unsearched list and a genuinely empty table are indistinguishable, in a screen whose whole purpose is to tell you whether the thing you just created exists. Walk 23 reported "not listed" for a study that had saved perfectly well, and the DB was the only way to tell the two...
- Original status: open, worked around (walk 23 submits a search on the exact name before reading back)
- Source location: `BUGS.md:329`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O23: Examination / Clinical Outcome

- Candidate state: unverified clinical product candidate.
- Symptom: Element_OphCiExamination_ClinicOutcome::afterSave() updates episode.episode_status_id only when $this->event->isLatestOfTypeInEpisode(), and getLatestOfTypeInEpisode() orders by event_date DESC, created_date DESC. Saving an Examination with an earlier event_date than an existing one in the same episode therefore stores the outcome element and its entry row and moves the episode not at all - no message, no warning, a green save.
- Impact or evidence: Nothing for forward-in-time clinical use. It is a correctness trap for any backfill, data migration or replay: the clinical record says "discharged" and the episode says "new", and the two disagree permanently because nothing re-derives the status. For this project it forces...
- Original status: open - product behaviour, worked around by ordering
- Source location: `BUGS.md:328`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O24: Examination / IOP adder markup

- Candidate state: unverified clinical product candidate.
- Symptom: Every other itemset in the adder component labels its option list with data-id matching the itemset name. reading_value does not: splitIntegerNumberColumns emits one 0-9 ul per digit and neither carries a data-id, so ul[data-id="reading_value"] - the selector the same component's own contract implies - matches nothing. The columns are reachable only through the TD at the index of th[data-id="reading_value"].
- Impact or evidence: Nothing for a human. For any caller driving the widget by its documented shape it is a silent zero-match on the second-largest element family in the source (2.99M elements, 7.6M readings), and the symptom is an empty dialog rather than an error.
- Original status: open, worked around (walk 03 resolves the column by header index)
- Source location: `BUGS.md:327`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O25: Patient registration / save redirect

- Candidate state: unverified clinical product candidate.
- Symptom: The save handler is window.location.href = data.redirect, with no check that data is the JSON the success branch renders. When it is not, the assignment writes the string "undefined", which the browser resolves against /patient/create as /patient/undefined - a 404 for an action that has already committed. Observed once: patient [sample identifier omitted] was created and the walk landed on http://web/patient/undefined.
- Impact or evidence: The patient exists and the operator is told nothing except "unable to find the requested action". Any caller that judges the save by where it landed records a failure and, if it retries, is then blocked by duplicate detection on a patient it did create.
- Original status: open, worked around (walk 01 accepts either destination and recovers the id from the save response when the URL carries none)
- Source location: `BUGS.md:326`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O26: Patient registration / GP and practice autocompletes

- Candidate state: unverified clinical product candidate.
- Symptom: The same keydown-only search as O17, on the two fields that gate an entire event family. fill() sets the visible text, fires input/change, and the menu never opens - so nothing is ever picked, gp_id/practice_id stay NULL, and the save succeeds because both fields are optional. There is no error and no empty-menu state; the patient reads as complete on the summary screen.
- Impact or evidence: Every patient this harness had registered - five for five - carried NULL for both, and the effects surfaced somewhere else entirely: Correspondence opened behind a modal alert and could only save drafts, and bug O6's silent letterless op note was not a rare configuration but the...
- Original status: open, worked around (pickAutocomplete types with pressSequentially and asserts the hidden id)
- Source location: `BUGS.md:325`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O27: Correspondence / esign PIN entry

- Candidate state: unverified clinical product candidate.
- Symptom: The PIN box is data-test="event-auto-pin-entry" and it means it - entering the sixth digit submits on its own. The PIN sign button next to it stays enabled while that request runs, but the page is greyed behind a spinner, so clicking it is an actionability timeout on work that has already succeeded. Meanwhile every action button goes disabled/inactive for the duration.
- Impact or evidence: Three separate misreadings from one design: click the button and you time out; check Save immediately after and it reports disabled; check whether the PIN box vanished and it has not, because the widget is replaced in place. Each one points somewhere different and none of them...
- Original status: open, worked around (walk 26 fills, waits for the confirmation, and only falls back to the button if nothing happened)
- Source location: `BUGS.md:324`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O28: Correspondence / esign

- Candidate state: unverified clinical product candidate.
- Symptom: Save draft is disabled permanently the moment a signature lands, with no way to remove the signature on the same form. Signing is therefore a one-way door taken before the operator chooses how to save.
- Impact or evidence: A letter signed by mistake cannot be parked as a draft; the only exits are finalise or cancel. For the generator it means the draft/finalised choice must be made before signing, which is the reverse of how the form reads.
- Original status: open
- Source location: `BUGS.md:323`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O29: Patient summary / deceased patients

- Candidate state: unverified clinical product candidate.
- Symptom: The Add Event control is not rendered for a patient with is_deceased = 1 - not disabled, not explained, absent. The header carries class deceased and nothing else says why the button a moment ago is gone.
- Impact or evidence: Nothing clinically - the record is closed on purpose. It matters to anything scripted or assistive, because the failure presents as "the page never finished loading": the walk that met it timed out for 30s waiting on #add-event. For the atlas it is a hard ordering constraint -...
- Original status: open - product behaviour, recorded because it dictates scenario order
- Source location: `BUGS.md:322`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O30: Operation note / event DTO date cast

- Candidate state: unverified clinical product candidate.
- Symptom: A backdated Operation note is written and then thrown away. BaseEventTypeController::setEventDate() deliberately stores a date-only event_date for a historic event ("Unset the timestamp if the created event is an historic event", line 1753); Element_OphTrOperationnote_ProcedureList::afterSave() then maps the event through EventMapper, whose cast for event_date is AttributeCastType::DateTime -> DateTime::createFromFormat('!Y-m-d H:i:s', '2023-05-09') ->...
- Impact or evidence: Every backdated Operation note, and with it any surgical story with a real timeline: 467k events in the source, all of them historic. Confirmed on patient [sample identifier omitted] - 2023-05-09 rolled back and burned event id 3687116, the identical run with no date saved as...
- Original status: duplicate of O54, worked-around. The two entries are the same defect found twice, six weeks apart, from opposite ends: this one from a hand-run backdated save, O54 from a story CSV whose blank date had been hiding it. The conclusion recorded here - "no frontend workaround; the date input is date-only by construction" - was wrong, and wrong in an instructive...
- Source location: `BUGS.md:321`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O31: Child events / episode assignment

- Candidate state: unverified clinical product candidate.
- Symptom: A child event's create URL carries patient_id and parent_event_id and no episode, so OE files it under whatever episode the session firm is currently on. Confirmed twice on patient [sample identifier omitted]: DNA sample 3687057 sits in the Glaucoma episode and its children 3687119 and 3687120 landed in the Cataract one, purely because the session had been left on 1 Stop Cataract by an earlier walk. The Add Event dialog's own context step does not help -...
- Impact or evidence: A child event can end up in a different episode from its parent, which breaks the assumption that an episode is one coherent care story, and does it silently: both events render normally, on the same patient, under different tags. For the replay it means the session context is a...
- Original status: open, worked around (setContext() sets site and context from the banner's Change Context before the child is created; event 3687121 then filed correctly)
- Source location: `BUGS.md:320`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O32: Genetic results / conditional requirement

- Candidate state: unverified clinical product candidate.
- Symptom: Element_OphInGeneticresults_Test carries ['exon', 'validateForMethod', 'method' => 'Sanger'], so choosing the Sanger method silently makes Exon mandatory. Nothing on the form marks it, and the message the failed save returns is This is required when then method is set to Sanger - reported against Test, not against Exon, and with the typo intact.
- Impact or evidence: Not fatal, but the error names neither the field nor a fix, and Sanger is the method a generator is most likely to pick first. Worth recording because the pattern - a requirement created by another field's value, announced only after a save, attributed to the element rather than...
- Original status: open, worked around (OE_EXON supplied whenever the method is Sanger)
- Source location: `BUGS.md:319`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O33: DNA extraction / storage box sizing

- Candidate state: unverified clinical product candidate.
- Symptom: A DNA extraction requires a storage address, the address is minted from inside the extraction form, and the form can only offer one if the box declares how far its letters and numbers run. All 264 seeded boxes ship maxletter and maxnumber NULL, so Storage::generateLetterArrays() builds its grid from range('A', null) and range('1', null), actionGetAvailableLetterNumberToBox returns {}, and the JS takes the else branch: both fields go disabled and no...
- Impact or evidence: The entire event type, on a stock instance. The operator sees a Box select that works, a Letter and a Number field that will not accept typing, and a required Storage select that stays empty - with nothing to connect any of it to an admin screen three menus away. 55k DNA...
- Original status: open, worked around (walk 29 sets the box sizes through DnaExtractionBoxAdmin first; walk 28 then mints addresses normally)
- Source location: `BUGS.md:318`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O34: Event creation / orphan episodes

- Candidate state: unverified clinical product candidate.
- Symptom: Opening an event create form in a subspecialty the patient has no episode in creates the episode immediately, before anything is saved, and nothing removes it when the save fails or the operator walks away. Five of the 26 episodes on walk-registered patients are empty this way - 601070, 601072, 601109, 601128 and 601133 - each carrying a firm, a status of 1 and zero events, indistinguishable from a real episode whose first event has not been entered yet....
- Impact or evidence: Nothing, but it inflates episode silently and asymmetrically: the replay is at 19% empty episodes against the source's 1.1% (410 of a 37,293-episode modulus sample), so any per-episode statistic is measured against a denominator the walks manufactured. The generator has to treat...
- Original status: Confirmed by readback
- Source location: `BUGS.md:317`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O35: Pathway / visit created by the saving event

- Candidate state: unverified clinical product candidate.
- Symptom: PathstepObserver::completeStep fires on event_created and instances the pathway lazily off the visit it can find. A create route that attaches the patient to the unbooked worklist during the save - the Operation note's emergency route does - therefore runs the observer before the visit row exists, and the visit is written with no pathway at all. Measured on patient [sample identifier omitted]: worklist_patient 31 written 16:03:01 alongside op note...
- Impact or evidence: Nothing in the walk - a later event repairs it - but it makes pathway not 1:1 with worklist_patient, which is exactly what a generator would assume: the source runs 1.05% short (259 of 24,704 visits, patient-modulus sample), and this ordering is a mechanism that produces...
- Original status: open - no workaround inside the route; the next event on the visit creates it
- Source location: `BUGS.md:316`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O36: Analytics / follow-up aggregate

- Candidate state: unverified clinical product candidate.
- Symptom: FollowupAnalysisAggregate::findLatestFollowUpElementEvent filters the outer query to examinations and then correlates its "is this the patient's latest?" subquery on lower(e3.name) like lower('%examination%'). e3 is the outer query's event_type alias; the subquery joins its own e6 and never uses it. Inside the subquery the predicate is constant-true, so MAX(e4.event_date) is the latest event of any type, and no examination matches it once a later event of...
- Impact or evidence: Measured on 2339904: CVI 3687164 dated 2026-01-20 removed the row examination 3687163 (2025-11-04) had created - followup_analysis_aggregate -1 on the certificate's save. So the table is not a ledger of outstanding follow-ups, it is "patients whose newest event is an examination...
- Original status: open
- Source location: `BUGS.md:315`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O37: Audit / login

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: One login writes two login-successful rows. Measured on a login-only probe: audit +2, user_session +1, both rows at the same second on /site/login. And a login-failed row appears within a second of every walk run that saves something - the examination, both bookings and the cancellation each produced one - while a run that only logs in, or one that loads a create form and closes, produces none. The harness has one password and never mistypes it, so no...
- Impact or evidence: Two multipliers on the largest non-version table in the source. Login rows are 13.81M of its 174M audit rows, and at two per login that is 6.6M logins, not 13.3M - a generator that writes one row per replayed login undercounts by half. The login-failed share matters more than...
- Original status: open - recorded, not diagnosed; the replay's own ratio (171 failed to 943 successful) is a harness artifact and must not be mined
- Source location: `BUGS.md:314`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O38: CVI / print + e-sign route

- Candidate state: unverified clinical product candidate.
- Symptom: OphCoCvi\DefaultController::printESign reads $primary_identifier->value (line 1185) straight off PatientIdentifierHelper::getIdentifierForPatient(getPrimaryIdentifierSetting(), ...), which returns null when the patient carries no identifier of the installation's primary display usage type. The secondary one two lines below is guarded (?? null); the primary is not. Every route that renders the certificate - print, printIssue and the sign=1 iframe the...
- Impact or evidence: Issuing a CVI, completely. canIssueCvi needs isSignedByPatient(), the patient signature is captured in an iframe on that exact route, and the iframe renders the error page - so the certificate can never leave draft. It is invisible in the source because config hides it:...
- Original status: open - worked around by config (walk 31 restores the source's mandatory), not by code
- Source location: `BUGS.md:313`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O39: E-sign / signature entered before a popup signature

- Candidate state: unverified clinical product candidate.
- Symptom: A PIN signature is held in the page until the event is saved, but the patient e-Sign popup posts its drawing to the server and the element then redraws from the server when it returns - so a PIN entered first is silently discarded. Measured on 3687174: PIN sign reported Signed at, the patient popup was then signed, and the redrawn element showed the patient signed and the consultant row back to offering PIN sign; the save wrote one ophcocvi_signature row,...
- Impact or evidence: Issuing a CVI, for anyone who signs in the order the form lists (the consultant row is row 1, the patient row is row 2). The certificate saves clean, offers no Issue action, and the missing half is a row that was on screen a moment earlier. Any two-signature element with one...
- Original status: open - worked around by ordering: walk 32 signs the popup signatory first, then the PIN
- Source location: `BUGS.md:312`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O40: Drug administration / who gave the dose

- Candidate state: unverified clinical product candidate.
- Symptom: administered_by and administered_time are written only by DrugAdministration.js:553 on the switch's change handler, from the browser's own new Date(). Both columns are safe in OphDrPGDPSD_AssignmentMeds::rules() with no required, neither model has a beforeSave/beforeValidate, and OphDrPGDPSD_Assignment.php:200 coerces a missing value to null rather than to the current user. So a post carrying administered = 1 with either field absent stores a dose given...
- Impact or evidence: Two things. Provenance: the only record of who gave a drug and when is client-supplied, from the client's clock - a browser an hour out writes an administration an hour out, and a backdated event still stamps today's wall clock, so administered_time is not on the same timeline...
- Original status: open - recorded, not worked around; the walks avoid it by clicking the control rather than the checkbox
- Source location: `BUGS.md:311`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O41: Drug administration / PGD-PSD definition form

- Candidate state: unverified clinical product candidate.
- Symptom: Four requirements on /OphDrPGDPSD/admin/addPGDPSD that the form does not state. (1) A definition must name a team or a user - saving with neither is refused with Team or User list cannot be blank, and neither section carries the asterisk every other required field on the page carries. (2) Choosing type PGD makes frequency, duration, dispense condition and dispense location mandatory per drug, and the failure is reported once per drug by drug name, not by...
- Impact or evidence: Nothing that a save-and-read cycle per requirement does not eventually clear, which is the point: the type radio also has to be set before the drugs are added, because switchType() only shows or hides the extra columns on the rows that exist when it runs. Same class as O21 - the...
- Original status: open, worked around (walk 34 sets the type first, fills every blank the adder left, orders condition before location, and defaults the user list to the operator)
- Source location: `BUGS.md:310`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O42: Cat-PROM5 / the score is computed by the browser

- Candidate state: unverified clinical product candidate.
- Symptom: DefaultController::actionCreate reads $_POST['CatProm5EventResult']['total_raw_score'] and maps that number to the Rasch measure via rowScoreToRaschMeasure. The raw score is computed client-side by the questionnaire's change handler and posted; nothing server-side ever recomputes it from the six stored cat_prom5_answer_results rows, and nothing validates that it could have come from them.
- Impact or evidence: A questionnaire whose stored score need not match its stored answers. In the product that is a data-integrity hole reachable by anyone who can post a form; for this project it is a trap with a specific shape - a generator that writes answers and scores independently gets a...
- Original status: open - recorded, avoided by construction
- Source location: `BUGS.md:309`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O43: Request forms / MANY_MANY assignment rows

- Candidate state: unverified clinical product candidate.
- Symptom: Every row Form's auto-updated relations write - ophcorequestform_form_status_assignment, ophcorequestform_administrator_user_assignment - is stamped created_date and last_modified_date of 1901-01-01 00:00:00, while the ophcorequestform_form row it belongs to carries the correct timestamp. Confirmed on both definitions this walk created, and confirmed in the source as well: all 166 status-assignment rows there carry the same 1901 date, so it has been...
- Impact or evidence: Small but not zero. 1901-01-01 is not a null - it survives every "when was this configured" query as a real answer, and any audit that orders config changes by date puts every request-form assignment before every other row in the database. For this project it is a fidelity...
- Original status: open - recorded, and reproduced deliberately (the walk does not correct it)
- Source location: `BUGS.md:308`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O44: Correspondence / salutation on a practice-only patient

- Candidate state: unverified clinical product candidate.
- Symptom: A patient with a practice but no named GP resolves the To recipient to the placeholder contact The General Practitioner (practice address, no person), and the form's salutation JS - which builds Dear <name>, from the recipient's contact name - leaves ElementLetter.introduction empty. Save draft accepts that; Save refuses with Letter: Salutation: Cannot be empty. So the same letter, unchanged, is valid as a draft and invalid as a letter, and the refusal...
- Impact or evidence: Nothing structural, once known - but it makes finalised-letter volume a function of GP coverage, exactly as O6 makes op-note-generated letters one. 28% of source patients have no GP, and this is the second write path that quietly changes shape for them.
- Original status: open, worked around (walk 26 fills the salutation only when the form left it empty; Dear Sir/Madam, by default, OE_SALUTATION/salutation to override)
- Source location: `BUGS.md:307`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O45: Examination / the form contract is per subspecialty, and it is minable

- Candidate state: unverified clinical product candidate.
- Symptom: Which elements an examination carries is not a property of the module: ophciexamination_workflow_rule maps (subspecialty, firm, episode status) to a workflow, ophciexamination_element_set holds its positions, and ophciexamination_element_set_item names the elements. Glaucoma's first position carries no Intraocular Pressure at all; Eye Casualty's carries three elements; Paediatrics renders twenty-one and no Diagnoses. Separately, element_type.required -...
- Impact or evidence: This was the dominant failure mode of the whole replay effort, and it presented differently every time: a validation refusal, a click timing out against <ul class="element-list"> intercepts pointer events, or a CSV value silently discarded. It is not a defect - it is site...
- Original status: open - recorded as a contract to mine rather than a bug; walks/dx-sections.js reads the rendered truth per subspecialty and lib/elements.js now treats mandatory as a third state
- Source location: `BUGS.md:306`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O46: Examination / a second virtual review while the first ticket is open returns a 500

- Candidate state: unverified clinical product candidate.
- Symptom: Saving Virtual Review calls PatientTicketing_API::createOrUpdateTicketForEvent, which opens with if (!isset($data['patientticket_queue'])) throw new RuntimeException('no queue id found in data') (PatientTicketing_API.php:532). The queue id is a hidden input the form only renders when the patient has a valid queue set to enter, and a patient already holding an open ticket has none - ClinicOutcomeEntry_event_edit.php:200 renders No valid queues available...
- Impact or evidence: It puts a hard shape on the scenario rather than blocking it: a virtual-review pathway is one open ticket at a time, and the next virtual review is only reachable once the ticket has been moved on through the PatientTicketing queue screens - a walk that does not exist yet. Story...
- Original status: open - recorded; the queue transition is listed as missing walk support, not as a blocker
- Source location: `BUGS.md:305`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O47: Version tables / an episode and a Document event are created and hard-deleted behind a plain registration

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: The registration-only story a5-registered-never-seen writes eight tables, and two of them are episode_version +1 and event_version +1 on a patient who has neither an episode nor an event. The rows are real and they name the patient: episode_version 601326 carries patient_id 2339993 (the row a5 registered), firm_id 302 (Glaucoma Clinic) and start_date equal to the second the registration saved; event_version 3687521 sits on episode [sample identifier...
- Impact or evidence: Nothing clinically - the patient registers, and no episode or event survives to confuse a later walk. It is a size-model defect: the version tables are 720M rows in the source and the predictor prices them per base row saved, so a per-registration pair that no base row accounts...
- Original status: closed 2026-08-16 - it is O1, seen from the other end, and the rows are gone. The isolating probe was never needed: O1 had already read PatientController::actionPerformReferralDoc and found the cause, and every count taken since agrees with it. The controller runs on every patient save, create and edit alike, not only on a save carrying a referral letter;...
- Source location: `BUGS.md:304`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O48: Patient registration / a duplicate identifier fatals to the generic error page

- Candidate state: unverified clinical product candidate.
- Symptom: Registering a patient whose hospital number or NHS number is already held by another record does not come back as a field error. The form posts, the save throws, and the browser lands on OpenEyes' generic Page not found screen carrying There has been a problem trying to access OpenEyes, please try again in a moment - the same page a bad route produces. Reproduced by re-running e6-documents-arrive against patients-gen3.csv row 94, whose identifiers cell...
- Impact or evidence: Nothing clinical - the duplicate is correctly refused, and refusing it is the right behaviour. What it blocks is diagnosis: a batch that loses a patient this way says nothing about why, and the only way to tell a genuine duplicate from a broken form is to go and look at the...
- Original status: open - and it is a rule the generator has to encode rather than a defect to work round: a row of a patients CSV carries fixed identifiers, so it is consumable exactly once. bin/mix.js already refuses to hand out a row whose dob postdates the story (T35); it does not yet track rows already spent in an earlier run, and at mirror scale the patients file is the...
- Source location: `BUGS.md:303`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O49: Build config / most subspecialties have no procedures assigned

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: proc_subspecialty_assignment is well populated for the surgical services - External and Cornea 66 each, Strabismus 38, Glaucoma 33, Medical Retina 31, Vitreoretinal 28, Cataract 24 - and effectively empty for the rest. Adnexal, Oncology, General Ophthalmology, Eye Casualty, Neuro-ophthalmology and Anaesthetics hold three each, and they are the same three every time: phacoemulsification with a lens, intravitreal injection, fluorescein angiography. Adnexal...
- Impact or evidence: Any surgical story in those six subspecialties. A listing, a consent and an operation note all draw their procedure from the subspecialty's assigned list, so an Adnexal lid operation cannot be walked at all - the clinic half of the pathway is writable and the theatre half is not.
- Original status: observed. The fix is a config walk that assigns a procedure to a subspecialty, which is the same shape as the other admin walks and would clear the whole family at once. Until then, the six subspecialties above are clinic-only in the catalogue and L3 is written that way on purpose
- Source location: `BUGS.md:302`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O50: Build config / the per-subspecialty prescriber shortlists are all the same five drugs

- Candidate state: excluded provenance record - source says this is not a product defect.
- Symptom: The prescription form offers a "common ophthalmic" column that is a per-subspecialty medication set - Common Uveitis drugs, Common Vitreoretinal drugs, Common Cataract drugs and eleven more. Every one of them holds the identical five entries (acetazolamide oral suspension, acetylcysteine, adrenaline, betamethasone, prednisolone acetate), and only Common Glaucoma drugs has been curated - it carries 19 real glaucoma agents. So the shortlist a prescriber...
- Impact or evidence: Nothing outright, but it caps what a prescription story can name from the fast column: any drug outside those five (or outside glaucoma) has to come from the whole-catalogue search column instead, which is a different control and a different cost. The source's prescription drug...
- Original status: observed, not a defect to fix here - it is what this build ships, and the atlas records it so a CSV author does not assume a name is reachable because it is clinically obvious
- Source location: `BUGS.md:301`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O51: Build config / eleven of the source's services do not exist on this instance

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: The build ships 17 subspecialties and the source uses 28. The eleven missing ones are not exotic: Optometry (64,953 episodes), Orthoptics (56,134), Genetics (43,266), Contact Lens (14,151), Electrophysiology Department (12,228), Ultrasound, Research, Support Services, Ocular Prosthetics, Multidisciplinary Team Meeting and Pharmacy, plus 53,879 episodes on a firm with no subspecialty at all. Two more differ by name only and are the same service - Accident...
- Impact or evidence: 12.8% of the source's 2.02M episodes cannot be placed in the right service, and the shortfall is concentrated rather than spread: Optometry, Orthoptics and Genetics alone are 8.2%. The catalogue's F1 genetics chain already works around it by running in General Ophthalmology,...
- Original status: observed. The remedy is the same shape as O49 and would clear both: an admin walk that creates a subspecialty, a service and a firm, after which every one of the eleven is a config CSV row rather than a gap. Worth doing before the mirror extraction, because the episode's service is the one field the structural mirror cannot swap after the fact
- Source location: `BUGS.md:300`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O52: OphCiExamination / every element validation error is reported twice

- Candidate state: unverified clinical product candidate.
- Symptom: A refused save lists each element error once bare and once prefixed with the element's label - Right side cannot be blank and then Refraction: Right side cannot be blank, Intended benefits cannot be blank and then Benefits and risks: Intended benefits cannot be blank, Please add a diagnosis or acknowledge that no updates are needed and then the same under Diagnoses:. Three separate investigations (T41, T43, T45) each began by counting the messages and...
- Impact or evidence: Not a data-fidelity problem and not worth reporting upstream, but it is the single most reliable way to misread a failed walk, so it belongs in the reading instructions for the logs: halve the error list before counting elements, and match on the prefixed copy because the bare...
- Original status: recorded - read the prefixed copies only
- Source location: `BUGS.md:299`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O53: OphCoCorrespondence / an internal referral posts an empty booking address unless the location dropdown is touched

- Candidate state: unverified clinical product candidate.
- Symptom: The Internal Referral letter type addresses a service rather than a person: the "To" row is fixed to contact_type = INTERNALREFERRAL and its address is the referral location's correspondence name. Nothing fills that address on the create form. assets/js/module.js wires it to the change event of #ElementLetter_to_location_id (the handler calls getSiteInfo and writes data.site.correspondence_name into #Document_Target_Address_0), and the only other source...
- Impact or evidence: The internal referral scenario - 3.0% of the source's letters, 147,355 rows, and the only letter shape whose recipient is not a contact. Worked around in walks/26-correspondence.js, which re-selects the current location and waits for the ajax; events 3688988-3688991 saved signed...
- Original status: worked-around
- Source location: `BUGS.md:298`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O54: OphTrOperationnote / an op note given any date but today dies in an unhandled exception

- Candidate state: unverified clinical product candidate.
- Symptom: BaseEventTypeController::setEventDate (line 1758) runs the posted date through Helper::convertNHS2MySQL, which returns a bare Y-m-d, and assigns that string straight onto the in-memory event. Element_OphTrOperationnote_ProcedureList::afterSave (line 212) then hands the same event to EventDTO through DTOMapperManager so it can dispatch ProcedureCompletedSystemEvent, and GetsDTOAttributes::parseDateTimeOrFail casts event_date with a strict !Y-m-d H:i:s:...
- Impact or evidence: Every op note in the source carries a clinical date and 467k of them exist, so an unfixable version of this would cap the whole surgical chain at the run day. Worked around in lib/event.js: the walk drives the datepicker as a person would, reads the value back, and then writes...
- Original status: worked-around
- Source location: `BUGS.md:297`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O55: OphTrOperationnote / the anaesthetic validator rejects data this product wrote

- Candidate state: unverified clinical product candidate.
- Symptom: Element_OphTrOperationnote_Anaesthetic::afterValidate enforces four rules, and the source violates two of them at scale. Rule 4 ("You must enter an other description when selecting LA and Other") is refused on 19,975 source rows - LA plus an is_other delivery - every one of which has a NULL description, because O56 means the column is never filled at all. Rule 1 ("If anaesthetic Type is GA then LA Delivery Methods must only be Other") is refused on 8,606...
- Impact or evidence: Two combinations of a five-option field, 4.3% and 1.8% of the source's op notes, cannot be written through this form at any date. The failure is loud (the save is refused with a named error), so it costs a run rather than a silent divergence - but it means the anaesthetic...
- Original status: open - recorded as a coverage limit, no workaround possible
- Source location: `BUGS.md:296`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O56: OphTrOperationnote / the anaesthetic "other description" can never be NULL

- Candidate state: unverified clinical product candidate.
- Symptom: anaesthetic_delivery_other is a plain textField that is always present in the POST, so an untouched box stores ''. The column is NULL on all 468,838 source rows, and there is no path through this form that produces one.
- Impact or evidence: Nothing clinically - the two values render identically. It is a fidelity floor: this is a column no walk can match, and any IS NULL count taken against a generated database will be 0% where the source is 100%. Recorded rather than worked around because the workaround would be a...
- Original status: open - product behaviour, unworkable through the UI
- Source location: `BUGS.md:295`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O57: Build config / the LADS anaesthetic type is missing from this instance

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: The source's anaesthetic_type is 3 LA, 5 GA, 6 LADS, 7 Sedation, 8 No Anaesthetic. This instance's is 3 LA, 5 GA, 6 Sedation, 7 No Anaesthetic - LADS is absent entirely, and every id above 5 therefore means a different thing in the two databases.
- Impact or evidence: 6247 type assignments upstream (1.3% of op notes) have no control to tick here, so the LADS share of the mix cannot be replayed until the row is seeded. The id collision is the more dangerous half: a mirror that copied anaesthetic_type_id verbatim would turn every LADS into a...
- Original status: open - config gap, same family as O49-O51
- Source location: `BUGS.md:294`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O58: OphDrPrescription / printCopy prints a hardcoded event belonging to another patient

- Candidate state: unverified clinical product candidate.
- Symptom: DefaultController::actionPrintCopy($id) (line 547) prints the requested prescription and then does this: $eventid = 3686356; $api = Yii::app()->moduleAPI->get('OphCiExamination'); $api->printEvent($eventid);. The id is a literal. It is not derived from $id, from the patient, from the episode or from the request - every call to this action renders examination event 3686356 as well, whoever asked and whoever the prescription belongs to. On this instance...
- Impact or evidence: A confidentiality defect rather than a fidelity one, and the only one found so far that leaks across patients: anyone who reaches the route gets a second patient's examination in their print output, and the audit trail records a print against the prescription's patient rather...
- Original status: open - reported here only, not triggered
- Source location: `BUGS.md:293`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O59: OphDrPrescription / a draft prescription offers no way to print, and the code that would print it is unreachable

- Candidate state: unverified clinical product candidate.
- Symptom: views/default/view.php wraps every print action in if (!$Element->draft && $this->checkAccess('OprnPrintPrescription')), so a draft renders no #et_print, no #et_print_fp10 and no #et_print_wp10. But assets/js/module.js binds all three to a handler whose first branch is if ($('#et_ophdrprescription_draft').val() == 1), which GETs doPrint - the action that sets draft = 0, stamps the print mode and writes event.info. That branch can only run on a page that...
- Impact or evidence: Not a data-loss bug - the draft still finalises through the edit form - but it makes doPrint dead code and takes one lifecycle transition off the atlas: a draft prescription cannot be issued by printing it, which is how the paper workflow reads. Walk 41 reports it as its own...
- Original status: open - walk 41 refuses the row and says why
- Source location: `BUGS.md:292`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O60: Core / printing an event leaves no print audit entry on any module but Prescription

- Candidate state: unverified clinical product candidate.
- Symptom: BaseEventTypeController::printLog() writes the event/print audit row, and it has exactly one caller in the product: OphDrPrescription::actionMarkPrinted(). The generic actionPDFPrint() renders the PDF, streams it and returns without calling it, and actionPrint() goes straight to printHTML(). Measured rather than read: printing op note 3689097 through the header button wrote one audit row, event/view; printing prescription 3689076 the same way wrote...
- Impact or evidence: An IG gap in the product - who printed a consent form, an op note or a letter is not recorded anywhere, only that they viewed it - and a fidelity trap for the atlas, because the replay's audit mix will under-count prints exactly as the product does. It also means the audit table...
- Original status: open - product defect, no workaround needed
- Source location: `BUGS.md:291`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O61: OphCoCorrespondence / printing a letter writes an element version row that records nothing

- Candidate state: unverified clinical product candidate.
- Symptom: DefaultController::actionMarkPrinted() (line 464) sets $letter->print = 0 and calls $letter->save() before it touches the outputs. print is the "queued for printing" flag and is already 0 on a saved letter, so the save changes no column and the version behaviour still appends a full copy of et_ophcocorrespondence_letter. Measured: letter 821016 gained version 30 whose every field, print included, equals the base row - only version_date (11:34:22) differs...
- Impact or evidence: Harmless to the record and useful to the atlas - it is where correspondence version rows come from, the same way printing is where prescription version rows come from - but it means a letter's version history counts prints as edits, and nothing anywhere stores when a letter was...
- Original status: open - product defect, walk 41 reproduces it
- Source location: `BUGS.md:290`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O62: Core esign / the Save signature button accepts and stores a blank signature

- Candidate state: unverified clinical product candidate.
- Symptom: SignatureCapture.js binds its save handler as $(document).one("click", saveButtonSelector, ...) and goes straight to cropSignature() -> toDataURL() -> submitSignature(). It never asks signaturePad.isEmpty(), and neither does the controller behind saveCapturedSignature. Clicking Save on an untouched pad therefore writes a full ophtrconsent_signature / ophcocvi_signature row, a protected_file row and a real JPEG on disk - the JPEG is just an empty white...
- Impact or evidence: Clinically this is the serious one on this page: a consent form or a statutory CVI can be signed by a patient who never touched the pad, and nothing downstream can tell - canIssueCvi() is satisfied, the certificate issues, and the stored evidence is a blank rectangle. For the...
- Original status: open - product defect; harness guards against it in lib/esign.js
- Source location: `BUGS.md:289`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O63: OphCiExamination / the medication-risk observer writes nothing

- Candidate state: unverified clinical product candidate.
- Symptom: Saving a non-draft prescription whose items belong to a risk-tagged medication set is supposed to record those risks on the patient: Element_OphDrPrescription_Details::updateItems() dispatches after_medications_save with the patient and items, HistoryRisksManager::addPatientMedicationRisks looks the risks up from each item's medication sets, and createRiskEvent() opens a firm-less change-tracker episode carrying an Examination event with a HistoryRisks...
- Impact or evidence: Not the walk - the prescription itself is correct. What it blocks is the change-tracker episode class (SCENARIOS.md cause 27), whose only non-integration writer this is. Clinically it is the interesting half: a patient prescribed an anticoagulant does not get the risk flag the...
- Original status: open - product defect, cause not isolated
- Source location: `BUGS.md:288`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O64: OphDrPGDPSD / an administered drug no longer joins the patient's medication record

- Candidate state: unverified clinical product candidate.
- Symptom: Element_DrugAdministration::afterSave() walks its assignments and, for every med marked administered that has no entry yet, calls OphDrPGDPSD_API::setMedEventEntry() - which builds an Element_DrugAdministration_record (a subclass of EventMedicationUse, so a row in event_medication_use), saves it, and back-links it as ophdrpgdpsd_assignment_meds.administered_id. That is the mechanism by which a drug given in clinic appears in the medication history. It has...
- Impact or evidence: Clinically it means a drug recorded as given does not show up where a clinician looks for what the patient is on. For the atlas it settles a fidelity target that would otherwise have been read as a walk gap: DrugAdministration is 895,597 rows, 14.8% of the source's...
- Original status: open - product side, not fixed here. The instance agrees with the source's current behaviour, so no workaround is needed and none is wanted; what is needed is the era rule in the extraction spec. Worth reporting upstream: the silent save() makes it plausible that the row is being refused by validation rather than skipped, and...
- Source location: `BUGS.md:287`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O65: Integration feed / deceased patients

- Candidate state: unverified clinical product candidate.
- Symptom: An automated feed files Examination events onto patients the database already records as deceased. On the 1-in-97 patient sample, 1,548 of the 1,979 deceased patients that have any event (78.2%) carry at least one event dated after their own date_of_death, and 1,446 of those 1,548 (93.4%) have nothing but machine-written events after the death: 1,699 events from three feed accounts writing same-day (created_date - event_date = 0.0), the rest from the...
- Impact or evidence: Nothing for the replay, which has no feed channel and cannot reproduce it. It matters twice for the atlas: any "activity after death" statistic mined from the source measures an integration defect rather than clinical behaviour (FIDELITY section 39 corrects task #82 on exactly...
- Original status: open - source-side, recorded for whoever owns the feed
- Source location: `BUGS.md:286`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O66: event.is_automated / no default

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: The column is nullable with no default and nothing ever writes a zero. On the 1-in-97 event sample it is NULL on 222,259 rows and 1 on 4,927 - there are no 0 values anywhere in the column. So WHERE is_automated = 0 returns the empty set, AVG(is_automated) returns NULL for any group with no flagged rows, and NOT is_automated evaluates to NULL rather than true. The 2.2% that do carry the flag are Correspondence, Prescription, Device Information, Checklist,...
- Impact or evidence: Every "how much of this is automated" query is wrong in a way that still returns a plausible answer: ask for the automated share and you get it, ask for the manual share the obvious way and you get nothing at all. It is the nullable-boolean trap on the one column that decides...
- Original status: open - recorded; every query in this project now uses = 1 or IS NULL, never = 0
- Source location: `BUGS.md:285`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O67: Event save / concurrent writers on MariaDB 11.6+

- Candidate state: unverified clinical product candidate.
- Symptom: With five stories replaying at once, one INSERT INTO event was refused with SQLSTATE[HY000]: General error: 1020 Record has changed since last read in table 'event'; try restarting transaction. Nothing retries it: BaseEventTypeController::saveEvent turns it into Exception: Unable to save event at BaseEventTypeController.php:1999, the operator gets the generic Application Error page with an incident id, and the event is lost. The 1020 is...
- Impact or evidence: The replay's parallelism directly - the failure rate rises with the number of walkers, and it lands on whichever save is unlucky rather than on a particular walk, so it reads as a flaky story. It is worse than a lost row: the story stops, and every row after it in that CSV goes...
- Original status: open in the product; worked around in the harness - one occurrence in five parallel stories. bin/story.js now runs a failed row again (once by default, OE_RETRIES), and only when the walk announced no id: the refused save rolls back whole - the patient it happened to carried no orphan event row, checked - so re-running the row is the same row rather than a...
- Source location: `BUGS.md:284`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O68: Operation note - "generate standard GP letter" (OE_AUTOGEN=letter, walk 11)

- Candidate state: unverified clinical product candidate.
- Symptom: Ticking the auto-generation box on the op note form makes the product write a Correspondence event of its own on save, is_automated = 1, in the same transaction. That is exactly the source's commonest busy day - Correspondence + Operation note + Prescription is 71.2% of every op-note day in the 06-20 band and 63.0% in 21-50 (69-day-recipes.sql) - and it costs no extra walk. Two conditions decide whether it appears, and only one of them is a defect. Not a...
- Impact or evidence: Anything that wants the theatre-day letter for free. Used as-is on a backdated story it does the opposite of what is wanted: it takes the day apart, leaving the op note alone on its own date, and piles every generated letter onto the day the batch ran - the same calendar...
- Original status: worked-around - measured on a clean instance, three op notes and one letter created and then deleted through walk 15. e3-opnote-generates-letter is the one story that sets it and its letter is on the run day. Everywhere else the theatre-day letter is an authored correspondence row on the op-note's own date, which is more walk time and the right date (T65)
- Source location: `BUGS.md:283`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O69: OphLeEpatientletter on the -meh replay build - an active module whose model has no table

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: The replay image oe-web-live:v26.1.0-pre3-meh ships the module, and the deployment activates it: /config/modules.conf lists OphLeEpatientletter among modules=( ... ), which protected/config/core/common.php merges into $config['modules'], and OEConfig.php registers event_type 29 and element_type 327 off that list. The element table it needs does not exist. The bundled sample DB ships it renamed - archive_et_ophleepatientletter_epatientletter and...
- Impact or evidence: The channel's first row: walks/channels/epatient-letter-import.yaml has no table to insert into on the replay instance, and the whole 65,822-career import population behind it (232,085 patients at full scale that the channel owns outright) stalls at the setup step rather than at...
- Original status: open in the product, worked around in the spec. RENAME TABLE archive_et_ophleepatientletter_epatientletter TO et_ophleepatientletter_epatientletter plus the same for _version is the whole fix, and is replay.preconditions step 1 of the channel. Renaming is deliberately preferred to a hand-written CREATE: the archived definition still carries the three...
- Source location: `BUGS.md:282`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O70: event.created_date and episode.created_date default to 1900-01-01 00:00:00, so any raw-SQL insert silently backdates the row by a century

- Candidate state: unverified clinical product candidate.
- Symptom: Both columns are NOT NULL DEFAULT '1900-01-01 00:00:00', and created_user_id/last_modified_user_id default to 1 (information_schema, label 117-created-date-defaults). The model path never sees this - CTimestampBehavior fills all four - but a migration writing SQL does. modules/Diagnoses/migrations/m231201_164500_initialise_patient_state_from_old_model.php is the case in the checkout: it inserts episode naming only (patient_id, change_tracker) at :369 and...
- Impact or evidence: Nothing in the harness - the walks go through the model and are unaffected. It matters to the mirror twice: a generator that reproduces the source's created_date distribution has to reproduce this spike deliberately rather than treat it as noise (#128), and any index experiment...
- Original status: open, source-side, not ours to fix
- Source location: `BUGS.md:281`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O71: Examination / Pupils - no_pupillaryabnormalities_date_<side> is neither the event's date nor, on 43% of rows, any date on which this examination...

- Candidate state: unverified clinical product candidate.
- Symptom: Ticking "no pupillary abnormalities" on a side does not store a flag, it stores a date, and the date is date('Y-m-d H:i:s') read off the server clock at save time (modules/OphCiExamination/widgets/PupillaryAbnormalities.php:50-56). The event's own event_date is editable and routinely back-dated; this column never sees it. The same block only stamps when the column is empty (if (!$element->{'no_pupillaryabnormalities_date_' . $side})), and loadFromExisting...
- Impact or evidence: Nothing in the harness - the walk ticks the box and the element saves. It matters to the mirror: every walked confirmation is stamped with the run day against an event date years earlier, so 100% of generated rows land in the class the source puts 0.22% in, and at a distance of...
- Original status: open, source-side, not ours to fix; harness side deferred to #128
- Source location: `BUGS.md:280`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O72: OphCoDocument / a refused event save leaves its uploaded file behind, in the database and on disk

- Candidate state: unverified clinical product candidate.
- Symptom: The file is posted and stored before the event is: the upload control writes a protected_file row and the file itself, and the event save happens later from a different request. When that save fails there is nothing that takes either back. Seen once in shallow-weight-500: protected_file 676 written at 18:02:09, the save refused (FAIL OphCoDocument chrome-error://chromewebdata/), the retry uploaded protected_file 683 and saved event 3699004. 676 is named...
- Impact or evidence: Nothing, and it is closer to a shape we are short of than a defect to clean up. The source carries unowned protected_file rows as a matter of course: on a 1-in-1000 id sample (3,867 rows, label 19-protected-file-orphan-rate-source-full), 4.65% are named by no column that...
- Original status: recorded - deliberately not cleaned up, and not worked around; a failed document save is meant to leave this
- Source location: `BUGS.md:279`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O73: Pre-Assessment module / SeedOphInMehPacEventsCommand

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: The module ships a console command that cannot run on the image that ships it. ./yiic seedophinmehpacevents calls Event::factory(), every model factory constructs Faker\Factory, and faker is a require-dev package excluded from the production build - so the command fatals with Class "Faker\Factory" not found before writing anything. It is the only shipped command in protected/commands or any module's commands/ that does.
- Impact or evidence: Anyone told to seed pre-assessment data on a deployed instance gets a PHP fatal, and the fix needs a dev-mode rebuild rather than an option. Not a clinical path, and a developer running the suite locally has faker, which is why it survives.
- Original status: open, not reported
- Source location: `BUGS.md:278`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O74: Admin / add user - two administrators adding a user at the same moment deadlock, and the product tells them it was a unique constraint

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: actionEditUser (reached from actionAddUser) deletes before it inserts: UserAuthentication::model()->deleteAll('user_id = :user_id AND id NOT IN (...)') - O18's full-replace - runs first, and for a brand new account the id list is empty, so it deletes nothing and still walks user_auth_user_fk for a user_id that is the largest in the index. The range it scans ends at the page's supremum pseudo-record, and the next-key lock it takes there covers the gap...
- Impact or evidence: Two things, and the second is the expensive one. A deadlock here is transient by definition and the database's own advice is to retry, which the controller does not do - so a second administrator gets a 500 and a lost account rather than a wait. And the message sends whoever...
- Original status: open in the product; the harness's existing OE_RETRIES already covers it. One occurrence in 165 accounts seeded four-at-a-time (u037, taregrange.h, 2026-08-16 08:12:40); the retry saved it as user 6696 and the DB carries exactly one row for that username, so the refused attempt rolled back whole, same as O67's
- Source location: `BUGS.md:277`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O75: Version tables / three of the six busiest have no index on id, the column that names the base row

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: A _version table's primary key is version_id, a surrogate; the row it is a history of is named by a plain id column. GenerateVersionMigrationCommand copies the base table's indexes, so a version table inherits every FK index the base had - created_user_id, last_modified_user_id, episode_id, patient_id and so on - and gets id only where somebody added it by hand afterwards. On the source, event_version, et_ophcocorrespondence_letter_version and...
- Impact or evidence: Nothing clinical - the product reads a version chain from the audit screens rarely and one scan is survivable interactively. It cost this project a 1800s statement: sql/181's first form probed patient_version once per sampled patient and was killed at the cap. It also lands...
- Original status: open, source-side, not ours to fix; sql/181 works around it by aggregating the version side once. Widened 2026-08-17 by profiler/sql/202, which asked information_schema the same question of every version table over 0.5 GB: of the 26 that qualify, 16 lead on neither id nor event_id and they hold 141.30 GB. The split is not random - element version tables...
- Source location: `BUGS.md:276`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O76: Examination / a swallowed InnoDB deadlock turns one retryable refusal into an Application Error and a lost event

- Candidate state: unverified clinical product candidate.
- Symptom: Five steps, every one of them observed. (1) Two clinicians save an examination at the same moment and an INSERT inside the event-save transaction deadlocks - SQLSTATE[40001] ... 1213 Deadlock found when trying to get lock; try restarting transaction, on ophciexamination_intraocularpressure_value in every occurrence captured so far, which is the busiest child table on the busiest element. (2) MariaDB rolls the whole transaction back, which includes the...
- Impact or evidence: The event is lost outright, not half-written - the rollback is clean, and the id it would have had is simply missing from the sequence (3704133 in the run below). That is the good news; the bad news is that the user is told to phone the service desk over a condition that a retry...
- Original status: open in the product. Reproduced 2026-08-17 at 20 concurrent examinations, one loss (fairescar.s, patient [sample identifier omitted], 09:48:53, full cascade in application.log lines 1657-1663). Not caused by the harness sharing a login - the losing session held its own account. The harness's OE_RETRIES does not cover it, because the walk sees a 500 page...
- Source location: `BUGS.md:275`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O77: Biometry / the refraction sub-element is written as six columns of zeroes

- Candidate state: unverified clinical product candidate.
- Symptom: et_ophinbiometry_measurement carries refraction_sphere, refraction_delta and refraction_axis for each eye. Across 107,903 source studies, 25 rows (0.023%) carry a non-zero value in any of the six; the other 107,878 are zero on all of them. The columns are not dead - 19 distinct sphere values from -19.25 to 9.75 exist, so the importer can and occasionally does write them - the device simply almost never supplies a pre-op subjective refraction, and when it...
- Impact or evidence: Nothing clinically - a zero refraction is not read as a measurement by anything in the module. It is a data-shape trap in two directions: a query that treats 0 as a value gets 215,806 emmetropes, and one that treats NULL as "not measured" finds nothing not measured. For the...
- Original status: open - product behaviour, recorded so the channel reproduces the zeroes rather than modelling a distribution. Found via profiler/sql/197/198; the first reading of it was wrong, see T170
- Source location: `BUGS.md:274`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O78: Biometry / the imported event has no episode, so it is invisible to every event -> episode join

- Candidate state: unverified clinical product candidate.
- Symptom: The DICOM im The DICOM importer writes an event row with episode_id NULL and ophinbiometry_imported_events.is_linked = 0; only a clinician opening Add Biometry on that patient sets the episode, through OphInBiometry\DefaultController::updateImportedEvent(). Nothing else ever sets it, and nothing ever cleans up. In the source that leaves 93,591 of 107,900 studies (86.74%) as events on no episode - and because v26's event has no patient_id, the documented...
- Impact or evidence: Any report, count, index test or extract that joins through episode silently under-counts Biometry by a factor of 7.5, with no error and no empty-set signal - the query returns the 13% that were claimed and looks correct. It is also a live audit gap: an unclaimed study is a real...
- Original status: open - product behaviour, recorded because the mirror must reproduce it. Use ophinbiometry_imported_events.patient_id to reach these events, never event -> episode; do not use is_automated to find them
- Source location: `BUGS.md:273`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O79: Reference data / every patient message re-saves the GP, practice and commissioning body unchanged, and each re-save writes a history row - 238.4M of...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: BaseActiveRecordVersioned::versionToTable() copies the pre-update row into <table>_version on every UPDATE, with no comparison of any kind. BaseActiveRecord::save() stamps last_modified_user_id and last_modified_date before it decides anything, so the model is never clean and Yii's own short-circuit cannot fire. The guard exists and is opt-in: saveOnlyIfDirty() plus isModelDirty(), which deliberately excludes those two audit stamps...
- Impact or evidence: Nothing clinical, and nothing the harness trips - the walks go through the model and each walked save writes one version row, as intended. It costs 30.19 GB of a 356.6 GB database, of which 12.05 GB is index on columns no query uses, and it compounds with O75: none of the four...
- Original status: open in the product, source-side, not ours to fix. The one-line fix for the live half is to make the three PASAPI resources match ProcessHscicDataCommand; note that saveOnlyIfDirty() makes save() return false on a clean model, so callers that read the return value need checking
- Source location: `BUGS.md:272`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O80: Admin / opening the add-site form writes a contact row, so a site costs two contacts and an abandoned visit costs one

- Candidate state: unverified clinical product candidate.
- Symptom: AdminController::actionAddSite() (protected/controllers/AdminController.php:1947) is a straight delegate to actionEditSite(true) (:1952), whose if ($new) branch runs before if (!empty($_POST)). That branch constructs new Contact('admin_contact'), stamps created_institution_id from the session and calls $contact->save(false) (:1959) - validation skipped - then hangs the unsaved Site and Address off the saved contact id. Because the branch is keyed on $new...
- Impact or evidence: Nothing clinical and nothing a user sees; contacts are small. It bites this project twice. The walk must decide whether a site already exists before it opens the form, or a re-run of an idempotent config CSV writes a contact per row without creating a single site - which is...
- Original status: open, product-side. The fix is to move the contact creation inside the POST branch; walk 46 works around it and replay/FOOTPRINTS.md records the doubled count as intended output
- Source location: `BUGS.md:271`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O81: Admin / two accounts created at the same moment deadlock on a DELETE that matches nothing, and the product blames a unique constraint that does not...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: The user-save path replaces the account's institution authentications by deleting them and re-inserting them. protected/controllers/AdminController.php:875-884 builds user_id = :user_id plus an addNotInCondition('id', $ids) and runs UserAuthentication::model()->deleteAll($criteria); for a brand-new account $ids is empty, Yii1 adds nothing for an empty NOT IN, and the general query log shows the statement arriving as a bare DELETE FROM user_authentication...
- Impact or evidence: Nothing clinical - add-user is an admin screen. It is the ceiling on parallel account creation, which is what B20 needed: at ten concurrent walkers it refused 4 saves in 40 accounts (10%), every one recovered by the harness's own OE_RETRIES, and it is the reason the 8-way probe...
- Original status: open in the product, source-side. Two independent fixes: skip the deleteAll when $user->isNewRecord (there is nothing to delete), and correct the handler's message so a 40001/1213 is reported as a deadlock with a retry rather than as a constraint violation
- Source location: `BUGS.md:270`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O82: Admin / a modal asks every admin the same question every session, both answers write, and answering "yes" guarantees it is asked again

- Candidate state: unverified clinical product candidate.
- Symptom: protected/views/base/_form.php:47 opens VersionCheckWidgetReminder on the first page of every session for every account holding admin, gated only on SettingMetadata::getSetting('auto_version_check') === 'enable' and a shown_version_reminder session flag. The dialog (components/views/VersionCheckWidgetReminder.php) offers exactly two buttons - "Yes Enable" and "No Disable" - and both POST to /admin/changeVersionCheck, which is...
- Impact or evidence: Nothing clinical. It matters here in three ways. It is the single biggest concentration in setting_installation_version and any settings channel that reproduces version counts has to reproduce this one row or miss 97% of the table. It is a modal that opens on the first admin...
- Original status: open, product-side. The fix is a dismiss path that does not write, a dirty check before save(), and not re-asking a question the admin has already answered yes to. Recorded in walk-atlas-v1/walks/channels/settings-seed.yaml; no replay workaround is needed while the setting ships disabled
- Source location: `BUGS.md:269`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O83: Api/Request / an import that fails its attachment routine burns twenty retries, is never rescheduled, and leaves the rest of its chain permanently at...

- Candidate state: unverified clinical product candidate.
- Symptom: Every inbound payload runs a fixed ten-step chain of named routines (request_routine.execute_sequence is single-valued per routine name across all 14,505 requests, so the order never varies). The eighth step, BIOMETRY_MEDIA_ATTACHMENT_CREATE, FAILS at try_count 20 on 5,552 requests and sits at NEW with try_count 0 on a further 405 - 5,957 of 14,502, 41.08%. The two steps behind it stop dead: GENERIC_SET_ATTACHMENT_TYPE is at NEW on exactly 5,957 requests...
- Impact or evidence: Nothing clinical is lost - the DICOM study itself arrives through the older direct-import path, which is why the Biometry event exists at all; what is lost is the report PDF attached to it. It matters to this project as a fidelity fact: reproduce the chain without the failure...
- Original status: open, product-side, and only half-diagnosable read-only. The rate is reproduced deliberately by walk-atlas-v1/walks/channels/api-request-feed.yaml; settling the cause needs the routine implementation or one log_text value, and the sheet carries it as an open question
- Source location: `BUGS.md:268`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O84: Api/Request / the queue poller takes a routine lock and never gives it back, so request_routine_lock grows one row per routine run forever

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: The Api module's queue processing takes a mutex row in request_routine_lock before running a routine (protected/modules/Api/modules/Request/models/RequestRoutineLock.php, one column of interest: routine_lock). Nothing deletes from it. Measured in the source: 22,647 rows, all 22,647 distinct - so not one lock key is ever reused - at 1.561 rows per request over 14,505 requests in nine months. Key length runs 7 to 64 characters, average 34.4 (measured by...
- Impact or evidence: Nothing clinical and nothing visible. It matters here because the table is part of the API channel's write contract and its size is a pure leak: a mirror that reproduces the 1.561 ratio is reproducing a bug faithfully, which is the right call for an index test and worth knowing...
- Original status: open, product-side. The fix is to delete the lock row when the routine finishes (or to reuse one row per queue, as request_queue_lock does). Recorded in walk-atlas-v1/walks/channels/api-request-feed.yaml; the loader reproduces the ratio deliberately
- Source location: `BUGS.md:267`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O85: Api/Request + EventSupport / an event collects a second attachment group because the reuse check only looks at the groups already in memory, and...

- Candidate state: unverified clinical product candidate.
- Symptom: protected/modules/EventSupport/components/EventAttachmentHandler.php reuses an existing group through getOrCreateAttachmentGroupForEvent(), which walks $this->event->attachment_groups - the cached Yii relation on the event instance the handler is holding - and returns the first whose element_type_id is NULL; if the relation was loaded before the other writer's group existed, or the handler is a second instance in a second request, it finds nothing and...
- Impact or evidence: Nothing clinical: a duplicate group renders as an extra empty section, and the items still hang off one of them. It costs this project twice. Any loader that writes one group per event reproduces 92% of event_attachment_group and misses the whole tail, so the sheet pins the...
- Original status: open, product-side. The fix is to look the group up with a query rather than off the cached relation (or a unique key on (event_id, element_type_id) where the element is NULL), and to stamp created_user_id from the acting user like every other clinical write. Reproduced as-is by walk-atlas-v1/walks/channels/api-request-feed.yaml, which carries the histogram
- Source location: `BUGS.md:266`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O86: PASAPI / one external hospital number resolves to as many as 160 different patients, because the unique key that stopped it was dropped and nothing...

- Candidate state: unverified clinical product candidate.
- Symptom: pasapi_assignment was created with two unique keys (PASAPI/migrations/m160114_141005:28-29): internal_key (internal_id, internal_type) and resource_key (resource_id, resource_type). PASAPI/migrations/m200812_131808_drop_unique_key_pasapiassignmnet.php drops the second one and adds nothing in its place, so an external id may now be held by any number of patients. Resolution did not change to match: PasApiAssignment::findByResource()...
- Impact or evidence: Clinically this is the one that matters most of the recent set: a PAS demographic update addressed to hospital number X can land on a different patient's record than the one the sender meant, and it will do so consistently rather than intermittently. For this project it is a...
- Original status: open, product-side. Either restore the unique key (after reconciling the 4,698 rows), or make resolution deterministic and explicit about multiplicity - findByResource returning a set, and the caller refusing to update when it holds more than one. Recorded in walk-atlas-v1/walks/channels/pas-identity-feed.yaml, which reproduces the rate and flags whether a...
- Source location: `BUGS.md:265`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O87: Schema / the baseline schema ships two identical indexes on event.episode_id and two on event.event_type_id, and 22 more duplicate pairs sit behind...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: protected/migrations/m130913_000000_consolidation.php:1494-1499 creates, in a single CREATE TABLE, KEY event_1 (episode_id) and KEY idx_event_episode_id (episode_id), KEY event_3 (event_type_id) and KEY idx_event_event_type_id (event_type_id). Both pairs are non-unique, cover an identical column list, and have been in every OpenEyes installation since 2013; the event_1/event_3 names are also the FK constraint names, so the second index of each pair is...
- Impact or evidence: Nothing clinical and nothing visible. It matters to this project directly: #99 exists to test performance indexes on this database, and every such test would be run against a schema where inserting one event row maintains four B-trees where two would do, and where the optimizer...
- Original status: open, product-side, and cheap to fix: drop the redundant member of each pair. Worth quantifying before the index work starts - a DROP INDEX event_1-scale experiment on the replay is itself a legitimate first index test
- Source location: `BUGS.md:264`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O88: Event / is_automated is not a "was a human at the keyboard" flag - 29.69% of the events that pass the human-only filter were written by five accounts...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: event.is_automated (with its suppressed companion automated_source) is the only column in the schema that separates machine-created events from typed ones, and every actor and rate statistic in this atlas has been cut on is_automated = 0 OR is_automated IS NULL. Over the mirror window that filter passes 10,531,902 events across 3,471 accounts, and sql/226 + sql/227 measure what is actually inside it. The busiest account holds 2,420,335 - 22.98% of the...
- Impact or evidence: Everything cut on the human-only denominator, which is most of the atlas's actor and rate work, and the human Examination share worst of all - 2.42M of the window's supposedly-typed Examinations are one machine. The direct casualty is the actor curve (#226, T177): its rank-1...
- Original status: open, product-side. The flag exists and the write paths that set it are a subset of the ones that should: an event created outside an interactive request - a console command, an import, a non-PASAPI API route - should be flagged like a PASAPI one, and until it is, is_automated = 0 means "no PASAPI/Mirth stamp", not "a person did this". Atlas-side this is...
- Source location: `BUGS.md:263`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O89: Schema / user_authentication freezes the wall-clock second its migration ran into two column DEFAULTs, so 99.49% of an instance's accounts carry a...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: protected/migrations/m200517_044325_add_multiple_LDAP_auth_to_institutions.php:50-62 runs $date = date("Y-m-d H:i:s"); and then interpolates that PHP string straight into the DDL: 'password_softlocked_until' => 'datetime DEFAULT "' . $date . '"' and 'password_last_changed_date' => 'datetime DEFAULT "' . $date . '"'. What was meant as "default to now" becomes a literal in the schema, and MariaDB keeps it forever - information_schema reads the source's back...
- Impact or evidence: Anything that reads the column as a clock. A password-expiry policy driven off password_last_changed_date measures the age of the migration, not the age of the password, and on a long-lived instance it says every password is the same age; the softlock column is worse, because a...
- Original status: open, product-side. The fix is one character class - 'datetime DEFAULT CURRENT_TIMESTAMP', or no default at all with the model setting it on create - plus a data repair, because existing rows cannot be told apart from real ones after the fact. Replay-side this is reproduced deliberately rather than worked around: bin/estate-dates.sql puts 99.49% of the...
- Source location: `BUGS.md:262`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O90: PASAPI / a Practice PUT answers <Success>Practice updated.</Success> while writing nothing, because the Contact leg needs a surname a practice does...

- Candidate state: unverified clinical product candidate.
- Symptom: protected/modules/PASAPI/resources/Contact.php::saveModel() opens with $contact->scenario = "pasapi_import", and protected/models/Contact.php:92 is ['first_name, last_name', 'required', 'on' => ['manage_gp_role_req', 'pasapi_import']]. A practice contact carries the practice name in first_name and nothing at all in last_name - 19,386 of 19,386 source practice contacts, and 1,939 of 1,939 on the replay, have it absent (profiler/sql/269 q1). So...
- Impact or evidence: It is the whole of #262. PASAPI's AddressList is the only channel in v26 that can give a practice contact a second address: the admin screen renders one address block against a HAS_ONE (PracticeController::actionUpdate():396, views/practice/_form_address.php) and...
- Original status: open, product-side. Two independent fixes: give the PASAPI Contact resource a scenario that does not demand last_name when the contact is an organisation, and merge a sub-resource's errors and warnings into the response rather than discarding them. The replay closes #262 with a loader instead, which is also what the source's own rows look like - all 6,253...
- Source location: `BUGS.md:261`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O91: Genetics / pedigree_gene.priority is an integer rank in the schema, a checkbox on the edit form and Yes/No in the view, so 132 of the source's 408...

- Candidate state: unverified clinical product candidate.
- Symptom: The column is tinyint(1) unsigned NOT NULL and PedigreeGene validates it only as safe (protected/models/PedigreeGene.php:64), so any 0-255 value saves. GeneController::actionEdit declares it to the generic admin form as 'priority' => 'checkbox', which posts 0 or 1 and nothing else, and Genetics/views/gene/view.php:39 renders ($model->priority ? 'Yes' : 'No'). The source uses it as a rank and spends 19 distinct values on 408 genes (sql/288 q1): 240 at 0,...
- Impact or evidence: Nothing clinical - a wrong rank reorders a lookup list. It blocks #211: the walk can seed all 408 names and loci through the form but every one of them lands at the form's default of 0, so the rank distribution has to be restored out of band by...
- Original status: open, product-side. Either the form field becomes a number and the view prints it, or the column becomes a real boolean and the ranking moves somewhere that can express it - the current pair is a schema and a UI that disagree about the type. Worked around replay-side by the priority pass
- Source location: `BUGS.md:260`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O92: Drug Administration / editing a PGD/PSD assignment's comment inserts a new ophdrpgdpsd_assignment_comment row and repoints the assignment at it,...

- Candidate state: unverified clinical product candidate.
- Symptom: ophdrpgdpsd_assignment_comment is reached only through ophdrpgdpsd_assignment.comment_id; the child carries no parent FK of its own (its only outgoing FKs are the three user stamps). sql/292 counts 803,349 assignments of which 28,801 carry a comment_id, all 28,801 distinct, against 120,599 comment rows - so 91,798 rows (76.1%) are pointed at by no live assignment. Splitting them against ophdrpgdpsd_assignment_version.comment_id separates two failure...
- Impact or evidence: Nothing clinical - the live comment is always the one the assignment points at, and the strays are invisible in the UI. It is a storage and a fidelity problem. The table is the 7th largest the census classified as config and 76% of it is dead weight, which for a site running...
- Original status: open, product-side. The comment should be updated in place, or the repointed predecessor deleted with it; separately the create-and-never-link path should not be leaving a row at all. Recorded, not worked around - the replay writes zero assignment comments today because it writes 11 assignments against 803,349
- Source location: `BUGS.md:259`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O93: Request Form / editing a form's JSON mints a whole new ophcorequestform_form row and re-writes its status and administrator assignment sets against...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: AdminController::actionEditHtmlForm does not update the form it was given; it inserts a new row carrying the edited definition and repoints the predecessor through newest_form_id. sql/293 resolves the chains: 69 rows are 21 live forms (18 active, 3 inactive) plus 48 superseded versions, at depths of 8 chains of one version, 5 of two, 3 of three and one each of four, five, seven, eleven and fifteen. The satellites are rebuilt per version rather than...
- Impact or evidence: Nothing clinical - a request event resolves through newest_form_id and sees one form. It is a storage shape and, for this project, a census trap: the atlas sheet read 69 forms at 5.3 administrators each, where the truth is 21 forms at 5.6. It also sets a rate generation cannot...
- Original status: open, product-side. The version chain is presumably deliberate (a request raised against an old definition must still render it), but re-writing the assignment sets per version is not obviously part of that - the administrators and statuses of a form are properties of the form, not of a revision of its JSON. Recorded, not worked around; the replay writes...
- Source location: `BUGS.md:257`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O94: Team admin / a user removed from a team keeps the RBAC row that names it. Team::afterSave rewrites team_user_assign from the posted member list;...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: protected/models/Team.php:511 (the empty($user_ids) branch), reached from Team.php:318 via protected/controllers/oeadmin/TeamController.php:157. The removed user's authassignment.data keeps the team id, so AuthRules::hasTeamAssignment (AuthRules.php:96) still answers true for a team they are not on. Nothing in the UI shows the row, and nothing removes it later - team_user_assign is the only list the edit screen renders
- Impact or evidence: profiler/sql/301: the source carries 167 (user, team) references inside 164 hasTeamAssignment rows against 160 team_user_assign rows - 7 references with no membership behind them, 4 of them belonging to users with no team membership at all. Every referenced team still exists...
- Original status: not fixed - product side. Recorded for the atlas: an RBAC row without a membership row is what the source looks like, so #279 reproduces it by giving walk 41 a remove-a-member step rather than by writing the orphan directly
- Source location: `BUGS.md:258`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O95: Messaging / DefaultController::actionAddComment posts a reply with no re-check of canComment() and no check that the acting user belongs to the...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: protected/modules/OphCoMessaging/controllers/DefaultController.php - actionAddComment against canComment(); models/Element_OphCoMessaging_Message.php::isIntendedRecipient.
- Impact or evidence: The source shows all three shapes in real data. profiler/sql/309 q2: 4,532 replies follow a reply by the same account - the view would not have rendered that box. q4: 4 first replies are opened by a cc box, not a primary recipient, which the view cannot produce at all....
- Original status: not fixed - product side, and it is a hardening finding rather than a live leak: nothing here crosses a patient boundary, since every path already required the actor to be on the message. Recorded for the atlas because it changes what generation may assume: a replay walk cannot reproduce the 4,532 same-account-twice replies or the 4 cc-opened threads...
- Source location: `BUGS.md:256`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.

### O96: Messaging / a reply saves every recipient row twice, and the second save changes nothing. Element_OphCoMessaging_Message sets auto_update_relations =...

- Candidate state: excluded provenance record - outside this clinical workflow hunt.
- Symptom: protected/modules/OphCoMessaging/models/Element_OphCoMessaging_Message.php:60 (the flag) and :108-133 (the four recipient relations); protected/models/BaseActiveRecord.php:610-658 (the cascade, gated on getSafeAttributeNames()); protected/modules/OphCoMessaging/controllers/DefaultController.php:209-222 (the loop, then the element save).
- Impact or evidence: Measured on the replay first: a reply mints two ophcomessaging_message_recipient_version rows per recipient and an explicit mark-read mints one - recipient rows 141, 143 and 145 each carry 2 versions against 1 comment and no hand receipt at all, and their version pre-images read...
- Original status: not fixed - product side, and it costs the mirror nothing: the replay reproduces the doubling because it drives the same code, so the version volume comes out right for free. Recorded because it is a real write amplification on a hot path (the source's ophcomessaging_message_recipient_version carries 428,601 rows against 257,702 base rows) and because...
- Source location: `BUGS.md:255`.
- Dedupe: no close heading match in the pre-existing corpus; predicate-level dedupe still required.
