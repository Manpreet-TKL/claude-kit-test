---
name: c-oe-db-schema
description: OpenEyes DB - connect, schema, domain model
disable-model-invocation: true
---

# OpenEyes database

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself - it just loads knowledge; act only on instructions given in the conversation.

OpenEyes is event-based: every clinical interaction is an `event` row on an `episode` on a `patient` - reports, audit, RBAC, and integrations layer on that spine. 2300+ tables named after frontend/ophthalmology terms: navigate by naming convention, not by listing. Schema changes are clinical-safety changes; never bypass `audit` writes - see `c-oe-coding-standards`.

## Connecting

MariaDB: 10.6 for OE v6-v10, **11.8** for v11-v26. The DB is a local container (`<project>-db-1`) or remote AWS RDS - the app only knows `DATABASE_HOST`, so the same SQL works against either.

Interactive host fns (`~/.bash_aliases`; arg = compose-project prefix; each `docker exec -it`s and auto-detects the `mysql`||`mariadb` client):

| Fn | Runs as | Target |
|---|---|---|
| `dba [<proj>]` | root, colour prompt | local `*db-1`; falls back to the `*manager-1` container (-> RDS) when there is no local db |
| `dbas <proj>` | root, plain prompt | local `*db-1` |
| `dbs <proj>` | app user `openeyes` | local `*db-1` |
| `dbm [<proj>]` | root | local `*db-1`, **mirthdb** |

The fns open a shell (they forward no args), so for one-shot / scripted queries `docker exec` yourself:

```
# local db container, as root (append -N -e "<SQL>" for one-shot):
docker exec -i <proj>-db-1 bash -c 'mariadb -uroot -p"$(cat "${MYSQL_ROOT_PASSWORD_FILE:-/run/secrets/MYSQL_ROOT_PASSWORD}")" -A openeyes -N -e "<SQL>"'

# from the WEB container - works local AND RDS (uses $DATABASE_HOST), scriptable:
docker exec <proj>-web-1 sh -c 'mysql -h"$DATABASE_HOST" -P"$DATABASE_PORT" -uopeneyes -p"$(cat /run/secrets/DATABASE_PASS)" "$DATABASE_NAME" -N -e "<SQL>"'
```

**Credential gotchas (these cost time if unknown):**
- Passwords are Docker **secrets**, not env vars: `/run/secrets/DATABASE_PASS` (app user `openeyes`), `/run/secrets/MYSQL_ROOT_PASSWORD` (root). The `DATABASE_PASS` **env var is a stale placeholder** (often literally `openeyes`) and is rejected with `Access denied` - always read the secret file. Host/port/name come from `$DATABASE_HOST`/`$DATABASE_PORT`/`$DATABASE_NAME`.
- Client name differs by image: the web container ships `mysql`, the MariaDB db container ships `mariadb` (hence the auto-detect).
- No client, or you need results in code: PHP PDO from the web container works - `new PDO("mysql:host=".getenv("DATABASE_HOST").";dbname=".getenv("DATABASE_NAME"), "openeyes", trim(file_get_contents("/run/secrets/DATABASE_PASS")))`.

## Version-dependent schema

v26: ~2330 base tables, ~1060 `<table>_version` history tables, 57 views. New OE versions add tables and columns - never assume one exists:

```
SELECT column_name FROM information_schema.columns WHERE table_schema='openeyes' AND table_name='event';
```

## Navigating by name

- `oph...` = module event/element tables; 2nd segment: `ci` examination, `tr` treatment, `co` correspondence/outcome, `dr` drugs, `in` investigations. `et_...` = element tables. `v_...` = reporting views. Core tables don't start with `oph` (`patient`, `episode`, `event`, `user`).
- ~99% of tables carry `created_user_id, created_date, last_modified_user_id, last_modified_date` (`user_session` is an exception). `<table>_version` appends a row on every save; RBAC tables are not versioned.
- Soft-delete: clinical tables use `deleted`, org/config tables use `active`; default scopes hide them.
- Biggest families (base tables): `ophciexamination` 248, `et_` 230, `ophtroperationnote` 69, `f_` (NHS dm+d drug ontology) 47, `ophtroperationbooking` 37, `ophtrconsent` 36, `ophcocorrespondence` 25, `medication` 23, `worklist` 16. Full inventory -> `subs/table-families.md`.

**Stable core** (safe spine across versions): `user`, `user_session`, `authitem`, `authassignment`, `authitemchild`; `patient`, `patient_identifier(_type)`, `contact`, `address`; `episode`, `event`, `event_type`, `element_type`, `eye`; `institution`, `site`, `firm`, `subspecialty`; `setting_*`; `audit` + `audit_*` satellites.

## The spine

```
Patient ─┬─ PatientIdentifier(s)   NHS / hospital number, by type
         ├─ Contact -> Address; Gp, Practice, CommissioningBody
         ├─ Allergies, SocialHistory, secondary_diagnosis, EventMedicationUse
         └─ Episodes ── one per Firm/subspecialty; disorder_id = primary diagnosis
                └─ Events ── one clinical encounter or document
                       ├─ event_type_id -> module; event_date = clinical date
                       ├─ Element_<Module>_<Name> rows (one table per element type)
                       └─ EventDraft, EventImage, EventIssue, EsignElement
```

## Entity gotchas

- `patient.hos_num`/`nhs_num` are **legacy** - identifiers live in `patient_identifier` rows by type; resolve via `PatientIdentifierHelper`, never hard-code columns.
- `no_allergies_date`/`no_risks_date` are explicit "asked and answered: none" - a blank list != unrecorded.
- `event.event_date` (clinical, when it happened) != `created_date` (when entered). `parent_id` = amendment chain; `is_automated` + `automated_source` = PASAPI/Mirth-created; soft-delete carries `delete_reason`, may be `delete_pending`. Saves fire `ClinicalEvent*SystemEvent`s - listeners recompute diagnoses, relink medications, advance pathway steps.
- New element = migration + model + widget + view + `element_type` seed.
- `eye`: LEFT 1, RIGHT 2, BOTH 3. Per-eye data = `left_*`/`right_*` columns or per-eye rows with `eye_id`.
- Pathway = a visit's chain of `PathwayStep`s (`PathstepObserver` advances them on event save). Worklist = a day's clinic list; `worklist_patient_id` on `event` ties an event to its row.
- Data context = session site + firm + institution - filters almost every query (`CurrentContextSettingsService`). Firm ~ consultant team x subspecialty; episodes are owned per firm.
- RBAC: `authitem` (+`authitemchild` hierarchy, `authassignment`); prefixes `Oprn*` operations, `Task*` tasks; `bizrule` callables live in `components/AuthRules.php`. BreakGlass grants logged temporary access.
- `audit` is written by `AuditService` on every clinical CRUD - bypassing it is forbidden.

## Migrations

~730 core in `protected/migrations/` + per-module `migrations/`; run `OEMigrateCommand` / `MigrateModulesCommand` (`InitialDbMigrationCommand` for first setup). New: `m<YYMMDD>_<HHMMSS>_<snake_name>.php` extending `OEMigration`. Version tables: generate with `GenerateVersionMigrationCommand`, verify with `VerifyVersionTablesCommand`; FK integrity with `VerifyForeignKeysCommand`.

## Subs

- `subs/table-families.md` - full prefix inventory (clinical, reference/coding, feature families).
- `subs/diagnoses-allergies-medications.md` - disorders / allergies / medications layers.
- `subs/letters-and-esign.md` - letter tables and the esign chain.
- `subs/identifier-and-config-tables.md` - PatientIdentifier(Type), Setting, InstitutionAuthentication.
