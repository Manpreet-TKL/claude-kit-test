# The `protected/` tree - per-directory map + era key

`protected/` holds the whole Yii 1.1 app plus the Yii-side of the replatform.
The single fastest way to tell old code from new is the **namespace**.

## Era key

- **Legacy Yii 1.1** - global namespace, classes extend `C*` / `Base*`. Dirs:
  `components/ controllers/ models/ widgets/ behaviors/ commands/ migrations/
  extensions/ views/ config/`.
- **Replatform** - PSR-4 `OE\<dir>\`, mapped 1:1 to a `protected/` subdir in
  `composer.json` (`OE\repositories\` -> `protected/repositories`, etc.). So
  `OE\...` in a `use` = new; no namespace = old. The framework-agnostic
  interfaces/DTOs these depend on mostly live in `oe-shared/` (`OEShared\`); what
  sits in `protected/` is the **Yii-side glue** (repositories wrapping
  ActiveRecord, DTO mappers, Yii service impls, casters).

## Legacy dirs (global namespace)

| Dir | Purpose | Base / example |
|---|---|---|
| `models/` | ActiveRecord models (~311) | `BaseActiveRecord` -> `BaseActiveRecordVersioned[SoftDelete]`; subdirs `models/traits/`, `models/stepactions/` |
| `components/` | The legacy "everything" bucket (~191): APIs, managers, builders, services-before-`services/` | `BaseAPI`, `CoreAPI`, `ModuleAPI`, `EventBuilder`/`EventCreator`/`EventDefaults`, `AuthManager`, `DocumentRenderServicePuppeteer`, `AssetManager` |
| `controllers/` | `CController`-derived | `BaseController`, `BaseEventTypeController`, `BaseAdminController`; `controllers/oeadmin/` is a newer admin UI area (still legacy classes) |
| `widgets/` | `CWidget` UI widgets | `BaseEventElementWidget`, `BaseFieldWidget`, `BaseModuleWidget` |
| `behaviors/` | `CBehavior`/`CActiveRecordBehavior` mixins | `WorklistBehavior`, `EyedrawElementBehavior`, `OeDateFormat`, `LookupTable` |
| `commands/` | `CConsoleCommand` classes run by `./yiic <name>` (~58) | `GenerateWorklistsCommand`, `OEMigrateCommand`, `SeederCommand`; see `cli-jobs.md` |
| `cli_commands/` | **Not** yiic - standalone daemons run `php run*.php` | only `file_watcher/` (DICOM importer, raw mysqli); see `cli-jobs.md` |
| `migrations/` | `CDbMigration`/`OEMigration` files (~738) run by `./yiic migrate`; `migrations/data/` = per-migration CSV/xlsx payloads | schema detail -> `c-oe-db-schema` |
| `extensions/` | Yii extensions | `extensions/mpgii/` (custom Gii generator), `extensions/validators/` (legacy validators) |
| `config/` | The config root | `OEConfig.php` (the only merged-config assembler) + `main.php`/`console.php`/`test.php` + `core/`, `local/`, `local.sample/` |
| `views/` | Core (non-module) view templates (~37 dirs) | `patient/`, `worklist/`, `admin/`, `layouts/`, `print/` |
| `modules/` | The 45 Yii modules (clinical `Oph*` + infra) | each self-contained; may itself carry both eras (e.g. `Referral/` has legacy `models/` + replatform `dto/`/`repositories/`) |

## Replatform dirs (PSR-4 `OE\...`)

| Dir | Namespace | Purpose | Example |
|---|---|---|---|
| `repositories/` | `OE\repositories` | DTO-returning repos over ActiveRecord (read/write seam) | `PatientRepository extends BaseActiveRecordRepository implements PatientRepositoryContract` |
| `dto/` | `OE\dto` | AR <-> framework-agnostic DTO mappers (DTO classes themselves are in `oe-shared`) | `dto/mappers/PatientMapper extends ActiveRecordDTOMapper` |
| `services/` | `OE\services` | Domain services impl'ing OEShared contracts + an older FHIR-style resource layer | `AuditService implements AuditServiceContract`, `ModelService`, `ServiceManager` |
| `contracts/` | `OE\contracts` | Yii-only interfaces (most cross-framework contracts live in `oe-shared`) | `ProvidesYiiModelApplicationContext` |
| `casters/` | `OE\casters` | Attribute type-casters for the DTO/model layer | `CastToEnum implements CastToInterface` |
| `concerns/` | `OE\concerns` | Reusable traits | `AttributeCaster`, `CanBeFaked`, `InteractsWithApp` |
| `enums/` | `OE\enums` | Native PHP 8 enums | `SortDirection: string`, `FaceSide` |
| `exceptions/` | `OE\exceptions` | Typed exceptions extending SPL | `CannotSaveModelException`, `CannotFindModelException` |
| `factories/` | `OE\factories` | Yii-side model factories for tests/seeders (~165 in `factories/models/`) | `PatientFactory`, `EventFactory` |
| `forms/` | `OE\forms` | Typed form models bridging Yii | `BaseFormModel extends \CFormModel`, `PatientSearchPaginationForm` |
| `helpers/` | `OE\helpers` | Static utilities | `PatientIdentifierHelper`, `OEHtml`, `PDFUtils`, `Csv/` |
| `listeners/` | `OE\listeners` | App-level system-event listeners (`__invoke(<Event>)`) | `RemoveDraftEventAfterSoftDelete`, `UpdatePatientMedicationLinksAfterEventSave` |
| `resources/` | `OE\resources` | API resource/output transformers | `PatientResource`, `PaginationResource` |
| `seeders/` | `OE\seeders` | DB seeding framework, driven by `./yiic seeder` | `BaseSeeder`, `WorklistOwnerSeeder` |
| `validators/` | `OE\validators` | Validators (distinct from legacy `extensions/validators/`) | `PasswordValidator`, `EventTypeValidator` |

## Support / infra dirs (not code-era-coded)

- `javamodules/` - drop-zone for **compiled Java importers**; ships only a
  `README.md` here. The real artifact is `javamodules/IOLMasterImport/`
  (`OE_IOLMasterImport.jar`), invoked **only** by the `cli_commands/file_watcher`
  daemon to import DICOM biometry (consumed by `OphInBiometry`). See `cli-jobs.md`.
- `data/` - static seed/reference data (`dmd_data/...xlsx`, `randomdata.csv`).
- `scripts/` - host shell wrappers around yiic/cron (`generateworklists.sh`,
  `oe-migrate.sh`, `oe-fix.sh`, `cronrunner.sh`).
- `assets/` - published/served web assets (`js/`, `img/`, `nxblu/` submodule,
  `vue/dist` build output). `runtime/` - `runtime/logs/`. `docs/` - schema graffle.
- `quarantined_placeholder_files/` - replacement media swapped in when ClamAV
  flags an upload. `tests/` - PHPUnit/Codeception harness.

Note: `composer.json` maps `OE\SystemEvents\` -> `protected/system_events`, but
that dir does not exist in this checkout - system-event classes resolve from the
`OESysEvent` module / `oe-shared` instead.
