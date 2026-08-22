# Hardcoded-id shot marker inventory

Generated 2026-08-05 against the reset sample database (container commit `53b077c089`).
Read with `oe-docs-campaign-lessons.md`; the re-pointing job is blocked on the seed manifest.

`oe:shot` markers carrying a `uri`: **335**. Of those, **220** hardcode a numeric id.

| class | distinct ids | markers |
|---|---|---|
| event-view ids | 62 | 205 |
| patient ids | 3 | 8 |
| unclassified | 3 | 7 |

## Event ids that no longer resolve - capture 404s

| id | markers | referencing pages |
|---|---|---|
| 3687003 | 3 | user-guides/patients/adding-events/laser/checklist.md<br>user-guides/patients/adding-events/laser/fundus.md<br>user-guides/patients/adding-events/laser/generic-procedure.md |
| 3687005 | 2 | user-guides/patients/adding-events/request-form/form.md<br>user-guides/patients/adding-events/request-form/overview.md |
| 3687006 | 2 | user-guides/patients/adding-events/did-not-attend/comments.md<br>user-guides/patients/adding-events/did-not-attend/overview.md |
| 3687007 | 3 | user-guides/patients/adding-events/dna-extraction/dna-extraction.md<br>user-guides/patients/adding-events/dna-extraction/dna-withdrawals.md<br>user-guides/patients/adding-events/dna-extraction/overview.md |
| 3687008 | 2 | user-guides/patients/adding-events/drug-administration/drug-administration.md<br>user-guides/patients/adding-events/drug-administration/overview.md |
| 3687009 | 2 | user-guides/patients/adding-events/document/document-upload.md<br>user-guides/patients/adding-events/document/overview.md |
| 3687011 | 2 | user-guides/patients/adding-events/genetic-results/overview.md<br>user-guides/patients/adding-events/genetic-results/test.md |
| 3687012 | 3 | user-guides/patients/adding-events/lab-results/details.md<br>user-guides/patients/adding-events/lab-results/lab-results-entry.md<br>user-guides/patients/adding-events/lab-results/overview.md |
| 3687013 | 1 | user-guides/patients/adding-events/prescription/e-sign.md |
| 3687014 | 2 | user-guides/patients/adding-events/intravitreal-injection/checklist.md<br>user-guides/patients/adding-events/intravitreal-injection/comments.md |
| 3687016 | 3 | user-guides/patients/adding-events/medical-device-usage-record/overview.md<br>user-guides/patients/adding-events/medical-device-usage-record/procedure.md<br>user-guides/patients/adding-events/medical-device-usage-record/selected-event.md |
| 3687017 | 1 | user-guides/patients/adding-events/operation-note/checklist.md |
| 3687019 | 16 | user-guides/patients/adding-events/examination/conjunctival-hyperaemia-grading.md<br>user-guides/patients/adding-events/examination/convergence-accommodation.md<br>user-guides/patients/adding-events/examination/corrective-head-posture.md<br>user-guides/patients/adding-events/examination/diagnoses.md<br>user-guides/patients/adding-events/examination/dr-grading.md<br>user-guides/patients/adding-events/examination/driving-advice.md<br>... (+10) |
| 3687021 | 25 | user-guides/patients/adding-events/examination/birth-history.md<br>user-guides/patients/adding-events/examination/botox-management.md<br>user-guides/patients/adding-events/examination/checklist.md<br>user-guides/patients/adding-events/examination/contacts.md<br>user-guides/patients/adding-events/examination/corneal-tomography.md<br>user-guides/patients/adding-events/examination/correction-given.md<br>... (+19) |

## Event ids that resolve - to whatever the reset re-issued them to

The event type below is what a capture would actually photograph today.

