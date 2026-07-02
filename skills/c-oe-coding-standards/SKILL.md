---
name: c-oe-coding-standards
description: OpenEyes coding-standards index
disable-model-invocation: true
---

# OpenEyes coding standards

When loaded as context with no task, reply only `Context loaded.` This skill is context-only: it never does anything by itself — it just loads knowledge; act only on instructions given in the conversation.

Index of every OpenEyes coding standard, one line each. Read the linked sub-file
**only** for the standard(s) you're actually touching — that's where the example,
specifics, and source live. Distilled from the OPD Confluence space (Developer
Guidelines / Developer Checklist + topic pages); rules tagged *(replatform)* apply
to `OEShared` / `OELaravel` code, otherwise legacy Yii.

## Clinical safety — non-negotiable

1. Never change persistence, calculation, units, or display of a clinical value (VA, IOP, dose, laterality, drug name/strength) without an explicit ask. → [clinical-safety](subs/clinical-safety.md#never-touch-clinical-values-unasked)
2. Never bypass `audit` — write through the model layer so `AuditService` fires, even in scripts. → [clinical-safety](subs/clinical-safety.md#never-bypass-audit)
3. Soft-delete clinical data (`deleted = 1`); never hard `DELETE`. → [clinical-safety](subs/clinical-safety.md#soft-delete-only)
4. `TestHelper` is never enabled in production — don't loosen its `OE_MODE !== 'live'` gate. → [clinical-safety](subs/clinical-safety.md#testhelper-stays-out-of-live)
5. A module advertises itself in its own `config/common.php`; never edit `core/common.php` from a module install. → [clinical-safety](subs/clinical-safety.md#modules-self-register)
6. `voiceControl` stays independent of `aiSearch` — no runtime dependency, shared key, or cross-import. → [clinical-safety](subs/clinical-safety.md#voicecontrol-independent)

## Security & data integrity ("be paranoid")

7. Validate all user input. → [security](subs/security.md#validate-all-input)
8. Authorise every user action before performing it. → [security](subs/security.md#authorise-every-action)
9. Bind/escape all DB query parameters — never string-concatenate SQL. → [security](subs/security.md#bind-query-parameters)
10. Escape all rendered output (`CHtml::encode`). → [security](subs/security.md#escape-output)
11. Audit actions where appropriate. → [security](subs/security.md#audit-actions)
12. Make it scale: pagination, eager loading, caching. → [security](subs/security.md#design-for-scale)
13. Request forms MUST validate requests for all new endpoints. → [security](subs/security.md#request-forms-validate-endpoints)

## Code style & structure

14. Casing — Yii vars `snake_case` / methods `camelCase`; *(replatform)* + JS vars `camelCase`. → [style](subs/style.md#casing)
15. Short array syntax `[]`, never `array()`. → [style](subs/style.md#short-arrays)
16. Reference classes with `::class`, never a quoted FQN string. → [style](subs/style.md#class-constant)
17. `const` over `static` for class constants. → [style](subs/style.md#const-over-static)
18. RFC string interpolation `{$var}`; avoid `${}` (deprecated PHP 8.2). → [style](subs/style.md#string-interpolation)
19. Short methods; abstract complex conditionals into well-named methods. → [style](subs/style.md#short-methods)
20. At most two levels of nesting, never more than three. → [style](subs/style.md#nesting-depth)
21. Member order: `public` → `protected` → `private`; static before instance. → [style](subs/style.md#member-order)
22. Type-hint parameters and return types. → [style](subs/style.md#type-hints)
23. Prefer traits over Yii `CBehavior` unless `CBehavior` earns its keep. → [style](subs/style.md#traits-over-cbehavior)
24. Copyright header atop every file; `namespace` directly beneath it. → [style](subs/style.md#header-and-namespace)
25. Namespace every new module (`OEModule\[Name]`), segments correctly capitalised. → [style](subs/style.md#namespace-modules)
26. Target the latest supported PHP without breaking the minimum supported version. → [style](subs/style.md#target-php-version)

## Naming

27. New element classes: plain `UpperCamelCase` — drop legacy `Oph`+category prefixes. → [naming](subs/naming.md#class-names)
28. DB tables keep prefixes: `et_[module]_[element]`, `[module]_[element]_[purpose]`. → [naming](subs/naming.md#table-names)
29. Expressive names; avoid abbreviations; don't repeat the class name in its members. → [naming](subs/naming.md#name-quality)

## Comments & documentation

30. Comments explain *why*, not *what* — code reveals the what. → [docs-comments](subs/docs-comments.md#why-not-what)
31. DTO docblocks: one-line summary, `@property` per property (type + description), `@table`. → [docs-comments](subs/docs-comments.md#dto-docblocks)
32. PHP view headers: `Ref:` rendering `class::method` lines + `@var` type-hints. → [docs-comments](subs/docs-comments.md#view-headers)
33. JS file headers: short description + `Ref:` include-path line(s). → [docs-comments](subs/docs-comments.md#js-headers)

## Tooling & static analysis

34. PSR-12 via phpcs; run `composer cs:<yii|laravel|shared> -- <file>` before commit. → [tooling](subs/tooling.md#phpcs)
35. Configure `githooks/pre-commit` — it runs phpcbf + phpcs + rector on changed files. → [tooling](subs/tooling.md#pre-commit-hooks)
36. Run PHPStan via `composer stan:branch` before pushing; never pad a baseline to hide your own error. → [tooling](subs/tooling.md#phpstan)
37. Rector enforces the target PHP version (8.4) in pre-commit and CI. → [tooling](subs/tooling.md#rector)
38. Config change not showing? Clear APCu (`apc_clear.php` or restart php-fpm). → [tooling](subs/tooling.md#apcu)
39. Migrations: `<timestamp>_<snake>.php` extends `OEMigration`; run via `yiic OEMigrate` / `MigrateModulesCommand`; verify FKs. → [tooling](subs/tooling.md#migrations)

## Models (Yii)

40. No `$_GET`/`$_POST`/`$_SESSION` — and no controller dependency — inside a model. → [models](subs/models.md#no-globals)
41. All validation lives in `rules()`; validate lookups with `exist` + `::class`. → [models](subs/models.md#validation-in-rules)
42. Mark every data attribute `safe` (full mass assignment expected). → [models](subs/models.md#safe-attributes)
43. Reuse `OE*Validator`; promote a custom rule to a core validator (with tests) once >3 models would duplicate it. → [models](subs/models.md#reuse-validators)
44. Audit-user relations on every model (`user` / `usermodified` → `User`). → [models](subs/models.md#audit-user-relations)
45. Define `HAS_MANY` relations; enable `$auto_validate_relations` and `$auto_save_relations`. → [models](subs/models.md#relations)
46. Pass model instances, not ids; instantiate managers/components via the factory pattern. → [models](subs/models.md#pass-models)
47. Pick the right ActiveRecord base: `BaseActiveRecord` → `…Versioned` → `…VersionedSoftDelete` (default for clinical). → [models](subs/models.md#base-classes)

## Models (Laravel / Eloquent — replatform)

48. `@use HasFactory<…>` phpdoc + a `@return` generic on every relation method. → [laravel-models](subs/laravel-models.md#phpdoc-generics)
49. Filter with `has('rel', fn (Builder $q) => …)`, not `whereRelationId()` — it respects default scopes. → [laravel-models](subs/laravel-models.md#has-not-whererelationid)
50. Declare casts in `casts()`; eager loading is multi-query; ordering by a relation needs an explicit `join` + root-only `select`. → [laravel-models](subs/laravel-models.md#casts-and-loading)

## Modules & architecture

51. Read another module's data only via `Yii::app()->moduleAPI->get('[Module]')`; never import its models. → [modules](subs/modules.md#module-api-access)
52. A module API returns abstract data (not models); `getLetter[Desc](\Patient $patient, bool $use_context = false)`; split large APIs into traits. → [modules](subs/modules.md#api-shape)
53. Modules are self-contained: `README`, `test/{unit,feature}`, behaviour encapsulated in the module not core. → [modules](subs/modules.md#self-contained)
54. Record significant design decisions as ADRs in `docs/adr/` (adr-tools). → [modules](subs/modules.md#adrs)

## DTOs, services & repositories (replatform)

55. DTOs decouple logic from the ORM; generate via codegen; map via a named `DTOMapper` (resolve/mock through the container). → [dtos-services](subs/dtos-services.md#dtos-and-mappers)
56. DTO attribute casts via `$custom_casts` + `AttributeCastType`; protect id/event fields with `HasReadOnly*` traits (+ `__clone`). → [dtos-services](subs/dtos-services.md#dto-casts-and-readonly)
57. Services: concrete `OEShared`, operate on DTOs, constructor-injected deps, wrap writes in transactions, resolve via container, no web/data-layer reach. → [dtos-services](subs/dtos-services.md#service-layer)
58. Repositories mediate all storage, consume/return DTOs; `store(DTO)` returns the PK (re-fetch for saved state). → [dtos-services](subs/dtos-services.md#repository-layer)

## Auth (replatform)

59. Auth inside `OELaravel\Modules\YiiAuth` (Laravel conventions); authorise via `Gate` backed by `YiiRBAC`; drop hard-coded user refs (prefer HMAC tokens). → [auth](subs/auth.md#auth)

## Frontend

60. Never inline-style — themed CSS only. → [frontend](subs/frontend.md#no-inline-styling)
61. Match the IDG DOM (semantic, efficient HTML); never use `-idg-` classes; don't repurpose design elements without DA sign-off. → [frontend](subs/frontend.md#idg-dom)
62. New JS: encapsulated, jQuery-free modules; `js-` prefix for behaviour hooks (never drive behaviour off layout classes). → [frontend](subs/frontend.md#encapsulated-js)
63. `AdderDialog` / `ElementController` are the standard form UI; `CollapseData` toggles classes, never inline styles. → [frontend](subs/frontend.md#standard-ui-widgets)

## API / xAPI

64. OpenAPI 3.0+, spec generated from PHP `#[OAT\Schema]` / `#[OAT\Property]` attributes (`oe:generate-xapi-spec`). → [api-xapi](subs/api-xapi.md#attribute-driven-spec)
65. Resources extend `BaseDTOResource`; patient-owned extend `OwnedByPatientResource`; `ReferenceResource` for links; UCUM for non-SNOMED units. → [api-xapi](subs/api-xapi.md#resources)
66. Standard envelope `data`/`meta`/`links`; `ErrorResponse`/`ErrorObject` for errors; cursor pagination; a documented HTTP status per outcome. → [api-xapi](subs/api-xapi.md#response-contract)
67. Contract tests per resource + CI validation (`openapi:validate` / `coverage ≥95%` / `lint`). → [api-xapi](subs/api-xapi.md#validation)

## Testing

68. PHPUnit 11: attributes not annotations (`#[CoversClass]`, `#[Group]`); data providers must be `static`. → [testing](subs/testing.md#phpunit-attributes)
69. Run via `oeunittests` (`--laravel` / `--shared` / `--group`); CI runs PHPUnit on every PR. → [testing](subs/testing.md#running-tests)
70. Pick the right base class (`ModelTestCase` / `OEDbTestCase` / `OELaravel\Tests\TestCase` / `InMemoryTestCase`); write no new fixture-based tests. → [testing](subs/testing.md#base-classes)
71. Keep the DB clean: exactly one of `WithTransactions` (preferred) or `ResetsCreatedModels`, on an `OEDbTestCase`. → [testing](subs/testing.md#keep-db-clean)
72. Factories: `withoutParents()` to suppress parents, `unique()` faker for constrained fields, `withDefaultRelations()` (not `configure()`), `firstOrCreate` for lookups, `Event::factory()->forEventType*`. → [testing](subs/testing.md#factories)
73. Feature-test the request via `MakesApplicationRequests` (get/post, query-string GET params, `actingAs($user, $institution)`, wrapper assertions). → [testing](subs/testing.md#application-requests)
74. Non-namespaced `DefaultController` route tests need `@runTestsInSeparateProcesses` + `@preserveGlobalState disabled`. → [testing](subs/testing.md#process-isolation)
75. Every support-ticket fix gets ≥1 test reproducing the failure (urgent fixes: ship, then follow-up ticket adds it). → [testing](subs/testing.md#regression-tests)
76. New functionality gets at least an E2E happy-path test — prefer fast PHPUnit application-request over Cypress. → [testing](subs/testing.md#new-functionality)
77. Cypress for genuine JS interactivity / patient pathways; short suites run per-PR (keep fast), long suites run overnight. → [testing](subs/testing.md#cypress)

## Pull requests & merge

78. PR clarity — use the GitHub feature/bug template; explain purpose, changes, testing. → [process](subs/process.md#pr-clarity)
79. All new code passes the standards (phpcs + phpstan + the checklist) and ships automated tests. → [process](subs/process.md#standards-and-tests)
80. UI follows IDG; a change to an old version must also work on newer versions (contributor's responsibility). → [process](subs/process.md#ui-and-compatibility)

---

Related skills: `create-oe-module`, `c-oe-ui`, `c-bash-style`, `c-yiic-command-style`, `c-note-style`.
Extra subs: `subs/validators.md` (OE validator catalogue), `subs/disruptive-ops.md` (literal-`yes` confirms, secrets, demo caveats).
