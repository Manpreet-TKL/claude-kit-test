# OpenEyes clinical-module catalogue (volatile)

~45 modules under `protected/modules/`. List drifts as modules are added or merged. Always confirm against the `$modules` array in `core/common.php` (grep for the `'modules'` key / the `$modules` assignment - don't trust a line number, it moves), and remember a deployment's `local/common.php` + Docker `modules.conf` can switch modules on or off. A handful below are **external/site-specific** and absent from a base core checkout - flagged inline.

## Encounters & examinations

- **OphCiExamination** - the workhorse; most-created event type. ~59 element types - see `examination-elements.md`.
- **OphCiPhasing** - diurnal IOP phasing. Multiple timed IOP readings on one or both eyes.
- **OphCiDidNotAttend** - DNA/UTA outcomes with comments.

## Correspondence / documents

- **OphCoCorrespondence** - letter generation. `ElementLetter` (TinyMCE HTML body), `LetterMacro[_Firm|_Site|_Subspecialty|_Institution]`, esign via `Element_OphCoCorrespondence_Esign`.
- **OphLeEpatientletter** *(external - not in a base core checkout)* - secure patient-facing electronic letter. There is **no** `OphLe*` dir in core; core letters are `OphCoCorrespondence`.
- **Referral** - patient referral handling, and the cleanest **replatform exemplar** in the tree: legacy `models/`/`controllers/` alongside PSR-4 `dto/ repositories/ factories/ seeders/`. Reach for it when you want to see the new `OE\...` patterns in a real module.
  - **RTT clock feature** (develop, 2026): models `RTTClockState`/`RTTClockStateOption(Group)`/`RTTClockStateValidNext`, `components/RTTClockDisplayResolver`, `widgets/RTTClock`, `controllers/traits/ValidatesAndSavesRTT`, ReferralAdmin option(-group) controllers. Tables `referral_referral` + `referral_referral_rtt_clock_state` (+ `_option`/`_option_group`/`_valid_next`). Gated by `enable_rtt_clock_bar` (default 0); `rtt_alert_threshold_weeks=18`, breach = wait > 126 days. Option lookups need `code` AND `type` - codes 20/34 exist twice (enum type Outcome/DNA); display column is `display_value`, not `name`; latest state per referral = MAX(id). ClinicOutcome link via `ophciexamination_clinicoutcome_status.rtt_clock_state_option_group_id`. Laravel xAPI: `GET /xapi/referrals/{id}/current-rtt-clock-state`, `/xapi/referral-pas-identifiers/{pasId}/current-rtt-clock-state`, `/xapi/rtt-clock-states/{id}` (`oe-laravel/routes/api.php`).
- **OphCoDocument** - generic external document attachment event. Uses `FileStorage`.
- **OphCoMessaging** - secure in-EHR user-to-user messaging on a patient's record.
- **OphCoRequestForm** - generic request form events (imaging, lab, etc.).
- **OphCoChecklist** - generic clinical checklist event.
- **OphCoTherapyapplication** - funding/IFR workflow with configurable decision tree.
- **OphCoCvi** - Certificate of Visual Impairment (statutory, UK). Multi-element.

## Surgical / treatment

- **OphTrOperationbooking** - books surgical procedure. ERoD calculation lives here (`params.erod_lead_time_weeks`).
- **OphTrOperationnote** - surgical record. Includes `OpNote`, `Cataract`, `GenericProcedure`, `Anaesthetic`, `Surgeon`, `SiteTheatre`, `PostOpDrugs`, `Buckle`, `CXL`, `MembranePeel`, `GlaucomaTube`, `PreserFloMicroShunt`, `Mmc`, `RevisionAqueousShunt`, `Checklist`, `Biometry`.
- **OphTrConsent** - surgical consent form. Capacity assessment, advanced decision, esign.
- **OphTrIntravitrealinjection** - IVI event. Batched via `IVTBookingScreenCommand`.
- **OphTrLaser** - clinic-room laser treatment event.
- **OphTrOperationchecklists** - WHO-style sign-in/time-out/sign-out checklists.

## Investigations / results

- **OphInBiometry** - IOL biometry data, often imported from Lenstar/IOLMaster.
- **OphInVisualfields** - Humphrey/Octopus visual field results.
- **OphInLabResults** - generic lab result event (e.g. HbA1c).
- **OphInGeneticresults** - genetic testing results.
- **OphInDnasample** / **OphInDnaextraction** - sample tracking for genetics.
- **OphInMehPac** *(site-specific - may be absent)* - Moorfields PAC integration event.
- **OphGeneric** - catch-all event type for auto-imported data through Api / payload-processor.

## Drugs / prescribing

- **OphDrPrescription** - prescription event. `Element_OphDrPrescription_Details` + `OphDrPrescription_Item` rows.
- **OphDrPGDPSD** - Patient Group / Patient Specific Directive administration.

## Patient-reported outcomes

- **OphOuCatprom5** - Cat-PROM5 cataract surgery patient-reported outcome questionnaire.

## Workflow / cross-cutting

- **PatientTicketing** - virtual-clinic / triage workflow. `Queue`, `QueueSet`, `Priority`, `QueueOutcome`.
- **OECaseSearch** - clinical cohort search. Composable parameter classes.
- **Diagnoses** - central diagnosis-tracking infrastructure. `HasDiagnoses` trait + `DiagnosesManager` listens to `ClinicalEvent*SystemEvent`s.

## Research

- **Genetics** - pedigree / relationship modelling.
- **OETrial** - clinical trial management.

## Integrations

- **PASAPI** - legacy Yii REST module for Patient Administration Systems (XML/JSON inbound). Prefer Laravel xAPI for new endpoints.
- **Mirth** - HL7 integration helpers.
- **EventExport** - outbound event export for NOD / external analytics.
- **Webhooks** - outbound webhook subscriptions on system events.
- **FileStorage** - pluggable file storage backend (local FS, S3).
- **EventSupport** - shared utilities for event attachments.
- **Api** - legacy Yii REST module.
- **TrDeviceUsageRecord** - medical-device usage logging (procedure -> device consumable mapping).

## System / admin

- **Admin** - generic admin views (`BaseAdminController`, `ModuleAdminController`, `oldadmin`).
- **YiiAuth** - authentication adapter module.
- **BreakGlass** - emergency-access workflow (timed, reason-required, audited).
- **OESysEvent** - infrastructure for typed system-events (`ClinicalEventSaveCompleteSysEvent`, `SessionSiteChangedSystemEvent`, `UserSavedSystemEvent`, `WebUserLoggedInSysEvent`).
- **OEExceptionHandler** - error-handling override.
- **TestHelper** - Cypress seed-data routes. **Never run in production** (`OE_MODE !== 'live'`).
- **eyedraw** *(external - not in a base core checkout)* - Eyedraw assets + report-text policy admin; the `OEEyeDrawWidget` renderer.
- **mehstaffdb** *(external/site-specific)* - central staff DB integration.

## voiceControl (per memory)

`voiceControl` is its own module and must remain independent of `aiSearch`. No runtime dependency, no shared service container key.