| id | current event type | markers | referencing pages |
|---|---|---|---|
| 2544871 | Therapy Application | 1 | user-guides/patients/adding-events/therapy-application/exceptional-circumstances.md |
| 2743483 | Examination | 1 | user-guides/patients/adding-events/examination/van-herick.md |
| 3142075 | Operation note | 1 | user-guides/patients/adding-events/operation-note/trabectome.md |
| 3357108 | Operation note | 1 | user-guides/patients/adding-events/operation-note/membrane-peel.md |
| 3521882 | Correspondence | 1 | user-guides/patients/adding-events/correspondence/e-sign.md |
| 3547850 | Examination | 1 | user-guides/patients/adding-events/examination/colour-vision.md |
| 3553177 | Examination | 2 | user-guides/patients/adding-events/examination/adnexal.md<br>user-guides/patients/adding-events/examination/comorbidities.md |
| 3561879 | Therapy Application | 5 | user-guides/patients/adding-events/therapy-application/diagnosis.md<br>user-guides/patients/adding-events/therapy-application/mr-service-information.md<br>user-guides/patients/adding-events/therapy-application/overview.md<br>user-guides/patients/adding-events/therapy-application/patient-suitability.md<br>user-guides/patients/adding-events/therapy-application/relative-contra-indications.md |
| 3566251 | Operation note | 2 | user-guides/patients/adding-events/operation-note/tamponade.md<br>user-guides/patients/adding-events/operation-note/vitrectomy.md |
| 3627231 | Examination | 1 | user-guides/patients/adding-events/examination/oct-manual.md |
| 3627699 | Operation note | 1 | user-guides/patients/adding-events/operation-note/glaucoma-tube.md |
| 3656622 | Examination | 2 | user-guides/patients/adding-events/examination/optic-disc.md<br>user-guides/patients/adding-events/examination/risks.md |
| 3663116 | Intravitreal injection | 8 | user-guides/patients/adding-events/intravitreal-injection/anaesthetic.md<br>user-guides/patients/adding-events/intravitreal-injection/anterior-segment.md<br>user-guides/patients/adding-events/intravitreal-injection/complications.md<br>user-guides/patients/adding-events/intravitreal-injection/injection-management.md<br>user-guides/patients/adding-events/intravitreal-injection/overview.md<br>user-guides/patients/adding-events/intravitreal-injection/post-injection-examination.md<br>... (+2) |
| 3663348 | Phasing | 2 | user-guides/patients/adding-events/phasing/intraocular-pressure-phasing.md<br>user-guides/patients/adding-events/phasing/overview.md |
| 3682283 | Examination | 1 | user-guides/patients/adding-events/examination/drops.md |
| 3684965 | Examination | 1 | user-guides/patients/adding-events/examination/conclusion.md |
| 3686331 | Biometry | 4 | user-guides/patients/adding-events/biometry/biometry.md<br>user-guides/patients/adding-events/biometry/calculation.md<br>user-guides/patients/adding-events/biometry/overview.md<br>user-guides/patients/adding-events/biometry/selection.md |
| 3686538 | Examination | 2 | user-guides/patients/adding-events/examination/glaucoma-overall-plan.md<br>user-guides/patients/adding-events/examination/investigation.md |
| 3686546 | Correspondence | 1 | user-guides/menu-bar/core/docman-index.md |
| 3686552 | Examination | 5 | user-guides/patients/adding-events/examination/allergies-and-intolerances.md<br>user-guides/patients/adding-events/examination/cct.md<br>user-guides/patients/adding-events/examination/family-history.md<br>user-guides/patients/adding-events/examination/gonioscopy.md<br>user-guides/patients/adding-events/examination/social-history.md |
| 3686556 | Examination | 2 | user-guides/patients/adding-events/examination/clinical-outcome.md<br>user-guides/patients/adding-events/examination/ophthalmic-surgical-history.md |
| 3686565 | Operation note | 2 | user-guides/patients/adding-events/operation-note/application-of-mmc.md<br>user-guides/patients/adding-events/operation-note/trabeculectomy.md |
| 3686572 | Examination | 1 | user-guides/patients/adding-events/examination/bleb-assessment.md |
| 3686575 | Examination | 1 | user-guides/patients/adding-events/examination/optometrist-comments.md |
| 3686589 | Examination | 1 | user-guides/patients/adding-events/examination/near-visual-acuity.md |
| 3686590 | Message | 2 | user-guides/patients/adding-events/message/message.md<br>user-guides/patients/adding-events/message/overview.md |
| 3686591 | Operation note | 1 | user-guides/patients/adding-events/operation-note/cataract.md |
| 3686592 | Prescription | 2 | user-guides/patients/adding-events/prescription/details.md<br>user-guides/patients/adding-events/prescription/overview.md |
| 3686595 | Examination | 2 | user-guides/patients/adding-events/examination/anterior-segment.md<br>user-guides/patients/adding-events/examination/post-op-complications.md |
| 3686596 | Examination | 1 | user-guides/patients/adding-events/examination/refraction.md |
| 3686600 | Laser | 2 | user-guides/patients/adding-events/laser/comments.md<br>user-guides/patients/adding-events/laser/posterior-pole.md |
| 3686601 | Examination | 2 | user-guides/patients/adding-events/examination/laser-management.md<br>user-guides/patients/adding-events/examination/macula.md |
| 3686602 | Laser | 4 | user-guides/patients/adding-events/laser/anterior-segment.md<br>user-guides/patients/adding-events/laser/overview.md<br>user-guides/patients/adding-events/laser/site.md<br>user-guides/patients/adding-events/laser/treatment.md |
| 3686604 | Operation booking | 6 | user-guides/patients/adding-events/operation-booking/contact-details.md<br>user-guides/patients/adding-events/operation-booking/diagnosis.md<br>user-guides/patients/adding-events/operation-booking/operation.md<br>user-guides/patients/adding-events/operation-booking/overview.md<br>user-guides/patients/adding-events/operation-booking/pre-assessment.md<br>user-guides/patients/adding-events/operation-booking/schedule-operation.md |
| 3686605 | Consent form | 7 | user-guides/patients/adding-events/consent-form/additional-signatures.md<br>user-guides/patients/adding-events/consent-form/benefits-and-risks.md<br>user-guides/patients/adding-events/consent-form/leaflets.md<br>user-guides/patients/adding-events/consent-form/overview.md<br>user-guides/patients/adding-events/consent-form/procedure.md<br>user-guides/patients/adding-events/consent-form/supplementary-consent.md<br>... (+1) |
| 3686606 | Operation note | 8 | user-guides/patients/adding-events/operation-note/anaesthetic.md<br>user-guides/patients/adding-events/operation-note/comments.md<br>user-guides/patients/adding-events/operation-note/generic-procedure.md<br>user-guides/patients/adding-events/operation-note/location.md<br>user-guides/patients/adding-events/operation-note/overview.md<br>user-guides/patients/adding-events/operation-note/per-operative-drugs.md<br>... (+2) |
| 3686607 | Examination | 7 | user-guides/patients/adding-events/examination/clinical-management.md<br>user-guides/patients/adding-events/examination/glaucoma-current-plan.md<br>user-guides/patients/adding-events/examination/history.md<br>user-guides/patients/adding-events/examination/intraocular-pressure.md<br>user-guides/patients/adding-events/examination/medication-history.md<br>user-guides/patients/adding-events/examination/pupils.md<br>... (+1) |
| 3686608 | Correspondence | 2 | user-guides/patients/adding-events/correspondence/letter.md<br>user-guides/patients/adding-events/correspondence/overview.md |
| 3686611 | Examination | 1 | user-guides/patients/adding-events/examination/glaucoma-risk.md |
| 3686616 | Examination | 1 | user-guides/patients/adding-events/examination/observations.md |
| 3686734 | Device Information | 1 | user-guides/patients/adding-events/device-information/assessment.md |
| 3686996 | Checklist | 2 | user-guides/patients/adding-events/checklist/checklist.md<br>user-guides/patients/adding-events/checklist/overview.md |
| 3686997 | Did Not Attend | 8 | user-guides/patients/adding-events/consent-form/assessment-of-patient-s-capacity.md<br>user-guides/patients/adding-events/consent-form/best-interest-decision.md<br>user-guides/patients/adding-events/consent-form/consent-taken-by.md<br>user-guides/patients/adding-events/consent-form/independent-medical-capacity-advocate.md<br>user-guides/patients/adding-events/consent-form/others-involved-in-the-decision-making-process.md<br>user-guides/patients/adding-events/consent-form/patient-s-attorney-or-deputy.md<br>... (+2) |
| 3686998 | Lab Results | 6 | user-guides/patients/adding-events/consent-form/advanced-decision.md<br>user-guides/patients/adding-events/consent-form/confirm-consent.md<br>user-guides/patients/adding-events/consent-form/copies.md<br>user-guides/patients/adding-events/consent-form/e-sign.md<br>user-guides/patients/adding-events/consent-form/extra-procedures.md<br>user-guides/patients/adding-events/consent-form/patient-questions.md |
| 3686999 | Cat-PROM5 | 12 | user-guides/patients/adding-events/examination/accessibility-communication.md<br>user-guides/patients/adding-events/examination/advice-given.md<br>user-guides/patients/adding-events/examination/cataract-surgical-management.md<br>user-guides/patients/adding-events/examination/clinic-procedures.md<br>user-guides/patients/adding-events/examination/contrast-sensitivity.md<br>user-guides/patients/adding-events/examination/cvi-status.md<br>... (+6) |
| 3687000 | Document | 7 | user-guides/patients/adding-events/cvi/clerical-info.md<br>user-guides/patients/adding-events/cvi/clinical-info.md<br>user-guides/patients/adding-events/cvi/consent.md<br>user-guides/patients/adding-events/cvi/demographics.md<br>user-guides/patients/adding-events/cvi/e-sign.md<br>user-guides/patients/adding-events/cvi/event-info.md<br>... (+1) |
| 3687001 | CVI | 2 | user-guides/patients/adding-events/cat-prom5/overview.md<br>user-guides/patients/adding-events/cat-prom5/questionnaire.md |
| 3687002 | Medical Device Usage Record | 2 | user-guides/patients/adding-events/dna-sample/overview.md<br>user-guides/patients/adding-events/dna-sample/sample.md |

## Patient ids (stable across a wholesale sample restore)

| id | resolves | markers | referencing pages |
|---|---|---|---|
| 17887 | NO | 1 | user-guides/patients/adding-events/add-event-dialog.md |
| 17891 | NO | 4 | user-guides/patients/adding-events/add-event-dialog.md<br>user-guides/patients/patient-summary/patient-lightning-viewer.md<br>user-guides/patients/patient-summary/patient-summary.md<br>user-guides/patients/patient-summary/patient-view.md |
| 1919586 | NO | 3 | user-guides/patients/adding-events/add-event-dialog.md |

## Unclassified uri shapes - triage by hand

| id | resolves as event | markers | sample uri |
|---|---|---|---|
| 15041 | no | 1 | `/gp/view/15041` |
| 109006 | no | 1 | `/disorder/view/109006` |
| 3686604 | Operation booking | 5 | `/OphTrOperationbooking/whiteboard/view/3686604` |
