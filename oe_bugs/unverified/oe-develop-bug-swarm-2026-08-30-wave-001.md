# OpenEyes clinical bug swarm - wave 001 candidates

- Target: `develop` at `bafadd01b90cef38862f187c17d07160e757b276`.
- Comparison: `origin/master` at `ad2324084788608246a8250e817198c2f26a4fd6`.
- Method: version-matched develop-diff code walk by Luna agents 01 through 04.
- Status: every entry is unverified and counts as zero verified bugs.

### CAND-0001: Examination DR Grading reference image control has no handler

- Preconditions: Open an Examination with the DR Grading element available.
- Expected: Clicking the photo control opens the DR grading reference image.
- Actual: Develop still renders the `href="#"` photo control, but the jQuery UI
  popup initialization and click handler were removed with no local replacement.
- Predicate: After clicking the control, no visible dialog containing the DR
  grading reference image exists.
- Distinctness key: `Examination | open DR grading reference | DR Grading element | no image dialog | removed handler`.
- Severity and type: medium, UI regression.
- Discovery: agent 01, static only.
- Code note: `protected/modules/OphCiExamination/views/default/form_Element_OphCiExamination_DRGrading.php:65` and commit `f5533373247979e5fca2353368e67a8beaf2a66d`.
- Verification state: R1 in progress with a different agent.

> 1. Log in and open a patient in a context where DR Grading is available.
> 2. Click 'Add Event', choose 'Examination', and add 'DR Grading' if needed.
> 3. Click the photo control beside the DR Grading title.
> 4. Check whether a reference-image dialog opens.

### CAND-0002: Drug Administration irrelevant assignments are not sorted by appointment time

- Preconditions: The patient has at least two inactive or otherwise irrelevant
  drug assignments with different worklist appointment times.
- Expected: The irrelevant assignment group is displayed in appointment order.
- Actual: The new comparator compares the first assignment time with itself and
  returns equality for every pair, leaving input order unchanged.
- Predicate: Displayed irrelevant assignments are not ordered by their worklist
  appointment times.
- Distinctness key: `Drug Administration | view irrelevant assignments | multiple appointment times | wrong order | comparator self-comparison`.
- Severity and type: medium, clinical workflow ordering.
- Discovery: agent 02, static only.
- Code note: `protected/modules/OphDrPGDPSD/widgets/DrugAdministration.php:106` in commit `f7ba45a1d15941ac0e48777e3d33ff0e1d08287b`.
- Verification state: blocked pending suitable fixture identification.

> 1. Open a patient who has at least two inactive or irrelevant drug assignments.
> 2. Open the Drug Administration event or widget.
> 3. Compare the displayed irrelevant-assignment order with their appointment times.
> 4. Observe whether the group is chronological.

### CAND-0003: Correspondence Cancel lost its unsaved-edit confirmation

- Preconditions: A Correspondence create or edit form contains an unsaved change.
- Expected: Cancel asks the clinician to confirm before discarding the letter edit.
- Actual: The correspondence-specific jQuery UI confirmation handler was removed.
  Static inspection cannot decide whether the generic action immediately discards
  the edit or whether the control becomes a no-op.
- Predicate: Clicking Cancel shows no confirmation before leaving or failing to act.
- Distinctness key: `Correspondence | cancel edited letter | unsaved content | no confirmation | removed jQuery UI handler`.
- Severity and type: medium, potential clinical text loss.
- Discovery: agents 03 and 04, independently duplicated at discovery.
- Code note: `protected/modules/OphCoCorrespondence/assets/js/module.js`, commit `f5533373247979e5fca2353368e67a8beaf2a66d`.
- Verification state: R1 in progress with a different agent.

> 1. Open a Correspondence create or edit form.
> 2. Change the body or recipient without saving.
> 3. Click 'Cancel'.
> 4. Check whether a confirmation appears before the edit is discarded.

### CAND-0004: Existing dot-containing correspondence shortcode parameters no longer expand

- Preconditions: Correspondence reference data includes a shortcode parameter
  containing a dot, accepted by the previous grammar.
- Expected: An existing shortcode such as `[abc:param.one]` is substituted in the
  editor and server-generated letter.
- Actual: The develop JavaScript and PHP parameter regexes no longer accept a dot,
  so the shortcode can remain visible and unresolved.
- Predicate: Previewed or saved letter text still contains the literal shortcode.
- Distinctness key: `Correspondence | expand existing shortcode | dot parameter | literal shortcode remains | narrowed JS and PHP grammar`.
- Severity and type: medium, correspondence compatibility.
- Discovery: agent 04, static only.
- Code note: `protected/modules/OphCoCorrespondence/components/OphCoCorrespondence_Substitution.php:56` and `assets/js/OpenEyes.OphCoCorrespondence.LetterMacro.js:70`, commit `32acdeb0ce8cb97d94e905d39b015ae5f3bf8c02`.
- Verification state: blocked pending a configured dot-parameter shortcode.

> 1. Open a Correspondence form with an existing dot-parameter shortcode configured.
> 2. Insert the shortcode into the letter body.
> 3. Preview or save the letter.
> 4. Check whether the literal shortcode remains instead of its clinical text.

### CAND-0005: Add Episode may have lost modal and close behavior

- Preconditions: The patient needs a new episode during Add Event.
- Expected: The Add Episode form opens as a modal with a clear close or cancel path.
- Actual: The `CJuiDialog` wrapper was replaced by a plain hidden div and the old
  title-bar close behavior was removed. Surrounding replacement behavior is not
  established by the changed view alone.
- Predicate: The form appears inline, behind other content, or without an actionable
  close path when invoked.
- Distinctness key: `Add Event | create episode | no suitable episode | broken modal or close path | removed CJuiDialog wrapper`.
- Severity and type: medium, navigation and UI.
- Discovery: agent 03, static only.
- Code note: `protected/views/patient/add_new_episode.php:21`, commit `f5533373247979e5fca2353368e67a8beaf2a66d`.
- Verification state: browser replay in progress.

> 1. Open a patient who needs a new episode.
> 2. Click 'Add Event' and enter the new-episode path.
> 3. Inspect the form placement and available close controls.
> 4. Click the visible cancel or close control and check that the form closes.
