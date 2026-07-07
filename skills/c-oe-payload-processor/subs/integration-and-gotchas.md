# PayloadProcessor - OpenEyes integration & known issues

## How it writes back to OpenEyes - two paths

1. **REST API** (Basic auth as `API_USER`, `utils/*Api.java`):
   - `api/v2/attachmentData/{get,store,delete,UpdateAttachmentType,linkAttachmentWithEvent}`
     (`AttachmentDataApi`).
   - `api/v2/document/{search,create,update}` (`DocumentUploadApi`).
   - `api/v1/patient/search` with `term` + `patient_identifier_type`
     (`PatientSearchApi`) - this is the call that "handles hospital-number regexes
     and calls PAS" on the OpenEyes side.
2. **Direct SQL** on the shared DB via the `DataAPI`/`Query` event engine (through
   the worker's Hibernate connection) - this is how events, episodes, element rows
   etc. are actually created.

So the processor **shares the OpenEyes MySQL/MariaDB** and both calls the REST API
and writes directly to it. That dual nature is the key architectural fact.

## DB tables touched

Hibernate-mapped entities (`hibernate.cfg.xml`): `request`, `request_routine`,
`request_routine_execution`, `routine_library`, `attachment_data`, `request_queue`,
`request_queue_lock`, `request_routine_lock`, `request_details`,
`event_attachment_item`, `event`, `event_type`, `attachment_type`, `event_subtype`.
Plus direct native SQL (via `DataAPI`/`Query` and device DAOs) against core
OpenEyes tables: `episode`, `firm`, `service`, `subspecialty`,
`service_subspecialty_assignment`, `event_attachment_group`, `element_type`,
`et_ophgeneric_device_information`, `et_ophgeneric_comments`, `patient`, `user`, ...

## Admin surface - lives in the OpenEyes repo, not here

The OpenEyes `Api`/`Request` module provides the admin pages (Request Queue,
Request Type, Routine Library, Request, Request Routine, Mime Type, Attachment
Type, Manual Upload) and the `payload_processor` API user + RBAC. **None of that
is in this repository** - it only references the requirement that the API user
have the `API Access` RBAC role and not be able to log in interactively. For
admin-page / route / RBAC detail, look in the OpenEyes PHP module, not here. Seed
data for `request_type`/`mime_type`/`request`/`request_routine` is in
`src/main/resources/testDataInserts.sql`.

## Known issues / gotchas (from source)

- **`init.sh` switch bug** (`.docker_build/init.sh:65`): DB-retry passed as a
  second `-rq` instead of `-rd`; Commons CLI takes the first `-rq`, so the queue
  name survives but `-rd` is never set (DB-retry = 0). `/wait = 1` has a stray
  arg (`:60`).
- **DB-connect retry math** (`DicomEngine.java:162`): multiplies epoch millis by
  the retry minutes rather than adding an offset; combined with retry=0 it
  effectively tries once.
- **`getRequestWithLock` doesn't lock** (`RequestWorkerService.java:58-60`): calls
  plain `session.get(requestId)`, not a pessimistic `getWithLock` - the intended
  row lock on `request` isn't taken.
- **All-trusting TLS** (`BaseApi.java:102-136`, flagged `//TODO FIX HTTPS`): when
  `API_DO_HTTPS=true`, certificate and hostname verification are fully disabled.
- **`allowAllAccess(true)`** on the GraalVM context
  (`JavascriptScriptExecutor.java:42`): routines have unrestricted Java interop
  (arbitrary-Java capability). Fine for the trusted bundled scripts; dangerous if
  the routine dir / `routine_library` is ever attacker-controlled.
- **SQL by string concatenation** in `DataAPI`/`Query` and
  `RoutineScriptService.get*SqlQuery` (`:474-506`) - injection surface; values
  originate from device payloads.
- **Windows path separators** in a Linux container:
  `RoutineScriptService.getFileAsBlob`/`moveFile` use `dir + "\\" + name`
  (`:256,272-273`).
- **Routine sync never updates/deletes** - see `subs/queue-and-routines.md`;
  `hash_code` is a 32-bit `String.hashCode()` stored in a `BIGINT`.
- **`SELECT *` poll** over `request_routine` with a correlated `NOT EXISTS` on the
  same table runs every `busy_yield_ms`; performance leans on indexes
  (`execute_request_queue`, `status`, `request_id`, `execute_sequence`,
  `next_try_date_time`) that are **not defined in this repo** (`hbm2ddl=validate`).
- **No automated tests** - there is no `src/test`; the `src/*.json` files are
  ad-hoc `DataAPI.main` fixtures, not a test suite.
- **Stale docs:** README JDK 1.8 vs pom Java 21 vs CodeQL JDK 8; three different
  published image names.
