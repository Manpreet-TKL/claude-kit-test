# OpenEyes clinical bug swarm - wave 004 candidates

- Target: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Comparison: `origin/master` at `ad2324084788608246a8250e817198c2f26a4fd6`.
- Method: version-matched local snapshot review by Luna agents 15 through 19.
- Status: every entry is unverified and counts as zero verified bugs.

### CAND-0006: Mandatory intravitreal prescribing does not require a PIN before save

- Preconditions: Injection prescribing mode is Mandatory and the examination
  contains a mapped intravitreal treatment.
- Expected: Save is blocked until the prescription is signed with a PIN.
- Actual: The controller attempts signing only when a proof value was posted, so
  an empty proof can leave a saved unsigned prescription draft.
- Predicate: The examination saves and reopens with its prescription unsigned.
- Distinctness key: `Examination IVT | save mandatory prescription | PIN empty | unsigned draft saved | conditional signing call`.
- Code note: `protected/modules/OphCiExamination/controllers/DefaultController.php:1942`.

> 1. Configure intravitreal prescribing as Mandatory.
> 2. Add a mapped injection treatment to an Examination.
> 3. Leave 'Sign by PIN' empty and save.
> 4. Reopen the event and inspect prescription status.

### CAND-0007: Intravitreal prescription drafts are created while prescribing is disabled

- Preconditions: Injection prescribing is disabled and a new treatment sequence
  is saved.
- Expected: No prescription or prescription-signature state is created.
- Actual: New treatment sequences call signature creation without checking the
  prescribing mode.
- Predicate: A draft injection signature row exists after the event is saved.
- Distinctness key: `Examination IVT | save treatment | prescribing disabled | draft signature exists | unconditional signature creation`.
- Code note: `protected/modules/OphCiExamination/controllers/DefaultController.php:2092`.

> 1. Disable intravitreal prescribing in settings.
> 2. Create an Examination with a new injection treatment sequence.
> 3. Save and reopen the event.
> 4. Check whether prescription-signature state was created.

### CAND-0008: Same-second injection sequence disappears from a historical snapshot

- Preconditions: An injection sequence and event version are written in the same
  database second.
- Expected: The historical event version includes the sequence that existed when
  the version was created.
- Actual: The history query uses a strict earlier-than comparison and excludes a
  sequence whose timestamp equals the version timestamp.
- Predicate: The current event shows the sequence but its historical version does not.
- Distinctness key: `Examination IVT | view history | equal timestamps | sequence missing | strict timestamp comparison`.
- Code note: `protected/modules/OphCiExamination/models/Element_OphCiExamination_InjectionManagement_v2.php:329`.

> 1. Create and save an injection sequence.
> 2. Produce an event edit/version in the same second.
> 3. Open the historical version.
> 4. Compare its treatment sequence with the current event.

### CAND-0009: Signed injection prescription can retain stale pre-edit treatment details

- Preconditions: A saved active treatment sequence already has a draft signature.
- Expected: Editing treatment details updates the draft before it is signed.
- Actual: Signature content is created only when the sequence lacks a signature;
  an existing draft is not refreshed before signing.
- Predicate: The signed prescription differs from the treatment shown in the event.
- Distinctness key: `Examination IVT | edit then sign treatment | existing draft | signed details stale | draft created once`.
- Code note: `protected/modules/OphCiExamination/controllers/DefaultController.php:2092` and `controllers/traits/CreatesInjectionSequenceSignature.php:29`.

> 1. Save an Examination containing an unsigned injection treatment.
> 2. Reopen it and change a treatment detail.
> 3. Enter the PIN, save, and view the signed prescription.
> 4. Compare the signed content with the edited treatment.

### CAND-0010: Omitted administered row can lose protected Drug Administration state

- Preconditions: A non-prescriber edits a Drug Administration form containing an
  already administered row that a dynamic refresh omits from the submitted rows.
- Expected: Existing administered state remains unchanged.
- Actual: The restoration path protects only posted entry IDs, so an omitted row
  can reach caching without being restored.
- Predicate: Reopening the event shows the administered row deleted or altered.
- Distinctness key: `Drug Administration | save after dynamic row replacement | administered row omitted | state lost | restore only posted IDs`.
- Code note: `protected/modules/OphDrPGDPSD/widgets/DrugAdministration.php:351`.

