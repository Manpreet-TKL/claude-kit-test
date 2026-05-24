---
name: oe_db_schema
description: OpenEyes database schema and clinical domain model — Patient → Episode → Event → Element, eye laterality, Pathway/Worklist, Firm/Site/Institution/Subspecialty, RBAC (authitem/authassignment), diagnoses/allergies/medications layers, Element_* naming, versioning (`<table>_version`), soft-delete defaults. Invoke explicitly when designing migrations, reasoning about model relations, or writing reports. Volatile detail (current table inventories, recent migrations) lives in subs/.
disable-model-invocation: true
---

# OpenEyes data model

OpenEyes is **event-based**: every clinical interaction is an `event` row attached to an `episode` attached to a `patient`. Reports, audit, RBAC, and integrations are all layered on top of that spine.

> Schema changes are clinical-safety changes. Never alter persistence, calculations, units, or display of clinical values without an explicit ask. Never bypass `audit` writes. See `oe_coding_standards`.

## The spine

```
Patient ─┬─ PatientIdentifier(s)     NHS num, hospital num, MRN, study ID
         ├─ Address(es), Contact     Letter / phone / email targets
         ├─ Gp, Practice, CommissioningBody
         ├─ Allergies, SocialHistory, PatientOphInfo
         ├─ Referrals (PatientReferral, PatientUserReferral)
         ├─ EventMedicationUse       Patient-level medication list
         ├─ Episodes ──── one per Subspecialty / care pathway
         │      │  episode.firm_id, episode.disorder_id (primary diagnosis)
         │      └─ Events ──── one clinical encounter or document
         │             │  event.event_type_id → module; event.event_date
         │             │  event.episode_id, parent_id, step_id, worklist_patient_id
         │             ├─ Element_<Module>_<Name> rows (one per element type)
         │             ├─ EventDraft (autosave)
         │             ├─ EventImage(s) (lightning previews)
         │             ├─ EventIssue(s) (flagged for follow-up)
         │             └─ EsignElement (signature / PIN approval)
         ├─ secondary_diagnosis      Patient-level extra diagnoses
         └─ PatientStatistic / Datapoint   Pre-computed dashboard rollups
```

## Core entities

### Patient (`patient`)
- Demographics: `title`, `first_name`, `last_name`, `dob`, `date_of_death`, `gender`, `ethnic_group_id`, `patient_source`, `primary_institution_id`.
- `hos_num` and `nhs_num` are **legacy** columns. The modern source of truth is `PatientIdentifier` rows joined by type. Use `PatientIdentifierHelper` to resolve "the hospital number at site X" — don't hard-code columns.
- `no_allergies_date` / `no_risks_date` are **explicit "asked and answered: none"** markers. A blank list ≠ unrecorded.
- Behaviours: `ContactBehavior`, `HasFactory`, `HasDiagnoses`, `ModelCanBeFaked`.
- Base: `BaseActiveRecordVersionedSoftDelete`.

### Episode (`episode`)
- One per `Firm` (≈ consultant team × subspecialty). `start_date` / `end_date`.
- Episode-level diagnoses: `disorder_id` (primary) + `eye_id`.
- `EpisodeStatus` is workflow state ("New" / "Diagnosed" / "Discharged").
- `support_services`, `change_tracker` flag non-clinical / admin episodes.
- `ReferralEpisodeAssignment` links a referral to an episode.

### Event (`event`)
- One clinical artefact: examination, letter, op note, consent form, etc.
- `event_type_id` → `EventType` → module. `EventSubtype` for finer typing within a module.
- `event_date` is the **clinical** date (when it happened), distinct from `created_date` (when entered).
- Versioned + soft-deletable. Soft-deleted with `delete_reason`; can be `delete_pending` (admin approves).
- `parent_id` for draft → published amendments; `step_id` references a `PathwayStep`.
- `is_automated` + `automated_source` (JSON) — events created by PASAPI / payload-processor / Mirth.
- `context_firm_id` vs `service_firm_id` — which team owns vs performs.
- Save / soft-delete fires `ClinicalEventCreatedSystemEvent`, `ClinicalEventUpdatedSystemEvent`, `ClinicalEventSoftDeletedSystemEvent`. Listeners do diagnosis re-compute, medication relinking, draft cleanup, pathway-step advancement.

### Element (`Element_<Module>_<Name>`)
- Each element type → its own table. An event composes N elements; mandatory/optional set comes from `SubspecialtySubsection` + `ElementType.display_order`.
- Element types are seeded into `element_type` rows. **New element = migration + model + widget + view + `ElementType` seed.**
- Validation lives on the element model. Widgets render.
- Elements share traits like `HasCorrectionType`, `HasWithHeadPosture`, `HasRelationOptions`.

## Eye & laterality

