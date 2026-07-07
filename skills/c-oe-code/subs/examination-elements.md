# OphCiExamination element catalogue (volatile)

~59 element types in `protected/modules/OphCiExamination/models/Element_OphCiExamination_*`. Which elements appear for which subspecialty / visit type is controlled by `ElementType` rows + `SubspecialtySubsection` and `EventSubtype`. Cross-check the directory before relying on any specific element name.

## History / context

`History`, `HistoryRisk`, `Triage`, `AE_RedFlags`, `Comorbidities`, `AdnexalComorbidity`, `Contacts`, `Pain`, `Risks`, `Safeguarding`, `Driving_Safety`, `Observations`.

## Visual function

`VisualAcuity`, `NearVisualAcuity`, `ColourVision`, `ContrastSensitivity` (+ `_Result` / `_Type`), `Refraction`, `Keratometry`.

## Anterior segment

`AnteriorSegment`, `AnteriorSegment_CCT`, `Cornea`, `Slit_Lamp`, `Specular_Microscopy`, `PupillaryAbnormalities`, `ConjunctivalHyperaemia`, `BlebAssessment`.

## Posterior segment / retina

`OpticDisc`, `Fundus`, `PosteriorPole`, `OCT`, `DRGrading`, `DR_Maculopathy`, `DR_Retinopathy`.

## Glaucoma

`IntraocularPressure`, `Gonioscopy`, `GlaucomaRisk`, `BlebAssessment`.

## Strabismus / orthoptics

`CoverAndPrismCover` (+ `_Distance`, `_Entry`, `_HorizontalPrism`, `_VerticalPrism`), `ConvergenceAccommodation`, `CorrectionGiven`, `CorrectionType`.

## Diagnosis

`Diagnoses` - examination-recorded diagnoses with eye + principal flag (joined via `OphCiExamination_Diagnosis` rows).

## Plan / management

`Management`, `OverallManagementPlan`, `CurrentManagementPlan`, `Conclusion`, `NextSteps`, `Investigation`, `ClinicOutcome`, `ClinicProcedures`.

## Treatment / drugs in clinic

`DrugAdministration`, `DrugAdministration_record`, `LaserManagement`, `InjectionManagement` / `InjectionManagementComplex` / `InjectionManagement_v2`, `Dilation`.

## Risk scoring

`PcrRisk` (cataract complication), `PostOpComplications`, `CataractSurgicalManagement` (+ archive).

## CXL (corneal cross-linking)

`CXL_History`, `CXL_Outcome`.

## Statutory / shared

`CVI_Status`, `Checklist`, `AreaOfCare` (+ `AreaOfCareEntry`, `AreaOfCare_Disorder_Assignment`, `AreaofCare_Institution_Assignment`), `OptomComments`.

## Linked support models

`AISFlag(Group)`, `AccessibilityAndCommunication`, `AdviceGiven`, `AdviceLeaflet` + `AdviceLeafletCategory*`, `Allergies` / `AllergyEntry` / `AllergyCategory` / `AllergySeverity`, `BirthHistory` (paediatric), `BotoxManagement` + lookups, `AutomaticExaminationEventLog`.

## Adding a new element

The element model + view-triad + `element_type` mechanics live in
`event-element-model.md` (and the UI side in `c-oe-ui`
`subs/clinical-element-views.md`) - read those first. In short: migration (adds the
`et_...` table **and** the `element_type` seed row) + model + view triad
(`form_`/`view_`/`print_`) and/or widget triad. Elements extend
`BaseEventTypeElement` **directly or via a module-local base** - most
OphCiExamination elements extend it directly, but some modules interpose their own
(e.g. OphTrOperationnote's `Element_OpNote`/`Element_OnDemand`). For the modern
trait-driven pattern see the Strabismus implementation (bar-setter for
`HasCorrectionType`, `HasWithHeadPosture`, `HasRelationOptions`); for surrounding
scaffolding see `create-oe-module`.
