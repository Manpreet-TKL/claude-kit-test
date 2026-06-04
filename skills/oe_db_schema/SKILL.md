---
name: oe_db_schema
description: OpenEyes (OE) database — DBA & schema navigation plus the clinical domain model. Covers connecting to the DB (host `dba`/`dbas` aliases, web-container `dblogin`, direct docker exec; local MariaDB container vs remote RDS; MariaDB 10.6 for OE v6–v10, 11.8 for v11–v26), the version-dependent 2300+ table layout, navigating by name (oph/et_/v_ prefixes, `<table>_version` history, `audit_*`, soft-delete), the stable core tables (user, user_session, authitem, patient, episode, event…), and the model spine (Patient → Episode → Event → Element, eye laterality, Pathway/Worklist, Firm/Site/Institution/Subspecialty, RBAC). Invoke explicitly for DBA work, writing SQL/reports, designing migrations, or reasoning about relations. Volatile detail (table inventories, migrations) lives in subs/.
disable-model-invocation: true
---

# OpenEyes database — DBA & schema navigation

OpenEyes is **event-based**: every clinical interaction is an `event` row attached to an `episode` attached to a `patient`. Reports, audit, RBAC, and integrations are all layered on top of that spine. The DB is large (2300+ tables) and mostly named after frontend / ophthalmology terms — navigate by naming convention, not by listing.

> Schema changes are clinical-safety changes. Never alter persistence, calculations, units, or display of clinical values without an explicit ask. Never bypass `audit` writes. See `oe_coding_standards`.

## Connecting (read first for DBA work)

OE runs on **MariaDB**. The DB is either a **local container** (`<project>-db-1`) or a **remote AWS RDS** instance — the app only knows `DATABASE_HOST`, so the same SQL works against either.

**MariaDB version by OE version:** 10.6 for OE v6–v10; **11.8** for v11 through the current v26. Watch for SQL-mode / syntax differences when scripting across a mixed estate.

Three ways in — pick by what you can reach:

| Route | Runs as | Works against | How |
|---|---|---|---|
| Host fn `dba [<proj>]` | **root** | local container only | `dba monkey` (omit name if one stack is up) |
| Host fn `dbas` / `dbs` / `dbm` | root / app `openeyes` / mirthdb | local container only | `dbas monkey` (root, plain prompt) |
| Web-container fn `dblogin` | app user `openeyes` | **local *and* RDS** | exec the web container, run `dblogin` |
| Direct `docker exec` | root | local container only | snippet below |

The host `dba*`/`dbs`/`dbm` functions (`~/.bash_aliases`) `docker exec` into the project's `*db-1` (or `*manager-1`) container, so they only work when the DB is a **local container**. For an **RDS** deployment there is no db container — use `dblogin` from inside the web container (it reads `/run/secrets/DATABASE_*` and connects to `$DATABASE_HOST:$DATABASE_PORT`), or point a client at the RDS endpoint directly.

Direct, no aliases (use this in automation):

```
docker exec -i <project>-db-1 bash -c 'mariadb -uroot -p$(cat $MYSQL_ROOT_PASSWORD_FILE) -A openeyes'
```

Append `-N -e "<SQL>"` for non-interactive queries. App-user creds: env `DATABASE_USER|PASS|HOST|PORT|NAME` and `/run/secrets/DATABASE_PASS` (web container); root password: the db container's `$MYSQL_ROOT_PASSWORD_FILE`.

## The schema is version-dependent

This build (v26): **~2330 base tables, ~1060 `<table>_version` history tables, 57 views**. New OE versions **add tables and columns** — core and per-module migrations ship them (see Migrations below); older versions lack them. **Never assume a table or column exists — confirm against `information_schema` first:**

```
SELECT table_name  FROM information_schema.tables  WHERE table_schema='openeyes' AND table_name LIKE 'oph%';
SELECT column_name FROM information_schema.columns WHERE table_schema='openeyes' AND table_name='event';
```

The **stable core** (section below) is the safe spine to rely on across versions; `oph*` module tables churn the most.

## Navigating by name

