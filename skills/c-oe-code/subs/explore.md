# OpenEyes — entry points when exploring (mostly stable, but verify)

Goal-keyed jump table. Class names move sometimes — `grep` to confirm before quoting in a PR.

| Goal | Start here |
|---|---|
| How a patient page is assembled | `controllers/PatientController.php` + `views/patient/` (especially `_patient_summary*.php`) |
| How a new event is created | `BaseEventTypeController::actionCreate`, `EventBuilder`, `EventDefaults` |
| How elements are wired to events | `BaseEventTypeElement`, `ElementType`, the module's migration (`element_type` seed), `SubspecialtySubsection` — full model → `subs/event-element-model.md` |
| Is this code legacy or replatform? Where does a class live? | `subs/protected-tree.md` (namespace = era; per-dir map) |
| When was this code introduced / deprecated, and in which release? | `subs/code-history.md` (pickaxe `-S`/`-G`, creation migrations, `tag --contains`) |
| The Patient→Episode→Event→Element spine | `subs/event-element-model.md` |
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
| Console commands / batch jobs | `protected/commands/` (yiic) + module `commands/`; the job-dispatch bridge → `subs/cli-jobs.md`; how to write one → `c-yiic-command-style` |
| Cron schedule (what runs when) | container runtime → `c-oe-components` |
| Async/queued jobs | `oe-shared/app/.../Jobs`, `components/JobDispatcher.php`, the `jobs` table, Horizon — `subs/cli-jobs.md` |
| Audit trail | `services/AuditService.php`, `Audit*` models, `AuditController` |
| Static analysis baseline for Yii errors | `phpstan-yii-baseline.neon` |
| When config "won't update" | clear APCu (`apc_clear.php` or restart php-fpm) |
