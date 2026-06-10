# OpenEyes — entry points when exploring (mostly stable, but verify)

Goal-keyed jump table. Class names move sometimes — `grep` to confirm before quoting in a PR.

| Goal | Start here |
|---|---|
| How a patient page is assembled | `controllers/PatientController.php` + `views/patient/` (especially `_patient_summary*.php`) |
| How a new event is created | `BaseEventTypeController::actionCreate`, `EventBuilder`, `EventDefaults` |
| How elements are wired to events | `BaseEventTypeElement`, `ElementType`, the module's `config/common.php`, `SubspecialtySubsection` |
| Cross-module reads | `components/BaseAPI.php`, `components/ModuleAPI.php`, each module's `*_API.php` |
| Core cross-module reads | `components/CoreAPI.php` |
| Authentication / permissions | `components/AuthManager.php`, `AuthRules.php`, `YiiAuth` module, `Oprn*` items in `authitem` |
| Letter rendering | `OphCoCorrespondence/components/`, `DocumentRenderServicePuppeteer`, `EventStringTokeniser` |
| Worklist generation | `GenerateWorklistsCommand`, `WorklistPatientResolver`, `Worklist*` models |
| Pathway logic | `PathwayStep` model, `PathstepObserver`, `OEEventManager` config |
| Diagnoses recomputation | `Diagnoses` module + `OEShared` system-event listeners |
| Eyedraw doodles & policies | `eyedraw` module + `OE_ED_CONFIG.xml` + `EyedrawReportTextPolicy*` |
| Imaging / DICOM | `DicomFiles`, `EventImage*`, `event_images/` directory |
| Outbound integrations | `Mirth/`, `PASAPI/`, `Webhooks/`, `EventExport/`, `correspondence_export_*` params |
| Inbound REST (new) | `oe-laravel/routes/api.php` (`/xapi/*`) and `oe-laravel/app/Http/Controllers/Xapi/` |
| Inbound REST (legacy) | `protected/modules/Api/` and `protected/modules/PASAPI/` |
| Shared (framework-agnostic) logic | `oe-shared/app/` (Contracts / DTOs / Repositories / Services) |
| Settings / institution-scoped config | `BaseSetting`, `settingCache`, `Admin` module's settings screens |
| Cron / batch jobs | `protected/commands/` — see CLI commands list in `oe-components` |
| Audit trail | `services/AuditService.php`, `Audit*` models, `AuditController` |
| Static analysis baseline for Yii errors | `phpstan-yii-baseline.neon` |
| When config "won't update" | clear APCu (`apc_clear.php` or restart php-fpm) |