**Prefix decode**
- `oph…` — an ophthalmology **module event/element** table. 2nd segment = domain: `ci` = clinical info / examination, `tr` = treatment / operation, `co` = correspondence / clinical outcome, `dr` = drugs, `in` = investigations. e.g. `ophciexamination_*`, `ophtroperationnote_*`, `ophcocorrespondence_*`, `ophdrprescription_*`.
- `et_…` — **element** ("event type") tables, historically ≈ the same as `oph` (`et_ophco…`); roughly 1:1 with module elements.
- `v_…` — **reporting views** (read-only convenience joins). A few non-`v_` legacy views are used internally by the app.
- Core / common tables mostly **do not** start with `oph` (`patient`, `episode`, `event`, `user`…).

**Conventions on (almost) every table**
- Four audit columns: `created_user_id, created_date, last_modified_user_id, last_modified_date` (≈99% of tables; `user_session` is an exception).
- `<table>_version` — parallel history table holding prior row states (adds `version_id`, `version_date`); ~1060 of them. RBAC tables (`authitem`, `authassignment`) are **not** versioned.
- Soft-delete: clinical/patient tables use a `deleted` tinyint (`patient`, `episode`, `event`); org/config tables use an `active` tinyint (`user`, `firm`, `institution`). Default scopes hide soft-deleted rows.
- `audit` logs every user action; `audit_action|model|module|type|server|ipaddr|useragent` are its lookup satellites.

**Biggest families** (base-table counts; each ≈ doubles with `_version`):

| Prefix | ~Base | Domain |
|---|---|---|
| `ophciexamination` | 248 | examination elements (VA, segments, refraction, risks, history, plans) |
| `et_` | 230 | element tables across modules |
| `ophtroperationnote` | 69 | operation notes (cataract, glaucoma, retinal…) |
| `f_` | 47 | NHS **dm+d** drug ontology (vtm/vmp/amp/ampp/ingredient/lookup) |
| `ophtroperationbooking` | 37 | surgery scheduling / theatre / admission |
| `ophtrconsent` | 36 | surgical consent |
| `ophcotherapya` | 27 | therapy-advisory decision trees |
| `ophcocorrespondence` | 25 | clinical letters / macros / recipients |
| `medication` | 23 | medication master (drug ≈ medication) |
| `event_` | 23 | event metadata (types, subtypes, drafts, images) — not clinical data |
| `patientticketing` | 22 | patient communication tickets |
| `ophtroperationchecklists` | 22 | perioperative checklists |
| `worklist` | 16 | clinic worklists / queues |

Full inventory (all `oph*`, reference and feature families) → `subs/table-families.md`.

## Stable core tables

These rarely change across versions — the reliable spine for joins and scripts.

- **Auth / RBAC:** `user`, `user_session`, `authitem`, `authassignment`, `authitemchild`. (`user` is versioned; `authitem`/`authassignment` are not; `user_session` has no audit columns.)
- **Patient identity:** `patient`, `patient_identifier`, `patient_identifier_type`, `contact`, `address`. Demographics on `patient` are minimal; the real identifiers (NHS / hospital no.) live in `patient_identifier` by type. Each patient → a `contact` → an `address`.
- **Clinical spine:** `episode`, `event`, `event_type`, `event_subtype`, `element_type`, `eye` (LEFT 1 / RIGHT 2 / BOTH 3).
- **Org structure:** `institution`, `site`, `firm`, `subspecialty`, `service_subspecialty_assignment`, `gp`, `practice`, `commissioning_body`, `country`.
- **Config / lookup:** `setting_metadata`, `setting_installation`, and per-scope `setting_institution|site|firm|user|subspecialty|specialty`.
- **Audit:** `audit` + its `audit_*` satellites.

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

- `subs/table-families.md` — full prefix inventory: every `oph*` clinical family, the reference/coding tables (medications, dm+d, disorders, OPCS/proc), and the non-oph feature families.
- `subs/diagnoses-allergies-medications.md` — the disorders / allergies / medications layers and where they show up.
- `subs/letters-and-esign.md` — letter tables (`et_ophcocorrespondence_letter`, `LetterMacro`, `LetterRecipient`, `LetterEnclosure`) and the esign chain.
- `subs/identifier-and-config-tables.md` — `PatientIdentifier(Type)`, `Setting`, `InstitutionAuthentication` and the other lookup-shaped tables.