> 1. As a non-prescriber, reopen a Drug Administration event with an administered row.
> 2. Trigger a normal dynamic refresh that replaces or omits that row.
> 3. Save and reopen the event.
> 4. Compare the administered row with its original state.

### CAND-0011: Correspondence Quick Text with HTML collapses embedded plain-text line breaks

- Preconditions: A configured Quick Text response combines an HTML tag with
  newline-separated plain text.
- Expected: The authored lines remain separate in the letter.
- Actual: Detection of any HTML bypasses newline conversion for the whole response.
- Predicate: Preview or print joins newline-separated text onto one rendered line.
- Distinctness key: `Correspondence | insert Quick Text | mixed HTML and newlines | lines collapse | whole-string HTML bypass`.
- Code note: `protected/modules/OphCoCorrespondence/assets/js/module.js:1388`.

> 1. Open a Correspondence editor.
> 2. Insert Quick Text containing an HTML tag and newline-separated text.
> 3. Preview or print the letter.
> 4. Check whether the authored line breaks remain visible.

### CAND-0012: Correspondence Quick Text strips intentional outer whitespace

- Preconditions: A configured Quick Text response begins or ends with a space or
  blank line that separates it from surrounding letter content.
- Expected: Insertion preserves the configured response boundaries.
- Actual: The response is trimmed before insertion.
- Predicate: Preview lacks the authored leading or trailing separation.
- Distinctness key: `Correspondence | insert Quick Text | outer whitespace configured | spacing removed | trim before insertion`.
- Code note: `protected/modules/OphCoCorrespondence/assets/js/module.js:1388`.

> 1. Configure Quick Text with an intentional leading or trailing blank line.
> 2. Insert it between existing letter paragraphs.
> 3. Preview the letter.
> 4. Compare the spacing with the configured response.

### CAND-0013: Closing the duplicate-prescription warning does not cancel creation

- Preconditions: The patient already has a prescription dated today and the
  clinician starts another.
- Expected: Closing the warning has the same cancel behavior as choosing 'No'.
- Actual: The new dialog close control only closes the popup, leaving the clinician
  on the new-prescription form.
- Predicate: The create form remains active after the warning's close control is used.
- Distinctness key: `Prescription | close duplicate-day warning | existing prescription today | creation continues | close event not wired to cancel`.
- Code note: `protected/assets/js/OpenEyes.UI.Dialog.Confirm.js:104` and `protected/modules/OphDrPrescription/assets/js/defaultprescription.js:625`.

> 1. Open a patient with a prescription already created today.
> 2. Start another Prescription event.
> 3. Close the duplicate warning using its title-bar close control.
> 4. Check whether the create form remains active.

### CAND-0014: Operation Note save can fail while constructing procedure completion laterality

- Preconditions: An Operation Note contains a procedure and an eye choice not
  representable by the new procedure-completion DTO conversion.
- Expected: The note saves and remains viewable.
- Actual: Procedure completion converts the selected eye through a strict enum and
  can throw during the save transaction.
- Predicate: Save returns an error and no Operation Note is created or updated.
- Distinctness key: `Operation Note | save procedure | unsupported eye mapping | save fails | strict DTO laterality conversion`.
- Code note: `protected/modules/OphTrOperationnote/models/Element_OphTrOperationnote_ProcedureList.php:210`.

> 1. Create or edit an Operation Note.
> 2. Add a procedure and select the available eye choice.
> 3. Save the event.
> 4. Check whether the note saves or the transaction returns an error.

### CAND-0015: Existing patient risks have no working remove action

- Preconditions: The patient has an existing risk displayed in the clinical risk form.
- Expected: Clicking the remove control asks for confirmation and removes the risk.
- Actual: The UI migration removed the existing-risk remove and cancel handlers
  without a replacement in `risks.js`.
- Predicate: Clicking the remove control produces no confirmation and the risk remains.
- Distinctness key: `Patient risks | remove existing risk | saved risk present | no action | removed click handlers`.
- Code note: `protected/assets/js/risks.js` after commit `f5533373247979e5fca2353368e67a8beaf2a66d`.

> 1. Open a patient's clinical risks form.
> 2. Find an existing risk and click its remove control.
> 3. Observe whether a confirmation appears.
> 4. Save and check whether the risk was removed.