- `Eye` enum-model: `LEFT (1)`, `RIGHT (2)`, `BOTH (3)`.
- Per-eye data uses either two columns (`left_*`, `right_*`) or per-eye rows with `eye_id`.
- `Side` constants are used widely in OphCiExamination element widgets.

## Pathway / Worklist

- **Pathway** = the patient's journey through a clinic visit. Chain of `PathwayStep`s (arrival → triage → exam → injection → discharge).
- `PathwayType` is the template; `PathwayTypeStep` orders the `PathwayStepType`s. Per-institution overrides via `PathwayStepType_Institution`, `PathwayStepTypePresetAssignment`.
- `PathstepObserver` (registered in `eventManager`) advances step status when the relevant event saves.
- **Worklist** = a day's clinic list at a site/firm. Built from `WorklistDefinition` + `WorklistDefinitionMapping` + attendance data.
- `WorklistPatient` ties a patient to a worklist row. `worklist_patient_id` on `Event` says "this event was authored from this row".
- Filters: `WorklistFilter`, `WorklistRecentFilter`, `WorklistDisplayContext`.
- Wait-time analytics: `WorklistWaitTime[_Firm|_Site|_Subspecialty]`.
- Generated by `GenerateWorklistsCommand`; maintained by `UpdateWorklistInstancesCommand`.

## Firm / Site / Institution / Subspecialty

- **Institution** — the trust / hospital. Owns sites, firms, users.
- **Site** — a physical clinic location.
- **Subspecialty** — Glaucoma, Medical Retina, Cataract, Cornea, etc. `SubspecialtySubsection` controls which elements appear in OphCiExamination per subspecialty.
- **Firm** — a consultant team within a subspecialty at an institution. Episode ownership + user access keyed by firm via `UserFirm`, `FirmUserAssignment`, `UserFirmRights`.
- A user's **session site + selected firm + selected institution** form the data context for almost every query. See `CurrentContextSettingsService`, `DataContext`, `ApplicationContext`. Site change → `SessionSiteChangedSystemEvent` → session filters cleared.

## RBAC tables

- `authitem` — the items (roles, tasks, operations).
- `authitemchild` — hierarchy.
- `authassignment` — user → item assignments.
- Items have prefixes:
  - `Oprn*` — operational permission (`OprnEditEpisode`, `OprnCreateEvent`, `OprnInstitutionAdmin`, `OprnAccessAdminViews`, `OprnApi`, …).
  - `Task*` — task-level (`TaskViewAudit`).
  - Plain role names: `User`, `Admin`, `Edit`, `Create`.
- `bizrule` strings on items reference callables in `components/AuthRules.php` (`canEditEvent`, `canDeleteEvent`, `canRequestEventDeletion`, `canShowAllUsersInTeamUserAdder`).
- **Break-glass**: `BreakGlass` module records reason + grants scoped temporary access; logged.

## Audit table

- `audit` row written on every clinical CRUD by `AuditService` (OEShared contract → `services/AuditService.php`).
- Columns: `action`, `module`, `type`, `target_id`, `patient_id`, `episode_id`, `event_id`, `model`, `model_id`, `user_id`, `ip`, `user_agent`, `server`, `request_uri`, `data`, `created_date`.
- Rendered by the `Audit` controller. `Audit*` related tables hold the lookups for action/module/type names.
- **Bypassing audit writes is forbidden.** See `oe_coding_standards`.

## Versioning + soft-delete

- Every `BaseActiveRecordVersioned` table has a matching `<table>_version` history table. A row is appended on every save.
- `BaseActiveRecordVersionedSoftDelete` adds `deleted = 1` semantics with default scope hiding deleted rows.
- `DeletedEvent` / `DeletedEpisode` capture deletion metadata (reason, by-user, date).
- Admin/audit views opt in to seeing deleted rows.
- Generate the version table for a new model with `GenerateVersionMigrationCommand`; verify with `VerifyVersionTablesCommand`.
- Verify FK integrity across all module migrations with `VerifyForeignKeysCommand`.

## Migrations

- ~730 Yii migrations in `protected/migrations/` (core) plus per-module `migrations/`.
- Run with `OEMigrateCommand` (core) and `MigrateModulesCommand` (modules).
- For the initial DB setup: `InitialDbMigrationCommand`.
- New core migration: numeric prefix `<unix-timestamp>_<snake_name>.php` extending `OEMigration` (or `CDbMigration` for trivial schema-only changes). Module migrations live under `protected/modules/<Mod>/migrations/`.

## Where the volatile detail lives

- `subs/diagnoses-allergies-medications.md` — the disorders / allergies / medications layers and where they show up.
- `subs/letters-and-esign.md` — letter tables (`et_ophcocorrespondence_letter`, `LetterMacro`, `LetterRecipient`, `LetterEnclosure`) and the esign chain.
- `subs/identifier-and-config-tables.md` — `PatientIdentifier(Type)`, `Setting`, `InstitutionAuthentication` and the other lookup-shaped tables.
