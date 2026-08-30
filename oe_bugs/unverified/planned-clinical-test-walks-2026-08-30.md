# Planned OpenEyes clinical test walks - not executed

- Recorded: 2026-08-30.
- Status: planning inventory only. Frontend bug testing stopped at the user's
  request and none of these walks is authorised for execution.
- Counting: a planned walk is not a bug and contributes zero to every verified or
  unverified bug count until it produces a distinct candidate.

## Examination lifecycle

- Create, abandon, resume, delete draft, save, view, edit, copy forward, amend,
  print, and delete an Examination where permitted.
- Add, remove, collapse, reorder, and re-add optional elements; vary mandatory and
  context-restricted elements.
- Vary left, right, and both-eye state after entering values; check preservation
  through validation failures.
- Exercise Visual Acuity, refraction, and IOP with simple and complex inputs,
  boundary values, units, corrections, and unavailable-to-assess states.
- Exercise Clinic Outcome, follow-up, discharge, RTT, CVI, pathway completion, and
  mismatched event-versus-session worklist context.
- Exercise strabismus, motility, Nine Positions, sensory function, measurements,
  ocular movements, EyeDraw persistence, and mode switching.
- Exercise investigations, clinic procedures, report widgets, clinical images,
  and history views.
- Exercise diagnoses, risks, allergies, family history, and medication-history
  add, edit, remove, copy-forward, and saved-state behavior.
- Remove every Clinic Outcome row from an existing event and test the required
  outcome rule.

## Medication and prescribing lifecycle

- Start a medication, stop it, restart it, change its dose or route, and stop it
  again while checking every displayed and stored date and status.
- Exercise duplicate drugs, different preparations and routes, taper rows, PRN,
  allergies, interactions, inactive reference data, and inverted dates.
- Reopen Drug Administration events with administered and unadministered rows;
  refresh assignments, omit a row, save, and compare persisted state.
- Exercise intravitreal treatment sequence creation, edit, laterality, history,
  same-second versioning, prescribing-disabled behavior, and worklist state.
- Exercise unsigned, draft, signed, edited-after-signing, and bulk-PIN injection
  prescription states; compare signed content with the clinical treatment.
- Create, edit, duplicate, sign, print, and reopen Prescription events, including
  the duplicate-day warning and its close control.
- Close the Biometry manual-entry warning with both OK and the title-bar control,
  then compare worklist step state.

## Correspondence and signatures

- Create a letter from blank and from a template, switch templates after edits,
  cancel, save, reopen, amend, preview, print, and email.
- Insert Quick Text with plain lines, mixed HTML, leading or trailing blank lines,
  and shortcode parameters containing punctuation.
- Add, remove, and reorder recipients, attachments, macros, and copy-to entries.
- Exercise GP, practice, internal referral, mailbox, deceased, no-GP,
  missing-email, and out-of-office recipient states.
- Exercise PIN and non-PIN signatures, delegates, multiple signers, validation
  round trips, and history views.

## Other clinical events and administration

- Exercise DR Grading photograph and reference-image controls, grading history,
  electronic signing, and clinical versus national reference lists.
- Exercise Operation Note procedure laterality, save, view, and automatic-letter
  generation.
- Exercise Biometry formula, lens, manual entry, device report, signing, warning,
  and worklist flows.
- Reorder and save clinical reference data, then verify that order reaches the
  clinician-facing picker rather than only the administration screen.
- Exercise worklist filters, categories, mappings, pathway groups, and restoration
  after validation errors.
- Review clinical shortcuts, reports, OEScape widgets, and image timing.

## jQuery removal regression inventory

- Dialog open, close, confirm, and cancel controls.
- Date inputs, autocomplete, adders, dynamic delegated handlers, and validation
  round trips.
- Sortable and draggable lists, tabs, tooltips, and controls inserted after page
  load.
- Removed handlers for DR Grading images, existing patient risks, Correspondence
  cancel, and duplicate-prescription warnings.
- Changed selectors, old event shorthands, jQuery UI method calls, and handlers
  bound before their dynamic markup exists.

## Reverification backlog

- Recheck the nine older verified entries against the pinned target.
- Recheck imported OpenEyes records O1 through O24, O25 through O48, O49 through
  O72, and O73 through O96, excluding withdrawn and provenance-only records.
- Independently review the highest-risk medication, correspondence, signature,
  data-loss, and jQuery candidates before any future live replay.
