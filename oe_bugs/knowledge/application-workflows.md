# OpenEyes application workflow learnings

These notes separate version-matched code facts from browser-verified behavior.
Candidate behavior is not treated as application truth until replay succeeds.

## Patient Summary

- On the pinned develop target, opening an existing patient reaches the Diagnoses
  Patient Summary widget before Add Event is available.
- That widget maps the Patient active record into `PatientDTO`. The current model
  and DTO constructor are incompatible, so the whole summary returns HTTP 500.
  This was reproduced with five different existing patients.

## Examination

- The DR Grading element renders a photo control for a grading reference image.
  Its old jQuery UI dialog setup and click handler were removed on `develop`, but
  the form control remains. Browser replay is in progress.
- Examination is module-specific in its draft lifecycle. Opening its create form
  can create an episode and an event draft before the clinician saves an event.
  This replay-source observation still needs current-target verification.

## Drug Administration

- The Drug Administration widget separates relevant assignments from inactive or
  otherwise irrelevant assignments before rendering.
- Develop code intends to order the irrelevant group by the associated worklist
  appointment time. The comparator currently needs browser verification because
  its right-hand comparison reads the first assignment again.

## Correspondence

- Correspondence previously added its own confirmation before a clinician
  cancelled an edited letter. The jQuery UI removal commit removed that handler.
  A generic form cancel path remains, so browser replay must decide whether the
  result is an immediate discard or a no-op.
- Letter shortcodes are expanded in both JavaScript and PHP. The develop grammar
  accepts lowercase letters, hyphens, and comma-separated modifiers; existing
  dot-containing parameters are a compatibility candidate awaiting replay with
  configured reference data.

## Add Event

- Episode selection is part of the Add Event flow for patients without a suitable
  existing episode. The old `CJuiDialog` wrapper was replaced with plain markup.
  Browser replay is checking which surrounding controller now supplies modal and
  close behavior.
- Patient Summary is currently a global prerequisite blocker for normal Add Event
  walking. Direct module routes should not be substituted because they would no
  longer reproduce the clinician's ordinary path.
