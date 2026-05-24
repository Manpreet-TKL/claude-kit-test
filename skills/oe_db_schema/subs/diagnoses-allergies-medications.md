# Diagnoses, allergies, medications (volatile schema)

This is the most layered area of the schema — the same clinical fact (a patient's diagnoses) shows up in 6+ places and is reconciled by the `Diagnoses` module on every `ClinicalEvent*SystemEvent`.

## Disorders (the SNOMED layer)

- `disorder` — master SNOMED-CT term table. Every diagnosis ultimately references `disorder_id`.
- `CommonOphthalmicDisorder` + `CommonOphthalmicDisorderGroup` — curated shortlists, scoped per subspecialty / institution.
- `CommonSystemicDisorder` + `CommonSystemicDisorderGroup` — curated systemic comorbidity shortlists.
- `DisorderChangePolicy` / `DisorderChangePolicyRule` — RBAC for editing diagnoses (some only settable by specific roles).

## Where diagnoses live

1. `episode.disorder_id` (+ `eye_id`) — principal diagnosis of an episode.
2. `secondary_diagnosis` — patient-level extra diagnoses.
3. `Element_OphCiExamination_Diagnoses` → `OphCiExamination_Diagnosis` rows — captured at a specific examination, each with eye + principal flag.
4. `Element_OphTrOperationbooking_Diagnoses` / `_Diagnosis` — diagnosis set chosen at booking.
5. `OphCoCvi_ClinicalInfo_Disorder_Assignment` — diagnoses on a CVI cert.
6. `GeneticsPatientDiagnosis` — research-tracked.

The **`Diagnoses` module** reconciles these into a single canonical patient diagnosis set on every `ClinicalEvent*SystemEvent`. **Don't add a new "diagnosis place" without wiring it into that reconciliation.**

## Allergies & risks

- `Allergy` (master) + `OphCiExaminationAllergy` (patient-level recording) + `AllergyCategory` / `AllergySeverity` / `AllergyEntry`.
- `MedicationAllergyAssignment` — allergy to a specific medication.
- `PatientRiskAssignment` — flagged risks (anti-coagulants, blood-thinners, …); fed by `Risks` and `HistoryRisk` examination elements.
- `no_allergies_date` / `no_risks_date` on `Patient` are the explicit "asked, none" markers.

## Medications

- `Medication` (master) + `MedicationSearchIndex`, `MedicationForm`, `MedicationRoute`, `MedicationFrequency`, `MedicationDuration`, `MedicationLaterality`.
- `MedicationSet` + `MedicationSetAutoRuleAttribute` — grouped picks (e.g. "common pre-op drops").
- `EventMedicationUse` — patient's current medication list. Populated by `UpdatePatientMedicationLinksAfterEventSave` listener whenever a clinical event references a medication.
- `MedicationAdherence` / `MedicationAdherenceLevel` — recorded adherence.
- `Drug` is the **legacy** table superseded by `Medication`. `MedicationDrug`, `ArchiveMedication`, `OldMedicationAndDrugDeletionCommand` manage the transition. **Don't write new code against `Drug`** — read/write through `Medication`.
